extends SceneTree
## Focused production-UI fixture for typed loadout slots and paid partial resupply.
const UI = preload("res://scripts/pilgrimage_interface.gd")
const SETTINGS_PATH := "user://build_slots_ui_validation.cfg"
var checks := 0
var failures: Array[String]=[]

class MockBuild extends RefCounted:
    var catalog: Dictionary=preload("res://scripts/build_system.gd").new().catalog
    var previews: Dictionary={}
    var snapshot: Dictionary={}
    var state: Dictionary={"crest":"crimson","skills":["cleave","needle"],"tools":["shard","mine"],"active_skill_slot":0,"active_tool_slot":0}
    var cooldowns: Dictionary={}
    func get_snapshot() -> Dictionary:return snapshot.duplicate(true)
    func preview_loadout(name: String,_at_bell: bool=true) -> Dictionary:return previews.get(name,{"can_restore":false,"reason":"方案尚未保存"}).duplicate(true)

class MockNarrative extends RefCounted:
    var encountered_choice:=false
    func evaluate_progress(_inventory: Dictionary,_flags: Dictionary) -> Dictionary:
        var evidence: Dictionary={"id":"testimony_known","title":"已知证词","acquired":false,"location_hint":"已确认的线索位置"}
        var endings: Array=[]
        if encountered_choice:
            endings=[{"id":"ending_a","title":"续线结局","available":false,"status":"locked","chosen":false,
                "missing":[{"id":"secret_testimony","label":"不可见证词","hint":"绝密位置","kind":"evidence"}],
                "known_missing":[{"id":"testimony_known","label":"已知缺页","region":"雾庭","hint":"检查钟龛旁的石刻。","kind":"evidence"}],
                "hidden_missing_count":1,"message":"选择仍在准备中。","consequences":{}}]
        return {"quests":[],"entries":[evidence],"known_entries":[evidence],"endings":endings}

class MockPlayer extends Node:
    var build_profile: Dictionary={"hazard_trigger_mult": 1.0}
    var hp:=5
    var max_hp:=8
    var energy:=70
    var max_energy:=100
    func get_seal_mechanism_snapshot() -> Dictionary:return {"label":"线势","stacks":1,"max_stacks":3}
    func get_combat_ui_state() -> Dictionary:return {}

class MockRuntime extends Node:
    const AUDIO_SETTINGS_ROWS := [["master","总音量"],["music","音乐"],["sfx","音效"],["ambience","环境"]]
    var audio_director: Node
    var player: Node
    var build_system: MockBuild
    var world_mode:=false
    var world_narrative: MockNarrative
    var active_overlay := "build"
    var currency_count:=120
    var inventory_counts: Dictionary={"moss_chitin":5}
    var backpack_entry_ids: Array[String]=[]
    var backpack_selection: int=-1
    var story_flags: Dictionary={}
    var settings_selection:=0
    var current_room_id:="test"
    var config: Dictionary={"chapter_name":"验证区"}
    var boss_actor: Node
    var demo_complete:=false
    var last_action:=""
    var last_id:=""
    var last_extra: Variant
    var action_calls: Array[String]=[]
    func get_build_system() -> RefCounted:return build_system
    func is_near_shrine() -> bool:return bool(build_system.snapshot.get("at_workstation",false))
    func perform_build_action(action: String,id: String="",extra: Variant=null) -> Dictionary:
        last_action=action
        last_id=id
        last_extra=extra
        action_calls.append(action)
        if action=="quote_resupply":return {"ok":true,"charges":{"shard":1,"mine":1},"cost":{"currency":12,"materials":{"moss_chitin":1}}}
        if action=="resupply_tools":return {"ok":true,"reason":"补给已购买"}
        if action=="equip_family_slot":return {"ok":true,"reason":"装备已更新"}
        return {"ok":true,"reason":"已切换"}
    func _toggle_build() -> void:active_overlay="build" if active_overlay=="" else ""
    func _close_overlays() -> void:active_overlay=""
    func _toggle_backpack() -> void:pass
    func _toggle_map() -> void:pass
    func _toggle_audio_settings() -> void:pass
    func _settings_selection_clamped() -> int:return settings_selection
    func _backpack_selection_clamped() -> int:return backpack_selection
    func _map_room_by_id(_id: String) -> Dictionary:return {"name":"验证房间"}
    func _nearest_interactable(_range: int) -> Area2D:return null
    func _item_display_name(id: String) -> String:return {"moss_chitin":"苔壳"}.get(id,id)
    func _item_data(_id: String) -> Dictionary:return {"category":"Materials"}
    func _item_display_description(_id: String) -> String:return "验证物品"

