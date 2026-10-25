extends RefCounted
const K := preload("res://journey/fieldwork/knowledge.gd")
const V := preload("res://journey/fieldwork/scalars.gd")
const PROMPT := preload("res://scripts/input_prompt_bindings.gd")
const VIEW := preload("res://journey/fieldwork/curriculum/view.gd")
const BASE := {
    "move_left": "向左移动",
    "move_right": "向右移动",
    "jump": "跳跃",
    "attack": "针击",
    "heal": "缝补",
    "interact": "互动",
    "aim_up": "向上瞄准",
    "aim_down": "向下瞄准"
}
const ABILITIES := {
    "dash": ["thread_dash", "绯线冲刺"],
    "hook": ["echo_hook", "回声钩针"],
    "bell_guard": ["bell_guard", "铜铃架势"],
    "crown_resonance": ["crown_resonance", "王冠共鸣"],
    "lantern_phase": ["lantern_phase", "灯相穿行"]
}


static func introduction() -> String:
    return "把已获能力和当前已装线技排成个人动作课程，检查改键、动作覆盖、休息和资源假设。这里不会注入按键、自动战斗或授予训练进度。"


static func known_actions(snapshot: Dictionary) -> Array:
    var labels := BASE.duplicate()
    for action in ABILITIES:
        if K.positive(snapshot.get("inventory", {}).get(ABILITIES[action][0])):
            labels[action] = ABILITIES[action][1]
    var skill: Dictionary = {}
    for row in snapshot.get("build", {}).get("skills", []):
        if K.flag(row.get("unlocked")) and row.get("id") == snapshot.get("build", {}).get("skill"):
            skill = row
            labels["skill_1"] = String(row.get("name", "当前线技"))
    var result := []
    for id in labels:
        if not InputMap.has_action(id):
            continue
        var cost := 0.0
        var cooldown := 0.0
        var preparation := 0.0
        if id == "skill_1":
            cost = K.safe_number(skill.get("energy_cost"))
            cooldown = K.safe_number(skill.get("cooldown"))
            preparation = (
                K.safe_number(skill.get("windup"))
                + K.safe_number(skill.get("active"))
                + K.safe_number(skill.get("recovery"))
            )
        elif id == "heal":
            cost = K.safe_number(snapshot.get("build", {}).get("stats", {}).get("heal_cost"))
            preparation = K.safe_number(
                snapshot.get("build", {}).get("stats", {}).get("heal_duration")
            )
        var bindings := []
        for event in InputMap.action_get_events(id):
            var label := PROMPT.binding_label(event)
            if not label.is_empty() and not bindings.has(label):
                bindings.append(label)
        result.append(
            {
                "id": id,
                "name": String(labels[id]),
                "binding": PROMPT.action_label(id),
                "bindings": bindings,
                "cost": cost,
                "cooldown": cooldown,
                "duration": preparation,
                "movement": id in ["move_left", "move_right", "jump", "dash", "hook"]
            }
        )
    return result


static func capture(snapshot: Dictionary) -> Dictionary:
    var actions := known_actions(snapshot)
    var sequence := []
    var waits := {}
    for action in actions:
        waits[action.id] = maxf(0.5, float(action.duration))
        if action.id in ["move_left", "move_right", "jump", "attack"]:
            sequence.append(action.id)
    return {
        "actions": actions,
        "sequence": sequence,
        "waits": waits,
        "repeats": 2.0,
        "rest": 10.0,
        "energy": K.safe_number(snapshot.get("player", {}).get("energy")),
        "recovery": 0.0,
        "target_duration": 300.0,
        "title": "个人基础动作课"
    }


