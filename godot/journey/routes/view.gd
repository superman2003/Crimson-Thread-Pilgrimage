extends Control
signal room_selected(id: String)
const V := preload("res://journey/core/values.gd")
const COORD := preload("res://scripts/world_coordinates.gd")
var nodes: Dictionary = {}
var route: Array = []
var points: Dictionary = {}
var hovered := ""

func configure(graph: Dictionary, selected: Array) -> void:
    nodes = graph.get("nodes", {}).duplicate(true)
    route = selected.duplicate()
    custom_minimum_size = Vector2(500, 280)
    mouse_filter = Control.MOUSE_FILTER_STOP
    clip_contents = true
    queue_redraw()

func _ready() -> void:
    resized.connect(queue_redraw)

func _layout() -> void:
    points.clear()
    var bounds := Rect2()
    var original := {}
    for id in nodes:
        var node: Dictionary = nodes[id]
        var local := V.point(node.get("point", []))
        var world := COORD.to_world(String(node.region), local)
        if not world.is_finite():
            continue
        original[id] = world
        var footprint := Rect2(world - Vector2.ONE, Vector2(2, 2))
        bounds = footprint if bounds.size == Vector2.ZERO else bounds.merge(footprint)
    if original.is_empty():
        return
    var scale_value := minf(maxf(1.0, size.x - 36) / maxf(1.0, bounds.size.x), maxf(1.0, size.y - 36) / maxf(1.0, bounds.size.y))
    var offset := (size - bounds.size * scale_value) * 0.5
    for id in original:
        points[id] = offset + (original[id] - bounds.position) * scale_value

func _draw() -> void:
    _layout()
    draw_rect(Rect2(Vector2.ZERO, size), Color("0c1c20"))
    for index in range(1, route.size()):
        if points.has(route[index - 1]) and points.has(route[index]):
            draw_line(points[route[index - 1]], points[route[index]], Color("d0b37e"), 2.5, true)
    for id in points:
        var tint := Color("859c91")
        if route.has(id):
            tint = Color("d0b37e")
        if id == hovered:
            tint = Color("efcdc0")
        var radius := 5.0 if route.has(id) else 3.0
        draw_circle(points[id], radius, tint)
        if nodes[id].shrine:
            draw_arc(points[id], radius + 3, 0, TAU, 16, Color("b3d4c3"), 1.0, true)
    if not route.is_empty() and points.has(route[0]):
        draw_circle(points[route[0]], 8.0, Color("d0b37e"), false, 2.0, true)
    if not route.is_empty() and points.has(route[-1]):
        draw_rect(Rect2(points[route[-1]] - Vector2(7, 7), Vector2(14, 14)), Color("c76556"), false, 2.0)

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        var closest := ""
        var distance := 12.0
        for id in points:
            var current: float = points[id].distance_to(event.position)
            if current < distance:
                distance = current
                closest = String(id)
        if closest != hovered:
            hovered = closest
            tooltip_text = String(nodes[hovered].name) if nodes.has(hovered) else "只绘制已完整补绘的房间"
            queue_redraw()
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        if nodes.has(hovered):
            room_selected.emit(hovered)
            accept_event()
