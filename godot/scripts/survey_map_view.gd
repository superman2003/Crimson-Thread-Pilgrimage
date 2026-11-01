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
var view_memory: Dictionary = {}
var previous_size := Vector2.ZERO
const MAX_REMEMBERED_VIEWS := 8
func _ready() -> void:
    clip_contents = true
    mouse_filter = Control.MOUSE_FILTER_STOP
    tooltip_text = "WASD / 左摇杆 平移 · PgUp/PgDn / RB/LB 缩放 · Home / Y 复位"
    visibility_changed.connect(_cancel_navigation)
    Input.joy_connection_changed.connect(_controller_changed)
    resized.connect(_resize_view)
    previous_size=size
func reset() -> void:
    _cancel_navigation()
    zoom = 1.0
    view_memory.erase(view)
    if not is_instance_valid(content):return
    content.scale = Vector2.ONE
    content.position = Vector2.ZERO
func set_view(next: int) -> void:
    if next != view:
        remember_view()
        view = next
        _cancel_navigation()
        restore_view()

func remember_view() -> void:
    if view<0 or not is_instance_valid(content) or content.size.x<=0.0 or content.size.y<=0.0:return
    var center: Vector2=(size*0.5-content.position)/zoom/content.size
    if not center.is_finite():return
    view_memory.erase(view)
    view_memory[view]={"zoom":zoom,"center":center.clamp(Vector2.ZERO,Vector2.ONE)}
    while view_memory.size()>MAX_REMEMBERED_VIEWS:view_memory.erase(view_memory.keys()[0])

func restore_view() -> void:
    if not is_instance_valid(content):return
    var saved: Dictionary=view_memory.get(view,{})
    zoom=clampf(float(saved.get("zoom",1.0)),1.0,4.0)
    content.scale=Vector2.ONE*zoom
    var center: Vector2=saved.get("center",Vector2(0.5,0.5))
    content.position=size*0.5-center*content.size*zoom
    clamp_pan()

func _resize_view() -> void:
    if not is_instance_valid(content):previous_size=size;return
    var center: Vector2=(previous_size*0.5-content.position)/zoom
    content.position=size*0.5-center*zoom
    previous_size=size
    clamp_pan()

func navigation_available() -> bool:
    if not is_visible_in_tree() or not is_instance_valid(content):return false
    var window:=get_window()
    if window!=null:
        for child in window.find_children("*","Window",true,false):
            if child is Window and child.visible and child.exclusive:return false
    var focused:=get_viewport().gui_get_focus_owner()
    return not (focused is LineEdit or focused is TextEdit)
func magnify(factor: float, anchor: Vector2 = Vector2.INF) -> void:
    if not is_instance_valid(content) or not is_finite(factor) or factor <= 0.0: return
    if not anchor.is_finite(): anchor = size * 0.5
    var next := clampf(zoom * factor, 1.0, 4.0)
    content.position = anchor - (anchor - content.position) * (next / zoom)
    zoom = next
    content.scale = Vector2.ONE * zoom
    clamp_pan()
func clamp_pan() -> void:
    if not is_instance_valid(content):return
    var extent:=content.size*zoom
    var low:=(size-extent).min(Vector2.ZERO)
    var high:=(size-extent).max(Vector2.ZERO)*0.5
    content.position=content.position.clamp(low,high)

func center_on(point: Vector2, minimum_zoom: float=2.0) -> bool:
    if content==null or not point.is_finite() or not is_finite(minimum_zoom) or minimum_zoom<1.0 or minimum_zoom>4.0:return false
    if not Rect2(Vector2.ZERO,content.size).has_point(point):return false
    _cancel_navigation()
    zoom=maxf(zoom,minimum_zoom)
    content.scale=Vector2.ONE*zoom
    content.position=size*0.5-point*zoom
    clamp_pan()
    return true
func _gui_input(event: InputEvent) -> void:
    if not navigation_available():_cancel_navigation();return
    if event is InputEventMagnifyGesture:
        magnify(event.factor,event.position)
        accept_event()
    elif event is InputEventPanGesture:
        if event.delta.is_finite():content.position-=event.delta*24.0;clamp_pan()
        accept_event()
    elif event is InputEventMouseButton:
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
    if not navigation_available():_cancel_navigation();return
    if zoom <= 1.0 or not is_finite(delta) or delta<=0.0:return
    var direction := (keyboard_pan + stick_pan).limit_length()
    content.position -= direction * PAN_SPEED * delta
    clamp_pan()

func _input(event: InputEvent) -> void:
    # Release beyond the clipped viewport must also end a drag.
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
        dragging = false

    if not navigation_available():_cancel_navigation();return
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
