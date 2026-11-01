extends RefCounted
## Earliest feasible instruction schedule with explicit cooldown waits and rests.
## Resource recovery retains the user's per-rest assumption, never a game claim.
const K := preload("res://journey/fieldwork/knowledge.gd")
const MAX_STEPS := 640
const MAX_TIME := 7200.0


static func schedule(payload: Dictionary) -> Dictionary:
    var actions := {}
    for row in payload.actions:
        actions[row.id] = row
    var rows := []
    var time := 0.0
    var energy := float(payload.energy)
    var ready := {}
    var consumed := 0.0
    var recovered := 0.0
    var inserted := 0.0
    var completed := 0
    if payload.sequence.size() * int(payload.repeats) > MAX_STEPS:
        return {"ok": false, "reason": "动作数量超过640"}
    for repetition in int(payload.repeats):
        for index in payload.sequence.size():
            var id := String(payload.sequence[index])
            if not actions.has(id):
                return {"ok": false, "reason": "课程引用未知动作", "rows": []}
            var action: Dictionary = actions[id]
            var duration := maxf(float(payload.waits.get(id, 0.5)), float(action.duration))
            var cost := float(action.cost) + float(action.get("cost_rate", 0)) * duration
            var deficit := maxf(0, cost - energy)
            if deficit > 0:
                if float(payload.recovery) <= 0 or float(payload.rest) <= 0:
                    return {
                        "ok": false, "reason": "第%d轮第%d步能量不足；需要正的休息时长及每次恢复假设" % [repetition + 1, index + 1],
                        "completed": completed, "rows": rows, "energy": energy, "needed": deficit
                    }
                var rests := int(ceil(deficit / float(payload.recovery)))
                var rest_time := rests * float(payload.rest)
                if time + rest_time + duration > MAX_TIME:
                    return {"ok": false, "reason": "补充休息后超过7200秒，不输出部分成功计划", "rows": []}
                rows.append({
                    "kind": "recovery", "动作": "补充个人休息 ×%d" % rests,
                    "轮次": repetition + 1, "步骤": index + 1,
                    "开始秒": time, "结束秒": time + rest_time,
                    "能量前": energy, "能量后": energy + rests * float(payload.recovery)
                })
                time += rest_time
                inserted += rest_time
                recovered += rests * float(payload.recovery)
                energy += rests * float(payload.recovery)
            var wait := maxf(0, float(ready.get(id, 0)) - time)
            if wait > 0:
                rows.append({
                    "kind": "cooldown", "动作": "等待冷却：" + String(action.name),
                    "轮次": repetition + 1, "步骤": index + 1,
                    "开始秒": time, "结束秒": time + wait, "能量前": energy, "能量后": energy
                })
                time += wait
                inserted += wait
            if time + duration > MAX_TIME:
                return {"ok": false, "reason": "冷却排程超过7200秒", "rows": []}
            rows.append({
                "kind": "action", "id": id, "动作": action.name,
                "轮次": repetition + 1, "步骤": index + 1,
                "开始秒": time, "结束秒": time + duration,
                "能量前": energy, "能量后": energy - cost, "cost": cost
            })
            ready[id] = time + float(action.cooldown)
            energy -= cost
            consumed += cost
            time += duration
            completed += 1
        if repetition + 1 < int(payload.repeats):
            var rest := float(payload.rest)
            rows.append({
                "kind": "rest", "动作": "轮间个人休息", "轮次": repetition + 1, "步骤": 0,
                "开始秒": time, "结束秒": time + rest,
                "能量前": energy, "能量后": energy + float(payload.recovery)
            })
            time += rest
            energy += float(payload.recovery)
            recovered += float(payload.recovery)
            if time > MAX_TIME:
                return {"ok": false, "reason": "轮间休息超过7200秒", "rows": []}
    return {
        "ok": true, "rows": rows, "duration": time, "energy": energy,
        "consumed": consumed, "recovered": recovered, "inserted": inserted,
        "completed": completed, "within_target": time <= float(payload.target_duration)
    }


static func certify(payload: Dictionary, result: Dictionary) -> bool:
    if not result.get("ok", false):
        return false
    var ready := {}
    var actions := {}
    for action in payload.actions:
        actions[action.id] = action
    var previous := 0.0
    var sequence := []
    var energy := float(payload.energy)
    var consumed := 0.0
    var recovered := 0.0
    for row in result.rows:
        var start := float(row["开始秒"])
        var duration := float(row["结束秒"]) - start
        if absf(start - previous) > 0.000001 or duration < 0:
            return false
        if absf(float(row["能量前"]) - energy) > 0.000001:
            return false
        previous = float(row["结束秒"])
        match row.kind:
            "action":
                if not actions.has(row.id):
                    return false
                var action: Dictionary = actions[row.id]
                var cost := float(action.cost) + float(action.get("cost_rate", 0)) * duration
                if start < float(ready.get(row.id, 0)) - 0.000001 or energy < cost - 0.000001:
                    return false
                if absf(duration - maxf(float(payload.waits.get(row.id, 0.5)), float(action.duration))) > 0.000001:
                    return false
                ready[row.id] = start + float(action.cooldown)
                energy -= cost
                consumed += cost
                sequence.append(row.id)
            "cooldown":
                pass
            "rest":
                if absf(duration - float(payload.rest)) > 0.000001:
                    return false
                recovered += float(payload.recovery)
                energy += float(payload.recovery)
            "recovery":
                if float(payload.rest) <= 0 or float(payload.recovery) <= 0:
                    return false
                var breaks := duration / float(payload.rest)
                if int(round(breaks)) < 1 or absf(breaks - round(breaks)) > 0.000001:
                    return false
                energy += round(breaks) * float(payload.recovery)
                recovered += round(breaks) * float(payload.recovery)
            _:
                return false
        if absf(float(row["能量后"]) - energy) > 0.000001:
            return false
    var expected := []
    for repeat in int(payload.repeats):
        expected.append_array(payload.sequence)
    return sequence == expected and sequence.size() == result.completed and absf(energy - float(result.energy)) < 0.0001 and absf(consumed - float(result.consumed)) < 0.0001 and absf(recovered - float(result.recovered)) < 0.0001 and absf(previous - float(result.duration)) < 0.000001


static func sections(payload: Dictionary) -> Array:
    var result := schedule(payload)
    if not result.ok:
        return [K.notice("自动冷却排程", String(result.reason))]
    return [
        K.notice("显式等待与休息排程",
            "%d个动作；总时长%.2f秒；额外等待/补休%.2f秒；个人目标%s；冷却及能量证书%s。"
            % [result.completed, result.duration, result.inserted,
                "内完成" if result.within_target else "已超出",
                "通过" if certify(payload, result) else "未通过"]),
        K.table("可承受排程", ["轮次", "步骤", "动作", "开始秒", "结束秒", "能量前", "能量后"], result.rows),
        K.notice("假设边界", "维持动作顺序及每项持续时间，按冷却插入等待。能量不足时只按用户声明的每次休息恢复量补休；不会假定游戏持续回能，不发出按键、不执行动作、不授予训练成绩。")
    ]
