extends RefCounted
const PATH := "res://data/field_contracts.json"
const LIMIT := 3
static var catalog: Array=[]

static func contracts() -> Array:
    if catalog.is_empty():
        var raw: Variant=JSON.parse_string(FileAccess.get_file_as_string(PATH))
        if raw is Dictionary and raw.get("contracts") is Array:catalog=raw.contracts
    return catalog.duplicate(true)

static func flag(id: String, suffix: String) -> String:
    return "field_contract_"+id+"_"+suffix

static func marked(flags: Dictionary, key: String) -> bool:
    return flags.get(key) is bool and flags[key]

static func known(level: Node, region: String) -> bool:
    return String(level.config.id)==region or level.world_state.data.regions.has(region)

static func observed(level: Node, contract: Dictionary, objective: Dictionary) -> bool:
    if objective.kind=="enemy":return marked(level.story_flags,"journal_enemy_"+String(objective.target))
    var visits: Dictionary=level.visited_rooms if String(level.config.id)==String(contract.region) else level.world_state.get_region(String(contract.region)).visited_rooms
    return marked(visits,String(objective.target))

static func entries(level: Node, accepted_only: bool=false) -> Array:
    var result: Array=[]
    for contract in contracts():
        if not known(level,String(contract.region)):continue
        var accepted:=marked(level.story_flags,flag(String(contract.id),"accepted"))
        var claimed:=marked(level.story_flags,flag(String(contract.id),"claimed"))
        if accepted_only and not accepted:continue
        var steps: Array=[]
        for objective in contract.objectives:
            var done:=observed(level,contract,objective)
            var label:="已记录："+String(objective.label) if done else "巡查尚未记录的公共地点" if objective.kind=="visit" else "击败尚未登记的本区敌人"
            steps.append({"label":label,"complete":done})
        var complete:=steps.all(func(step):return step.complete)
        result.append({"id":"contract_"+String(contract.id),"contract_id":contract.id,"title":contract.title,"description":contract.description,
            "record_kind":"quest","status":"complete" if claimed else "active","reward_claimed":claimed,"steps":steps,
            "guidance":"巡礼印已收入行囊，可用于工匠改制。" if claimed else "回钟龛构筑页确认登记，领取巡礼印。" if complete else "沿本区已知道路继续探索；此前已完成的记录也认可。",
            "accepted":accepted,"claimed":claimed,"ready":complete,"reward_name":contract.reward_name,"region":contract.region})
    return result

static func regions(rows: Array) -> Array[Dictionary]:
    var seen: Dictionary={}
    var result: Array[Dictionary]=[]
    for row in rows:
        var id:=String(row.get("region",""))
        if id.is_empty() or seen.has(id):continue
        seen[id]=true
        result.append({"id":id,"name":String(row.get("title","")).get_slice("·",0)})
    return result

static func browse(rows: Array, query: String, mode: int = 0, region: String = "") -> Array:
    var result: Array=[]
    var tokens:=query.left(80).to_lower().replace("　"," ").replace("\t"," ").replace("\n"," ").split(" ",false)
    for row in rows:
        if not region.is_empty() and row.get("region")!=region:continue
        var accepted:=marked(row,"accepted")
        var claimed:=marked(row,"claimed")
        var ready:=marked(row,"ready")
        if mode==1 and (accepted or claimed):continue
        if mode==2 and (not accepted or claimed):continue
        if mode==3 and not claimed:continue
        if mode==4 and (not accepted or not ready or claimed):continue
        var text:=(String(row.get("title",""))+"\n"+String(row.get("description",""))).to_lower()
        for step in row.get("steps",[]):text+="\n"+String(step.get("label","")).to_lower()
        var matches:=true
        for token in tokens:
            if not text.contains(token):matches=false;break
        if matches:result.append(row.duplicate(true))
    return result

static func quote(level: Node, id: String, action: String) -> Dictionary:
    if not preload("res://scripts/field_transaction.gd").ready(level):return {"ok":false,"reason":"请在钟龛旁打开构筑页。"}
    var canonical: Dictionary={}
    for contract in contracts():
        if contract.id==id and known(level,String(contract.region)):canonical=contract;break
    if canonical.is_empty():return {"ok":false,"reason":"该契约尚不可见。"}
    var accepted:=marked(level.story_flags,flag(id,"accepted"))
    var claimed:=marked(level.story_flags,flag(id,"claimed"))
    var flags: Dictionary=level.story_flags.duplicate(true)
    var counts: Dictionary=level.inventory_counts.duplicate(true)
    var summary:=""
    if action=="accept":
        var active:=0
        for contract in contracts():
            if marked(flags,flag(String(contract.id),"accepted")) and not marked(flags,flag(String(contract.id),"claimed")):active+=1
        if accepted or claimed or active>=LIMIT:return {"ok":false,"reason":"已接取/结算，或三份进行中契约已满。"}
        flags[flag(id,"accepted")]=true;summary="接取「%s」。此前真实探索记录也可登记；最多同时三份。" % String(canonical.title)
    elif action=="cancel":
        if not accepted or claimed:return {"ok":false,"reason":"只有尚未领取回礼的契约可以取消。"}
        flags[flag(id,"accepted")]=false;summary="取消「%s」；探索记录不会被清除，可日后重新接取。" % String(canonical.title)
    elif action=="claim":
        if not accepted or claimed:return {"ok":false,"reason":"先接取契约；已结算的契约不可重复领取。"}
        for objective in canonical.objectives:
            if not observed(level,canonical,objective):return {"ok":false,"reason":"这份契约还有未完成的记录。"}
        var old: Variant=counts.get(canonical.reward_item,0)
        if typeof(old) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(old)) or float(old)<0.0 or float(old)!=floor(float(old)) or float(old)>999998.0:return {"ok":false,"reason":"巡礼印计数无效，未结算。"}
        counts[canonical.reward_item]=int(old)+int(canonical.reward_amount)
        flags[flag(id,"claimed")]=true;summary="登记「%s」，收入%s × %d。不补生命、绯线或战具。" % [String(canonical.title),String(canonical.reward_name),int(canonical.reward_amount)]
    else:return {"ok":false,"reason":"无效契约操作。"}
    return {"ok":true,"counts":counts,"flags":flags,"summary":summary,"fingerprint":var_to_str([id,action,canonical,level.inventory_counts,level.story_flags,level.currency_count,level.build_system.serialize()]).sha256_text()}

static func perform(level: Node,id: String,action: String,fingerprint: String) -> Dictionary:
    var candidate:=quote(level,id,action)
    if not candidate.ok:return candidate
    if fingerprint!=candidate.fingerprint:return {"ok":false,"reason":"契约、库存或构筑已变化，请重新核对。"}
    return preload("res://scripts/field_transaction.gd").commit(level,candidate.counts,candidate.flags,int(level.currency_count))
