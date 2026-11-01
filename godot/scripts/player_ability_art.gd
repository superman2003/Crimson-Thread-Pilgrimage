extends RefCounted
## Original action state owns all progress. Presentation never changes mechanics.
const POLICY:=preload("res://scripts/combat_visual_policy.gd")
const ATLAS:=preload("res://assets/vfx/player_ability/player_ability.png")
static func resonance_frame(duration:float,remaining:float,windup:float,active:float) -> int:
    var elapsed:=maxf(0,duration-remaining)
    if elapsed<windup:return mini(1,int(elapsed/maxf(.001,windup)*2))
    if elapsed<windup+active:return 2+mini(3,int((elapsed-windup)/maxf(.001,active)*4))
    return 6+mini(1,int((elapsed-windup-active)/maxf(.001,duration-windup-active)*2))
static func clear(player:Node,family:String="") -> void:
    if not player.is_inside_tree():return
    for node in player.get_tree().get_nodes_in_group(POLICY.SECONDARY_GROUP):
        if node.has_meta("player_ability_art") and node.owner_ref.get_ref()==player and (family.is_empty() or node.family==family):node.visible=false;node.queue_free()
static func downstrike(player:Node2D) -> Node2D:
    if not player.thorn_downstrike_unlocked or not player.traversal_downstrike_active or player.attack_timer<=0:return null
    return _attach(player,"downstrike",false)
static func phase_enter(player:Node2D) -> Node2D:
    if not player.lantern_phase_unlocked or not player.phase_active:return null
    return _attach(player,"phase",true)
static func phase_stop(player:Node2D) -> void:
    if not player.is_inside_tree():return
    for node in player.get_tree().get_nodes_in_group(POLICY.SECONDARY_GROUP):
        if node.has_meta("player_ability_art") and node.owner_ref.get_ref()==player and node.family=="phase" and not node.exiting:
            if player.hp<=0 or player.death_timer>0 or player.hurt_timer>0 or player.ui_input_locked:node.visible=false;node.queue_free()
            else:node.exiting=true;node.age=0;node.sampled=false;node.frame=3 if node.reduced else 6
static func resonance(player:Node2D) -> Node2D:
    if not player.crown_resonance_unlocked or player.attack_timer<=0 or String(player.active_skill.get("kind",""))!="resonance":return null
    return _attach(player,"resonance",true)
static func _attach(player:Node2D,family:String,body:bool) -> Node2D:
    clear(player,family)
    var node:=AbilityVisual.new();node.set_meta("player_ability_art",true);node.name="PlayerAbilityArt_"+family;node.owner_ref=weakref(player);node.family=family;node.direction=player.facing;node.sample_resonance=resonance_frame
    node.z_index=34 if family=="downstrike" else 60;node.reduced=not bool(player.get_meta("accessibility",{}).get("flash_enabled",true));node.frame=3 if node.reduced else 0;node.opacity=.35 if node.reduced else .7
    var host:Node=player if body else player.get_parent()
    if not POLICY.attach_secondary(host,node,&"state" if body else &"motion",player):return null
    if body:node.position=Vector2(0,-42)
    else:node.global_position=player.global_position
    return node
class AbilityVisual extends Node2D:
    var owner_ref:WeakRef
    var family:="downstrike"
    var direction:=1
    var age:=0.0
    var sampled:=false
    var exiting:=false
    var reduced:=false
    var frame:=0
    var opacity:=.7
    var sample_resonance:Callable
    func _process(delta:float) -> void:
        var player:Node=owner_ref.get_ref()
        if not is_instance_valid(player) or player.is_queued_for_deletion() or player.hp<=0 or player.death_timer>0 or player.hurt_timer>0 or player.ui_input_locked:visible=false;queue_free();return
        if sampled:age+=maxf(0,delta)
        else:sampled=true
        reduced=not bool(player.get_meta("accessibility",{}).get("flash_enabled",true));opacity=.35 if reduced else .7
        if family=="downstrike":
            if age>=.25:visible=false;queue_free();return
            frame=3 if reduced else mini(5,int(age*6/.25));opacity*=clampf((.25-age)/.05,0,1)
        elif family=="phase":
            direction=player.facing
            if exiting:
                if age>=.18:visible=false;queue_free();return
                frame=3 if reduced else mini(7,6+int(age*2/.18));opacity*=clampf((.18-age)/.06,0,1)
            elif not player.phase_active:visible=false;queue_free();return
            else:frame=3 if reduced else (mini(1,int(age*2/.10)) if age<.10 else 2+int((age-.10)*16)%4)
        else:
            if player.attack_timer<=0 or String(player.active_skill.get("kind",""))!="resonance":visible=false;queue_free();return
            frame=3 if reduced else int(sample_resonance.call(player.attack_duration,player.attack_timer,player.attack_windup,player.attack_active_time))
        queue_redraw()
    func _draw() -> void:
        var row:=0 if family=="downstrike" else (1 if family=="phase" else 2);var size:=138.0 if row==0 else (132.0 if row==1 else 148.0)
        draw_set_transform(Vector2.ZERO,0,Vector2(direction,1));draw_texture_rect_region(ATLAS,Rect2(-size/2,-size*(164.0/192.0 if row==0 else .5),size,size),Rect2(frame*192,row*192,192,192),Color(1,1,1,opacity));draw_set_transform(Vector2.ZERO)
