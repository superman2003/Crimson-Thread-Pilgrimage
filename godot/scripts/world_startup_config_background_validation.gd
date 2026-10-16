extends SceneTree
## Startup/lease fault fixtures; not a natural damage-enabled campaign run.
const MAIN := preload("res://scripts/main_level.gd")
const LOADER := preload("res://scripts/world_region_loader.gd")
const READER := preload("res://scripts/world_config_read_job.gd")
const VALIDATOR := preload("res://scripts/world_config_validator.gd")
const OVERLAY := preload("res://scripts/world_route_overlay_job.gd")
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

class ReadAheadHost extends StartupHost:
    var world_start_region_id := ""
    func _resolve_world_start_route() -> bool:
        if world_start_region_id.is_empty(): return true
        config_path = ROUTES.cached_config_path(world_start_region_id)
        return not config_path.is_empty()

class SerialManifestLoader extends "res://scripts/world_region_loader.gd":
    func _begin_startup_config_read_ahead(_host: Node, _tree: SceneTree, _route_ticket: Dictionary) -> void:
        pass

class FrameDelayedReader extends "res://scripts/world_config_read_job.gd":
    var fixture_path := ""
    var fixture_read: Dictionary = {}
    var held_ticket := 0
    var held_frame := -1
    var taken_frame := -1
    var manifest_taken_frame := -1
    var config_requests := 0
    var reject_first := false
    func request(path: String) -> int:
        if path != fixture_path: return super.request(path)
        config_requests += 1
        if reject_first and config_requests == 1: return 0
        if config_requests > (2 if reject_first else 1): return super.request(path)
        if closed or busy() or has_pending_ticket(): return 0
        # Deterministic availability, not a wall-clock performance assertion.
        # The real file was read before this fixture's measured frame window.
        _serial += 1
        _accepted = _serial
        held_ticket = _accepted
        held_frame = Engine.get_process_frames()
        return held_ticket
    func busy() -> bool:
        return super.busy() or (not closed and _accepted == held_ticket and held_ticket != 0 and Engine.get_process_frames() - held_frame < 24)
    func take(ticket: int) -> Dictionary:
        if ticket == held_ticket and ticket == _accepted and not busy():
            _accepted = 0
            taken_frame = Engine.get_process_frames()
            return fixture_read
        var result := super.take(ticket)
        if result.get("raw") is Dictionary and result.raw.has("chapters"):
            manifest_taken_frame = Engine.get_process_frames()
        return result

class FailedStartReader extends "res://scripts/world_config_read_job.gd":
    var attempts := 0
    func request(_path: String) -> int:
        attempts += 1
        return 0

class ExitDiagnosticsLoader extends "res://scripts/world_region_loader.gd":
    var exit_snapshots: Array = []
    var pre_shutdown_states: Array = []
    func _write_startup_exit_snapshot(snapshot: Dictionary) -> void:
        exit_snapshots.append(snapshot)
        pre_shutdown_states.append({"phase": phase, "shutting_down": shutting_down,
            "cancel_requested": cancel_requested, "reader_closed": config_read_job.closed,
            "reader_pending": config_read_job.has_pending_ticket(),
            "token_cancelled": startup_token != null and startup_token.cancelled})
        super._write_startup_exit_snapshot(snapshot)

class FaultReader extends "res://scripts/world_config_read_job.gd":
    var fault := ""
    func request_validation(raw: Variant, path: String, entry: Vector2, use_default_entry: bool, route_context: Dictionary) -> int:
        if fault == "validation_launch": return 0
        if fault == "overlay_type": route_context.bundle.overlay = {"world_overrides": 42}
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
    _startup_exit_diagnostics_contract()
    if "--startup-exit-diagnostics-only" in OS.get_cmdline_user_args():
        if failures.is_empty():
            print("WORLD STARTUP EXIT DIAGNOSTICS PASS checks=%d verbose=%s" % [checks, OS.is_stdout_verbose()])
            quit(0)
        else:
            for failure in failures: push_error(failure)
            quit(1)
        return
    await _manifest_read_ahead_contract()
    if "--startup-manifest-read-ahead-only" in OS.get_cmdline_user_args():
        if failures.is_empty():
            print("WORLD STARTUP MANIFEST READ AHEAD PASS checks=%d" % checks)
            quit(0)
        else:
            for failure in failures: push_error(failure)
            quit(1)
        return
    await _new_game_and_resume()
    await _background_validation_oracle()
    _malformed_overlay_steps()
    await _malformed_validation_workers()
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

