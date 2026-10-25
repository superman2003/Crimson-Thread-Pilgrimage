extends "res://journey/tests/i_support.gd"


func run() -> void:
    label = "I_LIVE_WORLD"
    var scene: Node = load("res://scenes/World.tscn").instantiate()
    scene.world_resume = false
    scene.world_save_path = "user://fieldwork_live_world_validation.json"
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    if not scene.initial_region_ready:
        quit(1)
        return
    var host: Node = root.get_node("JourneyWorkbench")
    for index in 120:
        if is_instance_valid(host.entry):
            break
        await process_frame
    check(is_instance_valid(host.entry), "actual settings entry attaches")
    scene.set_process(false)
    scene.player.set_physics_process(false)
    var inventory: Dictionary = scene.inventory_counts.duplicate(true)
    var build: Dictionary = scene.build_system.state.duplicate(true)
    var wallet: int = scene.currency_count
    var primary := FileAccess.get_file_as_bytes(scene.world_save_path)
    var mappings := mapping_signature()
    scene._toggle_audio_settings()
    await process_frame
    host.open()
    await process_frame
    await process_frame
    for id in ["i_rhythm", "i_input_trials", "i_movement_trials"]:
        if not host.features.has(id):
            continue
        host._select(id)
        await process_frame
        await process_frame
        var feature: RefCounted = host.features[id]
        var old_count: int = feature.data.records.size()
        feature._start_session()
        await process_frame
        await process_frame
        check(feature.live != null, id + " starts only via actual selected Window")
        if feature.live == null:
            continue
        if id == "i_rhythm":
            var entry := LineEdit.new()
            host.dialog.add_child(entry)
            entry.grab_focus()
            await process_frame
            var tap := InputEventKey.new()
            tap.keycode = KEY_T
            tap.pressed = true
            host.dialog.window_input.emit(tap)
            check(feature.live.taps.is_empty(), "text field focus does not record a rhythm tap")
            entry.release_focus()
            host.dialog.window_input.emit(tap)
            check(
                feature.live.taps.size() == 1,
                "native window signal reaches explicit rhythm session"
            )
            entry.free()
        if id == "i_input_trials":
            check(feature._focused(), "actual dedicated practice pad receives focus")
            feature._connection_changed(0, false)
            check(feature.live.paused, "disconnect pauses actual trial without completing it")
            feature._resume_session()
            check(not feature.live.paused, "explicit resume refocuses practice pad")
        if id != "i_movement_trials":
            feature._lost_focus()
            check(feature.live.paused, id + " focus loss pauses actual session")
            feature._resume_session()
            check(not feature.live.paused, id + " resumes explicitly")
        else:
            host.close()
            await process_frame
            check(
                feature.live != null and feature.live.active,
                "movement session survives return to gameplay"
            )
            host.open()
            await process_frame
        host.context.store.writable = false
        feature._finish_session("test lifecycle completion")
        check(
            feature.live == null and not feature.pending.is_empty(),
            id + " failed write retains complete result"
        )
        check(
            feature.data.records.size() == old_count, id + " failed write leaves history unchanged"
        )
        host.context.store.writable = true
        feature._save_pending()
        check(
            feature.pending.is_empty() and feature.data.records.size() == old_count + 1,
            id + " retry persists exactly one result"
        )
        check(feature.valid(feature.data), id + " lifecycle result validates")
        check(
            feature.pump == null and feature._window() == null,
            id + " releases timer and window signal ownership"
        )
    check(
        (
            scene.inventory_counts == inventory
            and scene.currency_count == wallet
            and scene.build_system.state == build
        ),
        "all live trials preserve actual resources and build"
    )
    check(
        FileAccess.get_file_as_bytes(scene.world_save_path) == primary,
        "live trial result writes never rewrite primary save"
    )
    check(mapping_signature() == mappings, "live trial lifecycle does not change InputMap")
    host.close()
    scene.free()
    await process_frame
    await process_frame
    check(host._owner() == null, "retired owner cannot be reused")
    finish()
