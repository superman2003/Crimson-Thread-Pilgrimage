extends SceneTree
const INQUIRIES := preload("res://scripts/narrative_inquiries.gd")
const DESK := preload("res://scripts/narrative_inquiry_desk.gd")
var checks := 0
var failures := 0

class State extends RefCounted:
    var data: Dictionary = {"sentinel": 31}

class Actor extends Node2D:
    var hp := 3

class Level extends Node2D:
    const INTERACTION_REACH := 150.0
    var world_mode := true
    var world_loading := false
    var active_overlay := "dialogue"
    var inventory_counts: Dictionary = {}
    var story_flags: Dictionary = {}
    var world_state := preload("res://scripts/world_state.gd").new()
    var player: Node2D
    var ui_shell: Node
    var writes := 0
    var allow_save := true
    func _save_world() -> bool:
        writes += 1
        if not allow_save:
            world_state.data.story_flags = story_flags.duplicate(true)
            return false
        if not world_state.capture_global({"current_region":"demo_ch01_moss_bell_court", "story_flags":story_flags}):
            return false
        return world_state.write("user://inquiry_transaction.json")

class Shell extends Control:
    var level: Node
    var dialogue: Control
    var dialogue_area: Area2D
    var dialogue_inquiry_button: Button
    var modal_closed_frame := -1

func _initialize() -> void:
    call_deferred("run")

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)

func grant(sources: Array, inventory: Dictionary, flags: Dictionary) -> void:
    for source in sources:
        if source.kind == "item":
            inventory[source.id] = 1
        elif source.kind == "history":
            flags["scene_history_" + String(source.id)] = true
        else:
            flags[source.id] = true

func test_entry(entry: Dictionary) -> void:
    check(INQUIRIES.quote(entry, {}, {}).is_empty(), entry.id + " hidden without sources")
    var inventory: Dictionary = {}
    var flags: Dictionary = {}
    grant(entry.requires, inventory, flags)
    var before := [inventory.duplicate(true), flags.duplicate(true)]
    var row := INQUIRIES.quote(entry, inventory, flags)
    check(not row.is_empty() and row.lines == entry.lines, entry.id + " base answer")
    check(INQUIRIES.records(flags).is_empty(), entry.id + " possession is not a memory")
    check(before == [inventory, flags], entry.id + " quote is pure")
    for source in entry.requires:
        var bad_inventory := inventory.duplicate(true)
        var bad_flags := flags.duplicate(true)
        if source.kind == "item":
            bad_inventory[source.id] = 0
        else:
            bad_flags[("scene_history_" if source.kind == "history" else "") + String(source.id)] = false
        check(INQUIRIES.quote(entry, bad_inventory, bad_flags).is_empty(), entry.id + " each source matters")
    flags[row.marker] = true
    check(INQUIRIES.records(flags).size() == 1, entry.id + " exact base memory")
    if entry.has("continuation"):
        var base_marker: String = row.marker
        grant(entry.continuation.requires, inventory, flags)
        var extra := INQUIRIES.quote(entry, inventory, flags)
        check(extra.lines.size() == entry.lines.size() + entry.continuation.lines.size(), entry.id + " earned continuation")
        check(extra.marker != base_marker and not extra.recorded, entry.id + " expansion needs fresh reading")
        check(INQUIRIES.records(flags).size() == 1, entry.id + " expansion not invented")
        flags[extra.marker] = true
        check(INQUIRIES.records(flags).size() == 2, entry.id + " both heard versions retained")
    row.lines[0] = "changed outside"
    check(INQUIRIES.find(entry.id).lines[0] != row.lines[0], entry.id + " detached result")

