extends Control
var rows: Array = []
var offset := 0
var selected := 0
var hovered := -1
var total := 1.0
var start := 0.0
var span := 60.0
var budget := 1.0
const LEFT := 170.0
const TOP := 35.0
const ROW := 26.0
const FOOTER := 40.0


func _init() -> void:
    custom_minimum_size = Vector2(480, 400)
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    focus_mode = Control.FOCUS_ALL
    clip_contents = true


func configure(data: Dictionary) -> void:
    rows = data.get("rows", []).duplicate(true)
    total = 1.0
    for row in rows:
        total = maxf(total, float(row.get("结束秒", 0)))
    budget = maxf(1, float(data.get("budget", 1)))
    offset = 0
    selected = 0
    hovered = -1
    start = 0
    span = minf(60, total)
    queue_redraw()


func _ready() -> void:
    resized.connect(
        func():
            _clamp()
            queue_redraw()
    )
    mouse_exited.connect(
        func():
            hovered = -1
            tooltip_text = ""
            queue_redraw()
    )
    focus_entered.connect(queue_redraw)
    focus_exited.connect(queue_redraw)


func _count() -> int:
    return maxi(1, int(floor((size.y - TOP - FOOTER) / ROW)))


func _clamp() -> void:
    offset = clampi(offset, 0, maxi(0, rows.size() - _count()))
    span = clampf(span, 1, maxf(1, total))
    start = clampf(start, 0, maxf(0, total - span))
    selected = clampi(selected, 0, maxi(0, rows.size() - 1))


func _x(time: float) -> float:
    return LEFT + (time - start) / span * maxf(1, size.x - LEFT - 15)


func _at(point: Vector2) -> int:
    if point.y < TOP or point.y >= size.y - FOOTER:
        return -1
    var index := offset + int(floor((point.y - TOP) / ROW))
    return index if index < rows.size() else -1


func _description(index: int) -> String:
    if index < 0 or index >= rows.size():
        return ""
    var row: Dictionary = rows[index]
    return (
        "第%d轮 · 步骤%d · %s\n按键：%s\n时间 %.1f—%.1f秒\n记录费用 %.1f · 冷却重叠 %.1f秒\n%s"
        % [
            row["轮次"],
            row["步骤"],
            row["动作"],
            row["按键"],
            row["开始秒"],
            row["结束秒"],
            row["假设动作费用"],
            row["过早于冷却秒"],
            "个人资源假设允许" if row["假设可承受"] else "个人资源假设不足"
        ]
    )


func _ensure_selected() -> void:
    if rows.is_empty():
        return
    if selected < offset:
        offset = selected
    elif selected >= offset + _count():
        offset = selected - _count() + 1
    var row: Dictionary = rows[selected]
    var beginning := float(row["开始秒"])
    var finish := float(row["结束秒"])
    if beginning < start or finish > start + span:
        start = beginning
    _clamp()


func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        hovered = _at(event.position)
        tooltip_text = _description(hovered)
        queue_redraw()
    elif event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT:
            var index := _at(event.position)
            if index >= 0:
                selected = index
                tooltip_text = _description(selected)
            grab_focus()
        elif event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
            var direction := -1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1
            if event.ctrl_pressed:
                span *= 0.8 if direction < 0 else 1.25
            elif event.shift_pressed:
                start += direction * span * 0.2
            else:
                offset += direction * 3
            _clamp()
        else:
            return
        accept_event()
        queue_redraw()
    elif event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_UP:
                selected = maxi(0, selected - 1)
            KEY_DOWN:
                selected = mini(rows.size() - 1, selected + 1)
            KEY_PAGEUP:
                selected = maxi(0, selected - _count())
            KEY_PAGEDOWN:
                selected = mini(rows.size() - 1, selected + _count())
            KEY_LEFT:
                start -= span * 0.25
            KEY_RIGHT:
                start += span * 0.25
            KEY_HOME:
                selected = 0
                start = 0
                offset = 0
                span = minf(60, total)
            _:
                return
        if event.keycode not in [KEY_LEFT, KEY_RIGHT]:
            _ensure_selected()
        _clamp()
        tooltip_text = _description(selected)
        accept_event()
        queue_redraw()


func _time_grid(font: Font) -> void:
    for i in 5:
        var time := start + span * float(i) / 4
        var x := _x(time)
        draw_line(Vector2(x, TOP - 8), Vector2(x, size.y - FOOTER), Color("30473e"), 1)
        draw_string(
            font,
            Vector2(x + 2, 19),
            "%.1fs" % time,
            HORIZONTAL_ALIGNMENT_LEFT,
            80,
            11,
            Color("a3b3aa")
        )
    var boundary := _x(budget)
    if boundary >= LEFT and boundary <= size.x - 15:
        draw_line(
            Vector2(boundary, TOP - 8), Vector2(boundary, size.y - FOOTER), Color("b98768"), 2
        )


func _step(index: int, font: Font) -> void:
    var row: Dictionary = rows[index]
    var y := TOP + (index - offset) * ROW
    if index == selected or index == hovered:
        draw_rect(Rect2(2, y - 1, size.x - 4, ROW - 1), Color("3c4c3c"))
    var caption := "%d.%d %s" % [row["轮次"], row["步骤"], row["动作"]]
    draw_string(
        font, Vector2(7, y + 16), caption, HORIZONTAL_ALIGNMENT_LEFT, LEFT - 13, 12, Color("e3d7bf")
    )
    var a := clampf(_x(float(row["开始秒"])), LEFT, size.x - 15)
    var b := clampf(_x(float(row["结束秒"])), LEFT, size.x - 15)
    if b <= a:
        return
    var color := Color("6a9e8a") if row.kind == "action" else Color("8a825c")
    if not row["假设可承受"]:
        color = Color("9f6657")
    elif float(row["过早于冷却秒"]) > 0:
        color = Color("a48c59")
    draw_rect(Rect2(a, y + 3, b - a, ROW - 8), color)
    if b - a > 50:
        draw_string(
            font,
            Vector2(a + 4, y + 16),
            String(row["按键"]),
            HORIZONTAL_ALIGNMENT_LEFT,
            b - a - 8,
            11,
            Color("102522")
        )
    if index == selected:
        draw_rect(Rect2(a, y + 2, maxf(2, b - a), ROW - 6), Color("e1c28c"), false, 2)


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("102425"))
    var font := get_theme_default_font()
    _time_grid(font)
    for i in range(offset, mini(rows.size(), offset + _count())):
        _step(i, font)
    draw_string(
        font,
        Vector2(8, size.y - 24),
        (
            "%d—%d / %d步骤 · 绿色动作、灰金休息、红色假设资源不足"
            % [offset + 1, mini(rows.size(), offset + _count()), rows.size()]
        ),
        HORIZONTAL_ALIGNMENT_LEFT,
        size.x - 16,
        11,
        Color("b8b9a4")
    )
    draw_string(
        font,
        Vector2(8, size.y - 8),
        "滚轮翻步骤 · Ctrl滚轮缩放时间 · Shift滚轮平移时间 · 方向键选择",
        HORIZONTAL_ALIGNMENT_LEFT,
        size.x - 16,
        11,
        Color("a3b3aa")
    )
    if rows.is_empty():
        draw_string(
            font,
            Vector2(20, TOP + 25),
            "先在候选中添加已获动作。",
            HORIZONTAL_ALIGNMENT_LEFT,
            size.x - 40,
            16,
            Color("d5bd8d")
        )
    if has_focus():
        draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), Color("cfb484"), false, 2)
