extends RefCounted
## The map page: building it, redrawing rooms, routes and pins, and opening it.
## Moved out of main_level.gd unchanged in behaviour; the level keeps one-line
## methods of the same names, so callers and validations are unaffected.
const CARTOGRAPHY_UI := preload("res://scripts/cartography_runtime.gd")
const MAP_PLAYER_PINS := preload("res://scripts/map_player_pins_runtime.gd")

const PILGRIMAGE_UI_SCRIPT := preload("res://scripts/pilgrimage_interface.gd")

static func build_map_overlay(level: Node) -> void:
    level.map_panel = ColorRect.new()
    level.map_panel.name = "CourtMapOverlay"
    level.map_panel.position = Vector2(52, 54)
    level.map_panel.size = Vector2(1176, 640)
    level.map_panel.color = Color("091719")
    if level.world_mode:
        level.map_panel.theme = level.ui_shell.theme.duplicate()
    level.map_panel.visible = false
    level.ui_shell.add_child(level.map_panel)

    var map_art := TextureRect.new()
    map_art.name = "MapBackgroundArt"
    map_art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    map_art.texture = level._load_texture_resource(level._theme_map_background_texture())
    map_art.position = Vector2.ZERO
    map_art.size = level.map_panel.size
    map_art.stretch_mode = TextureRect.STRETCH_SCALE
    map_art.modulate = Color(1,1,1,.07)
    map_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    level.map_panel.add_child(map_art)
    level.ui_shell.frame(level.map_panel)
    level.map_panel.get_child(0).kind="map"
    level.map_panel.move_child(level.map_panel.get_child(0),1)
    level.ui_shell._icon(level.map_panel,preload("res://assets/ui/inscription/v2/map.png"),Vector2(23,2),Vector2(112,65))

    var title := Label.new()
    title.text = level._theme_map_title()
    title.name = "SurveyMapTitle"
    title.position = Vector2(155, 20)
    title.add_theme_font_override("font",PILGRIMAGE_UI_SCRIPT.display_font())
    title.add_theme_font_size_override("font_size", 23)
    title.add_theme_color_override("font_color", PILGRIMAGE_UI_SCRIPT.IVORY)
    level.map_panel.add_child(title)

    level.ui_shell._button(level.map_panel,"返回",Vector2(1080,18),Vector2(62,34),func():level._close_overlays())

    level.map_draw_root = Control.new()
    level.map_draw_root.name = "MapDrawRoot"
    level.map_draw_root.position = Vector2(34, 78) if level.world_mode else Vector2(34, 106)
    level.map_draw_root.size = Vector2(1108, 504) if level.world_mode else Vector2(1108, 396)
    if level.world_mode:
        # Only the zoomed content needs MSDF glyphs. Fixed titles, hints and
        # pin controls reuse the ordinary HUD font instead of rasterizing a
        # second CJK glyph atlas during every cold map setup.
        level.map_draw_root.theme = level.ui_shell.theme.duplicate()
        level.map_draw_root.theme.default_font = PILGRIMAGE_UI_SCRIPT.survey_font()
        level.survey_map_view = preload("res://scripts/survey_map_view.gd").new()
        level.survey_map_view.name = "SurveyMapViewport"
        level.survey_map_view.position = level.map_draw_root.position
        level.survey_map_view.size = level.map_draw_root.size
        level.map_draw_root.position = Vector2.ZERO
        level.map_draw_root.mouse_filter = Control.MOUSE_FILTER_PASS
        level.survey_map_view.content = level.map_draw_root
        level.map_panel.add_child(level.survey_map_view)
        level.survey_map_view.add_child(level.map_draw_root)
        var out_button: Button = level.ui_shell._button(level.map_panel,"−",Vector2(946,18),Vector2(34,34),func():level.survey_map_view.magnify(0.8))
        out_button.tooltip_text = "缩小地图"
        var in_button: Button = level.ui_shell._button(level.map_panel,"+",Vector2(984,18),Vector2(34,34),func():level.survey_map_view.magnify(1.25))
        in_button.tooltip_text = "放大地图"
        var reset_button: Button = level.ui_shell._button(level.map_panel,"复位",Vector2(1022,18),Vector2(50,34),func():level.survey_map_view.reset())
        reset_button.tooltip_text = "显示完整地图"
    else:
        level.map_panel.add_child(level.map_draw_root)

    level.map_text = Label.new()
    level.map_text.position = Vector2(34, 600) if level.world_mode else Vector2(34, 514)
    level.map_text.size = Vector2(1108, 24) if level.world_mode else Vector2(1108, 110)
    level.map_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    level.map_text.add_theme_font_size_override("font_size", 14)
    level.map_text.add_theme_color_override("font_color", PILGRIMAGE_UI_SCRIPT.IVORY)
    level.map_panel.add_child(level.map_text)
    level._build_wish_board_overlay()


