extends RefCounted
## Optional, evidence-led questions. Reading these never advances a quest.
const DIRECTORY := "res://data/inquiries"
const PREFIX := "narrative_inquiry_"
const MAX_FILES := 16
const MAX_ENTRIES := 256
const MAX_LINES := 8
static var _catalog: Array[Dictionary] = []

static func held(value: Variant) -> bool:
    if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
        return false
    var count := float(value)
    return is_finite(count) and count > 0 and count <= 1000000 and count == floor(count)

static func true_flag(flags: Dictionary, id: String) -> bool:
    return flags.get(id) is bool and flags[id]

static func valid_source(value: Variant) -> bool:
    if not value is Dictionary or value.size() != 3:
        return false
    return value.get("kind") in ["item", "flag", "history"] and value.get("id") is String and not String(value.id).is_empty() and value.get("label") is String and not String(value.label).strip_edges().is_empty()

static func valid_sources(value: Variant) -> bool:
    if not value is Array or value.is_empty() or value.size() > 6:
        return false
    for source in value:
        if not valid_source(source):
            return false
    return true

static func valid_lines(value: Variant) -> bool:
    if not value is Array or value.size() < 2 or value.size() > MAX_LINES:
        return false
    for line in value:
        if not line is String or String(line).strip_edges().is_empty() or String(line).length() > 360:
            return false
    return true

static func valid_entry(value: Variant) -> bool:
    if not value is Dictionary:
        return false
    for field in ["id", "npc", "question", "reflection"]:
        if not value.get(field) is String or String(value[field]).strip_edges().is_empty():
            return false
    if String(value.id).length() > 80 or String(value.question).length() > 48 or String(value.reflection).length() > 160:
        return false
    if not valid_sources(value.get("requires")) or not valid_lines(value.get("lines")):
        return false
    if value.has("continuation"):
        var extra: Variant = value.continuation
        if not extra is Dictionary or not valid_sources(extra.get("requires")) or not valid_lines(extra.get("lines")):
            return false
        if value.lines.size() + extra.lines.size() > MAX_LINES:
            return false
    return true

static func catalog() -> Array[Dictionary]:
    if not _catalog.is_empty():
        return _catalog.duplicate(true)
    if not DirAccess.dir_exists_absolute(DIRECTORY):
        return []
    var files := DirAccess.get_files_at(DIRECTORY)
    files.sort()
    var file_count := 0
    var seen: Dictionary = {}
    for file in files:
        if not file.ends_with(".json"):
            continue
        file_count += 1
        if file_count > MAX_FILES:
            break
        var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY + "/" + file))
        if not parsed is Dictionary or parsed.get("version") != 1 or not parsed.get("entries") is Array:
            continue
        for entry in parsed.entries:
            if _catalog.size() >= MAX_ENTRIES:
                break
            if not valid_entry(entry) or seen.has(entry.id):
                continue
            seen[entry.id] = true
            _catalog.append(entry.duplicate(true))
    return _catalog.duplicate(true)

static func source_met(source: Dictionary, inventory: Dictionary, flags: Dictionary) -> bool:
    if not valid_source(source):
        return false
    match String(source.kind):
        "item":
            return held(inventory.get(source.id, 0))
        "history":
            return true_flag(flags, "scene_history_" + String(source.id))
        "flag":
            # Resolve legacy ending conflicts through the production authority.
            if String(source.id).begins_with("ending_"):
                var checked := flags.duplicate(true)
                for ending in ["ending_a_done", "ending_b_done", "ending_c_done"]:
                    if not checked.get(ending) is bool:
                        checked.erase(ending)
                var restored: Dictionary = preload("res://scripts/world_narrative.gd").new().restored_ending_flags(checked)
                return true_flag(restored, String(source.id))
            return true_flag(flags, String(source.id))
    return false

static func sources_met(sources: Array, inventory: Dictionary, flags: Dictionary) -> bool:
    if not valid_sources(sources):
        return false
    for source in sources:
        if not source_met(source, inventory, flags):
            return false
    return true

static func quote(entry: Dictionary, inventory: Dictionary, flags: Dictionary) -> Dictionary:
    if not valid_entry(entry) or not sources_met(entry.requires, inventory, flags):
        return {}
    var lines: Array = entry.lines.duplicate()
    var sources: Array = entry.requires.duplicate(true)
    var expanded := entry.has("continuation") and sources_met(entry.continuation.requires, inventory, flags)
    if expanded:
        lines.append_array(entry.continuation.lines)
        sources.append_array(entry.continuation.requires)
    var result := {"id": entry.id, "npc": entry.npc, "question": entry.question,
        "lines": lines, "reflection": entry.reflection, "sources": sources, "expanded": expanded}
    # Include exactly the visible version; a later discovery asks for rereading.
    result["fingerprint"] = JSON.stringify([result.id, result.npc, result.question, lines, result.reflection, sources]).sha256_text()
    result["marker"] = PREFIX + String(result.fingerprint)
    result["recorded"] = true_flag(flags, result.marker)
    return result

