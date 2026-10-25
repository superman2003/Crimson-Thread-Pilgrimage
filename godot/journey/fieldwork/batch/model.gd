extends RefCounted
const K := preload("res://journey/fieldwork/knowledge.gd")
const V := preload("res://journey/fieldwork/scalars.gd")
const RECIPES := preload("res://journey/fieldwork/recipes/model.gd")
const BUILD := preload("res://scripts/build_system.gd")
const VIEW := preload("res://journey/fieldwork/batch/view.gd")
const LIMIT := 8


static func introduction() -> String:
    return "为最多八个已公开改制目标分配个人优先级，枚举资源可承受的组合并比较有效前沿。优先级来自个人计划，不代表游戏官方强度。"


static func capture(snapshot: Dictionary) -> Dictionary:
    var base := RECIPES.capture(snapshot)
    var candidates := []
    var weights := {}
    for row in base.recipes.slice(0, LIMIT):
        var candidate: Dictionary = row.duplicate(true)
        candidate["available"] = not row.crafted
        candidate["reason"] = "记录中尚未制作" if not row.crafted else "已经制作"
        if row.kind == "skill_branch":
            var source: Dictionary = snapshot.get("catalog", {}).get("recipes", {}).get(row.id, {})
            if (
                int(snapshot.get("build_state", {}).get("skill_levels", {}).get(row.target, 0))
                == int(source.get("branch", 0))
            ):
                candidate.available = false
                candidate.reason = "已经处于此校习方向"
        if (
            row.kind == "passive"
            and snapshot.get("build_state", {}).get("unlocked_passives", []).has(row.target)
        ):
            candidate.available = false
            candidate.reason = "该饰件已经获得"
        candidates.append(candidate)
        weights[row.id] = 1.0
    return {
        "candidates": candidates,
        "weights": weights,
        "mandatory": [],
        "inventory": base.inventory,
        "labels": base.labels,
        "wallet": base.wallet,
        "reserve": 0.0,
        "material_reserve": 0.0,
        "material_weight": 10.0,
        "policy": "value"
    }


static func validate(payload: Dictionary) -> bool:
    if (
        not payload.get("candidates") is Array
        or payload.candidates.size() > LIMIT
        or not payload.get("weights") is Dictionary
    ):
        return false
    if (
        not payload.get("mandatory") is Array
        or payload.mandatory.size() > LIMIT
        or not payload.get("inventory") is Dictionary
        or not payload.get("labels") is Dictionary
    ):
        return false
    if not V.count(payload.get("wallet")) or not V.count(payload.get("reserve")):
        return false
    if (
        not V.number(payload.get("material_reserve"))
        or payload.material_reserve < 0
        or payload.material_reserve > 100
    ):
        return false
    if (
        not V.number(payload.get("material_weight"))
        or payload.material_weight < 0
        or payload.material_weight > 10000
        or payload.get("policy") not in ["value", "count", "efficiency"]
    ):
        return false
    var ids := {}
    for row in payload.candidates:
        if (
            not row is Dictionary
            or not row.get("id") is String
            or ids.has(row.id)
            or not row.get("name") is String
        ):
            return false
        if (
            not row.get("kind") is String
            or not row.get("target") is String
            or not row.get("available") is bool
            or not row.get("reason") is String
        ):
            return false
        if (
            not V.count(row.get("currency"))
            or not row.get("materials") is Dictionary
            or row.materials.size() > 30
        ):
            return false
        for id in row.materials:
            if not id is String or not V.count(row.materials[id]):
                return false
        ids[row.id] = true
    for id in payload.weights:
        if (
            not ids.has(id)
            or not V.number(payload.weights[id])
            or payload.weights[id] < 0
            or payload.weights[id] > 100
        ):
            return false
    var seen := {}
    for id in payload.mandatory:
        if not id is String or not ids.has(id) or seen.has(id):
            return false
        seen[id] = true
    for id in payload.inventory:
        if not id is String or not V.count(payload.inventory[id]):
            return false
    for id in payload.labels:
        if (
            not id is String
            or not payload.labels[id] is String
            or payload.labels[id].length() > 200
        ):
            return false
    return V.json_safe(payload, 0, [V.MAX_ITEMS])


