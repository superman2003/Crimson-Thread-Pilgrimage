extends RefCounted
## The same provenance rule applies to gains, spending and capacity reductions:
## practice is consumed/discarded first, and only actual accepted income is tagged.
static func change(amount: int, energy: int, maximum: int, practice: int, practice_gain: bool = false) -> Dictionary:
    var before := maxi(0, energy)
    var after := clampi(before + amount, 0, maxi(0, maximum))
    var tagged := clampi(practice, 0, before)
    var removed := maxi(0, before - after)
    var accepted := maxi(0, after - before)
    tagged = maxi(0, tagged - removed)
    if practice_gain:
        tagged += accepted
    return {"energy":after, "practice":mini(after, tagged),
        "accepted":accepted, "removed":removed}

## Refund accounting is calculated before energy_changed can reenter Player.
## Practice thread follows only the amount that actually fits in the wallet.
static func settlement(cost: int, reserved_practice: int, loss_ratio: float,
        energy: int, maximum: int, practice: int) -> Dictionary:
    var paid := maxi(0, cost)
    var capacity := maxi(0, maximum)
    var balance := clampi(energy, 0, capacity)
    var old_practice := clampi(practice, 0, balance)
    # Unknown fractions must never manufacture an unearned refund.
    var ratio := clampf(loss_ratio, 0.0, 1.0) if is_finite(loss_ratio) else 1.0
    var loss := mini(paid, int(ceil(float(paid) * ratio)))
    var refundable := paid - loss
    var accepted := mini(refundable, capacity - balance)
    var practice_return := mini(accepted, clampi(reserved_practice, 0, paid))
    return {
        "paid":paid,
        "loss":loss,
        "refundable":refundable,
        "accepted":accepted,
        "overflow":refundable - accepted,
        "practice_return":practice_return,
        "energy_after":balance + accepted,
        "practice_after":old_practice + practice_return,
    }
