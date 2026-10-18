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
static func charted(flags: Dictionary, id: String, room: String) -> bool:
    return owned(flags,id) and bool(region(flags,id).charted.get(room,false))
static func visit(flags: Dictionary, id: String, room: String) -> void:
    if room.is_empty(): return
    var journal := region(flags,id)
    if not bool(journal.charted.get(room,false)): journal.pending[room] = true
static func purchase(flags: Dictionary, id: String, wallet: int) -> Dictionary:
    if owned(flags,id): return {"ok":false,"reason":"这张底图已经收进旅册。","wallet":wallet}
    if wallet<PRICE: return {"ok":false,"reason":"需要%d枚松脂碎钱。" % PRICE,"wallet":wallet}
    region(flags,id).owned = true
    return {"ok":true,"reason":"收好底图。安坐钟龛时，才能把旅途笔记补绘上去。","wallet":wallet-PRICE}
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
