extends SceneTree

const PROMPTS := preload("res://scripts/input_prompt_bindings.gd")
const UI := preload("res://scripts/pilgrimage_interface.gd")
const AUDIO := preload("res://scripts/audio_retirement.gd")
const SAVE := "user://input_prompt_validation.json"
var checks := 0
var failures := 0
var original_bindings: Dictionary = {}

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var world: Node = load("res://scenes/World.tscn").instantiate()
    world.world_resume = false
    world.world_save_path = SAVE
    root.add_child(world)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(world)
    world.set_process(false)
    world.set_physics_process(false)
    world.player.set_physics_process(false)
    for enemy in get_nodes_in_group("enemy"):
        enemy.set_physics_process(false)
    var ui: Control = world.ui_shell
    ui.set_process(false)
    for action in ["interact", "jump", "attack", "close_overlay", "skill_1"]:
        original_bindings[action] = InputMap.action_get_events(action).duplicate()
    _bind("interact", [_key(KEY_F), _button(JOY_BUTTON_BACK)])
    _bind("jump", [_key(KEY_SPACE), _button(JOY_BUTTON_A)])
    _bind("attack", [_key(KEY_J), _button(JOY_BUTTON_X)])
    _bind("close_overlay", [_key(KEY_ESCAPE), _button(JOY_BUTTON_B)])
    _bind("skill_1", [_key(KEY_L), _button(JOY_BUTTON_Y)])

    # Go through the real viewport input callback, not only the pure formatter.
    await _send(_key(KEY_F))
    _check(ui._short_binding("interact") == "F", "keyboard prompts read the live action map")
    await _send(_button(JOY_BUTTON_GUIDE, 7))
    _check(ui._short_binding("interact") == "手柄 Back", "viewport controller input switches interaction prompt")
    _check(ui._short_binding("jump") == "手柄 A", "controller jump hint is independent of event order")
    _check(ui._short_binding("skill_1") == "手柄 Y", "HUD skill prompt follows the same device")
    _check(ui._dialogue_binding_hint() == "手柄 Back 继续\n手柄 B 离开", "dialogue uses real interact and close-overlay bindings")

    var rest: Area2D
    for child in world.get_children():
        if child is Area2D and String(child.get_meta("kind", "")) == "save_point":
            rest = child
            break
    _check(is_instance_valid(rest), "real world has a checkpoint sign fixture")
    if is_instance_valid(rest):
        # Positioning is a fixture; selection and displayed prompt use production logic.
        world.player.global_position = rest.global_position
        var marker: Node = rest.get_node("Wayfinding")
        marker._process(0.0)
        _check(marker.nearby and marker.key_hint == "手柄 Back", "real world sign displays active controller binding")
        _bind("interact", [_key(KEY_E), _button(JOY_BUTTON_X)])
        marker._process(0.0)
        _check(marker.key_hint == "手柄 X", "sign refresh reads remapped controller binding immediately")
        await _send(_key(KEY_E))
        marker._process(0.0)
        _check(marker.key_hint == "E", "same sign switches back to remapped keyboard key")
        await _send(_button(JOY_BUTTON_GUIDE, 7))
        world.active_overlay = "dialogue"
        marker._process(0.0)
        _check(not marker.nearby and marker.key_hint.is_empty(), "overlay still suppresses world interaction prompt")
        world.active_overlay = ""

    ui.accessibility["tutorial_hints"] = true
    ui._process(0.0)
    _check(ui.tutorial_hint.text.contains("手柄 A") and ui.tutorial_hint.text.contains("手柄 X"), "existing tutorial HUD refresh uses controller mapping")
    ui.dialogue.show()
    world.active_overlay = "dialogue"
    ui._process(0.0)
    _check(ui.dialogue_hint.text == "手柄 X 继续\n手柄 B 离开", "visible dialogue refreshes after a remap")
    for line in ui.dialogue_hint.text.split("\n"):
        _check(ui.dialogue_hint.get_theme_font("font").get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x <= ui.dialogue_hint.size.x, "controller dialogue label fits its own column")
    await _capture("controller", world)
    await _send(_key(KEY_E))
    ui._process(0.0)
    _check(ui.dialogue_hint.text == "E 继续\nEscape 离开", "visible dialogue switches to keyboard without reopening")
    await _capture("keyboard", world)
    world.active_overlay = ""
    ui.dialogue.hide()

    await _send(_button(JOY_BUTTON_GUIDE, 7))
    var replacement := UI.new()
    _check(replacement._short_binding("jump") == "手柄 A", "replacement region UI keeps current device without retaining old UI")
    replacement.free()
    Input.joy_connection_changed.emit(8, false)
    _check(ui._short_binding("jump") == "手柄 A", "another controller disconnect does not steal the active mode")
    # Disconnect during the gap between region UI lifetimes.
    Input.joy_connection_changed.disconnect(ui._on_joy_connection_changed)
    Input.joy_connection_changed.emit(7, false)
    Input.joy_connection_changed.connect(ui._on_joy_connection_changed)
    _check(ui._short_binding("jump") == "Space", "active controller disconnect returns to keyboard")
    Input.joy_connection_changed.emit(7, true)
    _check(ui._short_binding("jump") == "Space", "reconnection alone does not claim input mode")

    await _send(_axis(JOY_AXIS_LEFT_X, 0.18, 7))
    await _send(_axis(JOY_AXIS_TRIGGER_LEFT, -1.0, 7))
    await _send(_axis(JOY_AXIS_RIGHT_Y, NAN, 7))
    _check(ui._short_binding("jump") == "Space", "stick drift, resting trigger and NaN cannot change mode")
    await _send(_axis(JOY_AXIS_LEFT_X, -0.9, 7))
    _check(ui._short_binding("jump") == "手柄 A", "deliberate negative stick input selects controller")
    var key_release := _key(KEY_SPACE)
    key_release.pressed = false
    await _send(key_release)
    var repeat_key := _key(KEY_SPACE)
    repeat_key.echo = true
    await _send(repeat_key)
    await _send(InputEventMouseMotion.new())
    _check(ui._short_binding("jump") == "手柄 A", "key release, key echo and mouse motion do not flicker hints")
    var mouse := InputEventMouseButton.new()
    mouse.button_index = MOUSE_BUTTON_LEFT
    mouse.pressed = true
    mouse.position = Vector2(-100, -100)
    await _send(mouse)
    _check(ui._short_binding("jump") == "Space", "mouse click selects keyboard and mouse prompts")
    mouse.pressed = false
    await _send(mouse)
    await _send(_axis(JOY_AXIS_TRIGGER_RIGHT, 0.9, 7))
    _check(ui._short_binding("jump") == "手柄 A", "intentional trigger press selects controller")

    var specific := _button(JOY_BUTTON_X, 8)
    _bind("jump", [specific, _key(KEY_K)])
    _check(ui._short_binding("jump") == "键盘 K", "another device's binding falls back explicitly to keyboard")
    _bind("jump", [specific])
    _check(ui._short_binding("jump") == "未设置", "other-device-only action does not advertise an unusable button")
    _bind("jump", [_button(JOY_BUTTON_Y)])
    _check(ui._short_binding("jump") == "手柄 Y", "device-independent controller binding remains usable")
    _bind("jump", [])
    _check(ui._short_binding("jump") == "未设置" and ui._short_binding("validation_missing_action") == "未设置", "empty and missing actions have honest prompts")
    _bind("jump", [InputEventKey.new(), _key(KEY_K)])
    _check(ui._short_binding("jump") == "键盘 K", "invalid empty key cannot hide a valid fallback")
    var modified := _key(KEY_K)
    modified.ctrl_pressed = true
    _check(PROMPTS.binding_label(modified).contains("Ctrl") and PROMPTS.binding_label(modified).contains("K"), "physical key labels preserve required modifiers")
    var logical := InputEventKey.new()
    logical.keycode = KEY_Q
    _check(PROMPTS.binding_label(logical) == "Q", "logical-only keyboard binding displays correctly")
    _check(PROMPTS.binding_label(_axis(JOY_AXIS_LEFT_X, -1.0)) == "左摇杆 ←", "left-stick binding uses readable direction")
    _check(PROMPTS.binding_label(_axis(JOY_AXIS_RIGHT_Y, 1.0)) == "右摇杆 ↓", "right-stick binding uses readable direction")
    _check(PROMPTS.binding_label(_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)) == "手柄 L2", "trigger binding has a readable control name")
    var side_button := InputEventMouseButton.new()
    side_button.button_index = MOUSE_BUTTON_XBUTTON1
    _check(PROMPTS.binding_label(side_button) == "鼠标侧键 1", "mouse side-button remaps have a readable label")

    for action in original_bindings:
        _bind(action, original_bindings[action])
    PROMPTS.observe(_key(KEY_SPACE))
    AUDIO.retire_tree(world)
    world.queue_free()
    await process_frame
    _check(await AUDIO.drain(self), "prompt validation retires its real world audio")
    for suffix in ["", ".tmp", ".bak"]:
        if FileAccess.file_exists(SAVE + suffix):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
    print("INPUT_PROMPT_VALIDATION checks=%d failures=%d" % [checks, failures])
    quit(0 if failures == 0 else 1)

