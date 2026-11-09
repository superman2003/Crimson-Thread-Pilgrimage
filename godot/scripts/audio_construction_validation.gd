extends SceneTree
## Real audio streams, production preparation jobs and cancellation boundaries.
const DIRECTOR := preload("res://scripts/audio_director.gd")
const RETIRE := preload("res://scripts/audio_retirement.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const AUDIO_JOBS := ["_begin_audio", "_start_audio_explore", "_start_audio_ambience"]
var checks := 0
var failures := 0
var world: Node
var cancel_stage := ""
var exit_stage := ""
var observed := {}
var work: Array = []

class AudioHost:
    extends "res://scripts/main_level.gd"
    func _ready() -> void: pass
    func _process(_delta: float) -> void: pass
    func _should_autoplay_audio() -> bool: return true

class ObservedWorld:
    extends "res://scripts/main_level.gd"
    signal audio_stage(stage: String)
    # Exercise the actual audio branch under both GL and headless fixtures.
    func _should_autoplay_audio() -> bool: return true
    func _begin_audio() -> void:
        super._begin_audio()
        audio_stage.emit("begin")
    func _start_audio_explore() -> void:
        super._start_audio_explore()
        audio_stage.emit("explore")
    func _start_audio_ambience() -> void:
        super._start_audio_ambience()
        audio_stage.emit("ambience")

func _initialize() -> void:
    call_deferred("run")

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)

func exported_audio_remaps() -> void:
    # Mount a real miniature pack with imported AudioStream resources and
    # .remap entries, deliberately without their raw OGG/WAV files.
    var pack := PCKPacker.new()
    var pack_path := "user://audio_export_contract.pck"
    check(pack.pck_start(ProjectSettings.globalize_path(pack_path)) == OK,"start remap-only audio fixture")
    var sources := ["res://assets/audio/sfx/kenney/impact/footstep_grass_003.ogg","res://assets/audio/seals/ward_prepare.wav"]
    var aliases: Array[String] = []
    for index in sources.size():
        var extension: String = String(sources[index]).get_extension()
        var alias := "res://__audio_export_contract/stream_%d.%s" % [index,extension]
        var resource_path := "res://__audio_export_contract/stream_%d.tres" % index
        var saved := "user://audio_export_stream_%d.tres" % index
        var remap := "user://audio_export_stream_%d.remap" % index
        var stream := DIRECTOR._load_stream(sources[index])
        check(stream != null,"fixture starts with a real " + extension + " stream")
        check(ResourceSaver.save(stream,saved) == OK,"save native audio fixture resource")
        var file := FileAccess.open(remap,FileAccess.WRITE)
        file.store_string('[remap]\npath="%s"\n' % resource_path)
        file.close()
        check(pack.add_file(resource_path,ProjectSettings.globalize_path(saved)) == OK,"pack native stream")
        check(pack.add_file(alias+".remap",ProjectSettings.globalize_path(remap)) == OK,"pack the export remap")
        aliases.append(alias)
    check(pack.flush() == OK,"finish real audio fixture pack")
    pack = null
    check(ProjectSettings.load_resource_pack(ProjectSettings.globalize_path(pack_path)),"mount exported audio fixture")
    for alias in aliases:
        check(not FileAccess.file_exists(alias) and ResourceLoader.exists(alias,"AudioStream"),"export fixture has a remap and no raw audio file")
        var once := DIRECTOR.load_cached(alias,false)
        var looping := DIRECTOR.load_cached(alias,true)
        check(once != null and looping != null and once.get_length() > 0,"exported audio decodes through production loader")
        check(once != looping and once == DIRECTOR.load_cached(alias,false),"each loop policy owns its stream and retains cache identity")
        if once is AudioStreamOggVorbis:
            check(not once.loop and looping.loop,"OGG loop flag cannot leak across policy keys")
        elif once is AudioStreamWAV:
            check(once.loop_mode == AudioStreamWAV.LOOP_DISABLED and looping.loop_mode == AudioStreamWAV.LOOP_FORWARD,"WAV loop flag cannot leak across policy keys")
    DIRECTOR._stream_cache.clear()

func state(host: Node) -> Dictionary:
    var director: Node = host.audio_director
    var result := {"chapter":director.chapter_short_id,"volumes":director.user_volumes.duplicate(),"players":[],"timers":[]}
    for player in [director.explore_player,director.ambience_bed_player]:
        result.players.append({"name":String(player.name),"bus":String(player.bus),
            "loop":player.stream.loop,"length":player.stream.get_length(),"playing":player.playing})
    for child in director.get_children():
        if child is Timer:
            result.timers.append({"name":String(child.name),"one_shot":child.one_shot,"stopped":child.is_stopped()})
    return result

