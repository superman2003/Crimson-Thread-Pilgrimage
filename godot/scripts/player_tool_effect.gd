extends Node2D
## Swept projectiles and finite, once-per-target traps. No energy gain from tools.
var payload: Dictionary = {}
var direction := 1
var owner_player: Node2D = null
var elapsed := 0.0
var travelled := 0.0
var targets: Dictionary = {}
var trap := false

func _ready() -> void:
    trap = String(payload.get("kind", "projectile")) == "trap"
    var visual := Polygon2D.new()
    visual.polygon = PackedVector2Array([Vector2(-8, -5), Vector2(8, -5), Vector2(8, 5), Vector2(-8, 5)])
    visual.color = Color(0.94, 0.55, 0.42) if not trap else Color(0.85, 0.75, 0.3)
    add_child(visual)

func _physics_process(delta: float) -> void:
    elapsed += delta
    var limit := float(payload.get("range", 340.0))
    if elapsed >= float(payload.get("duration", 3.0)) or travelled >= limit or not is_instance_valid(owner_player):
        queue_free()
        return
    var previous := global_position
    var next := previous if trap else previous + Vector2(direction * 620.0 * delta, 0)
    if not trap:
        var ray := PhysicsRayQueryParameters2D.create(previous, next, owner_player.collision_mask, [owner_player.get_rid()])
        var hit := get_world_2d().direct_space_state.intersect_ray(ray)
        if not hit.is_empty() and not hit.collider.is_in_group("enemy"):
            queue_free()
            return
    global_position = next
    travelled += previous.distance_to(next)
    for enemy in get_tree().get_nodes_in_group("enemy"):
        if not enemy is Node2D or not enemy.has_method("take_hit") or targets.has(enemy.get_instance_id()):
            continue
        var hurtbox := Rect2(enemy.global_position - Vector2(34, 38), Vector2(68, 76))
        if enemy.has_method("get_hurtbox_rect"):
            hurtbox = enemy.get_hurtbox_rect()
        var center := hurtbox.get_center()
        var point := Geometry2D.get_closest_point_to_segment(center, previous, next)
        var area := hurtbox.grow(50.0 if trap else 8.0)
        if not area.has_point(point):
            continue
        var ray := PhysicsRayQueryParameters2D.create(global_position, center, owner_player.collision_mask, [owner_player.get_rid()])
        var hit := get_world_2d().direct_space_state.intersect_ray(ray)
        if not hit.is_empty() and not hit.collider.is_in_group("enemy"):
            continue
        targets[enemy.get_instance_id()] = true
        enemy.take_hit(maxi(1, int(payload.get("damage", 1))), direction)
        if trap and enemy.has_method("apply_snare"):
            enemy.apply_snare(1.5)
        if not trap and targets.size() >= maxi(1, int(payload.get("pierce", 1))):
            queue_free()
            return