static func fields(payload: Dictionary) -> Array:
    var choices := []
    for row in payload.candidates:
        choices.append({"id": row.id, "name": row.name})
    return [
        {
            "id": "weights",
            "name": "个人目标优先级",
            "kind": "weights",
            "choices": choices,
            "min": 0,
            "max": 100
        },
        {"id": "mandatory", "name": "必须纳入的目标", "kind": "checklist", "choices": choices},
        {"id": "reserve", "name": "保留资金", "kind": "number", "min": 0, "max": 1000000},
        {
            "id": "material_reserve",
            "name": "保留材料比例百分比",
            "kind": "number",
            "min": 0,
            "max": 100,
            "step": 5
        },
        {"id": "material_weight", "name": "效率比较中的个人材料权重", "kind": "number", "min": 0, "max": 10000},
        {
            "id": "policy",
            "name": "选择策略",
            "kind": "choice",
            "choices":
            [
                {"id": "value", "name": "最大个人优先级"},
                {"id": "count", "name": "最多目标数量"},
                {"id": "efficiency", "name": "个人加权成本效率"}
            ]
        }
    ]


static func summary(payload: Dictionary) -> String:
    return "%d 个候选 · 资金%d · 保留%d" % [payload.candidates.size(), payload.wallet, payload.reserve]


static func usable_inventory(payload: Dictionary) -> Dictionary:
    var result := {}
    for id in payload.inventory:
        result[id] = int(
            floor(float(payload.inventory[id]) * (1 - float(payload.material_reserve) / 100))
        )
    return result


static func subset(payload: Dictionary, mask: int) -> Dictionary:
    var ids := []
    var materials := {}
    var branches := {}
    var currency := 0
    var value := 0.0
    var reasons := []
    for i in payload.candidates.size():
        if not mask & (1 << i):
            continue
        var row: Dictionary = payload.candidates[i]
        ids.append(row.id)
        currency += int(row.currency)
        value += float(payload.weights.get(row.id, 0))
        if not row.available:
            reasons.append(row.name + "：" + String(row.reason))
        if row.kind == "skill_branch":
            if branches.has(row.target):
                reasons.append("同一技能的校习方向冲突")
            branches[row.target] = true
        for id in row.materials:
            materials[id] = int(materials.get(id, 0)) + int(row.materials[id])
    for id in payload.mandatory:
        if not ids.has(id):
            reasons.append("缺少必选目标")
    var spending := maxi(0, int(payload.wallet) - int(payload.reserve))
    var missing_currency := maxi(0, currency - spending)
    if missing_currency > 0:
        reasons.append("超过可用资金")
    var inventory := usable_inventory(payload)
    var missing := {}
    var material_total := 0
    for id in materials:
        material_total += int(materials[id])
        var amount := maxi(0, int(materials[id]) - int(inventory.get(id, 0)))
        if amount > 0:
            missing[id] = amount
            reasons.append("材料不足：" + String(payload.labels.get(id, id)))
    var score_cost := float(currency) + material_total * float(payload.material_weight)
    var efficiency := value / maxf(1, score_cost)
    return {
        "mask": mask,
        "ids": ids,
        "currency": currency,
        "materials": materials,
        "material_total": material_total,
        "value": value,
        "efficiency": efficiency,
        "feasible": reasons.is_empty(),
        "reasons": reasons,
        "missing_currency": missing_currency,
        "missing_materials": missing
    }


static func enumerate(payload: Dictionary) -> Array:
    var result := []
    for mask in range(1 << payload.candidates.size()):
        result.append(subset(payload, mask))
    return result