static func toggle_map(level: Node) -> void:
    if level.ui_shell != null and is_instance_valid(level.ui_shell.get("build_panel")):
        level.ui_shell.build_panel.visible = false
    if level.active_overlay == "map":
        level._close_overlays()
        return
    if level.active_overlay in ["cartographer", "recall"]:
        level._close_overlays()
    level.world_map_view = false
    level._play_sfx("ui_map_open", -2.0)
    level._notify_dialogue_closed()
    level.active_overlay = "map"
    if level.backpack_panel != null:
        level.backpack_panel.visible = false
    if level.dialogue_panel != null:
        level.dialogue_panel.visible = false
    if level.settings_panel != null:
        level.settings_panel.visible = false
    if level.map_panel != null:
        level.map_panel.visible = true
    level._sync_ui_input_lock()
    level._update_room_visit()
    level._refresh_map_overlay()


static func room_map_rect(level: Node, room_data: Dictionary) -> Rect2:
    var rect_value: Variant = room_data.get("map_rect", [])
    if typeof(rect_value) == TYPE_ARRAY and rect_value.size() >= 4:
        return level._rect2(rect_value)
    return level._room_layout_rect(room_data)


static func map_room_by_id(level: Node, room_id: String) -> Dictionary:
    for room_value in level.config.get("map_rooms", []):
        if room_value is Dictionary and String(room_value.get("id", "")) == room_id:
            return room_value
    return {}