func _startup_exit_diagnostics_contract() -> void:
    for complete in [false, true]:
        var loader := ExitDiagnosticsLoader.new()
        loader.phase = "idle" if complete else "startup"
        loader.active_region_id = "fixture" if complete else ""
        var token = preload("res://scripts/world_transition_token.gd").new()
        if not complete:
            loader.startup_token = token
            loader.config_read_job._accepted = 7
        loader.last_transition = {"startup_requested_frame": Engine.get_process_frames(),
            "startup_requested_usec": Time.get_ticks_usec(), "jobs": 42, "build_cursor": 17,
            "build_batches": 3, "max_build_operations": 8, "prepare_wall_usec": "SECRET_NUMBER_FIELD",
            "catalog_reads": [{"wait_frames": 2, "read_overlap_frames": 1, "worker_usec": 42,
                "merge_frame_batches": 3, "path": "SECRET_CATALOG_PATH"}],
            "startup_config_lease": {"path": "SECRET_USER_PATH", "payload": "SECRET_SAVE_CONTENT"},
            "untrusted_extra": "SECRET_TOKEN_PAYLOAD"}
        var before := loader.last_transition.duplicate(true)
        var snapshot: Dictionary = loader._startup_exit_snapshot()
        _check(loader.last_transition == before and not loader.shutting_down and not loader.cancel_requested and not token.cancelled, "exit snapshot does not mutate metrics or cancellation state")
        _check(loader.config_read_job.has_pending_ticket() == (not complete) and not loader.config_read_job.closed, "exit snapshot does not consume reader ownership")
        _check(snapshot.stage == ("published" if complete else "build") and snapshot.startup_pending == (not complete), "exit snapshot distinguishes publication from unfinished build")
        _check(snapshot.jobs == 42 and snapshot.build_cursor == 17 and snapshot.build_batches == 3 and snapshot.max_build_operations == 8, "exit snapshot retains numeric build diagnostics")
        _check(snapshot.catalog_read_count == 1 and snapshot.catalog_wait_frames == 2 and snapshot.catalog_read_overlap_frames == 1 and snapshot.catalog_worker_usec == 42 and snapshot.catalog_merge_frame_batches == 3, "exit snapshot aggregates only numeric catalog diagnostics")
        _check(snapshot.elapsed_frames >= 0 and snapshot.elapsed_usec >= 0, "exit snapshot records bounded scalar elapsed diagnostics")
        _check(not JSON.stringify(snapshot).contains("SECRET") and not snapshot.has("startup_config_lease") and not snapshot.has("untrusted_extra") and snapshot.prepare_wall_usec == -1, "exit snapshot excludes save contents paths and private payloads")
        loader.shutdown()
        loader.shutdown()
        _check(loader.exit_snapshots.size() == (1 if OS.is_stdout_verbose() else 0), "verbose shutdown emits once and quiet shutdown emits nothing")
        _check(loader.last_transition == before, "shutdown logging leaves transition metrics unchanged")
        _check(loader.config_read_job.closed and not loader.config_read_job.has_pending_ticket(), "diagnostic teardown still drains reader ownership")
        if OS.is_stdout_verbose():
            var emitted: Dictionary = loader.exit_snapshots[0]
            var state: Dictionary = loader.pre_shutdown_states[0]
            _check(not state.shutting_down and not state.cancel_requested and not state.reader_closed and not state.token_cancelled, "exit logging occurs before cancel join and clear")
            _check(state.reader_pending == (not complete) and emitted.reader_pending == (not complete) and emitted.phase == ("idle" if complete else "startup"), "exit logging captures original owner and phase")
    var unused := ExitDiagnosticsLoader.new()
    unused.shutdown()
    _check(unused.exit_snapshots.is_empty(), "non-startup loader does not emit startup diagnostics")

