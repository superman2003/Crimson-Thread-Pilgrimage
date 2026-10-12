extends Node2D
## Paint only the camera's neighbourhood. Collision remains owned by CaveWorld.
var solid_rects: Array[Rect2] = []
var painted_rects: Array[Rect2] = []
var view_bounds := Rect2()
const MARGIN := 96.0
const QUANTUM := 128.0

func configure(rects: Array[Rect2], rock_material: ShaderMaterial) -> void:
    solid_rects = rects
    material = rock_material
    _refresh_view()

func _process(_delta: float) -> void:
    _refresh_view()

func _refresh_view() -> void:
    var inverse := get_global_transform_with_canvas().affine_inverse()
    var size := get_viewport_rect().size
    var bounds := Rect2(inverse * Vector2.ZERO, Vector2.ZERO)
    for corner in [Vector2(size.x, 0), size, Vector2(0, size.y)]:
        bounds = bounds.expand(inverse * corner)
    bounds = bounds.grow(MARGIN)
    var start := (bounds.position / QUANTUM).floor() * QUANTUM
    var finish := (bounds.end / QUANTUM).ceil() * QUANTUM
    bounds = Rect2(start, finish - start)
    if bounds == view_bounds:
        return
    view_bounds = bounds
    painted_rects.clear()
    for solid in solid_rects:
        var clipped := solid.intersection(bounds)
        if clipped.has_area():
            painted_rects.append(clipped)
    queue_redraw()

func _draw() -> void:
    for rect in painted_rects:
        draw_rect(rect, Color.WHITE)
