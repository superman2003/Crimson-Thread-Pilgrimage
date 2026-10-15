extends RefCounted
## Fixed world-coordinate overview. Buying/charting changes ink, never layout.
const COORD := preload("res://scripts/world_coordinates.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const PASSAGE := preload("res://scripts/world_passage.gd")
const JOURNAL := preload("res://scripts/pilgrimage_cartography.gd")
const SURVEY := preload("res://scripts/cartography_runtime.gd")
const INK := preload("res://scripts/hand_drawn_map_room.gd")
const SURFACE := preload("res://scripts/survey_map_surface.gd")
const GEOMETRY := preload("res://scripts/world_collision_geometry.gd")
const KNOWLEDGE := preload("res://scripts/survey_map_knowledge.gd")
static var configurations: Dictionary = {}
static var geometry: Dictionary = {}
static var room_contours: Dictionary = {}

static func world_bounds() -> Rect2:
    var bounds := Rect2()
    for id in COORD.manifest().regions:
        var rect := COORD.region_bounds(id)
        bounds = rect if bounds.size == Vector2.ZERO else bounds.merge(rect)
    return bounds

static func frame(size: Vector2) -> Dictionary:
    var bounds := world_bounds()
    var available := size - Vector2(48, 76)
    var scale := minf(available.x / bounds.size.x, available.y / bounds.size.y)
    return {"bounds": bounds, "scale": scale, "offset": (size - bounds.size * scale) * 0.5}

static func project(point: Vector2, layout: Dictionary) -> Vector2:
    return layout.offset + (point - layout.bounds.position) * layout.scale

static func configuration(id: String) -> Dictionary:
    if not configurations.has(id):
        var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROUTES.config_path(id)))
        configurations[id] = ROUTES.apply_to(raw)
    return configurations[id]

static func terrain(id: String) -> Array[PackedVector2Array]:
    if geometry.has(id): return geometry[id]
    var data := configuration(id)
    var polygons: Array[PackedVector2Array] = []
    for landform in data.get("terrain", []):
        var surface: Array = landform.get("surface", [])
        var spans := GEOMETRY.terrain_spans(data, String(landform.id), surface)
        for section in GEOMETRY.terrain_sections(surface, float(landform.get("depth", 104)), spans):
            polygons.append(section.polygon)
    for platform in data.get("platforms", []):
        if not String(platform.get("terrain_id", "")).is_empty(): continue
        var rect: Array = platform.rect
        polygons.append(SURVEY.rect_polygon(Rect2(rect[0], rect[1], rect[2], rect[3])))
    geometry[id] = polygons
    return polygons

