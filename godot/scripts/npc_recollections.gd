extends RefCounted
## Recollections only become public after a full, durable conversation commit.
## Save flags contain identities; dialogue text and scene nodes are not saved.
const NARRATIVE := preload("res://scripts/world_narrative.gd")
const REGIONS := preload("res://scripts/save_inspector.gd").REGION_NAMES
const PREFIX := "npc_recollection_"
const MAX_NPCS := 64
const MAX_STATES := 16
const MAX_LINES := 16
static var _catalog: Dictionary={}

static func catalog() -> Dictionary:
    if not _catalog.is_empty():return _catalog.duplicate(true)
    var narrative:=NARRATIVE.new()
    for npc_id in narrative.entries:
        if _catalog.size()>=MAX_NPCS:break
        var npc: Dictionary=narrative.entries[npc_id]
        if not npc.get("display_name") is String or String(npc.display_name).is_empty():continue
        var states: Array=[]
        for value in npc.get("states",[]):
            if states.size()>=MAX_STATES:break
            if not value is Dictionary or not value.get("id") is String or not value.get("lines") is Array:continue
            if value.lines.is_empty() or value.lines.size()>MAX_LINES:continue
            var valid:=true
            for line in value.lines:
                if not line is String or line.is_empty() or line.length()>1000:valid=false
            if valid:states.append({"id":String(value.id),"lines":value.lines.duplicate()})
        if not states.is_empty():_catalog[npc_id]={"name":String(npc.display_name),"states":states}
    # The production resolver falls back to chapter dialogue when no world
    # narrative state applies. Those authored conversations are equally heard.
    for region in REGIONS:
        var data: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/"+String(region)+".json"))
        if not data is Dictionary:continue
        for npc in data.get("npcs",[]):
            if not npc is Dictionary:continue
            var npc_id:=String(npc.get("id",""))
            if npc_id.is_empty():continue
            if not _catalog.has(npc_id):
                if _catalog.size()>=MAX_NPCS:continue
                _catalog[npc_id]={"name":String(npc.get("name",npc_id)),"states":[]}
            var states: Array=_catalog[npc_id].states
            var variants: Dictionary={"fallback":npc.get("dialogue",[])}
            for state in npc.get("story_dialogue",{}):variants[String(state)]=npc.story_dialogue[state]
            for state in variants:
                var lines: Variant=variants[state]
                if not lines is Array or lines.is_empty() or lines.size()>MAX_LINES:continue
                var valid:=true
                for line in lines:
                    if not line is String or line.is_empty() or line.length()>1000:valid=false
                if valid and states.size()<MAX_STATES:states.append({"id":local_state(String(region),String(state)),"lines":lines.duplicate(),"region":String(region)})
    return _catalog.duplicate(true)

static func local_state(region: String, state: String) -> String:
    return "local:"+region+":"+state

static func resolved_result(npc_id: String, world_result: Dictionary, state: String, lines: Array, region: String) -> Dictionary:
    if not world_result.is_empty():return world_result.duplicate(true)
    var all:=catalog()
    if not all.has(npc_id):return {}
    # The legacy resolver may substitute its dialogue array for an empty state.
    for id in [local_state(region,state),local_state(region,"fallback")]:
        for value in all[npc_id].states:
            if value.id==id and value.lines==lines:return {"state":id,"lines":lines.duplicate()}
    return {}

static func identity(npc_id: String, state: Dictionary, region: String) -> String:
    return PREFIX+JSON.stringify([npc_id,state.id,state.lines,region]).sha256_text()

static func completion_marker(npc_id: String, result: Dictionary, displayed_index: int, region: String) -> String:
    if not REGIONS.has(region):return ""
    var all:=catalog()
    if not all.has(npc_id):return ""
    for state in all[npc_id].states:
        if state.has("region") and state.region!=region:continue
        if result.get("state")!=state.id or result.get("lines")!=state.lines:continue
        if displayed_index!=state.lines.size()-1:return ""
        return identity(npc_id,state,region)
    return ""

static func records(flags: Dictionary) -> Array[Dictionary]:
    var result: Array[Dictionary]=[]
    var all:=catalog()
    for npc_id in all:
        var npc: Dictionary=all[npc_id]
        var sections: Array[String]=[]
        var places: Array[String]=[]
        var conversations:=0
        for state in npc.states:
            for region in REGIONS:
                if state.has("region") and state.region!=region:continue
                var value: Variant=flags.get(identity(npc_id,state,region),false)
                if not value is bool or not value:continue
                conversations+=1
                var place:=String(REGIONS[region])
                if not places.has(place):places.append(place)
                sections.append("在%s交谈\n%s" % [place,"\n".join(state.lines)])
        if sections.is_empty():continue
        result.append({"id":PREFIX+String(npc_id).sha256_text(),"record_kind":"people","acquired":true,
            "title":String(npc.name),"description":"与你交谈过的话\n\n"+"\n\n——\n\n".join(sections),
            "places":places,"conversations":conversations})
    return result
