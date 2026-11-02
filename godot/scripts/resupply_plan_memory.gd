extends RefCounted
## An explicit shopping preference, scoped to the journey. No prices, wallet,
## stock, unlocks or gameplay save are stored here.
var store:=preload("res://scripts/journey_desk_store.gd").new()
var journey_key:=""

func configure(journey: String) -> void:
    if journey.is_empty() or journey==journey_key:return
    journey_key=journey
    store.configure("resupply_plan",journey)

static func valid(plan: Variant) -> bool:
    if not plan is Dictionary or plan.size()!=2 or not plan.get("order") is Array or not plan.get("limits") is Dictionary:return false
    if plan.order.size()>32 or plan.order.size()!=plan.limits.size():return false
    var seen:={}
    for id in plan.order:
        if not id is String or id.is_empty() or id.length()>64 or not id.is_valid_identifier() or seen.has(id):return false
        var amount: Variant=plan.limits.get(id)
        if typeof(amount) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(amount)) or float(amount)<0 or float(amount)>100 or float(amount)!=floor(float(amount)):return false
        seen[id]=true
    return true

func save(plan: Dictionary) -> Dictionary:
    if store.path.is_empty():return {"ok":false,"reason":"当前旅途暂不能保存补给清单。"}
    if not valid(plan):return {"ok":false,"reason":"清单内容无效，已存清单保持不变。"}
    var ok: bool=store.write(plan)
    return {"ok":ok,"reason":"已保存补给顺序与申请份数；下次读取仍会重新报价。" if ok else store.error}

func load_for(options: Array) -> Dictionary:
    if store.path.is_empty():return {"ok":false,"reason":"当前旅途暂不能读取补给清单。"}
    if not FileAccess.file_exists(store.path):return {"ok":false,"reason":"这段旅途尚无已存补给清单。"}
    var saved: Dictionary=store.read()
    if not store.writable:return {"ok":false,"reason":store.error}
    if not valid(saved):
        store.writable=false;store.error="已存补给清单无效，保留原文件与当前申请。"
        return {"ok":false,"reason":store.error}
    return project(saved,options)

static func project(saved: Dictionary, options: Array) -> Dictionary:
    if not valid(saved):return {"ok":false,"reason":"清单内容无效。"}
    var available:={}
    for row in options:
        if not row is Dictionary or not row.get("unlocked") is bool or not row.unlocked or not row.get("id") is String:continue
        available[String(row.id)]=row
    var order: Array=[]
    var limits:={}
    var skipped:=0
    var clamped:=0
    for id in saved.order:
        if not available.has(id):skipped+=1;continue
        var row: Dictionary=available[id]
        var missing:=maxi(0,int(row.get("capacity",0))-int(row.get("count",0)))
        var amount:=mini(int(saved.limits[id]),missing)
        order.append(id);limits[id]=amount
        clamped+=int(saved.limits[id])-amount
    # New unlocks are shown for editing but are never silently added to a saved
    # order. Only a fresh explicit request may spend resources on them.
    for id in available:
        if not limits.has(id):order.append(id);limits[id]=0
    return {"ok":true,"plan":{"order":order,"limits":limits},"skipped":skipped,"clamped":clamped}
