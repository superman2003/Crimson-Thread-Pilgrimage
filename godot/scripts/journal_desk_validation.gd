extends SceneTree
const CATALOG = preload("res://scripts/journal_catalog.gd")
const PREFS := "user://journal_desk_preferences.json"
var checks := 0
var failures: Array[String] = []
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:failures.append(label)

func run() -> void:
    DirAccess.remove_absolute(ProjectSettings.globalize_path(PREFS))
    var catalog := CATALOG.new()
    catalog.path = PREFS
    catalog.configure("slot_one")
    var first: Dictionary = catalog.document("quest:lamp", "Amber 灯", "委托", "known copper bridge")
    var second: Dictionary = catalog.document("guide:heal", "疗伤", "手册", "恢复绯线")
    first["entry"] = {"hidden_missing": [{"label": "绝密镜塔", "hint": "secret-location-987"}]}
    var docs: Array = [first, second]
    check(not catalog.is_read(first) and not catalog.is_starred(first.key), "new reading preferences start empty")
    check(catalog.filter_documents(docs, "AMBER copper", false, false).size() == 1, "search combines case-insensitive tokens across visible title and body")
    check(catalog.filter_documents(docs, "绝密镜塔", false, false).is_empty() and catalog.filter_documents(docs, "secret-location-987", false, false).is_empty(), "backing hidden fields never participate in search")
    var original: Dictionary = catalog.profiles.duplicate(true)
    check(catalog.filter_documents(docs, "无结果", false, false).is_empty() and catalog.profiles == original, "search is read-only even when nothing matches")
    check(catalog.mark_read(first, true).persisted and catalog.is_read(first), "explicit reading mark writes its content fingerprint")
    check(catalog.toggle_star(first.key).persisted and catalog.is_starred(first.key), "explicit favorite is saved independently")
    check(catalog.filter_documents(docs, "", true, false) == [second], "unread filter excludes only explicitly read content")
    check(catalog.filter_documents(docs, "", false, true) == [first], "favorite filter only exposes known matching documents")
    check(catalog.filter_documents(docs, "", false, false, 2)[0].key == second.key, "unread-first ordering uses actual reading state")
    var changed: Dictionary = catalog.document(first.key, first.title, "委托", "new phase with a different known objective")
    check(not catalog.is_read(changed), "changed quest content becomes unread without discarding its favorite")
    var restarted := CATALOG.new()
    restarted.path = PREFS
    restarted.configure("slot_one")
    check(restarted.is_read(first) and restarted.is_starred(first.key), "new reader instance restores actual on-disk marks")
    restarted.configure("slot_two")
    check(not restarted.is_read(first) and not restarted.is_starred(first.key), "different save-slot paths isolate reading preferences")
    restarted.configure("slot_one")
    check(restarted.is_read(first), "switching back recovers the original slot preferences")
    var serialized := FileAccess.get_file_as_string(PREFS)
    check(not serialized.contains("copper bridge") and not serialized.contains("secret-location-987"), "preferences contain IDs and fingerprints, not journal or secret text")
    check(catalog.mark_read(first, false).persisted and not catalog.is_read(first), "read state can be explicitly reversed")
    check(catalog.toggle_star(first.key).persisted and not catalog.is_starred(first.key), "favorite can be explicitly removed")
    var bounded := CATALOG.new()
    bounded.configure("bounded")
    bounded.writer = func(_data: Dictionary):return OK
    for index in 260:bounded.mark_read(bounded.document("guide:" + str(index), "t", "c", "body"), true)
    check(bounded.profiles[bounded.scope].read.size() == 256 and not bounded.profiles[bounded.scope].read.has("guide:0"), "read history evicts oldest fingerprints at its memory bound")
    for index in 64:bounded.toggle_star("guide:" + str(index))
    check(bounded.profiles[bounded.scope].stars.size()==64, "favorites fill their supported capacity")
    check(not bounded.toggle_star("guide:65").ok and bounded.profiles[bounded.scope].stars.size() == 64, "favorite overflow is explained rather than silently discarding a mark")
    for index in 10:bounded.configure("profile" + str(index))
    check(bounded.profiles.size() == 8, "slot-profile storage has a fixed bound")
    var failed := CATALOG.new()
    failed.configure("failed")
    failed.writer = func(_data: Dictionary):return ERR_CANT_CREATE
    var failure: Dictionary = failed.mark_read(second, true)
    check(failure.ok and not failure.persisted and failed.is_read(second) and not failure.reason.is_empty(), "write failure retains session marks and reports persistence honestly")
    var malformed := CATALOG.new()
    malformed._load({"version": true, "profiles": {"a".repeat(64): {"read": {first.key: first.fingerprint}}}})
    check(malformed.profiles.is_empty(), "boolean schema version cannot masquerade as version one")
    malformed._load({"version": 1, "profiles": {"invalid": {}, "b".repeat(64): {"read": {"x": true}, "stars": [false, "valid", "valid"]}}})
    check(malformed.profiles.size() == 1 and malformed.profiles["b".repeat(64)].read.is_empty() and malformed.profiles["b".repeat(64)].stars == ["valid"], "malformed preference entries are bounded, typed and deduplicated")
    var corrupt := FileAccess.open(PREFS + ".bad", FileAccess.WRITE)
    corrupt.store_string("{ invalid json");corrupt.close()
    malformed = CATALOG.new();malformed.path = PREFS + ".bad";malformed.configure("fresh")
    check(malformed.profiles[malformed.scope].read.is_empty(), "corrupt preference JSON does not block journal startup")

    var main: Node = load("res://scenes/World.tscn").instantiate()
    main.world_resume = false
    main.world_save_path = "user://journal_desk_world.json"
    root.add_child(main)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(main)
    main.set_process(false)
    main.player.set_physics_process(false)
    for enemy in get_nodes_in_group("enemy"):enemy.set_physics_process(false)
    var ui: Control = main.ui_shell
    ui.journal_preferences_path = PREFS + ".world"
    main._toggle_backpack();ui.bag_category = "旅记";ui.refresh_inventory()
    await process_frame
    await process_frame
    main._process(0.0) # settle the first normal room/hint publication before read-only UI checks
    var before_wallet: Dictionary = main._build_wallet_snapshot()
    var before_flags: Dictionary = main.story_flags.duplicate(true)
    var before_build: Dictionary = main.build_system.serialize()
    check(ui.journal_documents.size() >= 5 and ui.journal_tools.visible, "real World journal exposes known teaching and story documents with its toolbar")
    var panel := Rect2(Vector2.ZERO, ui.bag.size)
    print("JOURNAL_DESK_BOUNDS panel=",panel," tools=",ui.journal_tools.get_rect()," read=",ui.journal_mark_button.get_rect()," star=",ui.journal_star_button.get_rect())
    check(panel.encloses(ui.journal_tools.get_rect()) and panel.encloses(ui.journal_mark_button.get_rect()) and panel.encloses(ui.journal_star_button.get_rect()), "search and reading controls stay within production panel bounds")
    ui.journal_search.grab_focus();ui.journal_search.text = "疗伤";ui.journal_search.text_changed.emit(ui.journal_search.text)
    check(ui.bag_grid.get_child_count() > 0 and ui.journal_search.has_focus(), "typing filters real known records without stealing search focus")
    ui.journal_search.text = "未获绝密地点987";ui.journal_search.text_changed.emit(ui.journal_search.text)
    check(ui.bag_grid.get_child_count() == 0 and ui.journal_mark_button.disabled and ui.bag_name.text.contains("筛选"), "empty known-only search gives a clear recovery state and no stale actions")
    ui.journal_search.text = "";ui.journal_search.text_changed.emit("")
    var read_key := String(ui.journal_current_document.key)
    ui.journal_mark_button.pressed.emit()
    check(ui.journal_catalog.profiles[ui.journal_catalog.scope].read.has(read_key), "real reading action updates the slot preference rather than story flags")
    ui.journal_star_button.pressed.emit();ui.journal_stars.button_pressed = true
    check(ui.bag_grid.get_child_count() == 1 and ui.journal_catalog.is_starred(read_key), "real favorites filter follows the marked record identity")
    ui.journal_unread.button_pressed = true
    check(ui.bag_grid.get_child_count() == 0, "combined unread and favorites filters intersect correctly")
    ui.journal_unread.button_pressed = false;ui.journal_stars.button_pressed = false
    ui.journal_search.grab_focus()
    var letter := InputEventKey.new();letter.physical_keycode = KEY_B;letter.keycode = KEY_B;letter.unicode = 98;letter.pressed = true
    ui._input(letter)
    check(main.active_overlay == "backpack", "text field consumes build-hotkey letters as text")
    Input.action_press("map");main._process(0.0);Input.action_release("map")
    check(main.active_overlay == "backpack", "polled map shortcut cannot steal a typing journal")
    print("JOURNAL_DESK_IMMUTABLE wallet=",main._build_wallet_snapshot()==before_wallet," flags=",main.story_flags==before_flags," build=",main.build_system.serialize()==before_build)
    check(main._build_wallet_snapshot() == before_wallet and main.story_flags == before_flags and main.build_system.serialize() == before_build, "search reading favorites and typing leave all gameplay progress unchanged")
    ui.bag_category = "材料";ui.refresh_inventory()
    check(not ui.journal_tools.visible and not ui.journal_mark_button.visible, "inventory categories retain their original layout without journal controls")
    var retirement:=preload("res://scripts/audio_retirement.gd")
    retirement.retire_tree(main)
    main.free()
    await process_frame
    preload("res://scripts/audio_director.gd")._stream_cache.clear()
    preload("res://scripts/audio_director.gd")._npc_voice_cache.clear()
    check(await retirement.drain(self),"fixture releases its actual World audio owners before exit")
    for suffix in ["", ".tmp", ".bad", ".world", ".world.tmp"]:DirAccess.remove_absolute(ProjectSettings.globalize_path(PREFS + suffix))
    if failures.is_empty():print("JOURNAL_DESK checks=%d failures=0" % checks)
    else:
        for item in failures:push_error(item)
    quit(0 if failures.is_empty() else 1)
