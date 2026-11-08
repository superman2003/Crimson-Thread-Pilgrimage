extends RefCounted
## Durations are normalized to N, preserving the existing phase clock and its
## speed_scale contract. Only the distribution within windup/recovery changes.
static func weights(count: int, duration: float, phase: String, authored_fps: float) -> PackedFloat32Array:
    var result := PackedFloat32Array()
    if count <= 0:
        return result
    result.resize(count)
    result.fill(1.0)
    if phase not in ["windup", "recover"] or count < 2 or not is_finite(duration) or duration <= 0.0:
        return result
    var step := minf(duration / count, 1.0 / maxf(12.0, authored_fps))
    var hold := count - 1 if phase == "windup" else 0
    for index in count:
        var seconds := duration - step * (count - 1) if index == hold else step
        result[index] = seconds * count / duration
    return result

static func cursor(frames: SpriteFrames, animation: StringName, speed_scale: float, elapsed: float) -> Vector2:
    var count := frames.get_frame_count(animation)
    var rate := frames.get_animation_speed(animation) * speed_scale
    if count <= 0 or rate <= 0.0:
        return Vector2.ZERO
    var remaining := maxf(0.0, elapsed)
    for index in count:
        var seconds := frames.get_frame_duration(animation, index) / rate
        if remaining < seconds or index == count - 1:
            return Vector2(index, clampf(remaining / maxf(seconds, .00001), 0.0, 1.0))
        remaining -= seconds
    return Vector2(count - 1, 1)