func _manifest_read_ahead_contract() -> void:
    var path := "res://data/demo_ch01_moss_bell_court.json"
    var source_read: Dictionary = READER._read(path)
    var observations := []
    for mode in ["overlap", "serial", "rejected", "resume"]:
        var host := ReadAheadHost.new()
        host.config_path = path
        if mode == "resume":
            host.config_path = "res://data/%s.json" % REGION
            host.world_start_region_id = "demo_ch01_moss_bell_court"
        root.add_child(host)
        var loader = SerialManifestLoader.new() if mode == "serial" else LOADER.new()
        loader.phase = "startup"
        var reader := FrameDelayedReader.new()
        reader.fixture_path = path
        reader.fixture_read = source_read.duplicate(true)
        reader.reject_first = mode == "rejected"
        loader.config_read_job = reader
        var before_generation := ROUTES.cached_generation()
        var private_checks := {"observed": false, "untouched": true}
        var observe := func():
            if not loader.startup_config_read_ahead.is_empty():
                private_checks.observed = true
                private_checks.untouched = private_checks.untouched and ROUTES.cached_generation() == before_generation and reader.has_pending_ticket()
        process_frame.connect(observe)
        var manifest_ok: bool = await loader._prepare_routes_manifest(host, self)
        process_frame.disconnect(observe)
        _check(manifest_ok and host._resolve_world_start_route(), mode + " commits manifest before resolving startup path")
        _check(private_checks.untouched, mode + " early result cannot publish private manifest or consume its ticket")
        _check(private_checks.observed == (mode in ["overlap", "resume"]), mode + " read is admitted only during owned manifest copy")
        var prepared: Dictionary = await loader._prepare_startup_config(host, self)
        var metric: Dictionary = loader.last_transition
        var copy_frames := int(metric.route_manifest_copy_batches)
        var context_frames := int(metric.startup_config_context_copy_batches)
        var overlap := int(metric.startup_config_manifest_overlap_frames)
        _check(not prepared.is_empty() and prepared.id == "demo_ch01_moss_bell_court", mode + " delayed result retains complete validated startup semantics")
        _check(reader.config_requests == (2 if mode == "rejected" else 1), mode + " no duplicate startup read; rejected speculation retries normal admission")
        _check(overlap == (copy_frames if mode in ["overlap", "resume"] else 0), mode + " records exactly the existing manifest copy windows")
        var expected_frames := maxi(24, copy_frames + context_frames) if overlap > 0 else copy_frames + maxi(24, context_frames)
        _check(reader.taken_frame - reader.manifest_taken_frame == expected_frames, mode + " 24-frame delayed read overlaps existing windows without extra yields")
        _check(loader.startup_config_read_ahead.is_empty() and not reader.has_pending_ticket() and not reader.busy(), mode + " successful transfer releases every owned ticket")
        observations.append({"mode": mode, "manifest_copy_frames": copy_frames, "context_copy_frames": context_frames,
            "read_available_after_frames": 24, "take_after_manifest_frames": reader.taken_frame - reader.manifest_taken_frame,
            "manifest_overlap_frames": overlap})
        loader.shutdown()
        host.free()
        await process_frame
    print("WORLD_STARTUP_MANIFEST_READ_AHEAD " + JSON.stringify(observations))
    # A replacement host must never claim an earlier host's already-ready result.
    var old_host := ReadAheadHost.new()
    old_host.config_path = path
    root.add_child(old_host)
    var loader := LOADER.new()
    loader.phase = "startup"
    _check(await loader._prepare_routes_manifest(old_host, self), "old host owns speculative read after manifest commit")
    var old_ticket := int(loader.startup_config_read_ahead.ticket)
    while loader.config_read_job.busy(): await process_frame
    _check(not loader.config_read_job.busy() and loader.config_read_job.has_pending_ticket() and loader.config_read_job._accepted == old_ticket, "old host replacement fixture retains an already-ready unconsumed result")
    var replacement := ReadAheadHost.new()
    replacement.config_path = path
    root.add_child(replacement)
    old_host.free()
    var prepared: Dictionary = await loader._prepare_startup_config(replacement, self)
    _check(prepared.is_empty() and loader.startup_config_read_ahead.is_empty() and not loader.config_read_job.has_pending_ticket(), "replacement host rejects and discards old host result")
    _check(loader.config_read_job.take(old_ticket).is_empty(), "old ticket cannot be reused after host rejection")
    prepared = await loader._prepare_startup_config(replacement, self)
    _check(not prepared.is_empty(), "replacement host can obtain its own fresh validated request")
    loader.shutdown()
    replacement.free()
    await process_frame

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
    _check(metric.startup_config_context_overlap_frames == metric.startup_config_context_copy_batches and metric.startup_config_wait_frames >= metric.startup_config_context_overlap_frames, "private context copy shares owned read waits without double-counting serial frames")
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