static func validate(payload: Dictionary) -> bool:
    if (
        not payload.get("actions") is Array
        or payload.actions.size() > 32
        or not payload.get("sequence") is Array
        or payload.sequence.size() > 32
    ):
        return false
    if (
        not payload.get("waits") is Dictionary
        or payload.waits.size() > 32
        or not payload.get("title") is String
        or payload.title.length() > 100
    ):
        return false
    if not V.count(payload.get("repeats"), 20) or payload.repeats < 1:
        return false
    var bounds := {
        "rest": [0, 300], "energy": [0, 10000], "recovery": [0, 1000], "target_duration": [1, 7200]
    }
    for key in bounds:
        if (
            not V.number(payload.get(key))
            or payload[key] < bounds[key][0]
            or payload[key] > bounds[key][1]
        ):
            return false
    var ids := {}
    for row in payload.actions:
        if (
            not row is Dictionary
            or not row.get("id") is String
            or ids.has(row.id)
            or not row.get("movement") is bool
        ):
            return false
        if (
            not row.get("name") is String
            or not row.get("binding") is String
            or row.name.length() > 200
            or row.binding.length() > 200
        ):
            return false
        if not row.get("bindings") is Array or row.bindings.size() > 32:
            return false
        for binding in row.bindings:
            if not binding is String or binding.length() > 200:
                return false
        for field in ["cost", "cooldown", "duration"]:
            if not V.number(row.get(field)) or row[field] < 0 or row[field] > 10000:
                return false
        ids[row.id] = true
    for id in payload.sequence:
        if not id is String or not ids.has(id):
            return false
    for id in payload.waits:
        if (
            not ids.has(id)
            or not V.number(payload.waits[id])
            or payload.waits[id] < 0.1
            or payload.waits[id] > 60
        ):
            return false
    return V.json_safe(payload, 0, [V.MAX_ITEMS])


static func fields(payload: Dictionary) -> Array:
    var choices := []
    for action in payload.actions:
        choices.append({"id": action.id, "name": action.name + " · " + action.binding})
    return [
        {"id": "title", "name": "课程名", "max": 100},
        {
            "id": "sequence",
            "name": "有序动作步骤",
            "kind": "ordered",
            "choices": choices,
            "limit": 32,
            "allow_duplicates": true
        },
        {
            "id": "waits",
            "name": "每个动作的个人间隔秒数",
            "kind": "weights",
            "choices": choices,
            "min": 0.1,
            "max": 60,
            "step": 0.1
        },
        {"id": "repeats", "name": "重复轮数", "kind": "number", "min": 1, "max": 20},
        {"id": "rest", "name": "轮间休息秒数", "kind": "number", "min": 0, "max": 300},
        {"id": "recovery", "name": "每次休息的假设回能", "kind": "number", "min": 0, "max": 1000},
        {"id": "target_duration", "name": "个人时长预算秒数", "kind": "number", "min": 1, "max": 7200}
    ]


static func summary(payload: Dictionary) -> String:
    return "%s · 每轮%d步骤 · %d轮" % [payload.title, payload.sequence.size(), payload.repeats]


static func index(payload: Dictionary) -> Dictionary:
    var result := {}
    for row in payload.actions:
        result[row.id] = row
    return result


static func timeline(payload: Dictionary) -> Array:
    var actions := index(payload)
    var rows := []
    var time := 0.0
    var energy := float(payload.energy)
    var last := {}
    for repetition in int(payload.repeats):
        for step in payload.sequence.size():
            var id := String(payload.sequence[step])
            var action: Dictionary = actions[id]
            var duration := maxf(float(payload.waits.get(id, 0.5)), float(action.duration))
            var ready := float(last.get(id, -100000)) + float(action.cooldown)
            var early := maxf(0, ready - time)
            var available := energy >= float(action.cost)
            rows.append(
                {
                    "轮次": repetition + 1,
                    "步骤": step + 1,
                    "动作": action.name,
                    "按键": action.binding,
                    "开始秒": time,
                    "结束秒": time + duration,
                    "过早于冷却秒": early,
                    "假设动作费用": action.cost,
                    "假设能量前": energy,
                    "假设可承受": available,
                    "id": id,
                    "kind": "action"
                }
            )
            energy = maxf(0, energy - float(action.cost))
            last[id] = time
            time += duration
        if repetition < int(payload.repeats) - 1:
            rows.append(
                {
                    "轮次": repetition + 1,
                    "步骤": 0,
                    "动作": "个人休息",
                    "按键": "释放全部动作",
                    "开始秒": time,
                    "结束秒": time + float(payload.rest),
                    "过早于冷却秒": 0.0,
                    "假设动作费用": 0.0,
                    "假设能量前": energy,
                    "假设可承受": true,
                    "id": "rest",
                    "kind": "rest"
                }
            )
            time += float(payload.rest)
            energy += float(payload.recovery)
    return rows


