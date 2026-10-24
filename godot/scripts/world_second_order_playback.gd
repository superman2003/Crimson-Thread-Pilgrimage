extends "res://scripts/world_damage_route_playback.gd"
## Fresh second-order campaign: only production Input, no grants/position writes.
## Parent _run/old seeds are never called. Initial probe has no gameplay input.
const RETIREMENT = preload("res://scripts/audio_retirement.gd")
const AUDIO = preload("res://scripts/audio_director.gd")
var order_stage := "probe"
var order_output := ""
var order_save := ""
var order_input := ""
var order_input_sha := ""
var order_input_proof := ""
var parent_proof: Dictionary = {}
var order_air_down_target := ""
var order_conversations := 0
var order_spear_approach := false
var order_spear_cast := false
var order_spear_cast_frame := -100
var order_camp_guard_approach := false
var order_camp_guard_cast := false
func _run() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--order-stage="):order_stage = arg.trim_prefix("--order-stage=")
        if arg.begins_with("--output="):order_output = arg.trim_prefix("--output=")
        if arg.begins_with("--input-checkpoint="):order_input = arg.trim_prefix("--input-checkpoint=")
        if arg.begins_with("--input-sha="):order_input_sha = arg.trim_prefix("--input-sha=")
        if arg.begins_with("--input-proof="):order_input_proof = arg.trim_prefix("--input-proof=")
    order_save = "user://second_order_%d.json" % OS.get_process_id()
    _check(order_stage in ["probe","first_lamp","canal_aqueduct","archive_obsidian_camp","camp_restore","camp_prepare","greenhouse_entry","earned_restore"],"explicit bounded fresh-start stage")
    _check(not FileAccess.file_exists(order_save),"private new-game save does not exist")
    var continuing := order_stage in ["canal_aqueduct","archive_obsidian_camp","camp_restore","camp_prepare","greenhouse_entry","earned_restore"]
    if continuing:
        var raw := FileAccess.get_file_as_bytes(order_input)
        var hash := HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(raw)
        _check(not raw.is_empty() and hash.finish().hex_encode()==order_input_sha,"continuation uses exact preceding earned checkpoint bytes")
        parent_proof = JSON.parse_string(FileAccess.get_file_as_string(order_input_proof))
        _check(String(parent_proof.get("save_sha256",""))==order_input_sha and int(parent_proof.get("pid",-1))!=OS.get_process_id(),"source proof and independent PID match the real preceding stage")
        if failures>0:await finish_order();return
        var file := FileAccess.open(order_save,FileAccess.WRITE);file.store_buffer(raw);file.close()
    scene = load("res://scenes/World.tscn").instantiate()
    scene.world_resume = continuing
    scene.world_save_path = order_save
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene = scene
    scene.player.ability_action.connect(order_ability_observed)
    await _tick(15)
    var initial := snapshot()
    print("SECOND_ORDER_INITIAL "+JSON.stringify(initial))
    if not order_output.is_empty():write_json("initial.json",initial)
    if continuing:
        _check(scene.initial_region_ready and String(scene.config.id)==String(parent_proof.region) and scene.active_save_point_id==String(parent_proof.checkpoint),"new PID restores actual source region and normal shrine")
        _check(scene.currency_count==int(parent_proof.wallet) and same_json(scene.inventory_counts,parent_proof.inventory) and same_json(scene.build_system.serialize(),parent_proof.build),"new PID restores earned wallet inventory and complete build without grants")
        _check(scene.player.hp==int(parent_proof.hp) and scene.player.energy==int(parent_proof.energy) and not scene.player.debug_invulnerable,"source HP and thread restore with damage enabled")
        if failures>0:await finish_order();return
        if order_stage == "canal_aqueduct":await canal_aqueduct()
        elif order_stage == "archive_obsidian_camp":await archive_obsidian_camp()
        elif order_stage == "camp_prepare":await camp_prepare()
        elif order_stage == "greenhouse_entry":await greenhouse_entry()
        elif order_stage=="earned_restore":
            _check(same_json(scene.story_flags,parent_proof.flags) and scene.player.max_hp==int(parent_proof.max_hp) and scene.player.max_energy==int(parent_proof.max_energy),"independent production World restores exact earned flags and resource limits")
        else:
            _check(scene.active_save_point_id=="save_ch05_lower_loop" and int(scene.inventory_counts.get("lantern_phase",0))==1,"independent production World restores naturally earned camp and phase")
            _check(scene.world_state.data.regions.get("demo_ch04_broken_string_greenhouse",{}).get("visited_rooms",{}).is_empty(),"independent disk restore still records C5 before first C4")
        await finish_order()
        return
    _check(scene.initial_region_ready and String(scene.config.id)=="demo_ch01_moss_bell_court","new game starts in original C1")
    _check(scene.currency_count==0 and scene.player.hp==5 and scene.player.max_hp==5 and scene.player.energy==100 and scene.player.max_energy==100,"unmodified fresh HP thread limits and zero wallet")
    _check(scene.inventory_counts=={"thread_burst":1,"menders_right":1,"moss_lens":1},"exact original starting tools and relic only")
    _check(not scene.player.debug_invulnerable and not SHOP_RUNTIME.shows_position(scene) and not SHOP_RUNTIME.owns_tool(scene,"compass"),"damage enabled with no navigation position or compass")
    for ability in scene.WORLD_ABILITIES:_check(int(scene.inventory_counts.get(ability,0))==0,"no pre-granted permanent ability "+String(ability))
    if failures>0 or order_stage=="probe":await finish_order();return
    for point in [Vector2(410,3400),Vector2(640,3452),Vector2(870,3532),Vector2(1130,3612),Vector2(1420,3692),Vector2(1710,3752)]:
        await _walk(point,"fresh C1 drainage to first authored lamp")
        if failures>0:await finish_order();return
    await _world_interact()
    _check(scene.active_save_point_id=="save_first_bell","real F rests at original first bell lamp")
    _check(FileAccess.file_exists(order_save),"normal shrine produced actual save bytes")
    if failures==0:export_checkpoint("fresh new game, actual input to first C1 lamp")
    await finish_order()
