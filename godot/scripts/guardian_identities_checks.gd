extends RefCounted
const IDENTITIES := preload("res://scripts/guardian_identities.gd")
const INQUIRIES := preload("res://scripts/narrative_inquiries.gd")
const SOURCES := preload("res://scripts/journal_sources.gd")
const STATE := preload("res://scripts/world_state.gd")

func version(id: String, expanded: bool) -> Dictionary:
    var entry := INQUIRIES.find(id)
    if not expanded:
        entry.erase("continuation")
    var items := {}
    var flags := {}
    var sources: Array = entry.requires.duplicate(true)
    if expanded and entry.has("continuation"):
        sources.append_array(entry.continuation.requires)
    for source in sources:
        if source.kind == "item":
            items[String(source.id)] = 1
        elif source.kind == "history":
            flags["scene_history_" + String(source.id)] = true
        else:
            flags[String(source.id)] = true
    return INQUIRIES.quote(entry, items, flags)

func fixture(row: Dictionary, expanded: bool = false) -> Dictionary:
    var flags := {String(row.boss_flag): true}
    for account in row.accounts:
        flags[String(version(String(account.inquiry), expanded).marker)] = true
    return flags

func pure(tree: SceneTree) -> void:
    var data := IDENTITIES.catalog()
    tree.check(IDENTITIES.valid(data) and data.entries.size() == 6, "all six regions have bounded recognition grounded in existing spoken accounts")
    tree.check(IDENTITIES.records({}).is_empty(), "a new journey reveals no future guardian identity titles")
    var all_memories := {}
    var all_bosses := {}
    for row in data.entries:
        var base := fixture(row)
        var before := base.duplicate(true)
        var records := IDENTITIES.records(base)
        tree.check(records.size() == 1 and records[0].description.contains(row.recognition) and records[0].description.contains(row.limit), "each fully supported regional recognition preserves its witness boundary")
        var links := SOURCES.links("guide:" + IDENTITIES.PREFIX + String(row.id), {}, base)
        tree.check(links.size() == row.accounts.size() and links.all(func(link): return link.entry.record_kind == "people"), "recognition opens actual committed speech rather than a newly quoted answer")
        for account in row.accounts:
            var old := version(String(account.inquiry), false)
            var missing := base.duplicate(true)
            missing.erase(String(old.marker))
            tree.check(IDENTITIES.records(missing).is_empty(), "every required conversation must really have been committed")
            for malformed in [false, 1, "true", null]:
                missing[String(old.marker)] = malformed
                tree.check(IDENTITIES.records(missing).is_empty(), "truthy or malformed memory markers do not create a heard answer")
            all_memories[String(old.marker)] = true
        var no_fight := base.duplicate(true)
        no_fight.erase(String(row.boss_flag))
        tree.check(IDENTITIES.records(no_fight).is_empty(), "hearing an identity before the fight does not spoil the post-fight note")
        for malformed in [1, "true", false]:
            no_fight[String(row.boss_flag)] = malformed
            tree.check(IDENTITIES.records(no_fight).is_empty(), "boss confirmation requires a real saved boolean")
        all_bosses[String(row.boss_flag)] = true
        var both := base.merged(fixture(row, true))
        var repeated := IDENTITIES.records(both)
        tree.check(repeated.size() == 1 and repeated[0].id == records[0].id, "hearing a later expansion keeps one stable regional identity")
        var expanded_links := SOURCES.links("guide:" + IDENTITIES.PREFIX + String(row.id), {}, both)
        for account in row.accounts:
            var expanded := version(String(account.inquiry), true)
            tree.check(expanded_links.any(func(link): return link.key == "people:" + String(expanded.marker)), "a recorded expansion is preferred without inventing an unheard version")
        tree.check(base == before and IDENTITIES.records(JSON.parse_string(JSON.stringify(base))) == records, "reading and existing JSON restoration preserve the exact earlier account")
        tree.check(not INQUIRIES.records(base).is_empty() and IDENTITIES.records(base) == records, "a durable heard answer survives without currently possessing its original question materials")
    for mask in 64:
        var flags := all_memories.duplicate(true)
        var expected := 0
        for index in 6:
            if mask & (1 << index):
                flags[String(data.entries[index].boss_flag)] = true
                expected += 1
        tree.check(IDENTITIES.records(flags).size() == expected, "all 64 boss combinations withhold regions whose fight is unfinished")
        flags = all_bosses.duplicate(true)
        for index in 6:
            if mask & (1 << index):
                flags.merge(fixture(data.entries[index]))
        tree.check(IDENTITIES.records(flags).size() == expected, "all 64 confirmed-account combinations withhold unheard regional explanations")
    var forged := all_bosses.merged({INQUIRIES.PREFIX + "invented".sha256_text(): true})
    tree.check(IDENTITIES.records(forged).is_empty(), "an arbitrary memory hash cannot become a recognized canonical speaker")
    var bad := data.duplicate(true)
    bad.entries[1].accounts[0].lines = INQUIRIES.find("chapter_02_02").continuation.lines
    tree.check(not IDENTITIES.valid(bad), "a baseline recognition cannot quietly require an unheard future expansion")
    bad = data.duplicate(true)
    bad.entries[1].boss_flag = "boss_down_ch01"
    tree.check(not IDENTITIES.valid(bad), "a recognition cannot use another region's boss flag")
    tree.check(IDENTITIES.valid(IDENTITIES.catalog()), "caller mutations leave the canonical recognition catalogue intact")