static func coverage(payload: Dictionary) -> Array:
    var counts := {}
    for id in payload.sequence:
        counts[id] = int(counts.get(id, 0)) + int(payload.repeats)
    var result := []
    for action in payload.actions:
        result.append(
            {
                "动作": action.name,
                "当前记录按键": action.binding,
                "计划次数": int(counts.get(action.id, 0)),
                "动作类": "机动" if action.movement else "操作",
                "记录绑定数": action.bindings.size()
            }
        )
    return result


static func transitions(payload: Dictionary) -> Array:
    var actions := index(payload)
    var counts := {}
    for i in range(1, payload.sequence.size()):
        var key := String(payload.sequence[i - 1]) + "|" + String(payload.sequence[i])
        counts[key] = int(counts.get(key, 0)) + int(payload.repeats)
    var result := []
    for key in counts:
        var pair := String(key).split("|")
        result.append(
            {
                "前动作": actions[pair[0]].name,
                "后动作": actions[pair[1]].name,
                "计划切换次数": counts[key],
                "是否同动作重复": pair[0] == pair[1]
            }
        )
    return result


static func binding_collisions(payload: Dictionary) -> Array:
    var map := {}
    for action in payload.actions:
        for binding in action.bindings:
            if not map.has(binding):
                map[binding] = []
            map[binding].append(action.name)
    var result := []
    for binding in map:
        if map[binding].size() > 1:
            result.append(
                {
                    "记录绑定": binding,
                    "涉及动作": " / ".join(map[binding]),
                    "说明": "同一显示绑定可能在不同场景有意复用，需按现场上下文判断"
                }
            )
    return result


static func resource_summary(payload: Dictionary, rows: Array) -> Dictionary:
    var cost := 0.0
    var early := 0
    var missing := 0
    var active := 0.0
    var rest := 0.0
    for row in rows:
        cost += float(row["假设动作费用"])
        early += 1 if float(row["过早于冷却秒"]) > 0 else 0
        missing += 1 if not row["假设可承受"] else 0
        var duration := float(row["结束秒"]) - float(row["开始秒"])
        if row.kind == "rest":
            rest += duration
        else:
            active += duration
    return {
        "cost": cost,
        "early": early,
        "missing": missing,
        "active": active,
        "rest": rest,
        "total": active + rest
    }


static func interval_sensitivity(payload: Dictionary) -> Array:
    var result := []
    for factor in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]:
        var sample := payload.duplicate(true)
        for id in sample.waits:
            sample.waits[id] = clampf(float(sample.waits[id]) * float(factor), 0.1, 60)
        var stats := resource_summary(sample, timeline(sample))
        result.append(
            {
                "个人间隔倍率": factor,
                "预计总秒": stats.total,
                "冷却重叠步骤": stats.early,
                "动作段秒": stats.active,
                "休息段秒": stats.rest
            }
        )
    return result


static func recovery_sensitivity(payload: Dictionary) -> Array:
    var result := []
    for recovery in [0, 10, 25, 50, 100]:
        var sample := payload.duplicate(true)
        sample.recovery = float(recovery)
        var stats := resource_summary(sample, timeline(sample))
        result.append(
            {
                "每次休息假设回能": recovery,
                "假设资源不足步骤": stats.missing,
                "累计费用": stats.cost,
                "说明": "不代表原游戏回能规则"
            }
        )
    return result


static func live_bindings(payload: Dictionary, snapshot: Dictionary) -> Array:
    var current := {}
    for action in known_actions(snapshot):
        current[action.id] = action
    var result := []
    for action in payload.actions:
        var row: Dictionary = current.get(action.id, {})
        result.append(
            {
                "动作": action.name,
                "记录按键": action.binding,
                "当前按键": String(row.get("binding", "当前已获动作未包含")),
                "是否变化": row.get("binding", "") != action.binding
            }
        )
    return result


