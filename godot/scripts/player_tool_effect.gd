extends Node2D
## Finite swept effects; tools never generate attack energy.
var payload: Dictionary = {}
var direction := 1
var owner_player: Node2D = null
var elapsed := 0.0
var travelled := 0.0
var targets: Dictionary = {}
var trap := false
var ballistic_velocity := Vector2.ZERO
var landed := false
var warning_timer := -1.0

func _ready() -> void:
    var id := String(payload.get("id", ""))
    trap = String(payload.get("kind", "")) == "trap" or id == "mine"
    if String(payload.get("kind", "")) == "snare_field":
        trap = true
    if trap:
        add_to_group("player_snare_field" if String(payload.get("kind", "")) == "snare_field" else "player_trap")
    if id == "shard":
        ballistic_velocity = Vector2(direction * 290.0, -270.0)
    var visual := Polygon2D.new()
    visual.polygon = PackedVector2Array([Vector2(-8, -5), Vector2(8, -5), Vector2(8, 5), Vector2(-8, 5)])
    visual.color = Color(0.86, 0.65, 0.28) if id in ["shard", "lure"] else Color(0.88, 0.86, 0.72)
    add_child(visual)

func _physics_process(delta: float) -> void:
    elapsed += delta
    var id := String(payload.get("id", ""))
    if elapsed >= float(payload.get("duration", 5.0)) or travelled >= float(payload.get("range", 420.0)) or not is_instance_valid(owner_player):
        queue_free()
        return
    var previous := global_position
    var next := previous
    if id == "shard" and not landed:
        ballistic_velocity.y += 700.0 * delta
        next += ballistic_velocity * delta
    elif not trap and id not in ["fog", "lure"] and not landed:
        next += Vector2(direction * 620.0 * delta, 0)
    if next != previous:
        if get_parent().has_method("_ensure_collision_segment"):
            get_parent()._ensure_collision_segment(previous, next)
        var ray := PhysicsRayQueryParameters2D.create(previous, next, 1, [owner_player.get_rid()])
        var hit := get_world_2d().direct_space_state.intersect_ray(ray)
        if get_parent().has_method("_rock_ray_hit"):
            var rock: Dictionary = get_parent()._rock_ray_hit(previous, next)
            if not rock.is_empty() and (hit.is_empty() or previous.distance_squared_to(rock.position) < previous.distance_squared_to(hit.position)):
                hit = rock
        if not hit.is_empty():
            global_position = hit.position
            if id == "shard":
                landed = true
                warning_timer = 0.35
                modulate = Color(1.0, 0.45, 0.15)
            else:
                queue_free()
                return
        else:
            global_position = next
    travelled += previous.distance_to(global_position)
    if id == "shard":
        if not landed:
            return
        warning_timer -= delta
        if warning_timer > 0.0:
            return
    if id == "lure":
        for enemy in get_tree().get_nodes_in_group("enemy"):
            if enemy.has_method("world_residency_active") and not enemy.world_residency_active(): continue
            if enemy is Node2D and enemy.global_position.distance_to(global_position) <= float(payload.get("range", 320.0)) and enemy.has_method("investigate_lure"):
                enemy.investigate_lure(global_position, 1.5)
        queue_free()
        return
    for enemy in get_tree().get_nodes_in_group("enemy"):
        if enemy.has_method("world_residency_active") and not enemy.world_residency_active():
            continue
        if not enemy is Node2D or not enemy.has_method("take_hit") or targets.has(enemy.get_instance_id()):
            continue
        var hurtbox: Rect2 = enemy.get_hurtbox_rect() if enemy.has_method("get_hurtbox_rect") else Rect2(enemy.global_position - Vector2(34,38), Vector2(68,76))
        var radius := 130.0 if id == "fog" else (75.0 if id == "shard" else (36.0 if trap else 8.0))
        var point := Geometry2D.get_closest_point_to_segment(hurtbox.get_center(), previous, global_position)
        if not hurtbox.grow(radius).has_point(point):
            continue
        if get_parent().has_method("_ensure_collision_segment"):
            get_parent()._ensure_collision_segment(global_position, hurtbox.get_center())
        var ray := PhysicsRayQueryParameters2D.create(global_position, hurtbox.get_center(), 1, [owner_player.get_rid()])
        if get_parent().has_method("_rock_ray_hit") and not get_parent()._rock_ray_hit(global_position, hurtbox.get_center()).is_empty():
            continue
        if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
            continue
        if id == "fog":
            if enemy.has_method("apply_target_interference"):
                enemy.apply_target_interference(2.0)
            continue
        targets[enemy.get_instance_id()] = true
        enemy.take_hit(maxi(1, int(payload.get("damage", 1))), direction)
        if bool(payload.get("salt_mark", false)) and enemy.has_method("apply_salt_mark"):
            enemy.apply_salt_mark(5.0)
        if float(payload.get("stagger", 0.0)) > 0.0 and enemy.has_method("apply_stagger"):
            enemy.apply_stagger(float(payload.stagger))
        if String(payload.get("kind", "")) == "snare_field" and enemy.has_method("apply_snare"):
            var control_duration := float(payload.get("duration", 1.5))
            if bool(payload.get("salt_consume", false)) and enemy.has_method("consume_salt_mark") and enemy.consume_salt_mark():
                control_duration += 1.5
            enemy.apply_snare(control_duration)
        elif trap and enemy.has_method("apply_trip"):
            enemy.apply_trip(0.7)
        elif trap and enemy.has_method("apply_snare"):
            enemy.apply_snare(1.5)
        if not trap and id != "shard" and String(payload.get("kind", "")) != "wave":
            queue_free()
            return
    if id == "shard" or id == "mine" and not targets.is_empty():
        queue_free()
