extends SceneTree
## Positioned real Player/build fixture; direct damage here is explicitly not natural combat.
const ART:=preload("res://scripts/player_hurt_art.gd")
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
    if not ok:failures+=1;push_error("HURT_ART: "+label)
func frames(count:int=2) -> void:
    for i in count:await physics_frame;await process_frame
func artwork(family:String="") -> Array:
    return get_nodes_in_group(POLICY.SECONDARY_GROUP).filter(func(n):return n.has_meta("player_hurt_art") and not n.is_queued_for_deletion() and n.owner_ref.get_ref()==player and (family.is_empty() or n.family==family))
func family(name:String) -> bool:return artwork().size()==1 and artwork(name).size()==1
func capture(label:String) -> void:
    if output.is_empty():return
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"native "+label)
func setup(crest:String="crimson") -> void:
    for action in ["jump","move_left","move_right","bell_guard"]:Input.action_release(action)
    player.ui_input_locked=false;player.set_physics_process(false);player._reset_traversal_state()
    build.state.crest=crest;player.apply_build_stats(build.profile());player.restore_at_save_point()
    player.position=Vector2(480,360);player.spawn_position=Vector2(480,360);player.velocity=Vector2.ZERO
    player.debug_invulnerable=false;player.arrival_guard_timer=0;player.hurt_timer=0;player.death_timer=0;player.energy=20
    player.set_meta("accessibility",{"flash_enabled":true});player.set_physics_process(true);await frames(4)