func run() -> void:
    var entries := INQUIRIES.catalog()
    check(not entries.is_empty(), "shipped questions loaded")
    var archived := INQUIRIES.archived_catalog()
    check(not archived.is_empty(), "published answers retained for old saves")
    if not archived.is_empty():
        var old_entry: Dictionary = archived[0]
        var old_inventory: Dictionary = {}
        var old_flags: Dictionary = {}
        grant(old_entry.requires, old_inventory, old_flags)
        var old_row := INQUIRIES.quote(old_entry, old_inventory, old_flags)
        check(INQUIRIES.records(old_flags).is_empty(), "possessing old sources invents no archived memory")
        old_flags[old_row.marker] = true
        var old_records := INQUIRIES.records(old_flags)
        check(old_records.size() == 1 and old_records[0].description.contains(old_entry.lines[0]), "old save recovers the exact published answer")
        var active_rows := INQUIRIES.available(old_entry.npc, old_inventory, old_flags)
        check(not active_rows.any(func(value): return value.fingerprint == old_row.fingerprint), "retired answer is absent from active questions")
        check(active_rows.any(func(value): return not value.recorded), "rewritten answer requires its own reading")
        var current := INQUIRIES.quote(INQUIRIES.find(old_entry.id), old_inventory, old_flags)
        old_flags[current.marker] = true
        check(INQUIRIES.records(old_flags).size() == 2, "old and rewritten confirmed versions coexist")
        var detached_archive := INQUIRIES.archived_catalog()
        detached_archive[0].lines[0] = "external mutation"
        check(INQUIRIES.archived_catalog()[0].lines[0] != "external mutation", "archive snapshots are detached")
    for entry in entries:
        test_entry(entry)
    for value in [null, false, true, -1, 0, 0.5, INF, NAN, "1", [], {}, 1000001]:
        check(not INQUIRIES.held(value), "malformed ownership denied")
    check(INQUIRIES.held(1) and INQUIRIES.held(1.0), "positive integral ownership accepted")
    for value in [1, "true", [], {}]:
        check(not INQUIRIES.source_met({"kind":"flag", "id":"boss_down_ch01", "label":"test"}, {}, {"boss_down_ch01":value}), "flags require literal bool")
    for ending in ["ending_a_done", "ending_b_done", "ending_c_done"]:
        for value in [1, "true", []]:
            check(not INQUIRIES.source_met({"kind":"flag", "id":ending, "label":"test"}, {}, {ending:value}), "malformed ending flag is not a choice")
    check(INQUIRIES.quote({"id":"forged"}, {}, {}).is_empty(), "malformed entry denied")
    check(not INQUIRIES.sources_met([], {}, {}), "empty requirements fail closed")
    var conflict := {"ending_a_done":true, "ending_b_done":true}
    check(not INQUIRIES.source_met({"kind":"flag", "id":"ending_a_done", "label":"test"}, {}, conflict), "conflicting legacy endings have no authority")
    var level := Level.new()
    root.add_child(level)
    level.player = Actor.new()
    level.add_child(level.player)
    var ui := Shell.new()
    root.add_child(ui)
    ui.dialogue = Control.new()
    ui.add_child(ui.dialogue)
    ui.level = level
    level.ui_shell = ui
    var area := Area2D.new()
    level.add_child(area)
    area.set_meta("kind", "npc")
    area.set_meta("npc_id", entries[0].npc)
    ui.dialogue_area = area
    grant(entries[0].requires, level.inventory_counts, level.story_flags)
    var row := INQUIRIES.quote(entries[0], level.inventory_counts, level.story_flags)
    check(INQUIRIES.can_talk(ui, area), "live speaker context")
    var before_flags := level.story_flags.duplicate(true)
    var before_world := level.world_state.data.duplicate(true)
    check(not INQUIRIES.commit(ui, area, row.id, row.fingerprint, 0).ok, "interruption commits nothing")
    check(level.writes == 0 and level.story_flags == before_flags, "interruption does not save")
    level.allow_save = false
    check(not INQUIRIES.commit(ui, area, row.id, row.fingerprint, row.lines.size()-1).ok, "save failure reported")
    check(level.story_flags == before_flags and level.world_state.data == before_world, "failed write rolls both snapshots back")
    level.allow_save = true
    check(INQUIRIES.commit(ui, area, row.id, row.fingerprint, row.lines.size()-1).ok, "save retry succeeds")
    var restored := preload("res://scripts/world_state.gd").new()
    check(restored.read("user://inquiry_transaction.json"), "actual save reloads")
    check(INQUIRIES.records(restored.data.story_flags).size() == 1, "saved answer survives new reader")
    var writes := level.writes
    check(INQUIRIES.commit(ui, area, row.id, row.fingerprint, row.lines.size()-1).repeated, "repeat is idempotent")
    check(level.writes == writes, "repeat does not write")
    check(not INQUIRIES.commit(ui, area, row.id, "stale", row.lines.size()-1).ok, "stale answer rejected")
    grant(entries[0].continuation.requires, level.inventory_counts, level.story_flags)
    check(not INQUIRIES.commit(ui, area, row.id, row.fingerprint, row.lines.size()-1).ok, "new discovery rejects old confirmation")
    check(level.writes == writes, "changed conditions cannot save old answer")
    var detached := INQUIRIES.catalog()
    detached[0].question = "outside mutation"
    check(INQUIRIES.catalog()[0].question != detached[0].question, "catalog is detached")
    check(INQUIRIES.available("missing_npc", level.inventory_counts, level.story_flags).is_empty(), "unknown speaker has no questions")
    ui.dialogue.hide()
    check(not INQUIRIES.can_talk(ui, area), "hidden parent conversation denies commit")
    ui.dialogue.show()
    area.position.x = 151
    check(not INQUIRIES.can_talk(ui, area), "distance rechecked")
    area.position.x = 0
    level.player.hp = 0
    check(not INQUIRIES.can_talk(ui, area), "dead player cannot commit")
    level.player.hp = 3
    level.world_loading = true
    check(not INQUIRIES.can_talk(ui, area), "region transition invalidates speaker")
    level.world_loading = false
    var desk := DESK.new()
    ui.add_child(desk)
    desk.open(ui, area)
    check(desk.questions.get_child_count() >= 1, "actual dialog offers earned questions")
    desk._select(row.id)
    check(desk.line_index == 0, "dialog starts at first line")
    desk.hide()
    check(desk.selected.is_empty() and desk.line_index == -1, "cancel clears reading session")
    desk.open(ui, area)
    level.active_overlay = ""
    desk._process(0)
    check(not desk.visible, "dialog closes with parent conversation")
    for file in DirAccess.get_files_at("user://"):
        if file.begins_with("inquiry_transaction.json"):
            DirAccess.remove_absolute("user://" + file)
    ui.queue_free()
    level.queue_free()
    await process_frame
    print("NARRATIVE_INQUIRIES_PASS checks=%d failures=%d" % [checks, failures])
    quit(1 if failures else 0)
