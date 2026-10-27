extends RefCounted
## Only a fresh, fully read and saved response earns a memory identity. Existing
## quest flags alone cannot invent words or gestures for an older playthrough.
const NARRATIVE:=preload("res://scripts/world_narrative.gd")
const REGIONS:=preload("res://scripts/save_inspector.gd").REGION_NAMES
const MODES:={"speech":"短回应","gesture":"针线动作","resonance":"共鸣回应"}
const PREFIX:="protagonist_response_"
static var _catalog: Array[Dictionary]=[]

static func catalog() -> Array[Dictionary]:
    if not _catalog.is_empty():return _catalog.duplicate(true)
    var narrative:=NARRATIVE.new()
    for npc in narrative.entries:
        var entry: Dictionary=narrative.entries[npc]
        for state in entry.get("states",[]):
            var text:=String(state.get("response","")).strip_edges()
            var mode:=String(state.get("response_mode","gesture"))
            if text.is_empty() or text.length()>48 or not MODES.has(mode):continue
            var valid:=true
            for index in text.length():
                if text.unicode_at(index)<32 or text.unicode_at(index)==127:valid=false;break
            var result:=narrative._state_result(entry,state,[])
            if not valid or result.lines.is_empty() or NARRATIVE.completion_response(result,result.lines.size()-1,{}).is_empty():continue
            _catalog.append({"npc":String(npc),"name":String(entry.get("display_name",npc)),"result":result,"text":text,"mode":mode})
    return _catalog.duplicate(true)

static func identity(row: Dictionary, region: String) -> String:
    return PREFIX+JSON.stringify([row.npc,row.result.state,row.result.lines,row.text,row.mode,region]).sha256_text()

static func quote(npc: String, result: Dictionary, index: int, flags_before: Dictionary, region: String) -> Dictionary:
    if not REGIONS.has(region) or not result.get("lines") is Array or index!=result.lines.size()-1:return {}
    for row in catalog():
        # Bind the response to the exact production resolver result, including
        # rewards/flags; arbitrary lookalike text cannot create a memory.
        if row.npc!=npc or row.result!=result:continue
        var text:=NARRATIVE.completion_response(result,index,flags_before)
        if text.is_empty():return {}
        var marker:=identity(row,region)
        if flags_before.get(marker) is bool and flags_before[marker]:return {}
        return {"marker":marker,"text":text,"mode":row.mode}
    return {}

static func records(flags: Dictionary) -> Array[Dictionary]:
    var result: Array[Dictionary]=[]
    for row in catalog():
        for region in REGIONS:
            var marker:=identity(row,String(region))
            var earned: Variant=flags.get(marker,false)
            if not earned is bool or not earned:continue
            var mode:=String(MODES[row.mode])
            result.append({"id":marker,"record_kind":"voice","acquired":true,"title":"%s · 向%s" % [mode,row.name],
                "description":"%s · %s\n\n巡礼者 · %s\n\n回应之前，对方说：\n%s" % [String(REGIONS[region]),mode,row.text,String(row.result.lines.back())],
                "response_mode":row.mode,"region":String(region)})
    return result
