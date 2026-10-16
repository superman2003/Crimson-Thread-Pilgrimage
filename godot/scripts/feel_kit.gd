extends Node
## FeelKit：全局打击感单例（hitstop / trauma 震屏 / 全屏闪帧 / 受击黑屏帧）。
## 规格：docs/spec/20260726160500000_动作特效与打击感设计规格.md §6.3–§6.5
## 访问方式：get_node_or_null("/root/FeelKit")，调用方必须判空，
## 保证 headless 自定义 SceneTree 验证脚本（无 autoload）不受影响。

const HITSTOP_MAX_SECONDS := 0.25
const TRAUMA_DECAY := 2.2
const TRAUMA_AMPLITUDE := 14.0
const TRAUMA_ROTATION_DEG := 0.5
const RUMBLE_MAX_SECONDS := 0.09
const RUMBLE_INPUT_THRESHOLD := 0.55
const BLACK_FRAME_SHADER := preload("res://shaders/black_frame.gdshader")

var _hitstop_remaining := 0.0
var _trauma := 0.0
var _camera: Camera2D = null
var _noise_x := FastNoiseLite.new()
var _noise_y := FastNoiseLite.new()
var _noise_time := 0.0
var _flash_enabled := true
var _shake_enabled := true
var _overlay_layer: CanvasLayer
var _vibration_enabled := true
var _vibration_strength := 1.0
var _active_joy_device := -1
var _rumble_device := -1
var _rumble_deadline_usec := 0
var _last_rumble_frame := -1


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _noise_x.seed = 1937
    _noise_y.seed = 7391
    _overlay_layer = CanvasLayer.new()
    _overlay_layer.name = "FeelKitOverlay"
    _overlay_layer.layer = 90
    add_child(_overlay_layer)
    if not Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
        Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _process(delta: float) -> void:
    # Hardware vibration uses wall time, not the slowed hitstop clock.
    if _rumble_device >= 0 and (get_tree().paused or _now_usec() >= _rumble_deadline_usec or not _joy_devices().has(_rumble_device)):
        cancel_rumble()
    var real_delta := delta / maxf(Engine.time_scale, 0.001)
    if _hitstop_remaining > 0.0:
        _hitstop_remaining -= real_delta
        if _hitstop_remaining <= 0.0:
            _hitstop_remaining = 0.0
            Engine.time_scale = 1.0
    if _trauma > 0.0:
        _trauma = maxf(0.0, _trauma - TRAUMA_DECAY * real_delta)
        _noise_time += real_delta * 18.0
        _apply_camera_shake()
    else:
        _clear_camera_shake()


func register_camera(camera: Camera2D) -> void:
    if _camera == camera:
        return
    _clear_camera_shake()
    _trauma = 0.0
    _camera = camera


func set_accessibility(preferences: Dictionary) -> void:
    _flash_enabled = bool(preferences.get("flash_enabled", true))
    _vibration_enabled = bool(preferences.get("vibration_enabled", true))
    var requested_strength := float(preferences.get("vibration_strength", 1.0))
    _vibration_strength = clampf(requested_strength, 0.0, 1.0) if is_finite(requested_strength) else 1.0
    # Changing the slider or disabling cannot leave an old, stronger pulse alive.
    cancel_rumble()
    # Player already scales nonzero trauma by the slider; do not scale it twice.
    _shake_enabled = float(preferences.get("camera_shake", 1.0)) > 0.0
    if not _shake_enabled:
        _trauma = 0.0
        _clear_camera_shake()
    if not _flash_enabled and is_instance_valid(_overlay_layer):
        for effect in _overlay_layer.get_children():
            _overlay_layer.remove_child(effect)
            effect.queue_free()


func _clear_camera_shake() -> void:
    if is_instance_valid(_camera):
        _camera.offset = Vector2.ZERO
        _camera.rotation = 0.0


## 冻结世界 ms 毫秒（真实时间）。不叠加：与剩余冻结取较大者，单次上限 250ms。
func hitstop(ms: float, time_scale: float = 0.05) -> void:
    if _is_headless():
        return
    var seconds := minf(ms / 1000.0, HITSTOP_MAX_SECONDS)
    if seconds <= _hitstop_remaining:
        return
    _hitstop_remaining = seconds
    Engine.time_scale = time_scale


## trauma 模型：振幅 = trauma^2 × 14px，线性衰减 2.2/s，叠加上限 1.0。
func add_trauma(amount: float) -> void:
    if _shake_enabled:
        _trauma = clampf(_trauma + amount, 0.0, 1.0)


## 全屏纯色闪帧（击杀提亮/完美格挡等）。frames 按 60fps 真实帧计。
func flash_screen(color: Color, alpha: float, frames: int = 1) -> void:
    if not _flash_enabled or _is_headless() or _overlay_layer == null:
        return
    var rect := ColorRect.new()
    rect.name = "FeelKitFlash"
    rect.color = Color(color.r, color.g, color.b, alpha)
    rect.set_anchors_preset(Control.PRESET_FULL_RECT)
    rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _overlay_layer.add_child(rect)
    _free_after_real_seconds(rect, float(frames) / 60.0)


