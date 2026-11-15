extends RefCounted
## Which room a position is in, its name and visited state, and recording room visits.
## Moved out of main_level.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.
const CARTOGRAPHY := preload("res://scripts/pilgrimage_cartography.gd")

static func update_room_visit(level: Node) -> void:
    if level.player == null or not is_instance_valid(level.player):
        return
    var room: Dictionary = level._room_for_position(level.player.global_position)
    if room.is_empty():
        return
    var previous_room_id = level.current_room_id
    level.current_room_id = String(room.get("id", ""))
    if not level.current_room_id.is_empty():
        var first_visit = not bool(level.visited_rooms.get(level.current_room_id, false))
        level.visited_rooms[level.current_room_id] = true
        if first_visit:
            level._play_echo_room_beat(room)
        if level.world_mode:
            CARTOGRAPHY.visit_at(level.story_flags, String(level.config.id), room, level.player.global_position)
        if level.metsys_bridge != null:
            level.metsys_bridge.update_player_position(level.player.global_position, level.current_room_id)
        if level.current_room_id != previous_room_id:
            level._abort_challenge_if_left_room()
            level._show_tool_encounter_hint()

            level._mark_hidden_route_found()
            level._save_world()
            level._trigger_whispers("enter_room", level.current_room_id)
            # 房型混响微调（规格 §5.2）：hub/vista 抬 wet、corridor/secret 收 wet。
            if level.audio_director != null:
                level.audio_director.on_room_changed(String(room.get("kind", "")))
                if level.audio_director.has_method("set_hidden_zone"):
                    level.audio_director.set_hidden_zone(level._is_hidden_room(level.current_room_id))


static func play_echo_room_beat(level: Node, room: Dictionary) -> bool:
    if String(level.config.get("id", "")) != "demo_ch06_silent_crown_core":
        return false
    if not String(room.get("id", "")).begins_with("echo_"):
        return false
    level._play_sfx("ch06_beat_echo_room", -9.0)
    return true


static func room_for_x(level: Node, world_x: float, legacy_only: bool = false) -> Dictionary:
    for room in level.config.get("map_rooms", []):
        if not (room is Dictionary):
            continue
        var room_data: Dictionary = room
        if legacy_only and level._room_has_position_bounds(room_data):
            continue
        var room_range: Array = room_data.get("range", [0.0, level.world_width])
        if room_range.size() < 2:
            continue
        if world_x >= float(room_range[0]) and world_x <= float(room_range[1]):
            return room_data
    return {}


static func room_for_position(level: Node, world_position: Vector2) -> Dictionary:
    var best_room: Dictionary = {}
    var best_area := INF
    for room in level.config.get("map_rooms", []):
        if not (room is Dictionary):
            continue
        var room_data: Dictionary = room
        var area: float = level._room_containing_area(room_data, world_position)
        if area < best_area:
            best_room = room_data
            best_area = area
    # A nested corridor or reward pocket takes precedence over its enclosing
    # hall. Only legacy rooms without authored 2D bounds may use x fallback.
    return best_room if not best_room.is_empty() else level._room_for_x(world_position.x, true)


static func room_layout_rect(level: Node, room_data: Dictionary) -> Rect2:
    var rect_value: Variant = room_data.get("layout_rect", room_data.get("play_rect", []))
    if typeof(rect_value) != TYPE_ARRAY or rect_value.size() < 4:
        return Rect2()
    return level._rect2(rect_value)


static func rect_contains_position(level: Node, rect: Rect2, position_value: Vector2, padding: float = 0.0) -> bool:
    return (
        position_value.x >= rect.position.x - padding
        and position_value.x <= rect.position.x + rect.size.x + padding
        and position_value.y >= rect.position.y - padding
        and position_value.y <= rect.position.y + rect.size.y + padding
    )


static func room_contains_position(level: Node, room_data: Dictionary, world_position: Vector2) -> bool:
    return level._room_containing_area(room_data, world_position) < INF


static func room_name(level: Node, room_id: String) -> String:
    for room in level.config.get("map_rooms", []):
        if not (room is Dictionary):
            continue
        var room_data: Dictionary = room
        if String(room_data.get("id", "")) == room_id and room_data.has("name"):
            return String(room_data.get("name", room_id))
    return String(level.ROOM_DISPLAY_NAMES.get(room_id, room_id if not room_id.is_empty() else "Unknown Room"))


static func room_is_visited(level: Node, room_id: String) -> bool:
    return bool(level.visited_rooms.get(room_id, false))
