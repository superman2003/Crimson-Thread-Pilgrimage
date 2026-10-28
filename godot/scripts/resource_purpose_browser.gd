extends RefCounted
const LEDGER := preload("res://scripts/resource_purpose_ledger.gd")
## Extend the public reverse index only with materials already named in an
## unlocked cost. A zero-stock known material must remain discoverable.
static func public_rows(report: Dictionary, name_for: Callable) -> Array:
    if report.get("ok")!=true:return []
    var result: Array=[]
    var seen: Dictionary={}
    for raw in report.get("rows",[]):
        if not raw is Dictionary or not raw.get("id") is String or not LEDGER.counter(raw.get("count")):continue
        if seen.has(raw.id):continue
        seen[raw.id]=true;result.append(raw.duplicate(true))
    for use in report.get("uses",[]):
        if not use is Dictionary or not use.get("materials") is Dictionary:continue
        for id in use.materials:
            if not id is String or seen.has(id):continue
            var cost: Variant=use.materials[id]
            if not cost is Dictionary or not LEDGER.counter(cost.get("owned")):continue
            var title:=String(name_for.call(id)) if name_for.is_valid() else "已知材料"
            result.append({"id":id,"name":title,"count":int(cost.owned),"purpose":"已解锁用途中已经列明的材料；未持有也可在这里核对缺额。"})
            seen[id]=true
    return result

static func required(use: Dictionary, id: String) -> int:
    if id=="currency":return int(use.get("currency",0)) if LEDGER.counter(use.get("currency",0)) else 0
    if id=="thread":return int(use.get("thread",0)) if LEDGER.counter(use.get("thread",0)) else 0
    var cost: Variant=use.get("materials",{}).get(id,{})
    return int(cost.get("required",0)) if cost is Dictionary and LEDGER.counter(cost.get("required",0)) else 0

static func inspect(row: Dictionary, report: Dictionary) -> Dictionary:
    var result:=row.duplicate(true)
    result["pending_uses"]=0;result["ready_uses"]=0;result["short_uses"]=0;result["largest_shortfall"]=0
    var labels: Array[String]=[]
    for use in report.get("uses",[]):
        if not use is Dictionary:continue
        var amount:=required(use,String(row.id))
        if amount<=0:continue
        labels.append(String(use.get("name",""))+" "+String(use.get("kind","")))
        if use.get("complete")==true:continue
        result.pending_uses+=1
        if use.get("ready")==true:result.ready_uses+=1
        var deficit:=maxi(0,amount-int(row.count))
        if deficit>0:result.short_uses+=1;result.largest_shortfall=maxi(result.largest_shortfall,deficit)
    result["search_text"]=(String(row.get("name",""))+" "+String(row.get("purpose",""))+" "+" ".join(labels)).to_lower()
    return result

static func browse(report: Dictionary, name_for: Callable, query: String="", scope: int=0, order: int=0) -> Array:
    var result: Array=[]
    var tokens:=query.left(80).to_lower().replace("　"," ").replace("\t"," ").replace("\n"," ").split(" ",false)
    for raw in public_rows(report,name_for):
        var row:=inspect(raw,report)
        if scope==1 and row.ready_uses==0:continue
        if scope==2 and row.short_uses==0:continue
        if scope==3 and row.pending_uses>0:continue
        var matches:=true
        for token in tokens:
            if not String(row.search_text).contains(token):matches=false;break
        if matches:result.append(row)
    result.sort_custom(func(a: Dictionary,b: Dictionary):
        if order==1 and a.count!=b.count:return a.count<b.count
        if order==2 and a.largest_shortfall!=b.largest_shortfall:return a.largest_shortfall>b.largest_shortfall
        var compared:=String(a.name).naturalnocasecmp_to(String(b.name))
        return compared<0 if compared!=0 else String(a.id)<String(b.id))
    return result

static func summary(row: Dictionary) -> String:
    return "已知未完成用途%d项 · 所示条件已齐%d项 · 本资源不足%d项\n最大单项缺额%d；各用途独立核对，没有把多份互斥制作费用相加。" % [row.pending_uses,row.ready_uses,row.short_uses,row.largest_shortfall]
