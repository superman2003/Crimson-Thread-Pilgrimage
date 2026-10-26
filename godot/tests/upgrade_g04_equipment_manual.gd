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
    var notes:=preload("res://scripts/equipment_field_notes.gd")
    var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(notes.CATALOG_PATH))
    var rows:=notes.records({},{});check(rows.size()==2,"starting equipment only is public")
    var inventory: Dictionary={};var controls:={"skill_1":"Q","skill_cycle":"E","tool_cast":"V","tool_cycle":"R","interact":"F"}
    for table in ["skills","tools"]:
        for id in catalog[table]:inventory[catalog[table][id].unlock_item]=1
    var before:=inventory.duplicate(true)
    rows=notes.records(inventory,controls)
    check(rows.size()==10,"all ten authored equipment notes are integrated")
    var ids: Dictionary={}
    for row in rows:
        check(not ids.has(row.id),"manual identity unique");ids[row.id]=true
        check(row.description.contains("Q") if row.id.contains("skills") else row.description.contains("V"),"actual action binding reaches note")
        check(not row.description.contains("{"),"no unresolved placeholders")
    for invalid in [true,-1,0,0.5,NAN,INF,"1",1000001]:
        check(notes.records({"relic_skill_needle":invalid},controls).size()==2,"invalid inventory cannot reveal equipment")
    check(notes.records({"relic_skill_needle":1.0},controls).size()==3,"whole JSON counters accepted")
    check(inventory==before,"manual never mutates inventory")
    var guide:=preload("res://scripts/field_guide.gd").records({},controls,false,inventory)
    check(guide.size()==4 and guide[0].description.contains("断弦回斩 · 使用札记") and guide[1].description.contains("盐雾瓶 · 使用札记"),"normal journal pages include all owned equipment without changing category identities")
    await capture_world()
    print("UPGRADE_G04 checks=%d failures=%d" % [checks,failures])
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
    var catalog: Dictionary=scene.build_system.catalog
    for table in ["skills","tools"]:
        for item in catalog[table].values():scene.inventory_counts[item.unlock_item]=1
    scene._close_overlays();scene._toggle_backpack()
    scene.ui_shell.bag_category="旅记";scene.ui_shell.journal_filter="guide";scene.ui_shell.refresh_inventory()
    await process_frame
    if scene.ui_shell.bag_grid.get_child_count()>1:scene.ui_shell.bag_grid.get_child(1).pressed.emit()
    await process_frame
    await process_frame
    check(scene.ui_shell.bag_description.text.contains("盐雾瓶 · 使用札记"),"actual journal includes owned tool notes")
    var bar: VScrollBar=scene.ui_shell.bag_description.get_v_scroll_bar()
    check(bar.max_value>bar.page,"equipment text remains in scrollable journal")
    bar.value=(bar.max_value-bar.page)*0.35

    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(directory.path_join("world.png"))
    scene.free()
    await process_frame
    for suffix in ["",".tmp",".bak"]:DirAccess.remove_absolute("user://upgrade_g_capture.json"+suffix)
