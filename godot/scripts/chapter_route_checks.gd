extends RefCounted
const LEVEL_HOST := preload("res://scripts/level_host.gd")
## All-chapters demo checks: rooms, positions, floors, late-route gaps, exits, multi-level layout and platform or enemy overlap between chapters.
## Moved out of all_chapters_demo_validation.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func normal_enemy_kinds(suite: SceneTree, scene: Node) -> Array:
    var kinds: Array = []
    for child in LEVEL_HOST.children(scene):
        if child.is_in_group("enemy") and not child.is_boss:
            kinds.append(child.kind)
    return kinds


static func attacks_have_pose_keys(suite: SceneTree, attacks: Array) -> bool:
    if attacks.is_empty():
        return false
    for attack in attacks:
        if not (attack is Dictionary):
            return false
        var data: Dictionary = attack
        if not data.has("windup_scale") or not data.has("active_scale") or not data.has("recover_offset"):
            return false
    return true


static func find_runtime_scene(suite: SceneTree, config_id: String) -> Node:
    for child in suite.root.get_children():
        if child == null or not is_instance_valid(child):
            continue
        if not child.has_method("get_demo_state"):
            continue
        var state: Dictionary = child.get_demo_state()
        if String(state.get("config_id", "")) == config_id:
            return child
    return null


static func points_match(suite: SceneTree, actual_value, expected_value) -> bool:
    if not (actual_value is Array) or not (expected_value is Array):
        return false
    var actual: Array = actual_value
    var expected: Array = expected_value
    if actual.size() < 2 or expected.size() < 2:
        return false
    return absf(float(actual[0]) - float(expected[0])) <= 0.5 and absf(float(actual[1]) - float(expected[1])) <= 0.5


static func vec2(suite: SceneTree, value) -> Vector2:
    if not (value is Array):
        return Vector2.ZERO
    var data: Array = value
    if data.size() < 2:
        return Vector2.ZERO
    return Vector2(float(data[0]), float(data[1]))


static func interactive_by_kind(suite: SceneTree, interactives: Array, kind: String) -> Dictionary:
    for interactive in interactives:
        var item: Dictionary = interactive
        if String(item.get("kind", "")) == kind:
            return item
    return {}


static func interactive_exit(suite: SceneTree, interactives: Array) -> Dictionary:
    for interactive in interactives:
        var item: Dictionary = interactive
        var kind := String(item.get("kind", ""))
        if kind == "chapter_exit" or kind == "ending_exit":
            return item
    return {}


static func item_collectible_count(suite: SceneTree, config: Dictionary) -> int:
    var total := 0
    for collectible in config.get("collectibles", []):
        if collectible is Dictionary and String((collectible as Dictionary).get("kind", "")) == "item":
            total += 1
    return total


static func collectibles_have_no_route_tokens(suite: SceneTree, config: Dictionary) -> bool:
    for collectible in config.get("collectibles", []):
        if not (collectible is Dictionary):
            return false
        if String((collectible as Dictionary).get("kind", "")) not in ["item"]:
            return false
    return true


static func room_by_kind(suite: SceneTree, rooms: Array, kind: String) -> Dictionary:
    for room in rooms:
        if not (room is Dictionary):
            continue
        var data: Dictionary = room
        if String(data.get("kind", "")) == kind:
            return data
    return {}


static func position_inside_room(suite: SceneTree, position_value, room: Dictionary) -> bool:
    if room.is_empty() or not (position_value is Array):
        return false
    var position_data: Array = position_value
    if position_data.size() < 2:
        return false
    var x := float(position_data[0])
    var y := float(position_data[1])
    if suite._room_contains_position(room, Vector2(x, y)):
        return true
    var range_data: Array = room.get("range", [])
    if range_data.size() < 2:
        return false
    return x >= float(range_data[0]) and x <= float(range_data[1])


static func position_has_floor(suite: SceneTree, config: Dictionary, position_value, clearance: float) -> bool:
    if not (position_value is Array):
        return false
    var position_data: Array = position_value
    if position_data.size() < 2:
        return false
    var x := float(position_data[0])
    var expected_top := float(position_data[1]) + clearance
    for platform in config.get("platforms", []):
        if not (platform is Dictionary):
            continue
        var platform_data: Dictionary = platform
        var rect: Rect2 = suite._platform_rect(platform_data.get("rect", []))
        if not suite._playable_floor_allowed(platform_data, rect):
            continue
        if x >= rect.position.x - 1.0 and x <= rect.position.x + rect.size.x + 1.0 and absf(rect.position.y - expected_top) <= 8.0:
            return true
    return false


