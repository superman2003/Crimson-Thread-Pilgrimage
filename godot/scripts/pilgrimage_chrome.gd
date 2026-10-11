extends Control
## Original needle, stitch and hammered-bronze geometry, rendered at UI scale.
var kind := "frame"
var hp := 0
var maximum := 1
const COPPER := Color("bda176")
const THREAD := Color("d5686b")

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    resized.connect(queue_redraw)

func _draw() -> void:
    if kind == "health":
        var spacing := minf(27.0, size.x / maxf(1.0, maximum))
        for index in maximum:
            var center := Vector2(12 + index * spacing, 14)
            var points := PackedVector2Array([center+Vector2(0,-11),center+Vector2(7,-4),center+Vector2(5,6),center+Vector2(0,11),center+Vector2(-5,6),center+Vector2(-7,-4)])
            draw_colored_polygon(points, Color("f1dfc0") if index < hp else Color("272e31"))
            points.append(points[0])
            draw_polyline(points, THREAD if hp <= 1 and index < hp else COPPER, 1.0, true)
            if index < hp:
                draw_line(center+Vector2(0,-6),center+Vector2(0,6), THREAD, 1.5, true)
        return
    var bounds := Rect2(Vector2(1,1),size-Vector2(2,2))
    draw_rect(bounds, Color("10191f"))
    draw_rect(Rect2(1,1,size.x-2,68),Color("1b252a"))
    draw_rect(bounds, Color("655b48"),false,1)
    draw_rect(Rect2(8,8,size.x-16,size.y-16),Color("353b38"),false,1)
    for x in range(26,int(size.x)-26,14):
        draw_line(Vector2(x,size.y-12),Vector2(x+4,size.y-12),Color("675c46"),1,true)
    for corner in [Vector2(17,17),Vector2(size.x-17,17),Vector2(17,size.y-17),Vector2(size.x-17,size.y-17)]:
        var dx := 1.0 if corner.x < size.x/2 else -1.0
        var dy := 1.0 if corner.y < size.y/2 else -1.0
        draw_polyline(PackedVector2Array([corner+Vector2(0,19*dy),corner,corner+Vector2(19*dx,0)]),COPPER,1.5,true)
        draw_line(corner+Vector2(4*dx,4*dy),corner+Vector2(13*dx,13*dy),THREAD,1,true)
    if kind == "frame":
        draw_line(Vector2(32,94),Vector2(size.x-32,94),Color("494b40"),1,true)
        draw_line(Vector2(32,94),Vector2(106,94),THREAD,2,true)
        var c := Vector2(size.x/2,35)
        draw_line(c-Vector2(55,0),c+Vector2(55,0),Color("625841"),1,true)
        draw_arc(c,11,0,TAU,32,COPPER,1,true)
        draw_line(c+Vector2(-5,7),c+Vector2(5,-7),THREAD,2,true)
