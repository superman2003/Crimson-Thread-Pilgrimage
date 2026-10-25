extends "res://journey/fieldwork/sessionpanel.gd"
const DOMAIN := preload("res://journey/fieldwork/input_trials/model.gd")
const PAD := preload("res://journey/fieldwork/input_trials/view.gd")
var pad_ref: WeakRef


func _init() -> void:
    domain = DOMAIN


func descriptor() -> Dictionary:
    return {"id": "i_input_trials", "name": "按键练习台", "summary": "专用聚焦区域内的映射按下、按住和释放练习"}


func draw_session_controls(parent: Control) -> void:
    var pad: Control = PAD.new()
    pad.configure(
        {"active": _active(), "text": live.status_text() if _active() else "启动练习后，请聚焦此区域。"}
    )
    parent.add_child(pad)
    pad_ref = weakref(pad)
    if _active():
        pad.call_deferred("grab_focus")


func _start_session() -> void:
    super._start_session()
    if _active() and not Input.joy_connection_changed.is_connected(_connection_changed):
        Input.joy_connection_changed.connect(_connection_changed)


func _connection_changed(_device: int, connected: bool) -> void:
    if not connected and _active():
        _pause_session()
        context.tell("控制器已断开，练习暂停；连接后可明确继续。")


func _disconnect() -> void:
    if Input.joy_connection_changed.is_connected(_connection_changed):
        Input.joy_connection_changed.disconnect(_connection_changed)
    super._disconnect()


func _focused() -> bool:
    var pad: Control = pad_ref.get_ref() if pad_ref != null else null
    var window := _window()
    return is_instance_valid(pad) and window != null and window.gui_get_focus_owner() == pad


func _resume_session() -> void:
    super._resume_session()
    var pad: Control = pad_ref.get_ref() if pad_ref != null else null
    if is_instance_valid(pad):
        pad.grab_focus()


func session_tick(clock: float) -> void:
    if not _focused():
        if not live.paused:
            live.pause(clock)
    else:
        var pressed := []
        for action in live.settings.actions:
            if InputMap.has_action(action.id) and Input.is_action_pressed(action.id):
                pressed.append(action.id)
        live.set_neutral(pressed, clock)
        live.advance(clock)
    var pad: Control = pad_ref.get_ref() if pad_ref != null else null
    if is_instance_valid(pad):
        pad.update_state(live.status_text(), bool(live.paused), live.progress())


func accept_session_event(event: InputEvent, clock: float) -> void:
    if not _focused() or (event is InputEventKey and event.echo):
        return
    var down := []
    var up := []
    if event is InputEventKey or event is InputEventJoypadButton:
        for action in live.settings.actions:
            if event.is_action(action.id, true):
                if event.pressed:
                    down.append(action.id)
                else:
                    up.append(action.id)
    elif (
        event is InputEventJoypadMotion
        and is_finite(event.axis_value)
        and absf(event.axis_value) <= 1
    ):
        for action in live.settings.actions:
            var strength := -1.0
            for binding in InputMap.action_get_events(action.id):
                if not binding is InputEventJoypadMotion or binding.axis != event.axis:
                    continue
                if binding.device >= 0 and binding.device != event.device:
                    continue
                var direction := 1.0 if binding.axis_value > 0 else -1.0
                strength = maxf(strength, maxf(0, event.axis_value * direction))
            if strength < 0:
                continue
            var threshold := maxf(0.5, InputMap.action_get_deadzone(action.id))
            if strength >= threshold and not live.held.has(action.id):
                down.append(action.id)
            elif strength <= threshold * 0.5 and live.held.has(action.id):
                up.append(action.id)
    if not down.is_empty():
        live.feed(down, true, clock)
    if not up.is_empty():
        live.feed(up, false, clock)
    if not down.is_empty() or not up.is_empty():
        var window := _window()
        if window != null:
            window.set_input_as_handled()
