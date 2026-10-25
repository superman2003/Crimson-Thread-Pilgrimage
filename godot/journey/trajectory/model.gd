extends RefCounted
const V := preload("res://journey/core/values.gd")
const MAX_RUNS := 8
const MAX_SAMPLES := 300
const MAX_SECONDS := 60.0

static func fresh() -> Dictionary:
    return {"version":1, "sequence":0, "runs":[]}

static func valid(data: Dictionary) -> bool:
    if data.get("version") != 1 or not V.count(data.get("sequence")):
        return false
    if not data.get("runs") is Array or data.runs.size() > MAX_RUNS:
        return false
    var ids := {}
    for run in data.runs:
        if not run is Dictionary or not run.get("id") is String or ids.has(run.id):
            return false
        if not run.get("samples") is Array or run.samples.size() > MAX_SAMPLES:
            return false
        if V.text(run.get("name"), 50).is_empty() or not run.get("note") is String or run.note.length() > 800:
            return false
        if not run.get("region") is String or not V.number(run.get("duration")) or float(run.duration) < 0 or float(run.duration) > MAX_SECONDS + 1:
            return false
        var previous := -1.0
        for sample in run.samples:
            if not sample is Dictionary or not V.number(sample.get("t")):
                return false
            if float(sample.t) <= previous or float(sample.t) > MAX_SECONDS + 1:
                return false
            if not V.point(sample.get("p")).is_finite() or not V.point(sample.get("v")).is_finite():
                return false
            if not V.count(sample.get("hp"), 1000) or not V.count(sample.get("energy"), 100000) or not sample.get("floor") is bool:
                return false
            previous = float(sample.t)
        ids[run.id] = true
    return V.json_safe(data, 0, [V.MAX_ITEMS])

static func start(snapshot: Dictionary, title: String) -> Dictionary:
    if snapshot.is_empty() or not snapshot.get("player") is Dictionary:
        return {}
    var name := V.text(title, 50)
    if name.is_empty():
        name = "机动观察"
    return {"name":name, "region":String(snapshot.get("region", "")), "region_name":String(snapshot.get("region_name", "")), "started":int(snapshot.get("timestamp", 0)), "duration":0.0, "paused":0.0, "wall":0.0, "samples":[], "note":"", "reason":""}

static func sample(run: Dictionary, snapshot: Dictionary, delta: float) -> Dictionary:
    var result := run.duplicate(true)
    if not V.number(delta) or delta <= 0 or delta > 1.0:
        result.reason = "采样长帧中断"
        return result
    result.wall = float(result.get("wall", 0.0)) + delta
    if snapshot.get("region") != result.region:
        result.reason = "地区已经切换"
        return result
    var player: Dictionary = snapshot.get("player", {})
    if not player.get("alive", false):
        result.reason = "角色倒下"
        return result
    if not snapshot.get("exploring", false):
        result.paused = float(result.paused) + delta
        if result.wall > 180:
            result.reason = "暂停时间过长"
        return result
    var position := V.point(player.get("position"))
    var velocity := V.point(player.get("velocity"))
    if not position.is_finite() or not velocity.is_finite():
        result.reason = "位置样本无效"
        return result
    result.duration = minf(MAX_SECONDS + 0.5, float(result.duration) + delta)
    if result.samples.size() < MAX_SAMPLES:
        result.samples.append({"t":result.duration, "p":V.pair(position), "v":V.pair(velocity), "hp":int(player.get("hp", 0)), "energy":int(player.get("energy", 0)), "floor":bool(player.get("grounded", false)), "room":String(snapshot.get("room", ""))})
    if result.samples.size() >= MAX_SAMPLES:
        result.reason = "达到300个样本上限"
    elif result.duration >= MAX_SECONDS:
        result.reason = "达到60秒观察时长"
    return result

static func save(data: Dictionary, run: Dictionary) -> Dictionary:
    var result := data.duplicate(true)
    if run.get("samples", []).size() < 2:
        return result
    result.sequence = int(result.sequence) + 1
    var record := run.duplicate(true)
    record["id"] = "trace_" + str(int(result.sequence))
    result.runs.push_front(record)
    while result.runs.size() > MAX_RUNS:
        result.runs.pop_back()
    return result if valid(result) else data.duplicate(true)

static func statistics(run: Dictionary) -> Dictionary:
    var samples: Array = run.get("samples", [])
    var result := {"duration":float(run.get("duration", 0.0)), "distance":0.0, "displacement":0.0, "peak_speed":0.0, "airtime":0.0, "groundtime":0.0, "jumps":0, "rooms":0, "damage_seen":0, "energy_spent_seen":0, "energy_gained_seen":0, "height_range":0.0, "samples":samples.size()}
    if samples.is_empty():
        return result
    var rooms := {}
    var low := INF
    var high := -INF
    var previous: Dictionary = {}
    var largest_gap := 0.0
    for entry in samples:
        var point := V.point(entry.p)
        var velocity := V.point(entry.v)
        result.peak_speed = maxf(float(result.peak_speed), velocity.length())
        low = minf(low, point.y)
        high = maxf(high, point.y)
        rooms[String(entry.room)] = true
        if not previous.is_empty():
            var delta := float(entry.t) - float(previous.t)
            largest_gap = maxf(largest_gap, delta)
            result.distance += point.distance_to(V.point(previous.p))
            if entry.floor:
                result.groundtime += delta
            else:
                result.airtime += delta
            if previous.floor and not entry.floor and velocity.y < 0:
                result.jumps += 1
            result.damage_seen += maxi(0, int(previous.hp) - int(entry.hp))
            result.energy_spent_seen += maxi(0, int(previous.energy) - int(entry.energy))
            result.energy_gained_seen += maxi(0, int(entry.energy) - int(previous.energy))
        previous = entry
    result.displacement = V.point(samples[-1].p).distance_to(V.point(samples[0].p))
    result.rooms = rooms.size()
    result.height_range = high - low
    result["largest_gap"] = largest_gap
    result["average_speed"] = float(result.distance) / maxf(0.001, float(result.duration))
    result["straightness"] = float(result.displacement) / maxf(0.001, float(result.distance))
    return result

