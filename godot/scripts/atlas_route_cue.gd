extends Node2D
## Direction markers inherit the route's knowledge and visibility lifecycle.
var start := Vector2.ZERO
var finish := Vector2.ZERO
var forward := false
var reverse := false
var tint := Color("b29168")

static func state(a: Dictionary, b: Dictionary) -> String:
    var outgoing: Variant=a.get("open",false)
    var incoming: Variant=b.get("open",false)
    var left: bool=outgoing is bool and outgoing
    var right: bool=incoming is bool and incoming
    return "双向可通" if left and right else "仅正向可通" if left else "仅反向可通" if right else "两侧均有门槛"

func configure(a: Vector2,b: Vector2,outgoing: Dictionary,incoming: Dictionary) -> void:
    start=a;finish=b
    forward=outgoing.get("open") is bool and outgoing.get("open",false)
    reverse=incoming.get("open") is bool and incoming.get("open",false)
    queue_redraw()

func arrow_tip(point: Vector2,direction: Vector2) -> PackedVector2Array:
    var normal:=Vector2(-direction.y,direction.x)
    return PackedVector2Array([point-direction*6+normal*4,point,point-direction*6-normal*4])

func _draw() -> void:
    if not start.is_finite() or not finish.is_finite():return
    var length:=start.distance_to(finish)
    if length<20.0:return
    var direction:=start.direction_to(finish)
    if forward:draw_polyline(arrow_tip(start.lerp(finish,0.65),direction),tint,1.6,true)
    if reverse:draw_polyline(arrow_tip(start.lerp(finish,0.35),-direction),tint,1.6,true)
    if not forward and not reverse:
        var center:=start.lerp(finish,0.5)
        var normal:=Vector2(-direction.y,direction.x)*4.0
        draw_line(center-normal,center+normal,tint,2.0,true)
