extends RefCounted
const KINDS := {"room":"房间","gate":"能力门","shortcut":"捷径","hazard":"危险","pin":"图钉","clue":"入口线索"}
const LIMIT := 1024

static func clean(value: Variant, maximum: int=160) -> String:
    if not value is String:return ""
    return String(value).replace("\r"," ").replace("\n"," ").replace("\t"," ").strip_edges().left(maximum)

static func snapshot(public_rows: Array) -> Dictionary:
    var rows: Array=[]
    var seen: Dictionary={}
    var omitted:=0
    for raw in public_rows:
        if not raw is Dictionary or not KINDS.has(raw.get("kind")):continue
        var title:=clean(raw.get("title"))
        var region:=clean(raw.get("region_name"),80)
        if title.is_empty() or region.is_empty():continue
        # Internal identity is used only to avoid duplicate visible rows; it
        # is never copied into the output projection or exported document.
        var key: Variant=raw.get("key")
        if key is String and seen.has(key):continue
        if key is String:seen[key]=true
        if rows.size()>=LIMIT:omitted+=1;continue
        rows.append({"title":title,"region_name":region,"floor_name":clean(raw.get("floor_name","未标注层位"),80),"kind":KINDS[raw.kind],"detail":clean(raw.get("detail",""),600)})
    rows.sort_custom(func(a: Dictionary,b: Dictionary):
        for field in ["region_name","floor_name","kind","title"]:
            var order:=String(a[field]).naturalnocasecmp_to(String(b[field]))
            if order!=0:return order<0
        return false)
    return {"rows":rows,"omitted":omitted,"checked":[]}

static func toggle(snapshot_data: Dictionary, indices: PackedInt32Array) -> void:
    for index in indices:
        if index<0 or index>=snapshot_data.get("rows",[]).size():continue
        if snapshot_data.checked.has(index):snapshot_data.checked.erase(index)
        else:snapshot_data.checked.append(index)

static func document(snapshot_data: Dictionary, with_details: bool=false) -> String:
    var lines: Array[String]=["已知地图出行清单", "来自生成时的目录筛选；勾选仅为本次核对，不表示已经到达或补绘。"]
    var rows: Array=snapshot_data.get("rows",[])
    var checked: Array=snapshot_data.get("checked",[])
    lines.append("地点%d处 · 本次已勾选%d处" % [rows.size(),checked.size()])
    var last_region:=""
    var last_floor:=""
    for index in rows.size():
        var row: Dictionary=rows[index]
        if row.region_name!=last_region:
            last_region=String(row.region_name);last_floor=""
            lines.append("\n"+last_region)
        if row.floor_name!=last_floor:
            last_floor=String(row.floor_name)
            lines.append("  层位："+last_floor)
        lines.append("%s %s · %s" % ["[x]" if checked.has(index) else "[ ]",row.kind,row.title])
        if with_details and not String(row.detail).is_empty():lines.append("    "+String(row.detail))
    if rows.is_empty():lines.append("\n当前筛选没有可生成清单的已知地点。")
    if int(snapshot_data.get("omitted",0))>0:lines.append("\n另有%d处超出1024条清单上限，请缩小目录筛选后再生成。" % int(snapshot_data.omitted))
    lines.append("\n仅记录公开地点；清单不提供玩家定位、传送、自动路线或未探索地点比例。更改筛选或世界状态后须重新生成。")
    return "\n".join(lines)
