extends "res://scripts/player_dash_art_validation.gd"
## Explicit positioned real Player/EnemyActor component fixtures; all casts use Input.
## Direct receiver calls below are labeled event boundaries, not natural World combat.
const CONTACT:=preload("res://scripts/player_contact_art.gd")
const MELEE:=preload("res://scripts/player_melee_feedback.gd")
var legacy:=false
var enemy_script:Script
var enemies:Array[Area2D]=[]
class ReentrantCurrent extends "res://scripts/enemy_actor.gd":
    var reenter:=false
    func _play_sfx(_key:String,_volume:float=-6,_pitch:float=1,_priority:int=1) -> void:
        if reenter:reenter=false;take_hit(1,-1)
class ReentrantBaseline extends "res://../artifacts/v04_contact_material/pre_enemy_actor.gd":
    var reenter:=false
    func _play_sfx(_key:String,_volume:float=-6,_pitch:float=1,_priority:int=1) -> void:
        if reenter:reenter=false;take_hit(1,-1)
func marks(receiver:Node=null) -> Array:
    return get_nodes_in_group(POLICY.CONTACT_GROUP).filter(func(n):return n.has_meta("delivered_contact_art") and not n.is_queued_for_deletion() and (receiver==null or int(n.get_meta("receiver_id",0))==receiver.get_instance_id()))
func blades() -> Array:return get_nodes_in_group(POLICY.ACTION_TRACE_GROUP).filter(func(n):return n.has_meta("delivered_blade_art") and not n.is_queued_for_deletion())
func slashes() -> Array:return get_nodes_in_group(POLICY.SECONDARY_GROUP).filter(func(n):return n.has_meta("delivered_skill_art") and not n.is_queued_for_deletion())
func make_enemy(point:Vector2,hp:int=40,reentrant:bool=false) -> Area2D:
    var enemy:Area2D=(ReentrantBaseline.new() if legacy else ReentrantCurrent.new()) if reentrant else enemy_script.new()
    enemy.configure({"id":"material_target_"+str(enemies.size()),"hp":hp,"kind":"moss_larva"},"",false,{});enemy.position=point;stage.add_child(enemy);enemy.set_physics_process(false);enemy.contact_timer=1000;enemies.append(enemy);return enemy
func prepare(crest:String="crimson",direction:int=1,skill:String="cleave") -> void:
    for action in ["attack","skill_1","aim_up","aim_down","jump"]:Input.action_release(action)
    for enemy in enemies:
        if is_instance_valid(enemy):RETIREMENT.retire_tree(enemy);enemy.queue_free()
    enemies.clear()
    for node in get_nodes_in_group(POLICY.CONTACT_GROUP):node.queue_free()
    for child in stage.get_children():
        if child.get_script()!=null and child.get_script().resource_path=="res://scripts/player_tool_effect.gd":RETIREMENT.retire_tree(child);child.queue_free()
    await setup(crest,direction)
    build.state.unlocked_skills=build.catalog.skills.keys();build.state.mechanisms=["crimson","bell","salt"];build.cooldowns.clear()
    var rows:Array=build.catalog.crests[crest].slot_layout.thread_skill;var slot:=0
    if not rows[0].compatible.has(skill):slot=1
    check(bool(build.select_skill(skill,slot).get("ok",false)),crest+" actual legal skill slot "+skill)
    player.apply_build_stats(build.profile());player.energy=100;player.skill_cooldown=0;await frames(4)
