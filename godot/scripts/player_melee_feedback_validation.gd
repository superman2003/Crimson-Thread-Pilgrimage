extends SceneTree
## Production Player acceptance + real helper transforms + simulated hardware.
## This validates routing/timing contracts; it cannot assess physical pad feel.
const MELEE := preload("res://scripts/player_melee_feedback.gd")

class RecordingFeel extends "res://scripts/feel_kit.gd":
    var devices: Array[int] = [3, 7]
    var starts: Array[Dictionary] = []
    var stops: Array[int] = []
    var stop_requests: Array[float] = []
    var clock_usec := 1000000
    func _joy_devices() -> Array[int]:
        return devices
    func _send_joy_vibration(device: int, weak: float, strong: float, duration: float) -> void:
        starts.append({"device":device, "weak":weak, "strong":strong, "duration":duration})
    func _stop_joy_vibration(device: int) -> void:
        stops.append(device)
    func _now_usec() -> int:
        return clock_usec
    func hitstop(ms: float, _time_scale: float = 0.05) -> void:
        stop_requests.append(ms)

class ProbePlayer extends "res://scripts/player_controller.gd":
    func _play_sfx(_key: String, _volume: float = -5.0, _pitch: float = 1.0, _voice_key: String = "", _priority: int = 1) -> void:
        pass

class HitTarget extends Node2D:
    var hp := 20
    var accepts := true
    var hit_calls := 0
    func take_hit(amount: int, _hit_direction: int) -> void:
        hit_calls += 1
        if accepts:
            hp -= amount
    func get_hurtbox_rect() -> Rect2:
        return Rect2(global_position - Vector2(20, 30), Vector2(40, 60))

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run_device_selection" if OS.get_cmdline_user_args().has("--device-selection-only") else "_run")

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)
        push_error(label)

func _joy_press(feel: RecordingFeel, device: int = 7) -> void:
    var event := InputEventJoypadButton.new()
    event.device = device
    event.button_index = JOY_BUTTON_X
    event.pressed = true
    feel._input(event)

func _new_frame(feel: RecordingFeel) -> void:
    # The recorded backend is driven explicitly; keep engine ticks independent.
    await physics_frame
    feel.clock_usec += 17000

func _axis_event(feel: RecordingFeel, axis: JoyAxis, value: float, device: int = 3) -> void:
    var event := InputEventJoypadMotion.new()
    event.device = device
    event.axis = axis
    event.axis_value = value
    feel._input(event)

