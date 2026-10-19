extends RefCounted
## JSON-only survey journal inside the existing world story_flags container.
const KEY := "cartography_v1"
const PRICE := 20
## 盐墨绘针: one quill charts every owned map at a shrine. Without it, travel
## notes are kept as pending and are charted at the first rest after buying it.
const QUILL_FLAG := "cartography_quill"
const QUILL_PRICE := 10
static func has_quill(flags: Dictionary) -> bool:
    return bool(flags.get(QUILL_FLAG, false))
static func grant_quill(flags: Dictionary) -> void:
    flags[QUILL_FLAG] = true
## Saves from before the quill already charted at shrines; keep that ability.
static func legacy_quill(flags: Dictionary) -> void:
    if has_quill(flags) or not flags.get(KEY) is Dictionary: return
    for id in flags[KEY]:
        if flags[KEY][id] is Dictionary and bool(flags[KEY][id].get("owned", false)):
            grant_quill(flags)
            return
static func pending_count(flags: Dictionary) -> int:
    var count := 0
    for id in flags.get(KEY, {}).keys():
        var journal := region(flags, String(id))
        if bool(journal.get("owned", false)): count += journal.pending.size()
    return count
static func region(flags: Dictionary, id: String) -> Dictionary:
    if not flags.get(KEY) is Dictionary: flags[KEY] = {}
    if not flags[KEY].get(id) is Dictionary:
        flags[KEY][id] = {"owned":false,"charted":{},"pending":{}}
    var journal: Dictionary = flags[KEY][id]
    if not journal.get("owned") is bool: journal.owned=false
    for field in ["charted","pending"]:
        if not journal.get(field) is Dictionary: journal[field]={}
        for room in journal[field].keys():
            if not room is String or room.is_empty() or not journal[field][room] is bool:
                journal[field].erase(room)
    return journal
static func owned(flags: Dictionary, id: String) -> bool:
    return bool(region(flags,id).get("owned",false))
## Any part of the room is charted: the whole-room note or one of its sections.
static func charted(flags: Dictionary, id: String, room: String) -> bool:
    if not owned(flags,id): return false
    var notes: Dictionary = region(flags,id).charted
    if bool(notes.get(room,false)): return true
    var prefix := room + "@"
    for key in notes:
        if String(key).begins_with(prefix) and bool(notes[key]): return true
    return false
static func visit(flags: Dictionary, id: String, room: String) -> void:
    if room.is_empty(): return
    var journal := region(flags,id)
    if not bool(journal.charted.get(room,false)): journal.pending[room] = true
## Large rooms are noted one screen-sized section at a time, so a long shaft or
## a great hall is charted only where it was actually explored. Notes are
## "<room>@<index>"; a whole-room note (older saves, small rooms) covers all.
const SEGMENT := Vector2(1280, 720)
const SEGMENT_THRESHOLD := 1.5
static func segments(room: Dictionary) -> Array[Rect2]:
    var result: Array[Rect2] = []
    var value: Array = room.get("layout_rect", room.get("play_rect", []))
    if value.size() < 4: return result
    var rect := Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
    if rect.size.x <= SEGMENT.x * SEGMENT_THRESHOLD and rect.size.y <= SEGMENT.y * SEGMENT_THRESHOLD: return result
    var cols := maxi(1, ceili(rect.size.x / SEGMENT.x))
    var rows := maxi(1, ceili(rect.size.y / SEGMENT.y))
    var cell := Vector2(rect.size.x / cols, rect.size.y / rows)
    for row in rows:
        for col in cols:
            result.append(Rect2(rect.position + Vector2(col * cell.x, row * cell.y), cell))
    return result
static func segment_index(room: Dictionary, point: Vector2) -> int:
    var cells := segments(room)
    for index in cells.size():
        if cells[index].grow(0.5).has_point(point): return index
    return -1
static func segment_key(room_id: String, index: int) -> String:
    return "%s@%d" % [room_id, index]
