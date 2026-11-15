extends RefCounted
## Tool resupply quotes, craft batches and the transaction that applies them.
## Moved out of build_system.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func normalize_resupply_plan(system: RefCounted, plan: Variant) -> Dictionary:
    if not plan is Dictionary:return system._fail("补给清单无效")
    for key in plan:
        if key not in ["order", "limits"]:return system._fail("未知补给选项")
    var limits: Variant = plan.get("limits", {})
    var order: Variant = plan.get("order", [])
    if not limits is Dictionary or not order is Array:return system._fail("补给清单无效")
    var normalized := {"order": [], "limits": {}}
    for id in order:
        if not id is String or not system.catalog.tools.has(id) or not system.state.unlocked_tools.has(id) or normalized.order.has(id):
            return system._fail("补给顺序包含未知、重复或未取得战具")
        normalized.order.append(id)
    for id in limits:
        if not id is String or not system.catalog.tools.has(id) or not system.state.unlocked_tools.has(id) or not system._counter(limits[id], 100):
            return system._fail("补给数量无效")
        normalized.limits[id] = int(limits[id])
    for id in system.catalog.tools:
        if system.state.unlocked_tools.has(id) and not normalized.order.has(id):normalized.order.append(id)
    normalized["explicit_limits"] = plan.has("limits")
    return system._ok({"plan": normalized})


static func quote_resupply(system: RefCounted, wallet: Dictionary, plan: Variant) -> Dictionary:
    if not wallet.get("inventory_counts") is Dictionary or not system._counter(wallet.get("currency")):
        return system._resupply_result(false, "无效钱包", wallet, {}, {"currency": 0, "materials": {}})
    var normalized: Dictionary = system._normalize_resupply_plan(plan)
    if not normalized.ok:return system._resupply_result(false, normalized.reason, wallet, {}, {"currency":0,"materials":{}})
    var request: Dictionary = normalized.plan
    var next_wallet: Dictionary = wallet.duplicate(true)
    var charges := {}
    var total_cost := {"currency": 0, "materials": {}}
    var deficits := {}
    for id in system.catalog.tools:
        var remaining := maxi(0, system.tool_capacity(String(id)) - int(system.state.tool_counts.get(id, 0)))
        deficits[id] = mini(remaining, int(request.limits.get(id, 0))) if request.explicit_limits else remaining
    var unaffordable_reason := "材料或碎钱不足"
    for id_value in request.order:
        var id := String(id_value)
        if not system.state.unlocked_tools.has(id) or int(deficits[id]) <= 0: continue
        var unit: Dictionary = system.catalog.tools[id].get("resupply", {})
        var unit_currency := int(unit.get("currency", -1))
        var unit_materials: Dictionary = unit.get("materials", {})
        if unit_currency <= 0 or unit_materials.is_empty():
            unaffordable_reason = "战具补给方案无效"
            continue
        var bought := 0
        while bought < int(deficits[id]):
            if int(next_wallet.currency) < unit_currency:
                unaffordable_reason = "碎钱不足：每份需要%d" % unit_currency
                break
            var can_pay := true
            for material in unit_materials:
                var amount: Variant = unit_materials[material]
                if not system._counter(amount) or int(amount) <= 0 or not system._counter(next_wallet.inventory_counts.get(material, 0)) or int(next_wallet.inventory_counts.get(material, 0)) < int(amount):
                    can_pay = false
                    unaffordable_reason = "材料不足：%s" % String(material)
                    break
            if not can_pay: break
            next_wallet.currency = int(next_wallet.currency) - unit_currency
            total_cost.currency = int(total_cost.currency) + unit_currency
            for material in unit_materials:
                var amount := int(unit_materials[material])
                next_wallet.inventory_counts[material] = int(next_wallet.inventory_counts.get(material, 0)) - amount
                total_cost.materials[material] = int(total_cost.materials.get(material, 0)) + amount
            bought += 1
        if bought > 0: charges[id] = bought
    var quote: Dictionary
    if charges.is_empty():
        var any_deficit := false
        for amount in deficits.values():
            if int(amount) > 0: any_deficit = true
        var reason := "未选择需要补给的数量" if not any_deficit and request.explicit_limits else ("携带量已满" if not any_deficit else unaffordable_reason)
        quote = system._resupply_result(false, reason, wallet, {}, {"currency": 0, "materials": {}})
    else:
        quote = system._resupply_result(true, "", wallet, charges, total_cost, next_wallet)
    quote["requested"] = deficits.duplicate(true)
    quote["unfilled"] = {}
    for id in deficits:quote.unfilled[id] = maxi(0, int(deficits[id]) - int(charges.get(id, 0)))
    quote["order"] = request.order.duplicate()
    var budget_request := {}
    for id in request.order:
        if system.state.unlocked_tools.has(id):budget_request[id] = deficits[id]
    quote["budget"] = preload("res://scripts/resupply_budget.gd").quote(system.catalog.tools, budget_request, wallet)
    return quote


