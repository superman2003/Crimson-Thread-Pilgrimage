extends Button
## Native Button interaction with a chamfered copper outline and a threaded focus.
const COPPER := Color("a88a62")
const THREAD := Color("c85450")

func _ready() -> void:
    mouse_entered.connect(queue_redraw)
    mouse_exited.connect(queue_redraw)
    focus_entered.connect(queue_redraw)
    focus_entered.connect(_request_focus_reveal)
    focus_exited.connect(queue_redraw)
    button_down.connect(queue_redraw)
    button_up.connect(queue_redraw)
    resized.connect(queue_redraw)
    theme_changed.connect(queue_redraw)
    # Ellipsized labels retain their complete wording for mouse and keyboard.
    resized.connect(_refresh_overflow_hint)
    minimum_size_changed.connect(_refresh_overflow_hint)
    _refresh_overflow_hint()

var _automatic_tooltip := ""
var _reveal_pending := false

func _request_focus_reveal() -> void:
    if _reveal_pending:return
    _reveal_pending=true
    call_deferred("_reveal_focus")

func _reveal_focus() -> void:
    _reveal_pending=false
    if not is_inside_tree() or not is_visible_in_tree() or is_queued_for_deletion() or not has_focus():return
    var ancestor:=get_parent()
    while ancestor!=null:
        if ancestor is ScrollContainer:
            # Respect nested scroll ownership, including controls in grid cells.
            ancestor.ensure_control_visible(self)
        if ancestor is Window:break
        ancestor=ancestor.get_parent()

func _refresh_overflow_hint() -> void:
    if not is_inside_tree():return
    if not tooltip_text.is_empty() and tooltip_text!=_automatic_tooltip:return
    var font:=get_theme_font("font")
    var font_size:=get_theme_font_size("font_size")
    var box:=get_theme_stylebox("normal")
    var available:=maxf(0.0,size.x-box.get_minimum_size().x)
    var width:=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
    if width>available and not text.is_empty():
        _automatic_tooltip=text
        tooltip_text=_automatic_tooltip
    else:
        tooltip_text=""
        _automatic_tooltip=""

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
