extends "res://scripts/world_greenhouse_route_playback.gd"
## Input-only return to the original court's missing dash. No grants or warps.
const DASH_SAVE := "user://test_world_earned_dash_return.json"
const DASH_SEED := "res://../artifacts/t04_bishop_route/earned_bishop_seed.json"
var route_stage := 1
var input_save := ""
var export_save := ""
var proof_file := ""
var capture_dir := ""
var wall_return := false
var dash_actions := 0

func _run() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--dash-stage="):route_stage=int(argument.trim_prefix("--dash-stage="))
        if argument.begins_with("--dash-input="):input_save=argument.trim_prefix("--dash-input=")
        if argument.begins_with("--dash-export="):export_save=argument.trim_prefix("--dash-export=")
        if argument.begins_with("--dash-proof="):proof_file=argument.trim_prefix("--dash-proof=")
        if argument.begins_with("--dash-captures="):capture_dir=argument.trim_prefix("--dash-captures=")
    var source := DASH_SEED if route_stage == 1 else input_save
    if source.is_empty() or not FileAccess.file_exists(source):
        _check(false,"preceding actual save must exist; never fall back to a fresh journey")
        quit(1);return
    var bytes := FileAccess.get_file_as_bytes(source)
    _check(not bytes.is_empty(),"actual preceding save bytes are available")
    var file := FileAccess.open(DASH_SAVE,FileAccess.WRITE)
    if file == null:quit(1);return
    file.store_buffer(bytes)
    file.close()
    print("DASH_RETURN_STORAGE ",OS.get_user_data_dir()," save=",ProjectSettings.globalize_path(DASH_SAVE))
    scene=load("res://scenes/World.tscn").instantiate()
    scene.world_resume=true
    scene.world_save_path=DASH_SAVE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene=scene
    await _tick(15)
    if route_stage<=3:
        _check(not scene.player.dash_unlocked and not scene.inventory_counts.has("thread_dash"),"earned start still lacks the actual permanent dash")
    else:
        _check(scene.player.dash_unlocked and scene.inventory_counts.get("thread_dash",0)==1,"continues actual earned permanent dash")
    scene.player.ability_action.connect(_ability_observed)
    var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DASH_SEED))
    _check(_exact_state(scene.build_system.serialize(),original.build_state),"normal return retains the seed build without equipping the new reward")
    if route_stage == 1:
        _check(scene.active_save_point_id=="save_late_runback" and scene.currency_count==297,"starts at actual bishop victory shrine")
        for point in [Vector2(5380,794),Vector2(5490,794),Vector2(5710,832),Vector2(6170,832),Vector2(6450,788),Vector2(6740,744),Vector2(7070,792)]:
            if not await _leap(point,35,"normal bishop victory east exit"):await _finish_stage();return
        if not await _walk_without_jump(Vector2(7140,792)):await _finish_stage();return
        await _interact("world_4_5_out","demo_ch05_obsidian_pilgrim_road",Vector2(430,2720))
        if failures>0:await _finish_stage();return
        if not await _leap(Vector2(710,2712),20,"normal military book-line western landing"):await _finish_stage();return
        await _interact("upgrade_archive_obsidian_branch_b","demo_ch03_saltwhite_archive",Vector2(2340,2118))
        if failures>0:await _finish_stage();return
        if not await _leap(Vector2(2010,2184),35,"old candle eastern walk"):await _finish_stage();return
        if not await _walk_without_jump(Vector2(1940,2184)):await _finish_stage();return
        if not await _walk_without_jump(Vector2(1720,2350)):await _finish_stage();return
        wall_return=true
        if not await _leap(Vector2(1640,2240),999,"normal candle stair return below the rock lip"):await _finish_stage();return
        await _interact("archive_moss_return","demo_ch01_moss_bell_court",Vector2(280,3360))
        wall_return=false
        if failures>0:await _finish_stage();return
        for point in [Vector2(640,3452),Vector2(870,3532),Vector2(1130,3612),Vector2(1420,3692),Vector2(1710,3752)]:
            await _walk(point,"returned original court descent")
            if failures>0:await _finish_stage();return
        if not await _clear_nearby():await _finish_stage();return
        if not await _heart_interact("save_first_bell",1710):await _finish_stage();return
        _check(scene.active_save_point_id=="save_first_bell","actual F rests at original court shrine")
        _check(scene.locked_gate_bodies.has("gate_dash_cache") and not scene.inventory_counts.has("quiet_sole"),"original optional gate is closed before earning dash and its reward remains uncollected")
    elif route_stage == 2:
        _check(String(scene.config.id)=="demo_ch01_moss_bell_court" and scene.active_save_point_id=="save_first_bell","continues actually returned original court shrine")
        for point in [Vector2(1420,3692),Vector2(1130,3612),Vector2(870,3532)]:
            if not await _leap(point,20,"normal old court west approach"):await _finish_stage();return
        if not await _overgrowth_descent():await _finish_stage();return
        if scene.player.position.y<3800:
            if not await _leap(Vector2(520,3900),999,"normal overgrowth first ledge"):await _finish_stage();return
        if scene.player.position.y<3980:
            if not await _leap(Vector2(780,4040),999,"normal overgrowth second ledge"):await _finish_stage();return
        if not await _walk_without_jump(Vector2(900,4180)):await _finish_stage();return
        if not await _walk_without_jump(Vector2(1200,4240)):await _finish_stage();return
        if not await _clear_nearby():await _finish_stage();return
        if not await _walk_without_jump(Vector2(1510,4320)):await _finish_stage();return
        if not await _leap(Vector2(1830,4460),999,"normal jump across the old tangle teeth"):await _finish_stage();return
        for point in [Vector2(1630,4600),Vector2(1850,4740),Vector2(1630,4880),Vector2(1850,5020),Vector2(1520,5120)]:
            if not await _leap(point,999,"normal old vine well descent"):await _finish_stage();return
        if not await _heart_interact("save_maze_respite",1520):await _finish_stage();return
        _check(scene.active_save_point_id=="save_maze_respite","actual F rests before original broken-branch altar")
    elif route_stage == 3:
        _check(String(scene.config.id)=="demo_ch01_moss_bell_court" and scene.active_save_point_id=="save_maze_respite","continues actual original maze respite")
        var wallet: int=scene.currency_count
        var moss: int=scene.inventory_counts.get("moss_chitin",0)
        if not await _leap(Vector2(1200,5420),999,"normal west altar descent around the root bench"):await _finish_stage();return
        if not await _clear_nearby():await _finish_stage();return
        _check(scene.currency_count==wallet+8 and scene.inventory_counts.get("moss_chitin",0)==moss+1,"actual altar guardian grants its normal reward once")
        if not await _leap(Vector2(1335,5332),999,"normal original dash altar pedestal"):await _finish_stage();return
        if not scene.inventory_counts.has("thread_dash"):await _world_interact()
        _check(scene.inventory_counts.get("thread_dash",0)==1 and scene.player.dash_unlocked,"actually obtains original permanent thread dash")
        if not await _walk_without_jump(Vector2(1300,5332)):await _finish_stage();return
        if not await _altar_return():await _finish_stage();return
        if not await _leap(Vector2(1420,5064),999,"normal jump over the respite root bench"):await _finish_stage();return
        if not await _walk_without_jump(Vector2(1520,5120)):await _finish_stage();return
        if not await _heart_interact("save_maze_respite",1520):await _finish_stage();return
        _check(scene.active_save_point_id=="save_maze_respite","actual altar return is rested")
    elif route_stage == 4:
        _check(scene.active_save_point_id=="save_maze_respite","continues actual altar return rest")
        for point in [Vector2(1850,5020),Vector2(2190,4832)]:
            if not await _leap(point,35,"normal old well to return stair"):await _finish_stage();return
        for point in [Vector2(2360,4740),Vector2(2190,4620),Vector2(2360,4372)]:
            if not await _leap(point,20,"normal stair around the moss refuge ceiling"):await _finish_stage();return
        for index in range(16,19,2):
            var point := Vector2(2360,5568-92*(index-1))
            if not await _leap(point,35,"normal eastern same-column double jump"):await _finish_stage();return
        if not await _walk_without_jump(Vector2(2420,4004)):await _finish_stage();return
        for height in [3820,3636,3452]:
            if not await _leap(Vector2(2420,height),35,"normal narrow stair beside crawlway"):await _finish_stage();return
        if not await _leap(Vector2(2430,3268),35,"normal return stair crown"):await _finish_stage();return
        if not await _leap(Vector2(2240,3160),35,"normal original bellbone station"):await _finish_stage();return
        print("DASH_RETURN_STATION ",scene.player.position)
        if not await _walk_without_jump(Vector2(2340,3160)):await _finish_stage();return
        if not await _observe_dash():await _finish_stage();return
        _check(not scene.locked_gate_bodies.has("gate_dash_cache"),"earned dash actually releases the original cache gate")
        if not await _walk_without_jump(Vector2(2070,3160)):await _finish_stage();return
        if not await _leap(Vector2(1740,3160),35,"normal original dash cache return gate"):await _finish_stage();return
        _check(scene.inventory_counts.get("quiet_sole",0)==1,"original automatic-contact quiet sole is actually collected once")
        if not await _walk_without_jump(Vector2(1700,3160)):await _finish_stage();return
        _check(scene.inventory_counts.get("quiet_sole",0)==1,"continued contact cannot duplicate the original reward")
        await _capture("original_quiet_sole")
        if not await _leap(Vector2(2100,3160),35,"normal original cache safe return"):await _finish_stage();return
        if not await _leap(Vector2(1740,3160),35,"actual reentry into original collected cache"):await _finish_stage();return
        _check(scene.inventory_counts.get("quiet_sole",0)==1,"actual exit and reentry cannot duplicate original quiet sole")
        if not await _leap(Vector2(2100,3160),35,"normal return after collected cache reentry"):await _finish_stage();return
        if not await _walk_without_jump(Vector2(2710,3892)):await _finish_stage();return
        if not await _walk_without_jump(Vector2(2480,3892)):await _finish_stage();return
        if not await _leap(Vector2(2340,3812),999,"normal return through original low crawlway"):await _finish_stage();return
        if not await _walk_without_jump(Vector2(1980,3812)):await _finish_stage();return
        if not await _leap(Vector2(1710,3752),35,"normal first bell ledge return"):await _finish_stage();return
        if not await _heart_interact("save_first_bell",1710):await _finish_stage();return
        _check(scene.active_save_point_id=="save_first_bell","actual dash cache journey returns to rest")
        await _capture("rested_first_bell")
    elif route_stage == 5:
        var proof: Variant=JSON.parse_string(FileAccess.get_file_as_string(proof_file)) if not proof_file.is_empty() else null
        var valid:=proof is Dictionary
        var actual:=_stage_proof()
        if valid:
            var pid: Variant=proof.get("pid",0)
            valid=typeof(pid) in [TYPE_INT,TYPE_FLOAT] and pid>0 and pid==int(pid) and OS.get_process_id()!=int(pid)
            for key in ["region","checkpoint","wallet","inventory","build","story","collected","shortcuts"]:
                valid=valid and proof.has(key) and _exact_state(actual[key],proof[key])
        _check(valid,"independent PID restores exact earned wallet inventory build story collected gates and checkpoint")
        _check(scene.active_save_point_id=="save_first_bell" and scene.player.position.distance_to(Vector2(1710,3752))<50,"new process resumes at actual final rested first bell")
        _check(scene.inventory_counts.get("thread_dash",0)==1 and scene.inventory_counts.get("quiet_sole",0)==1 and scene.player.dash_unlocked and not scene.locked_gate_bodies.has("gate_dash_cache"),"new process retains actual dash original gate release and exactly one quiet sole")
        _check(scene.player.dash_timer<=0 and scene.player.dash_cooldown<=0 and scene.player.hp==scene.player.max_hp and scene.player.energy==scene.player.max_energy,"new process restores safe rest without leftover action timers")
    else:
        _check(false,"unknown dash route stage")
    await _finish_stage()