func canal_aqueduct() -> void:
    await _walk(Vector2(1790,3752),"normal first-lamp departure to rain pipe")
    if failures>0:return
    await _interact("moss_rain_pipe","demo_ch02_rain_foundry_canal",Vector2(330,720))
    if failures>0:return
    for point in [Vector2(620,812),Vector2(960,880),Vector2(1350,836),Vector2(1700,920)]:
        await _walk(point,"second-order C2 normal repair route")
        if failures>0:return
    _check(int(scene.inventory_counts.get("silk_wall_grip",0))==1,"wall grip comes from actual authored pickup")
    print("SECOND_ORDER_MISSED_MAP_SELLER "+JSON.stringify({"wallet":scene.currency_count,"map_owned":JOURNAL.owned(scene.story_flags,String(scene.config.id)),"quill_owned":SHOP_RUNTIME.owns_tool(scene,"quill"),"reason":"continue the original route without buying the optional map on the first pass"}))
    for point in [Vector2(2040,1000),Vector2(2320,1080),Vector2(2540,1160),Vector2(2730,1160),Vector2(2990,1240)]:
        await _walk(point,"second-order C2 to actual aqueduct shrine",false,point.x==2730.0)
        if failures>0:return
    await _world_interact()
    _check(scene.active_save_point_id=="save_ch02_aqueduct" and scene.player.hp==scene.player.max_hp and scene.player.energy==scene.player.max_energy,"actual aqueduct F rest preserves natural income and refills by shrine only")
    _check(not int(scene.inventory_counts.get("double_thread_jump",0))>0 and not int(scene.inventory_counts.get("lantern_phase",0))>0,"later-region abilities remain unearned at the first canal shrine")
    if failures==0:export_checkpoint("actual C1 lamp bytes -> original rain passage -> authored wall-grip pickup -> actual aqueduct shrine")
