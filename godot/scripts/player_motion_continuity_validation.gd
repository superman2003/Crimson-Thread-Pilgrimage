extends SceneTree
## Real floor/wall physics and the production four-pose sprite. This validates
## registration/state/phase, not the subjective quality of the source artwork.
class ProbePlayer extends "res://scripts/player_controller.gd":
    var samples: Array[Dictionary] = []
    var recording := false
    func _physics_process(delta: float) -> void:
        var before := global_position
        super._physics_process(delta)
        if recording:
            samples.append({"dt": delta, "x": global_position.x, "y": global_position.y,
                "dx": global_position.x - before.x, "vx": velocity.x,
                "grounded": is_on_floor(), "motion": ground_motion_x,
                "motion_speed": ground_motion_speed, "phase": run_cycle_phase,
                "animation": sprite.animation, "frame": sprite.frame,
                "frame_progress": sprite.frame_progress, "flip": sprite.flip_h,
                "facing": facing, "land": land_timer, "attack": attack_timer,
                "heal": heal_timer, "sprite_position": sprite.position,
                "sprite_offset": sprite.offset, "sprite_scale": sprite.scale,
                "camera_position": $Camera2D.global_position})
    func _play_sfx(_key: String, _volume: float = -6.0, _pitch: float = 1.0,
            _voice_key: String = "", _priority: int = 1) -> void:
        pass

var checks := 0
var failures: Array[String] = []
var player: ProbePlayer
var fixture: Node2D
const ACTIONS := ["move_left", "move_right", "jump", "attack", "dash", "heal", "aim_up", "aim_down"]

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)

func _frames(count: int) -> void:
    for index in range(count):
        await physics_frame
        await process_frame

func _release() -> void:
    for action in ACTIONS:
        Input.action_release(action)

func _reset(position_value: Vector2 = Vector2(300, 300)) -> void:
    _release()
    player.recording = false
    player.ui_input_locked = false
    player.restore_at_save_point()
    player.respawn_at(position_value)
    await _frames(12)
    player.samples.clear()

func _capture() -> void:
    player.samples.clear()
    player.recording = true

func _body(center: Vector2, size: Vector2) -> void:
    var body := StaticBody2D.new()
    var collision := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = size
    collision.shape = rectangle
    body.position = center
    body.add_child(collision)
    fixture.add_child(body)

func _sole_center(image: Image, left: int, right: int) -> float:
    var sum := 0.0
    var count := 0
    for y in range(276, 282):
        for x in range(left, right):
            if roundi(image.get_pixel(x, y).a * 255.0) > 128:
                sum += x
                count += 1
    return sum / maxi(count, 1)

func _check_idle_registration() -> void:
    var sprite := player.sprite
    var frames := sprite.sprite_frames
    _check(frames.get_frame_count(&"idle") == 4, "Idle retains all four authored breathing/cape poses")
    var centers: Array[float] = []
    for frame in range(4):
        var image := frames.get_frame_texture(&"idle", frame).get_image()
        var center := (_sole_center(image, 150, 185) + _sole_center(image, 185, 220)) * 0.5
        centers.append(center)
        print("IDLE_SOLE_CENTER pose=%d source_x=%.6f correction_x=%.6f" % [frame, center, player.IDLE_FOOT_CENTER_X[0] - player.IDLE_FOOT_CENTER_X[frame]])
        _check(absf(center - player.IDLE_FOOT_CENTER_X[frame]) < 0.001,
            "Idle source foot registration matches actual pixels, pose %d" % frame)
    player.set_physics_process(false)
    for flip in [false, true]:
        sprite.flip_h = flip
        for frame in range(4):
            player._pose_progress(&"idle", float(frame) / 4.0)
            var registered_x: float = (centers[frame] - 192.0) * (-1.0 if flip else 1.0) + sprite.offset.x
            var reference_x: float = (centers[0] - 192.0) * (-1.0 if flip else 1.0)
            _check(absf(registered_x - reference_x) < 0.001,
                "Both-facing idle foot midpoint stays planted, pose %d facing %s" % [frame, str(flip)])
        player._play(&"attack_1")
        _check(sprite.offset == Vector2.ZERO, "Attack does not inherit idle registration offset")
    player.set_physics_process(true)