static func late_route_has_no_large_gap(suite: SceneTree, config: Dictionary, exit_position_value, max_gap: float) -> bool:
    if suite._uses_layout_rects(config.get("map_rooms", [])):
        return true
    if not (exit_position_value is Array):
        return false
    var exit_position: Array = exit_position_value
    if exit_position.size() < 2:
        return false
    var start_x: float = suite._late_route_start_x(config)
    var end_x := float(exit_position[0])
    var ranges: Array = []
    for platform in config.get("platforms", []):
        if not (platform is Dictionary):
            continue
        var platform_data: Dictionary = platform
        var rect: Rect2 = suite._platform_rect(platform_data.get("rect", []))
        if not suite._playable_floor_allowed(platform_data, rect):
            continue
        if rect.size.x < 180.0 or rect.position.y < 492.0 or rect.position.y > 545.0:
            continue
        var left := maxf(start_x, rect.position.x)
        var right := minf(end_x, rect.position.x + rect.size.x)
        if right > left:
            ranges.append([left, right])
    ranges.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
    var cursor = start_x
    for range_item in ranges:
        var left := float(range_item[0])
        var right := float(range_item[1])
        if left - cursor > max_gap:
            return false
        cursor = maxf(cursor, right)
    return end_x - cursor <= max_gap


static func uses_layout_rects(suite: SceneTree, rooms: Array) -> bool:
    for room in rooms:
        if not (room is Dictionary):
            continue
        var rect: Rect2 = suite._room_layout_rect(room)
        if rect.size.x > 0.0 and rect.size.y > 0.0:
            return true
    return false


static func late_route_start_x(suite: SceneTree, config: Dictionary) -> float:
    for platform in config.get("platforms", []):
        if not (platform is Dictionary):
            continue
        var platform_data: Dictionary = platform
        if String(platform_data.get("id", "")) == "backdoor_room":
            return suite._platform_rect(platform_data.get("rect", [])).position.x
    return 3600.0


static func playable_floor_allowed(suite: SceneTree, platform_data: Dictionary, rect: Rect2) -> bool:
    if rect.size.x <= 0.0 or rect.size.y <= 0.0:
        return false
    var lowered := String(platform_data.get("id", "")).to_lower()
    if lowered.contains("wall") or lowered.contains("gate") or lowered.contains("locked"):
        return false
    return rect.size.x >= 26.0 and rect.size.y <= 90.0


static func platform_rect(suite: SceneTree, rect_value) -> Rect2:
    if not (rect_value is Array):
        return Rect2()
    var data: Array = rect_value
    if data.size() < 4:
        return Rect2()
    return Rect2(float(data[0]), float(data[1]), float(data[2]), float(data[3]))


static func exit_points_to_next(suite: SceneTree, config: Dictionary, config_id: String) -> bool:
    var exit_data: Dictionary = suite._interactive_exit(config.get("interactives", []))
    if exit_data.is_empty():
        return false
    if config_id.ends_with("silent_crown_core"):
        return String(exit_data.get("kind", "")) == "ending_exit"
    var transition: Dictionary = config.get("chapter_transition", {})
    return String(exit_data.get("kind", "")) == "chapter_exit" and not String(transition.get("to_runtime_config_id", "")).is_empty() and String(exit_data.get("next_runtime_config_id", "")) == String(transition.get("to_runtime_config_id", ""))


static func attack_types(suite: SceneTree, profile: Dictionary) -> Array:
    var types: Array = []
    for attack in profile.get("attacks", []):
        if not (attack is Dictionary):
            continue
        var data: Dictionary = attack
        var attack_type := String(data.get("type", ""))
        if not types.has(attack_type):
            types.append(attack_type)
    return types


static func world_area(suite: SceneTree, config: Dictionary) -> float:
    var world: Dictionary = config.get("world", {})
    return float(world.get("width", 0)) * float(world.get("height", 0))


