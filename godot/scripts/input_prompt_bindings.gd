extends RefCounted
## Last meaningful input survives region-owned UI replacement, without retaining nodes.
static var controller_device := -1

static func observe(event: InputEvent) -> void:
    if not is_instance_valid(event):return
    if not Input.joy_connection_changed.is_connected(_connection_changed):
        Input.joy_connection_changed.connect(_connection_changed)
    if event is InputEventKey:
        if event.pressed and not event.echo and (event.physical_keycode != 0 or event.keycode != 0):
            controller_device = -1
    elif event is InputEventMouseButton:
        if event.pressed and not binding_label(event).is_empty():
            controller_device = -1
    elif event is InputEventJoypadButton:
        if event.pressed and event.device >= 0 and not binding_label(event).is_empty():
            controller_device = event.device
    elif event is InputEventJoypadMotion:
        if event.device < 0 or binding_label(event).is_empty():
            return
        # Triggers rest below zero on some backends; resting motion isn't intent.
        var intentional: bool = event.axis_value > 0.65 if event.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT] else absf(event.axis_value) > 0.65
        if intentional:
            controller_device = event.device

static func _connection_changed(device: int, connected: bool) -> void:
    if not connected:
        disconnected(device)

static func disconnected(device: int) -> void:
    if controller_device == device:
        controller_device = -1

static func action_label(action: String) -> String:
    if not InputMap.has_action(action):
        return "未设置"
    var keyboard := ""
    var mouse_binding := false
    var controller := ""
    var specific := false
    for event in InputMap.action_get_events(action):
        var label := binding_label(event)
        if label.is_empty():
            continue
        if event is InputEventJoypadButton or event is InputEventJoypadMotion:
            # Never advertise another controller's device-specific binding.
            if event.device == controller_device and controller_device >= 0:
                if not specific:controller = label
                specific = true
            elif controller.is_empty() and event.device < 0:
                controller = label
        elif keyboard.is_empty():
            keyboard = label
            mouse_binding = event is InputEventMouseButton
    if controller_device >= 0:
        if not controller.is_empty():
            return controller
        if not keyboard.is_empty():
            return keyboard if mouse_binding else "键盘 " + keyboard
        return "未设置"
    return keyboard if not keyboard.is_empty() else controller if not controller.is_empty() else "未设置"

static func binding_label(event: InputEvent) -> String:
    if not is_instance_valid(event):return ""
    if event is InputEventKey:
        if event.physical_keycode == 0 and event.keycode == 0:
            return ""
        var code: int = event.get_physical_keycode_with_modifiers() if event.physical_keycode != 0 else event.get_keycode_with_modifiers()
        return OS.get_keycode_string(code)
    if event is InputEventMouseButton:
        var label: String={MOUSE_BUTTON_LEFT:"鼠标左键", MOUSE_BUTTON_RIGHT:"鼠标右键", MOUSE_BUTTON_MIDDLE:"鼠标中键", MOUSE_BUTTON_WHEEL_UP:"滚轮 ↑", MOUSE_BUTTON_WHEEL_DOWN:"滚轮 ↓", MOUSE_BUTTON_WHEEL_LEFT:"滚轮 ←", MOUSE_BUTTON_WHEEL_RIGHT:"滚轮 →", MOUSE_BUTTON_XBUTTON1:"鼠标侧键 1", MOUSE_BUTTON_XBUTTON2:"鼠标侧键 2"}.get(event.button_index, "")
        if label.is_empty():return ""
        var modifiers: Array[String]=[]
        if event.ctrl_pressed:modifiers.append("Ctrl")
        if event.alt_pressed:modifiers.append("Alt")
        if event.shift_pressed:modifiers.append("Shift")
        if event.meta_pressed:modifiers.append("Meta")
        modifiers.append(label)
        return "+".join(modifiers)
    if event is InputEventJoypadButton:
        return {JOY_BUTTON_A:"手柄 A", JOY_BUTTON_B:"手柄 B", JOY_BUTTON_X:"手柄 X", JOY_BUTTON_Y:"手柄 Y", JOY_BUTTON_BACK:"手柄 Back", JOY_BUTTON_GUIDE:"手柄 Guide", JOY_BUTTON_START:"手柄 Start", JOY_BUTTON_LEFT_STICK:"手柄 L3", JOY_BUTTON_RIGHT_STICK:"手柄 R3", JOY_BUTTON_LEFT_SHOULDER:"手柄 LB", JOY_BUTTON_RIGHT_SHOULDER:"手柄 RB", JOY_BUTTON_DPAD_DOWN:"十字键 ↓", JOY_BUTTON_DPAD_UP:"十字键 ↑", JOY_BUTTON_DPAD_LEFT:"十字键 ←", JOY_BUTTON_DPAD_RIGHT:"十字键 →"}.get(event.button_index, "手柄 %d" % event.button_index) if event.button_index >= 0 and event.button_index < JOY_BUTTON_MAX else ""
    if event is InputEventJoypadMotion and event.axis >= 0 and event.axis < JOY_AXIS_MAX and is_finite(event.axis_value) and absf(event.axis_value) >= 0.5 and absf(event.axis_value) <= 1.0:
        if event.axis == JOY_AXIS_TRIGGER_LEFT:
            return "手柄 L2" if event.axis_value > 0 else ""
        if event.axis == JOY_AXIS_TRIGGER_RIGHT:
            return "手柄 R2" if event.axis_value > 0 else ""
        var stick := "左摇杆" if event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y] else "右摇杆"
        if event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_RIGHT_X]:
            return stick + (" ←" if event.axis_value < 0 else " →")
        if event.axis in [JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_Y]:
            return stick + (" ↑" if event.axis_value < 0 else " ↓")
    return ""
