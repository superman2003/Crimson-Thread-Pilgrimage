extends SceneTree

const MAIN_SCENE := "res://scenes/Main.tscn"
const CONFIG_PATHS := [
    "res://data/generated/demo_ch01_moss_bell_court.generated.json",
    "res://data/generated/demo_ch02_rain_foundry_canal.generated.json",
    "res://data/generated/demo_ch03_saltwhite_archive.generated.json",
    "res://data/generated/demo_ch04_broken_string_greenhouse.generated.json",
    "res://data/generated/demo_ch05_obsidian_pilgrim_road.generated.json",
    "res://data/generated/demo_ch06_silent_crown_core.generated.json",
]


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var configs: Array = []
    var runtime_unlock_checked := false
    for path in CONFIG_PATHS:
        var config := _validate_config(path)
        configs.append(config)
        if not runtime_unlock_checked:
            await _validate_runtime_unlocks(path, config)
            runtime_unlock_checked = true
    _validate_generated_chain(configs)
    print("GENERATED_RUNTIME_VALIDATION_PASS configs=%d" % CONFIG_PATHS.size())
    quit(0)


func _validate_config(path: String) -> Dictionary:
    _assert(FileAccess.file_exists(path), "generated config exists: " + path)
    var file := FileAccess.open(path, FileAccess.READ)
    _assert(file != null, "generated config opens: " + path)
    var parsed = JSON.parse_string(file.get_as_text())
    _assert(typeof(parsed) == TYPE_DICTIONARY, "generated config parses as dictionary: " + path)
    var config: Dictionary = parsed
    var rooms: Array = config.get("map_rooms", [])
    var platforms: Array = config.get("platforms", [])
    var enemies: Array = config.get("enemy_spawns", [])
    var saves: Array = config.get("save_points", [])
    var connections: Array = config.get("connections", [])
    var locked_gates: Array = config.get("locked_gates", [])
    _assert(rooms.size() >= 55, "generated room count >= 55")
    _assert(platforms.size() >= rooms.size() * 2, "generated platform density")
    _assert(enemies.size() >= 12, "generated enemy count")
    _assert(saves.size() >= 5, "generated save point count")
    _assert(connections.size() >= rooms.size() - 1, "generated connection count")
    _assert(_has_kind(rooms, "gate"), "generated has gate room")
    _assert(_has_kind(rooms, "boss"), "generated has boss room")
    _assert(_has_chapter_exit(config.get("interactives", [])), "generated has chapter exit")
    _assert(_positions_inside_rooms(config), "generated important positions inside rooms")
    _assert(_connections_have_progression_contracts(connections), "generated connections have progression contracts")
    _assert(_ability_gates_have_runtime_locks(config), "generated ability gates have runtime locks")
    _assert(_shortcut_levers_have_direction_contracts(config), "generated shortcut levers have direction contracts")
    _assert(_setpiece_contracts_are_valid(config), "generated setpiece contracts are valid")
    _assert(_debug_map_is_consistent(config), "generated debug map is consistent")
    config["_validation_path"] = path
    return config


func _validate_generated_chain(configs: Array) -> void:
    for index in range(configs.size() - 1):
        var current: Dictionary = configs[index]
        var expected_next: Dictionary = configs[index + 1]
        var transition: Dictionary = current.get("chapter_transition", {})
        _assert(
            String(transition.get("to_runtime_config_id", "")) == String(expected_next.get("id", "")),
            "generated chapter chain id %s -> %s" % [current.get("id", ""), expected_next.get("id", "")]
        )
        _assert(
            String(transition.get("next_config_path", "")) == String(expected_next.get("_validation_path", "")),
            "generated chapter chain path %s -> %s" % [current.get("id", ""), expected_next.get("_validation_path", "")]
        )
    var last_transition: Dictionary = configs.back().get("chapter_transition", {})
    _assert(String(last_transition.get("next_config_path", "")).is_empty(), "last generated chapter has no next path")


func _has_kind(rooms: Array, kind: String) -> bool:
    for room in rooms:
        if String(room.get("kind", "")) == kind:
            return true
    return false


func _has_chapter_exit(interactives: Array) -> bool:
    for item in interactives:
        if String(item.get("kind", "")) == "chapter_exit":
            return true
    return false


