extends "res://tests/verify_narrative_runtime.gd"
## Real UI/transactions with deliberate evidence and position fixtures.
## This does not claim a new-player playthrough or a natural final boss win.
const JOURNEY := preload("res://scripts/narrative_journey.gd")
const DESK := preload("res://scripts/ending_story_desk.gd")
const AUDIO := preload("res://scripts/audio_retirement.gd")
var permutations := 0

func permutations_check(prefix: Array, remaining: Array, narrative: RefCounted) -> void:
    if remaining.is_empty():
        permutations += 1
        var inventory := {}
        for id in prefix:
            inventory[id] = 1
            var rows := JOURNEY.reflections(inventory, {})
            for row in rows:
                var source: Dictionary = {}
                for value in JOURNEY.catalog().reflections:
                    if value.id == row.id:
                        source = value
                check(not source.is_empty(), "every synthesis has an authored source")
                for required in source.get("evidence_all", []):
                    check(int(inventory.get(required, 0)) > 0, "every discovery order withholds unseen evidence")
        check(narrative.evaluate_ending("ending_c", inventory, {"boss_down_ch06": true}).available, "each complete order still permits rewrite")
        return
    for id in remaining:
        var tail := remaining.duplicate()
        tail.erase(id)
        permutations_check(prefix + [id], tail, narrative)

func gate_for(id: String) -> Area2D:
    for child in scene.get_children():
        if child is Area2D and child.get_meta("kind", "") == "ending_gate" and child.get_meta("ending", "") == id:
            return child
    return null

func retire() -> void:
    scene._close_overlays()
    AUDIO.retire_tree(scene)
    scene.queue_free()
    for unused in 8:
        await process_frame

func capture(name: String) -> void:
    var destination := OS.get_environment("NARRATIVE_CLOSURE_CAPTURE_DIR")
    if destination.is_empty() or DisplayServer.get_name() == "headless":
        return
    DirAccess.make_dir_recursive_absolute(destination)
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(destination.path_join(name + ".png"))

