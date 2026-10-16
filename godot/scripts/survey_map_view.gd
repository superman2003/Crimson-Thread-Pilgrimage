extends Control
## Camera only transforms the presentation; the cartography frame never moves.
signal secondary_pressed(content_position: Vector2)
var content: Control
var zoom := 1.0
var dragging := false
var view := -1
const PAN_SPEED := 560.0
var keyboard_pan := Vector2.ZERO
var pan_keys: Dictionary = {}
var stick_pan := Vector2.ZERO
var pan_device := -1
func _ready() -> void:
    clip_contents = true
    mouse_filter = Control.MOUSE_FILTER_STOP
    tooltip_text = "WASD / 左摇杆 平移 · PgUp/PgDn / RB/LB 缩放 · Home / Y 复位"
    visibility_changed.connect(_cancel_navigation)
    Input.joy_connection_changed.connect(_controller_changed)
func reset() -> void:
    _cancel_navigation()
    zoom = 1.0
    content.scale = Vector2.ONE
    content.position = Vector2.ZERO
func set_view(next: int) -> void:
    if next != view:
        view = next
        reset()
func magnify(factor: float, anchor: Vector2 = Vector2.INF) -> void:
    if not is_finite(factor) or factor <= 0.0: return
    if not anchor.is_finite(): anchor = size * 0.5
    var next := clampf(zoom * factor, 1.0, 4.0)
    content.position = anchor - (anchor - content.position) * (next / zoom)
    zoom = next
    content.scale = Vector2.ONE * zoom
    clamp_pan()
func clamp_pan() -> void:
    content.position = content.position.clamp(size - content.size * zoom, Vector2.ZERO)
func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
            magnify(1.25, event.position)
            accept_event()
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
            magnify(0.8, event.position)
            accept_event()
        elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
            if not dragging and Rect2(Vector2.ZERO, size).has_point(event.position):
                secondary_pressed.emit((event.position - content.position) / zoom)
            accept_event()
        elif event.button_index == MOUSE_BUTTON_LEFT:
            dragging = event.pressed
            accept_event()
    elif event is InputEventMouseMotion and dragging and zoom > 1.0:
        content.position += event.relative
        clamp_pan()
        accept_event()
func _cancel_navigation() -> void:
    dragging = false
    keyboard_pan = Vector2.ZERO
    stick_pan = Vector2.ZERO
    pan_device = -1
    pan_keys.clear()

func _controller_changed(device: int, connected: bool) -> void:
    if not connected and device == pan_device:
        stick_pan = Vector2.ZERO
        pan_device = -1

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        _cancel_navigation()

func _process(delta: float) -> void:
    if not is_visible_in_tree() or zoom <= 1.0: return
    var direction := (keyboard_pan + stick_pan).limit_length()
    content.position -= direction * PAN_SPEED * delta
    clamp_pan()

func _input(event: InputEvent) -> void:
    # Release beyond the clipped viewport must also end a drag.
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
        dragging = false

    if not is_visible_in_tree(): return
    if event is InputEventKey:
        var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
        if code in [KEY_W,KEY_A,KEY_S,KEY_D]:
            if not event.echo:
                var value := 1.0 if event.pressed else 0.0
                pan_keys[code]=value
                keyboard_pan = Vector2(float(pan_keys.get(KEY_D,0.0))-float(pan_keys.get(KEY_A,0.0)),float(pan_keys.get(KEY_S,0.0))-float(pan_keys.get(KEY_W,0.0)))
            get_viewport().set_input_as_handled()
        elif event.pressed and not event.echo and code in [KEY_PAGEUP,KEY_PAGEDOWN,KEY_HOME]:
            if code == KEY_HOME: reset()
            else: magnify(1.25 if code == KEY_PAGEUP else 0.8)
            get_viewport().set_input_as_handled()
    elif event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER,JOY_BUTTON_Y]:
        if event.button_index == JOY_BUTTON_Y: reset()
        else: magnify(1.25 if event.button_index == JOY_BUTTON_RIGHT_SHOULDER else 0.8)
        get_viewport().set_input_as_handled()
    elif event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y] and is_finite(event.axis_value):
        if pan_device != event.device:
            if absf(event.axis_value) <= 0.25: return
            stick_pan = Vector2.ZERO
            pan_device = event.device
        var value := signf(event.axis_value) * (absf(event.axis_value)-0.25)/0.75 if absf(event.axis_value)>0.25 else 0.0
        if event.axis == JOY_AXIS_LEFT_X: stick_pan.x = value
        else: stick_pan.y = value
        get_viewport().set_input_as_handled()