func _connections_have_progression_contracts(connections: Array) -> bool:
    for connection in connections:
        if not (connection is Dictionary):
            return false
        if String(connection.get("id", "")).is_empty():
            return false
        if String(connection.get("progression_tier", "")).is_empty():
            return false
        if String(connection.get("traversal", "")).is_empty():
            return false
        if String(connection.get("directionality", "")).is_empty():
            return false
        var kind := String(connection.get("type", ""))
        if kind == "ability_gate":
            if String(connection.get("gate_id", "")).is_empty():
                return false
            if String(connection.get("required_ability", "")).is_empty():
                return false
        elif kind == "shortcut":
            if String(connection.get("shortcut_id", "")).is_empty():
                return false
            if String(connection.get("initial_directionality", "")) != "from_to_only":
                return false
            if String(connection.get("opened_directionality", "")) != "two_way":
                return false
            var shortcut_value: Dictionary = connection.get("shortcut_value", {})
            if int(shortcut_value.get("distance_saved", 0)) < 1:
                return false
    return true


func _ability_gates_have_runtime_locks(config: Dictionary) -> bool:
    var gate_ids := {}
    var item_ids := {}
    var ability_connection_ids := {}
    for collectible in config.get("collectibles", []):
        if collectible is Dictionary and String(collectible.get("kind", "")) == "item":
            item_ids[String(collectible.get("item_id", ""))] = true
    for gate in config.get("locked_gates", []):
        if not (gate is Dictionary):
            return false
        var gate_id := String(gate.get("id", ""))
        var required_ability := String(gate.get("required_ability", ""))
        var rect: Array = gate.get("rect", [])
        if gate_id.is_empty() or required_ability.is_empty() or rect.size() < 4:
            return false
        if not item_ids.has(required_ability):
            return false
        gate_ids[gate_id] = true
    var ability_links := 0
    for connection in config.get("connections", []):
        if String(connection.get("type", "")) != "ability_gate":
            continue
        ability_links += 1
        ability_connection_ids[String(connection.get("id", ""))] = true
        var gate_id := String(connection.get("gate_id", ""))
        if not gate_ids.has(gate_id):
            return false
        var required_ability := String(connection.get("required_ability", ""))
        if not item_ids.has(required_ability):
            return false
    for gate in config.get("locked_gates", []):
        if not ability_connection_ids.has(String(gate.get("connection_id", ""))):
            return false
    return ability_links >= 5 and gate_ids.size() == ability_links


func _shortcut_levers_have_direction_contracts(config: Dictionary) -> bool:
    var shortcut_ids := {}
    for connection in config.get("connections", []):
        if String(connection.get("type", "")) == "shortcut":
            shortcut_ids[String(connection.get("shortcut_id", ""))] = true
    var lever_count := 0
    for interactive in config.get("interactives", []):
        if not (interactive is Dictionary) or String(interactive.get("kind", "")) != "lever":
            continue
        lever_count += 1
        if not shortcut_ids.has(String(interactive.get("shortcut_id", ""))):
            return false
        var opened: Dictionary = interactive.get("opens_connection", {})
        if String(opened.get("initial_directionality", "")) != "from_to_only":
            return false
        if String(opened.get("opened_directionality", "")) != "two_way":
            return false
    return lever_count >= 5


func _debug_map_is_consistent(config: Dictionary) -> bool:
    var debug_map: Dictionary = config.get("debug_map", {})
    if debug_map.is_empty():
        return false
    var counts: Dictionary = debug_map.get("connection_counts", {})
    for tier in ["critical_path", "optional_branch", "opened_shortcut", "ability_locked"]:
        if int(counts.get(tier, 0)) <= 0:
            return false
    return (
        debug_map.get("main_route", []).size() > 0
        and debug_map.get("side_branches", []).size() > 0
        and debug_map.get("shortcuts", []).size() > 0
        and debug_map.get("ability_gates", []).size() > 0
    )


func _setpiece_contracts_are_valid(config: Dictionary) -> bool:
    var setpiece_count := 0
    for room in config.get("map_rooms", []):
        if not (room is Dictionary):
            continue
        var setpiece := String(room.get("setpiece", ""))
        if setpiece.is_empty():
            continue
        setpiece_count += 1
        for field in ["micro_objective", "landmark", "mechanic_prompt", "playtest_note"]:
            if String(room.get(field, "")).is_empty():
                return false
    if String(config.get("id", "")).contains("ch01") and setpiece_count < 18:
        return false
    return true


