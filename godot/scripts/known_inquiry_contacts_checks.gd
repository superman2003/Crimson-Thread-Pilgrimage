extends RefCounted
const FOLLOWUPS := preload("res://scripts/known_inquiry_contacts.gd")
const INQUIRIES := preload("res://scripts/narrative_inquiries.gd")
const MEMORY := preload("res://scripts/npc_recollections.gd")
const SOURCES := preload("res://scripts/journal_sources.gd")
const STATE := preload("res://scripts/world_state.gd")
const GRANT := preload("res://scripts/inquiry_source_notes_checks.gd")

func acquaintance(npc: String) -> String:
    var home: Dictionary = FOLLOWUPS.catalog().homes[npc]
    for state in MEMORY.catalog()[npc].states:
        if state.get("region") == home.region and String(state.id).ends_with(":fallback"):
            return MEMORY.identity(npc, state, String(home.region))
    return ""

func question(rows: Array, id: String) -> Dictionary:
    for row in rows:
        for value in row.questions:
            if value.id == id:
                return value
    return {}

func pure(tree: SceneTree) -> void:
    var grant := GRANT.new()
    var data := FOLLOWUPS.catalog()
    tree.check(FOLLOWUPS.valid(data) and data.homes.size() == 25, "follow-up destinations cover exactly the shipped speakers")
    tree.check(FOLLOWUPS.records({}, {}).is_empty(), "new journeys do not reveal future speakers or locked question counts")
    var visited := {}
    var expanded_cases := 0
    for entry in INQUIRIES.catalog():
        var items := {}
        var flags := {}
        grant.grant(entry.requires, items, flags)
        if entry.has("continuation"):
            grant.grant(entry.continuation.requires, items, flags)
        var quote := INQUIRIES.quote(entry, items, flags)
        tree.check(not quote.is_empty(), "authored current question fixtures satisfy the production evaluator")
        tree.check(FOLLOWUPS.rows(items, flags).is_empty(), "possessing every question material cannot introduce an unmet person")
        var met := acquaintance(String(entry.npc))
        tree.check(not met.is_empty(), "each known-person fixture uses an exact published local conversation identity")
        flags[met] = true
        var before := [items.duplicate(true), flags.duplicate(true)]
        var rows := FOLLOWUPS.rows(items, flags)
        var visible := question(rows, String(entry.id))
        tree.check(not visible.is_empty() and visible.question == entry.question, "all eligible current questions can point back to their actually known speaker")
        tree.check(rows.size() == 1 and rows[0].npc == entry.npc and not visible.has("lines") and not visible.has("requires"), "guidance discloses neither an unknown speaker nor the unheard answer or its hidden requirements")
        tree.check(before == [items, flags], "looking up a possible follow-up changes no materials or confirmation markers")
        flags[String(quote.marker)] = true
        tree.check(question(FOLLOWUPS.rows(items, flags), String(entry.id)).is_empty(), "confirmed current answers retire their own optional reminder")
        visited[String(entry.npc)] = true
        if entry.has("continuation"):
            var base_entry: Dictionary = entry.duplicate(true)
            base_entry.erase("continuation")
            var base := INQUIRIES.quote(base_entry, items, flags)
            var old := flags.duplicate(true)
            old.erase(String(quote.marker))
            old[String(base.marker)] = true
            var followup := question(FOLLOWUPS.rows(items, old), String(entry.id))
            tree.check(not followup.is_empty() and followup.expanded and followup.label == "有新线索可续问", "a heard base plus new materials identifies an unrecorded expansion without inventing its words")
            expanded_cases += 1
    tree.check(visited.size() == 25 and expanded_cases > 0, "known follow-up coverage reaches all twenty-five speakers and expanded answers")
    var entry := INQUIRIES.find("chapter_04_07")
    var items := {}
    var flags := {}
    grant.grant(entry.requires, items, flags)
    flags[acquaintance("npc_root_prisoner")] = true
    tree.check(FOLLOWUPS.location("npc_root_prisoner", flags).room == "root_vault", "without a saved relocation the rescue contact remains at the real root vault")
    flags["npc_root_prisoner_at_west_gate"] = true
    tree.check(FOLLOWUPS.location("npc_root_prisoner", flags).room == "west_gate", "the saved rescue migration moves every eligible follow-up to west gate")
    flags["npc_root_prisoner_at_west_gate"] = "true"
    tree.check(FOLLOWUPS.location("npc_root_prisoner", flags).room == "root_vault", "malformed relocation cannot invent a moved speaker")
    tree.check(FOLLOWUPS.location("npc_deserter_flagbearer", {"npc_deserter_at_camp": true}).room == "pilgrim_camp", "the second migrated speaker follows his saved camp destination")
    tree.check(FOLLOWUPS.location("npc_deserter_flagbearer", {}).room == "war_graves", "an unfinished flagbearer move does not fabricate camp residency")
    flags["npc_root_prisoner_at_west_gate"] = true
    var records := FOLLOWUPS.records(items, flags)
    tree.check(not records.is_empty(), "a known rescued speaker still has a supported optional question")
    if not records.is_empty():
        var links := SOURCES.links("guide:" + String(records[0].id), items, flags)
        tree.check(links.size() == 1 and links[0].entry.record_kind == "people", "the optional reminder cites a genuinely heard conversation instead of its unread question")
    var quote := INQUIRIES.quote(entry, items, flags)
    var inquiry_only := {String(quote.marker): true}
    tree.check(FOLLOWUPS.known(inquiry_only).has("npc_root_prisoner"), "a saved inquiry proves acquaintance even without finishing the ordinary dialogue")
    tree.check(FOLLOWUPS.records(items, JSON.parse_string(JSON.stringify(flags))) == records, "JSON restoration preserves current contacts without a new save schema")
    var before_move := flags.duplicate(true)
    before_move.erase("npc_root_prisoner_at_west_gate")
    before_move["quest_root_rescue_complete"] = true
    before_move["reward_root_rescue_claimed"] = true
    tree.check(FOLLOWUPS.location("npc_root_prisoner", before_move).room == "root_vault", "completing and paying a quest alone cannot invent an unsaved relocation")
    var old_page: Dictionary = FOLLOWUPS.records(items, before_move)[0]
    var moved_page: Dictionary = records[0]
    tree.check(old_page.id == moved_page.id and old_page.description != moved_page.description, "saved migration updates one stable known-person reminder instead of making another task")
    var reading := preload("res://scripts/journal_catalog.gd").new()
    reading.writer = func(_data): return OK
    reading.configure("known-contact-migration-isolated")
    var old_document: Dictionary = reading.document("guide:" + String(old_page.id), String(old_page.title), String(old_page.guide_context), String(old_page.description))
    var new_document: Dictionary = reading.document("guide:" + String(moved_page.id), String(moved_page.title), String(moved_page.guide_context), String(moved_page.description))
    tree.check(reading.mark_read(old_document, true).ok and reading.is_read(old_document), "explicit reading marks the exact old destination wording")
    tree.check(not reading.is_read(new_document), "a newly saved destination is not hidden behind an older read fingerprint")
    var all_read := flags.duplicate(true)
    for topic in INQUIRIES.catalog():
        if topic.npc != "npc_root_prisoner":
            continue
        var ready := INQUIRIES.quote(topic, items, flags)
        if not ready.is_empty():
            all_read[String(ready.marker)] = true
    tree.check(not FOLLOWUPS.rows(items, all_read).any(func(row): return row.npc == "npc_root_prisoner"), "a known person with no eligible unread answer produces no empty checklist")
    for invalid in [1, "true", false]:
        tree.check(FOLLOWUPS.known({acquaintance("npc_root_prisoner"): invalid}).is_empty(), "acquaintance requires an actual boolean committed memory")
    var unintroduced := {"npc_met_npc_root_prisoner": true, "seen_npc_root_prisoner": true}
    tree.check(FOLLOWUPS.rows(items, unintroduced).is_empty(), "unverified met/seen names cannot introduce a speaker without a committed conversation")
    for source in entry.requires:
        if source.kind != "item":
            continue
        for invalid in [0, -1, 0.5, true, "1", INF, NAN, 1000001]:
            var malformed := items.duplicate(true)
            malformed[String(source.id)] = invalid
            var stale := flags.duplicate(true)
            stale["evidence_known_" + String(source.id)] = true
            stale["evidence_read_" + String(source.id)] = true
            tree.check(question(FOLLOWUPS.rows(malformed, stale), String(entry.id)).is_empty(), "malformed ownership and remembered material labels cannot advertise an ineligible question")
    tree.check(FOLLOWUPS.location("unknown_person", flags).is_empty(), "unknown people have no inferred destination")
    tree.check(FOLLOWUPS.known({MEMORY.PREFIX + "forged": true}).is_empty(), "a forged acquaintance hash is not a shipped speaker")
    for invalid in [null, [], true, {"version": true, "homes": {}}, {"version": 1, "homes": {}}]:
        tree.check(not FOLLOWUPS.valid(invalid), "invalid contact envelopes do not become a partial public roster")
    var changed := FOLLOWUPS.catalog()
    changed.homes.npc_root_prisoner.region = "demo_ch01_moss_bell_court"
    tree.check(not FOLLOWUPS.valid(changed), "a valid room in another region cannot reassign a known person")
    changed = FOLLOWUPS.catalog()
    changed.homes.npc_root_prisoner["grant_flags"] = ["fake"]
    tree.check(not FOLLOWUPS.valid(changed), "contact presentation data cannot gain a progress side effect")
    if not records.is_empty():
        var detached := records.duplicate(true)
        detached[0].journal_source_keys.clear()
        detached[0].description = "mutated"
        tree.check(FOLLOWUPS.records(items, flags) == records, "caller changes to a public reminder cannot rewrite a later reminder")
        tree.check(not String(records[0].description).contains("npc_") and not String(records[0].description).contains("demo_"), "optional reminders expose localized people and places instead of internal identities")
    var snapshot := FOLLOWUPS.catalog()
    snapshot.homes.npc_root_prisoner.room = "future_room"
    tree.check(not FOLLOWUPS.valid(snapshot) and FOLLOWUPS.valid(FOLLOWUPS.catalog()), "a malformed destination fails without poisoning the cached location catalogue")