func _capture(label: String) -> void:
    if capture_dir.is_empty() or DisplayServer.get_name()=="headless":return
    await RenderingServer.frame_post_draw
    var frame_image:=root.get_texture().get_image()
    _check(frame_image.save_png(capture_dir.path_join(label+".png"))==OK,"actual native frame is captured")

func _stage_proof() -> Dictionary:
    return {"pid":OS.get_process_id(),"stage":route_stage,"region":String(scene.config.id),"checkpoint":String(scene.active_save_point_id),"wallet":scene.currency_count,"inventory":scene.inventory_counts.duplicate(true),"build":scene.build_system.serialize(),"story":scene.story_flags.duplicate(true),"collected":scene.world_collected_ids.duplicate(true),"shortcuts":scene.opened_shortcuts.duplicate(true)}

func _exact_state(actual: Variant,expected: Variant) -> bool:
    if actual is Dictionary and expected is Dictionary:
        if actual.size()!=expected.size():return false
        for key in actual:
            if not expected.has(key) or not _exact_state(actual[key],expected[key]):return false
        return true
    if actual is Array and expected is Array:
        if actual.size()!=expected.size():return false
        for i in actual.size():
            if not _exact_state(actual[i],expected[i]):return false
        return true
    if typeof(actual) in [TYPE_INT,TYPE_FLOAT] and typeof(expected) in [TYPE_INT,TYPE_FLOAT]:return actual==expected
    return typeof(actual)==typeof(expected) and actual==expected

