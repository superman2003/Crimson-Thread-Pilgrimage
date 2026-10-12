extends SceneTree
## UI fixture: sets ability/latch state; does not traverse or unlock them naturally.
func _initialize() -> void: call_deferred("run")
func run() -> void:
    root.size=Vector2i(1280,720)
    var output := ProjectSettings.globalize_path("res://../artifacts/world_route_contract")
    DirAccess.make_dir_recursive_absolute(output)
    var scene: Node=load("res://scenes/World.tscn").instantiate()
    scene.world_resume=false
    scene.world_save_path="user://route_contract_capture.json"
    root.add_child(scene)
    scene.set_process(false)
    scene.player.set_physics_process(false)
    for enemy in get_nodes_in_group("enemy"): enemy.set_physics_process(false)
    scene._add_inventory_item("double_thread_jump",1,false)
    scene._toggle_map()
    scene.world_map_view=true
    for opened in [false,true]:
        scene.story_flags["world_shortcut_archive_return"]=opened
        scene._refresh_world_portals()
        scene._refresh_map_overlay()
        for tick in 4: await process_frame
        await RenderingServer.frame_post_draw
        var image:=root.get_texture().get_image()
        if image.is_empty():
            push_error("Real GL renderer required")
            quit(1)
            return
        image.save_jpg(output+("/atlas_both_open.jpg" if opened else "/atlas_far_side_locked.jpg"),0.90)
    scene.queue_free()
    await process_frame
    print("CAPTURE_ROUTE_CONTRACT states=2 fixture_inventory=true fixture_flags=true")
    quit()