static func better(a: Dictionary, b: Dictionary, policy: String) -> bool:
    if b.is_empty():
        return true
    var first: float = a.value
    var second: float = b.value
    if policy == "count":
        first = a.ids.size()
        second = b.ids.size()
    elif policy == "efficiency":
        first = a.efficiency
        second = b.efficiency
    if not is_equal_approx(first, second):
        return first > second
    if not is_equal_approx(float(a.value), float(b.value)):
        return a.value > b.value
    if a.currency != b.currency:
        return int(a.currency) < int(b.currency)
    if a.material_total != b.material_total:
        return int(a.material_total) < int(b.material_total)
    return int(a.mask) < int(b.mask)


static func best(payload: Dictionary, options: Array = []) -> Dictionary:
    var candidates := options if not options.is_empty() else enumerate(payload)
    var result := {}
    for candidate in candidates:
        if candidate.feasible and better(candidate, result, String(payload.policy)):
            result = candidate
    return result


static func dominates(a: Dictionary, b: Dictionary) -> bool:
    var no_worse: bool = (
        a.value >= b.value and a.currency <= b.currency and a.material_total <= b.material_total
    )
    var improved: bool = (
        a.value > b.value or a.currency < b.currency or a.material_total < b.material_total
    )
    return no_worse and improved


static func frontier(options: Array) -> Array:
    var result := []
    for candidate in options:
        if not candidate.feasible:
            continue
        var dominated := false
        for other in options:
            if other.feasible and dominates(other, candidate):
                dominated = true
                break
        if not dominated:
            result.append(candidate)
    result.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.currency) < int(b.currency))
    return result


static func names(payload: Dictionary, ids: Array) -> String:
    var result: Array[String] = []
    for row in payload.candidates:
        if ids.has(row.id):
            result.append(row.name)
    return " / ".join(result) if not result.is_empty() else "保留全部资源"


static func solution_rows(payload: Dictionary, options: Array) -> Array:
    var result := []
    for candidate in options:
        result.append(
            {
                "目标组合": names(payload, candidate.ids),
                "目标数": candidate.ids.size(),
                "个人优先级": candidate.value,
                "资金": candidate.currency,
                "材料合计": candidate.material_total,
                "个人效率": candidate.efficiency
            }
        )
    return result


static func sensitivity(payload: Dictionary) -> Array:
    var result := []
    for factor in [0.5, 0.75, 1.0, 1.25, 1.5]:
        var sample := payload.duplicate(true)
        sample.wallet = int(floor(float(payload.wallet) * float(factor)))
        var winner := best(sample)
        result.append(
            {
                "资金假设": sample.wallet,
                "可满足": not winner.is_empty(),
                "目标数": winner.get("ids", []).size(),
                "个人优先级": winner.get("value", 0),
                "支出": winner.get("currency", 0)
            }
        )
    return result


static func exclusion_reasons(payload: Dictionary, winner: Dictionary) -> Array:
    var result := []
    if winner.is_empty():
        return result
    for i in payload.candidates.size():
        var row: Dictionary = payload.candidates[i]
        if winner.ids.has(row.id):
            continue
        var candidate := subset(payload, int(winner.mask) | (1 << i))
        result.append(
            {
                "目标": row.name,
                "加入后优先级": candidate.value,
                "额外资金": int(candidate.currency) - int(winner.currency),
                "可加入": candidate.feasible,
                "原因":
                "；".join(candidate.reasons) if not candidate.reasons.is_empty() else "受当前选择策略影响"
            }
        )
    return result


static func closest_infeasible(payload: Dictionary, options: Array) -> Array:
    var candidates := []
    for candidate in options:
        if candidate.feasible or candidate.ids.is_empty():
            continue
        var shortage := int(candidate.missing_currency)
        for amount in candidate.missing_materials.values():
            shortage += int(amount) * int(payload.material_weight)
        candidates.append(
            {
                "目标组合": names(payload, candidate.ids),
                "个人优先级": candidate.value,
                "资金缺口": candidate.missing_currency,
                "材料缺口": candidate.missing_materials,
                "个人加权缺口": shortage,
                "原因": "；".join(candidate.reasons)
            }
        )
    candidates.sort_custom(
        func(a: Dictionary, b: Dictionary): return int(a["个人加权缺口"]) < int(b["个人加权缺口"])
    )
    return candidates.slice(0, 10)


