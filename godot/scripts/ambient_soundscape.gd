extends RefCounted
## Sparse diegetic accents have authored origins; the diffuse chapter bed stays
## non-positional. Only the active region's small catalogue is held here.
const VOICE := preload("res://scripts/spatial_ambience_voice.gd")
const RETIREMENT := preload("res://scripts/audio_retirement.gd")
const RANGE := 900.0
const REFRESH_MS := 100
const MAX_VOICES := 2
const SOURCE_GAP_MS := 12000
# Normalised anchors are authored inside named production rooms, never inferred
# from a player's location or an unknown neighbouring region. Variants match the
# existing generated pack: dripping moss, rain/metal, pages/salt, glass/strings,
# flags/stone, and crown metal/threads. No speech or player-heartbeat is placed.
const PROFILES := {
    "demo_ch01_moss_bell_court": [
        {"room":"court_hub", "anchor":Vector2(0.55,0.80), "variants":[1,4,6]},
        {"room":"rust_crown_hall", "anchor":Vector2(0.72,0.48), "variants":[2,7,8]},
    ],
    "demo_ch02_rain_foundry_canal": [
        {"room":"pump_atrium", "anchor":Vector2(0.55,0.70), "variants":[2,3,7]},
        {"room":"smith_arena", "anchor":Vector2(0.70,0.45), "variants":[1,4,5]},
        {"room":"furnace_floor", "anchor":Vector2(0.60,0.48), "family":"anvil", "variants":[]},
    ],
    "demo_ch03_saltwhite_archive": [
        {"room":"atrium_shaft", "anchor":Vector2(0.55,0.55), "variants":[1,3,4]},
        {"room":"mantis_court", "anchor":Vector2(0.70,0.48), "variants":[3,6,7]},
    ],
    "demo_ch04_broken_string_greenhouse": [
        {"room":"tree_heart", "anchor":Vector2(0.55,0.60), "variants":[2,6,7]},
        {"room":"fracture_dome", "anchor":Vector2(0.70,0.45), "variants":[1,5,6]},
    ],
    "demo_ch05_obsidian_pilgrim_road": [
        {"room":"pilgrim_camp", "anchor":Vector2(0.55,0.55), "variants":[1,2,5]},
        {"room":"mirror_pool", "anchor":Vector2(0.70,0.45), "variants":[4,6,8]},
    ],
    "demo_ch06_silent_crown_core": [
        {"room":"crown_antechamber", "anchor":Vector2(0.55,0.48), "variants":[1,2,6]},
        {"room":"silent_throne", "anchor":Vector2(0.70,0.45), "variants":[2,6,8]},
    ],
}
var sources: Array[Dictionary] = []
var voices: Array[AudioStreamPlayer2D] = []
var host_ref: WeakRef
var chapter := ""
var transitioning := false
var next_refresh_ms := 0
var source_times: Dictionary = {}

func configure(config: Dictionary, host: Node2D) -> void:
    clear()
    if not is_instance_valid(host) or not host.is_inside_tree():
        return
    var id := String(config.get("id", ""))
    if not PROFILES.has(id):
        return
    var rooms: Variant = config.get("map_rooms", [])
    if not rooms is Array:
        return
    chapter = id.substr(5, 4)
    host_ref = weakref(host)
    for profile in PROFILES[id]:
        var matches: Array = rooms.filter(func(room): return room is Dictionary and room.get("id") == profile.room)
        if matches.size() != 1:
            continue
        var rect: Variant = matches[0].get("layout_rect", [])
        if not valid_rect(rect):
            continue
        var bounds := Rect2(float(rect[0]),float(rect[1]),float(rect[2]),float(rect[3]))
        sources.append({"id":profile.room, "position":bounds.position+bounds.size*profile.anchor,
            "family":profile.get("family","regional"), "variants":profile.variants.duplicate()})

static func valid_rect(value: Variant) -> bool:
    if not value is Array or value.size() != 4:
        return false
    for number in value:
        if not (number is int or number is float) or not is_finite(float(number)):
            return false
    return value[2] > 0 and value[3] > 0

func host_node() -> Node2D:
    var host: Variant = host_ref.get_ref() if host_ref != null else null
    if not is_instance_valid(host) or not host is Node2D or not host.is_inside_tree() or host.is_queued_for_deletion():
        return null
    return host

