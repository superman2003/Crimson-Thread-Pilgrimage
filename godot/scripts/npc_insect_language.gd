extends RefCounted
## A character owns its timbre; the line selects a short nonverbal phrase.
const PATH := "res://data/npc_insect_language.json"
const ART := preload("res://scripts/hand_drawn_assets.gd")
static var _catalogue: Dictionary = {}

static func catalogue() -> Dictionary:
    if _catalogue.is_empty():
        var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
        if parsed is Dictionary: _catalogue = parsed
    return _catalogue

static func utterance(npc_id: String, line: String, profile: String = "warm") -> Dictionary:
    var actors: Dictionary = catalogue().get("actors", {})
    var actor := ART.npc_art_id(npc_id)
    if not actors.has(actor) or line.strip_edges().is_empty(): return {}
    var phrase := "explain_a" if line.hash() % 2 == 0 else "explain_b"
    if line.contains("？") or line.contains("?"):
        phrase = "question"
    elif line.contains("小心") or line.contains("危险") or line.contains("别碰"):
        phrase = "warning"
    elif line.contains("谢谢") or line.contains("放心") or line.contains("愿你"):
        phrase = "reassure"
    elif line.length() < 15:
        phrase = "greet"
    var result: Dictionary = actors[actor].clips[phrase].duplicate(true)
    result["actor_id"] = actor
    result["phrase_id"] = phrase
    var colour := {"warm": 1.0, "bright": 1.035, "low": 0.96, "hushed": 0.975, "dry": 0.99}
    result["pitch_scale"] = float(colour.get(profile, 1.0)) * (0.98 + float(line.hash() % 5) * 0.01)
    result["volume_db"] = -12.5 if profile == "hushed" else -9.5
    return result
