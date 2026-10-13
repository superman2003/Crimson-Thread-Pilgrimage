extends Node2D
## In-world bronze signs and proximity pictograms. No route prose is drawn.
const COORD := preload("res://scripts/world_coordinates.gd")
const INK := Color(0.86, 0.80, 0.57)
var host: Node
var area: Area2D
var symbol := "rest"
var direction := Vector2.RIGHT
var physical_sign := false
var nearby := false
var gate_state := "open"
var key_hint := ""

static func region_symbol(region: String) -> String:
    for pair in [["ch01", "bell"], ["ch02", "forge"], ["ch03", "book"],
            ["ch04", "leaf"], ["ch05", "crystal"], ["ch06", "crown"]]:
        if region.contains(pair[0]):
            return pair[1]
    return "passage"

func configure_portal(data: Dictionary, region: String) -> void:
    symbol = region_symbol(String(data.get("target_config_id", "")))
    physical_sign = true
    var start := COORD.to_world(region, Vector2(data.position[0], data.position[1]))
    var spawn: Array = data.get("target_spawn", [0, 0])
    var end := COORD.to_world(String(data.get("target_config_id", "")), Vector2(spawn[0], spawn[1]))
    if start.is_finite() and end.is_finite():
        var delta := end - start
        direction = Vector2(signf(delta.x), 0) if absf(delta.x) >= absf(delta.y) else Vector2(0, signf(delta.y))
    queue_redraw()

func _process(_delta: float) -> void:
    if not is_instance_valid(host) or not is_instance_valid(area):
        return
    # Use the same chosen object/range as interaction, not a larger hint radius.
    nearby = is_instance_valid(host.player) and host.active_overlay == "" and not host.world_loading and host.player.global_position.distance_to(area.global_position) < 140 and host._nearest_interactable(140) == area
    if String(area.get_meta("kind", "")) == "npc":
        symbol = "map" if area.has_meta("map_seller_region") else "shop" if area.has_meta("shop_items") or area.has_meta("shop") else "talk"
    key_hint = host.ui_shell._short_binding("interact") if nearby and is_instance_valid(host.ui_shell) else ""
    if nearby:
        host._show_first_interaction_hint(area)
    visible = physical_sign or nearby
    queue_redraw()

func _draw() -> void:
    if physical_sign:
        # Grounded post with a carved plank, behind the walking actor.
        draw_line(Vector2(0, 36), Vector2(0, -48), Color(0.20, 0.17, 0.12), 9, true)
        var plank := PackedVector2Array([Vector2(-45,-76),Vector2(45,-76),Vector2(53,-58),Vector2(45,-40),Vector2(-45,-40),Vector2(-51,-58)])
        draw_colored_polygon(plank, Color(0.15, 0.18, 0.13))
        var edge := plank.duplicate()
        edge.append(plank[0])
        draw_polyline(edge, Color(0.49, 0.44, 0.28), 2, true)
        draw_circle(Vector2(-39,-58), 2, INK)
        _icon(symbol, Vector2(-12,-58), 0.78)
        var tail := Vector2(21,-58) - direction * 10
        var tip := Vector2(21,-58) + direction * 10
        draw_line(tail, tip, INK, 2.5, true)
        var normal := Vector2(-direction.y, direction.x)
        draw_polyline(PackedVector2Array([tip-direction*6+normal*5,tip,tip-direction*6-normal*5]), INK, 2.5, true)
        if gate_state != "open":
            _icon("lock" if gate_state == "far_side" else "ability", Vector2(0,-24), 0.65)
    elif nearby:
        draw_circle(Vector2(0,-91), 23, Color(0.05,0.08,0.07,0.9))
        draw_arc(Vector2(0,-91), 23, 0, TAU, 32, INK, 1.5, true)
        _icon(symbol, Vector2(0,-91), 1.0)
    if nearby and not key_hint.is_empty():
        var font := ThemeDB.fallback_font
        var width := font.get_string_size(key_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
        var anchor := Vector2(-width/2, -108 if physical_sign else -124)
        draw_style_box(_key_box(), Rect2(anchor-Vector2(6,16),Vector2(width+12,23)))
        draw_string(font, anchor, key_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK)

func _key_box() -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = Color(0.05,0.08,0.07,0.9)
    box.border_color = INK
    box.set_border_width_all(1)
    box.set_corner_radius_all(4)
    return box

func _stroke(points: Array, center: Vector2, scale_value: float) -> void:
    var path := PackedVector2Array()
    for point in points:
        path.append(center + Vector2(point[0],point[1])*scale_value)
    draw_polyline(path, INK, 2.2, true)

func _icon(kind: String, c: Vector2, s: float) -> void:
    match kind:
        "rest": # One flame glyph for every rest/checkpoint, including hidden ones.
            _stroke([[-11,10],[-13,0],[-5,-9],[-3,0],[4,-15],[11,-3],[12,5],[5,11],[-11,10]],c,s)
            _stroke([[-15,15],[15,15]],c,s)
        "bell":
            _stroke([[-13,9],[-9,3],[-8,-8],[-4,-12],[4,-12],[8,-8],[9,3],[13,9],[-13,9]],c,s)
            _stroke([[-3,13],[3,13]],c,s)
        "forge":
            _stroke([[-14,-3],[14,-3],[6,3],[4,9],[10,13],[-10,13],[-4,9],[-6,3],[-14,-3]],c,s)
            _stroke([[0,-7],[4,-14]],c,s)
        "book", "map":
            _stroke([[-14,-11],[-2,-8],[0,-5],[2,-8],[14,-11],[14,10],[2,13],[0,10],[-2,13],[-14,10],[-14,-11]],c,s)
            _stroke([[0,-5],[0,10]],c,s)
            if kind == "map":
                _stroke([[-10,2],[-5,-2],[5,5],[10,0]],c,s)
        "leaf":
            _stroke([[-12,12],[-12,-2],[-5,-11],[13,-13],[11,5],[2,12],[-12,12],[8,-8]],c,s)
        "crystal":
            _stroke([[0,-15],[12,-3],[8,13],[-8,13],[-12,-3],[0,-15],[0,13]],c,s)
        "crown":
            _stroke([[-13,12],[-15,-10],[-6,0],[0,-14],[6,0],[15,-10],[13,12],[-13,12]],c,s)
        "lock":
            _stroke([[-10,0],[-10,13],[10,13],[10,0],[-10,0],[-7,0],[-7,-9],[0,-13],[7,-9],[7,0]],c,s)
        "ability":
            _stroke([[0,-14],[11,0],[0,14],[-11,0],[0,-14]],c,s)
            _stroke([[0,-6],[0,6]],c,s)
        "lever":
            _stroke([[-12,13],[12,13],[5,7],[-5,7],[-12,13]],c,s)
            _stroke([[0,7],[9,-12]],c,s)
        "shop":
            _stroke([[-12,-5],[-10,13],[10,13],[12,-5],[-12,-5],[-6,-5],[-6,-12],[6,-12],[6,-5]],c,s)
        "talk":
            _stroke([[-14,-11],[14,-11],[14,7],[0,7],[-8,14],[-8,7],[-14,7],[-14,-11]],c,s)
        _:
            _stroke([[-10,13],[-10,-10],[10,-10],[10,13]],c,s)
