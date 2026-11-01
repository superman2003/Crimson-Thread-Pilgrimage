extends RefCounted
## Display semantics only. Never grants abilities or changes traversal rules.
const PATH := "res://data/permanent_ability_roles.json"
const IDS := ["thread_dash","silk_wall_grip","echo_hook","double_thread_jump","bell_guard","thorn_downstrike","lantern_phase","crown_resonance"]
const KINDS := {"exploration":"移动探索","combat":"战斗技巧","ritual":"共鸣仪式"}
static var _data: Dictionary={}

static func valid(data: Variant) -> bool:
    if not data is Dictionary or typeof(data.get("version")) not in [TYPE_INT,TYPE_FLOAT] or data.get("version")!=1 or data.get("kinds")!=KINDS:return false
    if not data.get("abilities") is Dictionary or data.abilities.size()!=IDS.size():return false
    for id in IDS:
        var row: Variant=data.abilities.get(id)
        if not row is Dictionary or not KINDS.has(row.get("kind")):return false
        for field in ["title","scope","role","limits"]:
            if not row.get(field) is String or String(row[field]).strip_edges().is_empty() or String(row[field]).length()>240:return false
        if row.get("ownership")!="permanent" or not row.get("equipment_required") is bool or row.equipment_required:return false
        if not row.get("interactions") is Array or row.interactions.is_empty() or row.interactions.size()>4:return false
        for value in row.interactions:
            if not value is String or value.is_empty() or value.length()>80:return false
    return true

static func catalog() -> Dictionary:
    if _data.is_empty() and FileAccess.file_exists(PATH):
        var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(PATH))
        if valid(parsed):_data=parsed
    return _data.duplicate(true)

static func owns(inventory: Dictionary, id: String) -> bool:
    var amount: Variant=inventory.get(id,0)
    return id in IDS and typeof(amount) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(amount)) and float(amount)>0.0 and float(amount)<=1000000.0 and float(amount)==floor(float(amount))

static func annotate(entry: Dictionary, id: String, inventory: Dictionary) -> Dictionary:
    var result:=entry.duplicate(true)
    if not owns(inventory,id):return {}
    var data:=catalog()
    if data.is_empty():return result
    var role: Dictionary=data.abilities[id]
    result["ability_id"]=id
    result["ability_kind"]=role.kind
    result["ability_role"]=role.role
    result["ability_interactions"]=role.interactions.duplicate()
    result["permanent"]=true
    # Keep original dynamically rebound controls. The reader/search sees the
    # category in plain text; hidden abilities are never added to public notes.
    result["description"]="%s · 永久取得，无需装备铭饰\n%s\n适用：%s\n边界：%s\n\n%s" % [KINDS[role.kind],role.role," / ".join(role.interactions),role.limits,String(entry.get("description",""))]
    return result

static func is_ability(entry: Dictionary) -> bool:
    if entry.get("record_kind")!="guide" or not entry.get("permanent") is bool or not entry.permanent or entry.get("ability_id") not in IDS:return false
    var data:=catalog()
    return not data.is_empty() and entry.get("ability_kind")==data.abilities[entry.ability_id].kind

static func select(records: Array, filter: String) -> Array:
    if filter!="ability":return records.filter(func(entry):return entry is Dictionary and (filter=="all" or String(entry.get("record_kind",""))==filter))
    return records.filter(func(entry):return entry is Dictionary and is_ability(entry))

static func label(entry: Dictionary) -> String:
    return String(KINDS.get(entry.get("ability_kind",""),"永久能力")) if is_ability(entry) else ""
