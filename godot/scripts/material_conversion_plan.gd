extends RefCounted
## Bounded, read-only conversion search. Callers must provide only known recipes.
const MAX_STEPS:=4
const MAX_STATES:=1024
const MAX_EXPANSIONS:=512
const MAX_STOCK:=999999
static func natural(value: Variant,maximum: int) -> bool:
    return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)>=0.0 and float(value)==floorf(float(value)) and float(value)<=maximum
static func failure(reason: String,limited: bool=false) -> Dictionary:
    return {"ok":false,"reason":reason,"limited":limited}
static func schema(recipes: Array) -> bool:
    if recipes.size()>24:return false
    var seen:={}
    for row in recipes:
        if not row is Dictionary:return false
        for key in ["id","input","output"]:
            if not row.get(key) is String or row[key].is_empty() or row[key].length()>128:return false
        if seen.has(row.id) or row.input==row.output:return false
        seen[row.id]=true
        for key in ["input_amount","output_amount","currency"]:
            if not natural(row.get(key),9999999):return false
        if int(row.input_amount)<1 or int(row.output_amount)<1:return false
    return true
static func initial(recipes: Array,inventory: Dictionary,money: Variant,target: String,required: Variant) -> Dictionary:
    if not schema(recipes) or not natural(money,9999999) or not natural(required,MAX_STOCK) or int(required)<1:
        return failure("兑换规划字段无效，未计算。")
    var material_ids:={}
    for row in recipes:material_ids[row.input]=true;material_ids[row.output]=true
    if not material_ids.has(target):return failure("目标不在已知兑换材料中。")
    var counts:={}
    for id in material_ids:
        if not natural(inventory.get(id,0),MAX_STOCK):return failure("材料库存无效，未计算。")
        counts[id]=int(inventory.get(id,0))
    return {"ok":true,"counts":counts,"money":int(money)}
static func transition(node: Dictionary,recipe: Dictionary,batches: int) -> Dictionary:
    if batches<1 or batches>10:return {}
    var spent:=int(recipe.input_amount)*batches
    var gained:=int(recipe.output_amount)*batches
    var cost:=int(recipe.currency)*batches
    if int(node.counts.get(recipe.input,0))<spent or int(node.money)<cost:return {}
    if int(node.counts.get(recipe.output,0))+gained>MAX_STOCK:return {}
    var counts: Dictionary=node.counts.duplicate()
    counts[recipe.input]-=spent;counts[recipe.output]=int(counts.get(recipe.output,0))+gained
    var path: Array=node.path.duplicate(true)
    path.append({"recipe":String(recipe.id),"batches":batches,"spent":spent,"gained":gained,"cost":cost})
    return {"counts":counts,"money":int(node.money)-cost,"path":path}
static func signature(node: Dictionary,ids: Array) -> String:
    var values: Array=[node.path.size()]
    for id in ids:values.append(node.counts[id])
    return var_to_str(values)
static func search(recipes: Array,inventory: Dictionary,money: Variant,target: String,required: Variant) -> Dictionary:
    var start:=initial(recipes,inventory,money,target,required)
    if not start.ok:return start
    var ordered:=recipes.duplicate(true)
    ordered.sort_custom(func(a: Dictionary,b: Dictionary):return String(a.id)<String(b.id))
    var first:={"counts":start.counts,"money":start.money,"path":[]}
    var ids: Array=start.counts.keys();ids.sort()
    var frontier: Array=[first]
    var visited:={signature(first,ids):int(start.money)}
    var expanded:=0;var generated:=1
    while not frontier.is_empty():
        # Maximum remaining wallet first: the first accepted result is cheapest
        # inside this explicit four-operation search, if the bound is not hit.
        frontier.sort_custom(func(a: Dictionary,b: Dictionary):
            return a.money>b.money if a.money!=b.money else a.path.size()<b.path.size())
        var node: Dictionary=frontier.pop_front()
        if int(visited.get(signature(node,ids),-1))>int(node.money):continue
        if int(node.counts[target])>=int(required):
            return {"ok":true,"counts":node.counts.duplicate(),"money":int(node.money),"cost":int(start.money)-int(node.money),"path":node.path.duplicate(true),"expanded":expanded,"generated":generated,"limited":false}
        if node.path.size()>=MAX_STEPS:continue
        if expanded>=MAX_EXPANSIONS:return failure("搜索达到工作上限，未判断是否存在方案。",true)
        expanded+=1
        for recipe in ordered:
            for batches in range(1,11):
                var next:=transition(node,recipe,batches)
                if next.is_empty():continue
                var key:=signature(next,ids)
                if int(visited.get(key,-1))>=int(next.money):continue
                if generated>=MAX_STATES:return failure("搜索达到容量上限，未判断是否存在方案。",true)
                visited[key]=int(next.money);frontier.append(next);generated+=1
    return failure("在四次交易、每次最多十份的范围内未找到可行方案。")
static func verify(recipes: Array,inventory: Dictionary,money: Variant,target: String,required: Variant,result: Dictionary) -> bool:
    var start:=initial(recipes,inventory,money,target,required)
    if not start.ok or not result.get("ok",false) or not result.get("path") is Array or result.path.size()>MAX_STEPS:return false
    var node:={"counts":start.counts,"money":start.money,"path":[]}
    var by_id:={}
    for row in recipes:by_id[row.id]=row
    for step in result.path:
        if not step is Dictionary or not by_id.has(step.get("recipe")) or not natural(step.get("batches"),10) or int(step.batches)<1:return false
        node=transition(node,by_id[step.recipe],int(step.batches))
        if node.is_empty() or node.path[-1]!=step:return false
    return node.counts==result.get("counts") and node.money==result.get("money") and int(start.money)-int(node.money)==result.get("cost") and int(node.counts[target])>=int(required)
