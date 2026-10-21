extends "res://scripts/world_waterwheel_route_playback.gd"
## Damage-enabled earned-checkpoint continuation; all four moves and the hook vault.
## No grants, position writes or damage suppression; not a fresh campaign or human playtest.
const SMITH_SAVE := "user://test_world_smith_route.json"
const FORGE_SEED := "res://../artifacts/w02_spillway/earned_forge_seed.json"
var observed_attacks: Dictionary={}
var active_attacks: Dictionary={}
var boss_damage_events := 0
func _run() -> void:
    for argument in OS.get_cmdline_user_args():
        if String(argument).begins_with("--smith-restart-proof="):
            var proof: Variant=JSON.parse_string(String(argument).trim_prefix("--smith-restart-proof="))
            if not proof is Dictionary:
                _check(false,"restart proof must be a JSON object")
                quit(1)
                return
            await _verify_smith_restart(proof)
            return
    var bytes:=FileAccess.get_file_as_bytes(FORGE_SEED)
    _check(not bytes.is_empty(),"earned forge seed exists")
    for suffix in ["", ".bak", ".tmp"]:
        if FileAccess.file_exists(SMITH_SAVE+suffix):DirAccess.remove_absolute(ProjectSettings.globalize_path(SMITH_SAVE+suffix))
    var destination:=FileAccess.open(SMITH_SAVE,FileAccess.WRITE)
    _check(destination!=null,"private smith replay save can be written")
    if destination==null:
        quit(1)
        return
    destination.store_buffer(bytes)
    destination.close()
    scene=load("res://scenes/World.tscn").instantiate()
    scene.world_resume=true
    scene.world_save_path=SMITH_SAVE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene=scene
    await _tick(15)
    _check(scene.active_save_point_id=="save_ch02_forge" and scene.currency_count==94 and scene.boss_unlocked,"restores earned forge progression")
    await _walk(Vector2(5100,3760),"eastern forge ledge")
    if not await _leap(Vector2(5330,3820),35,"normal jump to the smith gate"):
        await _finish(false)
        return
    await _world_interact()
    _check(scene.boss_spawned and is_instance_valid(scene.boss_actor),"normal F starts the authored smith encounter")
    if not scene.boss_spawned:
        await _finish(false)
        return
    var wallet: int=scene.currency_count
    await _fight()
    _check(scene.demo_complete,"actual input defeats the full-health smith")
    _check(active_attacks.has("boss_shears_knots") and active_attacks.has("boss_shears_turn"),"fight naturally covers the knot formation and second-phase vault")
    _check(scene.inventory_counts.has("smith_oath_plate") and scene.currency_count==wallet+30,"real boss awards its oath plate and 30 fragments")
    _check(bool(scene.story_flags.get("boss_down_ch02",false)),"boss story flag persists naturally")
    _check(scene.boss_arena_lock_body==null,"boss defeat removes the actual arena lock")
    _check(deaths==0,"earned forge boss continuation completes without death")
    if failures>0:
        await _finish(false)
        return
    await _tick(15)
    var earned:=FileAccess.open("user://test_world_postsmith_earned_seed.json",FileAccess.WRITE)
    _check(earned!=null,"normally earned post-Boss save can be archived")
    if earned==null:
        await _finish(false)
        return
    earned.store_buffer(FileAccess.get_file_as_bytes(SMITH_SAVE))
    earned.close()
    print("SMITH_BOSS_EARNED_POINT ",ProjectSettings.globalize_path("user://test_world_postsmith_earned_seed.json"))
    await _postboss()
    await _finish(failures==0)

