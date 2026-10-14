extends SceneTree
## Paused UI fixtures with preset progress, not natural traversal/FPS evidence.
## A separate real GL viewport isolates UI pixels from animated world content.
const ROUTES := preload("res://scripts/world_routes.gd")
const JOURNAL := preload("res://scripts/pilgrimage_cartography.gd")
const ATLAS := preload("res://scripts/world_atlas.gd")
const COORD := preload("res://scripts/world_coordinates.gd")
const SAVE := "user://region_commit_pixels.json"
const MODES := ["hud", "backpack", "map", "build", "settings"]
var scene: Node
var probes: Array = []
var failures := 0
var output: String
var view: SubViewport

func _initialize() -> void:
    call_deferred("run")

func frames(count: int) -> void:
    for unused in count: await process_frame

func capture_ui() -> Dictionary:
    var images: Dictionary = {}
    scene.ui_canvas.reparent(view)
    scene.ui_shell._fit_viewport()
    for mode in MODES:
        scene._close_overlays()
        if mode != "hud":
            scene.active_overlay = mode
            if mode == "backpack": scene.backpack_panel.visible = true
            elif mode == "map":
                scene.map_panel.visible = true
                scene._refresh_map_overlay()
            elif mode == "build": scene.ui_shell.build_panel.visible = true
            elif mode == "settings": scene.settings_panel.visible = true
        scene.ui_shell._process(0.0)
        scene.ui_shell.toast.visible = false
        scene.win_label.visible = false
        await frames(4)
        await RenderingServer.frame_post_draw
        images[mode] = view.get_texture().get_image()
    scene._close_overlays()
    scene.ui_canvas.reparent(scene)
    return images

func changed_pixels(a: Image, b: Image) -> int:
    if a.is_empty() or b.is_empty() or a.get_size() != b.get_size(): return -1
    a.convert(Image.FORMAT_RGBA8)
    b.convert(Image.FORMAT_RGBA8)
    var left := a.get_data()
    var right := b.get_data()
    if left == right: return 0
    var changed := 0
    for offset in range(0, left.size(), 4):
        if left[offset] != right[offset] or left[offset+1] != right[offset+1] or left[offset+2] != right[offset+2] or left[offset+3] != right[offset+3]:
            changed += 1
    return changed

func run() -> void:
    if DisplayServer.get_name() == "headless":
        push_error("Real GL required")
        quit(1)
        return
    root.size = Vector2i(1280, 720)
    root.process_mode = Node.PROCESS_MODE_DISABLED
    output = ProjectSettings.globalize_path("res://../artifacts/region_commit")
    DirAccess.make_dir_recursive_absolute(output)
    view = SubViewport.new()
    view.size = root.size
    view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(view)
    scene = load("res://scenes/World.tscn").instantiate()
    scene.world_resume = false
    scene.world_save_path = SAVE
    root.add_child(scene)
    await frames(3)
    scene.player.hp = 3
    scene.player.energy = 51
    scene.currency_count = 317
    for id in COORD.manifest().regions:
        JOURNAL.region(scene.story_flags, id).owned = true
        for room in ATLAS.configuration(id).map_rooms:
            JOURNAL.visit(scene.story_flags, id, String(room.id))
    JOURNAL.rest(scene.story_flags)
    for id in ["demo_ch01_moss_bell_court", "demo_ch02_rain_foundry_canal"]:
        var path := ROUTES.config_path(id)
        var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
        var entry := Vector2(config.player_start[0], config.player_start[1])
        var arrived: bool = await scene.world_loader.replace_region_async(scene, path, entry)
        var asynchronous := await capture_ui()
        scene._travel_world(path, entry)
        var synchronous := await capture_ui()
        for mode in MODES:
            var delta := changed_pixels(asynchronous[mode], synchronous[mode])
            var passed: bool = arrived and delta == 0
            if not passed:
                failures += 1
                push_error("Region commit UI pixel mismatch: %s/%s pixels=%d" % [id, mode, delta])
            probes.append({"region": id, "mode": mode, "changed_pixels": delta, "passed": passed})
        if id == "demo_ch01_moss_bell_court": asynchronous.map.save_jpg(output.path_join("moss_map.jpg"), 0.92)
        else: asynchronous.backpack.save_jpg(output.path_join("rain_backpack.jpg"), 0.92)
    scene.free()
    view.free()
    await frames(3)
    for suffix in ["", ".bak", ".tmp"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
    var summary := {"probes": probes, "failures": failures, "renderer": "real software GL",
        "fixture_positioning": true, "ui_isolated_viewport": true, "combat_acceptance": false}
    var file := FileAccess.open(output.path_join("gpu_ui.json"), FileAccess.WRITE)
    file.store_string(JSON.stringify(summary, "  ") + "\n")
    file.close()
    print("REGION_COMMIT_PIXELS probes=%d failures=%d" % [probes.size(), failures])
    quit(1 if failures > 0 else 0)
