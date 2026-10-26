extends RefCounted
## Observed training counters. Never writes to the World or awards progress.
const V := preload("res://journey/core/values.gd")
const MAX_STEP := 0.5
const MAX_TRAVEL := 600.0
const LIMIT_SECONDS := 600.0
const TERMINAL := ["passed", "failed", "cancelled", "interrupted"]

static func sample_valid(s: Dictionary) -> bool:
    for key in ["slot", "region", "room"]:
        if not s.get(key) is String or String(s[key]).is_empty() or String(s[key]).length() > 200:
            return false
    for key in ["exploring", "at_shrine"]:
        if not s.get(key) is bool:
            return false
    if not V.count(s.get("wallet")) or not s.get("inventory") is Dictionary:
        return false
    if s.inventory.size() > 10000:
        return false
    for key in s.inventory:
        if not key is String or not V.count(s.inventory[key]):
            return false
    if not s.get("player") is Dictionary:
        return false
    var p: Dictionary = s.player
    if not V.count(p.get("hp"), 10000) or not V.count(p.get("energy"), 10000):
        return false
    if not p.get("alive") is bool or not p.get("grounded") is bool:
        return false
    return V.point(p.get("position")).is_finite() and V.point(p.get("velocity")).is_finite()

static func compact(s: Dictionary) -> Dictionary:
    # Context snapshots also contain large catalogs and authored map geometry.
    # Retain only fields consumed by the counter, never those shared resources.
    var out: Dictionary = {}
    for key in ["slot", "region", "room", "wallet", "inventory", "exploring", "at_shrine"]:
        var value: Variant = s[key]
        out[key] = value.duplicate(true) if value is Dictionary or value is Array else value
    out.player = {}
    for key in ["hp", "energy", "alive", "grounded", "position", "velocity"]:
        var value: Variant = s.player[key]
        out.player[key] = value.duplicate(true) if value is Array else value
    return out

static func begin(mode: String, s: Dictionary, target: float) -> Dictionary:
    if not sample_valid(s) or not is_finite(target) or target < 1.0 or target > 10000.0:
        return {}
    if not s.player.alive or s.player.hp <= 0:
        return {}
    if mode == "escape" and s.player.hp > 2:
        return {}
    return {
        "mode":mode,
        "state":"active",
        "reason":"",
        "slot":s.slot,
        "target":target,
        "progress":0.0,
        "elapsed":0.0,
        "samples":0,
        "paused":0,
        "gaps":0,
        "distance":0.0,
        "peak_distance":0.0,
        "initial":compact(s),
        "previous":compact(s),
        "rooms":{room_key(s):true},
        "regions":{s.region:true},
        "shrines":{},
    }

static func room_key(s: Dictionary) -> String:
    # JSON encoding prevents concatenation collisions between room and region.
    return JSON.stringify([s.region, s.room])

static func cancel(run: Dictionary) -> Dictionary:
    if run.is_empty() or run.state != "active":
        return run.duplicate(true)
    var out := run.duplicate(true)
    out.state = "cancelled"
    out.reason = "手动结束；不计为通过。"
    return out

static func stop(run: Dictionary, state: String, reason: String) -> Dictionary:
    var out := run.duplicate(true)
    out.state = state
    out.reason = reason
    return out

