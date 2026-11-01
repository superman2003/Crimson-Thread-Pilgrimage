extends RefCounted
const VALUES := preload("res://journey/core/values.gd")
const LIMIT := 240
const KINDS := {"room":"抵达房间", "region":"抵达地区", "shrine":"钟龛停留", "return":"返回旅途", "milestone":"永久成长", "note":"手记"}

static func fresh() -> Dictionary:
    return {"version":1, "sequence":0, "events":[], "favorites":[], "notes":{}, "last_region":"", "last_room":"", "last_shrine":false, "earned":{}}

static func valid(data: Dictionary) -> bool:
    if data.get("version") != 1 or not VALUES.count(data.get("sequence")):
        return false
    if not data.get("events") is Array or data.events.size() > LIMIT:
        return false
    if not data.get("favorites") is Array or data.favorites.size() > LIMIT:
        return false
    if not data.get("notes") is Dictionary or data.notes.size() > LIMIT:
        return false
    if not data.get("earned") is Dictionary or not data.get("last_shrine") is bool:
        return false
    for field in ["last_region", "last_room"]:
        if not data.get(field) is String or data[field].length() > 200:
            return false
    var ids := {}
    for event in data.events:
        if not event is Dictionary:
            return false
        if not VALUES.count(event.get("id")) or int(event.id) <= 0 or int(event.id) > int(data.sequence) or ids.has(str(int(event.id))):
            return false
        if not KINDS.has(event.get("kind")) or not event.get("title") is String:
            return false
        if not VALUES.count(event.get("time"), 9999999999):
            return false
        if not event.get("region") is String or not event.get("room") is String:
            return false
        ids[str(int(event.id))] = true
    for id in data.favorites:
        if not id is String or not ids.has(id):
            return false
    for id in data.notes:
        if not ids.has(id) or not data.notes[id] is String or data.notes[id].length() > 800:
            return false
    return VALUES.json_safe(data, 0, [VALUES.MAX_ITEMS])

static func append(data: Dictionary, kind: String, title: String, snapshot: Dictionary) -> Dictionary:
    var result := data.duplicate(true)
    if not KINDS.has(kind) or VALUES.text(title, 120).is_empty() or int(result.sequence) >= 1000000:
        return result
    result.sequence = int(result.sequence) + 1
    var event := {
        "id":result.sequence,
        "kind":kind,
        "title":VALUES.text(title, 120),
        "time":int(snapshot.get("timestamp", Time.get_unix_time_from_system())),
        "region":String(snapshot.get("region", "")),
        "region_name":String(snapshot.get("region_name", "")),
        "room":String(snapshot.get("room", "")),
        "wallet":int(snapshot.get("wallet", 0))
    }
    result.events.append(event)
    while result.events.size() > LIMIT:
        var removed: Dictionary = result.events.pop_front()
        var id := str(int(removed.id))
        result.favorites.erase(id)
        result.notes.erase(id)
    return result

static func observe(data: Dictionary, snapshot: Dictionary) -> Dictionary:
    if snapshot.is_empty() or String(snapshot.get("region", "")).is_empty():
        return data.duplicate(true)
    var result := data.duplicate(true)
    var region := String(snapshot.region)
    var room := String(snapshot.get("room", ""))
    if region != result.last_region:
        result = append(result, "region", "抵达「" + String(snapshot.get("region_name", region)) + "」", snapshot)
    if not room.is_empty() and (room != result.last_room or region != result.last_region):
        var title := room
        for record in snapshot.get("config", {}).get("map_rooms", []):
            if String(record.get("id", "")) == room:
                title = String(record.get("name", room))
                break
        result = append(result, "room", "走进「" + title + "」", snapshot)
    var shrine: bool = snapshot.get("at_shrine", false) is bool and snapshot.get("at_shrine", false)
    if shrine and not result.last_shrine:
        result = append(result, "shrine", "钟龛旁的停留", snapshot)
    var catalog: Dictionary = preload("res://journey/core/public_catalog.gd").items(snapshot)
    var inventory: Dictionary = snapshot.get("inventory", {})
    for id in inventory:
        if not VALUES.held(inventory[id]) or bool(result.earned.get(id, false)):
            continue
        if not catalog.get(id) is Dictionary:
            continue
        var item: Dictionary = catalog[id]
        if String(item.get("category", item.get("kind", ""))) not in ["ability", "key", "quest"] and not String(id).begins_with("relic_"):
            continue
        result.earned[id] = true
        result = append(result, "milestone", "记下「" + String(item.get("name", id)) + "」", snapshot)
    result.last_region = region
    result.last_room = room
    result.last_shrine = shrine
    return result

static func records(data: Dictionary, query: String, kind: String = "all", favorites_only: bool = false, newest: bool = true) -> Array:
    var result := []
    for event in data.events:
        var id := str(int(event.id))
        if kind != "all" and event.kind != kind:
            continue
        if favorites_only and not data.favorites.has(id):
            continue
        if not VALUES.matches(query, [String(event.title), String(event.get("region_name", "")), String(data.notes.get(id, "")), String(KINDS.get(event.kind, ""))]):
            continue
        var row: Dictionary = event.duplicate(true)
        row["favorite"] = data.favorites.has(id)
        row["note"] = String(data.notes.get(id, ""))
        result.append(row)
    result.sort_custom(func(a: Dictionary, b: Dictionary):return int(a.id) > int(b.id) if newest else int(a.id) < int(b.id))
    return result

static func annotate(data: Dictionary, id: String, note: String, favorite: bool) -> Dictionary:
    var result := data.duplicate(true)
    var found := false
    for event in result.events:
        if str(int(event.id)) == id:
            found = true
            break
    if not found:
        return result
    var clean := VALUES.text(note, 800)
    if clean.is_empty():
        result.notes.erase(id)
    else:
        result.notes[id] = clean
    result.favorites.erase(id)
    if favorite:
        result.favorites.append(id)
    return result

static func statistics(data: Dictionary) -> Dictionary:
    var regions := {}
    var rooms := {}
    var days := {}
    var kinds := {}
    for event in data.events:
        if not String(event.region).is_empty():
            regions[event.region] = true
        if not String(event.room).is_empty():
            rooms[String(event.region) + ":" + String(event.room)] = true
        var day := Time.get_date_string_from_unix_time(int(event.time))
        days[day] = int(days.get(day, 0)) + 1
        kinds[event.kind] = int(kinds.get(event.kind, 0)) + 1
    return {"regions":regions.size(), "rooms":rooms.size(), "days":days, "kinds":kinds, "favorites":data.favorites.size(), "notes":data.notes.size()}

static func document(data: Dictionary, query: String = "", kind: String = "all", favorites_only: bool = false) -> String:
    var lines: Array[String] = ["巡礼行旅编年", "记录来自工作台启用后的实际观察，不是全程通关证明。", ""]
    for event in records(data, query, kind, favorites_only, false):
        lines.append(VALUES.date(int(event.time)) + " · " + String(event.title))
        if not String(event.note).is_empty():
            lines.append("手记：" + String(event.note))
        lines.append("")
    return "\n".join(lines)
