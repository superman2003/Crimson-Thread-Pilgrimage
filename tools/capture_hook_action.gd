extends SceneTree
## An isolated world fixture: grants hook and sets test start; then real physics.
var output := ""
var records: Array = []
func _initialize() -> void: call_deferred("run")
func snapshot(player: Node, label: String) -> void:
    player.set_physics_process(false)
    player._update_animation(0)
    await process_frame
    await RenderingServer.frame_post_draw
    var image: Image=root.get_texture().get_image()
    if image.is_empty():
        push_error("Real renderer required")
        quit(1)
        return
    image.save_jpg(output+"/"+label+".jpg",0.90)
    records.append({"stage":label,"position":[player.position.x,player.position.y],"pose":player.sprite.frame,"grapple_active":player.grapple_timer>0})
func run() -> void:
    root.size=Vector2i(1280,720)
    output=ProjectSettings.globalize_path("res://../artifacts/hero_rock_upgrade/checkpoint3")
    DirAccess.make_dir_recursive_absolute(output)
    var scene: Node=load("res://scenes/World.tscn").instantiate()
    scene.world_resume=false
    scene.world_save_path="user://hook_capture_v4.json"
    root.add_child(scene)
    scene.set_process(false)
    scene.player.set_physics_process(false)
    for enemy in get_nodes_in_group("enemy"): enemy.set_physics_process(false)
    scene._add_inventory_item("echo_hook",1,false)
    scene._sync_player_abilities()
    var player: Node=scene.player
    player.debug_invulnerable=true
    player.feel=null
    player.respawn_at(Vector2(3990,2650))
    player.get_node("Camera2D").reset_smoothing()
    for tick in 4: await process_frame
    await snapshot(player,"00_ready")
    if not player._try_start_grapple():
        push_error("Real viaduct anchor cannot latch from its authored test position")
        quit(1)
        return
    await snapshot(player,"01_release")
    var start: Vector2=player.position
    player.set_physics_process(true)
    for tick in 6:
        await physics_frame
        await process_frame
    await snapshot(player,"02_pull")
    if player.position.distance_to(start)<60:
        push_error("Hook fixture did not move collision body")
        quit(1)
        return
    player.set_physics_process(true)
    for tick in 60:
        await physics_frame
        await process_frame
        if player.grapple_timer<=0: break
    await snapshot(player,"03_arrival")
    var file:=FileAccess.open(output+"/physics_capture.json",FileAccess.WRITE)
    file.store_string(JSON.stringify({"fixture_grants_ability":true,"fixture_sets_start":true,"records":records},"  "))
    file.close()
    scene.queue_free()
    await process_frame
    print("CAPTURE_HOOK_ACTION stages=4 real_physics=true")
    quit()
