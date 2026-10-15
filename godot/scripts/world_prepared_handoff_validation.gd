extends SceneTree
const LOADER := preload("res://scripts/world_region_loader.gd")
const PREFETCH := preload("res://scripts/world_prefetch.gd")
const STATE := preload("res://scripts/world_state.gd")
const MAIN := preload("res://scripts/main_level.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const SAVE := "user://world_prepared_handoff_validation.json"
const SOURCE := "user://world_prepared_handoff_fixture.json"
var checks := 0
var failures: Array[String] = []

class ProbeWorld extends "res://scripts/main_level.gd":
    var sync_calls := 0
    var owned_calls := 0
    var accepted_input: Dictionary
    func _region_prepare_jobs(prepared: Dictionary = {}) -> Array:
        accepted_input = prepared
        return super._region_prepare_jobs(prepared)
    func _prepare_config_and_route(prepared: Dictionary) -> void:
        sync_calls += 1
        super._prepare_config_and_route(prepared)
    func _accept_owned_prepared_config(prepared: Dictionary) -> void:
        owned_calls += 1
        super._accept_owned_prepared_config(prepared)

class FixtureHost extends ProbeWorld:
    func _ready() -> void: process_mode = Node.PROCESS_MODE_DISABLED
    func _region_prepare_jobs(prepared: Dictionary = {}) -> Array:
        accepted_input = prepared
        return [{"method": "_prepare_config_and_route", "args": [prepared]}]
    func _region_build_jobs() -> Array: return []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
    root.process_mode = Node.PROCESS_MODE_DISABLED
    await _production()
    await _copy_fixtures()
    _borrow_lease()
    for path in [SOURCE, SAVE, SAVE + ".bak", SAVE + ".tmp", SAVE + ".previous"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    if failures.is_empty():
        print("WORLD PREPARED HANDOFF PASS checks=%d" % checks)
        quit(0)
    else:
        for failure in failures: push_error(failure)
        quit(1)

func _production() -> void:
    var host := ProbeWorld.new()
    host.world_mode = true
    host.world_resume = false
    host.world_save_path = SAVE
    root.add_child(host)
    await _wait(host)
    _check(host.initial_region_ready and host.sync_calls == 0 and host.owned_calls == 1, "World startup accepts one owned copy without synchronous prepared deepcopy")
    _check(host.config == host.accepted_input, "startup config equals validated prepared input")
    _isolation(host)
    var metric: Dictionary = host.world_loader.last_transition.prepared_config_copy
    _check(metric.complete and metric.batches > 1 and metric.max_step_edges <= 512, "startup handoff copies in bounded batches")
    var path := ROUTES.cached_config_path("demo_ch02_rain_foundry_canal")
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
    var ok: bool = await host.world_loader.replace_region_async(host, path, Vector2(raw.player_start[0], raw.player_start[1]))
    _check(ok and host.sync_calls == 0 and host.owned_calls == 1 and host.config == host.accepted_input, "foreground travel accepts isolated prepared copy through owned hook")
    _isolation(host)
    metric = host.world_loader.last_transition.prepared_config_copy
    _check(metric.complete and metric.max_step_edges <= 512 and not metric.source_lease.is_empty(), "travel copy retains preflight source lease")
    # Cancellation after a real target-copy step must not save that destination.
    var source_id: String = host.config.id
    var source_currency: int = host.currency_count
    host.story_flags["handoff_reward_fixture"] = true
    path = ROUTES.cached_config_path("demo_ch01_moss_bell_court")
    var target_bytes := FileAccess.get_file_as_bytes(path)
    raw = JSON.parse_string(target_bytes.get_string_from_utf8())
    raw.wish_board = [{"id": "prepared_copy_reward", "title": "handoff fixture", "desc": "",
        "target_flag": "handoff_reward_fixture", "reward_currency": 713}]
    host.world_prefetch.shutdown()
    host.world_prefetch.generation = host.world_loader.generation
    host.world_prefetch.selection_elapsed = -1000
    host.world_prefetch.desired = {String(raw.id): {"path": path, "entry": Vector2(raw.player_start[0], raw.player_start[1])}}
    host.world_prefetch.configs = {String(raw.id): {"raw": raw, "stamp": FileAccess.get_modified_time(path), "size": target_bytes.size()}}
    var cancel := {"done": false}
    var interrupt := func():
        if not cancel.done and host.world_loader.phase == "loading":
            var copy_metric: Dictionary = host.world_loader.last_transition.get("prepared_config_copy", {})
            if int(copy_metric.get("batches", 0)) > 0 and not copy_metric.get("complete", false):
                cancel.done = true
                host.world_loader.cancel_transition()
    process_frame.connect(interrupt)
    path = ROUTES.cached_config_path("demo_ch01_moss_bell_court")
    ok = await host.world_loader.replace_region_async(host, path, Vector2(raw.player_start[0], raw.player_start[1]))
    process_frame.disconnect(interrupt)
    _check(cancel.done and not ok and host.config.id == source_id and host.world_loader.phase == "idle", "copy cancellation rolls back complete source region")
    var attempts: Array = host.world_loader.last_transition.prepare_attempts
    var target_attempt: Dictionary = attempts.filter(func(attempt): return attempt.role == "target").back()
    var rollback_attempt: Dictionary = attempts.filter(func(attempt): return attempt.role == "rollback").back()
    _check(not target_attempt.prepared_config_copy.complete and rollback_attempt.prepared_config_copy.complete and rollback_attempt.prepared_config_copy.source_lease.is_empty(), "attempt metrics distinguish cancelled target from completed memory-snapshot rollback")
    var saved := STATE.new()
    _check(saved.read(SAVE) and saved.data.current_region == source_id and int(saved.data.currency) == source_currency, "copy cancellation never commits target location or reward to save")
    _check(host.currency_count == source_currency and host.story_flags.get("handoff_reward_fixture", false), "cancelled target reward cannot change settled source progress")
    _check(host.sync_calls == 0 and host.player.collision_layer != 0 and not host.world_loading, "rollback handoff uses owned copy and restores gameplay")
    host.free()
    await process_frame

func _isolation(host: Node) -> void:
    var key: Variant = host.config.inventory.catalog.keys()[0]
    var original: Variant = host.config.inventory.catalog[key].get("name")
    host.config.inventory.catalog[key]["name"] = "consumer only"
    _check(host.accepted_input.inventory.catalog[key].get("name") == original, "consumer nested mutation cannot change prepared input")
    host.accepted_input.inventory.catalog[key]["name"] = "input only"
    _check(host.config.inventory.catalog[key].name == "consumer only", "prepared input nested mutation cannot change consumer")
    host.config.inventory.catalog[key]["name"] = original
    host.accepted_input.inventory.catalog[key]["name"] = original

func _copy_fixtures() -> void:
    var large := {"nested": {"rows": []}, "tail": true}
    for index in range(2400): large.nested.rows.append({"value": float(index), "path": [float(index), float(index + 1)]})
    var text := JSON.stringify(large)
    _write(SOURCE, text)
    var host := FixtureHost.new()
    host.world_mode = true
    host.config_path = SOURCE
    host.config = {"settled": "source"}
    root.add_child(host)
    var loader := LOADER.new()
    loader.phase = "loading"
    var lease := _source_lease()
    var seen := {"copy": false, "partial": false}
    var observe := func():
        var metric: Dictionary = loader.last_transition.get("prepared_config_copy", {})
        if int(metric.get("batches", 0)) > 0 and not metric.get("complete", false):
            seen.copy = true
            seen.partial = seen.partial or host.config != {"settled": "source"}
    process_frame.connect(observe)
    var ok: bool = await loader._construct_budgeted(host, large, true, lease)
    process_frame.disconnect(observe)
    _check(ok and seen.copy and not seen.partial and host.config == large and host.owned_calls == 1 and host.sync_calls == 0, "large input publishes once after complete copy")
    _check(loader.last_transition.prepared_config_copy.max_step_edges <= 512 and loader.last_transition.prepared_config_copy.batches > 1, "large handoff admits at most 512 edges per step")
    var full_copy_batches: int = loader.last_transition.prepared_config_copy.batches
    host.config.nested.rows[0].value = -1.0
    _check(large.nested.rows[0].value == 0.0, "large copied graph has independent nested ownership")
    host.free()
    loader.shutdown()
    # Both explicit World sync and nonWorld compatibility retain defensive copy.
    for world in [true, false]:
        var sync = MAIN.new()
        sync.world_mode = world
        sync._prepare_config_and_route(large)
        sync.config.nested.rows[0].value = -2.0
        _check(large.nested.rows[0].value == 0.0, "synchronous compatibility preserves prepared-input isolation")
        sync.free()
    for boundary in ["cancel", "final_accept", "generation", "route", "path", "entry", "source_size", "source_stamp", "detach", "free", "shutdown"]:
        _write(SOURCE, text)
        host = FixtureHost.new()
        host.world_mode = true
        host.config_path = SOURCE
        host.config = {"settled": "source"}
        root.add_child(host)
        loader = LOADER.new()
        loader.phase = "loading"
        host.world_loader = loader
        lease = _source_lease()
        if boundary == "source_stamp":
            _check(text.length() == text.replace('"tail":true', '"tail":null').length(), "stamp fixture keeps source length unchanged")
            await create_timer(1.1).timeout
        var fired := {"done": false, "final_frames": 0}
        var inject := func():
            if fired.done: return
            var metric: Dictionary = loader.last_transition.get("prepared_config_copy", {})
            if int(metric.get("batches", 0)) == 0: return
            if boundary == "final_accept":
                if int(metric.batches) != full_copy_batches: return
                fired.final_frames += 1
                # First frame observes the last copy step; second observes the
                # extra acceptance window, after all edges have been copied.
                if fired.final_frames < 2: return
            fired.done = true
            match boundary:
                "cancel", "final_accept": loader.cancel_transition()
                "generation": loader.generation += 1
                "route": ROUTES._cache_generation += 1
                "path": host.config_path = SOURCE + ".other"
                "entry":
                    host.entry_spawn_override_enabled = true
                    host.entry_spawn_override = Vector2(INF, 0)
                "source_size":
                    _write(SOURCE, "{}")
                    # Hold mtime equal deliberately so size alone must reject.
                    lease.mtime = FileAccess.get_modified_time(SOURCE)
                "source_stamp": _write(SOURCE, text.replace('"tail":true', '"tail":null'))
                "detach": root.remove_child(host)
                "free": host.free()
                "shutdown": loader.shutdown()
        process_frame.connect(inject)
        ok = await loader._construct_budgeted(host, large, true, lease)
        process_frame.disconnect(inject)
        _check(fired.done and not ok and not loader.last_transition.prepared_config_copy.complete, boundary + " rejects in-flight handoff")
        if is_instance_valid(host):
            _check(host.config == {"settled": "source"} and host.owned_calls == 0, boundary + " never exposes partial config")
            host.free()
        loader.shutdown()
        _check(not loader.config_read_job.busy(), boundary + " leaves sole reader drained")
        await process_frame

func _borrow_lease() -> void:
    _write(SOURCE, '{"value":"old"}')
    var bytes := FileAccess.get_file_as_bytes(SOURCE)
    var raw: Dictionary = JSON.parse_string(bytes.get_string_from_utf8())
    var pref := PREFETCH.new()
    pref.desired = {"fixture": {"path": SOURCE}}
    pref.configs = {"fixture": {"raw": raw, "stamp": FileAccess.get_modified_time(SOURCE), "size": bytes.size()}}
    _check(pref._cached_raw_borrow(SOURCE) == raw, "valid cached read borrows with original stamp and size")
    _write(SOURCE, '{"value":"different size"}')
    # Make mtime equal deliberately; the original recorded size must still win.
    pref.configs.fixture.stamp = FileAccess.get_modified_time(SOURCE)
    _check(pref._cached_raw_borrow(SOURCE) == null, "same-mtime different-size cached body cannot acquire a new source lease")
    pref.configs.fixture.erase("size")
    _check(pref._cached_raw_borrow(SOURCE) == null, "legacy cache without original size requires a fresh read")
    pref.shutdown()

func _source_lease() -> Dictionary:
    var file := FileAccess.open(SOURCE, FileAccess.READ)
    var size := file.get_length()
    file.close()
    return {"path": SOURCE, "mtime": FileAccess.get_modified_time(SOURCE), "size": size}

func _write(path: String, text: String) -> void:
    var file := FileAccess.open(path, FileAccess.WRITE)
    file.store_string(text)
    file.close()

func _wait(host: Node) -> void:
    for frame in range(1500):
        if host.initial_region_ready or host.world_loader.phase == "startup_error": return
        await process_frame
    _check(false, "startup reaches publication before fixture deadline")

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label)
