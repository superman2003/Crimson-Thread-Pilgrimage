extends Node
## Short combat pulses on the last actively used controller. Native duration is
## a fail-safe; our real-time deadline is independent of hitstop/time_scale.
const PROFILES := {
    "hit":{"weak":0.16,"strong":0.04,"seconds":0.045,"priority":1},
    "kill":{"weak":0.30,"strong":0.12,"seconds":0.075,"priority":2},
    "hurt":{"weak":0.45,"strong":0.60,"seconds":0.14,"priority":3},
}
var selected_device := -1
var running_device := -1
var deadline_ms := 0
var priority := 0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    Input.joy_connection_changed.connect(_connection_changed)

func _input(event: InputEvent) -> void:
    if (event is InputEventJoypadButton and event.pressed) or (event is InputEventJoypadMotion and is_finite(event.axis_value) and absf(event.axis_value) >= 0.7):
        if event.device in _devices():
            if selected_device != event.device:stop()
            selected_device = event.device
    elif (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed):
        stop()
        selected_device = -1

func _allowed() -> bool:
    var player := get_parent()
    if not is_instance_valid(player) or not player.is_inside_tree():return false
    if get_tree().paused or player.ui_input_locked or player.hp <= 0 or player.death_timer > 0.0:return false
    return bool(player.get_meta("accessibility",{}).get("vibration_enabled",true))

func pulse(kind: String) -> bool:
    if not _allowed() or selected_device not in _devices() or not PROFILES.has(kind):
        stop()
        return false
    var profile: Dictionary = PROFILES[kind]
    var now := _now_ms()
    # A crowd of equal/weaker hits cannot prolong or mask a stronger warning.
    if running_device == selected_device and now < deadline_ms and priority >= int(profile.priority):return false
    stop()
    running_device = selected_device
    priority = int(profile.priority)
    deadline_ms = now + int(ceil(float(profile.seconds) * 1000.0))
    _start_output(running_device,float(profile.weak),float(profile.strong),float(profile.seconds))
    return true

func stop() -> void:
    if running_device >= 0:_stop_output(running_device)
    running_device = -1
    deadline_ms = 0
    priority = 0

func _process(_delta: float) -> void:
    if selected_device >= 0 and selected_device not in _devices():
        stop()
        selected_device = -1
    if running_device >= 0 and (not _allowed() or running_device not in _devices() or _now_ms() >= deadline_ms):stop()

func _connection_changed(device: int, connected: bool) -> void:
    if not connected:
        if running_device == device:stop()
        if selected_device == device:selected_device = -1

func _exit_tree() -> void:
    stop()

# Hardware and clock boundary, replaced only by the automated test adapter.
func _devices() -> Array[int]:
    return Input.get_connected_joypads()

func _now_ms() -> int:
    return Time.get_ticks_msec()

func _start_output(device: int, weak: float, strong: float, seconds: float) -> void:
    Input.start_joy_vibration(device,weak,strong,seconds)

func _stop_output(device: int) -> void:
    Input.stop_joy_vibration(device)