static func refresh_map_overlay(level: Node) -> void:
    if level.map_draw_root == null or level.map_text == null:
        return
    if level.survey_map_view != null: level.survey_map_view.set_view(1 if level.world_map_view else 0)
    var title: Label = level.map_panel.get_node_or_null("SurveyMapTitle")
    if title != null:
        title.text = ("世界地图" if level.world_map_view else String(level.config.get("chapter_name", "区域地图"))) if level.world_mode else level._theme_map_title()
    for child in level.map_draw_root.get_children():
        child.free()

    var rooms: Array = level.config.get("map_rooms", [])
    var draw_width: float = 760.0 if not level._wish_board_entries().is_empty() else 1108.0
    var draw_size := Vector2(draw_width, level.map_draw_root.size.y)
    var base_y := 132.0
    var depth_step := 72.0
    var layout_bounds := map_layout_bounds(level, rooms)
    var uses_layout := layout_bounds.size.x > 0.0 and layout_bounds.size.y > 0.0
    if level.wish_panel != null:
        level.wish_panel.visible = not (level.world_mode and level.world_map_view)
    if level.world_mode and level.world_map_view:
        CARTOGRAPHY_UI.paper(level, true)
        level._draw_world_atlas()
        MAP_PLAYER_PINS.refresh(level)
        preload("res://scripts/death_recovery_map.gd").render(level)
        return
    if level.world_mode:
        CARTOGRAPHY_UI.render(level)
        MAP_PLAYER_PINS.refresh(level)
        preload("res://scripts/death_recovery_map.gd").render(level)
        return
    add_map_route_line(level, rooms, draw_width, base_y, depth_step, layout_bounds, draw_size)
    for room in rooms:
        if not (room is Dictionary):
            continue
        var room_data: Dictionary = room
        var room_id := String(room_data.get("id", ""))
        var overlay_rect: Rect2 = map_room_overlay_rect(level, room_data, layout_bounds, draw_size, draw_width, base_y, depth_step)
        if overlay_rect.size.x <= 0.0 or overlay_rect.size.y <= 0.0:
            continue
        var visited: bool = level._room_is_visited(room_id)
        var current: bool = room_id == level.current_room_id
        var room_size: Vector2 = overlay_rect.size
        var fill := Color(0.060, 0.115, 0.092, 0.98) if visited else Color(0.030, 0.038, 0.042, 0.98)
        var border := Color(0.74, 1.0, 0.92, 1.0) if current else (Color(0.42, 0.78, 0.56, 0.90) if visited else Color(0.24, 0.30, 0.28, 0.92))
        var border_width: float = 4.0 if current else 2.0
        add_map_ui_rect(level, "Room_" + room_id, overlay_rect.position, room_size, fill, border, border_width)
        add_map_wall_caps(level, room_id, overlay_rect.position, room_size, visited, current)

        var room_kind := String(room_data.get("kind", ""))
        var should_label: bool = not uses_layout or current or room_kind == "boss" or room_kind == "exit" or room_id == "entry_bell"
        if not should_label:
            continue
        var label := Label.new()
        label.text = level._room_name(room_id)
        label.position = overlay_rect.position + (Vector2(4.0, 4.0) if uses_layout else Vector2(6.0, 48.0))
        label.size = Vector2(maxf(62.0, room_size.x - 4.0), 42.0)
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        label.add_theme_font_size_override("font_size", 11 if uses_layout and not current else (12 if uses_layout else (14 if current else 12)))
        label.add_theme_color_override("font_color", Color(0.88, 1.0, 0.95) if current else (Color(0.86, 0.94, 0.80) if visited else Color(0.50, 0.56, 0.52)))
        level.map_draw_root.add_child(label)

    add_map_special_passage_markers(level, draw_width, base_y, depth_step, layout_bounds, draw_size)
    add_world_map_pins(level, draw_width, base_y, depth_step, layout_bounds, draw_size)
    if level.world_mode:
        level._add_world_portal_map_pins(layout_bounds, draw_size, draw_width, base_y, depth_step)
    if level.player != null and is_instance_valid(level.player):
        if uses_layout:
            var player_room: Dictionary = level._room_for_position(level.player.global_position)
            var player_pos: Vector2 = map_room_world_position_to_overlay(level, player_room, level.player.global_position, layout_bounds, draw_size)
            add_map_ui_rect(level, "PlayerMarker", player_pos - Vector2(7.0, 7.0), Vector2(14.0, 14.0), Color(0.21, 0.92, 1.0, 0.98), Color(0.86, 1.0, 1.0, 1.0), 3.0)
        else:
            var player_x := clampf(level.player.global_position.x / level.world_width * draw_width, 0.0, draw_width)
            add_map_ui_rect(level, "PlayerMarker", Vector2(player_x - 7.0, base_y - 36.0), Vector2(14.0, 96.0), Color(0.21, 0.92, 1.0, 0.98), Color(0.86, 1.0, 1.0, 1.0), 3.0)

    var current_room: Dictionary = level._room_for_position(level.player.global_position) if level.player != null and is_instance_valid(level.player) else {}
    var current_map_room_id := String(current_room.get("id", level.current_room_id))
    var objective: String = level._room_map_copy(current_map_room_id, "objective", "Keep exploring toward the next bell.")
    var guide: String = level._room_map_copy(current_map_room_id, "guide", "Use the map for route status and F for nearby interactions.")
    var danger: String = level._room_map_copy(current_map_room_id, "danger", "Watch enemy windups.")
    var next_step: String = level._room_map_copy(current_map_room_id, "next", "Move forward.")
    if level.world_mode:
        objective = "找回被删去的名字，接通旧运书线。"
        guide = level._world_exploration_hint()
        next_step = "金色出口待解锁；蓝色出口已接通 · %s 世界图" % level.ui_shell._short_binding("inventory")
    level.map_text.text = "%s  ·  %s  ·  探索 %d/%d  ·  捷径 %d/%d\n目标  %s\n路线  %s  →  %s\n危险  %s\n%s / %s 返回  ·  %s 与附近人物或机关互动" % [
        String(level.current_campaign_chapter.get("name", "苔钟庭")),
        level._room_name(level.current_room_id),
        level.visited_rooms.size(),
        rooms.size(),
        level._opened_shortcut_total(),
        level._shortcut_total(),
        objective,
        guide,
        next_step,
        danger,
        level.ui_shell._short_binding("map"), level.ui_shell._short_binding("close_overlay"), level.ui_shell._short_binding("interact")
    ]


