extends RefCounted
## A read-only reverse index of held materials and already unlocked uses.
## This does not reserve resources or replace a live shop/crafting quote.
static func counter(value: Variant) -> bool:
    return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)>=0.0 and float(value)<=2147483647.0 and floor(float(value))==float(value)

static func owned(value: Variant) -> bool:return counter(value) and float(value)>0.0

static func measure(value: Variant) -> bool:
    return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)>=0.0 and float(value)<=2147483647.0

static func flag(flags: Dictionary, key: String) -> bool:
    var value: Variant=flags.get(key,false)
    return value is bool and value

static func known_recipe(recipe: Dictionary, state: Dictionary, flags: Dictionary, inventory: Dictionary={}) -> bool:
    var gate:=String(recipe.get("requires_flag",""))
    if not gate.is_empty() and not flag(flags,gate):return false
    for proof in recipe.get("requires_items",[]):
        if not owned(inventory.get(proof,0)):return false
    var kind:=String(recipe.get("kind",""))
    var target:=String(recipe.get("target",""))
    match kind:
        "skill_branch":return state.get("unlocked_skills",[]).has(target) and flag(flags,"skill_practiced_"+target)
        "tool_capacity","refill":return state.get("unlocked_tools",[]).has(target)
        "passive":return state.get("unlocked_passives",[]).has(target) or not gate.is_empty()
        "slot_part":return state.get("crafted",[]).has(String(recipe.get("id",""))) or not gate.is_empty()
    return false

static func cost_row(id: String, name: String, kind: String, price: Variant, ingredients: Variant, wallet: Dictionary) -> Dictionary:
    if not counter(price) or not ingredients is Dictionary:return {}
    var materials: Dictionary={}
    var ready:=int(wallet.currency)>=int(price)
    for material in ingredients:
        if not material is String or not counter(ingredients[material]) or int(ingredients[material])<=0:return {}
        var held: Variant=wallet.inventory_counts.get(material,0)
        if not counter(held):return {}
        materials[material]={"required":int(ingredients[material]),"owned":int(held)}
        ready=ready and int(held)>=int(ingredients[material])
    return {"id":id,"name":name,"kind":kind,"currency":int(price),"materials":materials,"ready":ready}

static func collect(build: RefCounted, wallet: Dictionary, flags: Dictionary, items: Dictionary, energy: Variant, maximum: Variant, heal: Dictionary) -> Dictionary:
    var result:={"ok":false,"rows":[],"uses":[],"reason":"资源记录暂不可读取。"}
    if build==null or not counter(wallet.get("currency")) or not wallet.get("inventory_counts") is Dictionary:return result
    if not measure(energy) or not measure(maximum) or float(energy)>float(maximum):return result
    result.rows.append({"id":"currency","name":"松脂碎钱","count":int(wallet.currency),"purpose":"交易、设施与制作费用。钟龛休息不免费补充战具。"})
    result.rows.append({"id":"thread","name":"绯线","count":int(energy),"maximum":int(maximum),"purpose":"战斗、线术与疗伤共用；这里不把绯线当作交易货币。"})
    var counts: Dictionary=wallet.inventory_counts
    for id in counts:
        if not id is String or not owned(counts[id]) or not items.get(id) is Dictionary:continue
        var item: Dictionary=items[id]
        if item.get("category")!="Materials":continue
        result.rows.append({"id":id,"name":String(item.get("name",id)),"count":int(counts[id]),"purpose":String(item.get("description",""))})
    var material_rows: Array=result.rows.slice(2)
    material_rows.sort_custom(func(a: Dictionary,b: Dictionary):return String(a.name)<String(b.name) if a.name!=b.name else String(a.id)<String(b.id))
    result.rows=result.rows.slice(0,2)+material_rows
    for id in build.state.get("unlocked_tools",[]):
        if not build.catalog.get("tools",{}).get(id) is Dictionary:continue
        var tool: Dictionary=build.catalog.tools[id]
        var supply: Dictionary=tool.get("resupply",{})
        var row:=cost_row("tool_"+String(id),String(tool.get("name",id)),"每次补给",supply.get("currency"),supply.get("materials"),wallet)
        if row.is_empty():continue
        row["stock"]=int(build.state.tool_counts.get(id,0))
        row["source"]=String(tool.get("source",""))
        row["capacity"]=build.tool_capacity(id)
        row["ready"]=row.ready and row.stock<row.capacity
        row["complete"]=row.stock>=row.capacity
        result.uses.append(row)
    for id in build.catalog.get("recipes",{}):
        var recipe: Dictionary=build.catalog.recipes[id].duplicate(true)
        recipe["id"]=String(id)
        if not known_recipe(recipe,build.state,flags,counts):continue
        var row:=cost_row("recipe_"+String(id),String(recipe.get("name",id)),"制作或校习",recipe.get("currency"),recipe.get("materials"),wallet)
        if row.is_empty():continue
        var complete: bool=build.state.get("crafted",[]).has(id) or (recipe.get("kind")=="passive" and build.state.get("unlocked_passives",[]).has(recipe.get("target")))
        if recipe.get("kind")=="skill_branch":complete=int(build.state.skill_levels.get(recipe.target,0))==int(recipe.get("branch",0))
        row["complete"]=complete
        row["source"]=String(recipe.get("source",""))
        row["ready"]=row.ready and not complete
        row["conditions"]=[]
        for proof in recipe.get("requires_items",[]):
            if not owned(counts.get(proof,0)):row.conditions.append("仍需携带图样")
        for prior in recipe.get("requires_crafted",[]):
            if not build.state.get("crafted",[]).has(prior):row.conditions.append("仍需前阶改制")
        if not row.conditions.is_empty():row.ready=false
        result.uses.append(row)
    for skill in build.get_snapshot().get("skills",[]):
        if not bool(skill.get("unlocked",false)) or not counter(skill.get("energy_cost")):continue
        result.uses.append({"id":"skill_"+String(skill.id),"name":String(skill.get("name",skill.id)),"kind":"施放线术","thread":int(skill.energy_cost),"ready":int(energy)>=int(skill.energy_cost)})
    if counter(heal.get("cost")) and counter(heal.get("amount")):
        result.uses.append({"id":"heal","name":"当前契印疗伤","kind":"完成一次疗伤","thread":int(heal.cost),"amount":int(heal.amount),"ready":int(energy)>=int(heal.cost)})
    result.ok=true
    result.reason="只核对已解锁用途，不执行交易；实际使用还须满足地点、动作和当前报价。"
    return result

