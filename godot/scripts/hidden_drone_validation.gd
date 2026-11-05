extends SceneTree
## W04/S03: hidden rooms lay the black-tide drone under the region ambience.
## Production AudioDirector state, then the World room tracker on every hidden
## room of the route plan versus its entrance room.
const DIRECTOR := preload("res://scripts/audio_director.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)

func _run() -> void:
    for bus in ["BGM", "SFX", "Ambience", "UI"]:
        DIRECTOR._ensure_bus(bus, "Master")
    var director: Node = DIRECTOR.new()
    director.settings_path = "user://hidden_drone_validation.cfg"
    root.add_child(director)
    director.set_process(false)
    _check(ResourceLoader.exists(DIRECTOR.HIDDEN_DRONE), "the generated drone is a shipped resource")
    director.set_hidden_zone(true)
    var drone: AudioStreamPlayer = director.hidden_drone_player
    _check(drone != null and drone.playing and drone.bus == "Ambience", "entering a hidden room starts the drone on the ambience bus")
    _check(drone != null and drone.stream is AudioStreamOggVorbis and drone.stream.loop, "the drone loops")
    director.hidden_drone_tween.custom_step(DIRECTOR.HIDDEN_DRONE_FADE_IN_S + 0.1)
    _check(drone != null and is_equal_approx(drone.volume_db, DIRECTOR.HIDDEN_DRONE_DB), "the drone fades in to its quiet level")
    var stream_before: AudioStream = drone.stream if drone != null else null
    var position_before: float = drone.get_playback_position() if drone != null else 0.0
    director.set_hidden_zone(true)
    _check(drone != null and drone.stream == stream_before and drone.playing, "staying hidden never restarts the drone (%.2f)" % position_before)
    director.set_hidden_zone(false)
    director.hidden_drone_tween.custom_step(DIRECTOR.HIDDEN_DRONE_FADE_OUT_S + 0.1)
    _check(drone != null and not drone.playing, "leaving fades the drone out and stops it")
    director.set_hidden_zone(true)
    director.begin_chapter_transition()
    if director.hidden_drone_tween != null and director.hidden_drone_tween.is_valid():
        director.hidden_drone_tween.custom_step(DIRECTOR.HIDDEN_DRONE_FADE_OUT_S + 0.1)
    _check(drone != null and not drone.playing and not director.hidden_zone, "a region transition never carries the drone along")
    director.queue_free()

    # The World room tracker recognises exactly the planned hidden rooms.
    var scene: Node = load("res://scenes/World.tscn").instantiate()
    scene.world_resume = false
    scene.world_save_path = "user://hidden_drone_validation.json"
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    var plan: Array = ROUTES._data().get("hidden_route_plan", [])
    _check(plan.size() >= 8, "route plan lists the hidden rooms (%d)" % plan.size())
    var region := String(scene.config.get("id", ""))
    var local := 0
    for entry in plan:
        if String(entry.region_id) != region:
            continue
        local += 1
        _check(scene._is_hidden_room(String(entry.hidden_room_id)), "%s counts as hidden" % entry.hidden_room_id)
        _check(not scene._is_hidden_room(String(entry.entrance_room_id)), "%s entrance is ordinary" % entry.entrance_room_id)
    _check(local >= 1, "the starting region has a hidden room to check")
    _check(not scene._is_hidden_room(""), "no room id is never hidden")
    scene.queue_free()
    for _frame in 3:
        await process_frame
    for name in DirAccess.get_files_at("user://"):
        if name.begins_with("hidden_drone_validation"):
            DirAccess.remove_absolute("user://" + name)
    if failures.is_empty():
        print("HIDDEN_DRONE_PASS checks=%d" % checks)
    else:
        for label in failures:
            push_error(label)
        print("HIDDEN_DRONE_FAIL failures=%d checks=%d" % [failures.size(), checks])
    call_deferred("quit", 0 if failures.is_empty() else 1)
