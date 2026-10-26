extends RefCounted
const K := preload("res://journey/fieldwork/knowledge.gd")
const V := preload("res://journey/fieldwork/scalars.gd")
const VIEW := preload("res://journey/fieldwork/milestones/view.gd")
const ABILITIES := {
    "thread_dash": "绯线冲刺",
    "silk_wall_grip": "绯线攀壁",
    "double_thread_jump": "二段绯跳",
    "echo_hook": "回声钩针",
    "bell_guard": "铜铃架势",
    "thorn_downstrike": "荆棘下刺",
    "lantern_phase": "灯相穿行",
    "crown_resonance": "王冠共鸣"
}
const KINDS := ["能力", "装备", "物资", "任务", "结局"]


static func introduction() -> String:
    return "用已取得能力、已获装备、已知任务和持有物资建立成长观察快照，比较两次观察间的变化。个人目标只引用已知条目，不授予成长或自动跟踪未知目标。"


static func capture(snapshot: Dictionary) -> Dictionary:
    var facts := []
    for id in ABILITIES:
        if K.positive(snapshot.get("inventory", {}).get(id)):
            facts.append(
                {
                    "id": "ability:" + String(id),
                    "name": ABILITIES[id],
                    "kind": "能力",
                    "count": 1,
                    "status": "已取得"
                }
            )
    for row in K.equipment(snapshot):
        facts.append(
            {
                "id": "gear:" + String(row.group) + ":" + String(row.id),
                "name": String(row.get("name", row.id)),
                "kind": "装备",
                "count": 1,
                "status": "已获得"
            }
        )
    var tokens := ABILITIES.duplicate()
    for group in ["crests", "skills", "tools", "passives"]:
        for entry in snapshot.get("catalog", {}).get(group, {}).values():
            var token := String(entry.get("unlock_item", ""))
            if not token.is_empty():
                tokens[token] = true
    for row in K.inventory(snapshot).slice(0, 200):
        if tokens.has(row.id):
            continue
        facts.append(
            {
                "id": "item:" + String(row.id),
                "name": row.name,
                "kind": "物资",
                "count": row.count,
                "status": "当前持有"
            }
        )
    var story := K.story(snapshot)
    for row in story.get("quests", []).slice(0, 80):
        var done := String(row.get("status", "")) == "complete"
        facts.append(
            {
                "id": "quest:" + String(row.get("id", "")),
                "name": String(row.get("title", "已知任务")),
                "kind": "任务",
                "count": 1 if done else 0,
                "status": "已完成" if done else "已知进行中"
            }
        )
    for row in story.get("endings", []):
        if K.flag(row.get("chosen")):
            facts.append(
                {
                    "id": "ending:" + String(row.id),
                    "name": String(row.get("title", "已选结局")),
                    "kind": "结局",
                    "count": 1,
                    "status": "已选择"
                }
            )
    facts = facts.slice(0, 400)
    var targets := {}
    var priorities := {}
    for row in facts.slice(0, 60):
        targets[row.id] = float(row.count)
        priorities[row.id] = 1.0
    var stats := {}
    for key in [
        "max_hp",
        "max_energy",
        "move_mult",
        "attack_damage_mult",
        "heal_cost",
        "heal_duration",
        "skill_cost_mult",
        "skill_damage_mult",
        "damage_taken_mult"
    ]:
        var value: Variant = snapshot.get("build", {}).get("stats", {}).get(key)
        if V.number(value):
            stats[key] = float(value)
    return {
        "facts": facts,
        "stats": stats,
        "recorded": int(snapshot.get("timestamp", 0)),
        "region": String(snapshot.get("region_name", "")),
        "kind": "全部",
        "targets": targets,
        "priorities": priorities,
        "pinned": [],
        "question": ""
    }


