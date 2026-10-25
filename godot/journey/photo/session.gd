extends Node
signal captured(record: Dictionary)
signal finished
const UI := preload("res://journey/core/ui.gd")
const V := preload("res://journey/core/values.gd")
const GUIDES := preload("res://journey/photo/guides.gd")
var owner_ref: WeakRef
var original_camera_ref: WeakRef
var original_mode := Node.PROCESS_MODE_INHERIT
var original_ui := true
var original_enabled := true
var camera: Camera2D
var controls: Window
var status: Label
var layer: CanvasLayer
var guides: Control
var filter_rect: ColorRect
var active := false
var capturing := false
var directory := "user://journey_workbench/photos"
var frame_origin := Vector2.ZERO
var base_zoom := Vector2.ONE
var pan := Vector2.ZERO
var options := {"zoom":1.0, "exposure":1.0, "saturation":1.0, "warmth":0.0, "guides":"thirds", "letterbox":false, "include_guides":false}
var capture_context: Dictionary = {}
var value_controls: Dictionary = {}
const MAX_PHOTOS := 40
const MAX_TOTAL_BYTES := 134217728

func begin(owner: Node, snapshot: Dictionary) -> Dictionary:
    if active or not is_instance_valid(owner) or not bool(owner.get("initial_region_ready")):
        return {"ok":false, "reason":"拍照场景尚未就绪。"}
    if String(owner.get("active_overlay")) != "settings" or bool(owner.get("world_loading")) or bool(owner.get("chapter_transitioning")):
        return {"ok":false, "reason":"请从稳定旅途的设置页进入拍照。"}
    var original: Camera2D = owner.player.get_node_or_null("Camera2D")
    if original == null:
        return {"ok":false, "reason":"当前场景没有可用镜头。"}
    owner_ref = weakref(owner)
    original_camera_ref = weakref(original)
    original_mode = owner.process_mode
    original_ui = owner.ui_shell.visible
    original_enabled = original.enabled
    capture_context = snapshot.duplicate(true)
    frame_origin = original.get_screen_center_position()
    base_zoom = original.zoom
    process_mode = Node.PROCESS_MODE_ALWAYS
    owner.process_mode = Node.PROCESS_MODE_DISABLED
    owner.ui_shell.visible = false
    original.enabled = false
    camera = Camera2D.new()
    camera.position_smoothing_enabled = false
    camera.global_position = frame_origin
    camera.zoom = base_zoom
    add_child(camera)
    camera.make_current()
    layer = CanvasLayer.new()
    layer.layer = 50
    add_child(layer)
    filter_rect = ColorRect.new()
    filter_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    filter_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var material := ShaderMaterial.new()
    material.shader = preload("res://journey/photo/filter.gdshader")
    filter_rect.material = material
    layer.add_child(filter_rect)
    guides = GUIDES.new()
    layer.add_child(guides)
    _toolbar()
    active = true
    _apply()
    controls.popup_centered(Vector2i(480, 600))
    return {"ok":true, "reason":"拍照模式已暂停当前世界；退出后恢复原镜头与界面。"}

func _toolbar() -> void:
    controls = Window.new()
    controls.title = "巡礼拍照 · 世界暂停"
    controls.min_size = Vector2i(440, 520)
    controls.size = Vector2i(480, 600)
    controls.transient = true
    controls.exclusive = false
    add_child(controls)
    controls.close_requested.connect(end)
    controls.window_input.connect(_controls_input)
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 12)
    controls.add_child(margin)
    var outer := UI.column(margin, true)
    var column := UI.scroll(outer)
    UI.label(column, "巡礼拍照", true)
    UI.hint(column, "拖动游戏画面平移，滚轮调整镜头；控制窗口不会写进照片。世界与角色保持暂停。")
    for definition in [["zoom", "镜头倍率", 1.0, 2.0, 0.1], ["exposure", "曝光", 0.5, 1.8, 0.1], ["saturation", "饱和度", 0.0, 1.5, 0.1], ["warmth", "冷暖", -0.3, 0.3, 0.05]]:
        var row := UI.row(column)
        UI.label(row, String(definition[1]))
        var control := UI.spin(row, float(options[definition[0]]), float(definition[2]), float(definition[3]), float(definition[4]))
        var key := String(definition[0])
        value_controls[key] = control
        control.value_changed.connect(func(value: float):options[key] = value;_apply())
    var picker := UI.pick(column, [{"id":"none", "name":"无构图线"}, {"id":"thirds", "name":"三分线"}, {"id":"center", "name":"中心十字"}], String(options.guides))
    picker.item_selected.connect(func(_index: int):options.guides = UI.chosen(picker);_apply())
    UI.toggle(column, "电影画幅遮幅", bool(options.letterbox), func(value: bool):options.letterbox = value;_apply())
    UI.toggle(column, "照片保留构图线", bool(options.include_guides), func(value: bool):options.include_guides = value)
    var directions := UI.row(column)
    UI.button(directions, "←", func():pan.x -= 100;_apply())
    UI.button(directions, "↑", func():pan.y -= 100;_apply())
    UI.button(directions, "↓", func():pan.y += 100;_apply())
    UI.button(directions, "→", func():pan.x += 100;_apply())
    UI.button(column, "复位镜头与色调", reset)
    status = UI.hint(column, "照片保存在游戏用户目录；不会上传或分享。")
    UI.button(outer, "保存照片", capture)
    UI.button(outer, "退出拍照并恢复旅途", end)

