extends SceneTree
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
    if not value:
        failures+=1
        push_error(message)
func click_id(ui: Control,id: String) -> bool:
    for child in ui.build_grid.get_children():
        if child is Button and String(child.get_meta("build_id",""))==id:
            child.pressed.emit()
            return true
    return false
func run() -> void:
    var main: Node=load("res://scenes/World.tscn").instantiate()
    main.world_save_path="user://ui_world_integration_validation.json"
    main.world_resume=false
    root.add_child(main)
    await process_frame
    main.set_process(false)
    main.player.set_physics_process(false)
    for enemy in get_nodes_in_group("enemy"):enemy.set_physics_process(false)
    var ui: Control=main.ui_shell
    var shrine: Area2D
    for child in main.get_children():
        if child is Area2D and String(child.get_meta("kind",""))=="save_point":
            shrine=child
            break
    check(shrine!=null,"Live fixture locates an actual world save point for workstation-only build actions")
    if shrine!=null:main.player.global_position=shrine.global_position
    check(main.is_near_shrine(),"Production shrine proximity adapter enables workstation editing")
    main._toggle_build()
    check(main.active_overlay=="build" and ui.build_panel.visible,"B runtime adapter opens exclusive live build panel")
    check(main.player.ui_input_locked,"Live build overlay locks gameplay input")
    main.story_flags["tool_mine_found"]=true
    main.inventory_counts["relic_tool_mine"]=1
    main.build_system.sync_progress(main.inventory_counts,String(main.config.get("id","")),main.story_flags)
    ui.build_category="战具"
    ui.build_assign_slot=0
    ui.refresh_build()
    check(click_id(ui,"mine"),"Tool button is accessible by real build ID")
    check(main.build_system.state.tool=="mine","Click changes actual selected tool")
    ui.build_category="构筑"
    ui.refresh_build()
    (ui.build_grid.get_child(1) as Button).pressed.emit()
    check(main.build_system.state.loadouts.has("巡礼方案 1"),"Visible save action records real build plan")
    check(main.world_state.last_error.is_empty(),"Build UI writes valid world state: "+main.world_state.last_error)
    var saved: RefCounted=load("res://scripts/world_state.gd").new()
    check(saved.read(main.world_save_path),"Build buttons save readable world state to disk")
    check(saved.data.build_state.tool=="mine" and saved.data.build_state.loadouts.has("巡礼方案 1"),"Disk world state restores selected tool and saved loadout")
    main._close_overlays()
    check(not ui.build_panel.visible and not main.player.ui_input_locked,"Closing build releases overlay and gameplay lock")
    main._toggle_backpack()
    ui.bag_category="旅记"
    main.story_flags["quest_bring_names_started"]=true
    main.story_flags["evidence_known_testimony_01"]=true
    ui.refresh_inventory()
    var journal_text:=""
    for record in ui.bag_grid.get_children():journal_text+=String((record as Button).text)+"\n"
    journal_text+="\n"+ui.bag_description.text
    check(ui.bag_grid.get_child_count()==2 and journal_text.contains("把名字带回来") and journal_text.contains("苔钟庭的自愿抵押"),"Live journal shows the encountered quest and explicitly known evidence row")
    check(not journal_text.contains("雨铸渠的工匠名字") and not journal_text.contains("雨泵侧室的锤语"),"Live journal withholds unencountered evidence titles and location hints")
    check(ui.bag_description.text.length()>0,"Journal selection supplies readable clue or task phase")
    main._close_overlays()
    main._toggle_audio_settings()
    await process_frame
    ui._process(0.0)
    check(ui.settings.visible and ui.save_slot_buttons.size()==3,"Live settings expose all save slots")
    check(ui.dialogue_body.get_parent()==ui.dialogue_scroll,"Long dialogue lives in scrollable viewport")
    ui.dialogue_body.text="长文本无障碍验证。".repeat(60)
    await process_frame
    check(ui.dialogue_body.get_minimum_size().y>ui.dialogue_scroll.size.y,"Oversize dialogue expands within scrollable container")
    main.free()
    await process_frame
    for suffix in ["",".tmp",".bak"]:DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ui_world_integration_validation.json"+suffix))
    print("UI_WORLD_INTEGRATION_VALIDATION_%s failures=%d" % ["PASS" if failures==0 else "FAIL",failures])
    quit(1 if failures else 0)
