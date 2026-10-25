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
