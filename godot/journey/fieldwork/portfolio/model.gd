extends RefCounted
const K := preload("res://journey/fieldwork/knowledge.gd")
const V := preload("res://journey/fieldwork/scalars.gd")
const VIEW := preload("res://journey/fieldwork/portfolio/view.gd")
const LIMIT := 60


static func introduction() -> String:
    return "按当前持有物资和个人等价权重检查集中度、储备与目标偏差。个人权重不是游戏价格，目标分配不会买卖、兑换或消耗物资。"


static func capture(snapshot: Dictionary) -> Dictionary:
    var assets := K.inventory(snapshot)
    var prices := {}
    var targets := {}
    var reserves := {}
    for row in assets.slice(0, LIMIT):
        prices[row.id] = 1.0
        targets[row.id] = 1.0
        reserves[row.id] = 0.0
    return {
        "assets": assets.slice(0, LIMIT),
        "prices": prices,
        "targets": targets,
        "reserves": reserves,
        "protected": [],
        "budget": 100.0,
        "loss": 25.0,
        "omitted": maxi(0, assets.size() - LIMIT)
    }


static func validate(payload: Dictionary) -> bool:
    if not payload.get("assets") is Array or payload.assets.size() > LIMIT:
        return false
    if (
        not payload.get("protected") is Array
        or payload.protected.size() > LIMIT
        or not V.count(payload.get("omitted"))
    ):
        return false
    if not V.number(payload.get("budget")) or payload.budget < 0 or payload.budget > 1000000:
        return false
    if not V.number(payload.get("loss")) or payload.loss < 0 or payload.loss > 100:
        return false
    var ids := {}
    for row in payload.assets:
        if not row is Dictionary or not row.get("id") is String or ids.has(row.id):
            return false
        if (
            not row.get("name") is String
            or row.name.length() > 200
            or not V.count(row.get("count"))
        ):
            return false
        ids[row.id] = true
    for group in ["prices", "targets", "reserves"]:
        if not payload.get(group) is Dictionary or payload[group].size() > LIMIT:
            return false
        for id in payload[group]:
            if not ids.has(id) or not V.number(payload[group][id]):
                return false
            var amount := float(payload[group][id])
            if amount < 0 or amount > 1000000 or (group == "prices" and amount < 0.01):
                return false
    var protected := {}
    for id in payload.protected:
        if not ids.has(id) or protected.has(id):
            return false
        protected[id] = true
    return V.json_safe(payload, 0, [V.MAX_ITEMS])


static func fields(payload: Dictionary) -> Array:
    var choices := []
    for row in payload.assets:
        choices.append({"id": row.id, "name": row.name})
    return [
        {
            "id": "prices", "default": 1.0,
            "name": "个人等价权重（不是价格）",
            "kind": "weights",
            "choices": choices,
            "min": 0.01,
            "max": 1000000
        },
        {
            "id": "targets",
            "name": "个人目标比例权重",
            "kind": "weights",
            "choices": choices,
            "min": 0,
            "max": 1000000
        },
        {
            "id": "reserves",
            "name": "最低个人储备数量",
            "kind": "weights",
            "choices": choices,
            "min": 0,
            "max": 1000000
        },
        {"id": "protected", "name": "假设损耗中保护的物资", "kind": "checklist", "choices": choices},
        {"id": "budget", "name": "个人等价单位分配预算", "kind": "number", "min": 0, "max": 1000000},
        {"id": "loss", "name": "假设损耗百分比", "kind": "number", "min": 0, "max": 100, "step": 5}
    ]


static func summary(payload: Dictionary) -> String:
    return (
        "%d 项当前持有物资 · 个人分配预算 %.1f · 未纳入%d项"
        % [payload.assets.size(), payload.budget, payload.omitted]
    )


static func asset_index(payload: Dictionary) -> Dictionary:
    var result := {}
    for row in payload.assets:
        result[row.id] = row
    return result


static func normalize(weights: Dictionary, ids: Array) -> Dictionary:
    var total := 0.0
    for id in ids:
        total += maxf(0, float(weights.get(id, 0)))
    var result := {}
    for id in ids:
        result[id] = maxf(0, float(weights.get(id, 0))) / total if total > 0 else 0.0
    return result


