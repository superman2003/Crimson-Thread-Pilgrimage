extends Node

const DIR_R := 0
const DIR_D := 1
const DIR_L := 2
const DIR_U := 3
const WALL_BORDER := 0
const PASSAGE_BORDER := 1

const WALL_COLOR := Color(0.10, 0.16, 0.15, 1.0)
const PASSAGE_COLOR := Color(0.42, 0.94, 0.75, 1.0)
const LOCKED_PASSAGE_COLOR := Color(1.0, 0.68, 0.24, 1.0)
const EXIT_PASSAGE_COLOR := Color(0.45, 0.76, 1.0, 1.0)
const ROOM_COLOR := Color(0.12, 0.26, 0.21, 1.0)
const CONNECTOR_COLOR := Color(0.08, 0.16, 0.16, 1.0)

var metsys: Node
var bridge_ready := false
var room_coords: Dictionary = {}
var current_coords := Vector3i.MAX
var registered_ids: Dictionary = {}
var stored_ids: Dictionary = {}

var connector_cells: Dictionary = {}
var route_edges: Array[String] = []
var locked_edges: Array[String] = []
var wall_decisions: Array[String] = []
var wall_border_count := 0
var passage_border_count := 0


func configure(level_config: Dictionary, world_width: float, world_height: float) -> void:
    metsys = get_node_or_null("/root/MetSys")
    if metsys == null:
        push_warning("MetSys autoload is not available.")
        return

    metsys.reset_state()
    metsys.set_save_data()
    _clear_runtime_map_data()
    metsys.settings.in_game_cell_size = Vector2(maxf(1.0, world_width / max(1, level_config.get("map_rooms", []).size())), world_height)
    metsys.current_layer = 0

    bridge_ready = false
    room_coords.clear()
    connector_cells.clear()
    route_edges.clear()
    locked_edges.clear()
    wall_decisions.clear()
    registered_ids.clear()
    stored_ids.clear()
    current_coords = Vector3i.MAX

    _build_room_cells(level_config)
    _connect_main_route(level_config)
    _mark_special_passages(level_config)
    _classify_static_walls(level_config)
    _recount_borders()

    bridge_ready = true


func _clear_runtime_map_data() -> void:
    if metsys == null or metsys.map_data == null:
        return
    metsys.map_data.cells.clear()
    metsys.map_data.custom_cells.clear()
    metsys.map_data.assigned_scenes.clear()
    metsys.map_data.cell_groups.clear()
    metsys.map_data.group_cache.clear()


func _build_room_cells(level_config: Dictionary) -> void:
    var index := 0
    for room in level_config.get("map_rooms", []):
        if not (room is Dictionary):
            continue
        var room_data: Dictionary = room
        var room_id := String(room_data.get("id", "room_%d" % index))
        var coords := Vector3i(index, int(room_data.get("depth", 0)), 0)
        room_coords[room_id] = coords
        _ensure_cell(coords, true)
        index += 1


func _ensure_cell(coords: Vector3i, is_room: bool) -> Object:
    if metsys == null or metsys.map_data == null:
        return null
    var cell: Object
    var is_new := false
    if metsys.map_data.cells.has(coords):
        cell = metsys.map_data.cells[coords]
    else:
        cell = metsys.map_data.create_cell_at(coords)
        is_new = true
    if cell == null:
        return null
    if is_new:
        var border_values: Array[int] = [WALL_BORDER, WALL_BORDER, WALL_BORDER, WALL_BORDER]
        var border_color_values: Array[Color] = [WALL_COLOR, WALL_COLOR, WALL_COLOR, WALL_COLOR]
        cell.borders = border_values
        cell.border_colors = border_color_values
        cell.color = ROOM_COLOR if is_room else CONNECTOR_COLOR
    elif is_room:
        cell.color = ROOM_COLOR
    if not is_room:
        connector_cells[str(coords)] = true
    return cell


func _connect_main_route(level_config: Dictionary) -> void:
    var explicit_connections: Array = level_config.get("connections", [])
    if not explicit_connections.is_empty():
        for connection in explicit_connections:
            if not (connection is Dictionary):
                continue
            var connection_data: Dictionary = connection
            var from_id := String(connection_data.get("from", ""))
            var to_id := String(connection_data.get("to", ""))
            if from_id.is_empty() or to_id.is_empty() or not room_coords.has(from_id) or not room_coords.has(to_id):
                continue
            _connect_cells_with_path(room_coords[from_id], room_coords[to_id], "%s->%s:%s" % [from_id, to_id, String(connection_data.get("type", "passage"))])
        return

    var previous_id := ""
    for room in level_config.get("map_rooms", []):
        if not (room is Dictionary):
            continue
        var room_data: Dictionary = room
        var room_id := String(room_data.get("id", ""))
        if room_id.is_empty() or not room_coords.has(room_id):
            continue
        if not previous_id.is_empty() and room_coords.has(previous_id):
            _connect_cells_with_path(room_coords[previous_id], room_coords[room_id], "%s->%s" % [previous_id, room_id])
        previous_id = room_id


