extends SceneTree
## Production framing rules, plus opt-in real Player input/scroll integration.
## --player requires the two Player follow/reset calls; no campaign-clear claim.
const FOCUS := preload("res://scripts/camera_focus.gd")
const ROOMS := preload("res://scripts/room_camera.gd")
const DOORWAYS := preload("res://scripts/room_camera_doorway_validation.gd")
var checks := 0
var failures: Array[String] = []
var metrics: Dictionary = {}

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)

func _frames(count: int = 1) -> void:
    for tick in count:
        await physics_frame
        await process_frame

func _run() -> void:
    root.size = Vector2i(1280, 720)
    var body := Node2D.new()
    var camera := Camera2D.new()
    camera.zoom = Vector2(1.25, 1.25)
    camera.position_smoothing_enabled = true
    camera.position_smoothing_speed = 6.0
    camera.position = Vector2(0, -55)
    body.add_child(camera)
    root.add_child(body)
    var focus := FOCUS.new()
    focus.configure(camera, Rect2(0, 0, 8000, 6000))
    _follow_rules(focus, camera, body)
    _room_and_event_rules(focus, camera, body)
    DOORWAYS.new().run(_check)
    body.queue_free()
    await _frames()
    if "--player" in OS.get_cmdline_user_args():
        await _player_integration()
        await _vertical_interruption_integration()
    for label in failures:
        push_error(label)
    print("ROOM_CAMERA_STABILITY checks=%d failures=%d player_integration=%s metrics=%s" % [checks, failures.size(), "--player" in OS.get_cmdline_user_args(), JSON.stringify(metrics)])
    quit(0 if failures.is_empty() else 1)

func _step(focus: RefCounted, camera: Camera2D, body: Node2D, point: Vector2, motion: Vector2, grounded: bool, delta: float, strength: float = 1.0, observation: float = 0.0) -> float:
    body.position = point
    camera.position = focus.follow_position(camera, point, motion, grounded, delta, strength, observation)
    return camera.global_position.y

func _follow_rules(focus: RefCounted, camera: Camera2D, body: Node2D) -> void:
    for rate in [30, 60, 120]:
        var delta := 1.0 / float(rate)
        for jump_speed in [340.0, 710.0]:
            focus.reset_follow(Vector2(2000, 1500))
            var drift := 0.0
            var height := 0.0
            for tick in range(1, ceili(jump_speed * 2.0 / 1850.0 * rate)):
                var time := tick * delta
                var y: float = 1500.0 - jump_speed * time + 925.0 * time * time
                var center := _step(focus, camera, body, Vector2(2000, y), Vector2(0, -jump_speed + 1850.0 * time), false, delta)
                drift = maxf(drift, absf(center - 1445.0))
                height = maxf(height, 1500.0 - y)
            _step(focus, camera, body, Vector2(2000, 1500), Vector2.ZERO, true, delta)
            metrics["jump_target_y_drift_%dHz_speed%d" % [rate, int(jump_speed)]] = drift
            _check(drift < 0.001 and absf(camera.global_position.y - 1445) < 0.001, "Short/full jump keeps world Y at %d Hz, speed %.0f" % [rate, jump_speed])
            _check(height > 25 if jump_speed < 500 else height > 130, "Jump fixture includes a real vertical excursion at %d Hz" % rate)
        focus.reset_follow(Vector2(2000, 1500))
        var previous_x := camera.position.x
        var actual_y := _step(focus, camera, body, Vector2(2050, 1500), Vector2(350, 0), true, delta)
        var expected_x := lerpf(previous_x, 63.0, 1.0 - exp(-delta * 5.0))
        _check(absf(camera.position.x - expected_x) < 0.001 and absf(actual_y - 1445) < 0.001, "Horizontal response stays unchanged at %d Hz" % rate)
    focus.reset_follow(Vector2(2000, 1500))
    for y in [1500.5, 1499.5, 1501.0, 1500.0]:
        _step(focus, camera, body, Vector2(2000, y), Vector2.ZERO, true, 1.0 / 60)
    _check(absf(camera.global_position.y - 1445) < 0.001, "Floor-contact corrections do not move the center")
    _step(focus, camera, body, Vector2(2000, 1380), Vector2.ZERO, true, 1.0 / 60)
    _check(absf(camera.global_position.y - 1325) < 0.001, "A new platform layer rebases neutral framing")
    for direction in [-1, 1]:
        focus.reset_follow(Vector2(2000, 2500))
        var last_y: float = focus.follow_center_y
        var longest_hold := 0
        var hold := 0
        for tick in range(1, 121):
            var point := Vector2(2000, 2500 + direction * tick * 10)
            _step(focus, camera, body, point, Vector2(0, direction * 600), false, 1.0 / 60, 0.0)
            if tick > 30:
                hold = hold + 1 if absf(focus.follow_center_y - last_y) < 0.001 else 0
                longest_hold = maxi(longest_hold, hold)
            last_y = focus.follow_center_y
        _check(direction * (focus.follow_center_y - 2445) > 850, "Long vertical travel follows with optional lookahead off, direction %d" % direction)
        _check(longest_hold == 0, "Sustained vertical travel does not staircase between deadzone crossings, direction %d" % direction)
        _step(focus, camera, body, Vector2(2000, 2500 + direction * 1200), Vector2.ZERO, true, 1.0 / 60)
        _check(absf(camera.position.y + 55) < 0.001, "Landing after travel restores neutral target, direction %d" % direction)
    focus.reset_follow(Vector2(2000, 1500))
    for tick in 60:
        var observation: float = focus.update(camera, 1.0 / 60, -1, true, 1.0)
        _step(focus, camera, body, Vector2(2000, 1500), Vector2.ZERO, true, 1.0 / 60, 1.0, observation)
    _check(focus.look_offset == -150 and camera.position.y < -190, "Delayed manual look retains its original response")
    focus.clear_look()
    for tick in 60:
        var observation: float = focus.update(camera, 1.0 / 60, 0, false, 1.0)
        _step(focus, camera, body, Vector2(2000, 1500), Vector2.ZERO, true, 1.0 / 60, 1.0, observation)
    _check(absf(camera.position.y + 55) < 1.1, "Clearing look returns to the same stable baseline")
    camera.offset = Vector2(3, -2)
    camera.rotation = 0.01
    _step(focus, camera, body, Vector2(2000, 1500), Vector2.ZERO, true, 1.0 / 60)
    _check(camera.offset == Vector2(3, -2) and is_equal_approx(camera.rotation, 0.01) and camera.zoom == Vector2(1.25, 1.25), "Follow does not own FeelKit offset, rotation or zoom")
    camera.offset = Vector2.ZERO
    camera.rotation = 0.0
    focus.reset_follow(Vector2(5000, 800))
    _step(focus, camera, body, Vector2(5000, 800), Vector2.ZERO, true, 1.0 / 60)
    _check(camera.position.y == -55 and focus.follow_observation == 0, "Explicit arrival discards previous baseline and observation")
    focus.configure(camera, Rect2(0, 0, 8000, 6000))
    _check(not focus.follow_ready, "Region configuration invalidates old follow state")

