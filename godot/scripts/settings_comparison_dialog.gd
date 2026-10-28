extends "res://scripts/journey_desk_window.gd"
const MODEL:=preload("res://scripts/settings_profile_comparison.gd")
var owner_ref: WeakRef
var left: OptionButton
var right: OptionButton
var scope: OptionButton
var only_changes: CheckButton
var query: LineEdit
var detail: RichTextLabel
var names: Array=[]
var snapshot: Dictionary={}
var identity:=""
var stale:=false
var polling:=0.0
func _ready() -> void:
    super._ready();title="比较两套保存方案"
    text(column,"并排阅读两套已保存的阅读、手柄和输入记录；这里不会应用、覆盖或写入任何方案。",48)
    var pair:=row(column)
    text_label(pair,"左侧方案")
    left=OptionButton.new();left.custom_minimum_size=Vector2(310,32);pair.add_child(left)
    text_label(pair,"右侧方案")
    right=OptionButton.new();right.custom_minimum_size=Vector2(310,32);pair.add_child(right)
    left.item_selected.connect(func(_index: int):render())
    right.item_selected.connect(func(_index: int):render())
    var filters:=row(column)
    scope=OptionButton.new();filters.add_child(scope)
    for label in ["全部保存值","仅设置参数","仅键盘鼠标","仅手柄按键"]:scope.add_item(label)
    scope.item_selected.connect(func(_index: int):render())
    only_changes=CheckButton.new();only_changes.text="只看不同项";only_changes.button_pressed=true;filters.add_child(only_changes)
    only_changes.toggled.connect(func(_value: bool):render())
    button(filters,"交换左右",swap_sides)
    button(filters,"重新读取方案",refresh)
    query=search(column,"搜索设置名称或输入标签",func(_value: String):render())
    detail=RichTextLabel.new();detail.bbcode_enabled=false;detail.selection_enabled=true;detail.scroll_active=true
    detail.focus_mode=Control.FOCUS_ALL;detail.custom_minimum_size=Vector2(880,340);column.add_child(detail)
    footer()
    visibility_changed.connect(func():
        if not visible:snapshot={};names=[];identity="";detail.text="";left.clear();right.clear())
func text_label(parent: Node,value: String) -> void:
    var label:=Label.new();label.text=value;parent.add_child(label)
func host_node() -> Node:
    var host: Node=owner_ref.get_ref() if owner_ref!=null else null
    if not is_instance_valid(host) or host.is_queued_for_deletion() or not host.is_inside_tree():return null
    if not is_instance_valid(host.window) or not host.window.visible or not is_instance_valid(host.ui) or not host.ui.settings.is_visible_in_tree():return null
    return host
func open_for(host: Node) -> void:
    owner_ref=weakref(host)
    if host_node()==null:return
    bind_overlay(host.ui,host.ui.settings)
    query.clear();scope.select(0);only_changes.set_pressed_no_signal(true)
    refresh();popup_centered();left.grab_focus()
func selected_name(control: OptionButton) -> String:
    return String(names[control.selected]) if control.selected>=0 and control.selected<names.size() else ""
func refresh() -> void:
    var host:=host_node()
    if host==null:return
    var previous_left:=selected_name(left)
    var previous_right:=selected_name(right)
    snapshot=host.model.profiles.duplicate(true);identity=var_to_str(host.model.profiles).sha256_text();stale=false
    names=snapshot.keys();names.sort();left.clear();right.clear()
    for name in names:left.add_item(String(name));right.add_item(String(name))
    if not names.is_empty():
        left.select(names.find(previous_left) if names.has(previous_left) else 0)
        right.select(names.find(previous_right) if names.has(previous_right) else mini(1,names.size()-1))
    render();status.text="只读比较；保存方案的管理与应用仍在原窗口。"
func swap_sides() -> void:
    if not visible or host_node()==null or stale or names.is_empty():return
    var previous:=left.selected;left.select(right.selected);right.select(previous);render()
func render() -> void:
    var host:=host_node()
    if host==null:return
    if stale or var_to_str(host.model.profiles).sha256_text()!=identity:
        stale=true;detail.text="保存方案已变化，请重新读取后比较。";return
    if names.size()<2:detail.text="至少保存两套方案后再比较；不会为比较创建或覆盖方案。";return
    var a:=selected_name(left);var b:=selected_name(right)
    if a.is_empty() or b.is_empty():detail.text="请选择左右两套保存方案。";return
    var report:=MODEL.compare(snapshot[a],snapshot[b],host.ui.REMAPPABLE_ACTIONS,scope.selected)
    detail.text="左：%s\n右：%s\n\n%s" % [a,b,MODEL.describe(report,query.text,only_changes.button_pressed)]
    detail.scroll_to_line(0)
func _process(delta: float) -> void:
    if not visible:return
    var host:=host_node()
    if host==null:hide();return
    polling+=delta
    if polling>=0.25:
        polling=0.0
        if var_to_str(host.model.profiles).sha256_text()!=identity:stale=true;detail.text="保存方案已变化，请重新读取后比较。"
