extends ConfirmationDialog
const POLICY = preload("res://scripts/controller_preferences.gd")
var baseline: Dictionary = {}
var candidate: Dictionary = {}
var apply_action: Callable
var deadzone: HSlider
var changes: Label
var device_status: Label
var device_picker: OptionButton
var response_preview: Control
var device_ids: Array=[]
var elapsed := 0.0

func _ready() -> void:
    title = "手柄校准与舒适设置"
    min_size = Vector2i(720,620)
    dialog_hide_on_ok = false
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation",8)
    add_child(column)
    var intro := Label.new()
    intro.text = "只调整摇杆轴死区，不改变扳机、按键或声音。\n预设先列出变化；确认前原设置保持有效。"
    column.add_child(intro)
    device_picker=OptionButton.new();column.add_child(device_picker)
    device_picker.item_selected.connect(func(_index: int):_refresh_devices())
    device_status = Label.new()
    device_status.custom_minimum_size = Vector2(620,40)
    device_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(device_status)
    response_preview=preload("res://scripts/stick_response_meter.gd").new()
    response_preview.custom_minimum_size=Vector2(660,120);column.add_child(response_preview)
    var legend:=Label.new();legend.text="灰区：暂存死区 · 白点：原始轴 · 金点：逐轴预估\n预估仅展示普通摇杆轴；实际动作还取决于改键，扳机与菜单保留原规则。";legend.add_theme_font_size_override("font_size",13);column.add_child(legend)
    var label := Label.new();label.text = "摇杆死区 10%—60%（偏大可抑制漂移，偏小更灵敏）";column.add_child(label)
    deadzone = HSlider.new();deadzone.min_value = 0.1;deadzone.max_value = 0.6;deadzone.step = 0.01
    column.add_child(deadzone)
    deadzone.value_changed.connect(func(value: float):candidate.controller_deadzone = value;_refresh_changes())
    var modes := HBoxContainer.new();column.add_child(modes)
    for row in [["comfort","低闪光与轻震动"],["reading","大字慢字幕"],["controller_default","手柄默认"],["visual_default","阅读画面默认"]]:
        var id: String = row[0]
        var button := Button.new();button.text = row[1];button.add_theme_font_size_override("font_size",13);modes.add_child(button)
        button.pressed.connect(func():choose_preset(id))
    var changes_scroll:=ScrollContainer.new();changes_scroll.custom_minimum_size=Vector2(660,135);changes_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;column.add_child(changes_scroll)
    changes = Label.new();changes.custom_minimum_size = Vector2(630,0);changes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;changes_scroll.add_child(changes)
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
    var next_ids: Array=[]
    for device in devices:next_ids.append(device.id)
    if next_ids!=device_ids:
        var previous: Variant=device_picker.get_selected_metadata() if device_picker.selected>=0 else null
        device_picker.clear();device_ids=next_ids
        for device in devices:
            device_picker.add_item("%s · 设备 %d" % [String(device.name).left(32),int(device.id)])
            var index:=device_picker.item_count-1
            device_picker.set_item_metadata(index,device.id)
            if device.id==previous:device_picker.select(index)
    device_picker.disabled=devices.is_empty()
    var selected: Dictionary={}
    for device in devices:
        if device.id==device_picker.get_selected_metadata():selected=device;break
    var values: Array=selected.get("axes",[])
    response_preview.update_sample(values,float(candidate.get("controller_deadzone",0.2)))
    device_status.text="未检测到手柄。可以先设置死区；连接后显示原始轴与预估响应。" if selected.is_empty() else "已连接 %d 个手柄，当前查看设备 %d；松开摇杆观察漂移，再推动查看行程。" % [devices.size(),int(selected.id)]

func _apply_candidate() -> void:
    if candidate == baseline or not apply_action.is_valid():return
    var result: Variant = apply_action.call(POLICY.normalize(candidate))
    if result is Dictionary and bool(result.get("ok",false)):hide()
