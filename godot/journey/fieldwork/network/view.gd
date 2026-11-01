extends Control
var payload: Dictionary = {}
var selected := ""
var hovered := ""
var zoom := 1.0
var pan := Vector2.ZERO
var dragging := false
var previous := Vector2.ZERO
var positions: Dictionary = {}
var source_bounds := Rect2()
const PADDING := 45.0
const NODE_RADIUS := 11.0


func _init() -> void:
    custom_minimum_size = Vector2(480, 380)
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    focus_mode = Control.FOCUS_ALL
    mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    clip_contents = true


func configure(value: Dictionary) -> void:
    payload = value.duplicate(true)
    zoom = 1.0
    pan = Vector2.ZERO
    selected = String(payload.get("source", ""))
    _bounds()
    queue_redraw()


func _ready() -> void:
    resized.connect(queue_redraw)
    mouse_exited.connect(
        func():
            hovered = ""
            dragging = false
            tooltip_text = ""
            queue_redraw()
    )
    focus_entered.connect(queue_redraw)
    focus_exited.connect(
        func():
            dragging = false
            queue_redraw()
    )


func _bounds() -> void:
    var first := true
    for node in payload.get("nodes", []):
        var point := Vector2(float(node.point[0]), float(node.point[1]))
        source_bounds = Rect2(point, Vector2.ONE) if first else source_bounds.expand(point)
        first = false
    source_bounds.size.x = maxf(1, source_bounds.size.x)
    source_bounds.size.y = maxf(1, source_bounds.size.y)


func _position(point: Array) -> Vector2:
    var area := Vector2(maxf(1, size.x - PADDING * 2), maxf(1, size.y - PADDING * 2))
    var scale_factor := minf(area.x / source_bounds.size.x, area.y / source_bounds.size.y)
    var source := Vector2(float(point[0]), float(point[1]))
    return size * 0.5 + (source - source_bounds.get_center()) * scale_factor * zoom + pan


func _geometry() -> void:
    positions.clear()
    for node in payload.get("nodes", []):
        positions[node.id] = _position(node.point)


func _node_at(point: Vector2) -> String:
    var best := ""
    var distance := 24.0
    for id in positions:
        var candidate: float = positions[id].distance_to(point)
        if candidate < distance:
            distance = candidate
            best = String(id)
    return best


func _name(id: String) -> String:
    for node in payload.get("nodes", []):
        if node.id == id:
            return String(node.name)
    return ""


func _details(id: String) -> String:
    var outgoing := []
    for edge in payload.get("edges", []):
        if edge.from == id:
            outgoing.append(_name(String(edge.to)) + (" · " + String(edge.reason)))
    return _name(id) + "\n" + "\n".join(outgoing)


func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if (
            event.button_index == MOUSE_BUTTON_WHEEL_UP
            or event.button_index == MOUSE_BUTTON_WHEEL_DOWN
        ):
            zoom = clampf(
                zoom * (1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15), 1, 3
            )
            _clamp_pan()
            accept_event()
            queue_redraw()
        elif event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                grab_focus()
                previous = event.position
                dragging = true
                var id := _node_at(event.position)
                if not id.is_empty():
                    selected = id
                    tooltip_text = _details(id)
            else:
                dragging = false
            accept_event()
            queue_redraw()
    elif event is InputEventMouseMotion:
        if dragging:
            pan += event.position - previous
            previous = event.position
            _clamp_pan()
        hovered = _node_at(event.position)
        tooltip_text = (
            _details(hovered) if not hovered.is_empty() else "拖动平移，滚轮缩放；聚焦后方向键选择已知节点，Home复位。"
        )
        queue_redraw()
    elif event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_HOME:
            pan = Vector2.ZERO
            zoom = 1.0
        elif event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
            _move_focus(event.keycode)
        else:
            return
        accept_event()
        queue_redraw()


func _clamp_pan() -> void:
    pan.x = clampf(pan.x, -size.x * (zoom - 1) * 0.5, size.x * (zoom - 1) * 0.5)
    pan.y = clampf(pan.y, -size.y * (zoom - 1) * 0.5, size.y * (zoom - 1) * 0.5)


func _move_focus(key: int) -> void:
    var origin: Vector2 = positions.get(selected, size * 0.5)
    var direction := Vector2(-1, 0) if key == KEY_LEFT else Vector2(1, 0)
    if key == KEY_UP:
        direction = Vector2(0, -1)
    elif key == KEY_DOWN:
        direction = Vector2(0, 1)
    var best := ""
    var score := INF
    for id in positions:
        var delta: Vector2 = positions[id] - origin
        var advance := delta.dot(direction)
        if advance <= 0.1:
            continue
        var candidate := advance + absf(delta.cross(direction)) * 2.5
        if candidate < score:
            score = candidate
            best = String(id)
    if not best.is_empty():
        selected = best
        tooltip_text = _details(selected)


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("102021"))
    _geometry()
    for edge in payload.get("edges", []):
        if not positions.has(edge.from) or not positions.has(edge.to):
            continue
        var a: Vector2 = positions[edge.from]
        var b: Vector2 = positions[edge.to]
        var color := Color("85b6a5") if edge.open else Color("8c6960")
        if not edge.open and not payload.get("include_blocked", false):
            color.a = 0.25
        var emphasized: bool = edge.from == selected or edge.to == selected
        draw_line(a, b, color, 3.0 if emphasized else 1.2, true)
        var direction := (b - a).normalized()
        var tip := a.lerp(b, 0.7)
        var normal := Vector2(-direction.y, direction.x)
        draw_colored_polygon(
            PackedVector2Array(
                [tip, tip - direction * 9 + normal * 4, tip - direction * 9 - normal * 4]
            ),
            color
        )
    var font := get_theme_default_font()
    for id in positions:
        var point: Vector2 = positions[id]
        var active: bool = id == selected or id == hovered
        draw_circle(
            point,
            NODE_RADIUS + (3 if active else 0),
            Color("d6ba83") if active else Color("5d8d82")
        )
        draw_circle(point, NODE_RADIUS - 3, Color("122526"))
        if active or zoom > 1.5 or positions.size() <= 14:
            draw_string(
                font,
                point + Vector2(15, 4),
                _name(String(id)),
                HORIZONTAL_ALIGNMENT_LEFT,
                180,
                14,
                Color("eadcc6")
            )
    if has_focus():
        draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), Color("cfb484"), false, 2)
    draw_string(
        font,
        Vector2(10, size.y - 12),
        "已知关系图 · 方向箭头 · 滚轮缩放 · Home复位",
        HORIZONTAL_ALIGNMENT_LEFT,
        size.x - 20,
        13,
        Color("a3b3aa")
    )
