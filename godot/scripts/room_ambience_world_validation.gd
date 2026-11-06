extends SceneTree
## Explicit room placement and production World callbacks; not a natural route.
const MIX := preload("res://scripts/room_ambience_mix.gd")
const AUDIO := preload("res://scripts/audio_director.gd")
const RETIRE := preload("res://scripts/audio_retirement.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const SAVE := "user://room_ambience_world_validation.json"
var world: Node
var checks := 0
var failures := 0
var cancel_after_bind := false
var cancelled_bus := ""
var cancelled_ref: WeakRef
var visits: Array = []

class ObservedWorld:
    extends "res://scripts/main_level.gd"
    signal bound_audio
    func _should_autoplay_audio() -> bool: return true
    func _bind_region_audio() -> void:
        super._bind_region_audio()
        bound_audio.emit()

func _initialize() -> void:
    call_deferred("run")

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)

func point_for(config: Dictionary, room_id: String) -> Vector2:
    for room in config.map_rooms:
        if String(room.id) != room_id: continue
        var value: Array = room.get("visit_rects",[room.layout_rect])[0]
        return Vector2(float(value[0])+float(value[2])*0.5,float(value[1])+float(value[3])*0.5)
    return Vector2.INF

func room_visit(id: String, profile: String) -> void:
    var mix: Node = world.audio_director.room_ambience_mix
    mix.process_mode = Node.PROCESS_MODE_ALWAYS
    world.player.global_position = point_for(world.config,id)
    world._update_room_visit()
    check(world.current_room_id == id,"actual spatial room resolver selects " + id)
    check(mix.current_profile == profile,"production room-visit callback applies " + profile)
    var before_save := FileAccess.get_file_as_bytes(SAVE)
    var before_inventory: Dictionary = world.inventory_counts.duplicate(true)
    var before_money: int = world.currency_count
    var before_flags: Dictionary = world.story_flags.duplicate(true)
    var bed: AudioStreamPlayer = world.audio_director.ambience_bed_player
    var playback_id: int = bed.get_stream_playback().get_instance_id()
    var parent_index := AudioServer.get_bus_index("Ambience")
    var user_gain := AudioServer.get_bus_volume_db(parent_index)
    await create_timer(0.7).timeout
    var index: int = mix.owned_index()
    if profile == "sheltered":
        check(index >= 0 and is_equal_approx(AudioServer.get_bus_volume_db(index),-6.0) and is_equal_approx(mix.effect.cutoff_hz,3200.0),"World reaches sheltered bed gain and lowpass through its real Tween")
    else:
        check(index < 0 or is_zero_approx(AudioServer.get_bus_volume_db(index)),"World exposed room keeps the original bed gain")
    check(bed.playing and bed.get_stream_playback().get_instance_id() == playback_id,"actual World keeps the same uninterrupted bed playback")
    check(AudioServer.get_bus_volume_db(parent_index) == user_gain,"World room change preserves the selected user ambience volume")
    check(world.inventory_counts == before_inventory and world.currency_count == before_money and world.story_flags == before_flags,"audio treatment cannot grant or consume progress after normal room entry")
    check(FileAccess.get_file_as_bytes(SAVE) == before_save,"treatment fade adds no journey write after the ordinary room-visit save")
    visits.append({"region":String(world.config.id),"room":id,"profile":profile,"same_playback":true})

func observe_binding() -> void:
    if not cancel_after_bind or world.world_loader.phase != "committing": return
    cancel_after_bind = false
    # The request's actual destination spawn is inside a configured shelter.
    # Query the production resolver without admitting room discovery or saving.
    var room: Dictionary = world._room_for_position(world.player.global_position)
    world.current_room_id = String(room.get("id",""))
    var mix: Node = world.audio_director.room_ambience_mix
    check(mix.update_room() and mix.current_profile == "sheltered","partially built destination selects shelter from its actual arrival position")
    mix.apply_profile("sheltered",0)
    cancelled_bus = mix.bus_name
    cancelled_ref = weakref(mix)
    check(mix.owned_index() >= 0,"cancel boundary observes a real destination-owned treatment bus")
    world.world_loader.cancel_transition()