static func step(run: Dictionary, s: Dictionary, delta: float) -> Dictionary:
    if run.is_empty() or run.state != "active":
        return run.duplicate(true)
    if not sample_valid(s):
        return stop(run, "interrupted", "观察数据暂不可用；本次未通过。")
    if s.slot != run.slot:
        return stop(run, "interrupted", "存档槽已更换；本次未通过。")
    var out := run.duplicate(true)
    var old: Dictionary = out.previous
    out.previous = compact(s)
    if not is_finite(delta) or delta <= 0 or delta > MAX_STEP:
        out.gaps += 1
        return out
    if not s.exploring or not old.exploring:
        out.paused += 1
        return out
    if not s.player.alive or s.player.hp <= 0:
        return stop(out, "failed", "观察到倒下；本次未通过。")
    out.elapsed += delta
    out.samples += 1
    var mode := String(out.mode)
    var same_region: bool = s.region == old.region
    var movement := 0.0
    if same_region:
        movement = V.point(s.player.position).distance_to(V.point(old.player.position))
    var jumped: bool = movement > MAX_TRAVEL
    if jumped:
        out.gaps += 1
        movement = 0.0
    out.distance += movement
    var key := room_key(s)
    var new_room: bool = not out.rooms.has(key)
    var crossed: bool = key != room_key(old)
    out.rooms[key] = true
    out.regions[s.region] = true
    if s.at_shrine:
        out.shrines[key] = true
    var lost_health: bool = s.player.hp < old.player.hp
    match mode:
        "safe_rooms":
            if lost_health:
                return stop(out, "failed", "观察到生命降低。")
            out.progress = float(out.rooms.size() - 1)
        "walking":
            if old.player.grounded and s.player.grounded:
                out.progress += movement
        "airtime":
            if not old.player.grounded and not s.player.grounded:
                out.progress += delta
        "landings":
            if not old.player.grounded and s.player.grounded:
                out.progress += 1.0
        "reserve":
            if s.player.energy < 60:
                return stop(out, "failed", "观察到绯线低于 60。")
            out.progress = out.elapsed
        "frugal":
            if s.wallet < out.initial.wallet:
                return stop(out, "failed", "钱袋低于本次起点。")
            out.progress = out.elapsed
        "collector":
            for item in s.inventory:
                out.progress += maxf(0, float(s.inventory[item]) - float(old.inventory.get(item, 0)))
        "survey":
            out.progress = float(out.rooms.size() - 1)
        "regions":
            out.progress = float(out.regions.size() - 1)
        "shrine_return":
            if s.at_shrine and not old.at_shrine and out.rooms.size() >= 2:
                out.progress = 1.0
        "escape":
            if lost_health:
                return stop(out, "failed", "撤退中观察到生命降低。")
            if s.at_shrine and not old.at_shrine:
                out.progress = 1.0
        "recovery":
            if s.at_shrine:
                out.progress = maxf(out.progress, float(s.player.hp) - float(out.initial.player.hp))
        "stride":
            if old.player.grounded and s.player.grounded and movement > 0.1:
                out.progress += delta
            else:
                out.progress = 0.0
        "turnaround":
            if s.region == out.initial.region and not jumped:
                var distance := V.point(s.player.position).distance_to(V.point(out.initial.player.position))
                out.peak_distance = maxf(out.peak_distance, distance)
                if out.peak_distance >= 1000.0 and distance <= 80.0:
                    out.progress = 1.0
        "recharge":
            out.progress += maxf(0, float(s.player.energy) - float(old.player.energy))
        "residence":
            if key != room_key(out.initial):
                return stop(out, "failed", "已离开起始房间。")
            out.progress = out.elapsed
        "crossings":
            if crossed and not new_room:
                return stop(out, "failed", "观察到重复房间。")
            out.progress = float(out.rooms.size() - 1)
        "shrines":
            out.progress = float(out.shrines.size())
        "keeper":
            for item in out.initial.inventory:
                if int(s.inventory.get(item, 0)) < int(out.initial.inventory[item]):
                    return stop(out, "failed", "起点持有物资减少。")
            out.progress = out.elapsed
        "home_loop":
            if out.rooms.size() >= 3 and key == room_key(out.initial):
                out.progress = 1.0
        _:
            return stop(out, "interrupted", "未知挑战类型。")
    if out.progress >= out.target:
        out.progress = out.target
        return stop(out, "passed", "观察目标已完成。")
    if out.elapsed >= LIMIT_SECONDS:
        return stop(out, "failed", "观察时间达到十分钟上限。")
    return out

static func record(run: Dictionary, timestamp: int) -> Dictionary:
    if run.is_empty() or not TERMINAL.has(run.get("state")):
        return {}
    return {
        "mode":run.mode,
        "state":run.state,
        "reason":run.reason,
        "target":run.target,
        "progress":run.progress,
        "elapsed":run.elapsed,
        "samples":run.samples,
        "paused":run.paused,
        "gaps":run.gaps,
        "time":maxi(0, timestamp),
        "region":run.initial.region,
        "room":run.initial.room,
    }

static func record_valid(r: Dictionary, mode: String) -> bool:
    if r.get("mode") != mode or not TERMINAL.has(r.get("state")):
        return false
    for key in ["reason", "region", "room"]:
        if not r.get(key) is String or String(r[key]).length() > 200:
            return false
    for key in ["target", "progress", "elapsed"]:
        if not V.number(r.get(key)) or float(r[key]) < 0 or float(r[key]) > 10000000:
            return false
    if float(r.target) < 1:
        return false
    for key in ["samples", "paused", "gaps", "time"]:
        if not V.count(r.get(key), 9999999999):
            return false
    return r.state != "passed" or float(r.progress) >= float(r.target)
