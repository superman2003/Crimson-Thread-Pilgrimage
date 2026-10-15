extends SceneTree
const JOB := preload("res://scripts/world_config_read_job.gd")
const LOADER := preload("res://scripts/world_region_loader.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const SAVE := "user://world_config_background_validation.json"
const FIXTURE := "user://world_config_background_fixture.json"
var checks := 0
var failures: Array[String] = []
var cancel_loader: Variant

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var host := Node.new()
    root.add_child(host)
    for region_id in ["demo_ch01_moss_bell_court", "demo_ch02_rain_foundry_canal", "demo_ch03_saltwhite_archive", "demo_ch04_broken_string_greenhouse", "demo_ch05_obsidian_pilgrim_road", "demo_ch06_silent_crown_core"]:
        var path := ROUTES.config_path(region_id)
        var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
        var entry := Vector2(raw.player_start[0], raw.player_start[1])
        var loader = LOADER.new()
        var expected: Dictionary = loader.preflight(path, entry)
        var result: Dictionary = await loader._preflight_async(path, entry, null, host)
        _check(result == expected and not result.is_empty(), region_id + " cold async result equals synchronous result")
        _check(loader.last_transition.json_background and not loader.last_transition.json_worker_is_main, region_id + " read/parse ran outside main thread")
        _check(loader.last_transition.json_wait_frames >= 1 and loader.last_transition.json_bytes > 0, region_id + " yielded and recorded bytes")
        _check(loader.last_transition.preflight_max_operations <= 8, region_id + " validator admission remains bounded")
        loader.shutdown()
    var job = JOB.new()
    var first := job.request(ROUTES.config_path("demo_ch01_moss_bell_court"))
    _check(first > 0, "worker request starts")
    job.discard(first)
    _check(job.take(first).is_empty(), "discarded ticket cannot publish even if worker completed")
    while job.busy(): await process_frame
    var second := job.request(ROUTES.config_path("demo_ch02_rain_foundry_canal"))
    _check(second > first and job.take(first).is_empty(), "new request rejects old ticket")
    while job.busy(): await process_frame
    # A delayed cancellation for an old task cannot erase a finished retry.
    job.discard(first)
    var read: Dictionary = job.take(second)
    _check(read.raw.id == "demo_ch02_rain_foundry_canal", "retry publishes only requested destination")
    _check(job.take(second).is_empty(), "result can only be consumed once")
    var missing := job.request("user://nonexistent_background_region_fixture.json")
    while job.busy(): await process_frame
    _check(not String(job.take(missing).error).is_empty(), "missing file is a data error without engine diagnostics")
    var file := FileAccess.open(FIXTURE, FileAccess.WRITE)
    file.store_string("{broken JSON")
    file.close()
    var invalid_loader = LOADER.new()
    var invalid: Dictionary = await invalid_loader._preflight_async(FIXTURE, Vector2.ZERO, null, host)
    _check(invalid.is_empty() and invalid_loader.last_error == "目标区域记录无法读取。", "malformed JSON retains validator diagnostic")
    invalid_loader.shutdown()
    # Shutdown must join a started thread, and is idempotent; no worker can
    # outlive the owner or be restarted after whole-host teardown.
    job.request(ROUTES.config_path("demo_ch03_saltwhite_archive"))
    job.shutdown()
    job.shutdown()
    _check(not job.busy() and job.request(FIXTURE) == 0, "teardown drains and permanently closes service")
    host.free()
    await _source_cancel()
    for suffix in ["", ".bak", ".tmp", ".previous"]:
        if FileAccess.file_exists(SAVE + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE))
    if failures.is_empty():
        print("WORLD CONFIG BACKGROUND PASS checks=%d" % checks)
        quit(0)
    else:
        for failure in failures: push_error(failure)
        quit(1)

func _source_cancel() -> void:
    var scene: Node = load("res://scenes/World.tscn").instantiate()
    scene.world_resume = false
    scene.world_save_path = SAVE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    for frame in range(4): await process_frame
    scene.process_mode = Node.PROCESS_MODE_DISABLED
    scene.world_prefetch.configs.clear()
    scene.world_prefetch.desired.clear()
    scene.currency_count += 17
    var ids := []
    for child in scene.get_children(): ids.append(child.get_instance_id())
    var state: Dictionary = scene.world_state.data.duplicate(true)
    var position: Vector2 = scene.player.global_position
    var generation: int = scene.world_loader.generation
    var currency: int = scene.currency_count
    var save_bytes := FileAccess.get_file_as_bytes(SAVE)
    cancel_loader = scene.world_loader
    process_frame.connect(_cancel_read, CONNECT_ONE_SHOT)
    var ok: bool = await scene.world_loader.replace_region_async(scene, ROUTES.config_path("demo_ch02_rain_foundry_canal"), Vector2(120,500))
    var after_ids := []
    for child in scene.get_children(): after_ids.append(child.get_instance_id())
    _check(not ok and cancel_loader.last_transition.preflight_cancelled and cancel_loader.last_transition.json_background, "cancel reaches cold background stage")
    _check(ids == after_ids and scene.player.global_position == position, "read cancellation preserves source nodes and player")
    _check(scene.world_loader.generation == generation and scene.world_state.data == state, "read cancellation precedes generation and state publication")
    _check(FileAccess.get_file_as_bytes(SAVE) == save_bytes and scene.currency_count == currency, "read cancellation preserves save and unsaved currency")
    _check(scene.world_loader.phase == "idle" and scene.process_mode == Node.PROCESS_MODE_DISABLED, "read cancellation restores source process mode")
    var result: Dictionary = await scene.world_loader._preflight_async(ROUTES.config_path("demo_ch03_saltwhite_archive"), Vector2(120,500), null, scene)
    _check(result.get("id") == "demo_ch03_saltwhite_archive", "retry after cancellation cannot publish abandoned target")
    cancel_loader = null
    scene.free()
    await process_frame

func _cancel_read() -> void:
    cancel_loader.cancel_transition()

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label)
