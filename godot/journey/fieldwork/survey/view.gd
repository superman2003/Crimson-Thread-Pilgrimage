extends Control
var data: Dictionary = {}
var zoom := 1.0
var pan := Vector2.ZERO
var hovered := -1
var selected := -1
var marks: Dictionary = {}
var dragging := false
var previous := Vector2.ZERO
const PADDING := 28.0


func _init() -> void:
    custom_minimum_size = Vector2(480, 380)
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    focus_mode = Control.FOCUS_ALL
    clip_contents = true


func configure(value: Dictionary) -> void:
    data = value.duplicate(true)
    zoom = 1.0
    pan = Vector2.ZERO
    marks.clear()
    hovered = -1
    selected = -1
    queue_redraw()


func _ready() -> void:
    resized.connect(queue_redraw)
    focus_entered.connect(queue_redraw)
    focus_exited.connect(
        func():
            dragging = false
            queue_redraw()
    )
    mouse_exited.connect(
        func():
            hovered = -1
            dragging = false
            tooltip_text = ""
            queue_redraw()
    )


func _cell_scale() -> float:
    if int(data.get("width", 0)) == 0 or int(data.get("height", 0)) == 0:
        return 1.0
    return (
        minf(
            maxf(1, size.x - PADDING * 2) / float(data.width),
            maxf(1, size.y - PADDING * 2 - 24) / float(data.height)
        )
        * zoom
    )


func _origin() -> Vector2:
    return (
        Vector2(size.x, size.y - 24) * 0.5
        - Vector2(float(data.get("width", 0)), float(data.get("height", 0))) * _cell_scale() * 0.5
        + pan
    )


func _rect(id: int) -> Rect2:
    var width := int(data.get("width", 1))
    return Rect2(
        _origin() + Vector2(id % width, id / width) * _cell_scale(), Vector2.ONE * _cell_scale()
    )


func _at(point: Vector2) -> int:
    if int(data.get("width", 0)) == 0:
        return -1
    var local := (point - _origin()) / _cell_scale()
    var x := int(floor(local.x))
    var y := int(floor(local.y))
    return (
        y * int(data.width) + x
        if x >= 0 and y >= 0 and x < int(data.width) and y < int(data.height)
        else -1
    )


func _description(id: int) -> String:
    if id < 0 or id >= data.get("cells", []).size():
        return ""
    var width := int(data.width)
    var amount := int(data.cells[id])
    return "网格列%d · 行%d\n覆盖设计矩形%d个\nShift点击临时标注；图面标注换页后清空。" % [id % width, id / width, amount]


func _clamp_pan() -> void:
    var limit := size * maxf(0.5, zoom - 0.5)
    pan.x = clampf(pan.x, -limit.x, limit.x)
    pan.y = clampf(pan.y, -limit.y, limit.y)


func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
            zoom = clampf(
                zoom * (1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2), 1, 6
            )
            _clamp_pan()
            accept_event()
            queue_redraw()
        elif event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                grab_focus()
                selected = _at(event.position)
                previous = event.position
                dragging = not event.shift_pressed
                if event.shift_pressed and selected >= 0:
                    if marks.has(selected):
                        marks.erase(selected)
                    elif marks.size() < 40:
                        marks[selected] = true
                tooltip_text = _description(selected)
            else:
                dragging = false
            accept_event()
            queue_redraw()
    elif event is InputEventMouseMotion:
        if dragging:
            pan += event.position - previous
            previous = event.position
            _clamp_pan()
        hovered = _at(event.position)
        tooltip_text = _description(hovered)
        queue_redraw()
    elif event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_HOME:
            zoom = 1
            pan = Vector2.ZERO
            marks.clear()
        elif event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
            _move(event.keycode)
        elif event.keycode == KEY_SPACE and selected >= 0:
            if marks.has(selected):
                marks.erase(selected)
            elif marks.size() < 40:
                marks[selected] = true
        else:
            return
        accept_event()
        queue_redraw()


func _move(key: int) -> void:
    if data.get("cells", []).is_empty():
        return
    if selected < 0:
        selected = 0
    var width := int(data.width)
    var x := selected % width
    var y := selected / width
    if key == KEY_LEFT:
        x = maxi(0, x - 1)
    elif key == KEY_RIGHT:
        x = mini(width - 1, x + 1)
    elif key == KEY_UP:
        y = maxi(0, y - 1)
    else:
        y = mini(int(data.height) - 1, y + 1)
    selected = y * width + x
    var rect := _rect(selected)
    var viewport := Rect2(Vector2(10, 10), size - Vector2(20, 50))
    if not viewport.encloses(rect):
        pan += viewport.get_center() - rect.get_center()
        _clamp_pan()
    tooltip_text = _description(selected)


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("102021"))
    var font := get_theme_default_font()
    for id in data.get("cells", []).size():
        var rect := _rect(id)
        if not rect.intersects(Rect2(Vector2.ZERO, size - Vector2(0, 25))):
            continue
        var value := int(data.cells[id])
        var color := Color("20312f") if value == 0 else Color("4b7e73")
        if value > 1:
            color = Color("b19b65").lightened(minf(0.3, float(value - 2) * 0.05))
        draw_rect(rect.grow(-minf(1, _cell_scale() * 0.08)), color)
        if marks.has(id):
            draw_circle(rect.get_center(), maxf(2, _cell_scale() * 0.18), Color("e5c78b"))
        if id == selected or id == hovered:
            draw_rect(rect.grow(-1), Color("f2d59d"), false, 2)
    draw_string(
        font,
        Vector2(10, size.y - 10),
        "已知矩形采样 · 深色为留白 · Shift点击/空格临时标注%d格" % marks.size(),
        HORIZONTAL_ALIGNMENT_LEFT,
        size.x - 20,
        12,
        Color("c8c3ae")
    )
    if has_focus():
        draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), Color("cfb484"), false, 2)
