extends RefCounted
const K := preload("res://journey/fieldwork/knowledge.gd")
const V := preload("res://journey/fieldwork/scalars.gd")
const RECIPES := preload("res://journey/fieldwork/recipes/model.gd")
const HISTORY_VIEW := preload("res://journey/fieldwork/prices/history_view.gd")
const VIEW := preload("res://journey/fieldwork/batch/view.gd")


static func introduction() -> String:
    return "记录已公开配方的目录成本，比较历史变化与个人价格假设。折扣、附加费和假设份数只用于计算，不改变实际报价或制作规则。"


static func capture(snapshot: Dictionary) -> Dictionary:
    var quotes := []
    var prices := {}
    var quantities := {}
    for recipe in RECIPES.known_recipes(snapshot):
        quotes.append(
            {
                "id": recipe.id,
                "name": recipe.name,
                "price": recipe.currency,
                "kind": recipe.kind,
                "target": recipe.target,
                "materials": recipe.materials.duplicate(true)
            }
        )
        prices[recipe.id] = float(recipe.currency)
        quantities[recipe.id] = 1.0
    return {
        "quotes": quotes,
        "prices": prices,
        "quantities": quantities,
        "recorded": int(snapshot.get("timestamp", 0)),
        "discount": 0.0,
        "fee": 0.0,
        "focus": String(quotes[0].id) if not quotes.is_empty() else "",
        "rounding": "ceil",
        "wallet": int(snapshot.get("wallet", 0))
    }


static func validate(payload: Dictionary) -> bool:
    if (
        not payload.get("quotes") is Array
        or payload.quotes.size() > 100
        or not payload.get("prices") is Dictionary
        or not payload.get("quantities") is Dictionary
    ):
        return false
    if (
        not V.count(payload.get("recorded"), 9999999999)
        or not V.count(payload.get("wallet"))
        or not payload.get("focus") is String
    ):
        return false
    if payload.get("rounding") not in ["ceil", "nearest", "exact"]:
        return false
    if not V.number(payload.get("discount")) or payload.discount < 0 or payload.discount > 100:
        return false
    if not V.number(payload.get("fee")) or payload.fee < 0 or payload.fee > 1000000:
        return false
    var ids := {}
    for quote in payload.quotes:
        if not quote is Dictionary or not quote.get("id") is String or ids.has(quote.id):
            return false
        if (
            not quote.get("name") is String
            or quote.name.length() > 200
            or not quote.get("kind") is String
            or not quote.get("target") is String
        ):
            return false
        if (
            not V.count(quote.get("price"))
            or not quote.get("materials") is Dictionary
            or quote.materials.size() > 30
        ):
            return false
        for id in quote.materials:
            if not id is String or not V.count(quote.materials[id]):
                return false
        ids[quote.id] = true
    if not payload.focus.is_empty() and not ids.has(payload.focus):
        return false
    for field in ["prices", "quantities"]:
        if payload[field].size() > 100:
            return false
        for id in payload[field]:
            if (
                not ids.has(id)
                or not V.number(payload[field][id])
                or payload[field][id] < 0
                or payload[field][id] > 1000000
            ):
                return false
            if field == "quantities" and not V.count(payload[field][id], 10000):
                return false
    return V.json_safe(payload, 0, [V.MAX_ITEMS])


static func fields(payload: Dictionary) -> Array:
    var choices := []
    for row in payload.quotes:
        choices.append({"id": row.id, "name": row.name})
    return [
        {"id": "focus", "name": "分析方案", "kind": "choice", "choices": choices},
        {
            "id": "prices",
            "name": "个人假设单价（默认目录成本）",
            "kind": "weights",
            "choices": choices,
            "min": 0,
            "max": 1000000
        },
        {
            "id": "quantities",
            "name": "个人假设份数",
            "kind": "weights",
            "choices": choices,
            "min": 0,
            "max": 10000
        },
        {"id": "discount", "name": "个人假设折扣百分比", "kind": "number", "min": 0, "max": 100},
        {"id": "fee", "name": "每份计划的假设固定附加费", "kind": "number", "min": 0, "max": 1000000},
        {
            "id": "rounding",
            "name": "假设总额取整",
            "kind": "choice",
            "choices":
            [
                {"id": "ceil", "name": "向上取整"},
                {"id": "nearest", "name": "四舍五入"},
                {"id": "exact", "name": "保留小数"}
            ]
        }
    ]


