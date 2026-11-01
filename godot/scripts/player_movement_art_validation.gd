extends SceneTree
## Positioned component fixture with actual Input and enabled production physics.
const ART := preload("res://scripts/player_movement_art.gd")
const POLICY := preload("res://scripts/combat_visual_policy.gd")
const RETIREMENT := preload("res://scripts/audio_retirement.gd")
const AUDIO := preload("res://scripts/audio_director.gd")
var player: CharacterBody2D
var stage: Node2D
var checks:=0
var failures:=0
var output:=""
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error("MOVEMENT_ART: "+label)
func frames(count:int=2) -> void:
    for i in count:await physics_frame;await process_frame
func artwork(family:String="") -> Array:
    return player.get_children().filter(func(n):return n.has_meta("player_movement_art") and not n.is_queued_for_deletion() and (family.is_empty() or n.family==family))
func capture(label:String) -> void:
    if output.is_empty():return
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"native "+label)
func setup(x:float=250) -> void:
    for action in ["jump","move_left","move_right"]:Input.action_release(action)
    player.set_physics_process(false);player._reset_traversal_state();player.position=Vector2(x,440);player.velocity=Vector2.ZERO
    player.ui_input_locked=false;player.hurt_timer=0;player.death_timer=0;player.arrival_guard_timer=0
    player.double_jump_unlocked=true;player.wall_grip_unlocked=true;player.dash_unlocked=false
    player.set_meta("accessibility",{"flash_enabled":true});player.set_physics_process(true);await frames(5)
    ART.clear(player)
func jump(hold:int=3) -> void:
    Input.action_press("jump");await frames(hold);Input.action_release("jump")
func land() -> void:
    for i in 150:
        if player.is_on_floor():return
        await frames(1)
    check(false,"actual jump returns to fixture ground")
func contact(side:int) -> void:
    await setup(450 if side==1 else 510)
    Input.action_press("move_right" if side==1 else "move_left");await frames(6)
    await jump(3)
    for i in 60:
        if player.wall_sliding:return
        await frames(1)
    check(player.wall_sliding,"actual wall sliding reached")
