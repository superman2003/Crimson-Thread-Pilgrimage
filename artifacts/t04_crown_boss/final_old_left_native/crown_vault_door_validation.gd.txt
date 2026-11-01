extends SceneTree
## Positioned final-door collision fixture only, never earned exploration evidence.
var scene: Node2D
var failures:=0
var frames:=0
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var path: String="res://data/demo_ch06_silent_crown_core.json"
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--slot-config="):path=arg.trim_prefix("--slot-config=")
    scene=load("res://scenes/Main.tscn").instantiate()
    scene.config_path=path
    scene.world_save_path="user://test_crown_vault_door_fixture.json"
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    _check(String(scene.config.id)=="demo_ch06_silent_crown_core","positioned fixture loads the exact requested C6 data")
    scene.set_process(false)
    scene.set_physics_process(false)
    for enemy in get_nodes_in_group("enemy"):
        enemy.set_process(false)
        enemy.set_physics_process(false)
        enemy.set_collision_layer_value(3,false)
        if enemy is Area2D:enemy.monitoring=false
    for hazard in scene.find_children("ch06_hazard*","Area2D",true,false):hazard.monitoring=false
    scene.player.double_jump_unlocked=false
    scene.player.wall_grip_unlocked=false
    var selected_side:="both"
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--vault-side="):selected_side=arg.trim_prefix("--vault-side=")
    for side in (["right","left"] if selected_side=="both" else [selected_side]):
        var origin:=Vector2(3000,3060) if side=="right" else Vector2(2250,3040)
        scene.player.position=origin
        scene.player.velocity=Vector2.ZERO
        scene.cave_world.warm_collision_focus(scene.player.position)
        await _tick(20)
        if await _walk_without_jump(Vector2(2690,3106),side):
            _check(absf(scene.player.position.y-3106)<4,"ordinary walking reaches the real final-door shrine floor")
            if await _walk_without_jump(origin,side+"_return"):
                _check(absf(scene.player.position.y-origin.y)<4,"ordinary walking preserves the reverse front-corridor approach")
        if failures>0:break
    if failures==0:
        scene.player.position=Vector2(2570,2900)
        scene.player.velocity=Vector2.ZERO
        scene.cave_world.warm_collision_focus(scene.player.position)
        await _tick(20)
        if await _leap(Vector2(2730,2900),999,"ordinary upper vault route remains intact"):
            _check(absf(scene.player.position.y-2900)<4,"original upper vault top remains unchanged")
    print("CROWN_VAULT_DOOR failures=",failures)
    _release()
    preload("res://scripts/audio_retirement.gd").retire_tree(scene)
    scene.queue_free()
    for unused in 10:await process_frame
    preload("res://scripts/audio_director.gd")._stream_cache.clear()
    preload("res://scripts/audio_director.gd")._npc_voice_cache.clear()
    _check(await preload("res://scripts/audio_retirement.gd").drain(self),"vault door fixture retires audio")
    quit(0 if failures==0 else 1)
func _check(ok: bool,label: String) -> void:
    if ok:print("PASS ",label)
    else:failures+=1;push_error(label)
func _tick(count: int=1) -> void:
    for unused in count:
        await physics_frame
        frames+=1
        assert(not scene.player.debug_invulnerable)
func _axis(axis: float) -> void:
    Input.action_release("move_left");Input.action_release("move_right")
    if axis>0:Input.action_press("move_right")
    elif axis<0:Input.action_press("move_left")
func _release() -> void:
    for action in ["move_left","move_right","jump"]:Input.action_release(action)
func _walk_without_jump(target: Vector2,label: String) -> bool:
    _release()
    for frame in 220:
        var p: CharacterBody2D=scene.player
        _axis(signf(target.x-p.position.x) if absf(target.x-p.position.x)>7 else 0)
        await _tick()
        if absf(target.x-p.position.x)<16 and absf(target.y-p.position.y)<4 and p.is_on_floor():_release();return true
    _release();_check(false,"walk-only route blocked "+label+" at "+str(scene.player.position));return false
func _leap(target: Vector2, _second: int,label: String) -> bool:
    _release();await _tick(3)
    Input.action_press("jump")
    await process_frame
    for frame in 220:
        var p: CharacterBody2D=scene.player
        _axis(signf(target.x-p.position.x) if absf(target.x-p.position.x)>7 else 0)
        if _second<200 and frame==_second-3:Input.action_release("jump");await process_frame
        if _second<200 and frame==_second:Input.action_press("jump");await process_frame
        if frame==(_second+30 if _second<200 else 35):Input.action_release("jump")
        await _tick()
        if frame>10 and absf(target.x-p.position.x)<16 and absf(target.y-p.position.y)<4 and p.is_on_floor():
            _release();print("RAIN_SLOT_ORDINARY_JUMP ",label," ",p.position);return true
    _release();_check(false,"ordinary jump blocked: "+label+" at "+str(scene.player.position));return false
