extends Control
var samples: Array = []
var selected := 0
var hovered := -1
var show_assumptions := true
var minimum := 0.0
var maximum := 1.0
const LEFT := 70.0
const TOP := 35.0
const BOTTOM := 42.0


func _init() -> void:
    custom_minimum_size = Vector2(480, 330)
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    focus_mode = Control.FOCUS_ALL
    clip_contents = true


func configure(data: Dictionary) -> void:
    samples = data.get("samples", []).duplicate(true)
    selected = clampi(selected, 0, maxi(0, samples.size() - 1))
    hovered = -1
    _bounds()
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


func _bounds() -> void:
    minimum = 0
    maximum = 1
    for row in samples:
        maximum = maxf(maximum, float(row.catalog))
        if show_assumptions:
            maximum = maxf(maximum, float(row.assumed))
    maximum *= 1.1


func _area() -> Rect2:
    return Rect2(LEFT, TOP, maxf(1, size.x - LEFT - 20), maxf(1, size.y - TOP - BOTTOM))


func _point(index: int, assumed: bool = false) -> Vector2:
    var area := _area()
    var value := float(samples[index].assumed if assumed else samples[index].catalog)
    return Vector2(
        area.position.x + area.size.x * float(index) / maxi(1, samples.size() - 1),
        area.end.y - area.size.y * (value - minimum) / (maximum - minimum)
    )


func _hit(point: Vector2) -> int:
    if samples.is_empty() or not _area().grow(10).has_point(point):
        return -1
    return clampi(
        int(round((point.x - _area().position.x) / _area().size.x * maxi(1, samples.size() - 1))),
        0,
        samples.size() - 1
    )


func _description(index: int) -> String:
    if index < 0 or index >= samples.size():
        return ""
    var row: Dictionary = samples[index]
    var stamp := Time.get_datetime_string_from_unix_time(int(row.time)).replace("T", " ")
    return (
        "%s\n记录时间 %s UTC\n目录成本 %.0f · 个人假设 %.1f\n%s"
        % [row.name, stamp, row.catalog, row.assumed, "个人已修改单价假设" if row.altered else "个人单价与记录目录相同"]
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
                selected = mini(samples.size() - 1, selected + 1)
            KEY_HOME:
                selected = 0
            KEY_END:
                selected = maxi(0, samples.size() - 1)
            KEY_A:
                show_assumptions = not show_assumptions
                _bounds()
            _:
                return
        tooltip_text = _description(selected)
        accept_event()
        queue_redraw()


func _series(assumed: bool, color: Color) -> void:
    var line := PackedVector2Array()
    for i in samples.size():
        line.append(_point(i, assumed))
    if line.size() > 1:
        draw_polyline(line, color, 2, true)
    for i in samples.size():
        var active: bool = i == selected or i == hovered
        draw_circle(_point(i, assumed), 5 if active else 2.5, color)


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("122525"))
    var font := get_theme_default_font()
    var area := _area()
    for i in 6:
        var value := lerpf(minimum, maximum, float(i) / 5)
        var y := area.end.y - area.size.y * float(i) / 5
        draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color("30463b"), 1)
        draw_string(
            font,
            Vector2(3, y + 4),
            "%.1f" % value,
            HORIZONTAL_ALIGNMENT_LEFT,
            LEFT - 6,
            11,
            Color("a3b3aa")
        )
    draw_rect(area, Color("61755d"), false, 1)
    _series(false, Color("7fb09a"))
    if show_assumptions:
        _series(true, Color("c1a16e"))
    for index in [selected, hovered]:
        if index >= 0 and index < samples.size():
            var x := _point(index).x
            draw_line(
                Vector2(x, area.position.y), Vector2(x, area.end.y), Color(0.8, 0.7, 0.5, 0.3), 1
            )
    if samples.is_empty():
        draw_string(
            font,
            area.position + Vector2(20, 40),
            "保存记录后显示同一方案的目录成本与个人假设。",
            HORIZONTAL_ALIGNMENT_LEFT,
            area.size.x - 40,
            15,
            Color("c7b58b")
        )
    draw_string(
        font,
        Vector2(LEFT, 20),
        "绿色目录成本 · 金色个人假设 · 横轴为观察顺序",
        HORIZONTAL_ALIGNMENT_LEFT,
        size.x - LEFT - 10,
        12,
        Color("d0b584")
    )
    draw_string(
        font,
        Vector2(10, size.y - 10),
        "A切换个人假设线 · 方向键选择记录；这不是实时市场或价格预测。",
        HORIZONTAL_ALIGNMENT_LEFT,
        size.x - 20,
        12,
        Color("a3b3aa")
    )
    if has_focus():
        draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), Color("cfb484"), false, 2)
