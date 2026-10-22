extends "res://scripts/world_waterwheel_route_playback.gd"
## Actual-input continuation from the normally earned #191 index shrine save.
## Damage enabled; no grants or position writes; not a fresh campaign or human playtest.
const JUDGE_SAVE := "user://test_world_salt_judge_route.json"
const INDEX_SEED := "res://../artifacts/w02_salt_index_clearance/earned_index_seed.json"
var windups: Dictionary={}
var active_moves: Dictionary={}
var guard_blocks := 0
func _run() -> void:
    for argument in OS.get_cmdline_user_args():
        if String(argument).begins_with("--judge-restart-proof="):
            var proof: Variant=JSON.parse_string(String(argument).trim_prefix("--judge-restart-proof="))
            if not proof is Dictionary:
                _check(false,"judge restart proof must be a dictionary")
                quit(1)
                return
            await _verify_judge_restart(proof)
            return
    var bytes:=FileAccess.get_file_as_bytes(INDEX_SEED)
    _check(not bytes.is_empty(),"earned index seed exists")
    if bytes.is_empty():quit(1);return
    for suffix in ["", ".bak", ".tmp"]:
        if FileAccess.file_exists(JUDGE_SAVE+suffix):DirAccess.remove_absolute(ProjectSettings.globalize_path(JUDGE_SAVE+suffix))
    var file:=FileAccess.open(JUDGE_SAVE,FileAccess.WRITE)
    _check(file!=null,"private judge save can be written")
    if file==null:quit(1);return
    file.store_buffer(bytes)
    file.close()
    scene=load("res://scenes/World.tscn").instantiate()
    scene.world_resume=true
    scene.world_save_path=JUDGE_SAVE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene=scene
    await _tick(15)
    _check(scene.active_save_point_id=="save_late_runback" and scene.currency_count==156 and scene.player.bell_guard_unlocked and scene.boss_unlocked,"restores actual index checkpoint and earned guard")
    if not await _walk_without_jump(Vector2(5220,2606)):await _finish();return
    if not await _leap(Vector2(5400,2648),999,"single jump to the contract threshold"):await _finish();return
    if not await _walk_without_jump(Vector2(5490,2648)):await _finish();return
    if not await _leap(Vector2(5710,2704),999,"single jump to the actual judge gate"):await _finish();return
    await _world_interact()
    _check(scene.boss_spawned and is_instance_valid(scene.boss_actor) and scene.boss_actor.hp==22,"normal F starts the full-health 22 HP judge")
    if not scene.boss_spawned:await _finish();return
    var wallet: int=scene.currency_count
    await _fight_judge()
    _check(scene.demo_complete,"actual inputs defeat the full-health judge")
    for id in ["boss_mantis_guard","boss_mantis_lunge","boss_mantis_overhead","boss_mantis_flurry"]:
        _check(active_moves.has(id),"judge naturally uses "+id)
    _check(guard_blocks>0,"earned bell guard actually blocks a Boss strike")
    _check(scene.inventory_counts.get("silent_mark_saltwhite",0)==1 and scene.currency_count==wallet+30,"normal judge victory awards one mark and thirty fragments")
    _check(bool(scene.story_flags.get("boss_down_ch03",false)) and scene.boss_arena_lock_body==null,"actual victory persists and removes the arena lock")
    if failures>0:await _finish();return
    await _tick(95)
    if not await _walk_without_jump(Vector2(5730,2704)):await _finish();return
    if not await _leap(Vector2(5420,2648),35,"return through the defeated judge gate"):await _finish();return
    if not await _walk_without_jump(Vector2(5365,2648)):await _finish();return
    if not await _leap(Vector2(5180,2606),999,"return to the actual index shrine"):await _finish();return
    await _world_interact()
    _check(scene.active_save_point_id=="save_late_runback" and scene.player.hp==scene.player.max_hp,"normal shrine rest after judge victory")
    if failures==0:
        var earned:=FileAccess.open("user://test_world_salt_judge_earned_seed.json",FileAccess.WRITE)
        _check(earned!=null,"actual judge checkpoint can be archived")
        if earned!=null:
            earned.store_buffer(FileAccess.get_file_as_bytes(JUDGE_SAVE))
            earned.close()
            print("JUDGE_EARNED_SEED ",ProjectSettings.globalize_path("user://test_world_salt_judge_earned_seed.json"))
    await _finish()

