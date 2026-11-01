extends RefCounted
const PATH := "res://data/practice_curriculum.json"
const MAX_HISTORY := 24
var courses: Array=[]
var history: Array=[]
var active: Dictionary={}
var pending: Dictionary={}
var store:=preload("res://scripts/journey_desk_store.gd").new()

func configure(journey: String) -> void:
    history=[]
    store.configure("curriculum",journey)
    var raw: Variant=JSON.parse_string(FileAccess.get_file_as_string(PATH))
    courses=raw.get("courses",[]).duplicate(true) if raw is Dictionary else []
    var data:=store.read()
    if data.get("history") is Array:
        for record in data.history.slice(0,MAX_HISTORY):
            if not record is Dictionary or not record.get("course") is String or not record.get("complete") is bool:continue
            var seconds: Variant=record.get("seconds")
            if typeof(seconds) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(seconds)) or float(seconds)<0.0 or float(seconds)>3600.0:continue
            var restored: Dictionary={"course":record.course,"complete":record.complete,"seconds":float(seconds),"reason":String(record.get("reason","")).left(80)}
            restored.merge(preload("res://scripts/practice_attempt_review.gd").restore(record))
            history.append(restored)

static func earned(inventory: Dictionary, ability: String) -> bool:
    var value: Variant=inventory.get(ability,0)
    return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)>=1.0 and float(value)==floor(float(value))

func available(inventory: Dictionary) -> Array:
    return courses.filter(func(course):return course.requires.all(func(ability):return earned(inventory,String(ability))))

func browse(inventory: Dictionary, query: String = "", mode: int = 0) -> Array:
    var result: Array = []
    var tokens := query.left(80).to_lower().replace("　"," ").replace("\t"," ").replace("\n"," ").split(" ",false)
    for course in available(inventory):
        var completed := best(String(course.id)) < INF
        if (mode == 1 and completed) or (mode == 2 and not completed):continue
        var text := (String(course.title)+"\n"+String(course.hint)).to_lower()
        var matches:=true
        for token in tokens:
            if not text.contains(token):matches=false;break
        if matches:result.append(course.duplicate(true))
    return result

func recent(id: String, inventory: Dictionary, limit: int = 3) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    if not available(inventory).any(func(course):return course.id==id):return result
    for record in history:
        if record.course!=id:continue
        result.append(record.duplicate(true))
        if result.size()>=clampi(limit,1,6):break
    return result

func start(id: String, inventory: Dictionary) -> Dictionary:
    if not active.is_empty() or not pending.is_empty():return {"ok":false,"reason":"先结束当前课程或处理待保存记录。"}
    for course in available(inventory):
        if course.id!=id:continue
        active={"course":course.duplicate(true),"stage":0,"count":0,"seconds":0.0,"seen":{},"split_seconds":{}}
        return {"ok":true,"reason":"课程开始；只观察真实动作，不授予资源或能力。"}
    return {"ok":false,"reason":"课程尚不可用。"}

func tick(delta: float) -> void:
    if not active.is_empty() and is_finite(delta) and delta>0.0:
        var elapsed:=minf(delta,1.0)
        active.seconds+=elapsed
        active.split_seconds[active.stage]=float(active.split_seconds.get(active.stage,0.0))+elapsed

func accept(action: String, frame: int) -> bool:
    if active.is_empty():return false
    var stage: Dictionary=active.course.stages[active.stage]
    if action!=stage.action or active.seen.get(action,-1)==frame:return false
    active.seen[action]=frame
    active.count+=1
    if active.count>=int(stage.count):
        active.stage+=1;active.count=0
        if active.stage>=active.course.stages.size():finish(true,"课程完成")
    return true

func finish(complete: bool, reason: String) -> void:
    if active.is_empty():return
    pending={"course":String(active.course.id),"complete":complete,"seconds":float(active.seconds),"reason":reason.left(80)}
    pending.merge(preload("res://scripts/practice_attempt_review.gd").capture(active))
    active={}
    retry()

func retry() -> bool:
    if pending.is_empty():return true
    var next:=history.duplicate(true)
    next.push_front(pending.duplicate(true))
    next.resize(mini(next.size(),MAX_HISTORY))
    if not store.write({"history":next}):return false
    history=next;pending={}
    return true

func best(id: String) -> float:
    var result:=INF
    for record in history:
        if record.course==id and record.complete:result=minf(result,float(record.seconds))
    return result

func progress() -> String:
    if not pending.is_empty():return "记录待写入："+String(pending.reason)+"。可重试保存；没有成长奖励。"
    if active.is_empty():return "尚未开始课程；在练习架附近选择一项。"
    var stage: Dictionary=active.course.stages[active.stage]
    return "%s · 第%d/%d步：%s %d/%d · %.1f秒" % [String(active.course.title),int(active.stage)+1,active.course.stages.size(),String(stage.label),int(active.count),int(stage.count),float(active.seconds)]