func _connect_cells_with_path(from_coords: Vector3i, to_coords: Vector3i, label: String) -> void:
    if from_coords == to_coords:
        return
    var cursor := from_coords
    route_edges.append(label)

    while cursor.y != to_coords.y:
        var y_step := 1 if to_coords.y > cursor.y else -1
        var next := Vector3i(cursor.x, cursor.y + y_step, cursor.z)
        _ensure_cell(next, room_coords.values().has(next))
        _open_passage(cursor, next, PASSAGE_COLOR)
        cursor = next

    while cursor.x != to_coords.x:
        var x_step := 1 if to_coords.x > cursor.x else -1
        var next := Vector3i(cursor.x + x_step, cursor.y, cursor.z)
        _ensure_cell(next, room_coords.values().has(next))
        _open_passage(cursor, next, PASSAGE_COLOR)
        cursor = next


func _open_passage(a: Vector3i, b: Vector3i, color: Color) -> void:
    var dir := _direction_between(a, b)
    if dir < 0:
        return
    var opposite := _opposite_dir(dir)
    var cell_a: Object = _ensure_cell(a, room_coords.values().has(a))
    var cell_b: Object = _ensure_cell(b, room_coords.values().has(b))
    if cell_a == null or cell_b == null:
        return
    cell_a.borders[dir] = PASSAGE_BORDER
    cell_a.border_colors[dir] = color
    cell_b.borders[opposite] = PASSAGE_BORDER
    cell_b.border_colors[opposite] = color


func _mark_special_passages(level_config: Dictionary) -> void:
    for interactive in level_config.get("interactives", []):
        if not (interactive is Dictionary):
            continue
        var data: Dictionary = interactive
        var interact_type := String(data.get("kind", data.get("type", "")))
        var room_id := _room_id_for_world_position(level_config, _vec2(data.get("position", [0, 0])))
        if room_id.is_empty():
            continue
        if interact_type == "boss_gate":
            _mark_room_border(room_id, DIR_R, LOCKED_PASSAGE_COLOR)
            locked_edges.append("%s:boss_gate" % room_id)
        elif interact_type == "chapter_exit" or interact_type == "ending_exit":
            _mark_room_border(room_id, DIR_R, EXIT_PASSAGE_COLOR)
            route_edges.append("%s:%s" % [room_id, interact_type])


func _mark_room_border(room_id: String, dir: int, color: Color) -> void:
    if not room_coords.has(room_id):
        return
    var coords: Vector3i = room_coords[room_id]
    var cell: Object = _ensure_cell(coords, true)
    if cell == null:
        return
    cell.borders[dir] = PASSAGE_BORDER
    cell.border_colors[dir] = color


func _classify_static_walls(level_config: Dictionary) -> void:
    for platform in level_config.get("platforms", []):
        if not (platform is Dictionary):
            continue
        var platform_data: Dictionary = platform
        var platform_id := String(platform_data.get("id", "")).to_lower()
        if platform_id.contains("wall") or platform_id.contains("gate") or platform_id.contains("locked"):
            wall_decisions.append(platform_id)
    for gate in level_config.get("locked_gates", []):
        if gate is Dictionary:
            wall_decisions.append(String(gate.get("id", "locked_gate")).to_lower())


func _recount_borders() -> void:
    wall_border_count = 0
    passage_border_count = 0
    if metsys == null or metsys.map_data == null:
        return
    for coords in metsys.map_data.cells.keys():
        var cell: Object = metsys.map_data.cells[coords]
        for border in cell.borders:
            if int(border) == WALL_BORDER:
                wall_border_count += 1
            elif int(border) == PASSAGE_BORDER:
                passage_border_count += 1


func _direction_between(a: Vector3i, b: Vector3i) -> int:
    if b.x == a.x + 1 and b.y == a.y:
        return DIR_R
    if b.x == a.x - 1 and b.y == a.y:
        return DIR_L
    if b.y == a.y + 1 and b.x == a.x:
        return DIR_D
    if b.y == a.y - 1 and b.x == a.x:
        return DIR_U
    return -1


func _opposite_dir(dir: int) -> int:
    if dir == DIR_R:
        return DIR_L
    if dir == DIR_L:
        return DIR_R
    if dir == DIR_D:
        return DIR_U
    if dir == DIR_U:
        return DIR_D
    return -1


