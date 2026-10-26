extends RefCounted
const K := preload("res://journey/fieldwork/knowledge.gd")
const V := preload("res://journey/fieldwork/scalars.gd")
const RECIPES := preload("res://journey/fieldwork/recipes/model.gd")
const BUILD := preload("res://scripts/build_system.gd")
const VIEW := preload("res://journey/fieldwork/budget/view.gd")
const STAGES := 8


static func introduction() -> String:
    return "将当前真实资金作为起点，安排最多八段改制计划，比较个人假设收入、其它开销与储备线。预算段不是游戏日期，不执行消费或授予资金。"


static func capture(snapshot: Dictionary) -> Dictionary:
    var base := RECIPES.capture(snapshot)
    var income := {}
    var expenses := {}
    for i in STAGES:
        income[str(i)] = 0.0
        expenses[str(i)] = 0.0
    return {
        "recipes": base.recipes,
        "inventory": base.inventory,
        "labels": base.labels,
        "initial": base.wallet,
        "plan": [],
        "income": income,
        "expenses": expenses,
        "material_inflow": {},
        "reserve": 0.0,
        "cost_factor": 1.0,
        "contingency": 0.0
    }


static func validate(payload: Dictionary) -> bool:
    if (
        not payload.get("recipes") is Array
        or payload.recipes.size() > 100
        or not payload.get("plan") is Array
        or payload.plan.size() > STAGES
    ):
        return false
    if (
        not payload.get("inventory") is Dictionary
        or not payload.get("labels") is Dictionary
        or not V.count(payload.get("initial"))
    ):
        return false
    for key in ["reserve", "contingency"]:
        if not V.number(payload.get(key)) or payload[key] < 0 or payload[key] > 1000000:
            return false
    if (
        not V.number(payload.get("cost_factor"))
        or payload.cost_factor < 0.1
        or payload.cost_factor > 5
    ):
        return false
    var ids := {}
    var materials := {}
    for row in payload.recipes:
        if (
            not row is Dictionary
            or not row.get("id") is String
            or ids.has(row.id)
            or not row.get("name") is String
        ):
            return false
        if not V.count(row.get("currency")) or not row.get("materials") is Dictionary or row.materials.size() > 100:
            return false
        for id in row.materials:
            if not id is String or not V.count(row.materials[id]):
                return false
            materials[id] = true
        ids[row.id] = true
    var selected := {}
    for id in payload.plan:
        if not id is String or not ids.has(id) or selected.has(id):
            return false
        selected[id] = true
    for group in ["income", "expenses"]:
        if not payload.get(group) is Dictionary or payload[group].size() > STAGES:
            return false
        for stage in payload[group]:
            if (
                not stage is String
                or not stage.is_valid_int()
                or int(stage) < 0
                or int(stage) >= STAGES
            ):
                return false
            if not V.count(payload[group][stage]):
                return false
    if not payload.get("material_inflow") is Dictionary or payload.material_inflow.size() > 100:
        return false
    for id in payload.material_inflow:
        if not materials.has(id) or not V.count(payload.material_inflow[id]):
            return false
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
    var recipes := []
    var stages := []
    var materials := []
    var known := {}
    for row in payload.recipes:
        recipes.append({"id": row.id, "name": row.name})
        for id in row.materials:
            known[id] = true
    for id in known:
        materials.append({"id": id, "name": String(payload.labels.get(id, id))})
    for i in STAGES:
        stages.append({"id": str(i), "name": "第%d段" % (i + 1)})
    return [
        {
            "id": "plan",
            "name": "按顺序安排改制目标",
            "kind": "ordered",
            "choices": recipes,
            "limit": STAGES,
            "allow_duplicates": false
        },
        {
            "id": "income",
            "name": "每段个人假设收入",
            "kind": "weights",
            "choices": stages,
            "min": 0,
            "max": 1000000
        },
        {
            "id": "expenses",
            "name": "每段其它个人计划开销",
            "kind": "weights",
            "choices": stages,
            "min": 0,
            "max": 1000000
        },
        {
            "id": "material_inflow",
            "name": "计划开始前假设补足的材料",
            "kind": "weights",
            "choices": materials,
            "min": 0,
            "max": 1000000
        },
        {"id": "reserve", "name": "每段结束保留资金线", "kind": "number", "min": 0, "max": 1000000},
        {"id": "contingency", "name": "每段额外风险准备", "kind": "number", "min": 0, "max": 1000000},
        {
            "id": "cost_factor",
            "name": "个人成本倍率情景",
            "kind": "number",
            "min": 0.1,
            "max": 5,
            "step": 0.1
        }
    ]


