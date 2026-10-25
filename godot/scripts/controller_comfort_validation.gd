extends SceneTree
const POLICY = preload("res://scripts/controller_preferences.gd")
const DIALOG = preload("res://scripts/controller_comfort_dialog.gd")
var checks := 0
var failures: Array[String] = []
var applications := 0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:failures.append(label)
func axis(id: int) -> InputEventJoypadMotion:
    var event := InputEventJoypadMotion.new();event.axis = id;event.axis_value = 1.0;return event

func run() -> void:
    var original := {}
    for action in InputMap.get_actions():original[String(action)] = InputMap.action_get_deadzone(action)
    for id in ["cal_stick","cal_trigger","cal_mixed","cal_key"]:InputMap.add_action(id,0.37)
    InputMap.action_add_event("cal_stick",axis(JOY_AXIS_LEFT_X))
    InputMap.action_add_event("cal_trigger",axis(JOY_AXIS_TRIGGER_LEFT))
    InputMap.action_add_event("cal_mixed",axis(JOY_AXIS_RIGHT_X));InputMap.action_add_event("cal_mixed",axis(JOY_AXIS_TRIGGER_RIGHT))
    var key := InputEventKey.new();key.physical_keycode = KEY_A;InputMap.action_add_event("cal_key",key)
    InputMap.add_action("ui_cal_menu",0.5)
    InputMap.action_add_event("ui_cal_menu",axis(JOY_AXIS_LEFT_Y))
    POLICY.apply_deadzone(0.52)
    check(is_equal_approx(InputMap.action_get_deadzone("ui_cal_menu"),0.5), "built-in ui_* menu navigation keeps its own stick threshold")
    check(is_equal_approx(InputMap.action_get_deadzone("cal_stick"),0.52), "custom deadzone applies to actual stick action")
    for id in ["cal_trigger","cal_mixed","cal_key"]:check(is_equal_approx(InputMap.action_get_deadzone(id),0.37), "trigger mixed and keyboard actions preserve their thresholds: " + id)
    InputMap.action_erase_events("cal_stick");InputMap.action_add_event("cal_stick",key)
    POLICY.apply_deadzone(0.4)
    check(is_equal_approx(InputMap.action_get_deadzone("cal_stick"),0.37), "remapping away from a stick restores its original threshold")
    InputMap.action_add_event("cal_stick",axis(JOY_AXIS_LEFT_Y));POLICY.apply_deadzone(NAN)
    check(is_equal_approx(InputMap.action_get_deadzone("cal_stick"),0.2), "non-finite threshold falls back to the playable default")
    POLICY.apply_deadzone(9.0)
    check(is_equal_approx(InputMap.action_get_deadzone("cal_stick"),0.6), "threshold is bounded below an impossible full-travel value")
    var normalized: Dictionary = POLICY.normalize({"controller_deadzone":true,"subtitle_size":NAN,"subtitle_speed":INF,"flash_enabled":"false","vibration_strength":-9})
    check(is_equal_approx(normalized.controller_deadzone, 0.2) and normalized.subtitle_size == 21 and normalized.subtitle_speed == 1.0 and normalized.flash_enabled and normalized.vibration_strength == 0.0, "malformed settings cannot reach sliders or device actions")
    var custom := POLICY.normalize({"controller_deadzone":0.5,"subtitle_size":24,"subtitle_speed":1.5,"flash_enabled":false,"vibration_strength":0.5})
    var reset: Dictionary = POLICY.preset(custom,"controller_default")
    check(is_equal_approx(reset.controller_deadzone, 0.2) and reset.subtitle_size == 24 and reset.subtitle_speed == 1.5 and not reset.flash_enabled, "controller-only reset preserves reading and visual choices")
    reset = POLICY.preset(custom,"visual_default")
    check(reset.subtitle_size == 21 and reset.controller_deadzone == 0.5 and reset.vibration_strength == 0.5, "visual-only reset preserves calibrated controller values")
    check(POLICY.preset(custom,"reading").subtitle_size == 26 and POLICY.preset(custom,"comfort").camera_shake == 0.25, "comfort and reading presets carry distinct prospective choices")
    var dialog := DIALOG.new();root.add_child(dialog)
    dialog.open(custom,func(_values: Dictionary):applications += 1;return {"ok":true})
    check(dialog.get_cancel_button().has_focus() and dialog.get_ok_button().disabled, "preset dialog starts with a safe unchanged state")
    dialog.deadzone.value = 0.42
    dialog.choose_preset("reading")
    check(applications == 0 and custom.subtitle_size == 24 and dialog.changes.text.contains("字幕字号"), "changing calibration and choosing a preset only stages labeled changes")
    dialog.hide()
    check(applications == 0, "canceling the window applies nothing")
    dialog.open(custom,func(_values: Dictionary):applications += 1;return {"ok":true})
    dialog.choose_preset("comfort");dialog._apply_candidate()
    check(applications == 1 and not dialog.visible, "only explicit confirmation applies the candidate once")
    check(not dialog.device_status.text.is_empty(), "controller diagnostics explain either actual readings or absent hardware")
    dialog.free()

    var main: Node = load("res://scenes/World.tscn").instantiate()
    main.world_resume = false;main.world_save_path = "user://controller_comfort_world.json"
    root.add_child(main)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(main)
    main.set_process(false);main.player.set_physics_process(false)
    var ui: Control = main.ui_shell
    if not ui.accessibility.has("controller_deadzone") or is_equal_approx(float(ui.accessibility.controller_deadzone), POLICY.DEFAULTS.controller_deadzone):
        check(is_equal_approx(InputMap.action_get_deadzone("move_left"),0.2) and is_equal_approx(InputMap.action_get_deadzone("ui_left"),0.5), "loading default settings keeps the gameplay stick at 0.2 and menu navigation at 0.5")
    ui.accessibility_path = "user://controller_comfort_settings.cfg"
    main._toggle_audio_settings();ui._open_controller_comfort()
    var before: Dictionary = ui.accessibility.duplicate(true)
    var binding_before: Array = InputMap.action_get_events("jump")
    ui.controller_comfort_dialog.choose_preset("reading")
    check(ui.accessibility == before, "production settings remain unchanged while the dialog previews")
    ui.controller_comfort_dialog.deadzone.value = 0.43
    ui.controller_comfort_dialog._apply_candidate()
    check(ui.accessibility.subtitle_size == 26 and is_equal_approx(ui.accessibility.controller_deadzone,0.43), "production confirm commits both reading and controller choices")
    check(is_equal_approx(InputMap.action_get_deadzone("move_left"),0.43) and InputMap.action_get_events("jump") == binding_before, "actual runtime mapping consumes the new threshold without rewriting bindings")
    check(ui.accessibility_controls.subtitle_size.slider.value == 26 and not ui.accessibility_toggles.flash_enabled.button_pressed, "main settings sliders labels and toggles synchronize with a preset")
    check(ui.accessibility.navigation_assist == before.navigation_assist and ui.accessibility.tutorial_hints == before.tutorial_hints, "presets do not silently change navigation or exploration assistance")
    var config := ConfigFile.new()
    check(config.load(ui.accessibility_path) == OK and is_equal_approx(config.get_value("accessibility","controller_deadzone"),0.43), "calibration is actually persisted with existing preferences")
    ui.accessibility.controller_deadzone = 0.2;ui._load_accessibility();ui._apply_accessibility()
    check(is_equal_approx(ui.accessibility.controller_deadzone,0.43) and is_equal_approx(InputMap.action_get_deadzone("move_left"),0.43), "preference reload re-applies controller calibration")
    ui._open_controller_comfort();ui.controller_comfort_dialog.choose_preset("comfort")
    var confirmed: Dictionary = ui.accessibility.duplicate(true)
    ui.settings.hide()
    check(not ui.controller_comfort_dialog.visible and ui.accessibility == confirmed, "leaving settings cancels staged preferences")
    var retirement := preload("res://scripts/audio_retirement.gd")
    retirement.retire_tree(main);main.free();await process_frame
    preload("res://scripts/audio_director.gd")._stream_cache.clear();preload("res://scripts/audio_director.gd")._npc_voice_cache.clear()
    check(await retirement.drain(self), "fixture retires its actual World audio ownership")
    for id in ["cal_stick","cal_trigger","cal_mixed","cal_key","ui_cal_menu"]:InputMap.erase_action(id)
    for action in original:
        if InputMap.has_action(action):InputMap.action_set_deadzone(action,original[action])
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://controller_comfort_settings.cfg"))
    if failures.is_empty():print("CONTROLLER_COMFORT checks=%d failures=0" % checks)
    else:
        for item in failures:push_error(item)
    quit(0 if failures.is_empty() else 1)
