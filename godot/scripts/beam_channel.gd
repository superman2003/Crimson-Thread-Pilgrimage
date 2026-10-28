extends RefCounted
## A conservative rectangular beam: an obstruction at either edge clips the
## entire visible channel, so painted danger and damaging reach share one end.
static func reach(effect: Node2D, maximum: float) -> float:
    var axis: Vector2 = effect.heading
    if not axis.is_finite() or axis.length_squared() < 0.000001 or not is_finite(maximum) or maximum < 0 or not is_finite(effect.radius) or effect.radius < 0: return -1.0
    axis = axis.normalized(); effect.heading = axis
    var side: Vector2 = axis.orthogonal() * effect.radius
    var result := maximum
    for offset in [-side, Vector2.ZERO, side]:
        var start: Vector2 = effect.global_position + offset
        var finish := start + axis * maximum
        var hit: Dictionary = effect._wave_wall(start, finish)
        if not hit.is_empty(): result = minf(result, start.distance_to(hit.position))
    return maxf(0, result)
