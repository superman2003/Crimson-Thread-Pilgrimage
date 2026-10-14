extends SceneTree
## Real GL reference/streamed terrain comparison; no image synthesis.
const TERRAIN := preload("res://scripts/chapter_terrain.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const COORDINATES := preload("res://scripts/world_coordinates.gd")
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
    root.process_mode = Node.PROCESS_MODE_DISABLED
    RenderingServer.set_default_clear_color(Color(0.055, 0.065, 0.072))
    for id in COORDINATES.manifest().regions:
        var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROUTES.config_path(id)))
        config = ROUTES.apply_to(config)
        var reference := TERRAIN.new()
        root.add_child(reference)
        reference.configure(config, String(config.art_theme))
        var streamed := TERRAIN.new()
        root.add_child(streamed)
        var point: Array = config.player_start
        var focus := Vector2(point[0], point[1])
        streamed.configure(config, String(config.art_theme), true, focus)
        var keys: Array = streamed.visual_chunks.keys()
        var middle: Vector2 = streamed.visual_chunks[keys[keys.size() / 2]].bounds.get_center()
        for sample in [focus, middle]:
            root.canvas_transform = Transform2D(0, Vector2(640, 360) - sample)
            var view := Rect2(sample - Vector2(640, 360), Vector2(1280, 720))
            streamed.refresh_visual_chunks(view, true)
            reference.visible = true
            streamed.visible = false
            var expected: Image = await _capture()
            reference.visible = false
            streamed.visible = true
            var actual: Image = await _capture()
            var changed := _changed_pixels(expected, actual)
            # A split translucent top line may change a few cap/join pixels.
            # Ground texture/geometry holes would change thousands of pixels.
            var ok := changed <= 64
            if not ok:
                failures += 1
                push_error("Streaming pixel difference %s: %d" % [id, changed])
            probes.append({"region": id, "focus": [sample.x, sample.y], "changed_pixels": changed,
                "allowed_outline_pixels": 64, "passed": ok})
        reference.free()
        streamed.free()
        await process_frame
    var output := ProjectSettings.globalize_path("res://../artifacts/world_streaming")
    DirAccess.make_dir_recursive_absolute(output)
    var file := FileAccess.open(output + "/gpu_pixels.json", FileAccess.WRITE)
    file.store_string(JSON.stringify({"renderer": "real_gl", "probes": probes, "failures": failures}, "  "))
    file.close()
    print("STREAMING_PIXELS probes=%d failures=%d" % [probes.size(), failures])
    call_deferred("quit", 1 if failures > 0 else 0)

func _capture() -> Image:
    for unused in 3:
        await process_frame
    await RenderingServer.frame_post_draw
    return root.get_texture().get_image()

func _changed_pixels(expected: Image, actual: Image) -> int:
    if expected.is_empty() or actual.is_empty() or expected.get_size() != actual.get_size():
        return 1000000
    expected.convert(Image.FORMAT_RGBA8)
    actual.convert(Image.FORMAT_RGBA8)
    var a := expected.get_data()
    var b := actual.get_data()
    if a == b:
        return 0
    var changed := 0
    for offset in range(0, a.size(), 4):
        if a[offset] != b[offset] or a[offset + 1] != b[offset + 1] or a[offset + 2] != b[offset + 2]:
            changed += 1
    return changed
