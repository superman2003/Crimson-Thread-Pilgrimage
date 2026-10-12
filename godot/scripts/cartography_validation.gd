extends SceneTree
const JOURNAL := preload("res://scripts/pilgrimage_cartography.gd")
const RUNTIME := preload("res://scripts/cartography_runtime.gd")
const STATE := preload("res://scripts/world_state.gd")
const SAVE := "user://cartography_validation.json"
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:
        failures+=1
        push_error(label)
func run() -> void:
    var flags: Dictionary={}
    JOURNAL.visit(flags,"a","room_a")
    JOURNAL.visit(flags,"b","room_b")
    check(JOURNAL.rest(flags)==0,"rest cannot reveal unpurchased regions")
    check(not JOURNAL.purchase(flags,"a",19).ok,"insufficient funds leave ownership unchanged")
    var sale:=JOURNAL.purchase(flags,"a",40)
    check(sale.ok and sale.wallet==20,"purchase deducts exactly twenty")
    check(not JOURNAL.charted(flags,"a","room_a"),"purchase grants coarse base map, not pending detail")
    check(not JOURNAL.purchase(flags,"a",20).ok,"repeat purchase cannot charge again")
    check(JOURNAL.rest(flags)==1 and JOURNAL.charted(flags,"a","room_a"),"rest commits owned map notes")
    check(not JOURNAL.charted(flags,"b","room_b") and JOURNAL.region(flags,"b").pending.has("room_b"),"unowned remote notes remain pending")
    check(JOURNAL.rest(flags)==0,"rest is idempotent")
    var legacy: Dictionary={"quest_old":true}
    JOURNAL.migrate(legacy,{"a":{"visited_rooms":{"old_room":true}}})
    check(legacy.quest_old and JOURNAL.region(legacy,"a").pending.has("old_room"),"legacy exploration retained without free map or detail")
    var scene: Node=load("res://scenes/World.tscn").instantiate()
    scene.world_save_path=SAVE
    scene.world_resume=false
    root.add_child(scene)
    scene.set_process(false)
    scene.player.set_physics_process(false)
    for enemy in get_nodes_in_group("enemy"): enemy.set_physics_process(false)
    var id:=String(scene.config.id)
    var stall: Area2D=scene.get_node("npc_gear_cartographer")
    scene._toggle_map()
    check(scene.map_draw_root.get_node_or_null("MapNotPurchased")!=null,"M map with no purchase shows no room routes")
    check(scene.map_draw_root.get_node_or_null("SurveyRoom_entry_bell")==null,"unowned room geometry hidden")
    scene._close_overlays()
    scene.player.position=stall.position
    scene.currency_count=0
    scene._try_interact()
    var dialog: ConfirmationDialog=scene.get_node("MapPurchaseDialog")
    check(dialog.theme.default_font!=null,"map shop explicitly inherits Chinese UI font")
    check(dialog.visible and scene.player.ui_input_locked,"real F opens purchase confirmation and locks gameplay")
    check(dialog.get_ok_button().disabled,"insufficient game currency disables purchase button")
    dialog.confirmed.emit()
    check(not JOURNAL.owned(scene.story_flags,id) and scene.currency_count==0,"failed UI transaction does not charge or grant")
    check(not scene.player.ui_input_locked and not dialog.visible,"confirmation returns player control")
    scene.currency_count=40
    scene._try_interact()
    check(not dialog.get_ok_button().disabled,"sufficient currency enables purchase button")
    dialog.confirmed.emit()
    check(JOURNAL.owned(scene.story_flags,id) and scene.currency_count==20,"real confirmation buys current region map")
    scene.player.position=scene._vec2(scene.config.player_start)
    scene._update_room_visit()
    scene._toggle_map()
    var base: Node=scene.map_draw_root.get_node_or_null("SurveyRoom_entry_bell")
    check(base!=null and not bool(base.get_meta("charted")),"walking after purchase still shows coarse ink")
    check(scene.map_draw_root.get_node_or_null("SurveyRoom_hidden_attic")==null,"secret outline not exposed by base map")
    check(scene.map_draw_root.get_node_or_null("SurveyPin_moss_archive_return")==null,"entry details wait for bell shrine")
    scene._close_overlays()
    var shrine: Area2D=scene.get_node("save_first_bell")
    scene._activate_save_point(shrine)
    scene._toggle_map()
    base=scene.map_draw_root.get_node_or_null("SurveyRoom_entry_bell")
    check(base!=null and bool(base.get_meta("charted")),"live bell-shrine rest inks visited room")
    check(scene.map_draw_root.get_node_or_null("SurveyPin_moss_archive_return")!=null,"charted room reveals its real portal")
    var wallet: int=scene.currency_count
    scene._close_overlays()
    scene.player.position=stall.position
    scene._try_interact()
    check(dialog.get_ok_button().disabled,"owned region map cannot be bought twice")
    dialog.custom_action.emit("talk")
    check(scene.active_overlay=="dialogue" and not dialog.visible,"map NPC retains its original story dialogue")
    scene._close_overlays()
    check(not RUNTIME.purchase(scene,stall).ok and scene.currency_count==wallet,"duplicate direct transaction cannot spend again")
    JOURNAL.visit(scene.story_flags,id,"hidden_attic")
    scene._save_world()
    var saved:=STATE.new()
    check(saved.read(SAVE),"existing atomic world save accepts journal data")
    check(JOURNAL.owned(saved.data.story_flags,id) and JOURNAL.charted(saved.data.story_flags,id,"entry_bell"),"disk preserves ownership and charted rooms")
    check(not JOURNAL.charted(saved.data.story_flags,id,"hidden_attic") and JOURNAL.region(saved.data.story_flags,id).pending.has("hidden_attic"),"autosave preserves pending notes without revealing them")
    scene.queue_free()
    await process_frame
    scene=load("res://scenes/World.tscn").instantiate()
    scene.world_save_path=SAVE
    scene.world_resume=true
    root.add_child(scene)
    scene.set_process(false)
    scene.player.set_physics_process(false)
    for enemy in get_nodes_in_group("enemy"): enemy.set_physics_process(false)
    scene._toggle_map()
    check(scene.map_draw_root.get_node_or_null("SurveyRoom_hidden_attic")==null,"restart keeps pending secret uncharted")
    scene._close_overlays()
    scene._activate_save_point(scene.get_node("save_first_bell"))
    scene._toggle_map()
    check(scene.map_draw_root.get_node_or_null("SurveyRoom_hidden_attic")!=null,"rest after restart commits pending secret")
    scene.queue_free()
    await process_frame
    var sellers: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/cartography_sellers.json"))
    for region_id in sellers:
        var test_scene: Node=load("res://scenes/World.tscn").instantiate()
        test_scene.config_path="res://data/"+String(region_id)+".json"
        test_scene.world_resume=false
        test_scene.world_save_path=SAVE
        root.add_child(test_scene)
        test_scene.set_process(false)
        test_scene.player.set_physics_process(false)
        for enemy in get_nodes_in_group("enemy"):enemy.set_physics_process(false)
        var npc: Node=test_scene.get_node_or_null(NodePath(String(sellers[region_id].npc_id)))
        check(npc!=null and npc.has_meta("map_seller_region"),String(region_id)+": authored map NPC registered")
        check(npc!=null and npc.get_meta("kind","")=="npc",String(region_id)+": purchase belongs to a character, not a stall")
        test_scene._toggle_map()
        check(test_scene.map_draw_root.get_node("MapNotPurchased").text=="还未获得此区域地图",String(region_id)+": unpurchased M uses exact requested message")
        test_scene.queue_free()
        await process_frame
    for suffix in ["",".tmp",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE+suffix))
    print("CARTOGRAPHY checks=%d failures=%d fixture_positioning=true" % [checks,failures])
    call_deferred("quit",1 if failures else 0)