static func exposures(payload: Dictionary) -> Array:
    var values := {}
    var index := asset_index(payload)
    for row in payload.assets:
        values[row.id] = int(row.count) * float(payload.prices.get(row.id, 1))
    var shares := normalize(values, index.keys())
    var targets := normalize(payload.targets, index.keys())
    var result := []
    for row in payload.assets:
        var id := String(row.id)
        result.append(
            {
                "id": id,
                "物资": row.name,
                "数量": row.count,
                "个人等价权重": float(payload.prices.get(id, 1)),
                "等价合计": values[id],
                "实际占比": shares[id],
                "目标占比": targets[id],
                "占比偏差": float(shares[id]) - float(targets[id])
            }
        )
    result.sort_custom(
        func(a: Dictionary, b: Dictionary): return float(a["等价合计"]) > float(b["等价合计"])
    )
    return result


static func concentration(payload: Dictionary) -> Dictionary:
    var hhi := 0.0
    var entropy := 0.0
    var total := 0.0
    var positive := 0
    for row in exposures(payload):
        var share := float(row["实际占比"])
        total += float(row["等价合计"])
        hhi += share * share
        if share > 0:
            entropy -= share * log(share)
            positive += 1
    return {
        "total": total,
        "hhi": hhi,
        "effective": 1.0 / hhi if hhi > 0 else 0.0,
        "entropy": entropy,
        "normalized_entropy": entropy / log(float(positive)) if positive > 1 else 0.0,
        "positive": positive
    }


static func lorenz(payload: Dictionary) -> Array:
    var rows := exposures(payload)
    rows.reverse()
    var result := [{"x": 0.0, "y": 0.0, "name": "起点"}]
    var cumulative := 0.0
    for i in rows.size():
        cumulative += float(rows[i]["实际占比"])
        result.append({"x": float(i + 1) / rows.size(), "y": cumulative, "name": rows[i]["物资"]})
    return result


static func gini(payload: Dictionary) -> float:
    var points := lorenz(payload)
    if concentration(payload).total <= 0:
        return 0.0
    var area := 0.0
    for i in range(1, points.size()):
        var width := float(points[i].x) - float(points[i - 1].x)
        area += width * (float(points[i].y) + float(points[i - 1].y)) * 0.5
    return clampf(1 - 2 * area, 0, 1)


static func reserves(payload: Dictionary) -> Array:
    var result := []
    for row in payload.assets:
        var desired := int(ceil(float(payload.reserves.get(row.id, 0))))
        var amount := int(row.count)
        result.append(
            {
                "物资": row.name,
                "现有": amount,
                "个人储备": desired,
                "储备缺口": maxi(0, desired - amount),
                "储备以上": maxi(0, amount - desired),
                "覆盖比例": float(amount) / desired if desired > 0 else "未设置",
                "保护": payload.protected.has(row.id)
            }
        )
    return result


static func reserve_cost(payload: Dictionary) -> float:
    var total := 0.0
    for row in payload.assets:
        total += ceil(float(payload.reserves.get(row.id, 0))) * float(payload.prices.get(row.id, 1))
    return total


static func allocation(payload: Dictionary) -> Dictionary:
    var minimum := reserve_cost(payload)
    var budget := float(payload.budget)
    if minimum > budget + 0.00001:
        return {"ok":false,"reason":"个人预算不足以覆盖储备。","rows":[],"spent":0.0,"remainder":budget}
    var index := asset_index(payload)
    var weights := normalize(payload.targets, index.keys())
    # Water-fill the full target values while clamping each mandatory reserve.
    var low := 0.0
    var high := budget
    var has_weight := false
    for weight in weights.values():
        has_weight = has_weight or float(weight) > 0
    if has_weight:
        for iteration in 64:
            var mid := (low + high) * 0.5
            var total := 0.0
            for row in payload.assets:
                var price := float(payload.prices.get(row.id, 1))
                var reserve := ceilf(float(payload.reserves.get(row.id, 0))) * price
                total += maxf(reserve, mid * float(weights[row.id]))
            if total > budget:
                high = mid
            else:
                low = mid
    var rows := []
    var spent := 0.0
    for row in payload.assets:
        var price := float(payload.prices.get(row.id, 1))
        var count := maxi(int(ceil(float(payload.reserves.get(row.id, 0)))), int(floor(low * float(weights[row.id]) / price)))
        rows.append({"id":row.id,"物资":row.name,"目标数量":count,"等价成本":count*price,"单份等价":price,"实际持有":row.count,"余数":low*float(weights[row.id])/price-count})
        spent += count * price
    # Redistribute stranded integer rounding budget among affordable targets.
    while true:
        var eligible := []
        var total_weight := 0.0
        var remaining := maxf(0, budget - spent)
        for row in rows:
            if float(weights[row.id]) > 0 and float(row["单份等价"]) <= remaining + 0.000001:
                eligible.append(row)
                total_weight += float(weights[row.id])
        if eligible.is_empty():
            break
        var additions := 0
        for row in eligible:
            var count := int(floor(remaining * float(weights[row.id]) / total_weight / float(row["单份等价"])))
            count = mini(count, int(floor((budget - spent + 0.000001) / float(row["单份等价"]))))
            if count > 0:
                row["目标数量"] += count
                row["等价成本"] += count * float(row["单份等价"])
                spent += count * float(row["单份等价"])
                additions += count
        if additions == 0:
            eligible.sort_custom(func(a: Dictionary, b: Dictionary): return float(a["余数"]) > float(b["余数"]))
            var row: Dictionary = eligible[0]
            row["目标数量"] += 1
            row["等价成本"] += float(row["单份等价"])
            spent += float(row["单份等价"])
    for row in rows:
        row["数量偏差"] = int(row["实际持有"]) - int(row["目标数量"])
    return {"ok":true,"reason":"储备约束下的个人权重整数近似分配。","rows":rows,"spent":spent,"remainder":maxf(0,budget-spent)}