static func validate(payload: Dictionary) -> bool:
    if (
        not payload.get("facts") is Array
        or payload.facts.size() > 400
        or not payload.get("stats") is Dictionary
        or payload.stats.size() > 30
    ):
        return false
    if (
        not V.count(payload.get("recorded"), 9999999999)
        or not payload.get("region") is String
        or payload.get("kind") not in ["全部"] + KINDS
    ):
        return false
    if (
        not payload.get("question") is String
        or payload.question.length() > 1000
        or not payload.get("pinned") is Array
        or payload.pinned.size() > 100
    ):
        return false
    var ids := {}
    for row in payload.facts:
        if (
            not row is Dictionary
            or not row.get("id") is String
            or ids.has(row.id)
            or row.id.length() > 200
        ):
            return false
        if (
            not row.get("name") is String
            or row.name.length() > 200
            or row.get("kind") not in KINDS
            or not row.get("status") is String
            or not V.count(row.get("count"))
        ):
            return false
        ids[row.id] = true
    for key in payload.stats:
        if (
            not key is String
            or not V.number(payload.stats[key])
            or absf(float(payload.stats[key])) > 1000000
        ):
            return false
    for key in ["targets", "priorities"]:
        if not payload.get(key) is Dictionary or payload[key].size() > 400:
            return false
        for id in payload[key]:
            if (
                not ids.has(id)
                or not V.number(payload[key][id])
                or payload[key][id] < 0
                or payload[key][id] > (100 if key == "priorities" else 1000000)
            ):
                return false
            if key == "targets" and not V.count(payload[key][id]):
                return false
    var seen := {}
    for id in payload.pinned:
        if not ids.has(id) or seen.has(id):
            return false
        seen[id] = true
    return V.json_safe(payload, 0, [V.MAX_ITEMS])


static func fields(payload: Dictionary) -> Array:
    var choices := []
    var kinds := [{"id": "全部", "name": "全部已知类型"}]
    for kind in KINDS:
        kinds.append({"id": kind, "name": kind})
    for row in payload.facts:
        if payload.kind == "全部" or row.kind == payload.kind:
            choices.append({"id": row.id, "name": row.kind + " · " + row.name})
    choices = choices.slice(0, 60)
    return [
        {"id": "kind", "name": "目标编辑类型", "kind": "choice", "choices": kinds},
        {
            "id": "targets",
            "name": "当前类型的个人数量目标（前60项）",
            "kind": "weights",
            "choices": choices,
            "min": 0,
            "max": 1000000
        },
        {
            "id": "priorities",
            "name": "个人目标优先级",
            "kind": "weights",
            "choices": choices,
            "min": 0,
            "max": 100
        },
        {"id": "pinned", "name": "个人重点条目", "kind": "checklist", "choices": choices},
        {"id": "question", "name": "本次成长观察问题", "max": 1000}
    ]


static func summary(payload: Dictionary) -> String:
    return (
        "%d项已知事实 · %s · %s" % [payload.facts.size(), payload.region, V.date(int(payload.recorded))]
    )


static func index(payload: Dictionary) -> Dictionary:
    var result := {}
    for row in payload.facts:
        result[row.id] = row
    return result


static func counts(payload: Dictionary) -> Dictionary:
    var result := {}
    for kind in KINDS:
        result[kind] = 0
    for row in payload.facts:
        result[row.kind] += 1
    return result


static func rows(payload: Dictionary) -> Array:
    var result := []
    for row in payload.facts:
        if payload.kind != "全部" and payload.kind != row.kind:
            continue
        result.append(
            {
                "条目": row.name,
                "类型": row.kind,
                "记录数量": row.count,
                "状态": row.status,
                "个人重点": payload.pinned.has(row.id)
            }
        )
    result.sort_custom(
        func(a: Dictionary, b: Dictionary):
            if a["个人重点"] != b["个人重点"]:
                return bool(a["个人重点"])
            return String(a["条目"]).naturalnocasecmp_to(String(b["条目"])) < 0
    )
    return result


