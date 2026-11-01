extends SceneTree
## Positioned component fixture: unlock/state setup and direct damage are explicit boundaries.
## All dash starts are real Input. This is not a natural acquisition playthrough.
const ART:=preload("res://scripts/player_dash_art.gd")
const POLICY:=preload("res://scripts/combat_visual_policy.gd")
const BUILD:=preload("res://scripts/build_system.gd")
const RETIREMENT:=preload("res://scripts/audio_retirement.gd")
const AUDIO:=preload("res://scripts/audio_director.gd")
var stage:Node2D
var player:CharacterBody2D
var build:RefCounted
var checks:=0
var failures:=0
var output:=""
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
    checks+=1
    if not ok:failures+=1;push_error("DASH_ART: "+label)
func frames(n:int=1) -> void:
    for i in n:await physics_frame;await process_frame
func artwork() -> Array:
    return get_nodes_in_group(POLICY.SECONDARY_GROUP).filter(func(n):return n.has_meta("player_dash_art") and not n.is_queued_for_deletion())
func ghosts() -> Array:
    return get_nodes_in_group(POLICY.SECONDARY_GROUP).filter(func(n):return n.name=="DashGhost" and not n.is_queued_for_deletion())
func capture(label:String) -> void:
    if output.is_empty():return
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"native "+label)
func setup(crest:String="crimson",direction:int=1) -> void:
    for action in ["dash","move_left","move_right"]:Input.action_release(action)
    player.ui_input_locked=false;player._reset_traversal_state();player.set_physics_process(false)
    build.state.crest=crest;player.apply_build_stats(build.profile());player.restore_at_save_point();player.position=Vector2(480,360);player.spawn_position=player.position;player.velocity=Vector2.ZERO
    player.dash_unlocked=true;player.facing=direction;player.sprite.flip_h=direction<0;player.arrival_guard_timer=0;player.debug_invulnerable=false;player.energy=20;player.set_meta("accessibility",{"flash_enabled":true});player.set_physics_process(true);await frames(4)
func dash() -> void:
    Input.action_press("dash");await frames();Input.action_release("dash")
func finish_dash() -> void:
    for i in 40:
        if player.dash_timer<=0:break
        await frames()
