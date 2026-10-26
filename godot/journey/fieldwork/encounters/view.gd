extends Control
var attacks: Array = []
var reaction := 0.0
var maximum := 1.0
var selected := 0
var hovered := -1
const LEFT := 150.0
const TOP := 35.0
const ROW := 31.0
const BOTTOM := 35.0


func _init() -> void:
    custom_minimum_size = Vector2(480, 260)
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    focus_mode = Control.FOCUS_ALL
    clip_contents = true


func configure(data: Dictionary) -> void:
    attacks = data.get("attacks", []).duplicate(true)
    reaction = maxf(0, float(data.get("reaction", 0)))
    maximum = maxf(1, reaction)
    for row in attacks:
        maximum = maxf(maximum, float(row.windup) + float(row.active) + float(row.recover))
    custom_minimum_size.y = maxf(260, TOP + attacks.size() * ROW + BOTTOM)
    selected = clampi(selected, 0, maxi(0, attacks.size() - 1))
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


func _x(time: float) -> float:
    return LEFT + time / maximum * maxf(1, size.x - LEFT - 20)


func _row(point: Vector2) -> int:
    var index := int(floor((point.y - TOP) / ROW))
    return index if point.y >= TOP and index >= 0 and index < attacks.size() else -1


func _description(index: int) -> String:
    if index < 0 or index >= attacks.size():
        return ""
    var row: Dictionary = attacks[index]
    return (
        "%s · %s\n前摇 %.2f · 判定 %.2f · 收势 %.2f\n目录冷却 %.2f · 目录触发距离 %.0f"
        % [row.name, row.type, row.windup, row.active, row.recover, row.cooldown, row.range]
    )


func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        hovered = _row(event.position)
        tooltip_text = _description(hovered)
        queue_redraw()
    elif (
        event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
    ):
        var index := _row(event.position)
        if index >= 0:
            selected = index
            tooltip_text = _description(selected)
        grab_focus()
        accept_event()
        queue_redraw()
    elif event is InputEventKey and event.pressed and not event.echo:
        if event.keycode in [KEY_UP, KEY_LEFT]:
            selected = maxi(0, selected - 1)
        elif event.keycode in [KEY_DOWN, KEY_RIGHT]:
            selected = mini(attacks.size() - 1, selected + 1)
        elif event.keycode == KEY_HOME:
            selected = 0
        else:
            return
        tooltip_text = _description(selected)
        accept_event()
        queue_redraw()


func _phase(start: float, finish: float, y: float, color: Color) -> void:
    var a := _x(start)
    var b := _x(finish)
    if b > a:
        draw_rect(Rect2(a, y, b - a, ROW - 10), color)


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("132525"))
    var font := get_theme_default_font()
    for i in 6:
        var time := maximum * float(i) / 5
        var x := _x(time)
        draw_line(Vector2(x, TOP - 8), Vector2(x, size.y - BOTTOM), Color("30453b"), 1)
        draw_string(
            font,
            Vector2(x + 2, 20),
            "%.1fs" % time,
            HORIZONTAL_ALIGNMENT_LEFT,
            70,
            11,
            Color("a3b3aa")
        )
    for i in attacks.size():
        var row: Dictionary = attacks[i]
        var y := TOP + i * ROW
        if i == selected or i == hovered:
            draw_rect(Rect2(3, y - 2, size.x - 6, ROW - 2), Color("414936"))
        draw_string(
            font,
            Vector2(7, y + 15),
            String(row.name),
            HORIZONTAL_ALIGNMENT_LEFT,
            LEFT - 12,
            12,
            Color("eadcc6")
        )
        var first := float(row.windup)
        var second := first + float(row.active)
        var third := second + float(row.recover)
        _phase(0, first, y, Color("b49b63"))
        _phase(first, second, y, Color("a65f53"))
        _phase(second, third, y, Color("669d89"))
    var x := _x(reaction)
    draw_line(Vector2(x, TOP - 9), Vector2(x, size.y - BOTTOM), Color("d6c896"), 2)
    draw_string(
        font,
        Vector2(10, size.y - 10),
        "金：前摇 · 红：判定 · 绿：收势 · 竖线：个人准备间隔假设",
        HORIZONTAL_ALIGNMENT_LEFT,
        size.x - 20,
        12,
        Color("a3b3aa")
    )
    if has_focus():
        draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), Color("cfb484"), false, 2)
