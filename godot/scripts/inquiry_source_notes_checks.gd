extends RefCounted
const INQUIRIES := preload("res://scripts/narrative_inquiries.gd")
const NOTES := preload("res://scripts/inquiry_source_notes.gd")
const SOURCES := preload("res://scripts/journal_sources.gd")
const HISTORY := preload("res://scripts/scene_history.gd")
const PROOF := preload("res://scripts/testimony_sources.gd")

func grant(sources: Array, items: Dictionary, flags: Dictionary) -> void:
    for source in sources:
        match source.kind:
            "item": items[String(source.id)] = 1
            "history": flags[HISTORY.FLAG_PREFIX + String(source.id)] = true
            "flag": flags[String(source.id)] = true

func pure(tree: SceneTree) -> void:
    var entries := INQUIRIES.catalog()
    entries.append_array(INQUIRIES.archived_catalog())
    var quotes := {}
    var all_flags := {}
    var all_items := {}
    var history_ids := {}
    for entry in HISTORY.all_entries():
        history_ids[String(entry.id)] = true
    var story: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world_narrative.json"))
    for entry in entries:
        for expanded in [false, true]:
            if expanded and not entry.has("continuation"):
                continue
            var version: Dictionary = entry.duplicate(true)
            if not expanded:
                version.erase("continuation")
            var items := {}
            var flags := {}
            grant(version.requires, items, flags)
            if expanded:
                grant(version.continuation.requires, items, flags)
            var quoted := INQUIRIES.quote(version, items, flags)
            tree.check(not quoted.is_empty(), "every published source version remains quotable under its original materials")
            if quoted.is_empty():
                continue
            quotes[String(quoted.marker)] = quoted
            all_flags.merge(flags, true)
            all_flags[String(quoted.marker)] = true
            all_items.merge(items, true)
    var before := all_flags.duplicate(true)
    var rows := INQUIRIES.records(all_flags)
    var indexed := {}
    for row in rows:
        indexed[String(row.id)] = row
    tree.check(indexed.size() == quotes.size(), "all 426 published source versions resolve exactly their distinct saved identities")
    var samples: Array[String] = []
    var coverage := {}
    for marker in quotes:
        var quote: Dictionary = quotes[marker]
        tree.check(indexed.has(marker), "a source header cannot change an already published inquiry identity")
        if not indexed.has(marker):
            continue
        var memory: Dictionary = indexed[marker]
        tree.check(memory.inquiry_npc == quote.npc and memory.inquiry_speaker == story.npcs[quote.npc].display_name and memory.description.begins_with("对话者：" + String(memory.inquiry_speaker)), "each confirmed answer names its real localized speaker")
        tree.check(memory.inquiry_lines == quote.lines, "adding source context never adds an unheard answer line")
        var expected: Array[String] = []
        for source in quote.sources:
            var key := ""
            if source.kind == "history" and history_ids.has(source.id):
                key = "evidence:" + HISTORY.FLAG_PREFIX + String(source.id)
            elif source.kind == "item" and source.id in PROOF.IDS:
                key = "evidence:" + String(source.id)
            if not key.is_empty() and not expected.has(key):
                expected.append(key)
        tree.check(memory.journal_source_keys == expected, "source keys contain only the exact version's physical observations and independent originals")
        for line in quote.lines:
            tree.check(memory.description.contains(line), "the spoken transcript remains complete after adding its speaker")
        var kind := String(quote.npc) + ":" + str(quote.expanded)
        if not coverage.has(kind) and samples.size() < 24:
            coverage[kind] = true
            samples.append(String(marker))
    for marker in samples:
        var memory: Dictionary = indexed[marker]
        var expected: Array = memory.journal_source_keys
        var links := SOURCES.links("people:" + marker, all_items, all_flags)
        tree.check(links.map(func(row): return row.key) == expected, "representative native source routes open exactly the published version's original records")
        var lost := all_items.duplicate(true)
        for id in PROOF.IDS:
            lost[String(id)] = 0
        links = SOURCES.links("people:" + marker, lost, all_flags)
        tree.check(not links.any(func(row): return String(row.key).begins_with("evidence:testimony_")), "known or remembered evidence titles cannot substitute for currently held source originals")
    for marker in samples.slice(0, 6):
        for invalid in [true, "1", -1, 0.5, INF, NAN, 1000001]:
            var malformed := all_items.duplicate(true)
            var known := all_flags.duplicate(true)
            for id in PROOF.IDS:
                malformed[String(id)] = invalid
                known["evidence_known_" + String(id)] = true
                known["evidence_read_" + String(id)] = true
            var links := SOURCES.links("people:" + marker, malformed, known)
            tree.check(not links.any(func(row): return String(row.key).begins_with("evidence:testimony_")), "malformed ownership and stale known/read markers cannot open original evidence from a durable memory")
        for invalid in [false, 1, "true", null]:
            var changed := all_flags.duplicate(true)
            for id in history_ids:
                changed[HISTORY.FLAG_PREFIX + String(id)] = invalid
            var links := SOURCES.links("people:" + marker, all_items, changed)
            tree.check(not links.any(func(row): return String(row.key).begins_with("evidence:" + HISTORY.FLAG_PREFIX)), "malformed observation flags cannot open physical source notes from remembered words")
    for invalid in [null, false, 1, "sources", {}]:
        tree.check(NOTES.source_keys(invalid).is_empty(), "non-array source metadata is rejected without inventing a source")
    var over_limit: Array = []
    for unused in 13:
        over_limit.append({"kind": "item", "id": "testimony_01"})
    tree.check(NOTES.source_keys(over_limit).is_empty(), "over-limit metadata fails closed before any duplicate source filtering")
    tree.check(all_flags == before and INQUIRIES.records(JSON.parse_string(JSON.stringify(all_flags))) == rows, "new source presentation is pure and restores from existing JSON without new markers")
    tree.check(SOURCES.links("people:" + INQUIRIES.PREFIX + "forged", all_items, all_flags).is_empty(), "an arbitrary inquiry hash cannot choose a person's source set")
    tree.check(NOTES.source_keys([{"kind": "history", "id": "future_room"}, {"kind": "item", "id": "testimony_99"}, {"kind": "flag", "id": "ending_c_done"}]).is_empty(), "unknown objects and story flags do not become invented original documents")
    tree.check(NOTES.source_keys([{"kind": "item", "id": "testimony_01"}, {"kind": "item", "id": "testimony_01"}]) == ["evidence:testimony_01"], "a repeated source remains one independent original")
    var original_catalog := INQUIRIES._catalog.duplicate(true)
    var original_rows := INQUIRIES.records(all_flags)
    var changed_entry: Dictionary = original_catalog[0].duplicate(true)
    changed_entry.lines[0] = "（修订版本）" + String(changed_entry.lines[0])
    INQUIRIES._catalog[0] = changed_entry
    var test_items := {}
    var test_flags := {}
    grant(changed_entry.requires, test_items, test_flags)
    changed_entry.erase("continuation")
    var changed_quote := INQUIRIES.quote(changed_entry, test_items, test_flags)
    tree.check(not INQUIRIES.records(all_flags).any(func(row): return row.description.contains(changed_entry.lines[0])), "a revised catalogue invalidates templates without adding a new answer to old memory markers")
    test_flags[String(changed_quote.marker)] = true
    tree.check(INQUIRIES.records(test_flags).any(func(row): return row.description.contains(changed_entry.lines[0])), "only the revised version's own marker can publish the revised answer")
    INQUIRIES._catalog = original_catalog
    tree.check(INQUIRIES.records(all_flags) == original_rows, "restoring the published catalogue also restores its exact source-bound templates")
    if not original_rows.is_empty():
        var detached := INQUIRIES.records(all_flags)
        detached[0].inquiry_lines.clear()
        detached[0].journal_source_keys.clear()
        tree.check(INQUIRIES.records(all_flags) == original_rows, "caller mutations cannot alter nested transcript or source arrays in the memory cache")
    var raw := {"description": "原文"}
    var annotated := NOTES.annotate(raw, {"npc": "npc_rain_smith_liu", "sources": []})
    tree.check(raw.description == "原文" and annotated.description.contains(String(story.npcs.npc_rain_smith_liu.display_name)) and not annotated.description.contains("npc_rain_smith_liu"), "annotation borrows neither the caller's record nor an internal NPC name")

