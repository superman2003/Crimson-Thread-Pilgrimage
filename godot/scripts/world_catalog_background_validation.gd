extends SceneTree
const LOADER := preload("res://scripts/world_region_loader.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const MAIN := preload("res://scripts/main_level.gd")
const FIXTURE := "user://world_catalog_background_fixture.json"
const SAVE := "user://world_catalog_background_validation.json"
var checks := 0
var failures: Array[String] = []

class Host extends Node:
    var world_catalog: Dictionary = {}
    var world_catalog_prepare_staging: Dictionary = {}

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    root.process_mode = Node.PROCESS_MODE_DISABLED
    var scene: Node = load("res://scenes/World.tscn").instantiate()
    scene.world_resume = false
    scene.world_save_path = SAVE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    var oracle = MAIN.new()
    oracle._begin_world_catalog_prepare()
    for job in oracle._prepare_world_catalog_jobs(): oracle.callv(job.method, job.args)
    oracle._commit_world_catalog_prepare()
    _check(not scene.world_catalog.is_empty() and scene.world_catalog == oracle.world_catalog, "cold startup matches synchronous catalog oracle")
    var reads: Array = scene.world_loader.last_transition.catalog_reads
    _check(reads.size() == ROUTES.cached_chapters().size(), "all regions read once")
    for read in reads:
        _check(not read.worker_is_main and read.bytes > 0 and read.wait_frames >= 1, "region read and parse used background worker")
        _check(read.max_merge_edges <= 64 and read.route_generation == ROUTES.cached_generation(), "catalog merge bounded and generation pinned")
    var reader_id: int = scene.world_loader.config_read_job.get_instance_id()
    var path := ROUTES.cached_config_path("demo_ch02_rain_foundry_canal")
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
    var ok: bool = await scene.world_loader.replace_region_async(scene, path, Vector2(raw.player_start[0], raw.player_start[1]))
    _check(ok and scene.world_loader.last_transition.catalog_reads.is_empty(), "warm travel reuses published catalog without reads")
    _check(scene.world_loader.config_read_job.get_instance_id() == reader_id, "startup catalog and travel share one reader")
    # Invalidate after the catalog was fully assigned, before region handoff.
    # Restoring the empty source snapshot must force a fresh rollback catalog.
    scene.world_catalog = {}
    var invalidation := {"reached": false}
    var invalidate := func():
        if not invalidation.reached and scene.world_loader.phase == "loading" and not scene.world_catalog.is_empty():
            invalidation.reached = true
            ROUTES._cache_generation += 1
    process_frame.connect(invalidate)
    path = ROUTES.cached_config_path("demo_ch01_moss_bell_court")
    raw = JSON.parse_string(FileAccess.get_file_as_string(path))
    ok = await scene.world_loader.replace_region_async(scene, path, Vector2(raw.player_start[0], raw.player_start[1]))
    process_frame.disconnect(invalidate)
    _check(invalidation.reached and not ok and scene.world_loader.last_transition.rolled_back, "post-catalog-commit generation invalidation rolls back")
    _check(scene.world_catalog == oracle.world_catalog and scene.world_catalog_prepare_staging.is_empty(), "rollback restores complete catalog")
    reads = scene.world_loader.last_transition.catalog_reads
    _check(reads.size() == ROUTES.cached_chapters().size(), "rollback rebuilds from restored empty source snapshot")
    for read in reads:
        _check(read.route_generation == ROUTES.cached_generation(), "rollback catalog belongs to current generation")
    await _manifest_change(scene, false)
    await _manifest_change(scene, true)
    oracle.free()
    scene.free()
    await process_frame
    await _faults()
    for suffix in ["", ".bak", ".tmp", ".previous"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE))
    if failures.is_empty():
        print("WORLD CATALOG BACKGROUND PASS checks=%d" % checks)
        quit(0)
    else:
        for failure in failures: push_error(failure)
        quit(1)


func _manifest_change(scene: Node, invalid: bool) -> void:
    var original := FileAccess.get_file_as_string(ROUTES.ROUTES_PATH)
    var before_stamp := FileAccess.get_modified_time(ROUTES.ROUTES_PATH)
    var reader_id: int = scene.world_loader.config_read_job.get_instance_id()
    var source_id: String = scene.config.id
    scene.world_catalog = {}
    var change := {"reached": false, "saved": PackedByteArray()}
    await create_timer(1.1).timeout
    var mutate := func():
        if not change.reached and scene.world_loader.phase == "loading" and not scene.world_catalog.is_empty():
            change.reached = true
            change.saved = FileAccess.get_file_as_bytes(SAVE)
            var file := FileAccess.open(ROUTES.ROUTES_PATH, FileAccess.WRITE)
            file.store_string("{broken" if invalid else original + "\n")
            file.close()
    process_frame.connect(mutate)
    var target_id := "demo_ch01_moss_bell_court" if source_id != "demo_ch01_moss_bell_court" else "demo_ch02_rain_foundry_canal"
    var path := ROUTES.cached_config_path(target_id)
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
    var ok: bool = await scene.world_loader.replace_region_async(scene, path, Vector2(raw.player_start[0], raw.player_start[1]))
    process_frame.disconnect(mutate)
    var changed_stamp := FileAccess.get_modified_time(ROUTES.ROUTES_PATH)
    # Restore repository content before evaluating assertions or tearing down.
    var file := FileAccess.open(ROUTES.ROUTES_PATH, FileAccess.WRITE)
    file.store_string(original)
    file.close()
    _check(change.reached and changed_stamp != before_stamp and not ok, "real manifest stamp change rejects target")
    _check(scene.world_loader.config_read_job.get_instance_id() == reader_id, "manifest recovery shares unique reader")
    if invalid:
        _check(scene.world_loader.phase == "startup_error" and scene.world_loading, "invalid manifest leaves half-built gameplay gated")
        var button: Node = scene.world_loader.loading_canvas.find_child("StartupRetry", true, false)
        _check(button is Button and not button.disabled and scene.world_loader.loading_canvas.process_mode == Node.PROCESS_MODE_ALWAYS, "manifest failure exposes enabled root retry control")
        _check(FileAccess.get_file_as_bytes(SAVE) == change.saved and scene.world_catalog.is_empty() and scene.world_catalog_prepare_staging.is_empty(), "failed recovery preserves source save and no target catalog")
    else:
        _check(scene.world_loader.phase == "idle" and scene.config.id == source_id and not scene.world_loading, "changed valid manifest refreshes and rolls back to playable source")
        _check(scene.player.collision_layer != 0 and not scene.world_catalog.is_empty(), "rollback restores collisions and complete catalog")
    # The restored bytes may have a new stamp even though content is identical.
    await scene.world_loader._prepare_routes_manifest(scene, self)


