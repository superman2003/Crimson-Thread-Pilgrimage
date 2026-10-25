extends Node
const PREFS := preload("res://scripts/controller_preferences.gd")
const KEYS := ["danger_captions","danger_caption_limit","danger_caption_contrast"]
var ui: Control
var window: ConfirmationDialog
var enabled: CheckBox
var contrast: CheckBox
var limit: SpinBox
var status: Label
var baseline: Dictionary={}
var director: Node

static func install(shell: Control) -> void:
    var world: Variant=shell.level.get("world_mode")
    if not world is bool or not world:return
    var desk:=new();desk.name="DangerCaptionDesk";shell.add_child(desk);desk.setup(shell)

func setup(shell: Control) -> void:
    ui=shell
    var button: Button=ui._button(ui.settings,"危险字幕辅助",Vector2(244,332),Vector2(200,32),open)
    button.name="DangerCaptionButton";button.add_theme_font_size_override("font_size",15)
    director=preload("res://scripts/danger_captions.gd").new();director.name="DangerCaptions";ui.level.add_child(director);director.setup(ui.level,ui)

func _build() -> void:
    window=ConfirmationDialog.new();window.title="危险字幕辅助";window.min_size=Vector2i(720,390);window.dialog_hide_on_ok=false;ui.settings.add_child(window);ui.register_text_entry_window(window)
    var column:=VBoxContainer.new();column.add_theme_constant_override("separation",12);window.add_child(column)
    var intro:=Label.new();intro.text="只显示屏幕内、无遮挡、正在前摇的敌人。\n提示相对方向、攻击类别与不可格挡状态；不展示未知名称或下一招。\n前摇中断、敌人死亡、遮挡、出屏或打开菜单时立即撤下。";intro.custom_minimum_size=Vector2(670,100);column.add_child(intro)
    enabled=CheckBox.new();enabled.text="启用危险字幕（默认关闭）";column.add_child(enabled)
    contrast=CheckBox.new();contrast.text="深色高对比背景";column.add_child(contrast)
    var row:=HBoxContainer.new();column.add_child(row);var label:=Label.new();label.text="同时显示条数（优先不可格挡与 Boss）";row.add_child(label)
    limit=SpinBox.new();limit.min_value=1;limit.max_value=3;limit.step=1;row.add_child(limit)
    status=Label.new();status.text="字号跟随字幕字号；可随设置方案保存和切换。";column.add_child(status)
    window.get_ok_button().text="保存这些设置";window.get_cancel_button().text="保留原设置"
    window.confirmed.connect(apply)
    ui.settings.visibility_changed.connect(func():
        if not ui.settings.is_visible_in_tree():window.hide())

func open() -> void:
    if not ui.settings.is_visible_in_tree():return
    if not is_instance_valid(window):_build()
    baseline=PREFS.normalize(ui.accessibility);enabled.button_pressed=baseline.danger_captions;contrast.button_pressed=baseline.danger_caption_contrast;limit.value=baseline.danger_caption_limit
    status.text="字号跟随字幕字号；可随设置方案保存和切换。"
    window.popup_centered();window.get_cancel_button().grab_focus()

func apply() -> void:
    if not window.visible or not ui.settings.is_visible_in_tree():return
    var current:=PREFS.normalize(ui.accessibility)
    for key in KEYS:
        if current[key]!=baseline[key]:status.text="原设置已经变化，请关闭后重新打开。";return
    var values:=PREFS.normalize({"danger_captions":enabled.button_pressed,"danger_caption_contrast":contrast.button_pressed,"danger_caption_limit":limit.value})
    var config:=ConfigFile.new();config.load(ui.accessibility_path)
    for key in KEYS:config.set_value("accessibility",key,values[key])
    var temporary: String=ui.accessibility_path+".danger.tmp"
    var saved:=config.save(temporary)
    if saved==OK:saved=DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(ui.accessibility_path))
    if saved!=OK:status.text="设置未写入，原设置保持有效，可重试。";return
    for key in KEYS:ui.accessibility[key]=values[key]
    ui._apply_accessibility();window.hide()
