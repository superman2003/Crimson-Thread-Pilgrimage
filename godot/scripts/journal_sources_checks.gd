extends RefCounted
const SOURCES := preload("res://scripts/journal_sources.gd")
const ECHOES := preload("res://scripts/observed_echoes.gd")
const RETURNS := preload("res://scripts/ending_return_journal.gd")
const HISTORY := preload("res://scripts/scene_history.gd")
const PROVENANCE := preload("res://scripts/testimony_sources.gd")
const CONTACTS := preload("res://scripts/quest_contacts.gd")

func pure(tree: SceneTree) -> void:
    tree.check(SOURCES.links("voice:voice_observed_fake", {}, {}).is_empty(), "an arbitrary source key cannot query unknown records")
    for row in ECHOES.catalog().entries:
        var items := {}
        var flags := {}
        var expected: Array[String] = []
        for id in row.observations_all:
            flags[HISTORY.FLAG_PREFIX + String(id)] = true
            expected.append("evidence:" + HISTORY.FLAG_PREFIX + String(id))
        for id in row.evidence_all:
            items[String(id)] = 1
            expected.append("evidence:" + String(id))
        var origin := "voice:" + ECHOES.PREFIX + String(row.id)
        var before := [items.duplicate(true), flags.duplicate(true)]
        var links := SOURCES.links(origin, items, flags)
        tree.check(links.map(func(link): return link.key) == expected, "all twelve notes link their exact original facility and testimony records in source order")
        for link in links:
            tree.check(SOURCES.key(link.entry) == link.key and not link.entry.has("journal_source_keys"), "source records retain their canonical identity and do not form recursive derived links")
            tree.check(not String(link.title).is_empty(), "source chooser has an already-known localized title")
        for id in row.observations_all:
            var missing := flags.duplicate(true)
            missing.erase(HISTORY.FLAG_PREFIX + String(id))
            tree.check(SOURCES.links(origin, items, missing).is_empty(), "withdrawing a required observation invalidates the entire derived origin")
        for id in row.evidence_all:
            for invalid in [0, -1, 0.5, true, "1", INF, NAN]:
                var malformed := items.duplicate(true)
                malformed[String(id)] = invalid
                tree.check(SOURCES.links(origin, malformed, flags).is_empty(), "bad possession cannot use source navigation to disclose an unearned synthesis")
        tree.check([items, flags] == before, "resolving original sources leaves all gameplay inputs unchanged")
        if not links.is_empty():
            links[0].entry["title"] = "tampered"
            tree.check(SOURCES.links(origin, items, flags)[0].title != "tampered", "returned source snapshots cannot poison later readers")
    var daily: Array = HISTORY.all_entries().filter(func(row): return row.role == "daily")
    for mask in 64:
        var items := {}
        var flags := {}
        for index in 6:
            items[ECHOES.EVIDENCE[index]] = 1
            if mask & (1 << index):
                flags[HISTORY.FLAG_PREFIX + String(daily[index].id)] = true
        for row in ECHOES.catalog().entries:
            var key := "voice:" + ECHOES.PREFIX + String(row.id)
            var public := ECHOES.records(items, flags).any(func(note): return SOURCES.key(note) == key)
            tree.check(not SOURCES.links(key, items, flags).is_empty() == public, "all 64 observation subsets resolve links only for actually earned notes")
    for mask in 64:
        var items := {}
        var flags := {}
        for index in 6:
            flags[HISTORY.FLAG_PREFIX + String(daily[index].id)] = true
            if mask & (1 << index):
                items[ECHOES.EVIDENCE[index]] = 1
        for row in ECHOES.catalog().entries:
            var key := "voice:" + ECHOES.PREFIX + String(row.id)
            var links := SOURCES.links(key, items, flags)
            for link in links:
                if String(link.key).begins_with("evidence:testimony_"):
                    tree.check(items.has(String(link.entry.id)), "all 64 evidence subsets keep every cited testimony tied to real possession")
    for ending in RETURNS.ENDINGS:
        for mask in 32:
            var flags := {"ending_chosen": ending}
            var expected: Array[String] = []
            var quests: Array = CONTACTS.narrative().story_data.quests
            for index in quests.size():
                if mask & (1 << index):
                    flags[String(quests[index].started_flag)] = true
                    expected.append("quest:" + String(quests[index].id))
            var links := SOURCES.links("guide:ending_return_contacts", {}, flags)
            tree.check(links.map(func(row): return row.key) == expected, "all 96 ending and acceptance combinations link only to accepted canonical quests")
    for mask in 64:
        var items := {}
        for index in 6:
            if mask & (1 << index):
                items[PROVENANCE.IDS[index]] = 1
        for id in PROVENANCE.IDS:
            var expected: Array[String] = []
            if items.has(id):
                for comparison in PROVENANCE.catalog().sources[id].cross_checks:
                    var ready: bool = comparison.evidence_all.all(func(required): return items.has(required))
                    if ready:
                        for required in comparison.evidence_all:
                            var key := "evidence:" + String(required)
                            if required != id and not expected.has(key):
                                expected.append(key)
            var links := SOURCES.links("evidence:" + String(id), items, {})
            tree.check(links.map(func(row): return row.key) == expected, "all 384 testimony and possession combinations link only the partners of a currently visible comparison")
            tree.check(not links.any(func(row): return row.key == "evidence:" + String(id)), "an original testimony never cites itself as another independent proof")
            var known := {"evidence_known_" + String(id): true, "evidence_read_" + String(id): true}
            tree.check(SOURCES.links("evidence:" + String(id), {}, known).is_empty(), "remembering an evidence title does not reveal its possession-gated cross-reading partners")
    tree.check(SOURCES.links("quest:root_rescue", {}, {"quest_root_rescue_started": true}).is_empty(), "ordinary records do not gain synthetic self-links")

