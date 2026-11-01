extends RefCounted
## A room modifier leases an effect; it never becomes that effect's authored base.
## Metadata keeps only weak owners/tweens, so shared buses cannot retain scenes.
const KEY := &"crimson_room_reverb_lease"
var bindings: Dictionary = {}

func _owner(record: Dictionary) -> Object:
    var reference: Variant = record.get("owner")
    return reference.get_ref() if reference is WeakRef else null

static func _stop(record: Dictionary) -> void:
    var reference: Variant = record.get("tween")
    var tween: Variant = reference.get_ref() if reference is WeakRef else null
    if tween is Tween and tween.is_valid():
        tween.kill()

static func set_baseline(effect: AudioEffectReverb, wet: float) -> void:
    # Main installs a different authored preset before creating the next director.
    # End the old room lease so its fade/exit cannot overwrite the new chapter.
    _stop(effect.get_meta(KEY, {}))
    if effect.has_meta(KEY):
        effect.remove_meta(KEY)
    effect.wet = clampf(wet, 0.0, 1.0)

func _effect(bus: String) -> AudioEffectReverb:
    var reference: Variant = bindings.get(bus)
    return reference.get_ref() as AudioEffectReverb if reference is WeakRef else null

func capture(owner: Node, bus: String, effect: AudioEffectReverb) -> float:
    var previous := _effect(bus)
    if previous != null and previous != effect:
        _release_effect(owner, previous)
    bindings[bus] = weakref(effect)
    var record: Dictionary = effect.get_meta(KEY, {})
    var baseline := float(record.get("baseline", effect.wet))
    if _owner(record) != owner:
        # A new director inherits the authored base, not the old room's wet value.
        # Retire its predecessor's pending fade before installing another one.
        _stop(record)
        record = {"owner": weakref(owner), "baseline": baseline}
        effect.set_meta(KEY, record)
    return baseline

func fade(owner: Node, bus: String, effect: AudioEffectReverb, target: float, seconds: float) -> Tween:
    capture(owner, bus, effect)
    var record: Dictionary = effect.get_meta(KEY)
    _stop(record)
    record.erase("tween")
    target = clampf(target, 0.0, 1.0)
    var tween: Tween
    if owner.is_inside_tree():
        tween = owner.create_tween()
        tween.tween_property(effect, "wet", target, seconds)
        record["tween"] = weakref(tween)
    else:
        effect.wet = target
    effect.set_meta(KEY, record)
    return tween

func _release_effect(owner: Node, effect: AudioEffectReverb) -> void:
    var record: Dictionary = effect.get_meta(KEY, {})
    # Old queued regions may exit after their successor has claimed this bus.
    if _owner(record) != owner:
        return
    _stop(record)
    effect.wet = float(record.baseline)
    effect.remove_meta(KEY)

func release_bus(owner: Node, bus: String) -> void:
    var effect := _effect(bus)
    if effect != null:
        _release_effect(owner, effect)
    bindings.erase(bus)

func release(owner: Node) -> void:
    for bus: String in bindings.keys():
        release_bus(owner, bus)

