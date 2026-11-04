extends RefCounted
## Recognition follows a defeated guardian and exact, already committed speech.
const PATH := "res://data/guardian_identities.json"
const INQUIRIES := preload("res://scripts/narrative_inquiries.gd")
const REGIONS := preload("res://scripts/save_inspector.gd").REGION_NAMES
const PREFIX := "guardian_identity_"
static var _data: Dictionary = {}

static func _text(value: Variant, maximum: int) -> bool:
    return value is String and not value.strip_edges().is_empty() and value.length() <= maximum and not value.contains("\n")

static func valid(data: Variant) -> bool:
    if not data is Dictionary or data.size() != 2 or typeof(data.get("version")) not in [TYPE_INT, TYPE_FLOAT] or data.version != 1:
        return false
    if not data.get("entries") is Array or data.entries.size() != 6:
        return false
    var ids := {}
    var regions := {}
    var topics := {}
    for entry in INQUIRIES.catalog():
        topics[String(entry.id)] = entry
    for row in data.entries:
        if not row is Dictionary or row.size() != 7 or not _text(row.get("id"), 48) or not row.id.is_valid_identifier() or ids.has(row.id):
            return false
        ids[row.id] = true
        if not _text(row.get("region"), 80) or regions.has(row.region) or not _text(row.get("boss_flag"), 32):
            return false
        if not REGIONS.has(row.region) or row.boss_flag != "boss_down_" + String(row.region).trim_prefix("demo_").get_slice("_", 0) or row.id != "chapter_" + String(row.region).substr(7, 2):
            return false
        regions[row.region] = true
        for field in ["title", "recognition", "limit"]:
            if not _text(row.get(field), 180):
                return false
        if not row.get("accounts") is Array or row.accounts.is_empty() or row.accounts.size() > 3:
            return false
        var seen := {}
        for account in row.accounts:
            if not account is Dictionary or account.size() != 2 or not topics.has(account.get("inquiry")) or seen.has(account.inquiry):
                return false
            if not String(account.inquiry).begins_with(String(row.id) + "_"):
                return false
            seen[account.inquiry] = true
            if not account.get("lines") is Array or account.lines.is_empty() or account.lines.size() > 2:
                return false
            for line in account.lines:
                if not _text(line, 360) or line not in topics[account.inquiry].lines:
                    return false
    return true

static func catalog() -> Dictionary:
    if _data.is_empty() and FileAccess.file_exists(PATH):
        var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
        if valid(parsed):
            _data = parsed
    return _data.duplicate(true)

static func records(flags: Dictionary) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var has_memory := false
    for key in flags:
        if String(key).begins_with(INQUIRIES.PREFIX) and flags[key] is bool and flags[key]:
            has_memory = true
            break
    if not has_memory:
        return result
    var memories := INQUIRIES.records(flags)
    for row in catalog().get("entries", []):
        if not flags.get(row.boss_flag) is bool or not flags[row.boss_flag]:
            continue
        var keys: Array[String] = []
        for account in row.accounts:
            var confirmed := {}
            for memory in memories:
                if memory.get("inquiry_id") != account.inquiry:
                    continue
                var supports := true
                for line in account.lines:
                    supports = supports and memory.get("inquiry_lines", []).has(line)
                if supports and (confirmed.is_empty() or memory.get("inquiry_expanded", false)):
                    confirmed = memory
            if confirmed.is_empty():
                break
            keys.append("people:" + String(confirmed.id))
        if keys.size() != row.accounts.size():
            continue
        result.append({"id": PREFIX + String(row.id), "title": "辨认 · " + String(row.title), "record_kind": "guide",
            "guide_context": "战后辨认 · 已确认交谈", "description": String(row.recognition) + "\n\n证言的边界\n" + String(row.limit)
                + "\n\n这些辨认来自已经听完并保存的追问；可以回看当时的原话，不替说话者补写答案。",
            "journal_source_keys": keys})
    return result