func frames(tree: SceneTree) -> void:
    for unused in 3:
        await tree.process_frame

func live(tree: SceneTree, world: Node) -> void:
    # Deliberate source fixtures: this checks reading, not a natural acquisition.
    var authored: Dictionary = ECHOES.catalog().entries[0]
    for id in authored.observations_all:
        world.story_flags[HISTORY.FLAG_PREFIX + String(id)] = true
    for id in authored.evidence_all:
        world.inventory_counts[String(id)] = 1
    world.inventory_counts["testimony_03"] = 1
    tree.check(world._save_world(), "source reader fixture saves a real World checkpoint")
    var flags: Dictionary = world.story_flags.duplicate(true)
    var items: Dictionary = world.inventory_counts.duplicate(true)
    var wallet: int = world.currency_count
    var disk := FileAccess.get_file_as_bytes(world.world_save_path)
    world._close_overlays()
    world._toggle_backpack()
    var ui: Control = world.ui_shell
    ui.bag_category = "旅记"
    ui.journal_filter = "voice"
    ui.journal_search.text = String(authored.title)
    ui.journal_unread.button_pressed = false
    ui.journal_stars.button_pressed = false
    ui.refresh_inventory()
    await frames(tree)
    var origin_key := "voice:" + ECHOES.PREFIX + String(authored.id)
    tree.check(ui.journal_current_document.get("key") == origin_key and not ui.bag_pin.disabled, "the actual filtered note enables its source action")
    var original: Dictionary = ui.journal_current_document.duplicate(true)
    var filter_before: Array = [ui.journal_filter, ui.journal_search.text, ui.journal_unread.button_pressed, ui.journal_stars.button_pressed, ui.journal_sort.selected]
    var offset: float = ui.bag_description.get_v_scroll_bar().value
    var profiles: Dictionary = ui.journal_catalog.profiles.duplicate(true)
    ui.bag_pin.pressed.emit()
    await frames(tree)
    var dialog: AcceptDialog = ui.journal_source_dialog
    tree.check(is_instance_valid(dialog) and dialog.visible and dialog.chooser.has_focus() and ui.has_modal_window(), "the real source action opens a registered native modal with keyboard and controller focus")
    var map_key := InputEventKey.new()
    map_key.keycode = KEY_M
    map_key.physical_keycode = KEY_M
    map_key.pressed = true
    ui._input(map_key)
    Input.action_press("map")
    world._process(0.0)
    Input.action_release("map")
    tree.check(world.active_overlay == "backpack" and dialog.visible, "registered source modal blocks gameplay and map shortcuts behind the reader")
    var sources := SOURCES.links(origin_key, items, flags)
    tree.check(dialog.rows.size() == sources.size() and dialog.body.text == ui._journal_presentation(sources[0].entry).text and not dialog.body.bbcode_enabled, "the reader displays the exact existing public source text as literal text")
    var original_font: Variant = ui.accessibility.get("subtitle_size", 21)
    tree.check(dialog.body.get_theme_font_size("normal_font_size") == clampi(int(original_font), 17, 26), "the source reader uses the existing accessible reading size")
    dialog.next.pressed.emit()
    tree.check(dialog.body.text == ui._journal_presentation(sources[1].entry).text, "next source opens the independent original testimony rather than a rewritten summary")
    dialog.previous.pressed.emit()
    tree.check(dialog.chooser.selected == 0, "previous source returns to its matching selector item")
    dialog.previous.pressed.emit()
    tree.check(dialog.chooser.selected == sources.size() - 1, "source navigation wraps backward inside its known source set")
    dialog.next.pressed.emit()
    tree.check(dialog.chooser.selected == 0, "source navigation wraps forward without leaving its original note")
    dialog.chooser.item_selected.emit(1)
    tree.check(dialog.chooser.selected == 1 and not dialog.heading.text.contains("testimony_"), "the native selector opens a localized known source")
    tree.check(ui.journal_current_document == original and is_equal_approx(ui.bag_description.get_v_scroll_bar().value, offset), "source traversal leaves the original document and scroll untouched")
    dialog.hide()
    dialog.confirmed.emit()
    await frames(tree)
    tree.check(ui.bag_pin.has_focus() and dialog.rows.is_empty() and dialog.body.text.is_empty(), "return clears detached sources and restores the original action focus")
    tree.check(filter_before == [ui.journal_filter, ui.journal_search.text, ui.journal_unread.button_pressed, ui.journal_stars.button_pressed, ui.journal_sort.selected], "return preserves category, search, unread, starred and sort preferences")
    ui.bag_pin.pressed.emit()
    world.inventory_counts[String(authored.evidence_all[0])] = 0
    dialog.select_source(1)
    tree.check(not dialog.visible and dialog.body.text.is_empty(), "a source removed while open cannot survive on a stale snapshot")
    world.inventory_counts = items.duplicate(true)
    ui.bag_pin.pressed.emit()
    var path: String = world.world_save_path
    world.world_save_path = path + ".other"
    dialog.select_source(0)
    tree.check(not dialog.visible, "switching journey scope invalidates a source callback before it renders")
    world.world_save_path = path
    ui.bag_pin.pressed.emit()
    ui.reading_session_generation += 1
    dialog.select_source(0)
    tree.check(not dialog.visible, "a retired reading session rejects callbacks from its previous generation")
    ui.bag_pin.pressed.emit()
    var quest: Dictionary = CONTACTS.narrative().quest_journal(items, flags)[0].merged({"record_kind": "quest"})
    ui._show_journal_record(quest)
    tree.check(not dialog.visible and ui.bag_pin.disabled, "selecting another ordinary record closes the source reader and disables unavailable links")
    var returns: Dictionary = RETURNS.records(items, flags)[0]
    ui._show_journal_record(returns)
    ui.bag_pin.pressed.emit()
    tree.check(dialog.visible and dialog.body.text.contains("温室西门"), "the ending guide opens the existing quest record with its saved migrated contact")
    ui.bag_category = "材料"
    ui.refresh_inventory()
    tree.check(not dialog.visible, "switching to ordinary inventory closes the detached source reader")
    ui.bag_category = "旅记"
    ui._show_journal_record(returns)
    ui.bag_pin.pressed.emit()
    var proof: Dictionary = CONTACTS.narrative().evaluate_evidence(items, flags).entries.filter(func(row): return row.id == "testimony_01")[0].merged({"record_kind": "evidence"})
    ui._show_journal_record(proof)
    ui.bag_pin.pressed.emit()
    var partner: Dictionary = CONTACTS.narrative().evaluate_evidence(items, flags).entries.filter(func(row): return row.id == "testimony_03")[0].merged({"record_kind": "evidence"})
    tree.check(dialog.visible and dialog.rows.size() == 1 and dialog.body.text == ui._journal_presentation(partner).text, "a real testimony cross-reading opens the exact possessed partner original without adding an independent proof")
    world._close_overlays()
    tree.check(not dialog.visible, "closing the bag also retires the source popup")
    tree.check(world.story_flags == flags and world.inventory_counts == items and world.currency_count == wallet and FileAccess.get_file_as_bytes(world.world_save_path) == disk, "the complete live source flow preserves progress, rewards, possessions and checkpoint bytes")
    tree.check(ui.journal_catalog.profiles == profiles, "source reading never changes explicit read marks or stars")
