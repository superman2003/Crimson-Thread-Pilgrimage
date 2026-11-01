extends RefCounted
## A shopping list, never a transaction. Aggregate all requested materials even
## when the first recipe is blocked; the live World quote remains authoritative.
static func report(build: RefCounted, request: Variant, wallet: Dictionary) -> Dictionary:
    var result:={"valid":false,"rows":[],"materials":[],"patterns":[],"currency":{},"ready":false,"effects":{},"reason":"请选择1至8个不同制作方案。"}
    if build==null or not request is Array or request.is_empty() or request.size()>8:return result
    if not wallet.get("inventory_counts") is Dictionary or not build._counter(wallet.get("currency")):
        result.reason="钱包记录无效，暂不能规划制作。"
        return result
    var seen:={}
    var material_costs:={}
    var proofs:={}
    var currency:=0
    for id in request:
        if not id is String or seen.has(id) or not build.catalog.recipes.has(id):
            result.reason="清单含重复或未知制作方案。"
            return result
        seen[id]=true
        var recipe: Dictionary=build.catalog.recipes[id]
        currency+=int(recipe.currency)
        for material in recipe.materials:
            var amount:=int(recipe.materials[material])
            material_costs[material]=int(material_costs.get(material,0))+amount
        for proof in recipe.get("requires_items",[]):proofs[String(proof)]=true
        var individual: Dictionary=build.quote_craft_batch([id],wallet)
        result.rows.append({"id":id,"name":String(recipe.name),"description":String(recipe.get("description","")),
            "currency":int(recipe.currency),"materials":recipe.materials.duplicate(true),"patterns":Array(recipe.get("requires_items",[])).duplicate(),
            "prerequisites":Array(recipe.get("requires_crafted",[])).duplicate(),"source":String(recipe.get("source","")),
            "ready":bool(individual.get("ok",false)),"reason":String(individual.get("reason",""))})
    result.currency=balance(currency,int(wallet.currency))
    var ids:=material_costs.keys()
    ids.sort()
    for id in ids:
        var owned: Variant=wallet.inventory_counts.get(id,0)
        if not build._counter(owned):result.reason="材料记录无效，暂不能规划制作。";return result
        var row:=balance(int(material_costs[id]),int(owned))
        row.id=String(id)
        result.materials.append(row)
    ids=proofs.keys()
    ids.sort()
    for id in ids:
        var owned: Variant=wallet.inventory_counts.get(id,0)
        if not build._counter(owned):result.reason="图样记录无效，暂不能规划制作。";return result
        result.patterns.append({"id":String(id),"owned":int(owned),"missing":int(owned)<=0})
    var quoted: Dictionary=build.quote_craft_batch(request,wallet)
    result.effects=preload("res://scripts/craft_result_projection.gd").compare(build,quoted)
    result.valid=true
    result.ready=bool(quoted.get("ok",false))
    result.reason=String(quoted.get("reason",""))
    return result

static func balance(required: int, owned: int) -> Dictionary:
    return {"required":required,"owned":owned,"missing":maxi(0,required-owned),"remaining":maxi(0,owned-required)}

static func text(plan: Dictionary, name_for: Callable, description_for: Callable) -> String:
    if not plan.valid:return String(plan.reason)
    var money: Dictionary=plan.currency
    var lines: Array[String]=["碎钱合计：需要%d / 持有%d / 缺%d" % [money.required,money.owned,money.missing],"\n整单材料（不含图样）"]
    for material in plan.materials:
        lines.append("%s：需要%d / 持有%d / 缺%d" % [str(name_for.call(material.id)),material.required,material.owned,material.missing])
        var source:=str(description_for.call(material.id)).strip_edges()
        if not source.is_empty():lines.append("  材料说明："+source)
    if plan.materials.is_empty():lines.append("此清单不消耗材料。")
    if not plan.patterns.is_empty():
        lines.append("\n图样（只出示，不消耗；多件共用同一份）")
        for proof in plan.patterns:lines.append("%s：%s" % [str(name_for.call(proof.id)),"尚缺" if proof.missing else "已携带"])
    lines.append("\n逐件核对")
    for row in plan.rows:
        lines.append("%s · %d碎钱" % [row.name,row.currency])
        if not row.description.is_empty():lines.append(row.description)
        if not row.source.is_empty():lines.append("工艺来源："+row.source)
        for prior in row.prerequisites:lines.append("前阶改制："+str(name_for.call(prior)))
        lines.append("单件条件已满足。" if row.ready else "暂不可做："+String(row.reason))
    lines.append("\n构筑与材料条件已满足。" if plan.ready else "构筑与材料暂不满足："+String(plan.reason))
    lines.append("\n"+preload("res://scripts/craft_result_projection.gd").text(plan.effects))
    lines.append("生命、绯线与已有战具次数不补满；材料齐全也须满足工匠、校习与前阶条件，并另行确认整单。")
    return "\n".join(lines)
