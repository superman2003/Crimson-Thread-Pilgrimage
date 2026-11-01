extends SceneTree
const WORLD := preload("res://scripts/world_state.gd")
const BUILD := preload("res://scripts/build_system.gd")
const RAIN := "demo_ch02_rain_foundry_canal"
const OBSIDIAN := "demo_ch05_obsidian_pilgrim_road"
const PATH := "user://save_product_validation.json"
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
    _run()

func _run() -> void:
    var old := WORLD.fresh_data()
    old.version = 1
    old.erase("build_state")
    old.erase("death_cache")
    old.currency = 77
    old.current_region = RAIN
    old.entry = [321, 654]
    _put(PATH, JSON.stringify(old))
    var world := WORLD.new()
    _check(world.read(PATH), "v1 save migrates")
    _check(world.data.version == WORLD.VERSION and world.data.currency == 77, "migration preserves progress")
    _check(world.data.build_state.is_empty() and world.data.death_cache.is_empty(), "v1 receives empty optional systems")
    _check(world.data.world_location.region_id == RAIN and WORLD._point(world.data.world_location.position), "v1 migration derives campaign coordinates for canonical region")
    _check(world.resume_local_position() == Vector2(321, 654), "migrated world coordinates resume in local frame")
    var legacy := WORLD.fresh_data()
    legacy.version = 1
    legacy.erase("build_state")
    legacy.erase("death_cache")
    legacy.current_region = "rain"
    legacy.entry = [321, 654]
    _put(PATH, JSON.stringify(legacy))
    var legacy_world := WORLD.new()
    _check(legacy_world.read(PATH), "legacy noncanonical region identifier remains readable")
    _check(legacy_world.data.world_location.is_empty() and legacy_world.resume_local_position() == Vector2(321, 654), "legacy region without layout mapping keeps local fallback")
    _put(PATH, JSON.stringify(old))
    world = WORLD.new()
    _check(world.read(PATH), "canonical migration fixture restored")
    var build := BUILD.new()
    build.sync_progress({"echo_hook": 1, "bell_guard": 1}, RAIN, {"skill_needle_learned": true})
    build.select_skill("needle")
    build.try_cast(100)
    build.save_loadout("one")
    var death := {"region_id": RAIN, "position": [320, 500], "currency": 25}
    _check(world.capture_global({"build_state": build.serialize(), "death_cache": death}), "capture build and death cache")
    _check(world.capture_region(RAIN, {"visited_rooms": {"entry": true, "bell": true}, "checkpoint": Vector2(400, 800)}), "capture visited rooms and checkpoint")
    _check(world.capture_global({"current_region": OBSIDIAN, "entry": [1200, 2300]}), "cross-region travel stores new world frame")
    _check(world.write(PATH), "upgrade is atomic")
    var reboot := WORLD.new()
    _check(reboot.read(PATH), "restart reads upgraded state")
    var recovered_build := BUILD.new()
    _check(recovered_build.restore(reboot.data.build_state).ok, "build restores")
    _check(recovered_build.state.skill == "needle" and recovered_build.cooldowns.get("needle", 0) > 0, "read does not reset selected skill cooldown")
    _check(int(reboot.data.death_cache.get("currency", -1)) == 25, "death cache persists")
    _check(reboot.data.world_location.region_id == OBSIDIAN and reboot.resume_local_position() == Vector2(1200, 2300), "cross-region world coordinates survive restart")
    _check(reboot.get_region(RAIN).visited_rooms == {"entry": true, "bell": true}, "visited rooms survive restart")
    var before := reboot.data.duplicate(true)
    _check(not reboot.capture_global({"death_cache": {"region_id": RAIN, "position": [0, 0], "currency": -5}}), "negative death cache rejected")
    _check(reboot.data == before, "bad update leaves live state unchanged")
    _put(PATH, "{damaged")
    var damaged_primary := FileAccess.get_file_as_string(PATH)
    var valid_backup := FileAccess.get_file_as_string(PATH + ".bak")
    _check(not reboot.write(PATH), "damaged primary never overwritten")
    _check(reboot.restore_backup(PATH), "valid v1 backup restores damaged primary")
    _check(reboot.data.currency == 77, "backup retained original progress")
    _check(FileAccess.get_file_as_string(PATH) == valid_backup and FileAccess.get_file_as_string(PATH + ".bak") == valid_backup, "validated backup remains intact after recovery")
    var preserved_files := DirAccess.get_files_at("user://")
    var preserved_count := 0
    for name in preserved_files:
        if name.begins_with("save_product_validation.json.before_restore_"):
            preserved_count += 1
            _check(FileAccess.get_file_as_string("user://" + name) == damaged_primary, "damaged original retained byte-for-byte")
    _check(preserved_count == 1, "recovery preservation name is unique and retained")
    _check(not reboot.restore_backup(PATH + ".missing"), "missing backup rejected")
    # A failed temporary open must leave both the primary and its recovery copy untouched.
    var primary_before_failure := FileAccess.get_file_as_string(PATH)
    var backup_before_failure := FileAccess.get_file_as_string(PATH + ".bak")
    DirAccess.make_dir_absolute(ProjectSettings.globalize_path(PATH + ".tmp"))
    _check(not reboot.write(PATH), "temporary-open failure reported")
    _check(FileAccess.get_file_as_string(PATH) == primary_before_failure and FileAccess.get_file_as_string(PATH + ".bak") == backup_before_failure, "failed write preserves primary and backup")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + ".tmp"))
    for slot in range(1, 4):
        _check(not WORLD.slot_path(slot).is_empty(), "slot path exists")
    _check(WORLD.slot_path(1) != WORLD.slot_path(2) and WORLD.slot_path(2) != WORLD.slot_path(3), "three isolated save slots")
    var summaries := WORLD.slot_summaries()
    _check(summaries.size() == 3, "all slots are described")
    for row in summaries:
        _check(row.has("exists") and row.has("valid") and row.has("error"), "slot validity is explicit")
    preload("res://scripts/journey_history_validation.gd").new().run(_check)
    var dir := DirAccess.open("user://")
    for name in dir.get_files():
        if name.begins_with("save_product_validation.json"):
            dir.remove(name)
    if failures.is_empty():
        print("SAVE PRODUCT PASS: %d checks, v1 migration, atomic backup recovery, builds, death cache and slots" % checks)
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        print("FAILED: " + label)
        failures.append(label)

func _put(path: String, contents: String) -> void:
    var file := FileAccess.open(path, FileAccess.WRITE)
    file.store_string(contents)
    file.close()
