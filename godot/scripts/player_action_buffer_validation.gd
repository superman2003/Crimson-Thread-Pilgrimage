extends SceneTree
## Real InputMap edges and controller physics on solid ground. No chapter/playthrough claim.
class ProbePlayer extends "res://scripts/player_controller.gd":
    var strike_count := 0
    var dash_count := 0
    func _start_attack(animation: StringName, traversal: bool = true, queued_direction: Vector2 = Vector2.ZERO) -> void:
        super._start_attack(animation, traversal, queued_direction)
        strike_count += 1
    func _start_dash() -> void:
        super._start_dash()
        dash_count += 1
    func _play_sfx(_key: String, _volume: float = -6.0, _pitch: float = 1.0, _voice_key: String = "", _priority_override: int = -1) -> void:
        pass

var checks := 0
var failures: Array[String] = []
var player: ProbePlayer

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label)

func _frames(count: int) -> void:
    for index in range(count):
        await physics_frame
        await process_frame

func _reset() -> void:
    for action in ["attack", "dash", "aim_up", "aim_down", "move_left", "move_right"]:
        Input.action_release(action)
    player.ui_input_locked = false
    player.restore_at_save_point()
    player.respawn_at(Vector2(300, 300))
    await _frames(4)
    player.strike_count = 0
    player.dash_count = 0