static func goals(payload: Dictionary) -> Array:
    var result := []
    for row in payload.facts:
        var target := int(payload.targets.get(row.id, row.count))
        var gap := maxi(0, target - int(row.count))
        var priority := float(payload.priorities.get(row.id, 1))
        if target == int(row.count) and not payload.pinned.has(row.id):
            continue
        result.append(
            {
                "条目": row.name,
                "类型": row.kind,
                "记录数量": row.count,
                "个人目标": target,
                "缺口": gap,
                "覆盖比例": minf(1, float(row.count) / target) if target > 0 else 1.0,
                "个人优先级": priority,
                "个人重点": payload.pinned.has(row.id),
                "id": row.id
            }
        )
    result.sort_custom(
        func(a: Dictionary, b: Dictionary):
            if a["个人重点"] != b["个人重点"]:
                return bool(a["个人重点"])
            return float(a["个人优先级"]) * int(a["缺口"]) > float(b["个人优先级"]) * int(b["缺口"])
    )
    return result


static func differences(a: Dictionary, b: Dictionary) -> Array:
    var left := index(a)
    var right := index(b)
    var keys := left.duplicate()
    keys.merge(right, true)
    var result := []
    for id in keys:
        var before: Dictionary = left.get(id, {})
        var after: Dictionary = right.get(id, {})
        if not before.is_empty() and not after.is_empty() and before.kind == after.kind and before.count == after.count and before.status == after.status:
            continue
        var source: Dictionary = after if not after.is_empty() else before
        var kind := "新增已知条目" if before.is_empty() else "本次未包含" if after.is_empty() else "状态或数量变化"
        result.append(
            {
                "id": id,
                "条目": source.name,
                "类型": source.kind,
                "变化类型": kind,
                "旧数量": int(before.get("count", 0)),
                "新数量": int(after.get("count", 0)),
                "数量差": int(after.get("count", 0)) - int(before.get("count", 0)),
                "旧状态": String(before.get("status", "本次样本未包含")),
                "新状态": String(after.get("status", "本次样本未包含"))
            }
        )
    return result


static func rates(a: Dictionary, b: Dictionary) -> Array:
    var interval := float(int(b.recorded) - int(a.recorded)) / 60
    if interval <= 0:
        return []
    var result := []
    for row in differences(a, b):
        result.append(
            {
                "条目": row["条目"],
                "类型": row["类型"],
                "数量差": row["数量差"],
                "观察窗口分钟": interval,
                "两次观察间每分钟差值": float(row["数量差"]) / interval
            }
        )
    return result


static func stat_rows(payload: Dictionary) -> Array:
    var labels := {
        "max_hp": "生命上限",
        "max_energy": "能量上限",
        "move_mult": "移动倍率",
        "attack_damage_mult": "普攻伤害倍率",
        "heal_cost": "缝补费用",
        "heal_duration": "缝补准备秒",
        "skill_cost_mult": "线技费用倍率",
        "skill_damage_mult": "线技伤害倍率",
        "damage_taken_mult": "受伤倍率"
    }
    var result := []
    for key in payload.stats:
        result.append({"构筑字段": String(labels.get(key, key)), "记录值": payload.stats[key]})
    return result


static func history(records: Array) -> Array:
    var result := []
    for record in records.slice(0, 60):
        var payload: Dictionary = record.get("payload", {})
        if not validate(payload):
            continue
        var groups := counts(payload)
        result.append(
            {
                "id": record.id,
                "title": record.title,
                "time": payload.recorded,
                "counts": groups,
                "facts": payload.facts.size(),
                "payload": payload
            }
        )
    result.sort_custom(
        func(a: Dictionary, b: Dictionary):
            if int(a.time) == int(b.time):
                return int(a.id) < int(b.id)
            return int(a.time) < int(b.time)
    )
    return result


