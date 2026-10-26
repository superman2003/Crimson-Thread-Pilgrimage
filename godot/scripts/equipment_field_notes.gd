extends RefCounted
## A read-only manual for starting equipment and physically owned relics.
const PATH := "res://data/equipment_field_notes.json"
const CATALOG_PATH := "res://data/build_catalog.json"
static var notes: Array = []
static var catalog: Dictionary = {}

static func owns(value: Variant) -> bool:
    return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)>0.0 and float(value)<=1000000.0 and floor(float(value))==float(value)

static func records(inventory: Dictionary, bindings: Dictionary) -> Array[Dictionary]:
    if catalog.is_empty():
        var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
        if data is Dictionary:catalog=data
    if notes.is_empty():
        var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(PATH))
        if data is Dictionary and data.get("entries") is Array:notes=data.entries
    var result: Array[Dictionary]=[]
    var seen: Dictionary={}
    for note in notes:
        if not note is Dictionary:continue
        var table:=String(note.get("table",""))
        var id:=String(note.get("id",""))
        var key:=table+":"+id
        if table not in ["skills","tools"] or seen.has(key):continue
        var entries: Variant=catalog.get(table,{})
        if not entries is Dictionary or not entries.get(id) is Dictionary:continue
        var item: Dictionary=entries[id]
        if not ((table=="skills" and id=="cleave") or (table=="tools" and id=="shard") or owns(inventory.get(String(item.get("unlock_item","")),0))):continue
        var text:=String(note.get("text",""))
        if text.is_empty():continue
        var actions: Dictionary={}
        for action in ["skill_1","skill_cycle","tool_cast","tool_cycle","interact"]:actions[action]=String(bindings.get(action,"未设置"))
        var controls: String="{skill_1} 施放 · {skill_cycle} 切换已配线术" if table=="skills" else "{tool_cast} 使用 · {tool_cycle} 切换已配战具"
        var description:=controls.format(actions)+"\n\n"+text+"\n\n"+"在构筑页面查看配置；{interact} 在钟龛调整。实际费用、冷却与余量以当前 HUD 为准。".format(actions)
        result.append({"id":"equipment_guide_"+table+"_"+id,"title":String(item.get("name",id))+" · 使用札记","description":description,"record_kind":"guide","acquired":true})
        seen[key]=true
    return result
