extends SceneTree
## Real-scene persistence regression. Uses only its own save path, never player slots.
## godot --headless --path godot --script res://scripts/world_resume_regression_validation.gd
const WORLD := preload("res://scripts/world_state.gd")
const MAIN := preload("res://scripts/main_level.gd")
const LOADER := preload("res://scripts/world_region_loader.gd")
const SAVE := "user://world_resume_regression_validation.json"
const FINAL_REGION := "demo_ch06_silent_crown_core"
var checks := 0
var failures: Array[String] = []
var scene: Node

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    create_timer(90.0).timeout.connect(func():
        _check(false, "resume regression timed out")
        _finish())
    root.process_mode = Node.PROCESS_MODE_DISABLED
    _clean()
    _test_startup_options()
    _test_persistent_session_guards()
    _test_backup_failure()
    await _test_ending_restore()
    await _test_incompatible_build()
    _finish()

func _test_startup_options() -> void:
    var subject := MAIN.new()
    _check(subject._consume_world_startup_options(PackedStringArray(["--save-slot=2", "--new-game"])), "initial launch accepts new-game")
    _check(subject.world_slot == 2 and subject.world_save_path == WORLD.slot_path(2), "initial launch accepts slot selection")
    subject.world_slot = 3
    subject.world_save_path = SAVE
    _check(not subject._consume_world_startup_options(PackedStringArray(["--save-slot=2", "--new-game"])), "consumed startup cannot replay new-game")
    _check(subject.world_slot == 3 and subject.world_save_path == SAVE, "consumed startup cannot override selected slot")
    subject.free()
    subject = MAIN.new()
    subject.world_startup_options_enabled = false
    subject.world_slot = 3
    subject.world_save_path = SAVE
    _check(not subject._consume_world_startup_options(PackedStringArray(["--save-slot=2", "--new-game"])), "replacement scene ignores startup new-game")
    _check(subject.world_slot == 3 and subject.world_save_path == SAVE, "replacement scene preserves explicit target slot")
    subject.free()

func _test_persistent_session_guards() -> void:
    var subject := MAIN.new()
    var loader := LOADER.new()
    subject.world_save_blocked = true
    subject.world_startup_options_enabled = false
    loader._reset_region_fields(subject)
    _check(subject.world_save_blocked, "persistent host reset retains incompatible-save protection")
    _check(not subject.world_startup_options_enabled, "persistent host reset retains consumed launch options")
    subject.free()

func _test_backup_failure() -> void:
    var original := WORLD.new()
    original.capture_global({"currency": 71})
    _check(original.write(SAVE), "backup fixture written")
    var before := FileAccess.get_file_as_string(SAVE)
    # A nonempty directory cannot be replaced by the backup file.
    DirAccess.make_dir_absolute(ProjectSettings.globalize_path(SAVE + ".previous"))
    var marker := FileAccess.open(SAVE + ".previous/keep", FileAccess.WRITE)
    marker.store_string("backup destination unavailable")
    marker.close()
    var subject := MAIN.new()
    subject.world_save_path = SAVE
    _check(not subject._preserve_previous_journey(), "failed backup blocks reset")
    _check(FileAccess.get_file_as_string(SAVE) == before, "failed backup leaves primary byte-identical")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + ".previous/keep"))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + ".previous"))
    _check(subject._preserve_previous_journey(), "valid backup permits reset")
    _check(not FileAccess.file_exists(SAVE), "reset removes primary only after backup")
    _check(FileAccess.get_file_as_string(SAVE + ".previous") == before, "reset backup preserves exact prior journey")
    subject.free()
    _clean()

