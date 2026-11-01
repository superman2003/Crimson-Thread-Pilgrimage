extends "res://scripts/world_g02_death_playback.gd"
## Diagnostic World fixture: explicit placement and fatal damage, never natural-route evidence.
func _run() -> void:
    var file:=FileAccess.open(DEATH_SAVE+".fixture",FileAccess.WRITE)
    file.store_buffer(FileAccess.get_file_as_bytes(DEATH_SEED))
    file.close()
    scene=load("res://scenes/World.tscn").instantiate()
    scene.world_resume=true
    scene.world_save_path=DEATH_SAVE+".fixture"
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene=scene
    await _tick(15)
    _check(scene.boss_unlocked and not scene.boss_spawned,"earned World unlock is not a fight")
    await _fixture_ground(Vector2(1960,1562))
    await _fixture_death()
    _check(not scene.boss_spawned and not is_instance_valid(scene.boss_actor),"field respawn does not summon unlocked Boss")
    _check(not is_instance_valid(scene.boss_arena_lock_body),"field respawn leaves arena unlocked")
    _check(scene.audio_director!=null and not scene.audio_director.boss_active,"field respawn keeps exploration music")
    await _fixture_ground(Vector2(1960,1562))
    var safe: Vector2=scene.last_safe_ground
    await _fixture_death()
    var cache: Dictionary=scene.world_state.data.death_cache
    _check(Vector2(cache.position[0],cache.position[1]).distance_to(safe)<2,"second field death uses actual permanent last-safe floor")
    await _fixture_ground(Vector2(5710,792))
    scene.player.set_physics_process(false)
    var target: Area2D=scene.interaction_target()
    _check(target!=null and target.get_meta("kind","")=="boss_gate","fixture normal F is aimed at actual bell gate")
    await _world_interact()
    _check(scene.boss_spawned and is_instance_valid(scene.boss_actor) and is_instance_valid(scene.boss_arena_lock_body),"normal gate F still starts and locks actual Boss encounter")
    _check(scene.audio_director.boss_active,"normal gate F starts Boss music")
    await _fixture_death()
    cache=scene.world_state.data.death_cache
    _check(Vector2(cache.position[0],cache.position[1]).distance_to(scene.active_spawn)<2,"actual Boss attempt death puts knot at outside checkpoint")
    _check(not scene.boss_spawned and not is_instance_valid(scene.boss_arena_lock_body) and not scene.audio_director.boss_active,"World Boss defeat-by-death requires next manual retry")
    scene.boss_trial_mode=true
    scene._start_boss_trial()
    await _tick(10)
    _check(scene.boss_spawned,"trial starts Boss")
    await _fixture_death()
    _check(scene.boss_spawned and is_instance_valid(scene.boss_actor),"trial death retains dedicated automatic retry")
    scene.boss_trial_mode=false
    scene.world_mode=false
    scene._reset_encounters_after_player_death()
    await _tick(15)
    _check(scene.boss_spawned,"legacy non-World keeps automatic unlocked Boss respawn")
    _release()
    print("WORLD_G02_RESPAWN_FIXTURE failures=%d deaths=%d"%[failures,deaths])
    scene.queue_free()
    for unused in 10:await process_frame
    quit(0 if failures==0 else 1)
func _fixture_ground(point: Vector2) -> void:
    for actor in get_nodes_in_group("enemy"):
        if is_instance_valid(actor):actor.set_physics_process(false)
    scene.player.set_physics_process(true)
    scene.player.global_position=point
    scene.player.velocity=Vector2.ZERO
    await _tick(12)
func _fixture_death() -> void:
    for actor in get_nodes_in_group("enemy"):
        if is_instance_valid(actor):actor.set_physics_process(false)
    scene.player.set_physics_process(true)
    for frame in 120:
        if scene.player.arrival_guard_timer<=0 and scene.player.hurt_timer<=0:break
        await _tick()
    scene.player.take_damage(scene.player.max_hp,scene.player.global_position+Vector2(100,0),false)
    for frame in 240:
        await _tick()
        if scene.player.hp>0 and scene.player.death_timer<=0 and not scene.pending_enemy_respawn:break
    await _tick(10)
