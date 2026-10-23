extends "res://scripts/world_obsidian_earned_playback.gd"
## Normal-input continuation: earned camp, actual ash winch, physical camp return.
const TOWER_SAVE := "user://test_world_c05_tower_boss.json"
var tower_spear := false
var tower_spear_id := "E06"
var tower_skill_at := -100
const CAMP_SEED := "res://../artifacts/t04_obsidian_route/earned_camp_seed.json"
func _run() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--tower-restart-proof="):
            var proof: Variant=JSON.parse_string(arg.trim_prefix("--tower-restart-proof="))
            if not proof is Dictionary:_check(false,"tower proof must be dictionary");quit(1);return
            await _verify_tower_restart(proof)
            return
    for suffix in ["", ".bak", ".tmp"]:
        if FileAccess.file_exists(TOWER_SAVE+suffix):DirAccess.remove_absolute(ProjectSettings.globalize_path(TOWER_SAVE+suffix))
    var file:=FileAccess.open(TOWER_SAVE,FileAccess.WRITE)
    file.store_buffer(FileAccess.get_file_as_bytes(CAMP_SEED))
    file.close()
    scene=load("res://scenes/World.tscn").instantiate()
    scene.world_resume=true
    scene.world_save_path=TOWER_SAVE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene=scene
    await _tick(15)
    _check(scene.currency_count==287 and scene.active_save_point_id=="save_ch05_lower_loop","normal camp seed resumes at earned checkpoint")
    _check(not scene.boss_unlocked and scene.opened_shortcuts.is_empty() and scene.inventory_counts.get("lantern_phase",0)==1,"phase is earned but actual ash winch remains unopened")
    _check(scene.inventory_counts.get("thread_dash",0)==0,"route does not assume unearned dash")
    if not await _walk_without_jump(Vector2(520,1910)):await _finish();return
    for point in [Vector2(640,1978),Vector2(900,2072),Vector2(1300,2178),Vector2(1510,2286),Vector2(1800,2390),Vector2(2150,2496),Vector2(2510,2608)]:
        tower_spear=point.y==2178
        spear_approach=false
        phase_crossing=point.x==1800
        if point.y==2286:
            if not await _walk_without_jump(Vector2(1320,2178)):await _finish();return
        var reached: bool=await _leap(point,999 if point.y==2286 else 20,"downhill west ledge") if point.y>=2286 else await _walk_without_jump(point)
        if not reached:await _finish();return
        tower_spear=false
        spear_approach=false
        phase_crossing=false
        Input.action_release("skill_1")
        Input.action_release("aim_down")
        if not await _clear_nearby():await _finish();return
    if not await _walk_without_jump(Vector2(2800,2768)):await _finish();return
    if not await _leap(Vector2(3130,2830),20,"normal ash descent"):await _finish();return
    if not await _walk_without_jump(Vector2(3605,2896)):await _finish();return
    if not await _clear_nearby():await _finish();return
    await _world_interact()
    _check(scene.opened_shortcuts.get("ch05_funicular_shortcut",false) and scene.boss_unlocked,"actual normal F winch unlocks Boss without clearing full map")
    if failures>0:await _finish();return
    if not await _leap(Vector2(3330,2760),20,"normal return onto free shaft"):await _finish();return
    for point in [Vector2(3470,2652),Vector2(3280,2544),Vector2(3470,2436),Vector2(3280,2328),Vector2(3470,2220),Vector2(3280,2112),Vector2(3460,2004)]:
        if not await _leap(point,999 if point.y==2004 else 20,"earned free shaft return"):await _finish();return
    if not await _leap(Vector2(3220,1868),999,"ordinary final dock jump"):await _finish();return
    if not await _walk_without_jump(Vector2(2800,1868)):await _finish();return
    if not await _walk_without_jump(Vector2(2510,2608)):await _finish();return
    for point in [Vector2(2150,2496),Vector2(1800,2390),Vector2(1510,2286),Vector2(1300,2178),Vector2(900,2072),Vector2(640,1978),Vector2(300,1910)]:
        spear_approach=point.y==2178
        phase_crossing=point.x==1800
        if not await _leap(point,20,"physical return to actual camp"):await _finish();return
        spear_approach=false
        phase_crossing=false
        Input.action_release("skill_1")
        Input.action_release("aim_down")
        if not await _clear_nearby():await _finish();return
    if not await _heart_interact("save_ch05_lower_loop",190):await _finish();return
    _check(scene.player.hp==scene.player.max_hp and scene.player.energy==scene.player.max_energy,"actual camp rest after physical winch round trip")
    if not await _upper_tower():await _finish();return
    if not await _heart_interact("npc_lantern_sister",3350):await _finish();return
    _check(scene.active_overlay=="dialogue","actual tower nun dialogue opens normally")
    Input.action_press("close_overlay")
    await _tick(3)
    Input.action_release("close_overlay")
    await _tick(3)
    _check(scene.active_overlay.is_empty(),"normal close input releases the nun dialogue")
    if not await _leap(Vector2(3100,730),20,"normal west banner branch"):await _finish();return
    if not await _walk_without_jump(Vector2(2910,730)):await _finish();return
    if not await _leap(Vector2(2670,762),20,"banner bridge second bank"):await _finish();return
    if not await _clear_nearby():await _finish();return
    if not await _walk_without_jump(Vector2(2450,762)):await _finish();return
    tower_spear=true
    tower_spear_id="E12"
    if not await _leap(Vector2(2200,726),20,"normal military banner spear bank"):await _finish();return
    if not await _clear_nearby():await _finish();return
    tower_spear=false
    tower_spear_id="E06"
    if not await _walk_without_jump(Vector2(2050,726)):await _finish();return
    if not await _leap(Vector2(1830,768),20,"land beyond rotten banner edge"):await _finish();return
    if not await _leap(Vector2(1400,812),35,"cross the actual rotten banner"):await _finish();return
    for point in [Vector2(1040,1010),Vector2(720,1300),Vector2(480,1600),Vector2(275,1392)]:
        if not await _leap(point,20,"normal military grave descent"):await _finish();return
    if not await _heart_interact("col_testimony_05",295):await _finish();return
    _check(scene.inventory_counts.get("testimony_05",0)==1,"actual grave branch yields fifth testimony")
    if not await _leap(Vector2(480,1600),20,"physical return from actual testimony"):await _finish();return
    if not await _walk_without_jump(Vector2(300,1910)):await _finish();return
    if not await _heart_interact("save_ch05_lower_loop",190):await _finish();return
    if not await _upper_tower():await _finish();return
    if not await _leap(Vector2(3700,662),20,"normal mirror approach"):await _finish();return
    if not await _walk_without_jump(Vector2(3780,662)):await _finish();return
    if not await _leap(Vector2(4100,618),20,"normal jump beyond mirror crack"):await _finish();return
    if not await _heart_interact("save_late_runback",4150):await _finish();return
    _check(scene.player.hp==scene.player.max_hp and scene.player.energy==scene.player.max_energy,"normal mirror checkpoint rest after actual testimony circuit")
    await _inspect_map_without_position()
    await _finish()
