extends SceneTree
## Use a real GL renderer (xvfb-run), never the headless dummy renderer.
func _initialize() -> void: call_deferred("run")
func run() -> void:
    var output := ProjectSettings.globalize_path("res://../artifacts/hero_rock_upgrade/checkpoint4")
    DirAccess.make_dir_recursive_absolute(output)
    root.size=Vector2i(1280,720)
    for id in ["demo_ch01_moss_bell_court","demo_ch02_rain_foundry_canal","demo_ch03_saltwhite_archive","demo_ch04_broken_string_greenhouse","demo_ch05_obsidian_pilgrim_road","demo_ch06_silent_crown_core"]:
        var scene: Node = load("res://scenes/Main.tscn").instantiate()
        scene.config_path="res://data/"+id+".json"
        root.add_child(scene)
        for actor in get_nodes_in_group("enemy"): actor.set_physics_process(false)
        for tick in 25: await physics_frame
        scene.player.set_physics_process(false)
        var camera: Camera2D=scene.player.get_node("Camera2D")
        camera.reset_smoothing()
        var material: ShaderMaterial=scene.cave_world.get_node("PaintedRockMass").material
        var native: Vector2=material.get_shader_parameter("tile_size")
        # Place the view on an authored solid rectangle spanning a repeat boundary.
        var found := false
        for value in scene.config.cave_world.solid_rects:
            var rect := Rect2(float(value[0]),float(value[1]),float(value[2]),float(value[3]))
            var seam_x := ceilf((rect.position.x+64.0)/native.x)*native.x
            if seam_x<rect.end.x-64.0 and rect.size.y>=64:
                scene.player.position=Vector2(seam_x,rect.position.y-100)
                camera.reset_smoothing()
                found=true
                break
        if not found:
            push_error("No authored seam-spanning rock rectangle: "+id)
            quit(1)
            return
        for variant in ["before_seams","after_seams"]:
            material.set_shader_parameter("mirror_repeat",variant=="after_seams")
            for tick in 4: await process_frame
            await RenderingServer.frame_post_draw
            var image: Image=root.get_texture().get_image()
            if image.is_empty():
                push_error("Real renderer required for screenshot")
                quit(1)
                return
            image.save_jpg(output+"/"+id+"_"+variant+".jpg",0.94)
        material.set_shader_parameter("mirror_repeat",true)
        scene.queue_free()
        for tick in 4: await process_frame
    print("CAPTURE_ROCK_SEAMS regions=6 comparisons=12")
    quit()
