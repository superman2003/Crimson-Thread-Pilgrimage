extends "res://scripts/world_obsidian_earned_playback.gd"
## Positioned collision fixture only; not earned exploration evidence.
func _run() -> void:
    scene=load("res://scenes/World.tscn").instantiate()
    scene.world_resume=false
    scene.world_save_path="user://test_obsidian_dock_clearance.json"
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene=scene
    var path: String="res://data/demo_ch05_obsidian_pilgrim_road.json"
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--clearance-config="):path=arg.trim_prefix("--clearance-config=")
    scene._travel_world(path,Vector2(3446,1964))
    for frame in 2000:
        if not _transition_busy():break
        await process_frame
    await _tick(10)
    scene.set_process(false)
    scene.set_physics_process(false)
    combat_enabled=false
    for enemy in get_nodes_in_group("enemy"):
        enemy.set_process(false)
        enemy.set_physics_process(false)
        enemy.set_collision_layer_value(3,false)
    for hazard in scene.find_children("ch05_hazard*","Area2D",true,false):
        hazard.monitoring=false
    scene.player.double_jump_unlocked=false
    scene.player.wall_grip_unlocked=false
    scene.player.position=Vector2(3446,1964)
    scene.player.velocity=Vector2.ZERO
    scene.cave_world.warm_collision_focus(scene.player.position)
    await _tick(20)
    trace_ceiling=true
    if await _leap(Vector2(3220,1868),999,"ordinary free shaft top exit"):
        _check(absf(scene.player.position.y-1868)<4,"upper gallery actual ground reached with ordinary jump")
    print("OBSIDIAN_DOCK_CLEARANCE failures=",failures)
    _release()
    scene.queue_free()
    scene=null
    for unused in 10:await process_frame
    for suffix in ["",".tmp",".bak"]:DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_obsidian_dock_clearance.json"+suffix))
    quit(0 if failures==0 else 1)

func _near_foe() -> Node2D:
    return null
