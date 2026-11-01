extends RefCounted
## Area2D enemies need an explicit body sweep during authored attack movement.
static func constrain(actor: Area2D, start: Vector2, finish: Vector2) -> Vector2:
    if not start.is_finite() or not finish.is_finite(): return start
    var motion := finish - start
    if motion.length_squared() < 0.000001: return finish
    var box: Rect2 = actor.get_hurtbox_rect()
    var offset := box.get_center() - actor.global_position
    var level := actor.get_parent()
    if level.has_method("_ensure_collision_segment"): level._ensure_collision_segment(start + offset, finish + offset)
    var shape := RectangleShape2D.new(); shape.size = box.size
    var query := PhysicsShapeQueryParameters2D.new()
    query.shape = shape; query.transform = Transform2D(0, start + offset)
    query.motion = motion; query.collision_mask = 1
    query.collide_with_areas = false; query.exclude = [actor.get_rid()]
    query.margin = 0.5
    var fractions := actor.get_world_2d().direct_space_state.cast_motion(query)
    var fraction := float(fractions[0]) if fractions.size() == 2 else 0.0
    if level.has_method("_rock_ray_hit"):
        for y in [-0.5, 0.0, 0.5]:
            for x in [-0.5, 0.5]:
                var edge := offset + box.size * Vector2(x, y)
                var hit: Dictionary = level._rock_ray_hit(start + edge, finish + edge)
                if not hit.is_empty(): fraction = minf(fraction, preload("res://scripts/attack_sweep.gd").fraction(start + edge, finish + edge, hit.position))
    return start + motion * clampf(fraction, 0.0, 1.0)

static func contact(start: Vector2, finish: Vector2, attack: Rect2, target: Rect2) -> bool:
    var half := attack.size * 0.5
    var expanded := Rect2(target.position - half, target.size + attack.size)
    var offset := attack.get_center() - finish
    return preload("res://scripts/attack_sweep.gd").rect_time(start + offset, finish + offset, expanded) <= 1.0
