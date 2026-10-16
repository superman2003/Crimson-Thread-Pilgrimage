extends "res://tests/verify_narrative_runtime.gd"
## Reuses isolated save, real-NPC residency and dialogue helpers. Fixture
## placement verifies transactions and restoration, not natural traversal.

func run_checks() -> void:
    create_timer(120.0).timeout.connect(func():
        check(false, "Narrative return transactions timed out")
        quit(1))
    root.process_mode = Node.PROCESS_MODE_DISABLED
    cleanup_save()
    scene = await spawn("res://data/demo_ch04_broken_string_greenhouse.json")
    var prisoner: Area2D = await resident_npc(scene, "npc_root_prisoner")
    if not is_instance_valid(prisoner):
        scene.free()
        cleanup_save()
        quit(1)
        return
    scene._add_inventory_item("thorn_downstrike", 1, false)
    scene._save_world()
    var flags_before: Dictionary = scene.story_flags.duplicate(true)
    var world_before: Dictionary = scene.world_state.data.duplicate(true)
    var build_before: Dictionary = scene.build_system.serialize()
    var currency_before: int = scene.currency_count
    var position_before: Vector2 = prisoner.position
    scene.world_save_failure_injected_for_validation = true
    hear_round(prisoner)
    check(scene.story_flags == flags_before and scene.currency_count == currency_before, "failed dialogue save rolls back quest and currency")
    check(scene.world_state.data == world_before and scene.build_system.serialize() == build_before, "failed dialogue save rolls back shared snapshot and unlocks")
    check(prisoner.position == position_before, "failed rescue never moves the NPC")
    check(prisoner.get_meta("dialogue_state_indices", {}).get("root_rescued", 0) == 0, "failed dialogue does not advance the read cursor")
    scene.world_save_failure_injected_for_validation = false
    scene.world_save_blocked = true
    hear_round(prisoner)
    check(scene.story_flags == flags_before and scene.world_state.data == world_before, "blocked incompatible save cannot publish an in-memory quest commit")
    check(scene.currency_count == currency_before and prisoner.position == position_before, "blocked save grants no reward or migration")
    scene.world_save_blocked = false
    hear_round(prisoner)
    check(bool(scene.story_flags.get("quest_root_rescue_complete", false)), "retry completes the same rescue")
    check(scene.currency_count == currency_before + 45 and prisoner.position == Vector2(320, 1740), "successful save confirms one reward and migration")
    hear_round(prisoner)
    check(scene.currency_count == currency_before + 45, "repeat visit cannot pay again")
    scene.free()
    scene = await spawn("res://data/demo_ch04_broken_string_greenhouse.json", true)
    prisoner = await resident_npc(scene, "npc_root_prisoner")
    check(is_instance_valid(prisoner) and prisoner.position == Vector2(320, 1740), "restart restores committed migration")
    check(scene.currency_count == currency_before + 45, "restart restores reward exactly once")

    # Exercise the actual ending handler, with a fixture gate and final-boss
    # flag. No teleport is presented as a natural route or boss victory.
    scene.story_flags["boss_down_ch06"] = true
    scene._save_world()
    flags_before = scene.story_flags.duplicate(true)
    world_before = scene.world_state.data.duplicate(true)
    var gate := Area2D.new()
    gate.set_meta("ending", "ending_b")
    gate.set_meta("label", "断冠")
    gate.set_meta("message", "fixture must not replace authored conclusion")
    scene.add_child(gate)
    var old_win_text: String = scene.win_label.text
    var old_win_visible: bool = scene.win_label.visible
    scene.world_save_failure_injected_for_validation = true
    scene._activate_ending_gate(gate)
    check(scene.story_flags == flags_before and scene.world_state.data == world_before, "failed ending save leaves the choice and consequences uncommitted")
    check(scene.win_label.text == old_win_text and scene.win_label.visible == old_win_visible, "failed ending save presents no victory banner")
    scene.world_save_failure_injected_for_validation = false
    scene._activate_ending_gate(gate)
    check(scene.story_flags.get("ending_chosen", "") == "ending_b", "retry commits the requested ending")
    check(bool(scene.story_flags.get("world_crown_severed", false)) and not bool(scene.story_flags.get("world_bells_restored", false)), "ending commits only its world consequences")
    check(scene.win_label.visible and scene.win_label.text == scene.world_narrative.story_data.endings.ending_b.message, "confirmed ending displays authored conclusion")
    gate.set_meta("ending", "ending_a")
    scene._activate_ending_gate(gate)
    check(scene.story_flags.get("ending_chosen", "") == "ending_b", "another gate cannot replace the committed choice")
    scene.free()
    scene = await spawn("res://data/demo_ch04_broken_string_greenhouse.json", true)
    check(scene.story_flags.get("ending_chosen", "") == "ending_b" and bool(scene.story_flags.get("world_black_tide_uncontained", false)), "restart preserves selected ending and consequences")
    prisoner = await resident_npc(scene, "npc_root_prisoner")
    check(is_instance_valid(prisoner) and scene._resolve_npc_lines(prisoner) == scene.world_narrative.resolve("npc_root_prisoner", [], [], scene.story_flags, scene.inventory_counts).lines, "restored real NPC uses selected aftermath")

    # Journal surface consumes canonical records, using localized names and
    # scene witnesses instead of internal NPC keys or outdated pickup rooms.
    var evidence: Dictionary = scene.world_narrative.evaluate_progress({"testimony_02": 1, "testimony_03": 1}, {})
    var record: Dictionary = evidence.known_entries[0].duplicate(true)
    record["record_kind"] = "evidence"
    scene.ui_shell._show_journal_record(record)
    check(scene.ui_shell.bag_description.text.contains("场景印证") and scene.ui_shell.bag_description.text.contains("互证"), "real journal displays discovered scene context and cross-reading")
    var ending: Dictionary = scene.world_narrative.evaluate_ending("ending_b", {}, scene.story_flags)
    ending["record_kind"] = "ending"
    ending["chosen"] = true
    scene.ui_shell._show_journal_record(ending)
    check(not scene.ui_shell.bag_description.text.contains("npc_") and scene.ui_shell.bag_description.text.contains("灯影修女"), "real journal localizes consequence names")
    check(scene.ui_shell._ending_status_label({"status": "closed", "available": false}) == "已关闭", "closed branches are distinct from unfinished requirements")
    scene.free()
    cleanup_save()
    await process_frame
    print("NARRATIVE_RETURN_RUNTIME_PASS checks=%d failures=%d" % [checks, failures])
    quit(1 if failures else 0)
