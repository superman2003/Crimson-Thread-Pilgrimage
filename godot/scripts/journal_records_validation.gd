extends RefCounted
const JOURNAL := preload("res://scripts/enemy_journal.gd")
const WORLD := preload("res://scripts/world_state.gd")

static func filters_match(buttons: Dictionary) -> bool:
    var expected:=["all","main","quest","evidence","enemy","ending","guide","ability","voice"]
    if buttons.size()!=expected.size():return false
    for id in expected:
        if not buttons.get(id) is Button:return false
    return true

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
    check.call(ui.journal_filters.visible and filters_match(ui.journal_filter_buttons),"real journal contains exactly the six original filters, guide, earned ability and earned voice")
    var contained := true
    for button in ui.journal_filter_buttons.values():contained=contained and ui.bag.get_global_rect().encloses(button.get_global_rect())
    check.call(contained and ui.bag_scroll.position.y>=ui.journal_filters.position.y+ui.journal_filters.size.y,"filter controls fit the scaled panel above the scrolling records")
    var guide_flags: Dictionary=main.story_flags.duplicate(true)
    var guide_hp: int=main.player.hp
    var guide_energy: int=main.player.energy
    ui.journal_filter_buttons.guide.pressed.emit()
    await tree.process_frame
    check.call(ui.bag_grid.get_child_count()==4 and ui.bag_category_label.text.contains("操作手册"),"field-guide filter opens four complete teaching notes through production controls")
    var guide_text: String=ui.bag_description.text
    var quote: Dictionary=main.player.get_heal_readiness()
    check.call(guide_text.contains("消耗 %d 绯线" % int(quote.cost)) and guide_text.contains("恢复 %d 生命" % int(quote.amount)),"teaching note quotes the actual current Player recovery values")
    check.call(main.story_flags==guide_flags and main.player.hp==guide_hp and main.player.energy==guide_energy,"reading teaching notes grants no progress or resources")
    var guide:=preload("res://scripts/field_guide.gd")
    check.call(guide.ability_records({},{}).is_empty(),"unknown abilities reveal no manual titles or controls")
    var earned:={}
    for row in preload("res://scripts/protagonist_voice.gd").catalogue():earned[String(row.ability)]=1
    var earned_before:=earned.duplicate(true)
    var controls:={"jump":"重绑跳跃","hook":"重绑钩索","aim_down":"重绑向下","attack":"重绑针击","lantern_phase":"重绑相位"}
    var manuals: Array=guide.ability_records(earned,controls)
    check.call(manuals.size()==8 and earned==earned_before,"all eight earned abilities have read-only operating notes")
    check.call(String(manuals[3].description).contains("重绑钩索") and String(manuals[3].description).contains("重绑跳跃") and String(manuals[5].description).contains("重绑向下") and String(manuals[5].description).contains("重绑针击"),"compound ability instructions use actual remapped controls")
    for invalid in [true,"1",0,-1,0.5,NAN,INF,1000001]:
        check.call(guide.ability_records({"echo_hook":invalid},controls).is_empty(),"invalid inventory cannot expose an unearned ability: "+str(invalid))
    check.call(guide.ability_records({"echo_hook":1.0},controls).size()==1,"legacy whole-number inventory values remain compatible")
    var catalogue: Dictionary=main.build_system.catalog
    for crest in catalogue.crests.values():
        var sample:={"cost":crest.heal_cost,"amount":crest.heal_amount,"duration":crest.heal_duration}
        var rows: Array=guide.records(sample,{"heal":"自定义疗伤键"})
        check.call(String(rows[0].description).contains("消耗 %d 绯线" % int(crest.heal_cost)) and String(rows[0].description).contains("恢复 %d 生命" % int(crest.heal_amount)) and String(rows[0].description).contains("自定义疗伤键"),"field guide accepts each canonical crest's distinct recovery quote and rebound input")
    check.call(not String(guide.records({},{} ,false)[3].description).contains("召回") and String(guide.records({},{} ,true)[3].description).contains("六成"),"late recall teaching appears only after its existing unlock rule")
    check.call(String(guide.records({"cost":NAN,"amount":1,"duration":1.0},{})[0].description).contains("当前提示"),"malformed recovery values use explanatory text instead of invented numbers")
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
