extends RefCounted
const LIMIT := 6
var state := {"stops":[],"done":[],"deferred":[],"active":false}
var store := preload("res://scripts/journey_desk_store.gd").new()

func configure(journey: String) -> void:
    store.configure("expedition",journey)
    var before:=disk_identity()
    var raw := store.read()
    if before!=disk_identity():store.writable=false;store.error="读取期间行程被另一处更新，请重新打开旅途。"
    restore_payload(raw)

func restore_payload(raw: Dictionary) -> void:
    state={"stops":[],"done":[],"deferred":[],"active":false}
    if raw.get("stops") is Array:
        for key in raw.stops.slice(0,32):
            if key is String and key.length()<=180 and key.count(":")>=2 and not state.stops.has(key) and state.stops.size()<LIMIT:state.stops.append(key)
    if raw.get("done") is Array:
        for key in raw.done:
            if state.stops.has(key) and not state.done.has(key):state.done.append(key)
    if raw.get("deferred") is Array:
        for key in raw.deferred.slice(0,32):
            if state.stops.has(key) and not state.done.has(key) and not state.deferred.has(key):state.deferred.append(key)
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
        "remove":candidate.stops.erase(key);candidate.done.erase(key);candidate.deferred.erase(key)
        "up", "down":
            var index: int=candidate.stops.find(key)
            if index<0:return {"ok":false,"reason":"请选择行程中的一站。"}
            var next:=clampi(index+(-1 if action=="up" else 1),0,candidate.stops.size()-1)
            candidate.stops.remove_at(index);candidate.stops.insert(next,key)
        "done":
            if not candidate.stops.has(key) or not keys.has(key):return {"ok":false,"reason":"只能勾选仍然已知的行程地点。"}
            if candidate.done.has(key):candidate.done.erase(key)
            else:candidate.done.append(key);candidate.deferred.erase(key)
        "defer":
            if not candidate.stops.has(key) or candidate.done.has(key):return {"ok":false,"reason":"只能暂缓尚未完成的行程站点。"}
            if candidate.deferred.has(key):candidate.deferred.erase(key)
            else:candidate.deferred.append(key)
            if candidate.active and not candidate.stops.any(func(stop):return not candidate.done.has(stop) and not candidate.deferred.has(stop)):candidate.active=false
        "start":
            if candidate.stops.is_empty():return {"ok":false,"reason":"先加入一处已知地点。"}
            if not candidate.deferred.is_empty() and not candidate.stops.any(func(stop):return not candidate.done.has(stop) and not candidate.deferred.has(stop)):
                return {"ok":false,"reason":"其余站点均已完成或暂缓；恢复一站后再开始。"}
            for stop in candidate.stops:
                if not candidate.deferred.has(stop) and not keys.has(stop):return {"ok":false,"reason":"部分行程地点已不可见，请暂缓或移除后再开始。"}
            candidate.active=true
        "pause":candidate.active=false
        "reset":candidate.done=[];candidate.deferred=[];candidate.active=false
        _:return {"ok":false,"reason":"无效行程操作。"}
    if candidate.stops.is_empty():candidate.active=false
    if not commit(candidate):return {"ok":false,"reason":store.error}
    return {"ok":true,"reason":"行程已保存；仅安排次序，不会移动角色。"}

func disk_identity() -> String:
    if store.path.is_empty():return "unconfigured"
    if not FileAccess.file_exists(store.path):return "missing"
    var file:=FileAccess.open(store.path,FileAccess.READ)
    if file==null or file.get_length()>store.MAX_BYTES:return "unreadable"
    return file.get_buffer(file.get_length()).hex_encode().sha256_text()

func commit(candidate: Dictionary) -> bool:
    if not store.writable or store.path.is_empty():return false
    var parent:=ProjectSettings.globalize_path(store.path.get_base_dir())
    if DirAccess.make_dir_recursive_absolute(parent)!=OK:store.error="无法建立行程记录目录。";return false
    var lock:=ProjectSettings.globalize_path(store.path+".route_writer_lock")
    if DirAccess.make_dir_absolute(lock)!=OK:store.error="行程正在另一处写入，请稍后重新打开。";return false
    var reader: RefCounted=get_script().new()
    reader.store.path=store.path
    reader.restore_payload(reader.store.read())
    if not reader.store.writable or reader.state!=state:
        DirAccess.remove_absolute(lock);store.error="行程文件已变化或不可读，请重新进入旅途后再安排。";return false
    var success:=store.write(candidate)
    if success:state=candidate.duplicate(true)
    DirAccess.remove_absolute(lock)
    return success

func next_stop(known: Array) -> Dictionary:
    if not state.active:return {}
    for key in state.stops:
        if state.done.has(key) or state.deferred.has(key):continue
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