static func stress(payload: Dictionary, loss: float, only: String = "") -> Dictionary:
    var sample := payload.duplicate(true)
    for row in sample.assets:
        if sample.protected.has(row.id) or (not only.is_empty() and row.id != only):
            continue
        var minimum := int(ceil(float(sample.reserves.get(row.id, 0))))
        var exposed := maxi(0, int(row.count) - minimum)
        var lost := int(floor(exposed * clampf(loss, 0, 100) / 100))
        row.count = maxi(0, int(row.count) - lost)
    return sample


static func stress_rows(payload: Dictionary) -> Array:
    var baseline := concentration(payload)
    var result := []
    for amount in [0, 10, 25, 50, 75, 100]:
        var sample := stress(payload, float(amount))
        var stats := concentration(sample)
        result.append(
            {
                "假设损耗百分比": amount,
                "等价合计": stats.total,
                "等价减少": float(baseline.total) - float(stats.total),
                "集中度": stats.hhi,
                "有效物资数": stats.effective
            }
        )
    return result


static func single_exposure(payload: Dictionary) -> Array:
    var base := concentration(payload)
    var result := []
    for row in payload.assets:
        var sample := stress(payload, float(payload.loss), String(row.id))
        var next := concentration(sample)
        result.append(
            {
                "仅此物资假设损耗": row.name,
                "个人等价减少": float(base.total) - float(next.total),
                "减少比例": (float(base.total) - float(next.total)) / float(base.total) if float(base.total) > 0 else 0.0,
                "保护": payload.protected.has(row.id)
            }
        )
    result.sort_custom(
        func(a: Dictionary, b: Dictionary): return float(a["个人等价减少"]) > float(b["个人等价减少"])
    )
    return result


static func target_alignment(payload: Dictionary) -> Dictionary:
    var actual := []
    var desired := []
    var absolute := 0.0
    var squared := 0.0
    for row in exposures(payload):
        var a := float(row["实际占比"])
        var b := float(row["目标占比"])
        actual.append(a)
        desired.append(b)
        absolute += absf(a - b)
        squared += pow(a - b, 2)
    var first := K.distribution(actual)
    var second := K.distribution(desired)
    var numerator := 0.0
    for i in actual.size():
        numerator += (
            (float(actual[i]) - float(first.mean)) * (float(desired[i]) - float(second.mean))
        )
    var denominator := float(actual.size()) * float(first.deviation) * float(second.deviation)
    return {
        "absolute": absolute,
        "euclidean": sqrt(squared),
        "defined": denominator > 0.000001,
        "correlation": numerator / denominator if denominator > 0.000001 else 0.0
    }


static func allocation_sensitivity(payload: Dictionary) -> Array:
    var result := []
    for factor in [0.5, 0.75, 1.0, 1.25, 1.5]:
        var sample := payload.duplicate(true)
        sample.budget = float(payload.budget) * float(factor)
        var plan := allocation(sample)
        var units := 0
        for row in plan.rows:
            units += int(row["目标数量"])
        result.append(
            {
                "个人等价预算": sample.budget,
                "储备可覆盖": plan.ok,
                "近似目标总份数": units,
                "计划等价成本": plan.spent,
                "未分配等价": plan.remainder
            }
        )
    return result


