extends RefCounted
## Authored floor semantics for already charted directory entries.
## Unknown metadata is deliberately not inferred from hidden room geometry.
const MAX_ID := 48
const MAX_NAME := 48

static func floor_of(room: Dictionary) -> Dictionary:
    var id: Variant = room.get("floor_id", "")
    var name: Variant = room.get("floor_name", "")
    if not id is String or not name is String:
        return {}
    if id.is_empty() or name.strip_edges().is_empty() or id.length() > MAX_ID or name.length() > MAX_NAME:
        return {}
    for character in id:
        if not "abcdefghijklmnopqrstuvwxyz0123456789_".contains(character):
            return {}
    for character in name:
        var code: int = character.unicode_at(0)
        if code < 32 or code == 127:
            return {}
    return {"id":String(id), "name":String(name)}

static func key(region: String, floor_id: String) -> String:
    # Delimiter-free encoding cannot alias a different region/floor pair.
    return JSON.stringify([region, floor_id])

static func annotate(row: Dictionary, room: Dictionary) -> Dictionary:
    var out := row.duplicate(true)
    var floor := floor_of(room)
    out.floor_id = String(floor.get("id", ""))
    out.floor_name = String(floor.get("name", "未标注层位"))
    out.floor_key = key(String(out.get("region", "")), out.floor_id)
    return out

static func choices(rows: Array, region: String = "") -> Array[Dictionary]:
    # Only the public index is accepted. No atlas/configuration lookup occurs.
    var found: Dictionary = {}
    for value in rows:
        if not value is Dictionary:
            continue
        var row: Dictionary = value
        var row_region := String(row.get("region", ""))
        if not region.is_empty() and row_region != region:
            continue
        var floor_id := String(row.get("floor_id", ""))
        if floor_id.is_empty():
            continue
        var identifier := key(row_region, floor_id)
        if found.has(identifier):
            continue
        var label := String(row.get("floor_name", ""))
        if region.is_empty():
            label = String(row.get("region_name", row_region)) + " · " + label
        found[identifier] = {"id":identifier, "name":label}
    var result: Array[Dictionary] = []
    for choice in found.values():
        result.append(choice)
    result.sort_custom(func(a: Dictionary, b: Dictionary):
        var order := String(a.name).naturalnocasecmp_to(String(b.name))
        return order < 0 if order != 0 else String(a.id) < String(b.id))
    return result

static func filter_rows(rows: Array, identifier: String = "") -> Array:
    var result: Array = []
    for value in rows:
        if not value is Dictionary:
            continue
        if identifier.is_empty() or String(value.get("floor_key", "")) == identifier:
            result.append(value.duplicate(true))
    return result

static func caption(row: Dictionary) -> String:
    return String(row.get("floor_name", "未标注层位"))
