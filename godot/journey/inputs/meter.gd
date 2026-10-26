extends Control
var device := -1
var history: Array = []
var elapsed := 0.0
var threshold := 0.2
var negative_triggers := {}
const AXES := [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y, JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]

func _ready() -> void:
    custom_minimum_size = Vector2(500, 230)
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
    elapsed += delta
    if elapsed < 0.1:
        return
    elapsed = 0.0
    if device not in Input.get_connected_joypads():
        history.clear()
        queue_redraw()
        return
    var sample := []
    for axis in AXES:
        var value := Input.get_joy_axis(device, axis)
        if axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
            if value < -0.05:
                negative_triggers[axis] = true
            value = trigger_value(value, negative_triggers.has(axis))
        sample.append(value)
    history.append(sample)
    while history.size() > 60:
        history.pop_front()
    queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("0e2026"))
    var font := get_theme_default_font()
    if history.is_empty():
        draw_string(font, Vector2(20, 40), "没有当前设备的轴样本。", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("c9d2c2"))
        return
    var latest: Array = history[-1]
    for stick in 2:
        var center := Vector2(80 + stick * 160, 85)
        draw_circle(center, 55, Color("678078"), false, 1.0, true)
        draw_circle(center, 55 * clampf(threshold, 0, 1), Color(0.55, 0.57, 0.5, 0.25))
        draw_line(center - Vector2(55, 0), center + Vector2(55, 0), Color("3a5459"), 1)
        draw_line(center - Vector2(0, 55), center + Vector2(0, 55), Color("3a5459"), 1)
        var point := Vector2(float(latest[stick * 2]), float(latest[stick * 2 + 1]))
        draw_circle(center + point * 55, 4, Color("dfbc82"))
        draw_string(font, center + Vector2(-48, 80), "%+.2f / %+.2f" % [point.x, point.y], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("d8d3ba"))
    for index in 2:
        var x := 365.0 + index * 60.0
        draw_rect(Rect2(x, 30, 20, 110), Color("294249"))
        var value := clampf(float(latest[index + 4]), 0, 1)
        draw_rect(Rect2(x, 140 - 110 * value, 20, 110 * value), Color("a7c0ac"))
    var points := PackedVector2Array()
    for index in history.size():
        points.append(Vector2(20 + float(index) / 59 * maxf(1, size.x - 40), 205 - absf(float(history[index][0])) * 35))
    if points.size() > 1:
        draw_polyline(points, Color("d6b078"), 1.5, true)
    draw_string(font, Vector2(20, 224), "左摇杆X绝对值 · 最近约6秒 · 死区仅展示当前动作阈值", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("a9b9af"))

static func trigger_value(value: float, negative_rest: bool) -> float:
    return clampf((value + 1.0) * 0.5 if negative_rest else value, 0, 1)