func _test_ending_restore() -> void:
    var saved := WORLD.new()
    var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + FINAL_REGION + ".json"))
    var checkpoint: Array = config.player_start
    saved.capture_global({"current_region": FINAL_REGION, "entry": checkpoint})
    saved.capture_region(FINAL_REGION, {"boss_defeated": true, "boss_unlocked": true,
        "checkpoint": checkpoint, "checkpoint_id": "resume_fixture"})
    _check(saved.write(SAVE), "completed final-region fixture saved")
    _spawn()
    await _frames()
    _check(scene.demo_complete and scene.post_boss_route_open, "completed final region restores boss and exit")
    _check(scene.ending_gates_spawned, "completed final region restores ending gates")
    _check(_ending_count() == 3, "all three ending choices survive restart")
    var arena := Vector2(float(config.boss.position[0]), float(config.boss.position[1]))
    for child in scene.get_children():
        if child is Area2D and String(child.get_meta("kind", "")) == "ending_gate":
            _check(absf(child.position.y - arena.y) < 1.0 and absf(child.position.x - arena.x) <= 230.0, "restored ending remains in boss arena")
    scene._spawn_ending_gates()
    scene._spawn_ending_gates()
    _check(_ending_count() == 3, "ending reconstruction is idempotent")
    scene._travel_world("res://data/" + FINAL_REGION + ".json", arena)
    scene = current_scene
    await _frames()
    _check(_ending_count() == 3, "completed final region restores endings on revisit")
    _check(not scene.world_startup_options_enabled, "region travel never reapplies launch flags")
    await scene._travel_world_async("res://data/" + FINAL_REGION + ".json", arena)
    _check(_ending_count() == 3 and scene.world_loader.phase == "idle", "asynchronous publication also restores ending choices exactly once")
    await _dispose_scene()
    _clean()
    # Standalone demos retain their existing boss-death ending choices.
    scene = load("res://scenes/Main.tscn").instantiate()
    scene.config_path = "res://data/" + FINAL_REGION + ".json"
    root.add_child(scene)
    current_scene = scene
    await _frames()
    scene._spawn_ending_gates()
    scene._spawn_ending_gates()
    _check(_ending_count() == 3, "standalone ending spawn remains idempotent")
    await _dispose_scene()

func _test_incompatible_build() -> void:
    var saved := WORLD.new()
    saved.capture_global({"current_region": "demo_ch01_moss_bell_court", "currency": 85,
        "build_state": {"version": 999, "future_progress": "retain exactly"}})
    _check(saved.write(SAVE), "outer save accepts opaque future build fixture")
    var before := FileAccess.get_file_as_string(SAVE)
    _spawn()
    await _frames()
    _check(scene.world_save_blocked and not scene.world_initial_error.is_empty(), "incompatible build suspends saving with explanation")
    _check(FileAccess.get_file_as_string(SAVE) == before, "initial autosave preserves incompatible primary")
    scene.currency_count += 17
    scene._save_world()
    scene._save_world()
    _check(FileAccess.get_file_as_string(SAVE) == before, "repeated autosave cannot rotate away incompatible progress")
    _check(scene.world_state.data.currency == 102, "blocked disk save still carries live progress")
    scene._travel_world(scene.config_path, scene.active_spawn)
    scene = current_scene
    await _frames()
    _check(scene.world_save_blocked and scene.currency_count == 102, "region travel carries save protection and live progress")
    _check(FileAccess.get_file_as_string(SAVE) == before, "region autosave remains blocked")
    await scene._travel_world_async(scene.config_path, scene.active_spawn)
    _check(scene.world_save_blocked and scene.currency_count == 102, "async host travel retains save protection and live progress")
    _check(FileAccess.get_file_as_string(SAVE) == before, "async publication never overwrites incompatible disk progress")
    scene._start_new_journey()
    scene = current_scene
    await _frames()
    _check(not scene.world_save_blocked, "explicit new journey clears incompatible-build protection")
    _check(FileAccess.get_file_as_string(SAVE + ".previous") == before, "explicit new journey archives incompatible original")
    var fresh := WORLD.new()
    _check(fresh.read(SAVE) and fresh.data.currency == 0, "explicit new journey writes valid fresh progress")
    await _dispose_scene()
    _clean()

func _spawn() -> void:
    scene = load("res://scenes/World.tscn").instantiate()
    scene.world_save_path = SAVE
    scene.world_startup_options_enabled = false
    root.add_child(scene)
    current_scene = scene

func _ending_count() -> int:
    var total := 0
    for child in scene.get_children():
        if child is Area2D and String(child.get_meta("kind", "")) == "ending_gate":
            total += 1
    return total

func _frames() -> void:
    await process_frame
    await process_frame

func _dispose_scene() -> void:
    if is_instance_valid(scene):
        scene.queue_free()
    await _frames()
    scene = null

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)
        push_error(label)

func _clean() -> void:
    for suffix in ["", ".tmp", ".bak", ".previous"]:
        var path: String = SAVE + String(suffix)
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _finish() -> void:
    if is_instance_valid(scene):
        scene.queue_free()
    _clean()
    print("WORLD_RESUME_REGRESSION checks=%d failures=%d" % [checks, failures.size()])
    quit(0 if failures.is_empty() else 1)
