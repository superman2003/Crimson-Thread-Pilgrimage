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
    var marker:=preload("res://scripts/world_wayfinding.gd")
    check(marker.caption_for("save_point","初鸣钟龛","E").contains("E · 安坐"),"rest uses current binding and verb")
    check(marker.caption_for("npc","制图师","F",false,"map").contains("查看报价"),"merchant prompt explains operation")
    check(not marker.caption_for("history","未读秘密标题","F").contains("秘密"),"unread prop title hidden")
    check(marker.caption_for("history","已读旧物","F",true).contains("重读旧物：已读旧物"),"read prop may show title")
    check(not marker.caption_for("lever","bad\nlabel\ttext","F").contains("\n"),"control characters removed")
    check(marker.caption_for("lever","很长".repeat(40),"F").length()<40,"long labels bounded")
    var node:=marker.new();root.add_child(node)
    node.physical_sign=true;node.nearby=true;node.key_hint="F";node.interaction_caption="old"
    node._process(0.1)
    check(not node.visible and node.key_hint.is_empty() and node.interaction_caption.is_empty(),"retired source cannot leave a stale prompt")
    check(not node.is_processing(),"retired marker stops processing")
    check(node._key_box()==node._key_box(),"prompt style is reused")
    node.queue_free();await process_frame
    await capture_world()
    print("UPGRADE_G07 checks=%d failures=%d" % [checks,failures])
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
    for child in scene.get_children():
        if child is Area2D and String(child.get_meta("kind",""))=="save_point":
            scene.player.global_position=child.global_position
            child.get_node("Wayfinding")._process(0.0)
            break
    var camera: Camera2D=scene.player.get_node("Camera2D")
    camera.position_smoothing_enabled=false;camera.reset_smoothing();camera.force_update_scroll()

    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(directory.path_join("world.png"))
    scene.free()
    await process_frame
    for suffix in ["",".tmp",".bak"]:DirAccess.remove_absolute("user://upgrade_g_capture.json"+suffix)
