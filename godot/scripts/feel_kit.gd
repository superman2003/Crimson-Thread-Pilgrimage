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
# One full-screen envelope, shared by kill/parry flashes and damage shade.
# Damage may replace a live kill flash but cannot extend its original deadline.
const FLASH_MAX_ALPHA := 0.12
const DAMAGE_SHADE_MAX_ALPHA := 0.24
const FLASH_MAX_USEC := 50000
const FLASH_INTERVAL_USEC := 200000
const BLACK_FRAME_SHADER := preload("res://shaders/black_frame.gdshader")

var _hitstop_remaining := 0.0
var _hitstop_deadline_usec := 0
var _hitstop_restore_scale := 1.0
var _hitstop_applied_scale := 1.0
var _trauma := 0.0
var _camera: Camera2D = null
var _noise_x := FastNoiseLite.new()
var _noise_y := FastNoiseLite.new()
var _noise_time := 0.0
var _flash_enabled := true
var _shake_enabled := true
var _overlay_layer: CanvasLayer
var _screen_effect: ColorRect
var _screen_effect_priority := -1
var _screen_effect_deadline_usec := 0
var _last_screen_effect_usec := -FLASH_INTERVAL_USEC
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
    if is_instance_valid(_screen_effect) and _now_usec() >= _screen_effect_deadline_usec:
        _clear_screen_effect()
    # Hardware vibration uses wall time, not the slowed hitstop clock.
    if _rumble_device >= 0 and (get_tree().paused or _now_usec() >= _rumble_deadline_usec or not _joy_devices().has(_rumble_device)):
        cancel_rumble()
    var real_delta := maxf(delta, 0.0) / maxf(Engine.time_scale, 0.001) if is_finite(delta) else 0.0
    if _hitstop_deadline_usec > 0:
        # A stopped/scaled simulation clock cannot strand the global timescale.
        # External clock owners may replace ours; do not restore over them.
        if get_tree().paused or not is_equal_approx(Engine.time_scale, _hitstop_applied_scale) or _now_usec() >= _hitstop_deadline_usec:
            cancel_hitstop()
        else:
            _hitstop_remaining = maxf(0.0, float(_hitstop_deadline_usec - _now_usec()) / 1000000.0)
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
    _clear_screen_effect()
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
    if not _flash_enabled:
        _clear_screen_effect()
        _last_screen_effect_usec = -FLASH_INTERVAL_USEC


func _clear_camera_shake() -> void:
    if is_instance_valid(_camera):
        _camera.offset = Vector2.ZERO
        _camera.rotation = 0.0


## 冻结世界 ms 毫秒（真实时间）。不叠加：与剩余冻结取较大者，单次上限 250ms。
func hitstop(ms: float, time_scale: float = 0.05) -> void:
    if _is_headless():
        return
    if not is_finite(ms) or ms <= 0.0 or not is_finite(time_scale) or time_scale <= 0.0 or time_scale > 1.0 or get_tree().paused:
        return
    var seconds := minf(ms / 1000.0, HITSTOP_MAX_SECONDS)
    var now := _now_usec()
    var deadline := now + int(seconds * 1000000.0)
    if _hitstop_deadline_usec > 0 and (now >= _hitstop_deadline_usec or not is_equal_approx(Engine.time_scale, _hitstop_applied_scale)):
        cancel_hitstop()
    if deadline <= _hitstop_deadline_usec:return
    if _hitstop_deadline_usec == 0:_hitstop_restore_scale = Engine.time_scale
    _hitstop_remaining = seconds
    _hitstop_deadline_usec = deadline
    _hitstop_applied_scale = minf(time_scale, _hitstop_restore_scale)
    Engine.time_scale = _hitstop_applied_scale


## Restore only the clock value this instance still owns. Idempotent on
## pause, focus loss and teardown, including during an unfinished hitstop.
func cancel_hitstop() -> void:
    if _hitstop_deadline_usec > 0 and is_equal_approx(Engine.time_scale, _hitstop_applied_scale):
        Engine.time_scale = _hitstop_restore_scale
    _hitstop_remaining = 0.0
    _hitstop_deadline_usec = 0


## trauma 模型：振幅 = trauma^2 × 14px，线性衰减 2.2/s，叠加上限 1.0。
func add_trauma(amount: float) -> void:
    if _shake_enabled and is_finite(amount):
        _trauma = clampf(_trauma + amount, 0.0, 1.0)


## Full-screen accents share a wall-clock budget, including during hitstop.
func flash_screen(color: Color, alpha: float, frames: int = 1) -> void:
    if not (is_finite(color.r) and is_finite(color.g) and is_finite(color.b) and is_finite(color.a)) or not is_finite(alpha) or alpha <= 0.0:
        return
    var rect := _begin_screen_effect(0, frames)
    if rect != null:
        rect.name = "FeelKitFlash"
        rect.color = Color(clampf(color.r, 0.0, 1.0), clampf(color.g, 0.0, 1.0), clampf(color.b, 0.0, 1.0), minf(alpha, FLASH_MAX_ALPHA))


## A short, translucent damage shade retains the impact-position opening.
func black_frame(world_position: Vector2, frames: int = 2) -> void:
    if not world_position.is_finite():
        return
    var rect := _begin_screen_effect(1, frames)
    if rect == null:
        return
    rect.name = "FeelKitBlackFrame"
    var material := ShaderMaterial.new()
    material.shader = BLACK_FRAME_SHADER
    material.set_shader_parameter("hole_center_px", _world_to_screen(world_position))
    material.set_shader_parameter("hole_radius_px", 90.0)
    material.set_shader_parameter("tint", Color(0.078, 0.063, 0.118, DAMAGE_SHADE_MAX_ALPHA))
    rect.material = material


func _begin_screen_effect(priority: int, frames: int) -> ColorRect:
    if not _flash_enabled or _is_headless() or not is_instance_valid(_overlay_layer) or frames <= 0:
        return null
    var now := _now_usec()
    if is_instance_valid(_screen_effect) and now >= _screen_effect_deadline_usec:
        _clear_screen_effect()
    var deadline: int = now + int(mini(frames, 3) * 1000000.0 / 60.0)
    if now - _last_screen_effect_usec < FLASH_INTERVAL_USEC:
        if not is_instance_valid(_screen_effect) or priority <= _screen_effect_priority:
            return null
        deadline = mini(deadline, _screen_effect_deadline_usec)
    else:
        _last_screen_effect_usec = now
    _clear_screen_effect()
    _screen_effect = ColorRect.new()
    _screen_effect.set_anchors_preset(Control.PRESET_FULL_RECT)
    _screen_effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _screen_effect_priority = priority
    _screen_effect_deadline_usec = mini(deadline, now + FLASH_MAX_USEC)
    _overlay_layer.add_child(_screen_effect)
    return _screen_effect


func _clear_screen_effect() -> void:
    if is_instance_valid(_screen_effect):
        # Detach immediately: queued controls would still stack this frame.
        _overlay_layer.remove_child(_screen_effect)
        _screen_effect.queue_free()
    _screen_effect = null
    _screen_effect_priority = -1
    _screen_effect_deadline_usec = 0


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
        cancel_hitstop()
        _active_joy_device = -1
        cancel_rumble()


func _exit_tree() -> void:
    cancel_hitstop()
    _clear_camera_shake()
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
