extends RefCounted
## A guard contact and a rejected hit are not a paid wound. Production Player
## returns its own result; legacy receivers can be observed through real HP.
enum Receipt { REJECTED, WOUND, LEGACY_CONTACT }

static func apply(target: Variant, amount: int, point: Vector2, blockable: bool) -> bool:
    return receive(target, amount, point, blockable) == Receipt.WOUND

static func receive(target: Variant, amount: int, point: Vector2, blockable: bool) -> Receipt:
    if not is_instance_valid(target) or target.is_queued_for_deletion() or not target.has_method("take_damage"):
        return Receipt.REJECTED
    var before: Variant = target.get("hp")
    var result: Variant = target.call("take_damage", amount, point, blockable)
    if result is bool:
        return Receipt.WOUND if result else Receipt.REJECTED
    if not is_instance_valid(target) or target.is_queued_for_deletion():
        return Receipt.REJECTED
    var after: Variant = target.get("hp")
    if (before is int or before is float) and (after is int or after is float):
        return Receipt.WOUND if float(after) < float(before) else Receipt.REJECTED
    # A legacy receiver without readable HP handled the callback, but cannot
    # confirm a paid wound for snare, rewards or other on-damage effects.
    return Receipt.LEGACY_CONTACT
