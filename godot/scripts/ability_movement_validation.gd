extends SceneTree
## Real input + CharacterBody2D physics, independent of chapter generation.
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    _floor(Vector2(500, 310), Vector2(1500, 20))
    var player = PLAYER_SCENE.instantiate()
    root.add_child(player)
    player.feel = null # No cinematic hitstop in deterministic physics probes.
    player.global_position = Vector2(100, 300)
    await _frames(5)
    _assert(player.is_on_floor(), "fixture starts on solid ground")
    Input.action_press("jump")
    await _frames(3)
    _assert(player.velocity.y < -500.0, "first jump still uses the existing movement")
    Input.action_release("jump")
    await _frames(3)
    var before: float = player.velocity.y
    Input.action_press("jump")
    await _frames(2)
    _assert(player.velocity.y >= before, "locked double jump cannot create upward impulse")
    Input.action_release("jump")
    await _frames(45)

    player.double_jump_unlocked = true
    player.respawn_at(Vector2(100, 300))
    await _frames(5)
    Input.action_press("jump")
    await _frames(10)
    _assert(player.air_jump_available, "held first jump does not spend the second jump")
    Input.action_release("jump")
    await _frames(2)
    Input.action_press("jump")
    await _frames(2)
    _assert(player.velocity.y < -500.0 and not player.air_jump_available, "fresh airborne press performs double jump")
    Input.action_release("jump")
    await _frames(3)
    before = player.velocity.y
    Input.action_press("jump")
    await _frames(2)
    _assert(player.velocity.y >= before, "third press cannot create an infinite jump")
    Input.action_release("jump")
    await _frames(60)
    _assert(player.is_on_floor() and player.air_jump_available, "landing restores the air jump")

    var locked_peak: float = await _jump_peak(player, false)
    var unlocked_peak: float = await _jump_peak(player, true)
    print("ABILITY_PEAK locked=%.3f unlocked=%.3f" % [locked_peak,unlocked_peak])
    _assert(locked_peak > 120.0 and unlocked_peak < 110.0, "double jump reaches a high ledge that a single jump cannot reach")

    var anchor := Node2D.new()
    root.add_child(anchor)
    anchor.add_to_group("grapple_anchor")
    anchor.position = Vector2(370, 175)
    player.respawn_at(Vector2(100, 300))
    await _frames(4)
    _assert(not player._try_start_grapple(), "locked grapple ignores a reachable anchor")
    player.thread_grapple_unlocked = true
    _assert(player._try_start_grapple(), "unlocked grapple latches an explicit visible anchor")
    var start: Vector2 = player.global_position
    await _frames(8)
    _assert(player.global_position.x > start.x + 70.0 and player.global_position.y < start.y - 15.0, "grapple moves the actual collision body toward the anchor")
    Input.action_press("dash")
    await _frames(2)
    _assert(player.grapple_timer <= 0.0, "dash cancels active grapple")
    Input.action_release("dash")

    player.respawn_at(Vector2(100, 300))
    await _frames(5)
    var blocker := _floor(Vector2(235, 175), Vector2(24, 250))
    await _frames(3)
    _assert(not player._try_start_grapple(), "solid wall prevents latching through terrain")
    blocker.queue_free()
    await _frames(3)
    anchor.set_meta("grapple_enabled", false)
    _assert(not player._try_start_grapple(), "disabled anchor cannot be targeted")
    anchor.set_meta("grapple_enabled", true)
    anchor.position = Vector2(900, 175)
    _assert(not player._try_start_grapple(), "out of range anchor cannot be targeted")
    anchor.position = Vector2(370, 175)
    anchor.hide()
    _assert(not player._try_start_grapple(), "hidden anchor cannot be targeted")
    anchor.show()
    _assert(player._try_start_grapple(), "reachable anchor is available again")
    anchor.queue_free()
    await _frames(3)
    _assert(player.grapple_timer <= 0.0, "freed anchor cancels without retaining an invalid reference")
    player.air_jump_available = false
    player.dash_timer = 0.1
    player.jump_buffer_timer = 0.1
    player.respawn_at(Vector2(100, 300))
    _assert(player.air_jump_available and player.dash_timer == 0.0 and player.jump_buffer_timer == 0.0, "respawn resets traversal impulses and air jump")
    player.queue_free()
    await _frames(2)
    print("ABILITY_MOVEMENT_VALIDATION failures=%d" % failures)
    quit(0 if failures == 0 else 1)

func _jump_peak(player: CharacterBody2D, unlocked: bool) -> float:
    player.double_jump_unlocked = unlocked
    player.respawn_at(Vector2(100, 300))
    await _frames(5)
    var peak: float = player.global_position.y
    Input.action_press("jump")
    await _frames(14)
    Input.action_release("jump")
    await _frames(2)
    Input.action_press("jump")
    for index in range(45):
        await _frames(1)
        peak = minf(peak, player.global_position.y)
    Input.action_release("jump")
    await _frames(40)
    return peak

func _floor(center: Vector2, size: Vector2) -> StaticBody2D:
    var body := StaticBody2D.new()
    var shape := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = size
    shape.shape = rectangle
    body.add_child(shape)
    root.add_child(body)
    body.position = center
    return body

func _frames(count: int) -> void:
    for index in range(count):
        await physics_frame
        await process_frame

func _assert(condition: bool, label: String) -> void:
    if condition:
        print("PASS: " + label)
    else:
        failures += 1
        push_error("FAIL: " + label)
