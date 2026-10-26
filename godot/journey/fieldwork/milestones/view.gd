extends Control
var points: Array = []
var enabled: Dictionary = {"能力": true, "装备": true, "物资": true, "任务": true, "结局": true}
var colors: Dictionary = {
    "能力": Color("c1ae73"),
    "装备": Color("7eae97"),
    "物资": Color("7e9bb5"),
    "任务": Color("b38679"),
    "结局": Color("b69bc2")
}
var selected := 0
var hovered := -1
var maximum := 1.0
const LEFT := 55.0
const TOP := 62.0
const BOTTOM := 40.0


func _init() -> void:
    custom_minimum_size = Vector2(480, 350)
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    focus_mode = Control.FOCUS_ALL
    clip_contents = true


func configure(data: Dictionary) -> void:
    points = data.get("points", []).duplicate(true)
    selected = clampi(selected, 0, maxi(0, points.size() - 1))
    hovered = -1
    _maximum()
    queue_redraw()


func _ready() -> void:
    var row := HBoxContainer.new()
    row.position = Vector2(8, 5)
    add_child(row)
    for kind in enabled:
        var key := String(kind)
        var toggle := CheckButton.new()
        toggle.text = key
        toggle.button_pressed = true
        toggle.add_theme_color_override("font_color", colors[key])
        toggle.toggled.connect(
            func(value: bool):
                enabled[key] = value
                _maximum()
                queue_redraw()
        )
        row.add_child(toggle)
    resized.connect(queue_redraw)
    mouse_exited.connect(
        func():
            hovered = -1
            tooltip_text = ""
            queue_redraw()
    )
    focus_entered.connect(queue_redraw)
    focus_exited.connect(queue_redraw)


func _maximum() -> void:
    maximum = 1
    for point in points:
        for kind in enabled:
            if enabled[kind]:
                maximum = maxf(maximum, float(point.get("counts", {}).get(kind, 0)))


func _area() -> Rect2:
    return Rect2(LEFT, TOP, maxf(1, size.x - LEFT - 20), maxf(1, size.y - TOP - BOTTOM))


func _position(index: int, kind: String) -> Vector2:
    var fraction := float(index) / maxi(1, points.size() - 1)
    var amount := float(points[index].get("counts", {}).get(kind, 0))
    var area := _area()
    return Vector2(
        area.position.x + area.size.x * fraction, area.end.y - area.size.y * amount / maximum
    )


func _index(point: Vector2) -> int:
    if points.is_empty() or not _area().grow(10).has_point(point):
        return -1
    return clampi(
        int(round((point.x - _area().position.x) / _area().size.x * maxi(1, points.size() - 1))),
        0,
        points.size() - 1
    )


func _description(index: int) -> String:
    if index < 0 or index >= points.size():
        return ""
    var point: Dictionary = points[index]
    var parts: Array[String] = [String(point.name)]
    for kind in enabled:
        parts.append(String(kind) + "：" + str(point.get("counts", {}).get(kind, 0)))
    parts.append("这是观察记录中包含的条目数，不是全游戏总量。")
    return "\n".join(parts)


func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        hovered = _index(event.position)
        tooltip_text = _description(hovered)
        queue_redraw()
    elif (
        event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
    ):
        var index := _index(event.position)
        if index >= 0:
            selected = index
            tooltip_text = _description(selected)
        grab_focus()
        accept_event()
        queue_redraw()
    elif event is InputEventKey and event.pressed and not event.echo:
        if event.keycode in [KEY_LEFT, KEY_DOWN]:
            selected = maxi(0, selected - 1)
        elif event.keycode in [KEY_RIGHT, KEY_UP]:
            selected = mini(points.size() - 1, selected + 1)
        elif event.keycode == KEY_HOME:
            selected = 0
        elif event.keycode == KEY_END:
            selected = maxi(0, points.size() - 1)
        else:
            return
        tooltip_text = _description(selected)
        accept_event()
        queue_redraw()


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("122626"))
    var font := get_theme_default_font()
    var area := _area()
    for i in 5:
        var value := maximum * float(i) / 4
        var y := area.end.y - area.size.y * float(i) / 4
        draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color("33483f"), 1)
        draw_string(
            font,
            Vector2(4, y + 4),
            "%.0f" % value,
            HORIZONTAL_ALIGNMENT_LEFT,
            45,
            11,
            Color("a3b3aa")
        )
    for kind in enabled:
        if not enabled[kind]:
            continue
        var line := PackedVector2Array()
        for i in points.size():
            line.append(_position(i, kind))
        if line.size() > 1:
            draw_polyline(line, colors[kind], 2, true)
        for index in [selected, hovered]:
            if index >= 0 and index < points.size():
                draw_circle(_position(index, kind), 5, colors[kind])
    draw_rect(area, Color("63765d"), false, 1)
    if points.is_empty():
        draw_string(
            font,
            area.position + Vector2(20, 40),
            "保存观察后显示个人记录序列。",
            HORIZONTAL_ALIGNMENT_LEFT,
            area.size.x - 40,
            16,
            Color("c8b890")
        )
    draw_string(
        font,
        Vector2(LEFT, TOP - 10),
        "横轴：观察顺序；记录时间另见表格",
        HORIZONTAL_ALIGNMENT_LEFT,
        size.x - LEFT - 10,
        12,
        Color("d0b580")
    )
    draw_string(
        font,
        Vector2(10, size.y - 10),
        "顶部选择类型 · 方向键逐份查看 · 不表示实际取得时间或全游戏完成率",
        HORIZONTAL_ALIGNMENT_LEFT,
        size.x - 20,
        12,
        Color("a3b3aa")
    )
    if has_focus():
        draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), Color("cfb484"), false, 2)