func _faults() -> void:
    var host := Host.new()
    root.add_child(host)
    var loader = LOADER.new()
    var reader_id: int = loader.config_read_job.get_instance_id()
    _write('{"inventory":{"catalog":{"conflict":{"name":"raw"},"raw_only":{"name":"raw"}}}}')
    var overlay := {"conflict": {"name": "route"}, "route_only": {"name": "route"}}
    var result: bool = await _read(loader, host, overlay)
    _check(result and host.world_catalog.is_empty(), "complete region remains staging until atomic commit")
    _check(host.world_catalog_prepare_staging.conflict.name == "route", "route overrides local catalog")
    host.world_catalog_prepare_staging.raw_only.name = "first"
    result = await _read(loader, host, {})
    _check(result and host.world_catalog_prepare_staging.raw_only.name == "first", "first region wins duplicate item")
    host.world_catalog_prepare_staging = {"partial": {}}
    loader.phase = "loading"
    process_frame.connect(func(): loader.cancel_transition(), CONNECT_ONE_SHOT)
    result = await _read(loader, host, {})
    _check(not result and host.world_catalog.is_empty() and host.world_catalog_prepare_staging.is_empty(), "worker wait cancellation discards staging")
    loader.cancel_requested = false
    result = await _read(loader, host, {})
    _check(result and loader.config_read_job.get_instance_id() == reader_id, "retry reuses same reader after cancelled ticket")
    var large := {}
    for index in range(193): large["item_%d" % index] = {"name": str(index)}
    _write(JSON.stringify({"inventory": {"catalog": large}}))
    host.world_catalog_prepare_staging = {}
    var merged_cancel := {"reached": false}
    var cancel_merge := func():
        if not host.world_catalog_prepare_staging.is_empty():
            merged_cancel.reached = true
            loader.cancel_transition()
    process_frame.connect(cancel_merge)
    result = await _read(loader, host, {})
    process_frame.disconnect(cancel_merge)
    _check(merged_cancel.reached and not result and host.world_catalog_prepare_staging.is_empty(), "merge cancellation discards populated staging")
    loader.cancel_requested = false
    result = await _read(loader, host, {})
    var large_read: Dictionary = loader.last_transition.catalog_reads.back()
    _check(result and host.world_catalog_prepare_staging.size() == 193 and large_read.merge_batches == 4 and large_read.max_merge_edges == 64, "large catalog transfers in bounded merge batches")
    for bad in ["{broken", "[]", '{"inventory":{"catalog":[]}}']:
        _write(bad)
        host.world_catalog_prepare_staging = {"partial": {}}
        result = await _read(loader, host, {})
        _check(not result and host.world_catalog.is_empty() and host.world_catalog_prepare_staging.is_empty(), "bad catalog cannot publish partial result")
    _write('{"inventory":{"catalog":{"item":{}}}}')
    host.world_catalog_prepare_staging = {"partial": {}}
    process_frame.connect(func(): loader.generation += 1, CONNECT_ONE_SHOT)
    result = await _read(loader, host, {})
    _check(not result and host.world_catalog_prepare_staging.is_empty(), "generation invalidation rejects worker result")
    process_frame.connect(func(): ROUTES._cache_generation += 1, CONNECT_ONE_SHOT)
    result = await _read(loader, host, {})
    _check(not result and host.world_catalog_prepare_staging.is_empty(), "route generation invalidation rejects worker result")
    process_frame.connect(func(): root.remove_child(host), CONNECT_ONE_SHOT)
    result = await _read(loader, host, {})
    _check(not result and host.world_catalog_prepare_staging.is_empty(), "host detach rejects worker result")
    root.add_child(host)
    # Ensure the next real filesystem write has a distinct second-resolution stamp.
    await create_timer(1.1).timeout
    process_frame.connect(func(): _write('{"inventory":{"catalog":{"changed":{}}}}'), CONNECT_ONE_SHOT)
    result = await _read(loader, host, {})
    _check(not result and host.world_catalog_prepare_staging.is_empty(), "source stamp invalidation rejects handoff")
    process_frame.connect(func(): host.free(), CONNECT_ONE_SHOT)
    result = await _read(loader, host, {})
    _check(not result, "host free rejects worker result safely")
    loader.shutdown()
    _check(not loader.config_read_job.busy(), "teardown drains unique reader")

func _read(loader: RefCounted, host: Node, overlay: Dictionary) -> bool:
    return await loader._prepare_catalog_region_async(host, "fixture", overlay, self, loader.generation, ROUTES.cached_generation(), true, FIXTURE)

func _write(content: String) -> void:
    var file := FileAccess.open(FIXTURE, FileAccess.WRITE)
    file.store_string(content)
    file.close()

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label)
