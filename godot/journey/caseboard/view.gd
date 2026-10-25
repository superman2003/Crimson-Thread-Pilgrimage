extends Control
signal selected_node(id: String)
signal moved_node(id: String, point: Vector2)
const V := preload("res://journey/core/values.gd")
const COLORS := {"evidence":Color("d8c5a4"), "quest":Color("8fbca5"), "npc":Color("bca3cc"), "ending":Color("d49178")}
var graph: Dictionary = {}
var positions: Dictionary = {}
var selected := ""
var hovered := ""
var dragging := ""
var drag_start := Vector2.ZERO
var displaced := false
var screen_points: Dictionary = {}
const MAX_DRAWN := 64

func configure(value: Dictionary, saved: Dictionary, selection: String) -> void:
    graph = value.duplicate(true)
    positions = saved.duplicate(true)
    selected = selection
    var rows := maxi(1, ceili(float(mini(MAX_DRAWN, graph.get("nodes", {}).size())) / 4.0))
    custom_minimum_size = Vector2(500, maxf(300, rows * 76))
    clip_contents = true
    mouse_filter = Control.MOUSE_FILTER_STOP
    queue_redraw()

func _ready() -> void:
    resized.connect(queue_redraw)
    mouse_exited.connect(func():hovered = "";queue_redraw())

func _point(id: String, index: int) -> Vector2:
    var stored := V.point(positions.get(id, []))
    if stored.is_finite():
        return Vector2(64, 32) + stored * (size - Vector2(128, 64))
    var columns := 4
    var rows := maxi(1, ceili(float(mini(MAX_DRAWN, graph.get("nodes", {}).size())) / columns))
    return Vector2((index % columns + 0.5) * size.x / columns, (index / columns + 0.5) * size.y / rows)

func _layout() -> void:
    screen_points.clear()
    var ids: Array = graph.get("nodes", {}).keys()
    ids.sort()
    for index in mini(MAX_DRAWN, ids.size()):
        var id := String(ids[index])
        screen_points[id] = _point(id, index)

func _draw() -> void:
    _layout()
    draw_rect(Rect2(Vector2.ZERO, size), Color("0e1d22"))
    for edge in graph.get("edges", []):
        if not screen_points.has(edge.from) or not screen_points.has(edge.to):
            continue
        var a: Vector2 = screen_points[edge.from]
        var b: Vector2 = screen_points[edge.to]
        var authored: bool = edge.kind == "authored"
        var tint := Color("c2aa78") if authored else Color("607b82")
        if edge.from == selected or edge.to == selected:
            tint = Color("dba293")
        if authored:
            draw_line(a, b, tint, 2.0, true)
        else:
            var length := a.distance_to(b)
            var count := maxi(1, ceili(length / 12.0))
            for step in range(0, count, 2):
                draw_line(a.lerp(b, float(step) / count), a.lerp(b, float(mini(count, step + 1)) / count), tint, 1.0, true)
    var font := get_theme_default_font()
    for id in screen_points:
        var node: Dictionary = graph.nodes[id]
        var point: Vector2 = screen_points[id]
        var tint: Color = COLORS.get(node.kind, Color.WHITE)
        draw_circle(point, 9, tint)
        if id == selected or id == hovered:
            draw_arc(point, 13, 0, TAU, 24, Color("efdbbd"), 2.0, true)
        var title := String(node.title).left(10)
        var width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
        draw_string(font, point + Vector2(-width * 0.5, 28), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, tint)

func _nearest(point: Vector2) -> String:
    var best := ""
    var distance := 30.0
    for id in screen_points:
        var value: float = screen_points[id].distance_to(point)
        if value < distance:
            best = String(id)
            distance = value
    return best

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        if not dragging.is_empty():
            if event.position.distance_to(drag_start) > 6:
                displaced = true
            var normalized: Vector2 = (event.position - Vector2(64, 32)) / (size - Vector2(128, 64)).max(Vector2.ONE)
            positions[dragging] = V.pair(normalized.clamp(Vector2.ZERO, Vector2.ONE))
            queue_redraw()
            accept_event()
        else:
            var next := _nearest(event.position)
            if next != hovered:
                hovered = next
                tooltip_text = String(graph.nodes[hovered].title) if graph.get("nodes", {}).has(hovered) else "拖动节点可整理关系板；实线为正文关联，虚线为个人假设。"
                queue_redraw()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            dragging = _nearest(event.position)
            drag_start = event.position
            displaced = false
        elif not dragging.is_empty():
            if displaced:
                moved_node.emit(dragging, V.point(positions[dragging]))
            else:
                selected_node.emit(dragging)
            dragging = ""
            accept_event()

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        dragging = ""
        displaced = false