static func recommendations(payload: Dictionary, rows: Array) -> Array:
    var result := []
    var stats := resource_summary(payload, rows)
    if payload.sequence.is_empty():
        result.append({"提示": "先把至少一个已获动作加入有序课程。"})
    if stats.early > 0:
        result.append({"提示": "部分计划间隔短于目录冷却，可延长这些动作的间隔。"})
    if stats.missing > 0:
        result.append({"提示": "按当前能量与个人回能假设，部分步骤不能支付动作费用。"})
    if stats.total > float(payload.target_duration):
        result.append({"提示": "计划超过个人时长预算，可减少轮数或缩短计划。"})
    var unbound := 0
    for row in payload.actions:
        if payload.sequence.has(row.id) and row.bindings.is_empty():
            unbound += 1
    if unbound > 0:
        result.append({"提示": "课程含没有记录绑定的动作，应先在原设置中检查改键。"})
    if result.is_empty():
        result.append({"提示": "计划字段检查通过。请自行选择安全地点练习，所有实际动作仍由游戏控制器判断。"})
    return result


static func analyze(payload: Dictionary, snapshot: Dictionary) -> Array:
    var rows := timeline(payload)
    var stats := resource_summary(payload, rows)
    return [
        K.notice("个人动作课程", summary(payload)),
        {
            "kind": "custom",
            "title": "课程顺序与休息",
            "view": VIEW,
            "data": {"rows": rows, "budget": payload.target_duration}
        },
        K.notice(
            "课程负担",
            (
                "动作段%.1f秒 · 休息%.1f秒 · 总计%.1f秒 · 记录费用合计%.1f。"
                % [stats.active, stats.rest, stats.total, stats.cost]
            )
        ),
        K.table("逐步练习卡", ["轮次", "步骤", "动作", "按键", "开始秒", "结束秒", "过早于冷却秒", "假设能量前", "假设可承受"], rows),
        K.table("已获动作覆盖", ["动作", "当前记录按键", "计划次数", "动作类", "记录绑定数"], coverage(payload)),
        K.table("动作切换", ["前动作", "后动作", "计划切换次数", "是否同动作重复"], transitions(payload)),
        K.table("记录绑定复用", ["记录绑定", "涉及动作", "说明"], binding_collisions(payload)),
        K.table(
            "个人间隔敏感性", ["个人间隔倍率", "预计总秒", "冷却重叠步骤", "动作段秒", "休息段秒"], interval_sensitivity(payload)
        ),
        K.table("个人回能假设", ["每次休息假设回能", "假设资源不足步骤", "累计费用", "说明"], recovery_sensitivity(payload)),
        K.table("当前改键复核", ["动作", "记录按键", "当前按键", "是否变化"], live_bindings(payload, snapshot)),
        K.table("课程检查", ["提示"], recommendations(payload, rows)),
        K.notice("课程边界", "目录时间与个人间隔只是排程参考。这里没有自动施放、移动、命中判定或训练奖励；实际游戏资源费用与动作许可仍由原控制器执行。")
    ]


static func compare(a: Dictionary, b: Dictionary) -> Array:
    var left := resource_summary(a, timeline(a))
    var right := resource_summary(b, timeline(b))
    return [
        K.table(
            "课程方案变化",
            ["样本", "每轮步骤", "轮数", "总秒数", "记录费用合计", "冷却重叠步骤"],
            [
                {
                    "样本": "记录",
                    "每轮步骤": a.sequence.size(),
                    "轮数": a.repeats,
                    "总秒数": left.total,
                    "记录费用合计": left.cost,
                    "冷却重叠步骤": left.early
                },
                {
                    "样本": "当前",
                    "每轮步骤": b.sequence.size(),
                    "轮数": b.repeats,
                    "总秒数": right.total,
                    "记录费用合计": right.cost,
                    "冷却重叠步骤": right.early
                }
            ]
        )
    ]
