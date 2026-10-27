extends RefCounted
## Authored story synthesis. Reading never grants evidence, quest flags or rewards.
const PATH := "res://data/narrative_journey.json"
static var _data: Dictionary = {}

static func catalog() -> Dictionary:
    if _data.is_empty():
        var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
        if parsed is Dictionary:
            _data = parsed
    return _data.duplicate(true)

static func _matches(row: Dictionary, inventory: Dictionary, flags: Dictionary) -> bool:
    for id in row.get("evidence_all", []):
        var amount: Variant = inventory.get(String(id), 0)
        if typeof(amount) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(amount)) or float(amount) <= 0.0 or float(amount) != floor(float(amount)):
            return false
    for id in row.get("flags_all", []):
        if not flags.get(String(id), false) is bool or not flags.get(String(id), false):
            return false
    return true

static func reflections(inventory: Dictionary, flags: Dictionary) -> Array:
    var rows: Array = []
    for value in catalog().get("reflections", []):
        var row: Dictionary = value
        if _matches(row, inventory, flags):
            rows.append({"id": row.id, "title": row.title, "text": row.text, "question": row.question})
    return rows

static func epilogue(ending: String, flags: Dictionary) -> Array:
    var rows: Array = []
    for value in catalog().get("endings", {}).get(ending, {}).get("scenes", []):
        var row: Dictionary = value
        if _matches(row, {}, flags):
            rows.append({"title": row.title, "text": row.text, "response": row.response})
    return rows

static func decision(ending: String) -> Dictionary:
    return catalog().get("endings", {}).get(ending, {}).get("decision", {}).duplicate(true)

static func goal(inventory: Dictionary, flags: Dictionary) -> String:
    if flags.get("boss_down_ch06", false) == true:
        return "王冠已经停下。回看亲手取得的证词，决定六城今后如何守潮、谁有权拒绝。"
    if _matches({"evidence_all": ["testimony_01", "testimony_03"]}, inventory, flags):
        return "原约只约束自愿献心的人，后嗣却被写了进去。把各城证词带到王冠，问清谁改了约、代价由谁承担。"
    if inventory.get("testimony_03", 0) is int and inventory.get("testimony_03", 0) > 0:
        return "原页上留下了改字的痕迹。寻找其他独立证词，分清守潮与夺走名字之间的关系。"
    if not reflections(inventory, flags).is_empty():
        return "把遇见的人、留下的物件和亲手找到的证词对照起来，追查失声的缘故。"
    return String(catalog().get("opening_goal", "查明哑钟缘故，找到仍在等候的人。"))