func live(tree: SceneTree, world: Node) -> void:
    var quote := INQUIRIES.quote(INQUIRIES.find("chapter_04_02"), world.inventory_counts, world.story_flags)
    var matches := INQUIRIES.records(world.story_flags).filter(func(row): return row.id == quote.marker)
    tree.check(matches.size() == 1, "the preceding real singer confirmation supplies one exact source-bearing memory")
    if matches.is_empty():
        return
    var memory: Dictionary = matches[0]
    var flags: Dictionary = world.story_flags.duplicate(true)
    var items: Dictionary = world.inventory_counts.duplicate(true)
    var money: int = world.currency_count
    var disk := FileAccess.get_file_as_bytes(world.world_save_path)
    world._toggle_backpack()
    var ui: Control = world.ui_shell
    ui.bag_category = "旅记"
    ui.journal_filter = "people"
    ui.journal_search.text = String(quote.question)
    ui.refresh_inventory()
    ui._show_journal_record(memory)
    tree.check(ui.bag_description.text.begins_with("对话者：断弦歌者") and not ui.bag_pin.disabled, "the actual remembered answer identifies its speaker and enables source review")
    var original: Dictionary = ui.journal_current_document.duplicate(true)
    var profiles: Dictionary = ui.journal_catalog.profiles.duplicate(true)
    var reading_size: Variant = ui.accessibility.get("subtitle_size", 21)
    ui.accessibility["subtitle_size"] = 26
    ui.bag_pin.pressed.emit()
    var desk: AcceptDialog = ui.journal_source_dialog
    tree.check(desk.body.get_theme_font_size("normal_font_size") == 26 and desk.body.size.x <= float(desk.size.x), "the actual long source reader uses the large accessible font within its native panel")
    ui.accessibility["subtitle_size"] = reading_size
    tree.check(desk.visible and desk.rows.size() == 2, "the real answer opens its observed greenhouse object and independently held fourth testimony")
    var linked := SOURCES.links("people:" + String(memory.id), items, flags)
    var proof_index: int = linked.map(func(row): return row.key).find("evidence:testimony_04")
    var history_index: int = linked.map(func(row): return row.key).find("evidence:scene_history_ch04_broken_string_greenhouse_daily")
    tree.check(proof_index >= 0 and history_index >= 0 and proof_index != history_index, "actual source keys keep independent proof and observation distinct")
    for index in linked.size():
        desk.select_source(index)
        tree.check(desk.body.text == ui._journal_presentation(linked[index].entry).text, "every source selector item displays the production original body without changing the answer")
    world.inventory_counts["testimony_04"] = 0
    desk.select_source(proof_index)
    tree.check(not desk.visible and INQUIRIES.records(world.story_flags).has(memory), "losing an original closes that stale source while preserving the confirmed conversation")
    world.inventory_counts = items.duplicate(true)
    ui._show_journal_record(memory)
    ui.bag_pin.pressed.emit()
    world.story_flags.erase("scene_history_ch04_broken_string_greenhouse_daily")
    desk.select_source(history_index)
    tree.check(not desk.visible, "withdrawing an observation cannot leave its stale original in the reader")
    world.story_flags = flags.duplicate(true)
    tree.check(ui.journal_current_document == original and ui.journal_catalog.profiles == profiles, "source review preserves the original answer selection and explicit read or star preferences")
    world._close_overlays()
    tree.check(world.story_flags == flags and world.inventory_counts == items and world.currency_count == money and FileAccess.get_file_as_bytes(world.world_save_path) == disk, "speaker and source navigation leaves the real saved inquiry transaction unchanged")
