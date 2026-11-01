extends "res://scripts/world_greenhouse_west_playback.gd"
const DEATH_SAVE := "user://test_world_g02_earned_death.json"
const DEATH_SEED := "res://../artifacts/t04_greenhouse_west/earned_west_seed.json"
var records: Array=[]
var expected_inventory: Dictionary={}
var fatal_safe := Vector2.ZERO
var phase := 0
var previous_proof: Dictionary={}
func _run() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--g02-phase="):phase=int(arg.trim_prefix("--g02-phase="))
        if arg.begins_with("--g02-proof="):previous_proof=JSON.parse_string(arg.trim_prefix("--g02-proof="))
    if phase==0:
        var bytes:=FileAccess.get_file_as_bytes(DEATH_SEED)
        _check(not bytes.is_empty(),"normal west seed available")
        for suffix in ["", ".bak", ".tmp"]:
            if FileAccess.file_exists(DEATH_SAVE+suffix):DirAccess.remove_absolute(ProjectSettings.globalize_path(DEATH_SAVE+suffix))
        var file:=FileAccess.open(DEATH_SAVE,FileAccess.WRITE)
        file.store_buffer(bytes)
        file.close()
    scene=load("res://scenes/World.tscn").instantiate()
    scene.world_resume=true
    scene.world_save_path=DEATH_SAVE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene=scene
    await _tick(15)
    if phase==0:_check(scene.currency_count==259,"normal seed wallet restores exactly")
    else:
        _check(typeof(previous_proof.get("pid")) in [TYPE_INT,TYPE_FLOAT] and previous_proof.get("pid",0)>0 and previous_proof.pid==int(previous_proof.pid) and previous_proof.pid!=OS.get_process_id(),"phase resumes in independent PID")
        var actual:=_proof()
        for key in ["wallet","cache","inventory","build","charted","checkpoint","region"]:
            _check(previous_proof.has(key) and _same_json(actual[key],previous_proof[key]),"new process retains exact "+key)
        if failures>0:await _finish();return
    if phase<3:
        if not await _to_moss():await _finish();return
        if phase==1:
            if not await _recover_knot():await _finish();return
        if not await _natural_death(phase):await _finish();return
    elif phase==3:
        if scene.player.position.distance_to(Vector2(scene.world_state.data.death_cache.position[0],scene.world_state.data.death_cache.position[1]))>100:
            if not await _to_moss():await _finish();return
        if not await _recover_knot():await _finish();return
    await _finish()
func _proof() -> Dictionary:
    return {"pid":OS.get_process_id(),"wallet":scene.currency_count,"cache":scene.world_state.data.get("death_cache",{}).duplicate(true),"inventory":scene.inventory_counts.duplicate(true),"build":scene.build_system.serialize(),"charted":JOURNAL.region(scene.story_flags,String(scene.config.id)).charted.duplicate(true),"checkpoint":scene.active_save_point_id,"region":String(scene.config.id)}
func _to_moss() -> bool:
    if not await _walk_without_jump(Vector2(2560,1732)):return false
    if not await _walk_without_jump(Vector2(2730,1856)):return false
    if not await _walk_without_jump(Vector2(2400,1982)):return false
    for point in [Vector2(2200,1864),Vector2(2040,1756),Vector2(2200,1650),Vector2(1960,1562)]:
        if not await _leap(point,20,"earned death route"):return false
    return true
