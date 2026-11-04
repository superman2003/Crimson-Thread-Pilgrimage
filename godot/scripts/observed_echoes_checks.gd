extends RefCounted
const ECHOES := preload("res://scripts/observed_echoes.gd")
const VOICE := preload("res://scripts/protagonist_voice.gd")
const HISTORY := preload("res://scripts/scene_history.gd")

func _has(rows: Array, id: String) -> bool:
    return rows.any(func(row: Dictionary): return row.id == ECHOES.PREFIX + id)

func run(main: Node, tree: SceneTree, check: Callable) -> void:
    var data := ECHOES.catalog()
    check.call(ECHOES.valid(data) and data.get("entries", []).size() == 12, "twelve bounded environmental responses have authored source conditions")
    if data.is_empty():
        return
    var facilities: Array[String] = []
    for source in HISTORY.all_entries():
        if source.role == "daily":
            facilities.append(String(source.id))
    check.call(facilities.size() == 6, "each city supplies one independently observed daily facility")
    check.call(ECHOES.records({}, {}).is_empty(), "new and legacy journeys without observations reveal no new response titles")
    var matrix_cases := 0
    for mask in 4096:
        var inventory := {}
        var flags := {}
        for index in 6:
            if mask & (1 << index):
                flags[HISTORY.FLAG_PREFIX + facilities[index]] = true
            if mask & (1 << (index + 6)):
                inventory[ECHOES.EVIDENCE[index]] = 1
        var before := [inventory.duplicate(true), flags.duplicate(true)]
        var visible := ECHOES.records(inventory, flags)
        var expected := 0
        for row in data.entries:
            var ready := true
            for observation in row.observations_all:
                ready = ready and flags.has(HISTORY.FLAG_PREFIX + String(observation))
            for evidence in row.evidence_all:
                ready = ready and inventory.has(String(evidence))
            if ready:
                expected += 1
            check.call(_has(visible, String(row.id)) == ready, "all 4096 observation/evidence combinations withhold every unearned response")
        check.call(visible.size() == expected, "the derived record set contains no extra or duplicated responses")
        check.call(before == [inventory, flags], "synthesizing observations changes no discovery, quest or ending state")
        matrix_cases += 1
    check.call(matrix_cases == 4096, "all six facility bits and all six evidence bits were exercised")

    for row in data.entries:
        var inventory := {}
        var flags := {}
        for id in row.observations_all:
            flags[HISTORY.FLAG_PREFIX + String(id)] = true
        for id in row.evidence_all:
            inventory[String(id)] = 1
        var public := ECHOES.records(inventory, flags).filter(func(item): return item.id == ECHOES.PREFIX + String(row.id))
        check.call(public.size() == 1, "the minimal real source set reveals its authored response once")
        if public.size() != 1:
            continue
        check.call(not public[0].has("observations_all") and not public[0].has("evidence_all"), "public records omit locked conditions and internal source tables")
        check.call(public[0].voice_sources.size() == row.observations_all.size() + row.evidence_all.size(), "every displayed response points back to all of its encountered sources")
        check.call(String(public[0].description).length() <= 90, "environmental responses remain brief first-person notes")
        for id in row.observations_all:
            for invalid in [false, 0, 1, "true", null, {}, []]:
                var changed := flags.duplicate(true)
                changed[HISTORY.FLAG_PREFIX + String(id)] = invalid
                check.call(not _has(ECHOES.records(inventory, changed), String(row.id)), "non-boolean or unconfirmed observations cannot invent a response")
        for id in row.evidence_all:
            for invalid in [0, -1, true, "1", 0.5, INF, NAN, 1000001]:
                var changed := inventory.duplicate(true)
                changed[String(id)] = invalid
                var known := flags.duplicate(true)
                known["evidence_known_" + String(id)] = true
                known["evidence_read_" + String(id)] = true
                check.call(not _has(ECHOES.records(changed, known), String(row.id)), "known flags and malformed possession cannot replace an independent testimony")
        var restored_inventory: Dictionary = JSON.parse_string(JSON.stringify(inventory))
        var restored_flags: Dictionary = JSON.parse_string(JSON.stringify(flags))
        check.call(ECHOES.records(restored_inventory, restored_flags) == ECHOES.records(inventory, flags), "existing JSON progress reconstructs the same notes without a new save field")
        public[0].voice_sources.clear()
        check.call(not ECHOES.records(inventory, flags)[0].voice_sources.is_empty(), "journal callers cannot alter the shared provenance of later readings")
    var broken := data.duplicate(true)
    broken.entries[0].observations_all = ["unseen_invented_facility"]
    check.call(not ECHOES.valid(broken), "unknown observation identities fail the authored source gate")
    broken = data.duplicate(true)
    broken.entries[0].evidence_all = []
    check.call(not ECHOES.valid(broken), "one ambient object alone cannot impersonate a new combined reading")
    broken = data.duplicate(true)
    broken.entries[1].id = broken.entries[0].id
    check.call(not ECHOES.valid(broken), "duplicate response identities cannot create duplicate journal entries")
    broken = data.duplicate(true)
    broken.entries[0]["grant_flags"] = ["invented_progress"]
    check.call(not ECHOES.valid(broken), "response authoring cannot smuggle progress fields into derived notes")

    var inventory_before: Dictionary = main.inventory_counts.duplicate(true)
    var flags_before: Dictionary = main.story_flags.duplicate(true)
    var wallet_before: int = main.currency_count
    var toast_before: String = main.toast_label.text
    var saved_before := FileAccess.get_file_as_bytes(main.world_save_path)
    main.inventory_counts = {}
    main.story_flags = {HISTORY.FLAG_PREFIX + facilities[0]: true}
    main._toggle_backpack()
    var ui: Node = main.ui_shell
    ui.bag_category = "旅记"
    ui.journal_filter_buttons.voice.pressed.emit()
    await tree.process_frame
    check.call(ui.bag_grid.get_child_count() == 0, "one observed facility does not leak its paired testimony or future reaction")
    main.inventory_counts.testimony_01 = 1
    ui.refresh_inventory()
    await tree.process_frame
    check.call(ui.bag_grid.get_child_count() == 1 and ui.bag_name.text == "把试音模合回去", "the production voice tab shows the response to the actually owned source pair")
    check.call(ui.bag_category_label.text == "自述 · 观察遗迹之后" and ui.bag_description.text.contains("记自：开合试音模"), "the real reader distinguishes observed reflections from ability acquisition and names its source")
    main.story_flags[HISTORY.FLAG_PREFIX + facilities[1]] = true
    ui.refresh_inventory()
    await tree.process_frame
    check.call(ui.bag_grid.get_child_count() == 2, "a second actual facility adds the cross-city note while withholding its unowned proof response")
    var row: Dictionary = ECHOES.records(main.inventory_counts, main.story_flags).back()
    ui._show_journal_record(row)
    var presentation: Dictionary = ui._journal_presentation(row)
    check.call(presentation.text == ui.bag_description.text and presentation.text.contains("泵渠分流箱"), "searchable response text includes the same encountered sources as the live reader")
    check.call(main.active_overlay == "backpack" and not ui.dialogue.visible, "derived environmental notes open no dialogue or exploration interruption")
    check.call(main.currency_count == wallet_before and main.toast_label.text == toast_before, "reading a response grants no money and emits no unsolicited toast")
    check.call(FileAccess.get_file_as_bytes(main.world_save_path) == saved_before, "derived reading does not write the World checkpoint")
    main.inventory_counts = inventory_before
    main.story_flags = flags_before
    ui.refresh_inventory()
    main._close_overlays()
    print("OBSERVED_ECHOES_MATRIX combinations=%d notes=12" % matrix_cases)
