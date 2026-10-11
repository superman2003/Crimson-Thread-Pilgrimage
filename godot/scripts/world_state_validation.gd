extends SceneTree
## godot --headless --path godot --script res://scripts/world_state_validation.gd
const WORLD := preload("res://scripts/world_state.gd")
const PATH := "user://world_state_validation.json"
var failures: Array[String] = []

func _initialize() -> void:
    _clean()
    var world := WORLD.new()
    _check(not world.read(PATH) and world.last_error == "missing", "missing save starts fresh")
    _check(world.capture_global({"inventory_counts": {"silk_wall_grip": 1, "double_jump": 1}, "currency": 47,
        "story_flags": {"npc_name_returned": true, "ending_chosen": "release"},
        "current_region": "moss", "entry": Vector2(128, 480), "hp": 3, "energy": 64}), "capture global")
    for region_id in ["moss", "rain", "salt"]:
        _check(world.capture_region(region_id, {"collected_ids": {"reward_" + region_id: true},
            "opened_shortcuts": {"loop_" + region_id: true}, "visited_rooms": {"room_" + region_id: true},
            "checkpoint": Vector2(300, 600), "checkpoint_id": "lamp_" + region_id,
            "boss_defeated": region_id == "rain"}), "capture region " + region_id)
    _check(world.write(PATH), "first atomic save: " + world.last_error)
    var restart := WORLD.new()
    _check(restart.read(PATH), "load separate instance: " + restart.last_error)
    _check(restart.data.inventory_counts == world.data.inventory_counts, "abilities persist after restart")
    _check(restart.data.story_flags == world.data.story_flags, "quest and ending persist")
    _check(restart.data.regions.size() == 3, "three regions persist")
    _check(restart.data.entry == [128.0, 480.0], "entry Vector2 serialized")
    _check(restart.get_region("rain").boss_defeated, "boss persists")
    _check(restart.get_region("salt").checkpoint == [300.0, 600.0], "checkpoint serialized")
    var detached := restart.get_region("salt")
    detached.visited_rooms.clear()
    _check(not restart.get_region("salt").visited_rooms.is_empty(), "region snapshots are detached")
    _check(restart.capture_global({"currency": 81}) and restart.write(PATH), "save new version")
    var previous := WORLD.new()
    _check(previous.read(PATH + ".bak") and previous.data.currency == 47, "previous save preserved as backup")
    var before: Dictionary = restart.data.duplicate(true)
    _check(not restart.capture_global({"currency": -1}) and restart.data == before, "invalid snapshot is transactional")
    _check(not restart.capture_region("rain", {"checkpoint": [1, "bad"]}) and restart.data == before, "invalid region rejected")
    _check(not restart.capture_region("rain", {"bell_count": 1000001}), "unreasonable bell counter rejected")
    _check(not restart.capture_region("rain", {"boss_unlocked": "yes"}), "boss flag type checked")
    _check(not restart.capture_global({"inventory_counts": {"silk_wall_grip": 1.5}}), "fractional inventory rejected")
    _put("{broken")
    _check(not restart.read(PATH) and restart.data == before, "malformed JSON preserves live state")
    _check(not restart.write(PATH) and FileAccess.get_file_as_string(PATH) == "{broken", "damaged save is not overwritten")
    var preserved_backup := WORLD.new()
    _check(preserved_backup.read(PATH + ".bak") and preserved_backup.data.currency == 47, "damaged save cannot replace good backup")
    var unsupported := WORLD.fresh_data()
    unsupported.version = 999
    _put(JSON.stringify(unsupported))
    _check(not restart.read(PATH) and restart.data == before, "unknown save version rejected")
    var wrong_types := WORLD.fresh_data()
    wrong_types.inventory_counts = []
    _put(JSON.stringify(wrong_types))
    _check(not restart.read(PATH) and restart.data == before, "wrong container rejected")
    wrong_types = WORLD.fresh_data()
    wrong_types.hp = "5"
    _put(JSON.stringify(wrong_types))
    _check(not restart.read(PATH), "string number rejected")
    wrong_types = WORLD.fresh_data()
    wrong_types.regions = {"moss": {"checkpoint": [0, 0]}}
    _put(JSON.stringify(wrong_types))
    _check(not restart.read(PATH), "incomplete region rejected")
    _clean()
    if failures.is_empty():
        print("WORLD STATE PASS: roundtrip, three regions, restart, backup, damaged and invalid saves")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)

func _check(condition: bool, label: String) -> void:
    if not condition:
        failures.append(label)

func _put(contents: String) -> void:
    var file := FileAccess.open(PATH, FileAccess.WRITE)
    file.store_string(contents)
    file.close()

func _clean() -> void:
    for suffix in ["", ".tmp", ".bak"]:
        if FileAccess.file_exists(PATH + suffix):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + suffix))
