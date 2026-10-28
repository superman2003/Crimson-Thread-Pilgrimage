extends Node
## One settings-owned dialog. Closing it discards confirmation, never changes route.
var ui: Control
var model:=preload("res://scripts/audio_output_preferences.gd").new()
var window: AcceptDialog
var options: OptionButton
var status: Label
var confirm: ConfirmationDialog
var pending: Dictionary={}
var elapsed:=0.0
var shown: Array[String]=[]

static func install(shell: Control) -> void:
    if shell.has_node("AudioOutputDesk"):return
    var desk:=new();desk.name="AudioOutputDesk";shell.add_child(desk);desk.setup(shell)

func setup(shell: Control) -> void:
    ui=shell;model.initialize()
    # Row 332 already holds the comfort and danger-caption launchers; use the
    # free header space left of the journey workbench entry.
    var launcher: Button=ui._button(ui.settings,"声音输出设备",Vector2(420,60),Vector2(210,30),open)
    launcher.name="AudioOutputDeviceButton";launcher.add_theme_font_size_override("font_size",15)
    window=AcceptDialog.new();window.title="声音输出设备";window.min_size=Vector2i(660,360)
    ui.settings.add_child(window);ui.register_text_entry_window(window)
    var column:=VBoxContainer.new();column.add_theme_constant_override("separation",16);window.add_child(column)
    var explanation:=Label.new();explanation.custom_minimum_size=Vector2(610,90)
    explanation.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    explanation.text="选择此电脑的耳机、扬声器或系统默认输出。切换可能有短暂停顿；不会重开曲目、改音量或修改旅途存档。系统默认会跟随操作系统设置。设备偏好独立保存，不随设置方案或分享码转移。"
    column.add_child(explanation)
    options=OptionButton.new();options.custom_minimum_size=Vector2(610,38)
    options.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;column.add_child(options)
    var actions:=HBoxContainer.new();column.add_child(actions)
    for entry in [["核对并切换",ask],["刷新设备",refresh],["重试保存",retry_save]]:
        var button:=Button.new();button.text=entry[0];button.custom_minimum_size=Vector2(190,36)
        button.pressed.connect(entry[1]);actions.add_child(button)
    status=Label.new();status.custom_minimum_size=Vector2(610,90)
    status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(status)
    confirm=ConfirmationDialog.new();confirm.title="核对声音输出";confirm.min_size=Vector2i(600,220)
    window.add_child(confirm);ui.register_text_entry_window(confirm)
    confirm.confirmed.connect(commit)
    window.visibility_changed.connect(func():
        if not window.visible:pending={};confirm.hide())
    ui.settings.visibility_changed.connect(func():
        if not ui.settings.is_visible_in_tree():window.hide())

func open() -> void:
    if not ui.settings.is_visible_in_tree():return
    pending={};confirm.hide();refresh();window.popup_centered();options.grab_focus()

func _process(delta: float) -> void:
    elapsed+=delta
    if elapsed<1.0:return
    elapsed=0.0
    # Hot-unplug fallback remains active while gameplay continues.
    var view:=model.refresh()
    if is_instance_valid(window) and window.visible:
        if shown!=view.devices:refresh()
        else:_status(view)

func refresh() -> void:
    var previous: String=String(options.get_item_metadata(options.selected)) if options.item_count>0 and options.selected>=0 else model.active()
    var view:=model.refresh();shown.assign(view.devices);options.clear()
    for name in shown:
        options.add_item("系统默认" if name==model.DEFAULT else name)
        options.set_item_metadata(options.item_count-1,name)
    var index:=shown.find(previous)
    if index<0:index=shown.find(String(view.active))
    options.select(maxi(index,0));_status(view)

func _status(view: Dictionary) -> void:
    status.text="当前输出：%s\n%s" % ["系统默认" if view.active==model.DEFAULT else view.active,view.notice]
    if not String(view.save_error).is_empty() and not status.text.contains(String(view.save_error)):
        status.text+="\n"+String(view.save_error)

func ask() -> void:
    if not window.visible or not ui.settings.is_visible_in_tree() or options.selected<0:return
    pending=model.quote(String(options.get_item_metadata(options.selected)))
    if not pending.get("ok",false):status.text=String(pending.get("reason","设备不可用"));return
    confirm.dialog_text="当前：%s\n切换到：%s\n确认后立即切换；取消保持当前输出。" % [pending.before,pending.device]
    confirm.popup_centered();confirm.get_cancel_button().grab_focus()

func commit() -> void:
    if not window.visible or not ui.settings.is_visible_in_tree() or pending.is_empty():return
    var request:=pending.duplicate(true);pending={}
    var result:=model.apply(String(request.device),String(request.fingerprint))
    refresh();status.text=String(result.reason)

func retry_save() -> void:
    if not window.visible or not ui.settings.is_visible_in_tree():return
    var result:=model.save();status.text=String(result.reason)