func _check_device_selection() -> void:
    var feel := RecordingFeel.new()
    root.add_child(feel)
    feel.set_process(false)
    feel.set_process_input(false)
    var key := InputEventKey.new()
    key.keycode = KEY_J
    key.physical_keycode = KEY_J
    key.pressed = true
    feel._input(key)
    for axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
        var previous_starts := feel.starts.size()
        _axis_event(feel, axis, -1.0)
        feel.melee_rumble(&"attack_1", false, Vector2.RIGHT)
        _check(feel._active_joy_device == -1 and feel.starts.size() == previous_starts,
            "Resting negative trigger after keyboard input cannot select a controller: %d" % axis)
        # Isolate each negative input from any preceding failure.
        feel._input(key)
    for value in [NAN, INF, -INF]:
        _axis_event(feel, JOY_AXIS_LEFT_X, value)
        _check(feel._active_joy_device == -1, "Non-finite stick input cannot select a controller: %s" % value)
        feel._input(key)

    # A held key predates the deliberate controller action. Its later OS repeat
    # is not a fresh choice to leave the controller, and must not stop its pulse.
    _joy_press(feel, 7)
    await _new_frame(feel)
    feel.melee_rumble(&"attack_1", false, Vector2.RIGHT)
    var starts_before := feel.starts.size()
    var stops_before := feel.stops.size()
    var deadline_before := feel._rumble_deadline_usec
    var echo := key.duplicate() as InputEventKey
    echo.echo = true
    feel._input(echo)
    _check(feel._active_joy_device == 7 and feel._rumble_device == 7,
        "Old keyboard repeat preserves the deliberately selected controller and active pulse")
    _check(feel.starts.size() == starts_before and feel.stops.size() == stops_before and feel._rumble_deadline_usec == deadline_before,
        "Keyboard echo neither restarts nor truncates the hardware pulse")
    var release := key.duplicate() as InputEventKey
    release.pressed = false
    feel._input(release)
    _check(feel._active_joy_device == 7 and feel._rumble_device == 7,
        "Releasing the old keyboard key does not steal controller feedback")
    for axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
        _joy_press(feel, 7)
        await _new_frame(feel)
        feel.melee_rumble(&"attack_1", false, Vector2.RIGHT)
        stops_before = feel.stops.size()
        _axis_event(feel, axis, -1.0, 3)
        _check(feel._active_joy_device == 7 and feel._rumble_device == 7 and feel.stops.size() == stops_before,
            "A second pad's resting trigger cannot steal or cancel the active pad: %d" % axis)
    starts_before = feel.starts.size()
    await _new_frame(feel)
    feel.melee_rumble(&"attack_1", false, Vector2.RIGHT)
    _check(feel.starts.size() == starts_before + 1 and feel.starts.back().device == 7,
        "The next accepted hit still reaches the active pad after key echo and resting triggers")
    stops_before = feel.stops.size()
    feel._input(key)
    _check(feel._active_joy_device == -1 and feel._rumble_device == -1 and feel.stops.size() == stops_before + 1,
        "A genuine new keyboard press still stops the active pad immediately")

    for axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
        feel._input(key)
        _axis_event(feel, axis, 0.9, 3)
        await _new_frame(feel)
        starts_before = feel.starts.size()
        feel.melee_rumble(&"attack_1", false, Vector2.RIGHT)
        _check(feel._active_joy_device == 3 and feel.starts.size() == starts_before + 1 and feel.starts.back().device == 3,
            "A deliberate positive trigger still selects its controller and receives feedback: %d" % axis)
    _axis_event(feel, JOY_AXIS_LEFT_X, -0.9, 7)
    await _new_frame(feel)
    starts_before = feel.starts.size()
    feel.melee_rumble(&"attack_1", false, Vector2.RIGHT)
    _check(feel._active_joy_device == 7 and feel.starts.size() == starts_before + 1 and feel.starts.back().device == 7,
        "Intentional negative stick movement still selects its controller")
    var mouse := InputEventMouseButton.new()
    mouse.button_index = MOUSE_BUTTON_LEFT
    mouse.pressed = true
    stops_before = feel.stops.size()
    feel._input(mouse)
    _check(feel._active_joy_device == -1 and feel._rumble_device == -1 and feel.stops.size() == stops_before + 1,
        "A fresh mouse press still returns feedback to keyboard/mouse mode")
    feel.queue_free()
    await process_frame

func _run_device_selection() -> void:
    await _check_device_selection()
    print("PLAYER_MELEE_DEVICE_SELECTION checks=%d failures=%d hardware=simulated" % [checks, failures.size()])
    quit(0 if failures.is_empty() else 1)

