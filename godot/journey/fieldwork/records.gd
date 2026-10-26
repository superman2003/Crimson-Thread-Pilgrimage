extends RefCounted
const V := preload("res://journey/fieldwork/scalars.gd")
const LIMIT := 60


static func fresh() -> Dictionary:
    return {"version": 1, "sequence": 0, "records": []}


static func valid(data: Dictionary, validate_payload: Callable) -> bool:
    if data.get("version") != 1 or not V.count(data.get("sequence"), 100000000):
        return false
    if not data.get("records") is Array or data.records.size() > LIMIT:
        return false
    var ids := {}
    for row in data.records:
        if (
            not row is Dictionary
            or not V.count(row.get("id"), int(data.sequence))
            or int(row.id) == 0
        ):
            return false
        if ids.has(str(int(row.id))) or not row.get("title") is String or row.title.length() > 100:
            return false
        if (
            not row.get("note") is String
            or row.note.length() > 2000
            or not row.get("favorite") is bool
        ):
            return false
        if (
            not V.count(row.get("created"), 9999999999)
            or not V.count(row.get("updated"), 9999999999)
        ):
            return false
        if not row.get("payload") is Dictionary or not validate_payload.call(row.payload):
            return false
        ids[str(int(row.id))] = true
    return V.json_safe(data, 0, [V.MAX_ITEMS])


static func find(data: Dictionary, id: int) -> Dictionary:
    for row in data.get("records", []):
        if int(row.id) == id:
            return row.duplicate(true)
    return {}


static func append(data: Dictionary, title: String, payload: Dictionary) -> Dictionary:
    var next := data.duplicate(true)
    if next.records.size() >= LIMIT or int(next.sequence) >= 100000000:
        return next
    next.sequence = int(next.sequence) + 1
    var now := int(Time.get_unix_time_from_system())
    next.records.push_front(
        {
            "id": next.sequence,
            "title": V.text(title, 100),
            "note": "",
            "favorite": false,
            "created": now,
            "updated": now,
            "payload": payload.duplicate(true)
        }
    )
    return next


static func replace(
    data: Dictionary, id: int, title: String, note: String, favorite: bool, payload: Dictionary
) -> Dictionary:
    var next := data.duplicate(true)
    for row in next.records:
        if int(row.id) == id:
            row.title = V.text(title, 100)
            row.note = V.text(note, 2000)
            row.favorite = favorite
            row.updated = int(Time.get_unix_time_from_system())
            row.payload = payload.duplicate(true)
            break
    return next


static func remove(data: Dictionary, id: int) -> Dictionary:
    var next := data.duplicate(true)
    for index in range(next.records.size() - 1, -1, -1):
        if int(next.records[index].id) == id:
            next.records.remove_at(index)
    return next


static func query(
    data: Dictionary, text: String, favorites: bool = false, newest: bool = true
) -> Array:
    var result := []
    for row in data.get("records", []):
        if favorites and not row.favorite:
            continue
        if not V.matches(text, [String(row.title), String(row.note)]):
            continue
        result.append(row.duplicate(true))
    result.sort_custom(
        func(a: Dictionary, b: Dictionary):
            if int(a.updated) == int(b.updated):
                return int(a.id) > int(b.id) if newest else int(a.id) < int(b.id)
            return int(a.updated) > int(b.updated) if newest else int(a.updated) < int(b.updated)
    )
    return result


static func export_package(data: Dictionary, feature: String, scope: String) -> String:
    return JSON.stringify(
        {
            "format": "pilgrimage-fieldwork",
            "version": 1,
            "feature": feature,
            "scope": scope,
            "data": data
        }
    )


static func import_package(
    raw: String, feature: String, scope: String, validate_payload: Callable
) -> Dictionary:
    if raw.to_utf8_buffer().size() > 2097152:
        return {"ok": false, "reason": "导入文本超过2MiB。"}
    var parsed: Variant = V.parse_json(raw)
    if (
        not parsed is Dictionary
        or parsed.get("format") != "pilgrimage-fieldwork"
        or parsed.get("version") != 1
    ):
        return {"ok": false, "reason": "记录格式无法识别。"}
    if parsed.get("feature") != feature or parsed.get("scope") != scope:
        return {"ok": false, "reason": "记录属于其它功能或存档槽。"}
    if not parsed.get("data") is Dictionary or not valid(parsed.data, validate_payload):
        return {"ok": false, "reason": "导入字段未通过检查。"}
    return {"ok": true, "data": parsed.data.duplicate(true), "reason": "已检查导入候选，尚未写入。"}


static func merge(data: Dictionary, incoming: Dictionary) -> Dictionary:
    var next := data.duplicate(true)
    var fingerprints := {}
    for row in next.records:
        fingerprints[semantic_key({"title": row.title, "note": row.note, "payload": row.payload})] = true
    for row in incoming.records:
        var key := semantic_key({"title": row.title, "note": row.note, "payload": row.payload})
        if fingerprints.has(key):
            continue
        if next.records.size() >= LIMIT or int(next.sequence) >= 100000000:
            return {"ok": false, "reason": "合并超过记录数或序号上限，未应用部分结果。"}
        next = append(next, String(row.title), row.payload)
        next.records[0].created = row.created
        next.records[0].updated = row.updated
        next.records[0].note = row.note
        next.records[0].favorite = row.favorite
        fingerprints[key] = true
    return {"ok": true, "data": next, "reason": "导入候选已合并。"}


static func difference(before: Dictionary, after: Dictionary) -> Array:
    var result := []
    var ids := {}
    for row in before.get("records", []):
        ids[str(int(row.id))] = true
    for row in after.get("records", []):
        ids[str(int(row.id))] = true
    for id in ids:
        var a := find(before, int(id))
        var b := find(after, int(id))
        if a == b:
            continue
        result.append(
            {
                "id": id,
                "kind": "新增" if a.is_empty() else ("移除" if b.is_empty() else "更新"),
                "title": String(b.get("title", a.get("title", "")))
            }
        )
    return result


# JSON has one numeric category; the Godot parser reads all JSON numbers as floats.
# Canonical text removes only integral .0 suffixes, preserving booleans and ordering.
static func semantic_key(value: Variant) -> String:
    if not V.json_safe(value):
        return ""
    return _canonical(value).sha256_text()


static func _canonical(value: Variant) -> String:
    if value is Dictionary:
        var keys: Array = value.keys()
        keys.sort()
        var entries: PackedStringArray = []
        for key in keys:
            entries.append(JSON.stringify(key) + ":" + _canonical(value[key]))
        return "{" + ",".join(entries) + "}"
    if value is Array:
        var entries: PackedStringArray = []
        for item in value:
            entries.append(_canonical(item))
        return "[" + ",".join(entries) + "]"
    if typeof(value) == TYPE_FLOAT:
        if float(value) == 0.0:
            return "0"
        return JSON.stringify(value).trim_suffix(".0")
    return JSON.stringify(value)