func _initialize() -> void:call_deferred("_run")

func _check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures.append(label)

func _slot(id: String,family: String,index: int,compatible: Array[String],unlocked: bool,equipped_id: String) -> Dictionary:
    return {"id":id,"family":family,"index":index,"compatible":compatible,"unlocked":unlocked,"equipped_id":equipped_id}

func _option(id: String,name: String,family: String,cost: int=0,unlocked: bool=true) -> Dictionary:
    return {"id":id,"name":name,"slot_family":family,"cost":cost,"unlocked":unlocked,"description":"验证用装备"}

func _run() -> void:
    var runtime:=MockRuntime.new()
    root.add_child(runtime)
    runtime.player=MockPlayer.new()
    runtime.add_child(runtime.player)
    runtime.build_system=MockBuild.new()
    runtime.build_system.snapshot={
        "at_workstation":true,"crest":"crimson","skill":"cleave","tool":"shard","currency":120,
        "slots_used":1,"slots_total":3,"loadouts":[],"crests":[{"id":"crimson","name":"赤契","unlocked":true,"selected":true}],"recipes":[],
        "skills":[_option("cleave","裂斩","thread_skill"),_option("needle","丝针","thread_skill")],
        "tools":[_option("shard","碎片","tool"),_option("mine","线雷","tool")],
        "passive_options":[_option("stride","疾行铭饰","combat_accessory",1),_option("mender","愈线铭饰","combat_accessory",2),_option("wayfinder","引路铭饰","travel_accessory",1)],
        "slot_layout":{
            "tool":[_slot("tool_0","tool",0,["shard","mine"],true,"shard"),_slot("tool_1","tool",1,["mine"],false,"mine")],
            "combat_accessory":[_slot("combat_accessory_0","combat_accessory",0,["stride","mender"],true,"stride"),_slot("combat_accessory_1","combat_accessory",1,["stride","mender"],true,""),_slot("combat_accessory_2","combat_accessory",2,["stride","mender"],true,"")],
            "travel_accessory":[_slot("travel_accessory_0","travel_accessory",0,["wayfinder"],true,"")],
            "thread_skill":[_slot("thread_skill_0","thread_skill",0,["cleave","needle"],true,"cleave"),_slot("thread_skill_1","thread_skill",1,["cleave"],true,"")]
        },
        "slot_families":{
            "tool":{"id":"tool","name":"战具","options":[_option("shard","碎片","tool"),_option("mine","线雷","tool")]},
            "combat_accessory":{"id":"combat_accessory","name":"战斗饰品","options":[_option("stride","疾行铭饰","combat_accessory",1),_option("mender","愈线铭饰","combat_accessory",2)]},
            "travel_accessory":{"id":"travel_accessory","name":"旅行饰品","options":[_option("wayfinder","引路铭饰","travel_accessory",1)]},
            "thread_skill":{"id":"thread_skill","name":"绯线技","options":[_option("cleave","裂斩","thread_skill"),_option("needle","丝针","thread_skill")]}
        }
    }
    var ui:=UI.new()
    ui.accessibility_path=SETTINGS_PATH
    runtime.add_child(ui)
    ui.bind(runtime)
    ui.set_process(false)
    var fixture_label:=Label.new()
    fixture_label.text="UI VALIDATION FIXTURE · MockRuntime"
    fixture_label.position=Vector2(870,12)
    fixture_label.size=Vector2(360,28)
    fixture_label.z_index=100
    fixture_label.add_theme_color_override("font_color",Color("ffd580"))
    ui.add_child(fixture_label)
    ui.build_panel.visible=true
    ui.refresh_build()
    _check(ui.build_tabs.size()==6,"Production build panel retains its six reachable top-level pages")
    _check(ui.build_summary.text.contains("战具 1/2") and ui.build_summary.text.contains("绯线技 1/2"),"Header reports active versus available typed slot counts")
    _check(ui.build_summary.text.contains("休眠 1"),"Header separates a stored dormant item from active equipment counts")
    ui.build_tabs[1].pressed.emit()
    _check(ui.build_slot_buttons.size()==2 and ui.build_slot_buttons[1].disabled==false,"Skill family exposes both unlocked typed slots")
    ui.build_slot_buttons[0].grab_focus()
    var nav_right:=InputEventJoypadButton.new()
    nav_right.device=-1
    nav_right.button_index=JOY_BUTTON_DPAD_RIGHT
    nav_right.pressed=true
    # Push the actual joypad event into the UI viewport. Input.parse_input_event
    # filters joypad events when no physical device is connected in the fixture.
    ui.get_viewport().push_input(nav_right)
    await process_frame
    _check(ui.get_viewport().gui_get_focus_owner()==ui.build_slot_buttons[1],"Injected controller d-pad input moves focus between typed equipment slots")
    ui.build_slot_buttons[1].pressed.emit()
    _check((ui.build_grid.get_child(1) as Button).disabled and String((ui.build_grid.get_child(1) as Button).text).contains("不兼容"),"Incompatible equipment is visibly rejected for the selected typed slot")
    ui.build_slot_buttons[0].pressed.emit()
    var skill_option:=ui.build_grid.get_child(1) as Button
    skill_option.pressed.emit()
    _check(runtime.last_action=="equip_family_slot" and runtime.last_id=="needle","Confirming a skill option invokes typed slot assignment")
    _check(runtime.last_extra is Dictionary and runtime.last_extra.get("family")=="thread_skill" and runtime.last_extra.get("slot")==0,"Typed skill action carries exact family and selected slot")
    ui.clear_family_slot_button.pressed.emit()
    _check(runtime.last_action=="equip_family_slot" and runtime.last_id.is_empty() and runtime.last_extra.get("family")=="thread_skill","Clear-slot control routes an explicit empty assignment through the runtime adapter")
    ui.build_tabs[3].pressed.emit()
    _check(ui.family_selector_buttons[0].visible and ui.family_selector_buttons[1].visible,"铭饰 page offers separate combat and travel accessory families")
    _check(ui.build_slot_buttons.size()==3,"Three-slot accessory family renders all typed slot controls")
    _check(ui.build_slot_buttons[0].tooltip_text.contains("疾行铭饰") and ui.build_slot_buttons[0].tooltip_text.contains("愈线铭饰"),"Compatibility tooltip uses localized equipment names instead of catalog IDs")
    var panel_bounds:=Rect2(Vector2.ZERO,ui.build_panel.size)
    var every_slot_fits:=true
    for slot_button in ui.build_slot_buttons:
        if not panel_bounds.encloses(slot_button.get_rect()):every_slot_fits=false
    _check(every_slot_fits,"Every accessory slot button remains inside the production build panel")
    ui.build_slot_buttons[2].grab_focus()
    _check(ui.get_viewport().gui_get_focus_owner()==ui.build_slot_buttons[2] and not ui.build_slot_buttons[2].disabled,"Unlocked third accessory slot remains reachable by keyboard and controller focus")
    var accessory_option:=ui.build_grid.get_child(0) as Button
    ui._show_build_detail(_option("mender","愈线铭饰","combat_accessory",2))
    _check(ui.build_detail.text.contains("容量比较") and ui.build_summary.text.contains("旅行饰品 0/1"),"Accessory preview compares cost and real typed-family counts")
    _check(accessory_option.disabled==false,"Compatible unlocked accessory can be selected")
    await process_frame
    # Dummy has no viewport texture; all layout/input assertions still run.
    if DisplayServer.get_name()!="headless":
        var fixture_image:=ui.get_viewport().get_texture().get_image()
        if fixture_image!=null:fixture_image.save_png(ProjectSettings.globalize_path("user://build_slots_ui_validation_fixture.png"))
    fixture_label.queue_free()
    ui.family_selector_buttons[1].pressed.emit()
    _check(ui.build_family=="travel_accessory" and ui.build_grid.get_child_count()==1,"Travel accessory selector shows only its own family options")
    ui.build_tabs[2].pressed.emit()
    _check(ui.build_slot_buttons.size()==2 and ui.build_slot_buttons[1].disabled,"Locked typed tool slot is visible and cannot receive equipment")
    _check(ui.build_slot_buttons[1].text.contains("休眠") and ui.build_slot_buttons[1].tooltip_text.contains("未激活：槽位未解锁"),"Stored equipment in a locked slot is explicitly labeled dormant")
    ui.build_slot_buttons[0].grab_focus()
    _check(ui.get_viewport().gui_get_focus_owner()==ui.build_slot_buttons[0] and ui.build_slot_buttons[0].focus_mode==Control.FOCUS_ALL,"Typed slot selector participates in keyboard/controller focus navigation")
    ui._refresh_tactical_cards(ui._build_snapshot(),runtime.build_system.state,runtime.build_system)
    _check(ui.tactical_names[3].text=="休眠 · 线雷" and ui.tactical_values[3].text=="槽位未解锁","HUD does not present a locked dormant tool as ready")
    ui.resupply_preview_button.pressed.emit()
    _check(runtime.last_action=="quote_resupply" and runtime.currency_count==120,"Paid supply preview reads a quote without spending currency")
    _check(ui.build_heading.text=="战具补给报价" and ui.build_detail.text.contains("碎钱：12") and ui.build_detail.text.contains("碎片 +1") and ui.build_detail.text.contains("线雷 +1") and not ui.resupply_confirm_button.disabled,"Partial refill preview uses localized tool names and shows gains plus exact cost before confirmation")
    ui.resupply_confirm_button.pressed.emit()
    _check(runtime.last_action=="resupply_tools","Paid resupply requires the separate confirmation signal")
    runtime.build_system.snapshot.at_workstation=false
    ui.refresh_build()
    var all_tabs_hidden:=true
    for tab in ui.build_tabs:
        if tab.visible:all_tabs_hidden=false
    _check(all_tabs_hidden,"Road view hides full loadout editing pages")
    _check(ui.build_grid.get_child_count()==2,"Road view exposes only preconfigured skill and tool quick-cycle controls")
    (ui.build_grid.get_child(0) as Button).pressed.emit()
    _check(runtime.last_action=="cycle_skill","Road quick-cycle invokes the live skill cycle action")
    runtime.world_mode=true
    runtime.world_narrative=MockNarrative.new()
    ui.bag_category="旅记"
    ui.refresh_inventory()
    var early_ending_visible:=false
    for record in ui.bag_grid.get_children():
        if String((record as Button).text).contains("结局"):early_ending_visible=true
    _check(not early_ending_visible,"Journal hides ending choices until the player encounters them")
    runtime.world_narrative.encountered_choice=true
    ui.refresh_inventory()
    var ending_button: Button=ui.bag_grid.get_child(ui.bag_grid.get_child_count()-1) as Button
    ending_button.pressed.emit()
    _check(ui.bag_name.text=="续线结局" and ui.bag_description.text.contains("检查钟龛旁的石刻。"),"Encountered ending readiness shows only known clue guidance")
    _check(not ui.bag_description.text.contains("绝密位置") and not ui.bag_description.text.contains("不可见证词"),"Journal never renders hidden missing proof details")
    runtime.build_system.state["passives"]=[]
    var saved_plan:=runtime.build_system.state.duplicate(true)
    runtime.build_system.state["loadouts"]={"巡礼方案 2":saved_plan}
    runtime.build_system.snapshot.loadouts=["巡礼方案 2"]
    runtime.build_system.snapshot.at_workstation=true
    runtime.build_system.previews["巡礼方案 2"]={"can_restore":true,"reason":"","profile":{"max_hp":6,"max_energy":120}}
    ui.build_category="构筑"
    ui.build_selection=""
    ui.refresh_build()
    var restore_empty: Button=ui.build_grid.get_child(0)
    var save_first: Button=ui.build_grid.get_child(1)
    var restore_second: Button=ui.build_grid.get_child(2)
    var save_second: Button=ui.build_grid.get_child(3)
    _check(restore_empty.disabled and restore_empty.tooltip_text.contains("尚未保存"),"Empty plan cannot be restored and explains why")
    _check(not restore_second.disabled,"Compatible plan keeps its restore action available")
    save_second.grab_focus()
    await process_frame
    _check(ui.build_selection=="巡礼方案 2" and ui.build_heading.text=="巡礼方案 2","Controller focus on a save row previews that same plan")
    _check(ui.build_detail.text.contains("可以恢复") and ui.build_detail.text.contains("生命上限：8 → 6") and ui.build_detail.text.contains("绯线上限：100 → 120"),"Plan detail shows actual restore conditions and capacity changes")
    _check(ui.build_detail.text.contains("陷阱触发宽高：100% → 100%"), "Plan detail exposes trap trigger percentage")
    save_first.grab_focus()
    await process_frame
    _check(ui.build_detail.text.contains("方案尚未保存") and ui.build_detail.text.contains("不清空冷却"),"Empty plan focus explains resource preservation and permits saving")
    save_second.pressed.emit()
    _check(ui.loadout_dialog.visible and runtime.last_action!="save_loadout","Overwriting a saved plan requires an explicit confirmation")
    _check(ui.loadout_dialog.gui_get_focus_owner()==ui.loadout_dialog.get_cancel_button(),"Overwrite dialog defaults to keeping the old plan")
    ui.loadout_dialog.get_cancel_button().pressed.emit()
    _check(ui.pending_loadout_action.is_empty(),"Cancelling overwrite clears the pending operation")
    save_second.pressed.emit()
    ui.loadout_dialog.confirmed.emit()
    ui.loadout_dialog.hide()
    _check(runtime.last_action=="save_loadout" and runtime.last_id=="巡礼方案 2","Save row dispatch keeps the focused plan identity")
    _check(ui._loadout_names(runtime.build_system.snapshot).size()==8 and ui._loadout_names(runtime.build_system.snapshot).has("巡礼方案 8"),"All eight backend slots are reachable from the UI")
    runtime.build_system.snapshot.loadouts=["旧旅途自定义名称"]
    var names:=ui._loadout_names(runtime.build_system.snapshot)
    _check(names.size()==8 and names.has("旧旅途自定义名称"),"Custom names from old saves remain visible without exceeding eight rows")
    runtime.build_system.snapshot.loadouts=["巡礼方案 2"]
    ui._request_loadout_change("delete_loadout","巡礼方案 2")
    _check(ui.loadout_dialog.dialog_text.contains("当前装备") and ui.pending_loadout_action=="delete_loadout","Deletion explains that current equipment is retained")
    runtime.build_system.snapshot.at_workstation=false
    var previous_calls:=runtime.action_calls.size()
    ui._confirm_loadout_change()
    _check(runtime.action_calls.size()==previous_calls,"Leaving the shrine before confirming cannot delete a plan")
    ui.loadout_dialog.hide()
    ui.bag.show()
    ui.bag_category="旅记"
    var long_a:={"record_kind":"quest","id":"reading_a","title":"长记录甲","description":"长段落：针线记录旅途。\n".repeat(80),"steps":[]}
    var long_b:={"record_kind":"quest","id":"reading_b","title":"长记录乙","description":"另一份长记录。\n".repeat(80),"steps":[]}
    ui._show_journal_record(long_a)
    await process_frame
    await process_frame
    var reading_bar: VScrollBar=ui.bag_description.get_v_scroll_bar()
    reading_bar.value=150
    var saved_offset:=reading_bar.value
    ui._show_journal_record(long_b)
    await process_frame
    await process_frame
    ui._show_journal_record(long_a)
    ui._show_journal_record(long_a) # repeated focus before deferred layout
    await process_frame
    await process_frame
    _check(saved_offset>0 and is_equal_approx(reading_bar.value,saved_offset),"Returning to a long journal entry restores its own reading position across repeated focus")
    var page:=InputEventKey.new()
    page.physical_keycode=KEY_PAGEDOWN
    page.pressed=true
    ui._input(page)
    _check(reading_bar.value>saved_offset,"PageDown scrolls journal details without changing the selected record")
    var shoulder:=InputEventJoypadButton.new()
    shoulder.button_index=JOY_BUTTON_LEFT_SHOULDER
    shoulder.pressed=true
    ui._input(shoulder)
    _check(is_equal_approx(reading_bar.value,saved_offset),"Controller LB reverses one journal page")
    page.physical_keycode=KEY_HOME
    ui._input(page)
    _check(reading_bar.value==0,"Home reaches the start of a long journal record")
    page.physical_keycode=KEY_END
    ui._input(page)
    _check(reading_bar.value>saved_offset and is_equal_approx(reading_bar.value,reading_bar.max_value-reading_bar.page),"End reaches the final journal page")
    reading_bar.value=saved_offset
    ui.bag.hide()
    ui.bag.show()
    ui._show_journal_record(long_a)
    await process_frame
    await process_frame
    _check(is_equal_approx(reading_bar.value,saved_offset),"Closing and reopening the bag retains a journal bookmark")
    long_a.description+="新线索。"
    ui._show_journal_record(long_a)
    await process_frame
    await process_frame
    _check(reading_bar.value==0,"Changed quest content starts at the top instead of reusing an obsolete offset")
    _check(ui.bag_pin.disabled and ui.bag_pin.text.contains("LB/RB") and ui.bag_pin.tooltip_text.contains("Home"),"Journal reuses its inactive pin footer for reading shortcuts without adding overlapping controls")
    var bounded:=preload("res://scripts/journal_reading.gd").new()
    for index in 80:bounded.capture(str(index),"text",float(index))
    _check(bounded.bookmarks.size()==64 and bounded.resume("0","text")==0 and bounded.resume("79","text")==79,"Session bookmarks evict old entries at a fixed memory bound")
    bounded.capture("bad","text",NAN)
    _check(not bounded.bookmarks.has("bad"),"Non-finite offsets cannot enter reading state")
    runtime.build_system.snapshot.at_workstation=true
    ui.build_panel.show()
    ui._open_resupply_planner()
    _check(ui.resupply_planner.visible and ui.resupply_planner.rows.size()==2,"Production build entry opens owned-tool shopping planner")
    var planner_calls:=runtime.action_calls.size()
    ui.build_panel.hide()
    _check(not ui.resupply_planner.visible and runtime.action_calls.size()==planner_calls,"Closing build overlay cancels shopping without a transaction")
    runtime.free()
    DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
    await process_frame
    for failure in failures:push_error(failure)
    print("BUILD_SLOTS_UI_VALIDATION fixture=MockRuntime production=pilgrimage_interface checks=%d failures=%d capture=user://build_slots_ui_validation_fixture.png" % [checks,failures.size()])
    quit(0 if failures.is_empty() else 1)