func _overlay_type_cases() -> Array[Dictionary]:
    # Ordinary, syntactically valid JSON author mistakes. No source manifest
    # or save is edited. Every actual overlay consumer is represented.
    var cases: Array[Dictionary] = []
    var scalars: Array = [null, false, 42, 1.5, "wrong"]
    for value in scalars + [[]]:
        cases.append({"label": "overlay root " + str(value), "overlay": value})
        for field in ["world_overrides", "inventory_catalog"]:
            cases.append({"label": field + " container " + str(value), "overlay": {field: value}})
    var record_fields: Array = OVERLAY.APPEND_FIELDS.duplicate()
    record_fields.append("portals")
    for pair in OVERLAY.OVERRIDE_FIELDS: record_fields.append(pair[0])
    for field in record_fields + ["remove_interactives"]:
        for value in scalars + [{}]:
            cases.append({"label": field + " container " + str(value), "overlay": {field: value}})
    for field in record_fields:
        for value in scalars + [[]]:
            cases.append({"label": field + " record " + str(value), "overlay": {field: [{}, value]}})
    for value in scalars + [[]]:
        cases.append({"label": "inventory_catalog record " + str(value), "overlay": {"inventory_catalog": {"valid": {}, "invalid": value}}})
    return cases

func _malformed_overlay_steps() -> void:
    var job := OVERLAY.new()
    # The originally reported path reaches a terminal state in exactly one
    # operation, without a worker or an unbounded error/retry loop.
    job.begin({"world": {}}, {"world_overrides": 42}, 1)
    job.step(1, 1)
    _check(job.done and not job.error.is_empty() and job.result.is_empty() and job.total_operations == 1, "numeric world_overrides terminates after one checked operation")
    for sample in _overlay_type_cases():
        job.begin({"world": {}}, sample.overlay, 1)
        for _operation in range(256):
            if job.done: break
            job.step(1, 1)
        _check(job.done and not job.error.is_empty() and job.result.is_empty(), sample.label + " explicitly fails in bounded overlay steps")
    # Reusing a failed job must not retain its error, partial merge or cursor.
    job.begin({"world": {}}, {"world_overrides": {"width": 20}, "inventory_catalog": {"item": {"name": "valid"}}}, 2)
    for _operation in range(256):
        if job.done: break
        job.step(1, 1)
    _check(job.done and job.error.is_empty() and job.result.world.width == 20 and job.result.inventory.catalog.item.name == "valid", "failed overlay can restart with a valid detached config")
    job.begin({"world": {}}, {}, 3)
    _check(job.done and job.error.is_empty() and job.result == {"world": {}}, "empty overlay remains an immediate legacy no-op after failure")