func _fight_judge() -> void:
    steps+=1
    _release()
    var boss: Node2D=scene.boss_actor
    var previous := ""
    var attack_at := -100
    var jump_at := -100
    var guard_at := -100
    var escape_until := -1
    var escape_goal := 0.0
    var escape_jump_at := -100
    var escape_double_done := true
    for frame in 5200:
        if not is_instance_valid(boss) or scene.demo_complete or deaths>0:break
        var player: CharacterBody2D=scene.player
        if player.hp<=0:break
        var state: String=String(boss.state)
        var kind: String=String(boss.active_attack.get("type",""))
        var id: String=String(boss.active_attack.get("id",""))
        var key: String=state+":"+id
        var side: float=signf(player.position.x-boss.position.x)
        if side==0:side=-1
        if key!=previous:
            print("JUDGE_STATE ",JSON.stringify({"frame":frame,"state":state,"attack":id,"boss_hp":boss.hp,"boss_position":str(boss.position),"player_position":str(player.position),"hp":player.hp,"energy":player.energy,"remaining":boss.state_timer}))
            if state=="windup":windups[id]=int(windups.get(id,0))+1
            if state=="active":active_moves[id]=int(active_moves.get(id,0))+1
            previous=key
        if frame-attack_at>=3:Input.action_release("attack")
        if frame-guard_at>=2:Input.action_release("bell_guard")
        if frame-jump_at>=35 and Input.is_action_pressed("jump"):Input.action_release("jump")
        var goal: float=boss.position.x+side*125
        var punish: bool=state in ["patrol","recover"]
        if state in ["windup","active"] and kind in ["guard","melee"]:goal=boss.position.x+side*265
        if state in ["windup","active"] and kind=="combo":goal=boss.position.x-float(boss.attack_direction)*215
        if boss.hp<=11 and active_moves.size()<4:punish=false
        var escape_needed: bool=state=="windup" and (kind=="combo" or (kind in ["guard","melee"] and (goal<5650 or goal>6230)))
        if escape_needed and frame>=escape_until:
            punish=false
            if not player.is_on_floor() or (player.attack_timer<=0 and player.hurt_timer<=0 and player.heal_timer<=0):
                escape_goal=clampf(boss.position.x-float(boss.attack_direction)*250,5650,6230)
                escape_until=frame+90
                escape_jump_at=frame if player.is_on_floor() else frame-15
                escape_double_done=not player.air_jump_available
                if player.is_on_floor():
                    _axis(0)
                    Input.action_press("jump")
                    jump_at=frame
                    await process_frame
            else:
                goal=player.position.x
        if frame<escape_until:
            goal=escape_goal if frame-escape_jump_at>=15 else player.position.x
            punish=false
        if frame-escape_jump_at==14 and not escape_double_done and Input.is_action_pressed("jump"):
            Input.action_release("jump")
            await process_frame
        if frame-escape_jump_at>=17 and not escape_double_done and player.air_jump_available and player.attack_timer<=0 and player.hurt_timer<=0:
            Input.action_press("jump")
            jump_at=frame
            escape_double_done=true
            await process_frame
        goal=clampf(goal,5650,6230)
        _axis(signf(goal-player.position.x) if absf(goal-player.position.x)>7 else 0)
        if state=="windup" and kind=="lunge" and guard_blocks==0 and boss.state_timer<0.09 and player.guard_cooldown<=0 and player.energy>=8:
            _axis(signf(boss.position.x-player.position.x))
            Input.action_press("bell_guard")
            guard_at=frame
            await process_frame
        if kind=="lunge" and ((state=="windup" and guard_blocks>0 and boss.state_timer<0.22) or (state=="active" and guard_blocks>0)) and player.is_on_floor() and player.hurt_timer<=0.12:
            Input.action_press("jump")
            jump_at=frame
            await process_frame
        if state=="recover" and player.hp<=2 and player.energy>=player.heal_energy_cost and boss.state_timer>0.8 and player.is_on_floor():
            await _recover()
            continue
        var dx: float=boss.position.x-player.position.x
        if punish and absf(dx)<172 and player.hurt_timer<=0 and frames%24==0:
            if player.facing!=signi(dx):_axis(signf(dx))
            Input.action_press("attack")
            attack_at=frame
        await _tick()
        if frame%300==299:print("JUDGE_PENDING ",JSON.stringify({"frame":frame,"hp":player.hp,"energy":player.energy,"boss_hp":boss.hp,"position":str(player.position),"state":key}))
    _release()
    Input.action_release("bell_guard")
    print("JUDGE_OBSERVED ",JSON.stringify({"windups":windups,"active":active_moves,"guard_blocks":guard_blocks}))

