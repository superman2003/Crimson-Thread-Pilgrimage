extends SceneTree
## W04: the bell-marrow cell (moss bell court) is closed on every side until
## the thorn downstrike is owned. Production World host and real Player input:
## without the ability the shaft-side opening is a wall and nothing leaves the
## cell; with it both gates are gone and the cell can be entered and left on
## foot.
const READY := preload("res://scripts/world_ready_validation_helper.gd")
const KNOWLEDGE := preload("res://scripts/survey_map_knowledge.gd")
const PORTAL := "upgrade_bell_guard_1_access_a"
const SIDE := "gate_marrow_side"
const LIFT_SIDE := "gate_marrow_lift"
const FLOOR := "gate_break_marrow"
const CELL := Rect2(3960, 1026, 260, 184)
const SHAFT_LOW_STEP := Vector2(3930, 1276)
const CELL_STAND := Vector2(4090, 1206)
const LIFT_SHAFT := Vector2(4300, 1150)
var checks := 0
var failures: Array[String] = []
var scene: Node

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

func _release() -> void:
    for action in ["move_left", "move_right", "jump"]:
        Input.action_release(action)

## Put the player down and let the streamed collision around the spot arrive
## before gravity acts.
func _place(point: Vector2) -> void:
    var player: CharacterBody2D = scene.player
    _release()
    player.set_physics_process(false)
    player.global_position = point
    player.velocity = Vector2.ZERO
    await _physics(30)
    player.set_physics_process(true)
    await _physics(20)

func _inside_cell() -> bool:
    # Feet position: strictly inside the room, away from the gate's own width.
    var point: Vector2 = scene.player.global_position
    return point.x > CELL.position.x + 42.0 and point.x < CELL.end.x - 42.0 and point.y > CELL.position.y and point.y <= CELL.end.y + 4.0

## Hold a direction, jumping every `jump_every` frames (0 = never). Returns
## whether the player was ever inside the cell, and the furthest x reached.
func _push(direction: int, frames: int, jump_every: int) -> Dictionary:
    var entered := false
    var extreme: float = scene.player.global_position.x
    Input.action_press("move_right" if direction > 0 else "move_left")
    for frame in frames:
        if jump_every > 0 and frame % jump_every == 0:
            Input.action_press("jump")
        elif jump_every > 0 and frame % jump_every == 12:
            Input.action_release("jump")
        await _physics(1)
        var x: float = scene.player.global_position.x
        extreme = maxf(extreme, x) if direction > 0 else minf(extreme, x)
        if _inside_cell():
            entered = true
    _release()
    await _physics(10)
    return {"entered": entered, "extreme": extreme}