static func actual_quote(solution: Dictionary, snapshot: Dictionary) -> Dictionary:
    if solution.is_empty() or solution.ids.is_empty():
        return {"ok": true, "reason": "没有制作目标，保留当前资源。"}
    var clone := BUILD.new()
    var restored: Dictionary = clone.restore(snapshot.get("build_state", {}))
    if not restored.ok:
        return {"ok": false, "reason": "当前构筑不能用于生产报价。"}
    clone.sync_progress(
        snapshot.get("inventory", {}), String(snapshot.get("region", "")), snapshot.get("flags", {})
    )
    return clone.quote_craft_batch(
        solution.ids,
        {
            "currency": int(snapshot.get("wallet", 0)),
            "inventory_counts": snapshot.get("inventory", {}).duplicate(true)
        }
    )


static func resource_balances(payload: Dictionary, solution: Dictionary) -> Array:
    if solution.is_empty():
        return []
    var available := usable_inventory(payload)
    var result := []
    for id in solution.materials:
        result.append(
            {
                "材料": String(payload.labels.get(id, id)),
                "持有": int(payload.inventory.get(id, 0)),
                "可用": int(available.get(id, 0)),
                "计划消费": int(solution.materials[id]),
                "保留后余额": int(available.get(id, 0)) - int(solution.materials[id])
            }
        )
    return result


static func analyze(payload: Dictionary, snapshot: Dictionary) -> Array:
    var options := enumerate(payload)
    var winner := best(payload, options)
    var efficient := frontier(options)
    var quote := actual_quote(winner, snapshot)
    var chart := []
    for candidate in options:
        chart.append(
            {
                "x": candidate.currency,
                "y": candidate.value,
                "feasible": candidate.feasible,
                "selected": not winner.is_empty() and candidate.mask == winner.mask,
                "name": names(payload, candidate.ids),
                "reason": "；".join(candidate.reasons)
            }
        )
    return [
        K.notice("批量方案优化", summary(payload)),
        K.notice("枚举规模", "完整检查%d种组合，最多八个候选。所有约束在内存中评估。" % options.size()),
        {
            "kind": "custom",
            "title": "个人价值与资金候选图",
            "view": VIEW,
            "data": {"points": chart, "budget": maxi(0, int(payload.wallet) - int(payload.reserve))}
        },
        K.table(
            "当前策略建议",
            ["目标组合", "目标数", "个人优先级", "资金", "材料合计", "个人效率"],
            solution_rows(payload, [winner] if not winner.is_empty() else [])
        ),
        K.table("有效前沿", ["目标组合", "个人优先级", "资金", "材料合计"], solution_rows(payload, efficient)),
        K.table("材料计划余额", ["材料", "持有", "可用", "计划消费", "保留后余额"], resource_balances(payload, winner)),
        K.table(
            "未纳入目标的原因", ["目标", "加入后优先级", "额外资金", "可加入", "原因"], exclusion_reasons(payload, winner)
        ),
        K.table("资金敏感性", ["资金假设", "可满足", "目标数", "个人优先级", "支出"], sensitivity(payload)),
        K.table(
            "接近资源边界的方案",
            ["目标组合", "个人优先级", "资金缺口", "材料缺口", "原因"],
            closest_infeasible(payload, options)
        ),
        K.notice(
            "当前生产报价复核",
            (
                "当前构筑与钱包检查通过；实际制作仍需原工匠、地点和门槛。未执行制作。"
                if quote.ok
                else String(quote.get("reason", "报价未通过"))
            )
        ),
        K.notice("计划含义", "个人优先级与材料权重都是自设偏好；分析不会将其解释为官方战力、游戏价格或自动制作授权。")
    ]


