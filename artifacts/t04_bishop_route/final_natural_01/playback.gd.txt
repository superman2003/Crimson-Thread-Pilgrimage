extends "res://scripts/world_greenhouse_vault_playback.gd"
## Actual-input climb from the normally earned vault return checkpoint.
const BISHOP_SAVE := "user://test_world_greenhouse_bishop.json"
const VAULT_SEED := "res://../artifacts/t04_greenhouse_vault/earned_vault_seed.json"
var bishop_fighting := false
var bishop_active: Dictionary={}
var bishop_windup: Dictionary={}
func _run() -> void:
    for argument in OS.get_cmdline_user_args():
        if String(argument).begins_with("--bishop-restart-proof="):
            var proof: Variant=JSON.parse_string(String(argument).trim_prefix("--bishop-restart-proof="))
            if not proof is Dictionary:
                _check(false,"bishop restart proof must be a dictionary")
                quit(1)
                return
            await _verify_bishop_restart(proof)
            return
    var bytes:=FileAccess.get_file_as_bytes(VAULT_SEED)
    _check(not bytes.is_empty(),"normally earned vault return seed exists")
    if bytes.is_empty():quit(1);return
    for suffix in ["", ".bak", ".tmp"]:
        if FileAccess.file_exists(BISHOP_SAVE+suffix):DirAccess.remove_absolute(ProjectSettings.globalize_path(BISHOP_SAVE+suffix))
    var file:=FileAccess.open(BISHOP_SAVE,FileAccess.WRITE)
    _check(file!=null,"private bishop save can be written")
    if file==null:quit(1);return
    file.store_buffer(bytes)
    file.close()
    scene=load("res://scenes/World.tscn").instantiate()
    scene.world_resume=true
    scene.world_save_path=BISHOP_SAVE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene=scene
    await _tick(15)
    _check(scene.active_save_point_id=="save_ch04_lower_loop" and scene.currency_count==243 and scene.boss_unlocked,"restores actual vault lever and tree heart checkpoint")
    if not await _walk_without_jump(Vector2(3170,1602)):await _finish();return
    if not await _clear_nearby():await _finish();return
    if not await _walk_without_jump(Vector2(3315,1632)):await _finish();return
    trace_ceiling=true
    if not await _leap(Vector2(3480,1632),999,"ordinary jump onto the actual crown return rock"):await _finish();return
    _check(scene.player.double_jump_unlocked,"the normally earned double jump is active")
    scene.player.ability_action.connect(func(id: String,origin: Vector2,_direction: Vector2):print("BISHOP_APPROACH_ABILITY ",id," ",origin))
    if not await _leap(Vector2(3560,1494),20,"tree crown return onto first rising vine"):await _finish();return
    for target in [Vector2(3750,1384),Vector2(3570,1274),Vector2(3770,1164),Vector2(3595,1054)]:
        if not await _leap(target,20,"tree crown rising vine"):await _finish();return
    if not await _walk_without_jump(Vector2(3660,1054)):await _finish();return
    if not await _leap(Vector2(3770,948),999,"ordinary jump to the final crown vine"):await _finish();return
    trace_ceiling=false
    if not await _leap(Vector2(3770,882),999,"single jump back to the actual canopy"):await _finish();return
    if not await _leap(Vector2(4190,928),35,"canopy eastern bank"):await _finish();return
    if not await _vine_bee_duel("E08",4240,-1):await _finish();return
    if not await _walk_without_jump(Vector2(4280,928)):await _finish();return
    if not await _leap(Vector2(4590,892),35,"safe landing beyond the canopy clapper"):await _finish();return
    if not await _leap(Vector2(4820,806),20,"dome rising vine"):await _finish();return
    if not await _leap(Vector2(5110,762),20,"actual dome shrine deck"):await _finish();return
    await _world_interact()
    _check(scene.active_save_point_id=="save_late_runback" and scene.player.hp==scene.player.max_hp,"normal F rests at the actually reached dome shrine")
    await _inspect_map_without_position()
    if not await _leap(Vector2(5380,794),35,"normal thorn sentinel threshold"):await _finish();return
    if not await _clear_nearby():await _finish();return
    if not await _leap(Vector2(5110,762),35,"return to rest after the actual sentinel"):await _finish();return
    await _world_interact()
    _check(scene.player.hp==scene.player.max_hp and scene.player.energy==scene.player.max_energy,"normal dome rest before the full-health Boss")
    if not await _leap(Vector2(5400,794),35,"cleared bishop threshold"):await _finish();return
    if not await _walk_without_jump(Vector2(5490,794)):await _finish();return
    if not await _leap(Vector2(5710,832),999,"ordinary jump to the actual bishop gate"):await _finish();return
    await _world_interact()
    _check(scene.boss_spawned and is_instance_valid(scene.boss_actor) and scene.boss_actor.hp==22,"normal F starts the actual full-health 22 HP bishop")
    if not scene.boss_spawned:await _finish();return
    var wallet: int=scene.currency_count
    await _fight_bishop()
    _check(scene.demo_complete,"normal actual inputs defeat the bishop")
    for id in ["boss_bishop_staff","boss_bishop_seeds","boss_bishop_roots","boss_bishop_cage"]:
        _check(bishop_active.has(id),"bishop actually uses "+id)
    _check(scene.currency_count==wallet+30 and scene.inventory_counts.get("silent_mark_greenhouse",0)==1,"actual victory awards the normal fragments and one greenhouse mark")
    _check(bool(scene.story_flags.get("boss_down_ch04",false)) and scene.boss_arena_lock_body==null,"actual bishop victory persists and releases the arena lock")
    if failures>0:await _finish();return
    await _tick(95)
    if not await _walk_without_jump(Vector2(5730,832)):await _finish();return
    if not await _leap(Vector2(5400,794),35,"return across the defeated bishop gate"):await _finish();return
    if not await _leap(Vector2(5110,762),35,"return to the actual dome shrine after victory"):await _finish();return
    await _world_interact()
    _check(scene.active_save_point_id=="save_late_runback" and scene.player.hp==scene.player.max_hp and scene.player.energy==scene.player.max_energy,"normal dome rest after the bishop victory")
    await _inspect_map_without_position()
    if failures==0:
        var earned:=FileAccess.open("user://test_world_bishop_earned_seed.json",FileAccess.WRITE)
        _check(earned!=null,"actual bishop victory checkpoint can be archived")
        if earned!=null:
            earned.store_buffer(FileAccess.get_file_as_bytes(BISHOP_SAVE))
            earned.close()
            print("BISHOP_EARNED_SEED ",ProjectSettings.globalize_path("user://test_world_bishop_earned_seed.json"))
    await _finish()

