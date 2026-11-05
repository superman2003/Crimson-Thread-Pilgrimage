extends RefCounted
## A read-only overview of accepted promises after the canonical ending.
const PATH := "res://data/ending_return_journal.json"
const CONTACTS := preload("res://scripts/quest_contacts.gd")
const ENDINGS := ["ending_a", "ending_b", "ending_c"]
const LABELS := {"active": "约定还在继续", "reward": "先核对原委托报酬", "confirm": "可回去确认近况", "ready": "有新的重逢可听", "seen": "这次重逢已确认"}
static var _data: Dictionary = {}

static func valid(data: Variant) -> bool:
    if not data is Dictionary or data.size() != 2 or typeof(data.get("version")) not in [TYPE_INT, TYPE_FLOAT] or data.version != 1:
        return false
    if not data.get("quests") is Dictionary or data.quests.size() != CONTACTS.IDS.size():
        return false
    for id in CONTACTS.IDS:
        var row: Variant = data.quests.get(id)
        if not row is Dictionary or row.size() != ENDINGS.size():
            return false
        for ending in ENDINGS:
            var context: Variant = row.get(ending)
            if not context is Dictionary or context.size() != 2:
                return false
            for field in ["active", "reunion"]:
                var value: Variant = context.get(field)
                if not value is String or value.strip_edges().is_empty() or value.length() > 100 or value.contains("\n"):
                    return false
    return true

static func catalog() -> Dictionary:
    if _data.is_empty() and FileAccess.file_exists(PATH):
        var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
        if valid(parsed):
            _data = parsed
    return _data.duplicate(true)

static func rows(inventory: Dictionary, flags: Dictionary) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var data := catalog()
    if data.is_empty():
        return result
    var narrative := CONTACTS.narrative()
    var clean: Dictionary = narrative.restored_ending_flags(CONTACTS.confirmed_flags(flags))
    var ending := String(clean.get("ending_chosen", ""))
    if ending not in ENDINGS:
        return result
    var held := CONTACTS.confirmed_inventory(inventory)
    for quest in narrative.quest_journal(held, clean):
        var id := String(quest.id)
        if not data.quests.has(id):
            continue
        var contact := CONTACTS.for_quest(id, held, clean)
        if contact.is_empty():
            continue
        var stage := "active"
        var guidance := String(contact.label)
        if quest.status == "complete":
            stage = "reward" if not quest.reward_claimed else "confirm"
            if quest.reward_claimed:
                # Metadata identifies the existing authored conversation. Its
                # actual resolver, including remaining unlocks, decides readiness.
                for state in narrative.entries[contact.npc].states:
                    if state.get("quest_coda") != id or state.get("ending") != ending:
                        continue
                    var prerequisites := true
                    for flag in state.get("flags_all", []):
                        prerequisites = prerequisites and clean.get(String(flag), false) == true
                    if not prerequisites:
                        break
                    if clean.get(String(state.grant_flags[0]), false) == true:
                        stage = "seen"
                    elif narrative.resolve(String(contact.npc), [], held.keys(), clean, held).state == state.id:
                        stage = "ready"
                    break
            guidance = "原报酬只领取一次；可以主动交谈。" if stage == "reward" else "可以自由选择是否回访；这不会重选结局。"
        var context: Dictionary = data.quests[id][ending]
        result.append({"id": id, "title": String(quest.title), "stage": stage, "label": LABELS[stage],
            "name": String(contact.name), "place": String(contact.place), "guidance": guidance,
            "context": String(context.active if stage == "active" else context.reunion), "source_key": "quest:" + id})
    return result

static func records(inventory: Dictionary, flags: Dictionary) -> Array[Dictionary]:
    var known := rows(inventory, flags)
    if known.is_empty():
        return []
    var lines: Array[String] = ["这些是已知的可选委托；回访不会改变已经选定的结局。"]
    var sources: Array[String] = []
    for row in known:
        sources.append(String(row.source_key))
        lines.append("\n%s · %s\n%s\n%s\n%s" % [row.title, row.label, row.context, row.place, row.guidance])
        if not String(row.name).is_empty():
            lines.append("联系谁：" + String(row.name))
    return [{"id": "ending_return_contacts", "title": "结局之后，还在等你的事", "record_kind": "guide",
        "guide_context": "结局之后 · 可选回访", "description": "\n".join(lines), "journal_source_keys": sources}]
