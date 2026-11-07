extends RefCounted
## Art-space gait. Support motion exactly cancels the player's world travel.
## No random poses, limb scaling, or timing interpolation enters the IK solver.
const CYCLE_DISTANCE := 95.0
const STANCE := 0.38
const THIGH := 31.0
const SHIN := 31.0
const HIP := Vector2(198.0, 226.0)
const SOLE_Y := 280.0
const FOOT_SOLE := Vector2(0.0, 6.8)

static func _target(phase: float, art_scale: float, slope: float) -> Dictionary:
    var t := fposmod(phase, 1.0)
    var travel := CYCLE_DISTANCE / maxf(absf(art_scale), 0.01)
    var half := travel * STANCE * 0.5
    var x: float
    var lift := 0.0
    var foot_angle := 0.0
    var planted := t <= STANCE
    if planted:
        # Constant world-space support velocity, including acceleration, slow
        # effects and carrier subtraction: phase itself is distance-driven.
        x = half - travel * t
    else:
        var u := (t - STANCE) / (1.0 - STANCE)
        var u2 := u * u
        var u3 := u2 * u
        var tangent := -travel * (1.0 - STANCE)
        x = (2.0 * u3 - 3.0 * u2 + 1.0) * -half + (u3 - 2.0 * u2 + u) * tangent \
            + (-2.0 * u3 + 3.0 * u2) * half + (u3 - u2) * tangent
        lift = 24.0 * pow(sin(PI * u), 2.0)
        foot_angle = -0.42 * sin(TAU * u) * sin(PI * u)
    var sole := Vector2(HIP.x + x, SOLE_Y - lift + (HIP.x + x - 192.0) * slope)
    var ankle := sole - FOOT_SOLE.rotated(foot_angle)
    return {"sole": sole, "ankle": ankle, "foot_angle": foot_angle, "planted": planted, "phase": t}

static func leg(phase: float, hip: Vector2, art_scale: float, slope: float = 0.0) -> Dictionary:
    var target := _target(phase, art_scale, slope)
    var ankle: Vector2 = target.ankle
    var delta := ankle - hip
    var distance := delta.length()
    # Refuse an unreachable art setup rather than silently stretching a bone.
    assert(distance > 0.001 and distance < THIGH + SHIN, "run rig target outside fixed-bone reach")
    var along := (THIGH * THIGH - SHIN * SHIN + distance * distance) / (2.0 * distance)
    var height := sqrt(maxf(0.0, THIGH * THIGH - along * along))
    var unit := delta / distance
    var knee := hip + unit * along + Vector2(unit.y, -unit.x) * height
    target.merge({"hip": hip, "knee": knee})
    return target

static func sample(phase: float, art_scale: float = 0.66, slope: float = 0.0) -> Dictionary:
    var t := fposmod(phase, 1.0)
    # Lower slightly under load; rise into the two short flight intervals.
    var hip := HIP + Vector2(0, 1.4 * sin(TAU * (2.0 * t - 0.10)))
    # On an incline the downhill contact can be farther from the pelvis.
    # Lower the shared pelvis within reach instead of lengthening either leg.
    for phase_offset in [0.0, 0.5]:
        var target := _target(t + phase_offset, art_scale, slope)
        var dx: float = target.ankle.x - hip.x
        var reach_y := sqrt(maxf(0.01, pow(THIGH + SHIN - 2.0, 2.0) - dx * dx))
        hip.y = maxf(hip.y, target.ankle.y - reach_y)
    return {"phase": t, "hip": hip,
        "near": leg(t, hip, art_scale, slope),
        "far": leg(t + 0.5, hip + Vector2(-1.0, 0), art_scale, slope)}