func _near_foe() -> Node2D:
    if bishop_fighting:return null
    return super._near_foe()

func _fight_bishop() -> void:
    steps+=1
    bishop_fighting=true
    combat_enabled=false
    _release()
    var boss: Node2D=scene.boss_actor
    var previous: String=""
    var jump_at := -100
    var skill_at := -100
    var crossing_at := -1000
    var crossing_goal := 0.0
    var crossing_start := 0.0
    var crossing_double := false
    var crossing_moving := false
    var dash_at := -100
    for frame in 5200:
        if not is_instance_valid(boss) or scene.demo_complete or deaths>0:break
        var p: CharacterBody2D=scene.player
        var state: String=String(boss.state)
        var kind: String=String(boss.active_attack.get("type",""))
        var id: String=String(boss.active_attack.get("id",""))
        var key:=state+":"+id
        if key!=previous:
            print("BISHOP_STATE ",JSON.stringify({"frame":frame,"state":state,"attack":id,"boss_hp":boss.hp,"boss_position":str(boss.position),"player_position":str(p.position),"hp":p.hp,"energy":p.energy,"remaining":boss.state_timer}))
            if state=="active":bishop_active[id]=int(bishop_active.get(id,0))+1
            if state=="windup":bishop_windup[id]=int(bishop_windup.get(id,0))+1
            previous=key
        if frame-jump_at>=35 and Input.is_action_pressed("jump"):Input.action_release("jump")
        if frame-skill_at>=2 and Input.is_action_pressed("skill_1"):Input.action_release("skill_1")
        if frame-dash_at>=2 and Input.is_action_pressed("dash"):Input.action_release("dash")
        var side: float=signf(p.position.x-boss.position.x)
        if side==0:side=-1
        var waiting: bool=boss.hp<=11 and bishop_active.size()<4
        var goal: float=boss.position.x+side*(325 if waiting else 125)
        var punish: bool=(state in ["patrol","recover"] or (state in ["windup","active"] and kind in ["fan","rootline","pool"])) and not waiting
        if state in ["windup","active"] and kind=="melee":goal=boss.position.x+side*270
        goal=clampf(goal,5660,6240)
        var danger_near := false
        var jump_now := false
        var parry_now := false
        var projectile_near := false
        var hazards: Array=[]
        for effect in get_nodes_in_group("hostile_attack"):
            if not is_instance_valid(effect) or effect.owner_actor!=boss or effect.hit_player:continue
            var time: float=effect.arm_delay-effect.age
            if effect.effect_kind in ["pool","eruption"]:
                hazards.append(effect)
                if absf(effect.position.x-p.position.x)<effect.radius+55 and time<p.heal_duration+0.2:danger_near=true
                if absf(effect.position.x-p.position.x)<effect.radius+(6 if effect.effect_kind=="eruption" else 12) and time<0.16:jump_now=true
            elif effect.effect_kind=="projectile" and not effect.reflected:
                var distance: float=effect.position.distance_to(p.position-Vector2(0,42))
                if distance<170:projectile_near=true
                if distance<97:parry_now=true
        if not hazards.is_empty():
            var best := INF
            for candidate in range(5660,6241,20):
                if absf(candidate-boss.position.x)<(230 if kind=="melee" and state in ["windup","active"] else 110):continue
                var safe := true
                for hazard in hazards:
                    if hazard.arm_delay-hazard.age<0.6 and absf(candidate-hazard.position.x)<hazard.radius+14:safe=false;break
                if not safe:continue
                var score: float=absf(candidate-goal)+absf(candidate-p.position.x)*0.35+(300 if (candidate-boss.position.x)*(p.position.x-boss.position.x)<0 else 0)
                if score<best:best=score;goal=candidate
        if (goal-boss.position.x)*(p.position.x-boss.position.x)<0 and frame-crossing_at>=100 and p.is_on_floor() and p.attack_timer<=0 and p.hurt_timer<=0:
            crossing_at=frame
            crossing_goal=goal
            crossing_start=p.position.x
            crossing_double=false
            crossing_moving=false
            Input.action_press("jump")
            jump_at=frame
            await process_frame
        if frame-crossing_at<100:
            if not crossing_moving and p.position.y<boss.position.y-154:
                crossing_moving=true
                _axis(signf(crossing_goal-p.position.x))
                if p.dash_cooldown<=0:
                    Input.action_press("dash");dash_at=frame;await process_frame
            goal=crossing_goal if crossing_moving else crossing_start
            punish=false
            if frame-crossing_at==17 and Input.is_action_pressed("jump"):Input.action_release("jump");await process_frame
            if frame-crossing_at>=20 and not crossing_double and p.air_jump_available and p.attack_timer<=0 and p.hurt_timer<=0:
                Input.action_press("jump");jump_at=frame;crossing_double=true;await process_frame
        elif jump_now and p.is_on_floor() and p.attack_timer<=0 and p.hurt_timer<=0:
            Input.action_press("jump");jump_at=frame;await process_frame
        if projectile_near and not danger_near and frame-crossing_at>=100 and kind!="melee":goal=p.position.x
        _axis(signf(goal-p.position.x) if absf(goal-p.position.x)>7 else 0)
        if parry_now and p.attack_timer<=0 and p.hurt_timer<=0:
            if p.facing!=signi(boss.position.x-p.position.x):_axis(signf(boss.position.x-p.position.x))
            Input.action_press("attack");attack_pressed_frame=frames
            print("BISHOP_PROJECTILE_PARRY_INPUT ",str(p.position))
        if not danger_near and state=="recover" and boss.state_timer>p.heal_duration+0.1 and p.hp<=3 and p.energy>=p.heal_energy_cost and frame-crossing_at>=100:
            await _recover()
            continue
        var dx: float=boss.position.x-p.position.x
        if punish and not projectile_near and absf(dx)<170 and p.hurt_timer<=0 and p.attack_timer<=0 and p.skill_cooldown<=0 and p.energy>=75 and frames%30==5:
            if p.facing!=signi(dx):_axis(signf(dx))
            Input.action_press("skill_1");skill_at=frame;await process_frame
        if punish and not projectile_near and absf(dx)<172 and p.hurt_timer<=0 and p.attack_timer<=0 and frames%24==0:
            if p.facing!=signi(dx):_axis(signf(dx))
            Input.action_press("attack")
            attack_pressed_frame=frames
        await _tick()
        if frame%300==299:print("BISHOP_PENDING ",JSON.stringify({"frame":frame,"hp":p.hp,"energy":p.energy,"boss_hp":boss.hp,"position":str(p.position),"state":key}))
    _release()
    Input.action_release("skill_1")
    Input.action_release("dash")
    bishop_fighting=false
    print("BISHOP_OBSERVED ",JSON.stringify({"windups":bishop_windup,"active":bishop_active}))

