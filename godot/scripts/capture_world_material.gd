extends SceneTree
var destination := ""
var prefix := "after"
func _initialize() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--capture-output="): destination=arg.trim_prefix("--capture-output=")
        if arg.begins_with("--prefix="): prefix=arg.trim_prefix("--prefix=")
    call_deferred("capture")
func capture() -> void:
    if destination.is_empty():
        push_error("Specify --capture-output")
        quit(1)
        return
    root.size=Vector2i(1280,720)
    DirAccess.make_dir_recursive_absolute(destination)
    var index := 0
    for id in ["demo_ch01_moss_bell_court","demo_ch02_rain_foundry_canal","demo_ch03_saltwhite_archive","demo_ch04_broken_string_greenhouse","demo_ch05_obsidian_pilgrim_road","demo_ch06_silent_crown_core"]:
        var scene: Node=load("res://scenes/World.tscn").instantiate()
        scene.config_path="res://data/"+id+".json"
        scene.world_resume=false
        scene.world_save_path="user://material_showcase.json"
        root.add_child(scene)
        current_scene=scene
        scene.player.debug_invulnerable=true
        for actor in get_nodes_in_group("enemy"): actor.set_physics_process(false)
        for i in 50: await physics_frame
        scene.player.set_physics_process(false)
        scene.ui_shell.toast.text=""
        var camera: Camera2D=scene.player.get_node("Camera2D")
        camera.reset_smoothing();camera.force_update_scroll()
        for i in 5: await process_frame
        await RenderingServer.frame_post_draw
        var image: Image=root.get_texture().get_image()
        var result := image.save_png(destination.path_join(prefix+"_ch0"+str(index+1)+".png"))
        if result!=OK:
            push_error("Capture failed")
            quit(1)
            return
        if index==0:
            scene.player.global_position=Vector2(3820,5420)
            camera.reset_smoothing();camera.force_update_scroll()
            for i in 8: await process_frame
            await RenderingServer.frame_post_draw
            root.get_texture().get_image().save_png(destination.path_join(prefix+"_internal.png"))
        scene.queue_free()
        for i in 5: await process_frame
        index+=1
    print("WORLD_MATERIAL_CAPTURE_PASS regions=6 internal_room=true")
    quit(0)
