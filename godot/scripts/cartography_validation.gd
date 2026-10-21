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
    check(JOURNAL.rest(flags)==0 and not JOURNAL.charted(flags,"a","room_a") and JOURNAL.region(flags,"a").pending.has("room_a"),"without the quill a rest keeps notes pending")
    JOURNAL.grant_quill(flags)
    check(JOURNAL.rest(flags)==1 and JOURNAL.charted(flags,"a","room_a"),"with the quill a rest commits owned map notes")
    check(not JOURNAL.charted(flags,"b","room_b") and JOURNAL.region(flags,"b").pending.has("room_b"),"unowned remote notes remain pending")
    check(JOURNAL.rest(flags)==0,"rest is idempotent")
    var priced: Dictionary={}
    check(not JOURNAL.purchase(priced,"c",44,45).ok and JOURNAL.purchase(priced,"c",50,45).wallet==5,"purchase charges the seller's own price")
    var legacy: Dictionary={"quest_old":true}
    JOURNAL.migrate(legacy,{"a":{"visited_rooms":{"old_room":true}}})
    check(legacy.quest_old and JOURNAL.region(legacy,"a").pending.has("old_room"),"legacy exploration retained without free map or detail")
    JOURNAL.legacy_quill(legacy)
    check(not JOURNAL.has_quill(legacy),"a save without any map does not receive a free quill")
    JOURNAL.region(legacy,"a").owned=true
    JOURNAL.legacy_quill(legacy)
    check(JOURNAL.has_quill(legacy),"a save that already owned a map keeps charting at shrines")
    var scene: Node=load("res://scenes/World.tscn").instantiate()
    scene.world_save_path=SAVE
    scene.world_resume=false
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
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
    scene._toggle_backpack()
    check(not dialog.visible and scene.active_overlay=="backpack","backpack closes seller window")
    scene._close_overlays()
    RUNTIME.open_shop(scene,stall)
    scene._toggle_audio_settings()
    check(not dialog.visible and scene.active_overlay=="settings","settings closes seller window")
    scene._close_overlays()
    RUNTIME.open_shop(scene,stall)
    dialog.confirmed.emit()
    check(not JOURNAL.owned(scene.story_flags,id) and scene.currency_count==0,"failed UI transaction does not charge or grant")
    check(not scene.player.ui_input_locked and not dialog.visible,"confirmation returns player control")
    # A later region's seller price, applied to this live stall, must be what the dialog shows and charges.
    var seller_data: Dictionary=stall.get_meta("map_seller_data")
    seller_data["price"]=35
    stall.set_meta("map_seller_data",seller_data)
    scene.currency_count=34
    scene._try_interact()
    check(dialog.get_ok_button().disabled and dialog.dialog_text.contains("35枚"),"live shop shows the seller's price and refuses one coin short")
    scene._close_overlays()
    scene.currency_count=40
    scene._try_interact()
    check(not dialog.get_ok_button().disabled,"sufficient currency enables purchase button")
    dialog.confirmed.emit()
    check(JOURNAL.owned(scene.story_flags,id) and scene.currency_count==5,"real confirmation buys current region map at the seller's price")
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
    check(not JOURNAL.charted(scene.story_flags,id,"entry_bell") and scene.toast_label.text.contains("盐墨绘针"),"a rest without the quill keeps notes and says why")
    # Buy the quill and compass through the live seller dialog.
    scene.player.position=stall.position
    scene.currency_count=RUNTIME.tool_price("quill")-1
    scene._try_interact()
    var quill_button: Button=dialog.find_child("MapSellerQuill",true,false)
    var compass_button: Button=dialog.find_child("MapSellerCompass",true,false)
    check(quill_button.visible and quill_button.disabled and compass_button.visible,"seller offers both survey tools and refuses the quill one coin short")
    scene.currency_count=RUNTIME.tool_price("quill")+RUNTIME.tool_price("compass")
    RUNTIME.open_shop(scene,stall)
    if not await _keyboard_quill_purchase(scene, dialog, quill_button, stall):
        scene.free()
        await process_frame
        quit(1)
        return
    check(JOURNAL.has_quill(scene.story_flags) and scene.currency_count==RUNTIME.tool_price("compass") and not quill_button.visible,"real shop sells the quill once at its price")
    dialog.custom_action.emit("compass")
    check(scene.build_system.state.unlocked_passives.has("compass") and scene.currency_count==0 and not compass_button.visible,"real shop sells the compass once at its price")
    check(not RUNTIME.purchase_tool(scene,stall,"quill").ok and not RUNTIME.purchase_tool(scene,stall,"compass").ok and scene.currency_count==0,"survey tools cannot be bought twice")
    scene._close_overlays()
    scene.player.position=scene._vec2(scene.config.player_start)
    scene._activate_save_point(shrine)
    scene._toggle_map()
    base=scene.map_draw_root.get_node_or_null("SurveyRoom_entry_bell")
    check(base!=null and bool(base.get_meta("charted")),"live bell-shrine rest with the quill inks visited room")
    check(scene.map_draw_root.get_node_or_null("SurveyPlayerMarker")==null and scene.map_text.text.contains("无罗盘"),"an unequipped compass shows no position marker")
    var travel: Array=scene.build_system.state.equipped_families.travel_accessory
    var free_slot := travel.find("")
    check(free_slot >= 0 and scene.build_system.equip_family_slot("compass","travel_accessory",free_slot).ok,"compass equips in a travel accessory slot")
    scene._refresh_map_overlay()
    check(scene.map_draw_root.get_node_or_null("SurveyPlayerMarker")!=null,"an equipped compass marks the player's position")
    scene.build_system.equip_family_slot("","travel_accessory",free_slot)
    scene.ui_shell.accessibility["navigation_assist"]=true
    scene._refresh_map_overlay()
    check(scene.map_draw_root.get_node_or_null("SurveyPlayerMarker")!=null,"navigation assist shows the position without a compass")
    scene.ui_shell.accessibility["navigation_assist"]=false
    check(scene.map_draw_root.get_node_or_null("SurveyPin_moss_archive_return")!=null,"charted room reveals its real portal")
    var wallet: int=scene.currency_count
    scene._close_overlays()
    scene.player.position=stall.position
    scene._try_interact()
    check(dialog.get_ok_button().disabled,"owned region map cannot be bought twice")
    dialog.custom_action.emit("talk")
    check(scene.active_overlay=="dialogue" and not dialog.visible,"map NPC retains its original story dialogue")
    scene.dialogue_text_label.visible_characters=-1
    scene._try_interact()
    check(not dialog.visible and scene.active_overlay!="cartographer","F advances seller narrative without reopening shop")
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
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
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
        await preload("res://scripts/world_ready_validation_helper.gd").wait_for(test_scene)
        test_scene.set_process(false)
        test_scene.player.set_physics_process(false)
        for enemy in get_nodes_in_group("enemy"):enemy.set_physics_process(false)
        var npc: Node=test_scene.get_node_or_null(NodePath(String(sellers[region_id].npc_id)))
        check(npc!=null and npc.has_meta("map_seller_region"),String(region_id)+": authored map NPC registered")
        check(npc!=null and npc.get_meta("kind","")=="npc",String(region_id)+": purchase belongs to a character, not a stall")
        test_scene._toggle_map()
        check(test_scene.map_draw_root.get_node("MapNotPurchased").text=="还未获得此区域地图",String(region_id)+": unpurchased M uses exact requested message")
        JOURNAL.region(test_scene.story_flags,String(region_id)).owned=true
        test_scene._refresh_map_overlay()
        var positions: Dictionary={}
        var initial_bounds: Rect2=RUNTIME.region_bounds(test_scene)
        var terrain: Array[PackedVector2Array]=RUNTIME.terrain_polygons(test_scene)
        var terrain_rooms:=0
        for room in test_scene.config.map_rooms:
            var node: Control=test_scene.map_draw_root.get_node_or_null("SurveyRoom_"+String(room.id))
            if RUNTIME.public_room(room):
                check(node!=null,String(region_id)+": public base room exists "+String(room.id))
                positions[String(room.id)]=Rect2(node.position,node.size)
            else:
                check(node==null,String(region_id)+": hidden/reward/exit withheld "+String(room.id))
            JOURNAL.visit(test_scene.story_flags,String(region_id),String(room.id))
        test_scene._refresh_map_overlay()
        for room_id in positions:
            var node: Control=test_scene.map_draw_root.get_node("SurveyRoom_"+room_id)
            check(Rect2(node.position,node.size)==positions[room_id],String(region_id)+": pending notes preserve base transform")
        JOURNAL.grant_quill(test_scene.story_flags)
        JOURNAL.rest(test_scene.story_flags)
        test_scene._refresh_map_overlay()
        check(RUNTIME.region_bounds(test_scene)==initial_bounds,String(region_id)+": secret charting preserves region bounds")
        for room in test_scene.config.map_rooms:
            var node: Control=test_scene.map_draw_root.get_node("SurveyRoom_"+String(room.id))
            if positions.has(String(room.id)):
                check(Rect2(node.position,node.size)==positions[String(room.id)],String(region_id)+": charting preserves original room position and scale")
            check(node.detailed,String(region_id)+": rest charts room")
            if not node.contours.is_empty(): terrain_rooms+=1
            for contour in node.contours:
                for point in contour:
                    check(point.x>=-0.001 and point.y>=-0.001 and point.x<=1.001 and point.y<=1.001,String(region_id)+": terrain clipped to physical room")
            var physical: Rect2=test_scene._room_layout_rect(room)
            check(RUNTIME.map_position(test_scene,room,physical.position,initial_bounds,test_scene.map_draw_root.size).is_equal_approx(node.position),String(region_id)+": terrain and marker share exact origin")
        check(terrain_rooms>0 and not terrain.is_empty(),String(region_id)+": charted ink includes runtime collision terrain")
        test_scene.queue_free()
        await process_frame
    for suffix in ["",".tmp",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE+suffix))
    print("CARTOGRAPHY checks=%d failures=%d fixture_positioning=true" % [checks,failures])
    call_deferred("quit",1 if failures else 0)