static func map_layout_bounds(level: Node, rooms: Array) -> Rect2:
    var has_layout := false
    var min_x := INF
    var min_y := INF
    var max_x := -INF
    var max_y := -INF
    for room in rooms:
        if not (room is Dictionary):
            continue
        var rect := room_map_rect(level, room)
        if rect.size.x <= 0.0 or rect.size.y <= 0.0:
            continue
        has_layout = true
        min_x = minf(min_x, rect.position.x)
        min_y = minf(min_y, rect.position.y)
        max_x = maxf(max_x, rect.position.x + rect.size.x)
        max_y = maxf(max_y, rect.position.y + rect.size.y)
    if not has_layout:
        return Rect2()
    return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


static func map_world_to_overlay(level: Node, world_position: Vector2, layout_bounds: Rect2, draw_size: Vector2) -> Vector2:
    if layout_bounds.size.x <= 0.0 or layout_bounds.size.y <= 0.0:
        return Vector2.ZERO
    var map_scale := minf(draw_size.x / layout_bounds.size.x, draw_size.y / layout_bounds.size.y)
    var fitted_size := layout_bounds.size * map_scale
    var offset := Vector2((draw_size.x - fitted_size.x) * 0.5, (draw_size.y - fitted_size.y) * 0.5)
    return offset + (world_position - layout_bounds.position) * map_scale


static func map_room_world_position_to_overlay(level: Node, room: Dictionary, world_position: Vector2, layout_bounds: Rect2, draw_size: Vector2) -> Vector2:
    if room.is_empty():
        return level._map_world_to_overlay(world_position, layout_bounds, draw_size)
    var map_rect := room_map_rect(level, room)
    var physical_rect: Rect2 = level._room_layout_rect(room)
    if map_rect.size.x <= 0.0 or map_rect.size.y <= 0.0:
        return level._map_world_to_overlay(world_position, layout_bounds, draw_size)
    var normalized := Vector2(0.5, 0.5)
    if physical_rect.size.x > 0.0 and physical_rect.size.y > 0.0:
        normalized.x = clampf((world_position.x - physical_rect.position.x) / physical_rect.size.x, 0.16, 0.84)
        normalized.y = clampf((world_position.y - physical_rect.position.y) / physical_rect.size.y, 0.20, 0.80)
    return level._map_world_to_overlay(map_rect.position + map_rect.size * normalized, layout_bounds, draw_size)


static func map_room_overlay_rect(level: Node, room_data: Dictionary, layout_bounds: Rect2, draw_size: Vector2, draw_width: float, base_y: float, depth_step: float) -> Rect2:
    var layout := room_map_rect(level, room_data)
    if layout.size.x > 0.0 and layout.size.y > 0.0 and layout_bounds.size.x > 0.0 and layout_bounds.size.y > 0.0:
        var top_left: Vector2 = level._map_world_to_overlay(layout.position, layout_bounds, draw_size)
        var bottom_right: Vector2 = level._map_world_to_overlay(layout.position + layout.size, layout_bounds, draw_size)
        return Rect2(top_left, Vector2(maxf(24.0, bottom_right.x - top_left.x), maxf(12.0, bottom_right.y - top_left.y)))
    var room_range: Array = room_data.get("range", [0.0, 0.0])
    if room_range.size() < 2:
        return Rect2()
    var start_x := float(room_range[0])
    var end_x := float(room_range[1])
    var x0: float = start_x / level.world_width * draw_width
    var x1: float = end_x / level.world_width * draw_width
    var y := base_y + float(int(room_data.get("depth", 0))) * depth_step
    return Rect2(Vector2(x0, y), Vector2(maxf(34.0, x1 - x0 - 6.0), 42.0))


static func add_world_map_pins(level: Node, draw_width: float, base_y: float, depth_step: float, layout_bounds: Rect2 = Rect2(), draw_size: Vector2 = Vector2.ZERO) -> void:
    for data in level.config.get("cave_lifts", []):
        for y in [float(data.top_y),float(data.bottom_y)]:
            level._add_map_pin(Vector2(float(data.x),y),draw_width,base_y,depth_step,Color(.6,.8,.9,.95),Vector2(11,11),layout_bounds,draw_size)
    for collectible in level.config.get("collectibles", []):
        if collectible is Dictionary:
            var data: Dictionary = collectible
            level._add_map_pin(level._vec2(data.get("position", [0, 0])), draw_width, base_y, depth_step, Color(1.0, 0.74, 0.24, 0.95), Vector2(9, 9), layout_bounds, draw_size)
    for interactive in level.config.get("interactives", []):
        if interactive is Dictionary:
            var data: Dictionary = interactive
            level._add_map_pin(level._vec2(data.get("position", [0, 0])), draw_width, base_y, depth_step, Color(0.94, 0.54, 0.22, 0.95), Vector2(9, 9), layout_bounds, draw_size)
    var boss_data: Dictionary = level.config.get("boss", {})
    if not boss_data.is_empty():
        level._add_map_pin(level._vec2(boss_data.get("position", [0, 0])), draw_width, base_y, depth_step, Color(0.86, 0.18, 0.16, 0.95), Vector2(14, 14), layout_bounds, draw_size)