static func uses_for(report: Dictionary, resource: String, ready_only: bool=false) -> Array:
    var result: Array=[]
    for use in report.get("uses",[]):
        var relevant: bool=use.has("thread") if resource=="thread" else (int(use.get("currency",0))>0 if resource=="currency" else use.get("materials",{}).has(resource))
        if relevant and (not ready_only or bool(use.get("ready",false))):result.append(use.duplicate(true))
    return result

static func observed_sources(config: Dictionary, collected: Dictionary, visited: Dictionary, inventory: Dictionary) -> Dictionary:
    # Only inspect the current already-loaded region. A ledger must not parse
    # other regions or turn an unvisited hidden reward into a source hint.
    var result: Dictionary={}
    if not config.get("name") is String or not config.get("collectibles") is Array or not config.get("map_rooms") is Array:return result
    var rooms: Dictionary={}
    for room in config.map_rooms:
        if not room is Dictionary or not room.get("id") is String or not room.get("name") is String:continue
        if flag(visited,String(room.id)):rooms[room.id]=String(room.name)
    var seen: Dictionary={}
    for source in config.collectibles:
        if not source is Dictionary or source.get("kind")!="item" or not source.get("id") is String:continue
        if seen.has(source.id) or not flag(collected,String(source.id)):continue
        seen[source.id]=true
        var item: Variant=source.get("item_id")
        var room: Variant=source.get("room_id")
        if not item is String or not owned(inventory.get(item,0)) or not room is String or not rooms.has(room):continue
        if not source.get("label") is String or String(source.label).is_empty():continue
        if not counter(source.get("amount",1)) or int(source.get("amount",1))<=0:continue
        if not result.has(item):result[item]=[]
        # Do not return positions, internal IDs or the source's private note.
        result[item].append({"title":String(source.label),"place":String(config.name)+" · "+String(rooms[room])})
    return result

static func describe(report: Dictionary, resource: Dictionary, ready_only: bool, name_for: Callable) -> String:
    var text: Array[String]=[String(resource.name),"当前持有：%d%s" % [resource.count," / %d" % resource.maximum if resource.has("maximum") else ""],String(resource.purpose),"\n已解锁用途"]
    var sources: Array=report.get("observed_sources",{}).get(String(resource.id),[])
    if not sources.is_empty():
        text.insert(3,"\n当前地区已收取位置\n"+"\n".join(sources.map(func(source: Dictionary):return String(source.title)+" · "+String(source.place)))+"\n这些位置已经收取，不是再次领取的承诺；持有量还会受战利品与消费影响。")
    var uses:=uses_for(report,String(resource.id),ready_only)
    for use in uses:
        text.append("\n"+String(use.name)+" · "+String(use.kind))
        if not String(use.get("source","")).is_empty():text.append("工艺与来处："+String(use.source))
        if use.has("thread"):
            text.append("绯线费用：%d%s" % [use.thread," · 恢复%d生命" % use.amount if use.has("amount") else ""])
        else:
            text.append("碎钱：需要%d / 持有%d" % [use.currency,report.rows[0].count])
            for id in use.materials:
                var amount: Dictionary=use.materials[id]
                text.append("%s：需要%d / 持有%d" % [str(name_for.call(id)),amount.required,amount.owned])
        if use.has("stock"):text.append("当前携带：%d / %d；费用为补充一次的单价。" % [use.stock,use.capacity])
        if use.get("complete",false):text.append("已完成或携带已满；不会重复制作或免费补给。")
        elif use.ready:text.append("所示费用已备齐；仍需到对应地点并满足动作条件。")
        else:text.append("所示费用或前置条件尚未备齐。")
        for condition in use.get("conditions",[]):text.append(String(condition))
    if uses.is_empty():text.append("当前筛选没有已知用途；不代表这件材料在后续旅途中没有用。")
    text.append("\n"+String(report.reason))
    return "\n".join(text)