func _check_travel_samples(label: String, initial_phase: float) -> void:
    var expected := initial_phase
    for sample in player.samples:
        if not sample.grounded:
            continue
        var distance := absf(float(sample.dx))
        if distance / float(sample.dt) > player.GROUND_MOTION_EPSILON:
            expected = fposmod(expected + distance / player.RUN_CYCLE_DISTANCE, 1.0)
        var phase_error := absf(float(sample.phase) - expected)
        _check(minf(phase_error, 1.0 - phase_error) < 0.0001, label + ": pose phase follows measured collision-resolved travel")
        if float(sample.motion_speed) > player.GROUND_MOTION_EPSILON and float(sample.attack) <= 0.0 and float(sample.heal) <= 0.0:
            _check(sample.animation == &"run", label + ": actual motion retains run despite input/landing transitions")
            _check(bool(sample.flip) == (float(sample.dx) < 0.0), label + ": visible facing follows actual ground travel")
            var pose_phase := (float(sample.frame) + float(sample.frame_progress)) / 4.0
            _check(absf(pose_phase - float(sample.phase)) < 0.0001, label + ": rendered pose uses the distance phase")

func _run() -> void:
    fixture = Node2D.new()
    root.add_child(fixture)
    _body(Vector2(1000, 310), Vector2(5000, 20))
    _body(Vector2(950, 200), Vector2(20, 200))
    var instance := (load("res://scenes/Player.tscn") as PackedScene).instantiate()
    instance.set_script(ProbePlayer)
    player = instance
    fixture.add_child(player)
    player.feel = null
    await _reset()
    _check(player.is_on_floor(), "Fixture has real floor contact")
    _check_idle_registration()

    await _reset()
    var position_before := player.global_position
    var sprite_before := player.sprite.position
    var scale_before := player.sprite.scale
    var camera_before: Vector2 = player.get_node("Camera2D").global_position
    _capture()
    await _frames(120)
    var seen_frames: Dictionary = {}
    for sample in player.samples:
        seen_frames[sample.frame] = true
        _check(Vector2(sample.x, sample.y).distance_to(position_before) < 0.001 and absf(sample.vx) < 0.001,
            "Zero-input idle body has no world-space drift")
        _check(sample.animation == &"idle" and sample.phase == 0.0, "Zero-input idle does not advance run phase")
        _check(sample.sprite_position == sprite_before and sample.sprite_scale == scale_before,
            "Idle registration does not move/scale the sprite node")
        _check(sample.camera_position == camera_before, "Stationary idle does not move the camera target")
    _check(seen_frames.size() == 4, "Continuous idle still displays four breathing poses")

    await _reset()
    var initial_phase := player.run_cycle_phase
    _capture()
    Input.action_press("move_right")
    await _frames(30)
    _check_travel_samples("Idle to acceleration and cruise", initial_phase)
    _check(absf(player.velocity.x - player.speed) < 0.001, "Nominal movement speed remains unchanged")
    initial_phase = player.run_cycle_phase
    _capture()
    Input.action_release("move_right")
    await _frames(16)
    _check_travel_samples("Release and deceleration", initial_phase)
    var moving_after_release := false
    for sample in player.samples:
        if float(sample.motion_speed) > 1.0:
            moving_after_release = true
    _check(moving_after_release, "Release test exercises real deceleration travel")
    _check(player.sprite.animation == &"idle" and player.velocity.x == 0.0, "Idle begins once actual movement stops")

    await _reset(Vector2(880, 300))
    Input.action_press("move_right")
    await _frames(40)
    var wall_x := player.global_position.x
    initial_phase = player.run_cycle_phase
    _capture()
    await _frames(20)
    _check(player.is_on_wall(), "Wall test reaches a real solid collision")
    for sample in player.samples:
        _check(absf(float(sample.x) - wall_x) < 0.001 and sample.animation == &"idle",
            "Held movement against wall does not run in place")
        _check(sample.phase == initial_phase, "Blocked movement does not advance gait phase")

    await _reset()
    Input.action_press("move_right")
    await _frames(20)
    initial_phase = player.run_cycle_phase
    _capture()
    Input.action_release("move_right")
    Input.action_press("move_left")
    await _frames(24)
    _check_travel_samples("Direction reversal", initial_phase)
    var braking_right := false
    var moving_left := false
    for sample in player.samples:
        braking_right = braking_right or (float(sample.dx) > 0.01 and int(sample.facing) == -1 and not bool(sample.flip))
        moving_left = moving_left or (float(sample.dx) < -0.01 and bool(sample.flip))
    _check(braking_right and moving_left, "Turn preserves immediate gameplay facing and reverses visible gait with travel")

    await _reset()
    Input.action_press("move_right")
    await _frames(12)
    _capture()
    Input.action_press("jump")
    await _frames(3)
    Input.action_release("jump")
    await _frames(58)
    var airborne := false
    var moving_landing := false
    for sample in player.samples:
        airborne = airborne or not bool(sample.grounded)
        if sample.grounded and float(sample.land) > 0.0 and float(sample.motion_speed) > 1.0:
            moving_landing = true
            _check(sample.animation == &"run", "Moving landing does not slide through a fixed landing pose")
    _check(airborne and moving_landing, "Moving landing scenario includes actual airborne and landing physics")

    await _reset()
    _capture()
    Input.action_press("jump")
    await _frames(3)
    Input.action_release("jump")
    await _frames(58)
    var stationary_landing := false
    for sample in player.samples:
        if sample.grounded and float(sample.land) > 0.0 and float(sample.motion_speed) == 0.0:
            stationary_landing = true
            _check(sample.animation == &"land", "Stationary landing retains authored compression/recovery")
    _check(stationary_landing, "Stationary landing fixture reaches the landing window")

    await _reset()
    Input.action_press("move_right")
    await _frames(12)
    _capture()
    Input.action_press("attack")
    await _frames(2)
    Input.action_release("attack")
    await _frames(30)
    var saw_attack := false
    var resumed_run := false
    for sample in player.samples:
        if float(sample.attack) > 0.0:
            saw_attack = true
            _check(sample.animation == &"attack_1", "Attack phase retains priority over ground gait")
            _check(sample.sprite_offset == Vector2.ZERO, "Attack clears idle foot correction")
        elif saw_attack and sample.animation == &"run":
            resumed_run = true
    _check(saw_attack and resumed_run, "Attack recovery returns directly to travel-driven gait")

    await _reset()
    player.hp = player.max_hp - 1
    player.energy = player.max_energy
    var energy_before := player.energy
    _capture()
    Input.action_press("heal")
    await _frames(2)
    Input.action_release("heal")
    await _frames(65)
    var saw_heal := false
    for sample in player.samples:
        if float(sample.heal) > 0.0:
            saw_heal = true
            _check(sample.animation == &"heal", "Healing phase retains priority over idle/run")
            _check(sample.sprite_offset == Vector2.ZERO, "Heal clears idle foot correction")
    _check(saw_heal and player.hp == player.max_hp, "Heal still completes its existing HP recovery")
    _check(player.energy == energy_before - player.heal_energy_cost, "Visual changes preserve healing energy cost")

    player.ground_motion_x = 4.0
    player.ground_motion_speed = 240.0
    player.run_cycle_phase = 0.7
    player.prepare_region_handoff()
    _check(player.ground_motion_x == 0.0 and player.ground_motion_speed == 0.0 and player.run_cycle_phase == 0.0,
        "Region handoff clears stale locomotion presentation")
    _release()
    fixture.queue_free()
    await _frames(3)
    for failure in failures:
        push_error(failure)
    print("PLAYER_MOTION_CONTINUITY checks=%d failures=%d" % [checks, failures.size()])
    quit(0 if failures.is_empty() else 1)
