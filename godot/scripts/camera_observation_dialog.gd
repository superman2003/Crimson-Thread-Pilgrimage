extends Node
const POLICY:=preload("res://scripts/camera_observation_preferences.gd")
var ui: Control
var window: ConfirmationDialog
var mode_picker: OptionButton
var delay_slider: HSlider
var distance_slider: HSlider
var summary: Label
var notice: Label
var candidate: Dictionary={}
var baseline: Dictionary={}
var launcher: Button
static func install(shell: Control) -> void:
    if shell.has_node("CameraObservationDesk"):return
    var desk:=new();desk.name="CameraObservationDesk";shell.add_child(desk);desk.setup(shell)
func setup(shell: Control) -> void:
    ui=shell
    var row: Dictionary=ui.accessibility_controls.camera_lookahead
    row.label.hide()
    launcher=ui._button(ui.settings,"前瞻 / 观察  "+str(ui.accessibility.camera_lookahead),Vector2(512,238),Vector2(176,28),open)
    launcher.name="CameraObservationButton";launcher.add_theme_font_size_override("font_size",14)
    launcher.tooltip_text="打开主动观察设置；右侧滑条仍调整自动前瞻。"
    row.label=launcher;row.title="前瞻 / 观察"
    window=ConfirmationDialog.new();window.name="CameraObservationWindow";window.title="主动观察镜头";window.min_size=Vector2i(680,470)
    window.dialog_hide_on_ok=false;ui.settings.add_child(window);ui.register_text_entry_window(window)
    var column:=VBoxContainer.new();column.add_theme_constant_override("separation",12);window.add_child(column)
    var intro:=Label.new();intro.custom_minimum_size=Vector2(630,64);intro.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    intro.text="自动前瞻和静止主动观察可分别控制。独立模式允许关闭自动前瞻后继续观察高处和下方。确认前不改变当前镜头。";column.add_child(intro)
    mode_picker=OptionButton.new();mode_picker.name="ObservationMode";column.add_child(mode_picker)
    for label in POLICY.MODES:mode_picker.add_item(label)
    mode_picker.item_selected.connect(func(value: int):candidate.observation_mode=value;refresh())
    delay_slider=slider(column,"持续按住的等待时间：0.15—1.00 秒",0.15,1.0,0.05,"observation_delay")
    distance_slider=slider(column,"观察距离：标准距离的 25%—100%",0.25,1.0,0.05,"observation_distance")
    summary=Label.new();summary.custom_minimum_size=Vector2(630,100);summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(summary)
    var reset:=Button.new();reset.text="暂存原版观察规则";column.add_child(reset);reset.pressed.connect(func():candidate=POLICY.DEFAULTS.duplicate();sync())
    notice=Label.new();notice.custom_minimum_size=Vector2(630,65);notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(notice)
    window.get_ok_button().text="确认并保存";window.confirmed.connect(apply)
    window.visibility_changed.connect(func():
        if not window.visible:candidate.clear();baseline.clear();notice.text="")
    ui.settings.visibility_changed.connect(func():
        if not ui.settings.visible:window.hide())
func slider(column: VBoxContainer,label_text: String,minimum: float,maximum: float,increment: float,key: String) -> HSlider:
    var label:=Label.new();label.text=label_text;column.add_child(label)
    var control:=HSlider.new();control.min_value=minimum;control.max_value=maximum;control.step=increment;column.add_child(control)
    control.value_changed.connect(func(value: float):candidate[key]=value;refresh())
    return control
func open() -> void:
    if not ui.settings.is_visible_in_tree():return
    baseline=POLICY.normalize(ui.accessibility);candidate=baseline.duplicate();sync()
    notice.text="只保存本机观察偏好，不随命名方案或分享码转移；不修改存档、输入或角色速度。"
    window.popup_centered();window.get_cancel_button().grab_focus()
func sync() -> void:
    mode_picker.select(candidate.observation_mode)
    delay_slider.set_value_no_signal(candidate.observation_delay)
    distance_slider.set_value_no_signal(candidate.observation_distance)
    refresh()
func refresh() -> void:
    summary.text=POLICY.describe(candidate,float(ui.accessibility.camera_lookahead))
    delay_slider.editable=candidate.observation_mode!=2;distance_slider.editable=delay_slider.editable
    window.get_ok_button().disabled=candidate==baseline
func apply() -> void:
    if not window.visible or not ui.settings.is_visible_in_tree():return
    if POLICY.normalize(ui.accessibility)!=baseline:
        notice.text="当前观察设置已改变，请关闭后重新打开再确认。";window.get_ok_button().disabled=true;return
    for key in candidate:ui.accessibility[key]=candidate[key]
    ui._apply_accessibility()
    var saved: Error=ui._save_accessibility()
    baseline=candidate.duplicate();refresh()
    if saved==OK:notice.text="观察偏好已保存。取消或关闭不会撤销本次确认。"
    else:notice.text="本次观察偏好已生效，但尚未保存。关闭此窗口后可用设置页的重试保存；原文件保留。"
