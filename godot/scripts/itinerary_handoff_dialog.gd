extends ConfirmationDialog
const BRIDGE:=preload("res://scripts/itinerary_handoff.gd")
const DIRECTORY:=preload("res://scripts/map_directory_runtime.gd")
var owner_ref: WeakRef
var parent_ref: WeakRef
var payload: Dictionary={}
var pending: Dictionary={}
var parent_changed: Callable
var detail: RichTextLabel
var status: Label
static func open_for(level: Node,parent: Window,candidate: Dictionary) -> Window:
    var old:=parent.get_node_or_null("ItineraryHandoff")
    if old!=null:old.queue_free()
    var dialog:=new();dialog.name="ItineraryHandoff";dialog.owner_ref=weakref(level);dialog.parent_ref=weakref(parent)
    dialog.payload=candidate.duplicate(true);parent.add_child(dialog)
    level.ui_shell.register_text_entry_window(dialog)
    var child_ref: WeakRef=weakref(dialog)
    var host_ref: WeakRef=weakref(parent)
    dialog.parent_changed=func():
        var child: Variant=child_ref.get_ref();var host: Variant=host_ref.get_ref()
        if is_instance_valid(child) and (not is_instance_valid(host) or not host.visible):child.hide()
    parent.visibility_changed.connect(dialog.parent_changed)
    dialog.refresh();dialog.popup_centered();dialog.get_cancel_button().grab_focus()
    return dialog
func _ready() -> void:
    title="将排程安排为行程";min_size=Vector2i(720,530);dialog_hide_on_ok=false
    var column:=VBoxContainer.new();column.add_theme_constant_override("separation",10);add_child(column)
    detail=RichTextLabel.new();detail.custom_minimum_size=Vector2(670,360);detail.bbcode_enabled=false;detail.focus_mode=Control.FOCUS_ALL;column.add_child(detail)
    status=Label.new();status.custom_minimum_size=Vector2(670,70);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(status)
    get_ok_button().text="确认替换并暂停";get_cancel_button().text="保留原行程"
    confirmed.connect(apply)
    visibility_changed.connect(func():
        if not visible:pending.clear();payload.clear();queue_free())
func level() -> Node:
    var node: Variant=owner_ref.get_ref() if owner_ref!=null else null
    return node if is_instance_valid(node) and not node.is_queued_for_deletion() else null
func eligible(node: Node) -> bool:
    var parent: Variant=parent_ref.get_ref() if parent_ref!=null else null
    return node!=null and not node.world_loading and not node.chapter_transitioning and node.active_overlay=="settings" and is_instance_valid(parent) and parent.visible
func refresh() -> void:
    var node:=level()
    if not eligible(node):pending={};detail.text="当前工作台已经关闭或旅途正在切换。";get_ok_button().disabled=true;return
    var desk: Node=node.ui_shell.get_node_or_null("ExpeditionDesk")
    if desk==null:pending={};detail.text="当前旅途尚未准备好行程。";get_ok_button().disabled=true;return
    pending=BRIDGE.quote(payload,DIRECTORY.rows(node),desk.plan,String(node.config.id),String(node.world_save_path))
    detail.text=BRIDGE.describe(pending);status.text="确认后在地图的行程窗口开始；本次不自动开始。"
    get_ok_button().disabled=not pending.get("ok",false)
func apply() -> void:
    if not visible:return
    var node:=level()
    if not eligible(node):status.text="旅途或工作台已变化，未修改行程。";get_ok_button().disabled=true;return
    var desk: Node=node.ui_shell.get_node_or_null("ExpeditionDesk")
    if desk==null:return
    var result:=BRIDGE.apply(payload,DIRECTORY.rows(node),desk.plan,String(node.config.id),String(node.world_save_path),pending)
    if result.ok:
        desk._refresh_hud();status.text=result.reason;get_ok_button().disabled=true;pending.clear()
    else:
        status.text=result.reason+" 原行程保持不变。请关闭后重新预览或重试。";get_ok_button().disabled=true

func _exit_tree() -> void:
    var parent: Variant=parent_ref.get_ref() if parent_ref!=null else null
    if is_instance_valid(parent) and parent.visibility_changed.is_connected(parent_changed):parent.visibility_changed.disconnect(parent_changed)
    pending.clear();payload.clear()