func _run() -> void:
    var floor_body := StaticBody2D.new()
    var shape := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = Vector2(4000, 20)
    shape.shape = rectangle
    floor_body.position = Vector2(1000, 310)
    floor_body.add_child(shape)
    root.add_child(floor_body)
    # Use the production scene's collision, hitbox, sprite, and camera nodes.
    var scene := load("res://scenes/Player.tscn") as PackedScene
    var instance := scene.instantiate() as CharacterBody2D
    instance.set_script(ProbePlayer)
    player = instance
    root.add_child(player)
    player.feel = null
    await _reset()
    _check(player.is_on_floor(), "Fixture has real floor contact")
    player._start_attack(&"attack_1")
    player.strike_count = 0
    player.attack_timer = 0.05
    Input.action_press("aim_up")
    Input.action_press("attack")
    await _frames(1)
    _check(player.buffered_action == &"attack" and player.strike_count == 0, "Recovery retains a fresh attack press")
    Input.action_release("attack")
    Input.action_release("aim_up")
    await _frames(5)
    _check(player.strike_count == 1 and player.current_attack_direction == Vector2.UP, "Released buffered press fires once with original upward aim")
    _check(player.buffered_action == &"", "Executed attack consumes its pending command")
    await _frames(30)
    _check(player.strike_count == 1, "An executed command never repeats after recovery")

    await _reset()
    player._start_attack(&"attack_1")
    player.strike_count = 0
    Input.action_press("attack")
    await _frames(32)
    _check(player.strike_count == 0 and player.buffered_action == &"", "Early input expires and holding does not auto attack")

    await _reset()
    player.dash_cooldown = 0.05
    Input.action_press("move_left")
    Input.action_press("dash")
    await _frames(1)
    _check(player.buffered_action == &"dash" and player.dash_count == 0, "Dash cooldown retains a nearby press")
    Input.action_release("dash")
    Input.action_release("move_left")
    Input.action_press("move_right")
    await _frames(4)
    _check(player.dash_count == 1 and player.facing == -1 and player.velocity.x < 0, "Dash preserves pressed direction despite a later turn")
    await _frames(45)
    _check(player.dash_count == 1, "Dash command remains single use")

    await _reset()
    player.dash_cooldown = 0.4
    Input.action_press("dash")
    await _frames(32)
    _check(player.dash_count == 0, "Expired cooldown input does not dash later")
    player.dash_unlocked = false
    Input.action_release("dash")
    await _frames(2)
    Input.action_press("dash")
    await _frames(1)
    _check(player.buffered_action == &"" and player.dash_count == 0, "Locked ability cannot enqueue a dash")
    player.dash_unlocked = true

    await _reset()
    player._start_attack(&"attack_1")
    player.strike_count = 0
    # Still inside the active frames: the recovery (where a dash would cut the
    # swing at once, see melee_recovery) has not started yet.
    player.attack_timer = 0.2
    Input.action_press("attack")
    await _frames(1)
    Input.action_release("attack")
    Input.action_press("dash")
    await _frames(1)
    _check(player.buffered_action == &"dash", "New dash replaces the pending attack")
    Input.action_release("dash")
    await _frames(6)
    _check(player.dash_count == 1 and player.strike_count == 0, "Only the latest command runs")

    await _reset()
    Input.action_press("attack")
    Input.action_press("dash")
    await _frames(1)
    _check(player.dash_count == 1 and player.strike_count == 0, "Same tick preserves dash priority")

    await _reset()
    player._start_attack(&"attack_1")
    player.strike_count = 0
    player.attack_timer = 0.05
    Input.action_press("attack")
    await _frames(1)
    player.ui_input_locked = true
    _check(player.buffered_action == &"", "Opening overlay clears the queue immediately")
    Input.action_release("attack")
    await _frames(10)
    player.ui_input_locked = false
    await _frames(10)
    _check(player.strike_count == 0, "Closing overlay cannot replay its old command")

    await _reset()
    player._start_attack(&"attack_1")
    player.strike_count = 0
    Input.action_press("attack")
    await _frames(1)
    Input.action_release("attack")
    player.take_damage(1, player.global_position + Vector2(50, 0))
    _check(player.buffered_action == &"", "Accepted damage clears pending combat input")
    await _frames(70)
    _check(player.strike_count == 0, "Damage recovery cannot replay a cleared attack")

    await _reset()
    player._start_attack(&"attack_1")
    player.strike_count = 0
    player.attack_timer = 0.05
    Input.action_press("attack")
    await _frames(1)
    Input.action_release("attack")
    player.arrival_guard_timer = 0.5
    player.take_damage(1, player.global_position + Vector2(50, 0))
    _check(player.buffered_action == &"attack", "Ignored arrival damage does not erase a valid command")
    await _frames(5)
    _check(player.strike_count == 1, "Buffered attack still executes after ignored damage")

    await _reset()
    player._start_attack(&"attack_1")
    player.strike_count = 0
    player.attack_timer = 0.05
    Input.action_press("move_left")
    Input.action_press("attack")
    await _frames(1)
    Input.action_release("attack")
    Input.action_release("move_left")
    Input.action_press("move_right")
    await _frames(4)
    _check(player.strike_count == 1 and player.facing == -1, "Horizontal buffered strike preserves facing")
    _check(player.attack_hitbox.position.x < 0, "Queued strike hitbox agrees with preserved facing")

    for boundary in ["prepare_region_handoff", "restore_at_save_point", "_hard_respawn"]:
        await _reset()
        player._start_attack(&"attack_1")
        player.strike_count = 0
        Input.action_press("attack")
        await _frames(1)
        Input.action_release("attack")
        player.call(boundary)
        _check(player.buffered_action == &"", boundary + " clears pending combat input")
        await _frames(10)
        _check(player.strike_count == 0, boundary + " cannot replay a stale attack")

    await _reset()
    player.action_buffer_time = 0.0
    Input.action_press("attack")
    await _frames(1)
    _check(player.strike_count == 1, "Zero buffer keeps immediate input usable")
    player.action_buffer_time = 0.1
    player.set_physics_process(false)
    # Check equal simulated timeout across different physics rates.
    for rate in [30, 60, 120]:
        Input.action_release("attack")
        await _frames(2)
        Input.action_press("attack")
        player._sample_action_input(1.0 / rate)
        Input.action_release("attack")
        await _frames(2)
        for tick in range(int(ceil(0.11 * rate))):
            player._sample_action_input(1.0 / rate)
        _check(player.buffered_action == &"", "Timeout uses seconds at %d Hz" % rate)

    for action in ["attack", "dash", "aim_up", "aim_down", "move_left", "move_right"]:
        Input.action_release(action)
    player.queue_free()
    floor_body.queue_free()
    await _frames(3)
    for failure in failures: push_error(failure)
    print("PLAYER_ACTION_BUFFER checks=%d failures=%d" % [checks, failures.size()])
    quit(0 if failures.is_empty() else 1)
