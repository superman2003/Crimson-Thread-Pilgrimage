extends SceneTree
const READY:=preload("res://scripts/world_ready_validation_helper.gd")
const RETIRE:=preload("res://scripts/audio_retirement.gd")
const MODEL:=preload("res://scripts/known_wish_manifest.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error(label)
func snapshot(world: Node) -> String:
    return var_to_str([world.currency_count,world.inventory_counts,world.story_flags,world.build_system.serialize(),world.player.hp,world.player.energy,world.player.global_position])
func run() -> void:
    var world: Node=load("res://scenes/World.tscn").instantiate()
    world.world_resume=false;world.world_save_path="user://known_wish_world.json";root.add_child(world)
    await READY.wait_for(world)
    if world.player==null:check(false,"World readiness");quit(1);return
    for unused in 4:await physics_frame
    world.set_process(false);world.player.set_physics_process(false)
    for enemy in get_nodes_in_group("enemy"):enemy.set_physics_process(false)
    world._toggle_backpack();var ui: Control=world.ui_shell
    ui.bag.get_node("GoalDeskButton").pressed.emit();await process_frame
    var desk: Node=ui.get_node_or_null("GoalDesk")
    if desk==null:check(false,"missing actual goal desk");RETIRE.retire_tree(world);world.queue_free();await process_frame;quit(1);return
    var button:=desk.window.find_child("KnownWishManifestButton",true,false) as Button
    check(button!=null and button.is_visible_in_tree(),"actual goal workbench has owned wish-manifest launcher")
    button.grab_focus();button.pressed.emit();await process_frame
    var dialog: Node=desk.wish_manifest
    check(dialog.visible and dialog.query.has_focus() and world.player.ui_input_locked,"actual nested manifest opens with keyboard focus and bag ownership")
    check(dialog.report.ok and dialog.report.rows.is_empty(),"fresh journey does not reveal unasked NPC delivery requests")
    var person: Dictionary={}
    for npc in world.config.npcs:
        if npc.get("dialogue_topics",{}).get("quest",{}).get("accept_flag","")!="":person=npc;break
    check(not person.is_empty(),"canonical current region has an authored delivery wish")
    if person.is_empty():RETIRE.retire_tree(world);world.queue_free();await process_frame;quit(1);return
    var quest: Dictionary=person.dialogue_topics.quest
    # Explicit saved-state fixture: this is not a claim of natural NPC discovery.
    world.story_flags[String(quest.accept_flag)]=true;world.inventory_counts[String(quest.item)]=2
    check(world._save_world(),"fixture saves accepted canonical wish before readonly controls")
    var before:=snapshot(world)
    var bytes:=FileAccess.get_file_as_bytes(world.world_save_path)
    var flags: Dictionary=world.story_flags.duplicate(true)
    var inventory: Dictionary=world.inventory_counts.duplicate(true)
    dialog.refresh()
    check(dialog.report.rows.size()==1 and dialog.visible_rows.size()==1,"real source adapter projects accepted current-region NPC")
    check(dialog.detail.text.contains(String(person.name)) and dialog.detail.text.contains(world._item_display_name(String(quest.item))),"UI names come from actual canonical person and item records")
    check(not dialog.detail.text.contains(String(person.id)) and not dialog.detail.text.contains(str(person.position)),"UI omits internal identity and coordinates")
    check(dialog.summary.text.contains("需备1份") and dialog.summary.text.contains("持有2"),"canonical show-only wish needs one reusable token")
    dialog.view_mode.select(1);dialog.view_mode.item_selected.emit(1)
    check(dialog.visible_rows.size()==1 and dialog.visible_rows[0].ready,"ready filter uses real current inventory")
    dialog.query.text=String(person.id);dialog.query.text_changed.emit(dialog.query.text)
    check(dialog.visible_rows.is_empty() and dialog.detail.text.contains("没有已登记"),"private NPC ID is not a public search term")
    dialog.query.text=String(person.name);dialog.query.text_changed.emit(dialog.query.text)
    check(dialog.visible_rows.size()==1,"public person name restores actual known wish")
    dialog.region.select(1);dialog.region.item_selected.emit(1)
    check(dialog.visible_rows.size()==1,"known-region selector scopes the authored request")
    dialog.preserve.button_pressed=true;dialog.preserve.toggled.emit(true)
    check(dialog.summary.text.contains("另留一份"),"explicit proof-preservation preference is visible and transient")
    world.inventory_counts[String(quest.item)]=true;dialog.refresh()
    dialog.view_mode.select(2);dialog.view_mode.item_selected.emit(2)
    check(dialog.visible_rows.size()==1 and dialog.detail.text.contains("暂不可读取"),"invalid live stock is reported rather than treated as one")
    world.inventory_counts=inventory.duplicate(true)
    world.story_flags[String(quest.complete_flag)]=true;dialog.refresh()
    dialog.view_mode.select(3);dialog.view_mode.item_selected.emit(3)
    check(dialog.visible_rows.size()==1 and dialog.detail.text.contains("已经完成") and dialog.summary.text.contains("没有未完成"),"completion does not request another gift or charge it twice")
    world.story_flags=flags.duplicate(true);dialog.view_mode.select(0);dialog.query.clear();dialog.refresh()
    var regions_before: Dictionary=world.world_state.data.regions.duplicate(true)
    var foreign: Dictionary={}
    for region_id in preload("res://scripts/world_routes.gd").cached_chapters():
        if region_id==String(world.config.id):continue
        var config_path:=preload("res://scripts/world_routes.gd").cached_config_path(region_id)
        var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(config_path))
        for npc in data.get("npcs",[]):
            if not String(npc.get("dialogue_topics",{}).get("quest",{}).get("accept_flag","")).is_empty():foreign={"id":region_id,"npc":npc,"name":data.name};break
        if not foreign.is_empty():break
    check(not foreign.is_empty(),"authored second region has a canonical delivery wish")
    var foreign_quest: Dictionary=foreign.npc.dialogue_topics.quest
    world.story_flags[String(foreign_quest.accept_flag)]=true
    dialog.refresh()
    check(dialog.report.rows.size()==1,"accepted flag alone cannot reveal a region absent from this journey's visited records")
    world.world_state.data.regions[foreign.id]={}
    dialog.refresh()
    check(dialog.report.rows.size()==2,"visited canonical region contributes its already-asked wish without traveling")
    check(dialog.region_ids.has(foreign.id) and dialog.region.item_count==3,"cross-region selector contains only the two registered known places")
    check(world.world_state.data.regions.size()==regions_before.size()+1,"readonly source lookup does not manufacture further region records")
    world.world_state.data.regions=regions_before
    world.story_flags=flags.duplicate(true);dialog.refresh()
    check(snapshot(world)==before and FileAccess.get_file_as_bytes(world.world_save_path)==bytes,"readonly controls preserve gameplay values and exact save bytes")
    desk.window.hide();await process_frame
    check(not dialog.visible and dialog.report.is_empty() and dialog.detail.text.is_empty() and dialog.summary.text.is_empty(),"closing goal owner retires all wish records and detail")
    dialog.refresh();check(dialog.report.is_empty(),"hidden late refresh cannot repopulate retired records")
    desk.open();desk.open_wish_manifest();await process_frame
    check(dialog.visible and not dialog.preserve.button_pressed and dialog.view_mode.selected==0,"reopen starts fresh explicit filters and reservation option")
    world._close_overlays();await process_frame
    check(not dialog.visible and not world.player.ui_input_locked,"closing bag retires child and restores player input")
    check(snapshot(world)==before and FileAccess.get_file_as_bytes(world.world_save_path)==bytes,"closing does not deliver a wish or grant a reward")
    RETIRE.retire_tree(world);world.queue_free();await process_frame
    check(await RETIRE.drain(self),"actual World audio retirement")
    for suffix in ["",".tmp",".bak",".previous"]:DirAccess.remove_absolute(ProjectSettings.globalize_path("user://known_wish_world.json"+suffix))
    print("KNOWN_WISH_WORLD checks=%d failures=%d" % [checks,failures]);quit(0 if failures==0 else 1)
