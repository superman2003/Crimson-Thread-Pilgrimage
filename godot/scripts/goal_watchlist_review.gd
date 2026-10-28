extends RefCounted
## Goal rows are already public journal presentations. Only display step
## labels; never inspect target IDs, conditions, regions or private hints.
static func next_hint(row: Dictionary) -> String:
    if row.get("complete")==true:return "已完成，可在工作台整理追踪。"
    var entry: Dictionary=row.get("entry",{}) if row.get("entry") is Dictionary else {}
    var total:=0
    var completed:=0
    var next:=""
    for step in entry.get("steps",[]):
        if not step is Dictionary or not step.get("label") is String:continue
        total+=1
        if step.get("complete")==true:completed+=1
        elif next.is_empty():next=String(step.label).strip_edges().left(52)
    if not next.is_empty():return "%d/%d · %s" % [completed,total,next]
    var guidance: Variant=entry.get("guidance","")
    return String(guidance).strip_edges().left(64) if guidance is String and not guidance.strip_edges().is_empty() else "打开旅记核对已知线索。"

static func hud_lines(state: Dictionary, known: Array) -> Array[String]:
    var index: Dictionary={}
    for row in known:
        if row is Dictionary and row.get("key") is String:index[row.key]=row
    var lines: Array[String]=[]
    for key in state.get("pins",[]).slice(0,3):
        if not index.has(key):continue
        var row: Dictionary=index[key]
        lines.append(("✓ " if row.get("complete")==true else "○ ")+String(row.get("title","已知目标")).left(28))
        lines.append("  "+next_hint(row))
    return lines

static func quote(state: Dictionary, known: Array) -> Dictionary:
    if not state.get("pins") is Array or not state.get("notes") is Dictionary:return failure("追踪记录暂不可整理。")
    var index: Dictionary={}
    for row in known:
        if row is Dictionary and row.get("key") is String:index[row.key]=row
    var candidate:=state.duplicate(true)
    var retired: Array=[]
    var titles: Array[String]=[]
    for key in state.pins:
        if not index.has(key) or index[key].get("complete")!=true:continue
        retired.append(key);titles.append(String(index[key].get("title","已完成目标")))
        candidate.pins.erase(key);candidate.notes.erase(key)
    if retired.is_empty():return failure("目前没有仍可见且已完成的追踪目标。")
    return {"ok":true,"candidate":candidate,"keys":retired,"titles":titles,"fingerprint":var_to_str([state,retired,titles]).sha256_text(),
        "summary":"从HUD移除以下%d项已完成追踪，并清除这些目标的追踪备注：\n· %s\n剧情、旅记、奖励与未完成追踪不变；之后仍可重新追踪。" % [retired.size(),"\n· ".join(titles)]}

static func apply(model: RefCounted, known: Array, fingerprint: String) -> Dictionary:
    var fresh:=quote(model.state,known)
    if not fresh.ok:return fresh
    if fingerprint!=fresh.fingerprint:return failure("追踪状态或完成目标已变化，请重新核对。")
    if not model.store.write(fresh.candidate):return failure(String(model.store.error))
    model.state=fresh.candidate
    return {"ok":true,"reason":"已整理%d项追踪；任务和奖励记录不变。" % fresh.keys.size()}

static func failure(reason: String) -> Dictionary:return {"ok":false,"reason":reason}