static func world_is_expanded_2d(suite: SceneTree, world: Dictionary) -> bool:
    # True-2D maps trade raw ribbon width for stacked vertical layers, so
    # require enough playable area on both axes instead of 1D length.
    var width := float(world.get("width", 0))
    var height := float(world.get("height", 0))
    return width >= 5200.0 and height >= 2400.0 and width * height >= 14000000.0


static func rooms_cover_world(suite: SceneTree, rooms: Array, world: Dictionary) -> bool:
    # Every room must expose a positive 2D layout rect, and together the
    # rooms must span most of the world on both axes.
    if rooms.is_empty():
        return false
    var min_x := INF
    var min_y := INF
    var max_x := -INF
    var max_y := -INF
    for room in rooms:
        if not (room is Dictionary):
            return false
        var rect: Rect2 = suite._room_layout_rect(room)
        if rect.size.x <= 0.0 or rect.size.y <= 0.0:
            return false
        min_x = minf(min_x, rect.position.x)
        min_y = minf(min_y, rect.position.y)
        max_x = maxf(max_x, rect.position.x + rect.size.x)
        max_y = maxf(max_y, rect.position.y + rect.size.y)
    var width := maxf(1.0, float(world.get("width", 1)))
    var height := maxf(1.0, float(world.get("height", 1)))
    return (max_x - min_x) >= width * 0.72 and (max_y - min_y) >= height * 0.55


static func has_multilayer_room_kinds(suite: SceneTree, rooms: Array) -> bool:
    var room_types: Dictionary = {}
    var min_layer := 999
    var max_layer := -999
    for room in rooms:
        if not (room is Dictionary):
            continue
        var data: Dictionary = room
        room_types[String(data.get("room_type", data.get("kind", "")))] = true
        var layer := int(data.get("layer", data.get("depth", 0)))
        min_layer = mini(min_layer, layer)
        max_layer = maxi(max_layer, layer)
    return room_types.size() >= 3 and max_layer - min_layer >= 3


static func has_multilevel_platforms(suite: SceneTree, platforms: Array) -> bool:
    # Split the playable vertical span into thirds and require standable
    # floors in every band, so each chapter is genuinely stacked in 2D.
    var min_y := INF
    var max_y := -INF
    var floor_ys: Array = []
    for platform in platforms:
        if not (platform is Dictionary):
            continue
        var data: Dictionary = platform
        var rect: Rect2 = suite._platform_rect(data.get("rect", []))
        if not suite._playable_floor_allowed(data, rect):
            continue
        floor_ys.append(rect.position.y)
        min_y = minf(min_y, rect.position.y)
        max_y = maxf(max_y, rect.position.y)
    if floor_ys.size() < 3 or max_y - min_y < 1200.0:
        return false
    var band := (max_y - min_y) / 3.0
    var has_upper := false
    var has_mid := false
    var has_lower := false
    for y_value in floor_ys:
        var y := float(y_value)
        if y < min_y + band:
            has_upper = true
        elif y < min_y + band * 2.0:
            has_mid = true
        else:
            has_lower = true
    return has_upper and has_mid and has_lower


static func connections_reference_rooms(suite: SceneTree, connections: Array, rooms: Array) -> bool:
    var ids: Dictionary = {}
    for room in rooms:
        if room is Dictionary:
            ids[String((room as Dictionary).get("id", ""))] = true
    if connections.is_empty():
        return false
    for connection in connections:
        if not (connection is Dictionary):
            return false
        var data: Dictionary = connection
        if not ids.has(String(data.get("from", ""))) or not ids.has(String(data.get("to", ""))):
            return false
    return true


static func positions_map_to_rooms(suite: SceneTree, config: Dictionary, config_id: String) -> bool:
    var rooms: Array = config.get("map_rooms", [])
    var positions: Array = [
        config.get("player_start", []),
        config.get("boss_checkpoint", []),
        config.get("boss", {}).get("position", [])
    ]
    for enemy in config.get("enemy_spawns", []):
        if enemy is Dictionary:
            positions.append((enemy as Dictionary).get("position", []))
    for save_point in config.get("save_points", []):
        if save_point is Dictionary:
            positions.append((save_point as Dictionary).get("position", []))
    for npc in config.get("npcs", []):
        if npc is Dictionary:
            positions.append((npc as Dictionary).get("position", []))
    for interactive in config.get("interactives", []):
        if interactive is Dictionary:
            positions.append((interactive as Dictionary).get("position", []))
    for position_value in positions:
        if not suite._position_inside_any_room(position_value, rooms):
            print("POSITION_OUTSIDE_ROOM: %s %s" % [config_id, JSON.stringify(position_value)])
            return false
    return true


