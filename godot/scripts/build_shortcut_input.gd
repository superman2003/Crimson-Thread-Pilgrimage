extends Node
## One menu activation per physical press. Navigation remains available in UI.
## Only value tokens survive input events; no player or UI nodes are retained.
const ACTION := "build_menu"
const POLICY := preload("res://scripts/input_binding_policy.gd")
var held: Dictionary = {}

static func ensure_action() -> void:
    if not InputMap.has_action(ACTION):InputMap.add_action(ACTION)
    if not InputMap.action_get_events(ACTION).is_empty():return
    var key := InputEventKey.new()
    key.physical_keycode = KEY_B
    InputMap.action_add_event(ACTION,key)
    var button := InputEventJoypadButton.new()
    button.button_index = JOY_BUTTON_LEFT_STICK
    button.device = -1
    InputMap.action_add_event(ACTION,button)

func _ready() -> void:
    Input.joy_connection_changed.connect(_connection_changed)

func _exit_tree() -> void:
    if Input.joy_connection_changed.is_connected(_connection_changed):
        Input.joy_connection_changed.disconnect(_connection_changed)
    clear()

func _connection_changed(device: int, connected: bool) -> void:
    if connected:return
    var prefix := "joy_%d_" % device
    for token in held.keys():
        if String(token).begins_with(prefix):held.erase(token)

func clear() -> void:
    held.clear()

static func token(event: InputEvent) -> String:
    if event is InputEventKey:
        return "key_%d" % (event.physical_keycode if event.physical_keycode != 0 else event.keycode)
    if event is InputEventMouseButton:return "mouse_%d" % event.button_index
    if event is InputEventJoypadButton:return "joy_%d_button_%d" % [event.device,event.button_index]
    return ""

func suppress_capture(event: InputEvent) -> void:
    clear()
    var identity := token(event)
    if not identity.is_empty():held[identity] = true

func consume(event: InputEvent) -> bool:
    var identity := token(event)
    if identity.is_empty() or not InputMap.has_action(ACTION):return false
    if POLICY.is_reserved(event) or not POLICY.allowed_for(ACTION,event):return false
    var pressed := event.is_action_pressed(ACTION)
    # Releases clear tokens even when a modifier was lifted first, or this
    # device family was remapped while the original key was held.
    var released: bool = not event.pressed if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton else not pressed
    if released:
        held.erase(identity)
        return false
    if not pressed:return false
    if event is InputEventKey and event.echo:return false
    if held.has(identity):return false
    var already_held := not held.is_empty()
    held[identity] = true
    return not already_held
