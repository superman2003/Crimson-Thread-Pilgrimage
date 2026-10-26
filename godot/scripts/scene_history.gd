extends RefCounted
## Read-only authored observations. No inventory, ability or ending rewards.
const DATA_PATH := "res://data/scene_history.json"
const FLAG_PREFIX := "scene_history_"
static var _catalog: Array = []
static var _story: Dictionary = {}
static var _craft_notes: Dictionary = {}

static func craft_note(id: String) -> String:
    if _craft_notes.is_empty():
        var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/scene_craft_notes.json"))
        if parsed is Dictionary and parsed.get("entries") is Array:
            for value in parsed.entries:
                if not value is Dictionary or not value.get("history_id") is String:continue
                if not value.get("detail") is String or not value.get("question") is String:continue
                if _craft_notes.has(value.history_id):continue
                _craft_notes[value.history_id]="近看工艺\n"+String(value.detail)+"\n\n巡礼者手记\n"+String(value.question)
    return String(_craft_notes.get(id,""))

static func all_entries() -> Array:
    if _catalog.is_empty():
        var raw: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
        _catalog=raw.get("entries",[])
        _story=JSON.parse_string(FileAccess.get_file_as_string("res://data/world_narrative.json"))
    var result: Array=[]
    for value in _catalog:
        var entry: Dictionary=value.duplicate(true)
        if entry.has("evidence_id"):
            for evidence in _story.get("evidence",[]):
                if String(evidence.id)==String(entry.evidence_id):
                    var witness: Dictionary=evidence.get("scene_witness",{})
                    entry["title"]=String(witness.get("title",""))
                    entry["text"]=String(witness.get("text",""))
                    break
        var note:=craft_note(String(entry.get("id","")))
        if not note.is_empty() and not entry.has("evidence_id"):
            entry["text"]=String(entry.get("text",""))+"\n\n"+note
        result.append(entry)
    return result

static func region_entries(region_id: String) -> Array:
    return all_entries().filter(func(entry):return String(entry.region_id)==region_id)

static func discovered(flags: Dictionary,id: String) -> bool:
    var value: Variant=flags.get(FLAG_PREFIX+id,false)
    return value is bool and value

static func records(flags: Dictionary) -> Array:
    var result: Array=[]
    for entry in all_entries():
        if discovered(flags,String(entry.id)):
            result.append({"id":FLAG_PREFIX+String(entry.id),"title":String(entry.title),"text":String(entry.text),
                "place":String(entry.room_title),"record_kind":"evidence","history_note":true,"acquired":true})
    return result