static func available(npc: String, inventory: Dictionary, flags: Dictionary) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for entry in catalog():
        if entry.npc != npc:
            continue
        var row := quote(entry, inventory, flags)
        if not row.is_empty():
            result.append(row)
    return result

static func find(id: String) -> Dictionary:
    for entry in catalog():
        if entry.id == id:
            return entry
    return {}

static func records(flags: Dictionary) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    # Reconstruct only versions actually confirmed. Current possession is not
    # needed for a durable memory, and a new source cannot rewrite an old one.
    for entry in catalog():
        var versions: Array[Dictionary] = [entry.duplicate(true)]
        versions[0].erase("continuation")
        if entry.has("continuation"):
            var expanded: Dictionary = entry.duplicate(true)
            expanded.lines.append_array(entry.continuation.lines)
            expanded.requires.append_array(entry.continuation.requires)
            expanded.erase("continuation")
            versions.append(expanded)
        for version in versions:
            var inventory: Dictionary = {}
            var earned: Dictionary = {}
            for source in version.requires:
                if source.kind == "item":
                    inventory[source.id] = 1
                elif source.kind == "history":
                    earned["scene_history_" + String(source.id)] = true
                else:
                    earned[source.id] = true
            var row := quote(version, inventory, earned)
            if row.is_empty() or not true_flag(flags, row.marker):
                continue
            var labels: Array[String] = []
            for source in row.sources:
                labels.append(String(source.label))
            var text := "我问：%s\n\n%s\n\n巡礼者手记：%s\n\n当时核对的线索：%s" % [row.question, "\n\n".join(row.lines), row.reflection, "、".join(labels)]
            result.append({"id": row.marker, "title": "追问 · " + String(row.question),
                "record_kind": "people", "acquired": true, "description": text, "places": []})
    return result

static func can_talk(ui: Node, area: Area2D) -> bool:
    if not is_instance_valid(ui) or not is_instance_valid(area) or area.is_queued_for_deletion() or not area.is_inside_tree() or not area.is_visible_in_tree():
        return false
    var level: Node = ui.get("level")
    if not is_instance_valid(level) or not bool(level.get("world_mode")) or bool(level.get("world_loading")):
        return false
    if ui.get("dialogue_area") != area or level.get("active_overlay") != "dialogue":
        return false
    var dialogue: CanvasItem = ui.get("dialogue")
    if not is_instance_valid(dialogue) or not dialogue.is_visible_in_tree():
        return false
    var player: Node2D = level.get("player")
    if level.get("ui_shell") != ui or not is_instance_valid(player) or int(player.get("hp")) <= 0 or level.get("world_state") == null:
        return false
    if area.get_world_2d() != player.get_world_2d():
        return false
    return is_instance_valid(player) and player.global_position.distance_to(area.global_position) <= float(level.INTERACTION_REACH) and String(area.get_meta("kind", "")) == "npc"

static func commit(ui: Node, area: Area2D, id: String, fingerprint: String, displayed_index: int) -> Dictionary:
    if not can_talk(ui, area):
        return {"ok": false, "reason": "交谈已经结束，请回到人物身边。"}
    var level: Node = ui.get("level")
    var row := quote(find(id), level.inventory_counts, level.story_flags)
    if row.is_empty() or row.npc != String(area.get_meta("npc_id", "")):
        return {"ok": false, "reason": "线索条件已经变化，请重新选择问题。"}
    if row.fingerprint != fingerprint or displayed_index != row.lines.size() - 1:
        return {"ok": false, "reason": "请读完当前线索对应的回答，再记下追问。"}
    if row.recorded:
        return {"ok": true, "repeated": true}
    var before: Dictionary = level.story_flags.duplicate(true)
    var world_before: Dictionary = level.world_state.data.duplicate(true)
    level.story_flags[row.marker] = true
    if not level._save_world():
        level.story_flags = before
        level.world_state.data = world_before
        return {"ok": false, "reason": "追问尚未写入旅记；可以重试，或先离开。"}
    return {"ok": true, "repeated": false}