static func resupply_tools(system: RefCounted, wallet: Dictionary, at_bell: bool, plan: Variant) -> Dictionary:
    if not at_bell:
        return system._resupply_result(false, "请在钟龛补给战具", wallet, {}, {"currency": 0, "materials": {}})
    var quote: Dictionary = system.quote_resupply(wallet, plan)
    if not bool(quote.get("ok", false)): return quote
    # The quote's detached wallet is committed only after every charge and
    # material has been validated; no stock changes on an affordability error.
    for id in quote.charges:
        system.state.tool_counts[id] = int(system.state.tool_counts.get(id, 0)) + int(quote.charges[id])
    quote.wallet = quote.remaining_wallet.duplicate(true)
    return quote


static func resupply_result(system: RefCounted, ok: bool, reason: String, wallet: Dictionary, charges: Dictionary, cost: Dictionary, remaining_wallet: Variant) -> Dictionary:
    var remaining: Dictionary = wallet if not remaining_wallet is Dictionary else remaining_wallet
    var deficits := {}
    var after := {}
    for id in system.catalog.tools:
        var current := int(system.state.tool_counts.get(id, 0))
        var bought := int(charges.get(id, 0))
        deficits[id] = maxi(0, system.tool_capacity(String(id)) - current)
        after[id] = current + bought
    return {"ok": ok, "reason": reason, "wallet": wallet.duplicate(true),
        "remaining_wallet": remaining.duplicate(true), "charges": charges.duplicate(true),
        "deficits": deficits, "remaining": after, "cost": cost.duplicate(true)}


static func quote_craft_batch(system: RefCounted, request: Variant, wallet: Dictionary) -> Dictionary:
    if not request is Array or request.is_empty() or request.size()>8:return system._fail("制作清单需要1至8个不同方案")
    var ids: Array[String]=[]
    var branches: Array[String]=[]
    var materials: Dictionary={}
    var cost := 0
    var rows: Array=[]
    for value in request:
        if not value is String or value in ids or not system.catalog.recipes.has(value):return system._fail("清单含未知或重复制作方案")
        ids.append(value)
        var recipe: Dictionary=system.catalog.recipes[value]
        for prerequisite in recipe.get("requires_crafted", []):
            if not system.state.crafted.has(prerequisite):return system._fail("先单独完成前阶改制，再报价二阶清单")
        if String(recipe.kind)=="skill_branch":
            if String(recipe.target) in branches:return system._fail("同一技能只能选择一个校习方向")
            branches.append(String(recipe.target))
        cost+=int(recipe.currency)
        for material in recipe.materials:materials[material]=int(materials.get(material,0))+int(recipe.materials[material])
        rows.append({"id":value,"name":String(recipe.name),"currency":int(recipe.currency)})
    var clone=system.get_script().new()
    if not clone.restore(system.serialize()).ok:return system._fail("当前构筑无法用于制作报价")
    clone.catalog=system.catalog.duplicate(true)
    var next_wallet:=wallet.duplicate(true)
    for id in ids:
        var result: Dictionary=clone.transact(id,next_wallet)
        if not result.ok:return {"ok":false,"reason":"%s：%s" % [String(system.catalog.recipes[id].name),String(result.reason)],"currency_spent":cost,"materials":materials,"rows":rows}
        next_wallet=result.wallet
    return system._ok({"wallet":next_wallet,"build":clone.serialize(),"currency_spent":cost,"materials":materials,"rows":rows})


