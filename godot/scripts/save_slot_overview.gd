extends RefCounted
## Read-only presentation of the six snapshots supplied by get_save_slots.
## A newer timestamp is never treated as a more advanced or safer journey.
static func rows(snapshots: Array, current: int) -> Array:
    var result: Array=[]
    var seen: Dictionary={}
    for snapshot in snapshots:
        if not snapshot is Dictionary or typeof(snapshot.get("slot"))!=TYPE_INT:continue
        var slot:=int(snapshot.slot)
        if slot<1 or slot>3 or seen.has(slot):continue
        seen[slot]=true
        var primary: Dictionary=snapshot.duplicate(true)
        primary.erase("backup")
        var backup: Dictionary=snapshot.get("backup",{}).duplicate(true) if snapshot.get("backup") is Dictionary else {}
        var state:="主档可读" if readable(primary) else "主档不可读" if primary.get("exists")==true else "空槽"
        if not readable(primary) and readable(backup):state+=" · 有可读备份"
        elif primary.get("exists")==true and not readable(backup):state+=" · 无可读备份"
        result.append({"slot":slot,"current":slot==current,"primary":primary,"backup":backup,"state":state})
    result.sort_custom(func(a: Dictionary,b: Dictionary):return a.slot<b.slot)
    return result

static func readable(snapshot: Dictionary) -> bool:
    return snapshot.get("exists")==true and snapshot.get("valid")==true

static func relationship(primary: Dictionary, backup: Dictionary) -> String:
    if not readable(primary) or not readable(backup):return "只有两份记录均可读取时才能核对差异。"
    var first:=String(primary.get("sha",""))
    var second:=String(backup.get("sha",""))
    if not first.is_empty() and first==second:return "主档与备份的文件指纹相同。"
    var lines: Array[String]=["主档与备份是不同文件；资源计数相同也不代表旅途相同。"]
    var a: Variant=primary.get("modified",0)
    var b: Variant=backup.get("modified",0)
    if typeof(a)==TYPE_INT and typeof(b)==TYPE_INT and int(a)>0 and int(b)>0:
        lines.append("备份文件时间晚于主档。" if b>a else "备份文件时间早于主档。" if b<a else "两份文件时间相同。")
    lines.append("文件时间不能判断路线、结局或装备哪一份更合意；请进入原核对窗口阅读差异。")
    return "\n".join(lines)

static func describe(row: Dictionary, describe_snapshot: Callable) -> String:
    if row.is_empty():return "请选择一个存档槽。"
    var lines: Array[String]=["存档槽%d%s" % [int(row.slot)," · 当前旅途" if row.current else ""],String(row.state)]
    if describe_snapshot.is_valid():
        lines.append("\n主档\n"+String(describe_snapshot.call(row.primary)))
        lines.append("\n备份\n"+String(describe_snapshot.call(row.backup)))
    for pair in [["primary","主档"],["backup","备份"]]:
        var info: Dictionary=row[pair[0]]
        if not String(info.get("error","")).is_empty():lines.append(pair[1]+"读取说明："+String(info.error))
    lines.append("\n"+relationship(row.primary,row.backup))
    lines.append("\n这是打开或刷新时的磁盘快照，尚未保存当前内存进度。查看不会切换、恢复或写入任何存档；实际操作仍须另行核对确认。")
    return "\n".join(lines)
