extends SceneTree
const JOURNAL := preload("res://scripts/pilgrimage_cartography.gd")
const RUNTIME := preload("res://scripts/cartography_runtime.gd")
var scene: Node
var output: String
func _initialize() -> void: call_deferred("run")
func capture(label: String) -> void:
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
    output=ProjectSettings.globalize_path("res://../artifacts/cartography")
    DirAccess.make_dir_recursive_absolute(output)
    scene=load("res://scenes/World.tscn").instantiate()
    scene.world_resume=false
    scene.world_save_path="user://cartography_capture.json"
    root.add_child(scene)
    scene.set_process(false)
    scene.player.set_physics_process(false)
    for enemy in get_nodes_in_group("enemy"): enemy.set_physics_process(false)
    scene._toggle_map()
    await capture("01_unpurchased")
    scene._close_overlays()
    var stall: Area2D=scene.get_node("npc_gear_cartographer")
    scene.player.position=stall.position
    scene.currency_count=40
    RUNTIME.open_shop(scene,stall)
    for tick in 3: await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_jpg(output+"/02_purchase.jpg",0.92)
    scene.get_node("MapPurchaseDialog").confirmed.emit()
    scene.player.position=scene._vec2(scene.config.player_start)
    scene._update_room_visit()
    scene._toggle_map()
    await capture("03_coarse")
    # Fixture explores two known rooms, then rests through the real shrine adapter.
    JOURNAL.visit(scene.story_flags,String(scene.config.id),"moss_descent")
    JOURNAL.visit(scene.story_flags,String(scene.config.id),"hidden_attic")
    await capture("04_pending")
    scene._close_overlays()
    scene._activate_save_point(scene.get_node("save_first_bell"))
    scene._toggle_map()
    await capture("05_charted")
    scene.queue_free()
    await process_frame
    print("CAPTURE_CARTOGRAPHY states=5 fixture_currency=true fixture_notes=true")
    quit()
