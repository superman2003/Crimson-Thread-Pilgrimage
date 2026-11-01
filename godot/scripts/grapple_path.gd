extends RefCounted
## Selection and continued pull use exactly the same streamed path contract.
static func available(anchor: Variant) -> bool:
    return is_instance_valid(anchor) and anchor is Node2D and anchor.is_inside_tree() and not anchor.is_queued_for_deletion() and anchor.is_visible_in_tree() and anchor.global_position.is_finite() and bool(anchor.get_meta("grapple_enabled", true))
static func clear(player: CharacterBody2D, anchor: Node2D) -> bool:
    if not available(anchor) or not player.is_inside_tree(): return false
    var start := player.global_position + Vector2(0, -42)
    var finish := anchor.global_position
    if not start.is_finite(): return false
    var level := player.get_parent()
    if level.has_method("_ensure_collision_segment"): level._ensure_collision_segment(start, finish)
    if level.has_method("_rock_ray_hit") and not level._rock_ray_hit(start, finish).is_empty(): return false
    var query := PhysicsRayQueryParameters2D.create(start, finish, player.collision_mask, [player.get_rid()])
    query.collide_with_areas = false
    var obstruction := player.get_world_2d().direct_space_state.intersect_ray(query)
    return obstruction.is_empty() or obstruction.get("collider") == anchor
static func preferred(score: float, anchor: Node2D, best_score: float, best: Node2D) -> bool:
    if not is_finite(score): return false
    if not is_instance_valid(best): return true
    return score < best_score if not is_equal_approx(score, best_score) else String(anchor.get_path()) < String(best.get_path())