func _finish() -> void:
    _release()
    Input.action_release("aim_down")
    _check(deaths==0,"earned camp continuation survives without death")
    if failures==0:
        _check(scene.active_save_point_id=="save_late_runback","formal route really rests at mirror shrine")
        print("TOWER_RESTART_PROOF ",JSON.stringify(_tower_proof()))
        var earned:=FileAccess.open("user://test_world_c05_mirror_earned_seed.json",FileAccess.WRITE)
        earned.store_buffer(FileAccess.get_file_as_bytes(TOWER_SAVE))
        earned.close()
        print("TOWER_EARNED_SEED ",ProjectSettings.globalize_path("user://test_world_c05_mirror_earned_seed.json"))
    print("TOWER_STATE ",JSON.stringify({"position":str(scene.player.position),"wallet":scene.currency_count,"hp":scene.player.hp,"energy":scene.player.energy,"inventory":scene.inventory_counts,"shortcuts":scene.opened_shortcuts,"checkpoint":scene.active_save_point_id,"boss_unlocked":scene.boss_unlocked}))
    print("WORLD_C05_TOWER steps=%d failures=%d damage_events=%d heals=%d deaths=%d damage_suppression=false"%[steps,failures,damage_events,heals,deaths])
    scene.queue_free()
    for unused in 10:await process_frame
    quit(0 if failures==0 else 1)

