extends SceneTree
## Reproducible UI fixture; auxiliary profiles and gameplay use isolated names.
const CAPTURE_DIR := "user://journey_desk_captures"
func _initialize() -> void:call_deferred("run")
func snap(desk: Node,name_text: String) -> void:
    for frame in 5:await process_frame
    print("DESK_LAYOUT ",name_text," size=",desk.window.size," pos=",desk.window.position," column_min=",desk.window.column.get_combined_minimum_size())
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(CAPTURE_DIR+"/"+name_text+".png")
    desk.window.hide()
func run() -> void:
    if DisplayServer.get_name()=="headless":
        push_error("Use an actual rendering display for workbench captures.");quit(1);return
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
    print("DESK_CAPTURE_DIRECTORY ",ProjectSettings.globalize_path(CAPTURE_DIR))
    root.gui_embed_subwindows=true
    var main: Node=load("res://scenes/World.tscn").instantiate()
    main.world_resume=false;main.world_save_path="user://d_capture_world.json";root.add_child(main)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(main)
    main.set_process(false);main.player.set_physics_process(false)
    for enemy in get_nodes_in_group("enemy"):enemy.set_physics_process(false)
    var ui: Control=main.ui_shell
    main._toggle_backpack();var goal: Node=ui.get_node("GoalDesk");goal.open();goal.act("pin");await snap(goal,"goals")
    main._close_overlays()
    var journal:=preload("res://scripts/pilgrimage_cartography.gd")
    journal.region(main.story_flags,String(main.config.id)).owned=true
    for room in main.config.map_rooms.slice(0,4):journal.region(main.story_flags,String(main.config.id)).charted[String(room.id)]=true
    main._toggle_map();var trip: Node=ui.get_node("ExpeditionDesk");trip.open();trip.act("add");await snap(trip,"expedition")
    main._close_overlays();main._toggle_build();var practice: Node=ui.get_node("PracticeDesk");practice.open();await snap(practice,"practice")
    main._close_overlays();main._toggle_audio_settings();var profiles: Node=ui.get_node("SettingsProfilesDesk");profiles.model.configure("capture_fixture");profiles.open();profiles.name_input.text="大字阅读";profiles.manage("save");await snap(profiles,"profiles")
    main._close_overlays();main._toggle_backpack();var combat: Node=ui.get_node("CombatDesk");combat.open();await snap(combat,"combat")
    preload("res://scripts/audio_retirement.gd").retire_tree(main);main.free();await process_frame
    await preload("res://scripts/audio_retirement.gd").drain(self)
    quit()
