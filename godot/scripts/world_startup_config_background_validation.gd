extends SceneTree
## Startup/lease fault fixtures; not a natural damage-enabled campaign run.
const MAIN := preload("res://scripts/main_level.gd")
const LOADER := preload("res://scripts/world_region_loader.gd")
const READER := preload("res://scripts/world_config_read_job.gd")
const VALIDATOR := preload("res://scripts/world_config_validator.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const COORDINATES := preload("res://scripts/world_coordinates.gd")
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

class StartupHost extends Node:
    var config_path := ""
    var entry_spawn_override_enabled := false
    var entry_spawn_override := Vector2.ZERO

class FailedStartReader extends "res://scripts/world_config_read_job.gd":
    var attempts := 0
    func request(_path: String) -> int:
        attempts += 1
        return 0

class FaultReader extends "res://scripts/world_config_read_job.gd":
    var fault := ""
    func request_validation(raw: Variant, path: String, entry: Vector2, use_default_entry: bool, route_context: Dictionary) -> int:
        if fault == "validation_launch": return 0
        return super.request_validation(raw, path, entry, use_default_entry, route_context)
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
    await _background_validation_oracle()
    await _default_entry_oracle()
    await _reader_ownership()
    await _early_startup_cancellation()
    await _teardown_and_faults()
    await _validation_teardown_ownership()
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
    var reader_id: int = host.world_loader.config_read_job.get_instance_id()
    _check(not is_instance_valid(host.player), "startup attachment creates no partial region")
    await _wait(host)
    _check(host.initial_region_ready and host.config == expected and host.received_prepared, "explicit World region matches synchronous validation oracle")
    _check(host.config_content_reads == 0, "World initial config never reads content on main thread")
    var metric: Dictionary = host.world_loader.last_transition
    _check(not metric.startup_config_worker_is_main and metric.startup_config_bytes > 0 and metric.startup_config_wait_frames >= 1, "startup config read and parse run in shared background worker")
    _check(not metric.startup_config_validation_worker_is_main and metric.startup_config_validation_steps > 900 and metric.startup_config_validation_wait_frames >= 1, "complete scalar validation and route overlay run on the sole worker")
    _check(metric.startup_config_context_copy_batches >= 1 and metric.startup_config_context_copy_max_operations <= 8 and metric.startup_config_context_max_step_edges <= 512, "private route snapshot uses bounded main-thread copy operations")
    _check(metric.route_manifest_copy_max_operations <= 8, "manifest handoff preserves main-thread operation cap")
    for catalog_read in metric.catalog_reads:
        _check(catalog_read.max_merge_operations <= 8 and catalog_read.max_merge_edges <= 64, "catalog source scheduling preserves both operation and chunk caps")
    _check(host.active_spawn == Vector2(expected.player_start[0], expected.player_start[1]), "new game uses authored final player_start")
    _check(metric.startup_config_lease.route_generation == ROUTES.cached_generation(), "cold manifest is pinned before startup config")
    _check(host.world_loader.config_read_job.get_instance_id() == reader_id and metric.route_manifest_bytes > 0 and not metric.catalog_reads.is_empty(), "manifest, startup config and catalog keep the same reader instance")
    _check(not host.world_loader.config_read_job.busy() and not host.world_loader.config_read_job.has_pending_ticket(), "published startup releases the sole reader ticket")
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

func _validation_context(region_id: String) -> Dictionary:
    return {"generation": ROUTES.cached_generation(), "region_id": region_id,
        "known_region": COORDINATES.has_region(region_id), "path": ROUTES.cached_config_path(region_id),
        "world_size": COORDINATES.region_bounds(region_id).size,
        "bundle": ROUTES.cached_overlay_bundle(region_id).duplicate(true)}

func _background_validation_oracle() -> void:
    var reader := READER.new()
    for region_id in ROUTES.cached_chapters():
        var path := ROUTES.cached_config_path(region_id)
        var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
        var untouched := raw.duplicate(true)
        var context := _validation_context(region_id)
        var untouched_context := context.duplicate(true)
        var oracle := VALIDATOR.new()
        oracle.begin(raw, path, Vector2.ZERO, true)
        var oracle_operations: Dictionary = {}
        while not oracle.done:
            oracle.step()
            oracle_operations[oracle.operation_name] = int(oracle_operations.get(oracle.operation_name, 0)) + 1
        var foreign_ticket := reader.request(path)
        while reader.busy(): await process_frame
        _check(reader.request_validation(raw, path, Vector2.ZERO, true, context) == 0 and reader.has_pending_ticket(), "validation cannot steal an accepted completed read")
        _check(reader.take(foreign_ticket).get("raw") is Dictionary, "foreign read remains consumable after rejected validation admission")
        var ticket := reader.request_validation(raw, path, Vector2.ZERO, true, context)
        # The worker must use its private snapshot even when the global cache
        # generation changes. The production loader separately rejects this
        # lease change before consuming or publishing any worker result.
        var generation := ROUTES._cache_generation
        ROUTES._cache_generation += 1
        while reader.busy(): await process_frame
        var validated := reader.take(ticket)
        ROUTES._cache_generation = generation
        _check(not validated.worker_is_main and validated.error.is_empty() and validated.prepared == oracle.result, region_id + " background result fully equals the synchronous oracle despite live cache changes")
        for operation in ["header", "records", "identity", "profiles", "profile", "terrain", "cave", "cave_rectangle", "platform", "world", "world_dimension", "world_bounds", "entry"]:
            _check(validated.validator_operations.get(operation, 0) == oracle_operations.get(operation, 0), region_id + " worker preserves every " + operation + " check")
        _check(raw == untouched and context == untouched_context, region_id + " validation leaves its raw input and private route context unchanged")
        _check(not reader.busy() and not reader.has_pending_ticket(), region_id + " validation transfers and releases its sole ticket")
    var ticket := reader.request_validation({}, "", Vector2.ZERO, true, {})
    while reader.busy(): await process_frame
    _check(not reader.take(ticket).get("error", "").is_empty(), "worker refuses missing private context instead of reading a live cache")
    reader.shutdown()
    _check(reader.request_validation({}, "", Vector2.ZERO, true, {}) == 0, "closed reader refuses new validation tasks")

func _validation_teardown_ownership() -> void:
    var host := ProbeWorld.new()
    host.world_mode = true
    host.world_resume = false
    host.world_save_path = SAVE
    host.config_path = ROUTES.cached_config_path(REGION)
    root.add_child(host)
    var loader: RefCounted = host.world_loader
    var reader: RefCounted = loader.config_read_job
    var token: RefCounted = loader.startup_token
    for _frame in range(120):
        if loader.last_transition.has("startup_config_validation_wait_frames"): break
        await process_frame
    _check(loader.last_transition.has("startup_config_validation_wait_frames") and reader.has_pending_ticket(), "teardown fixture reaches accepted validation task")
    host.free()
    _check(token.finished and token.cancelled and loader.startup_token == null and loader._startup_frame_tree == null, "validation teardown synchronously releases owned startup and private frame wakeup")
    _check(not reader.busy() and not reader.has_pending_ticket() and reader.closed, "validation teardown joins the sole worker before another frame")
    var loader_ref: WeakRef = weakref(loader)
    var token_ref: WeakRef = weakref(token)
    var reader_ref: WeakRef = weakref(reader)
    loader = null
    token = null
    reader = null
    _check(loader_ref.get_ref() == null and token_ref.get_ref() == null and reader_ref.get_ref() == null, "validation teardown releases loader, token and reader without another frame")
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
    for malformed in [[120], "120,500", ["120", 500], [999999, 999999]]:
        raw.player_start = malformed
        validator.begin(raw, path, Vector2.ZERO, true)
        while not validator.done: validator.step()
        _check(validator.result.is_empty(), "malformed or out-of-bounds authored default is rejected: " + str(malformed))

func _reader_ownership() -> void:
    var host := StartupHost.new()
    host.config_path = ROUTES.cached_config_path(REGION)
    root.add_child(host)
    var loader := LOADER.new()
    loader.phase = "startup"
    var reader_id: int = loader.config_read_job.get_instance_id()
    var foreign_ticket: int = loader.config_read_job.request(host.config_path)
    while loader.config_read_job.busy(): await process_frame
    var pending := {"frames": 0, "read": {}}
    var release := func():
        pending.frames += 1
        if pending.frames == 3:
            pending.read = loader.config_read_job.take(foreign_ticket)
    process_frame.connect(release)
    var prepared: Dictionary = await loader._prepare_startup_config(host, self)
    process_frame.disconnect(release)
    _check(not prepared.is_empty() and pending.frames >= 3 and pending.read.get("raw") is Dictionary, "startup waits for completed foreign ticket without consuming it")
    _check(loader.config_read_job.get_instance_id() == reader_id and not loader.config_read_job.has_pending_ticket(), "startup contention resolves using the same sole reader")
    foreign_ticket = loader.config_read_job.request(host.config_path)
    while loader.config_read_job.busy(): await process_frame
    process_frame.connect(func(): host.entry_spawn_override_enabled = true, CONNECT_ONE_SHOT)
    prepared = await loader._prepare_startup_config(host, self)
    _check(prepared.is_empty() and loader.config_read_job._accepted == foreign_ticket and loader.config_read_job.has_pending_ticket(), "invalidated startup waiting preserves foreign ticket ownership")
    var foreign_read: Dictionary = loader.config_read_job.take(foreign_ticket)
    _check(foreign_read.get("raw") is Dictionary, "foreign owner receives its completed result after startup invalidation")
    host.entry_spawn_override_enabled = false
    prepared = await loader._prepare_startup_config(host, self)
    _check(not prepared.is_empty() and loader.config_read_job.get_instance_id() == reader_id, "startup can retry after ownership-preserving invalidation")
    loader.shutdown()
    var failed := LOADER.new()
    var failed_reader := FailedStartReader.new()
    failed.config_read_job = failed_reader
    prepared = await failed._prepare_startup_config(host, self)
    _check(prepared.is_empty() and failed_reader.attempts == 1 and not failed.last_error.is_empty(), "idle startup launch failure terminates after one attempt")
    failed.shutdown()
    var closed := LOADER.new()
    closed.config_read_job.shutdown()
    prepared = await closed._prepare_startup_config(host, self)
    _check(prepared.is_empty() and not closed.last_error.is_empty(), "closed startup reader rejects promptly")
    closed.shutdown()
    host.free()
    await process_frame

func _early_startup_cancellation() -> void:
    for boundary in ["before_first_frame", "manifest_foreign_ticket", "manifest_copy"]:
        var host := ProbeWorld.new()
        host.world_mode = true
        host.world_resume = false
        host.world_save_path = SAVE
        host.config_path = ROUTES.cached_config_path(REGION)
        var before_save := FileAccess.get_file_as_bytes(SAVE)
        var route_generation := ROUTES.cached_generation()
        root.add_child(host)
        var loader: RefCounted = host.world_loader
        var reader: RefCounted = loader.config_read_job
        var token: RefCounted = loader.startup_token
        var foreign_ticket := 0
        var injected := {"done": false}
        var cancel_copy := func():
            if not injected.done and loader.manifest_refresh_running and not reader.has_pending_ticket() and not loader.last_transition.has("startup_config_lease"):
                injected.done = true
                token.cancel()
        if boundary == "before_first_frame":
            token.cancel()
            injected.done = true
        elif boundary == "manifest_foreign_ticket":
            foreign_ticket = reader.request(host.config_path)
            while reader.busy(): await process_frame
            _check(foreign_ticket != 0 and reader.has_pending_ticket(), "manifest cancellation fixture owns completed foreign ticket")
            # A tiny foreign read can finish before the first status poll.
            # Reach the manifest waiter before cancelling, never just repeat
            # the separate pre-frame cancellation case by accident.
            await process_frame
            var wait_entered := false
            for _frame in range(120):
                if loader.manifest_refresh_running and reader._accepted == foreign_ticket and not loader.last_transition.has("startup_config_lease"):
                    wait_entered = true
                    break
                if token.finished: break
                await process_frame
            _check(wait_entered, "manifest cancellation reaches the foreign-ticket wait boundary")
            token.cancel()
            injected.done = wait_entered
        else:
            process_frame.connect(cancel_copy)
        for _frame in range(1200):
            if token.finished: break
            await process_frame
        if boundary == "manifest_copy": process_frame.disconnect(cancel_copy)
        _check(injected.done and token.finished and loader.startup_token == null, boundary + " cancellation reaches a terminal owned task")
        _check(loader.phase == "startup_error" and is_instance_valid(loader.loading_canvas) and loader.loading_canvas.get_node("StartupRetry") is Button, boundary + " cancellation exposes retry")
        _check(not host.initial_region_ready and not is_instance_valid(host.player), boundary + " cancellation cannot construct or publish a partial region")
        _check(FileAccess.get_file_as_bytes(SAVE) == before_save and host.world_catalog.is_empty() and host.world_catalog_prepare_staging.is_empty(), boundary + " cancellation preserves source save/catalog")
        _check(ROUTES.cached_generation() == route_generation, boundary + " cancellation cannot publish a route manifest")
        if boundary == "manifest_foreign_ticket":
            _check(reader._accepted == foreign_ticket and reader.has_pending_ticket(), "manifest cancellation keeps foreign ticket ownership")
            var foreign_read: Dictionary = reader.take(foreign_ticket)
            _check(foreign_read.get("raw") is Dictionary, "foreign owner receives completed result after manifest cancellation")
        else:
            _check(not reader.has_pending_ticket(), boundary + " cancellation leaves no owned reader ticket")
        if boundary == "before_first_frame":
            _check(reader._serial == 0, "pre-frame cancellation starts no worker")
        host.free()
        await process_frame

func _teardown_and_faults() -> void:
    for fault in ["parse", "shape", "stamp", "spawn", "loader_generation", "route_generation", "detach", "free", "shutdown", "wait_path", "wait_entry", "validator_entry", "post_build_stamp", "post_build_entry", "post_build_path", "post_finish_entry", "post_finish_path", "post_catalog_entry", "post_catalog_path", "post_finish_generation", "token_cancel", "validation_launch", "validation_wait_route_generation", "validation_wait_path", "validation_wait_free", "validation_wait_shutdown", "validation_wait_cancel"]:
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
        var source_catalog: Dictionary = host.world_catalog
        var source_state: Dictionary = host.world_state.data.duplicate(true)
        var injected := {"done": false}
        var inject := func():
            var metric: Dictionary = loader.last_transition
            if injected.done: return
            if fault.begins_with("validation_wait_"):
                if not metric.has("startup_config_validation_wait_frames"): return
                injected.done = true
                match fault:
                    "validation_wait_route_generation": ROUTES._cache_generation += 1
                    "validation_wait_path": host.config_path = ROUTES.cached_config_path("demo_ch01_moss_bell_court")
                    "validation_wait_free": host.free()
                    "validation_wait_shutdown": loader.shutdown()
                    "validation_wait_cancel": loader.startup_token.cancel()
                return
            if fault.begins_with("post_"):
                if fault.begins_with("post_catalog_") and host.world_catalog.is_empty(): return
                if fault.begins_with("post_build_") and int(metric.get("max_build_operations", 0)) == 0: return
                if fault.begins_with("post_finish_") and (int(metric.get("commit_jobs", 0)) == 0 or metric.get("commit_cursor", 0) != metric.get("commit_jobs", 0)): return
                match fault:
                    "post_build_stamp": metric.startup_config_lease.stamp = -1
                    "post_build_entry", "post_finish_entry", "post_catalog_entry":
                        host.entry_spawn_override_enabled = true
                        host.entry_spawn_override = Vector2(INF, 0)
                    "post_build_path", "post_finish_path", "post_catalog_path": host.config_path = ROUTES.cached_config_path("demo_ch01_moss_bell_court")
                    "post_finish_generation": ROUTES._cache_generation += 1
                injected.done = true
            elif metric.has("startup_config_lease"):
                if fault == "validator_entry" and not metric.has("startup_config_validation_wait_frames"): return
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
                    "token_cancel": loader.startup_token.cancel()
        process_frame.connect(inject)
        for frame in range(1200):
            if loader.phase in ["startup_error", "idle"]: break
            await process_frame
        process_frame.disconnect(inject)
        # Prove task/ticket release before test cleanup can mask an ownership leak.
        for _frame in range(120):
            if loader.startup_token == null and not reader.busy(): break
            await process_frame
        _check(loader.startup_token == null and not reader.has_pending_ticket(), fault + " releases task and accepted ticket before explicit cleanup")
        _check(injected.done, fault + " reaches its declared fault boundary")
        _check(not is_instance_valid(host) or not host.initial_region_ready, fault + " cannot publish region")
        _check(FileAccess.get_file_as_bytes(SAVE) == before_save, fault + " preserves existing save bytes")
        if fault not in ["detach", "free", "shutdown", "validation_wait_free", "validation_wait_shutdown"]:
            _check(loader.phase == "startup_error" and is_instance_valid(loader.loading_canvas) and loader.loading_canvas.get_node("StartupRetry") is Button, fault + " exposes retry recovery")
            if not fault.begins_with("post_"): _check(not is_instance_valid(host.player), fault + " fails before any region construction")
        if is_instance_valid(host):
            _check(host.world_catalog == source_catalog and host.world_catalog_prepare_staging.is_empty(), fault + " restores source catalog without partial staging")
            _check(host.world_state.data == source_state, fault + " preserves durable WorldState including story")
            host.free()
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
