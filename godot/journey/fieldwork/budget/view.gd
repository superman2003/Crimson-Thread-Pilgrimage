extends Control
var rows: Array = []
var initial := 0.0
var reserve := 0.0
var minimum := 0.0
var maximum := 1.0
var selected := 0
var hovered := -1
const LEFT := 65.0
const TOP := 30.0
const BOTTOM := 45.0


func _init() -> void:
    custom_minimum_size = Vector2(480, 350)
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    focus_mode = Control.FOCUS_ALL
    clip_contents = true


func configure(data: Dictionary) -> void:
    rows = data.get("rows", []).duplicate(true)
    initial = float(data.get("initial", 0))
    reserve = float(data.get("reserve", 0))
    minimum = minf(0, initial)
    maximum = maxf(1, maxf(initial, reserve))
    for row in rows:
        minimum = minf(minimum, float(row.get("期末", 0)))
        maximum = maxf(maximum, float(row.get("期末", 0)))
    var margin := maxf(1, (maximum - minimum) * 0.1)
    maximum += margin
    minimum -= margin
    selected = clampi(selected, 0, rows.size())
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
    return Rect2(LEFT, TOP, maxf(1, size.x - LEFT - 20), maxf(1, size.y - TOP - BOTTOM))


func _x(index: int) -> float:
    return _area().position.x + _area().size.x * float(index) / maxi(1, rows.size())


func _y(value: float) -> float:
    return _area().end.y - (value - minimum) / maxf(1, maximum - minimum) * _area().size.y


func _value(index: int) -> float:
    return initial if index <= 0 else float(rows[mini(index - 1, rows.size() - 1)]["期末"])


func _index(point: Vector2) -> int:
    if not _area().grow(15).has_point(point):
        return -1
    var ratio := (point.x - _area().position.x) / _area().size.x
    return clampi(int(round(ratio * rows.size())), 0, rows.size())


func _description(index: int) -> String:
    if index < 0:
        return ""
    if index == 0:
        return "记录起点资金：%.1f\n个人储备线：%.1f" % [initial, reserve]
    var row: Dictionary = rows[index - 1]
    return (
        "第%d段 · %s\n假设收入 %.1f · 计划开销 %.1f\n期末 %.1f · 储备差 %.1f\n%s"
        % [
            index,
            row.get("计划目标", ""),
            row.get("假设收入", 0),
            row.get("计划总开销", 0),
            row.get("期末", 0),
            row.get("储备差", 0),
            row.get("材料缺口", "")
        ]
    )


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
        match event.keycode:
            KEY_LEFT, KEY_UP:
                selected = maxi(0, selected - 1)
            KEY_RIGHT, KEY_DOWN:
                selected = mini(rows.size(), selected + 1)
            KEY_HOME:
                selected = 0
            KEY_END:
                selected = rows.size()
            _:
                return
        tooltip_text = _description(selected)
        accept_event()
        queue_redraw()


func _grid(font: Font) -> void:
    var area := _area()
    for i in 6:
        var value := lerpf(minimum, maximum, float(i) / 5)
        var y := _y(value)
        draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color("30443c"), 1)
        draw_string(
            font,
            Vector2(2, y + 4),
            "%.0f" % value,
            HORIZONTAL_ALIGNMENT_LEFT,
            LEFT - 5,
            11,
            Color("a3b3aa")
        )
    for i in range(rows.size() + 1):
        var x := _x(i)
        draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), Color("243d37"), 1)
        draw_string(
            font,
            Vector2(x - 8, area.end.y + 18),
            str(i),
            HORIZONTAL_ALIGNMENT_LEFT,
            30,
            12,
            Color("a3b3aa")
        )
    draw_rect(area, Color("61755d"), false, 1)
    if minimum <= 0 and maximum >= 0:
        draw_line(Vector2(area.position.x, _y(0)), Vector2(area.end.x, _y(0)), Color("a67768"), 1.5)
    var y := _y(reserve)
    var x := area.position.x
    while x < area.end.x:
        draw_line(Vector2(x, y), Vector2(minf(x + 6, area.end.x), y), Color("d0b477"), 1.5)
        x += 11


func _line() -> void:
    var points := PackedVector2Array()
    for i in range(rows.size() + 1):
        points.append(Vector2(_x(i), _y(_value(i))))
    if points.size() > 1:
        draw_polyline(points, Color("83b29b"), 2.5, true)
    for i in range(rows.size() + 1):
        var value := _value(i)
        var color := Color("c07863") if value < reserve else Color("83b29b")
        draw_circle(Vector2(_x(i), _y(value)), 4, color)
    for index in [selected, hovered]:
        if index < 0 or index > rows.size():
            continue
        var point := Vector2(_x(index), _y(_value(index)))
        draw_circle(point, 7, Color("dfc28b"))
        draw_line(
            Vector2(point.x, _area().position.y),
            Vector2(point.x, _area().end.y),
            Color(0.8, 0.7, 0.5, 0.3),
            1
        )


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("112526"))
    var font := get_theme_default_font()
    _grid(font)
    _line()
    draw_string(
        font,
        Vector2(LEFT, 18),
        "假设余额路径 · 金色虚线为个人储备 · 红点低于储备",
        HORIZONTAL_ALIGNMENT_LEFT,
        size.x - LEFT - 10,
        12,
        Color("d0b582")
    )
    draw_string(
        font,
        Vector2(10, size.y - 10),
        "横轴为个人预算段，不是游戏日期；方向键或点击查看逐段计算",
        HORIZONTAL_ALIGNMENT_LEFT,
        size.x - 20,
        12,
        Color("a3b3aa")
    )
    if has_focus():
        draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), Color("cfb484"), false, 2)
