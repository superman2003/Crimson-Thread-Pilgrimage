extends RefCounted
## Optional per-stage detail. Historical records without this field remain
## readable and are never assigned invented progress or split times.
static func restore(raw: Dictionary) -> Dictionary:
    var result: Dictionary={}
    if not raw.get("stages") is Array or raw.stages.is_empty() or raw.stages.size()>32:return result
    var stages: Array=[]
    for row in raw.stages:
        if not row is Dictionary or not row.get("label") is String:return {}
        if not integer(row.get("required"),1,1000) or not integer(row.get("accepted"),0,1000):return {}
        if int(row.accepted)>int(row.required) or not number(row.get("seconds"),3600.0):return {}
        stages.append({"label":String(row.label).left(80),"required":int(row.required),"accepted":int(row.accepted),"seconds":float(row.seconds)})
    result["stages"]=stages
    return result

static func number(value: Variant, maximum: float) -> bool:
    return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)>=0 and float(value)<=maximum

static func integer(value: Variant, minimum: int, maximum: int) -> bool:
    return number(value,maximum) and float(value)>=minimum and floor(float(value))==float(value)

static func capture(active: Dictionary) -> Dictionary:
    if active.is_empty():return {}
    var stages: Array=[]
    var course: Dictionary=active.course
    for index in course.stages.size():
        var stage: Dictionary=course.stages[index]
        var accepted:=int(stage.count) if index<int(active.stage) else int(active.count) if index==int(active.stage) else 0
        stages.append({"label":String(stage.label),"required":int(stage.count),"accepted":accepted,"seconds":float(active.get("split_seconds",{}).get(index,0.0))})
    return restore({"stages":stages})

static func summary(history: Array, id: String) -> String:
    var attempts:=0
    var completions:=0
    var best:=INF
    var slowest:=0.0
    var total:=0.0
    for row in history:
        if not row is Dictionary or row.get("course")!=id:continue
        if not row.get("complete") is bool or not number(row.get("seconds"),3600):continue
        attempts+=1;total+=float(row.seconds)
        if row.complete:
            completions+=1;best=minf(best,float(row.seconds));slowest=maxf(slowest,float(row.seconds))
    if attempts==0:return "这个课程暂无已保存尝试。"
    var lines: Array[String]=["保留记录：尝试%d次，完成%d次，累计%.1f秒。" % [attempts,completions,total]]
    if completions>0:lines.append("完成用时：最好%.1f秒，最慢%.1f秒。" % [best,slowest])
    lines.append("统计只含最近24条中属于本课程的已保存记录；未写入的尝试不计入。")
    return "\n".join(lines)

static func describe(record: Dictionary) -> String:
    var clean:=restore(record)
    if clean.is_empty():return "旧记录未保存分步进度。"
    var lines: Array[String]=[]
    var completed:=0
    for stage in clean.stages:
        if stage.accepted==stage.required:completed+=1
        lines.append("%s · %d/%d · %.1f秒" % [stage.label,stage.accepted,stage.required,stage.seconds])
    lines.push_front("已完成%d/%d步；未完成动作不会算作完成。" % [completed,clean.stages.size()])
    return "\n".join(lines)
