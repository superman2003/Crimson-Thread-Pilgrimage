extends SceneTree
## A01/S02: an ordinary strike from above on a breakable floor cracks it (sound
## and shudder, once per swing) but leaves it whole and its collision in place;
## the thorn downstrike breaks the same floor without the crack. Production
## World host, real Player strikes on the moss court downstrike workshop floor.
const READY := preload("res://scripts/world_ready_validation_helper.gd")
const GATE := "upgrade_thorn_downstrike_1_action_gate"
var checks := 0
var failures: Array[String] = []
var scene: Node
var struck: Array = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)

func _physics(count: int) -> void:
    for index in count:
        await physics_frame
        await process_frame

func _gate() -> StaticBody2D:
    return scene.locked_gate_bodies.get(GATE) as StaticBody2D

func _release() -> void:
    for action in ["jump", "attack", "aim_down"]:
        Input.action_release(action)

## Real input: stand on the floor, jump, and strike downward either at the top
## of the jump (the workshop roof is 150px above the floor) or while falling.
func _jump_and_strike(gate: StaticBody2D, at_peak: bool) -> void:
    var player: CharacterBody2D = scene.player
    var size: Vector2 = gate.get_meta("gate_size")
    var top := gate.global_position.y - size.y * 0.5
    _release()
    player.global_position = Vector2(gate.global_position.x, top - 2)
    player.velocity = Vector2.ZERO
    player.attack_timer = 0.0
    player.attack_cancel_lock = 0.0
    await _physics(8)
    Input.action_press("jump")
    await _physics(2)
    for frame in 90:
        await _physics(1)
        if at_peak and player.velocity.y >= 0.0:
            break
        if not at_peak and player.velocity.y > 60.0:
            break
    Input.action_release("jump")
    _check(not player.is_on_floor(), "strike starts in the air above the floor")
    Input.action_press("aim_down")
    Input.action_press("attack")
    await _physics(3)
    _release()
    await _physics(40)

func _run() -> void:
    scene = load("res://scenes/World.tscn").instantiate()
    scene.world_resume = false
    scene.world_save_path = "user://fragile_gate_crack_validation.json"
    root.add_child(scene)
    await READY.wait_for(scene)
    current_scene = scene
    await _physics(4)
    for enemy in get_nodes_in_group("enemy"):
        enemy.set_physics_process(false)
    scene.player.gate_struck.connect(func(gate, point): struck.append([gate, point]))
    var gate := _gate()
    _check(gate != null and gate.is_in_group("fragile_terrain") and gate.has_meta("gate_size"), "workshop floor is breakable terrain with its size")
    _check(scene.player.SFX.has("downstrike_crack") and ResourceLoader.exists(scene.player.SFX.downstrike_crack), "crack sound is the generated downstrike crack")
    if gate != null:
        scene.inventory_counts.erase("thorn_downstrike")
        scene._sync_player_abilities()
        _check(not scene.player.thorn_downstrike_unlocked, "fixture starts without the thorn downstrike")
        var shape: CollisionShape2D = null
        for child in gate.get_children():
            if child is CollisionShape2D:
                shape = child
        var shape_before: Vector2 = shape.global_position if shape != null else Vector2.INF
        await _jump_and_strike(gate, false)
        _check(struck.size() == 1 and struck[0][0] == gate, "an ordinary down strike cracks the floor once per swing (%d)" % struck.size())
        _check(scene.locked_gate_bodies.has(GATE) and is_instance_valid(gate) and gate.is_inside_tree(), "the cracked floor still holds")
        _check(int(gate.get_meta("crack_count", 0)) == 1, "the floor drawing shudders on the crack")
        _check(shape != null and shape.global_position == shape_before, "the collision under the player never moves")
        await _physics(20)
        var drawn_back := true
        for child in gate.get_children():
            if child.has_meta("shudder_base") and child.position != child.get_meta("shudder_base"):
                drawn_back = false
        _check(drawn_back, "the drawing settles back where it was")
        await _jump_and_strike(gate, true)
        _check(struck.size() == 2, "a second swing cracks again (%d)" % struck.size())

        # Owning the thorn downstrike: the same strike breaks it, without the crack.
        scene.inventory_counts["thorn_downstrike"] = 1
        scene._sync_player_abilities()
        var before := struck.size()
        await _jump_and_strike(gate, true)
        _check(not scene.locked_gate_bodies.has(GATE), "a thorn downstrike from the top of the jump breaks the floor")
        _check(struck.size() == before, "breaking the floor does not also play the crack")

    scene.queue_free()
    await _physics(3)
    for name in DirAccess.get_files_at("user://"):
        if name.begins_with("fragile_gate_crack_validation.json"):
            DirAccess.remove_absolute("user://" + name)
    if failures.is_empty():
        print("FRAGILE_GATE_CRACK_PASS checks=%d" % checks)
    else:
        for label in failures:
            push_error(label)
        print("FRAGILE_GATE_CRACK_FAIL failures=%d checks=%d" % [failures.size(), checks])
    call_deferred("quit", 0 if failures.is_empty() else 1)