func _natural_death(cycle: int) -> bool:
    var wallet: int=scene.currency_count
    var inventory: Dictionary=scene.inventory_counts.duplicate(true)
    var build: Dictionary=scene.build_system.serialize()
    var chart: Dictionary=JOURNAL.region(scene.story_flags,String(scene.config.id)).charted.duplicate(true)
    var old: Dictionary=scene.world_state.data.get("death_cache",{}).duplicate(true)
    print("G02_PREDEATH ",JSON.stringify({"wallet":wallet,"last_safe":str(scene.last_safe_ground),"boss_spawned":scene.boss_spawned,"death_recorded":scene.death_recorded,"build":scene.build_system.serialize()}))
    var before: int=deaths
    for frame in 900:
        _axis(-1)
        await _tick()
        if deaths>before:
            _release()
            break
    _release()
    _check(deaths==before+1,"existing fake moss causes one actual death")
    for frame in 300:
        await _tick()
        if scene.player.hp>0 and scene.player.death_timer<=0 and not scene.world_loading:break
    await _tick(15)
    _check(not scene.boss_spawned and not is_instance_valid(scene.boss_actor),"same-process field respawn never auto-starts unlocked Boss")
    _check(not is_instance_valid(scene.boss_arena_lock_body) and not scene.audio_director.boss_active,"same-process field respawn has no lock or Boss music")
    var cache: Dictionary=scene.world_state.data.get("death_cache",{}).duplicate(true)
    _check(Vector2(cache.position[0],cache.position[1]).distance_to(fatal_safe)<2,"field knot equals actual last safe permanent floor at fatal hit")
    _check(_same_json(scene.build_system.serialize(),build) and _same_json(JOURNAL.region(scene.story_flags,String(scene.config.id)).charted,chart),"actual death preserves exact build and chart")
    _check(scene.currency_count==wallet-int(wallet/2),"actual death deducts exactly floor half")
    _check(cache.get("currency",-1)==int(wallet/2),"actual cache holds exactly floor half")
    _check(_same_json(scene.inventory_counts,inventory),"death preserves exact abilities materials and equipment")
    _check(scene.player.hp==scene.player.max_hp and scene.player.position.distance_to(Vector2(2750,1562))<100,"normal death respawns at earned heart checkpoint")
    if cycle==2:_check(not old.is_empty() and old.get("currency",-1)>0 and cache.currency!=old.currency,"second unrecovered death replaces old currency rather than adding it")
    records.append({"cycle":cycle,"wallet_before":wallet,"wallet_after":scene.currency_count,"old_cache":old,"cache":cache,"inventory":inventory,"hp":scene.player.hp,"energy":scene.player.energy})
    print("G02_DEATH ",JSON.stringify(records[-1]))
    return failures==0
func _recover_knot() -> bool:
    var cache: Dictionary=scene.world_state.data.get("death_cache",{}).duplicate(true)
    _check(not cache.is_empty(),"actual outstanding knot exists before return")
    if cache.is_empty():return false
    var x: float=cache.position[0]
    if scene.player.position.distance_to(Vector2(x,cache.position[1]))>65:
        if not await _walk_without_jump(Vector2(x,cache.position[1])):return false
    var wallet: int=scene.currency_count
    var target: Area2D=scene.interaction_target()
    _check(target!=null and target.get_meta("kind","")=="death_cache","normal F targets actual recovery knot")
    if failures>0:return false
    await _world_interact()
    _check(scene.currency_count==wallet+int(cache.currency) and scene.world_state.data.get("death_cache",{}).is_empty(),"normal F recovers exact new cache and clears persistent cache")
    print("G02_RECOVERY ",JSON.stringify({"before":wallet,"recovered":cache.currency,"after":scene.currency_count}))
    return failures==0
func _tick(count: int=1) -> void:
    for unused in count:
        _battle_inputs()
        await physics_frame
        frames+=1
        if is_instance_valid(scene) and is_instance_valid(scene.player):
            assert(not scene.player.debug_invulnerable)
            if scene.player.hp<last_hp:damage_events+=1
            if scene.player.hp==0 and last_hp>0:
                deaths+=1
                fatal_safe=scene.last_safe_ground
            last_hp=scene.player.hp
func _finish() -> void:
    _release()
    print("G02_PHASE_PROOF ",JSON.stringify(_proof()))
    var snapshot:=FileAccess.open("user://test_g02_snapshot_%d.json"%phase,FileAccess.WRITE)
    snapshot.store_buffer(FileAccess.get_file_as_bytes(DEATH_SAVE))
    snapshot.close()
    print("G02_SNAPSHOT ",ProjectSettings.globalize_path("user://test_g02_snapshot_%d.json"%phase))
    _check(deaths==(1 if phase<3 else 0),"phase observes exact expected actual death count")
    print("G02_FINAL ",JSON.stringify({"deaths":deaths,"damage":damage_events,"wallet":scene.currency_count,"cache":scene.world_state.data.get("death_cache",{}),"records":records}))
    print("WORLD_G02_DEATH failures=%d deaths=%d damage_suppression=false"%[failures,deaths])
    scene.queue_free()
    for unused in 10:await process_frame
    quit(0 if failures==0 else 1)

func _leap(target: Vector2, second_frame: int, label: String) -> bool:
    var start_deaths: int=deaths
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
        if deaths>start_deaths:break
    _release()
    _check(false,"leap blocked: "+label+" at "+str(scene.player.position))
    return false