func archive_obsidian_camp() -> void:
    # Return along previously reached C2 platforms; no positioning or transport shortcut.
    for point in [Vector2(2730,1160),Vector2(2540,1160),Vector2(2320,1080),Vector2(2040,1000),Vector2(1700,920),Vector2(1350,836)]:
        if point.x==1700.0:
            if not await order_walk_only(point):return # Stay under the actual overhead clapper on the connecting slope.
        else:await _walk(point,"actual aqueduct return to archive riser",false,point.x in [2730.0,2540.0])
        if failures>0:return
    await _interact("rain_archive_riser","demo_ch03_saltwhite_archive",Vector2(430,2580))
    if failures>0:return
    for point in [Vector2(700,2570),Vector2(1050,2620),Vector2(1430,2556),Vector2(1760,2612),Vector2(2090,2548),Vector2(1930,2442),Vector2(1740,2350),Vector2(1640,2240),Vector2(1440,2240)]:
        await _walk(point,"natural archive candle climb to double thread jump",false,point.x in [1640.0,1440.0])
        if failures>0:return
    _check(int(scene.inventory_counts.get("double_thread_jump",0))==1 and scene.player.double_jump_unlocked,"second permanent movement ability is obtained at the actual archive source")
    _check(scene.world_state.data.regions.get("demo_ch04_broken_string_greenhouse",{}).get("visited_rooms",{}).is_empty(),"fresh route has not entered C4 before its military branch")
    var supports_ok := true
    for probe in [["candle_east_walk",2000.0,2184.0],["candle_gap_stand",2317.0,2158.0]]:
        var query := PhysicsRayQueryParameters2D.create(Vector2(probe[1],probe[2]-6),Vector2(probe[1],probe[2]+34),1,[scene.player.get_rid()])
        var hit: Dictionary = scene.get_world_2d().direct_space_state.intersect_ray(query)
        var correct: bool = not hit.is_empty() and absf(hit.position.y-float(probe[2]))<3 and hit.normal.y<-.9
        if not correct:supports_ok = false
        print("SECOND_ORDER_AUTHORED_SUPPORT "+JSON.stringify({"id":probe[0],"x":probe[1],"expected_floor":probe[2],"hit":str(hit),"correct":correct,"collision_ready":scene._world_collision_ready()}))
    _check(supports_ok,"both original candle shipping supports exist as actual collision floors")
    if not supports_ok:return
    if not await order_hold_duel("E03",1440.0):return
    if not await order_leap(Vector2(1640,2240),999,"single jump to candle east edge"):return
    if not await order_candle_opening():return
    if not await order_clear():return
    if not await order_walk_only(Vector2(2090,2184)):return
    if not await order_walk_only(Vector2(2340,2158)):return
    await _interact("upgrade_archive_obsidian_branch_a","demo_ch05_obsidian_pilgrim_road",Vector2(710,2672))
    if failures>0:return
    print("SECOND_ORDER_REGION_ORDER C1>C2>C3>C5; C4 not yet entered")
    _check(not int(scene.inventory_counts.get("thorn_downstrike",0))>0 and not bool(scene.story_flags.get("boss_down_ch04",false)),"C5 military branch is actually reached before greenhouse downstrike or Boss")
    # The original C5 lower road and free service shaft, using actual jump inputs.
    for point in [Vector2(1100,2764),Vector2(1450,2708),Vector2(2000,2772),Vector2(2290,2716),Vector2(2590,2768),Vector2(3030,2830),Vector2(3330,2760)]:
        order_air_down_target = "E02" if point.x==2000.0 else ""
        var lower_landed := await order_leap(point,35,"original lower pilgrimage road")
        order_air_down_target = "";Input.action_release("aim_down");Input.action_release("attack")
        if not lower_landed:return
        if point.x==1100.0:
            if not await order_hold_duel("E01",1100.0):return
        elif point.x!=3030.0 and point.x!=3330.0 and not await order_clear():return
        if point.x==1450.0:
            if not await order_walk_only(Vector2(1650,2708)):return
    for point in [Vector2(3470,2652),Vector2(3280,2544),Vector2(3470,2436),Vector2(3280,2328),Vector2(3470,2220),Vector2(3280,2112),Vector2(3460,2004)]:
        if not await order_leap(point,999 if point.y==2004.0 else 20,"original free shaft ascent"):return
    if not await order_leap(Vector2(3220,1868),999,"free shaft upper dock"):return
    if not await order_walk_only(Vector2(2800,1868)):return
    if not await order_walk_only(Vector2(2510,2608)):return
    for point in [Vector2(2150,2496),Vector2(1800,2390),Vector2(1510,2286),Vector2(1300,2178),Vector2(900,2072),Vector2(640,1978),Vector2(300,1910)]:
        order_air_down_target = "E05" if point.x==1800.0 else ""
        order_spear_approach = point.x==1300.0;order_spear_cast=false
        order_camp_guard_approach = point.x==900.0;order_camp_guard_cast=false
        var landed := await order_leap(point,20,"original western camp approach")
        order_air_down_target = "";order_spear_approach=false;order_camp_guard_approach=false
        Input.action_release("aim_down");Input.action_release("attack");Input.action_release("skill_1")
        if not landed:return
        if point.x!=2150.0 and not await order_clear():return
    if not await order_walk_only(Vector2(190,1910)):return
    await _world_interact()
    _check(scene.active_save_point_id=="save_ch05_lower_loop","normal F rests at C5 camp before first C4 visit")
    _check(int(scene.inventory_counts.get("lantern_phase",0))==1,"lantern phase is actually obtained at its original camp pickup")
    if failures==0:export_checkpoint("actual aqueduct -> archive double jump -> original military branch -> C5 free shaft and camp, before C4")
