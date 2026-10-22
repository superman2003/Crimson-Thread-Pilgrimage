extends "res://scripts/world_greenhouse_route_playback.gd"
## Input-only continuation from the normally earned tree heart checkpoint.
const VAULT_SAVE := "user://test_world_greenhouse_vault.json"
const HEART_SEED := "res://../artifacts/t04_greenhouse/earned_heart_seed.json"
var downstrikes := 0
var vault_hits := 0
func _run() -> void:
    for argument in OS.get_cmdline_user_args():
        if String(argument).begins_with("--greenhouse-vault-restart-proof="):
            var proof: Variant=JSON.parse_string(String(argument).trim_prefix("--greenhouse-vault-restart-proof="))
            if not proof is Dictionary:
                _check(false,"root vault restart proof must be a dictionary")
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
    _check(file!=null,"private vault save can be written")
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
    _check(scene.active_save_point_id=="save_ch04_lower_loop" and scene.currency_count==235 and scene.player.thorn_downstrike_unlocked,"restores actual earned tree heart and downstrike")
    scene.player.ability_action.connect(func(id: String,origin: Vector2,_direction: Vector2):
        if id=="thorn_downstrike":
            downstrikes+=1
            print("GREENHOUSE_VAULT_DOWNSTRIKE ",origin))
    if not await _walk_without_jump(Vector2(2560,1732)):await _finish();return
    if not await _walk_without_jump(Vector2(2730,1856)):await _finish();return
    if not await _downstrike_vault_hunter():await _finish();return
    if not await _walk_without_jump(Vector2(2600,1982)):await _finish();return
    await _world_interact()
    _check(bool(scene.opened_shortcuts.get("ch04_west_spoke_shortcut",false)) and scene.boss_unlocked,"normal F opens the actual root vault lever and Boss route")
    if not await _leap(Vector2(2740,1856),20,"return onto root vault upper step"):await _finish();return
    if not await _walk_without_jump(Vector2(2656,1856)):await _finish();return
    if not await _leap(Vector2(2550,1732),20,"return onto root vault lower step"):await _finish();return
    if not await _walk_without_jump(Vector2(2590,1732)):await _finish();return
    if not await _leap(Vector2(2770,1602),20,"normal jump back into the tree heart"):await _finish();return
    if not await _heart_interact("save_ch04_lower_loop",2750):await _finish();return
    _check(scene.player.hp==scene.player.max_hp and scene.player.energy==scene.player.max_energy,"normal tree heart rest after the vault return")
    await _inspect_map_without_position()
    if failures==0:
        var earned:=FileAccess.open("user://test_world_greenhouse_vault_earned_seed.json",FileAccess.WRITE)
        _check(earned!=null,"actual root vault return checkpoint can be archived")
        if earned!=null:
            earned.store_buffer(FileAccess.get_file_as_bytes(VAULT_SAVE))
            earned.close()
            print("GREENHOUSE_VAULT_EARNED_SEED ",ProjectSettings.globalize_path("user://test_world_greenhouse_vault_earned_seed.json"))
    await _finish()

func _downstrike_vault_hunter() -> bool:
    steps+=1
    _release()
    await _tick(3)
    var target: Node2D
    for actor in get_nodes_in_group("enemy"):
        if is_instance_valid(actor) and actor.get("spawn_id")=="E12":target=actor
    _check(target!=null,"actual root vault hunter is present")
    if target==null:return false
    var wallet: int=scene.currency_count
    var pollen: int=scene.inventory_counts.get("pollen_wax",0)
    var prior_hp: int=target.hp
    Input.action_press("jump")
    for frame in 600:
        var player: CharacterBody2D=scene.player
        if not is_instance_valid(target) or target.hp<=0:
            _release()
            Input.action_release("aim_down")
            _check(vault_hits>0 and downstrikes>0,"actual downstrike damages the root vault hunter")
            _check(scene.currency_count==wallet+8 and scene.inventory_counts.get("pollen_wax",0)==pollen+1,"root vault hunter awards normal income and material")
            await _safe_recover()
            return failures==0
        var dx: float=target.position.x-player.position.x
        _axis(signf(dx) if absf(dx)>12 else 0)
        if frame>34 and Input.is_action_pressed("jump"):Input.action_release("jump")
        Input.action_press("aim_down")
        if not player.is_on_floor() and player.position.y>target.position.y-125 and player.position.y<target.position.y and player.attack_timer<=0 and player.hurt_timer<=0 and absf(dx)<70:
            Input.action_press("attack")
            attack_pressed_frame=frames
            await process_frame
        await _tick()
        if is_instance_valid(target) and target.hp<prior_hp:
            if downstrikes>0 and player.current_attack_direction.y>0.5:vault_hits+=prior_hp-target.hp
            prior_hp=target.hp
            print("GREENHOUSE_VAULT_HUNTER ",JSON.stringify({"hp":target.hp,"player":str(player.position),"direction":str(player.current_attack_direction),"downstrikes":downstrikes,"downstrike_damage":vault_hits}))
        if player.is_on_floor() and player.attack_timer<=0 and player.hurt_timer<=0 and frame%45==0:
            Input.action_press("jump")
            await process_frame
        if deaths>0:break
    _release()
    Input.action_release("aim_down")
    _check(false,"actual downstrike vault duel did not finish")
    return false

