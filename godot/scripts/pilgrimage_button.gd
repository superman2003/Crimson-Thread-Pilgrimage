extends Button
## Native Button interaction with a chamfered copper outline and a threaded focus.
const COPPER := Color("a88a62")
const THREAD := Color("c85450")

func _ready() -> void:
    mouse_entered.connect(queue_redraw)
    mouse_exited.connect(queue_redraw)
    focus_entered.connect(queue_redraw)
    focus_exited.connect(queue_redraw)
    button_down.connect(queue_redraw)
    button_up.connect(queue_redraw)
    resized.connect(queue_redraw)
    theme_changed.connect(queue_redraw)

func _draw() -> void:
    var normal := get_theme_stylebox("normal") as StyleBoxFlat
    var selected := normal!=null and (normal.border_width_left>=2 or normal.border_width_bottom>=2)
    var active := not disabled and (is_hovered() or has_focus() or selected)
    var tint := THREAD if active else Color(COPPER,.55 if not disabled else .18)
    if bool(get_meta("inscription_tab",false)):
        var y := size.y-3
        draw_line(Vector2(10,y),Vector2(size.x-10,y),tint,.65,true)
        if active:
            var c := Vector2(size.x*.5,y)
            draw_polyline(PackedVector2Array([c+Vector2(0,-4),c+Vector2(3,0),c+Vector2(0,4),c-Vector2(3,0),c+Vector2(0,-4)]),tint,.75,true)
        return
    var cut := minf(9,size.y*.21)
    var edge := PackedVector2Array([Vector2(cut,1),Vector2(size.x-cut,1),Vector2(size.x-1,cut),Vector2(size.x-1,size.y-cut),Vector2(size.x-cut,size.y-1),Vector2(cut,size.y-1),Vector2(1,size.y-cut),Vector2(1,cut),Vector2(cut,1)])
    draw_polyline(edge,tint,.7,true)
    if active:
        draw_line(Vector2(cut+8,size.y-4),Vector2(size.x-cut-8,size.y-4),Color(THREAD,.18),.7,true)
        var c := Vector2(3,size.y*.5)
        draw_colored_polygon(PackedVector2Array([c+Vector2(-4,0),c+Vector2(0,-6),c+Vector2(4,0),c+Vector2(0,6)]),Color("0a181a"))
        draw_polyline(PackedVector2Array([c+Vector2(-4,0),c+Vector2(0,-6),c+Vector2(4,0),c+Vector2(0,6),c+Vector2(-4,0)]),THREAD,1,true)
        # A needle in the margin leaves the label and native focus navigation clear.
        draw_line(Vector2(size.x-17,5),Vector2(size.x-7,21),Color("ead8b7"),1,true)
        draw_line(Vector2(size.x-17,5),Vector2(size.x-14,14),COPPER,1,true)
