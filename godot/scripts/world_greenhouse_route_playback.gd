extends "res://scripts/world_archive_lower_playback.gd"
## Input-only continuation from the normally earned judge victory.
const GREENHOUSE_SAVE := "user://test_world_greenhouse_route.json"
const JUDGE_SEED := "res://../artifacts/t04_salt_judge/earned_judge_seed.json"
func _run() -> void:
    for argument in OS.get_cmdline_user_args():
        if String(argument).begins_with("--greenhouse-restart-proof="):
            var proof: Variant=JSON.parse_string(String(argument).trim_prefix("--greenhouse-restart-proof="))
            if not proof is Dictionary:
                _check(false,"greenhouse restart proof must be a dictionary")
                quit(1)
                return
            await _verify_greenhouse_restart(proof)
            return
    var bytes:=FileAccess.get_file_as_bytes(JUDGE_SEED)
    _check(not bytes.is_empty(),"normally earned judge seed exists")
    if bytes.is_empty():quit(1);return
    for suffix in ["", ".bak", ".tmp"]:
        if FileAccess.file_exists(GREENHOUSE_SAVE+suffix):DirAccess.remove_absolute(ProjectSettings.globalize_path(GREENHOUSE_SAVE+suffix))
    var file:=FileAccess.open(GREENHOUSE_SAVE,FileAccess.WRITE)
    _check(file!=null,"private greenhouse save can be written")
    if file==null:quit(1);return
    file.store_buffer(bytes)
    file.close()
    scene=load("res://scenes/World.tscn").instantiate()
    scene.world_resume=true
    scene.world_save_path=GREENHOUSE_SAVE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene=scene
    await _tick(15)
    _check(scene.demo_complete and scene.active_save_point_id=="save_late_runback" and scene.currency_count==186,"restores actual judge victory and earned wallet")
    if failures>0:await _finish();return
    if not await _walk_without_jump(Vector2(5220,2606)):await _finish();return
    if not await _leap(Vector2(5400,2648),999,"cleared archive threshold"):await _finish();return
    if not await _walk_without_jump(Vector2(5490,2648)):await _finish();return
    if not await _leap(Vector2(5710,2704),999,"cleared judge court"):await _finish();return
    if not await _walk_without_jump(Vector2(6170,2704)):await _finish();return
    if not await _leap(Vector2(6470,2650),35,"archive eastern dock"):await _finish();return
    for point in [Vector2(6780,2606),Vector2(7000,2648)]:
        if not await _walk_without_jump(point):await _finish();return
    await _greenhouse_exit()
    if failures>0:await _finish();return
    if not await _walk_without_jump(Vector2(540,1780)):await _finish();return
    var wallet: int=scene.currency_count
    _check(not JOURNAL.owned(scene.story_flags,String(scene.config.id)),"greenhouse map has not been granted")
    await _world_interact()
    var dialog: ConfirmationDialog=scene.get_node("MapPurchaseDialog")
    _check(dialog.visible and dialog.get_ok_button().has_focus(),"normal F opens the greenhouse map shop")
    if not dialog.visible:await _finish();return
    await _key(KEY_ENTER,dialog)
    await _tick(4)
    _check(JOURNAL.owned(scene.story_flags,String(scene.config.id)) and scene.currency_count==wallet-45,"normal Enter pays forty-five earned fragments for the greenhouse map")
    _check(JOURNAL.has_quill(scene.story_flags),"normally purchased quill persists into the greenhouse")
    if not await _leap(Vector2(750,1896),999,"greenhouse western descent"):await _finish();return
    for point in [Vector2(545,2018),Vector2(795,2140),Vector2(615,2266)]:
        if not await _walk_without_jump(point):await _finish();return
    if not await _leap(Vector2(1000,2420),35,"land in the lower garden"):await _finish();return
    if not await _clear_nearby():await _finish();return
    if not await _walk_without_jump(Vector2(1460,2474)):await _finish();return
    if not await _leap(Vector2(1800,2412),35,"cross the false moss bed"):await _finish();return
    if not await _walk_without_jump(Vector2(2150,2478)):await _finish();return
    if not await _clear_nearby():await _finish();return
    for point in [Vector2(2670,2422),Vector2(2995,2484)]:
        if not await _walk_without_jump(point):await _finish();return
    if not await _clear_nearby():await _finish();return
    if not await _walk_without_jump(Vector2(3170,2484)):await _finish();return
    if not await _leap(Vector2(3530,2428),35,"cross the lower root spore chest"):await _finish();return
    if not await _walk_without_jump(Vector2(3920,2486)):await _finish();return
    if not await _clear_nearby():await _finish();return
    if not await _walk_without_jump(Vector2(4350,2432)):await _finish();return
    if not await _clear_nearby():await _finish();return
    if not await _leap(Vector2(4400,2432),999,"ordinary jump to duel the hovering thorn mote"):await _finish();return
    await _recover()
    if not await _walk_without_jump(Vector2(4510,2432)):await _finish();return
    if not await _leap(Vector2(4730,2354),20,"beeswax room approach"):await _finish();return
    if not await _leap(Vector2(4970,2300),20,"beeswax room landing"):await _finish();return
    if not await _walk_without_jump(Vector2(5100,2300)):await _finish();return
    await _world_interact()
    _check(scene.active_save_point_id=="save_hidden_upper_respite" and scene.player.hp==scene.player.max_hp,"normal F rests at the actually reached beeswax shrine")
    await _inspect_map_without_position()
    _check(scene.currency_count==203 and not scene.inventory_counts.has("thorn_downstrike"),"actual lower garden earns the beeswax checkpoint without the later ability")
    if failures>0:await _finish();return
    if not await _climb_to_heart():await _finish();return
    await _inspect_map_without_position()
    if failures==0:
        var earned:=FileAccess.open("user://test_world_greenhouse_heart_earned_seed.json",FileAccess.WRITE)
        _check(earned!=null,"actual tree heart checkpoint can be archived")
        if earned!=null:
            earned.store_buffer(FileAccess.get_file_as_bytes(GREENHOUSE_SAVE))
            earned.close()
            print("GREENHOUSE_HEART_EARNED_SEED ",ProjectSettings.globalize_path("user://test_world_greenhouse_heart_earned_seed.json"))
    await _finish()