static func summary(payload: Dictionary) -> String:
    return "记录资金%d · %d个计划目标 · 储备线%.0f" % [payload.initial, payload.plan.size(), payload.reserve]


static func index(payload: Dictionary) -> Dictionary:
    var result := {}
    for row in payload.recipes:
        result[row.id] = row
    return result


static func schedule(payload: Dictionary) -> Array:
    var recipes := index(payload)
    var balance := float(payload.initial)
    var materials: Dictionary = payload.inventory.duplicate()
    for id in payload.material_inflow:
        materials[id] = int(materials.get(id, 0)) + int(payload.material_inflow[id])
    var rows := []
    var cumulative_income := 0.0
    var cumulative_expense := 0.0
    for i in STAGES:
        var income := float(payload.income.get(str(i), 0))
        var other := float(payload.expenses.get(str(i), 0))
        var craft := 0.0
        var name := "没有改制目标"
        var shortages := []
        var before := balance
        if i < payload.plan.size():
            var recipe: Dictionary = recipes[payload.plan[i]]
            name = String(recipe.name)
            craft = ceil(float(recipe.currency) * float(payload.cost_factor))
            for id in recipe.materials:
                var required := int(recipe.materials[id])
                materials[id] = int(materials.get(id, 0)) - required
                if int(materials[id]) < 0:
                    shortages.append(
                        String(payload.labels.get(id, id)) + "缺" + str(-int(materials[id]))
                    )
        var expense := craft + other + float(payload.contingency)
        balance += income - expense
        cumulative_income += income
        cumulative_expense += expense
        rows.append(
            {
                "阶段": i + 1,
                "计划目标": name,
                "期初": before,
                "假设收入": income,
                "改制成本": craft,
                "其它开销": other,
                "风险准备": payload.contingency,
                "计划总开销": expense,
                "期末": balance,
                "储备差": balance - float(payload.reserve),
                "材料缺口": "；".join(shortages),
                "累计收入": cumulative_income,
                "累计开销": cumulative_expense
            }
        )
    return rows


static func liquidity(payload: Dictionary, rows: Array) -> Dictionary:
    var minimum := float(payload.initial)
    var maximum := minimum
    var first_negative := 0
    var first_reserve := 0
    var shortfall := 0.0
    for row in rows:
        minimum = minf(minimum, float(row["期末"]))
        maximum = maxf(maximum, float(row["期末"]))
        if first_negative == 0 and float(row["期末"]) < 0:
            first_negative = int(row["阶段"])
        if first_reserve == 0 and float(row["储备差"]) < 0:
            first_reserve = int(row["阶段"])
        shortfall = maxf(shortfall, -float(row["储备差"]))
    return {
        "min": minimum,
        "max": maximum,
        "first_negative": first_negative,
        "first_reserve": first_reserve,
        "additional": shortfall,
        "final": rows[-1]["期末"] if not rows.is_empty() else payload.initial
    }


static func required_start(payload: Dictionary) -> float:
    var sample := payload.duplicate(true)
    sample.initial = 0
    var minimum := 0.0
    for row in schedule(sample):
        minimum = minf(minimum, float(row["期末"]) - float(payload.reserve))
    return maxf(0, -minimum)