func _run() -> void:
    await _check_device_selection()
    var arena := Node2D.new()
    arena.position = Vector2(50, 20)
    root.add_child(arena)
    var sprite := AnimatedSprite2D.new()
    sprite.sprite_frames = SpriteFrames.new()
    var image := Image.create(384, 384, false, Image.FORMAT_RGBA8)
    var texture := ImageTexture.create_from_image(image)
    for animation: StringName in MELEE.BLADE_ANCHORS:
        sprite.sprite_frames.add_animation(animation)
        for frame in range(MELEE.BLADE_ANCHORS[animation].size()):
            sprite.sprite_frames.add_frame(animation, texture)
    _check(MELEE.BLADE_ANCHORS.has(&"attack_1") and MELEE.BLADE_ANCHORS.has(&"run_attack") and MELEE.BLADE_ANCHORS.has(&"air_attack"), "Measured blade anchors load for the packaged melee poses")
    var measured_tip: Vector2 = MELEE.BLADE_ANCHORS[&"attack_1"][2][1] - MELEE.SOURCE_SIZE * 0.5
    sprite.animation = &"attack_1"
    sprite.frame = 2
    sprite.position = Vector2(0, -58.08)
    sprite.scale = Vector2.ONE * 0.66
    arena.add_child(sprite)
    var right := MELEE.blade_points(sprite, 2, arena)
    _check(right.size() == 2 and right[1].is_equal_approx(sprite.position + measured_tip * 0.66), "Trail tip uses the measured displayed weapon anchor")
    sprite.flip_h = true
    var left := MELEE.blade_points(sprite, 2, arena)
    _check(is_equal_approx(left[1].x, -right[1].x) and is_equal_approx(left[1].y, right[1].y), "Weapon anchors mirror with the actual sprite")
    sprite.offset = Vector2(3, -2)
    var offset_left := MELEE.blade_points(sprite, 2, arena)
    _check(offset_left[1].is_equal_approx(left[1] + sprite.offset * sprite.scale), "Sprite draw offset is not mirrored with its texture")
    sprite.offset = Vector2.ZERO
    sprite.flip_h = false
    var trace = MELEE.spawn_swing(arena, sprite, 0.22, {"flash_enabled":false})
    trace.set_process(false)
    trace._process(0.001)
    _check(trace.name == &"AttackSlashVfx" and trace.get_child_count() == 0, "Swing is one blade-local draw node with no halo/particle hierarchy")
    _check(is_equal_approx(trace.lifetime, MELEE.TRACE_SECONDS) and MELEE.TRACE_SECONDS <= 0.1 and trace.reduced_flash, "Trace has a 100 ms ceiling and honors reduced flash")
    _check(trace.blade[1].is_equal_approx(right[1]), "Runtime trace samples the same displayed blade endpoint")
    # Rising cut: wind-up blade behind and low, first damage cel forward-up.
    # The swept band must travel through the front of the body, both facings.
    for facing_left in [false, true]:
        sprite.flip_h = facing_left
        sprite.animation = &"up_attack"
        sprite.frame = 2
        var arc_trace = MELEE.spawn_swing(arena, sprite, 0.22)
        arc_trace.set_process(false)
        arc_trace._process(0.001)
        var forward := Vector2.LEFT if facing_left else Vector2.RIGHT
        var middle := Vector2.from_angle(arc_trace.sweep_from + arc_trace.sweep * 0.5)
        _check(absf(arc_trace.sweep) > deg_to_rad(120.0) and middle.dot(forward) > 0.3, "Rising cut arc sweeps through the front (left=%s, sweep=%.0f deg)" % [facing_left, rad_to_deg(arc_trace.sweep)])
        sprite.frame = 3
        arc_trace._process(0.01)
        _check(absf(arc_trace.sweep) > deg_to_rad(120.0), "Arc keeps its swept extent across the damage cels (left=%s)" % facing_left)
        arc_trace.queue_free()
    sprite.flip_h = false
    sprite.animation = &"attack_1"
    sprite.frame = 2
    trace._process(MELEE.TRACE_SECONDS)
    _check(trace.is_queued_for_deletion(), "Trace cannot linger through recovery")
    var retired_traces: Array[WeakRef] = []
    for first_delta in [0.053, 0.1]:
        var slow_trace = MELEE.spawn_swing(arena, sprite, 0.22)
        slow_trace.set_process(false)
        slow_trace._process(first_delta)
        _check(not slow_trace.is_queued_for_deletion() and slow_trace.age == 0.0 and slow_trace.blade.size() == 2 and slow_trace.prior_blade.size() == 2, "Low-FPS first sample remains drawable at original opacity: %s" % first_delta)
        slow_trace._process(first_delta)
        _check(slow_trace.is_queued_for_deletion() == (first_delta >= slow_trace.lifetime), "Every subsequent low-FPS delta counts toward the finite lifetime: %s" % first_delta)
        slow_trace._process(slow_trace.lifetime)
        _check(slow_trace.is_queued_for_deletion(), "Low-FPS trace reaches cleanup without resetting its grace: %s" % first_delta)
        var final_age: float = slow_trace.age
        slow_trace._process(0.001)
        _check(slow_trace.age == final_age and slow_trace.is_queued_for_deletion(), "Queued trace cannot resample or restart: %s" % first_delta)
        retired_traces.append(weakref(slow_trace))
    var changing_trace = MELEE.spawn_swing(arena, sprite, 0.22)
    changing_trace.set_process(false)
    changing_trace._process(0.1)
    changing_trace._process(changing_trace.lifetime * 0.6)
    sprite.frame = 3
    changing_trace._process(changing_trace.lifetime * 0.6)
    _check(changing_trace.is_queued_for_deletion(), "Changing animation frames does not renew the trace lifetime")
    retired_traces.append(weakref(changing_trace))
    sprite.frame = 2
    var cancelled_trace = MELEE.spawn_swing(arena, sprite, 0.22)
    cancelled_trace.set_process(false)
    sprite.animation = &"default"
    cancelled_trace._process(0.1)
    _check(cancelled_trace.is_queued_for_deletion() and cancelled_trace.sampled_frame == -1, "Interrupted/unsupported pose receives no first-frame grace")
    retired_traces.append(weakref(cancelled_trace))
    sprite.animation = &"air_attack"
    sprite.frame = 4
    var empty_blade_trace = MELEE.spawn_swing(arena, sprite, 0.22)
    empty_blade_trace.set_process(false)
    empty_blade_trace._process(0.053)
    _check(empty_blade_trace.is_queued_for_deletion(), "A pose with no displayed blade cancels instead of waiting indefinitely")
    retired_traces.append(weakref(empty_blade_trace))
    sprite.animation = &"attack_1"
    sprite.frame = 2
    var lost_sprite_trace = MELEE.spawn_swing(arena, sprite, 0.22)
    lost_sprite_trace.set_process(false)
    lost_sprite_trace.weapon_sprite = null
    lost_sprite_trace._process(0.053)
    _check(lost_sprite_trace.is_queued_for_deletion(), "Missing weapon sprite cancels before its first draw sample")
    retired_traces.append(weakref(lost_sprite_trace))
    await process_frame
    await process_frame
    for reference in retired_traces:
        _check(reference.get_ref() == null, "Expired/cancelled draw nodes are actually freed by the SceneTree")

    var contact = MELEE.spawn_hit(arena, Vector2(100, 80), Vector2.LEFT, &"attack_1", {"flash_enabled":false})
    contact.set_process(false)
    _check(contact.global_position == Vector2(100, 80) and contact.length == 11.0 and contact.reduced_flash, "Contact is a compact world-anchored nick")
    contact._process(0.001)
    contact._process(0.066)
    _check(contact.is_queued_for_deletion(), "Contact mark cleans up without an expanding ring")
    var retired_contacts: Array[WeakRef] = []
    for first_delta in [0.053, 0.1]:
        var slow_contact = MELEE.spawn_hit(arena, Vector2(100, 80), Vector2.RIGHT, &"attack_1")
        slow_contact.set_process(false)
        slow_contact._process(first_delta)
        _check(slow_contact.sampled and slow_contact.age == 0.0 and not slow_contact.is_queued_for_deletion(), "Low-FPS contact has one first draw sample at its original opacity: %s" % first_delta)
        slow_contact._process(first_delta)
        _check(slow_contact.is_queued_for_deletion() == (first_delta >= MELEE.CONTACT_SECONDS), "Every later contact delta counts toward the 65 ms lifetime: %s" % first_delta)
        slow_contact._process(0.013)
        _check(slow_contact.is_queued_for_deletion(), "Low-FPS contact expires instead of renewing first-frame grace: %s" % first_delta)
        var final_age: float = slow_contact.age
        slow_contact._process(0.001)
        _check(slow_contact.age == final_age and slow_contact.is_queued_for_deletion(), "Retired contact cannot restart or resample: %s" % first_delta)
        retired_contacts.append(weakref(slow_contact))
    var cancelled_contact = MELEE.spawn_hit(arena, Vector2.ZERO, Vector2.RIGHT, &"attack_1")
    cancelled_contact.set_process(false)
    cancelled_contact.queue_free()
    cancelled_contact._process(0.1)
    _check(not cancelled_contact.sampled and cancelled_contact.is_queued_for_deletion(), "Explicit contact cancellation takes precedence over first-frame grace")
    retired_contacts.append(weakref(cancelled_contact))
    var invalid_contact = MELEE.spawn_hit(arena, Vector2.ZERO, Vector2.RIGHT, &"attack_1")
    invalid_contact.set_process(false)
    invalid_contact.length = 0.0
    invalid_contact._process(0.1)
    _check(not invalid_contact.sampled and invalid_contact.is_queued_for_deletion(), "Non-drawable contact cancels without waiting indefinitely")
    retired_contacts.append(weakref(invalid_contact))
    await process_frame
    await process_frame
    for reference in retired_contacts:
        _check(reference.get_ref() == null, "Expired/cancelled contact nodes are actually freed by the SceneTree")
    _check(MELEE.spawn_swing(arena, sprite, 0.0) == null, "Inactive window cannot spawn a trace")

    var feel := RecordingFeel.new()
    root.add_child(feel)
    feel.set_process(false)
    feel.set_process_input(false)
    feel.melee_rumble(&"attack_1", false, Vector2.RIGHT)
    _check(feel.starts.is_empty(), "Connected controllers alone are not permission to vibrate all pads")
    var drift := InputEventJoypadMotion.new()
    drift.device = 3
    drift.axis_value = 0.1
    feel._input(drift)
    _check(feel._active_joy_device == -1, "Stick drift cannot steal the feedback device")
    _joy_press(feel)
    feel.melee_rumble(&"attack_1", false, Vector2.RIGHT)
    _check(feel.starts.size() == 1 and feel.starts[0].device == 7, "Accepted hit routes to the latest active connected pad only")
    _check(is_equal_approx(feel.starts[0].weak, 0.17) and is_equal_approx(feel.starts[0].duration, 0.045), "Normal contact produces the bounded light pulse")
    feel.melee_rumble(&"attack_2", true, Vector2.RIGHT)
    _check(feel.starts.size() == 1, "Same-tick multi-target contact does not stack pulses")
    feel.set_accessibility({"vibration_enabled":false})
    _check(feel.stops == [7] and feel._rumble_device == -1, "Disabling stops the current pulse immediately")
    await _new_frame(feel)
    feel.melee_rumble(&"attack_1", false, Vector2.RIGHT)
    _check(feel.starts.size() == 1, "Disabled setting rejects future pulses")
    feel.set_accessibility({"vibration_enabled":true, "vibration_strength":0.5})
    feel.melee_rumble(&"attack_1", false, Vector2.RIGHT)
    _check(feel.starts.size() == 2 and is_equal_approx(feel.starts.back().weak, 0.085), "Strength scales both motors without increasing duration")
    feel.clock_usec += 46000
    feel._process(0.0001)
    _check(feel._rumble_device == -1, "Pulse expiry uses real time even during hitstop")
    await _new_frame(feel)
    feel.melee_rumble(&"attack_1", false, Vector2.RIGHT)
    paused = true
    feel._process(0.001)
    _check(feel._rumble_device == -1, "Pausing stops any active hardware pulse")
    var before_pause := feel.starts.size()
    feel.melee_rumble(&"attack_1", false, Vector2.RIGHT)
    _check(feel.starts.size() == before_pause, "Paused gameplay cannot start another pulse")
    paused = false
    await _new_frame(feel)
    feel.melee_rumble(&"attack_1", false, Vector2.RIGHT)
    feel._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
    _check(feel._rumble_device == -1 and feel._active_joy_device == -1, "Focus loss clears active feedback and controller selection")
    _joy_press(feel)
    await _new_frame(feel)
    feel.melee_rumble(&"attack_1", false, Vector2.RIGHT)
    feel.devices = [3]
    feel._on_joy_connection_changed(7, false)
    var before_disconnect := feel.starts.size()
    await _new_frame(feel)
    feel.melee_rumble(&"attack_1", false, Vector2.RIGHT)
    _check(feel._active_joy_device == -1 and feel._rumble_device == -1 and feel.starts.size() == before_disconnect, "Disconnected device is a safe no-op and does not redirect to another pad")
    _joy_press(feel, 3)
    var key := InputEventKey.new()
    key.pressed = true
    key.keycode = KEY_J
    feel._input(key)
    feel.melee_rumble(&"attack_1", false, Vector2.RIGHT)
    _check(feel.starts.size() == before_disconnect, "Keyboard input does not buzz a connected idle controller")
    _joy_press(feel, 3)
    feel.set_accessibility({"vibration_strength":0.0})
    feel.melee_rumble(&"attack_1", false, Vector2.RIGHT)
    _check(feel.starts.size() == before_disconnect, "Zero strength is fully silent")
    feel.set_accessibility({"vibration_strength":5.0})
    _check(feel._vibration_strength == 1.0, "Out-of-range strength is clamped")
    feel.set_accessibility({"vibration_strength":NAN})
    _check(feel._vibration_strength == 1.0, "Non-finite strength cannot reach the hardware backend")
    for animation in [&"attack_1", &"attack_2", &"hook_throw"]:
        for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
            for killed in [false, true]:
                var pulse := RecordingFeel.melee_rumble_profile(animation, killed, direction)
                _check(pulse.x >= 0.0 and pulse.x <= 1.0 and pulse.y >= 0.0 and pulse.y <= 1.0 and pulse.z > 0.0 and pulse.z <= 0.09, "Every hit profile is finite and bounded: %s/%s/%s" % [animation, direction, killed])

    # Production Player scene and accepted-damage gate, with no hardware writes.
    var player_scene := load("res://scenes/Player.tscn") as PackedScene
    var player = player_scene.instantiate()
    player.set_script(ProbePlayer)
    arena.add_child(player)
    player.set_physics_process(false)
    player.set_process(false)
    player.feel = feel
    player.position = Vector2(300, 200)
    player.energy = 0
    var target := HitTarget.new()
    arena.add_child(target)
    target.add_to_group("enemy")
    target.global_position = player.global_position + Vector2(500, -40)
    _joy_press(feel, 3)
    feel.starts.clear()
    feel.stop_requests.clear()
    await _new_frame(feel)
    player._start_attack(&"attack_1")
    var combat_before := [player.attack_duration, player.attack_windup, player.attack_active_time, player.attack_damage, player.attack_range, player.attack_height]
    player._update_attack(player.attack_windup + 0.001)
    player._update_attack_pose()
    _check(feel.starts.is_empty() and feel.stop_requests.is_empty() and target.hit_calls == 0, "Real player whiff causes no rumble, hitstop, or target call")
    _check(player.get_node_or_null("AttackSlashVfx") != null, "Real active boundary creates the replacement trace")
    target.global_position = player.global_position + player._attack_center_offset()
    target.accepts = false
    player._apply_attack_hits()
    _check(feel.starts.is_empty() and feel.stop_requests.is_empty() and player.energy == 0, "Rejected damage has no hit confirmation, hitstop, rumble, or energy")
    player.hit_targets.clear()
    target.accepts = true
    var hp_before: int = target.hp
    player._apply_attack_hits()
    _check(target.hp == hp_before - player.attack_damage and player.energy == player.energy_per_hit, "Accepted hit preserves damage and the existing energy award")
    _check(feel.starts.size() == 1 and feel.stop_requests.size() == 1 and is_equal_approx(feel.stop_requests[0], 45.0), "Accepted production hit reaches one rumble and the unchanged hitstop tier")
    player._apply_attack_hits()
    _check(target.hp == hp_before - player.attack_damage and feel.starts.size() == 1, "Per-target hit deduplication remains unchanged")
    _check(combat_before == [player.attack_duration, player.attack_windup, player.attack_active_time, player.attack_damage, player.attack_range, player.attack_height], "Feedback does not alter timings, damage, or attack geometry")
    _check(arena.get_node_or_null("HitConfirmVfx") != null, "Accepted production hit creates the compact contact mark")
    feel.cancel_rumble()
    arena.queue_free()
    feel.queue_free()
    await process_frame
    await process_frame
    if failures.is_empty():
        print("PLAYER_MELEE_FEEDBACK_PASS checks=%d hardware=simulated physical_feel=unverified" % checks)
        quit(0)
    else:
        print("PLAYER_MELEE_FEEDBACK_FAIL checks=%d failures=%s" % [checks, failures])
        quit(1)