func run() -> void:
    root.process_mode = Node.PROCESS_MODE_DISABLED
    world = ObservedWorld.new()
    world.world_mode = true
    world.world_resume = false
    world.world_startup_options_enabled = false
    world.world_save_path = SAVE
    world.bound_audio.connect(observe_binding)
    root.add_child(world)
    var deadline := Time.get_ticks_msec()+15000
    while not world.initial_region_ready and Time.get_ticks_msec() < deadline:
        await process_frame
    check(world.initial_region_ready,"actual World startup completes before room treatments")
    if not world.initial_region_ready:
        world.free()
        world = null
        quit(1)
        return
    for region in MIX.ROOMS:
        if String(world.config.id) != String(region):
            var previous: Node = world.audio_director.room_ambience_mix
            var previous_ref: WeakRef = weakref(previous)
            var previous_bus: String = previous.bus_name
            var path := ROUTES.config_path(String(region))
            var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
            var start := Vector2(float(config.player_start[0]),float(config.player_start[1]))
            var arrived: bool = await world.world_loader.replace_region_async(world,path,start)
            check(arrived and String(world.config.id) == region,"normal async region publication reaches " + String(region))
            check(previous_ref.get_ref() == null and AudioServer.get_bus_index(previous_bus) < 0,"publication removes the outgoing mixer and its private bus")
        world.audio_director.set_user_volume("ambience",52)
        var profiles: Dictionary = MIX.ROOMS[region]
        await room_visit(String(profiles.open[0]),"open")
        await room_visit(String(profiles.sheltered[0]),"sheltered")
    var source_id: String = world.config.id
    var source_position: Vector2 = world.player.global_position
    var source_inventory: Dictionary = world.inventory_counts.duplicate(true)
    var source_flags: Dictionary = world.story_flags.duplicate(true)
    var source_money: int = world.currency_count
    var target_path := ROUTES.config_path("demo_ch02_rain_foundry_canal")
    var target: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(target_path))
    cancel_after_bind = true
    var travelled: bool = await world.world_loader.replace_region_async(world,target_path,point_for(target,"tide_listening_cell"))
    check(not travelled and world.world_loader.last_transition.get("rolled_back",false),"audio-bound cancellation restores the source region")
    check(String(world.config.id) == source_id and world.player.global_position == source_position,"rollback keeps the settled source and player position")
    check(world.inventory_counts == source_inventory and world.story_flags == source_flags and world.currency_count == source_money,"rollback keeps exact inventory, story and money")
    check(cancelled_ref != null and cancelled_ref.get_ref() == null and AudioServer.get_bus_index(cancelled_bus) < 0,"cancelled destination releases its mixer and private bus")
    var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
    check(String(saved.get("current_region","")) == source_id,"cancelled room audio never publishes the destination save")
    RETIRE.retire_tree(world)
    world.free()
    world = null
    await process_frame
    AUDIO._stream_cache.clear()
    AUDIO._npc_voice_cache.clear()
    check(await RETIRE.drain(self),"final actual World playback retires before exit")
    var remaining := 0
    for index in AudioServer.bus_count:
        if String(AudioServer.get_bus_name(index)).begins_with(MIX.BUS_PREFIX): remaining += 1
    check(remaining == 0,"no room-treatment bus remains after final World exit")
    for suffix in ["",".bak",".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE+suffix))
    var output := ProjectSettings.globalize_path("res://../artifacts/room_ambience_v23")
    DirAccess.make_dir_recursive_absolute(output)
    var file := FileAccess.open(output.path_join("world-contract.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify({"checks":checks,"failures":failures,"visits":visits,"cancelled_bus":cancelled_bus},"  "))
    file.close()
    print("ROOM_AMBIENCE_WORLD checks=%d failures=%d regions=6" % [checks,failures])
    quit(0 if failures == 0 else 1)
