extends Control
signal action_selected(key: String)
var timeline: Dictionary = {}
var hit_boxes: Array = []
const COLORS := {"windup":Color("c4a46a"), "active":Color("d17e6e"), "recover":Color("78a69a")}

func configure(value: Dictionary) -> void:
    timeline = value.duplicate(true)
    custom_minimum_size = Vector2(500, maxf(100, value.get("rows", []).size() * 48 + 36))
    mouse_filter = Control.MOUSE_FILTER_STOP
    clip_contents = true
    queue_redraw()

func _draw() -> void:
    hit_boxes.clear()
    draw_rect(Rect2(Vector2.ZERO, size), Color("0d2026"))
    if not timeline.get("ok", false):
        return
    var font := get_theme_default_font()
    var width := maxf(1, size.x - 32)
    var duration := maxf(0.01, float(timeline.duration))
    var index := 0
    for row in timeline.rows:
        var y := 18.0 + index * 48
        draw_string(font, Vector2(16, y), String(row.name).left(28), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("d3d4bc"))
        for phase in row.phases:
            var x := 16 + float(phase.start) / duration * width
            var length := (float(phase.finish) - float(phase.start)) / duration * width
            draw_rect(Rect2(x, y + 6, maxf(1, length), 16), COLORS[phase.id])
        var box := Rect2(16 + float(row.begin) / duration * width, y + 4, maxf(10, (float(row.finish) - float(row.begin)) / duration * width), 20)
        hit_boxes.append({"rect":box, "key":row.key, "name":row.name, "begin":row.begin, "finish":row.finish})
        index += 1
    draw_string(font, Vector2(16, size.y - 8), "总字段时长 %.2f秒 · 点击色条打开原动作" % duration, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("adc0b6"))

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        tooltip_text = "空白为自定间隔；色条为前摇、判定和收势。"
        for box in hit_boxes:
            if box.rect.has_point(event.position):
                tooltip_text = "%s · %.2f–%.2f秒" % [box.name, box.begin, box.finish]
                break
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        for box in hit_boxes:
            if box.rect.has_point(event.position):
                action_selected.emit(String(box.key))
                accept_event()
                break