static func mass_balance(payload: Dictionary) -> Array:
    var total := 0
    var positive := 0
    var protected := 0
    var deficit := 0
    for row in payload.assets:
        total += int(row.count)
        positive += 1 if int(row.count) > 0 else 0
        if payload.protected.has(row.id):
            protected += int(row.count)
        deficit += maxi(0, int(ceil(float(payload.reserves.get(row.id, 0)))) - int(row.count))
    return [
        {"指标": "持有条目数", "值": positive},
        {"指标": "各物资数量相加", "值": total},
        {"指标": "被保护物资数量相加", "值": protected},
        {"指标": "个人储备缺口数量相加", "值": deficit},
        {"指标": "未纳入条目数", "值": payload.omitted}
    ]


static func analyze(payload: Dictionary, _snapshot: Dictionary) -> Array:
    var stats := concentration(payload)
    var alignment := target_alignment(payload)
    var plan := allocation(payload)
    var chart := lorenz(payload)
    var coverage := reserves(payload)
    return [
        K.notice("物资组合", summary(payload)),
        K.notice(
            "个人权重下的分布",
            (
                "等价合计 %.1f · HHI集中度 %.3f · 有效物资数 %.2f · 归一化熵 %.3f · Gini %.3f"
                % [stats.total, stats.hhi, stats.effective, stats.normalized_entropy, gini(payload)]
            )
        ),
        {
            "kind": "custom",
            "title": "个人等价占比分布曲线",
            "view": VIEW,
            "data": {"points": chart, "gini": gini(payload)}
        },
        K.table(
            "物资占比与目标偏差", ["物资", "数量", "个人等价权重", "等价合计", "实际占比", "目标占比", "占比偏差"], exposures(payload)
        ),
        K.table("个人储备覆盖", ["物资", "现有", "个人储备", "储备缺口", "储备以上", "覆盖比例", "保护"], coverage),
        K.notice(
            "个人目标匹配",
            (
                "占比绝对偏差 %.3f · 欧氏偏差 %.3f；目标相关性%s。"
                % [
                    alignment.absolute,
                    alignment.euclidean,
                    str(alignment.correlation) if alignment.defined else "因均匀或空样本而未定义"
                ]
            )
        ),
        K.notice("个人等价预算分配", String(plan.reason)),
        K.table("近似目标份数", ["物资", "目标数量", "等价成本", "实际持有", "数量偏差"], plan.rows),
        K.table(
            "个人预算敏感性",
            ["个人等价预算", "储备可覆盖", "近似目标总份数", "计划等价成本", "未分配等价"],
            allocation_sensitivity(payload)
        ),
        K.table(
            "假设损耗场景",
            ["假设损耗百分比", "等价合计", "等价减少", "集中度", "有效物资数"],
            stress_rows(payload),
            "只对个人储备以外且未保护的部分作数学假设，不代表游戏死亡或掉落规则。"
        ),
        K.table("单项暴露", ["仅此物资假设损耗", "个人等价减少", "减少比例", "保护"], single_exposure(payload)),
        K.table("数量核对", ["指标", "值"], mass_balance(payload)),
        K.notice("使用边界", "物资用途不同，数量和个人等价单位不能解释为真实购买力、战力或兑换承诺。")
    ]


static func compare(a: Dictionary, b: Dictionary) -> Array:
    var left := asset_index(a)
    var right := asset_index(b)
    var keys := left.duplicate()
    keys.merge(right, true)
    var rows := []
    for id in keys:
        var before := int(left.get(id, {}).get("count", 0))
        var after := int(right.get(id, {}).get("count", 0))
        rows.append(
            {
                "物资": String(right.get(id, left.get(id, {})).get("name", id)),
                "旧数量": before,
                "新数量": after,
                "变化": after - before
            }
        )
    return [
        K.table("持有数量变化", ["物资", "旧数量", "新数量", "变化"], rows),
        K.notice("比较权重", "数量变化可以直接比较；个人等价统计需先确认两份记录的个人权重相同。")
    ]


