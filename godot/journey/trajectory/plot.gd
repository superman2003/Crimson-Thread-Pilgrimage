extends Control
const V := preload("res://journey/core/values.gd")
var primary: Dictionary = {}
var comparison: Dictionary = {}
var mode := "path"
var hover_index := -1
var primary_points: Array[Vector2] = []

func configure(a: Dictionary, b: Dictionary, metric: String) -> void:
    primary = a.duplicate(true)
    comparison = b.duplicate(true)
    mode = metric
    custom_minimum_size = Vector2(500, 280)
    mouse_filter = Control.MOUSE_FILTER_STOP
    clip_contents = true
    queue_redraw()

func _ready() -> void:
    resized.connect(queue_redraw)
    mouse_exited.connect(func():hover_index = -1;queue_redraw())

func _values(run: Dictionary) -> Array[Vector2]:
    var result: Array[Vector2] = []
    var samples: Array = run.get("samples", [])
    var origin := V.point(samples[0].p) if not samples.is_empty() else Vector2.ZERO
    for sample in samples:
        if mode == "path":
            result.append(V.point(sample.p) - origin)
        elif mode == "speed":
            result.append(Vector2(float(sample.t), -V.point(sample.v).length()))
        elif mode == "energy":
            result.append(Vector2(float(sample.t), -float(sample.energy)))
        else:
            result.append(Vector2(float(sample.t), float(sample.p[1]) - origin.y))
    return result

func _draw() -> void:
    var a := _values(primary)
    var b := _values(comparison)
    var bounds := Rect2()
    for point in a + b:
        var rect := Rect2(point - Vector2.ONE, Vector2(2, 2))
        bounds = rect if bounds.size == Vector2.ZERO else bounds.merge(rect)
    draw_rect(Rect2(Vector2.ZERO, size), Color("0c1e24"))
    var area := Rect2(40, 18, maxf(1, size.x - 58), maxf(1, size.y - 48))
    for index in range(1, 5):
        var x := area.position.x + area.size.x * index / 5.0
        var y := area.position.y + area.size.y * index / 5.0
        draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), Color("244047"), 1)
        draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color("244047"), 1)
    if mode == "path":
        var scale := minf(area.size.x / maxf(1, bounds.size.x), area.size.y / maxf(1, bounds.size.y))
        var fitted := bounds.size * scale
        area = Rect2(area.get_center() - fitted * 0.5, fitted)
    primary_points.clear()
    var comparison_points := PackedVector2Array()
    for point in a:
        primary_points.append(area.position + (point - bounds.position) / bounds.size.max(Vector2.ONE) * area.size)
    for point in b:
        comparison_points.append(area.position + (point - bounds.position) / bounds.size.max(Vector2.ONE) * area.size)
    if comparison_points.size() > 1:
        draw_polyline(comparison_points, Color("8aa8bb"), 1.5, true)
    if primary_points.size() > 1:
        draw_polyline(PackedVector2Array(primary_points), Color("d2b078"), 2.0, true)
        draw_circle(primary_points[0], 4, Color("c3dfca"))
        draw_rect(Rect2(primary_points[-1] - Vector2(4, 4), Vector2(8, 8)), Color("df998a"))
    if hover_index >= 0 and hover_index < primary_points.size():
        draw_circle(primary_points[hover_index], 6, Color("f2e0c2"), false, 2.0, true)
    var font := get_theme_default_font()
    draw_string(font, Vector2(8, size.y - 10), "金：当前记录 · 蓝：比较记录 · 轨迹按各自起点对齐", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("b4c8bd"))

func _gui_input(event: InputEvent) -> void:
    if not event is InputEventMouseMotion:
        return
    var closest := -1
    var distance := 14.0
    for index in primary_points.size():
        var value := primary_points[index].distance_to(event.position)
        if value < distance:
            distance = value
            closest = index
    if closest != hover_index:
        hover_index = closest
        if closest >= 0:
            var sample: Dictionary = primary.samples[closest]
            tooltip_text = "%.2f秒 · 位置 %.1f,%.1f · 速度 %.1f · 生命%d · 绯线%d" % [sample.t, sample.p[0], sample.p[1], V.point(sample.v).length(), sample.hp, sample.energy]
        else:
            tooltip_text = "悬停折线可查看实际采样值。"
        queue_redraw()
