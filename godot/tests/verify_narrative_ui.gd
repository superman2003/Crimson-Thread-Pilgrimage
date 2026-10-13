extends SceneTree
const Main = preload("res://scripts/main_level.gd")
var failures := 0
func _initialize() -> void:
    call_deferred("run")
func check(ok: bool, description: String) -> void:
    if not ok:
        failures += 1
        push_error(description)

func resident_npc(main: Node, npc_id: String) -> Area2D:
    var authored: Dictionary = {}
    for value in main.config.get("npcs", []):
        if String(value.get("id", "")) == npc_id:
            authored = value
            break
    check(not authored.is_empty(), "NPC fixture exists in authored region " + npc_id)
    if authored.is_empty():
        return null
    var point := Vector2(float(authored.position[0]), float(authored.position[1]))
    point = main._world_npc_residency_position(npc_id, point)
    var prior_mode: int = main.process_mode
    var prior_physics: bool = main.player.is_physics_processing()
    var paused_enemies: Array[Dictionary] = []
    for enemy in main.get_tree().get_nodes_in_group("enemy"):
        if is_instance_valid(enemy):
            paused_enemies.append({"node": enemy, "mode": enemy.process_mode})
            enemy.process_mode = Node.PROCESS_MODE_DISABLED
    main.process_mode = Node.PROCESS_MODE_ALWAYS
    main.player.set_physics_process(false)
    main.player.velocity = Vector2.ZERO
    main.player.global_position = main.to_global(point)
    for frame in range(120):
        await process_frame
        var npc := main.get_node_or_null(NodePath(npc_id)) as Area2D
        var snapshot: Dictionary = main.world_gameplay_residency.snapshot()
        if is_instance_valid(npc) and npc.is_inside_tree() and npc.get_parent() == main and String(npc.get_meta("npc_id", "")) == npc_id and main.player.global_position.distance_to(npc.global_position) <= 190.0 and bool(snapshot.window_ready) and int(snapshot.pending_build) == 0:
            main.player.set_physics_process(prior_physics)
            main.process_mode = prior_mode
            for paused in paused_enemies:
                if is_instance_valid(paused.node): paused.node.process_mode = int(paused.mode)
            return npc
    main.player.set_physics_process(prior_physics)
    main.process_mode = prior_mode
    for paused in paused_enemies:
        if is_instance_valid(paused.node): paused.node.process_mode = int(paused.mode)
    check(false, "moving the test player into the active window constructs the requested NPC " + npc_id)
    return null

func press_f() -> void:
    var event := InputEventKey.new()
    event.physical_keycode = KEY_F
    event.keycode = KEY_F
    event.pressed = true
    Input.parse_input_event(event)
    await create_timer(0.03).timeout
    event = InputEventKey.new()
    event.physical_keycode = KEY_F
    event.keycode = KEY_F
    event.pressed = false
    Input.parse_input_event(event)
    await create_timer(0.03).timeout
func run() -> void:
    var main := Main.new()
    main.world_mode = true
    main.world_save_path = "user://verify_narrative_ui.json"
    main.world_resume = false
    root.add_child(main)
    main.set_physics_process(false)
    main.player.set_physics_process(false)
    for enemy in get_nodes_in_group("enemy"):
        enemy.set_physics_process(false)
    check(main.get_node_or_null("npc_gate_pilgrim") == null, "remote ordinary pilgrim remains deferred outside the arrival window")
    var npc: Area2D = await resident_npc(main, "npc_threadsmith_apprentice")
    if not is_instance_valid(npc):
        main.free()
        quit(1)
        return
    main.player.global_position = npc.global_position
    main.nearby_interactable = npc
    await press_f()
    check(main.active_overlay == "dialogue", "Physical interact opens actual dialogue")
    check(main.dialogue_text_label.visible_characters < main.dialogue_text_label.text.length(), "Subtitle begins partially revealed")
    main._close_overlays()
    check(not main.story_flags.has("quest_bring_names_started"), "Closing unread first sentence does not accept quest")
    main.nearby_interactable = npc
    await press_f()
    check(int(npc.get_meta("world_displayed_index", -1)) == 0, "Reopening interrupted dialogue restarts its full round")
    main._close_overlays()
    # Three fast close/open cycles must never reach the quest-completing last sentence.
    for attempt in 3:
        main.nearby_interactable = npc
        await press_f()
        main._close_overlays()
    check(not main.story_flags.has("quest_bring_names_started"), "Interrupted sessions cannot manufacture a complete round")
    main.nearby_interactable = npc
    await press_f()
    for line in 3:
        await press_f() # first F finishes the currently typing subtitle
        if line < 2:
            await press_f() # next F advances it
    main._close_overlays()
    check(bool(main.story_flags.get("quest_bring_names_started", false)), "Real F presses through full round accept quest")
    # Button callbacks use the same reveal/commit path as physical F.
    main.story_flags.erase("quest_bring_names_started")
    npc.set_meta("dialogue_state_indices", {})
    main.nearby_interactable = npc
    await press_f()
    var continue_button: Button
    for child in main.ui_shell.dialogue.get_children():
        if child is Button and child.text == "继续交谈":
            continue_button = child
    check(continue_button != null, "Visible continue button exists")
    continue_button.pressed.emit()
    check(int(npc.get_meta("world_displayed_index")) == 0, "Mouse click reveals text before advancing")
    await process_frame
    continue_button.pressed.emit()
    check(int(npc.get_meta("world_displayed_index")) == 1, "Second mouse click advances committed sentence")
    main._close_overlays()
    check(not main.story_flags.has("quest_bring_names_started"), "Partial mouse round grants no quest")
    # Topic substitution on an unread final sentence cannot impersonate its evidence.
    npc.set_meta("dialogue_state_indices", {"names_request": 2})
    main._talk_to_npc(npc)
    main.ui_shell._topic("route")
    main.dialogue_text_label.visible_characters = -1
    main._close_overlays()
    check(not main.story_flags.has("quest_bring_names_started"), "Route topic cannot complete an unread story sentence")
    # Generic hand-in is persisted after both consumption and reward have completed.
    var topics: Dictionary = npc.get_meta("dialogue_topics", {}).duplicate(true)
    topics["quest"] = {"item":"test_supply", "complete_flag":"test_handin", "consume":true, "reward":"energy_spindle"}
    npc.set_meta("dialogue_topics", topics)
    main.inventory_counts["test_supply"] = 1
    main._talk_to_npc(npc)
    main.ui_shell._topic("wish")
    check(not main.inventory_counts.has("test_supply") and main.inventory_counts.has("energy_spindle"), "Hand-in consumes supply and gives reward")
    var restored = preload("res://scripts/world_state.gd").new()
    check(restored.read(main.world_save_path), "Hand-in transaction saves readable world")
    check(bool(restored.data.story_flags.get("test_handin", false)), "Saved transaction includes completed hand-in")
    check(not restored.data.inventory_counts.has("test_supply") and restored.data.inventory_counts.has("energy_spindle"), "Saved transaction contains final inventory")
    check(main.dialogue_panel.visible, "Exit fixture leaves NPC dialogue open for the real interactable-exit callback")
    # Freeing the level emits Area2D body_exited while the scene tree is
    # tearing down. Closing dialogue there must not attach or play audio in
    # the middle of tree notifications.
    main.free()
    for suffix in ["", ".bak", ".tmp"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path("user://verify_narrative_ui.json" + suffix))
    await process_frame
    print("Narrative UI failures: %d" % failures)
    quit(1 if failures else 0)
