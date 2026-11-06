extends SceneTree
## Publication/rollback fixture, with explicit placement at sound origins.
## This is not a natural walkthrough or an audible mix review.
const AUDIO := preload("res://scripts/audio_director.gd")
const RETIREMENT := preload("res://scripts/audio_retirement.gd")
const SAVE := "user://spatial_ambience_world.json"
var checks := 0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures.append(label)
func play_at_source(scene: Node, family: String = "regional") -> AudioStreamPlayer2D:
    var director: Node=scene.audio_director
    var rows: Array=director.ambient_soundscape.sources.filter(func(row):return row.family==family)
    if rows.is_empty():return null
    # The host is persistent: published source positions are region-local,
    # transformed by that same host rather than copied into a new world frame.
    scene.player.global_position=scene.to_global(rows[0].position)
    director.autoplay_enabled=true
    director.combat_active=false
    director.boss_active=false
    director.dialogue_open=false
    director.shrine_engaged=false
    scene.player.ui_input_locked=false
    director.set_user_volume("master",100)
    director.set_user_volume("ambience",100)
    AUDIO._voice_last_ms.erase("amb_oneshot")
    if not director._play_ambience_oneshot(-6,family):return null
    return director.ambient_soundscape.voices[0]
func run() -> void:
    root.process_mode=Node.PROCESS_MODE_DISABLED
    var scene: Node=load("res://scenes/World.tscn").instantiate()
    scene.world_resume=false
    scene.world_startup_options_enabled=false
    scene.world_save_path=SAVE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    var original_director: Node=scene.audio_director
    var original_director_ref: WeakRef=weakref(original_director)
    check(original_director.ambient_soundscape.sources.size()==2,"normal startup publication configures courtyard sound origins")
    check(original_director.ambient_soundscape.host_node()==scene and original_director.runtime_player==scene.player,"production region audio binding supplies the live host and persistent player")
    var inventory: Dictionary=scene.inventory_counts.duplicate(true)
    var flags: Dictionary=scene.story_flags.duplicate(true)
    var money: int=scene.currency_count
    var saved_bytes:=FileAccess.get_file_as_bytes(SAVE)
    var voice:=play_at_source(scene)
    check(voice!=null and voice.playing,"published World director admits a real accent at its authored courtyard origin")
    if voice!=null:
        check(voice.global_position==scene.player.global_position,"actual World uses one coordinate system for source and listener")
    check(scene.inventory_counts==inventory and scene.story_flags==flags and scene.currency_count==money,"ambient playback cannot grant progress, rewards or map knowledge")
    check(FileAccess.get_file_as_bytes(SAVE)==saved_bytes,"ambient playback performs no journey save")
    var target: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/demo_ch02_rain_foundry_canal.json"))
    var start: Array=target.player_start
    var player_id: int=scene.player.get_instance_id()
    var switched: bool=await scene.world_loader.replace_region_async(scene,"res://data/demo_ch02_rain_foundry_canal.json",Vector2(start[0],start[1]))
    check(switched and scene.world_loader.phase=="idle","real async publication reaches the rain canal")
    check(not is_instance_valid(voice) or not voice.playing,"departed region's accent cannot survive publication")
    voice=null
    original_director=null
    await process_frame
    check(original_director_ref.get_ref()==null,"departed director and its soundscape are actually freed")
    check(scene.player.get_instance_id()==player_id,"transition preserves the real persistent player")
    var next_director: Node=scene.audio_director
    check(next_director.ambient_soundscape.sources.size()==3 and next_director.ambient_soundscape.chapter=="ch02","arrival rebuilds only the destination's two regional sources and furnace")
    check(next_director.ambient_soundscape.host_node()==scene and next_director.runtime_player==scene.player,"async arrival executes the same production audio binding")
    voice=play_at_source(scene,"anvil")
    check(voice!=null and voice.playing and voice.get_meta("ambient_source","")=="furnace_floor","actual arrived region plays the furnace from its own authored room")
    next_director.begin_chapter_transition()
    check(voice==null or (not voice.playing and voice.stream==null),"departure immediately retires destination playback")
    next_director.cancel_chapter_transition()
    next_director.ambient_soundscape.source_times.clear()
    voice=play_at_source(scene,"anvil")
    check(voice!=null and voice.playing,"cancelled departure permits the same region's ambient playback again")
    RETIREMENT.retire_tree(scene)
    scene.queue_free()
    voice=null
    next_director=null
    await process_frame
    AUDIO._stream_cache.clear()
    AUDIO._npc_voice_cache.clear()
    check(await RETIREMENT.drain(self),"World unload releases every observed audio playback")
    for file in DirAccess.get_files_at("user://"):
        if file.begins_with("spatial_ambience_world"):DirAccess.remove_absolute("user://"+file)
    for failure in failures:printerr("FAIL: "+failure)
    print("SPATIAL_AMBIENCE_WORLD checks=%d failures=%d" % [checks,failures.size()])
    quit(0 if failures.is_empty() else 1)
