extends RefCounted
## A prerequisite is a separate transaction in the current craft system.
## Produce ordered carts, never put an unmade prerequisite and its child in
## one cart, and never grant simulated crafts to the live build.
const MAX_NODES := 64
const CART_LIMIT := 8

static func plan(recipes: Dictionary, crafted: Array, requested: Array, artisan: String) -> Dictionary:
    if requested.is_empty() or requested.size()>CART_LIMIT:return failure("先选择1至8件目标改制。")
    var context: Dictionary={"seen":{},"visiting":{},"ordered":[],"error":""}
    var unique: Dictionary={}
    for id in requested:
        if not id is String or unique.has(id):return failure("目标清单含重复或无效方案。")
        unique[id]=true
        if not visit(id,recipes,crafted,artisan,context):return failure(String(context.error))
    if context.ordered.is_empty():return failure("所选目标均已完成，没有待制作的前阶。")
    var remaining: Array=context.ordered.duplicate()
    var simulated:=crafted.duplicate()
    var batches: Array=[]
    while not remaining.is_empty() and batches.size()<MAX_NODES:
        var next: Array[String]=[]
        for id in remaining:
            var ready:=true
            for prior in recipes[id].get("requires_crafted",[]):
                if not simulated.has(prior):ready=false;break
            if ready and next.size()<CART_LIMIT:next.append(String(id))
        if next.is_empty():return failure("前阶关系无法排序，未修改清单。")
        batches.append({"ids":next.duplicate(),"names":next.map(func(id: String):return String(recipes[id].get("name",id)))})
        for id in next:remaining.erase(id);simulated.append(id)
    if not remaining.is_empty():return failure("前阶链过长，未修改清单。")
    return {"ok":true,"batches":batches,"total":context.ordered.size(),"fingerprint":var_to_str([recipes,crafted,requested,artisan]).sha256_text()}

static func visit(id: String, recipes: Dictionary, crafted: Array, artisan: String, context: Dictionary) -> bool:
    if crafted.has(id):return true
    if context.visiting.has(id):context.error="制作前阶存在循环，未修改清单。";return false
    if context.seen.has(id):return true
    if context.seen.size()+context.visiting.size()>=MAX_NODES:context.error="制作前阶超过64件，未修改清单。";return false
    if not recipes.get(id) is Dictionary:context.error="制作前阶包含未知方案，未修改清单。";return false
    var recipe: Dictionary=recipes[id]
    if not String(recipe.get("artisan","")) in ["",artisan]:context.error="部分前阶需要另一位工匠；请先完成该处改制后再来规划。";return false
    if not recipe.get("requires_crafted",[]) is Array:context.error="前阶记录无效，未修改清单。";return false
    context.visiting[id]=true
    for prior in recipe.get("requires_crafted",[]):
        if not prior is String:context.error="前阶记录无效，未修改清单。";return false
        if not visit(prior,recipes,crafted,artisan,context):return false
    context.visiting.erase(id);context.seen[id]=true;context.ordered.append(id)
    return true

static func describe(plan_result: Dictionary) -> String:
    if not plan_result.get("ok",false):return String(plan_result.get("reason","暂不能规划。"))
    var lines: Array[String]=["包含前阶共%d件，分%d批。" % [plan_result.total,plan_result.batches.size()],"每批须单独核价、支付和写入；后批只是预览，尚未制作。"]
    for index in plan_result.batches.size():
        var names: Array[String]=[]
        for name in plan_result.batches[index].names:names.append(String(name))
        lines.append("\n第%d批（%d件）\n· %s" % [index+1,names.size(),"\n· ".join(names)])
    lines.append("\n使用下一批只替换当前清单；不消费资源，也不绕过图样、校习、工匠和钱包条件。完成本批后重新选择目标，继续规划。")
    return "\n".join(lines)

static func failure(reason: String) -> Dictionary:return {"ok":false,"reason":reason}
