extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(label)
func run() -> void:
    var cue:=preload("res://scripts/atlas_route_cue.gd")
    check(cue.state({"open":true},{"open":true})=="双向可通","two open endpoints")
    check(cue.state({"open":true},{"open":false})=="仅正向可通","forward only")
    check(cue.state({"open":false},{"open":true})=="仅反向可通","reverse only")
    check(cue.state({"open":1},{"open":"true"})=="两侧均有门槛","malformed truth cannot imply passage")
    var node:=cue.new();root.add_child(node);node.configure(Vector2.ZERO,Vector2(100,0),{"open":true},{"open":false})
    check(node.forward and not node.reverse,"render direction matches access snapshot")
    var tip:=node.arrow_tip(Vector2(10,10),Vector2.RIGHT)
    check(tip.size()==3 and tip[1]==Vector2(10,10) and tip[0].x<10,"arrow points along actual route")
    var atlas:=preload("res://scripts/world_atlas.gd")
    var host:=Control.new();root.add_child(host)
    var line:=Line2D.new();line.set_meta("physical_passage",false);line.set_meta("source_region","a");line.set_meta("source_room","one");host.add_child(line)
    var room:=Control.new();room.name="WorldSurvey_a_one";room.set_meta("region_id","a");room.set_meta("room_id","one");room.focus_mode=Control.FOCUS_ALL;host.add_child(room)
    atlas._update_route_visibility(line);check(not line.visible,"old route private until public endpoint interaction")
    room.set_meta("route_hover",true);atlas._update_route_visibility(line);check(line.visible,"mouse hover reveals route")
    room.set_meta("route_hover",false);room.grab_focus();atlas._update_route_visibility(line);check(line.visible,"keyboard focus preserves route after mouse leaves")
    room.release_focus();atlas._update_route_visibility(line);check(not line.visible,"route retires after both hover and focus end")
    line.set_meta("physical_passage",true);atlas._update_route_visibility(line);check(line.visible,"physical passage always visible")
    node.queue_free();host.queue_free();await process_frame
    await capture_world()
    print("UPGRADE_G10 checks=%d failures=%d" % [checks,failures])
    quit(1 if failures else 0)

func capture_world() -> void:
    var directory:=OS.get_environment("UPGRADE_CAPTURE_DIR")
    if directory.is_empty() or DisplayServer.get_name()=="headless":return
    DirAccess.make_dir_recursive_absolute(directory)
    var scene: Node=load("res://scenes/World.tscn").instantiate()
    scene.world_resume=false
    scene.world_save_path="user://upgrade_g_capture.json"
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    if not scene.initial_region_ready or not is_instance_valid(scene.player):
        check(false,"capture requires original 15-second publication boundary")
        scene.free()
        return
    scene.set_process(false);scene.player.set_physics_process(false)
    for enemy in get_nodes_in_group("enemy"):enemy.set_physics_process(false)
    var key: String=preload("res://scripts/pilgrimage_cartography.gd").KEY
    var charted: Dictionary={}
    for room in scene.config.map_rooms:
        if preload("res://scripts/survey_map_knowledge.gd").public_room(room):charted[room.id]=true
    scene.story_flags[key]={String(scene.config.id):{"owned":true,"charted":charted,"pending":{}}}
    scene._close_overlays();scene._toggle_map()
    scene.world_map_view=true;scene._refresh_map_overlay()
    for child in scene.map_draw_root.get_children():
        if String(child.name).begins_with("WorldSurvey_"):child.grab_focus();break

    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(directory.path_join("world.png"))
    scene.free()
    await process_frame
    for suffix in ["",".tmp",".bak"]:DirAccess.remove_absolute("user://upgrade_g_capture.json"+suffix)
