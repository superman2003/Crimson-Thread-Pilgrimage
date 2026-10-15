extends SceneTree
const ROUTES := preload("res://scripts/world_routes.gd")
const STATE := preload("res://scripts/world_state.gd")
const SAVE := "user://world_departure_snapshot_validation.json"
const OTHER := "user://world_departure_snapshot_wrong_slot.json"
var scene: Node
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")
func _run() -> void:
    root.process_mode = Node.PROCESS_MODE_DISABLED
    scene = await _new_world()
    await _cancel_and_settlement()
    await _save_failures()
    await _dirty_business()
    await _snapshot_rollback()
    await _lease_failures()
    await _successful_arrival()
    scene.free()
    await process_frame
    for boundary in ["detach", "free", "shutdown"]: await _teardown(boundary)
    for path in [SAVE, SAVE + ".bak", SAVE + ".tmp", SAVE + ".previous", OTHER]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    if failures.is_empty():
        print("WORLD DEPARTURE SNAPSHOT PASS checks=%d" % checks)
        quit(0)
    else:
        for failure in failures: push_error(failure)
        quit(1)

func _new_world() -> Node:
    var host: Node = load("res://scenes/World.tscn").instantiate()
    host.world_resume = false
    host.world_save_path = SAVE
    root.add_child(host)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(host)
    var rows := []
    for index in range(1600): rows.append({"value": float(index), "pair": [float(index), float(index + 1)]})
    host.config["departure_probe"] = {"value": "settled", "rows": rows}
    host.story_flags["departure_probe"] = {"value": "settled", "rows": rows.duplicate(true)}
    return host

func _target() -> Dictionary:
    var id := "demo_ch02_rain_foundry_canal" if scene.config.id != "demo_ch02_rain_foundry_canal" else "demo_ch01_moss_bell_court"
    var path := ROUTES.cached_config_path(id)
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
    return {"path": path, "entry": Vector2(raw.player_start[0], raw.player_start[1])}

func _controls() -> Dictionary:
    return {"world_loading": scene.world_loading, "chapter": scene.chapter_transitioning,
        "mode": scene.process_mode, "player_mode": scene.player.process_mode, "ui": scene.player.ui_input_locked,
        "layer": scene.player.collision_layer, "mask": scene.player.collision_mask,
        "player": scene.player.get_instance_id(), "generation": scene.world_loader.generation,
        "unloaded": scene.world_loader.unloaded_nodes, "id": String(scene.config.id)}

func _restored(before: Dictionary, label: String, ui_changed: bool = false) -> void:
    _check(scene.world_loading == before.world_loading and scene.chapter_transitioning == before.chapter and scene.process_mode == before.mode and scene.player.process_mode == before.player_mode, label + " restores source process and gates")
    _check(scene.player.collision_layer == before.layer and scene.player.collision_mask == before.mask and (ui_changed or scene.player.ui_input_locked == before.ui), label + " restores source collision and input lock")
    _check(scene.player.get_instance_id() == before.player and scene.world_loader.generation == before.generation and scene.world_loader.unloaded_nodes == before.unloaded and scene.config.id == before.id, label + " retains original region without eviction or generation advance")

func _cancel_and_settlement() -> void:
    scene.currency_count = 317
    scene.player.energy = 30
    scene.player.heal_timer = 1.0
    scene.player.heal_reserved_cost = 20
    scene.player.build_profile["heal_interrupt_loss_ratio"] = 0.5
    scene._toggle_map()
    var before := _controls()
    var running: Tween = scene._region_tween()
    running.tween_interval(30)
    var paused: Tween = scene._region_tween()
    paused.tween_interval(30)
    paused.pause()
    var target := _target()
    var seen := {"done": false}
    var cancel := func():
        var metric: Dictionary = scene.world_loader.last_transition.get("departure_snapshot", {})
        if scene.world_loader.phase == "departure_snapshot" and metric.get("stage", "") == "state" and not seen.done:
            seen.done = true
            scene.world_loader.cancel_transition()
    process_frame.connect(cancel)
    var ok: bool = await scene.world_loader.replace_region_async(scene, target.path, target.entry, Vector2.INF, {"departure_target_reward": true})
    process_frame.disconnect(cancel)
    _check(seen.done and not ok, "Esc-style cancellation reaches state-copy window")
    _restored(before, "cancel")
    _check(scene.active_overlay == "map" and scene.player.ui_input_locked and running.is_running() and not paused.is_running(), "cancel preserves overlay and resumes only formerly running tweens")
    _check(scene.player.energy == 40 and scene.player.heal_reserved_cost == 0 and scene.player.heal_timer == 0, "source handoff settles healing refund exactly once")
    var saved := STATE.new()
    _check(saved.read(SAVE) and saved.data.current_region == before.id and int(saved.data.energy) == 40 and not saved.data.story_flags.has("departure_target_reward"), "cancel keeps settled source checkpoint without target reward")
    var metric: Dictionary = scene.world_loader.last_transition.departure_snapshot
    _check(not metric.complete and metric.copies.config.complete and metric.copies.config.batches > 1 and metric.copies.config.max_step_edges <= 512 and metric.copies.state.max_step_edges <= 512, "snapshot metrics expose bounded private copies and cancelled attempt")
    running.kill()
    paused.kill()
    scene._close_overlays()