static func cost_sensitivity(payload: Dictionary) -> Array:
    var result := []
    for multiplier in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]:
        var sample := payload.duplicate(true)
        sample.cost_factor = float(multiplier)
        var stats := liquidity(sample, schedule(sample))
        result.append(
            {
                "个人成本倍率": multiplier,
                "最低计划余额": stats.min,
                "最终计划余额": stats.final,
                "最早跌破储备段": stats.first_reserve,
                "需补足假设资金": stats.additional
            }
        )
    return result


static func income_sensitivity(payload: Dictionary) -> Array:
    var result := []
    for factor in [0.0, 0.5, 0.75, 1.0, 1.25]:
        var sample := payload.duplicate(true)
        for stage in sample.income:
            sample.income[stage] = floor(float(sample.income[stage]) * float(factor))
        var stats := liquidity(sample, schedule(sample))
        result.append(
            {
                "假设收入实现比例": factor,
                "最低计划余额": stats.min,
                "最终计划余额": stats.final,
                "需补足假设资金": stats.additional
            }
        )
    return result


static func material_balance(payload: Dictionary) -> Array:
    var required := {}
    var recipes := index(payload)
    for id in payload.plan:
        for material in recipes[id].materials:
            required[material] = (
                int(required.get(material, 0)) + int(recipes[id].materials[material])
            )
    var result := []
    for id in required:
        var actual := int(payload.inventory.get(id, 0))
        var assumed := int(payload.material_inflow.get(id, 0))
        result.append(
            {
                "材料": String(payload.labels.get(id, id)),
                "记录持有": actual,
                "假设补足": assumed,
                "计划消耗": required[id],
                "计划余额": actual + assumed - int(required[id]),
                "仅现有材料缺口": maxi(0, int(required[id]) - actual)
            }
        )
    return result


static func mass_balance(payload: Dictionary, rows: Array) -> Dictionary:
    var income := 0.0
    var expense := 0.0
    for row in rows:
        income += float(row["假设收入"])
        expense += float(row["计划总开销"])
    var expected := float(payload.initial) + income - expense
    var actual := float(rows[-1]["期末"]) if not rows.is_empty() else float(payload.initial)
    return {
        "ok": absf(expected - actual) < 0.0001,
        "initial": payload.initial,
        "income": income,
        "expense": expense,
        "expected": expected,
        "actual": actual
    }


static func production_sequence(payload: Dictionary, snapshot: Dictionary) -> Array:
    var clone := BUILD.new()
    var result: Dictionary = clone.restore(snapshot.get("build_state", {}))
    if not result.ok:
        return [{"阶段": 0, "结果": "当前构筑无法用于独立试算"}]
    clone.sync_progress(
        snapshot.get("inventory", {}), String(snapshot.get("region", "")), snapshot.get("flags", {})
    )
    var wallet := {
        "currency": int(snapshot.get("wallet", 0)),
        "inventory_counts": snapshot.get("inventory", {}).duplicate(true)
    }
    var rows := []
    var recipes := index(payload)
    for i in payload.plan.size():
        var id := String(payload.plan[i])
        var quote: Dictionary = clone.transact(id, wallet)
        rows.append(
            {
                "阶段": i + 1,
                "目标": recipes[id].name,
                "现有资源生产规则": quote.ok,
                "结果": "可在独立实例中继续" if quote.ok else String(quote.get("reason", "失败"))
            }
        )
        if not quote.ok:
            break
        wallet = quote.wallet
    return rows


static func delay_study(payload: Dictionary) -> Array:
    var result := []
    for delay in range(0, 4):
        var sample := payload.duplicate(true)
        var shifted := {}
        var dropped := 0.0
        for stage in sample.income:
            var next := int(stage) + delay
            if next < STAGES:
                shifted[str(next)] = float(shifted.get(str(next), 0)) + float(sample.income[stage])
            else:
                dropped += float(sample.income[stage])
        sample.income = shifted
        var stats := liquidity(sample, schedule(sample))
        result.append(
            {
                "收入延后段数": delay,
                "样本末段以外收入": dropped,
                "最低余额": stats.min,
                "最终余额": stats.final,
                "假设补资需求": stats.additional
            }
        )
    return result


