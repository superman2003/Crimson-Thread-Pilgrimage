extends Control
var mode := "thirds"
var letterbox := false

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    resized.connect(queue_redraw)

func _draw() -> void:
    var tint := Color(0.9, 0.85, 0.7, 0.45)
    if mode == "thirds":
        for index in [1, 2]:
            var x := size.x * float(index) / 3.0
            var y := size.y * float(index) / 3.0
            draw_line(Vector2(x, 0), Vector2(x, size.y), tint, 1.0)
            draw_line(Vector2(0, y), Vector2(size.x, y), tint, 1.0)
    elif mode == "center":
        var center := size * 0.5
        draw_line(center - Vector2(18, 0), center + Vector2(18, 0), tint, 1.0)
        draw_line(center - Vector2(0, 18), center + Vector2(0, 18), tint, 1.0)
        draw_circle(center, 5, tint, false, 1.0, true)
    if letterbox:
        var height := maxf(0, (size.y - size.x / 2.35) * 0.5)
        draw_rect(Rect2(0, 0, size.x, height), Color.BLACK)
        draw_rect(Rect2(0, size.y - height, size.x, height), Color.BLACK)
