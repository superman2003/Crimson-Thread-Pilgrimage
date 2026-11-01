extends "res://journey/tests/support.gd"
const RECORDS := preload("res://journey/fieldwork/records.gd")
const K := preload("res://journey/fieldwork/knowledge.gd")
const V := preload("res://journey/fieldwork/scalars.gd")


func field_fixture(name: String) -> RefCounted:
    var context := fixture(name)
    context.latest.timestamp = 1700000000
    context.latest.wallet = 1000
    var mappings := {
        "move_left": KEY_A,
        "move_right": KEY_D,
        "jump": KEY_SPACE,
        "attack": KEY_J,
        "heal": KEY_Q,
        "interact": KEY_F,
        "aim_up": KEY_W,
        "aim_down": KEY_S,
        "dash": KEY_K,
        "hook": KEY_L,
        "skill_1": KEY_U,
        "bell_guard": KEY_H,
        "crown_resonance": KEY_R,
        "lantern_phase": KEY_C
    }
    for id in mappings:
        if not InputMap.has_action(id):
            InputMap.add_action(id)
            var event := InputEventKey.new()
            event.physical_keycode = int(mappings[id])
            InputMap.action_add_event(id, event)
    var visits := {}
    var shortcuts := {}
    for room in context.latest.config.get("map_rooms", []).slice(0, 6):
        visits[room.id] = true
    for link in context.latest.config.get("connections", []):
        if link.has("shortcut_id"):
            shortcuts[String(link.shortcut_id)] = true
    context.latest.regions = {REGION: {"visited_rooms": visits, "opened_shortcuts": shortcuts}}
    var first: Dictionary = context.latest.config.map_rooms[0]
    context.latest.room = first.id
    context.latest.player.position = V.pair(K.rectangle(first.layout_rect).get_center())
    for id in [
        "thread_dash",
        "echo_hook",
        "silk_wall_grip",
        "double_thread_jump",
        "bell_guard",
        "crown_resonance",
        "lantern_phase"
    ]:
        context.latest.inventory[id] = 1
    for npc in context.latest.config.get("npcs", []):
        context.latest.flags["npc_met_" + String(npc.id)] = true
    var build := BUILD.new()
    for group in ["skills", "tools", "passives", "crests"]:
        for entry in build.catalog[group].values():
            var item := String(entry.get("unlock_item", ""))
            if not item.is_empty():
                context.latest.inventory[item] = 1
    for recipe in build.catalog.recipes.values():
        for id in recipe.get("materials", {}):
            context.latest.inventory[id] = 100
        for id in recipe.get("requires_items", []):
            context.latest.inventory[id] = 1
        var flag := String(recipe.get("requires_flag", ""))
        if not flag.is_empty():
            context.latest.flags[flag] = true
        var artisan := String(recipe.get("artisan", ""))
        if not artisan.is_empty():
            context.latest.flags["npc_met_" + artisan] = true
    var combat := V.read_json("res://data/original_creature_combat.json")
    var added := 0
    for id in combat:
        if (
            combat[id] is Dictionary
            and combat[id].get("attacks") is Array
            and not combat[id].attacks.is_empty()
        ):
            context.latest.flags["journal_enemy_" + String(id)] = true
            added += 1
        if added == 2:
            break
    build.sync_progress(context.latest.inventory, REGION, context.latest.flags)
    context.latest.build_state = build.serialize()
    context.latest.build = build.get_snapshot(
        {"currency": context.latest.wallet, "inventory_counts": context.latest.inventory}
    )
    return context


func mapping_signature() -> String:
    var map := {}
    for action in InputMap.get_actions():
        var bindings := []
        for event in InputMap.action_get_events(action):
            bindings.append(event.as_text())
        map[String(action)] = {
            "bindings": bindings, "deadzone": InputMap.action_get_deadzone(action)
        }
    return V.fingerprint(map)