func _room_id_for_world_x(level_config: Dictionary, world_x: float) -> String:
    for room in level_config.get("map_rooms", []):
        if not (room is Dictionary):
            continue
        var room_data: Dictionary = room
        var room_range: Array = room_data.get("range", [0.0, 0.0])
        if room_range.size() < 2:
            continue
        if world_x >= float(room_range[0]) and world_x <= float(room_range[1]):
            return String(room_data.get("id", ""))
    return ""


func _room_id_for_world_position(level_config: Dictionary, world_position: Vector2) -> String:
    for room in level_config.get("map_rooms", []):
        if not (room is Dictionary):
            continue
        var room_data: Dictionary = room
        var rect_value = room_data.get("layout_rect", room_data.get("play_rect", []))
        if not (rect_value is Array) or rect_value.size() < 4:
            continue
        var rect := Rect2(float(rect_value[0]), float(rect_value[1]), float(rect_value[2]), float(rect_value[3]))
        if world_position.x >= rect.position.x and world_position.x <= rect.position.x + rect.size.x and world_position.y >= rect.position.y and world_position.y <= rect.position.y + rect.size.y:
            return String(room_data.get("id", ""))
    return _room_id_for_world_x(level_config, world_position.x)


func _vec2(value) -> Vector2:
    if value is Vector2:
        return value
    if value is Array and value.size() >= 2:
        return Vector2(float(value[0]), float(value[1]))
    return Vector2.ZERO


func update_player_position(global_position: Vector2, room_id: String) -> void:
    if not bridge_ready or room_id.is_empty() or not room_coords.has(room_id):
        return
    var coords: Vector3i = room_coords[room_id]
    metsys.exact_player_position = global_position
    if coords == current_coords:
        return
    current_coords = coords
    metsys.last_player_position = coords
    metsys.save_data.explore_cell(coords)
    metsys.cell_changed.emit(coords)


func register_object(object: Object, object_id: String, room_id: String = "") -> void:
    if not bridge_ready or object_id.is_empty():
        return
    object.set_meta("object_id", object_id)
    if not room_id.is_empty() and room_coords.has(room_id):
        object.set_meta("object_coords", room_coords[room_id])
    elif current_coords != Vector3i.MAX:
        object.set_meta("object_coords", current_coords)
    metsys.register_storable_object(object)
    var object_key := StringName(object_id)
    if metsys.save_data.stored_objects.has(object_key):
        registered_ids[object_id] = true
        if metsys.save_data.stored_objects.get(object_key, false):
            stored_ids[object_id] = true


func store_object(object: Object) -> void:
    if not bridge_ready:
        return
    var object_id := String(object.get_meta("object_id", ""))
    if object_id.is_empty():
        return
    if object_id in stored_ids:
        return
    var object_key := StringName(object_id)
    if not metsys.save_data.stored_objects.has(object_key):
        register_object(object, object_id)
    if not metsys.save_data.stored_objects.has(object_key):
        return
    if metsys.save_data.stored_objects.get(object_key, false):
        stored_ids[object_id] = true
        return
    metsys.store_object(object, -1)
    stored_ids[object_id] = true


func discover_room(room_id: String) -> void:
    if not bridge_ready or not room_coords.has(room_id):
        return
    var coords: Vector3i = room_coords[room_id]
    if metsys.map_data.cells.has(coords):
        metsys.discover_cell(coords)


func get_state() -> Dictionary:
    if not bridge_ready:
        return {
            "metsys_ready": false,
            "metsys_map_cells": 0,
            "metsys_discovered_cells": 0,
            "metsys_registered_objects": 0,
            "metsys_stored_objects": 0,
            "metsys_current_coords": "",
            "metsys_wall_borders": 0,
            "metsys_passage_borders": 0,
            "metsys_route_edges": 0,
            "metsys_locked_edges": 0,
            "metsys_connector_cells": 0,
            "metsys_wall_decisions": 0
        }
    return {
        "metsys_ready": true,
        "metsys_map_cells": metsys.map_data.cells.size(),
        "metsys_discovered_cells": metsys.save_data.discovered_cells.size(),
        "metsys_registered_objects": registered_ids.size(),
        "metsys_stored_objects": stored_ids.size(),
        "metsys_current_coords": str(current_coords),
        "metsys_wall_borders": wall_border_count,
        "metsys_passage_borders": passage_border_count,
        "metsys_route_edges": route_edges.size(),
        "metsys_locked_edges": locked_edges.size(),
        "metsys_connector_cells": connector_cells.size(),
        "metsys_wall_decisions": wall_decisions.size(),
        "metsys_room_coords": room_coords.size(),
        "metsys_route_labels": route_edges.duplicate(),
        "metsys_locked_labels": locked_edges.duplicate(),
        "metsys_save_data": metsys.get_save_data()
    }
