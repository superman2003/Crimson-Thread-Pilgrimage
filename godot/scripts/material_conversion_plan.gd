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
static func begin(recipes: Array,inventory: Dictionary,money: Variant,target: String,required: Variant) -> RefCounted:
    var session:=SearchSession.new()
    session.transition_step=transition
    session.state_key=signature
    session.target=target
    session.required=int(required) if natural(required,MAX_STOCK) else 0
    var start:=initial(recipes,inventory,money,target,required)
    if not start.ok:
        session.finish(start)
        return session
    session.start_money=int(start.money)
    session.recipes=recipes.duplicate(true)
    session.recipes.sort_custom(func(left: Dictionary,right: Dictionary):return String(left.id)<String(right.id))
    session.ids=start.counts.keys()
    session.ids.sort()
    var first:={"counts":start.counts,"money":start.money,"path":[]}
    session.frontier=[first]
    session.visited[signature(first,session.ids)]=session.start_money
    return session

static func search(recipes: Array,inventory: Dictionary,money: Variant,target: String,required: Variant) -> Dictionary:
    var session:=begin(recipes,inventory,money,target,required)
    while not session.done:
        session.advance(32)
    return session.result.duplicate(true)

class SearchSession extends RefCounted:
    var done:=false
    var result: Dictionary={}
    var frontier: Array=[]
    var visited: Dictionary={}
    var recipes: Array=[]
    var ids: Array=[]
    var target:=""
    var required:=0
    var start_money:=0
    var expanded:=0
    var generated:=1
    var popped:=0
    var transition_step: Callable
    var state_key: Callable

    func finish(value: Dictionary) -> void:
        result=value.duplicate(true)
        done=true
        frontier.clear()
        visited.clear()

    func cancel() -> void:
        if done:return
        finish({"ok":false,"limited":false,"cancelled":true,"reason":"本次规划已取消，库存没有改变。"})

    func advance(work: int=32) -> void:
        if done:return
        var quota:=clampi(work,1,32)
        var consumed:=0
        while consumed<quota and not frontier.is_empty():
            consumed+=1
            popped+=1
            frontier.sort_custom(func(left: Dictionary,right: Dictionary):
                return left.money>right.money if left.money!=right.money else left.path.size()<right.path.size())
            var node: Dictionary=frontier.pop_front()
            var current_key: String=state_key.call(node,ids)
            if int(visited.get(current_key,-1))>int(node.money):continue
            if int(node.counts[target])>=required:
                finish({"ok":true,"counts":node.counts,"money":int(node.money),"cost":start_money-int(node.money),"path":node.path,"expanded":expanded,"generated":generated,"limited":false})
                return
            if node.path.size()>=4:continue
            if expanded>=512:
                finish({"ok":false,"limited":true,"reason":"搜索达到工作上限，未判断是否存在方案。"})
                return
            expanded+=1
            for recipe in recipes:
                for batches in range(1,11):
                    var next: Dictionary=transition_step.call(node,recipe,batches)
                    if next.is_empty():continue
                    var key: String=state_key.call(next,ids)
                    if int(visited.get(key,-1))>=int(next.money):continue
                    if generated>=1024:
                        finish({"ok":false,"limited":true,"reason":"搜索达到容量上限，未判断是否存在方案。"})
                        return
                    visited[key]=int(next.money)
                    frontier.append(next)
                    generated+=1
        if frontier.is_empty():
            finish({"ok":false,"limited":false,"reason":"在四次交易、每次最多十份的范围内未找到可行方案。"})
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