func order_candle_opening() -> bool:
    steps+=1;_release();await _tick(3)
    for settle in 90:
        if scene.player._can_start_action() and scene.player.is_on_floor():break
        await _tick()
    Input.action_press("jump");await process_frame
    var second_fired := false
    var second_at := -100
    for frame in 240:
        var p: CharacterBody2D = scene.player
        _axis(1.0 if p.position.x<1898 else 0.0)
        if frame==30:Input.action_release("jump");await process_frame
        # Keep the genuine air jump until the body passes below the original rock lip.
        if not second_fired and p.position.x>=1830 and p.position.y>2184 and not p.is_on_wall() and p.air_jump_available and p._can_start_action():
            Input.action_press("jump");second_fired=true;second_at=frame
            print("SECOND_ORDER_CANDLE_LOW_SECOND ",p.position," velocity=",p.velocity)
            await process_frame
        if second_fired and frame-second_at==30:Input.action_release("jump")
        await _tick()
        if second_fired and absf(p.position.x-1905)<16 and absf(p.position.y-2184)<8 and p.is_on_floor():
            _release();print("SECOND_ORDER_CANDLE_OPENING reached ",p.position);return true
        if frame%20==19:print("SECOND_ORDER_CANDLE_OPENING pending ",p.position," velocity=",p.velocity," wall=",p.is_on_wall()," second=",second_fired)
        if p.hp<=0:break
    _release();_check(false,"actual delayed second jump did not reach candle east floor");return false
func order_hold_duel(spawn_id: String,hold_x: float) -> bool:
    _release();combat_enabled=false
    var skill_at := -100
    for frame in 480:
        var foe: Node2D
        for candidate in get_nodes_in_group("enemy"):
            if is_instance_valid(candidate) and candidate.get("spawn_id")==spawn_id and candidate.get("hp")!=null and candidate.hp>0 and candidate.global_position.distance_to(scene.player.global_position)<600:foe=candidate
        if foe==null:
            _release();Input.action_release("skill_1");await _recover();return true
        var dx: float=hold_x-scene.player.position.x
        var enemy_dx: float=foe.position.x-scene.player.position.x
        _axis(signf(dx) if absf(dx)>3 else (signf(enemy_dx) if scene.player.facing!=signi(enemy_dx) else 0))
        if frame-skill_at>=2:Input.action_release("skill_1")
        if absf(enemy_dx)<180 and absf(scene.player.position.y-foe.position.y)<80 and scene.player._can_start_action() and scene.player.energy>=25 and frame-skill_at>=45:
            Input.action_press("skill_1");skill_at=frame
            print("SECOND_ORDER_REAL_SKILL ",scene.player.position," target=",spawn_id," energy_before=",scene.player.energy)
            await process_frame
        elif absf(enemy_dx)<85 and scene.player._can_start_action() and frame%24==0:
            Input.action_press("attack");attack_pressed_frame=frames
        await _tick()
        if scene.player.hp<=0:break
    _release();Input.action_release("skill_1");_check(false,"safe-side actual duel did not finish: "+spawn_id);return false
func order_clear() -> bool:
    _release()
    for frame in 360:
        var foe := _near_foe()
        if foe==null:
            combat_enabled=false;_release()
            for settle in 90:
                if scene.player._can_start_action() and scene.player.is_on_floor():break
                await _tick()
            await _recover();return true
        var dx: float=foe.position.x-scene.player.position.x
        _axis(signf(dx) if absf(dx)>95 or scene.player.facing!=signi(dx) else 0)
        combat_enabled=true;await _tick()
        if scene.player.hp<=0:break
    combat_enabled=false;_release();_check(false,"actual route duel did not finish");return false
func order_walk_only(target: Vector2, actual_surface: bool=false) -> bool:
    steps+=1;_release();await _tick(3)
    for frame in 480:
        var delta: Vector2=target-scene.player.position
        if absf(delta.x)<16 and (actual_surface or absf(delta.y)<8) and scene.player.is_on_floor():
            _release();print("SECOND_ORDER_WALK reached ",scene.player.position);return true
        _axis(signf(delta.x) if absf(delta.x)>8 else 0);await _tick()
        if frame%90==89:print("SECOND_ORDER_WALK pending ",scene.player.position," target=",target)
    _release();_check(false,"normal walk blocked at "+str(scene.player.position));return false
