extends "res://scripts/journey_desk_window.gd"
const MODEL:=preload("res://scripts/known_wish_manifest.gd")
const SOURCES:=preload("res://scripts/known_wish_sources.gd")
var owner_ref: WeakRef
var report: Dictionary={}
var query: LineEdit
var view_mode: OptionButton
var region: OptionButton
var region_ids: Array=[]
var list: ItemList
var detail: RichTextLabel
var summary: RichTextLabel
var preserve: CheckButton
var visible_rows: Array=[]
var selected:=""
func _ready() -> void:
    super._ready();title="已询问心愿交付清单"
    text(column,"只列已经询问或完成的交付心愿，以及本旅途已到地区；这里不交付、不取回礼，也不更改追踪目标。",48)
    var filters:=row(column)
    query=search(filters,"搜索已知人物、地区或所需信物",func(_value: String):render())
    view_mode=OptionButton.new();filters.add_child(view_mode)
    for label in ["未完成","信物已备齐","尚缺或库存待核对","已完成"]:view_mode.add_item(label)
    view_mode.item_selected.connect(func(_index: int):render())
    region=OptionButton.new();filters.add_child(region)
    region.item_selected.connect(func(_index: int):render())
    var columns:=row(column)
    list=ItemList.new();list.custom_minimum_size=Vector2(300,200);columns.add_child(list)
    list.item_selected.connect(func(index: int):selected=String(visible_rows[index].key);show_detail())
    detail=RichTextLabel.new();detail.bbcode_enabled=false;detail.selection_enabled=true
    detail.focus_mode=Control.FOCUS_ALL;detail.custom_minimum_size=Vector2(580,200);columns.add_child(detail)
    preserve=CheckButton.new();preserve.text="消耗后另留一份可出示信物";column.add_child(preserve)
    preserve.toggled.connect(func(_value: bool):render_totals())
    summary=RichTextLabel.new();summary.bbcode_enabled=false;summary.selection_enabled=true
    summary.focus_mode=Control.FOCUS_ALL;summary.custom_minimum_size=Vector2(880,150);column.add_child(summary)
    button(column,"重新读取当前库存与心愿",refresh)
    footer()
    visibility_changed.connect(func():
        if not visible:report={};visible_rows=[];region_ids=[];list.clear();detail.text="";summary.text="")
func host_node() -> Node:
    var host: Node=owner_ref.get_ref() if owner_ref!=null else null
    if not is_instance_valid(host) or host.is_queued_for_deletion() or not host.is_inside_tree():return null
    if not is_instance_valid(host.window) or not host.window.visible or not is_instance_valid(host.ui) or not host.ui.bag.is_visible_in_tree():return null
    if host.ui.level.world_loading:return null
    return host
func open_for(host: Node) -> void:
    owner_ref=weakref(host)
    if host_node()==null:return
    bind_overlay(host.ui,host.ui.bag)
    query.clear();view_mode.select(0);preserve.set_pressed_no_signal(false);selected=""
    refresh();popup_centered();query.grab_focus()
func refresh() -> void:
    var host:=host_node()
    if host==null:return
    var previous: String=String(region_ids[region.selected]) if region.selected>=0 and region.selected<region_ids.size() else ""
    report=SOURCES.read(host.ui.level)
    region.clear();region_ids=[""];region.add_item("全部已登记地区")
    var seen: Dictionary={}
    for row in report.get("rows",[]):
        if seen.has(row.region_id):continue
        seen[row.region_id]=true;region_ids.append(row.region_id);region.add_item(String(row.region))
    region.select(region_ids.find(previous) if region_ids.has(previous) else 0)
    render();status.text="已重读当前库存；交付仍须返回人物身旁核对。" if report.get("ok",false) else String(report.get("reason","清单暂不可读取。"))
func render() -> void:
    if host_node()==null:return
    list.clear();visible_rows=[];detail.text="";summary.text=""
    if not report.get("ok",false):detail.text=String(report.get("reason","清单暂不可读取。"));return
    var id:=String(region_ids[region.selected]) if region.selected>=0 and region.selected<region_ids.size() else ""
    visible_rows=MODEL.browse(report,query.text,view_mode.selected,id)
    var choice:=0
    for index in visible_rows.size():
        var entry: Dictionary=visible_rows[index]
        list.add_item(String(entry.npc)+" · "+("已完成" if entry.complete else "信物已备齐" if entry.ready else "待核对"))
        if entry.key==selected:choice=index
    if not visible_rows.is_empty():list.select(choice);selected=String(visible_rows[choice].key)
    else:selected=""
    show_detail();render_totals()
func show_detail() -> void:
    if host_node()==null:return
    detail.text="当前筛选没有已登记的交付心愿；未询问的心愿不会提前列出。"
    for row in visible_rows:
        if row.key==selected:detail.text=MODEL.detail(row);return
func render_totals() -> void:
    if host_node()==null:return
    summary.text=MODEL.totals(visible_rows,preserve.button_pressed) if report.get("ok",false) else ""
func _process(_delta: float) -> void:
    if visible and host_node()==null:hide()