static func svg(payload: Dictionary) -> String:
    var report := preload("res://journey/fieldwork/vector.gd").new("个人物资组合与储备", 1100, 1700)
    report.paragraph(summary(payload))
    var stats := concentration(payload)
    report.paragraph(
        (
            "个人等价合计%.2f，HHI集中度%.3f，有效物资数%.2f，Gini %.3f。个人等价权重不是游戏价格。"
            % [stats.total, stats.hhi, stats.effective, gini(payload)]
        )
    )
    report.title("按个人等价从小到大累计")
    var area := Rect2(95, report.cursor + 30, 930, 280)
    report.axes(area, 1, 0, 1, "累计条目占比", "累计个人等价占比")
    report.line(
        Vector2(area.position.x, area.end.y), Vector2(area.end.x, area.position.y), "#617d58", 1.5
    )
    var line := []
    for point in lorenz(payload):
        line.append(
            Vector2(
                area.position.x + float(point.x) * area.size.x,
                area.end.y - float(point.y) * area.size.y
            )
        )
    report.polyline(line, report.GOLD, 2.5)
    report.cursor = area.end.y + 65
    report.paragraph("斜线只是均匀分布参考。物资用途不同，集中度不能解释为官方强弱或真实交易风险。")
    report.title("主要物资的个人等价占比")
    var exposures := exposures(payload)
    for row in exposures.slice(0, 20):
        var y := report.cursor
        var current := float(row["实际占比"])
        var target := float(row["目标占比"])
        report.text(28, y + 17, String(row["物资"]).left(18), 13)
        report.rect(Rect2(250, y + 3, 650 * current, 17), report.GREEN)
        var target_x := 250 + 650 * target
        report.line(Vector2(target_x, y), Vector2(target_x, y + 23), report.GOLD, 2)
        report.text(925, y + 17, "%.1f%%" % (current * 100), 12, report.MUTED)
        report.cursor += 28
    report.paragraph("绿色为当前个人等价占比；金色短线为个人目标占比。")
    report.title("个人储备覆盖")
    var reserves := reserves(payload)
    for row in reserves.slice(0, 20):
        var desired := int(row["个人储备"])
        var held := int(row["现有"])
        var ratio := minf(1, float(held) / desired) if desired > 0 else 1.0
        report.text(28, report.cursor + 17, String(row["物资"]).left(18), 13)
        report.rect(Rect2(250, report.cursor + 3, 650, 16), "#30483b")
        report.rect(
            Rect2(250, report.cursor + 3, 650 * ratio, 16),
            report.GREEN if held >= desired else report.RED
        )
        report.text(925, report.cursor + 17, str(held) + " / " + str(desired), 12, report.MUTED)
        report.cursor += 26
    report.cursor += 10
    report.paragraph("储备是个人填写的最低数量，不是游戏要求。未设置储备时覆盖条显示为完整。")
    report.table("数量与目标", ["物资", "数量", "实际占比", "目标占比", "占比偏差"], exposures)
    var plan := allocation(payload)
    report.paragraph(String(plan.reason))
    report.table("个人等价预算的近似目标", ["物资", "目标数量", "等价成本", "实际持有", "数量偏差"], plan.rows)
    report.title("假设损耗对个人等价合计的影响")
    var stress := stress_rows(payload)
    var top := report.cursor
    var maximum := maxf(1, float(stats.total))
    var chart := Rect2(95, top + 25, 930, 240)
    report.axes(chart, 100, 0, maximum, "个人假设损耗百分比", "个人等价合计")
    var stress_line := []
    for row in stress:
        var point := Vector2(
            chart.position.x + chart.size.x * float(row["假设损耗百分比"]) / 100,
            chart.end.y - chart.size.y * float(row["等价合计"]) / maximum
        )
        stress_line.append(point)
        report.circle(point, 4, report.RED)
    report.polyline(stress_line, report.RED)
    report.cursor = chart.end.y + 55
    report.table("假设损耗读数", ["假设损耗百分比", "等价合计", "等价减少", "集中度", "有效物资数"], stress)
    report.table("单项假设暴露", ["仅此物资假设损耗", "个人等价减少", "减少比例", "保护"], single_exposure(payload))
    report.table(
        "个人预算情景", ["个人等价预算", "储备可覆盖", "近似目标总份数", "计划等价成本", "未分配等价"], allocation_sensitivity(payload)
    )
    report.table("数量核对", ["指标", "值"], mass_balance(payload))
    var target := target_alignment(payload)
    report.paragraph(
        "个人目标绝对偏差%.3f，欧氏偏差%.3f。均匀或空样本下的相关性不作数值解释。" % [target.absolute, target.euclidean]
    )
    report.paragraph("假设损耗只作用于未保护、且超过个人最低储备的部分。它不代表死亡掉落、敌人掠夺或任何游戏规则。")
    report.paragraph("图中的数量来自此观察样本。未纳入的条目%d项；比较另一份观察时，应先确认个人权重和采集范围相同。" % payload.omitted)
    return report.finish("此报告不执行买卖、兑换、使用物资或修改主档。")