static func add_map_pin(level: Node, world_position: Vector2, draw_width: float, base_y: float, depth_step: float, color: Color, size_value: Vector2 = Vector2(9, 9), layout_bounds: Rect2 = Rect2(), draw_size: Vector2 = Vector2.ZERO) -> void:
    var room: Dictionary = level._room_for_position(world_position)
    if not room.is_empty() and not level._room_is_visited(String(room.get("id", ""))):
        return
    var pin_pos := Vector2.ZERO
    if layout_bounds.size.x > 0.0 and layout_bounds.size.y > 0.0 and draw_size != Vector2.ZERO:
        pin_pos = map_room_world_position_to_overlay(level, room, world_position, layout_bounds, draw_size) - size_value * 0.5
    else:
        var depth := 0
        if not room.is_empty():
            depth = int(room.get("depth", 0))
        pin_pos = Vector2(clampf(world_position.x / level.world_width * draw_width, 0.0, draw_width) - size_value.x * 0.5, base_y + float(depth) * depth_step - 18.0)
    add_map_ui_rect(level, "MapPin", pin_pos, size_value + Vector2(5.0, 5.0), color, Color(1.0, 0.95, 0.72, 0.95), 2.0)


static func add_map_route_line(level: Node, rooms: Array, draw_width: float, base_y: float, depth_step: float, layout_bounds: Rect2 = Rect2(), draw_size: Vector2 = Vector2.ZERO) -> void:
    if layout_bounds.size.x > 0.0 and layout_bounds.size.y > 0.0 and draw_size != Vector2.ZERO:
        var drew_connection := false
        for connection_value in level.config.get("connections", []):
            if not (connection_value is Dictionary):
                continue
            var connection: Dictionary = connection_value
            var from_room: Dictionary = level._map_room_by_id(String(connection.get("from", "")))
            var to_room: Dictionary = level._map_room_by_id(String(connection.get("to", "")))
            if from_room.is_empty() or to_room.is_empty():
                continue
            var from_rect := room_map_rect(level, from_room)
            var to_rect := room_map_rect(level, to_room)
            if from_rect.size.x <= 0.0 or to_rect.size.x <= 0.0:
                continue
            var edge := Line2D.new()
            var edge_kind := String(connection.get("edge_kind", connection.get("type", "passage")))
            edge.name = "MapEdge_" + String(connection.get("from", "")) + "_" + String(connection.get("to", ""))
            edge.width = 5.0 if edge_kind in ["unlock_shortcut", "ability_gate"] else 3.0
            edge.default_color = Color(0.91, 0.68, 0.28, 0.86) if edge_kind in ["unlock_shortcut", "ability_gate"] else (Color(0.38, 0.76, 0.96, 0.78) if edge_kind == "one_way_drop" else Color(0.33, 0.72, 0.58, 0.70))
            edge.z_index = 1
            edge.points = PackedVector2Array([
                level._map_world_to_overlay(from_rect.position + from_rect.size * 0.5, layout_bounds, draw_size),
                level._map_world_to_overlay(to_rect.position + to_rect.size * 0.5, layout_bounds, draw_size)
            ])
            level.map_draw_root.add_child(edge)
            drew_connection = true
        if drew_connection:
            return
    var route := Line2D.new()
    route.name = "MapRouteLine"
    route.width = 4.0
    route.default_color = Color(0.54, 0.82, 0.92, 0.62) if level._is_rain_foundry_theme() else Color(0.33, 0.72, 0.58, 0.58)
    route.z_index = 1
    var points := PackedVector2Array()
    var previous_point := Vector2.ZERO
    var has_previous_point := false
    for room in rooms:
        if not (room is Dictionary):
            continue
        var room_data: Dictionary = room
        var point := Vector2.ZERO
        var layout := room_map_rect(level, room_data)
        if layout.size.x > 0.0 and layout.size.y > 0.0 and layout_bounds.size.x > 0.0 and layout_bounds.size.y > 0.0 and draw_size != Vector2.ZERO:
            point = level._map_world_to_overlay(layout.position + layout.size * 0.5, layout_bounds, draw_size)
        else:
            var room_range: Array = room_data.get("range", [0.0, 0.0])
            if room_range.size() < 2:
                continue
            var center_x: float = ((float(room_range[0]) + float(room_range[1])) * 0.5) / level.world_width * draw_width
            var y := base_y + float(int(room_data.get("depth", 0))) * depth_step + 21.0
            point = Vector2(center_x, y)
        if has_previous_point and not is_equal_approx(previous_point.y, point.y):
            points.append(Vector2(previous_point.x, point.y))
        points.append(point)
        previous_point = point
        has_previous_point = true
    route.points = points
    level.map_draw_root.add_child(route)