func _fight() -> void:
    steps+=1
    _release()
    var boss: Node2D=scene.boss_actor
    var previous: String=""
    var pool_until := -1
    var pool_goal := 0.0
    var jump_until := -1
    var attack_at := -100
    var initial_damage: int=damage_events
    for frame in 5200:
        if not is_instance_valid(boss) or scene.demo_complete:break
        if deaths>0 or scene.player.hp<=0:break
        var player: CharacterBody2D=scene.player
        var state: String=String(boss.state)
        var attack: String=String(boss.active_attack.get("type",""))
        var id: String=String(boss.active_attack.get("id",""))
        var key: String=state+":"+id
        var side: float=signf(player.position.x-boss.position.x)
        if side==0:side=-1
        if key!=previous:
            print("SMITH_STATE ",JSON.stringify({"frame":frame,"state":state,"attack":id,"boss_hp":boss.hp,"boss_position":str(boss.position),"player_position":str(player.position),"hp":player.hp,"energy":player.energy,"remaining":boss.state_timer}))
            if state=="windup":
                observed_attacks[id]=int(observed_attacks.get(id,0))+1
                if attack=="pool":
                    pool_goal=clampf(player.position.x+side*58,5285,5935)
                    pool_until=frame+180
            if state=="active":active_attacks[id]=int(active_attacks.get(id,0))+1
            previous=key
        if frame-attack_at>=3:Input.action_release("attack")
        if frame>=jump_until and Input.is_action_pressed("jump"):Input.action_release("jump")
        var goal: float=boss.position.x+side*155
        var punish: bool=state in ["patrol","recover"]
        if state in ["windup","active"] and attack=="melee":goal=boss.position.x+side*275
        elif attack=="vault":
            if state=="windup":goal=boss.position.x+side*275
            elif state=="active":goal=boss.position.x-float(boss.attack_direction)*230
            punish=false
        if boss.hp<=12 and (not active_attacks.has("boss_shears_turn") or not active_attacks.has("boss_shears_knots")):
            punish=false
            if state=="patrol":goal=boss.position.x+side*290
        if frame<pool_until:
            goal=pool_goal
            punish=false
        if attack=="vault" and state=="active":goal=boss.position.x-float(boss.attack_direction)*230
        goal=clampf(goal,5265,5955)
        _axis(signf(goal-player.position.x) if absf(goal-player.position.x)>7 else 0)
        if state=="windup" and ((attack=="beam" and boss.state_timer<0.26) or (attack=="melee" and frame<pool_until and boss.state_timer<0.45)) and player.is_on_floor() and frame>=jump_until:
            Input.action_press("jump")
            await process_frame
            jump_until=frame+20
        if attack=="beam" and state=="active" and frame>=jump_until+3 and player.air_jump_available:
            Input.action_press("jump")
            await process_frame
            jump_until=frame+20
        if state=="recover" and player.hp<=3 and player.energy>=player.heal_energy_cost and boss.state_timer>0.45 and player.is_on_floor():
            await _recover()
            continue
        var dx: float=boss.position.x-player.position.x
        if punish and absf(dx)<172 and player.hurt_timer<=0 and frames%24==0:
            if player.facing!=signi(dx):_axis(signf(dx))
            Input.action_press("attack")
            attack_at=frame
        await _tick()
        if frame%300==299:print("SMITH_PENDING frame=",frame," hp=",player.hp," energy=",player.energy," boss_hp=",boss.hp," state=",key)
    _release()
    boss_damage_events=damage_events-initial_damage
    print("SMITH_OBSERVED_ATTACKS ",JSON.stringify({"windups":observed_attacks,"active":active_attacks}))

func _finish(ok: bool) -> void:
    _release()
    Input.action_release("skill_1")
    if ok and failures==0:
        print("SMITH_RESTART_PROOF ",JSON.stringify({"pid":OS.get_process_id(),"region":String(scene.config.id),"checkpoint":String(scene.active_save_point_id),"wallet":scene.currency_count,"inventory":scene.inventory_counts.duplicate(true)}))
    print("WORLD_SMITH_ROUTE steps=%d failures=%d damage_events=%d heals=%d deaths=%d damage_suppression=false earned_checkpoint=true" % [steps,failures,boss_damage_events,heals,deaths])
    scene.queue_free()
    scene=null
    for unused in 10:await process_frame
    quit(0 if ok else 1)