func order_leap(target: Vector2,second_frame: int,label: String) -> bool:
    steps+=1;_release();await process_frame;await process_frame;await _tick(3)
    for settle in 90:
        if scene.player.hurt_timer<=0 and scene.player.attack_timer<=0 and scene.player.heal_timer<=0:break
        await _tick()
    Input.action_press("jump");await process_frame
    var max_frames := 600 if not order_air_down_target.is_empty() else 220
    for frame in max_frames:
        var delta_x: float=target.x-scene.player.position.x
        _axis(signf(delta_x) if absf(delta_x)>8 else 0)
        if frame==second_frame-3 or frame==second_frame+30:
            Input.action_release("jump");await process_frame;await process_frame
        if frame==second_frame:Input.action_press("jump");await process_frame
        await _tick()
        if frame>10 and absf(target.x-scene.player.position.x)<16 and absf(target.y-scene.player.position.y)<8 and scene.player.is_on_floor():
            _release();print("SECOND_ORDER_LEAP reached ",label," ",scene.player.position);return true
        if label.contains("candle gap") and frame%10==9:
            var contacts: Array = []
            for ci in scene.player.get_slide_collision_count():
                var collision: KinematicCollision2D = scene.player.get_slide_collision(ci)
                contacts.append({"body":str(collision.get_collider().get_path()),"point":str(collision.get_position()),"normal":str(collision.get_normal())})
            print("SECOND_ORDER_GAP_CONTACT "+JSON.stringify({"frame":frame,"position":str(scene.player.position),"velocity":str(scene.player.velocity),"jump":Input.is_action_pressed("jump"),"wall":scene.player.is_on_wall(),"floor":scene.player.is_on_floor(),"air_available":scene.player.air_jump_available,"contacts":contacts}))
        if frame%50==49:print("SECOND_ORDER_LEAP pending ",label," ",scene.player.position," velocity=",scene.player.velocity," hp=",scene.player.hp)
        if scene.player.hp<=0:break
    _release();_check(false,"actual jump blocked: "+label+" at "+str(scene.player.position));return false
func export_checkpoint(origin: String) -> void:
    var raw:=FileAccess.get_file_as_bytes(order_save)
    var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(raw)
    var proof:=snapshot();proof["save_sha256"]=hash.finish().hex_encode();proof["save_bytes"]=raw.size();proof["origin"]=origin
    proof["source_save_sha256"]=order_input_sha
    proof["source_pid"]=int(parent_proof.get("pid",-1))
    print("SECOND_ORDER_EARNED "+JSON.stringify(proof))
    if not order_output.is_empty():
        var file:=FileAccess.open(order_output.path_join("earned_checkpoint.json"),FileAccess.WRITE);file.store_buffer(raw);file.close()
        write_json("checkpoint_proof.json",proof)
func same_json(actual: Variant,expected: Variant) -> bool:
    if (actual is int or actual is float) and (expected is int or expected is float):return float(actual)==float(expected)
    if typeof(actual)!=typeof(expected):return false
    if actual is Dictionary:
        if actual.size()!=expected.size():return false
        for key in actual:
            if not expected.has(key) or not same_json(actual[key],expected[key]):return false
        return true
    if actual is Array:
        if actual.size()!=expected.size():return false
        for index in actual.size():
            if not same_json(actual[index],expected[index]):return false
        return true
    return actual==expected
func order_ability_observed(id: String,origin: Vector2,direction: Vector2) -> void:
    print("SECOND_ORDER_ABILITY_EVENT "+JSON.stringify({"id":id,"frame":frames,"origin":str(origin),"direction":str(direction)}))
func _tick(count: int=1) -> void:
    for unused in count:
        if order_camp_guard_approach and is_instance_valid(scene) and is_instance_valid(scene.player):
            if frames-order_spear_cast_frame>=3:Input.action_release("skill_1")
            for foe in get_nodes_in_group("enemy"):
                if not is_instance_valid(foe) or foe.get("spawn_id")!="E07" or foe.get("hp")==null or foe.hp<=0:continue
                if not order_camp_guard_cast and absf(foe.position.x-scene.player.position.x)<180 and absf(foe.position.y-scene.player.position.y)<120 and scene.player._can_start_action() and scene.player.energy>=25:
                    _axis(signf(foe.position.x-scene.player.position.x));await process_frame
                    Input.action_press("skill_1");order_camp_guard_cast=true;order_spear_cast_frame=frames
                    print("SECOND_ORDER_CAMP_GUARD_REAL_CLEAVE ",scene.player.position," enemy=",foe.position," energy_before=",scene.player.energy)
                    await process_frame
        if order_spear_approach and is_instance_valid(scene) and is_instance_valid(scene.player):
            if frames-order_spear_cast_frame>=3:Input.action_release("skill_1")
            if not order_spear_cast and scene.player.position.x<1400 and scene.player.position.y>2070 and scene.player.position.y<2180 and scene.player._can_start_action() and scene.player.energy>=25:
                Input.action_press("skill_1");order_spear_cast=true;order_spear_cast_frame=frames
                print("SECOND_ORDER_REAL_AIR_CLEAVE ",scene.player.position," energy_before=",scene.player.energy)
                await process_frame
        if not order_air_down_target.is_empty() and is_instance_valid(scene) and is_instance_valid(scene.player):
            for foe in get_nodes_in_group("enemy"):
                if not is_instance_valid(foe) or foe.get("spawn_id")!=order_air_down_target or foe.get("hp")==null or foe.hp<=0:continue
                if absf(foe.position.x-scene.player.position.x)<85 and scene.player.position.y<foe.position.y and foe.position.y-scene.player.position.y<120 and not scene.player.is_on_floor() and scene.player.attack_timer<=0 and scene.player.hurt_timer<=0 and not Input.is_action_pressed("attack"):
                    Input.action_press("aim_down");Input.action_press("attack");attack_pressed_frame=frames
                    print("SECOND_ORDER_BASIC_AIR_DOWN_INPUT ",scene.player.position," enemy=",foe.position," enemy_hp=",foe.hp," thorn_permanent_unlocked=",scene.player.thorn_downstrike_unlocked)
                    await process_frame
        var was_alive: bool = is_instance_valid(scene) and is_instance_valid(scene.player) and scene.player.hp>0
        var previous_deaths := deaths
        await super._tick(1)
        var died_now: bool = was_alive and is_instance_valid(scene) and is_instance_valid(scene.player) and scene.player.hp<=0
        # Diagnostic edge count only: a later wallet update at HP0 is not a second death.
        deaths = previous_deaths + (1 if died_now else 0)
        if died_now:print("SECOND_ORDER_DEATH_EVENT "+JSON.stringify({"frame":frames,"number":deaths,"region":String(scene.config.id),"position":[scene.player.position.x,scene.player.position.y],"wallet":scene.currency_count}))
