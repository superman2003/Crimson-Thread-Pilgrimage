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
    var navigation:=preload("res://scripts/map_room_navigation.gd")
    var parent:=Control.new();root.add_child(parent)
    var rooms: Array[Control]=[]
    for index in 4:
        var room:=Control.new();room.name="Room%d"%index;room.position=[Vector2.ZERO,Vector2(150,0),Vector2(0,120),Vector2(140,120)][index];room.size=Vector2(100,80);room.focus_mode=Control.FOCUS_ALL
        parent.add_child(room);navigation.bind(room);rooms.append(room)
    await process_frame
    check(navigation.neighbor(rooms[0],Vector2.RIGHT)==rooms[1],"right chooses same row")
    check(navigation.neighbor(rooms[0],Vector2.DOWN)==rooms[2],"down chooses same column")
    check(navigation.neighbor(rooms[0],Vector2.LEFT)==null,"edge has no phantom neighbor")
    rooms[1].hide()
    check(navigation.neighbor(rooms[0],Vector2.RIGHT)==rooms[3],"hidden rooms excluded")
    var secret:=Control.new();secret.position=Vector2(110,0);secret.size=Vector2(80,80);parent.add_child(secret)
    check(navigation.neighbor(rooms[0],Vector2.RIGHT)!=secret,"unbound hidden knowledge is never selected")
    rooms[1].show();rooms[0].grab_focus()
    var event:=InputEventKey.new();event.keycode=KEY_RIGHT;event.pressed=true
    rooms[0].gui_input.emit(event)
    check(rooms[1].has_focus(),"real room gui input moves native focus")
    check(navigation.score(Rect2(0,0,100,80),Rect2(-150,0,100,80),Vector2.RIGHT)==INF,"behind source rejected")
    navigation.bind(rooms[0]);check(rooms[0].gui_input.get_connections().size()==1,"binding is idempotent")
    parent.queue_free();await process_frame
    await capture_world()
    print("UPGRADE_G03 checks=%d failures=%d" % [checks,failures])
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