static func add_map_wall_caps(level: Node, room_id: String, rect_position: Vector2, rect_size: Vector2, visited: bool, current: bool) -> void:
    var alpha := 0.94 if visited or current else 0.62
    var wall_fill := Color(0.008, 0.014, 0.014, alpha)
    var wall_edge := Color(0.13, 0.22, 0.20, alpha)
    var cap_size := Vector2(5.0, maxf(18.0, rect_size.y - 14.0))
    var y := rect_position.y + 7.0
    add_map_ui_rect(level, "MapWallL_" + room_id, Vector2(rect_position.x - 2.0, y), cap_size, wall_fill, wall_edge, 1.0)
    add_map_ui_rect(level, "MapWallR_" + room_id, Vector2(rect_position.x + rect_size.x - 3.0, y), cap_size, wall_fill, wall_edge, 1.0)


static func add_map_special_passage_markers(level: Node, draw_width: float, base_y: float, depth_step: float, layout_bounds: Rect2 = Rect2(), draw_size: Vector2 = Vector2.ZERO) -> void:
    for interactive in level.config.get("interactives", []):
        if not (interactive is Dictionary):
            continue
        var data: Dictionary = interactive
        var interact_type := String(data.get("kind", data.get("type", "")))
        if interact_type != "boss_gate" and interact_type != "chapter_exit" and interact_type != "ending_exit":
            continue
        var world_position: Vector2 = level._vec2(data.get("position", [0, 0]))
        var room: Dictionary = level._room_for_position(world_position)
        if not room.is_empty() and not level._room_is_visited(String(room.get("id", ""))):
            continue
        var marker_position := Vector2.ZERO
        if layout_bounds.size.x > 0.0 and layout_bounds.size.y > 0.0 and draw_size != Vector2.ZERO:
            marker_position = map_room_world_position_to_overlay(level, room, world_position, layout_bounds, draw_size)
        else:
            var depth := int(room.get("depth", 0)) if not room.is_empty() else 0
            marker_position = Vector2(clampf(world_position.x / level.world_width * draw_width, 0.0, draw_width), base_y + float(depth) * depth_step + 21.0)
        var marker_color := Color(1.0, 0.68, 0.24, 0.96) if interact_type == "boss_gate" else Color(0.45, 0.76, 1.0, 0.96)
        add_map_ui_rect(level, "MetSysPassage_" + interact_type, marker_position - Vector2(4.0, 17.0), Vector2(8.0, 34.0), marker_color, Color(1.0, 0.95, 0.72, 0.94), 2.0)


static func add_map_ui_rect(level: Node, node_name: String, rect_position: Vector2, rect_size: Vector2, fill: Color, border: Color, border_width: float) -> ColorRect:
    var border_rect := ColorRect.new()
    border_rect.name = node_name + "Border"
    border_rect.position = rect_position - Vector2(border_width, border_width)
    border_rect.size = rect_size + Vector2(border_width * 2.0, border_width * 2.0)
    border_rect.color = border
    level.map_draw_root.add_child(border_rect)

    var fill_rect := ColorRect.new()
    fill_rect.name = node_name
    fill_rect.position = rect_position
    fill_rect.size = rect_size
    fill_rect.color = fill
    level.map_draw_root.add_child(fill_rect)
    return fill_rect
