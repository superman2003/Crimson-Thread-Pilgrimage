extends Control
var points: Array = []
var selected := 0
var hovered := -1
var gini := 0.0
var show_gaps := true
const LEFT := 55.0
const TOP := 35.0
const BOTTOM := 45.0


func _init() -> void:
    custom_minimum_size = Vector2(480, 350)
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    focus_mode = Control.FOCUS_ALL
    clip_contents = true


func configure(data: Dictionary) -> void:
    points = data.get("points", []).duplicate(true)
    gini = clampf(float(data.get("gini", 0)), 0, 1)
    selected = clampi(selected, 0, maxi(0, points.size() - 1))
    hovered = -1
    queue_redraw()


func _ready() -> void:
    resized.connect(queue_redraw)
    mouse_exited.connect(
        func():
            hovered = -1
            tooltip_text = ""
            queue_redraw()
    )
    focus_entered.connect(queue_redraw)
    focus_exited.connect(queue_redraw)


func _area() -> Rect2:
    return Rect2(LEFT, TOP, maxf(1, size.x - LEFT - 25), maxf(1, size.y - TOP - BOTTOM))


func _position(point: Dictionary) -> Vector2:
    var area := _area()
    return (
        area.position
        + Vector2(clampf(float(point.x), 0, 1), 1 - clampf(float(point.y), 0, 1)) * area.size
    )


func _hit(point: Vector2) -> int:
    var best := -1
    var distance := 15.0
    for i in points.size():
        var next := _position(points[i]).distance_to(point)
        if next < distance:
            distance = next
            best = i
    return best


func _description(index: int) -> String:
    if index < 0 or index >= points.size():
        return ""
    var point: Dictionary = points[index]
    return (
        "%s\n累计条目 %.1f%%\n累计个人等价 %.1f%%\n与均匀参考差 %.1f%%"
        % [
            point.get("name", ""),
            float(point.x) * 100,
            float(point.y) * 100,
            (float(point.x) - float(point.y)) * 100
        ]
    )


func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        hovered = _hit(event.position)
        tooltip_text = _description(hovered)
        queue_redraw()
    elif (
        event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
    ):
        var index := _hit(event.position)
        if index >= 0:
            selected = index
            tooltip_text = _description(selected)
        grab_focus()
        accept_event()
        queue_redraw()
    elif event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_LEFT, KEY_DOWN:
                selected = maxi(0, selected - 1)
            KEY_RIGHT, KEY_UP:
                selected = mini(points.size() - 1, selected + 1)
            KEY_HOME:
                selected = 0
            KEY_END:
                selected = maxi(0, points.size() - 1)
            KEY_G:
                show_gaps = not show_gaps
            _:
                return
        tooltip_text = _description(selected)
        accept_event()
        queue_redraw()


func _grid(font: Font) -> void:
    var area := _area()
    for i in 6:
        var portion := float(i) / 5
        var x := area.position.x + area.size.x * portion
        var y := area.end.y - area.size.y * portion
        draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), Color("30423b"), 1)
        draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color("30423b"), 1)
        draw_string(
            font,
            Vector2(x - 12, area.end.y + 19),
            "%.0f%%" % (portion * 100),
            HORIZONTAL_ALIGNMENT_LEFT,
            50,
            11,
            Color("a3b3aa")
        )
        draw_string(
            font,
            Vector2(4, y + 4),
            "%.0f%%" % (portion * 100),
            HORIZONTAL_ALIGNMENT_LEFT,
            45,
            11,
            Color("a3b3aa")
        )
    draw_line(
        Vector2(area.position.x, area.end.y),
        Vector2(area.end.x, area.position.y),
        Color("697e5a"),
        1.5,
        true
    )
    draw_rect(area, Color("6f7a61"), false, 1)


func _curve() -> void:
    if points.size() < 2:
        return
    var line := PackedVector2Array()
    for point in points:
        line.append(_position(point))
    var fill := PackedVector2Array([_position({"x": 0, "y": 0})])
    for point in points:
        fill.append(_position(point))
    fill.append(_position({"x": 1, "y": 1}))
    if fill.size() >= 3:
        draw_colored_polygon(fill, Color(0.45, 0.62, 0.48, 0.13))
    draw_polyline(line, Color("d3b785"), 2.5, true)
    for i in points.size():
        if i == selected or i == hovered:
            continue
        draw_circle(_position(points[i]), 2.5, Color("a99d70"))


func _focus_point(index: int, color: Color) -> void:
    if index < 0 or index >= points.size():
        return
    var point: Dictionary = points[index]
    var position := _position(point)
    draw_circle(position, 6, color)
    if show_gaps:
        var reference := _position({"x": point.x, "y": point.x})
        draw_line(position, reference, Color("aa7563"), 1.5, true)
        draw_arc(reference, 4, 0, TAU, 12, Color("a8b683"), 1.5, true)
    var area := _area()
    draw_line(position, Vector2(position.x, area.end.y), Color(0.8, 0.7, 0.5, 0.3), 1)
    draw_line(position, Vector2(area.position.x, position.y), Color(0.8, 0.7, 0.5, 0.3), 1)


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("122526"))
    var font := get_theme_default_font()
    _grid(font)
    _curve()
    _focus_point(selected, Color("ebcf95"))
    if hovered != selected:
        _focus_point(hovered, Color("a5c6b0"))
    draw_string(
        font,
        Vector2(LEFT, 20),
        "Gini %.3f · 按个人等价从小到大累计" % gini,
        HORIZONTAL_ALIGNMENT_LEFT,
        size.x - LEFT - 10,
        13,
        Color("d1b784")
    )
    if points.size() < 2:
        draw_string(
            font,
            _area().get_center(),
            "尚无持有物资样本",
            HORIZONTAL_ALIGNMENT_CENTER,
            250,
            16,
            Color("b7bdab")
        )
    draw_string(
        font,
        Vector2(10, size.y - 10),
        "横轴累计条目占比 · 纵轴累计个人等价占比 · 方向键查看 · G切换差距线",
        HORIZONTAL_ALIGNMENT_LEFT,
        size.x - 20,
        12,
        Color("a3b3aa")
    )
    if has_focus():
        draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), Color("cfb484"), false, 2)
