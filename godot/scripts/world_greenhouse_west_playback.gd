extends "res://scripts/world_greenhouse_route_playback.gd"
## Input-only west spoke physical round trip from the normally earned vault seed.
const VAULT_SAVE := "user://test_world_greenhouse_west.json"
const HEART_SEED := "res://../artifacts/t04_greenhouse_vault/earned_vault_seed.json"
func _run() -> void:
    for argument in OS.get_cmdline_user_args():
        if String(argument).begins_with("--greenhouse-west-restart-proof="):
            var proof: Variant=JSON.parse_string(String(argument).trim_prefix("--greenhouse-west-restart-proof="))
            if not proof is Dictionary:
                _check(false,"west physical loop restart proof must be a dictionary")
                quit(1)
                return
            await _verify_vault_restart(proof)
            return
    var bytes:=FileAccess.get_file_as_bytes(HEART_SEED)
    _check(not bytes.is_empty(),"earned tree heart seed exists")
    if bytes.is_empty():quit(1);return
    for suffix in ["", ".bak", ".tmp"]:
        if FileAccess.file_exists(VAULT_SAVE+suffix):DirAccess.remove_absolute(ProjectSettings.globalize_path(VAULT_SAVE+suffix))
    var file:=FileAccess.open(VAULT_SAVE,FileAccess.WRITE)
    _check(file!=null,"private west save can be written")
    if file==null:quit(1);return
    file.store_buffer(bytes)
    file.close()
    scene=load("res://scenes/World.tscn").instantiate()
    scene.world_resume=true
    scene.world_save_path=VAULT_SAVE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene=scene
    await _tick(15)
    _check(scene.active_save_point_id=="save_ch04_lower_loop" and scene.currency_count==243 and scene.player.thorn_downstrike_unlocked,"restores actual earned tree heart and downstrike")
    if not await _walk_without_jump(Vector2(2560,1732)):await _finish();return
    if not await _walk_without_jump(Vector2(2730,1856)):await _finish();return
    if not await _walk_without_jump(Vector2(2400,1982)):await _finish();return
    for point in [Vector2(2200,1864),Vector2(2040,1756),Vector2(2200,1650),Vector2(1960,1562)]:
        if not await _leap(point,20,"west physical spoke"):await _finish();return
    if not await _leap(Vector2(1500,1604),20,"west run b"):await _finish();return
    if not await _walk_without_jump(Vector2(1330,1604)):await _finish();return
    for point in [Vector2(1070,1556),Vector2(700,1520),Vector2(460,1568)]:
        if not await _leap(point,20,"west entrance approach"):await _finish();return
    if not await _walk_without_jump(Vector2(570,1780)):await _finish();return
    print("GREENHOUSE_WEST_ENTRANCE_REACHED ",scene.player.position)
    if not await _gate_return():await _finish();return
    for point in [Vector2(700,1520),Vector2(1070,1556),Vector2(1500,1604)]:
        if not await _leap(point,20,"west physical return"):await _finish();return
    if not await _walk_without_jump(Vector2(1570,1604)):await _finish();return
    if not await _leap(Vector2(1960,1562),35,"clear west fake moss return"):await _finish();return
    if not await _leap(Vector2(2200,1650),20,"return onto west lift c"):await _finish();return
    for point in [Vector2(2040,1756),Vector2(2200,1864),Vector2(2400,1982)]:
        if not await _walk_without_jump(point):await _finish();return
    if not await _walk_without_jump(Vector2(2600,1982)):await _finish();return
    if not await _leap(Vector2(2740,1856),20,"root step b"):await _finish();return
    if not await _walk_without_jump(Vector2(2656,1856)):await _finish();return
    if not await _leap(Vector2(2550,1732),20,"root step a"):await _finish();return
    if not await _walk_without_jump(Vector2(2590,1732)):await _finish();return
    if not await _leap(Vector2(2770,1602),20,"tree heart return"):await _finish();return
    if not await _heart_interact("save_ch04_lower_loop",2750):await _finish();return
    _check(scene.player.hp==scene.player.max_hp and scene.player.energy==scene.player.max_energy,"normal tree heart rest after the vault return")
    await _inspect_map_without_position()
    if failures==0:
        var earned:=FileAccess.open("user://test_world_greenhouse_west_earned_seed.json",FileAccess.WRITE)
        _check(earned!=null,"actual west physical loop return checkpoint can be archived")
        if earned!=null:
            earned.store_buffer(FileAccess.get_file_as_bytes(VAULT_SAVE))
            earned.close()
            print("GREENHOUSE_WEST_EARNED_SEED ",ProjectSettings.globalize_path("user://test_world_greenhouse_west_earned_seed.json"))
    await _finish()

