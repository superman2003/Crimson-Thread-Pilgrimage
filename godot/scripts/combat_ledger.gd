extends RefCounted
const LIMIT := 20
const EVENT_LIMIT := 60
const COUNTERS := ["hits","outgoing","incoming","guards","perfect","kills","boss_kills","heals","interruptions","casts","energy_in","energy_out"]
var history: Array=[]
var active: Dictionary={}
var pending: Dictionary={}
var store:=preload("res://scripts/journey_desk_store.gd").new()

func configure(journey: String) -> void:
    store.configure("combat_ledger",journey)
    var raw:=store.read()
    history=[]
    if raw.get("history") is Array:
        for record in raw.history.slice(0,LIMIT):
            var clean:=sanitize(record)
            if not clean.is_empty():history.append(clean)

static func number(value: Variant, maximum: float=1000000.0) -> bool:
    return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)>=0.0 and float(value)<=maximum

static func sanitize(raw: Variant) -> Dictionary:
    if not raw is Dictionary or not raw.get("region") is String or not raw.get("title") is String or not raw.get("crest") is String or not number(raw.get("seconds"),86400.0):return {}
    var result: Dictionary={"region":String(raw.region).left(80),"title":String(raw.title).left(80),"crest":String(raw.crest).left(40),"seconds":float(raw.seconds),"reason":String(raw.get("reason","")).left(60),"date":String(raw.get("date","")).left(40),"events":[]}
    for counter in COUNTERS:
        var value: Variant=raw.get(counter,0)
        if not number(value) or float(value)!=floor(float(value)):return {}
        result[counter]=int(value)
    if raw.get("events") is Array:
        for event in raw.events.slice(-EVENT_LIMIT):
            if event is Dictionary and number(event.get("at"),86400.0) and event.get("text") is String:result.events.append({"at":float(event.at),"text":String(event.text).left(120)})
    return result

func start(region: String,title: String,crest: String) -> Dictionary:
    if not active.is_empty() or not pending.is_empty():return {"ok":false,"reason":"先结束当前观察或保存待写记录。"}
    if not store.writable:return {"ok":false,"reason":store.error}
    active={"region":region,"title":title,"crest":crest,"date":Time.get_datetime_string_from_system(),"seconds":0.0,"events":[],"reason":""}
    for counter in COUNTERS:active[counter]=0
    event("观察开始；只记录实际接受的战斗事件。")
    return {"ok":true}

func tick(delta: float) -> void:
    if not active.is_empty() and number(delta,60.0):active.seconds=minf(86400.0,float(active.seconds)+delta)

func event(text: String) -> void:
    if active.is_empty():return
    active.events.append({"at":float(active.seconds),"text":text.left(120)})
    while active.events.size()>EVENT_LIMIT:active.events.pop_front()

func count(key: String, amount: int=1) -> void:
    if active.is_empty() or key not in COUNTERS or amount<0:return
    active[key]=mini(1000000,int(active[key])+amount)

func contact(data: Dictionary) -> void:
    if active.is_empty():return
    match String(data.get("kind","")):
        "strike":
            if data.get("practice",false)==true:return
            if not number(data.get("damage")) or float(data.damage)!=floor(float(data.damage)) or float(data.damage)<=0.0:return
            count("hits");count("outgoing",int(data.damage))
            if data.get("killed",false)==true:
                count("kills")
                if data.get("boss",false)==true:count("boss_kills")
            event("针击命中，实际伤害 %d%s" % [int(data.damage),"，击倒" if data.get("killed",false)==true else ""])
        "hurt":
            if not number(data.get("damage")) or float(data.damage)!=floor(float(data.damage)) or float(data.damage)<=0.0:return
            count("incoming",int(data.damage));event("实际承伤 %d" % int(data.damage))
            if data.get("lethal",false)==true:finish("倒下")
        "guard":count("guards");count("perfect",1 if data.get("perfect",false)==true else 0);event("及时格挡" if data.get("perfect",false)==true else "格挡成功")

func energy(previous: int, current: int) -> void:
    if active.is_empty():return
    var difference:=current-previous
    count("energy_in" if difference>=0 else "energy_out",absi(difference))

func heal(state: String) -> void:
    if state=="completed":count("heals");event("疗伤完成")
    elif state=="interrupted":count("interruptions");event("疗伤中断")

func cast(id: String) -> void:
    count("casts");event("线术施放："+id.left(40))

func finish(reason: String) -> bool:
    if active.is_empty():return pending.is_empty()
    active.reason=reason.left(60);event("观察结束："+reason)
    pending=sanitize(active);active={}
    return retry()

func retry() -> bool:
    if pending.is_empty():return true
    var candidate:=history.duplicate(true);candidate.push_front(pending.duplicate(true));candidate.resize(mini(candidate.size(),LIMIT))
    while candidate.size()>1 and JSON.stringify({"history":candidate}).to_utf8_buffer().size()>store.MAX_BYTES-128:candidate.pop_back()
    if not store.write({"history":candidate}):return false
    history=candidate;pending={}
    return true

static func report(record: Dictionary, previous: Dictionary={}) -> String:
    var lines: Array[String]=["%s · %s" % [String(record.get("title","")),String(record.get("date",""))],"契印 %s · 有效观察 %.1f秒 · %s" % [String(record.get("crest","")),float(record.get("seconds",0)),String(record.get("reason","进行中"))],
        "针击命中 %d / 实际伤害 %d / 实际承伤 %d" % [int(record.get("hits",0)),int(record.get("outgoing",0)),int(record.get("incoming",0))],
        "击倒 %d（首领%d）/ 格挡 %d（及时%d）" % [int(record.get("kills",0)),int(record.get("boss_kills",0)),int(record.get("guards",0)),int(record.get("perfect",0))],
        "线术 %d / 疗伤完成 %d / 中断 %d" % [int(record.get("casts",0)),int(record.get("heals",0)),int(record.get("interruptions",0))],
        "绯线流入 %d / 流出 %d（包括观察期间的休整与退款）" % [int(record.get("energy_in",0)),int(record.get("energy_out",0))]]
    if not previous.is_empty():lines.append("\n与较早所选记录比较：承伤 %+d，针击伤害 %+d，疗伤中断 %+d。" % [int(record.incoming)-int(previous.incoming),int(record.outgoing)-int(previous.outgoing),int(record.interruptions)-int(previous.interruptions)])
    lines.append("\n最近%d条事件；针击伤害只包含直接针击的有效命中，不等于所有战具与持续效果总伤害。" % record.get("events",[]).size())
    for event in record.get("events",[]):lines.append("%.1fs  %s" % [float(event.at),String(event.text)])
    return "\n".join(lines)
