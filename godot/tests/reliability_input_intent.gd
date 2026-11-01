extends SceneTree
const PROMPTS = preload("res://scripts/input_prompt_bindings.gd")
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:failures.append(label)
func axis(id: int, value: float, device: int = 2) -> InputEventJoypadMotion:
    var e := InputEventJoypadMotion.new();e.axis = id;e.axis_value = value;e.device = device;return e
func button(id: int, device: int = 2) -> InputEventJoypadButton:
    var e := InputEventJoypadButton.new();e.button_index = id;e.device = device;e.pressed = true;return e
func _initialize() -> void:
    PROMPTS.controller_device = -1
    PROMPTS.observe(null)
    for e in [axis(-1, 1), axis(JOY_AXIS_MAX, 1), axis(0, NAN), axis(0, INF), axis(0, 4), axis(0, 1, -1), button(-1), button(JOY_BUTTON_MAX), button(0, -1)]:
        PROMPTS.observe(e)
        check(PROMPTS.controller_device == -1, "malformed device event does not switch prompt family")
    for id in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
        PROMPTS.observe(axis(id, -1))
        check(PROMPTS.controller_device == -1 and PROMPTS.binding_label(axis(id, -1)).is_empty(), "resting trigger is neither intent nor a valid advertised binding")
    PROMPTS.observe(axis(JOY_AXIS_LEFT_X, 0.3))
    check(PROMPTS.controller_device == -1, "stick jitter does not switch prompts")
    PROMPTS.observe(axis(JOY_AXIS_LEFT_X, -0.8))
    check(PROMPTS.controller_device == 2, "deliberate negative stick movement selects its device")
    var bad_mouse := InputEventMouseButton.new();bad_mouse.pressed = true;bad_mouse.button_index = 0
    PROMPTS.observe(bad_mouse);check(PROMPTS.controller_device == 2, "invalid mouse button cannot erase controller intent")
    var key := InputEventKey.new();key.keycode = KEY_F;key.pressed = true;key.echo = true
    PROMPTS.observe(key);check(PROMPTS.controller_device == 2, "OS key repeat cannot steal controller prompts")
    key.echo = false;PROMPTS.observe(key)
    check(PROMPTS.controller_device == -1, "real key press switches back to keyboard")
    var action := "reliability_prompt_fixture"
    InputMap.add_action(action)
    var generic := button(JOY_BUTTON_A, -1)
    var specific := button(JOY_BUTTON_B, 2)
    InputMap.action_add_event(action, generic);InputMap.action_add_event(action, specific);InputMap.action_add_event(action, key)
    PROMPTS.observe(button(JOY_BUTTON_A, 2))
    check(PROMPTS.action_label(action) == "手柄 B", "active device's explicit binding takes priority over generic binding")
    PROMPTS.observe(button(JOY_BUTTON_A, 3))
    check(PROMPTS.action_label(action) == "手柄 A", "another controller uses generic fallback")
    PROMPTS.disconnected(2);check(PROMPTS.controller_device == 3, "unrelated disconnect preserves active family")
    PROMPTS.disconnected(3);check(PROMPTS.controller_device == -1 and PROMPTS.action_label(action) == "F", "active disconnect restores keyboard fallback")
    InputMap.erase_action(action)
    check(PROMPTS.action_label(action) == "未设置", "missing action is explained")
    for failure in failures:push_error(failure)
    print("RELIABILITY_INPUT_INTENT checks=%d failures=%d" % [checks, failures.size()])
    quit(0 if failures.is_empty() else 1)