func snapshot() -> Dictionary:
    return {"pid":OS.get_process_id(),"stage":order_stage,"region":String(scene.config.get("id","")),"position":[scene.player.position.x,scene.player.position.y],
        "authored_start":scene.config.get("player_start",[]),"hp":scene.player.hp,"max_hp":scene.player.max_hp,"energy":scene.player.energy,"max_energy":scene.player.max_energy,
        "wallet":scene.currency_count,"inventory":scene.inventory_counts.duplicate(true),"flags":scene.story_flags.duplicate(true),"build":scene.build_system.serialize(),
        "checkpoint":scene.active_save_point_id,"damage_enabled":not scene.player.debug_invulnerable,"deaths":deaths,"damage_events":damage_events,"heals":heals,
        "private_user_dir":OS.get_user_data_dir(),"appdata":OS.get_environment("APPDATA")}
func write_json(name: String,data: Dictionary) -> void:
    var file:=FileAccess.open(order_output.path_join(name),FileAccess.WRITE);file.store_string(JSON.stringify(data,"  "));file.close()
func finish_order() -> void:
    _release()
    if is_instance_valid(scene):
        if not order_output.is_empty():write_json("terminal.json",snapshot())
        RETIREMENT.retire_tree(root)
        scene.queue_free()
        for i in 5:await physics_frame;await process_frame
    AUDIO._stream_cache.clear();AUDIO._npc_voice_cache.clear()
    _check(await RETIREMENT.drain(self),"owned audio playback retires after stage")
    print("SECOND_ORDER_STAGE stage=%s steps=%d physics_frames=%d damage_events=%d heals=%d deaths=%d failures=%d" % [order_stage,steps,frames,damage_events,heals,deaths,failures])
    quit(1 if failures else 0)

func order_click(control: Control) -> void:
    _check(is_instance_valid(control) and control.is_visible_in_tree(),"actual visible control is available")
    if failures>0:return
    var point: Vector2=root.get_final_transform() * (control.get_global_transform_with_canvas() * (control.size*.5))
    print("SECOND_ORDER_UI_INPUT ",control.name," ",control.get_global_rect()," window=",root.get_window_id()," viewport=",root.get_visible_rect()," size=",root.size," transform=",root.get_final_transform()," point=",point)
    var motion:=InputEventMouseMotion.new();motion.window_id=root.get_window_id();motion.position=point;motion.global_position=point
    Input.parse_input_event(motion);Input.flush_buffered_events();await process_frame
    var event:=InputEventMouseButton.new();event.window_id=root.get_window_id();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
    Input.parse_input_event(event);Input.flush_buffered_events();await process_frame
    event=event.duplicate();event.pressed=false;Input.parse_input_event(event);Input.flush_buffered_events()
    await process_frame;await process_frame;await _tick(4)
func order_build_entry(id: String,save_button: bool=false) -> Button:
    for node in scene.ui_shell.build_grid.get_children():
        if node is Button and String(node.get_meta("build_id",""))==id and String(node.text).begins_with("保存为")==save_button:return node
    return null
