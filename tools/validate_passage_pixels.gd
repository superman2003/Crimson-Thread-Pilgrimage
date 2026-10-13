extends SceneTree
## Actual GL captures at fixture positions; no claim of natural progression.
var scene: Node
var probes: Array = []
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    if DisplayServer.get_name() == "headless":
        push_error("Real GL display required")
        quit(1)
        return
    root.size = Vector2i(1280, 720)
    scene = load("res://scenes/World.tscn").instantiate()
    scene.world_resume = false
    scene.world_save_path = "user://passage_pixels_fixture.json"
    root.add_child(scene)
    current_scene = scene
    await process_frame
    scene.process_mode = Node.PROCESS_MODE_DISABLED
    scene.player.global_position = scene.get_node("moss_rain_pipe").global_position
    if not scene.world_passage.begin("moss_rain_pipe"):
        push_error("Pipe capture cannot enter")
        quit(1)
        return
    var output := ProjectSettings.globalize_path("res://../artifacts/world_passage")
    DirAccess.make_dir_recursive_absolute(output)
    for offset in [1000, 4200, 7600, 8500]:
        var point: Vector2 = scene.world_passage.source_point.lerp(scene.world_passage.destination_point, float(offset) / 8540) + Vector2(0, 40)
        scene.player.global_position = point
        scene.player.reset_camera_after_arrival()
        scene.world_passage.step()
        for frame in range(4):
            await process_frame
            await RenderingServer.frame_post_draw
        var image: Image = root.get_texture().get_image()
        scene.player.visible = false
        for frame in range(3):
            await process_frame
            await RenderingServer.frame_post_draw
        var without_hero: Image = root.get_texture().get_image()
        scene.player.visible = true
        for frame in range(3):
            await process_frame
            await RenderingServer.frame_post_draw
        var hero_pixels := 0
        for y in range(0, image.get_height(), 2):
            for x in range(0, image.get_width(), 2):
                if image.get_pixel(x, y) != without_hero.get_pixel(x, y):
                    hero_pixels += 1
        # Prove the painted supports/lanterns actually contribute pixels.
        var ornaments: Array[Sprite2D] = []
        for child in scene.world_passage.get_children():
            if child is Sprite2D and child.has_meta("passage_ornament"):
                ornaments.append(child)
                child.visible = false
        for frame in range(3):
            await process_frame
            await RenderingServer.frame_post_draw
        var without_ornaments: Image = root.get_texture().get_image()
        for sprite in ornaments:
            sprite.visible = true
        var markers: Array[Label] = []
        for child in scene.world_passage.get_children():
            if child is Label and String(child.name).begins_with("Endpoint_"):
                markers.append(child)
                child.visible = false
        for frame in range(3):
            await process_frame
            await RenderingServer.frame_post_draw
        var without_markers: Image = root.get_texture().get_image()
        for marker in markers:
            marker.visible = true
        var endpoint_pixels := 0
        for y in range(0, image.get_height(), 2):
            for x in range(0, image.get_width(), 2):
                if image.get_pixel(x, y) != without_markers.get_pixel(x, y):
                    endpoint_pixels += 1
        var endpoint_ok := endpoint_pixels > 80 if offset == 8500 else endpoint_pixels == 0
        var ornament_pixels := 0
        for y in range(0, image.get_height(), 2):
            for x in range(0, image.get_width(), 2):
                if image.get_pixel(x, y) != without_ornaments.get_pixel(x, y):
                    ornament_pixels += 1
        var samples := 0
        var distinct: Dictionary = {}
        for y in range(50, 670, 12):
            for x in range(40, 1240, 12):
                var color := image.get_pixel(x, y)
                distinct[color.to_html()] = true
                if color.get_luminance() > 0.025:
                    samples += 1
        var ok := samples > 1000 and distinct.size() > 64 and hero_pixels > 40 and ornament_pixels > 400 and endpoint_ok
        if not ok:
            failures += 1
            push_error("Pipe render blank or untextured")
        var file := "pipe_%d.jpg" % offset
        if image.save_jpg(output.path_join(file), 0.92) != OK:
            failures += 1
            push_error("Cannot save pipe capture")
        ornaments.clear()
        markers.clear()
        probes.append({"offset": offset, "visible_samples": samples, "distinct_colors": distinct.size(), "hero_pixels": hero_pixels, "ornament_pixels": ornament_pixels, "endpoint_pixels": endpoint_pixels, "passed": ok, "file": file})
    scene.free()
    current_scene = null
    for frame in range(4):
        await process_frame
    var file := FileAccess.open(output.path_join("gpu_pipe.json"), FileAccess.WRITE)
    file.store_string(JSON.stringify({"renderer": "real_gl", "fixture_positioning": true, "probes": probes, "failures": failures}, "  "))
    file.close()
    print("PASSAGE_PIXELS probes=%d failures=%d" % [probes.size(), failures])
    call_deferred("quit", 1 if failures > 0 else 0)