func _climb_to_heart() -> bool:
    if not await _walk_without_jump(Vector2(5305,2300)):return false
    for point in [Vector2(5475,2210),Vector2(5320,2098),Vector2(5555,2000)]:
        if not await _leap(point,20,"lower vine ascent"):return false
        if point.y==2098:
            if not await _vine_bee_duel():return false
        elif not await _clear_nearby():return false
    if not await _clear_nearby():return false
    for point in [Vector2(5310,1900),Vector2(5520,1795),Vector2(5295,1678),Vector2(5545,1570),Vector2(5320,1462),Vector2(5555,1360)]:
        if not await _leap(point,20,"upper vine ascent"):return false
        if not await _clear_nearby():return false
    trace_ceiling=true
    if not await _leap(Vector2(5360,1186),20,"actual trellis landing"):return false
    trace_ceiling=false
    if not await _clear_nearby():return false
    await _safe_recover()
    if not await _leap(Vector2(5050,1120),35,"trellis western bank"):return false
    if not await _leap(Vector2(4795,1006),20,"trellis rise"):return false
    if not await _leap(Vector2(4590,892),20,"safe side of the canopy string"):return false
    if not await _leap(Vector2(4330,928),35,"canopy eastern walk"):return false
    if not await _vine_bee_duel("E08",4320,-1):return false
    if not await _clear_nearby():return false
    if not await _walk_without_jump(Vector2(4060,928)):return false
    if not await _leap(Vector2(3770,882),35,"canopy western takeoff"):return false
    for point in [Vector2(3605,1054),Vector2(3760,1164),Vector2(3560,1274),Vector2(3750,1384),Vector2(3565,1494)]:
        if not await _walk_without_jump(point):return false
    if not await _walk_without_jump(Vector2(3315,1632)):return false
    if not await _leap(Vector2(3150,1602),999,"ordinary jump into the tree heart"):return false
    if not await _walk_without_jump(Vector2(3060,1602)):return false
    if not await _clear_nearby():return false
    if not await _walk_without_jump(Vector2(2730,1602)):return false
    if not await _heart_interact("save_ch04_lower_loop",2750):return false
    _check(scene.active_save_point_id=="save_ch04_lower_loop","normal F rests at the actual tree heart shrine")
    if not await _walk_without_jump(Vector2(2790,1602)):return false
    if not await _heart_interact("col_testimony_04",2770):return false
    _check(scene.inventory_counts.get("testimony_04",0)==1,"normal F collects the actual fourth testimony")
    if not await _walk_without_jump(Vector2(2830,1602)):return false
    _check(scene.inventory_counts.get("thorn_downstrike",0)==1 and scene.player.thorn_downstrike_unlocked,"normal collision earns thorn downstrike")
    if not await _clear_nearby():return false
    if not await _walk_without_jump(Vector2(2730,1602)):return false
    if not await _heart_interact("save_ch04_lower_loop",2750):return false
    _check(scene.active_save_point_id=="save_ch04_lower_loop" and scene.player.hp==scene.player.max_hp,"normal tree heart rest after the earned ability")
    return failures==0