func retire_host(host: Node) -> void:
    host._release_region_audio()
    var director: Node = host.audio_director
    check(director.region_audio_released and not director.autoplay_enabled,
        "release invalidates the director before budgeted eviction")
    # Late calls model continuations already queued when cancellation was seen.
    # Both public host stages and direct director stages must stay retired.
    host._start_audio_explore()
    host._start_audio_ambience()
    director._play_explore_track(director._explore_track_path())
    director._start_ambience()
    host._release_region_audio()
    check(host.bgm_player == null or host.bgm_player.stream == null,
        "repeated release and late exploration cannot reacquire playback")
    check(director.ambience_bed_player == null or director.ambience_bed_player.stream == null,
        "late ambience cannot reacquire playback")
    for timer in [director.oneshot_timer, director.anvil_timer]:
        if is_instance_valid(timer): check(timer.is_stopped(), "retired ambience timers remain stopped")
    for tween in [director.explore_tween, director.transit_tween]:
        check(tween == null or not tween.is_valid(), "retirement cancels audio envelopes before eviction")
    check(await RETIRE.drain(self), "streams retire while the released director is still alive")
    host.free()
    await process_frame
    check(await RETIRE.drain(self), "all staged streams and playbacks retire")
    check(DIRECTOR.instance == null and DIRECTOR._stream_cache.is_empty(), "retirement releases director and decoded cache")

func chapter_fixture(id: String) -> void:
    var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROUTES.config_path(id)))
    var host := AudioHost.new()
    host.config = config
    root.add_child(host)
    var plan: Array = host._region_prepare_jobs(config)
    var methods: Array = []
    for job in plan:
        if String(job.method) in AUDIO_JOBS or String(job.method) == "_prepare_audio": methods.append(String(job.method))
    check(methods == AUDIO_JOBS, "production preparation admits three ordered audio jobs")
    var deltas: Array = []
    var maximum := 0
    for method in methods:
        var before := DIRECTOR._stream_cache.size()
        host.call(method)
        var added := DIRECTOR._stream_cache.size() - before
        maximum = maxi(maximum,added)
        deltas.append({"method":method,"decoded_streams":added})
        if method == "_begin_audio":
            check(DIRECTOR._stream_cache.is_empty() and host.bgm_player.stream == null,
                "initialization creates buses and ownership without loading either track")
            check(host.audio_director.chapter_short_id == DIRECTOR._short_chapter_id(id), "chapter identity is ready before track jobs")
        if method == "_start_audio_explore":
            check(host.bgm_player.stream == DIRECTOR._stream_cache.get(host.audio_director._explore_track_path()+"|1")
                and host.audio_director.ambience_bed_player == null, "explore admission loads only the selected looping music")
        await process_frame
    check(maximum <= 1 and DIRECTOR._stream_cache.size() == 2,
        "each admission decodes at most one stream and the completed chapter has both")
    var staged := state(host)
    var bed_path: String = host.audio_director._ambience_bed_path()
    check(host.audio_director.ambience_bed_player.stream == DIRECTOR._stream_cache.get(bed_path+"|1"), "ambience retains the selected looping bed")
    check(staged.players[0].loop and staged.players[1].loop and staged.players[0].playing and staged.players[1].playing,
        "both actual streams loop and have started")
    work.append({"region":id,"jobs":deltas,"maximum_decodes":maximum,"published_audio":staged})
    await retire_host(host)
    var synchronous := AudioHost.new()
    synchronous.config = config
    root.add_child(synchronous)
    synchronous._prepare_audio()
    check(state(synchronous) == staged, "synchronous wrapper preserves players, buses, loop flags, volumes and timers")
    await retire_host(synchronous)

func observe_stage(stage: String) -> void:
    if (stage != cancel_stage and stage != exit_stage) or world.world_loader.phase != "loading": return
    var exiting := stage == exit_stage
    cancel_stage = ""
    exit_stage = ""
    var director: Node = world.audio_director
    var refs: Array[WeakRef] = [weakref(director)]
    if world.world_loader.transition_token != null:
        refs.append(weakref(world.world_loader.transition_token))
    var streams := 0
    for player in [director.explore_player,director.ambience_bed_player]:
        if is_instance_valid(player) and player.stream != null:
            streams += 1
            refs.append(weakref(player.stream))
            if player.has_stream_playback(): refs.append(weakref(player.get_stream_playback()))
    observed = {"stage":stage,"target":String(world.config.id),"stream_count":streams,"refs":refs}
    if exiting: world.queue_free()
    else: world.world_loader.cancel_transition()

func progress() -> String:
    return var_to_str([world.currency_count,world.inventory_counts,world.story_flags,world.build_system.serialize(),world.player.hp,world.player.energy])

func wait_idle() -> void:
    for unused in 4000:
        if world.world_loader.phase == "idle": return
        await process_frame
    check(false,"audio transition returns to idle")