func _validate_runtime_unlocks(path: String, config: Dictionary) -> void:
    var scene: Node = load(MAIN_SCENE).instantiate()
    scene.set("config_path", path)
    root.add_child(scene)
    await process_frame
    await process_frame
    var state: Dictionary = scene.get_demo_state()
    var expected_gates: int = config.get("locked_gates", []).size()
    var expected_abilities: int = _ability_collectible_count(config)
    var expected_shortcuts: int = _shortcut_connection_count(config)
    _assert(int(state.get("locked_gate_total", -1)) == expected_gates, "runtime exposes locked gate total: " + path)
    _assert(int(state.get("locked_gate_remaining", -1)) == expected_gates, "runtime starts with all ability gates locked: " + path)
    _assert(int(state.get("shortcut_total", -1)) == expected_shortcuts, "runtime exposes generated shortcut total: " + path)
    _assert(int(state.get("opened_shortcut_total", -1)) == 0, "runtime starts with generated shortcuts closed: " + path)
    _assert(not String(state.get("current_room_archetype", "")).is_empty(), "runtime exposes current room archetype: " + path)
    _assert(state.has("current_room_setpiece"), "runtime exposes current room setpiece: " + path)
    _assert(int(state.get("collectible_total", -1)) == expected_abilities, "combat mode still spawns ability collectibles: " + path)
    if scene.has_method("_debug_collect_all_abilities"):
        scene.call("_debug_collect_all_abilities")
    else:
        _assert(false, "runtime exposes ability debug collection: " + path)
    await process_frame
    state = scene.get_demo_state()
    _assert(int(state.get("unlocked_ability_total", -1)) >= expected_abilities, "runtime collects generated abilities: " + path)
    _assert(int(state.get("locked_gate_remaining", -1)) == 0, "runtime unlocks ability gates after ability collection: " + path)
    if scene.has_method("_debug_open_all_shortcuts"):
        scene.call("_debug_open_all_shortcuts")
    else:
        _assert(false, "runtime exposes all-shortcut debug open: " + path)
    await process_frame
    state = scene.get_demo_state()
    _assert(int(state.get("opened_shortcut_total", -1)) == expected_shortcuts, "runtime tracks every opened generated shortcut: " + path)
    scene.queue_free()
    await process_frame


func _shortcut_connection_count(config: Dictionary) -> int:
    var ids := {}
    for connection in config.get("connections", []):
        if not (connection is Dictionary):
            continue
        if String(connection.get("type", "")) != "shortcut":
            continue
        var shortcut_id := String(connection.get("shortcut_id", ""))
        if shortcut_id.is_empty():
            continue
        ids[shortcut_id] = true
    return ids.size()


func _ability_collectible_count(config: Dictionary) -> int:
    var count := 0
    for collectible in config.get("collectibles", []):
        if collectible is Dictionary and String(collectible.get("kind", "")) == "item":
            count += 1
    return count


func _positions_inside_rooms(config: Dictionary) -> bool:
    var rooms: Array = config.get("map_rooms", [])
    var positions: Array = [
        config.get("player_start", []),
        config.get("boss_checkpoint", []),
        config.get("boss", {}).get("position", []),
    ]
    for group_name in ["enemy_spawns", "save_points", "npcs", "interactives"]:
        for item in config.get(group_name, []):
            positions.append(item.get("position", []))
    for position in positions:
        if not _position_inside_any_room(position, rooms):
            print("GENERATED_POSITION_OUTSIDE_ROOM " + JSON.stringify(position))
            return false
    return true


func _position_inside_any_room(position, rooms: Array) -> bool:
    if typeof(position) != TYPE_ARRAY or position.size() < 2:
        return false
    var x := float(position[0])
    var y := float(position[1])
    for room in rooms:
        for rect in room.get("visit_rects", []):
            if _point_inside_rect(x, y, rect):
                return true
        if room.has("layout_rect") and _point_inside_rect(x, y, room.get("layout_rect", [])):
            return true
        var range: Array = room.get("range", [])
        if range.size() >= 2 and x >= float(range[0]) and x <= float(range[1]):
            return true
    return false


func _point_inside_rect(x: float, y: float, rect: Array) -> bool:
    if rect.size() < 4:
        return false
    var rx := float(rect[0])
    var ry := float(rect[1])
    var rw := float(rect[2])
    var rh := float(rect[3])
    return x >= rx and x <= rx + rw and y >= ry and y <= ry + rh


func _assert(condition: bool, message: String) -> void:
    if not condition:
        push_error("GENERATED_RUNTIME_VALIDATION_FAIL " + message)
        quit(1)