func run() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
    root.size=Vector2i(960,540);root.content_scale_size=Vector2i(960,540)
    stage=Node2D.new();root.add_child(stage)
    var backdrop:=Polygon2D.new();backdrop.polygon=PackedVector2Array([Vector2.ZERO,Vector2(960,0),Vector2(960,540),Vector2(0,540)]);backdrop.color=Color("18242b");stage.add_child(backdrop)
    var floor_body:=StaticBody2D.new();floor_body.position=Vector2(480,380)
    var shape:=CollisionShape2D.new();var box:=RectangleShape2D.new();box.size=Vector2(2000,40);shape.shape=box;floor_body.add_child(shape);stage.add_child(floor_body)
    var paint:=Polygon2D.new();paint.polygon=PackedVector2Array([Vector2(0,360),Vector2(960,360),Vector2(960,540),Vector2(0,540)]);paint.color=Color("344048");stage.add_child(paint)
    player=load("res://scenes/Player.tscn").instantiate()
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--hurt-player-script="):player.set_script(load(argument.trim_prefix("--hurt-player-script=")))
    stage.add_child(player);player.feel=null
    for child in player.get_children():
        if child is Camera2D:child.enabled=false
    build=BUILD.new();build.state.unlocked_crests=build.catalog.crests.keys();build.state.mechanisms=["crimson","bell","salt"];player.build_system=build
    await frames(4)
    check(ART.ATLAS.get_size()==Vector2(1536,576),"one bounded atlas with22 authored cels")
    for row in 3:
        var distinct:={}
        for i in ART.COUNTS[row]:
            var image:=ART.ATLAS.get_image().get_region(Rect2i(ART.frame_rect(ART.FAMILIES[row],i)))
            check(not image.is_invisible(),ART.FAMILIES[row]+" real cel "+str(i));distinct[image.get_data().hex_encode().sha256_text()]=true
        check(distinct.size()==ART.COUNTS[row],ART.FAMILIES[row]+" distinct source frames")
    for crest in ["crimson","bell","salt"]:
        await setup(crest)
        var hp_before:int=player.hp;var origin:Vector2=player.global_position+Vector2(0,-34)
        var loss:=maxi(1,int(ceil(float(build.profile().get("damage_taken_mult",1)))))
        player.take_damage(1,player.global_position+Vector2(80,0),false)
        check(player.hp==hp_before-loss and player.energy==mini(player.max_energy,20+player.energy_on_damage) and is_equal_approx(player.hurt_timer,.35),crest+" accepted damage preserves HP, reward and original invulnerability")
        check(is_equal_approx(player.velocity.x,-260*float(build.profile().get("knockback_mult",1))) and is_equal_approx(player.velocity.y,-170),crest+" original knockback unchanged")
        check(family("hurt_snap"),crest+" accepted hit gets distinct authored snap")
        var id:int=artwork()[0].get_instance_id() if family("hurt_snap") else 0
        if family("hurt_snap"):check(artwork()[0].get_parent()==stage and artwork()[0].global_position==origin and artwork()[0].direction==-1 and artwork()[0].z_index==75,crest+" old world-hit anchor and actual75 layer preserved")
        player.take_damage(2,player.global_position-Vector2(80,0),false)
        check(player.hp==hp_before-loss and (artwork().is_empty() or artwork()[0].get_instance_id()==id),crest+" invulnerability rejection cannot spawn duplicate material")
        await frames(3);await capture(crest+"_hurt")
        if family("hurt_snap"):check(artwork()[0].global_position==origin,crest+" snap stays at accepted hit point while actor recoils")
        await setup(crest);var energy_before:int=player.energy
        player.take_damage(player.max_hp+5,player.global_position+Vector2(80,0),false)
        check(player.hp==0 and is_equal_approx(player.death_timer,.9) and player.velocity==Vector2.ZERO and player.energy==energy_before,crest+" lethal path retains original death lock and no hurt reward")
        check(family("death_unweave") and artwork("hurt_snap").is_empty(),crest+" lethal pose replaces snap with death only")
        player.take_damage(1,player.global_position,false)
        check(family("death_unweave") and is_equal_approx(player.death_timer,.9),crest+" dead rejection cannot restart death")
        await frames(18);await capture(crest+"_death")
        check(player.sprite.animation==&"death" and player.death_timer>0,crest+" original death animation is still active")
        if family("death_unweave"):check(artwork()[0].frame==mini(7,int((1-player.death_timer/.9)*8)),crest+" material follows real death clock")
        var timer:float=player.death_timer
        paused=true;await frames(4);check(is_equal_approx(timer,player.death_timer),crest+" pause freezes death clock");paused=false
        for i in 80:
            if player.respawn_reveal_timer>0:break
            await frames(1)
        check(player.hp==player.max_hp and player.energy==0 and player.respawn_reveal_timer>0,crest+" actual hard respawn restores profile maximum and zero energy")
        check(family("respawn_weave") and artwork("death_unweave").is_empty(),crest+" actual reveal owns only new weave")
        await frames(3);await capture(crest+"_respawn")
        await frames(15);check(artwork().is_empty() and player.respawn_reveal_timer<=0,crest+" actual reveal expiry removes all body material")
    for reason in ["debug","arrival","zero","block"]:
        await setup();player.bell_guard_unlocked=true
        if reason=="debug":player.debug_invulnerable=true
        if reason=="arrival":player.arrival_guard_timer=1
        if reason=="block":player._try_guard()
        var hp_before:int=player.hp
        player.take_damage(0 if reason=="zero" else 1,player.global_position+Vector2(player.facing*60,0))
        check(player.hp==hp_before and artwork().is_empty(),reason+" rejected damage never plays hurt/death")
    await setup();player.restore_at_save_point();check(artwork().is_empty(),"ordinary shrine restore is not death weaving")
    player.respawn_at(Vector2(480,360));check(artwork().is_empty(),"nondeath position reset is not hard respawn weaving")
    await setup();player.set_meta("accessibility",{"flash_enabled":false});player.take_damage(1,player.global_position+Vector2(80,0),false)
    check(family("hurt_snap") and artwork()[0].frame==3 and artwork()[0].opacity<=.4,"low-flash snap bounded before first process/draw")
    await capture("reduced_hurt_first")
    await setup();player.set_meta("accessibility",{"flash_enabled":false});player.take_damage(player.max_hp+5,player.global_position,false)
    check(family("death_unweave") and artwork()[0].frame==3 and artwork()[0].opacity<=.35,"low-flash death bounded before first process/draw")
    await capture("reduced_death_first")
    for i in 80:
        if player.respawn_reveal_timer>0:break
        await frames(1)
    check(family("respawn_weave") and artwork()[0].frame==3 and artwork()[0].opacity<=.35,"low-flash actual reveal bounded from creation")
    await capture("reduced_respawn_first")
    await setup();POLICY.clear_secondary(player);var fillers:Array[Node2D]=[]
    for i in 12:
        var node:=Node2D.new();var admitted:=POLICY.attach_secondary(stage,node,&"state",stage);check(admitted,"state budget fill")
        if admitted:fillers.append(node)
    var hp_before:int=player.hp;player.take_damage(1,player.global_position+Vector2(80,0),false)
    check(player.hp<hp_before and artwork().is_empty(),"full cosmetic budget cannot reject real damage")
    player.hurt_timer=0;player.take_damage(player.max_hp+5,player.global_position,false)
    check(player.hp==0 and player.death_timer>0 and artwork().is_empty(),"full cosmetic budget cannot reject death")
    for i in 80:
        if player.respawn_reveal_timer>0:break
        await frames(1)
    check(player.hp==player.max_hp and player.energy==0 and artwork().is_empty(),"full budget cannot reject actual respawn")
    for node in fillers:node.queue_free()
    await setup();player.take_damage(1,player.global_position+Vector2(80,0),false);player._reset_traversal_state()
    check(artwork().is_empty(),"reset retires world-anchored hurt too")
    await setup();player.take_damage(player.max_hp+5,player.global_position,false);player._reset_traversal_state()
    check(artwork().is_empty(),"reset retires death body material")
    RETIREMENT.retire_tree(stage);stage.queue_free();await frames(5);AUDIO._stream_cache.clear();AUDIO._npc_voice_cache.clear()
    check(get_nodes_in_group(POLICY.SECONDARY_GROUP).is_empty(),"scene teardown releases all budget nodes")
    check(await RETIREMENT.drain(self),"observable fixture audio retirement")
    print("PLAYER_HURT_ART checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
