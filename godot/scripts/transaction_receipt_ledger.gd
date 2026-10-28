extends RefCounted
## Ephemeral, bounded receipts of already durable field transactions. Never a save source.
const LIMIT:=32
const MAX_ITEMS:=4096
const MAX_CHANGES:=64
var entries: Array=[]
var generation:=0
var next_sequence:=1
var dropped:=0
var problem:=""
static func whole(value: Variant,maximum: int) -> bool:
    return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)>=0 and float(value)<=maximum and floor(float(value))==float(value)
static func valid_wallet(value: Variant) -> bool:
    if not value is Dictionary or not whole(value.get("currency"),9999999) or not value.get("items") is Dictionary or value.items.size()>MAX_ITEMS:return false
    for id in value.items:
        if not id is String or id.is_empty() or id.length()>96 or not whole(value.items[id],999999):return false
    return true
func reject(reason: String) -> bool:
    if problem!=reason:problem=reason;generation+=1
    return false
func record(before: Dictionary,after: Dictionary,region: String) -> bool:
    if not valid_wallet(before) or not valid_wallet(after):return reject("一笔资源变化暂不可完整读取；正式结算结果仍以原窗口为准。")
    var keys: Dictionary={}
    for id in before.items:keys[id]=true
    for id in after.items:keys[id]=true
    var changes: Array=[]
    var ordered: Array=keys.keys();ordered.sort()
    for id in ordered:
        var old:=int(before.items.get(id,0));var current:=int(after.items.get(id,0))
        if old==current:continue
        if changes.size()>=MAX_CHANGES:return reject("一笔变化超过记录上限，未把部分差额当成完整回执。")
        changes.append({"item":id,"before":old,"after":current,"delta":current-old})
    var delta:=int(after.currency)-int(before.currency)
    if changes.is_empty() and delta==0:
        if not problem.is_empty():problem="";generation+=1
        return false
    entries.push_front({"sequence":next_sequence,"region":region.left(96),"currency_before":int(before.currency),"currency_after":int(after.currency),"currency_delta":delta,"items":changes})
    next_sequence+=1
    if entries.size()>LIMIT:entries.pop_back();dropped+=1
    problem="";generation+=1
    return true
func report() -> Dictionary:
    return {"rows":entries.duplicate(true),"generation":generation,"dropped":dropped,"problem":problem}
func clear(expected: int) -> Dictionary:
    if expected!=generation:return {"ok":false,"reason":"记录已有新变化，请重新核对后清空。"}
    if not entries.is_empty() or not problem.is_empty():entries=[];dropped=0;problem="";generation+=1
    return {"ok":true,"reason":"本次运行的结算回执已清空；归途记录与资源不变。"}
static func item_name(callback: Callable,id: String) -> String:
    var value: Variant=callback.call(id) if callback.is_valid() else ""
    return String(value) if value is String and not value.is_empty() and value!=id else "已结算物品"
static func projection(entry: Dictionary,name_for: Callable) -> Dictionary:
    var result:={"sequence":entry.sequence,"region":entry.region,"currency_delta":entry.currency_delta,"spent":int(entry.currency_delta)<0,"received":int(entry.currency_delta)>0,"items":[]}
    var labels: Array[String]=[String(entry.region),"钟龛结算"]
    for change in entry.items:
        var name:=item_name(name_for,String(change.item));labels.append(name)
        result.items.append({"name":name,"before":change.before,"after":change.after,"delta":change.delta})
        result.spent=result.spent or int(change.delta)<0
        result.received=result.received or int(change.delta)>0
    result["search"]=" ".join(labels).to_lower()
    result["currency_before"]=entry.currency_before;result["currency_after"]=entry.currency_after
    return result
static func browse(report: Dictionary,name_for: Callable,query: String="",mode: int=0) -> Array:
    var rows: Array=[]
    var tokens:=query.left(80).to_lower().replace("　"," ").replace("\t"," ").split(" ",false)
    for entry in report.get("rows",[]):
        var row:=projection(entry,name_for)
        if mode==1 and not row.spent:continue
        if mode==2 and not row.received:continue
        var matches:=true
        for token in tokens:
            if not String(row.search).contains(token):matches=false;break
        if matches:rows.append(row)
    return rows
static func describe(row: Dictionary) -> String:
    var lines: Array[String]=["第%d笔 · %s · 已确认钟龛结算" % [row.sequence,row.region],"松脂碎钱：%d → %d（%+d）" % [row.currency_before,row.currency_after,row.currency_delta]]
    for change in row.items:lines.append("%s：%d → %d（%+d）" % [change.name,change.before,change.after,change.delta])
    lines.append("\n这里只显示已经成功写入归途后的资源变化；不是待确认报价，不提供撤销或再次领取。")
    return "\n".join(lines)