static func transact(system: RefCounted, recipe_id: String, wallet: Dictionary) -> Dictionary:
    # Validate every precondition before spending; failure never mutates either owner.
    if not system.catalog.recipes.has(recipe_id):
        return system._fail("未知制作方案")
    if not wallet.get("inventory_counts") is Dictionary or not system._counter(wallet.get("currency")):
        return system._fail("无效钱包")
    var recipe: Dictionary = system.catalog.recipes[recipe_id]
    for prerequisite in recipe.get("requires_crafted", []):
        if not system.state.crafted.has(prerequisite):return system._fail("先完成前阶改制：%s" % String(prerequisite))
    var target := String(recipe.target)
    var kind := String(recipe.kind)
    if kind == "skill_branch":
        if not system.state.unlocked_skills.has(target):
            return system._fail("先取得技能再校习")
        if int(system.state.skill_levels.get(target, 0)) == int(recipe.branch):
            return system._fail("已是这个校习方向")
    if kind == "passive" and system.state.unlocked_passives.has(target):
        return system._fail("此装备已经获得")
    if kind == "refill" and int(system.state.tool_counts[target]) >= int(system.catalog.tools[target].capacity):
        return system._fail("携带量已满")
    if kind in ["tool_capacity", "slot_part", "passive"]:
        if not system.state.get("crafted") is Array: system.state.crafted = []
        if system.state.crafted.has(recipe_id):
            return system._fail("已经制作过「%s」" % String(recipe.get("name", recipe_id)))
        if kind == "tool_capacity" and not system.state.unlocked_tools.has(target):
            return system._fail("先取得这件战具，工匠才能改制")
        # Patterns (challenge evidence) are shown to the artisan, never consumed.
        for item in recipe.get("requires_items", []):
            if not system._counter(wallet.inventory_counts.get(item, 0)) or int(wallet.inventory_counts.get(item, 0)) <= 0:
                return system._fail("缺少图样：%s" % String(item))
    var cost := int(recipe.currency)
    if int(wallet.currency) < cost:
        return system._fail("松脂碎片不足：需要%d" % cost)
    for material in recipe.materials:
        if not system._counter(wallet.inventory_counts.get(material, 0)) or int(wallet.inventory_counts.get(material, 0)) < int(recipe.materials[material]):
            return system._fail("材料不足：%s" % material)
    var next_wallet := wallet.duplicate(true)
    next_wallet.currency = int(next_wallet.currency) - cost
    for material in recipe.materials:
        next_wallet.inventory_counts[material] = int(next_wallet.inventory_counts[material]) - int(recipe.materials[material])
    if kind == "refill":
        system.state.tool_counts[target] = mini(int(system.catalog.tools[target].capacity), int(system.state.tool_counts[target]) + int(recipe.amount))
    elif kind == "passive":
        system._unlock("unlocked_passives", target)
    elif kind == "skill_branch":
        # Choosing the other direction later replaces this one at full price.
        system.state.skill_levels[target] = int(recipe.branch)
    elif kind == "tool_capacity":
        # A larger pouch holds more; it is filled at the shrine like any other charge.
        system.state.crafted.append(recipe_id)
    elif kind == "slot_part":
        system.state.crafted.append(recipe_id)
        system._settle_unlocked_slots()
    return system._ok({"wallet": next_wallet, "currency_spent": cost, "recipe_id": recipe_id})


static func settle_unlocked_slots(system: RefCounted) -> void:
    system._settle_families(system.state.equipped_families, String(system.state.crest))
    system._sync_aliases()
    for name in system.state.loadouts:
        var saved: Dictionary = system.state.loadouts[name]
        system._settle_families(saved.equipped_families, String(saved.crest))
        saved.passives = system._active_accessories(saved.equipped_families, String(saved.crest))


static func settle_families(system: RefCounted, families: Dictionary, crest: String) -> void:
    while not system._validate_passives(system._active_accessories(families, crest), crest).is_empty():
        var removed := false
        for family in ["travel_accessory", "combat_accessory"]:
            for slot in range(families[family].size() - 1, -1, -1):
                if system._slot_unlocked(family, slot, crest) and not String(families[family][slot]).is_empty():
                    families[family][slot] = ""
                    removed = true
                    break
            if removed: break
        if not removed: break
