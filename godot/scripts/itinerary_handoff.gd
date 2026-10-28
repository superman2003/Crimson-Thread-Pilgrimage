extends RefCounted
## Explicit bridge from a saved analysis candidate to the live auxiliary route.
const DOMAIN:=preload("res://journey/fieldwork/itinerary/model.gd")
const PLAN:=preload("res://scripts/expedition_plan.gd")
static func denied(reason: String) -> Dictionary:return {"ok":false,"reason":reason}
static func identity(plan: RefCounted,known: Array,region: String,scope: String) -> String:
    var keys: Array=[]
    for row in known:
        if row is Dictionary:keys.append(String(row.get("key","")))
    keys.sort()
    return var_to_str([plan.state,keys,region,scope]).sha256_text()
static func quote(payload: Dictionary,known: Array,plan: RefCounted,region: String,scope: String) -> Dictionary:
    if not DOMAIN.validate(payload):return denied("候选字段无效，请先在排程页修正。")
    if String(payload.graph.region)!=region:return denied("候选不是当前地区，不能安排到当前行程。")
    if DOMAIN.targets(payload).size()>PLAN.LIMIT:return denied("实际行程最多六站；请先减少候选目标。")
    var allowed:={}
    for row in known:
        if row is Dictionary and row.get("kind")=="room" and row.get("region")==region and row.get("room_id") is String:
            allowed[row.room_id]=row
    # Gate all requested targets, including those a heuristic might omit.
    for id in DOMAIN.targets(payload):
        if not allowed.has(id):return denied("候选含当前地图不可见的目标，请先补绘或减少目标。")
    if payload.get("return",false) and not allowed.has(payload.start):return denied("返回起点尚不在当前已补绘目录中。")
    var matrix:=DOMAIN.matrix(payload)
    var solution:=DOMAIN.solve(payload,matrix)
    if not solution.get("ok",false):return denied("候选无法得到可用排程，请先查看分析原因。")
    if not DOMAIN.verify(payload,solution,matrix).get("ok",false):return denied("候选排程核对失败，原行程保持不变。")
    var stops: Array=[];var rows: Array=[]
    for id in solution.order.slice(1):
        if not allowed.has(id):return denied("候选含当前地图不可见的目标，请先补绘或减少目标。")
        stops.append(String(allowed[id].key));rows.append({"title":String(allowed[id].title),"region_name":String(allowed[id].region_name)})
    if payload.get("return",false):
        stops.append(String(allowed[payload.start].key));rows.append({"title":String(allowed[payload.start].title),"region_name":String(allowed[payload.start].region_name)})
    if stops.is_empty():return denied("候选没有可安排的目标。")
    if stops.size()>PLAN.LIMIT:return denied("包含返回起点后超过六站；请减少目标或取消返回。")
    var candidate:={"stops":stops,"done":[],"deferred":[],"active":false}
    return {"ok":true,"candidate":candidate,"rows":rows,"fingerprint":identity(plan,known,region,scope),"omitted":maxi(0,DOMAIN.targets(payload).size()-solution.order.size()+1)}
static func apply(payload: Dictionary,known: Array,plan: RefCounted,region: String,scope: String,expected: Dictionary) -> Dictionary:
    var fresh:=quote(payload,known,plan,region,scope)
    if not fresh.ok:return fresh
    if fresh.fingerprint!=expected.get("fingerprint") or fresh.candidate!=expected.get("candidate"):
        return denied("行程、地图知识或候选已改变，请关闭后重新核对。")
    if not plan.commit(fresh.candidate):return denied(plan.store.error)
    return {"ok":true,"reason":"目标顺序已安排，行程保持暂停；只记录站序，不保证现场可通行。"}
static func describe(view: Dictionary) -> String:
    if not view.get("ok",false):return String(view.get("reason","暂不可安排。"))
    var lines: Array[String]=["将用候选求解的目标顺序替换当前行程，清除本行程勾选与暂缓，并保持暂停。"]
    for index in view.rows.size():lines.append("%d. %s · %s" % [index+1,view.rows[index].region_name,view.rows[index].title])
    if int(view.omitted)>0:lines.append("预算或允许跳过的规则省略了 %d 个已知目标。" % int(view.omitted))
    lines.append("只采用站序，不采用候选中的时间、距离、通行能力或位置；这些仍须在实际地图核对。不会移动角色、揭图、领取奖励或改变游戏存档。")
    return "\n\n".join(lines)