func _malformed_validation_workers() -> void:
    var path := ROUTES.cached_config_path(REGION)
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
    var reader := READER.new()
    var samples: Array[Dictionary] = []
    # One real background task for every container/record consumer. The full
    # JSON type matrix above stays a cheap, explicitly bounded overlay test.
    samples.append({"label": "overlay root", "overlay": 42})
    for field in ["world_overrides", "inventory_catalog", "remove_interactives"]:
        samples.append({"label": field, "overlay": {field: 42}})
    for pair in OVERLAY.OVERRIDE_FIELDS:
        samples.append({"label": pair[0] + " container", "overlay": {pair[0]: 42}})
        samples.append({"label": pair[0] + " record", "overlay": {pair[0]: [42]}})
    for field in OVERLAY.APPEND_FIELDS + ["portals"]:
        samples.append({"label": field + " container", "overlay": {field: 42}})
        samples.append({"label": field + " record", "overlay": {field: [42]}})
    samples.append({"label": "inventory_catalog entry", "overlay": {"inventory_catalog": {"item": 42}}})
    samples.append({"label": "raw catalog container", "raw_field": "catalog"})
    samples.append({"label": "raw region identity", "raw_field": "id"})
    samples.append({"label": "raw enemy kind", "raw_field": "kind"})
    for sample in samples:
        var input := raw.duplicate(true)
        var context := _validation_context(REGION)
        if sample.has("overlay"): context.bundle.overlay = sample.overlay
        match sample.get("raw_field", ""):
            "catalog": input.inventory.catalog = 42
            "id": input.id = 42
            "kind": input.enemy_spawns[0].kind = 42
        var before := input.duplicate(true)
        var context_before := context.duplicate(true)
        var ticket := reader.request_validation(input, path, Vector2.ZERO, true, context)
        _check(ticket != 0, sample.label + " gets sole validation ticket")
        var finished: bool = await _wait_validation_worker(reader)
        _check(finished, sample.label + " worker reaches terminal state within test deadline")
        if not finished:
            # Do not join a regressed infinite worker from the main thread.
            # The outer regression runner's existing timeout remains intact.
            quit(1)
            return
        _check(reader.has_pending_ticket() and reader.request(path) == 0, sample.label + " failed result retains ticket until its owner takes it")
        var validated := reader.take(ticket)
        _check(not validated.get("worker_is_main", true) and not validated.get("error", "").is_empty() and validated.get("prepared", {}).is_empty(), sample.label + " propagates explicit worker error with no prepared config")
        if sample.has("overlay"):
            var expected_field: String = sample.overlay.keys()[0] if sample.overlay is Dictionary else "区域覆盖"
            _check(str(validated.get("error", "")).contains(expected_field), sample.label + " reports the rejected overlay field")
        _check(not reader.busy() and not reader.has_pending_ticket() and reader._thread == null, sample.label + " take reaps thread and releases ticket")
        _check(input == before and context == context_before, sample.label + " failure leaves raw input and private context unchanged")
    # A large valid overlay has no artificial operation/time cutoff. Numeric
    # removal IDs keep the established exact-type matching behavior.
    var context := _validation_context(REGION)
    var wide: Dictionary = {}
    for index in range(4096): wide["fixture_%d" % index] = {"nested": [index, {"value": index}]}
    context.bundle.overlay.world_overrides.merge(wide, true)
    context.bundle.overlay.remove_interactives.append(42)
    var ticket := reader.request_validation(raw, path, Vector2.ZERO, true, context)
    var finished: bool = await _wait_validation_worker(reader)
    _check(finished, "large valid overlay reaches a terminal worker state")
    if not finished:
        quit(1)
        return
    var validated := reader.take(ticket)
    _check(validated.error.is_empty() and validated.prepared.world.fixture_4095.nested[1].value == 4095 and validated.validator_steps > 1000, "large valid overlay is accepted without a fixed validation step cutoff")
    context = _validation_context(REGION)
    context.bundle.overlay = {"world_overrides": 42}
    ticket = reader.request_validation(raw, path, Vector2.ZERO, true, context)
    reader.discard(ticket)
    _check(not reader.has_pending_ticket(), "discard immediately relinquishes failed validation ticket")
    finished = await _wait_validation_worker(reader)
    _check(finished, "discarded malformed validation still terminates")
    if not finished:
        quit(1)
        return
    # Admission must reap a completed abandoned result and recover normally.
    ticket = reader.request_validation(raw, path, Vector2.ZERO, true, _validation_context(REGION))
    finished = await _wait_validation_worker(reader)
    _check(ticket != 0 and finished, "reader can retry after discarding malformed validation")
    if not finished:
        quit(1)
        return
    _check(reader.take(ticket).get("error", "missing").is_empty(), "valid retry after malformed validation succeeds")
    reader.shutdown()
    _check(reader.closed and not reader.busy() and not reader.has_pending_ticket() and reader._thread == null, "failed-validation reader shutdown releases every owned resource")
    # Shutdown is also safe immediately after accepting the invalid task;
    # no intervening frame or successful take can hide a stuck worker.
    reader = READER.new()
    ticket = reader.request_validation(raw, path, Vector2.ZERO, true, context)
    _check(ticket != 0, "immediate malformed shutdown owns a validation ticket")
    reader.shutdown()
    _check(reader.closed and not reader.busy() and not reader.has_pending_ticket() and reader._thread == null, "shutdown joins malformed validation and clears ownership synchronously")

