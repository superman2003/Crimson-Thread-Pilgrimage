extends RefCounted
## Earliest contact uses existing gameplay radii and normalized physics-step time.
static func circle_time(start: Vector2,finish: Vector2,center: Vector2,radius: float) -> float:
    if not start.is_finite() or not finish.is_finite() or not center.is_finite() or not is_finite(radius) or radius<0:return INF
    var offset:=start-center
    var squared:=offset.length_squared()-radius*radius
    if squared<=0:return 0.0
    var step:=finish-start
    var length:=step.length_squared()
    if length<=0.000001:return INF
    var projection:=offset.dot(step)
    if projection>=0:return INF
    var discriminant:=projection*projection-length*squared
    if discriminant<0:return INF
    var time:=(-projection-sqrt(discriminant))/length
    return time if time>=0 and time<=1 else INF
static func fraction(start: Vector2,finish: Vector2,point: Vector2) -> float:
    var step:=finish-start
    return clampf((point-start).dot(step)/step.length_squared(),0,1) if step.length_squared()>0.000001 else 0.0

## Exact entry time for a point swept through an axis-aligned gameplay box.
static func rect_time(start: Vector2, finish: Vector2, box: Rect2) -> float:
    if not start.is_finite() or not finish.is_finite() or not box.position.is_finite() or not box.size.is_finite() or box.size.x <= 0 or box.size.y <= 0:
        return INF
    var step := finish - start
    var enter := 0.0
    var leave := 1.0
    for axis in range(2):
        if absf(step[axis]) < 0.000001:
            if start[axis] < box.position[axis] or start[axis] > box.end[axis]: return INF
            continue
        var near := (box.position[axis] - start[axis]) / step[axis]
        var far := (box.end[axis] - start[axis]) / step[axis]
        enter = maxf(enter, minf(near, far))
        leave = minf(leave, maxf(near, far))
        if enter > leave: return INF
    return enter if enter <= 1.0 and leave >= 0.0 else INF
