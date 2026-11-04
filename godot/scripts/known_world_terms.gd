extends RefCounted
## A bounded glossary derived from held originals; never a second quest gate.
const PATH := "res://data/known_world_terms.json"
const PROOF := preload("res://scripts/testimony_sources.gd")
const PREFIX := "world_term_"
static var _data: Dictionary = {}

static func _text(value: Variant, maximum: int) -> bool:
    return value is String and not value.strip_edges().is_empty() and value.length() <= maximum and not value.contains("\n")

static func valid(data: Variant) -> bool:
    if not data is Dictionary or data.size() != 2 or typeof(data.get("version")) not in [TYPE_INT, TYPE_FLOAT] or data.version != 1:
        return false
    if not data.get("entries") is Array or data.entries.is_empty() or data.entries.size() > 16:
        return false
    var ids := {}
    for row in data.entries:
        if not row is Dictionary or row.size() != 3 or not _text(row.get("id"), 48) or not row.id.is_valid_identifier() or ids.has(row.id):
            return false
        ids[row.id] = true
        if not _text(row.get("title"), 24) or not row.get("stages") is Array or row.stages.is_empty() or row.stages.size() > 3:
            return false
        var previous: Array = []
        for stage in row.stages:
            if not stage is Dictionary or stage.size() != 3 or not _text(stage.get("definition"), 160) or not _text(stage.get("limit"), 140):
                return false
            var evidence: Variant = stage.get("evidence_all")
            if not evidence is Array or evidence.is_empty() or evidence.size() > PROOF.IDS.size():
                return false
            var seen := {}
            for id in evidence:
                if id not in PROOF.IDS or seen.has(id):
                    return false
                seen[id] = true
            if evidence.size() <= previous.size():
                return false
            for id in previous:
                if id not in evidence:
                    return false
            previous = evidence
    return true

static func catalog() -> Dictionary:
    if _data.is_empty() and FileAccess.file_exists(PATH):
        var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
        if valid(parsed):
            _data = parsed
    return _data.duplicate(true)

static func records(inventory: Dictionary) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for row in catalog().get("entries", []):
        var chosen := {}
        for stage in row.stages:
            var ready := true
            for id in stage.evidence_all:
                ready = ready and PROOF.owns(inventory, String(id))
            if ready:
                chosen = stage
        if chosen.is_empty():
            continue
        var keys: Array[String] = []
        for id in chosen.evidence_all:
            keys.append("evidence:" + String(id))
        result.append({"id": PREFIX + String(row.id), "title": "辞记 · " + String(row.title), "record_kind": "guide",
            "guide_context": "世界辞记 · 已有证词", "description": String(chosen.definition) + "\n\n仍不能据此断言\n" + String(chosen.limit)
                + "\n\n这里只整理亲手取得的证词；新发现可能补充理解，阅读本身不会取得证物或推进委托。",
            "journal_source_keys": keys})
    return result
