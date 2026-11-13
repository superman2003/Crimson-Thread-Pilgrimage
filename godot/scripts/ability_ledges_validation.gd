extends SceneTree
## A01: every optional ability place in world_routes.json `ability_ledges`, rebuilt
## at its real coordinates (base floor, shelf, niche shell, bell plate, hook ring),
## is reached with real input only when its ability is used.
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const PLATFORM_BODY := preload("res://scripts/world_platform_body.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var routes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world_routes.json"))
    var places: Array = routes.get("ability_ledges", [])
    var kinds := {}
    for entry in places:
        kinds[String(entry.required_ability)] = true
    _check(kinds.has("double_thread_jump") and kinds.has("echo_hook") and kinds.has("crown_resonance"), "places cover double jump, echo hook and crown resonance")
    for entry in places:
        await _place(routes, entry)
    print("ABILITY_LEDGES checks=%d failures=%d" % [checks, failures])
    quit(0 if failures == 0 else 1)

func _place(routes: Dictionary, entry: Dictionary) -> void:
    var id := String(entry.id)
    var region := String(entry.region_id)
    var base_config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json" % region))
    var overlay: Dictionary = routes.chapters[region]
    var base := _find(base_config.platforms, String(entry.base_platform_id))
    var shelf := _find(overlay.platforms, String(entry.platform_id))
    _check(not base.is_empty() and not shelf.is_empty(), id + " base and shelf exist")
    if base.is_empty() or shelf.is_empty():
        return
    var base_rect := _rect(base.rect)
    var shelf_rect := _rect(shelf.rect)
    var bodies: Array = [
        PLATFORM_BODY.create("base", base_rect, String(base.get("collision_role", "floor"))),
        PLATFORM_BODY.create("shelf", shelf_rect, String(shelf.get("collision_role", "one_way"))),
    ]
    for part in ["roof", "wall_l", "wall_r"]:
        var piece := _find(overlay.platforms, id + "_" + part)
        if not piece.is_empty():
            bodies.append(PLATFORM_BODY.create(part, _rect(piece.rect), String(piece.collision_role)))
    var gate_body: StaticBody2D = null
    if entry.has("gate_id"):
        var gate := _find(overlay.locked_gates, String(entry.gate_id))
        _check(String(gate.get("requires_action", "")) == "crown_resonance", id + " bell plate opens only by the resonance action")
        gate_body = PLATFORM_BODY.create("bell", _rect(gate.rect), "")
        bodies.append(gate_body)
    var anchor: Node2D = null
    var ring := {}
    if entry.has("ring_id"):
        ring = _find(overlay.grapple_anchors, String(entry.ring_id))
        anchor = Node2D.new()
        anchor.position = _vec(ring.position)
        anchor.add_to_group("grapple_anchor")
        bodies.append(anchor)
    for body in bodies:
        root.add_child(body)
    await _frames(2)
    var floor_y := base_rect.position.y
    var shelf_y := shelf_rect.position.y
    var start := Vector2(shelf_rect.get_center().x, floor_y)
    match String(entry.required_ability):
        "double_thread_jump":
            _near(await _jump(start, false), floor_y, id + " a single jump falls back to the floor")
            _near(await _jump(start, true), shelf_y, id + " jump then air jump lands on the shelf")
        "echo_hook":
            _near(await _jump(start, true), floor_y, id + " even the double jump falls back to the floor")
            var hook_start := Vector2(float(ring.test_from[0]), floor_y)
            _near(await _hook(hook_start, false), floor_y, id + " without the hook the ring does nothing")
            _near(await _hook(hook_start, true), shelf_y, id + " aiming up at the ring pulls the body onto the shelf")
        "crown_resonance":
            _near(await _jump(start, true), floor_y, id + " the sealed bell plate stops every jump")
            gate_body.queue_free()
            await _frames(2)
            _near(await _jump(start, false), shelf_y, id + " once the plate opens a single jump lands on the shelf")
    for body in bodies:
        if is_instance_valid(body):
            body.queue_free()
    await _frames(2)

func _spawn(start: Vector2):
    var player = PLAYER_SCENE.instantiate()
    root.add_child(player)
    player.feel = null
    player.respawn_at(start)
    return player

## Jump; with `air` also press jump again near the apex. Returns resting feet y.
func _jump(start: Vector2, air: bool) -> float:
    var player = _spawn(start)
    player.double_jump_unlocked = air
    await _frames(6)
    Input.action_press("jump")
    await _frames(14)
    Input.action_release("jump")
    await _frames(2)
    Input.action_press("jump")
    await _frames(20)
    Input.action_release("jump")
    return await _settle(player)

func _hook(start: Vector2, unlocked: bool) -> float:
    var player = _spawn(start)
    player.thread_grapple_unlocked = unlocked
    await _frames(6)
    Input.action_press("aim_up")
    Input.action_press("hook")
    await _frames(2)
    print("HOOK_PROBE latched=%s position=%s ring=%s" % [player.grapple_timer > 0, player.global_position, player.grapple_anchor])
    Input.action_release("hook")
    for frame in range(36):
        await _frames(1)
        if frame % 6 == 0:
            print("HOOK_PROBE frame=%d position=%s velocity=%s pulling=%s" % [frame, player.global_position, player.velocity, player.grapple_timer > 0])
    Input.action_release("aim_up")
    # The ring hangs in the open shaft beside the shelf; step onto the shelf.
    Input.action_press("move_right")
    await _frames(24)
    Input.action_release("move_right")
    return await _settle(player)

func _settle(player) -> float:
    for index in range(90):
        await _frames(1)
        if index > 20 and player.is_on_floor() and absf(player.velocity.y) < 1.0:
            break
    var rest: float = player.global_position.y if player.is_on_floor() else INF
    player.queue_free()
    await _frames(2)
    return rest

func _near(value: float, target: float, label: String) -> void:
    _check(absf(value - target) < 4.0, label + " (y=%.1f, expected %.1f)" % [value, target])

func _find(list: Array, id: String) -> Dictionary:
    for item in list:
        if String(item.get("id", "")) == id:
            return item
    return {}

func _rect(values: Array) -> Rect2:
    return Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))

func _vec(values: Array) -> Vector2:
    return Vector2(float(values[0]), float(values[1]))

func _frames(count: int) -> void:
    for index in range(count):
        await physics_frame
        await process_frame

func _check(condition: bool, label: String) -> void:
    checks += 1
    if condition:
        print("PASS: " + label)
    else:
        failures += 1
        push_error("FAIL: " + label)
