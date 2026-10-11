extends SceneTree

const UI = preload("res://scripts/pilgrimage_interface.gd")
const BUILD = preload("res://scripts/build_system.gd")
var failures := 0

class MockPlayer extends Node:
    var hp := 3
    var max_hp := 7
    var max_energy := 100
    var energy := 70
    var skill_cooldown := 1.3
    func get_seal_mechanism_snapshot() -> Dictionary:
        return {"label":"线势","stacks":2,"max_stacks":3}
    func get_combat_ui_state() -> Dictionary:
        return {"heal_active":true,"heal_progress":0.5,"skill_name":"测试技能","skill_cooldown":1.3,"skill_cost":20}

class MockRuntime extends Node:
    const AUDIO_SETTINGS_ROWS := [["master","总音量"],["music","音乐"],["sfx","音效"],["ambience","环境"]]
    var audio_director: Node
    var player: Node
    var build_system: RefCounted
    var active_overlay := "build"
    var currency_count := 500
    var inventory_counts := {"moss_chitin":5}
    var story_flags := {}
    var settings_selection := 0
    var current_room_id := "test"
    var config := {}
    var boss_actor: Node
    var demo_complete := false
    var last_action := ""
    var last_id := ""
    var last_slot := -1
    var selected_save_slot := 0
    func get_build_system() -> RefCounted:return build_system
    func perform_build_action(action: String,id: String,_slot: int) -> Dictionary:
        last_action=action
        last_id=id
        last_slot=_slot
        if action=="select_skill":return build_system.select_skill(id,_slot)
        if action=="select_tool":return build_system.select_tool(id,_slot)
        return {"ok":true,"reason":"已执行测试事务"}
    func _toggle_build() -> void:active_overlay="build" if active_overlay=="" else ""
    func _close_overlays() -> void:active_overlay=""
    func _toggle_backpack() -> void:pass
    func _toggle_map() -> void:pass
    func _toggle_audio_settings() -> void:pass
    func _settings_selection_clamped() -> int:return settings_selection
    func _map_room_by_id(_id: String) -> Dictionary:return {"name":"验证房间"}
    func _nearest_interactable(_range: int) -> Area2D:return null
    func _item_display_name(id: String) -> String:return id
    func select_save_slot(slot: int) -> bool:selected_save_slot=slot;return true
    func restore_save_backup() -> bool:return true

func _initialize() -> void:call_deferred("run")

func check(condition: bool, message: String) -> void:
    if not condition:
        failures+=1
        push_error(message)

func run() -> void:
    var runtime:=MockRuntime.new()
    root.add_child(runtime)
    runtime.player=MockPlayer.new()
    runtime.add_child(runtime.player)
    runtime.build_system=BUILD.new()
    runtime.build_system.cooldowns["cleave"]=1.3
    var ui:=UI.new()
    ui.accessibility_path="user://ui_build_accessibility_validation.cfg"
    runtime.add_child(ui)
    ui.bind(runtime)
    ui.set_process(false)
    ui.build_panel.visible=true
    ui.refresh_build()
    check(ui.build_tabs.size()==6,"All six build categories have visible runtime pages")
    check(ui.build_grid.get_child_count()==3,"Three crests appear from real build snapshot")
    (ui.build_grid.get_child(0) as Button).pressed.emit()
    check(runtime.last_action=="switch_crest","Crest confirm invokes real runtime action adapter")
    ui.build_category="技能"
    ui.refresh_build()
    check(ui.build_detail.text.contains("消耗绯线") and ui.build_detail.text.contains("冷却"),"Skill preview shows actual resource cost and cooldown")
    (ui.build_grid.get_child(0) as Button).pressed.emit()
    check(runtime.last_action=="select_skill","Skill confirm routes to runtime selection")
    ui.build_category="强化"
    ui.refresh_build()
    (ui.build_grid.get_child(0) as Button).pressed.emit()
    check(runtime.last_action=="transact","Craft button invokes runtime transaction adapter")
    ui.build_category="构筑"
    ui.refresh_build()
    (ui.build_grid.get_child(1) as Button).pressed.emit()
    check(runtime.last_action=="save_loadout" and runtime.last_id=="巡礼方案 1","Visible save button names and saves a build")
    runtime.active_overlay=""
    ui._process(0.1)
    check(ui.health_glyphs.maximum-ui.health_glyphs.hp==4 and ui.hearts.text=="3 / 7","Needle health glyphs and numeric readout follow actual max HP")
    check(ui.healing_bar.visible and is_equal_approx(ui.healing_bar.value,0.5),"HUD renders real healing channel progress")
    check(ui.combat_status.text.contains("1.3s"),"HUD displays current skill cooldown")
    ui.accessibility["subtitle_size"]=26
    ui.accessibility["flash_enabled"]=false
    ui._save_accessibility()
    ui._apply_accessibility()
    check(ui.dialogue_body.get_theme_font_size("font_size")==26,"Subtitle font setting affects actual dialogue label")
    check(not bool(runtime.player.get_meta("accessibility").flash_enabled),"Accessibility settings reach player runtime")
    var restored:=UI.new()
    restored.accessibility_path=ui.accessibility_path
    restored._load_accessibility()
    check(int(restored.accessibility.subtitle_size)==26 and not bool(restored.accessibility.flash_enabled),"Accessibility preferences persist through ConfigFile reload")
    restored.free()
    ui.settings.visible=true
    ui._begin_remap("heal")
    var old_events:=InputMap.action_get_events("heal")
    var event:=InputEventKey.new()
    event.physical_keycode=KEY_P
    event.keycode=KEY_P
    event.pressed=true
    ui._input(event)
    check(ui.remap_target.is_empty() and InputMap.event_is_action(event,"heal"),"Key capture changes actual gameplay InputMap")
    InputMap.action_erase_events("heal")
    var restored_bindings:=UI.new()
    restored_bindings.accessibility_path=ui.accessibility_path
    restored_bindings._load_accessibility()
    check(InputMap.event_is_action(event,"heal"),"Rebound gameplay key persists through configuration reload")
    restored_bindings.free()
    ui._begin_remap("jump")
    ui._input(event)
    check(ui.remap_target=="jump","Mapping a key used by another action is rejected")
    var escape:=InputEventKey.new()
    escape.keycode=KEY_ESCAPE
    escape.pressed=true
    ui._input(escape)
    check(ui.remap_target.is_empty(),"Escape safely cancels an incomplete key remapping")
    ui._select_save_slot(2)
    check(runtime.selected_save_slot==2,"Save slot button adapter selects requested slot")
    InputMap.action_erase_events("heal")
    for old_event in old_events:InputMap.action_add_event("heal",old_event)
    runtime.free()
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ui_build_accessibility_validation.cfg"))
    await process_frame
    print("UI_BUILD_ACCESSIBILITY_VALIDATION_%s failures=%d" % ["PASS" if failures==0 else "FAIL",failures])
    quit(1 if failures else 0)
