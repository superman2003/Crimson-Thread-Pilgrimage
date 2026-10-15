extends RefCounted
## JSON-only player annotations. Reads never repair or mutate the save journal.
const KEY := "player_map_pins_v1"
const LIMIT := 12
const MAX_SCAN := 48
const KINDS := ["goal", "warning", "return"]
const NAMES := ["目标", "留意", "回访"]
const SYMBOLS := ["★", "!", "↩"]
const KNOWLEDGE := preload("res://scripts/survey_map_knowledge.gd")
const JOURNAL := preload("res://scripts/pilgrimage_cartography.gd")
const SURVEY := preload("res://scripts/cartography_runtime.gd")

static func owner(config: Dictionary, point: Vector2) -> Dictionary:
    if not point.is_finite(): return {}
    # A zero-area feature still selects the innermost authored room. Reject
    # its far boundary rather than falling back to a charted enclosing hall.
    var room := KNOWLEDGE.owner_room(config, Rect2(point, Vector2.ZERO))
    return room if not room.is_empty() and SURVEY.room_rect(room).has_point(point) else {}

static func allowed(flags: Dictionary, region: String, config: Dictionary, point: Vector2) -> bool:
    var room := owner(config, point)
    var journals: Variant = flags.get(JOURNAL.KEY, {})
    if room.is_empty() or not journals is Dictionary: return false
    var journal: Variant = journals.get(region, {})
    return journal is Dictionary and journal.get("owned") is bool and journal.owned and journal.get("charted") is Dictionary and journal.charted.get(String(room.get("id", "")), false) is bool and bool(journal.charted.get(String(room.get("id", "")), false))

static func records(flags: Dictionary, configs: Dictionary) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var raw: Variant = flags.get(KEY, [])
    if not raw is Array: return result
    var ids := {}
    for index in mini(raw.size(), MAX_SCAN):
        var record: Variant = raw[index]
        if not record is Dictionary: continue
        if not _integer(record.get("id")) or int(record.id) <= 0 or int(record.id) > 1000000000: continue
        if ids.has(int(record.id)) or not record.get("region_id") is String or not configs.has(record.region_id): continue
        if not record.get("kind") is String or record.kind not in KINDS or not record.get("room_id") is String: continue
        var position: Variant = record.get("position")
        if not position is Array or position.size() != 2 or not _number(position[0]) or not _number(position[1]): continue
        var point := Vector2(position[0], position[1])
        var room := owner(configs[record.region_id], point)
        if room.is_empty() or String(room.get("id", "")) != record.room_id: continue
        if not allowed(flags, record.region_id, configs[record.region_id], point): continue
        if _near(result, record.region_id, point): continue
        result.append({"id": int(record.id), "region_id": record.region_id, "room_id": record.room_id,
            "position": [point.x, point.y], "kind": record.kind})
        ids[int(record.id)] = true
        if result.size() == LIMIT: break
    return result

static func visible(flags: Dictionary, configs: Dictionary) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for record in records(flags, configs):
        if allowed(flags, record.region_id, configs[record.region_id], Vector2(record.position[0], record.position[1])):
            result.append(record)
    return result

static func add(flags: Dictionary, configs: Dictionary, region: String, point: Vector2, kind: String) -> Dictionary:
    if kind not in KINDS or not configs.has(region) or not allowed(flags, region, configs[region], point):
        return {"ok": false, "reason": "只能在已购且已补绘的房间标记。"}
    var next := records(flags, configs)
    if _near(next, region, point): return {"ok": false, "reason": "附近已有自定义图钉。"}
    if next.size() >= LIMIT: return {"ok": false, "reason": "最多保留12个图钉，请先删除一个。"}
    var id := 1
    for record in next: id = maxi(id, int(record.id) + 1)
    if id > 1000000000: return {"ok": false, "reason": "图钉编号无效，请先清理旧标记。"}
    next.append({"id": id, "region_id": region, "room_id": String(owner(configs[region], point).id),
        "position": [point.x, point.y], "kind": kind})
    return {"ok": true, "records": next, "reason": "已添加" + NAMES[KINDS.find(kind)] + "图钉。"}

static func remove(flags: Dictionary, configs: Dictionary, id: int) -> Dictionary:
    var next := records(flags, configs)
    for record in visible(flags, configs):
        if int(record.id) != id: continue
        for index in next.size():
            if int(next[index].id) == id:
                next.remove_at(index)
                return {"ok": true, "records": next, "reason": "已删除图钉。"}
    return {"ok": false, "reason": "请选择一个已知图钉。"}

static func _near(records_value: Array, region: String, point: Vector2) -> bool:
    for record in records_value:
        if record.region_id == region and point.distance_to(Vector2(record.position[0], record.position[1])) < 24.0: return true
    return false
static func _number(value: Variant) -> bool:
    return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))
static func _integer(value: Variant) -> bool:
    return _number(value) and float(value) == floor(float(value))