func _finish() -> void:
    _release()
    Input.action_release("aim_down")
    _check(deaths==0,"west physical loop route survives without death")
    if failures==0:
        print("GREENHOUSE_WEST_RESTART_PROOF ",JSON.stringify({"pid":OS.get_process_id(),"region":String(scene.config.id),"checkpoint":String(scene.active_save_point_id),"wallet":scene.currency_count,"build_state":scene.build_system.serialize(),"inventory":scene.inventory_counts.duplicate(true),"charted":JOURNAL.region(scene.story_flags,String(scene.config.id)).charted.duplicate(true)}))
    print("GREENHOUSE_WEST_STATE ",JSON.stringify({"position":str(scene.player.position),"hp":scene.player.hp,"energy":scene.player.energy,"wallet":scene.currency_count,"inventory":scene.inventory_counts,"checkpoint":scene.active_save_point_id,"shortcuts":scene.opened_shortcuts}))
    print("WORLD_GREENHOUSE_WEST steps=%d failures=%d damage_events=%d heals=%d deaths=%d damage_suppression=false earned_checkpoint=true" % [steps,failures,damage_events,heals,deaths])
    scene.queue_free()
    scene=null
    for unused in 10:await process_frame
    quit(0 if failures==0 else 1)

func _verify_vault_restart(proof: Dictionary) -> void:
    scene=load("res://scenes/World.tscn").instantiate()
    scene.world_resume=true
    scene.world_save_path=VAULT_SAVE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene=scene
    await _tick(15)
    var previous_pid: Variant=proof.get("pid",0)
    _check(typeof(previous_pid) in [TYPE_INT,TYPE_FLOAT] and previous_pid>0 and previous_pid==int(previous_pid) and OS.get_process_id()!=int(previous_pid),"west physical loop checkpoint opens in a different process")
    _check(String(scene.config.id)==String(proof.get("region","")) and scene.active_save_point_id==String(proof.get("checkpoint","")),"west physical loop restart retains actual region and checkpoint")
    _check(scene.active_save_point_id=="save_ch04_lower_loop" and scene.player.position.distance_to(Vector2(2750,1562))<90,"restart resumes at the actual tree heart rest after the vault")
    _check(scene.currency_count==proof.get("wallet",-1),"west physical loop restart retains exact earned income")
    _check(_inventory_matches(scene.inventory_counts,proof.get("inventory",{})),"west physical loop restart retains every exact earned item count")
    print("WEST_BUILD_ACTUAL ",JSON.stringify(scene.build_system.serialize()))
    _check(not proof.get("build_state",{}).is_empty() and _same_json(scene.build_system.serialize(),proof.get("build_state",{})),"west restart retains exact build state")
    var chart: Dictionary=JOURNAL.region(scene.story_flags,String(scene.config.id))
    _check(not proof.get("charted",{}).is_empty() and chart.charted==proof.get("charted",{}),"west physical loop restart retains all actually charted notes")
    _check(JOURNAL.owned(scene.story_flags,String(scene.config.id)) and JOURNAL.has_quill(scene.story_flags),"west physical loop restart retains paid map and quill")
    _check(scene.inventory_counts.get("thorn_downstrike",0)==1 and scene.player.thorn_downstrike_unlocked and scene.inventory_counts.get("testimony_04",0)==1,"west physical loop restart retains the actual downstrike and testimony once")
    _check(bool(scene.opened_shortcuts.get("ch04_west_spoke_shortcut",false)) and scene.boss_unlocked and not scene.demo_complete,"actual west physical loop lever persists while the greenhouse Boss remains undefeated")
    await _inspect_map_without_position()
    print("WORLD_GREENHOUSE_WEST_RESTART failures=%d pid_changed=true" % failures)
    _release()
    scene.queue_free()
    scene=null
    for unused in 10:await process_frame
    quit(0 if failures==0 else 1)

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
        if frame%50==49:print("WHEEL_LEAP pending ",label," ",player.position," velocity=",player.velocity," hp=",player.hp)
        if deaths>0:break
    _release()
    _check(false,"leap blocked: "+label+" at "+str(scene.player.position))
    return false

func _gate_return() -> bool:
    steps+=1
    _release()
    await _tick(3)
    Input.action_press("jump")
    await process_frame
    for frame in 220:
        var p: CharacterBody2D=scene.player
        var target_x: float=570 if p.position.y>1555 and frame<60 else 460
        _axis(signf(target_x-p.position.x) if absf(target_x-p.position.x)>2 else 0)
        if frame==17:Input.action_release("jump")
        if frame==20:Input.action_press("jump")
        if frame==50:Input.action_release("jump")
        await _tick()
        if frame>20 and p.is_on_floor() and absf(p.position.y-1568)<8:
            _release()
            print("WEST_GATE_RETURN ",p.position)
            return true
        if frame%40==39:print("WEST_GATE_PENDING ",p.position)
    _check(false,"side approach gate return failed")
    return false

func _same_json(a: Variant,b: Variant) -> bool:
    if a is Dictionary and b is Dictionary:
        if a.size()!=b.size():return false
        for key in a:
            if not b.has(key) or not _same_json(a[key],b[key]):return false
        return true
    if a is Array and b is Array:
        if a.size()!=b.size():return false
        for i in a.size():
            if not _same_json(a[i],b[i]):return false
        return true
    if typeof(a) in [TYPE_INT,TYPE_FLOAT] and typeof(b) in [TYPE_INT,TYPE_FLOAT]:return float(a)==float(b)
    return typeof(a)==typeof(b) and a==b