func run() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
    root.size=Vector2i(960,540);root.content_scale_size=Vector2i(960,540)
    stage=Node2D.new();root.add_child(stage)
    var backdrop:=Polygon2D.new();backdrop.polygon=PackedVector2Array([Vector2.ZERO,Vector2(960,0),Vector2(960,540),Vector2(0,540)]);backdrop.color=Color("18242b");stage.add_child(backdrop)
    for config in [[Vector2(480,460),Vector2(2000,40)],[Vector2(480,230),Vector2(20,420)]]:
        var body:=StaticBody2D.new();body.position=config[0]
        var shape:=CollisionShape2D.new();var rect:=RectangleShape2D.new();rect.size=config[1];shape.shape=rect;body.add_child(shape);stage.add_child(body)
        var paint:=Polygon2D.new();paint.polygon=PackedVector2Array([config[0]-config[1]/2,config[0]+Vector2(config[1].x/2,-config[1].y/2),config[0]+config[1]/2,config[0]+Vector2(-config[1].x/2,config[1].y/2)]);paint.color=Color("344048");stage.add_child(paint)
    player=load("res://scenes/Player.tscn").instantiate()
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--movement-player-script="):player.set_script(load(argument.trim_prefix("--movement-player-script=")))
    stage.add_child(player);player.feel=null;player.build_system=null
    for node in player.get_children():
        if node is Camera2D:node.enabled=false
    await frames(4)
    check(ART.ATLAS.get_size()==Vector2(1152,576),"single bounded eighteen-cel atlas")
    for family in ART.FAMILIES:
        var distinct:={}
        for i in 6:
            var image:=ART.ATLAS.get_image().get_region(Rect2i(ART.frame_rect(family,i)))
            check(not image.is_invisible(),family+" real cel "+str(i));distinct[image.get_data().hex_encode().sha256_text()]=true
        check(distinct.size()==6,family+" distinct authored six frames")
    await setup();player.double_jump_unlocked=false
    await jump(3);check(artwork("double_jump").is_empty(),"ordinary first jump does not emit air-jump art")
    await frames(3);var locked_velocity:float=player.velocity.y;await jump(2)
    check(artwork("double_jump").is_empty() and player.velocity.y>locked_velocity,"locked second press has no visual or added impulse")
    await setup();Input.action_press("jump");await frames(10)
    check(player.air_jump_available and artwork("double_jump").is_empty(),"holding ordinary jump never consumes the air jump or creates its fan")
    Input.action_release("jump")
    await setup();await jump(3);await frames(3);await jump(2)
    check(not player.air_jump_available and player.velocity.y < -550,"actual second input spends the unchanged -650 air impulse")
    check(artwork("double_jump").size()==1,"true air consumption creates exactly one authored fan")
    var jump_id:int=artwork("double_jump")[0].get_instance_id() if artwork("double_jump").size()==1 else 0
    await frames(3);await capture("double_jump")
    await frames(2);var before:float=player.velocity.y;await jump(2)
    check(player.velocity.y>before and artwork("double_jump").size()<=1,"third press cannot add impulse or duplicate fan")
    if artwork("double_jump").size()==1:check(artwork("double_jump")[0].get_instance_id()==jump_id and artwork("double_jump")[0].z_index==58,"same trace stays on original58 layer")
    var age:float=artwork("double_jump")[0].age if artwork("double_jump").size()==1 else -1
    paused=true;await frames(5)
    check(artwork("double_jump").size()==1 and is_equal_approx(artwork("double_jump")[0].age,age),"pause freezes the existing motion trace")
    paused=false;await land();await frames(20)
    for heavy in [false,true]:
        await setup();player.facing=-1 if heavy else 1;await jump(26 if heavy else 3);await land()
        check(artwork("land").size()==1,"real airborne-to-ground edge emits one landing")
        if artwork("land").size()==1:
            var node:Node=artwork("land")[0]
            check(node.heavy==heavy and (node.fall_speed>=620)==heavy,"landing follows actual pre-contact speed and original620 threshold")
            check(node.z_index==34 and not node.z_as_relative and node.direction==player.facing,"grounded footprint retains34 layer and contact facing")
            var id:int=node.get_instance_id();await frames(2)
            check(artwork("land").size()==1 and artwork("land")[0].get_instance_id()==id,"standing contact cannot retrigger land")
        await frames(2);await capture("land_heavy" if heavy else "land_soft")
        await frames(20);check(artwork("land").is_empty(),"landing tail expires")
    for side in [-1,1]:
        await contact(side)
        check(artwork("wall_grip").size()==1,"actual sliding edge owns one contact tuft")
        var id:int=artwork("wall_grip")[0].get_instance_id() if artwork("wall_grip").size()==1 else 0
        if artwork("wall_grip").size()==1:check(artwork("wall_grip")[0].held and artwork("wall_grip")[0].direction==side and artwork("wall_grip")[0].position==Vector2(side*17,-42) and artwork("wall_grip")[0].z_index==58,"wall tuft mirrors actual collision side and body contact")
        await frames(6);check(artwork("wall_grip").size()==1 and artwork("wall_grip")[0].get_instance_id()==id,"sustained grip does not allocate every frame")
        await capture("wall_left" if side<0 else "wall_right")
        await jump(2)
        check(player.velocity.x*side<0 and player.velocity.y < -550 and player.air_jump_available,"actual wall jump retains rebound and does not spend air jump")
        check(artwork("wall_grip").size()==1 and not artwork("wall_grip")[0].held and artwork("wall_grip")[0].direction==side,"wall jump retires hold and snapshots actual contact side")
        await capture("wall_jump_left" if side<0 else "wall_jump_right")
        Input.action_release("move_right" if side>0 else "move_left");await frames(18)
        check(artwork("wall_grip").is_empty(),"wall departure leaves no held residue")
    await contact(1);player.ui_input_locked=true;await frames(2)
    check(artwork("wall_grip").is_empty(),"UI cancellation clears live contact presentation")
    await setup(450);Input.action_press("move_right");await frames(6)
    check(player.is_on_floor() and artwork("wall_grip").is_empty(),"grounded wall contact cannot start grip art")
    await contact(1);ART.clear(player)
    var state_fillers:Array[Node2D]=[]
    for i in 12:
        var n:=Node2D.new();var admitted:=POLICY.attach_secondary(stage,n,&"state",stage);check(admitted,"state budget setup")
        if admitted:state_fillers.append(n)
    ART.wall_state(player)
    check(artwork("wall_grip").is_empty() and int(player.get_meta(ART.SIDE_META,0))==1,"full state budget latches actual contact edge")
    await frames(3)
    for n in state_fillers:n.queue_free()
    await frames(3)
    check(artwork("wall_grip").is_empty(),"budget becoming available cannot cause per-frame contact reallocation")
    Input.action_release("move_right");await frames(2);Input.action_press("move_right");await frames(2)
    check(artwork("wall_grip").size()==1,"actual release and recontact admits one new tuft")
    player.set_meta("accessibility",{"flash_enabled":false});ART.clear(player);ART.wall_state(player)
    check(artwork("wall_grip").size()==1 and artwork("wall_grip")[0].frame==3 and artwork("wall_grip")[0].opacity<=.4,"low-flash real contact initialized before first process")
    await capture("reduced_wall_first")
    await setup();player.wall_grip_unlocked=false;player.position=Vector2(450,440);Input.action_press("move_right");await frames(6);await jump(3);await frames(14)
    check(not player.wall_sliding and artwork("wall_grip").is_empty(),"locked grip does not emit contact art")
    Input.action_release("move_right")
    await setup();player.set_meta("accessibility",{"flash_enabled":false});await jump(3);await frames(3)
    # Actual second input starts the effect during physics. Component direct hook below checks pre-tree defaults.
    await jump(2);await capture("reduced_double_jump")
    if artwork("double_jump").size()==1:check(artwork("double_jump")[0].frame==3 and artwork("double_jump")[0].opacity<=.4,"low-flash air fan stays on stable bounded cel")
    ART.clear(player);var first_double:Node2D=ART.double_jump(player)
    check(first_double!=null and first_double.frame==3 and first_double.opacity<=.4,"low-flash air fan initialized before first process")
    await capture("reduced_double_first")
    ART.clear(player);var first:Node2D=ART.land(player,700)
    check(first!=null and first.frame==3 and first.opacity<=.4,"low-flash landing initialized before first process")
    await capture("reduced_land_first")
    await setup();POLICY.clear_secondary(player);var fillers:Array[Node2D]=[]
    for i in 12:
        var node:=Node2D.new();var admitted:=POLICY.attach_secondary(stage,node,&"motion",stage);check(admitted,"motion budget setup")
        if admitted:fillers.append(node)
    await jump(3);await frames(3);await jump(2)
    check(not player.air_jump_available and artwork().is_empty(),"full shared motion budget cannot alter consumed air jump")
    for node in fillers:node.queue_free()
    await setup();await jump(3);await frames(3);await jump(2);player._reset_traversal_state()
    check(artwork().is_empty(),"reset retires every new movement trace")
    await setup();await jump(3);await frames(3);await jump(2);player.death_timer=.5;await frames(2)
    check(artwork().is_empty(),"death retires every new movement trace")
    RETIREMENT.retire_tree(stage);stage.queue_free();await frames(5);AUDIO._stream_cache.clear();AUDIO._npc_voice_cache.clear()
    check(get_nodes_in_group(POLICY.SECONDARY_GROUP).is_empty(),"room teardown releases shared budget")
    check(await RETIREMENT.drain(self),"observed audio retirement")
    print("PLAYER_MOVEMENT_ART checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
