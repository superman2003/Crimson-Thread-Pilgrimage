extends RefCounted
## The delivered ribbon is the existing dash-end burst. Current-pose ghosts stay original.
const POLICY := preload("res://scripts/combat_visual_policy.gd")
const ATLAS := preload("res://assets/vfx/player_dash/player_dash.png")
static func clear(player:Node) -> void:
    if not player.is_inside_tree():return
    for node in player.get_tree().get_nodes_in_group(POLICY.SECONDARY_GROUP):
        if node.has_meta("player_dash_art") and node.owner_ref.get_ref()==player:node.visible=false;node.queue_free()
static func finished(player:Node2D) -> Node2D:
    if not player.dash_unlocked or player.hp<=0 or player.death_timer>0:return null
    var from:Vector2=player.dash_start_position+Vector2(0,-34)
    var to:Vector2=player.global_position+Vector2(0,-34)
    if from.distance_to(to)<24:return null
    clear(player)
    var node:=Ribbon.new();node.name="PlayerDashRibbon";node.set_meta("player_dash_art",true)
    node.owner_ref=weakref(player);node.length=from.distance_to(to);node.from=from;node.to=to;node.z_index=56
    node.reduced=not bool(player.get_meta("accessibility",{}).get("flash_enabled",true));node.frame=3 if node.reduced else 0;node.opacity=.35 if node.reduced else .8
    if not POLICY.attach_secondary(player.get_parent(),node,&"motion",player):return null
    node.global_position=(from+to)/2;node.global_rotation=(to-from).angle()
    return node
class Ribbon extends Node2D:
    var owner_ref:WeakRef
    var length:=0.0
    var from:=Vector2.ZERO
    var to:=Vector2.ZERO
    var age:=0.0
    var sampled:=false
    var frame:=0
    var reduced:=false
    var opacity:=.8
    func _process(delta:float) -> void:
        var player:Node=owner_ref.get_ref()
        if not is_instance_valid(player) or player.is_queued_for_deletion() or player.death_timer>0 or player.hurt_timer>0 or player.ui_input_locked:visible=false;queue_free();return
        if sampled:age+=maxf(0,delta)
        else:sampled=true
        if age>=.20:visible=false;queue_free();return
        reduced=not bool(player.get_meta("accessibility",{}).get("flash_enabled",true))
        frame=3 if reduced else mini(5,int(age*6/.20));opacity=(.35 if reduced else .8)*clampf((.20-age)/.05,0,1)
        queue_redraw()
    func _draw() -> void:
        var progress:=clampf(age/.20,0,1)
        draw_texture_rect_region(ATLAS,Rect2(-length/2+length*progress,-32,length*(1-progress),64),Rect2(frame*256,0,256,128),Color(1,1,1,opacity))
