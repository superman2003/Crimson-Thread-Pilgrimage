extends Control
## Resolution-independent engraved copper, name tags, and stitched folio edges.
var kind := "frame"
var hp := 0
var maximum := 1
var seal_id := "crimson"
## kind "thresholds": marks on the thread meter (U03). Costs of 0 draw nothing.
var energy := 0
var heal_cost := 0
var skill_cost := 0
const FOLIO := preload("res://assets/ui/inscription/v2/folio.png")
const NEEDLE := preload("res://assets/ui/inscription/v2/needle_seal.svg")
const COPPER := Color("b29168")
const THREAD := Color("c85450")
const BONE := Color("e8d7b8")
const INK := Color("091719")

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    resized.connect(queue_redraw)

func _diamond(c: Vector2, radius: float, tint: Color = COPPER) -> void:
    draw_polyline(PackedVector2Array([c+Vector2(0,-radius),c+Vector2(radius*.65,0),c+Vector2(0,radius),c-Vector2(radius*.65,0),c+Vector2(0,-radius)]),tint,1.0,true)

func _thread(points: PackedVector2Array) -> void:
    draw_polyline(points,Color("51272a"),1.6,true)
    draw_polyline(points,THREAD,.7,true)

func _compass(center: Vector2, radius: float) -> void:
    var tint := Color(COPPER,.32)
    draw_arc(center,radius,0,TAU,48,tint,1,true)
    draw_arc(center,radius*.64,0,TAU,40,tint,1,true)
    draw_line(center-Vector2(radius+9,0),center+Vector2(radius+9,0),tint,1,true)
    draw_line(center-Vector2(0,radius+9),center+Vector2(0,radius+9),tint,1,true)
    _diamond(center,6,Color(COPPER,.7))

func _health() -> void:
    var spacing := minf(37.0,(size.x-20)/maxf(1.0,maximum))
    var previous := Vector2(0,10)
    for index in maximum:
        var center := Vector2(13+index*spacing,23)
        var eye := center+Vector2(0,-12)
        var strand := PackedVector2Array()
        for step in 13:
            var t := float(step)/12.0
            strand.append(previous.lerp(eye,t)+Vector2(0,sin(t*PI)*5))
        _thread(strand)
        previous=eye
        var silhouette := PackedVector2Array([center+Vector2(0,-20),center+Vector2(8,-14),center+Vector2(8,11),center+Vector2(0,21),center+Vector2(-8,12),center+Vector2(-8,-14)])
        var alive := index<hp
        draw_colored_polygon(silhouette,BONE if alive else Color("152326"))
        silhouette.append(silhouette[0])
        draw_polyline(silhouette,THREAD if hp<=1 and alive else Color(COPPER,.6),.6,true)
        if alive:
            for grain in 28:
                var gx := float((grain*17+index*5)%13)-6
                var gy := float((grain*11+index*3)%29)-13
                draw_line(center+Vector2(gx,gy),center+Vector2(gx+1,gy+2),Color(.28,.22,.15,.12),.6,true)
        draw_circle(eye,2.7,INK)
        draw_arc(eye,3.0,0,TAU,16,COPPER,.8,true)
        draw_line(center+Vector2(2,-6),center+Vector2(1,14),Color(.3,.24,.17,.35),.5,true)
        if not alive:
            draw_polyline(PackedVector2Array([center+Vector2(-3,-8),center+Vector2(3,-2),center+Vector2(-2,4),center+Vector2(3,10)]),INK,2,true)
    _thread(PackedVector2Array([previous,previous+Vector2(12,4),previous+Vector2(23,1)]))

func threshold_state() -> Dictionary:
    return {"heal_lit":heal_cost>0 and energy>=heal_cost,"skill_lit":skill_cost>0 and energy>=skill_cost,
        "heal_x":size.x*float(heal_cost)/maxf(1.0,float(maximum)),"skill_x":size.x*float(skill_cost)/maxf(1.0,float(maximum))}

