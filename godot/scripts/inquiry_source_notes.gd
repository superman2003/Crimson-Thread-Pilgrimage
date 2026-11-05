extends RefCounted
## Presentation metadata for an already confirmed, exact inquiry version.
const PROOF := preload("res://scripts/testimony_sources.gd")
const HISTORY := preload("res://scripts/scene_history.gd")
const MAX_SOURCES := 12
static var _names: Dictionary = {}
static var _history: Dictionary = {}

static func _prepare() -> void:
    if _names.is_empty():
        var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/world_narrative.json"))
        if parsed is Dictionary:
            for id in parsed.get("npcs", {}):
                var name: Variant = parsed.npcs[id].get("display_name")
                if name is String and not name.strip_edges().is_empty():
                    _names[String(id)] = name
    if _history.is_empty():
        for row in HISTORY.all_entries():
            _history[String(row.id)] = true

static func speaker(npc: String) -> String:
    _prepare()
    return String(_names.get(npc, ""))

static func source_keys(sources: Variant) -> Array[String]:
    _prepare()
    var result: Array[String] = []
    if not sources is Array or sources.size() > MAX_SOURCES:
        return result
    for source in sources:
        if not source is Dictionary or not source.get("id") is String:
            continue
        var key := ""
        if source.get("kind") == "history" and _history.has(source.id):
            key = "evidence:" + HISTORY.FLAG_PREFIX + String(source.id)
        elif source.get("kind") == "item" and source.id in PROOF.IDS:
            key = "evidence:" + String(source.id)
        if not key.is_empty() and not result.has(key):
            result.append(key)
    return result

static func annotate(record: Dictionary, quote: Dictionary) -> Dictionary:
    var result := record.duplicate(true)
    var name := speaker(String(quote.get("npc", "")))
    if not name.is_empty():
        result["inquiry_speaker"] = name
        result["inquiry_npc"] = String(quote.get("npc", ""))
        result["description"] = "对话者：" + name + "\n\n" + String(record.get("description", ""))
    result["journal_source_keys"] = source_keys(quote.get("sources", []))
    return result