static func summary(payload: Dictionary) -> String:
    return "%d 条已公开目录成本 · %s" % [payload.quotes.size(), V.date(int(payload.recorded))]


static func index(payload: Dictionary) -> Dictionary:
    var result := {}
    for row in payload.quotes:
        result[row.id] = row
    return result


static func round_cost(value: float, method: String) -> float:
    if method == "ceil":
        return ceil(value)
    if method == "nearest":
        return round(value)
    return value


static func total(payload: Dictionary, id: String, amount: float) -> Dictionary:
    var quote: Dictionary = index(payload).get(id, {})
    if quote.is_empty():
        return {"ok": false, "gross": 0.0, "net": 0.0, "unit": 0.0, "savings": 0.0, "rounding": 0.0}
    var price := float(payload.prices.get(id, quote.price))
    var gross := price * maxf(0, amount)
    var base := gross * (1 - float(payload.discount) / 100)
    var raw := base + (float(payload.fee) if amount > 0 else 0.0)
    var net := round_cost(raw, String(payload.rounding))
    return {
        "ok": true,
        "gross": gross,
        "net": net,
        "unit": net / amount if amount > 0 else 0.0,
        "savings": gross - net,
        "rounding": net - raw
    }


static func quote_rows(payload: Dictionary) -> Array:
    var result := []
    for quote in payload.quotes:
        var amount := float(payload.quantities.get(quote.id, 0))
        var cost := total(payload, String(quote.id), amount)
        var proposed := float(payload.prices.get(quote.id, quote.price))
        var altered := (
            not is_equal_approx(proposed, float(quote.price))
            or float(payload.discount) != 0
            or float(payload.fee) != 0
        )
        result.append(
            {
                "方案": quote.name,
                "目录成本": quote.price,
                "个人假设单价": proposed,
                "假设份数": amount,
                "假设总额": cost.net,
                "假设每份成本": cost.unit,
                "来源": "个人假设" if altered else "记录中的目录成本",
                "取整影响": cost.rounding
            }
        )
    return result


static func basket(payload: Dictionary) -> Dictionary:
    var gross := 0.0
    var net := 0.0
    var count := 0.0
    var altered := 0
    var materials := {}
    for quote in payload.quotes:
        var quantity := float(payload.quantities.get(quote.id, 0))
        var cost := total(payload, String(quote.id), quantity)
        gross += float(cost.gross)
        net += float(cost.net)
        count += quantity
        if not is_equal_approx(
            float(payload.prices.get(quote.id, quote.price)), float(quote.price)
        ):
            altered += 1
        for material in quote.materials:
            materials[material] = (
                float(materials.get(material, 0)) + float(quote.materials[material]) * quantity
            )
    return {
        "gross": gross,
        "net": net,
        "count": count,
        "altered": altered,
        "materials": materials,
        "wallet_difference": float(payload.wallet) - net
    }


static func quantity_study(payload: Dictionary) -> Array:
    var result := []
    for amount in [0, 1, 2, 3, 5, 8, 10, 20, 50, 100]:
        var cost := total(payload, String(payload.focus), float(amount))
        result.append(
            {
                "假设份数": amount,
                "假设总额": cost.net,
                "假设每份成本": cost.unit,
                "相对无折扣无附加费": cost.savings,
                "取整影响": cost.rounding
            }
        )
    return result


static func break_even(payload: Dictionary) -> Dictionary:
    var quote: Dictionary = index(payload).get(payload.focus, {})
    if quote.is_empty():
        return {"defined": false, "reason": "先选择一个已公开方案。", "units": 0}
    var price := float(payload.prices.get(payload.focus, quote.price))
    var saving := price * float(payload.discount) / 100
    if saving <= 0:
        return {"defined": false, "reason": "没有正的单份假设折扣，固定附加费无法靠折扣抵消。", "units": 0}
    var amount := int(ceil(float(payload.fee) / saving))
    return {"defined": true, "reason": "抵消固定附加费的理论份数，不表示配方可重复制作。", "units": amount}


static func discount_study(payload: Dictionary) -> Array:
    var result := []
    for discount in [0, 5, 10, 20, 30, 50]:
        var sample := payload.duplicate(true)
        sample.discount = float(discount)
        var current := basket(sample)
        result.append(
            {
                "假设折扣百分比": discount,
                "假设总额": current.net,
                "假设省下": float(current.gross) - float(current.net),
                "与记录资金差": current.wallet_difference
            }
        )
    return result


