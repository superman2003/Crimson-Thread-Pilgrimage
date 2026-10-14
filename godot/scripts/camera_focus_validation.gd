extends SceneTree
## Input + actual camera scroll, arena events and persistent World transitions.
const FOCUS := preload("res://scripts/camera_focus.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const SAVE_PATH := "user://camera_focus_validation.json"
var checks := 0
var failures: Array[String] = []
var capture := false

func _initialize() -> void:
    capture = "--capture" in OS.get_cmdline_user_args()
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label)

func _frames(count: int = 3) -> void:
    for index in range(count):
        await physics_frame
        await process_frame

func _release() -> void:
    for action in ["aim_up", "aim_down", "move_right", "jump", "attack"]:
        Input.action_release(action)

func _run() -> void:
    root.size = Vector2i(1280, 720)
    var stage := Node2D.new()
    root.add_child(stage)
    var floor_body := StaticBody2D.new()
    var shape := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = Vector2(4000, 20)
    shape.shape = rectangle
    floor_body.position = Vector2(2000, 1510)
    floor_body.add_child(shape)
    stage.add_child(floor_body)
    var player = load("res://scenes/Player.tscn").instantiate()
    stage.add_child(player)
    player.feel = null
    player.configure_camera_focus(Rect2(0, 0, 4000, 2400))
    player.respawn_at(Vector2(1000, 1500))
    await _frames(20)
    var camera: Camera2D = player.get_node("Camera2D")
    camera.reset_smoothing()
    camera.force_update_scroll()
    var zoom := camera.zoom
    var start: Vector2 = player.global_position
    var neutral: Vector2 = camera.get_screen_center_position()
    _check(player.is_on_floor(), "Observation fixture has real floor contact")
    Input.action_press("aim_up")
    await _frames(10)
    _check(is_zero_approx(player.camera_focus.look_offset), "Short aim press does not scroll the camera")
    await _frames(40)
    _check(player.camera_focus.look_offset < -100 and camera.position.y < -110, "Sustained grounded up input looks above the player")
    _check(camera.get_screen_center_position().y < neutral.y - 40, "Actual visible camera center moves upwards")
    _check(player.global_position.distance_to(start) < 1 and camera.zoom == zoom, "Observation preserves body position and zoom")
    Input.action_release("aim_up")
    await _frames(45)
    _check(absf(player.camera_focus.look_offset) < 3 and absf(camera.position.y + 55) < 10, "Release smoothly returns to neutral")
    Input.action_press("aim_down")
    await _frames(50)
    _check(player.camera_focus.look_offset > 100 and camera.get_screen_center_position().y > neutral.y + 40, "Grounded down input reveals the lower route")
    Input.action_press("move_right")
    await _frames(2)
    _check(player.camera_focus.look_timer == 0, "Moving cancels observation delay")
    _release()
    await _frames(45)
    Input.action_press("aim_up")
    Input.action_press("jump")
    await _frames(4)
    _check(not player.is_on_floor() and player.camera_focus.look_timer == 0, "Airborne jump does not begin stationary observation")
    _release()
    await _frames(65)
    Input.action_press("aim_up")
    Input.action_press("aim_down")
    await _frames(35)
    _check(player.camera_focus.look_direction == 0, "Opposed aim inputs remain neutral")
    _release()
    await _frames()
    Input.action_press("aim_up")
    await _frames(50)
    player.ui_input_locked = true
    _check(player.camera_focus.look_timer == 0 and player.camera_focus.look_offset == 0, "Menu lock immediately clears observation state")
    await _frames(30)
    player.ui_input_locked = false
    await _frames(10)
    _check(player.camera_focus.look_offset == 0, "Closing menu requires a fresh hold delay")
    Input.action_press("attack")
    await _frames(1)
    _check(player.current_attack_direction == Vector2.UP and player.camera_focus.look_timer == 0, "Upward attack still aims upwards and suppresses observation")
    _release()
    await _frames(40)
    player.set_meta("accessibility", {"camera_lookahead": 0.0})
    Input.action_press("aim_down")
    await _frames(50)
    _check(player.camera_focus.look_offset == 0 and absf(camera.position.y + 55) < 5, "Disabled lookahead also disables camera observation motion")
    _release()
    player.set_meta("accessibility", {})
    await _frames()
    Input.action_press("aim_up")
    await _frames(50)
    player.take_damage(1, player.global_position + Vector2(60, 0))
    _check(player.camera_focus.look_timer == 0 and player.camera_focus.look_offset == 0, "Accepted damage clears held observation")
    _release()
    player.respawn_at(start)
    _check(player.camera_focus.look_offset == 0 and camera.position == Vector2(0, -55), "Relocation restores neutral camera framing")
    player.prepare_region_handoff()
    _check(player.camera_focus.look_direction == 0, "Handoff clears held direction")
    player.set_physics_process(false)

    var focus = FOCUS.new()
    _check(focus.configure(camera, Rect2(0, 0, 4000, 2400)), "Valid camera region is accepted")
    _check(focus.push_lock("shaft", Rect2(500, 300, 700, 1600), 10), "Narrow shaft lock is accepted")
    focus.apply_limits(camera)
    var bounds := focus.effective_bounds(camera, focus.locks.shaft)
    _check(bounds.size.x >= 1024 and bounds.position.x >= 0, "Narrow lock expands safely for a full viewport")
    focus.push_lock("boss", Rect2(900, 800, 1200, 620), 100, true, true)
    focus.apply_limits(camera)
    _check(focus.active_lock == "boss", "Higher priority arena overrides shaft")
    for direction in [-1, 1]:
        for tick in range(60): focus.update(camera, 1.0 / 60, direction, true, 1.0)
        _check(focus.look_offset == 0, "Arena suppresses held observation %d" % direction)
    focus.remove_lock("boss")
    focus.apply_limits(camera)
    _check(focus.active_lock == "shaft", "Leaving arena restores previous lock")
    focus.push_lock("a_tie", Rect2(100, 100, 1800, 800), 10)
    focus.apply_limits(camera)
    _check(focus.active_lock == "a_tie", "Equal priorities have a deterministic tie break")
    _check(not focus.push_lock("bad", Rect2(Vector2.INF, Vector2.ONE)), "Non-finite bounds are rejected")
    _check(not focus.push_lock("bad", Rect2(0, 0, -1, 10)), "Reversed bounds are rejected")
    _check(not focus.push_lock("outside", Rect2(5000, 0, 500, 500)), "Out of region lock is rejected")
    var old_bounds: Rect2 = focus.region_bounds
    _check(not focus.configure(camera, Rect2()) and focus.region_bounds == old_bounds, "Invalid reconfiguration preserves existing region")
    for rate in [30, 60, 120]:
        focus.configure(camera, Rect2(0, 0, 4000, 2400))
        for tick in range(int(0.25 * rate)): focus.update(camera, 1.0 / rate, -1, true, 1.0)
        _check(focus.look_offset == 0, "Hold delay uses simulation seconds at %d Hz" % rate)
        for tick in range(int(0.5 * rate)): focus.update(camera, 1.0 / rate, -1, true, 1.0)
        _check(focus.look_offset < -100, "Observation starts after delay at %d Hz" % rate)
    camera.zoom = Vector2(0.75, 0.75)
    focus.push_lock("tiny", Rect2(1, 1, 5, 5), 100)
    focus.apply_limits(camera)
    _check(camera.limit_left >= 0 and camera.limit_top >= 0 and camera.limit_right > camera.limit_left, "Viewport/zoom change keeps limits inside region and ordered")
    _check(is_equal_approx(focus.effective_bounds(camera, focus.locks.tiny).size.x, float(root.size.x) / camera.zoom.x), "Zoom-out recomputes legal viewport extent")
    focus.configure(camera, Rect2(0, 0, 4000, 2400))
    _check(focus.locks.is_empty() and focus.active_lock.is_empty(), "New region clears event locks")
    stage.queue_free()
    await _frames()
    await _world_integration()
    _release()
    await _frames()
    for failure in failures: push_error(failure)
    print("CAMERA_FOCUS checks=%d failures=%d" % [checks, failures.size()])
    call_deferred("quit", 0 if failures.is_empty() else 1)