func _wait_validation_worker(reader: RefCounted) -> bool:
    var deadline := Time.get_ticks_msec() + 5000
    while reader.busy() and Time.get_ticks_msec() < deadline:
        await process_frame
    return not reader.busy()

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
            if not injected.done and loader.manifest_refresh_running and (not reader.has_pending_ticket() or not loader.startup_config_read_ahead.is_empty()) and not loader.last_transition.has("startup_config_lease"):
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
    for fault in ["parse", "shape", "stamp", "spawn", "loader_generation", "route_generation", "detach", "free", "shutdown", "wait_path", "wait_entry", "validator_entry", "post_build_stamp", "post_build_entry", "post_build_path", "post_finish_entry", "post_finish_path", "post_catalog_entry", "post_catalog_path", "post_finish_generation", "token_cancel", "validation_launch", "overlay_type", "validation_wait_route_generation", "validation_wait_path", "validation_wait_free", "validation_wait_shutdown", "validation_wait_cancel", "context_copy_path", "context_copy_entry", "context_copy_generation", "context_copy_route", "context_copy_cancel", "context_copy_detach", "context_copy_free", "context_copy_shutdown", "manifest_copy_path", "manifest_copy_entry", "manifest_copy_generation", "manifest_copy_stamp", "manifest_copy_target", "manifest_copy_cancel", "manifest_copy_detach", "manifest_copy_free", "manifest_copy_shutdown"]:
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
            if fault.begins_with("manifest_copy_"):
                if loader.startup_config_read_ahead.is_empty(): return
                _check(reader.has_pending_ticket() and not metric.has("startup_config_lease"), fault + " reaches uncommitted manifest with private pending read")
                injected.done = true
                match fault:
                    "manifest_copy_path": host.config_path = "res://data/demo_ch01_moss_bell_court.json"
                    "manifest_copy_entry": host.entry_spawn_override_enabled = not host.entry_spawn_override_enabled
                    "manifest_copy_generation": loader.generation += 1
                    "manifest_copy_stamp": loader.startup_config_read_ahead.manifest_stamp = -1
                    "manifest_copy_target": host.world_start_region_id = "demo_ch01_moss_bell_court"
                    "manifest_copy_cancel": loader.startup_token.cancel()
                    "manifest_copy_detach": root.remove_child(host)
                    "manifest_copy_free": host.free()
                    "manifest_copy_shutdown": loader.shutdown()
                if fault in ["manifest_copy_detach", "manifest_copy_free", "manifest_copy_shutdown"]:
                    _check(loader.startup_token == null and loader._startup_frame_tree == null and not reader.busy() and not reader.has_pending_ticket() and loader.startup_config_read_ahead.is_empty(), fault + " synchronously drains speculative owner at teardown")
                return
            if fault.begins_with("context_copy_"):
                if int(metric.get("startup_config_context_copy_batches", 0)) == 0: return
                _check(reader.has_pending_ticket() and not metric.has("startup_config_worker_is_main"), fault + " reaches private copy while its read ticket remains unconsumed")
                injected.done = true
                match fault:
                    "context_copy_path": host.config_path = ROUTES.cached_config_path("demo_ch01_moss_bell_court")
                    "context_copy_entry": host.entry_spawn_override_enabled = not host.entry_spawn_override_enabled
                    "context_copy_generation": loader.generation += 1
                    "context_copy_route": ROUTES._cache_generation += 1
                    "context_copy_cancel": loader.startup_token.cancel()
                    "context_copy_detach": root.remove_child(host)
                    "context_copy_free": host.free()
                    "context_copy_shutdown": loader.shutdown()
                if fault in ["context_copy_detach", "context_copy_free", "context_copy_shutdown"]:
                    _check(loader.startup_token == null and loader._startup_frame_tree == null and not reader.busy() and not reader.has_pending_ticket(), fault + " releases owned task and read synchronously before another frame")
                return
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
        if fault not in ["detach", "free", "shutdown", "validation_wait_free", "validation_wait_shutdown", "context_copy_detach", "context_copy_free", "context_copy_shutdown", "manifest_copy_detach", "manifest_copy_free", "manifest_copy_shutdown"]:
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