static func render(level: Node) -> void:
    var host: Control = level.map_draw_root
    var layout := frame(host.size)
    host.set_meta("world_atlas_frame", layout)
    var current := String(level.config.id)
    for id_value in COORD.manifest().regions:
        var id := String(id_value)
        var data := configuration(id)
        var bounds := COORD.region_bounds(id)
        var title := Label.new()
        title.name = "WorldRegion_" + id
        title.position = project(bounds.position, layout) - Vector2(0, 22)
        title.size = Vector2(bounds.size.x * layout.scale, 22)
        title.text = String(data.get("chapter_name", data.get("name", id)))
        title.add_theme_font_size_override("font_size", 14)
        title.add_theme_color_override("font_color", SURFACE.ACCENT if id == current else SURFACE.INK)
        title.mouse_filter = Control.MOUSE_FILTER_PASS
        title.tooltip_text = "未购本区地图" if not JOURNAL.owned(level.story_flags, id) else "已补绘 %d 室" % JOURNAL.region(level.story_flags, id).charted.size()
        host.add_child(title)
        if not JOURNAL.owned(level.story_flags, id): continue
        var surface := SURFACE.new()
        surface.name = "WorldSilhouette_" + id
        surface.size = host.size
        host.add_child(surface)
        for room in data.get("map_rooms", []):
            var room_id := String(room.id)
            var detailed := JOURNAL.charted(level.story_flags, id, room_id)
            if not detailed and not SURVEY.public_room(room): continue
            var physical := SURVEY.room_rect(room)
            if physical.size.x <= 0 or physical.size.y <= 0: continue
            var outline: Control = INK.new()
            outline.name = "WorldSurvey_" + id + "_" + room_id
            outline.position = project(COORD.to_world(id, physical.position), layout)
            outline.size = physical.size * layout.scale
            outline.mouse_filter = Control.MOUSE_FILTER_PASS
            outline.draw_ink = false
            outline.detailed = detailed
            var footprint := Rect2(outline.position, outline.size)
            if detailed: surface.charted_rooms.append(footprint)
            else: surface.base_rooms.append(footprint)
            outline.seed_value = room_id.hash()
            outline.stroke_scale = 0.6
            if detailed:
                var key := id + ":" + room_id
                if not room_contours.has(key):
                    room_contours[key] = SURVEY.room_terrain_config(data, room, terrain(id))
                outline.contours = room_contours[key]
            outline.set_meta("region_id", id)
            outline.set_meta("room_id", room_id)
            outline.set_meta("charted", detailed)
            outline.tooltip_text = String(room.get("name", room_id)) if detailed or SURVEY.public_room(room) else ""
            host.add_child(outline)
        surface.prepare()
        # Every region is evaluated against its own config. Ability inventory
        # is shared, while permanent action gates read their authored unlock id.
        for record in KNOWLEDGE.marker_records(data, level.story_flags, id, level.inventory_counts):
            var world_point: Vector2 = COORD.to_world(id, record.rect.get_center())
            var marker := Label.new()
            marker.name = ("WorldHazard_" if record.kind == "hazard" else "WorldGate_") + id + "_" + String(record.id)
            marker.position = project(world_point, layout) - Vector2(6, 9)
            marker.mouse_filter = Control.MOUSE_FILTER_PASS
            marker.text = String(record.text)
            marker.tooltip_text = String(record.tooltip)
            marker.add_theme_font_size_override("font_size", 11)
            marker.add_theme_color_override("font_color", Color("b44e43") if record.kind == "hazard" else SURFACE.GOLD)
            host.add_child(marker)
    var drawn: Dictionary = {}
    for id_value in COORD.manifest().regions:
        var id := String(id_value)
        var data := configuration(id)
        for portal in data.get("interactives", []):
            if String(portal.get("kind", "")) != "world_portal": continue
            var target := String(portal.get("target_config_id", ""))
            var peer := ROUTES.portal(target, String(portal.get("target_portal_id", "")))
            if peer.is_empty(): continue
            var a_key := id + ":" + String(portal.id)
            var b_key := target + ":" + String(peer.id)
            var key := a_key + ":" + b_key if a_key < b_key else b_key + ":" + a_key
            if drawn.has(key): continue
            if not JOURNAL.charted(level.story_flags, id, String(portal.get("room_id", ""))) and not JOURNAL.charted(level.story_flags, target, String(peer.get("room_id", ""))): continue
            drawn[key] = true
            var forward := ROUTES.access(portal, level.inventory_counts, level.story_flags)
            var reverse := ROUTES.access(peer, level.inventory_counts, level.story_flags)
            var a := COORD.to_world(id, Vector2(portal.position[0], portal.position[1]))
            var b := COORD.to_world(target, Vector2(peer.position[0], peer.position[1]))
            var physical := not PASSAGE.endpoint(id, String(portal.id)).is_empty()
            var line := Line2D.new()
            line.name = "WorldRoute_" + String(portal.id)
            line.width = 2.4 if physical else 1.0
            line.default_color = SURFACE.INK if physical else Color(0.55, 0.61, 0.56, 0.28)

            if not forward.open or not reverse.open: line.default_color = Color(0.74, 0.63, 0.46, 0.45)
            line.visible = physical
            line.points = PackedVector2Array([project(a, layout), project(b, layout)])
            line.set_meta("source_room", String(portal.get("room_id", "")))
            line.set_meta("target_room", String(peer.get("room_id", "")))
            line.set_meta("source_region", id)
            line.set_meta("target_region", target)
            line.set_meta("source_world", a)
            line.set_meta("target_world", b)
            line.set_meta("physical_passage", physical)
            line.set_meta("forward_status", forward)
            line.set_meta("reverse_status", reverse)
            host.add_child(line)
            host.move_child(line, 0)
            var badge := Label.new()
            badge.name = "WorldRouteState_" + String(portal.id)
            badge.position = project(a if not forward.open else b, layout) - Vector2(6, 9)
            badge.mouse_filter = Control.MOUSE_FILTER_PASS
            badge.text = "◇" if not forward.open or not reverse.open else ""
            badge.add_theme_font_size_override("font_size", 12)
            badge.add_theme_color_override("font_color", SURFACE.GOLD)
            badge.tooltip_text = "正向：%s\n反向：%s" % [forward.label, reverse.label]
            host.add_child(badge)
    # Old portal links are a hover detail, rather than a web of diagonals
    # across every region. The solid physical passage remains always visible.
    for child in host.get_children():
        if not String(child.name).begins_with("WorldSurvey_"): continue
        var links: Array[Line2D] = []
        for route in host.get_children():
            if not route is Line2D or bool(route.get_meta("physical_passage")): continue
            var source: bool = route.get_meta("source_region") == child.get_meta("region_id") and route.get_meta("source_room") == child.get_meta("room_id")
            var target: bool = route.get_meta("target_region") == child.get_meta("region_id") and route.get_meta("target_room") == child.get_meta("room_id")
            if source or target: links.append(route)
        child.mouse_entered.connect(func():
            for route in links:
                if is_instance_valid(route): route.visible = true)
        child.mouse_exited.connect(func():
            for route in links:
                if is_instance_valid(route): route.visible = false)
    var dot := Label.new()
    dot.name = "WorldSurveyPlayer"
    dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
    dot.text = "◆"
    dot.position = project(level.player_world_position(), layout) - Vector2(6, 9)
    dot.add_theme_color_override("font_color", SURFACE.ACCENT)
    host.add_child(dot)
    level.map_text.text = "◆ 位置    ◇ 门槛    滚轮缩放 / 拖动    Tab 区域地图    M / Esc 返回"
    level.map_text.tooltip_text = "实线是实体钟管；悬停房间可查看名称和旧路端点关系，悬停门槛可查看通行条件。"