func _postboss() -> void:
    _check(not scene.inventory_counts.has("echo_hook") and scene.locked_gate_bodies.has("gate_hook_chain"),"hook and chain gate remain unavailable before the actual pickup")
    await _walk(Vector2(5880,3820),"eastern smith arena exit")
    if not await _leap(Vector2(6120,3780),35,"jump to the outfall bank"):return
    for index in range(1,19):
        var point:=Vector2(6475 if index%2==0 else 6255,3780-index*94)
        await _walk(point,"pendulum gantry return step %d" % index,false,true)
        if failures>0:return
    if not await _leap(Vector2(6475,1900),20,"earned double jump at the workshop eave"):return
    if not await _leap(Vector2(6240,1840),20,"pendulum workshop landing"):return
    await _walk(Vector2(6170,1840),"actual echo-hook pickup")
    _check(scene.inventory_counts.has("echo_hook") and scene.player.thread_grapple_unlocked,"normal collision collects the actual echo hook")
    _check(not scene.locked_gate_bodies.has("gate_hook_chain") and not scene.locked_gate_bodies.has("gate_hook_skylight"),"earned hook opens both actual ability gates")
    var uses: Array=[]
    scene.player.ability_action.connect(func(id: String, point: Vector2, direction: Vector2):
        if id=="echo_hook":uses.append({"position":str(point),"direction":str(direction)}))
    _axis(1)
    await _tick(3)
    _axis(0)
    Input.action_press("aim_up")
    await process_frame
    Input.action_press("hook")
    await process_frame
    await _tick(3)
    Input.action_release("hook")
    Input.action_release("aim_up")
    for frame in 120:
        await _tick()
        if frame>5 and scene.player.grapple_timer<=0 and scene.player.is_on_floor():break
    _check(uses.size()==1,"real upward hook input uses the workshop copper ring once")
    print("SMITH_EARNED_HOOK ",JSON.stringify(uses))
    await _walk(Vector2(6385,1840),"open chain gate western bank")
    if not await _leap(Vector2(6700,1780),35,"real hook-gate crossing"):return
    var badges: int=int(scene.inventory_counts.get("worker_badge",0))
    await _walk(Vector2(6750,1780),"chain vault reward")
    _check(int(scene.inventory_counts.get("worker_badge",0))==badges+1,"normal vault visit collects its authored worker badge")
    await _walk(Vector2(6630,1780),"chain vault return bank")
    if not await _leap(Vector2(6360,1840),35,"return through the open hook gate"):return
    _check(deaths==0,"boss and hook-vault continuation returns without death")

func _verify_smith_restart(proof: Dictionary) -> void:
    scene=load("res://scenes/World.tscn").instantiate()
    scene.world_resume=true
    scene.world_save_path=SMITH_SAVE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene=scene
    await _tick(15)
    var previous_pid: Variant=proof.get("pid",0)
    _check(typeof(previous_pid) in [TYPE_INT,TYPE_FLOAT] and previous_pid>0 and previous_pid==int(previous_pid) and OS.get_process_id()!=int(previous_pid),"smith checkpoint opens in a different engine process")
    _check(String(scene.config.id)==String(proof.get("region","")) and scene.active_save_point_id==String(proof.get("checkpoint","")),"restart restores the actual earned region and checkpoint")
    _check(scene.player.position.distance_to(Vector2(4920,3720))<90,"restart uses the forge checkpoint")
    _check(scene.currency_count==proof.get("wallet",-1),"restart retains exact boss income without a duplicate reward")
    _check(_inventory_matches(scene.inventory_counts,proof.get("inventory",{})),"restart retains exact item counts, including hook, oath plate and vault badge")
    _check(scene.demo_complete and bool(scene.story_flags.get("boss_down_ch02",false)) and not scene.boss_spawned,"restart keeps the actual Boss defeat without respawning it")
    _check(scene.player.thread_grapple_unlocked and not scene.locked_gate_bodies.has("gate_hook_chain"),"restart retains the earned hook and open gate")
    print("WORLD_SMITH_RESTART failures=%d pid_changed=true" % failures)
    _release()
    scene.queue_free()
    scene=null
    for unused in 10:await process_frame
    quit(0 if failures==0 else 1)
