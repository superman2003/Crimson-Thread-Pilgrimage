extends "res://scripts/journey_desk_window.gd"
const OWNER:=preload("res://scripts/field_receipt_owner.gd")
const LEDGER:=preload("res://scripts/transaction_receipt_ledger.gd")
var owner_ref: WeakRef
var ledger: Variant
var query: LineEdit
var filter_kind: OptionButton
var list: ItemList
var detail: RichTextLabel
var clear_button: Button
var confirm: ConfirmationDialog
var pending_clear:=-1
var shown_generation:=-1
var selected:=-1
var rows: Array=[]
func _ready() -> void:
    super._ready();title="本次运行钟龛收支"
    text(column,"只记录本次运行中材料兑换与巡查结算成功写盘后的资源变化，最多32条；不包含拾取、战斗取线或其他商店，不写入归途存档。",65)
    var filters:=row(column)
    query=search(filters,"搜索已结算物品名称或登记地区",func(_value: String):render())
    filter_kind=OptionButton.new();filters.add_child(filter_kind)
    for label in ["全部结算","包含支出","包含收入"]:filter_kind.add_item(label)
    filter_kind.item_selected.connect(func(_index: int):render())
    var columns:=row(column)
    list=ItemList.new();list.custom_minimum_size=Vector2(300,280);columns.add_child(list)
    list.item_selected.connect(func(index: int):selected=int(rows[index].sequence);show_detail())
    detail=RichTextLabel.new();detail.bbcode_enabled=false;detail.selection_enabled=true
    detail.focus_mode=Control.FOCUS_ALL;detail.custom_minimum_size=Vector2(580,280);columns.add_child(detail)
    var actions:=row(column)
    button(actions,"刷新本次记录",refresh)
    clear_button=button(actions,"清空本次会话全部记录",ask_clear)
    footer()
    confirm=ConfirmationDialog.new();confirm.title="清空本次结算显示";confirm.dialog_hide_on_ok=false
    confirm.min_size=Vector2i(600,200);add_child(confirm)
    confirm.confirmed.connect(confirm_clear)
    confirm.canceled.connect(func():pending_clear=-1)
    visibility_changed.connect(func():
        if not visible:ledger=null;rows=[];list.clear();detail.text="";pending_clear=-1;confirm.hide())
func host_node() -> Node:
    var host: Node=owner_ref.get_ref() if owner_ref!=null else null
    if not is_instance_valid(host) or host.is_queued_for_deletion() or not host.is_inside_tree():return null
    if not is_instance_valid(host.window) or not host.window.visible or not is_instance_valid(host.ui) or not host.ui.build_panel.is_visible_in_tree():return null
    if host.ui.level.world_loading:return null
    return host
func open_for(host: Node) -> void:
    owner_ref=weakref(host)
    if host_node()==null:return
    bind_overlay(host.ui,host.ui.build_panel);host.ui.register_text_entry_window(confirm)
    ledger=OWNER.for_level(host.ui.level);selected=-1;query.clear();filter_kind.select(0)
    render();popup_centered();query.grab_focus()
func refresh() -> void:
    var host:=host_node()
    if host==null:return
    var current: Variant=OWNER.for_level(host.ui.level)
    if current!=ledger:pending_clear=-1;confirm.hide();selected=-1
    ledger=current;render()
func render() -> void:
    var host:=host_node()
    if host==null or ledger==null:return
    var report: Dictionary=ledger.report()
    shown_generation=int(report.generation)
    rows=LEDGER.browse(report,func(id: String):return host.ui.level._item_display_name(id),query.text,filter_kind.selected)
    list.clear();var choice:=0
    for index in rows.size():
        var entry: Dictionary=rows[index]
        list.add_item("第%d笔 · %s" % [entry.sequence,entry.region])
        if int(entry.sequence)==selected:choice=index
    if not rows.is_empty():list.select(choice);selected=int(rows[choice].sequence)
    else:selected=-1
    clear_button.disabled=report.rows.is_empty() and String(report.problem).is_empty()
    status.text="保留%d/32笔，当前筛选%d笔；更早的%d笔已按上限移出。%s" % [report.rows.size(),rows.size(),report.dropped,String(report.problem)]
    show_detail()
func show_detail() -> void:
    if host_node()==null:return
    detail.text="当前没有符合筛选的本次结算记录；预览、取消与保存失败不会登记。"
    for entry in rows:
        if int(entry.sequence)==selected:detail.text=LEDGER.describe(entry);return
func ask_clear() -> void:
    if not visible or host_node()==null or ledger==null:return
    var report: Dictionary=ledger.report();pending_clear=int(report.generation)
    confirm.dialog_text="清空本次运行的全部%d笔结算回执？\n也包含筛选之外的记录。\n不会撤销交易、修改物品或删除归途存档。" % report.rows.size()
    confirm.popup_centered();confirm.get_cancel_button().grab_focus()
func confirm_clear() -> void:
    if not visible or not confirm.visible or host_node()==null or ledger==null or pending_clear<0:return
    var result: Dictionary=ledger.clear(pending_clear);pending_clear=-1;confirm.hide();render();status.text=String(result.reason)
func _process(_delta: float) -> void:
    if not visible:return
    var host:=host_node()
    if host==null:hide();return
    var current: Variant=OWNER.for_level(host.ui.level)
    if current!=ledger:refresh()
    elif ledger!=null and int(ledger.generation)!=shown_generation:render()