func _bind(action: String, events: Array) -> void:
    InputMap.action_erase_events(action)
    for event in events:
        InputMap.action_add_event(action, event)

func _key(code: int) -> InputEventKey:
    var event := InputEventKey.new()
    event.physical_keycode = code
    event.pressed = true
    return event

func _button(index: int, device: int = -1) -> InputEventJoypadButton:
    var event := InputEventJoypadButton.new()
    event.button_index = index
    event.device = device
    event.pressed = true
    return event

func _axis(axis: int, value: float, device: int = -1) -> InputEventJoypadMotion:
    var event := InputEventJoypadMotion.new()
    event.axis = axis
    event.axis_value = value
    event.device = device
    return event

func _send(event: InputEvent) -> void:
    Input.parse_input_event(event)
    await process_frame

func _capture(name: String, world: Node) -> void:
    var directory := OS.get_environment("INPUT_PROMPT_CAPTURE_DIR")
    if directory.is_empty():
        return
    world.ui_shell.dialogue_name.text = "操作提示验证"
    world.ui_shell.dialogue_body.text = "此画面用于检查当前绑定在对话栏中的显示与排版。"
    await RenderingServer.frame_post_draw
    DirAccess.make_dir_recursive_absolute(directory)
    _check(root.get_texture().get_image().save_png(directory.path_join(name + ".png")) == OK, "save optional rendered prompt capture")

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("FAIL: " + label)