func live(tree: SceneTree, world: Node) -> void:
    # These are explicit evidence/fight fixtures, not a claimed natural boss win.
    world._close_overlays()
    world.inventory_counts["testimony_04"] = 1
    world.story_flags["scene_history_ch04_broken_string_greenhouse_daily"] = true
    world.story_flags["boss_down_ch04"] = true
    var saved: bool = world._save_world()
    tree.check(saved, "post-fight identity fixture uses an actual World checkpoint: " + String(world.world_state.last_error) + " blocked=" + str(world.world_save_blocked) + " injected=" + str(world.world_save_failure_injected_for_validation))
    if not saved:
        return
    var singer: Area2D = await tree.resident_npc(world, "npc_broken_singer")
    if not is_instance_valid(singer):
        return
    var ui: Control = world.ui_shell
    world._talk_to_npc(singer)
    ui._open_narrative_inquiries()
    var desk: AcceptDialog = ui.narrative_inquiry_desk
    tree.check(is_instance_valid(desk) and desk.visible, "the actual resident singer opens the production inquiry desk")
    if not is_instance_valid(desk):
        return
    var id := "chapter_04_02"
    var quoted := INQUIRIES.quote(INQUIRIES.find(id), world.inventory_counts, world.story_flags)
    var identity := IDENTITIES.PREFIX + "chapter_04"
    var before: Dictionary = world.story_flags.duplicate(true)
    var items: Dictionary = world.inventory_counts.duplicate(true)
    var money: int = world.currency_count
    var disk := FileAccess.get_file_as_bytes(world.world_save_path)
    desk._select(id)
    tree.check(not IDENTITIES.records(world.story_flags).any(func(row): return row.id == identity), "opening a real identity question cannot publish its summary")
    desk.hide()
    tree.check(world.story_flags == before, "leaving a real question early commits no identity memory")
    ui._open_narrative_inquiries()
    desk._select(id)
    while desk.line_index < quoted.lines.size() - 1:
        desk._advance()
    tree.check(not IDENTITIES.records(world.story_flags).any(func(row): return row.id == identity), "showing the last line still waits for explicit confirmation")
    world.world_save_failure_injected_for_validation = true
    desk._advance()
    tree.check(world.story_flags == before and FileAccess.get_file_as_bytes(world.world_save_path) == disk, "failed real inquiry save rolls the memory and derived identity back together")
    world.world_save_failure_injected_for_validation = false
    desk._advance()
    var rows := IDENTITIES.records(world.story_flags).filter(func(row): return row.id == identity)
    tree.check(rows.size() == 1 and world.story_flags.get(quoted.marker, false), "successful explicit retry publishes exactly the supported singer and gardener distinction")
    tree.check(world.currency_count == money and world.inventory_counts == items, "confirming recognition grants neither new quest rewards nor evidence")
    var restored := STATE.new()
    tree.check(restored.read(world.world_save_path) and IDENTITIES.records(restored.data.story_flags) == IDENTITIES.records(world.story_flags), "the actual World JSON restores the same heard recognition")
    desk.hide()
    world._close_overlays()
    world.inventory_counts.testimony_04 = 0
    tree.check(IDENTITIES.records(world.story_flags).filter(func(row): return row.id == identity).size() == 1, "losing current evidence never rewrites an already-confirmed NPC account")
    world.inventory_counts = items.duplicate(true)
    world._toggle_backpack()
    ui.bag_category = "旅记"
    ui.journal_filter = "guide"
    ui.journal_search.text = "辨认"
    ui.refresh_inventory()
    tree.check(ui._journal_batch_documents().size() == 1, "production journal search exposes only the actually heard regional recognition")
    if rows.is_empty():
        return
    ui._show_journal_record(rows[0])
    tree.check(ui.bag_category_label.text == "战后辨认 · 已确认交谈" and ui.bag_description.text.contains("园主"), "the production reader keeps the song keeper and gardener as distinct people")
    var after := FileAccess.get_file_as_bytes(world.world_save_path)
    ui.bag_pin.pressed.emit()
    var source: AcceptDialog = ui.journal_source_dialog
    tree.check(source.visible and source.body.text.contains(quoted.lines[0]) and source.body.text.contains(quoted.lines.back()), "the real source reader shows exactly the previously confirmed expanded answer")
    tree.check(not source.body.text.contains("chapter_04_02"), "the player reads the known person's words rather than internal topic identifiers")
    world._close_overlays()
    tree.check(FileAccess.get_file_as_bytes(world.world_save_path) == after and world.currency_count == money and world.inventory_counts == items, "recognition and source review preserve the saved conversation transaction")
