extends "res://scripts/player_dash_art_validation.gd"
## Explicit positioned component/unlock/damage fixtures. Every ability acceptance uses Input.
const ABILITY:=preload("res://scripts/player_ability_art.gd")
func abilitywork(family:String="") -> Array:
    return get_nodes_in_group(POLICY.SECONDARY_GROUP).filter(func(n):return n.has_meta("player_ability_art") and not n.is_queued_for_deletion() and (family.is_empty() or n.family==family))
func ability_setup(crest:String="crimson",direction:int=1) -> void:
    for action in ["lantern_phase","crown_resonance","aim_down","attack","jump"]:Input.action_release(action)
    await setup(crest,direction);player.thorn_downstrike_unlocked=true;player.lantern_phase_unlocked=true;player.crown_resonance_unlocked=true;player.resonance_cooldown=0
func pulse(action:String,count:int=1) -> void:
    Input.action_press(action);await frames(count);Input.action_release(action)
func downstrike() -> void:
    await pulse("jump",3);await frames(3);Input.action_press("aim_down");await pulse("attack");Input.action_release("aim_down")
func run() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
    root.size=Vector2i(960,540);root.content_scale_size=Vector2i(960,540);stage=Node2D.new();root.add_child(stage)
    var bg:=Polygon2D.new();bg.polygon=PackedVector2Array([Vector2.ZERO,Vector2(960,0),Vector2(960,540),Vector2(0,540)]);bg.color=Color("18242b");stage.add_child(bg)
    var floor_body:=StaticBody2D.new();floor_body.position=Vector2(480,380);var shape:=CollisionShape2D.new();var box:=RectangleShape2D.new();box.size=Vector2(2000,40);shape.shape=box;floor_body.add_child(shape);stage.add_child(floor_body)
    player=load("res://scenes/Player.tscn").instantiate()
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--ability-player-script="):player.set_script(load(arg.trim_prefix("--ability-player-script=")))
    stage.add_child(player);player.feel=null
    for child in player.get_children():
        if child is Camera2D:child.enabled=false
    build=BUILD.new();build.state.unlocked_crests=build.catalog.crests.keys();player.build_system=build;await frames(4)
    check(ABILITY.ATLAS.get_size()==Vector2(1536,576),"bounded atlas contains6/8/8 authored cels")
    for row in 3:
        var distinct:={}
        for i in (6 if row==0 else 8):
            var im:=ABILITY.ATLAS.get_image().get_region(Rect2i(i*192,row*192,192,192));check(not im.is_invisible(),"actual source cel");distinct[im.get_data().hex_encode().sha256_text()]=true
        check(distinct.size()==(6 if row==0 else 8),"distinct actual family frames")
    for crest in ["crimson","bell","salt"]:
        for direction in [-1,1]:
            await ability_setup(crest,direction);await downstrike()
            check(player.traversal_downstrike_active and player.velocity.y>=760 and player.attack_timer>0,crest+" actual down Input accepts unlocked original760 fall attack")
            check(abilitywork("downstrike").is_empty(),crest+" accepted airborne action has no fake ground impact")
            for i in 30:
                if player.is_on_floor():break
                await frames()
            check(player.is_on_floor() and abilitywork("downstrike").size()==1,crest+" actual landing owns authored ground burst")
            if not abilitywork("downstrike").is_empty():check(abilitywork("downstrike")[0].global_position.distance_to(player.global_position)<1 and abilitywork("downstrike")[0].z_index==34,crest+" actual ground anchor at original landing layer34")
            print("ABILITY_TRACE downstrike ",crest," direction=",direction," pos=",player.position," velocity=",player.velocity," hp=",player.hp," energy=",player.energy," attack=",player.attack_timer)
            await capture(crest+("_down_left" if direction<0 else "_down_right"));await frames(20);check(abilitywork().is_empty(),crest+" ground burst naturally retires")
            await ability_setup(crest,direction);Input.action_press("lantern_phase");await frames()
            check(player.phase_active and player.energy==12 and abilitywork("phase").size()==1,crest+" real phase acceptance costs original8 and creates one shell")
            await frames(10);check(player.phase_active and player.energy<12 and abilitywork("phase").size()==1,crest+" actual held phase drains original24 per second and retains one shell")
            var before:int=player.energy;var pos:Vector2=player.position;paused=true;await frames(3);check(player.energy==before and player.position==pos,crest+" pause freezes phase resources and motion");paused=false
            await capture(crest+("_phase_left" if direction<0 else "_phase_right"))
            Input.action_release("lantern_phase");await frames()
            check(not player.phase_active and abilitywork("phase").size()==1 and abilitywork("phase")[0].exiting,crest+" true release owns exit only after phase stopped")
            print("ABILITY_TRACE phase ",crest," direction=",direction," pos=",player.position," hp=",player.hp," energy=",player.energy," exceptions=",player.phase_exceptions.size())
            await capture(crest+("_phase_exit_left" if direction<0 else "_phase_exit_right"));await frames(15);check(abilitywork().is_empty(),crest+" exit shell retires")
            await ability_setup(crest,direction);await pulse("crown_resonance")
            check(player.energy==0 and player.resonance_cooldown>0 and String(player.active_skill.get("kind",""))=="resonance",crest+" real resonance input pays20 and keeps original action")
            check(abilitywork("resonance").size()==1 and player.attack_timer>0,crest+" accepted real action owns authored crown ring")
            await frames(4)
            if not abilitywork("resonance").is_empty():
                var elapsed:float=player.attack_duration-player.attack_timer
                var previous:=maxf(0,elapsed-1.0/60.0)
                var first_allowed:=0 if previous<player.attack_windup else (2 if previous<player.attack_windup+player.attack_active_time else 6)
                var last_allowed:=1 if elapsed<player.attack_windup else (5 if elapsed<player.attack_windup+player.attack_active_time else 7)
                check(abilitywork("resonance")[0].frame>=first_allowed and abilitywork("resonance")[0].frame<=last_allowed,crest+" crown material belongs to actual windup/active/recovery section")
            print("ABILITY_TRACE resonance ",crest," direction=",direction," pos=",player.position," hp=",player.hp," energy=",player.energy," attack=",player.attack_timer," cooldown=",player.resonance_cooldown)
            await capture(crest+("_resonance_left" if direction<0 else "_resonance_right"));await frames(40);check(abilitywork().is_empty(),crest+" actual resonance expiry retires ring")
    await ability_setup()
    var gate:=StaticBody2D.new();gate.position=Vector2(560,310);gate.add_to_group("phase_gate");var gate_shape:=CollisionShape2D.new();var gate_box:=RectangleShape2D.new();gate_box.size=Vector2(20,180);gate_shape.shape=gate_box;gate.add_child(gate_shape);stage.add_child(gate);await frames(3)
    Input.action_press("lantern_phase");Input.action_press("move_right");await frames(20);Input.action_release("move_right")
    check(player.phase_active and player.phase_exceptions.has(gate) and player.position.x>540,"actual held phase crosses real gate with original collision exception")
    Input.action_release("lantern_phase");await frames()
    check(not player.phase_active and player.phase_exceptions.is_empty() and absf(player.position.x-gate.position.x)>27,"original release clears exception and restores actual safe point outside gate")
    print("ABILITY_TRACE gate pos=",player.position," energy=",player.energy," exceptions=",player.phase_exceptions.size());gate.queue_free()
    await ability_setup()
    var targets:Array[Area2D]=[]
    for point in [Vector2(580,320),Vector2(680,320)]:
        var enemy:Area2D=load("res://scripts/enemy_actor.gd").new();enemy.configure({"id":"ability_material_target","hp":20,"kind":"moss_larva"},"",false,{});enemy.position=point;stage.add_child(enemy);enemy.set_physics_process(false);enemy.contact_timer=1000;targets.append(enemy)
    await frames(4);await pulse("crown_resonance")
    for i in 30:
        if player.skill_effect_started:break
        await frames()
    check(player.skill_effect_started and targets[0].hp<20 and targets[1].hp==20,"real resonance active frame keeps original inside/outside160 range")
    print("ABILITY_TRACE resonance_hits inside=",targets[0].hp," outside=",targets[1].hp," energy=",player.energy," attack=",player.attack_timer);await capture("resonance_actual_active_hit")
    for enemy in targets:enemy.queue_free()
    for action in ["lantern_phase","crown_resonance"]:
        for reason in ["locked","energy","hurt","dead","ui"]:
            await ability_setup()
            if reason=="locked":player.lantern_phase_unlocked=false;player.crown_resonance_unlocked=false
            if reason=="energy":player.energy=0
            if reason=="hurt":player.hurt_timer=1
            if reason=="dead":player.hp=0;player.death_timer=.9
            if reason=="ui":player.ui_input_locked=true
            await pulse(action,3);check(abilitywork().is_empty(),action+" "+reason+" rejection has no material")
    await ability_setup();player.resonance_cooldown=1;await pulse("crown_resonance",3);check(player.energy==20 and player.attack_timer<=0 and abilitywork().is_empty(),"real resonance cooldown rejects without flash or payment")
    await ability_setup();player.thorn_downstrike_unlocked=false;await downstrike();await frames(30);check(abilitywork("downstrike").is_empty(),"ordinary locked downslash is not thorn impact")
    await ability_setup();await pulse("jump",3);await frames(50);check(abilitywork("downstrike").is_empty(),"ordinary landing never implies downstrike")
    for family in ["phase","resonance"]:
        for lethal in [false,true]:
            await ability_setup();Input.action_press("lantern_phase" if family=="phase" else "crown_resonance");await frames();player.take_damage(player.max_hp+5 if lethal else 1,player.position+Vector2(80,0),false);Input.action_release("lantern_phase");Input.action_release("crown_resonance")
            check(abilitywork().is_empty(),family+" real accepted damage/death immediately clears shell without release burst")
    for family in ["phase","resonance","downstrike"]:
        await ability_setup();player.set_meta("accessibility",{"flash_enabled":false})
        if family=="downstrike":
            await downstrike()
            for i in 30:
                if player.is_on_floor():break
                await frames()
        else:Input.action_press("lantern_phase" if family=="phase" else "crown_resonance");await frames()
        check(abilitywork(family).size()==1 and abilitywork(family)[0].frame==3 and abilitywork(family)[0].opacity<=.35,"low-flash "+family+" bounded before first draw")
        await capture("reduced_"+family+"_first");player._reset_traversal_state();check(abilitywork().is_empty(),family+" reset clears without synthetic exit")
    await ability_setup();var fillers:Array[Node2D]=[]
    for i in 12:
        var node:=Node2D.new()
        if POLICY.attach_secondary(stage,node,&"state",stage):fillers.append(node)
    Input.action_press("lantern_phase");await frames();check(player.phase_active and player.energy==12 and abilitywork().is_empty(),"full state budget cannot reject real phase or payment");Input.action_release("lantern_phase")
    Input.action_release("lantern_phase");await frames(2);player.resonance_cooldown=0;player.energy=20;await pulse("crown_resonance");check(player.energy==0 and player.attack_timer>0 and abilitywork().is_empty(),"full state budget cannot reject actual resonance or payment")
    for node in fillers:node.queue_free()
    await ability_setup();fillers.clear()
    for i in 12:
        var node:=Node2D.new()
        if POLICY.attach_secondary(stage,node,&"motion",stage):fillers.append(node)
    await downstrike()
    for i in 30:
        if player.is_on_floor():break
        await frames()
    check(player.is_on_floor() and player.traversal_downstrike_active and abilitywork("downstrike").is_empty(),"full motion budget cannot reject actual downstrike landing")
    for node in fillers:node.queue_free()
    await ability_setup();await pulse("crown_resonance");RETIREMENT.retire_tree(stage);stage.queue_free();await frames(5);AUDIO._stream_cache.clear();AUDIO._npc_voice_cache.clear();check(get_nodes_in_group(POLICY.SECONDARY_GROUP).is_empty(),"exit releases all owned ability materials");check(await RETIREMENT.drain(self),"observable audio retirement")
    print("PLAYER_ABILITY_ART checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