static func position_inside_any_room(suite: SceneTree, position_value, rooms: Array) -> bool:
    if not (position_value is Array):
        return false
    var position_data: Array = position_value
    if position_data.size() < 2:
        return false
    var x := float(position_data[0])
    var y := float(position_data[1])
    for room in rooms:
        if not (room is Dictionary):
            continue
        var room_data: Dictionary = room
        if suite._room_contains_position(room_data, Vector2(x, y)):
            return true
        if suite._uses_layout_rects([room_data]):
            continue
        var range_data: Array = room_data.get("range", [])
        if range_data.size() < 2:
            continue
        if x >= float(range_data[0]) and x <= float(range_data[1]):
            return true
    return false


static func room_layout_rect(suite: SceneTree, room: Dictionary) -> Rect2:
    var rect_value = room.get("layout_rect", room.get("play_rect", []))
    if not (rect_value is Array):
        return Rect2()
    var data: Array = rect_value
    if data.size() < 4:
        return Rect2()
    return Rect2(float(data[0]), float(data[1]), float(data[2]), float(data[3]))


static func room_contains_position(suite: SceneTree, room: Dictionary, position_value: Vector2) -> bool:
    var layout_rect: Rect2 = suite._room_layout_rect(room)
    if layout_rect.size.x > 0.0 and layout_rect.size.y > 0.0:
        if position_value.x >= layout_rect.position.x and position_value.x <= layout_rect.position.x + layout_rect.size.x and position_value.y >= layout_rect.position.y and position_value.y <= layout_rect.position.y + layout_rect.size.y:
            return true
    for rect_value in room.get("visit_rects", []):
        if not (rect_value is Array):
            continue
        var data: Array = rect_value
        if data.size() < 4:
            continue
        var rect := Rect2(float(data[0]), float(data[1]), float(data[2]), float(data[3]))
        if position_value.x >= rect.position.x and position_value.x <= rect.position.x + rect.size.x and position_value.y >= rect.position.y and position_value.y <= rect.position.y + rect.size.y:
            return true
    return false


static func platform_materials(suite: SceneTree, config: Dictionary) -> Array:
    var materials: Array = []
    for platform in config.get("platforms", []):
        if not (platform is Dictionary):
            continue
        var data: Dictionary = platform
        var material := String(data.get("material", ""))
        if not materials.has(material):
            materials.append(material)
    return materials


static func platform_signature_overlap(suite: SceneTree, left_config: Dictionary, right_config: Dictionary) -> float:
    var left_signatures: Array = []
    for platform in left_config.get("platforms", []):
        if not (platform is Dictionary):
            continue
        left_signatures.append(suite._platform_signature(platform as Dictionary))
    var compared := 0
    var matched := 0
    for platform in right_config.get("platforms", []):
        if not (platform is Dictionary):
            continue
        compared += 1
        if left_signatures.has(suite._platform_signature(platform as Dictionary)):
            matched += 1
    if compared <= 0:
        return 1.0
    return float(matched) / float(compared)


static func platform_signature(suite: SceneTree, platform: Dictionary) -> String:
    return JSON.stringify({
        "rect": platform.get("rect", []),
        "material": platform.get("material", "")
    })


static func shared_enemy_position_count(suite: SceneTree, left_config: Dictionary, right_config: Dictionary) -> int:
    var left_positions: Array = []
    for enemy in left_config.get("enemy_spawns", []):
        if enemy is Dictionary:
            left_positions.append(suite._enemy_position_signature(enemy as Dictionary))
    var count := 0
    for enemy in right_config.get("enemy_spawns", []):
        if enemy is Dictionary and left_positions.has(suite._enemy_position_signature(enemy as Dictionary)):
            count += 1
    return count


static func enemy_position_signature(suite: SceneTree, enemy: Dictionary) -> String:
    var position: Array = enemy.get("position", [])
    if position.size() < 2:
        return ""
    return "%d:%d" % [int(position[0]), int(position[1])]


static func load_json(suite: SceneTree, path: String) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var data = JSON.parse_string(file.get_as_text())
    return data if typeof(data) == TYPE_DICTIONARY else {}