func _room_and_event_rules(focus: RefCounted, camera: Camera2D, body: Node2D) -> void:
    var rooms := ROOMS.new()
    rooms.configure([
        {"id": "hall", "layout_rect": [0, 1000, 2500, 1200], "camera_bounds": [0, 800, 2600, 1500]},
        {"id": "side", "layout_rect": [2500, 1000, 1800, 1200], "camera_bounds": [2400, 900, 1900, 1400]}
    ], focus)
    focus.reset_follow(Vector2(2400, 1500))
    rooms.update(focus, Vector2(2400, 1500))
    var old_bounds: Rect2 = rooms.display_bounds
    rooms.update(focus, Vector2(2508, 1500), 1.0 / 60)
    _check(rooms.current.id == "hall", "Door lip retains previous room")
    rooms.update(focus, Vector2(2550, 1500), 1.0 / 60)
    _check(rooms.current.id == "side" and rooms.display_bounds.position.x > old_bounds.position.x and rooms.display_bounds.position.x < 2400, "Room switch retains eased limits")
    _step(focus, camera, body, Vector2(2550, 1500), Vector2(350, 0), true, 1.0 / 60)
    _check(focus.follow_center_y == 1445, "Same-height doorway does not reset the vertical baseline")
    for tick in 90:
        rooms.update(focus, Vector2(3000, 1500), 1.0 / 60)
    focus.apply_limits(camera)
    _check(rooms.display_bounds.position.distance_to(Vector2(2400, 900)) < 0.1, "Doorway limits converge to the new room")
    focus.push_lock("boss_arena", Rect2(2700, 1000, 1200, 700), 100, true, true)
    focus.apply_limits(camera)
    _check(focus.active_lock == "boss_arena", "Boss priority remains above room framing")
    for direction in [-1, 1]:
        for tick in 60:
            var observation: float = focus.update(camera, 1.0 / 60, direction, true, 1.0)
            _step(focus, camera, body, Vector2(3000, 1500), Vector2.ZERO, true, 1.0 / 60, 1.0, observation)
        _check(focus.look_offset == 0, "Boss lock still suppresses manual look %d" % direction)
    for point in [Vector2(100, 100), Vector2(7000, 5500)]:
        _step(focus, camera, body, point, Vector2.ZERO, true, 1.0 / 60)
        camera.reset_smoothing()
        camera.force_update_scroll()
        var center := camera.get_screen_center_position()
        var half := Vector2(root.size) / camera.zoom * 0.5
        _check(center.x - half.x >= camera.limit_left - 1 and center.x + half.x <= camera.limit_right + 1 and center.y - half.y >= camera.limit_top - 1 and center.y + half.y <= camera.limit_bottom + 1, "Actual scroll remains inside authoritative Boss bounds at %s" % point)
    focus.remove_lock("boss_arena")
    focus.apply_limits(camera)
    _check(focus.active_lock == ROOMS.LOCK_ID, "Boss release restores exploration framing")
    rooms.configure([], focus)

