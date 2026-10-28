extends SceneTree
const PROMPT=preload("res://scripts/input_prompt_bindings.gd")
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures+=1;print("FAIL ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
    var mouse:=InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_RIGHT
    check(PROMPT.binding_label(mouse)=="鼠标右键","plain mouse label unchanged")
    mouse.ctrl_pressed=true;mouse.alt_pressed=true;mouse.shift_pressed=true;mouse.meta_pressed=true
    check(PROMPT.binding_label(mouse)=="Ctrl+Alt+Shift+Meta+鼠标右键","all required modifiers shown")
    mouse.button_index=MOUSE_BUTTON_WHEEL_LEFT
    check(PROMPT.binding_label(mouse).ends_with("滚轮 ←"),"horizontal wheel supported")
    mouse.button_index=MOUSE_BUTTON_WHEEL_RIGHT
    check(PROMPT.binding_label(mouse).ends_with("滚轮 →"),"opposite wheel distinct")
    mouse.button_index=99;check(PROMPT.binding_label(mouse).is_empty(),"invalid mouse cannot become modifier-only label")
    mouse.button_index=MOUSE_BUTTON_RIGHT
    InputMap.add_action("prompt_test");InputMap.action_add_event("prompt_test",mouse)
    PROMPT.controller_device=7
    check(PROMPT.action_label("prompt_test")=="Ctrl+Alt+Shift+Meta+鼠标右键","controller fallback does not call mouse a keyboard")
    var pad:=InputEventJoypadButton.new();pad.button_index=JOY_BUTTON_A;pad.device=-1
    InputMap.action_add_event("prompt_test",pad)
    check(PROMPT.action_label("prompt_test")=="手柄 A","generic binding used for current pad")
    var specific:=InputEventJoypadButton.new();specific.button_index=JOY_BUTTON_B;specific.device=7
    InputMap.action_add_event("prompt_test",specific)
    check(PROMPT.action_label("prompt_test")=="手柄 B","current-device binding preferred")
    PROMPT.controller_device=8
    check(PROMPT.action_label("prompt_test")=="手柄 A","other-device binding never advertised")
    PROMPT.disconnected(8)
    check(PROMPT.action_label("prompt_test").begins_with("Ctrl+"),"disconnect restores complete mouse chord")
    check(PROMPT.action_label("missing")=="未设置","missing action safe")
    var key:=InputEventKey.new();key.physical_keycode=KEY_H;key.shift_pressed=true
    check(PROMPT.binding_label(key).contains("Shift"),"physical key modifiers preserved")
    InputMap.erase_action("prompt_test")
    print("RELIABILITY_R05 checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
