extends RefCounted
## Read-only authored observations. No inventory, ability or ending rewards.
const DATA_PATH := "res://data/scene_history.json"
const FLAG_PREFIX := "scene_history_"
static var _catalog: Array = []
static var _story: Dictionary = {}

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