func _floor(stage: Node2D, y: float, one_way: bool = false, width: float = 8000.0, x: float = 4000.0) -> StaticBody2D:
    var body := StaticBody2D.new()
    var collision := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = Vector2(width, 20)
    collision.shape = shape
    collision.one_way_collision = one_way
    body.position = Vector2(x, y + 10)
    body.add_child(collision)
    stage.add_child(body)
    return body

func _player_integration() -> void:
    var stage := Node2D.new()
    root.add_child(stage)
    var floor_body := _floor(stage, 1500)
    var player = load("res://scenes/Player.tscn").instantiate()
    stage.add_child(player)
    player.feel = null
    player.configure_camera_focus(Rect2(0, 0, 8000, 6000))
    player.respawn_at(Vector2(2000, 1500))
    await _frames(40)
    var camera: Camera2D = player.get_node("Camera2D")
    _check(player.is_on_floor() and player.camera_focus.follow_ready, "Real Player is grounded and calls production follow API")
    var neutral := camera.get_screen_center_position()
    var min_y: float = player.global_position.y
    var drift := 0.0
    Input.action_press("jump")
    for tick in 65:
        await _frames()
        min_y = minf(min_y, player.global_position.y)
        drift = maxf(drift, absf(camera.get_screen_center_position().y - neutral.y))
    Input.action_release("jump")
    metrics["full_jump_body_height"] = 1500.0 - min_y
    metrics["full_jump_screen_y_drift"] = drift
    _check(1500.0 - min_y > 120 and player.is_on_floor(), "Real held-jump input leaves and returns to the floor")
    _check(drift < 1.5, "Real ordinary jump keeps visible Y stable")
    var start_x := camera.get_screen_center_position().x
    Input.action_press("move_right")
    await _frames(80)
    Input.action_release("move_right")
    _check(camera.get_screen_center_position().x > start_x + 200 and absf(camera.get_screen_center_position().y - neutral.y) < 1.5, "Actual horizontal movement follows X without bobbing Y")
    await _frames(40)
    player.respawn_at(Vector2(2000, 1500))
    await _frames(5)
    var platform := _floor(stage, 1380, true, 220, 2000)
    await _frames(2)
    Input.action_press("jump")
    await _frames(65)
    Input.action_release("jump")
    await _frames(40)
    _check(player.is_on_floor() and absf(player.global_position.y - 1380) < 2 and absf(camera.get_screen_center_position().y - 1325) < 3, "Landing on an actual higher platform smoothly adopts its new level")
    platform.queue_free()
    await _frames(2)
    player.respawn_at(Vector2(2000, 1500))
    player.double_jump_unlocked = true
    await _frames(5)
    Input.action_press("jump")
    await _frames(20)
    Input.action_release("jump")
    await _frames(1)
    Input.action_press("jump")
    var min_center := camera.get_screen_center_position().y
    var head_margin := INF
    for tick in 65:
        await _frames()
        min_center = minf(min_center, camera.get_screen_center_position().y)
        head_margin = minf(head_margin, player.global_position.y - 84 - camera.get_screen_center_position().y + 288)
    Input.action_release("jump")
    metrics["double_jump_camera_rise"] = 1445.0 - min_center
    metrics["double_jump_min_head_margin"] = head_margin
    _check(min_center < 1415 and head_margin > 24, "Vertical air traversal releases the baseline while retaining headroom")
    floor_body.queue_free()
    _floor(stage, 4500)
    player.respawn_at(Vector2(2000, 800))
    player.set_meta("accessibility", {"camera_lookahead": 0.0})
    var feet_margin := INF
    head_margin = INF
    var max_speed := 0.0
    for tick in 160:
        await _frames()
        var center := camera.get_screen_center_position()
        feet_margin = minf(feet_margin, center.y + 288 - player.global_position.y)
        head_margin = minf(head_margin, player.global_position.y - 84 - center.y + 288)
        max_speed = maxf(max_speed, player.velocity.y)
    metrics["shaft_fall_min_feet_margin"] = feet_margin
    metrics["shaft_fall_min_head_margin"] = head_margin
    metrics["shaft_fall_peak_speed"] = max_speed
    _check(max_speed > 2000 and player.is_on_floor(), "Real gravity fixture covers a long fast shaft fall and landing")
    _check(feet_margin > 70 and head_margin > 24, "Fast fall retains landing visibility even with optional lookahead off")
    player.set_meta("accessibility", {})
    Input.action_press("aim_up")
    await _frames(55)
    _check(player.camera_focus.look_offset == -150, "Actual sustained look remains available after vertical travel")
    player.take_damage(1, player.global_position + Vector2(60, 0))
    _check(player.camera_focus.look_timer == 0 and player.camera_focus.look_offset == 0, "Damage still clears held observation")
    Input.action_release("aim_up")
    player.respawn_at(Vector2(5000, 4500))
    _check(camera.position == Vector2(0, -55) and player.camera_focus.follow_center_y == 4445 and player.camera_focus.follow_observation == 0, "Actual respawn resets the stored baseline and observation")
    for action in ["jump", "move_right", "aim_up"]:
        Input.action_release(action)
    stage.queue_free()
    await _frames(3)