static func material_rows(payload: Dictionary) -> Array:
    var result := []
    for id in basket(payload).materials:
        result.append({"材料标识": id, "按假设份数展开": basket(payload).materials[id]})
    return result


static func history(records: Array, focus: String) -> Array:
    var result := []
    for record in records.slice(0, 60):
        var payload: Dictionary = record.get("payload", {})
        if not validate(payload):
            continue
        for quote in payload.quotes:
            if quote.id != focus:
                continue
            var price := float(payload.prices.get(quote.id, quote.price))
            result.append(
                {
                    "time": int(payload.recorded),
                    "record": int(record.get("id", 0)),
                    "name": String(record.get("title", "记录")),
                    "catalog": int(quote.price),
                    "assumed": price,
                    "altered": not is_equal_approx(price, float(quote.price))
                }
            )
    result.sort_custom(
        func(a: Dictionary, b: Dictionary):
            if int(a.time) == int(b.time):
                return int(a.record) < int(b.record)
            return int(a.time) < int(b.time)
    )
    return result


static func quantile(values: Array, portion: float) -> float:
    if values.is_empty():
        return 0.0
    var ordered := values.duplicate()
    ordered.sort()
    var offset := clampf(portion, 0, 1) * (ordered.size() - 1)
    var low := int(floor(offset))
    var high := int(ceil(offset))
    return lerpf(float(ordered[low]), float(ordered[high]), offset - low)


static func history_rows(samples: Array) -> Array:
    var result := []
    for row in samples:
        result.append(
            {
                "记录": row.name,
                "时间": V.date(int(row.time)),
                "记录目录成本": row.catalog,
                "个人假设成本": row.assumed,
                "是否改为假设": row.altered
            }
        )
    return result


static func history_statistics(samples: Array) -> Array:
    var catalog := []
    var assumed := []
    for row in samples:
        catalog.append(float(row.catalog))
        assumed.append(float(row.assumed))
    var result := []
    for group in [{"name": "记录目录成本", "values": catalog}, {"name": "个人假设单价", "values": assumed}]:
        var stats := K.distribution(group.values)
        result.append(
            {
                "序列": group.name,
                "样本数": stats.count,
                "最小": stats.min,
                "中位": stats.median,
                "最大": stats.max,
                "平均": stats.mean,
                "标准差": stats.deviation,
                "四分位距": quantile(group.values, 0.75) - quantile(group.values, 0.25)
            }
        )
    return result


static func outliers(samples: Array) -> Array:
    if samples.size() < 4:
        return []
    var values := []
    for row in samples:
        values.append(float(row.catalog))
    var low := quantile(values, 0.25)
    var high := quantile(values, 0.75)
    var spread := high - low
    var result := []
    for row in samples:
        var amount := float(row.catalog)
        if amount < low - spread * 1.5 or amount > high + spread * 1.5:
            result.append(
                {
                    "记录": row.name,
                    "记录目录成本": amount,
                    "下边界": low - spread * 1.5,
                    "上边界": high + spread * 1.5
                }
            )
    return result


static func changes(samples: Array) -> Array:
    var result := []
    for i in range(1, samples.size()):
        var before: Dictionary = samples[i - 1]
        var after: Dictionary = samples[i]
        if before.catalog == after.catalog:
            continue
        var difference := float(after.catalog) - float(before.catalog)
        result.append(
            {
                "前记录": before.name,
                "后记录": after.name,
                "目录成本变化": difference,
                "相对变化": difference / float(before.catalog) if float(before.catalog) > 0 else "原值为零",
                "间隔秒": int(after.time) - int(before.time)
            }
        )
    return result


static func price_indices(a: Dictionary, b: Dictionary) -> Dictionary:
    var left := index(a)
    var right := index(b)
    var old_old := 0.0
    var new_old := 0.0
    var old_new := 0.0
    var new_new := 0.0
    var common := 0
    for id in left:
        if not right.has(id):
            continue
        common += 1
        var p0 := float(left[id].price)
        var p1 := float(right[id].price)
        var q0 := float(a.quantities.get(id, 0))
        var q1 := float(b.quantities.get(id, 0))
        old_old += p0 * q0
        new_old += p1 * q0
        old_new += p0 * q1
        new_new += p1 * q1
    var laspeyres := new_old / old_old if old_old > 0 else 0.0
    var paasche := new_new / old_new if old_new > 0 else 0.0
    return {
        "common": common,
        "laspeyres": laspeyres,
        "paasche": paasche,
        "fisher": sqrt(laspeyres * paasche) if laspeyres > 0 and paasche > 0 else 0.0,
        "old_defined": old_old > 0,
        "new_defined": old_new > 0
    }