func _tick(count: int=1) -> void:
    for unused in count:
        var guarded: bool=is_instance_valid(scene) and is_instance_valid(scene.player) and scene.player.guard_timer>0
        var hp: int=scene.player.hp if is_instance_valid(scene) and is_instance_valid(scene.player) else -1
        await super._tick()
        if "--judge-input-trace" in OS.get_cmdline_user_args() and is_instance_valid(scene.boss_actor) and scene.boss_actor.hp<=11 and frames%10==0:
            print("JUDGE_JUMP_SAMPLE ",JSON.stringify({"frame":frames,"position":str(scene.player.position),"velocity":str(scene.player.velocity),"floor":scene.player.is_on_floor(),"jump_pressed":Input.is_action_pressed("jump"),"jump_buffer":scene.player.jump_buffer_timer,"coyote":scene.player.coyote_timer,"attack":scene.player.attack_timer,"hurt":scene.player.hurt_timer,"locked":scene.player.ui_input_locked}))
        if guarded and scene.player.guard_timer<=0 and scene.player.hurt_timer>0 and scene.player.hp==hp:
            guard_blocks+=1
            print("JUDGE_GUARD_BLOCK ",JSON.stringify({"frame":frames,"hp":scene.player.hp,"energy":scene.player.energy,"perfect":scene.player.guard_refunded}))

func _finish() -> void:
    _release()
    Input.action_release("bell_guard")
    _check(deaths==0,"judge route survives without death")
    if failures==0:
        print("JUDGE_RESTART_PROOF ",JSON.stringify({"pid":OS.get_process_id(),"region":String(scene.config.id),"checkpoint":String(scene.active_save_point_id),"wallet":scene.currency_count,"inventory":scene.inventory_counts.duplicate(true),"charted":JOURNAL.region(scene.story_flags,String(scene.config.id)).charted.duplicate(true)}))
    print("WORLD_JUDGE_ROUTE steps=%d failures=%d damage_events=%d heals=%d deaths=%d damage_suppression=false earned_checkpoint=true" % [steps,failures,damage_events,heals,deaths])
    scene.queue_free()
    scene=null
    for unused in 10:await process_frame
    quit(0 if failures==0 else 1)

func _verify_judge_restart(proof: Dictionary) -> void:
    scene=load("res://scenes/World.tscn").instantiate()
    scene.world_resume=true
    scene.world_save_path=JUDGE_SAVE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene=scene
    await _tick(15)
    var previous_pid: Variant=proof.get("pid",0)
    _check(typeof(previous_pid) in [TYPE_INT,TYPE_FLOAT] and previous_pid>0 and previous_pid==int(previous_pid) and OS.get_process_id()!=int(previous_pid),"judge checkpoint opens in a different process")
    _check(String(scene.config.id)==String(proof.get("region","")) and scene.active_save_point_id==String(proof.get("checkpoint","")),"judge restart retains the actual region and checkpoint")
    _check(scene.active_save_point_id=="save_late_runback" and scene.player.position.distance_to(Vector2(5180,2566))<90,"judge restart actually resumes at the rested index shrine")
    _check(scene.currency_count==proof.get("wallet",-1),"judge restart retains exact victory income without a duplicate reward")
    _check(_inventory_matches(scene.inventory_counts,proof.get("inventory",{})),"judge restart retains every exact earned item count")
    var chart: Dictionary=JOURNAL.region(scene.story_flags,String(scene.config.id))
    _check(not proof.get("charted",{}).is_empty() and chart.charted==proof.get("charted",{}),"judge restart retains all actually charted archive notes")
    _check(JOURNAL.owned(scene.story_flags,String(scene.config.id)) and JOURNAL.has_quill(scene.story_flags),"judge restart retains the normally paid map and quill")
    _check(scene.demo_complete and bool(scene.story_flags.get("boss_down_ch03",false)) and not scene.boss_spawned and scene.boss_arena_lock_body==null,"actual judge victory persists without respawn or arena lock")
    _check(scene.inventory_counts.get("silent_mark_saltwhite",0)==1 and scene.inventory_counts.get("bell_guard",0)==1 and scene.player.bell_guard_unlocked,"judge mark and earned guard persist exactly once")
    _check(bool(scene.opened_shortcuts.get("ch03_salt_gate_shortcut",false)),"actual wax lever shortcut remains open after judge victory")
    await _inspect_map_without_position()
    print("WORLD_JUDGE_ROUTE_RESTART failures=%d pid_changed=true" % failures)
    _release()
    scene.queue_free()
    scene=null
    for unused in 10:await process_frame
    quit(0 if failures==0 else 1)