static func spending_shares(rows: Array) -> Dictionary:
    var result := {"改制目标": 0.0, "其它开销": 0.0, "风险准备": 0.0}
    for row in rows:
        result["改制目标"] += float(row["改制成本"])
        result["其它开销"] += float(row["其它开销"])
        result["风险准备"] += float(row["风险准备"])
    return result


static func analyze(payload: Dictionary, snapshot: Dictionary) -> Array:
    var rows := schedule(payload)
    var stats := liquidity(payload, rows)
    var audit := mass_balance(payload, rows)
    return [
        K.notice("旅途预算沙盘", summary(payload)),
        {
            "kind": "custom",
            "title": "个人计划余额与储备线",
            "view": VIEW,
            "data": {"rows": rows, "reserve": payload.reserve, "initial": payload.initial}
        },
        K.table(
            "逐段计划", ["阶段", "计划目标", "期初", "假设收入", "改制成本", "其它开销", "风险准备", "期末", "储备差", "材料缺口"], rows
        ),
        K.notice(
            "计划流动性",
            (
                "最低余额%.1f · 最终余额%.1f · 首次负余额段%d · 首次跌破储备段%d · 维持储备需额外假设资金%.1f。"
                % [
                    stats.min,
                    stats.final,
                    stats.first_negative,
                    stats.first_reserve,
                    stats.additional
                ]
            )
        ),
        K.notice("起点资金阈值", "在此计划与假设收入下，起点资金至少需%.1f以维持各段储备。" % required_start(payload)),
        K.bars("计划开销构成", spending_shares(rows)),
        K.table(
            "材料计划余额", ["材料", "记录持有", "假设补足", "计划消耗", "计划余额", "仅现有材料缺口"], material_balance(payload)
        ),
        K.table(
            "成本倍率敏感性",
            ["个人成本倍率", "最低计划余额", "最终计划余额", "最早跌破储备段", "需补足假设资金"],
            cost_sensitivity(payload)
        ),
        K.table(
            "假设收入敏感性", ["假设收入实现比例", "最低计划余额", "最终计划余额", "需补足假设资金"], income_sensitivity(payload)
        ),
        K.table("假设收入延迟", ["收入延后段数", "样本末段以外收入", "最低余额", "最终余额", "假设补资需求"], delay_study(payload)),
        K.table(
            "仅现有资源的生产顺序试算",
            ["阶段", "目标", "现有资源生产规则", "结果"],
            production_sequence(payload, snapshot),
            "独立实例只检查当前构筑与真实资源，不计假设收入；实际制作还需原工匠与站点。"
        ),
        K.notice(
            "收支复核",
            (
                "记录起点%.1f + 假设收入%.1f - 计划开销%.1f = 期末%.1f；%s。"
                % [
                    audit.initial,
                    audit.income,
                    audit.expense,
                    audit.actual,
                    "复核一致" if audit.ok else "未通过复核"
                ]
            )
        ),
        K.notice("使用边界", "这里只安排个人目标和假设。没有授予未来收入、替换主档、修改构筑或执行制作。")
    ]


static func compare(a: Dictionary, b: Dictionary) -> Array:
    var left := liquidity(a, schedule(a))
    var right := liquidity(b, schedule(b))
    return [
        K.table(
            "计划资金路径比较",
            ["样本", "起点", "最低计划余额", "最终计划余额", "储备线", "额外假设资金"],
            [
                {
                    "样本": "记录",
                    "起点": a.initial,
                    "最低计划余额": left.min,
                    "最终计划余额": left.final,
                    "储备线": a.reserve,
                    "额外假设资金": left.additional
                },
                {
                    "样本": "当前",
                    "起点": b.initial,
                    "最低计划余额": right.min,
                    "最终计划余额": right.final,
                    "储备线": b.reserve,
                    "额外假设资金": right.additional
                }
            ]
        )
    ]