func live(tree: SceneTree, world: Node) -> void:
    # Compare the authored static homes with Main's actual nested-room resolver.
    var original_config: Dictionary = world.config
    for region in FOLLOWUPS.REGIONS:
        var chapter: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + String(region) + ".json"))
        world.config = chapter
        for npc in chapter.npcs:
            var point := Vector2(float(npc.position[0]), float(npc.position[1]))
            var actual: Dictionary = world._room_for_position(point)
            tree.check(String(actual.get("id", "")) == FOLLOWUPS.catalog().homes[npc.id].room, "all twenty-five authored speaker homes match production nested-room priority")
    for migration in [
        {"npc": "npc_root_prisoner", "region": "demo_ch04_broken_string_greenhouse", "flag": "npc_root_prisoner_at_west_gate"},
        {"npc": "npc_deserter_flagbearer", "region": "demo_ch05_obsidian_pilgrim_road", "flag": "npc_deserter_at_camp"}
    ]:
        world.config = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + String(migration.region) + ".json"))
        var moved := {String(migration.flag): true}
        var actual_state: Dictionary = world.world_narrative.npc_world_state(String(migration.npc), moved)
        var position: Array = actual_state.get("position", [])
        tree.check(position.size() == 2, "both saved migrations have an authored production position")
        if position.size() == 2:
            var actual: Dictionary = world._room_for_position(Vector2(float(position[0]), float(position[1])))
            tree.check(FOLLOWUPS.location(String(migration.npc), moved).room == actual.get("id"), "migrated follow-up rooms agree with the production actor's actual saved position")
    world.config = original_config
    var flags: Dictionary = world.story_flags.duplicate(true)
    var items: Dictionary = world.inventory_counts.duplicate(true)
    var money: int = world.currency_count
    var disk := FileAccess.get_file_as_bytes(world.world_save_path)
    var rows := FOLLOWUPS.rows(items, flags)
    var root := rows.filter(func(row): return row.npc == "npc_root_prisoner")
    tree.check(root.size() == 1 and root[0].place.contains("温室西门"), "the actual rescued prisoner advertises supported follow-ups at the migrated west gate")
    if root.is_empty():
        return
    world._toggle_backpack()
    var ui: Control = world.ui_shell
    ui.bag_category = "旅记"
    ui.journal_filter = "guide"
    ui.journal_search.text = "根笼囚徒"
    ui.refresh_inventory()
    var found := false
    for button in ui.bag_grid.get_children():
        if button is Button and String(button.text).begins_with("回访 · 根笼囚徒"):
            button.pressed.emit()
            found = true
            break
    tree.check(found and ui.bag_category_label.text == "回访线索 · 已认识的人" and ui.bag_description.text.contains("温室西门"), "the actual production journal button explains optional questions and the correct saved destination")
    ui.bag_pin.pressed.emit()
    tree.check(ui.journal_source_dialog.visible and ui.journal_source_dialog.body.text.contains("与你交谈过的话"), "the reminder opens the actual prior rescue conversation as its acquaintance source")
    world._close_overlays()
    tree.check(world.story_flags == flags and world.inventory_counts == items and world.currency_count == money and FileAccess.get_file_as_bytes(world.world_save_path) == disk, "reading the reminder and acquaintance source never confirms a new answer")
    var singer_rows := rows.filter(func(row): return row.npc == "npc_broken_singer")
    tree.check(singer_rows.size() == 1 and not singer_rows[0].questions.is_empty(), "the actually known singer has another eligible unrecorded question")
    if singer_rows.is_empty() or singer_rows[0].questions.is_empty():
        return
    var id := String(singer_rows[0].questions[0].id)
    var singer: Area2D = await tree.resident_npc(world, "npc_broken_singer")
    if not is_instance_valid(singer):
        return
    world._talk_to_npc(singer)
    ui._open_narrative_inquiries()
    var desk: AcceptDialog = ui.narrative_inquiry_desk
    desk._select(id)
    var quoted := INQUIRIES.quote(INQUIRIES.find(id), world.inventory_counts, world.story_flags)
    for unused in quoted.lines.size():
        desk._advance()
    tree.check(world.story_flags.get(quoted.marker, false) and question(FOLLOWUPS.rows(world.inventory_counts, world.story_flags), id).is_empty(), "only completing the actual new inquiry removes its real follow-up reminder")
    var restored := STATE.new()
    tree.check(restored.read(world.world_save_path) and question(FOLLOWUPS.rows(restored.data.inventory_counts, restored.data.story_flags), id).is_empty(), "the retired reminder stays retired after reading the actual World checkpoint")
    tree.check(world.currency_count == money and world.inventory_counts == items, "a new answered follow-up neither pays nor consumes its source materials")
    desk.hide()
    world._close_overlays()
