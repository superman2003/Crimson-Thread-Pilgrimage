extends SceneTree
const LOADER := preload("res://scripts/world_region_loader.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const READER := preload("res://scripts/world_config_read_job.gd")
const COORD := preload("res://scripts/world_coordinates.gd")
const SAVE := "user://world_metadata_background_validation.json"
const SOURCE := "user://world_metadata_background_fixture.json"
const OTHER := "user://world_metadata_background_other.json"
var checks := 0
var failures: Array[String] = []

class ProbeWorld extends "res://scripts/main_level.gd":
    var synchronous_metadata_calls := 0
    func _load_world_shared_json(path: String) -> Dictionary:
        synchronous_metadata_calls += 1
        return super._load_world_shared_json(path)

class FixtureHost extends "res://scripts/main_level.gd":
    func _ready() -> void:
        process_mode = Node.PROCESS_MODE_DISABLED

class FailingReader extends "res://scripts/world_config_read_job.gd":
    var fail_once := true
    func take(ticket: int) -> Dictionary:
        var result := super.take(ticket)
        if fail_once:
            fail_once = false
            result.error = "fixture failed read"
        return result

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
    root.process_mode = Node.PROCESS_MODE_DISABLED
    await _production()
    await _fixtures()
    var snapshot := COORD.manifest()
    var version := COORD.layout_version()
    var region_id := String(snapshot.regions.keys()[0])
    var origin := COORD.to_world(region_id, Vector2.ZERO)
    snapshot.version = -999
    snapshot.regions[region_id].origin[0] = -999999
    _check(COORD.layout_version() == version and COORD.to_world(region_id, Vector2.ZERO) == origin, "coordinate queries preserve public manifest snapshot isolation")
    _check(COORD.region_bounds(region_id).position == origin and COORD.has_region(region_id), "coordinate read-only queries agree without snapshot mutation")
    for path in [SOURCE, OTHER, SAVE, SAVE + ".bak", SAVE + ".tmp", SAVE + ".previous"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    if failures.is_empty():
        print("WORLD METADATA BACKGROUND PASS checks=%d" % checks)
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
    _check(host.initial_region_ready and host.synchronous_metadata_calls == 0, "World startup never invokes synchronous shared metadata content loader")
    var records: Array = host.world_loader.last_transition.metadata_reads
    _check(records.size() == 8 and host.world_shared_metadata_cache.size() == 8, "startup prepares all eight immutable sources")
    var reader_id: int = host.world_loader.config_read_job.get_instance_id()
    for record in records:
        _check(not record.cache_hit and record.worker_used and not record.worker_is_main and record.wait_frames >= 1, "cold metadata read and parse use the unique worker")
        _check(record.max_copy_edges <= 512 and record.copy_batches > 0, "cold metadata cache handoff is bounded")
        var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(record.path))
        _check(host.world_shared_metadata_cache[record.path].data == expected, "worker cache matches independent synchronous JSON oracle")
    var before := host.world_shared_metadata_snapshot()
    var path := ROUTES.cached_config_path("demo_ch02_rain_foundry_canal")
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
    var ok: bool = await host.world_loader.replace_region_async(host, path, Vector2(raw.player_start[0], raw.player_start[1]))
    _check(ok and host.world_loader.last_transition.metadata_reads.size() == 8, "warm travel prepares the same eight metadata jobs")
    _check(host.world_shared_metadata_reads == before.reads and host.world_shared_metadata_parses == before.parses and host.synchronous_metadata_calls == 0, "warm travel does not reread or reparse metadata")
    _check(host.world_loader.last_transition.metadata_reads.all(func(record): return record.cache_hit and not record.worker_used and record.max_copy_edges <= 512), "warm consumers use bounded isolated copies")
    _check(host.world_loader.config_read_job.get_instance_id() == reader_id, "startup, travel and metadata share one reader")
    # Cancel while the target owns a metadata-copy job, then allow source rollback.
    var cancel := {"reached": false}
    var on_frame := func():
        if not cancel.reached and host.world_loader.phase == "loading":
            for record in host.world_loader.last_transition.get("metadata_reads", []):
                if record.copy_batches > 0:
                    cancel.reached = true
                    host.world_loader.cancel_transition()
                    break
    process_frame.connect(on_frame)
    path = ROUTES.cached_config_path("demo_ch01_moss_bell_court")
    raw = JSON.parse_string(FileAccess.get_file_as_string(path))
    ok = await host.world_loader.replace_region_async(host, path, Vector2(raw.player_start[0], raw.player_start[1]))
    process_frame.disconnect(on_frame)
    _check(cancel.reached and not ok and host.world_loader.last_transition.rolled_back and host.world_loader.phase == "idle", "metadata cancellation returns to complete source region")
    _check(host.config.id == "demo_ch02_rain_foundry_canal" and host.world_shared_metadata_reads == before.reads, "rollback retains metadata cache and cumulative read counts")
    host.free()
    await process_frame

func _fixtures() -> void:
    var host := FixtureHost.new()
    host.world_mode = true
    root.add_child(host)
    var loader := LOADER.new()
    loader.phase = "loading"
    var key: String = host._world_shared_metadata_key(SOURCE)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(SOURCE))
    var result: Dictionary = await _read(loader, host)
    _check(result.complete and result.data.is_empty() and not host.world_shared_metadata_cache.has(key), "missing metadata degrades to empty without cache")
    _check(int(host.world_shared_metadata_probes[key]) == 1 and int(host.world_shared_metadata_failures[key]) == 1 and not host.world_shared_metadata_reads.has(key), "missing source preserves probe/failure accounting")
    for text in ["{broken", "[]", "null"]:
        _write(SOURCE, text)
        result = await _read(loader, host)
        _check(result.complete and result.data.is_empty() and not host.world_shared_metadata_cache.has(key), "bad JSON or root type is not cached")
    _check(int(host.world_shared_metadata_reads[key]) == 3 and int(host.world_shared_metadata_parses[key]) == 3, "failed parse and type attempts each count one read and parse")
    _write(SOURCE, "{}")
    result = await _read(loader, host)
    var empty_reads: int = host.world_shared_metadata_reads[key]
    _check(result.complete and result.data.is_empty() and host.world_shared_metadata_cache.has(key), "valid empty Dictionary is cached distinctly from failure")
    result = await _read(loader, host)
    _check(result.complete and result.data.is_empty() and host.world_shared_metadata_reads[key] == empty_reads, "empty Dictionary cache avoids reread")
    _write(SOURCE, '{"nested":{"value":"repaired"}}')
    result = await _read(loader, host)
    result.data.nested.value = "consumer mutation"
    _check(host.world_shared_metadata_cache[key].data.nested.value == "repaired", "cold consumer cannot mutate cache nested data")
    result = await _read(loader, host)
    result.data.nested.value = "warm mutation"
    _check(host.world_shared_metadata_cache[key].data.nested.value == "repaired", "warm consumer cannot mutate cache nested data")
    _write(SOURCE, "{broken")
    result = await _read(loader, host)
    _check(result.complete and result.data.is_empty() and not host.world_shared_metadata_cache.has(key), "malformed changed source evicts prior valid cache without stale fallback")
    _write(SOURCE, '{"nested":{"value":"repaired"}}')
    result = await _read(loader, host)
    _check(result.data.nested.value == "repaired", "metadata failure permits repaired-source retry")
    _write(OTHER, '{"nested":{"value":"other"}}')
    result = await _read(loader, host, OTHER)
    _check(result.data.nested.value == "other" and host.world_shared_metadata_cache[key].data.nested.value == "repaired", "canonical metadata keys isolate sources")
    var alias := "user://unused/../world_metadata_background_fixture.json"
    var alias_reads: int = host.world_shared_metadata_reads[key]
    result = await _read(loader, host, alias)
    _check(host._world_shared_metadata_key(alias) == key and result.data.nested.value == "repaired" and host.world_shared_metadata_reads[key] == alias_reads, "canonical aliases reuse the same cache entry without another read")
    var sync_reads: Dictionary = host.world_shared_metadata_reads.duplicate()
    host.world_mode = false
    _check(host._load_world_shared_json(OTHER).nested.value == "other" and host.world_shared_metadata_reads == sync_reads, "nonWorld synchronous compatibility does not use World cache counters")
    host.world_mode = true
    # Pin the old cache mtime to the new file stamp so size alone must reject it.
    var size_reads: int = host.world_shared_metadata_reads[key]
    var old_size: int = host.world_shared_metadata_cache[key].size
    _write(SOURCE, '{"nested":{"value":"different-size-source"}}')
    host.world_shared_metadata_cache[key].mtime = FileAccess.get_modified_time(SOURCE)
    result = await _read(loader, host)
    _check(result.data.nested.value == "different-size-source" and host.world_shared_metadata_reads[key] == size_reads + 1 and host.world_shared_metadata_cache[key].size != old_size, "same-mtime source with different size invalidates cache")
    _write(SOURCE, '{"nested":{"value":"repaired"}}')
    result = await _read(loader, host)
    # Same size, different mtime must invalidate a previously valid entry.
    await create_timer(1.1).timeout
    _write(SOURCE, '{"nested":{"value":"changed!"}}')
    result = await _read(loader, host)
    _check(result.data.nested.value == "changed!", "mtime refresh replaces cached source of equal size")
    var large := {"items": []}
    for index in range(1600): large.items.append({"value": float(index)})
    var large_oracle: Dictionary = JSON.parse_string(JSON.stringify(large))
    _write(SOURCE, JSON.stringify(large))
    var observed := {"copy": false, "partial": false}
    var watch_copy := func():
        var records: Array = loader.last_transition.get("metadata_reads", [])
        if not records.is_empty() and records.back().copy_batches > 0:
            observed.copy = true
            observed.partial = observed.partial or host.world_shared_metadata_cache.has(key)
    loader.last_transition.metadata_reads = []
    process_frame.connect(watch_copy)
    result = await _read(loader, host)
    process_frame.disconnect(watch_copy)
    _check(result.data == large_oracle and observed.copy and not observed.partial, "large source publishes only after complete private copy")
    var large_record: Dictionary = loader.last_transition.metadata_reads.back()
    _check(large_record.copy_batches > 1 and large_record.max_copy_edges <= 512, "large metadata copy honors edge budget")
    # Invalidate both warm and cold handoffs using only a user fixture file.
    for cache_state in ["warm", "cold"]:
        if cache_state == "cold":
            host.world_shared_metadata_cache.erase(key)
            _write(SOURCE, JSON.stringify(large))
        loader.last_transition.metadata_reads = []
        var source_change := {"done": false}
        var mutate := func():
            var records: Array = loader.last_transition.metadata_reads
            if not source_change.done and not records.is_empty() and records.back().copy_batches > 0:
                source_change.done = true
                _write(SOURCE, '{"fixed":true}')
        process_frame.connect(mutate)
        result = await _read(loader, host)
        process_frame.disconnect(mutate)
        _check(source_change.done and result.complete and result.data.is_empty() and not host.world_shared_metadata_cache.has(key), cache_state + " source mutation discards copy and obsolete cache")
    result = await _read(loader, host)
    _check(result.data.get("fixed", false), "repaired source retries through same reader")
    var failed_service := LOADER.new()
    failed_service.phase = "loading"
    var failing_reader := FailingReader.new()
    failed_service.config_read_job = failing_reader
    host.world_shared_metadata_cache.erase(key)
    result = await _read(failed_service, host)
    _check(result.complete and result.data.is_empty() and not host.world_shared_metadata_cache.has(key), "worker read error cannot cache a partial or stale source")
    result = await _read(failed_service, host)
    _check(result.data.get("fixed", false) and failed_service.config_read_job == failing_reader, "worker read failure retries on same reader")
    failed_service.shutdown()
    for boundary in ["read", "copy", "generation", "route", "detach", "free", "shutdown"]:
        var probe := FixtureHost.new()
        probe.world_mode = true
        root.add_child(probe)
        var service := LOADER.new()
        service.phase = "loading"
        var reader_id: int = service.config_read_job.get_instance_id()
        _write(SOURCE, JSON.stringify(large))
        var reached := {"done": false}
        var interrupt := func():
            if reached.done: return
            if boundary == "copy":
                var records: Array = service.last_transition.get("metadata_reads", [])
                if records.is_empty() or records.back().copy_batches == 0: return
            reached.done = true
            match boundary:
                "read", "copy": service.cancel_transition()
                "generation": service.generation += 1
                "route": ROUTES._cache_generation += 1
                "detach": root.remove_child(probe)
                "free": probe.free()
                "shutdown": service.shutdown()
        process_frame.connect(interrupt)
        result = await _read(service, probe)
        process_frame.disconnect(interrupt)
        _check(reached.done and not result.complete, boundary + " aborts metadata handoff")
        if is_instance_valid(probe):
            _check(not probe.world_shared_metadata_cache.has(key), boundary + " never exposes partial cache entry")
            if probe.is_inside_tree() and boundary != "shutdown":
                service.cancel_requested = false
                var reads_before_retry: int = probe.world_shared_metadata_reads.get(key, 0)
                result = await _read(service, probe)
                _check(int(probe.world_shared_metadata_reads[key]) == reads_before_retry + 1 and probe.world_shared_metadata_parses[key] == probe.world_shared_metadata_reads[key], boundary + " retry counts one accepted read and parse")
                _check(result.complete and result.data == large_oracle and service.config_read_job.get_instance_id() == reader_id, boundary + " retries with the original reader")
            probe.free()
        service.shutdown()
        _check(not service.config_read_job.busy(), boundary + " releases worker on teardown")
        await process_frame
    loader.shutdown()
    host.free()
    await process_frame

func _read(loader: RefCounted, host: Node, path: String = SOURCE) -> Dictionary:
    return await loader._prepare_shared_metadata_async(host, path, self, loader.generation, ROUTES.cached_generation(), true)

func _write(path: String, text: String) -> void:
    var file := FileAccess.open(path, FileAccess.WRITE)
    file.store_string(text)
    file.close()

func _wait(host: Node) -> void:
    for frame in range(1200):
        if host.initial_region_ready or host.world_loader.phase == "startup_error": return
        await process_frame
    _check(false, "World startup reaches publication before deadline")

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label)