## 受击黑屏帧：全屏压暗 2 帧，只在受击世界坐标处留一个径向亮孔。
func black_frame(world_position: Vector2, frames: int = 2) -> void:
    if not _flash_enabled or _is_headless() or _overlay_layer == null:
        return
    var rect := ColorRect.new()
    rect.name = "FeelKitBlackFrame"
    rect.set_anchors_preset(Control.PRESET_FULL_RECT)
    rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var material := ShaderMaterial.new()
    material.shader = BLACK_FRAME_SHADER
    material.set_shader_parameter("hole_center_px", _world_to_screen(world_position))
    material.set_shader_parameter("hole_radius_px", 90.0)
    rect.material = material
    _overlay_layer.add_child(rect)
    _free_after_real_seconds(rect, float(frames) / 60.0)


func _apply_camera_shake() -> void:
    if _camera == null or not is_instance_valid(_camera):
        return
    var strength := _trauma * _trauma
    _camera.offset = Vector2(
        _noise_x.get_noise_1d(_noise_time) * strength * TRAUMA_AMPLITUDE,
        _noise_y.get_noise_1d(_noise_time) * strength * TRAUMA_AMPLITUDE
    )
    _camera.rotation_degrees = _noise_x.get_noise_1d(_noise_time * 0.7 + 51.0) * strength * TRAUMA_ROTATION_DEG


func _world_to_screen(world_position: Vector2) -> Vector2:
    var viewport := get_viewport()
    if viewport == null:
        return Vector2(640.0, 360.0)
    return viewport.get_canvas_transform() * world_position


func _free_after_real_seconds(node: Node, seconds: float) -> void:
    var timer := get_tree().create_timer(seconds, true, false, true)
    timer.timeout.connect(func() -> void:
        if is_instance_valid(node):
            node.queue_free()
    )


func _is_headless() -> bool:
    return DisplayServer.get_name() == "headless"


## This is only called after the player's accepted-damage check. It neither
## starts hitstop nor plays impact audio: those existing paths remain owners.
func melee_rumble(animation: StringName, killed: bool, direction: Vector2) -> void:
    if not _vibration_enabled or _vibration_strength <= 0.0 or get_tree().paused:
        return
    if _active_joy_device < 0 or not _joy_devices().has(_active_joy_device):
        return
    var frame := Engine.get_physics_frames()
    # Several targets accepted by one strike must not stack or lengthen pulses.
    if frame == _last_rumble_frame:
        return
    _last_rumble_frame = frame
    var pulse := melee_rumble_profile(animation, killed, direction)
    var weak := clampf(pulse.x * _vibration_strength, 0.0, 1.0)
    var strong := clampf(pulse.y * _vibration_strength, 0.0, 1.0)
    var duration := clampf(pulse.z, 0.0, RUMBLE_MAX_SECONDS)
    if duration <= 0.0:
        return
    cancel_rumble()
    _rumble_device = _active_joy_device
    _rumble_deadline_usec = _now_usec() + int(duration * 1000000.0)
    _send_joy_vibration(_rumble_device, weak, strong, duration)


static func melee_rumble_profile(animation: StringName, killed: bool, direction: Vector2) -> Vector3:
    if animation == &"attack_2":
        return Vector3(0.27, 0.18, 0.075) if killed else Vector3(0.22, 0.14, 0.060)
    if animation == &"hook_throw":
        return Vector3(0.16, 0.07, 0.040)
    if direction.y > 0.5:
        return Vector3(0.15, 0.08, 0.040)
    return Vector3(0.22, 0.12, 0.060) if killed else Vector3(0.17, 0.08, 0.045)


func _input(event: InputEvent) -> void:
    if event is InputEventJoypadButton and event.is_pressed():
        _select_joy_device(event.device)
    elif event is InputEventJoypadMotion:
        if not is_finite(event.axis_value):
            return
        # Some backends report resting triggers as -1. Only a positive trigger
        # press is intent; sticks still accept deliberate motion in either sign.
        var intentional: bool = event.axis_value >= RUMBLE_INPUT_THRESHOLD if event.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT] else absf(event.axis_value) >= RUMBLE_INPUT_THRESHOLD
        if intentional:
            _select_joy_device(event.device)
    elif ((event is InputEventKey and not event.echo) or event is InputEventMouseButton) and event.is_pressed():
        # A connected but idle controller must not buzz during keyboard play.
        # An old held key's OS repeat must not cancel a newer controller action.
        _active_joy_device = -1
        cancel_rumble()


func _select_joy_device(device: int) -> void:
    if not _joy_devices().has(device):
        return
    if _active_joy_device != device:
        cancel_rumble()
    _active_joy_device = device


func _on_joy_connection_changed(device: int, connected: bool) -> void:
    if not connected and device == _active_joy_device:
        _active_joy_device = -1
    if not connected and device == _rumble_device:
        cancel_rumble()


func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        _active_joy_device = -1
        cancel_rumble()


func _exit_tree() -> void:
    cancel_rumble()


func cancel_rumble() -> void:
    if _rumble_device >= 0 and _joy_devices().has(_rumble_device):
        _stop_joy_vibration(_rumble_device)
    _rumble_device = -1
    _rumble_deadline_usec = 0


## Small overridable hardware boundary: validation substitutes a recording
## backend, so a headless pass proves routing/limits, never physical sensation.
func _joy_devices() -> Array[int]:
    return Input.get_connected_joypads()


func _send_joy_vibration(device: int, weak: float, strong: float, duration: float) -> void:
    Input.start_joy_vibration(device, weak, strong, duration)


func _stop_joy_vibration(device: int) -> void:
    Input.stop_joy_vibration(device)


func _now_usec() -> int:
    return Time.get_ticks_usec()
