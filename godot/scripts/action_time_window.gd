extends RefCounted
## Whether a forward simulation step crosses any of an authored active window.
## Recovery after the window is never turned into an additional active frame.
static func intersects(previous: float, current: float, start: float, length: float) -> bool:
    if not is_finite(previous) or not is_finite(current) or not is_finite(start) or not is_finite(length): return false
    return length > 0 and current > previous and current >= start and previous < start + length
static func contains(time: float, start: float, length: float) -> bool:
    return is_finite(time) and is_finite(start) and is_finite(length) and length > 0 and time >= start and time < start + length
