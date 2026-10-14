extends SceneTree
## Standalone asset rasterization probe; never loads the game's runtime scenes.
func _initialize() -> void:
    var args := OS.get_cmdline_user_args()
    if args.size() != 2:
        push_error("Usage: --headless --script check_svg_godot.gd -- <absolute-pack-dir> <temp-output-dir>")
        quit(2)
        return
    var manifest = JSON.parse_string(FileAccess.get_file_as_string(args[0].path_join("manifest.json")))
    var count := 0
    for item in manifest.items:
        for layer in item.layers:
            var img := Image.new()
            var source := FileAccess.get_file_as_string(args[0].path_join(layer.file))
            var err := img.load_svg_from_string(source)
            if err != OK or img.get_width() != 960 or img.get_height() != 540:
                push_error("SVG rasterization failed: " + str(layer.file))
                quit(1)
                return
            img.save_png(args[1].path_join(str(layer.file).replace(".svg", ".png")))
            count += 1
    print("SCENERY_SVG_RASTER_OK ", count)
    quit(0)
