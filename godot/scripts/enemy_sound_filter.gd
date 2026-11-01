extends RefCounted
## A bounded shared bus for occluded ordinary enemy sounds.
## Danger/confirmation cues keep the original bus and remain unfiltered.
const BUS := "CrimsonEnemyOccluded"
const OWNER_KEY := "crimson_enemy_occlusion_filter"
const CUTOFF_HZ := 2400.0
const GAIN_DB := 0.0

static func fallback(preferred: String = "SFXEnemy") -> String:
    if AudioServer.get_bus_index(preferred) >= 0 and preferred != BUS:
        return preferred
    if AudioServer.get_bus_index("SFX") >= 0:
        return "SFX"
    return "Master"

static func owned_effect(index: int) -> AudioEffectLowPassFilter:
    if index < 0 or index >= AudioServer.bus_count:
        return null
    for slot in AudioServer.get_bus_effect_count(index):
        var effect := AudioServer.get_bus_effect(index, slot)
        if effect is AudioEffectLowPassFilter and effect.get_meta(OWNER_KEY, false) == true:
            return effect
    return null

static func ensure_bus(preferred: String = "SFXEnemy") -> String:
    var send := fallback(preferred)
    AudioServer.lock()
    var index := AudioServer.get_bus_index(BUS)
    if index >= 0:
        # Do not hijack a same-named bus belonging to a user/plugin layout.
        if owned_effect(index) == null:
            AudioServer.unlock()
            return send
        # Godot mixes right-to-left. A parent restored after this bus may now
        # lie to its right; move only our owned bus, retaining effect identity.
        if index <= AudioServer.get_bus_index(send):
            AudioServer.move_bus(index, -1)
            index = AudioServer.get_bus_index(BUS)
        if AudioServer.get_bus_send(index) != send:
            AudioServer.set_bus_send(index, send)
        AudioServer.unlock()
        return BUS
    AudioServer.add_bus()
    index = AudioServer.bus_count - 1
    AudioServer.set_bus_name(index, BUS)
    AudioServer.set_bus_send(index, send)
    AudioServer.set_bus_volume_db(index, GAIN_DB)
    var effect := AudioEffectLowPassFilter.new()
    effect.cutoff_hz = CUTOFF_HZ
    effect.resonance = 0.5
    effect.set_meta(OWNER_KEY, true)
    AudioServer.add_bus_effect(index, effect)
    AudioServer.unlock()
    return BUS

static func route(preferred: String, occluded: bool, priority: int) -> String:
    if not occluded or priority <= 0:
        return fallback(preferred)
    return ensure_bus(preferred)

static func describe(preferred: String, occluded: bool, priority: int) -> Dictionary:
    var bus := route(preferred, occluded, priority)
    var index := AudioServer.get_bus_index(bus)
    var effect := owned_effect(index)
    return {
        "bus":bus,
        "filtered":bus == BUS and effect != null,
        "cutoff_hz":effect.cutoff_hz if effect != null else 0.0,
        "send":String(AudioServer.get_bus_send(index)) if index >= 0 else "",
    }
