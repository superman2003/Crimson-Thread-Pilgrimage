extends SceneTree
## Real rendered chapter geometry, isolated progress; these are room views, not a campaign clear.
var destination := ""
var prefix := "after"
var capture_config := "res://data/demo_ch01_moss_bell_court.json"
func _initialize() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--capture-output="): destination = arg.trim_prefix("--capture-output=")
        if arg.begins_with("--prefix="): prefix = arg.trim_prefix("--prefix=")
        if arg.begins_with("--config-path="): capture_config = arg.trim_prefix("--config-path=")
    call_deferred("capture")
func capture() -> void:
    if destination.is_empty():
        push_error("Specify --capture-output=absolute-directory")
        quit(1)
        return
    DirAccess.make_dir_recursive_absolute(destination)
    root.size = Vector2i(1280,720)
    var world: Node = load("res://scenes/World.tscn").instantiate()
    world.world_resume = false
    world.config_path = capture_config
    world.world_save_path = "user://room_showcase.json"
    root.add_child(world)
    current_scene = world
    world.player.debug_invulnerable = true
    world.player.set_physics_process(false)
    # Keep enemies visible in their authored starting poses for readable room views.
    for actor in get_nodes_in_group("enemy"): actor.set_physics_process(false)
    world.player.self_flash_timer = 0.0
    if world.player.flash_material != null: world.player.flash_material.set_shader_parameter("flash_amount",0.0)
    for i in 20: await physics_frame
    for view in [
        ["east_balcony",Vector2(4580,2790)],
        ["rain_overlook",Vector2(5920,2790)],
        ["cistern_deep_gallery",Vector2(3820,5420)],
        ["maze_respite",Vector2(1580,5120)],
        ["pre_boss_shrine",Vector2(5340,3920)]
    ]:
        world.player.global_position = view[1]
        world.player.velocity = Vector2.ZERO
        world._close_overlays()
        world.ui_shell.toast.text = ""
        var camera: Camera2D = world.player.get_node("Camera2D")
        camera.position = Vector2(0,-130)
        camera.reset_smoothing()
        camera.force_update_scroll()
        for i in 8: await process_frame
        await RenderingServer.frame_post_draw
        var result := root.get_texture().get_image().save_png(destination.path_join(prefix+"_"+String(view[0])+".png"))
        if result != OK:
            push_error("Room capture failed")
            quit(1)
            return
    print("CH01_ROOM_CAPTURE_PASS views=5 isolated_progress=true")
    world.queue_free()
    for i in 3: await process_frame
    quit(0)
