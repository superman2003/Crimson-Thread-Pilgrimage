extends RefCounted
## Short journal reflections derived from earned inventory; never grants flags.
const PATH := "res://data/protagonist_voice.json"
static var _catalogue: Array=[]
static var _combinations: Array=[]

static func catalogue() -> Array:
    if _catalogue.is_empty():
        var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(PATH))
        if data is Dictionary and data.get("entries") is Array:
            _catalogue=data.entries
            _combinations=data.get("combinations",[]) if data.get("combinations",[]) is Array else []
    return _catalogue.duplicate(true)

static func records(inventory: Dictionary) -> Array[Dictionary]:
    var result: Array[Dictionary]=[]
    for entry in catalogue():
        var value: Variant=inventory.get(String(entry.ability),0)
        if typeof(value) not in [TYPE_INT,TYPE_FLOAT]:continue
        var count:=float(value)
        if not is_finite(count) or count<=0.0 or count>1000000.0 or count!=floor(count):continue
        result.append({"id":"voice_"+String(entry.ability),"title":String(entry.title),"description":String(entry.text),"record_kind":"voice","acquired":true})
    for entry in _combinations:
        if not entry is Dictionary or not entry.get("id") is String or not entry.get("requires") is Array or entry.requires.size()<2:continue
        var acquired:=true
        for ability in entry.requires:
            if not ability is String or not held(inventory.get(ability,0)):acquired=false;break
        if acquired:result.append({"id":"voice_combo_"+String(entry.id),"title":String(entry.get("title","")),"description":String(entry.get("text","")),"record_kind":"voice","acquired":true})
    return result

static func held(value: Variant) -> bool:
    return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)>0 and float(value)<=1000000 and float(value)==floor(float(value))