static func segments(run: Dictionary) -> Array:
    var result := []
    var current := {}
    for entry in run.get("samples", []):
        var state := "地面" if entry.floor else "空中"
        if current.is_empty() or current.state != state:
            if not current.is_empty():
                result.append(current)
            current = {"state":state, "start":float(entry.t), "finish":float(entry.t), "samples":1}
        else:
            current.finish = float(entry.t)
            current.samples += 1
    if not current.is_empty():
        result.append(current)
    return result

static func get_run(data: Dictionary, id: String) -> Dictionary:
    for run in data.runs:
        if run.id == id:
            return run.duplicate(true)
    return {}

static func annotate(data: Dictionary, id: String, title: String, note: String) -> Dictionary:
    var result := data.duplicate(true)
    var name := V.text(title, 50)
    if name.is_empty():
        return result
    for run in result.runs:
        if run.id == id:
            run.name = name
            run.note = V.text(note, 800)
    return result

static func remove(data: Dictionary, id: String) -> Dictionary:
    var result := data.duplicate(true)
    for index in range(result.runs.size() - 1, -1, -1):
        if result.runs[index].id == id:
            result.runs.remove_at(index)
    return result

static func compare(a: Dictionary, b: Dictionary) -> Array:
    var left := statistics(a)
    var right := statistics(b)
    var names := {"duration":"观察秒数", "distance":"累计路程", "displacement":"起终点距离", "peak_speed":"峰值速度", "airtime":"空中时间", "jumps":"观察到的起跳", "damage_seen":"采样间掉血", "energy_spent_seen":"采样间耗线", "height_range":"高度跨度"}
    var result := []
    for key in names:
        result.append({"id":key, "name":names[key], "left":float(left[key]), "right":float(right[key]), "difference":float(right[key]) - float(left[key])})
    return result

static func csv(run: Dictionary) -> String:
    var lines: Array[String] = ["seconds,x,y,vx,vy,hp,energy,grounded"]
    for entry in run.get("samples", []):
        lines.append("%.6f,%.3f,%.3f,%.3f,%.3f,%d,%d,%d" % [entry.t, entry.p[0], entry.p[1], entry.v[0], entry.v[1], entry.hp, entry.energy, 1 if entry.floor else 0])
    return "\n".join(lines)

static func trim(run: Dictionary, begin: float, finish: float, title: String) -> Dictionary:
    if not is_finite(begin) or not is_finite(finish) or begin < 0 or finish <= begin:
        return {"ok":false, "reason":"片段起终时间无效。"}
    var samples := []
    for sample in run.get("samples", []):
        if float(sample.t) >= begin and float(sample.t) <= finish:
            samples.append(sample.duplicate(true))
    if samples.size() < 2:
        return {"ok":false, "reason":"所选片段至少需要两个实际采样点。"}
    var origin := float(samples[0].t)
    for sample in samples:
        sample.t = float(sample.t) - origin + 0.000001
    var result := run.duplicate(true)
    result.samples = samples
    result.duration = float(samples[-1].t)
    result.name = V.text(title, 50)
    if String(result.name).is_empty():
        result.name = String(run.get("name", "机动观察")) + "片段"
    result.name = String(result.name).left(50)
    result.note = "来自原记录的 %.2f–%.2f 秒，时间从片段首个样本重新计。" % [begin, finish]
    result.reason = "手动裁剪既有样本"
    result["source_id"] = String(run.get("id", ""))
    result["source_begin"] = begin
    result["source_finish"] = finish
    result.erase("id")
    return {"ok":true, "run":result, "reason":"只裁剪已保存采样，不生成新的运动数据。"}

static func changes(run: Dictionary) -> Array:
    var result := []
    var previous := {}
    for sample in run.get("samples", []):
        if not previous.is_empty():
            if int(sample.hp) != int(previous.hp):
                result.append({"time":sample.t, "kind":"生命", "before":int(previous.hp), "after":int(sample.hp)})
            if absf(float(sample.energy) - float(previous.energy)) >= 20:
                result.append({"time":sample.t, "kind":"绯线", "before":int(previous.energy), "after":int(sample.energy)})
            if String(sample.room) != String(previous.room):
                result.append({"time":sample.t, "kind":"房间", "before":String(previous.room), "after":String(sample.room)})
        previous = sample
    return result
