extends SceneTree
## Paused cartography fixtures; never counted as natural gameplay acceptance.
const JOURNAL := preload("res://scripts/pilgrimage_cartography.gd")
const ATLAS := preload("res://scripts/world_atlas.gd")
const COORD := preload("res://scripts/world_coordinates.gd")
var scene: Node
var probes: Array = []
var failures := 0
var output: String
func _initialize() -> void: call_deferred("run")
func capture(label: String) -> void:
    scene._refresh_map_overlay()
    for unused in 4: await process_frame
    await RenderingServer.frame_post_draw
    var image := root.get_texture().get_image()
    var passed := not image.is_empty()
    for child in scene.map_draw_root.get_children():
        if String(child.name).begins_with("WorldSurvey_") or String(child.name).begins_with("WorldRegion_"):
            var rect := Rect2(child.position, child.size)
            passed = passed and Rect2(Vector2.ZERO, scene.map_draw_root.size).encloses(rect)
    if passed:
        passed = image.save_jpg(output.path_join(label + ".jpg"), 0.92) == OK
    if not passed:
        failures += 1
        push_error("World atlas empty, clipped or cannot save: " + label)
    probes.append({"fixture": label, "passed": passed, "frame": str(scene.map_draw_root.get_meta("world_atlas_frame"))})
func run() -> void:
    if DisplayServer.get_name() == "headless":
        push_error("Real GL required")
        quit(1)
        return
    root.size = Vector2i(1280,720)
    output = ProjectSettings.globalize_path("res://../artifacts/world_atlas")
    DirAccess.make_dir_recursive_absolute(output)
    scene = load("res://scenes/World.tscn").instantiate()
    scene.world_resume = false
    scene.world_save_path = "user://atlas_pixels.json"
    root.add_child(scene)
    await process_frame
    for voice in scene.find_children("*","AudioStreamPlayer",true,false)+scene.find_children("*","AudioStreamPlayer2D",true,false):
        voice.stop()
        voice.stream = null
    scene.process_mode = Node.PROCESS_MODE_DISABLED
    scene._toggle_map()
    scene.world_map_view = true
    await capture("01_unpurchased")
    for id in COORD.manifest().regions:
        JOURNAL.region(scene.story_flags,id).owned = true
        for room in ATLAS.configuration(id).map_rooms:
            JOURNAL.visit(scene.story_flags,id,String(room.id))
    await capture("02_pending_notes")
    JOURNAL.rest(scene.story_flags)
    await capture("03_charted_world")
    scene.free()
    current_scene = null
    await process_frame
    for suffix in ["", ".bak", ".tmp"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path("user://atlas_pixels.json" + suffix))
    var summary := {"probes": probes, "failures": failures, "fixture_positioning": true, "combat_acceptance": false}
    var file := FileAccess.open(output.path_join("gpu_atlas.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify(summary,"  ") + "\n")
    file.close()
    print("WORLD_ATLAS_PIXELS probes=3 failures=%d" % failures)
    quit(1 if failures > 0 else 0)