static func visit_at(flags: Dictionary, id: String, room: Dictionary, point: Vector2) -> void:
    var room_id := String(room.get("id", ""))
    if room_id.is_empty(): return
    var index := segment_index(room, point)
    if index < 0:
        visit(flags, id, room_id)
        return
    var journal := region(flags, id)
    var key := segment_key(room_id, index)
    if not bool(journal.charted.get(room_id, false)) and not bool(journal.charted.get(key, false)): journal.pending[key] = true
## Charted parts of a room in world coordinates (the whole room when it is
## small or was charted whole); empty when nothing of it is on the map.
## Read-only: malformed journals answer empty instead of being repaired here.
static func charted_parts(flags: Dictionary, id: String, room: Dictionary) -> Array[Rect2]:
    var result: Array[Rect2] = []
    var journals: Variant = flags.get(KEY, {})
    var journal: Variant = journals.get(id, {}) if journals is Dictionary else {}
    if not journal is Dictionary or not journal.get("owned") is bool or not journal.owned or not journal.get("charted") is Dictionary: return result
    var notes: Dictionary = journal.charted
    var room_id := String(room.get("id", ""))
    var value: Array = room.get("layout_rect", room.get("play_rect", []))
    if room_id.is_empty() or value.size() < 4: return result
    var whole := Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
    if notes.get(room_id) is bool and notes[room_id]:
        result.append(whole)
        return result
    var cells := segments(room)
    for index in cells.size():
        var key := segment_key(room_id, index)
        if notes.get(key) is bool and notes[key]: result.append(cells[index])
    # Every section charted is the whole room again (one clean outline).
    if not cells.is_empty() and result.size() == cells.size():
        result.clear()
        result.append(whole)
    return result
static func charted_whole(flags: Dictionary, id: String, room: Dictionary) -> bool:
    var parts := charted_parts(flags, id, room)
    var value: Array = room.get("layout_rect", room.get("play_rect", []))
    return parts.size() == 1 and value.size() >= 4 and parts[0] == Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
## Any part of the room is on the map.
static func charted_any(flags: Dictionary, id: String, room: Dictionary) -> bool:
    return not charted_parts(flags, id, room).is_empty()
## The part of the room around a point is on the map (markers inside a room).
static func charted_at(flags: Dictionary, id: String, room: Dictionary, point: Vector2) -> bool:
    for part in charted_parts(flags, id, room):
        if part.grow(0.5).has_point(point): return true
    return false
static func charted_room_count(flags: Dictionary, id: String) -> int:
    var rooms := {}
    for key in region(flags, id).charted:
        rooms[String(key).get_slice("@", 0)] = true
    return rooms.size()
## Each region's seller sets its own price (cartography_sellers.json); PRICE is
## only the fallback for a seller record without one.
static func purchase(flags: Dictionary, id: String, wallet: int, price: int = PRICE) -> Dictionary:
    if owned(flags,id): return {"ok":false,"reason":"这张底图已经收进旅册。","wallet":wallet}
    if price <= 0: return {"ok":false,"reason":"这张底图暂不出售。","wallet":wallet}
    if wallet<price: return {"ok":false,"reason":"需要%d枚松脂碎钱。" % price,"wallet":wallet}
    region(flags,id).owned = true
    return {"ok":true,"reason":"收好底图。安坐钟龛时，才能把旅途笔记补绘上去。","wallet":wallet-price}
static func rest(flags: Dictionary) -> int:
    var count := 0
    if not has_quill(flags): return 0
    for id in flags.get(KEY,{}).keys():
        var journal := region(flags,String(id))
        if not bool(journal.get("owned",false)): continue
        for room in journal.pending:
            if not bool(journal.charted.get(room,false)):
                journal.charted[room] = true
                count+=1
        journal.pending.clear()
    return count
static func migrate(flags: Dictionary, regions: Dictionary) -> void:
    if flags.get(KEY) is Dictionary: return
    flags[KEY] = {}
    for id in regions:
        for room in regions[id].get("visited_rooms",{}):
            if bool(regions[id].visited_rooms[room]): visit(flags,id,room)
