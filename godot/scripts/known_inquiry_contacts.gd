extends RefCounted
## Optional follow-ups for people whose speech is already durably known.
const PATH := "res://data/known_inquiry_contacts.json"
const INQUIRIES := preload("res://scripts/narrative_inquiries.gd")
const MEMORY := preload("res://scripts/npc_recollections.gd")
const CONTACTS := preload("res://scripts/quest_contacts.gd")
const REGIONS := preload("res://scripts/save_inspector.gd").REGION_NAMES
const PREFIX := "inquiry_contact_"
static var _data: Dictionary = {}
static var _rooms: Dictionary = {}

static func _prepare_rooms() -> void:
    if not _rooms.is_empty():
        return
    for region in REGIONS:
        var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + String(region) + ".json"))
        if not parsed is Dictionary:
            continue
        var places := {}
        for room in parsed.get("map_rooms", []):
            if room is Dictionary and room.get("id") is String and room.get("name") is String:
                places[String(room.id)] = String(room.name)
        _rooms[String(region)] = places

static func valid(data: Variant) -> bool:
    _prepare_rooms()
    if not data is Dictionary or data.size() != 2 or typeof(data.get("version")) not in [TYPE_INT, TYPE_FLOAT] or data.version != 1:
        return false
    if not data.get("homes") is Dictionary or data.homes.size() != CONTACTS.narrative().entries.size():
        return false
    for npc in CONTACTS.narrative().entries:
        var home: Variant = data.homes.get(npc)
        if not home is Dictionary or home.size() != 2 or not REGIONS.has(home.get("region")):
            return false
        if home.region != "demo_" + String(CONTACTS.narrative().entries[npc].region) or not _rooms.get(home.region, {}).has(home.get("room")):
            return false
    return true

static func catalog() -> Dictionary:
    if _data.is_empty() and FileAccess.file_exists(PATH):
        var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
        if valid(parsed):
            _data = parsed
    return _data.duplicate(true)

static func known(flags: Dictionary) -> Dictionary:
    var clean := CONTACTS.confirmed_flags(flags)
    var result := {}
    var memories := {}
    for row in MEMORY.records(clean):
        memories[String(row.id)] = true
    for npc in catalog().get("homes", {}):
        var id := MEMORY.PREFIX + String(npc).sha256_text()
        if memories.has(id):
            result[String(npc)] = "people:" + id
    # A confirmed optional inquiry also proves acquaintance even when the
    # player left the ordinary conversation before its own final confirmation.
    for row in INQUIRIES.records(clean):
        var npc := String(row.get("inquiry_npc", ""))
        if catalog().get("homes", {}).has(npc):
            result[npc] = "people:" + String(row.id)
    return result

static func location(npc: String, flags: Dictionary) -> Dictionary:
    var data := catalog()
    if not data.get("homes", {}).has(npc):
        return {}
    var state: Dictionary = CONTACTS.narrative().npc_world_state(npc, CONTACTS.confirmed_flags(flags))
    if state.get("visible") is bool and not state.visible:
        return {}
    var home: Dictionary = data.homes[npc]
    var region := String(state.get("region", home.region))
    if not region.begins_with("demo_"):
        region = "demo_" + region
    var room := String(state.get("room", home.room))
    if not REGIONS.has(region) or not _rooms.get(region, {}).has(room):
        return {}
    return {"region": region, "room": room, "place": String(REGIONS[region]) + " · " + String(_rooms[region][room])}

static func rows(inventory: Dictionary, flags: Dictionary) -> Array[Dictionary]:
    var clean := CONTACTS.confirmed_flags(flags)
    var held := CONTACTS.confirmed_inventory(inventory)
    var people := known(clean)
    var grouped := {}
    for entry in INQUIRIES.catalog():
        var npc := String(entry.npc)
        if not people.has(npc):
            continue
        var quote := INQUIRIES.quote(entry, held, clean)
        if quote.is_empty() or quote.recorded:
            continue
        if not grouped.has(npc):
            var place := location(npc, clean)
            if place.is_empty():
                continue
            grouped[npc] = place.merged({"npc": npc, "name": String(CONTACTS.narrative().entries[npc].display_name), "questions": [], "source_key": people[npc]})
        var previous := entry.duplicate(true)
        previous.erase("continuation")
        var base := INQUIRIES.quote(previous, held, clean)
        var expanded: bool = quote.expanded and not base.is_empty() and base.recorded
        grouped[npc].questions.append({"id": String(entry.id), "question": String(quote.question),
            "label": "有新线索可续问" if expanded else "已有线索可追问", "expanded": expanded})
    var result: Array[Dictionary] = []
    for npc in catalog().get("homes", {}):
        if grouped.has(npc):
            result.append(grouped[npc])
    return result

static func records(inventory: Dictionary, flags: Dictionary) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for row in rows(inventory, flags):
        var lines: Array[String] = ["可以自由回访已经谈过的人，问问手中的线索。阅读本页不会替你确认回答。", "\n当前去处：" + String(row.place)]
        for question in row.questions:
            lines.append("\n%s\n%s" % [question.label, question.question])
        result.append({"id": PREFIX + String(row.npc), "title": "回访 · " + String(row.name), "record_kind": "guide",
            "guide_context": "回访线索 · 已认识的人", "description": "\n".join(lines), "journal_source_keys": [String(row.source_key)]})
    return result