func _apply() -> void:
    if not is_instance_valid(camera):
        return
    var zoom_value := clampf(float(options.zoom), 1.0, 2.0)
    var original_half := Vector2(get_tree().root.size) / base_zoom * 0.5
    var current_half := original_half / zoom_value
    var allowance := (original_half - current_half).max(Vector2.ZERO)
    pan = pan.clamp(-allowance, allowance)
    camera.global_position = frame_origin + pan
    camera.zoom = base_zoom * zoom_value
    camera.force_update_scroll()
    if is_instance_valid(guides):
        guides.mode = String(options.guides)
        guides.letterbox = bool(options.letterbox)
        guides.queue_redraw()
    if is_instance_valid(filter_rect):
        var material := filter_rect.material as ShaderMaterial
        material.set_shader_parameter("exposure", float(options.exposure))
        material.set_shader_parameter("saturation", float(options.saturation))
        material.set_shader_parameter("warmth", float(options.warmth))

func reset() -> void:
    pan = Vector2.ZERO
    options.zoom = 1.0
    options.exposure = 1.0
    options.saturation = 1.0
    options.warmth = 0.0
    for key in value_controls:
        if is_instance_valid(value_controls[key]):
            value_controls[key].set_value_no_signal(float(options[key]))
    _apply()
    if is_instance_valid(status):
        status.text = "已复位镜头与色调；数值控件下次进入时同步。"

func _input(event: InputEvent) -> void:
    if not active or capturing:
        return
    if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        pan -= event.relative / camera.zoom
        _apply()
    elif event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            options.zoom = minf(2.0, float(options.zoom) * 1.1)
            _apply()
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            options.zoom = maxf(1.0, float(options.zoom) / 1.1)
            _apply()

func capacity() -> Dictionary:
    var count := 0
    var bytes := 0
    if not DirAccess.dir_exists_absolute(directory):
        return {"count":0, "bytes":0, "available":true}
    for name in DirAccess.get_files_at(directory):
        if not name.ends_with(".png"):
            continue
        var file := FileAccess.open(directory.path_join(name), FileAccess.READ)
        if file != null:
            count += 1
            bytes += file.get_length()
            file.close()
    return {"count":count, "bytes":bytes, "available":count < MAX_PHOTOS and bytes < MAX_TOTAL_BYTES}

func capture() -> void:
    if not active or capturing:
        return
    if DisplayServer.get_name() == "headless":
        status.text = "照片需要实际渲染窗口；当前仅能验证拍照生命周期。"
        return
    if not capacity().available:
        status.text = "照片达到40张或128MiB上限，请在相册中先整理。"
        return
    if DirAccess.make_dir_recursive_absolute(directory) != OK:
        status.text = "无法建立照片目录。"
        return
    capturing = true
    controls.hide()
    guides.visible = bool(options.include_guides) or bool(options.letterbox)
    var previous_mode: String = guides.mode
    if not options.include_guides:
        guides.mode = "none"
        guides.queue_redraw()
    await RenderingServer.frame_post_draw
    if not active or not is_inside_tree():
        return
    var image := get_tree().root.get_texture().get_image()
    var stem := "pilgrimage_" + str(Time.get_unix_time_from_system()).replace(".", "_") + "_" + str(Time.get_ticks_usec())
    var path := directory.path_join(stem + ".png")
    var suffix := 0
    while FileAccess.file_exists(path):
        suffix += 1
        path = directory.path_join(stem + "_" + str(suffix) + ".png")
    var saved := image.save_png(path)
    if saved == OK and FileAccess.file_exists(path):
        var total := capacity()
        if int(total.bytes) > MAX_TOTAL_BYTES or int(total.count) > MAX_PHOTOS:
            DirAccess.remove_absolute(path)
            saved = ERR_OUT_OF_MEMORY
    if saved == OK and FileAccess.file_exists(path):
        var record := {"path":path, "sha256":FileAccess.get_sha256(path), "created":int(Time.get_unix_time_from_system()), "region":String(capture_context.get("region_name", "")), "room":String(capture_context.get("room", "")), "width":image.get_width(), "height":image.get_height(), "options":options.duplicate(true)}
        captured.emit(record)
        status.text = "已保存 " + ProjectSettings.globalize_path(path)
    else:
        status.text = "照片保存失败；旅途仍暂停，可重试。"
    guides.mode = previous_mode
    guides.visible = true
    guides.queue_redraw()
    controls.show()
    capturing = false

func end() -> void:
    if not active:
        return
    active = false
    capturing = false
    var original: Camera2D = original_camera_ref.get_ref() if original_camera_ref != null else null
    if is_instance_valid(original):
        original.enabled = original_enabled
        if original_enabled:
            original.make_current()
            original.force_update_scroll()
    var owner: Node = owner_ref.get_ref() if owner_ref != null else null
    if is_instance_valid(owner) and not owner.is_queued_for_deletion():
        owner.process_mode = original_mode
        if is_instance_valid(owner.get("ui_shell")):
            owner.ui_shell.visible = original_ui
    for node in [camera, controls, layer]:
        if is_instance_valid(node):
            node.queue_free()
    camera = null
    controls = null
    layer = null
    finished.emit()

func _exit_tree() -> void:
    end()

func _controls_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel") and not capturing:
        end()
