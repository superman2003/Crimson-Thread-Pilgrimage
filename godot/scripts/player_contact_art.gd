extends RefCounted
## Cosmetic call tokens correlate one receiver invocation, including reentrant/same-frame hits.
const POLICY:=preload("res://scripts/combat_visual_policy.gd")
const ATLAS:=preload("res://assets/vfx/player_contact/player_contact.png")
const CALL_META:=&"contact_art_call_serial"
static func begin_receiver_call(receiver:Node) -> int:
    var serial:=int(receiver.get_meta(CALL_META,0))+1
    receiver.set_meta(CALL_META,serial)
    return serial
static func reduced_for(tree:SceneTree) -> bool:
    var player:=tree.get_first_node_in_group("player")
    return player!=null and not bool(player.get_meta("accessibility",{}).get("flash_enabled",true))
static func clear_player(player:Node) -> void:
    if not player.is_inside_tree():return
    for group in [POLICY.CONTACT_GROUP,POLICY.ACTION_TRACE_GROUP]:
        for node in player.get_tree().get_nodes_in_group(group):
            if int(node.get_meta("contact_player_id",0))==player.get_instance_id():node.visible=false;node.queue_free()
    for node in player.get_tree().get_nodes_in_group(POLICY.SECONDARY_GROUP):
        if node.has_meta("delivered_skill_art") and node.owner_ref.get_ref()==player:node.visible=false;node.queue_free()
static func clear_receiver(receiver:Node) -> void:
    if not receiver.is_inside_tree():return
    for node in receiver.get_tree().get_nodes_in_group(POLICY.CONTACT_GROUP):
        if node.has_meta("delivered_contact_art") and int(node.get_meta("receiver_id",0))==receiver.get_instance_id():node.visible=false;node.queue_free()
static func receiver_hit(receiver:Node2D,direction:int,serial:int) -> Node2D:
    if not receiver.is_inside_tree():return null
    var node:=ReceiverContact.new();node.name="HitSpark";node.owner_ref=weakref(receiver);node.paint=paint_contact;node.read_reduced=reduced_for;node.strike_direction=Vector2(direction,0);node.length=20 if receiver.is_boss else 17
    node.reduced_flash=reduced_for(receiver.get_tree());node.set_meta("delivered_contact_art",true);node.set_meta("receiver_id",receiver.get_instance_id());node.set_meta("receiver_call",serial)
    if not POLICY.attach_contact(receiver,node):return null
    node.position=Vector2(-24*direction,-30)
    return node
static func refine_receiver(receiver:Node2D,serial:int,point:Vector2,direction:Vector2,_animation:StringName,_preferences:Dictionary) -> Node2D:
    if not is_instance_valid(receiver) or not receiver.is_inside_tree():return null
    for node in receiver.get_tree().get_nodes_in_group(POLICY.CONTACT_GROUP):
        if node.has_meta("delivered_contact_art") and not node.is_queued_for_deletion() and int(node.get_meta("receiver_id",0))==receiver.get_instance_id() and int(node.get_meta("receiver_call",-1))==serial:
            node.global_position=point;node.strike_direction=direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
            node.refined=true
            return node
    # A rejected/cancelled/budget-dropped receiver event must not become a new mark.
    return null
static func frame_index(age:float,lifetime:float,reduced:bool) -> int:return 3 if reduced else mini(5,int(maxf(0,age)*6/maxf(.001,lifetime)))
static func paint_polygon(host:Node2D,row:int,frame:int,vertices:PackedVector2Array,colors:PackedColorArray,unit_uv:PackedVector2Array) -> void:
    var uv:=PackedVector2Array()
    for point in unit_uv:uv.append((Vector2(frame*192,row*192)+point*192)/Vector2(1152,576))
    host.draw_polygon(vertices,colors,uv,ATLAS)
static func paint_line(host:Node2D,frame:int,from:Vector2,to:Vector2,width:float,color:Color) -> void:
    var normal:=(to-from).normalized().orthogonal()*width/2
    paint_polygon(host,1,frame,PackedVector2Array([from-normal,to-normal,to+normal,from+normal]),PackedColorArray([color]),PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]))
static func paint_contact(host:Node2D,age:float,lifetime:float,direction:Vector2,length:float,reduced:bool) -> void:
    var alpha:float=(.46 if reduced else .76)*clampf(1-age/maxf(.001,lifetime),0,1);var size:=length*2
    host.draw_set_transform(Vector2.ZERO,direction.angle());host.draw_texture_rect_region(ATLAS,Rect2(-size/2,-size/2,size,size),Rect2(frame_index(age,lifetime,reduced)*192,384,192,192),Color(1,1,1,alpha));host.draw_set_transform(Vector2.ZERO)
static func supported_slash(player:Node) -> bool:
    return String(player.active_skill.get("id","")) in ["cleave","crosscut"] or (player.active_skill.is_empty() and player.current_attack==&"attack_2" and player._crest()=="bell")
static func skill_slash(player:Node2D) -> Node2D:
    if player.attack_timer<=0 or player.hp<=0 or not supported_slash(player):return null
    var node:=SkillSlash.new();node.name="SkillSlashVfx";node.owner_ref=weakref(player);node.direction=player.current_attack_direction;node.position=player._attack_center_offset();node.z_index=60;node.reduced=not bool(player.get_meta("accessibility",{}).get("flash_enabled",true));node.set_meta("delivered_skill_art",true)
    var sprite:=Sprite2D.new();sprite.name="DeliveredSlashCel";sprite.texture=ATLAS;sprite.region_enabled=true;sprite.scale=Vector2.ONE*(132.0/192.0);node.art=sprite;node.add_child(sprite);node.update_frame()
    # Controller plus drawable retain the original two-unit secondary cost.
    return node if POLICY.attach_secondary(player,node,&"state",player) else null
class ReceiverContact extends Node2D:
    var owner_ref:WeakRef
    var strike_direction:=Vector2.RIGHT
    var length:=17.0
    var reduced_flash:=false
    var refined:=false
    var age:=0.0
    var sampled:=false
    var paint:Callable
    var read_reduced:Callable
    func _process(delta:float) -> void:
        if is_queued_for_deletion():return
        var receiver:Node=owner_ref.get_ref()
        if not is_instance_valid(receiver) or receiver.is_queued_for_deletion():visible=false;queue_free();return
        if receiver.combat_visuals_paused:return
        if sampled:age+=maxf(0,delta)
        else:sampled=true
        if age>=.16:visible=false;queue_free();return
        reduced_flash=bool(read_reduced.call(get_tree()));queue_redraw()
    func _draw() -> void:paint.call(self,age,.16,strike_direction,length,reduced_flash)
class SkillSlash extends Node2D:
    var owner_ref:WeakRef
    var direction:=Vector2.RIGHT
    var art:Sprite2D
    var reduced:=false
    var age:=0.0
    var sampled:=false
    func update_frame() -> void:
        art.region_rect=Rect2((3 if reduced else mini(5,int(age*6/.22)))*192,0,192,192);art.modulate=Color(1,1,1,(.35 if reduced else .8)*clampf((.22-age)/.05,0,1));rotation=direction.angle()
    func _process(delta:float) -> void:
        var player:Node=owner_ref.get_ref()
        if not is_instance_valid(player) or player.is_queued_for_deletion() or player.hp<=0 or player.hurt_timer>0 or player.ui_input_locked or player.attack_timer<=0:visible=false;queue_free();return
        if sampled:age+=maxf(0,delta)
        else:sampled=true
        if age>=.22:visible=false;queue_free();return
        reduced=not bool(player.get_meta("accessibility",{}).get("flash_enabled",true));update_frame()