static func first_observed(records: Array) -> Array:
    var seen := {}
    var result := []
    for record in history(records):
        for fact in record.payload.facts:
            if not seen.has(fact.id):
                seen[fact.id] = true
                result.append(
                    {
                        "条目": fact.name,
                        "类型": fact.kind,
                        "首次包含此条目的记录": record.title,
                        "记录时间": V.date(int(record.time))
                    }
                )
    return result


static func history_changes(records: Array) -> Array:
    var ordered := history(records)
    var result := []
    for i in range(1, ordered.size()):
        var a: Dictionary = ordered[i - 1]
        var b: Dictionary = ordered[i]
        var changed := differences(a.payload, b.payload)
        var added := 0
        var reduced := 0
        for row in changed:
            added += 1 if row["变化类型"] == "新增已知条目" else 0
            reduced += 1 if int(row["数量差"]) < 0 else 0
        result.append(
            {
                "前记录": a.title,
                "后记录": b.title,
                "变化条目": changed.size() + stat_changes(a.payload, b.payload).size(),
                "新增已知条目": added,
                "数量减少条目": reduced,
                "观察窗口秒": int(b.time) - int(a.time)
            }
        )
    return result


static func history_sections(records: Array) -> Array:
    var ordered := history(records)
    var points := []
    var rows := []
    for record in ordered:
        points.append({"time": record.time, "name": record.title, "counts": record.counts})
        rows.append(
            {
                "记录": record.title,
                "记录时间": V.date(int(record.time)),
                "已知事实": record.facts,
                "能力": record.counts["能力"],
                "装备": record.counts["装备"],
                "任务": record.counts["任务"]
            }
        )
    return [
        {"kind": "custom", "title": "已保存观察的已知条目数", "view": VIEW, "data": {"points": points}},
        K.table("已存观察顺序", ["记录", "记录时间", "已知事实", "能力", "装备", "任务"], rows),
        K.table(
            "相邻观察变化", ["前记录", "后记录", "变化条目", "新增已知条目", "数量减少条目", "观察窗口秒"], history_changes(records)
        ),
        K.table(
            "首次在记录中出现",
            ["条目", "类型", "首次包含此条目的记录", "记录时间"],
            first_observed(records),
            "首次观察时间不是实际取得时间。"
        )
    ]


static func analyze(payload: Dictionary, _snapshot: Dictionary) -> Array:
    return [
        K.notice("已获成长观察", summary(payload)),
        K.bars("记录的已知条目类型", counts(payload)),
        K.table("已知事实", ["条目", "类型", "记录数量", "状态", "个人重点"], rows(payload)),
        K.table("个人已知目标", ["条目", "类型", "记录数量", "个人目标", "缺口", "覆盖比例", "个人优先级"], goals(payload)),
        K.table("构筑字段快照", ["构筑字段", "记录值"], stat_rows(payload)),
        K.notice("个人观察问题", String(payload.question)),
        K.notice("读数边界", "条目数量不是全游戏完成率。没有提前给出未取得能力、未公开任务或未选择结局的总数。物资减少可能来自正常消耗，样本缺失不等于进度损坏。")
    ]


static func stat_changes(a: Dictionary, b: Dictionary) -> Array:
    var result := []
    var keys: Dictionary = a.stats.duplicate()
    keys.merge(b.stats, true)
    for key in keys:
        if a.stats.get(key) != b.stats.get(key):
            result.append({"字段":key,"原值":a.stats.get(key),"当前值":b.stats.get(key)})
    return result


static func compare(a: Dictionary, b: Dictionary) -> Array:
    return [
        K.table("构筑字段变化", ["字段", "原值", "当前值"], stat_changes(a, b)),
        K.table(
            "两次观察间变化", ["条目", "类型", "变化类型", "旧数量", "新数量", "数量差", "旧状态", "新状态"], differences(a, b)
        ),
        K.table(
            "观察间平均差值",
            ["条目", "类型", "数量差", "观察窗口分钟", "两次观察间每分钟差值"],
            rates(a, b),
            "只用两次记录差值，不推断取得方式、准确取得时刻或未来成长速度。"
        )
    ]
