extends RefCounted
## Achievements are read off a journey's own save data, so nothing new is
## written into the save. Which ones this installation has ever earned is kept
## in a small record of its own and survives new journeys.
const PROGRESS := preload("res://scripts/journey_progress.gd")
const ABILITIES := preload("res://scripts/permanent_ability_roles.gd")
const LIST := [
    {"id": "first_ability", "name": "第一缕线", "goal": "取得第一项永久能力"},
    {"id": "all_abilities", "name": "八线俱全", "goal": "取得全部八项永久能力"},
    {"id": "first_gatekeeper", "name": "叩开钟门", "goal": "击败第一位守门者"},
    {"id": "all_gatekeepers", "name": "六门皆启", "goal": "击败全部六位守门者"},
    {"id": "wanderer", "name": "走过半程", "goal": "到访一半的房间"},
    {"id": "cartographer", "name": "无处未至", "goal": "到访全部房间"},
    {"id": "gleaner", "name": "拾遗", "goal": "取得一半的可拾取物"},
    {"id": "ending_a", "name": "重鸣", "goal": "见证结局·重鸣"},
    {"id": "ending_b", "name": "断线", "goal": "见证结局·断线"},
    {"id": "ending_c", "name": "改写", "goal": "见证结局·改写"},
    {"id": "all_endings", "name": "三途尽览", "goal": "在同一段旅途见证三种结局"},
    {"id": "completionist", "name": "巡礼圆满", "goal": "完成度达到 100%"},
]
var store := preload("res://scripts/journey_desk_store.gd").new()
var unlocked: Dictionary = {}
var ready := false

## Ids this journey's data satisfies right now.
static func earned(data: Dictionary) -> Array[String]:
    var totals:=PROGRESS.totals()
    var abilities:=0
    for id in ABILITIES.IDS:
        if ABILITIES.owns(data.get("inventory_counts",{}),String(id)):abilities+=1
    var bosses:=0;var rooms:=0;var pickups:=0;var all_rooms:=0;var all_pickups:=0
    for region_id in totals:
        var known: Dictionary=totals[region_id]
        all_rooms+=known.rooms.size();all_pickups+=known.pickups.size()
        var region: Variant=data.get("regions",{}).get(region_id)
        if not region is Dictionary:continue
        if region.get("boss_defeated") is bool and region.boss_defeated:bosses+=1
        rooms+=PROGRESS._found(region.get("visited_rooms"),known.rooms)
        pickups+=PROGRESS._found(region.get("collected_ids"),known.pickups)
    var flags: Variant=data.get("story_flags",{})
    var endings:=0
    var result: Array[String]=[]
    for letter in ["a","b","c"]:
        if flags is Dictionary and flags.get("ending_%s_done" % letter) is bool and flags["ending_%s_done" % letter]:
            endings+=1;result.append("ending_"+letter)
    if endings==3:result.append("all_endings")
    if abilities>=1:result.append("first_ability")
    if abilities>=ABILITIES.IDS.size():result.append("all_abilities")
    if bosses>=1:result.append("first_gatekeeper")
    if bosses>=PROGRESS.BOSSES:result.append("all_gatekeepers")
    if all_rooms>0 and rooms*2>=all_rooms:result.append("wanderer")
    if all_rooms>0 and rooms>=all_rooms:result.append("cartographer")
    if all_pickups>0 and pickups*2>=all_pickups:result.append("gleaner")
    if PROGRESS.completion(data)>=100:result.append("completionist")
    return result

static func title(id: String) -> String:
    for entry in LIST:
        if entry.id==id:return String(entry.name)
    return ""

func load() -> void:
    if ready:return
    ready=true
    store.configure("achievements","installation")
    var saved:=store.read()
    if saved.is_empty():return
    var known:={}
    for entry in LIST:known[entry.id]=true
    for id in saved:
        if not id is String or not known.has(id) or typeof(saved[id]) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(saved[id])) or float(saved[id])<0.0:
            store.writable=false;store.error="成就记录无效，保留原文件。";unlocked={}
            return
        unlocked[id]=int(saved[id])

## Record what `data` newly earns; returns the names to announce, list order.
func sync(data: Dictionary, now: int) -> Array[String]:
    self.load()
    var fresh: Array[String]=[]
    var have:=earned(data)
    for entry in LIST:
        if have.has(entry.id) and not unlocked.has(entry.id):
            unlocked[entry.id]=now;fresh.append(String(entry.name))
    if fresh.is_empty():return fresh
    # Unsaved achievements are announced again next time rather than lost.
    if not store.write(unlocked):
        for entry in LIST:
            if fresh.has(String(entry.name)):unlocked.erase(entry.id)
        return []
    return fresh

func rows() -> Array:
    self.load()
    var result:=[]
    for entry in LIST:
        result.append({"id":entry.id,"name":entry.name,"goal":entry.goal,"earned":unlocked.has(entry.id)})
    return result
