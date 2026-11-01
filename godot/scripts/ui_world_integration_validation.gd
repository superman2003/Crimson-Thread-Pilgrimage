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
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(main)
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
    # N05 adds the main line as the first record.
    check(ui.bag_grid.get_child_count()==7 and String((ui.bag_grid.get_child(0) as Button).text).contains("主线") and journal_text.contains("把名字带回来") and journal_text.contains("苔钟庭的自愿抵押"),"Live journal shows main line, four teaching notes, encountered quest and known evidence")
    check(not journal_text.contains("雨铸渠的工匠名字") and not journal_text.contains("雨泵侧室的锤语"),"Live journal withholds unencountered evidence titles and location hints")
    check(ui.bag_description.text.length()>0,"Journal selection supplies readable clue or task phase")
    main._close_overlays()
    await preload("res://scripts/journal_records_validation.gd").new().run(main,self,check)
    await preload("res://scripts/protagonist_voice_validation.gd").new().run(main,self,check)
    preload("res://scripts/combat_hud_readiness_validation.gd").new().run(main,check)
    preload("res://scripts/hud_occlusion_checks.gd").new().run(main,check)
    await boss_hud_retirement(main)
    main._toggle_audio_settings()
    await process_frame
    ui._process(0.0)
    check(ui.settings.visible and ui.save_slot_buttons.size()==3,"Live settings expose all save slots")
    check(ui.dialogue_body.get_parent()==ui.dialogue_scroll,"Long dialogue lives in scrollable viewport")
    var reader: HBoxContainer=ui.dialogue.get_node("DialogueReader")
    ui.dialogue_body.text="长文本无障碍验证。".repeat(60)
    ui.dialogue_body.visible_characters=2
    reader.reveal_button.pressed.emit()
    check(ui.dialogue_body.visible_characters==2,"hidden reader cannot reveal a stale speaker")
    var reader_speaker:=Area2D.new()
    main.add_child(reader_speaker)
    main.active_overlay="dialogue"
    ui.settings.hide();ui.dialogue.show();ui.dialogue_area=reader_speaker
    var reader_flags: Dictionary=main.story_flags.duplicate(true)
    var reader_inventory: Dictionary=main.inventory_counts.duplicate(true)
    var reader_wallet: int=main.currency_count
    ui.dialogue_body.visible_characters=2
    reader.refresh()
    reader.reveal_button.pressed.emit()
    check(ui.dialogue_body.visible_characters==-1 and main.subtitle_elapsed==main.subtitle_seconds,"reader reveal completes only the current subtitle")
    check(main.story_flags==reader_flags and main.inventory_counts==reader_inventory and main.currency_count==reader_wallet,"reader reveal cannot commit dialogue progress or rewards")
    reader.refresh()
    check(reader.reveal_button.disabled and reader.progress.text.contains("逐字 100%"),"completed text disables redundant reveal and shows reading progress")
    await process_frame
    check(ui.dialogue_body.get_minimum_size().y>ui.dialogue_scroll.size.y,"Oversize dialogue expands within scrollable container")
    reader.turn(1)
    check(ui.dialogue_scroll.scroll_vertical>0,"reader page button scrolls actual oversized dialogue")
    reader.turn(-1)
    check(ui.dialogue_scroll.scroll_vertical==0,"reader page up returns to the top within bounds")
    reader.refresh()
    check(reader.previous_button.disabled and Rect2(Vector2.ZERO,ui.dialogue.size).encloses(reader.get_rect()),"reader controls fit the dialogue panel and disable the top boundary")
    ui.dialogue.hide();ui.dialogue_area=null;reader_speaker.free()
    main.active_overlay="settings";ui.settings.show()
    var saved_bytes := FileAccess.get_file_as_bytes(main.world_save_path)
    check(DirAccess.copy_absolute(ProjectSettings.globalize_path(main.world_save_path),ProjectSettings.globalize_path(main.world_save_path+".previous"))==OK,"history UI fixture preserves a journey")
    ui.journey_history_button.pressed.emit()
    await process_frame
    check(ui.journey_history_dialog.visible and ui.is_browsing_journey_history(),"settings history button opens an input-isolated browser")
    check(ui.journey_history_text.text.contains("只读浏览") and ui.journey_history_text.text.contains("苔钟庭"),"browser displays the archived progress in Chinese")
    check(FileAccess.get_file_as_bytes(main.world_save_path)==saved_bytes and not main.chapter_transitioning,"browsing never replaces or reloads the active journey")
    ui.journey_history_dialog.hide()
    ui.journey_history_dialog.canceled.emit()
    check(ui.is_browsing_journey_history(),"closing browser blocks the same-frame Escape from closing settings")
    await process_frame
    check(not ui.is_browsing_journey_history() and main.active_overlay=="settings","browser returns to settings after its capture frame")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(main.world_save_path+".previous"))
    main.free()
    await process_frame
    for suffix in ["",".tmp",".bak"]:DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ui_world_integration_validation.json"+suffix))
    print("UI_WORLD_INTEGRATION_VALIDATION_%s failures=%d" % ["PASS" if failures==0 else "FAIL",failures])
    quit(1 if failures else 0)

## Component fixture: production Boss death and its normal dissolve, not a
## natural boss clear. Keep the freed reference until the HUD has used it.
func boss_hud_retirement(main: Node) -> void:
    main._close_overlays()
    main._spawn_boss()
    var actor: Node=main.boss_actor
    actor.set_physics_process(false)
    var ui: Control=main.ui_shell
    ui._process(0.0)
    check(ui.boss_bar.visible and ui.boss_name.visible and ui.boss_bar.value==actor.hp,"Boss HUD reads the actual live actor")
    actor.take_hit(actor.hp,1)
    ui._process(0.0)
    check(main.demo_complete and not ui.boss_bar.visible and not ui.boss_name.visible,"Boss defeat hides its HUD during the original dissolve")
    for frame in 120:
        await physics_frame
        await process_frame
        if not is_instance_valid(actor):break
    check(not is_instance_valid(main.boss_actor),"Production dissolve leaves the actual freed Boss reference in the fixture")
    var reward: String=String(main.config.boss.get("reward_item","crown_splinter"))
    main.story_flags["ui_pin_"+reward]=true
    ui.pinned.text="before retired Boss refresh"
    ui._process(0.0)
    check(not ui.boss_bar.visible and not ui.boss_name.visible,"Boss HUD remains hidden after its actor is freed")
    check(ui.pinned.text=="旅记 · "+main._item_display_name(reward),"HUD continues to refresh the journal after Boss retirement")