func pulse(action:String,count:int=1) -> void:Input.action_press(action);await frames(count);Input.action_release(action)
func run() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
        if arg=="--contact-legacy":legacy=true
    enemy_script=load("res://../artifacts/v04_contact_material/pre_enemy_actor.gd" if legacy else "res://scripts/enemy_actor.gd")
    root.size=Vector2i(960,540);root.content_scale_size=Vector2i(960,540);stage=Node2D.new();root.add_child(stage)
    var bg:=Polygon2D.new();bg.polygon=PackedVector2Array([Vector2.ZERO,Vector2(960,0),Vector2(960,540),Vector2(0,540)]);bg.color=Color("18242b");stage.add_child(bg)
    var floor_body:=StaticBody2D.new();floor_body.position=Vector2(480,380);var shape:=CollisionShape2D.new();var box:=RectangleShape2D.new();box.size=Vector2(2000,40);shape.shape=box;floor_body.add_child(shape);stage.add_child(floor_body)
    player=load("res://scenes/Player.tscn").instantiate()
    if legacy:player.set_script(load("res://../artifacts/v04_contact_material/baseline_player_execution.gd"))
    stage.add_child(player);player.feel=null
    for child in player.get_children():
        if child is Camera2D:child.enabled=false
    build=BUILD.new();build.state.unlocked_crests=build.catalog.crests.keys();player.build_system=build;await frames(4)
    check(CONTACT.ATLAS.get_size()==Vector2(1152,576),"bounded atlas has18 true source cels")
    for row in 3:
        var distinct:={}
        for i in 6:
            var im:=CONTACT.ATLAS.get_image().get_region(Rect2i(i*192,row*192,192,192));check(not im.is_invisible(),"authored actual source cel");distinct[im.get_data().hex_encode().sha256_text()]=true
        check(distinct.size()==6,"all six family cels remain distinct")
    for crest in ["crimson","bell","salt"]:
        for direction in [-1,1]:
            await prepare(crest,direction);player.energy=20;var enemy:=make_enemy(Vector2(480+direction*75,320));await frames(3);await pulse("attack")
            for i in 30:
                if enemy.hp<40:break
                await frames()
            check(enemy.hp<40 and player.energy>20,crest+" real basic Input accepts production HP loss and original energy reward")
            check(marks(enemy).size()==1 and marks().size()==1,crest+" actual Player and receiver sources make one event mark")
            if marks(enemy).size()==1:
                var mark:Node2D=marks(enemy)[0];check(mark.refined and mark.global_position==enemy.global_position+Vector2(0,-28) and mark.strike_direction==player.current_attack_direction.normalized(),crest+" exact receiver event only refines original anchor/direction")
                check(mark.z_index==80 and mark.length==17 and mark.age<.16,crest+" refinement preserves receiver size/lifetime and contact80")
                var age:float=mark.age;paused=true;await frames(3);check(mark.age==age,crest+" pause freezes contact age");paused=false
            check(slashes().size()==1 if crest=="bell" else blades().size()==1,crest+" actual heavy/basic action receives its specific delivered material")
            print("CONTACT_TRACE basic ",crest," direction=",direction," enemy_hp=",enemy.hp," knockback=",enemy.knockback_velocity," hp=",player.hp," energy=",player.energy," damage=",player.attack_damage," duration=",player.attack_duration," windup=",player.attack_windup," active=",player.attack_active_time," range=",player.attack_range," height=",player.attack_height)
            await capture(crest+("_basic_left" if direction<0 else "_basic_right"));await frames(25);check(marks().is_empty() and slashes().is_empty() and blades().is_empty(),crest+" finite materials retire")
        for skill in ["cleave","crosscut","needle","snare","ward","shockwave"]:
            await prepare(crest,1,skill);var cost:int=build.selected_skill().energy_cost;await pulse("skill_1")
            check(String(player.active_skill.get("id",""))==skill and player.energy==100-cost,crest+" actual Input uses legal "+skill+" and original cost")
            for i in 40:
                if player.attack_vfx_started:break
                await frames()
            check(slashes().size()==1 if skill in ["cleave","crosscut"] else slashes().is_empty(),crest+" slash material does not replace incompatible "+skill)
            if not slashes().is_empty():check(slashes()[0].get_meta("secondary_units")==2 and slashes()[0].z_index==60,crest+" source slash keeps original two-unit budget and state60")
            print("CONTACT_TRACE skill ",crest," id=",skill," hp=",player.hp," energy=",player.energy," damage=",player.attack_damage," duration=",player.attack_duration," windup=",player.attack_windup," active=",player.attack_active_time," range=",player.attack_range," height=",player.attack_height)
            if crest=="crimson" and skill in ["cleave","crosscut","needle","snare","ward","shockwave"]:await capture("skill_"+skill)
            await frames(35)
    await prepare();var twin_a:=make_enemy(Vector2(555,320));var twin_b:=make_enemy(Vector2(555,320));await frames(3);await pulse("attack")
    for i in 30:
        if twin_a.hp<40 and twin_b.hp<40:break
        await frames()
    check(twin_a.hp==39 and twin_b.hp==39 and marks(twin_a).size()==1 and marks(twin_b).size()==1 and marks().size()==2,"actual same-frame Player swing preserves both same-position receiver events")
    print("CONTACT_TRACE twin first=",twin_a.hp," second=",twin_b.hp," energy=",player.energy);await capture("actual_same_position_targets")
    await prepare();var guarded:=make_enemy(Vector2(555,320));guarded.ai_profile={"front_guard":true};guarded.active_attack={"type":"guard"};guarded.state="windup";guarded.direction=-1;await frames(3);await pulse("attack");await frames(12)
    check(guarded.hp==40 and player.energy==100 and marks().is_empty(),"actual guarded Player Input preserves rejection and emits no contact")
    # Explicit direct receiver-only/fatal/guard boundaries; not natural World proof.
    for reason in ["zero","guard","dying","nonresident"]:
        await prepare();var enemy:=make_enemy(Vector2(555,320));await frames(3)
        if reason=="guard":enemy.ai_profile={"front_guard":true};enemy.active_attack={"type":"guard"};enemy.state="windup";enemy.direction=-1
        if reason=="dying":enemy.dying=true
        if reason=="nonresident":enemy.set_meta("world_residency_active",false)
        enemy.take_hit(0 if reason=="zero" else 1,1);check(enemy.hp==40 and marks().is_empty(),reason+" production rejection creates no contact material")
    await prepare();var enemy:=make_enemy(Vector2(555,320));await frames(3);enemy.take_hit(1,1)
    check(enemy.hp==39 and marks(enemy).size()==1 and not marks(enemy)[0].refined,"receiver-only hit retains one independent spark without Player callback")
    var same_frame:int=Engine.get_physics_frames()
    # Same receiver and frame, distinct invocations must stay distinct.
    enemy.take_hit(1,-1);check(enemy.hp==38 and marks(enemy).size()==2 and Engine.get_physics_frames()==same_frame,"same-frame independent calls on one receiver are not merged")
    if marks(enemy).size()==2:
        var original_position:Vector2=enemy.position;enemy.position+=Vector2(9,-4);await frames()
        check(marks(enemy).all(func(n):return n.get_parent()==enemy and n.global_position==enemy.to_global(n.position)),"receiver-only marks follow actual receiver transform across process frames")
        enemy.position=original_position;await frames()
        enemy.visible=false;check(marks(enemy).all(func(n):return not n.is_visible_in_tree()),"receiver hidden inherits mark visibility")
        enemy.visible=true;enemy.process_mode=Node.PROCESS_MODE_DISABLED
        var frozen_age:float=marks(enemy)[0].age;await frames(2)
        check(marks(enemy)[0].age==frozen_age,"receiver disabled inherits mark processing suspension")
        enemy.process_mode=Node.PROCESS_MODE_INHERIT
    await capture("receiver_only_distinct_hits")
    var other:=make_enemy(enemy.position);await frames(2);other.take_hit(1,1);check(marks(other).size()==1 and marks(enemy).size()==2,"different receiver at identical coordinates is not merged")
    print("CONTACT_TRACE distinct hp=",enemy.hp," other=",other.hp)
    if marks(enemy).size()==2:
        var receiver_mark:Node2D=marks(enemy)[0];var original_point:Vector2=receiver_mark.global_position;var original_age:float=receiver_mark.age;var original_length:float=receiver_mark.length
        check(CONTACT.refine_receiver(enemy,9999,Vector2.ZERO,Vector2.UP,&"attack_1",{})==null and receiver_mark.global_position==original_point,"unknown receiver event cannot steal a nearby legitimate mark")
        var token:int=receiver_mark.get_meta("receiver_call");var refined:Node2D=CONTACT.refine_receiver(enemy,token,original_point+Vector2(2,3),Vector2.UP,&"attack_2",{})
        check(refined==receiver_mark and refined.age==original_age and refined.length==original_length,"exact event refinement changes only anchor/direction and never restarts/resizes")
        enemy._set_combat_visuals_paused(true);var paused_age:float=receiver_mark.age;await frames(3);check(receiver_mark.age==paused_age,"receiver UI pause freezes global contact just like original combat tween");enemy._set_combat_visuals_paused(false)
    await prepare();enemy=make_enemy(Vector2(555,320),2);await frames(3);await pulse("skill_1")
    for i in 30:
        if enemy.hp<=0:break
        await frames()
    check(enemy.hp<=0 and enemy.dying and marks(enemy).size()==1,"actual paid Input fatal accepted hit keeps one correlated spark")
    await capture("actual_fatal_hit")
    print("CONTACT_TRACE fatal hp=",enemy.hp," dying=",enemy.dying," energy=",player.energy," knockback=",enemy.knockback_velocity)
    await prepare();enemy=make_enemy(Vector2(555,320),40,true);await frames(3);enemy.reenter=true;await pulse("attack")
    for i in 30:
        if enemy.hp<40:break
        await frames()
    check(enemy.hp==38 and marks(enemy).size()==2,"reentrant receiver call preserves two legitimate accepted events")
    if marks(enemy).size()==2:
        var refined:=marks(enemy).filter(func(n):return n.refined);check(refined.size()==1 and int(refined[0].get_meta("receiver_call"))==1 and marks(enemy).filter(func(n):return int(n.get_meta("receiver_call"))==2 and not n.refined).size()==1,"Player corrects the exact outer token, never the newer reentrant event")
    print("CONTACT_TRACE reentrant hp=",enemy.hp," energy=",player.energy," knockback=",enemy.knockback_velocity)
    await capture("reentrant_distinct_hits")
    await prepare();player.set_meta("accessibility",{"flash_enabled":false});enemy=make_enemy(Vector2(555,320));await frames(3);await pulse("attack")
    for i in 30:
        if enemy.hp<40:break
        await frames()
    check(marks(enemy).size()==1 and marks(enemy)[0].reduced_flash,"low-flash receiver mark is bounded before first draw/refinement")
    check(not blades().is_empty() and blades()[0].reduced_flash,"low-flash blade retains same measured geometry")
    await capture("reduced_contact_first")
    await prepare("crimson",1,"cleave");player.set_meta("accessibility",{"flash_enabled":false});await pulse("skill_1")
    for i in 30:
        if not slashes().is_empty():break
        await frames()
    check(slashes().size()==1 and slashes()[0].art.region_rect.position.x==576 and slashes()[0].art.modulate.a<=.35,"low-flash slash begins on bounded static cel")
    await capture("reduced_skill_first");player._reset_traversal_state();check(slashes().is_empty() and blades().is_empty(),"reset immediately hides owned slash and blade")
    await prepare();await pulse("jump",3);await frames(3)
    var level:Node2D=load("res://scripts/main_level.gd").new();level.player=player;level.world_loading=false
    level._hazard({"id":"contact_pogo_probe","kind":"spikes","rect":[440,326,80,20],"damage":1,"message":"component"})
    var spikes:Area2D=level.get_child(0);level.remove_child(spikes);stage.add_child(spikes);await frames(2)
    Input.action_press("aim_down");await pulse("attack");Input.action_release("aim_down")
    for i in 20:
        if player.pogo_chain>0:break
        await frames()
    check(player.pogo_chain>0 and marks().filter(func(n):return int(n.get_meta("receiver_id",0))==0).size()==1,"actual spike pogo keeps receiverless Player contact material")
    print("CONTACT_TRACE pogo chain=",player.pogo_chain," hp=",player.hp," energy=",player.energy," velocity=",player.velocity);await capture("actual_spike_pogo_contact");spikes.queue_free();level.free()
    await prepare();var fillers:Array[Node2D]=[]
    for i in 12:
        var node:=Node2D.new()
        if POLICY.attach_contact(stage,node):fillers.append(node)
    enemy=make_enemy(Vector2(555,320));await frames(3);await pulse("attack")
    for i in 30:
        if enemy.hp<40:break
        await frames()
    check(enemy.hp<40 and marks().is_empty(),"full contact budget rejects only cosmetics, never accepted damage")
    for node in fillers:node.queue_free()
    await prepare("bell");fillers.clear()
    for i in 12:
        var node:=Node2D.new()
        if POLICY.attach_secondary(stage,node,&"state",stage):fillers.append(node)
    enemy=make_enemy(Vector2(555,320));await frames(3);await pulse("attack")
    for i in 30:
        if enemy.hp<40:break
        await frames()
    check(enemy.hp<40 and slashes().is_empty(),"full state budget preserves actual heavy attack damage")
    for node in fillers:node.queue_free()
    RETIREMENT.retire_tree(stage);stage.queue_free();await frames(5);AUDIO._stream_cache.clear();AUDIO._npc_voice_cache.clear();check(get_nodes_in_group(POLICY.CONTACT_GROUP).is_empty() and get_nodes_in_group(POLICY.ACTION_TRACE_GROUP).is_empty() and get_nodes_in_group(POLICY.SECONDARY_GROUP).is_empty(),"scene exit releases all three effect budgets");check(await RETIREMENT.drain(self),"observable audio retirement")
    print("PLAYER_CONTACT_ART checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
