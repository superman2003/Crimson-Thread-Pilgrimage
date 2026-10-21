extends RefCounted
const JOURNAL := preload("res://scripts/enemy_journal.gd")
const WORLD := preload("res://scripts/world_state.gd")

func run(main: Node,tree: SceneTree,check: Callable) -> void:
    var combat: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/original_creature_combat.json"))
    check.call(JOURNAL._entries().size()==46 and JOURNAL._entries().keys()==combat.keys(),"journal covers the actual forty ordinary and six boss kinds")
    check.call(JOURNAL.records({}).is_empty(),"unencountered enemy names and totals stay hidden")
    check.call(JOURNAL.flag_for("fake_enemy").is_empty() and JOURNAL.records({"journal_enemy_fake_enemy":true}).is_empty(),"unknown saved names cannot inject journal entries")
    check.call(JOURNAL.records({JOURNAL.flag_for("moss_larva"):1}).is_empty(),"numeric or malformed flags do not reveal enemy records")
    var ui: Node=main.ui_shell
    main._close_overlays()
    main._toggle_backpack()
    ui.bag_category="旅记"
    ui.journal_filter="enemy"
    ui.refresh_inventory()
    await tree.process_frame
    check.call(ui.bag_grid.get_child_count()==0 and ui.bag_name.text=="尚无敌人记录","empty enemy category explains discovery without listing future enemies")
    check.call(ui.journal_filters.visible and ui.journal_filter_buttons.size()==6,"real journal exposes six record filters")
    var contained := true
    for button in ui.journal_filter_buttons.values():contained=contained and ui.bag.get_global_rect().encloses(button.get_global_rect())
    check.call(contained and ui.bag_scroll.position.y>=ui.journal_filters.position.y+ui.journal_filters.size.y,"filter controls fit the scaled panel above the scrolling records")
    ui.journal_filter_buttons.evidence.pressed.emit()
    await tree.process_frame
    var only_evidence := true
    for button in ui.bag_grid.get_children():only_evidence=only_evidence and String(button.get_meta("journal_key","")).begins_with("evidence:")
    check.call(only_evidence and not ui.bag_description.text.contains("雨铸渠的工匠名字"),"evidence filter keeps canonical unknown-clue withholding")
    main._close_overlays()
    var data: Dictionary=main.config.enemy_spawns[0].duplicate(true)
    data.id="journal_record_enemy_one"
    data.hp=1
    var enemy: Node=main._enemy(data)
    enemy.set_physics_process(false)
    check.call(JOURNAL.records(main.story_flags).is_empty(),"loading a real enemy prefab does not reveal it")
    enemy.take_hit(99,1)
    var records := JOURNAL.records(main.story_flags)
    check.call(records.size()==1 and records[0].title=="苔钟幼虫","actual enemy defeat signal records a localized battle note")
    var loaded := WORLD.new()
    check.call(loaded.read(main.world_save_path) and JOURNAL.records(loaded.data.story_flags).size()==1,"existing victory save persists the discovered enemy record")
    data.id="journal_record_enemy_two"
    enemy=main._enemy(data)
    enemy.set_physics_process(false)
    enemy.take_hit(99,1)
    check.call(JOURNAL.records(main.story_flags).size()==1,"repeat defeats and respawns cannot duplicate records")
    main._toggle_backpack()
    ui.bag_category="旅记"
    ui.journal_filter_buttons.enemy.pressed.emit()
    await tree.process_frame
    check.call(ui.bag_grid.get_child_count()==1 and ui.bag_description.text.contains("短促咬击") and ui.bag_category_label.text.contains("已击败"),"enemy filter renders the discovered combat identity through production controls")
    ui.journal_filter_buttons.all.pressed.emit()
    await tree.process_frame
    for button in ui.bag_grid.get_children():
        if String(button.get_meta("journal_key","")).begins_with("enemy:"):button.grab_focus()
    ui.journal_filter_buttons.evidence.pressed.emit()
    await tree.process_frame
    ui.journal_filter_buttons.all.pressed.emit()
    await tree.process_frame
    check.call(ui.bag_name.text=="苔钟幼虫","returning to a filter restores its selected record by identity")
    main._close_overlays()