func _finish() -> void:
    _release()
    Input.action_release("aim_down")
    _check(deaths==0,"root vault route survives without death")
    if failures==0:
        print("GREENHOUSE_VAULT_RESTART_PROOF ",JSON.stringify({"pid":OS.get_process_id(),"region":String(scene.config.id),"checkpoint":String(scene.active_save_point_id),"wallet":scene.currency_count,"inventory":scene.inventory_counts.duplicate(true),"charted":JOURNAL.region(scene.story_flags,String(scene.config.id)).charted.duplicate(true)}))
    print("GREENHOUSE_VAULT_STATE ",JSON.stringify({"position":str(scene.player.position),"hp":scene.player.hp,"energy":scene.player.energy,"wallet":scene.currency_count,"inventory":scene.inventory_counts,"checkpoint":scene.active_save_point_id,"shortcuts":scene.opened_shortcuts,"downstrikes":downstrikes,"downstrike_damage":vault_hits}))
    print("WORLD_GREENHOUSE_VAULT steps=%d failures=%d damage_events=%d heals=%d deaths=%d damage_suppression=false earned_checkpoint=true" % [steps,failures,damage_events,heals,deaths])
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
    _check(typeof(previous_pid) in [TYPE_INT,TYPE_FLOAT] and previous_pid>0 and previous_pid==int(previous_pid) and OS.get_process_id()!=int(previous_pid),"root vault checkpoint opens in a different process")
    _check(String(scene.config.id)==String(proof.get("region","")) and scene.active_save_point_id==String(proof.get("checkpoint","")),"root vault restart retains actual region and checkpoint")
    _check(scene.active_save_point_id=="save_ch04_lower_loop" and scene.player.position.distance_to(Vector2(2750,1562))<90,"restart resumes at the actual tree heart rest after the vault")
    _check(scene.currency_count==proof.get("wallet",-1),"root vault restart retains exact earned income")
    _check(_inventory_matches(scene.inventory_counts,proof.get("inventory",{})),"root vault restart retains every exact earned item count")
    var chart: Dictionary=JOURNAL.region(scene.story_flags,String(scene.config.id))
    _check(not proof.get("charted",{}).is_empty() and chart.charted==proof.get("charted",{}),"root vault restart retains all actually charted notes")
    _check(JOURNAL.owned(scene.story_flags,String(scene.config.id)) and JOURNAL.has_quill(scene.story_flags),"root vault restart retains paid map and quill")
    _check(scene.inventory_counts.get("thorn_downstrike",0)==1 and scene.player.thorn_downstrike_unlocked and scene.inventory_counts.get("testimony_04",0)==1,"root vault restart retains the actual downstrike and testimony once")
    _check(bool(scene.opened_shortcuts.get("ch04_west_spoke_shortcut",false)) and scene.boss_unlocked and not scene.demo_complete,"actual root vault lever persists while the greenhouse Boss remains undefeated")
    await _inspect_map_without_position()
    print("WORLD_GREENHOUSE_VAULT_RESTART failures=%d pid_changed=true" % failures)
    _release()
    scene.queue_free()
    scene=null
    for unused in 10:await process_frame
    quit(0 if failures==0 else 1)
