extends Control
var samples: Array = []
var origin := Vector2.ZERO
var radius := 1.0
var zoom := 1.0
var pan := Vector2.ZERO
var selected := 0
var hovered := -1
var dragging := false
var previous := Vector2.ZERO
const PADDING := 30.0


func _init() -> void:
    custom_minimum_size = Vector2(480, 360)
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    focus_mode = Control.FOCUS_ALL
    clip_contents = true


func configure(data: Dictionary) -> void:
    samples = data.get("samples", []).duplicate(true)
    var value: Array = data.get("origin", [0, 0])
    origin = Vector2(float(value[0]), float(value[1]))
    radius = maxf(1, float(data.get("radius", 1)))
    selected = clampi(selected, 0, maxi(0, samples.size() - 1))
    hovered = -1
    zoom = 1
    pan = Vector2.ZERO
    queue_redraw()


func _ready() -> void:
    resized.connect(queue_redraw)
    mouse_exited.connect(
        func():
            dragging = false
            hovered = -1
            tooltip_text = ""
            queue_redraw()
    )
    focus_entered.connect(queue_redraw)
    focus_exited.connect(
        func():
            dragging = false
            queue_redraw()
    )


func _center() -> Vector2:
    return Vector2(size.x, size.y - 25) * 0.5 + pan


func _scale() -> float:
    return maxf(1, minf(size.x, size.y - 25) * 0.5 - PADDING) * zoom / radius


func _position(index: int) -> Vector2:
    var point: Array = samples[index].position
    return _center() + (Vector2(float(point[0]), float(point[1])) - origin) * _scale()


func _hit(point: Vector2) -> int:
    var best := -1
    var minimum := 12.0
    for i in samples.size():
        var distance := _position(i).distance_to(point)
        if distance < minimum:
            minimum = distance
            best = i
    return best


func _description(index: int) -> String:
    if index < 0 or index >= samples.size():
        return ""
    var row: Dictionary = samples[index]
    var speed := Vector2(float(row.velocity[0]), float(row.velocity[1])).length()
    return (
        "观察%d · 活动时间%.2f秒 · 分段%d\n位置%s\n观测速度%.1f · 能量%.1f · 生命%.1f\n%s"
        % [
            index + 1,
            row.time,
            int(row.segment) + 1,
            str(row.position),
            speed,
            row.energy,
            row.hp,
            "此采样点着地" if row.grounded else "此采样点离地"
        ]
    )


func _clamp_pan() -> void:
    pan.x = clampf(pan.x, -size.x * zoom, size.x * zoom)
    pan.y = clampf(pan.y, -size.y * zoom, size.y * zoom)


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
                var found := _hit(event.position)
                if found >= 0:
                    selected = found
                tooltip_text = _description(selected)
                grab_focus()
            accept_event()
        elif (
            event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]
        ):
            zoom = clampf(
                zoom * (1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2), 0.5, 12
            )
            _clamp_pan()
            accept_event()
        queue_redraw()
    elif event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_LEFT, KEY_UP:
                selected = maxi(0, selected - 1)
            KEY_RIGHT, KEY_DOWN:
                selected = mini(samples.size() - 1, selected + 1)
            KEY_HOME:
                zoom = 1
                pan = Vector2.ZERO
                selected = 0
            KEY_END:
                selected = maxi(0, samples.size() - 1)
            _:
                return
        tooltip_text = _description(selected)
        accept_event()
        queue_redraw()


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("122626"))
    var font := get_theme_default_font()
    var center := _center()
    draw_arc(center, radius * _scale(), 0, TAU, 96, Color("5f7157"), 1.5, true)
    draw_line(center - Vector2(8, 0), center + Vector2(8, 0), Color("b6a67c"), 1)
    draw_line(center - Vector2(0, 8), center + Vector2(0, 8), Color("b6a67c"), 1)
    for i in range(1, samples.size()):
        var a: Dictionary = samples[i - 1]
        var b: Dictionary = samples[i]
        if a.segment != b.segment:
            continue
        var color := Color("6eac9b") if b.grounded else Color("9eb878")
        if float(b.energy) < float(a.energy):
            color = Color("c3a371")
        draw_line(_position(i - 1), _position(i), color, 2, true)
    for index in [selected, hovered]:
        if index >= 0 and index < samples.size():
            var point := _position(index)
            draw_circle(point, 6, Color("e3c78b"))
            var velocity: Array = samples[index].velocity
            var vector := Vector2(float(velocity[0]), float(velocity[1]))
            if vector.length() > 0:
                draw_line(point, point + vector.normalized() * 25, Color("b9d1ac"), 2, true)
    if samples.is_empty():
        draw_string(
            font,
            center - Vector2(120, 0),
            "返回旅途完成观察后显示分段轨迹。",
            HORIZONTAL_ALIGNMENT_LEFT,
            300,
            15,
            Color("c6b991")
        )
    draw_string(
        font,
        Vector2(10, 20),
        "区间半径 %.0f · 样本%d · 只连同一活动分段" % [radius, samples.size()],
        HORIZONTAL_ALIGNMENT_LEFT,
        size.x - 20,
        12,
        Color("d0b581")
    )
    draw_string(
        font,
        Vector2(10, size.y - 10),
        "方向键查看样本 · 滚轮缩放 · Shift拖动 · Home复位",
        HORIZONTAL_ALIGNMENT_LEFT,
        size.x - 20,
        12,
        Color("a3b3aa")
    )
    if has_focus():
        draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), Color("cfb484"), false, 2)