func _ability_observed(id: String,origin: Vector2,_direction: Vector2) -> void:
    if id=="thread_dash":dash_actions+=1
    print("DASH_RETURN_ABILITY ",id," ",origin)

func _observe_dash() -> bool:
    steps+=1
    wall_return=true
    _release()
    await _tick(5)
    _axis(-1)
    await _tick(2)
    var start: Vector2=scene.player.position
    var before:=dash_actions
    Input.action_press("dash")
    await process_frame
    await _tick(2)
    Input.action_release("dash")
    var active: float=scene.player.dash_timer
    await _capture("actual_dash_active")
    _check(dash_actions==before+1 and active>0,"actual dash action signal and positive motion timer")
    await _tick(12)
    _release()
    var displacement: float=start.x-scene.player.position.x
    _check(displacement>90 and scene.player.dash_timer<=0 and scene.player.dash_cooldown>0,"real dash moves and terminates normally into cooldown")
    print("DASH_RETURN_MOTION ",JSON.stringify({"actions":dash_actions-before,"active_timer":active,"displacement":displacement,"end_timer":scene.player.dash_timer,"cooldown":scene.player.dash_cooldown}))
    await _tick(45)
    _check(scene.player.dash_timer<=0 and scene.player.dash_cooldown<=0,"normal dash leaves no timer or cooldown residue")
    wall_return=false
    return failures==0

