extends Control
var rows: Array = []
var budget := 1.0
var selected := 0
var zoom := 1.0
var maximum := 1.0
var hovered := -1
const LEFT := 125.0
const ROW_HEIGHT := 35.0
const TOP := 40.0


func _init() -> void:
    custom_minimum_size = Vector2(480, 250)
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    focus_mode = Control.FOCUS_ALL
    clip_contents = true


func configure(data: Dictionary) -> void:
    rows = data.get("rows", []).duplicate(true)
    budget = maxf(1, float(data.get("budget", 1)))
    maximum = budget
    for row in rows:
        maximum = maxf(maximum, float(row.get("离开秒", 0)))
    selected = clampi(selected, 0, maxi(0, rows.size() - 1))
    custom_minimum_size.y = maxf(250, TOP + rows.size() * ROW_HEIGHT + 70)
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


func _x(seconds: float) -> float:
    var width := maxf(1, size.x - LEFT - 20)
    return LEFT + seconds / maximum * width * zoom


func _row_at(point: Vector2) -> int:
    if point.y < TOP or point.x < LEFT:
        return -1
    var index := int(floor((point.y - TOP) / ROW_HEIGHT))
    return index if index >= 0 and index < rows.size() else -1


func _description(index: int) -> String:
    if index < 0 or index >= rows.size():
        return ""
    var row: Dictionary = rows[index]
    return (
        "%s → %s\n到达 %.1f 秒 · 离开 %.1f 秒\n%s"
        % [
            row.get("起点", ""),
            row.get("终点", ""),
            row.get("到达秒", 0),
            row.get("离开秒", 0),
            row.get("路径", "")
        ]
    )


func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        hovered = _row_at(event.position)
        tooltip_text = _description(hovered)
        queue_redraw()
    elif event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT:
            var index := _row_at(event.position)
            if index >= 0:
                selected = index
                grab_focus()
                tooltip_text = _description(selected)
                accept_event()
        elif event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
            zoom = clampf(
                zoom * (1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2), 0.5, 4
            )
            accept_event()
        queue_redraw()
    elif event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_DOWN, KEY_RIGHT:
                selected = mini(rows.size() - 1, selected + 1)
            KEY_UP, KEY_LEFT:
                selected = maxi(0, selected - 1)
            KEY_HOME:
                zoom = 1.0
                selected = 0
            _:
                return
        tooltip_text = _description(selected)
        accept_event()
        queue_redraw()


func _bar(start: float, finish: float, y: float, color: Color) -> void:
    var a := clampf(_x(start), LEFT, size.x - 10)
    var b := clampf(_x(finish), LEFT, size.x - 10)
    if b > a:
        draw_rect(Rect2(a, y, b - a, ROW_HEIGHT - 10), color)


func _draw_grid(font: Font) -> void:
    var steps := 5
    for i in range(steps + 1):
        var seconds := maximum * float(i) / steps
        var x := _x(seconds)
        if x > size.x - 10:
            continue
        draw_line(Vector2(x, 28), Vector2(x, size.y - 46), Color("314442"), 1)
        draw_string(
            font,
            Vector2(x + 3, 20),
            "%.0fs" % seconds,
            HORIZONTAL_ALIGNMENT_LEFT,
            70,
            12,
            Color("a3b3aa")
        )
    var boundary := _x(budget)
    if boundary <= size.x - 10:
        var y := 28.0
        while y < size.y - 45:
            draw_line(Vector2(boundary, y), Vector2(boundary, y + 5), Color("d89575"), 2)
            y += 10
        draw_string(
            font,
            Vector2(maxf(LEFT, boundary - 45), 36),
            "预算",
            HORIZONTAL_ALIGNMENT_LEFT,
            70,
            12,
            Color("d89575")
        )


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("112324"))
    var font := get_theme_default_font()
    _draw_grid(font)
    var previous := 0.0
    for i in rows.size():
        var row: Dictionary = rows[i]
        var y := TOP + i * ROW_HEIGHT
        if i == selected or i == hovered:
            draw_rect(Rect2(2, y - 2, size.x - 4, ROW_HEIGHT - 1), Color(0.3, 0.34, 0.29, 0.55))
        draw_string(
            font,
            Vector2(8, y + 17),
            str(i + 1) + " " + String(row.get("终点", "")),
            HORIZONTAL_ALIGNMENT_LEFT,
            LEFT - 14,
            13,
            Color("eadcc6")
        )
        var arrival := float(row.get("到达秒", previous))
        var departure := float(row.get("离开秒", arrival))
        _bar(previous, arrival, y, Color("508f8e"))
        _bar(arrival, departure, y, Color("c6a86e"))
        if departure > budget:
            _bar(maxf(budget, previous), departure, y + 13, Color("9f5a4a"))
        previous = departure
    var legend_y := size.y - 30
    draw_rect(Rect2(10, legend_y - 9, 12, 12), Color("508f8e"))
    draw_string(
        font,
        Vector2(28, legend_y + 2),
        "规则距离估算",
        HORIZONTAL_ALIGNMENT_LEFT,
        150,
        12,
        Color("a3b3aa")
    )
    draw_rect(Rect2(180, legend_y - 9, 12, 12), Color("c6a86e"))
    draw_string(
        font,
        Vector2(198, legend_y + 2),
        "个人停留假设",
        HORIZONTAL_ALIGNMENT_LEFT,
        150,
        12,
        Color("a3b3aa")
    )
    draw_string(
        font,
        Vector2(10, size.y - 8),
        "方向键选择站点 · 滚轮缩放时间轴 · Home复位",
        HORIZONTAL_ALIGNMENT_LEFT,
        size.x - 20,
        12,
        Color("a3b3aa")
    )
    if has_focus():
        draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), Color("cfb484"), false, 2)