func _run() -> void:
    scene = load("res://scenes/World.tscn").instantiate()
    scene.world_resume = false
    scene.world_save_path = "user://marrow_cell_entry_validation.json"
    root.add_child(scene)
    await READY.wait_for(scene)
    current_scene = scene
    await _physics(4)
    for enemy in get_nodes_in_group("enemy"):
        enemy.set_physics_process(false)
    var player: CharacterBody2D = scene.player
    scene.inventory_counts.erase("thorn_downstrike")
    scene._sync_player_abilities()
    _check(String(scene.config.get("id", "")) == "demo_ch01_moss_bell_court", "the moss bell court is the starting region")
    _check(not player.thorn_downstrike_unlocked, "fixture starts without the thorn downstrike")

    # Closed: the walls and the floor all stand. The shaft step level with the
    # cell floor is the only place the opening can be reached from (the step
    # above it sits under a ceiling too low to stand on).
    await _place(SHAFT_LOW_STEP)
    _check(scene.locked_gate_bodies.has(SIDE) and scene.locked_gate_bodies.has(LIFT_SIDE) and scene.locked_gate_bodies.has(FLOOR), "both side walls and the breakable floor stand without the ability")
    _check(player.is_on_floor() and absf(player.global_position.y - 1280.0) < 6.0, "player stands on the shaft step below the opening (y=%.0f)" % player.global_position.y)
    var walk: Dictionary = await _push(1, 120, 0)
    _check(not walk.entered and walk.extreme < CELL.position.x + 2.0, "walking right from the shaft step stops short of the cell (x=%.0f)" % walk.extreme)
    await _place(SHAFT_LOW_STEP)
    var low: Dictionary = await _push(1, 240, 40)
    _check(not low.entered and low.extreme < CELL.position.x + 2.0, "jumping at the opening from the shaft step meets the wall (x=%.0f)" % low.extreme)

    # The workshop portal inside the cell is within reach of the shaft step as
    # the crow flies; the wall must keep it out of reach, even mid-jump.
    var portal := scene.get_node_or_null(PORTAL) as Area2D
    _check(portal != null and String(portal.get_meta("kind", "")) == "world_portal", "the cell holds the bell-guard workshop portal")
    await _place(SHAFT_LOW_STEP)
    var grabbed := false
    var in_range := false
    Input.action_press("move_right")
    for frame in 120:
        if frame % 40 == 0:
            Input.action_press("jump")
        elif frame % 40 == 12:
            Input.action_release("jump")
        await _physics(1)
        if portal != null and player.global_position.distance_to(portal.global_position) <= scene.INTERACTION_REACH:
            in_range = true
        if scene._nearest_interactable(scene.INTERACTION_REACH) == portal:
            grabbed = true
    _release()
    await _physics(10)
    _check(in_range, "the portal is within plain interaction distance of the shaft step")
    _check(not grabbed, "the portal cannot be picked through the closed wall")
    for id in [SIDE, LIFT_SIDE, FLOOR]:
        for gate in scene.config.get("locked_gates", []):
            if String(gate.get("id", "")) == id:
                var rect: Array = gate.rect
                _check(not KNOWLEDGE.owner_room(scene.config, Rect2(rect[0], rect[1], rect[2], rect[3])).is_empty(), "%s lies inside a map room, so the map can mark it" % id)

    # Closed room holds on the far side too: nothing leaves it to the right.
    await _place(CELL_STAND)
    _check(player.is_on_floor() and _inside_cell(), "fixture can stand on the cell floor (%.0f, %.0f)" % [player.global_position.x, player.global_position.y])
    _check(scene._nearest_interactable(scene.INTERACTION_REACH) == portal, "from inside the cell the portal is the interaction target")
    var right: Dictionary = await _push(1, 200, 40)
    _check(_inside_cell(), "walking and jumping right stays in the cell (%.0f, %.0f)" % [player.global_position.x, player.global_position.y])
    await _place(CELL_STAND)
    var left: Dictionary = await _push(-1, 200, 40)
    _check(_inside_cell(), "walking and jumping left stays in the cell while the wall stands (%.0f, %.0f)" % [player.global_position.x, player.global_position.y])

    # The lift shaft passes the cell's other side: a body level with the room,
    # falling past it and pushing left, never gets in.
    await _place(LIFT_SHAFT)
    var lift: Dictionary = await _push(-1, 90, 0)
    _check(not lift.entered, "pushing left from the lift shaft does not get in (x=%.0f)" % lift.extreme)

    # Owning the thorn downstrike opens every gate for good.
    scene.inventory_counts["thorn_downstrike"] = 1
    scene._refresh_ability_gates()
    await _physics(6)
    _check(not scene.locked_gate_bodies.has(SIDE) and not scene.locked_gate_bodies.has(LIFT_SIDE) and not scene.locked_gate_bodies.has(FLOOR), "all three gates are gone once the thorn downstrike is owned")
    await _place(SHAFT_LOW_STEP)
    var enter: Dictionary = await _push(1, 240, 40)
    _check(enter.entered, "jumping right from the shaft step now enters the cell (furthest x=%.0f)" % enter.extreme)
    await _place(CELL_STAND)
    var leave: Dictionary = await _push(-1, 200, 40)
    _check(not _inside_cell() and player.global_position.x < CELL.position.x, "walking and jumping left leaves the cell again (%.0f, %.0f)" % [player.global_position.x, player.global_position.y])
    print("MARROW_CELL_ENTRY_TRACE walk=%.0f low=%.0f right=%.0f left=%.0f lift=%.0f enter=%.0f leave=%.0f" % [walk.extreme, low.extreme, right.extreme, left.extreme, lift.extreme, enter.extreme, leave.extreme])

    _release()
    preload("res://scripts/audio_retirement.gd").retire_tree(scene)
    scene.queue_free()
    await _physics(3)
    for name in DirAccess.get_files_at("user://"):
        if name.begins_with("marrow_cell_entry_validation.json"):
            DirAccess.remove_absolute("user://" + name)
    if failures.is_empty():
        print("MARROW_CELL_ENTRY_PASS checks=%d" % checks)
    else:
        for label in failures:
            push_error(label)
        print("MARROW_CELL_ENTRY_FAIL failures=%d checks=%d" % [failures.size(), checks])
    call_deferred("quit", 0 if failures.is_empty() else 1)