func _walk_without_jump(target: Vector2) -> bool:
    steps+=1
    _release()
    await _tick(3)
    for frame in 480:
        var player: CharacterBody2D=scene.player
        var delta: Vector2=target-player.global_position
        if absf(delta.x)<16 and absf(delta.y)<8 and player.is_on_floor():
            _release()
            print("WHEEL_ROUTE_WALK reached ",player.position)
            return true
        _axis(signf(delta.x) if absf(delta.x)>8 else 0)
        await _tick()
        if frame%90==89:
            var collisions: Array=[]
            for index in player.get_slide_collision_count():
                var c:=player.get_slide_collision(index)
                collisions.append({"collider":str(c.get_collider().get_path()),"point":str(c.get_position()),"normal":str(c.get_normal())})
            print("WHEEL_ROUTE_WALK pending ",player.position," collisions=",JSON.stringify(collisions))
    _release()
    _check(false,"walk-only route blocked at "+str(scene.player.position))
    return false

func _leap(target: Vector2, second_frame: int, label: String) -> bool:
    steps+=1
    _release()
    await process_frame
    await process_frame
    await _tick(3)
    for settle in 90:
        if scene.player.hurt_timer<=0 and scene.player.attack_timer<=0 and scene.player.heal_timer<=0:break
        await _tick()
    Input.action_press("jump")
    await process_frame
    for frame in 220:
        var player: CharacterBody2D=scene.player
        var delta_x: float=target.x-player.position.x
        _axis(signf(delta_x) if absf(delta_x)>8 else 0)
        if frame==second_frame-3 or frame==second_frame+30:
            Input.action_release("jump")
            await process_frame
            await process_frame
        if frame==second_frame:
            Input.action_press("jump")
            await process_frame
        await _tick()
        if frame>10 and absf(target.x-player.position.x)<16 and absf(target.y-player.position.y)<8 and player.is_on_floor():
            _release()
            print("WHEEL_LEAP reached ",label," ",player.position)
            return true
        if frame%50==49:
            var hits: Array=[]
            for ci in player.get_slide_collision_count():
                var hit:=player.get_slide_collision(ci)
                if is_instance_valid(hit.get_collider()):hits.append({"body":str(hit.get_collider().get_path()),"point":str(hit.get_position()),"normal":str(hit.get_normal())})
            print("WHEEL_LEAP pending ",label," ",player.position," velocity=",player.velocity," hp=",player.hp," collisions=",JSON.stringify(hits))
        if deaths>0:break
    _release()
    _check(false,"leap blocked: "+label+" at "+str(scene.player.position))
    return false

func _tick(count: int=1) -> void:
    for unused in count:
        if frames-tower_skill_at>=2:Input.action_release("skill_1")
        if tower_spear and is_instance_valid(scene) and is_instance_valid(scene.player) and scene.player.is_on_floor():
            for foe in get_nodes_in_group("enemy"):
                if not is_instance_valid(foe) or foe.spawn_id!=tower_spear_id:continue
                if absf(foe.position.x-scene.player.position.x)<135 and absf(foe.position.y-scene.player.position.y)<70 and scene.player.skill_cooldown<=0 and scene.player.energy>=15 and scene.player.attack_timer<=0 and scene.player.hurt_timer<=0 and scene.player.facing==signi(foe.position.x-scene.player.position.x) and not Input.is_action_pressed("skill_1") and frames-tower_skill_at>=15:
                    Input.action_press("skill_1")
                    tower_skill_at=frames
                    print("TOWER_SPEAR_CLEAVE ",scene.player.position," foe=",foe.position)
                    await process_frame
        await super._tick()

