extends Node
## Explicit per-slot bookmarks; ordinary journal scrolling stays session-only.
const STORE:=preload("res://scripts/journal_mark_store.gd")
var host_ref: WeakRef
var model:=STORE.new()
var launcher: Button
var window: AcceptDialog
var description: Label
var save_button: Button
var restore_button: Button
var remove_button: Button
var retry_button: Button
var active_document: Dictionary={}
var active_scope:=""
var active_generation:=-1

static func install(ui: Control) -> void:
    if ui.has_node("JournalMarkDesk"):return
    var desk:=new();desk.name="JournalMarkDesk";desk.host_ref=weakref(ui);ui.add_child(desk)
    desk.launcher=ui._button(ui.bag,"阅读位置标记",Vector2(310,99),Vector2(185,30),desk.open)
    desk.launcher.name="JournalMarkButton";desk.launcher.add_theme_font_size_override("font_size",14)
    desk.launcher.tooltip_text="在旅记中选择一条已知记录，显式保存或恢复阅读位置；不改变已读状态。"
    ui.bag.visibility_changed.connect(desk._owner_changed)
    desk.refresh_launcher()

func _host() -> Control:
    var ui: Control=host_ref.get_ref() if host_ref!=null else null
    return ui if is_instance_valid(ui) and ui.is_inside_tree() and not ui.is_queued_for_deletion() else null

func _available(ui: Control) -> bool:
    return ui!=null and ui.bag.is_visible_in_tree() and ui.bag_category=="旅记" and not ui.journal_current_document.is_empty() and not ui.journal_restore_pending

func refresh_launcher() -> void:
    var ui:=_host()
    if is_instance_valid(launcher):launcher.disabled=not _available(ui)
    if is_instance_valid(window) and window.visible and not _owned():window.hide()

func _owner_changed() -> void:
    refresh_launcher()

func _build(ui: Control) -> void:
    window=AcceptDialog.new();window.name="JournalMarkWindow";window.title="旅记阅读位置标记";window.min_size=Vector2i(700,330)
    ui.bag.add_child(window);ui.register_text_entry_window(window);window.get_ok_button().text="返回旅记"
    var column:=VBoxContainer.new();column.custom_minimum_size.x=650;column.add_theme_constant_override("separation",12);window.add_child(column)
    description=Label.new();description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;description.custom_minimum_size=Vector2(640,160);column.add_child(description)
    var actions:=HBoxContainer.new();actions.add_theme_constant_override("separation",8);column.add_child(actions)
    save_button=_button(actions,"保存当前位置",save_position)
    restore_button=_button(actions,"恢复已存位置",restore_position)
    remove_button=_button(actions,"删除这条标记",remove_mark)
    retry_button=_button(actions,"重试保存",retry)
    _button(column,"重读标记文件（放弃待保存操作）",reload_marks)

func _button(parent: Node, title: String, callback: Callable) -> Button:
    var button:=Button.new();button.text=title;button.custom_minimum_size.y=34;button.pressed.connect(callback);parent.add_child(button);return button

func open() -> void:
    var ui:=_host()
    if not _available(ui):return
    if not is_instance_valid(window):_build(ui)
    active_scope=String(ui.level.world_save_path);active_generation=int(ui.reading_session_generation)
    active_document=ui.journal_current_document.duplicate(true)
    model.configure(active_scope)
    _describe("");window.popup_centered();window.get_ok_button().grab_focus()

func _owned() -> bool:
    var ui:=_host()
    return _available(ui) and String(ui.level.world_save_path)==active_scope and int(ui.reading_session_generation)==active_generation and ui.journal_current_document.get("key")==active_document.get("key") and ui.journal_current_document.get("fingerprint")==active_document.get("fingerprint")

func _layout() -> Dictionary:
    var ui:=_host()
    if ui==null:return {}
    var body: RichTextLabel=ui.bag_description
    var bar:=body.get_v_scroll_bar()
    return {"offset":maxf(0,bar.value),"maximum":maxf(0,bar.max_value-bar.page),"width":body.size.x,"font":float(body.get_theme_font_size("normal_font_size"))}

func _position() -> Dictionary:
    var layout:=_layout()
    if layout.is_empty():return {"ok":false,"reason":"阅读内容已关闭。"}
    return model.position(active_document,layout.maximum,layout.width,layout.font)

func _describe(message: String) -> void:
    if not is_instance_valid(window):return
    var position:=_position()
    description.text=String(active_document.get("title","当前记录"))+"\n\n仅存本机当前槽的内容指纹与位置；下次启动后可显式恢复。内容变化时不恢复旧位置，版式变化时按原比例定位。不会标为已读、收藏、推进剧情或写旅途存档。\n\n"+String(position.reason)
    if not message.is_empty():description.text+="\n"+message
    if not model.error.is_empty() and model.error!=message:description.text+="\n"+model.error
    save_button.disabled=not model.writable or model.has_pending
    restore_button.disabled=not position.ok
    remove_button.disabled=not model.writable or model.has_pending or not model.records.has(active_document.get("key"))
    retry_button.disabled=not model.has_pending or not model.writable

func save_position() -> void:
    if not is_instance_valid(window) or not window.visible or not _owned():return
    var value:=_layout()
    _describe(String(model.capture(active_document,value.offset,value.maximum,value.width,value.font).reason))

func restore_position() -> void:
    if not is_instance_valid(window) or not window.visible or not _owned():return
    var result:=_position()
    if not result.ok:_describe(String(result.reason));return
    var ui:=_host();window.hide()
    ui.journal_restore_pending=true
    ui._restore_journal_scroll(String(active_document.key),String(ui.bag_description.text),float(result.offset),active_generation)

func remove_mark() -> void:
    if is_instance_valid(window) and window.visible and _owned():_describe(String(model.remove(active_document).reason))

func retry() -> void:
    if is_instance_valid(window) and window.visible and _owned():_describe(String(model.retry().reason))

func reload_marks() -> void:
    if not is_instance_valid(window) or not window.visible or not _owned():return
    model.configure(active_scope,true);_describe("已重读标记文件；待保存操作已放弃。")
