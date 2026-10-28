extends RefCounted
## Arithmetic only over the already-public resource-purpose report. Never executes actions.
const LIMIT:=8
const MAX_COUNTER:=2147483647
static func counter(value: Variant) -> bool:
    return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)>=0 and float(value)<=MAX_COUNTER and floor(float(value))==float(value)
static func catalog(report: Dictionary) -> Dictionary:
    var result: Dictionary={}
    if report.get("ok")!=true or not report.get("uses") is Array:return result
    for use in report.get("uses",[]):
        if not use is Dictionary or not use.get("id") is String or not use.get("name") is String or not counter(use.get("thread")):continue
        if use.id!="heal" and not String(use.id).begins_with("skill_"):continue
        if String(use.id).length()>100 or String(use.name).is_empty() or String(use.name).length()>100:continue
        if result.has(use.id):return {} # Ambiguous public IDs must not pick an arbitrary price.
        result[use.id]={"id":String(use.id),"name":String(use.name),"cost":int(use.thread)}
    return result
static func balance(report: Dictionary) -> Dictionary:
    if report.get("ok")!=true:return {"ok":false,"reason":"当前绯线记录不可读取。"}
    if not report.get("rows") is Array:return {"ok":false,"reason":"当前绯线记录无效。"}
    var found: Dictionary={}
    for row in report.get("rows",[]):
        if not row is Dictionary or row.get("id")!="thread":continue
        if not found.is_empty() or not counter(row.get("count")) or not counter(row.get("maximum")) or row.count>row.maximum:return {"ok":false,"reason":"当前绯线记录无效。"}
        found={"ok":true,"held":int(row.count),"maximum":int(row.maximum)}
    return found if not found.is_empty() else {"ok":false,"reason":"尚无绯线记录。"}
static func preview(report: Dictionary, sequence: Array, reserve_heal: bool) -> Dictionary:
    var wallet:=balance(report)
    if not wallet.ok:return wallet
    if sequence.size()>LIMIT:return {"ok":false,"reason":"一次最多演算八个动作。"}
    var known:=catalog(report)
    if known.is_empty():return {"ok":false,"reason":"尚无可演算的已知动作。"}
    var reserve:=0
    if reserve_heal:
        if not known.has("heal"):return {"ok":false,"reason":"当前疗伤费用不可读取，未预留绯线。"}
        reserve=int(known.heal.cost)
    var remaining:=maxi(0,int(wallet.held)-reserve)
    var required:=reserve
    var blocked:=reserve>int(wallet.held)
    var first_short:=-1
    var rows: Array=[]
    for index in sequence.size():
        var id: Variant=sequence[index]
        if not id is String or not known.has(id):return {"ok":false,"reason":"草案含当前未知或不可用动作，请重新选择。"}
        var action: Dictionary=known[id]
        required+=int(action.cost)
        var before:=remaining
        var state:="前序不足，未继续扣算" if blocked else "费用可支撑"
        if not blocked:
            if int(action.cost)>remaining:
                blocked=true;first_short=index;state="绯线不足"
            else:remaining-=int(action.cost)
        rows.append({"id":id,"name":action.name,"cost":action.cost,"before":before,"after":remaining,"state":state})
    return {"ok":true,"held":wallet.held,"maximum":wallet.maximum,"reserve":reserve,"remaining":remaining,"required":required,"deficit":maxi(0,required-int(wallet.held)),"supported":not blocked,"first_short":first_short,"rows":rows,"reservation_short":reserve>int(wallet.held)}
static func describe(value: Dictionary) -> String:
    if not value.get("ok",false):return String(value.get("reason","暂不可演算。"))
    var lines: Array[String]=["当前绯线%d / %d；另留一次疗伤%d。" % [value.held,value.maximum,value.reserve],"草案共需%d；当前总缺额%d。" % [value.required,value.deficit]]
    for index in value.rows.size():
        var row: Dictionary=value.rows[index]
        lines.append("%d. %s · 费用%d · %s · 可用余额%d → %d" % [index+1,row.name,row.cost,row.state,row.before,row.after])
    if value.reservation_short:lines.append("当前绯线连预留的一次疗伤也不足。")
    lines.append("这里只演算当前费用，不计击中取线或自动恢复；不会执行、预约或保证动作可用。动作、冷却和实际疗伤条件仍以实战为准。")
    return "\n".join(lines)