func run() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
    root.size=Vector2i(960,540);root.content_scale_size=Vector2i(960,540);stage=Node2D.new();root.add_child(stage)
    var bg:=Polygon2D.new();bg.polygon=PackedVector2Array([Vector2.ZERO,Vector2(960,0),Vector2(960,540),Vector2(0,540)]);bg.color=Color("18242b");stage.add_child(bg)
    var floor_body:=StaticBody2D.new();floor_body.position=Vector2(480,380);var shape:=CollisionShape2D.new();var box:=RectangleShape2D.new();box.size=Vector2(2000,40);shape.shape=box;floor_body.add_child(shape);stage.add_child(floor_body)
    player=load("res://scenes/Player.tscn").instantiate()
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--dash-player-script="):player.set_script(load(arg.trim_prefix("--dash-player-script=")))
    stage.add_child(player);player.feel=null
    for child in player.get_children():
        if child is Camera2D:child.enabled=false
    build=BUILD.new();build.state.unlocked_crests=build.catalog.crests.keys();player.build_system=build;await frames(4)
    check(ART.ATLAS.get_size()==Vector2(1536,128),"one bounded atlas with six real sidecar cels")
    var distinct:={}
    for i in 6:
        var im:=ART.ATLAS.get_image().get_region(Rect2i(i*256,0,256,128));check(not im.is_invisible(),"real authored cel "+str(i));distinct[im.get_data().hex_encode().sha256_text()]=true
    check(distinct.size()==6,"six distinct delivered frames")
    for crest in ["crimson","bell","salt"]:
        for direction in [-1,1]:
            await setup(crest,direction);var start:Vector2=player.global_position;var hp:int=player.hp;var energy:int=player.energy
            await dash()
            check(player.dash_timer>0 and is_equal_approx(player.velocity.x,player.dash_speed*direction) and player.velocity.y==0,crest+" actual Input starts unchanged dash velocity")
            check(player.dash_cooldown>0 and player.hp==hp and player.energy==energy,crest+" dash keeps resource and cooldown rules")
            check(artwork().is_empty() and not ghosts().is_empty(),crest+" active dash retains original current-pose ghosts, no early end ribbon")
            var timer:float=player.dash_timer;var point:Vector2=player.position;paused=true;await frames(3);check(player.dash_timer==timer and player.position==point,crest+" pause freezes dash itself");paused=false
            await finish_dash()
            check(artwork().size()==1,crest+" actual timer expiry creates one authored end ribbon")
            if artwork().size()==1:
                var n:Node2D=artwork()[0];check(n.z_index==56 and n.get_meta("secondary_category")==&"motion" and n.get_parent()==stage,crest+" original56 layer and shared motion budget")
                check(n.from==start+Vector2(0,-34) and signi(n.to.x-n.from.x)==direction and n.length>24 and n.length<=player.dash_speed*player.dash_time+1,crest+" actual traveled endpoints and facing")
                var age:float=n.age;paused=true;await frames(3);check(n.age==age,crest+" pause freezes authored end burst");paused=false
            print("DASH_TRACE ",crest," facing=",direction," x=",player.position.x-start.x," timer=",player.dash_timer," cooldown=",player.dash_cooldown," hp=",player.hp," energy=",player.energy)
            await capture(crest+("_left" if direction<0 else "_right"));await frames(20);check(artwork().is_empty(),crest+" end ribbon naturally retires")
    for reason in ["locked","cooldown","ui","hurt","dead"]:
        await setup()
        if reason=="locked":player.dash_unlocked=false
        if reason=="cooldown":player.dash_cooldown=1
        if reason=="ui":player.ui_input_locked=true
        if reason=="hurt":player.hurt_timer=1
        if reason=="dead":player.death_timer=.9;player.hp=0
        await dash();await frames(4);check(player.dash_timer<=0 and artwork().is_empty() and ghosts().is_empty(),reason+" rejected cast has neither ghosts nor ribbon")
    for lethal in [false,true]:
        await setup();await dash();player.take_damage(player.max_hp+5 if lethal else 1,player.position+Vector2(80,0),false)
        check(player.dash_timer==0 and player.hp==0 if lethal else player.dash_timer==0 and player.hp==player.max_hp-1,"explicit component damage interrupts original dash")
        await frames(16);check(artwork().is_empty(),"damage/death interruption cannot synthesize normal-end ribbon")
    await setup();player.set_meta("accessibility",{"flash_enabled":false});await dash();await finish_dash()
    check(artwork().size()==1 and artwork()[0].frame==3 and artwork()[0].opacity<=.35,"low-flash ribbon bounded before first draw")
    await capture("reduced_end_first")
    await setup();await dash();await finish_dash();player._reset_traversal_state();check(artwork().is_empty(),"reset immediately hides anchored ribbon")
    await setup();var fillers:Array[Node2D]=[]
    for i in 12:
        var node:=Node2D.new()
        if POLICY.attach_secondary(stage,node,&"motion",stage):fillers.append(node)
    var start:Vector2=player.position;await dash();await finish_dash()
    check(absf(player.position.x-start.x)>24 and artwork().is_empty(),"full motion budget preserves actual dash and suppresses only cosmetics")
    for node in fillers:node.queue_free()
    await setup();var wall:=StaticBody2D.new();wall.position=Vector2(500,300);var wall_shape:=CollisionShape2D.new();var wall_box:=RectangleShape2D.new();wall_box.size=Vector2(10,300);wall_shape.shape=wall_box;wall.add_child(wall_shape);stage.add_child(wall);await frames(3)
    await dash();await finish_dash();check(player.position.x<490 and artwork().is_empty(),"real adjacent wall blocks travel without fake full-distance ribbon");wall.queue_free()
    await setup();await dash();await finish_dash();RETIREMENT.retire_tree(stage);stage.queue_free();await frames(5);AUDIO._stream_cache.clear();AUDIO._npc_voice_cache.clear()
    check(get_nodes_in_group(POLICY.SECONDARY_GROUP).is_empty(),"scene exit releases motion budget and anchored ribbon")
    check(await RETIREMENT.drain(self),"observable audio retirement")
    print("PLAYER_DASH_ART checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