func _vertical_interruption_integration() -> void:
    # Real collision/input transitions must retract prediction after an abrupt
    # speed change. Neither fixture assigns velocity or fakes a wall contact.
    var stage := Node2D.new()
    root.add_child(stage)
    _floor(stage, 10000)
    var wall := StaticBody2D.new()
    var collision := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = Vector2(20, 10000)
    collision.shape = shape
    wall.position = Vector2(2045, 5500)
    wall.add_child(collision)
    stage.add_child(wall)
    var player = load("res://scenes/Player.tscn").instantiate()
    stage.add_child(player)
    player.feel = null
    player.wall_grip_unlocked = true
    player.configure_camera_focus(Rect2(0, 0, 8000, 12000))
    player.set_meta("accessibility", {"camera_lookahead": 0.0})
    player.respawn_at(Vector2(2000, 800))
    var camera: Camera2D = player.get_node("Camera2D")
    var peak_speed := 0.0
    for tick in 120:
        await _frames()
        peak_speed = maxf(peak_speed, player.velocity.y)
    Input.action_press("move_right")
    var slide_frames := 0
    var head_margin := INF
    var feet_margin := INF
    for tick in 60:
        await _frames()
        peak_speed = maxf(peak_speed, player.velocity.y)
        if player.wall_sliding and player.is_on_wall():
            slide_frames += 1
        var center := camera.get_screen_center_position()
        head_margin = minf(head_margin, player.global_position.y - 84 - center.y + 288)
        feet_margin = minf(feet_margin, center.y + 288 - player.global_position.y)
    Input.action_release("move_right")
    metrics["wall_slide_entry_peak_speed"] = peak_speed
    metrics["wall_slide_actual_frames"] = slide_frames
    metrics["wall_slide_min_head_margin"] = head_margin
    metrics["wall_slide_min_feet_margin"] = feet_margin
    _check(peak_speed > 3500 and slide_frames >= 30 and absf(player.velocity.y - player.wall_slide_max_speed) < 0.1, "Real long fall enters sustained wall slide through collision and held input")
    _check(head_margin > 24 and feet_margin > 70, "Fast fall to wall slide keeps head and feet inside the visible screen")
    wall.queue_free()
    await _frames(2)

    # Air dash is the production zero-vertical-speed interruption, covering the
    # same stale-prediction boundary as a sudden collision stop.
    player.respawn_at(Vector2(5000, 800))
    peak_speed = 0.0
    for tick in 120:
        await _frames()
        peak_speed = maxf(peak_speed, player.velocity.y)
    Input.action_press("dash")
    var stopped_frames := 0
    head_margin = INF
    feet_margin = INF
    for tick in 30:
        await _frames()
        if player.dash_timer > 0.0 and absf(player.velocity.y) < 0.1:
            stopped_frames += 1
        var center := camera.get_screen_center_position()
        head_margin = minf(head_margin, player.global_position.y - 84 - center.y + 288)
        feet_margin = minf(feet_margin, center.y + 288 - player.global_position.y)
    Input.action_release("dash")
    metrics["air_stop_entry_peak_speed"] = peak_speed
    metrics["air_stop_actual_frames"] = stopped_frames
    metrics["air_stop_min_head_margin"] = head_margin
    metrics["air_stop_min_feet_margin"] = feet_margin
    _check(peak_speed > 3500 and stopped_frames >= 6 and not player.is_on_floor(), "Real airborne dash interrupts a long fall with zero vertical velocity")
    _check(head_margin > 24 and feet_margin > 70, "Abrupt airborne stop retracts prediction without losing the visible body")
    stage.queue_free()
    await _frames(3)
