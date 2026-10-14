extends SceneTree
## Configuration/ownership fixtures; not natural exploration or FPS evidence.
const ROUTES := preload("res://scripts/world_routes.gd")
const COORD := preload("res://scripts/world_coordinates.gd")
const SAVE := "user://world_neighbor_config_validation.json"
const BAD := "user://world_neighbor_config_bad.json"
const MISSING := "user://world_neighbor_config_missing.json"
var scene: Node
var pref: RefCounted
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    root.process_mode = Node.PROCESS_MODE_DISABLED
    _clean()
    scene = load("res://scenes/World.tscn").instantiate()
    scene.world_resume = false
    scene.world_save_path = SAVE
    root.add_child(scene)
    for unused in 4: await process_frame
    pref = scene.world_prefetch
    var source_ids := _node_ids()
    var state: Dictionary = scene.world_state.data.duplicate(true)
    var inventory: Dictionary = scene.inventory_counts.duplicate(true)
    var wallet: int = scene.currency_count
    var save_bytes := FileAccess.get_file_as_bytes(SAVE)
    for id in COORD.manifest().regions:
        var path := ROUTES.config_path(String(id))
        var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
        var entry := Vector2(raw.player_start[0], raw.player_start[1])
        var expected: Dictionary = scene.world_loader.validate_config(raw, path, entry)
        scene.world_loader.last_error = "foreground diagnostic"
        _target(String(id), path, entry)
        _check(pref.cached_raw(path) == null, "pending target is not exposed as a warm hit")
        await _ready(String(id))
        var record: Dictionary = pref.configs.get(id, {})
        _check(not expected.is_empty() and record.get("prepared") == expected, String(id) + " incremental result equals canonical validation")
        _check(record.get("raw") == raw and not pref.snapshot().config_worker_is_main, String(id) + " raw JSON read/parsed by shared worker")
        _check(pref.config_bytes > 0 and pref.max_config_operations <= 8 and pref.config_validation_batches > 1, "measured validation spans bounded batches")
        _check(scene.world_loader.last_error == "foreground diagnostic", "neighbor validation cannot overwrite foreground diagnostics")
        var copy: Variant = pref.cached_raw(path)
        if copy is Dictionary:
            copy.map_rooms.clear()
        _check(not pref.cached_raw(path).map_rooms.is_empty(), "published cache retains detached caller ownership")
    var id := "demo_ch02_rain_foundry_canal"
    var path := ROUTES.config_path(id)
    var entry := Vector2(120, 500)
    _target(id, path, entry)
    pref.step(scene, 0)
    var abandoned: int = pref.config_task.ticket
    _check(pref.config_task.reader == scene.world_loader.config_read_job and pref.snapshot().config_phase == "reading", "neighbor borrows loader's sole reader and yields before taking result")
    while scene.world_loader.config_read_job.busy(): await process_frame
    _check(scene.world_loader.config_read_job.request(path) == 0, "completed accepted ticket cannot be stolen by a second requester")
    var next_id := "demo_ch03_saltwhite_archive"
    var next_path := ROUTES.config_path(next_id)
    var result: Dictionary = await scene.world_loader._preflight_async(next_path, entry, pref, scene)
    _check(result.get("id") == next_id and scene.world_loader.last_transition.json_background, "foreground takes priority over completed neighbor read")
    _check(pref.config_task.is_empty() and pref.configs.is_empty() and scene.world_loader.config_read_job.take(abandoned).is_empty(), "abandoned neighbor cannot publish or consume foreground result")
    _target(id, path, entry)
    await _validating()
    var cancelled: int = pref.config_cancellations
    pref.desired[id].entry = entry + Vector2(1, 0)
    pref.step(scene, 0)
    await _ready(id)
    _check(pref.config_cancellations == cancelled + 1 and pref.configs[id].entry == entry + Vector2(1, 0), "changed same-region entrance cancels and validates a new lease")
    _target(id, path, entry)
    await _validating()
    pref.desired.clear()
    pref.step(scene, 0)
    _check(pref.config_task.is_empty() and pref.configs.is_empty() and pref.queue.is_empty(), "leaving range drops partially validated configuration")
    _target(id, path, entry)
    await _validating()
    pref.config_task.stamp = -1 # deterministic changed-file lease fixture
    pref._publish_config(result)
    _check(pref.configs.is_empty() and pref.config_task.is_empty(), "final publication rejects changed file lease")
    _target(id, path, entry)
    pref.step(scene, 0)
    scene.player.position = Vector2(-100000, -100000)
    scene.world_loader.generation += 1
    pref.step(scene, 0)
    _check(pref.config_task.is_empty() and pref.configs.is_empty() and pref.desired.is_empty(), "generation change rejects in-flight source read")
    _target(id, path, entry)
    await _ready(id)
    _check(not pref.configs[id].raw.is_empty(), "new generation retries after abandoned read without stale publication")
    var file := FileAccess.open(BAD, FileAccess.WRITE)
    file.store_string("{broken JSON")
    file.close()
    for failed_path in [MISSING, BAD]:
        _target(id, failed_path, entry)
        var before: int = pref.failures
        await _ready(id)
        var reads: int = pref.config_reads
        for unused in 12:
            pref.step(scene, 0)
            await process_frame
        _check(pref.configs[id].raw.is_empty() and pref.failures == before + 1, "invalid/missing JSON records one failed lease")
        _check(pref.config_reads == reads and pref.entities.is_empty() and pref.gameplay.regions.is_empty() and pref.queue.is_empty(), "failed lease cannot retry every frame or allocate gameplay")
        pref.desired[id].path = path
        await _ready(id)
        _check(not pref.configs[id].raw.is_empty(), "changed failed path retries successfully")
    _check(_node_ids() == source_ids and scene.world_state.data == state, "neighbor preparation leaves source nodes and world progress intact")
    _check(scene.inventory_counts == inventory and scene.currency_count == wallet and FileAccess.get_file_as_bytes(SAVE) == save_bytes, "neighbor preparation cannot grant inventory/currency or write save")
    print("NEIGHBOR CONFIG METRICS ", JSON.stringify(pref.snapshot()))
    _target(id, path, entry)
    pref.step(scene, 0)
    var reader: RefCounted = scene.world_loader.config_read_job
    scene.free()
    scene = null
    _check(reader.closed and not reader.busy() and reader.request(path) == 0 and pref.config_task.is_empty(), "host teardown drains and closes sole reader with a neighbor pending")
    pref = null
    await process_frame
    _clean()
    if failures.is_empty():
        print("WORLD NEIGHBOR CONFIG PASS checks=%d" % checks)
        quit(0)
    else:
        for failure in failures: push_error(failure)
        quit(1)