## Heal threshold as a notch through the meter, the active thread art's cost as
## a diamond above it; each lights once the current thread pays for it.
func _thresholds() -> void:
    var span := maxf(1.0,float(maximum))
    var mid := size.y*.5+2.0
    if heal_cost>0:
        var x := clampf(size.x*float(heal_cost)/span,1.0,size.x-1.0)
        var lit: bool = threshold_state().heal_lit
        draw_line(Vector2(x,mid-5),Vector2(x,mid+5),BONE if lit else Color(COPPER,.5),1.6 if lit else 1.0,true)
    if skill_cost>0:
        var x := clampf(size.x*float(skill_cost)/span,3.0,size.x-3.0)
        var c := Vector2(x,mid-6)
        var diamond := PackedVector2Array([c+Vector2(0,-3.5),c+Vector2(2.6,0),c+Vector2(0,3.5),c+Vector2(-2.6,0)])
        var lit: bool = threshold_state().skill_lit
        if lit:draw_colored_polygon(diamond,THREAD)
        diamond.append(diamond[0])
        draw_polyline(diamond,THREAD if lit else Color(COPPER,.6),.8,true)

func _draw() -> void:
    if size.x<4 or size.y<4:return
    if kind=="health":
        _health()
        return
    if kind=="thresholds":
        _thresholds()
        return
    if kind=="seal_art":
        if seal_id=="crimson":
            draw_texture_rect(NEEDLE,Rect2(Vector2.ZERO,size),false)
        else:
            var c := size*.5
            _compass(c,minf(size.x,size.y)*.38)
            if seal_id=="bell":
                var d := minf(size.x,size.y)*.32
                draw_arc(c-Vector2(0,d*.42),d*.48,PI,TAU,48,BONE,1.2,true)
                draw_polyline(PackedVector2Array([c+Vector2(-d*.48,-d*.42),c+Vector2(-d*.62,d*.58),c+Vector2(-d*.8,d*.73),c+Vector2(d*.8,d*.73),c+Vector2(d*.62,d*.58),c+Vector2(d*.48,-d*.42)]),BONE,1.2,true)
                draw_circle(c+Vector2(0,d*.88),5,COPPER)
            else:
                draw_rect(Rect2(c-Vector2(55,77),Vector2(110,154)),BONE,false,1.0)
                for y in range(-52,60,23):draw_line(c+Vector2(-32,y),c+Vector2(33,y),COPPER,.8,true)
        return
    if kind=="tactical":
        var active := bool(get_parent().get_meta("inscription_active",false))
        var tint := THREAD if active else Color(COPPER,.65)
        var edge := PackedVector2Array([Vector2(8,1),Vector2(size.x-9,1),Vector2(size.x-1,9),Vector2(size.x-1,size.y-8),Vector2(size.x-8,size.y-1),Vector2(1,size.y-1),Vector2(1,8),Vector2(8,1)])
        draw_polyline(edge,tint,.7,true)
        if active:_diamond(Vector2(1,9),4,THREAD)
        return
    if kind=="location":
        var y := size.y*.5
        draw_line(Vector2(0,y),Vector2(69,y),Color(COPPER,.6),1,true)
        draw_line(Vector2(size.x-69,y),Vector2(size.x,y),Color(COPPER,.6),1,true)
        _diamond(Vector2(54,y),6)
        _diamond(Vector2(size.x-54,y),6)
        draw_line(Vector2(size.x*.5-47,size.y-3),Vector2(size.x*.5+47,size.y-3),Color(COPPER,.4),1,true)
        _diamond(Vector2(size.x*.5,size.y-3),4)
        return
    if kind=="well":
        draw_rect(Rect2(Vector2.ZERO,size),Color(.015,.025,.025,.13))
        draw_line(Vector2(0,0),Vector2(0,size.y),Color(COPPER,.28),.7,true)
        _diamond(Vector2(0,12),3,Color(COPPER,.6))
        return
    if kind=="hud":
        for i in 24:
            draw_rect(Rect2(size.x*float(i)/24,0,size.x/24+1,size.y),Color(.01,.025,.028,.35*(1.0-float(i)/24)))
        return
    draw_texture_rect(FOLIO,Rect2(Vector2.ZERO,size),false)
    if kind in ["frame","map"]:
        var y := 70.0 if kind=="map" else 94.0
        draw_line(Vector2(30,y),Vector2(size.x-30,y),Color(COPPER,.45),.7,true)
        draw_line(Vector2(30,y),Vector2(171,y),Color(COPPER,.7),.7,true)
        _diamond(Vector2(180,y),5)
        _diamond(Vector2(size.x-32,y),3)
