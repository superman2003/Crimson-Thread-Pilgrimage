extends SceneTree
const JOURNAL := preload("res://scripts/pilgrimage_cartography.gd")
var output: String
func _initialize() -> void: call_deferred("run")
func capture(scene: Node, label: String) -> void:
    scene._refresh_map_overlay()
    for tick in 4: await process_frame
    await RenderingServer.frame_post_draw
    var image:=root.get_texture().get_image()
    if image.is_empty():
        push_error("Real GL renderer required")
        quit(1)
        return
    image.save_jpg(output+"/"+label+".jpg",0.92)
func run() -> void:
    root.size=Vector2i(1280,720)
    output=ProjectSettings.globalize_path("res://../artifacts/cartography/contour_fix")
    DirAccess.make_dir_recursive_absolute(output)
    var sellers: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/cartography_sellers.json"))
    var count:=0
    for id in sellers:
        var scene: Node=load("res://scenes/World.tscn").instantiate()
        scene.config_path="res://data/"+String(id)+".json"
        scene.world_resume=false
        scene.world_save_path="user://cartography_contour_capture.json"
        root.add_child(scene)
        scene.set_process(false)
        scene.player.set_physics_process(false)
        for enemy in get_nodes_in_group("enemy"): enemy.set_physics_process(false)
        JOURNAL.region(scene.story_flags,String(id)).owned=true
        scene._toggle_map()
        await capture(scene,"%02d_coarse" % count)
        for room in scene.config.map_rooms:
            JOURNAL.visit(scene.story_flags,String(id),String(room.id))
        if count==0: await capture(scene,"00_pending")
        scene._close_overlays()
        scene._activate_save_point(scene.get_node(String(scene.config.save_points[0].id)))
        scene._toggle_map()
        await capture(scene,"%02d_charted" % count)
        scene.queue_free()
        await process_frame
        count+=1
    for suffix in ["",".tmp",".bak"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path("user://cartography_contour_capture.json"+suffix))
    print("CAPTURE_CARTOGRAPHY_CONTOURS regions=%d fixture_owned=true fixture_notes=true" % count)
    quit()
