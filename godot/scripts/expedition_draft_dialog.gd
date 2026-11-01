extends "res://scripts/journey_desk_window.gd"
const LIB:=preload("res://scripts/expedition_draft_library.gd")
const DIRECTORY:=preload("res://scripts/map_directory_runtime.gd")
var owner_ref: WeakRef
var model:=LIB.new()
var names: ItemList
var name_input: LineEdit
var preview: RichTextLabel
var confirm: ConfirmationDialog
var selected:=""
var scope:=""
var pending: Dictionary={}

func _ready() -> void:
    super._ready();title="具名行程草案"
    text(column,"保存最多8份站点顺序草案，每份1至6站。载入会替换当前站序，清除该行程勾选/暂缓并保持暂停；不传送或补绘。",54)
    name_input=search(column,"新草案名（1至24字）",func(_value: String):_clear_pending())
    name_input.max_length=24
    var panels:=row(column)
    names=ItemList.new();names.custom_minimum_size=Vector2(280,230);panels.add_child(names)
    names.item_selected.connect(func(index: int):selected=String(names.get_item_metadata(index));_clear_pending();_describe())
    preview=RichTextLabel.new();preview.custom_minimum_size=Vector2(600,230);preview.bbcode_enabled=false;panels.add_child(preview)
    var actions:=row(column)
    button(actions,"保存当前站序为新草案",save_new)
    button(actions,"预览并确认载入",ask_restore)
    button(actions,"删除所选草案",ask_remove)
    button(actions,"重读草案文件",reload)
    footer()
    confirm=ConfirmationDialog.new();confirm.dialog_hide_on_ok=false;confirm.title="核对行程草案操作";confirm.min_size=Vector2i(650,270)
    confirm.get_label().autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;confirm.get_label().custom_minimum_size.x=580
    add_child(confirm);confirm.confirmed.connect(_confirm);confirm.canceled.connect(_clear_pending)
    visibility_changed.connect(func():
        if not visible:_clear_pending())

func _owner() -> Node:
    var host: Node=owner_ref.get_ref() if owner_ref!=null else null
    if not is_instance_valid(host) or host.is_queued_for_deletion() or not host.is_inside_tree():return null
    if not is_instance_valid(host.ui) or not is_instance_valid(host.ui.level):return null
    if not is_instance_valid(host.window) or not host.window.visible:return null
    if host.ui.level.active_overlay!="map" or host.ui.level.world_loading:return null
    return host

func _owned() -> Node:
    var host:=_owner()
    return host if host!=null and String(host.ui.level.world_save_path)==scope else null

func open_for(host: Node) -> void:
    owner_ref=weakref(host)
    if _owner()==null:return
    scope=String(host.ui.level.world_save_path);model.configure(scope)
    bind_overlay(host.ui,host.ui.level.map_panel)
    host.ui.register_text_entry_window(confirm)
    _clear_pending();refresh();popup_centered();name_input.grab_focus()

func _clear_pending() -> void:
    pending={}
    if is_instance_valid(confirm):confirm.hide()

func refresh() -> void:
    names.clear()
    var keys:=model.drafts.keys();keys.sort()
    for name in keys:
        names.add_item(String(name)+" · %d站" % model.drafts[name].size())
        names.set_item_metadata(names.item_count-1,name)
        if name==selected:names.select(names.item_count-1)
    if not model.drafts.has(selected):selected=""
    if selected.is_empty() and names.item_count>0:selected=String(names.get_item_metadata(0));names.select(0)
    _describe()
    status.text="%d / 8份草案。%s" % [model.drafts.size(),model.error]

func _describe() -> void:
    var host:=_owned()
    if host==null:return
    var quote:=model.quote_restore(selected,host.plan.state,DIRECTORY.rows(host.ui.level))
    preview.text=String(quote.reason)
    if quote.ok:preview.text+="\n\n"+"\n".join(quote.labels)

func save_new() -> void:
    var host:=_owned()
    if not visible or host==null:return
    _clear_pending()
    var result:=model.save_new(name_input.text,host.plan.state,DIRECTORY.rows(host.ui.level))
    if result.ok:selected=name_input.text
    refresh();status.text=String(result.reason)

func ask_restore() -> void:
    var host:=_owned()
    if not visible or host==null:return
    var quote:=model.quote_restore(selected,host.plan.state,DIRECTORY.rows(host.ui.level))
    if not quote.ok:status.text=String(quote.reason);return
    pending={"action":"restore","name":selected,"fingerprint":quote.fingerprint}
    confirm.dialog_text=String(quote.reason)+"\n\n将载入："+selected+"\n"+"\n".join(quote.labels)
    confirm.popup_centered();confirm.get_cancel_button().grab_focus()

func ask_remove() -> void:
    if not visible or _owned()==null or not model.drafts.has(selected):return
    pending={"action":"remove","name":selected,"fingerprint":model.source_hash}
    confirm.dialog_text="删除草案「%s」？只删除这份具名站序，不改变当前行程或实际进度。" % selected
    confirm.popup_centered();confirm.get_cancel_button().grab_focus()

func _confirm() -> void:
    var host:=_owned()
    if not visible or not confirm.visible or host==null or pending.is_empty():return
    var request:=pending.duplicate();_clear_pending()
    if selected!=request.name:status.text="选择已变化，请重新核对。";return
    var result: Dictionary=model.restore(request.name,request.fingerprint,host.plan,DIRECTORY.rows(host.ui.level)) if request.action=="restore" else model.remove(request.name,request.fingerprint)
    if result.ok and request.action=="restore":host.refresh()
    refresh();status.text=String(result.reason)

func reload() -> void:
    if not visible or _owned()==null:return
    _clear_pending();model.configure(scope,true);refresh()
