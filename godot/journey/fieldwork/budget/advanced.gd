extends RefCounted
## Exact subset DP minimizing required initial capital for eight fixed stages.
const K := preload("res://journey/fieldwork/knowledge.gd")
const STAGES := 8


static func catalogue(payload: Dictionary) -> Dictionary:
    var result := {}
    for row in payload.recipes:
        result[row.id] = row
    return result


static func fixed_net(payload: Dictionary, stage: int) -> float:
    return float(payload.income.get(str(stage), 0)) - float(payload.expenses.get(str(stage), 0)) - float(payload.contingency)


static func price(payload: Dictionary, recipe: Dictionary) -> float:
    return ceil(float(recipe.currency) * float(payload.cost_factor))


static func replay(payload: Dictionary, order: Array) -> Dictionary:
    var recipes := catalogue(payload)
    var seen := {}
    var net := 0.0
    var required := 0.0
    var minimum := INF
    var rows := []
    var material_cost := {}
    for stage in STAGES:
        var cost := 0.0
        var id := ""
        if stage < order.size():
            id = String(order[stage])
            if not recipes.has(id) or seen.has(id) or not payload.plan.has(id):
                return {"ok": false, "reason": "顺序包含未知、重复或未选择的配方"}
            seen[id] = true
            cost = price(payload, recipes[id])
            for material in recipes[id].materials:
                material_cost[material] = int(material_cost.get(material, 0)) + int(recipes[id].materials[material])
        net += fixed_net(payload, stage) - cost
        required = maxf(required, float(payload.reserve) - net)
        minimum = minf(minimum, net)
        rows.append({
            "阶段": stage + 1, "id": id, "目标": recipes[id].name if not id.is_empty() else "未安排改制",
            "改制成本": cost, "累计净流": net, "所需启动资金": maxf(0, required)
        })
    if seen.size() != payload.plan.size():
        return {"ok": false, "reason": "顺序漏掉了已选配方"}
    var gaps := {}
    for id in material_cost:
        var available := int(payload.inventory.get(id, 0)) + int(payload.material_inflow.get(id, 0))
        if int(material_cost[id]) > available:
            gaps[id] = int(material_cost[id]) - available
    return {
        "ok": true, "required": maxf(0, required), "additional": maxf(0, required - float(payload.initial)),
        "rows": rows, "material_gaps": gaps, "final_net": net
    }


static func solve(payload: Dictionary) -> Dictionary:
    if not payload.get("plan") is Array or payload.plan.size() > STAGES:
        return {"ok": false, "reason": "精确顺序规划最多八项"}
    var recipes := catalogue(payload)
    var ids: Array = payload.plan.duplicate()
    var seen := {}
    for id in ids:
        if not recipes.has(id) or seen.has(id):
            return {"ok": false, "reason": "计划目标无效或重复"}
        seen[id] = true
    var n := ids.size()
    var cost := []
    var count := []
    cost.resize(1 << n)
    count.resize(1 << n)
    cost.fill(0.0)
    count.fill(0)
    for mask in (1 << n):
        for i in n:
            if mask & (1 << i):
                cost[mask] += price(payload, recipes[ids[i]])
                count[mask] += 1
    var fixed := [0.0]
    for stage in STAGES:
        fixed.append(float(fixed[-1]) + fixed_net(payload, stage))
    var best := {0: 0.0}
    var parent := {}
    var transitions := 0
    for mask in (1 << n):
        if not best.has(mask):
            continue
        for i in n:
            if mask & (1 << i):
                continue
            transitions += 1
            var next := mask | (1 << i)
            var net := float(fixed[int(count[next])]) - float(cost[next])
            var needed := maxf(float(best[mask]), maxf(0, float(payload.reserve) - net))
            if not best.has(next) or needed < float(best[next]) - 0.000001:
                best[next] = needed
                parent[next] = {"mask": mask, "item": i}
    var cursor := (1 << n) - 1
    var order := []
    while cursor > 0:
        var step: Dictionary = parent[cursor]
        order.push_front(ids[int(step.item)])
        cursor = int(step.mask)
    var result := replay(payload, order)
    if not result.ok:
        return result
    # Empty later stages can require additional money, independent of order.
    var tail := float(best[(1 << n) - 1])
    for stage in range(n + 1, STAGES + 1):
        tail = maxf(tail, float(payload.reserve) - (float(fixed[stage]) - float(cost[-1])))
    result["order"] = order
    result["states"] = best.size()
    result["transitions"] = transitions
    result["certified"] = absf(float(result.required) - maxf(0, tail)) < 0.000001
    return result


static func sections(payload: Dictionary) -> Array:
    var optimized := solve(payload)
    if not optimized.ok:
        return [K.notice("预算顺序优化", optimized.reason)]
    var current := replay(payload, payload.plan)
    var gaps := []
    for id in optimized.material_gaps:
        gaps.append({"材料": payload.labels.get(id, id), "合计缺口": optimized.material_gaps[id]})
    return [
        K.notice("最低启动资金顺序",
            "当前顺序需%.1f，精确优化后需%.1f，按现有资金还需%.1f。%d个状态、%d次转移，复核%s。"
            % [current.required, optimized.required, optimized.additional, optimized.states,
                optimized.transitions, "通过" if optimized.certified else "未通过"]),
        K.table("优化后的八阶段计划", ["阶段", "目标", "改制成本", "累计净流", "所需启动资金"], optimized.rows),
        K.table("顺序不能消除的材料缺口", ["材料", "合计缺口"], gaps),
        K.notice("规划前提", "收入、其它开销及风险准备固定在原阶段；只交换已选改制目标，不自动采用此顺序。储备线在各阶段收入结算后检查；材料流入按原沙盘在起点可用。只优化货币启动资金，正式报价仍独立验证。")
    ]