static func compare(a: Dictionary, b: Dictionary) -> Array:
    var left := best(a)
    var right := best(b)
    return [
        K.table(
            "最优计划变化",
            ["样本", "目标", "个人优先级", "资金"],
            [
                {
                    "样本": "记录",
                    "目标": names(a, left.get("ids", [])),
                    "个人优先级": left.get("value", 0),
                    "资金": left.get("currency", 0)
                },
                {
                    "样本": "当前",
                    "目标": names(b, right.get("ids", [])),
                    "个人优先级": right.get("value", 0),
                    "资金": right.get("currency", 0)
                }
            ]
        )
    ]


static func svg(payload: Dictionary) -> String:
    var report := preload("res://journey/fieldwork/vector.gd").new("个人批量目标与有效前沿", 1100, 1200)
    report.paragraph(summary(payload))
    var options := enumerate(payload)
    var winner := best(payload, options)
    var efficient := frontier(options)
    var max_cost := 1.0
    var max_value := 1.0
    for option in options:
        max_cost = maxf(max_cost, float(option.currency))
        max_value = maxf(max_value, float(option.value))
    report.title("个人优先级与资金成本")
    var area := Rect2(95, report.cursor + 30, 930, 320)
    report.axes(area, max_cost, 0, max_value, "资金成本", "个人优先级")
    var front_points := []
    for option in efficient:
        front_points.append(
            Vector2(
                area.position.x + float(option.currency) / max_cost * area.size.x,
                area.end.y - float(option.value) / max_value * area.size.y
            )
        )
    report.polyline(front_points, report.GOLD, 2.5)
    for option in options:
        var point := Vector2(
            area.position.x + float(option.currency) / max_cost * area.size.x,
            area.end.y - float(option.value) / max_value * area.size.y
        )
        report.circle(point, 3, report.GREEN if option.feasible else "#735e55")
        if not winner.is_empty() and option.mask == winner.mask:
            report.circle(point, 7, report.GOLD)
            report.text(point.x + 10, point.y - 8, "当前个人策略建议", 13, report.GOLD)
    var available := maxi(0, int(payload.wallet) - int(payload.reserve))
    var boundary := area.position.x + float(available) / max_cost * area.size.x
    if boundary <= area.end.x:
        report.line(
            Vector2(boundary, area.position.y), Vector2(boundary, area.end.y), report.RED, 1.5
        )
        report.text(boundary + 5, area.position.y + 18, "可用资金", 12, report.RED)
    report.cursor = area.end.y + 65
    report.paragraph("绿点满足当前记录的资源约束；金色折线是个人目标、资金与材料数量上的非支配前沿。不是官方强度或购买指令。")
    report.table(
        "策略结果",
        ["目标组合", "目标数", "个人优先级", "资金", "材料合计"],
        solution_rows(payload, [winner] if not winner.is_empty() else [])
    )
    report.table("有效前沿", ["目标组合", "个人优先级", "资金", "材料合计"], solution_rows(payload, efficient))
    report.table("材料计划余额", ["材料", "持有", "可用", "计划消费", "保留后余额"], resource_balances(payload, winner))
    report.title("不同资金假设下的个人目标")
    var study := sensitivity(payload)
    var budget_area := Rect2(95, report.cursor + 25, 930, 220)
    var maximum := 1.0
    for row in study:
        maximum = maxf(maximum, float(row["个人优先级"]))
    report.axes(budget_area, maxf(1, float(study.size() - 1)), 0, maximum, "资金情景序号", "最高个人优先级")
    var line := []
    for i in study.size():
        var point := Vector2(
            budget_area.position.x + budget_area.size.x * float(i) / maxi(1, study.size() - 1),
            budget_area.end.y - budget_area.size.y * float(study[i]["个人优先级"]) / maximum
        )
        line.append(point)
        report.circle(point, 4, report.GREEN)
    report.polyline(line)
    report.cursor = budget_area.end.y + 55
    report.table("资金情景读数", ["资金假设", "可满足", "目标数", "个人优先级", "支出"], study)
    report.table("未纳入目标", ["目标", "额外资金", "可加入", "原因"], exclusion_reasons(payload, winner))
    return report.finish("所有组合在内存中枚举。没有修改真实资金、库存或构筑。")