func _save_failures() -> void:
    scene._toggle_map()
    var target := _target()
    for kind in ["write", "capture_blocked"]:
        var before := _controls()
        var bytes := FileAccess.get_file_as_bytes(SAVE)
        var currency: int = scene.currency_count
        if kind == "write": scene.world_save_failure_injected_for_validation = true
        else:
            scene.world_save_blocked = true
            scene.world_save_capture_ok = true # stale success must be reset.
            scene.currency_count = -1
        var ok: bool = await scene.world_loader.replace_region_async(scene, target.path, target.entry)
        _check(not ok and scene.world_loader.last_transition.departure_snapshot.copies.is_empty(), kind + " rejects before any snapshot copying")
        _restored(before, kind)
        _check(FileAccess.get_file_as_bytes(SAVE) == bytes, kind + " preserves existing source save bytes")
        if kind == "capture_blocked": _check(not scene.world_save_capture_ok, "blocked-save flag cannot disguise failed capture")
        scene.world_save_failure_injected_for_validation = false
        scene.world_save_blocked = false
        scene.currency_count = currency
    scene._close_overlays()
    # A valid blocked checkpoint remains usable without writing disk.
    scene.world_save_blocked = true
    var bytes := FileAccess.get_file_as_bytes(SAVE)
    var seen := {"done": false}
    var cancel := func():
        if scene.world_loader.phase == "departure_snapshot" and not seen.done:
            seen.done = true
            scene.world_loader.cancel_transition()
    process_frame.connect(cancel)
    var ok: bool = await scene.world_loader.replace_region_async(scene, target.path, target.entry)
    process_frame.disconnect(cancel)
    _check(seen.done and not ok and scene.world_loader.last_transition.departure_snapshot.capture_ok, "valid blocked-save capture is admitted to snapshot phase")
    _check(FileAccess.get_file_as_bytes(SAVE) == bytes, "blocked source checkpoint never writes disk")
    scene.world_save_blocked = false

func _dirty_business() -> void:
    var target := _target()
    for kind in ["deferred_currency", "enemy_death", "overlay"]:
        if kind == "overlay": scene._toggle_map()
        var before := _controls()
        var currency: int = scene.currency_count
        var enemy_count: int = scene.enemy_defeated
        var drop := String(scene.config.get("enemy_drop_item", "moss_chitin"))
        var inventory: int = scene.inventory_counts.get(drop, 0)
        var seen := {"done": false}
        var event := func():
            if scene.world_loader.phase != "departure_snapshot" or seen.done: return
            seen.done = true
            match kind:
                "deferred_currency": scene._defer_region_call("_add_currency", [7])
                "overlay": scene._defer_region_call("_close_overlays")
                "enemy_death":
                    for actor in get_nodes_in_group("enemy"):
                        if not actor.is_boss and not actor.dying:
                            actor._begin_death_dissolve()
                            break
        process_frame.connect(event)
        var ok: bool = await scene.world_loader.replace_region_async(scene, target.path, target.entry)
        process_frame.disconnect(event)
        _check(seen.done and not ok and scene.world_loader.last_transition.departure_snapshot.dirty, kind + " invalidates mixed snapshot without dropping business")
        _restored(before, kind, kind == "overlay")
        _check(scene.world_loader.last_transition.departure_snapshot.get("dirty_save_attempted", false), kind + " retries source checkpoint after unlocking")
        if kind == "deferred_currency": _check(scene.currency_count == currency + 7, "deferred currency is earned once")
        if kind == "enemy_death": _check(scene.currency_count == currency + 8 and scene.enemy_defeated == enemy_count + 1 and scene.inventory_counts.get(drop, 0) == inventory + 1, "real dying actor retains currency, kill count and material reward")
        if kind == "overlay": _check(scene.active_overlay.is_empty() and not scene.player.ui_input_locked, "dirty deferred overlay close recomputes live input lock")
        var saved := STATE.new()
        _check(saved.read(SAVE) and int(saved.data.currency) == scene.currency_count and saved.data.current_region == before.id, kind + " persists source progress without target publication")

