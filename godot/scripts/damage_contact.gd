extends RefCounted
## A guard contact and a rejected hit are not a paid wound. Production Player
## returns its own result; legacy receivers can be observed through real HP.
static func apply(target: Variant, amount: int, point: Vector2, blockable: bool) -> bool:
    if not is_instance_valid(target) or target.is_queued_for_deletion() or not target.has_method("take_damage"): return false
    var before: Variant = target.get("hp")
    var result: Variant = target.call("take_damage", amount, point, blockable)
    if result is bool: return result
    if not is_instance_valid(target) or target.is_queued_for_deletion(): return false
    var after: Variant = target.get("hp")
    return (before is int or before is float) and (after is int or after is float) and float(after) < float(before)
