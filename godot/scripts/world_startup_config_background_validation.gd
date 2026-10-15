extends SceneTree
const MAIN := preload("res://scripts/main_level.gd")
const LOADER := preload("res://scripts/world_region_loader.gd")
const READER := preload("res://scripts/world_config_read_job.gd")
const VALIDATOR := preload("res://scripts/world_config_validator.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const STATE := preload("res://scripts/world_state.gd")
const SAVE := "user://world_startup_config_background_validation.json"
const REGION := "demo_ch02_rain_foundry_canal"
var checks := 0
var failures: Array[String] = []

class ProbeWorld extends "res://scripts/main_level.gd":
    var config_content_reads := 0
    var received_prepared := false
    func _load_json(path: String) -> Dictionary:
        if path == config_path: config_content_reads += 1
        return super._load_json(path)
    func _prepare_config_and_route(prepared: Dictionary) -> void:
        received_prepared = not prepared.is_empty()
        super._prepare_config_and_route(prepared)
    func _accept_owned_prepared_config(prepared: Dictionary) -> void:
        received_prepared = not prepared.is_empty()
        super._accept_owned_prepared_config(prepared)

class FaultReader extends "res://scripts/world_config_read_job.gd":
    var fault := ""
    func take(ticket: int) -> Dictionary:
        var read := super.take(ticket)
        if read.get("raw") is Dictionary and read.raw.has("player_start"):
            match fault:
                "parse": read.raw = null
                "shape": read.raw.map_rooms = []
                "stamp": read.stamp = -1
                "spawn": read.raw.player_start = [INF, 0]
        return read

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    root.process_mode = Node.PROCESS_MODE_DISABLED
    await _new_game_and_resume()
    await _default_entry_oracle()
    await _teardown_and_faults()
    for suffix in ["", ".bak", ".tmp", ".previous"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
    if failures.is_empty():
        print("WORLD STARTUP CONFIG BACKGROUND PASS checks=%d" % checks)
        quit(0)
    else:
        for failure in failures: push_error(failure)
        quit(1)

func _new_game_and_resume() -> void:
    # Prime through the explicit synchronous oracle, then make production cold.
    var path := ROUTES.config_path(REGION)
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
    var sync = LOADER.new()
    var expected: Dictionary = sync.validate_config(raw, path, Vector2(raw.player_start[0], raw.player_start[1]))
    ROUTES._cached_stamp = -1
    var host := ProbeWorld.new()
    host.world_mode = true
    host.world_resume = false
    host.world_save_path = SAVE
    host.config_path = path
    root.add_child(host)
    _check(not is_instance_valid(host.player), "startup attachment creates no partial region")
    await _wait(host)
    _check(host.initial_region_ready and host.config == expected and host.received_prepared, "explicit World region matches synchronous validation oracle")
    _check(host.config_content_reads == 0, "World initial config never reads content on main thread")
    var metric: Dictionary = host.world_loader.last_transition
    _check(not metric.startup_config_worker_is_main and metric.startup_config_bytes > 0 and metric.startup_config_wait_frames >= 1, "startup config read and parse run in shared background worker")
    _check(metric.startup_config_validator_batches > 1 and metric.startup_config_validator_max_operations <= 8, "startup validator and overlay use bounded frame batches")
    _check(host.active_spawn == Vector2(expected.player_start[0], expected.player_start[1]), "new game uses authored final player_start")
    _check(metric.startup_config_lease.route_generation == ROUTES.cached_generation(), "cold manifest is pinned before startup config")
    var saved_entry := Vector2(320, 500)
    host.player.global_position = saved_entry
    host.active_spawn = saved_entry
    _check(host._save_world(), "resume fixture writes chosen checkpoint entry")
    host.free()
    await process_frame
    host = ProbeWorld.new()
    host.world_mode = true
    host.world_resume = true
    host.world_save_path = SAVE
    # Resume route must outrank an otherwise legitimate config override.
    host.config_path = ROUTES.cached_config_path("demo_ch01_moss_bell_court")
    root.add_child(host)
    await _wait(host)
    _check(host.initial_region_ready and host.config.id == REGION and host.config_path == path, "resume route wins explicit initial config override")
    _check(host.entry_spawn_override_enabled and host.active_spawn == saved_entry and host.player.global_position.distance_to(saved_entry) < 1, "resume uses saved entry rather than authored player_start")
    _check(host.config_content_reads == 0 and host.world_loader.last_transition.startup_config_bytes > 0, "resume uses same background config path")
    host.free()
    await process_frame
    # CLI demo/boss overrides select world_mode=false before this unchanged path.
    var demo := ProbeWorld.new()
    demo.world_mode = false
    demo.config_path = path
    root.add_child(demo)
    _check(is_instance_valid(demo.player) and demo.world_loader == null and demo.config_content_reads > 0 and not demo.received_prepared, "nonWorld config override retains synchronous chapter path")
    demo.free()
    sync.shutdown()
    await process_frame

func _default_entry_oracle() -> void:
    var path := ROUTES.cached_config_path(REGION)
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
    raw.erase("player_start")
    var validator := VALIDATOR.new()
    validator.begin(raw, path, Vector2.ZERO, true)
    while not validator.done: validator.step()
    _check(not validator.result.is_empty() and validator._entry == Vector2(120, 500), "missing authored spawn retains default fallback")
    raw.player_start = [INF, 0]
    validator.begin(raw, path, Vector2.ZERO, true)
    while not validator.done: validator.step()
    _check(validator.result.is_empty(), "invalid authored default spawn is rejected safely")
    validator.begin(raw, path, Vector2(320, 500), false)
    while not validator.done: validator.step()
    _check(not validator.result.is_empty(), "valid saved entry takes priority over unusable authored default")

func _teardown_and_faults() -> void:
    for fault in ["parse", "shape", "stamp", "spawn", "loader_generation", "route_generation", "detach", "free", "shutdown", "wait_path", "wait_entry", "validator_entry", "post_build_stamp", "post_build_entry", "post_build_path", "post_finish_entry", "post_finish_path"]:
        var host := ProbeWorld.new()
        host.world_mode = true
        host.world_resume = false
        host.world_save_path = SAVE
        host.config_path = ROUTES.cached_config_path(REGION)
        root.add_child(host)
        var loader: RefCounted = host.world_loader
        var reader := FaultReader.new()
        reader.fault = fault
        loader.config_read_job = reader
        var before_save := FileAccess.get_file_as_bytes(SAVE)
        var injected := {"done": false}
        var inject := func():
            var metric: Dictionary = loader.last_transition
            if injected.done: return
            if fault.begins_with("post_"):
                if fault.begins_with("post_build_") and int(metric.get("max_build_operations", 0)) == 0: return
                if fault.begins_with("post_finish_") and (int(metric.get("commit_jobs", 0)) == 0 or metric.get("commit_cursor", 0) != metric.get("commit_jobs", 0)): return
                match fault:
                    "post_build_stamp": metric.startup_config_lease.stamp = -1
                    "post_build_entry", "post_finish_entry":
                        host.entry_spawn_override_enabled = true
                        host.entry_spawn_override = Vector2(INF, 0)
                    "post_build_path", "post_finish_path": host.config_path = ROUTES.cached_config_path("demo_ch01_moss_bell_court")
                injected.done = true
            elif metric.has("startup_config_lease"):
                if fault == "validator_entry" and int(metric.get("startup_config_validator_batches", 0)) == 0: return
                injected.done = true
                match fault:
                    "wait_entry", "validator_entry":
                        host.entry_spawn_override_enabled = true
                        host.entry_spawn_override = Vector2(999999, 999999)
                    "wait_path": host.config_path = ROUTES.cached_config_path("demo_ch01_moss_bell_court")
                    "loader_generation": loader.generation += 1
                    "route_generation": ROUTES._cache_generation += 1
                    "detach": root.remove_child(host)
                    "free": host.free()
                    "shutdown": loader.shutdown()
        process_frame.connect(inject)
        for frame in range(1200):
            if loader.phase in ["startup_error", "idle"]: break
            await process_frame
        process_frame.disconnect(inject)
        _check(not is_instance_valid(host) or not host.initial_region_ready, fault + " cannot publish region")
        _check(FileAccess.get_file_as_bytes(SAVE) == before_save, fault + " preserves existing save bytes")
        if fault in ["parse", "shape", "stamp", "spawn", "loader_generation", "route_generation", "wait_path", "wait_entry", "validator_entry", "post_build_stamp", "post_build_entry", "post_build_path", "post_finish_entry", "post_finish_path"]:
            _check(loader.phase == "startup_error" and is_instance_valid(loader.loading_canvas) and loader.loading_canvas.get_node("StartupRetry") is Button, fault + " exposes retry recovery")
            if not fault.begins_with("post_"): _check(not is_instance_valid(host.player), fault + " fails before any region construction")
        if is_instance_valid(host): host.free()
        loader.shutdown()
        await process_frame
        _check(not reader.busy() and loader.startup_token == null, fault + " releases unique reader and startup owner")

func _wait(host: Node) -> void:
    for frame in range(1200):
        if host.initial_region_ready or host.world_loader.phase == "startup_error": return
        await process_frame
    _check(false, "startup completed within frame deadline")

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label)
