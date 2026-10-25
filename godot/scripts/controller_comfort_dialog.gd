extends ConfirmationDialog
const POLICY = preload("res://scripts/controller_preferences.gd")
var baseline: Dictionary = {}
var candidate: Dictionary = {}
var apply_action: Callable
var deadzone: HSlider
var changes: Label
var device_status: Label
var elapsed := 0.0

func _ready() -> void:
    title = "手柄校准与舒适设置"
    min_size = Vector2i(670,490)
    dialog_hide_on_ok = false
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation",12)
    add_child(column)
    var intro := Label.new()
    intro.text = "只调整摇杆轴死区，不改变扳机、按键或声音。\n预设先列出变化；确认前原设置保持有效。"
    column.add_child(intro)
    device_status = Label.new()
    device_status.custom_minimum_size = Vector2(620,64)
    device_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(device_status)
    var label := Label.new();label.text = "摇杆死区 10%—60%（偏大可抑制漂移，偏小更灵敏）";column.add_child(label)
    deadzone = HSlider.new();deadzone.min_value = 0.1;deadzone.max_value = 0.6;deadzone.step = 0.01
    column.add_child(deadzone)
    deadzone.value_changed.connect(func(value: float):candidate.controller_deadzone = value;_refresh_changes())
    var modes := HBoxContainer.new();column.add_child(modes)
    for row in [["comfort","低闪光与轻震动"],["reading","大字慢字幕"],["controller_default","手柄默认"],["visual_default","阅读画面默认"]]:
        var id: String = row[0]
        var button := Button.new();button.text = row[1];button.add_theme_font_size_override("font_size",13);modes.add_child(button)
        button.pressed.connect(func():choose_preset(id))
    changes = Label.new();changes.custom_minimum_size = Vector2(620,175);changes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;column.add_child(changes)
    get_ok_button().text = "应用这些变化"
    get_cancel_button().text = "保留原设置"
    confirmed.connect(_apply_candidate)

func open(values: Dictionary, action: Callable) -> void:
    baseline = POLICY.normalize(values)
    candidate = baseline.duplicate()
    apply_action = action
    deadzone.set_value_no_signal(float(candidate.controller_deadzone))
    _refresh_changes()
    _refresh_devices()
    popup_centered()
    get_cancel_button().grab_focus()

func choose_preset(id: String) -> void:
    candidate = POLICY.preset(candidate,id)
    deadzone.set_value_no_signal(float(candidate.controller_deadzone))
    _refresh_changes()

func _refresh_changes() -> void:
    var lines: Array[String] = ["当前死区：%d%%" % int(round(float(candidate.controller_deadzone)*100))]
    for key in candidate:
        if baseline.get(key) == candidate[key]:continue
        var before := str(baseline[key]);var after := str(candidate[key])
        if candidate[key] is bool:before = "开" if baseline[key] else "关";after = "开" if candidate[key] else "关"
        lines.append("%s：%s → %s" % [POLICY.LABELS[key],before,after])
    if lines.size() == 1:lines.append("尚无变化。按键、声音、探索提示与导航辅助保持原设置。")
    changes.text = "\n".join(lines)
    get_ok_button().disabled = candidate == baseline

func _process(delta: float) -> void:
    if not visible:return
    elapsed += delta
    if elapsed >= 0.1:elapsed = 0.0;_refresh_devices()

func _refresh_devices() -> void:
    var devices := POLICY.devices()
    var lines: Array[String] = []
    for device in devices.slice(0,2):
        var axes: Array = device.axes
        lines.append("%s · 左(%.2f, %.2f) 右(%.2f, %.2f)" % [String(device.name).left(32),float(axes[0]),float(axes[1]),float(axes[2]),float(axes[3])])
    if devices.size()>2:lines.append("另有%d个已连接手柄。" % (devices.size()-2))
    device_status.text = "未检测到手柄。可以先设置死区；连接后会显示原始摇杆读数。" if lines.is_empty() else "\n".join(lines)

func _apply_candidate() -> void:
    if candidate == baseline or not apply_action.is_valid():return
    var result: Variant = apply_action.call(POLICY.normalize(candidate))
    if result is Dictionary and bool(result.get("ok",false)):hide()
