extends RefCounted
## Integer target fit. Dynamic programming over conservative monetary ticks.
## Reports quantization and refuses excessive instances rather than hiding work.
const K := preload("res://journey/fieldwork/knowledge.gd")
const MAX_ASSETS := 12
const MAX_TICKS := 2000
const MAX_EXTRA := 40


static func active_assets(payload: Dictionary) -> Array:
    if not payload.has("integer_selected"):
        return []
    return payload.assets.filter(func(row: Dictionary): return payload.integer_selected.has(row.id))


static func prepare(payload: Dictionary) -> Dictionary:
    if active_assets(payload).size() > MAX_ASSETS:
        return {"ok": false, "reason": "整数目标精解最多12项；原有分配分析仍可使用全部物资"}
    var unit := maxf(0.01, ceil(float(payload.budget) / MAX_TICKS * 100.0) / 100.0)
    var budget_ticks := int(floor(float(payload.budget) / unit + 0.0000001))
    var entries := []
    var minimum_cost := 0.0
    var total_weight := 0.0
    for row in active_assets(payload):
        total_weight += float(payload.targets.get(row.id, 0))
    if total_weight <= 0 and not active_assets(payload).is_empty():
        return {"ok": false, "reason": "目标权重全为零，未定义整数拟合目标"}
    for row in active_assets(payload):
        var id := String(row.id)
        var price := float(payload.prices.get(id, 1))
        var reserve := int(ceil(float(payload.reserves.get(id, 0))))
        minimum_cost += reserve * price
        var desired := float(payload.budget) * float(payload.targets.get(id, 0)) / total_weight / price
        var affordable := int(floor(float(payload.budget) / price))
        var maximum := mini(affordable, maxi(reserve, int(ceil(desired))) + MAX_EXTRA)
        if maximum - reserve > 400:
            return {"ok": false, "reason": "单项整数候选超过400个，请缩小预算或调整权重"}
        entries.append({
            "id": id, "name": row.name, "price": price, "minimum": reserve,
            "maximum": maximum, "desired": desired
        })
    if minimum_cost > float(payload.budget) + 0.000001:
        return {"ok": false, "reason": "预算不足以满足向上取整后的储备"}
    return {"ok": true, "entries": entries, "unit": unit, "ticks": budget_ticks}


static func solve(payload: Dictionary) -> Dictionary:
    var prepared := prepare(payload)
    if not prepared.ok:
        return prepared
    var states := {0: {"loss": 0.0, "quantities": []}}
    var transitions := 0
    for item in prepared.entries:
        var next := {}
        for spent in states:
            for count in range(int(item.minimum), int(item.maximum) + 1):
                transitions += 1
                if transitions > 2000000:
                    return {"ok": false, "reason": "整数拟合超过200万次转移；保留原分配结果"}
                var ticks := int(ceil(count * float(item.price) / float(prepared.unit) - 0.0000001))
                var total := int(spent) + ticks
                if total > prepared.ticks:
                    break
                var error := absf(count - float(item.desired)) * float(item.price)
                var loss := float(states[spent].loss) + error
                if not next.has(total) or loss < float(next[total].loss) - 0.0000001:
                    var quantities: Array = states[spent].quantities.duplicate()
                    quantities.append(count)
                    next[total] = {"loss": loss, "quantities": quantities}
        states = next
        if states.is_empty():
            return {"ok": false, "reason": "保守刻度下储备无可行解；可尝试较小预算或原分配法"}
    var best := -1
    for spent in states:
        if best < 0 or float(states[spent].loss) < float(states[best].loss) - 0.0000001:
            best = spent
        elif is_equal_approx(float(states[spent].loss), float(states[best].loss)) and int(spent) < best:
            best = spent
    var rows := []
    var actual := 0.0
    var quantities: Array = states[best].quantities if best >= 0 else []
    for i in prepared.entries.size():
        var item: Dictionary = prepared.entries[i]
        var count := int(quantities[i])
        actual += count * float(item.price)
        rows.append({
            "物资": item.name, "id": item.id, "整数数量": count,
            "最低储备": item.minimum, "目标数量": snappedf(float(item.desired), 0.001),
            "个人等价开销": count * float(item.price)
        })
    return {
        "ok": true, "rows": rows, "spent": actual, "budget": float(payload.budget),
        "loss": float(states[best].loss) if best >= 0 else 0.0,
        "ticks": best, "unit": prepared.unit, "transitions": transitions,
        "quantization_bound": prepared.entries.size() * float(prepared.unit)
    }


static func certify(payload: Dictionary, result: Dictionary) -> bool:
    if not result.get("ok", false) or result.rows.size() != active_assets(payload).size():
        return false
    var actual := 0.0
    var expected := {}
    for asset in active_assets(payload):
        expected[asset.id] = true
    var seen := {}
    for row in result.rows:
        var id := String(row.id)
        if not expected.has(id) or seen.has(id) or not row["整数数量"] is int or row["整数数量"] < 0 or int(row["整数数量"]) < int(ceil(float(payload.reserves.get(id, 0)))):
            return false
        seen[id] = true
        actual += int(row["整数数量"]) * float(payload.prices.get(id, 1))
    return absf(actual - float(result.spent)) < 0.0001 and actual <= float(payload.budget) + 0.0001


static func sections(payload: Dictionary) -> Array:
    var result := solve(payload)
    if not result.ok:
        return [K.notice("整数目标拟合", result.reason)]
    return [
        K.notice("储备约束整数目标拟合",
            "目标误差%.3f；实际个人等价开销%.3f/%.3f；%d次转移；储备与预算复核%s。"
            % [result.loss, result.spent, result.budget, result.transitions,
                "通过" if certify(payload, result) else "未通过"]),
        K.table("整数拟合候选", ["物资", "整数数量", "最低储备", "目标数量", "个人等价开销"], result.rows),
        K.notice("精度与适用范围",
            "只分配勾选范围内至多12项；原有全部物资分析不变。在显示的有限整数候选及保守预算刻度上最优，不声称原连续预算下全局最优。每项费用向上取刻度，最多额外保留%.3f个人等价预算；不会超支。个人等价权重不是游戏售价，也不会生成或兑换物资。"
            % result.quantization_bound)
    ]
