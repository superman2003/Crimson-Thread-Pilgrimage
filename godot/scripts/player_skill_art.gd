extends RefCounted
## Presentation only. Skill costs, movement, damage and control remain outside.
const POLICY:=preload("res://scripts/combat_visual_policy.gd")
const ATLAS:=preload("res://assets/vfx/player_skills/player_skills.png")
const FAMILIES:=["needle","shockwave","snare"]
const WIDTHS:={"needle":24.0,"shockwave":60.0,"snare":72.0}
const CELL:=192.0

static func family_for(payload:Dictionary)->String:
    if not bool(payload.get("skill_effect",false)):return ""
    return String({"projectile":"needle","wave":"shockwave","snare_field":"snare"}.get(String(payload.get("kind","")),""))

static func active_frame(family:String,seconds:float)->int:
    if family=="needle":return int(maxf(0,seconds)*14)%4
    var fps:=24.0 if family=="shockwave" else 12.0
    var frame:=int(maxf(0,seconds)*fps)
    return frame if frame<2 else 2+(frame-2)%4

static func atlas_rect(family:String,frame:int)->Rect2:
    var row:=FAMILIES.find(family)
    if row<0 or frame<0 or frame>7:return Rect2()
    return Rect2(frame*CELL,row*CELL,CELL,CELL)

static func draw_frame(host:Node2D,family:String,frame:int,direction:int,alpha:float=1.0)->bool:
    var source:=atlas_rect(family,frame)
    if source.size==Vector2.ZERO:return false
    var factor:=float(WIDTHS[family])/(64.0 if family=="needle" else 96.0)
    var anchor:=Vector2(96,96) if family=="needle" else Vector2(96,144)
    var floor:=Vector2.ZERO if family=="needle" else Vector2(0,42 if family=="shockwave" else 6)
    host.draw_set_transform(Vector2.ZERO,0,Vector2(-1 if direction<0 and family!="snare" else 1,1))
    host.draw_texture_rect_region(ATLAS,Rect2(floor-anchor*factor,Vector2.ONE*CELL*factor),source,Color(1,1,1,alpha))
    host.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
    return true

static func spawn_terminal(host:Node,point:Vector2,family:String,direction:int,reason:String)->Node2D:
    if not FAMILIES.has(family):return null
    if family=="needle" and reason not in ["hit","wall"]:return null
    if family!="needle" and reason not in ["expiry","wall"]:return null
    var mark:=Terminal.new();mark.name="PlayerSkillTerminalVfx";mark.family=family;mark.direction=direction;mark.paint=draw_frame
    if not POLICY.attach_contact(host,mark):return null
    mark.global_position=point
    return mark

class Terminal extends Node2D:
    var family:=""
    var direction:=1
    var age:=0.0
    var sampled:=false
    var paint:Callable
    func _process(delta:float)->void:
        if is_queued_for_deletion():return
        if not sampled:sampled=true
        else:age+=maxf(0,delta)
        var duration:=.2 if family=="needle" else 2.0/12
        if age>=duration:queue_free();return
        queue_redraw()
    func _draw()->void:
        var first:=4 if family=="needle" else 6
        var count:=4 if family=="needle" else 2
        var fps:=20.0 if family=="needle" else 12.0
        var duration:=count/fps
        paint.call(self,family,first+clampi(int(age*fps),0,count-1),direction,clampf((duration-age)*fps,0,1))
