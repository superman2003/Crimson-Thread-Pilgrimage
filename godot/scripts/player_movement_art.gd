extends RefCounted
## Cosmetic event hooks; never mutate the Player's contact, velocity or jump budget.
const POLICY := preload("res://scripts/combat_visual_policy.gd")
const ATLAS := preload("res://assets/vfx/player_movement/player_movement.png")
const FAMILIES := ["double_jump","wall_grip","land"]
const SIDE_META := &"movement_art_wall_side"
static func frame_rect(family: String, frame: int) -> Rect2:
    var row := FAMILIES.find(family)
    return Rect2(frame*192,row*192,192,192) if row>=0 and frame>=0 and frame<6 else Rect2()
static func paint(host: Node2D, family: String, frame: int, direction: int, size: float, alpha: float) -> void:
    host.draw_set_transform(Vector2.ZERO,0,Vector2(direction,1))
    var anchor_y := .5 if family=="wall_grip" else 154.0/192.0
    host.draw_texture_rect_region(ATLAS,Rect2(-size/2,-size*anchor_y,size,size),frame_rect(family,frame),Color(1,1,1,alpha))
    host.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
static func clear(player: Node) -> void:
    player.set_meta(SIDE_META,0)
    for node in player.get_children():
        if node.has_meta("player_movement_art"): node.visible=false; node.queue_free()
static func clear_wall(player: Node) -> void:
    for node in player.get_children():
        if node.has_meta("player_movement_art") and node.family=="wall_grip" and node.held:
            node.visible=false; node.queue_free()
static func double_jump(player: Node2D) -> Node2D: return _attach(player,"double_jump",player.facing,false,false,0)
static func land(player: Node2D, fall_speed: float) -> Node2D: return _attach(player,"land",player.facing,false,fall_speed>=620,fall_speed)
static func wall_jump(player: Node2D, contact_side: int) -> Node2D:
    clear_wall(player); player.set_meta(SIDE_META,0)
    return _attach(player,"wall_grip",contact_side,false,false,0)
static func wall_state(player: Node2D) -> void:
    var side := 0
    if player.wall_sliding and player.is_on_wall() and not player.is_on_floor() and not player.ui_input_locked:
        side=signi(-player.get_wall_normal().x)
    if side==int(player.get_meta(SIDE_META,0)):return
    clear_wall(player); player.set_meta(SIDE_META,side)
    # Latch the edge even when a full cosmetic budget rejects admission.
    if side!=0:_attach(player,"wall_grip",side,true,false,0)
static func _attach(player: Node2D, family: String, direction: int, held: bool, heavy: bool, fall_speed: float) -> Node2D:
    var node := MotionVisual.new()
    node.set_meta("player_movement_art",true)
    node.name="PlayerMovementArt_"+family
    node.owner_ref=weakref(player); node.family=family; node.direction=direction; node.held=held; node.heavy=heavy; node.fall_speed=fall_speed
    node.position=Vector2(direction*17,-42) if family=="wall_grip" else Vector2.ZERO
    node.z_index=34 if family=="land" else 58
    node.size=(128.0 if heavy else 88.0) if family=="land" else (52.0 if family=="wall_grip" else 106.0)
    node.duration=(.24 if heavy else .18) if family=="land" else .24
    node.paint_frame=paint
    node.reduced=not bool(player.get_meta("accessibility",{}).get("flash_enabled",true))
    node.opacity=.4 if node.reduced else .8
    if node.reduced:node.frame=3
    return node if POLICY.attach_secondary(player,node,&"state" if held else &"motion",player) else null
class MotionVisual extends Node2D:
    var owner_ref: WeakRef
    var family:="double_jump"
    var direction:=1
    var held:=false
    var heavy:=false
    var fall_speed:=0.0
    var size:=106.0
    var duration:=.24
    var age:=0.0
    var sampled:=false
    var frame:=0
    var opacity:=.8
    var reduced:=false
    var paint_frame:Callable
    func valid_owner(player: Node) -> bool:
        if not is_instance_valid(player) or player.is_queued_for_deletion() or player.death_timer>0:return false
        return not held or (not player.ui_input_locked and player.wall_sliding and not player.is_on_floor() and player.is_on_wall() and signi(-player.get_wall_normal().x)==direction)
    func _process(delta: float) -> void:
        var player:Node=owner_ref.get_ref()
        if not valid_owner(player):
            if held and is_instance_valid(player) and int(player.get_meta(SIDE_META,0))==direction:player.set_meta(SIDE_META,0)
            visible=false;queue_free();return
        if sampled:age+=maxf(0,delta)
        else:sampled=true
        reduced=not bool(player.get_meta("accessibility",{}).get("flash_enabled",true))
        opacity=.4 if reduced else .8
        if held:frame=3 if reduced else mini(2,int(age*24))
        else:
            if age>=duration:visible=false;queue_free();return
            frame=3 if reduced else mini(5,int(age*6/duration))
            opacity*=clampf((duration-age)/.06,0,1)
        queue_redraw()
    func _draw() -> void:
        var player:Node=owner_ref.get_ref()
        if valid_owner(player):paint_frame.call(self,family,frame,direction,size,opacity)