func _greenhouse_exit() -> void:
    steps+=1
    _axis(1)
    for frame in 360:
        await _tick()
        if _transition_busy() or scene.world_passage.active or String(scene.config.id)!="demo_ch03_saltwhite_archive" or deaths>0:break
        if absf(scene.player.position.x-7110)<30:
            await _world_interact()
            break
    _release()
    if scene.world_passage.active:
        _axis(signf(scene.world_passage.destination_point.x-scene.world_passage.source_point.x))
        for frame in 3600:
            await _tick()
            if not scene.world_passage.active:break
        _release()
    for frame in 2000:
        if not _transition_busy():break
        await process_frame
    await _tick(15)
    _check(String(scene.config.id)=="demo_ch04_broken_string_greenhouse" and scene.player.position.distance_to(Vector2(460,1740))<90,"actual archive exit arrives at the greenhouse porch")

func _vine_bee_duel(spawn_id: String="E06",hold_x: float=5340,direction: int=1) -> bool:
    steps+=1
    _release()
    await _tick(3)
    if not await _walk_without_jump(Vector2(hold_x+10,2098 if spawn_id=="E06" else 928)):return false
    var before_wallet: int=scene.currency_count
    var before_pollen: int=scene.inventory_counts.get("pollen_wax",0)
    var cost: int=int(scene.build_system.selected_skill().get("energy_cost",999))
    scene.player.skill_cast.connect(func(id: String):print("GREENHOUSE_BEE_SKILL ",JSON.stringify({"id":id,"position":str(scene.player.position),"energy":scene.player.energy})))
    var jump_at := -100
    var skill_at := -100
    for frame in 600:
        var bee: Node2D
        for candidate in get_nodes_in_group("enemy"):
            if is_instance_valid(candidate) and candidate.get("spawn_id")==spawn_id and candidate.get("hp")!=null and candidate.hp>0:bee=candidate
        if bee==null:
            _release()
            Input.action_release("skill_1")
            for settle in 120:
                await _tick()
                if scene.player.is_on_floor() and scene.player.attack_timer<=0 and scene.player.hurt_timer<=0:break
            await _recover()
            _check(scene.currency_count==before_wallet+8 and scene.inventory_counts.get("pollen_wax",0)==before_pollen+1,"actual vine bee awards its normal income and material")
            print("GREENHOUSE_VINE_BEE_CLEARED ",scene.player.position)
            return failures==0
        var player: CharacterBody2D=scene.player
        var dx: float=hold_x-player.position.x
        _axis(signf(dx) if absf(dx)>10 else (float(direction) if player.facing!=direction else 0.0))
        if frame-jump_at>=35 and Input.is_action_pressed("jump"):Input.action_release("jump")
        if absf(player.position.y-bee.position.y)>90 and player.is_on_floor() and player.attack_timer<=0 and player.hurt_timer<=0 and not Input.is_action_pressed("jump"):
            Input.action_press("jump")
            jump_at=frame
            await process_frame
        if frame-skill_at>=2 and Input.is_action_pressed("skill_1"):Input.action_release("skill_1")
        if absf(player.position.y-bee.position.y)<80 and absf(player.position.x-bee.position.x)<120 and player.attack_timer<=0 and player.hurt_timer<=0 and player.skill_cooldown<=0 and player.energy>=cost and frames%20>=5:
            Input.action_press("skill_1")
            skill_at=frame
            await process_frame
        await _tick()
        if frame%90==89:print("GREENHOUSE_BEE_DUEL ",JSON.stringify({"player":str(player.position),"bee":str(bee.position),"bee_hp":bee.hp,"hp":player.hp}))
        if deaths>0:break
    _release()
    Input.action_release("skill_1")
    _check(false,"actual vine bee duel did not finish")
    return false