func run_checks() -> void:
    create_timer(180.0).timeout.connect(func():
        check(false, "Narrative closure timed out")
        quit(1))
    root.process_mode = Node.PROCESS_MODE_DISABLED
    root.gui_embed_subwindows = true
    cleanup_save()
    var narrative := preload("res://scripts/world_narrative.gd").new()
    var canon: Dictionary = JOURNEY.catalog().canon
    check(canon.present_year - canon.hush_year == canon.silent_years, "one chronology is used")
    check(JOURNEY.reflections({}, {}).is_empty(), "new journey has no invented revelations")
    check(JOURNEY.reflections({"testimony_03": 0}, {"evidence_known_testimony_03": true}).is_empty(), "known or zero-count proof does not reveal synthesis")
    for bad in [-1, 0.5, true, "1", INF]:
        check(JOURNEY.reflections({"testimony_03": bad}, {}).is_empty(), "invalid evidence cannot invent a revelation")
    check(not JOURNEY.goal({}, {}).contains("世袭"), "opening goal preserves the central revelation")
    permutations_check([], ["testimony_01", "testimony_02", "testimony_03", "testimony_04", "testimony_05", "testimony_06"], narrative)
    check(permutations == 720, "all testimony orders were exercised")

    # Each long relationship has one brief, durable response before the ending.
    for npc_id in ["npc_threadsmith_apprentice", "npc_root_prisoner", "npc_beeswax_vendor", "npc_lantern_sister", "npc_deserter_flagbearer"]:
        var reflection := {}
        for state in narrative.entries[npc_id].states:
            if String(state.id).begins_with("reflection_"):
                reflection = state
        var flags := {}
        for flag in reflection.flags_all:
            flags[flag] = true
        var result: Dictionary = narrative.resolve(npc_id, [], [], flags)
        check(result.state == reflection.id, "completed relationship offers its personal follow-up")
        check(narrative.completion_outcome(result, 0, flags).flags.is_empty(), "interrupted follow-up creates no progress")
        var outcome: Dictionary = narrative.completion_outcome(result, result.lines.size() - 1, flags)
        check(outcome.rewards.is_empty() and outcome.flags == reflection.grant_flags, "follow-up commits only its narrative marker")
        check(not narrative.completion_response(result, result.lines.size() - 1, flags).is_empty(), "follow-up contains a brief protagonist action")
        for flag in outcome.flags:
            flags[flag] = true
        check(narrative.resolve(npc_id, [], [], flags).state != reflection.id, "follow-up is not repeated forever")
        for id in ["ending_a", "ending_b", "ending_c"]:
            var after := flags.duplicate()
            after["ending_chosen"] = id
            after[id + "_done"] = true
            check(String(narrative.resolve(npc_id, [], [], after).state).begins_with("aftermath_"), "the selected ending keeps its priority")

    scene = await spawn("res://data/demo_ch06_silent_crown_core.json")
    await frames()
    var initial: Dictionary = scene.world_narrative.main_line({}, {})
    scene.ui_shell._show_journal_record(initial.merged({"record_kind": "main"}))
    check(not scene.ui_shell.bag_description.text.contains("同一根新线"), "the real journal withholds unearned synthesis")
    var known: Dictionary = scene.world_narrative.main_line({"testimony_01": 1, "testimony_03": 1}, {})
    scene.ui_shell._show_journal_record(known.merged({"record_kind": "main"}))
    check(scene.ui_shell.bag_description.text.contains("同一根新线") and not scene.ui_shell.bag_description.text.contains("停一拍"), "the real journal assembles only acquired proof")

    scene.story_flags["boss_down_ch06"] = true
    scene._spawn_ending_gates()
    var gate := gate_for("ending_b")
    check(is_instance_valid(gate), "production ending gate exists")
    if not is_instance_valid(gate):
        await retire()
        cleanup_save()
        quit(1)
        return
    scene.player.global_position = gate.global_position
    scene.player.velocity = Vector2.ZERO
    scene._try_interact()
    var desk = scene.get_node_or_null(DESK.NAME)
    check(is_instance_valid(desk) and desk.visible and desk.phase == "preview", "interacting opens the preview instead of committing")
    check(scene.player.ui_input_locked and scene.active_overlay == "ending_story", "story reader locks gameplay input")
    check(not scene.story_flags.has("ending_chosen") and desk.reader.text.contains("黑潮") and desk.reader.text.contains("承担什么"), "choice costs are explained before a save")
    await capture("ending-b-preview")
    desk.get_cancel_button().pressed.emit()
    await frames()
    check(not desk.visible and not scene.player.ui_input_locked and not scene.story_flags.has("ending_chosen"), "cancel returns to exploration without a choice")

    DESK.open(scene, gate)
    scene.story_flags.erase("boss_down_ch06")
    desk.get_ok_button().pressed.emit()
    check(not scene.story_flags.has("ending_chosen") and desk.get_ok_button().disabled, "stale readiness cannot commit")
    scene._close_overlays()
    await frames()
    scene.story_flags["boss_down_ch06"] = true
    DESK.open(scene, gate)
    var before: Dictionary = scene.story_flags.duplicate(true)
    scene.world_save_failure_injected_for_validation = true
    desk.get_ok_button().pressed.emit()
    check(scene.story_flags == before and desk.phase == "preview" and desk.visible, "save failure rolls back and leaves an explicit retry")
    check(desk.reader.text.contains("选择尚未生效"), "failed save never plays an epilogue")
    scene.world_save_failure_injected_for_validation = false
    desk.get_ok_button().pressed.emit()
    check(scene.story_flags.get("ending_chosen", "") == "ending_b" and desk.phase == "epilogue", "explicit confirmation commits then opens the ending scenes")
    check(desk.pages.size() == 3 and desk.reader.text.contains("挡潮板"), "base ending has authored scenes without fabricated optional encounters")
    await capture("ending-b-epilogue")
    check(desk.visible and scene.active_overlay == "ending_story", "the epilogue stays open across rendered frames")
    var page: int = desk.page
    desk.get_ok_button().pressed.emit()
    check(desk.page == page + 1, "the player advances the epilogue at their own pace")
    scene._close_overlays()
    await frames()
    var selected: Dictionary = scene.story_flags.duplicate(true)
    DESK.open(scene, gate)
    check(desk.phase == "epilogue" and scene.story_flags == selected, "the chosen gate replays without recommitting")
    scene._close_overlays()
    check(scene._save_world(), "selected ending can be saved")
    await retire()
    scene = await spawn("res://data/demo_ch06_silent_crown_core.json", true)
    check(scene.story_flags.get("ending_chosen", "") == "ending_b", "restart retains the selected world")
    var progress: Dictionary = scene.world_narrative.evaluate_progress(scene.inventory_counts, scene.story_flags)
    for entry in progress.endings:
        if entry.chosen:
            scene.ui_shell._show_journal_record(entry.merged({"record_kind": "ending"}))
            check(scene.ui_shell.bag_description.text.contains("尾声 · 叫出名字"), "the committed epilogue remains readable in the real journal")
            await capture("ending-b-journal")
    for id in ["ending_a", "ending_b", "ending_c"]:
        var plain := JOURNEY.epilogue(id, {})
        var flags := {"quest_bring_names_complete": true, "reward_returned_names_claimed": true}
        check(JOURNEY.epilogue(id, flags).size() >= plain.size(), "callbacks are conditional")
    check(JOURNEY.epilogue("ending_c", {"quest_root_rescue_complete": true}).size() == JOURNEY.epilogue("ending_c", {}).size(), "an uncommitted rescue cannot invent an ending cameo")
    await retire()
    cleanup_save()
    await AUDIO.drain(self)
    print("NARRATIVE_CLOSURE checks=%d failures=%d orders=%d" % [checks, failures, permutations])
    quit(1 if failures else 0)
