extends RefCounted
## JSON-only survey journal inside the existing world story_flags container.
const KEY := "cartography_v1"
const PRICE := 20
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
