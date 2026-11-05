extends RefCounted
const TERMS := preload("res://scripts/known_world_terms.gd")
const PROOF := preload("res://scripts/testimony_sources.gd")
const SOURCES := preload("res://scripts/journal_sources.gd")
const CATALOG := preload("res://scripts/journal_catalog.gd")

func pure(tree: SceneTree) -> void:
    var data := TERMS.catalog()
    tree.check(TERMS.valid(data) and data.entries.size() == 8, "eight bounded concepts use only the existing independent testimonies")
    tree.check(TERMS.records({}).is_empty(), "a new journey has no invented glossary titles or definitions")
    var stages := 0
    for mask in 64:
        var items := {}
        for index in 6:
            if mask & (1 << index):
                items[PROOF.IDS[index]] = 1
        var before := items.duplicate(true)
        var records := TERMS.records(items)
        for term in data.entries:
            var expected := {}
            for stage in term.stages:
                var ready: bool = stage.evidence_all.all(func(id): return items.has(id))
                if ready:
                    expected = stage
            var public := records.filter(func(row): return row.id == TERMS.PREFIX + String(term.id))
            tree.check(public.is_empty() == expected.is_empty(), "all 64 evidence subsets withhold every unseen concept")
            if expected.is_empty():
                continue
            tree.check(public.size() == 1 and public[0].description.contains(expected.definition) and public[0].description.contains(expected.limit), "the most supported stage replaces its older explanation without duplicating a concept")
            tree.check(not public[0].has("stages") and not public[0].has("evidence_all"), "public glossary rows do not expose future definitions or hidden conditions")
            var links := SOURCES.links("guide:" + String(public[0].id), items, {})
            tree.check(links.map(func(row): return row.key) == public[0].journal_source_keys, "every visible concept opens exactly its current held originals")
        tree.check(items == before, "deriving terminology grants no progress or evidence")
        tree.check(TERMS.records(JSON.parse_string(JSON.stringify(items))) == records, "existing JSON inventory restores the same current understanding")
    for term in data.entries:
        stages += term.stages.size()
        for stage in term.stages:
            var items := {}
            for id in stage.evidence_all:
                items[String(id)] = 1
            for id in stage.evidence_all:
                for invalid in [true, "1", 0, -1, 0.5, INF, NAN, 1000001]:
                    var changed := items.duplicate(true)
                    changed[String(id)] = invalid
                    var public := TERMS.records(changed).filter(func(row): return row.id == TERMS.PREFIX + String(term.id))
                    tree.check(public.is_empty() or not public[0].description.contains(stage.definition), "malformed and absent possession cannot publish a later concept stage")
    tree.check(stages == 14, "six local concepts deepen through independent corroboration plus two collective concepts")
    var catalogue := CATALOG.new()
    catalogue.writer = func(_data): return OK
    catalogue.configure("known-terms-isolated")
    var early: Dictionary = TERMS.records({"testimony_01": 1})[0]
    var late: Dictionary = TERMS.records({"testimony_01": 1, "testimony_03": 1})[0]
    var old_doc: Dictionary = catalogue.document("guide:" + early.id, early.title, early.guide_context, early.description)
    var new_doc: Dictionary = catalogue.document("guide:" + late.id, late.title, late.guide_context, late.description)
    tree.check(catalogue.mark_read(old_doc, true).ok and catalogue.is_read(old_doc), "explicit reading marks the exact known wording")
    tree.check(old_doc.key == new_doc.key and not catalogue.is_read(new_doc), "new corroboration preserves concept identity while making changed text unread")
    var broken := data.duplicate(true)
    broken.entries[0].stages[1].evidence_all = ["testimony_03"]
    tree.check(not TERMS.valid(broken), "a later concept stage cannot forget an earlier required source")
    broken = data.duplicate(true)
    broken.entries[0].stages[0]["grant_flags"] = ["fake"]
    tree.check(not TERMS.valid(broken) and TERMS.valid(TERMS.catalog()), "presentation cannot introduce grants or poison its cached catalogue")

func live(tree: SceneTree, world: Node) -> void:
    world._close_overlays()
    world._toggle_backpack()
    var ui: Control = world.ui_shell
    ui.bag_category = "旅记"
    ui.journal_filter = "guide"
    ui.journal_search.text = "辞记"
    ui.journal_unread.button_pressed = false
    ui.journal_stars.button_pressed = false
    var flags: Dictionary = world.story_flags.duplicate(true)
    var items: Dictionary = world.inventory_counts.duplicate(true)
    var money: int = world.currency_count
    var disk := FileAccess.get_file_as_bytes(world.world_save_path)
    ui.refresh_inventory()
    for unused in 3:
        await tree.process_frame
    var expected := TERMS.records(items)
    var visible: Array = ui._journal_batch_documents()
    tree.check(not expected.is_empty() and visible.size() == expected.size() and visible.all(func(doc): return String(doc.key).begins_with("guide:" + TERMS.PREFIX)), "the production guide filter and search expose only currently supported terminology")
    if expected.is_empty():
        return
    ui._show_journal_record(expected[0])
    tree.check(ui.bag_category_label.text == "世界辞记 · 已有证词" and ui.bag_description.text.contains("仍不能据此断言"), "the live reader separates the supported definition from its remaining uncertainty")
    ui.bag_pin.pressed.emit()
    tree.check(ui.journal_source_dialog.visible and ui.journal_source_dialog.rows.size() == expected[0].journal_source_keys.size(), "a live concept opens the same original-source reader as other journal notes")
    ui.journal_source_dialog.select_source(0)
    world._close_overlays()
    tree.check(world.story_flags == flags and world.inventory_counts == items and world.currency_count == money and FileAccess.get_file_as_bytes(world.world_save_path) == disk, "reading the concept and its sources leaves the real World checkpoint unchanged")
