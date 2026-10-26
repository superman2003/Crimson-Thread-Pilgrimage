extends Control
var matches: Array = []
var tolerance := 150.0
var selected := 0
var hovered := -1
const LEFT := 55.0
const TOP := 30.0
const BOTTOM := 38.0


func _init() -> void:
    custom_minimum_size = Vector2(480, 300)
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    focus_mode = Control.FOCUS_ALL
    clip_contents = true


func configure(data: Dictionary) -> void:
    matches = data.get("matches", []).duplicate(true)
    tolerance = maxf(1, float(data.get("tolerance", 150)))
    selected = clampi(selected, 0, maxi(0, matches.size() - 1))
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


func _position(index: int) -> Vector2:
    var row: Dictionary = matches[index]
    var fraction := float(index) / maxi(1, matches.size() - 1)
    var ratio := clampf(float(row.error_ms) / tolerance, -1, 1)
    return Vector2(
        LEFT + fraction * maxf(1, size.x - LEFT - 20),
        TOP + (1 - ratio) * 0.5 * maxf(1, size.y - TOP - BOTTOM)
    )


func _hit(point: Vector2) -> int:
    var result := -1
    var best := 13.0
    for i in matches.size():
        var distance := _position(i).distance_to(point)
        if distance < best:
            best = distance
            result = i
    return result


func _description(index: int) -> String:
    if index < 0 or index >= matches.size():
        return ""
    var row: Dictionary = matches[index]
    return (
        "目标%d · 输入%d\n目标%.3f秒 · 输入%.3f秒\n偏差%.1f毫秒"
        % [int(row.target) + 1, int(row.tap) + 1, row.expected, row.time, row.error_ms]
    )


func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        hovered = _hit(event.position)
        tooltip_text = _description(hovered)
        queue_redraw()
    elif (
        event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
    ):
        var found := _hit(event.position)
        if found >= 0:
            selected = found
            tooltip_text = _description(selected)
        grab_focus()
        accept_event()
        queue_redraw()
    elif event is InputEventKey and event.pressed and not event.echo:
        if event.keycode in [KEY_LEFT, KEY_DOWN]:
            selected = maxi(0, selected - 1)
        elif event.keycode in [KEY_RIGHT, KEY_UP]:
            selected = mini(matches.size() - 1, selected + 1)
        elif event.keycode == KEY_HOME:
            selected = 0
        else:
            return
        tooltip_text = _description(selected)
        accept_event()
        queue_redraw()


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("112526"))
    var font := get_theme_default_font()
    var height := maxf(1, size.y - TOP - BOTTOM)
    for i in 5:
        var y := TOP + height * float(i) / 4
        var value := tolerance * (1 - float(i) / 2)
        draw_line(
            Vector2(LEFT, y),
            Vector2(size.x - 20, y),
            Color("405443") if i == 2 else Color("2b4038"),
            1
        )
        draw_string(
            font,
            Vector2(2, y + 4),
            "%.0f" % value,
            HORIZONTAL_ALIGNMENT_LEFT,
            50,
            11,
            Color("a3b3aa")
        )
    var line := PackedVector2Array()
    for i in matches.size():
        var position := _position(i)
        line.append(position)
        draw_circle(
            position, 3, Color("d1b47b") if float(matches[i].error_ms) >= 0 else Color("73aea2")
        )
    if line.size() > 1:
        draw_polyline(line, Color("879f7e"), 1.3, true)
    for index in [selected, hovered]:
        if index >= 0 and index < matches.size():
            draw_circle(_position(index), 6, Color("e3cb95"))
    draw_string(
        font,
        Vector2(LEFT, 19),
        "纵轴毫秒：正值晚、负值早 · 横轴匹配序号",
        HORIZONTAL_ALIGNMENT_LEFT,
        size.x - LEFT - 10,
        12,
        Color("d3b983")
    )
    draw_string(
        font,
        Vector2(10, size.y - 10),
        "只显示容差内已匹配击拍；漏拍和多余击拍另列统计。",
        HORIZONTAL_ALIGNMENT_LEFT,
        size.x - 20,
        12,
        Color("a3b3aa")
    )
    if matches.is_empty():
        draw_string(
            font,
            Vector2(LEFT + 20, size.y * 0.5),
            "完成练习后显示匹配偏差。",
            HORIZONTAL_ALIGNMENT_LEFT,
            size.x - LEFT - 40,
            16,
            Color("c3baa0")
        )
    if has_focus():
        draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), Color("cfb484"), false, 2)
