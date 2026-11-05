extends RefCounted
## Public next-step context. The canonical quest evaluator remains authoritative.
const PATH := "res://data/quest_contacts.json"
const NARRATIVE := preload("res://scripts/world_narrative.gd")
const REGIONS := preload("res://scripts/save_inspector.gd").REGION_NAMES
const IDS := ["bring_names_home", "root_rescue", "wax_lamps", "lantern_watch", "deserter_order"]
static var _data: Dictionary = {}
static var _narrative: RefCounted

static func narrative() -> RefCounted:
    if _narrative == null:
        _narrative = NARRATIVE.new()
    return _narrative

static func valid(data: Variant) -> bool:
    if not data is Dictionary or typeof(data.get("version")) not in [TYPE_INT, TYPE_FLOAT] or data.version != 1:
        return false
    for key in ["homes", "places", "acquisitions", "quests"]:
        if not data.get(key) is Dictionary or data[key].is_empty():
            return false
    if data.quests.size() != IDS.size():
        return false
    for id in IDS:
        var row: Variant = data.quests.get(id)
        if not row is Dictionary or not data.homes.has(row.get("return_to")):
            return false
        if not row.get("completed_reason") is String or row.completed_reason.is_empty():
            return false
        if not row.get("steps") is Array or row.steps.is_empty() or row.steps.size() > 4:
            return false
        for step in row.steps:
            if not step is Dictionary or not step.get("why") is String or step.why.is_empty() or step.why.length() > 160:
                return false
            var kinds := int(step.has("npc")) + int(step.has("room")) + int(step.has("ability"))
            if kinds != 1:
                return false
            if step.has("npc") and not data.homes.has(step.npc):
                return false
            if step.has("room") and not data.places.has(String(step.get("region", "")) + ":" + String(step.room)):
                return false
            if step.has("ability") and not data.acquisitions.has(step.ability):
                return false
    return true

static func catalog() -> Dictionary:
    if _data.is_empty() and FileAccess.file_exists(PATH):
        var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
        if valid(parsed):
            _data = parsed
    return _data.duplicate(true)

static func confirmed_flags(flags: Dictionary) -> Dictionary:
    var result := {}
    for key in flags:
        var value: Variant = flags[key]
        if value is bool and value:
            result[key] = true
    if flags.get("ending_chosen") in ["ending_a", "ending_b", "ending_c"]:
        result["ending_chosen"] = flags.ending_chosen
    return result

static func confirmed_inventory(inventory: Dictionary) -> Dictionary:
    var result := {}
    for key in inventory:
        var value: Variant = inventory[key]
        if typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) \
                and float(value) > 0.0 and float(value) <= 1000000.0 and float(value) == floor(float(value)):
            result[key] = value
    return result

static func _location(target: Dictionary, flags: Dictionary, data: Dictionary) -> Dictionary:
    var region := String(target.get("region", ""))
    var room := String(target.get("room", ""))
    var name := ""
    if target.has("npc"):
        var npc := String(target.npc)
        if not narrative().entries.has(npc) or not data.homes.has(npc):
            return {}
        var home: Dictionary = data.homes[npc]
        var state: Dictionary = narrative().npc_world_state(npc, flags)
        if state.has("visible") and state.visible is bool and not state.visible:
            return {}
        region = String(state.get("region", home.region))
        if not region.begins_with("demo_"):
            region = "demo_" + region
        room = String(state.get("room", home.room))
        name = String(narrative().entries[npc].display_name)
    elif target.has("ability"):
        var plan: Dictionary = data.acquisitions.get(String(target.ability), {})
        region = String(plan.get("region_id", ""))
        room = String(plan.get("room_id", ""))
    var key := region + ":" + room
    if not REGIONS.has(region) or not data.places.has(key):
        return {}
    return {"npc": String(target.get("npc", "")), "name": name,
        "region": region, "room": room, "place": String(REGIONS[region]) + " · " + String(data.places[key])}

static func for_quest(id: String, inventory: Dictionary, flags: Dictionary) -> Dictionary:
    var data := catalog()
    if not data.get("quests", {}).has(id):
        return {}
    var confirmed := confirmed_flags(flags)
    var known: Dictionary = {}
    for row in narrative().quest_journal(confirmed_inventory(inventory), confirmed):
        if row.id == id:
            known = row
            break
    if known.is_empty():
        return {}
    var template: Dictionary = data.quests[id]
    var target: Dictionary
    var why := ""
    var phase := "next"
    var step_index := -1
    if known.status == "complete":
        target = {"npc": template.return_to}
        phase = "reunion" if known.reward_claimed else "reward"
        why = String(template.completed_reason)
    else:
        if known.steps.size() != template.steps.size():
            return {}
        for index in known.steps.size():
            if not known.steps[index].complete:
                step_index = index
                target = template.steps[index]
                why = String(target.why)
                break
        if step_index < 0:
            return {}
    var location := _location(target, confirmed, data)
    if location.is_empty():
        return {}
    location.merge({"phase": phase, "step": step_index, "why": why,
        "label": String(known.steps[step_index].label) if step_index >= 0 else "重逢" if phase == "reunion" else "核对尚未领取的奖励"})
    return location

static func appendix(id: String, inventory: Dictionary, flags: Dictionary) -> Array[String]:
    var context := for_quest(id, inventory, flags)
    var lines: Array[String] = []
    if context.is_empty():
        return lines
    lines.append("\n接下来 · " + String(context.label))
    if not String(context.name).is_empty():
        lines.append("联系谁：" + String(context.name))
    lines.append("当前去处：" + String(context.place))
    lines.append(String(context.why))
    return lines