static func analyze(payload: Dictionary, _snapshot: Dictionary) -> Array:
    var current := basket(payload)
    var threshold := break_even(payload)
    var chart := []
    for row in quantity_study(payload):
        chart.append(
            {
                "x": row["假设份数"],
                "y": row["假设每份成本"],
                "name": "份数" + str(row["假设份数"]),
                "feasible": true,
                "selected": row["假设份数"] == 1,
                "reason": "纯数学假设，不改变生产配方"
            }
        )
    return [
        K.notice("目录成本记录", summary(payload)),
        K.table(
            "成本与个人假设", ["方案", "目录成本", "个人假设单价", "假设份数", "假设总额", "假设每份成本", "来源"], quote_rows(payload)
        ),
        {
            "kind": "custom",
            "title": "固定附加费的摊分假设",
            "view": VIEW,
            "data":
            {
                "points": chart,
                "x_label": "个人假设份数",
                "y_label": "假设每份成本",
                "legend": "所有点均为个人假设；不表示允许重复制作",
                "budget": -1
            }
        },
        K.notice(
            "个人清单合计",
            (
                "假设份数%.0f · 假设总额%.2f · 记录资金差%.2f · 修改单价%d项。"
                % [current.count, current.net, current.wallet_difference, current.altered]
            )
        ),
        K.table("假设份数比较", ["假设份数", "假设总额", "假设每份成本", "相对无折扣无附加费", "取整影响"], quantity_study(payload)),
        K.notice(
            "假设折扣与附加费平衡",
            String(threshold.reason) + (" 理论份数%d。" % threshold.units if threshold.defined else "")
        ),
        K.table("假设折扣敏感性", ["假设折扣百分比", "假设总额", "假设省下", "与记录资金差"], discount_study(payload)),
        K.table("假设材料展开", ["材料标识", "按假设份数展开"], material_rows(payload)),
        K.notice("记录来源", "基础成本来自已获动作或已持图样公开的配方。所有个人折扣、附加费和份数假设均与生产报价分开，不执行购买。")
    ]


static func history_sections(records: Array, focus: String) -> Array:
    var samples := history(records, focus)
    return [
        {
            "kind": "custom",
            "title": "同一方案的已存成本观察",
            "view": HISTORY_VIEW,
            "data": {"samples": samples}
        },
        K.table("此方案的已存记录", ["记录", "时间", "记录目录成本", "个人假设成本", "是否改为假设"], history_rows(samples)),
        K.table(
            "此方案的记录统计",
            ["序列", "样本数", "最小", "中位", "最大", "平均", "标准差", "四分位距"],
            history_statistics(samples)
        ),
        K.table("目录成本变化", ["前记录", "后记录", "目录成本变化", "相对变化", "间隔秒"], changes(samples)),
        K.table(
            "四分位异常值提示",
            ["记录", "记录目录成本", "下边界", "上边界"],
            outliers(samples),
            "异常只表示相对此记录样本偏离，不判断游戏价格错误。"
        )
    ]


static func compare(a: Dictionary, b: Dictionary) -> Array:
    var result := []
    var left := index(a)
    var right := index(b)
    for id in left:
        if right.has(id):
            result.append(
                {
                    "方案": left[id].name,
                    "旧目录成本": left[id].price,
                    "新目录成本": right[id].price,
                    "变化": int(right[id].price) - int(left[id].price)
                }
            )
    var indices := price_indices(a, b)
    return [
        K.table("共同方案目录成本变化", ["方案", "旧目录成本", "新目录成本", "变化"], result),
        K.notice(
            "个人篮子成本指数",
            (
                "共同方案%d；旧份数指数%s，新份数指数%s，几何综合指数%s。基数为零时未定义。"
                % [
                    indices.common,
                    str(indices.laspeyres) if indices.old_defined else "未定义",
                    str(indices.paasche) if indices.new_defined else "未定义",
                    str(indices.fisher) if indices.old_defined and indices.new_defined else "未定义"
                ]
            )
        )
    ]
