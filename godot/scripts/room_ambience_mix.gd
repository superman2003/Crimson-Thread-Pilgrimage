extends Node
## Room treatment belongs only to the continuous bed, upstream of user volume.
## Explicit room identities avoid treating every corridor or secret as indoors.
const FADE_SECONDS := 0.6
const OPEN_HZ := 20500.0
const SHELTER_HZ := 3200.0
const SHELTER_DB := -6.0
const BUS_PREFIX := "CrimsonRoomBed_"
const ROOMS := {
    "demo_ch01_moss_bell_court": {
        "open": ["east_balcony", "rain_overlook"],
        "sheltered": ["threadmakers_cache", "hidden_attic"]},
    "demo_ch02_rain_foundry_canal": {
        "open": ["rain_deck", "valve_overlook"],
        "sheltered": ["flume_crawl", "tide_listening_cell"]},
    "demo_ch03_saltwhite_archive": {
        "open": ["crest_bridge", "salt_dock"],
        "sheltered": ["sealed_stacks", "wax_seal_vault"]},
    "demo_ch04_broken_string_greenhouse": {
        "open": ["canopy_overlook", "victory_terrace"],
        "sheltered": ["beeswax_nook", "root_vault"]},
    "demo_ch05_obsidian_pilgrim_road": {
        "open": ["banner_bridge", "upper_switchback"],
        "sheltered": ["ravine_gate", "watch_tower"]},
    "demo_ch06_silent_crown_core": {
        "open": ["shell_walk_east", "crown_ribs"],
        "sheltered": ["echo_rain", "bell_tongue_vault"]},
}
var host_ref: WeakRef
var player_ref: WeakRef
var chapter := ""
var known_rooms: Dictionary = {}
var current_profile := "neutral"
var original_bus := "Ambience"
var bus_name := ""
var effect: AudioEffectLowPassFilter
var envelope: Tween
var generation := 0
var released := true

func configure(config: Dictionary, host: Node) -> void:
    release()
    chapter = String(config.get("id", ""))
    known_rooms.clear()
    for room in config.get("map_rooms", []):
        if room is Dictionary and room.get("id") is String:
            known_rooms[String(room.id)] = true
    host_ref = weakref(host) if is_instance_valid(host) else null
    released = false

func player_node() -> AudioStreamPlayer:
    var value: Variant = player_ref.get_ref() if player_ref != null else null
    return value as AudioStreamPlayer if is_instance_valid(value) else null

func bind_player(player: AudioStreamPlayer) -> bool:
    if released or not is_instance_valid(player):
        return false
    if player_node() == player:
        return true
    # A replacement player does not inherit another voice's route or envelope.
    _release_bus()
    player_ref = weakref(player)
    original_bus = String(player.bus)
    return update_room()

func room_profile(room_id: String) -> String:
    if not known_rooms.has(room_id):
        return "neutral"
    var profiles: Dictionary = ROOMS.get(chapter, {})
    for kind in ["open", "sheltered"]:
        if room_id in profiles.get(kind, []):
            return kind
    return "neutral"

func update_room() -> bool:
    var host: Variant = host_ref.get_ref() if host_ref != null else null
    if released or not is_instance_valid(host) or not host.is_inside_tree() or host.is_queued_for_deletion():
        return false
    return apply_profile(room_profile(String(host.get("current_room_id"))))

func _send_bus() -> String:
    return original_bus if AudioServer.get_bus_index(original_bus) >= 0 else "Master"

func owned_index() -> int:
    var index := AudioServer.get_bus_index(bus_name) if not bus_name.is_empty() else -1
    if index < 0 or effect == null:
        return -1
    for slot in AudioServer.get_bus_effect_count(index):
        if AudioServer.get_bus_effect(index, slot) == effect:
            return index
    return -1

func _stop_envelope() -> void:
    if envelope != null and envelope.is_valid():
        envelope.kill()
    envelope = null

func _ensure_bus() -> bool:
    var player := player_node()
    if player == null or not player.is_inside_tree() or player.is_queued_for_deletion():
        return false
    var index := owned_index()
    var send := _send_bus()
    AudioServer.lock()
    if index < 0:
        # Never replace a foreign bus, even if it reuses our previous name.
        bus_name = BUS_PREFIX + str(get_instance_id()) + "_" + str(generation)
        if AudioServer.get_bus_index(bus_name) >= 0:
            AudioServer.unlock()
            return false
        AudioServer.add_bus()
        index = AudioServer.bus_count - 1
        AudioServer.set_bus_name(index, bus_name)
        effect = AudioEffectLowPassFilter.new()
        effect.cutoff_hz = OPEN_HZ
        effect.resonance = 0.5
        AudioServer.add_bus_effect(index, effect)
        AudioServer.set_bus_volume_db(index, 0.0)
    # AudioServer sends right to left; layout changes may move the parent.
    if index <= AudioServer.get_bus_index(send):
        AudioServer.move_bus(index, -1)
        index = AudioServer.get_bus_index(bus_name)
    AudioServer.set_bus_send(index, send)
    player.bus = bus_name
    AudioServer.unlock()
    return true

func _set_gain(value: float) -> void:
    var index := owned_index()
    if index >= 0:
        AudioServer.set_bus_volume_db(index, value)

func _finish(serial: int, clear: bool) -> void:
    var index := owned_index()
    if not released and serial == generation and index >= 0:
        _enable_filter(index, not clear)

func _enable_filter(index: int, enabled: bool) -> void:
    for slot in AudioServer.get_bus_effect_count(index):
        if AudioServer.get_bus_effect(index, slot) == effect:
            AudioServer.set_bus_effect_enabled(index, slot, enabled)
            return

func apply_profile(profile: String, seconds: float = FADE_SECONDS) -> bool:
    if released or profile not in ["neutral", "open", "sheltered"] or not is_finite(seconds) or seconds < 0.0 or seconds > 5.0:
        return false
    if player_node() == null:
        return false
    generation += 1
    _stop_envelope()
    var clear := profile != "sheltered"
    current_profile = profile
    if clear and bus_name.is_empty():
        return true
    if not _ensure_bus():
        return false
    var index := owned_index()
    var gain := 0.0 if clear else SHELTER_DB
    var cutoff := OPEN_HZ if clear else SHELTER_HZ
    _enable_filter(index, true)
    if seconds == 0.0 or not is_inside_tree():
        _set_gain(gain)
        effect.cutoff_hz = cutoff
        _finish(generation, clear)
    else:
        envelope = create_tween().set_parallel(true)
        envelope.tween_method(_set_gain, AudioServer.get_bus_volume_db(index), gain, seconds)
        envelope.tween_property(effect, "cutoff_hz", cutoff, seconds)
        envelope.finished.connect(_finish.bind(generation, clear))
    return true

func _release_bus() -> void:
    generation += 1
    _stop_envelope()
    var player := player_node()
    AudioServer.lock()
    if player != null and String(player.bus) == bus_name:
        player.bus = _send_bus()
    var index := owned_index()
    if index >= 0:
        AudioServer.remove_bus(index)
    AudioServer.unlock()
    bus_name = ""
    effect = null
    player_ref = null

func release() -> void:
    released = true
    _release_bus()
    host_ref = null
    current_profile = "neutral"

func _exit_tree() -> void:
    release()
