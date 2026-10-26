extends RefCounted
const LIMIT := 6
var state := {"stops":[],"done":[],"active":false}
var store := preload("res://scripts/journey_desk_store.gd").new()

func configure(journey: String) -> void:
    store.configure("expedition",journey)
    var raw := store.read()
    state={"stops":[],"done":[],"active":false}
    if raw.get("stops") is Array:
        for key in raw.stops.slice(0,32):
            if key is String and key.length()<=180 and key.count(":")>=2 and not state.stops.has(key) and state.stops.size()<LIMIT:state.stops.append(key)
    if raw.get("done") is Array:
        for key in raw.done:
            if state.stops.has(key) and not state.done.has(key):state.done.append(key)
    if raw.get("active") is bool:state.active=raw.active and not state.stops.is_empty()

func command(action: String, key: String, known: Array) -> Dictionary:
    var candidate:=state.duplicate(true)
    var keys: Array=known.map(func(row):return String(row.key))
    match action:
        "add":
            if not keys.has(key):return {"ok":false,"reason":"该地点不在当前已补绘目录中。"}
            if candidate.stops.has(key):return {"ok":false,"reason":"行程已有此站。"}
            if candidate.stops.size()>=LIMIT:return {"ok":false,"reason":"一次最多六站。"}
            candidate.stops.append(key)
        "remove":candidate.stops.erase(key);candidate.done.erase(key)
        "up", "down":
            var index: int=candidate.stops.find(key)
            if index<0:return {"ok":false,"reason":"请选择行程中的一站。"}
            var next:=clampi(index+(-1 if action=="up" else 1),0,candidate.stops.size()-1)
            candidate.stops.remove_at(index);candidate.stops.insert(next,key)
        "done":
            if not candidate.stops.has(key) or not keys.has(key):return {"ok":false,"reason":"只能勾选仍然已知的行程地点。"}
            if candidate.done.has(key):candidate.done.erase(key)
            else:candidate.done.append(key)
        "start":
            if candidate.stops.is_empty():return {"ok":false,"reason":"先加入一处已知地点。"}
            for stop in candidate.stops:
                if not keys.has(stop):return {"ok":false,"reason":"部分行程地点已不可见，请移除后再开始。"}
            candidate.active=true
        "pause":candidate.active=false
        "reset":candidate.done=[];candidate.active=false
        _:return {"ok":false,"reason":"无效行程操作。"}
    if candidate.stops.is_empty():candidate.active=false
    if not store.write(candidate):return {"ok":false,"reason":store.error}
    state=candidate
    return {"ok":true,"reason":"行程已保存；仅安排次序，不会移动角色。"}

func next_stop(known: Array) -> Dictionary:
    if not state.active:return {}
    for key in state.stops:
        if state.done.has(key):continue
        for row in known:
            if row.key==key:return row
        return {"unavailable":true}
    return {}

## A conservative adjacency preview, not a physical navigation guarantee.
## A partial room cannot serve as a bridge through uncharted territory.
static func path(config: Dictionary, known_rooms: Array, start: String, target: String, inventory: Dictionary, opened: Dictionary) -> Array[String]:
    if not known_rooms.has(start) or not known_rooms.has(target):return []
    var graph:={}
    for id in known_rooms:graph[id]=[]
    for edge in config.get("connections",[]):
        var a:=String(edge.get("from",""));var b:=String(edge.get("to",""))
        if not graph.has(a) or not graph.has(b):continue
        var ability:=String(edge.get("required_ability",""))
        var count: Variant=inventory.get(ability,0)
        if not ability.is_empty() and (typeof(count) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(count)) or float(count)<1.0 or float(count)!=floor(float(count))):continue
        var shortcut:=String(edge.get("shortcut_id",""))
        if not shortcut.is_empty() and (not opened.get(shortcut) is bool or not opened[shortcut]):continue
        if not String(edge.get("required_flag","")).is_empty():continue
        if String(edge.get("type",""))=="ability_gate" and ability.is_empty():continue
        var blocked:=false
        for gate in config.get("locked_gates",[]):
            if not ((gate.get("from")==a and gate.get("to")==b) or (gate.get("from")==b and gate.get("to")==a)):continue
            var requirement:=String(gate.get("required_ability",""))
            var held: Variant=inventory.get(requirement,0)
            if requirement.is_empty() or typeof(held) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(held)) or float(held)<1.0 or float(held)!=floor(float(held)):blocked=true
        if blocked:continue
        graph[a].append(b)
        if edge.get("bidirectional",false)==true:graph[b].append(a)
    var queue: Array[String]=[start]
    var previous:={start:""}
    var cursor:=0
    while cursor<queue.size() and cursor<512:
        var current:=queue[cursor];cursor+=1
        if current==target:break
        for neighbor in graph[current]:
            if previous.has(neighbor):continue
            previous[neighbor]=current;queue.append(neighbor)
    if not previous.has(target):return []
    var result: Array[String]=[]
    var current:=target
    while not current.is_empty():result.push_front(current);current=String(previous[current])
    return result