func _finish() -> void:
    _release()
    Input.action_release("skill_1")
    Input.action_release("dash")
    _check(deaths==0,"bishop continuation survives without death")
    if failures==0:
        print("BISHOP_RESTART_PROOF ",JSON.stringify({"pid":OS.get_process_id(),"region":String(scene.config.id),"checkpoint":String(scene.active_save_point_id),"wallet":scene.currency_count,"inventory":scene.inventory_counts.duplicate(true),"charted":JOURNAL.region(scene.story_flags,String(scene.config.id)).charted.duplicate(true)}))
    print("BISHOP_FINISH_STATE ",JSON.stringify({"position":str(scene.player.position),"hp":scene.player.hp,"energy":scene.player.energy,"wallet":scene.currency_count,"inventory":scene.inventory_counts,"checkpoint":scene.active_save_point_id}))
    print("WORLD_BISHOP_ROUTE steps=%d failures=%d damage_events=%d heals=%d deaths=%d damage_suppression=false earned_checkpoint=true" % [steps,failures,damage_events,heals,deaths])
    scene.queue_free()
    scene=null
    for unused in 10:await process_frame
    quit(0 if failures==0 else 1)

func _verify_bishop_restart(proof: Dictionary) -> void:
    scene=load("res://scenes/World.tscn").instantiate()
    scene.world_resume=true
    scene.world_save_path=BISHOP_SAVE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene=scene
    await _tick(15)
    var previous_pid: Variant=proof.get("pid",0)
    _check(typeof(previous_pid) in [TYPE_INT,TYPE_FLOAT] and previous_pid>0 and previous_pid==int(previous_pid) and OS.get_process_id()!=int(previous_pid),"bishop checkpoint opens in a different process")
    _check(String(scene.config.id)==String(proof.get("region","")) and scene.active_save_point_id==String(proof.get("checkpoint","")),"bishop restart retains the actual region and checkpoint")
    _check(scene.active_save_point_id=="save_late_runback" and scene.player.position.distance_to(Vector2(5110,722))<90,"bishop restart resumes at the actual rested dome shrine")
    _check(scene.currency_count==proof.get("wallet",-1),"bishop restart retains exact victory income without a duplicate reward")
    _check(_inventory_matches(scene.inventory_counts,proof.get("inventory",{})),"bishop restart retains every exact earned item count")
    var chart: Dictionary=JOURNAL.region(scene.story_flags,String(scene.config.id))
    _check(not proof.get("charted",{}).is_empty() and chart.charted==proof.get("charted",{}),"bishop restart retains all actually charted notes")
    _check(JOURNAL.owned(scene.story_flags,String(scene.config.id)) and JOURNAL.has_quill(scene.story_flags),"bishop restart retains the paid map and quill")
    _check(scene.demo_complete and bool(scene.story_flags.get("boss_down_ch04",false)) and not scene.boss_spawned and scene.boss_arena_lock_body==null,"actual bishop defeat persists without respawn or arena lock")
    _check(scene.inventory_counts.get("silent_mark_greenhouse",0)==1 and scene.inventory_counts.get("thorn_downstrike",0)==1 and scene.player.thorn_downstrike_unlocked,"bishop mark and actually earned downstrike persist exactly once")
    _check(bool(scene.opened_shortcuts.get("ch04_west_spoke_shortcut",false)),"actual root vault lever remains open after bishop victory")
    await _inspect_map_without_position()
    print("WORLD_BISHOP_ROUTE_RESTART failures=%d pid_changed=true" % failures)
    _release()
    scene.queue_free()
    scene=null
    for unused in 10:await process_frame
    quit(0 if failures==0 else 1)