func _modal_key_event(dialog: Window, code: Key, pressed: bool) -> void:
    var event:=InputEventKey.new()
    event.keycode=code
    event.physical_keycode=code
    event.window_id=dialog.get_window_id() if dialog.visible and not dialog.is_embedded() else root.get_window_id()
    event.pressed=pressed
    Input.parse_input_event(event)
    Input.flush_buffered_events()

func _modal_key(dialog: Window, code: Key) -> void:
    _modal_key_event(dialog,code,true)
    for unused in 3: await process_frame
    _modal_key_event(dialog,code,false)
    for unused in 3: await process_frame

func _keyboard_quill_purchase(scene: Node, dialog: ConfirmationDialog, quill: Button, stall: Area2D) -> bool:
    # Actors are positioned/stopped by this component fixture; the real Main
    # process and native dialog must both see the ordinary keyboard events.
    scene.set_process(true)
    for unused in 12:
        if quill.has_focus() or not dialog.visible or scene.active_overlay!="cartographer":break
        await _modal_key(dialog,KEY_TAB)
    check(dialog.visible and scene.active_overlay=="cartographer","native seller retains Tab instead of opening the backpack")
    check(quill.has_focus(),"ordinary Tab navigation reaches the quill button")
    if dialog.visible and quill.has_focus():await _modal_key(dialog,KEY_ENTER)
    if JOURNAL.has_quill(scene.story_flags):
        _modal_key_event(dialog,KEY_F9,true)
        for unused in 3:await process_frame
        check(dialog.visible and scene.active_overlay=="cartographer" and not scene.new_journey_dialog.visible,"seller keeps native focus while the new-journey key is held")
        await _modal_key(dialog,KEY_ESCAPE)
        for unused in 3:await process_frame
        check(scene.active_overlay.is_empty() and not scene.new_journey_dialog.visible,"closing seller does not replay the held new-journey key")
        _modal_key_event(dialog,KEY_F9,false)
        for unused in 3:await process_frame
        RUNTIME.open_shop(scene,stall)
    scene.set_process(false)
    return dialog.visible and scene.active_overlay=="cartographer" and JOURNAL.has_quill(scene.story_flags)
