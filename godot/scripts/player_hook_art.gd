extends RefCounted
## Only cosmetics: original traversal line and all action/hit logic stay owned by Player.
const POLICY:=preload("res://scripts/combat_visual_policy.gd")
const ATLAS:=preload("res://assets/vfx/player_hook/player_hook.png")
static func clear(player:Node,active_only:bool=false) -> void:
    if not player.is_inside_tree():return
    for node in player.get_tree().get_nodes_in_group(POLICY.SECONDARY_GROUP):
        if node.has_meta("player_hook_art") and node.owner_ref.get_ref()==player and (not active_only or node.kind!="latch"):node.visible=false;node.queue_free()
static func combat(player:Node2D) -> Node2D:return _active(player,false)
static func attached(player:Node2D) -> Node2D:
    latch(player,player.grapple_anchor.global_position)
    return _active(player,true)
static func stopped(player:Node2D,recover:bool) -> void:
    clear(player,true)
    if recover and is_instance_valid(player.grapple_anchor) and player.grapple_anchor.global_position.distance_to(player.global_position+Vector2(0,-42))<=36:latch(player,player.grapple_anchor.global_position)
static func _active(player:Node2D,traversal:bool) -> Node2D:
    clear(player,true)
    var node:=HookVisual.new();node.name="PlayerHookActive";node.kind="traversal" if traversal else "combat";node.owner_ref=weakref(player);node.z_index=59
    node.set_meta("player_hook_art",true);node.prepare(player)
    return node if POLICY.attach_secondary(player,node,&"motion",player) else null
static func latch(player:Node2D,point:Vector2) -> Node2D:
    if not player.is_inside_tree() or player.hp<=0 or player.death_timer>0:return null
    var node:=HookVisual.new();node.name="PlayerHookLatch";node.kind="latch";node.owner_ref=weakref(player);node.z_index=59;node.set_meta("player_hook_art",true);node.prepare(player)
    if not POLICY.attach_secondary(player.get_parent(),node,&"motion",player):return null
    node.global_position=point;return node
class HookVisual extends Node2D:
    var owner_ref:WeakRef
    var kind:="combat"
    var age:=0.0
    var sampled:=false
    var frame:=0
    var direction:=1
    var reduced:=false
    var opacity:=.8
    func prepare(player:Node) -> void:
        direction=player.facing;reduced=not bool(player.get_meta("accessibility",{}).get("flash_enabled",true));frame=3 if reduced else 0;opacity=.35 if reduced else .8
    func _process(delta:float) -> void:
        var player:Node=owner_ref.get_ref()
        if not is_instance_valid(player) or player.is_queued_for_deletion() or player.hp<=0 or player.death_timer>0 or player.hurt_timer>0 or player.ui_input_locked:visible=false;queue_free();return
        if kind=="traversal" and (player.grapple_timer<=0 or not is_instance_valid(player.grapple_anchor)):visible=false;queue_free();return
        if kind=="combat" and (player.current_attack!=&"hook_throw" or player.attack_timer<=0):visible=false;queue_free();return
        if sampled:age+=maxf(0,delta)
        else:sampled=true
        if kind!="traversal" and age>=.22:visible=false;queue_free();return
        reduced=not bool(player.get_meta("accessibility",{}).get("flash_enabled",true));frame=3 if reduced else (int(age*24)%6 if kind=="traversal" else mini(5,int(age*6/.22)));opacity=(.35 if reduced else .8)*(clampf((.22-age)/.05,0,1) if kind!="traversal" else 1)
        queue_redraw()
    func cel(row:int,index:int,rect:Rect2) -> void:draw_texture_rect_region(ATLAS,rect,Rect2(index*192,row*192,192,192),Color(1,1,1,opacity))
    func _draw() -> void:
        var player:Node=owner_ref.get_ref()
        if not is_instance_valid(player):return
        if kind=="latch":cel(2,frame,Rect2(-36,-36,72,72));return
        var origin:=Vector2(0,-42)
        var tip:Vector2=to_local(player.grapple_anchor.global_position) if kind=="traversal" and is_instance_valid(player.grapple_anchor) else Vector2(150*direction,-38)
        var offset:=tip-origin;var distance:=offset.length();var angle:=offset.angle();var count:=clampi(int(ceil(distance/32)),1,16)
        draw_set_transform(origin,angle)
        for i in count:
            var span:=distance/count
            cel(1,3 if reduced else int(age*20)%4,Rect2(i*span,-12,span,24))
        draw_set_transform(tip,angle);cel(0,frame,Rect2(-24,-24,48,48));draw_set_transform(Vector2.ZERO)