func _target(id: String, path: String, entry: Vector2) -> void:
    pref.shutdown()
    pref.generation = scene.world_loader.generation
    pref.selection_elapsed = -100000
    pref.desired = {id: {"path": path, "entry": entry, "distance": 0}}

func _ready(id: String) -> void:
    var bounded := true
    for unused in 3000:
        pref.step(scene, 0)
        bounded = bounded and pref.last_config_operations <= 8 and pref.snapshot().regions <= 2
        if pref.configs.has(id) and pref.configs[id].get("path", "") == pref.desired[id].path and pref.configs[id].get("entry") == pref.desired[id].entry:
            _check(bounded, "each poll respects configuration admission and cache capacity")
            return
        await process_frame
    _check(false, "configuration becomes ready within fixture frame limit")

func _validating() -> void:
    for unused in 3000:
        pref.step(scene, 0)
        if pref.config_validator != null and pref.last_config_operations > 0:
            _check(pref.configs.is_empty(), "partial validation stays private")
            return
        await process_frame
    _check(false, "fixture reaches incremental validation")

func _node_ids() -> Array:
    return scene.get_children().map(func(child): return child.get_instance_id())

func _clean() -> void:
    for path in [SAVE, SAVE + ".bak", SAVE + ".tmp", SAVE + ".previous", BAD, MISSING]:
        if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label)
