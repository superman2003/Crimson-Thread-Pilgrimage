extends RefCounted
## Art-space gait. Support motion exactly cancels the player's world travel.
## No random poses, limb scaling, or timing interpolation enters the IK solver.
const CYCLE_DISTANCE := 125.0
const STANCE := 0.34
const THIGH := 32.5
const SHIN := 32.5
const HIP := Vector2(198.0, 226.0)
const SOLE_Y := 280.0
const FOOT_SOLE := Vector2(0.0, 6.8)
## Authored half-stride: impact, compression, passing, push, toe-off, flight.
const WEIGHT_KEYS := [Vector2(0.0, 0.0), Vector2(0.07, 4.0), Vector2(0.16, 2.0),
    Vector2(0.28, -1.0), Vector2(0.34, -3.0), Vector2(0.41, -6.0), Vector2(0.5, 0.0)]

static func weight_height(phase: float) -> float:
    var t := fposmod(phase, 0.5)
    for index in range(WEIGHT_KEYS.size() - 1):
        var a: Vector2 = WEIGHT_KEYS[index]
        var b: Vector2 = WEIGHT_KEYS[index + 1]
        if t > b.x:
            continue
        var before: Vector2 = WEIGHT_KEYS[index - 1] if index > 0 else Vector2(WEIGHT_KEYS[-2].x - .5, WEIGHT_KEYS[-2].y)
        var after: Vector2 = WEIGHT_KEYS[index + 2] if index + 2 < WEIGHT_KEYS.size() else Vector2(WEIGHT_KEYS[1].x + .5, WEIGHT_KEYS[1].y)
        var length := b.x - a.x
        var tangent_a := (b.y - before.y) / (b.x - before.x) * length
        var tangent_b := (after.y - a.y) / (after.x - a.x) * length
        var u := (t - a.x) / length
        var u2 := u * u
        var u3 := u2 * u
        return (2.0 * u3 - 3.0 * u2 + 1.0) * a.y + (u3 - 2.0 * u2 + u) * tangent_a \
            + (-2.0 * u3 + 3.0 * u2) * b.y + (u3 - u2) * tangent_b
    return 0.0

static func _target(phase: float, art_scale: float, slope: float) -> Dictionary:
    var t := fposmod(phase, 1.0)
    var travel := CYCLE_DISTANCE / maxf(absf(art_scale), 0.01)
    var half := travel * STANCE * 0.5
    var x: float
    var lift := 0.0
    var foot_angle := 0.0
    var pivot := 0.0
    var contact_kind := "swing"
    var floor_angle := atan(slope)
    var planted := t <= STANCE
    if planted:
        # Constant world-space support velocity, including acceleration, slow
        # effects and carrier subtraction: phase itself is distance-driven.
        x = half - travel * t
        if t < .07:
            contact_kind = "heel"
            pivot = -4.0
            foot_angle = lerpf(-.14, 0.0, smoothstep(0.0, .07, t))
        elif t > .24:
            contact_kind = "toe"
            pivot = 12.0
            foot_angle = lerpf(0.0, .35, smoothstep(.24, STANCE, t))
        else:
            contact_kind = "flat"
    else:
        var u := (t - STANCE) / (1.0 - STANCE)
        var u2 := u * u
        var u3 := u2 * u
        var tangent := -travel * (1.0 - STANCE)
        x = (2.0 * u3 - 3.0 * u2 + 1.0) * -half + (u3 - 2.0 * u2 + u) * tangent \
            + (-2.0 * u3 + 3.0 * u2) * half + (u3 - u2) * tangent
        lift = 28.0 * (1.0 - exp(-4.5 * pow(sin(PI * u), 2.0))) / (1.0 - exp(-4.5))
        pivot = lerpf(12.0, -4.0, smoothstep(0.0, 1.0, u))
        foot_angle = lerpf(.35, -.35, smoothstep(0.0, .55, u)) if u < .55 else lerpf(-.35, -.14, smoothstep(.55, 1.0, u))
    var sole := Vector2(HIP.x + x, SOLE_Y - lift + (HIP.x + x - 192.0) * slope)
    foot_angle += floor_angle
    var contact := sole + Vector2(pivot, 0).rotated(floor_angle)
    var contact_local := FOOT_SOLE + Vector2(pivot, 0)
    var ankle := contact - contact_local.rotated(foot_angle)
    return {"sole": sole, "contact": contact, "contact_local": contact_local, "contact_kind": contact_kind,
        "ankle": ankle, "foot_angle": foot_angle, "planted": planted, "phase": t}

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
    var hip := HIP + Vector2(0, weight_height(t))
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
