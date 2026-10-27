extends RefCounted
## Full-list affordability is descriptive only; payment still uses quote_resupply.
static func counter(value: Variant, maximum: int = 1000000) -> bool:
    return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) >= 0.0 and float(value) <= maximum and float(value) == floor(float(value))

static func quote(tools: Dictionary, requested: Dictionary, wallet: Dictionary) -> Dictionary:
    if not counter(wallet.get("currency")) or not wallet.get("inventory_counts") is Dictionary:return {}
    var cost := {"currency":0, "materials":{}}
    var units := 0
    for id in requested:
        var count: Variant = requested[id]
        if not counter(count, 100):return {}
        if int(count) == 0:continue
        if not tools.get(id) is Dictionary:return {}
        var recipe: Variant = tools[id].get("resupply")
        if not recipe is Dictionary or not counter(recipe.get("currency")) or int(recipe.currency) <= 0:return {}
        if not recipe.get("materials") is Dictionary or recipe.materials.is_empty():return {}
        units += int(count)
        cost.currency += int(count) * int(recipe.currency)
        for material in recipe.materials:
            var amount: Variant = recipe.materials[material]
            if not material is String or not counter(amount) or int(amount) <= 0:return {}
            cost.materials[material] = int(cost.materials.get(material, 0)) + int(amount) * int(count)
    var missing := {"currency":maxi(0, int(cost.currency) - int(wallet.currency)), "materials":{}}
    var available := {}
    for material in cost.materials:
        var amount: Variant = wallet.inventory_counts.get(material, 0)
        if not counter(amount):return {}
        available[material] = int(amount)
        var gap := maxi(0, int(cost.materials[material]) - int(amount))
        if gap > 0:missing.materials[material] = gap
    return {"valid":true, "units":units, "cost":cost, "missing":missing, "available_materials":available,
        "currency":int(wallet.currency), "affordable":missing.currency == 0 and missing.materials.is_empty()}

static func lines(budget: Dictionary, names: Callable) -> Array[String]:
    var result: Array[String] = []
    if not budget.get("valid", false) or int(budget.get("units", 0)) == 0:return result
    result.append("")
    result.append("按当前库存买齐申请：碎钱总需%d / 持有%d / 还差%d" % [int(budget.cost.currency), int(budget.currency), int(budget.missing.currency)])
    var ids: Array = budget.cost.materials.keys()
    ids.sort()
    for id in ids:
        var name := String(names.call(String(id))) if names.is_valid() else String(id)
        result.append("%s：总需%d / 持有%d / 还差%d" % [name, int(budget.cost.materials[id]), int(budget.available_materials[id]), int(budget.missing.materials.get(id, 0))])
    result.append("可买齐本次申请。" if budget.affordable else "缺口按整份申请合计；当前仍可按优先顺序部分补给。")
    return result