func _heart_interact(id: String, x: float) -> bool:
    steps+=1
    _release()
    for frame in 240:
        var dx: float=x-scene.player.position.x
        Input.action_release("move_left")
        Input.action_release("move_right")
        if absf(dx)>1:
            Input.action_press("move_right" if dx>0 else "move_left",clampf(absf(dx)/60.0,0.08,1.0))
        await _tick()
        if absf(dx)<2 and absf(scene.player.velocity.x)<8:
            _release()
            await _tick(15)
            var target: Area2D=scene.interaction_target()
            if target!=null and String(target.name)==id:
                print("GREENHOUSE_INTERACTION ",JSON.stringify({"id":id,"position":str(scene.player.position)}))
                await _world_interact()
                _check(not _transition_busy(),"tree heart interaction does not enter the adjacent workshop")
                return failures==0
            print("GREENHOUSE_INTERACTION_PENDING ",str(scene.player.position)," target=",target.name if target!=null else "none")
    _release()
    _check(false,"cannot aim the normal tree heart interaction at "+id)
    return false

func _finish() -> void:
    _release()
    Input.action_release("skill_1")
    _check(deaths==0,"greenhouse continuation survives without death")
    if failures==0:
        print("GREENHOUSE_RESTART_PROOF ",JSON.stringify({"pid":OS.get_process_id(),"region":String(scene.config.id),"checkpoint":String(scene.active_save_point_id),"wallet":scene.currency_count,"inventory":scene.inventory_counts.duplicate(true),"charted":JOURNAL.region(scene.story_flags,String(scene.config.id)).charted.duplicate(true)}))
    print("GREENHOUSE_FINISH_STATE ",JSON.stringify({"region":String(scene.config.id),"position":str(scene.player.position),"hp":scene.player.hp,"energy":scene.player.energy,"wallet":scene.currency_count,"inventory":scene.inventory_counts,"checkpoint":scene.active_save_point_id}))
    print("WORLD_GREENHOUSE_ROUTE steps=%d failures=%d damage_events=%d heals=%d deaths=%d damage_suppression=false earned_checkpoint=true" % [steps,failures,damage_events,heals,deaths])
    scene.queue_free()
    scene=null
    for unused in 10:await process_frame
    quit(0 if failures==0 else 1)

func _verify_greenhouse_restart(proof: Dictionary) -> void:
    scene=load("res://scenes/World.tscn").instantiate()
    scene.world_resume=true
    scene.world_save_path=GREENHOUSE_SAVE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene=scene
    await _tick(15)
    var previous_pid: Variant=proof.get("pid",0)
    _check(typeof(previous_pid) in [TYPE_INT,TYPE_FLOAT] and previous_pid>0 and previous_pid==int(previous_pid) and OS.get_process_id()!=int(previous_pid),"greenhouse checkpoint opens in a different process")
    _check(String(scene.config.id)==String(proof.get("region","")) and scene.active_save_point_id==String(proof.get("checkpoint","")),"greenhouse restart retains the actual region and checkpoint")
    _check(scene.active_save_point_id=="save_ch04_lower_loop" and scene.player.position.distance_to(Vector2(2750,1562))<90,"restart actually resumes at the rested tree heart shrine")
    _check(scene.currency_count==proof.get("wallet",-1),"greenhouse restart retains exact earned income")
    _check(_inventory_matches(scene.inventory_counts,proof.get("inventory",{})),"greenhouse restart retains every exact earned item count")
    var chart: Dictionary=JOURNAL.region(scene.story_flags,String(scene.config.id))
    _check(not proof.get("charted",{}).is_empty() and chart.charted==proof.get("charted",{}),"greenhouse restart retains all actually charted notes")
    _check(JOURNAL.owned(scene.story_flags,String(scene.config.id)) and JOURNAL.has_quill(scene.story_flags),"restart retains the normally purchased map and quill")
    _check(scene.inventory_counts.get("thorn_downstrike",0)==1 and scene.player.thorn_downstrike_unlocked and scene.inventory_counts.get("testimony_04",0)==1,"actual tree heart ability and testimony persist exactly once")
    _check(bool(scene.story_flags.get("boss_down_ch03",false)) and not scene.demo_complete and not scene.boss_unlocked,"the prior judge stays defeated while the greenhouse lever and Boss remain pending")
    await _inspect_map_without_position()
    print("WORLD_GREENHOUSE_ROUTE_RESTART failures=%d pid_changed=true" % failures)
    _release()
    scene.queue_free()
    scene=null
    for unused in 10:await process_frame
    quit(0 if failures==0 else 1)

func _safe_recover() -> void:
    _release()
    for frame in 120:
        if scene.player.is_on_floor() and scene.player.attack_timer<=0 and scene.player.hurt_timer<=0:break
        await _tick()
    await _recover()
