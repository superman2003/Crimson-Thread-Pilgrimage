extends SceneTree
## Exercises the actual settings/remap adapter without world or combat fixtures.
const UI = preload("res://scripts/pilgrimage_interface.gd")
const PATH := "user://input_settings_regression.cfg"
class FixtureLevel extends Node:
    var map_panel: Control
    var active_overlay := ""
var failures: Array[String] = []
var checks := 0
var original_events: Dictionary = {}

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:failures.append(label)

func _key(code: Key) -> InputEventKey:
    var event := InputEventKey.new()
    event.physical_keycode = code
    event.keycode = code
    event.pressed = true
    return event

func _run() -> void:
    for action in UI.REMAPPABLE_ACTIONS:
        original_events[action] = InputMap.action_get_events(action) if InputMap.has_action(action) else null
        if not InputMap.has_action(action):InputMap.add_action(action)
        InputMap.action_erase_events(action)
    InputMap.action_add_event("heal", _key(KEY_H))
    var ui := UI.new()
    ui.accessibility_path = PATH
    root.add_child(ui)
    ui.set_process(false)
    ui.level = FixtureLevel.new()
    root.add_child(ui.level)
    ui.settings = ColorRect.new()
    ui.add_child(ui.settings)
    var setting_control:=Button.new()
    setting_control.focus_mode=Control.FOCUS_ALL
    ui.settings.add_child(setting_control)
    ui.remap_status = Label.new()
    ui.add_child(ui.remap_status)
    ui.bag = ColorRect.new()
    ui.add_child(ui.bag)
    ui.bag.hide()
    ui.settings.show()
    ui.bag_tabs=[Button.new(),Button.new()]
    for button in ui.bag_tabs:
        button.focus_mode=Control.FOCUS_ALL
        ui.bag.add_child(button)
    ui.build_panel=ColorRect.new()
    ui.add_child(ui.build_panel)
    ui.build_panel.hide()
    ui.dialogue=ColorRect.new()
    ui.add_child(ui.dialogue)
    ui.dialogue.hide()
    ui.level.map_panel=ColorRect.new()
    ui.level.add_child(ui.level.map_panel)
    var map_first:=Button.new()
    map_first.focus_mode=Control.FOCUS_ALL
    ui.level.map_panel.add_child(map_first)
    var map_second:=Button.new()
    map_second.focus_mode=Control.FOCUS_ALL
    ui.level.map_panel.add_child(map_second)
    # This adapter fixture supplies its controls directly, so finish staging.
    ui.construction_complete = true
    ui.finish_bind()
    ui.set_process(false)
    var config := ConfigFile.new()
    config.set_value("accessibility", "subtitle_size", {"broken":true})
    config.set_value("accessibility", "subtitle_speed", "fast")
    config.set_value("accessibility", "camera_shake", -5.0)
    config.set_value("accessibility", "camera_lookahead", 9.0)
    config.set_value("accessibility", "flash_enabled", "false")
    config.set_value("accessibility", "vibration_enabled", false)
    config.set_value("bindings", "heal", [null,"bad",InputEventMouseMotion.new(),InputEventKey.new()])
    _check(config.save(PATH)==OK,"Corrupt preference fixture is writable")
    ui._load_accessibility()
    _check(ui.accessibility.subtitle_size==21,"Invalid subtitle size preserves a usable default")
    _check(ui.accessibility.subtitle_speed==1.0,"Invalid subtitle speed preserves default")
    _check(ui.accessibility.camera_shake==0.0 and ui.accessibility.camera_lookahead==1.0,"Finite numeric preferences are clamped")
    _check(ui.accessibility.flash_enabled==true and ui.accessibility.vibration_enabled==false,"Only real booleans replace toggles")
    _check(InputMap.event_is_action(_key(KEY_H),"heal"),"All-invalid bindings do not erase working controls")
    config.set_value("accessibility","subtitle_speed",NAN)
    _check(ui._finite_setting(config,"subtitle_speed",0.5,2.0)==1.0,"NaN preference does not reach a UI slider")
    config.set_value("accessibility","subtitle_speed",INF)
    _check(ui._finite_setting(config,"subtitle_speed",0.5,2.0)==1.0,"Infinite preference does not reach a UI slider")
    # Focus is tested against real viewport controls and the viewport signal.
    ui.level.active_overlay="map"
    ui._focus_overlay("map",false)
    _check(root.get_viewport().gui_get_focus_owner()==map_first,"Opening map focuses its first navigable control")
    map_second.grab_focus()
    await process_frame
    _check(ui.overlay_focus_memory.has("map") and ui.overlay_focus_memory.map.get_ref()==map_second,"Viewport focus signal remembers a valid map control")
    map_second.free()
    await process_frame
    ui._focus_overlay("map",true)
    _check(root.get_viewport().gui_get_focus_owner()==map_first,"Released remembered controls fall back to the first live control")
    var click_only:=Button.new()
    click_only.focus_mode=Control.FOCUS_CLICK
    ui.level.map_panel.add_child(click_only)
    ui.overlay_focus_memory["map"]=weakref(click_only)
    ui._focus_overlay("map",true)
    _check(root.get_viewport().gui_get_focus_owner()==map_first,"FOCUS_CLICK controls are excluded from keyboard/controller navigation")
    click_only.free()
    await process_frame
    ui.level.active_overlay="settings"
    ui._focus_overlay("settings",false)
    _check(ui._is_navigable_focus(root.get_viewport().gui_get_focus_owner()),"Settings opens with a navigable focus owner")
    ui._begin_remap("heal")
    Input.emit_signal("joy_connection_changed",7,false)
    _check(ui.remap_target.is_empty(),"Disconnecting a controller cancels pending remapping")
    _check(ui.is_remapping_input(),"Disconnect cancellation protects only the current input frame")
    await process_frame
    _check(not ui.is_remapping_input(),"Disconnect input protection expires after one frame")
    Input.emit_signal("joy_connection_changed",7,true)
    root.get_viewport().gui_release_focus()
    await process_frame
    Input.emit_signal("joy_connection_changed",7,true)
    await process_frame
    _check(ui._is_navigable_focus(root.get_viewport().gui_get_focus_owner()),"Controller reconnect restores focus to an active overlay")
    ui._begin_remap("heal")
    _check(ui.is_remapping_input(),"Beginning capture blocks level polling")
    var escape := _key(KEY_ESCAPE)
    escape.keycode = 0
    ui._input(escape)
    _check(ui.remap_target.is_empty(),"Physical Escape cancels capture")
    _check(ui.is_remapping_input(),"Cancellation frame remains blocked from closing settings")
    await process_frame
    await process_frame
    await process_frame
    _check(not ui.is_remapping_input(),"Polling resumes after the captured frame")
    ui._begin_remap("heal")
    ui._input(_key(KEY_F9))
    _check(ui.remap_target=="heal" and not InputMap.event_is_action(_key(KEY_F9),"heal"),"New-journey shortcut remains reserved during capture")
    ui._input(_key(KEY_P))
    _check(ui.remap_target.is_empty() and InputMap.event_is_action(_key(KEY_P),"heal"),"Fresh key replaces previous keyboard mapping")
    _check(not InputMap.event_is_action(_key(KEY_H),"heal"),"Previous keyboard binding is removed")
    _check(ui.is_remapping_input(),"Successful capture cannot trigger other polled actions")
    ui._begin_remap("jump")
    ui._input(_key(KEY_P))
    _check(ui.remap_target=="jump","Conflicting gameplay binding is rejected")
    ui._input(_key(KEY_ESCAPE))
    ui._begin_remap("heal")
    var joy := InputEventJoypadButton.new()
    joy.button_index = JOY_BUTTON_RIGHT_SHOULDER
    joy.device = 2
    joy.pressed = true
    ui._input(joy)
    joy.device = 7
    _check(InputMap.event_is_action(joy,"heal"),"Controller binding survives a changed device index")
    _check(InputMap.event_is_action(_key(KEY_P),"heal"),"Controller remap preserves keyboard binding")
    var restored := UI.new()
    restored.accessibility_path = PATH
    InputMap.action_erase_events("heal")
    restored._load_accessibility()
    _check(InputMap.event_is_action(joy,"heal") and InputMap.event_is_action(_key(KEY_P),"heal"),"Normalized controller and keyboard bindings persist together")
    restored.free()
    var motion := InputEventJoypadMotion.new()
    motion.axis = JOY_AXIS_TRIGGER_RIGHT
    motion.axis_value = 0.8
    motion.device = 3
    var normalized: InputEvent = ui._normalized_binding(motion)
    _check(normalized.device==-1 and normalized.axis_value==1.0,"Axis binding is device independent and normalized")
    motion.axis_value = NAN
    _check(ui._normalized_binding(motion)==null,"Non-finite controller axis is rejected")
    ui.settings.hide()
    _check(not ui.is_remapping_input(),"Hidden settings never hold the input capture gate")
    for action in original_events:
        if original_events[action]==null:
            InputMap.erase_action(action)
        else:
            InputMap.action_erase_events(action)
            for event in original_events[action]:InputMap.action_add_event(action,event)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
    ui.level.free()
    ui.free()
    await process_frame
    for failure in failures:push_error(failure)
    print("INPUT_SETTINGS_REGRESSION checks=%d failures=%d" % [checks,failures.size()])
    quit(0 if failures.is_empty() else 1)