func exercise(
    context: RefCounted, domain: Script, feature_script: Script, key: String, required: String
) -> void:
    var before := V.fingerprint(context.latest)
    var inputs := mapping_signature()
    var payload: Dictionary = domain.capture(context.snapshot())
    check(domain.validate(payload), "captured domain schema")
    var roundtrip: Variant = V.parse_json(JSON.stringify(payload))
    check(
        roundtrip is Dictionary and domain.validate(roundtrip),
        "JSON representation retains domain schema"
    )
    var broken := payload.duplicate(true)
    broken.erase(required)
    check(not domain.validate(broken), "missing domain field rejected")
    var feature: RefCounted = feature_script.new()
    feature.setup(context)
    check(feature.valid(feature.data), "fresh module record schema")
    var box := node_container()
    feature.draw(box)
    check(box.get_child_count() > 5, "native current page is populated")
    UI.clear(box)
    feature.draft = payload.duplicate(true)
    feature.draft_title = "人工夹具观察 · " + key
    feature.tab = "editor"
    feature.draw(box)
    check(box.get_child_count() > 5, "native candidate editor is populated")
    context.store.writable = false
    feature._save_draft()
    check(
        feature.data.records.is_empty() and feature.selected_id == 0,
        "write failure cannot publish data or reserve a nonexistent id"
    )
    context.store.writable = true
    feature._save_draft()
    check(
        feature.data.records.size() == 1 and feature.selected_id == 1,
        "same candidate retries and saves successfully"
    )
    var persisted: Dictionary = context.store.read(String(feature.descriptor().id), RECORDS.fresh())
    check(
        feature.valid(persisted) and persisted.records.size() == 1, "actual auxiliary JSON readback"
    )
    feature.undo()
    check(feature.data.records.is_empty(), "undo publishes a validated auxiliary snapshot")
    feature.redo()
    check(feature.data.records.size() == 1, "redo restores the record through the same store")
    UI.clear(box)
    feature.tab = "records"
    feature.compare_id = 1
    feature.draw(box)
    check(box.get_child_count() > 5, "native library and comparison render")
    UI.clear(box)
    feature.tab = "transfer"
    feature.draw(box)
    check(box.get_child_count() > 5, "transfer or redacted share page renders")
    var raw := RECORDS.export_package(
        feature.data, String(feature.descriptor().id), context.store.scope
    )
    var parsed := RECORDS.import_package(
        raw, String(feature.descriptor().id), context.store.scope, domain.validate
    )
    check(parsed.ok, "same-feature same-scope import validates")
    check(
        not (
            RECORDS
            . import_package(raw, String(feature.descriptor().id), "foreign", domain.validate)
            . ok
        ),
        "foreign-slot import rejected"
    )
    var combined := RECORDS.merge(feature.data, parsed.data)
    check(
        combined.ok and combined.data.records.size() == 1, "semantic duplicate merge is idempotent"
    )
    if domain.has_method("svg"):
        var svg: String = domain.svg(payload)
        var xml := XMLParser.new()
        var status := xml.open_buffer(svg.to_utf8_buffer())
        check(status == OK and svg.begins_with("<svg"), "standalone SVG document opens")
        var reads := 0
        if status == OK:
            status = xml.read()
            while status == OK and reads < 20000:
                reads += 1
                status = xml.read()
        check(status == ERR_FILE_EOF and reads > 10, "SVG parses to a complete XML document")
        var capture := OS.get_environment("FIELDWORK_CAPTURE_DIR")
        if not capture.is_empty():
            DirAccess.make_dir_recursive_absolute(capture)
            var file := FileAccess.open(capture.path_join(key + ".svg"), FileAccess.WRITE)
            if file != null:
                file.store_string(svg)
                file.close()
    await process_frame
    await process_frame
    feature.shutdown()
    box.free()
    check(
        V.fingerprint(context.latest) == before,
        "all analysis and UI operations preserve live fixture data"
    )
    check(mapping_signature() == inputs, "analysis never rewrites InputMap")