func _near_foe() -> Node2D:
    if wall_return:return null
    return super._near_foe()

func _altar_return() -> bool:
    steps+=1
    _release()
    await process_frame
    await process_frame
    await _tick(3)
    Input.action_press("jump")
    await process_frame
    for frame in 220:
        var p: CharacterBody2D=scene.player
        _axis(1 if p.position.y<5110 else 0)
        if frame==17:Input.action_release("jump")
        if frame==20:Input.action_press("jump")
        if frame==50:Input.action_release("jump")
        await _tick()
        if p.is_on_floor() and absf(p.position.y-5120)<8:
            _release();return true
        if frame%40==0:print("DASH_ALTAR_RETURN ",p.position)
    _release()
    _check(false,"normal double jump around altar bank has not returned")
    return false

func _overgrowth_descent() -> bool:
    steps+=1
    _release()
    var departed_edge := false
    for frame in 600:
        var p: CharacterBody2D=scene.player
        if p.position.x>=995:departed_edge=true
        if not departed_edge:
            Input.action_release("move_left")
            Input.action_press("move_right",0.25)
        else:
            _axis(signf(780-p.position.x) if absf(780-p.position.x)>8 else 0)
        await _tick()
        if p.is_on_floor() and p.position.y>=3750 and p.position.y<=4200:
            _release()
            print("DASH_OVERGROWTH_LANDING ",p.position)
            return true
        if frame%60==0:print("DASH_OVERGROWTH_PENDING ",p.position)
    _release()
    _check(false,"normal root-road edge descent has not reached the overgrowth")
    return false

func _finish_stage() -> void:
    _release()
    _check(deaths==0,"earned dash return stage survives without death")
    if failures==0:
        var exported := FileAccess.open(export_save,FileAccess.WRITE)
        _check(exported!=null,"actual stage save can be exported verbatim")
        if exported!=null:
            exported.store_buffer(FileAccess.get_file_as_bytes(DASH_SAVE))
            exported.close()
        print("DASH_RETURN_STAGE_PROOF ",JSON.stringify(_stage_proof()))
    print("WORLD_EARNED_DASH_RETURN stage=%d steps=%d failures=%d deaths=%d damage_events=%d heals=%d" % [route_stage,steps,failures,deaths,damage_events,heals])
    preload("res://scripts/audio_retirement.gd").retire_tree(scene)
    scene.queue_free()
    scene=null
    await process_frame
    _check(await preload("res://scripts/audio_retirement.gd").drain(self),"stage audio retires")
    call_deferred("quit",0 if failures==0 else 1)