func allowed(director: Node, listener: Node2D) -> bool:
    var host := host_node()
    if host == null or not is_instance_valid(director) or not director.is_inside_tree() or director.is_queued_for_deletion():
        return false
    if director.instance != director or not director.autoplay_enabled or transitioning:
        return false
    if not is_instance_valid(listener) or not listener.is_inside_tree() or listener.is_queued_for_deletion():
        return false
    if listener.get_world_2d() != host.get_world_2d() or not listener.global_position.is_finite():
        return false
    if director.dialogue_open or director.combat_active or director.boss_active or director.shrine_engaged:
        return false
    if director.get_user_volume("master") <= 0 or director.get_user_volume("ambience") <= 0:
        return false
    if listener.get("ui_input_locked") == true:
        return false
    var hp: Variant = listener.get("hp")
    return not ((hp is int or hp is float) and hp <= 0)

func nearby(listener: Node2D, family: String, now: int) -> Dictionary:
    var host := host_node()
    if host == null or not is_instance_valid(listener):
        return {}
    var selected := {}
    var nearest := RANGE * RANGE
    for source in sources:
        if source.family != family or now-int(source_times.get(source.id,-SOURCE_GAP_MS)) < SOURCE_GAP_MS:
            continue
        var position := host.to_global(source.position)
        if not position.is_finite():
            continue
        var distance := position.distance_squared_to(listener.global_position)
        if distance < nearest:
            nearest = distance
            selected = source
    return selected

func play_nearby(director: Node, listener: Node2D, base_db: float, family: String = "regional") -> bool:
    prune()
    if not is_finite(base_db) or not allowed(director,listener) or voices.size() >= MAX_VOICES:
        return false
    var now := Time.get_ticks_msec()
    var source := nearby(listener,family,now)
    if source.is_empty():
        return false
    var path := "res://assets/audio/ambience/amb_ch02_anvil_far.ogg"
    if family == "regional":
        var variants: Array = source.variants
        path = "res://assets/audio/ambience/amb_%s_os_%d.ogg" % [chapter, variants.pick_random()]
    elif family != "anvil":
        return false
    # Background accents are below enemy warnings/NPC cues in the existing
    # shared voice budget. No allocation or decode occurs for distant sources.
    var ticket: int = director.reserve_voice("amb_oneshot",3,250,MAX_VOICES)
    if ticket == 0:
        return false
    var stream: AudioStream = director.load_cached(path)
    if stream == null:
        director.release_ticket(ticket)
        return false
    var voice := VOICE.new()
    voice.name = "SpatialAmbience"
    voice.set_meta("ambient_source",source.id)
    voice.set_meta("ambient_local_position",source.position)
    voice.stream = stream
    director.add_child(voice)
    if not voice.place(host_node().to_global(source.position),listener,base_db):
        voice.free()
        director.release_ticket(ticket)
        return false
    voice.finished.connect(voice.queue_free)
    if not director.start_reserved_voice(ticket,voice):
        voice.free()
        director.release_ticket(ticket)
        return false
    voices.append(voice)
    source_times[source.id] = now
    return true

func prune() -> void:
    for index in range(voices.size()-1,-1,-1):
        var voice := voices[index]
        if not is_instance_valid(voice):
            voices.remove_at(index)
        elif voice.is_queued_for_deletion() or not voice.playing:
            retire(voice)
            voices.remove_at(index)

func tick(director: Node, listener: Node2D) -> void:
    prune()
    if not allowed(director,listener):
        stop()
        return
    var now := Time.get_ticks_msec()
    if now < next_refresh_ms:
        return
    next_refresh_ms = now + REFRESH_MS
    # At most MAX_VOICES=2 physics rays per refresh, independent of frame rate.
    var host := host_node()
    for voice in voices.duplicate():
        if not voice.refresh_spatial(host.to_global(voice.get_meta("ambient_local_position")),listener):
            retire(voice)
            voices.erase(voice)

func retire(voice: AudioStreamPlayer2D) -> void:
    if not is_instance_valid(voice):
        return
    RETIREMENT.watch_player(voice)
    voice.stop()
    voice.stream = null
    voice.queue_free()

func stop() -> void:
    for voice in voices:
        retire(voice)
    voices.clear()
    next_refresh_ms = 0

func clear() -> void:
    stop()
    sources.clear()
    source_times.clear()
    host_ref = null
    chapter = ""
    transitioning = false
