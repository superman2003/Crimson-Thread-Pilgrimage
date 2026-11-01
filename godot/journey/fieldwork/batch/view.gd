extends Control
var points: Array = []
var selected := -1
var hovered := -1
var show_infeasible := true
var zoom := 1.0
var pan := Vector2.ZERO
var dragging := false
var previous := Vector2.ZERO
var maximum := Vector2.ONE
var budget := 0.0
var x_label := "资金成本"
var y_label := "个人优先级"
var legend := "绿点可行 · 金圈策略建议 · I切换不可行点 · 滚轮缩放 · Shift拖动"
const LEFT := 60.0
const BOTTOM := 45.0


func _init() -> void:
    custom_minimum_size = Vector2(480, 350)
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    focus_mode = Control.FOCUS_ALL
    clip_contents = true


func configure(data: Dictionary) -> void:
    points = data.get("points", []).duplicate(true)
    budget = float(data.get("budget", 0))
    x_label = String(data.get("x_label", "资金成本"))
    y_label = String(data.get("y_label", "个人优先级"))
    legend = String(data.get("legend", legend))
    selected = -1
    hovered = -1
    maximum = Vector2.ONE
    for i in points.size():
        maximum.x = maxf(maximum.x, float(points[i].x))
        maximum.y = maxf(maximum.y, float(points[i].y))
        if points[i].get("selected", false):
            selected = i
    zoom = 1.0
    pan = Vector2.ZERO
    queue_redraw()


func _ready() -> void:
    resized.connect(queue_redraw)
    mouse_exited.connect(
        func():
            hovered = -1
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


func _area() -> Rect2:
    return Rect2(LEFT, 25, maxf(1, size.x - LEFT - 20), maxf(1, size.y - BOTTOM - 25))


func _position(index: int) -> Vector2:
    var area := _area()
    var point: Dictionary = points[index]
    var fraction := Vector2(float(point.x) / maximum.x, 1 - float(point.y) / maximum.y)
    return area.position + (fraction - Vector2(0.5, 0.5)) * area.size * zoom + area.size * 0.5 + pan


func _hit(point: Vector2) -> int:
    var best := -1
    var minimum := 12.0
    for i in points.size():
        if not points[i].feasible and not show_infeasible:
            continue
        var distance := _position(i).distance_to(point)
        if distance < minimum or (is_equal_approx(distance, minimum) and points[i].feasible):
            minimum = distance
            best = i
    return best


func _description(index: int) -> String:
    if index < 0 or index >= points.size():
        return ""
    var point: Dictionary = points[index]
    return (
        "%s\n%s %.1f · %s %.1f\n%s"
        % [
            point.get("name", ""),
            x_label,
            point.x,
            y_label,
            point.y,
            "资源约束允许" if point.feasible else point.get("reason", "约束未满足")
        ]
    )


func _clamp_pan() -> void:
    var area := _area()
    var limit := area.size * (zoom - 1) * 0.5
    pan.x = clampf(pan.x, -limit.x, limit.x)
    pan.y = clampf(pan.y, -limit.y, limit.y)


func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        if dragging:
            pan += event.position - previous
            previous = event.position
            _clamp_pan()
        hovered = _hit(event.position)
        tooltip_text = _description(hovered)
        queue_redraw()
    elif event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            dragging = event.pressed and event.shift_pressed
            previous = event.position
            if event.pressed:
                selected = _hit(event.position)
                grab_focus()
                tooltip_text = _description(selected)
            accept_event()
        elif (
            event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]
        ):
            zoom = clampf(
                zoom * (1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2), 1, 5
            )
            _clamp_pan()
            accept_event()
        queue_redraw()
    elif event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_I:
                show_infeasible = not show_infeasible
            KEY_HOME:
                zoom = 1
                pan = Vector2.ZERO
            KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN:
                _move_selection(event.keycode)
            _:
                return
        tooltip_text = _description(selected)
        accept_event()
        queue_redraw()


func _move_selection(key: int) -> void:
    var direction := Vector2.LEFT if key == KEY_LEFT else Vector2.RIGHT
    if key == KEY_UP:
        direction = Vector2.UP
    elif key == KEY_DOWN:
        direction = Vector2.DOWN
    var origin := _position(selected) if selected >= 0 else _area().get_center()
    var best := -1
    var score := INF
    for i in points.size():
        if i == selected or (not show_infeasible and not points[i].feasible):
            continue
        var delta := _position(i) - origin
        var advance := delta.dot(direction)
        if advance <= 0.1:
            continue
        var candidate := advance + absf(delta.cross(direction)) * 2
        if candidate < score:
            score = candidate
            best = i
    if best >= 0:
        selected = best
        var point := _position(selected)
        if not _area().has_point(point):
            pan += _area().get_center() - point
            _clamp_pan()


func _grid(font: Font) -> void:
    var area := _area()
    for i in 6:
        var x := area.position.x + area.size.x * float(i) / 5
        var y := area.end.y - area.size.y * float(i) / 5
        draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), Color("293e39"), 1)
        draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color("293e39"), 1)
        if is_equal_approx(zoom, 1):
            draw_string(
                font,
                Vector2(x - 12, area.end.y + 18),
                "%.0f" % (maximum.x * float(i) / 5),
                HORIZONTAL_ALIGNMENT_LEFT,
                70,
                11,
                Color("a3b3aa")
            )
            draw_string(
                font,
                Vector2(4, y + 4),
                "%.0f" % (maximum.y * float(i) / 5),
                HORIZONTAL_ALIGNMENT_LEFT,
                50,
                11,
                Color("a3b3aa")
            )
    draw_rect(area, Color("6a7866"), false, 1)
    var budget_x := (
        area.position.x
        + (budget / maximum.x - 0.5) * area.size.x * zoom
        + area.size.x * 0.5
        + pan.x
    )
    if budget >= 0 and budget_x >= area.position.x and budget_x <= area.end.x:
        draw_line(
            Vector2(budget_x, area.position.y), Vector2(budget_x, area.end.y), Color("b19b6a"), 1.5
        )
        draw_string(
            font,
            Vector2(budget_x + 3, area.position.y + 14),
            "可用资金",
            HORIZONTAL_ALIGNMENT_LEFT,
            100,
            11,
            Color("bca575")
        )


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("112324"))
    var font := get_theme_default_font()
    _grid(font)
    for i in points.size():
        var point: Dictionary = points[i]
        if not show_infeasible and not point.feasible:
            continue
        var at := _position(i)
        if not _area().has_point(at):
            continue
        var color := Color("73ad9a") if point.feasible else Color("80685d")
        var active: bool = i == selected or i == hovered
        draw_circle(at, 6 if active else 3, color)
        if point.get("selected", false):
            draw_arc(at, 9, 0, TAU, 18, Color("e0c28b"), 2, true)
        if active:
            draw_string(
                font,
                at + Vector2(9, -6),
                String(point.get("name", "")),
                HORIZONTAL_ALIGNMENT_LEFT,
                240,
                12,
                Color("eadcc6")
            )
    draw_string(
        font,
        Vector2(LEFT, 17),
        "纵轴：" + y_label + " · 横轴：" + x_label,
        HORIZONTAL_ALIGNMENT_LEFT,
        size.x - LEFT - 10,
        12,
        Color("d0b582")
    )
    draw_string(
        font,
        Vector2(10, size.y - 9),
        legend,
        HORIZONTAL_ALIGNMENT_LEFT,
        size.x - 20,
        12,
        Color("a3b3aa")
    )
    if has_focus():
        draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), Color("cfb484"), false, 2)
