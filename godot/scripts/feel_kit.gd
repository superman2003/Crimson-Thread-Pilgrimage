extends Node
## FeelKit：全局打击感单例（hitstop / trauma 震屏 / 全屏闪帧 / 受击黑屏帧）。
## 规格：docs/spec/20260726160500000_动作特效与打击感设计规格.md §6.3–§6.5
## 访问方式：get_node_or_null("/root/FeelKit")，调用方必须判空，
## 保证 headless 自定义 SceneTree 验证脚本（无 autoload）不受影响。

const HITSTOP_MAX_SECONDS := 0.25
const TRAUMA_DECAY := 2.2
const TRAUMA_AMPLITUDE := 14.0
const TRAUMA_ROTATION_DEG := 0.5
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


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _noise_x.seed = 1937
    _noise_y.seed = 7391
    _overlay_layer = CanvasLayer.new()
    _overlay_layer.name = "FeelKitOverlay"
    _overlay_layer.layer = 90
    add_child(_overlay_layer)


func _process(delta: float) -> void:
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