func cancel_audio(stage: String) -> void:
    var source: String = world.config.id
    var position: Vector2 = world.player.global_position
    var before := progress()
    var path := ROUTES.config_path("demo_ch02_rain_foundry_canal")
    var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
    observed = {}
    cancel_stage = stage
    world._request_world_travel(path,Vector2(config.player_start[0],config.player_start[1]))
    await wait_idle()
    check(not observed.is_empty() and String(observed.get("stage","")) == stage,
        "cancellation observes the requested actual audio job")
    check(String(observed.get("target","")) == String(config.id), "the observed partial director belongs to the destination")
    var expected := {"begin":0,"explore":1,"ambience":2}
    check(int(observed.get("stream_count",-1)) == int(expected[stage]), "partial destination owns exactly the completed track admissions")
    check(bool(world.world_loader.last_transition.get("rolled_back",false)) and String(world.config.id) == source,
        "audio cancellation rebuilds the source instead of publishing the target")
    check(world.player.global_position == position and progress() == before,
        "audio cancellation preserves settled position, inventory and progress")
    var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.world_save_path))
    check(String(saved.get("current_region","")) == source, "partial audio never publishes the destination save")
    check(DIRECTOR.instance == world.audio_director and world.bgm_player.stream != null
        and world.audio_director.ambience_bed_player.stream != null, "source rollback owns complete exploration and ambience")
    check(await RETIRE.drain(self), "cancelled destination playback releases AudioServer ownership")
    for ref in observed.get("refs",[]): check(ref.get_ref() == null, "cancelled destination director, stream and playback are released")
    work.append({"cancel_stage":stage,"stream_count":observed.get("stream_count",-1),"source_restored":String(world.config.id)})
    observed.clear()


func exit_partial_audio(stage: String) -> void:
    const SAVE := "user://audio_construction_exit_validation.json"
    world = ObservedWorld.new()
    world.world_mode = true
    world.world_resume = false
    world.world_save_path = SAVE
    world.audio_stage.connect(observe_stage)
    root.add_child(world)
    for unused in 4000:
        if world.initial_region_ready: break
        await process_frame
    check(world.initial_region_ready, "exit fixture publishes source before requesting travel")
    if not world.initial_region_ready:
        world.free()
        world = null
        return
    current_scene = world
    var source: String = world.config.id
    var host_ref: WeakRef = weakref(world)
    var loader_ref: WeakRef = weakref(world.world_loader)
    var path := ROUTES.config_path("demo_ch02_rain_foundry_canal")
    var target: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
    observed = {}
    exit_stage = stage
    world._request_world_travel(path,Vector2(target.player_start[0],target.player_start[1]))
    for unused in 4000:
        if host_ref.get_ref() == null: break
        await process_frame
    check(host_ref.get_ref() == null, "actual World exits during " + stage + " preparation")
    check(not observed.is_empty() and String(observed.get("stage","")) == stage,
        "exit reaches the requested production audio stage")
    var expected := {"begin":0,"explore":1,"ambience":2}
    check(int(observed.get("stream_count",-1)) == int(expected[stage]), "exit captures exactly the admitted destination streams")
    world = null
    current_scene = null
    await process_frame
    check(await RETIRE.drain(self), "tree-exit fallback observes and retires partial playback")
    check(loader_ref.get_ref() == null, "host exit releases its suspended region loader")
    for reference in observed.get("refs",[]):
        check(reference.get_ref() == null, "host exit releases partial director, stream and playback")
    check(DIRECTOR.instance == null and DIRECTOR._stream_cache.is_empty(), "partial host exit releases singleton and cache")
    var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
    check(String(saved.get("current_region","")) == source, "host exit never saves a partially prepared destination")
    work.append({"exit_stage":stage,"source_save":source,"stream_count":observed.get("stream_count",-1)})
    observed.clear()
    for suffix in ["", ".bak", ".tmp"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))

func run() -> void:
    root.process_mode = Node.PROCESS_MODE_DISABLED
    for id in ROUTES._data().chapters:
        await chapter_fixture(String(id))
    world = ObservedWorld.new()
    world.world_mode = true
    world.world_resume = false
    world.world_save_path = "user://audio_construction_validation.json"
    world.audio_stage.connect(observe_stage)
    root.add_child(world)
    for unused in 4000:
        if world.initial_region_ready: break
        await process_frame
    current_scene = world
    check(world.initial_region_ready, "observed World publishes production startup")
    if world.initial_region_ready:
        for stage in ["begin","explore","ambience"]: await cancel_audio(stage)
    world.free()
    world = null
    current_scene = null
    await process_frame
    check(await RETIRE.drain(self), "final World audio drains")
    check(DIRECTOR.instance == null and DIRECTOR._stream_cache.is_empty(), "final World releases audio owner and stream cache")
    for stage in ["begin","explore","ambience"]: await exit_partial_audio(stage)
    exported_audio_remaps()
    var output := ProjectSettings.globalize_path("res://../artifacts/audio_preparation_retirement_v22")
    DirAccess.make_dir_recursive_absolute(output)
    var file := FileAccess.open(output.path_join("job-contract.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify({"checks":checks,"failures":failures,"work":work},"  "))
    file.close()
    print("AUDIO_CONSTRUCTION checks=%d failures=%d" % [checks,failures])
    quit(1 if failures > 0 else 0)
