extends Control
var payload: Dictionary = {}
var heading := 0.0
var radius := 1.0
var selected := ""
var hovered := ""
var positions: Dictionary = {}
var rotating := false
const PADDING := 35.0


func _init() -> void:
    custom_minimum_size = Vector2(480, 400)
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    focus_mode = Control.FOCUS_ALL
    clip_contents = true


func configure(value: Dictionary) -> void:
    payload = value.duplicate(true)
    heading = float(payload.get("heading", 0))
    radius = maxf(1, float(payload.get("radius", 1)))
    selected = ""
    hovered = ""
    queue_redraw()


func _ready() -> void:
    resized.connect(queue_redraw)
    focus_entered.connect(queue_redraw)
    focus_exited.connect(
        func():
            rotating = false
            queue_redraw()
    )
    mouse_exited.connect(
        func():
            hovered = ""
            rotating = false
            tooltip_text = ""
            queue_redraw()
    )


func _center() -> Vector2:
    return Vector2(size.x * 0.5, (size.y - 25) * 0.5)


func _scale_radius() -> float:
    return maxf(1, minf(size.x, size.y - 25) * 0.5 - PADDING)


func _origin() -> Vector2:
    var point: Array = payload.get("origin", [0, 0])
    return Vector2(float(point[0]), float(point[1]))


func _angle(point: Vector2) -> float:
    return fposmod(rad_to_deg(atan2(-point.y, point.x)), 360)


func _distance_angle(id: String) -> Dictionary:
    for marker in payload.get("markers", []):
        if marker.id == id:
            var delta := Vector2(float(marker.point[0]), float(marker.point[1])) - _origin()
            return {"name": marker.name, "distance": delta.length(), "bearing": _angle(delta)}
    return {}


func _description(id: String) -> String:
    var value := _distance_angle(id)
    if value.is_empty():
        return ""
    if float(value.distance) <= 0.001:
        return String(value.name) + "\n与记录点重合，方位未定义。"
    var relative := fposmod(float(value.bearing) - heading + 180, 360) - 180
    return (
        "%s\n距离 %.1f · 方位 %.1f° · 相对角 %.1f°" % [value.name, value.distance, value.bearing, relative]
    )


func _hit(point: Vector2) -> String:
    var best := ""
    var minimum := 18.0
    for id in positions:
        var distance: float = positions[id].distance_to(point)
        if distance < minimum:
            minimum = distance
            best = String(id)
    return best


func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            rotating = event.pressed and event.shift_pressed
            if event.pressed:
                grab_focus()
                selected = _hit(event.position)
                tooltip_text = _description(selected)
            accept_event()
        elif (
            event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]
        ):
            radius = clampf(
                radius * (0.8 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.25), 1, 100000
            )
            accept_event()
        queue_redraw()
    elif event is InputEventMouseMotion:
        if rotating:
            heading = _angle(event.position - _center())
        hovered = _hit(event.position)
        tooltip_text = _description(hovered)
        queue_redraw()
    elif event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_LEFT:
                heading = fposmod(heading + 5, 360)
            KEY_RIGHT:
                heading = fposmod(heading - 5, 360)
            KEY_UP:
                _select_forward()
            KEY_HOME:
                heading = float(payload.get("heading", 0))
                radius = maxf(1, float(payload.get("radius", 1)))
            _:
                return
        accept_event()
        queue_redraw()


func _select_forward() -> void:
    var minimum := INF
    for marker in payload.get("markers", []):
        var value := _distance_angle(String(marker.id))
        var difference := absf(fposmod(float(value.bearing) - heading + 180, 360) - 180)
        if difference < minimum:
            minimum = difference
            selected = String(marker.id)
    tooltip_text = _description(selected)


func _fan(center: Vector2, length: float) -> void:
    var half := float(payload.get("fov", 90)) * 0.5
    var polygon := PackedVector2Array([center])
    for i in 25:
        var angle := deg_to_rad(-heading - half + float(i) * half * 2 / 24)
        polygon.append(center + Vector2(cos(angle), sin(angle)) * length)
    draw_colored_polygon(polygon, Color(0.4, 0.56, 0.44, 0.18))
    var forward := Vector2(cos(deg_to_rad(heading)), -sin(deg_to_rad(heading)))
    draw_line(center, center + forward * length, Color("d0b785"), 2, true)


func _rings(center: Vector2, length: float, font: Font) -> void:
    for i in range(1, 5):
        var amount := float(i) / 4
        draw_arc(center, length * amount, 0, TAU, 72, Color("354c45"), 1, true)
        draw_string(
            font,
            center + Vector2(length * amount, 13),
            "%.0f" % (radius * amount),
            HORIZONTAL_ALIGNMENT_LEFT,
            60,
            11,
            Color("9aaca0")
        )
    var names := ["东", "北", "西", "南"]
    for i in 4:
        var angle := float(i) * PI * 0.5
        var point := center + Vector2(cos(angle), -sin(angle)) * (length + 17)
        draw_string(
            font,
            point + Vector2(-7, 5),
            names[i],
            HORIZONTAL_ALIGNMENT_LEFT,
            30,
            14,
            Color("d7c291")
        )


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("112526"))
    var center := _center()
    var length := _scale_radius()
    var font := get_theme_default_font()
    _rings(center, length, font)
    _fan(center, length)
    positions.clear()
    for marker in payload.get("markers", []):
        var delta := Vector2(float(marker.point[0]), float(marker.point[1])) - _origin()
        var distance := delta.length()
        var scale := minf(1, distance / radius)
        var point := center + delta.normalized() * length * scale
        positions[marker.id] = point
        var active: bool = marker.id == selected or marker.id == hovered
        var color := Color("dec18b") if active else Color("80aaa0")
        if distance > radius:
            draw_arc(point, 5, 0, TAU, 12, color, 1.5, true)
        else:
            draw_circle(point, 7 if active else 4, color)
        if active:
            draw_line(center, point, color, 1.2, true)
            draw_string(
                font,
                point + Vector2(9, -7),
                String(marker.name),
                HORIZONTAL_ALIGNMENT_LEFT,
                200,
                14,
                Color("eadcc6")
            )
    draw_circle(center, 4, Color("eadcc6"))
    draw_string(
        font,
        Vector2(10, 19),
        "图面参考朝向 %.0f° · 半径 %.0f" % [heading, radius],
        HORIZONTAL_ALIGNMENT_LEFT,
        size.x - 20,
        13,
        Color("d6bf90")
    )
    draw_string(
        font,
        Vector2(10, size.y - 11),
        "Shift拖动旋转 · 滚轮调半径 · ↑选择朝向地标 · Home复位；换页清空预览",
        HORIZONTAL_ALIGNMENT_LEFT,
        size.x - 20,
        12,
        Color("a3b3aa")
    )
    if has_focus():
        draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), Color("cfb484"), false, 2)