func order_capture(label: String,window: Window=null) -> void:
    if DisplayServer.get_name()=="headless" or order_output.is_empty():return
    await process_frame;await process_frame
    var image:=window.get_texture().get_image() if window!=null and window.visible and not window.is_embedded() else root.get_texture().get_image()
    _check(image!=null and image.save_png(order_output.path_join(label+".png"))==OK,"native visible UI screenshot "+label)
func order_record_build(label: String) -> void:
    var entries: Array=[]
    for child in scene.ui_shell.build_grid.get_children():
        if child is Button:entries.append({"id":child.get_meta("build_id",""),"text":child.text,"disabled":child.disabled,"tooltip":child.tooltip_text})
    print("SECOND_ORDER_BUILD_UI "+JSON.stringify({"label":label,"category":scene.ui_shell.build_category,"family":scene.ui_shell.build_family,"summary":scene.ui_shell.build_summary.text,"detail":scene.ui_shell.build_detail.text,"entries":entries,"build":scene.build_system.serialize(),"wallet":scene.currency_count,"inventory":scene.inventory_counts}))
func camp_prepare() -> void:
    var before:=snapshot()
    await _key(KEY_B,root)
    _check(scene.ui_shell.build_panel.visible,"physical B opens build UI at the actually earned camp shrine")
    if failures>0:return
    order_record_build("original camp crest restrictions")
    await order_capture("camp_crest_restrictions")
    await order_click(scene.ui_shell.build_tabs[5])
    order_record_build("original empty loadout restrictions")
    await order_click(order_build_entry("巡礼方案 1",true))
    _check(scene.build_system.serialize().loadouts.has("巡礼方案 1"),"actual UI saves the original earned build")
    await order_click(scene.ui_shell.build_tabs[3])
    await order_click(scene.ui_shell.family_selector_buttons[1])
    order_record_build("real inventory travel options before selection")
    var stride:=order_build_entry("stride")
    _check(stride!=null and not stride.disabled,"original default-unlocked stride is a legal alternative; no new reward claim")
    if failures>0:return
    await order_click(stride)
    order_record_build("legally equipped default stride")
    await order_capture("camp_equipped_stride")
    _check(scene.build_system.serialize().passives.has("stride"),"actual travel slot UI equips stride at the real shrine")
    _check(same_json(scene.inventory_counts,before.inventory) and scene.currency_count==before.wallet and scene.player.hp==before.hp and scene.player.energy==before.energy,"free legal equip does not grant inventory currency or resource refill")
    await order_click(scene.ui_shell.build_tabs[5])
    await order_click(order_build_entry("巡礼方案 2",true))
    _check(scene.build_system.serialize().loadouts.has("巡礼方案 2"),"actual UI saves the distinct stride scheme")
    await order_capture("camp_two_schemes")
    await _key(KEY_B,root)
    _check(not scene.ui_shell.build_panel.visible,"physical B closes build UI")
    if failures>0:return
    if not await order_walk_only(Vector2(500,1910)):return
    await _world_interact()
    _check(scene.active_overlay=="dialogue" and scene.dialogue_name_label.text=="盲钟骑士","real F starts actual camp NPC dialogue")
    if failures>0:return
    print("SECOND_ORDER_REAL_DIALOGUE "+JSON.stringify({"speaker":scene.dialogue_name_label.text,"line":scene.dialogue_text_label.text}))
    for i in 3:await _world_interact()
    print("SECOND_ORDER_REAL_DIALOGUE "+JSON.stringify({"speaker":scene.dialogue_name_label.text,"line":scene.dialogue_text_label.text}))
    await _key(KEY_ESCAPE,root)
    await _tick(6)
    _check(String(scene.active_overlay).is_empty(),"actual Escape closes read camp dialogue")
    if not await order_walk_only(Vector2(190,1910)):return
    await _world_interact()
    _check(scene.active_save_point_id=="save_ch05_lower_loop" and scene.player.hp==scene.player.max_hp,"real camp rest commits normal UI build and dialogue progress")
    if failures==0:export_checkpoint("actual earned camp -> physical B legal default stride UI/loadout -> actual blind knight F conversation -> normal F rest")

