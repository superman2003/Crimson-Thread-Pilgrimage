extends SceneTree
## G02 return-knot placement: the production Player on a real cave lift basket
## and on MainLevel-built ability gates never records an unreachable spot.
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const LEVEL_SCRIPT := preload("res://scripts/main_level.gd")
const LIFT_SCRIPT := preload("res://scripts/cave_lift.gd")
var checks := 0
var failures := 0
var level: Node2D
var player: CharacterBody2D

func _initialize() -> void:
    call_deferred("_run")

func _check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error(label)

func _frames(count: int) -> void:
    for _index in count:
        await physics_frame

## Stand the player on a support, let physics settle, then run the production
## per-frame update a few times while still (no input).
func _stand(at: Vector2) -> void:
    player.global_position = at
    player.velocity = Vector2.ZERO
    await _frames(8)
    for _index in 4:
        level._update_safe_ground()
        await _frames(1)

func _adopt(body: Node) -> Node:
    body.get_parent().remove_child(body)
    root.add_child(body)
    return body

func _gate(id: String, rect: Array, extra: Dictionary) -> Node:
    var data := {"id": id, "rect": rect, "material": "bronze_bridge"}
    data.merge(extra, true)
    level._region_gate(data)
    return _adopt(level.locked_gate_bodies[id])

func _run() -> void:
    level = LEVEL_SCRIPT.new()
    level.config = {"id": "placement_probe", "hazards": [{"id": "probe_spikes", "kind": "spikes", "rect": [1500, 178, 80, 24]}]}
    root.add_child(_static_box(Vector2(400, 214), Vector2(900, 24)))
    root.add_child(_static_box(Vector2(1550, 214), Vector2(300, 24)))
    player = PLAYER_SCENE.instantiate()
    root.add_child(player)
    player.feel = null
    level.player = player
    await _frames(2)

    await _stand(Vector2(200, 190))
    var floor_point: Vector2 = level.last_safe_ground
    _check(player.is_on_floor() and floor_point != Vector2.ZERO and absf(floor_point.x - 200.0) < 4.0, "standing still on permanent terrain records the return point")

    var lift: Node2D = LIFT_SCRIPT.new()
    root.add_child(lift)
    lift.configure({"id": "probe_lift", "x": 2400, "top_y": 120, "bottom_y": 600}, level)
    await _stand(Vector2(2400, 580))
    _check(player.is_on_floor(), "player stands on the production lift basket")
    _check(level.last_safe_ground == floor_point, "riding a lift basket never moves the return point into the shaft")

    var fragile := _gate("probe_fragile", [2900, 300, 200, 30], {"requires_action": "thorn_downstrike"})
    await _stand(Vector2(3000, 280))
    _check(player.is_on_floor() and fragile.is_in_group("fragile_terrain"), "player stands on a downstrike-breakable floor")
    _check(level.last_safe_ground == floor_point, "a breakable floor is not a safe return point")

    _gate("probe_locked", [3400, 300, 200, 30], {"required_ability": "silk_wall_grip"})
    await _stand(Vector2(3500, 280))
    _check(player.is_on_floor() and level.last_safe_ground == floor_point, "an openable ability gate is not a safe return point")

    _gate("probe_phase", [3900, 300, 200, 30], {"requires_action": "lantern_phase"})
    await _stand(Vector2(4000, 280))
    _check(player.is_on_floor() and level.last_safe_ground == floor_point, "a lantern-phase gate is not a safe return point")

    await _stand(Vector2(1540, 190))
    _check(player.is_on_floor() and level.last_safe_ground == floor_point, "ground beside spikes still keeps the earlier safe point")

    await _stand(Vector2(600, 190))
    _check(absf(level.last_safe_ground.x - 600.0) < 4.0, "returning to permanent terrain records again")
    lift.free()
    level.free()
    print("DEATH_CACHE_PLACEMENT checks=%d failures=%d" % [checks, failures])
    quit(0 if failures == 0 else 1)

func _static_box(position_value: Vector2, size: Vector2) -> StaticBody2D:
    var body := StaticBody2D.new()
    body.position = position_value
    body.collision_layer = 17
    body.collision_mask = 0
    var shape := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = size
    shape.shape = rectangle
    body.add_child(shape)
    return body
