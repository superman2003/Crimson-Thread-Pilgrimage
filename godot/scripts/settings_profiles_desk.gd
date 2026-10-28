extends Node
var ui: Control
var model:=preload("res://scripts/settings_profiles.gd").new()
var window: AcceptDialog
var list: ItemList
var detail: RichTextLabel
var name_input: LineEdit
var scope: OptionButton
var confirm: ConfirmationDialog
var selected:=""
var pending: Dictionary={}
var transfer: ConfirmationDialog

static func install(shell: Control) -> void:
    var world: Variant=shell.level.get("world_mode")
    if not world is bool or not world:return
    var desk:=new();desk.name="SettingsProfilesDesk";shell.add_child(desk);desk.setup(shell)

func setup(shell: Control) -> void:
    ui=shell;model.configure()
    var button: Button=ui._button(ui.settings,"设置方案管理",Vector2(802,100),Vector2(170,28),open)
    button.name="SettingsProfilesButton";button.add_theme_font_size_override("font_size",14)

func _build() -> void:
    window=preload("res://scripts/journey_desk_window.gd").new();window.name="SettingsProfilesWindow"
    ui.settings.add_child(window);window.title="命名设置方案";window.bind_overlay(ui,ui.settings)
    window.text(window.column,"最多六套跨旅途共享的阅读、画面、手柄与按键方案。先预览差异再确认；写入失败保留现有设置。",42)
    var columns: HBoxContainer=window.row(window.column)
    list=ItemList.new();list.custom_minimum_size=Vector2(250,260);columns.add_child(list)
    detail=RichTextLabel.new();detail.custom_minimum_size=Vector2(640,260);columns.add_child(detail)
    list.item_selected.connect(func(index: int):selected=String(model.profiles.keys()[index]);_preview())
    var input_row: HBoxContainer=window.row(window.column)
    name_input=window.search(input_row,"方案名称，最多24字",func(_value: String):pass);name_input.max_length=24
    scope=OptionButton.new();input_row.add_child(scope)
    for title_text in ["全部设置与按键","仅阅读画面","仅手柄参数","仅按键"]:scope.add_item(title_text)
    scope.item_selected.connect(func(_index: int):_preview())
    var actions: HBoxContainer=window.row(window.column)
    window.button(actions,"保存当前为新方案",func():manage("save"))
    window.button(actions,"复制所选",func():manage("copy"))
    window.button(actions,"重命名",func():manage("rename"))
    window.button(actions,"更新为当前",func():ask("replace"))
    window.button(actions,"删除所选",func():ask("delete"))
    window.button(window.column,"预览并应用所选范围",func():ask("apply"))
    var sharing: HBoxContainer=window.row(window.column)
    var export_button: Button=window.button(sharing,"导出所选分享码",func():open_transfer("export"))
    export_button.name="ExportSettingsCode"
    var import_button: Button=window.button(sharing,"从分享码创建方案",func():open_transfer("import"))
    import_button.name="ImportSettingsCode"
    window.footer()
    confirm=ConfirmationDialog.new();confirm.title="核对设置方案";confirm.min_size=Vector2i(620,250);window.add_child(confirm)
    ui.register_text_entry_window(confirm)
    confirm.confirmed.connect(_confirm)
    window.visibility_changed.connect(func():
        if not window.visible:
            confirm.hide();pending={}
            if is_instance_valid(transfer):transfer.hide())

func open() -> void:
    if not ui.settings.is_visible_in_tree():return
    if not is_instance_valid(window):_build()
    refresh();window.popup_centered();name_input.grab_focus()

func refresh() -> void:
    list.clear()
    for name in model.profiles:
        list.add_item(String(name))
        if name==selected:list.select(list.item_count-1)
    if list.get_selected_items().is_empty() and list.item_count>0:selected=String(model.profiles.keys()[0]);list.select(0)
    if list.item_count==0:selected=""
    window.status.text="%d/6套。%s" % [model.profiles.size(),model.store.error+model.rejected_summary()]
    _preview()

func _preview() -> void:
    var result: Dictionary=model.quote(selected,ui,scope.selected)
    detail.text=String(result.reason) if not result.ok else "方案「%s」\n\n%s" % [selected,"\n".join(result.lines) if not result.lines.is_empty() else "这个范围与当前设置一致。"]

func manage(command: String) -> void:
    var result: Dictionary=model.manage(command,selected,name_input.text,model.capture(ui))
    if result.ok and command in ["save","copy","rename"]:selected=name_input.text
    refresh();window.status.text=String(result.reason)

func ask(command: String) -> void:
    if selected.is_empty():window.status.text="请选择一套方案。";return
    var quote: Dictionary=model.quote(selected,ui,scope.selected)
    if command=="apply" and not quote.ok:window.status.text=String(quote.reason);return
    pending={"command":command,"name":selected,"scope":scope.selected,"snapshot":model.profiles.get(selected,{}).duplicate(true),"baseline":model.capture(ui)}
    confirm.dialog_text=("应用以下变化？\n"+"\n".join(quote.get("lines",[]))) if command=="apply" else ("删除" if command=="delete" else "用当前设置覆盖")+"方案「"+selected+"」？"
    confirm.dialog_text=confirm.dialog_text.left(1000)
    confirm.popup_centered();confirm.get_cancel_button().grab_focus()

func _confirm() -> void:
    if pending.is_empty() or not ui.settings.is_visible_in_tree():return
    var request:=pending.duplicate(true);pending={}
    var result: Dictionary
    if model.profiles.get(request.name,{})!=request.snapshot or model.capture(ui)!=request.baseline:result={"ok":false,"reason":"方案或当前设置已变化，请重新核对。"}
    elif request.command=="apply":result=model.apply(String(request.name),ui,int(request.scope),request.snapshot)
    else:result=model.manage(String(request.command),String(request.name),"",model.capture(ui))
    refresh();window.status.text=String(result.reason)

func open_transfer(mode: String) -> void:
    if not is_instance_valid(window) or not window.visible or not ui.settings.is_visible_in_tree():return
    if not is_instance_valid(transfer):
        transfer=preload("res://scripts/settings_profile_transfer_dialog.gd").new()
        transfer.name="SettingsProfileTransfer"
        transfer.theme=ui.theme
        window.add_child(transfer)
        ui.register_text_entry_window(transfer)
    var source:=window.find_child("ExportSettingsCode" if mode=="export" else "ImportSettingsCode",true,false) as Control
    if mode=="export":transfer.open_export(self,source)
    else:transfer.open_import(self,source)
