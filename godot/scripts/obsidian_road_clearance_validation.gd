extends "res://scripts/world_obsidian_earned_playback.gd"
## Positioned collision fixture only; not earned exploration evidence.
func _run() -> void:
    scene=load("res://scenes/World.tscn").instantiate()
    scene.world_resume=false
    scene.world_save_path="user://test_obsidian_road_clearance.json"
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene=scene
    var path: String="res://data/demo_ch05_obsidian_pilgrim_road.json"
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--clearance-config="):path=arg.trim_prefix("--clearance-config=")
    scene._travel_world(path,Vector2(1638,2668))
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
    for pair in [[Vector2(1638,2668),Vector2(2010,2772)],[Vector2(2140,2732),Vector2(2440,2716)]]:
        scene.player.position=pair[0]
        scene.player.velocity=Vector2.ZERO
        await _tick(20)
        if not await _walk_without_jump(pair[1]):break
        _check(absf(scene.player.position.y-pair[1].y)<4,"actual floor reached under unchanged upper road")
    print("OBSIDIAN_ROAD_CLEARANCE failures=",failures)
    _release()
    scene.queue_free()
    scene=null
    for unused in 10:await process_frame
    for suffix in ["",".tmp",".bak"]:DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_obsidian_road_clearance.json"+suffix))
    quit(0 if failures==0 else 1)

func _near_foe() -> Node2D:
    return null
