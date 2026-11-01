extends Control
var data: Dictionary = {}
var selected := ""
var hovered := ""
var column := 0
var scrolls := [0, 0]
var show_proofs := true
var hitboxes: Dictionary = {}
var points: Dictionary = {}
const TOP := 40.0
const ROW := 34.0
const FOOTER := 35.0


func _init() -> void:
    custom_minimum_size = Vector2(480, 380)
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    focus_mode = Control.FOCUS_ALL
    clip_contents = true


func configure(value: Dictionary) -> void:
    data = value.duplicate(true)
    selected = ""
    hovered = ""
    scrolls = [0, 0]
    queue_redraw()


func _ready() -> void:
    resized.connect(queue_redraw)
    mouse_exited.connect(
        func():
            hovered = ""
            tooltip_text = ""
            queue_redraw()
    )
    focus_entered.connect(queue_redraw)
    focus_exited.connect(queue_redraw)


func _items(side: int) -> Array:
    var result := []
    if side == 1:
        return data.get("recipes", [])
    for item in data.get("resources", []):
        if show_proofs or not item.proof:
            result.append(item)
    return result


func _visible_count() -> int:
    return maxi(1, int(floor((size.y - TOP - FOOTER) / ROW)))


func _clamp_scrolls() -> void:
    for side in 2:
        scrolls[side] = clampi(
            int(scrolls[side]), 0, maxi(0, _items(side).size() - _visible_count())
        )


func _layout() -> void:
    _clamp_scrolls()
    points.clear()
    hitboxes.clear()
    var width := minf(190, (size.x - 80) * 0.42)
    for side in 2:
        var items := _items(side)
        for i in range(
            int(scrolls[side]), mini(items.size(), int(scrolls[side]) + _visible_count())
        ):
            var x := 10.0 if side == 0 else size.x - width - 10
            var rect := Rect2(x, TOP + (i - int(scrolls[side])) * ROW, width, ROW - 6)
            var id := String(items[i].id)
            hitboxes[id] = rect
            points[id] = (
                Vector2(rect.end.x, rect.get_center().y)
                if side == 0
                else Vector2(rect.position.x, rect.get_center().y)
            )


func _at(point: Vector2) -> String:
    for id in hitboxes:
        if hitboxes[id].has_point(point):
            return String(id)
    return ""


func _description(id: String) -> String:
    var details: Array[String] = []
    for side in 2:
        for item in _items(side):
            if item.id == id:
                details.append(String(item.name))
                if side == 0:
                    details.append("记录持有：" + str(item.held))
                    details.append("出示图样，不消耗" if item.proof else "会按配方消耗的材料")
                else:
                    details.append("资金成本：" + str(item.currency))
    for link in data.get("links", []):
        if link.from == id or link.to == id:
            var other := String(link.to if link.from == id else link.from)
            details.append(_name(other) + " × " + str(link.amount) + ("（图样）" if link.proof else ""))
    return "\n".join(details)


func _name(id: String) -> String:
    for side in 2:
        for item in _items(side):
            if item.id == id:
                return String(item.name)
    return "已知依赖"


func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        hovered = _at(event.position)
        column = 0 if event.position.x < size.x * 0.5 else 1
        tooltip_text = _description(hovered)
        queue_redraw()
    elif event is InputEventMouseButton and event.pressed:
        column = 0 if event.position.x < size.x * 0.5 else 1
        if event.button_index == MOUSE_BUTTON_LEFT:
            selected = _at(event.position)
            tooltip_text = _description(selected)
            grab_focus()
        elif event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
            scrolls[column] = (
                int(scrolls[column]) + (-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
            )
            _clamp_scrolls()
        else:
            return
        accept_event()
        queue_redraw()
    elif event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_LEFT:
                column = 0
                _select_offset(0)
            KEY_RIGHT:
                column = 1
                _select_offset(0)
            KEY_UP:
                _select_offset(-1)
            KEY_DOWN:
                _select_offset(1)
            KEY_P:
                show_proofs = not show_proofs
            KEY_HOME:
                scrolls = [0, 0]
                selected = ""
            _:
                return
        _clamp_scrolls()
        tooltip_text = _description(selected)
        accept_event()
        queue_redraw()


func _select_offset(offset: int) -> void:
    var items := _items(column)
    if items.is_empty():
        return
    var index := 0
    for i in items.size():
        if items[i].id == selected:
            index = i
            break
    index = clampi(index + offset, 0, items.size() - 1)
    selected = String(items[index].id)
    if index < int(scrolls[column]):
        scrolls[column] = index
    elif index >= int(scrolls[column]) + _visible_count():
        scrolls[column] = index - _visible_count() + 1


func _curve(a: Vector2, b: Vector2, color: Color, width: float) -> void:
    var distance := absf(b.x - a.x) * 0.5
    var first := a + Vector2(distance, 0)
    var second := b - Vector2(distance, 0)
    var line := PackedVector2Array()
    for i in 18:
        var t := float(i) / 17
        var u := 1 - t
        line.append(a * u * u * u + first * 3 * u * u * t + second * 3 * u * t * t + b * t * t * t)
    draw_polyline(line, color, width, true)


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("112425"))
    _layout()
    var font := get_theme_default_font()
    draw_string(
        font, Vector2(10, 23), "材料 / 图样", HORIZONTAL_ALIGNMENT_LEFT, 200, 15, Color("d5ba86")
    )
    draw_string(
        font,
        Vector2(size.x * 0.57, 23),
        "已选改制方案",
        HORIZONTAL_ALIGNMENT_LEFT,
        220,
        15,
        Color("d5ba86")
    )
    for link in data.get("links", []):
        if not points.has(link.from) or not points.has(link.to):
            continue
        var emphasized: bool = (
            link.from == selected
            or link.to == selected
            or link.from == hovered
            or link.to == hovered
        )
        var color := Color("c4a56e") if link.proof else Color("6faaa1")
        color.a = 0.95 if emphasized else 0.4
        var a: Vector2 = points[link.from]
        var b: Vector2 = points[link.to]
        _curve(a, b, color, 2.5 if emphasized else 1.2)
        if emphasized:
            draw_string(
                font,
                a.lerp(b, 0.5) + Vector2(-8, -3),
                str(link.amount),
                HORIZONTAL_ALIGNMENT_LEFT,
                45,
                13,
                Color("eadcc6")
            )
    for side in 2:
        for item in _items(side):
            if not hitboxes.has(item.id):
                continue
            var rect: Rect2 = hitboxes[item.id]
            var active: bool = item.id == selected or item.id == hovered
            draw_rect(rect, Color("4b5140") if active else Color("203c3a"))
            draw_rect(rect, Color("bca575") if active else Color("49665d"), false, 1)
            draw_string(
                font,
                rect.position + Vector2(7, 19),
                String(item.name),
                HORIZONTAL_ALIGNMENT_LEFT,
                rect.size.x - 14,
                13,
                Color("eadcc6")
            )
            if side == 0 and item.proof:
                draw_circle(rect.end - Vector2(8, 8), 3, Color("c4a56e"))
    draw_string(
        font,
        Vector2(10, size.y - 12),
        "分别滚动两列 · 方向键查看依赖 · P切换图样线 · 金色图样不消耗",
        HORIZONTAL_ALIGNMENT_LEFT,
        size.x - 20,
        12,
        Color("a3b3aa")
    )
    if has_focus():
        draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), Color("cfb484"), false, 2)