func greenhouse_entry() -> void:
    _check(scene.build_system.serialize().passives.has("stride") and not scene.player.dash_unlocked,"continues the actual equipped stride scheme without permanent dash")
    for point in [Vector2(640,1978),Vector2(900,2072),Vector2(710,2712)]:
        if not await order_walk_only(point):return
    if not await order_leap(Vector2(530,2760),999,"normal jump past the archive walk mouth to the ravine guide"):return
    var candidates: Array=[]
    for child in scene.get_children():
        if child is Area2D and scene.player.position.distance_to(child.position)<260:candidates.append({"id":str(child.name),"position":str(child.position),"kind":child.get_meta("kind",""),"visible":child.is_visible_in_tree(),"global":str(child.global_position),"distance":scene.player.global_position.distance_to(child.global_position)})
    print("SECOND_ORDER_GUIDE_NEARBY "+JSON.stringify({"player":str(scene.player.position),"global_player":str(scene.player.global_position),"can_interact":scene._can_interact_with_world(),"loading":scene.world_loading,"passage_route":scene.world_passage.route,"transitioning":scene.chapter_transitioning,"death_timer":scene.player.death_timer,"overlay":scene.active_overlay,"target":str(scene.interaction_target()),"candidates":candidates}))
    await _world_interact()
    print("SECOND_ORDER_GUIDE_F_RESULT ",scene.config.id," overlay=",scene.active_overlay," target=",scene.interaction_target())
    var dialog: ConfirmationDialog=scene.get_node("MapPurchaseDialog")
    _check(dialog.visible and not dialog.get_ok_button().disabled,"F opens the original C5 guide shop with earned funds")
    if failures>0:return
    var expression:=RegEx.new();expression.compile("本区地图：([0-9]+)枚")
    var price_match:=expression.search(dialog.dialog_text)
    _check(price_match!=null,"actual visible local map quote includes its price")
    if failures>0:return
    var map_price:=int(price_match.get_string(1))
    var wallet:int=scene.currency_count
    print("SECOND_ORDER_ACTUAL_SHOP_QUOTE "+JSON.stringify({"dialog":dialog.dialog_text,"wallet":wallet,"map_price":map_price}))
    await order_capture("obsidian_actual_map_quote",dialog)
    await _key(KEY_ENTER,dialog);await _tick(4)
    _check(JOURNAL.owned(scene.story_flags,String(scene.config.id)) and scene.currency_count==wallet-map_price,"actual Enter buys this guide map at its visible quote")
    if failures>0:return
    await _world_interact()
    var quill: Button=dialog.find_child("MapSellerQuill",true,false)
    expression.compile("· ([0-9]+)枚")
    price_match=expression.search(quill.text)
    _check(quill.visible and not quill.disabled and price_match!=null,"visible affordable quill has its actual own quote")
    if failures>0:return
    var quill_price:=int(price_match.get_string(1))
    print("SECOND_ORDER_ACTUAL_QUILL_QUOTE "+JSON.stringify({"text":quill.text,"price":quill_price,"wallet":scene.currency_count}))
    for attempt in 16:
        if quill.has_focus():break
        await _key(KEY_TAB,dialog)
    _check(quill.has_focus(),"actual modal Tab reaches quoted quill")
    if failures>0:return
    await _key(KEY_ENTER,dialog);await _tick(4)
    _check(JOURNAL.has_quill(scene.story_flags) and scene.currency_count==wallet-map_price-quill_price,"actual Enter pays quoted quill cost from earned wallet")
    _check(not SHOP_RUNTIME.owns_tool(scene,"compass") and not SHOP_RUNTIME.shows_position(scene),"no compass or player-position aid is granted with the purchases")
    await _key(KEY_ESCAPE,dialog);await _tick(6)
    await _walk(Vector2(440,2760),"normal approach to actual eastern slag walk mouth")
    if failures>0:return
    await _interact("world_5_4_back","demo_ch04_broken_string_greenhouse",Vector2(7140,752))
    if failures>0:return
    _check(int(scene.inventory_counts.get("lantern_phase",0))==1 and not scene.world_state.data.regions.get("demo_ch05_obsidian_pilgrim_road",{}).get("visited_rooms",{}).is_empty(),"first C4 entry follows the same new game's earned C5 phase and exploration")
    for point in [Vector2(7070,792),Vector2(6740,744),Vector2(6450,788),Vector2(6170,832),Vector2(5710,832),Vector2(5490,794),Vector2(5380,794),Vector2(5110,762)]:
        if not await order_leap(point,35,"real first C4 entry from original eastern slag passage"):return
        if point.x==5490.0:
            if not await order_hold_duel("E14",5490):return
            if not await order_clear():return
    await _world_interact()
    _check(scene.active_save_point_id=="save_late_runback" and scene.player.hp==scene.player.max_hp,"normal dome shrine rest after first C4 entry")
    _check(scene.build_system.serialize().passives.has("stride") and not scene.player.dash_unlocked,"alternate legal equipment persists across the real region change")
    if failures==0:export_checkpoint("actual stride camp -> C5 original guide quoted map/quill purchases -> original C5-C4 slag portal -> first C4 dome shrine")