func _snapshot_rollback() -> void:
    scene._toggle_map()
    _check(scene.active_overlay == "map" and scene.player.ui_input_locked, "rollback departure begins with a source overlay lock")
    var target := _target()
    var source_id: String = scene.config.id
    var source_currency: int = scene.currency_count
    var source_build: Dictionary = scene.build_system.serialize()
    var changed := {"done": false}
    var mutate := func():
        if scene.world_loader.phase == "unloading" and not changed.done:
            changed.done = true
            # Deliberate post-capture mutation proves private rollback ownership;
            # ordinary source mutation during the borrowing window is rejected.
            scene.config.departure_probe.value = "live mutation after capture"
            scene.world_state.data.story_flags.departure_probe.value = "live mutation after capture"
            scene.world_loader.cancel_transition()
    process_frame.connect(mutate)
    var ok: bool = await scene.world_loader.replace_region_async(scene, target.path, target.entry, Vector2.INF, {"departure_target_reward": true})
    process_frame.disconnect(mutate)
    _check(changed.done and not ok and scene.world_loader.last_transition.rolled_back, "fully staged departure can rollback after unload begins")
    _check(scene.config.id == source_id and scene.config.departure_probe.value == "settled" and scene.story_flags.departure_probe.value == "settled" and scene.currency_count == source_currency and scene.build_system.serialize() == source_build, "rollback uses independent settled config, state and build snapshots")
    _check(scene.world_loader.phase == "idle" and not scene.world_loading and scene.player.collision_layer != 0 and not scene.story_flags.has("departure_target_reward"), "rollback restores gameplay without target reward")
    _check(scene.active_overlay.is_empty() and not scene.player.ui_input_locked, "rebuilt rollback source discards the old overlay input lock")

func _successful_arrival() -> void:
    scene._close_overlays()
    scene._toggle_map()
    var target := _target()
    _check(scene.active_overlay == "map" and scene.player.ui_input_locked, "successful departure begins with a source overlay lock")
    var ok: bool = await scene.world_loader.replace_region_async(scene, target.path, target.entry, Vector2.INF, {"departure_target_reward": true})
    _check(ok and scene.world_loader.last_transition.departure_snapshot.complete and scene.world_loader.last_transition.departure_snapshot.copies.state.complete, "complete private departure snapshots permit target publication")
    _check(scene.config_path == target.path and scene.active_overlay.is_empty() and not scene.player.ui_input_locked, "successful arrival discards source overlay input lock")
    var saved := STATE.new()
    _check(saved.read(SAVE) and saved.data.current_region == scene.config.id and bool(saved.data.story_flags.get("departure_target_reward", false)), "successful arrival saves the complete target and publishes its reward")

func _lease_failures() -> void:
    var target := _target()
    for kind in ["token", "generation", "route", "path", "save_path", "save_blocked", "gate"]:
        var before := _controls()
        var old_path: String = scene.config_path
        var old_save: String = scene.world_save_path
        var old_blocked: bool = scene.world_save_blocked
        var old_generation: int = scene.world_loader.generation
        var seen := {"done": false, "owner": null}
        var owner: RefCounted
        var event := func():
            if scene.world_loader.phase != "departure_snapshot" or seen.done: return
            seen.done = true
            match kind:
                "token": seen.owner.cancel()
                "generation": scene.world_loader.generation += 1
                "route": ROUTES._cache_generation += 1
                "path": scene.config_path = old_path + ".other"
                "save_path": scene.world_save_path = OTHER
                "save_blocked": scene.world_save_blocked = true
                "gate": scene.player.collision_mask = 123
        process_frame.connect(event)
        owner = scene.world_loader.request_region_transition(scene, target.path, target.entry)
        seen.owner = owner
        for frame in range(1800):
            if owner.finished: break
            await process_frame
        process_frame.disconnect(event)
        _check(seen.done and owner.finished and not owner.succeeded and scene.world_loader.unloaded_nodes == before.unloaded, kind + " rejects departure before eviction")
        _check(scene.world_loading == before.world_loading and scene.chapter_transitioning == before.chapter and scene.player.collision_layer == before.layer and scene.player.collision_mask == before.mask and scene.player.process_mode == before.player_mode and scene.process_mode == before.mode, kind + " restores live source controls")
        scene.config_path = old_path
        scene.world_save_path = old_save
        scene.world_save_blocked = old_blocked
        scene.world_loader.generation = old_generation # deliberate fixture fault reset.
    _check(not FileAccess.file_exists(OTHER), "source slot change never creates or overwrites another save")

func _teardown(boundary: String) -> void:
    scene = await _new_world()
    var target := _target()
    var before := _controls()
    var loader: RefCounted = scene.world_loader
    var seen := {"done": false}
    var event := func():
        if loader.phase != "departure_snapshot" or seen.done: return
        seen.done = true
        match boundary:
            "detach": root.remove_child(scene)
            "free": scene.free()
            "shutdown": loader.shutdown()
    process_frame.connect(event)
    var ok: bool = await loader.replace_region_async(scene, target.path, target.entry)
    process_frame.disconnect(event)
    _check(seen.done and not ok and loader.unloaded_nodes == before.unloaded and not loader.config_read_job.busy(), boundary + " aborts before eviction and releases reader")
    if is_instance_valid(scene):
        _check(scene.world_loading == before.world_loading and scene.chapter_transitioning == before.chapter and scene.player.collision_layer == before.layer and scene.player.collision_mask == before.mask and scene.player.process_mode == before.player_mode, boundary + " restores controls on a valid detached or shutdown source")
        scene.free()
    await process_frame

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label)
