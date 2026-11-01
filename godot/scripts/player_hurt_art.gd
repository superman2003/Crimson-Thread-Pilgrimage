extends RefCounted
## Accepted damage and the Player's existing death/reveal clocks own these cosmetics.
const POLICY := preload("res://scripts/combat_visual_policy.gd")
const ATLAS := preload("res://assets/vfx/player_hurt/player_hurt.png")
const FAMILIES := ["hurt_snap","death_unweave","respawn_weave"]
const COUNTS := [6,8,8]
static func frame_rect(family:String,frame:int) -> Rect2:
    var row:=FAMILIES.find(family)
    return Rect2(frame*192,row*192,192,192) if row>=0 and frame>=0 and frame<COUNTS[row] else Rect2()
static func paint(host:Node2D,family:String,frame:int,direction:int,alpha:float) -> void:
    var size:=94.0 if family=="hurt_snap" else (124.0 if family=="death_unweave" else 118.0)
    host.draw_set_transform(Vector2.ZERO,0,Vector2(direction,1))
    host.draw_texture_rect_region(ATLAS,Rect2(-size/2,-size/2,size,size),frame_rect(family,frame),Color(1,1,1,alpha))
    host.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
static func clear(player:Node) -> void:
    if player.is_inside_tree():
        for node in player.get_tree().get_nodes_in_group(POLICY.SECONDARY_GROUP):
            if node.has_meta("player_hurt_art") and node.owner_ref.get_ref()==player:
                node.visible=false;node.queue_free()
    else:
        for node in player.get_children():
            if node.has_meta("player_hurt_art"):node.visible=false;node.queue_free()
static func hurt(player:Node2D,source_position:Vector2) -> Node2D:
    var away:=signi(player.global_position.x-source_position.x)
    return _attach(player,"hurt_snap",away if away!=0 else -player.facing)
static func died(player:Node2D) -> Node2D:return _attach(player,"death_unweave",player.facing)
static func respawned(player:Node2D) -> Node2D:return _attach(player,"respawn_weave",player.facing)
static func _attach(player:Node2D,family:String,direction:int) -> Node2D:
    if not player.is_inside_tree() or player.is_queued_for_deletion():return null
    clear(player)
    var node:=HurtVisual.new()
    node.set_meta("player_hurt_art",true);node.name="PlayerHurtArt_"+family
    node.owner_ref=weakref(player);node.family=family;node.direction=direction;node.paint_frame=paint
    node.timer_total=float(player.death_timer) if family=="death_unweave" else (float(player.respawn_reveal_timer) if family=="respawn_weave" else .25)
    node.z_index=75
    node.reduced=not bool(player.get_meta("accessibility",{}).get("flash_enabled",true));node.update_opacity()
    if node.reduced:node.frame=3
    # Hurt is a world hit anchor, matching the old detached thread sparks.
    var host:Node=player.get_parent() if family=="hurt_snap" else player
    if not POLICY.attach_secondary(host,node,&"state",player):return null
    if family=="hurt_snap":node.global_position=player.global_position+Vector2(0,-34)
    else:node.position=Vector2(0,-42)
    return node
class HurtVisual extends Node2D:
    var owner_ref:WeakRef
    var family:="hurt_snap"
    var direction:=1
    var timer_total:=.25
    var frame:=0
    var opacity:=.8
    var age:=0.0
    var sampled:=false
    var reduced:=false
    var paint_frame:Callable
    func update_opacity() -> void:opacity=(.4 if reduced else .8) if family=="hurt_snap" else (.35 if reduced else .65)
    func valid_owner(player:Node) -> bool:
        if not is_instance_valid(player) or player.is_queued_for_deletion():return false
        if family=="death_unweave":return player.death_timer>0
        if family=="respawn_weave":return player.death_timer<=0 and player.respawn_reveal_timer>0 and player.hp>0
        return player.death_timer<=0 and player.hp>0
    func _process(delta:float) -> void:
        var player:Node=owner_ref.get_ref()
        if not valid_owner(player):visible=false;queue_free();return
        reduced=not bool(player.get_meta("accessibility",{}).get("flash_enabled",true));update_opacity()
        if family=="hurt_snap":
            if sampled:age+=maxf(0,delta)
            else:sampled=true
            if age>=.25:visible=false;queue_free();return
            frame=3 if reduced else mini(5,int(age*6/.25))
            opacity*=clampf((.25-age)/.06,0,1)
        else:
            var remaining:float=player.death_timer if family=="death_unweave" else player.respawn_reveal_timer
            frame=3 if reduced else mini(7,int(clampf(1-remaining/maxf(.001,timer_total),0,1)*8))
        queue_redraw()
    func _draw() -> void:
        var player:Node=owner_ref.get_ref()
        if valid_owner(player):paint_frame.call(self,family,frame,direction,opacity)