func _world_integration() -> void:
    for suffix in ["", ".bak", ".tmp"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + suffix))
    var world = load("res://scenes/World.tscn").instantiate()
    world.world_resume = false
    world.world_save_path = SAVE_PATH
    root.add_child(world)
    current_scene = world
    await _frames(5)
    if capture:
        world.player.feel = null
        world.player.debug_invulnerable = true
        for enemy in get_nodes_in_group("enemy"): enemy.set_physics_process(false)
        await _frames(90)
        var entry_camera: Camera2D = world.player.get_node("Camera2D")
        entry_camera.reset_smoothing()
        entry_camera.force_update_scroll()
        await _frames(3)
        print("CAPTURE_ENTRY neutral body=%s center=%s grounded=%s" % [world.player.global_position, entry_camera.get_screen_center_position(), world.player.is_on_floor()])
        await _capture("entry_neutral")
        Input.action_press("aim_up")
        await _frames(50)
        entry_camera.reset_smoothing()
        entry_camera.force_update_scroll()
        await _frames(3)
        print("CAPTURE_ENTRY up body=%s center=%s target=%s" % [world.player.global_position, entry_camera.get_screen_center_position(), world.player.camera_focus.look_offset])
        await _capture("entry_look_up")
        Input.action_release("aim_up")
        await _frames(45)
    world.set_process(false)
    world.set_physics_process(false)
    var camera: Camera2D = world.player.get_node("Camera2D")
    var camera_id := camera.get_instance_id()
    var focus_id: int = world.player.camera_focus.get_instance_id()
    for id in ROUTES._data().get("chapters", {}).keys():
        var path: String = ROUTES.config_path(String(id))
        var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
        var entry: Array = data.get("player_start", [200, 300])
        world._travel_world(path, Vector2(entry[0], entry[1]))
        _check(String(world.config.id) == String(id), String(id) + " region arrival succeeds")
        world.set_process(false)
        world.set_physics_process(false)
        world.player.set_physics_process(false)
        await _frames(3)
        _check(world.player.camera_focus.get_instance_id() == focus_id and camera.get_instance_id() == camera_id, String(id) + " preserves player-owned focus and camera")
        _check(not world.player.camera_focus.locks.has("boss_arena") and world.player.camera_focus.region_bounds.end.x == world.world_width + 80, String(id) + " has fresh region and no previous event lock")
        for enemy in get_nodes_in_group("enemy"):
            if enemy.get_parent() == world: enemy.set_physics_process(false)
        var boss: Dictionary = world.config.boss
        var point := Vector2(boss.position[0], boss.position[1])
        world.player.global_position = point
        world._set_boss_arena_locked(true)
        _check(world.player.camera_focus.active_lock == "boss_arena", String(id) + " actual seal event locks arena camera")
        camera.reset_smoothing()
        camera.force_update_scroll()
        await _frames(3)
        var center := camera.get_screen_center_position()
        var half := Vector2(root.size) / camera.zoom * 0.5
        _check(point.x - 24 > center.x - half.x and point.x + 24 < center.x + half.x, String(id) + " player fits visible arena width")
        _check(float(boss.arena_min_x) >= center.x - half.x and float(boss.arena_max_x) <= center.x + half.x, String(id) + " both patrol ends remain visible")
        _check(point.y - 220 >= center.y - half.y and point.y + 40 <= center.y + half.y, String(id) + " jump apex and floor remain visible")
        if capture and String(id) in ["demo_ch01_moss_bell_court", "demo_ch06_silent_crown_core"]:
            world._spawn_boss()
            if is_instance_valid(world.boss_actor): world.boss_actor.set_physics_process(false)
            world.player.global_position = Vector2(float(boss.arena_min_x) + 100.0, point.y + 40.0)
            camera.reset_smoothing()
            camera.force_update_scroll()
            await _frames(3)
            await _capture(String(id) + "_arena")
        world._set_boss_arena_locked(false)
        _check(not world.player.camera_focus.locks.has("boss_arena") and world.player.camera_focus.active_lock != "boss_arena", String(id) + " seal release restores exploration limits")
    world.queue_free()
    await _frames(4)
    for suffix in ["", ".bak", ".tmp"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + suffix))

func _capture(label: String) -> void:
    await RenderingServer.frame_post_draw
    DirAccess.make_dir_recursive_absolute("res://../artifacts/camera_focus")
    root.get_texture().get_image().save_png("res://../artifacts/camera_focus/" + label + ".png")