func _upper_tower() -> bool:
    if not await _walk_without_jump(Vector2(540,1910)):return false
    if not await _leap(Vector2(900,1878),35,"normal east camp exit"):return false
    if not await _clear_nearby():return false
    for point in [Vector2(1160,1798),Vector2(1470,1682),Vector2(1860,1596),Vector2(2160,1482),Vector2(2440,1398),Vector2(2780,1284),Vector2(3070,1224)]:
        if point.y==1596:
            if not await _walk_without_jump(Vector2(1525,1682)):return false
        if not await _leap(point,35 if point.y==1596 else 20,"normal upper pilgrimage road"):return false
        if not await _clear_nearby():return false
    for point in [Vector2(3350,1122),Vector2(3190,1014),Vector2(3370,906),Vector2(3250,798),Vector2(3400,690)]:
        if point.y==798:
            if not await _walk_without_jump(Vector2(3320,906)):return false
        if not await _leap(point,20,"normal watch tower ascent"):return false
    _check(absf(scene.player.position.y-690)<8,"actual tower summit floor reached")
    return true

func _tower_proof() -> Dictionary:
    return {"pid":OS.get_process_id(),"region":String(scene.config.id),"checkpoint":scene.active_save_point_id,"wallet":scene.currency_count,"inventory":scene.inventory_counts.duplicate(true),"build":scene.build_system.serialize(),"story":scene.story_flags.duplicate(true),"charted":JOURNAL.region(scene.story_flags,String(scene.config.id)).charted.duplicate(true),"shortcuts":scene.opened_shortcuts.duplicate(true)}
func _verify_tower_restart(proof: Dictionary) -> void:
    scene=load("res://scenes/World.tscn").instantiate()
    scene.world_resume=true
    scene.world_save_path=TOWER_SAVE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene=scene
    await _tick(15)
    var pid: Variant=proof.get("pid",0)
    _check(typeof(pid) in [TYPE_INT,TYPE_FLOAT] and pid>0 and pid==int(pid) and OS.get_process_id()!=int(pid),"mirror seed restores in a different actual process")
    var actual:=_tower_proof()
    for key in ["region","checkpoint","wallet","inventory","build","story","charted","shortcuts"]:
        _check(proof.has(key) and _exact_state(actual[key],proof[key]),"mirror restart retains exact "+key)
    _check(scene.active_save_point_id=="save_late_runback" and scene.player.position.distance_to(Vector2(4150,578))<90,"new process resumes at actually rested mirror checkpoint")
    _check(scene.inventory_counts.get("lantern_phase",0)==1 and scene.inventory_counts.get("testimony_05",0)==1 and scene.inventory_counts.get("thread_dash",0)==0,"actual phase and grave testimony persist without unearned dash")
    _check(scene.opened_shortcuts.get("ch05_funicular_shortcut",false) and scene.boss_unlocked and not scene.demo_complete and not scene.boss_spawned,"actual winch unlock persists without prematurely starting or defeating Bride")
    _check(JOURNAL.owned(scene.story_flags,String(scene.config.id)) and JOURNAL.has_quill(scene.story_flags),"actual paid map and quill persist")
    await _inspect_map_without_position()
    print("WORLD_C05_TOWER_RESTART failures=%d pid_changed=true"%failures)
    _release()
    scene.queue_free()
    for unused in 10:await process_frame
    quit(0 if failures==0 else 1)
