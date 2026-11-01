extends "res://scripts/journey_desk_window.gd"
const BUDGET:=preload("res://scripts/thread_action_budget.gd")
var owner_ref: WeakRef
var sequence: Array=[]
var choices: Array=[]
var available: ItemList
var planned: ItemList
var reserve: CheckButton
var detail: RichTextLabel
func _ready() -> void:
    super._ready();title="绯线行动预算"
    text(column,"把已经知道的线术与疗伤排成费用草案；不施放、不消费，也不代替实战条件。",48)
    var lists:=row(column)
    available=ItemList.new();available.custom_minimum_size=Vector2(440,180);lists.add_child(available)
    planned=ItemList.new();planned.custom_minimum_size=Vector2(440,180);lists.add_child(planned)
    var actions:=row(column)
    button(actions,"加入所选动作",append_action)
    button(actions,"移除所选",remove_action)
    button(actions,"上移",func():move_action(-1))
    button(actions,"下移",func():move_action(1))
    button(actions,"清空草案",func():sequence=[];render())
    reserve=CheckButton.new();reserve.text="另留一次当前疗伤费用";column.add_child(reserve)
    reserve.toggled.connect(func(_value: bool):render())
    button(column,"重新读取当前绯线与费用",refresh)
    detail=RichTextLabel.new();detail.bbcode_enabled=false;detail.scroll_active=true
    detail.focus_mode=Control.FOCUS_ALL;detail.custom_minimum_size=Vector2(880,180);column.add_child(detail)
    footer()
    visibility_changed.connect(func():
        if not visible:sequence=[];choices=[];available.clear();planned.clear();detail.text="")
func host_node() -> Node:
    var source: Node=owner_ref.get_ref() if owner_ref!=null else null
    return source if is_instance_valid(source) and not source.is_queued_for_deletion() and source.is_inside_tree() and source.visible and source.usable() else null
func open_for(source: Node) -> void:
    owner_ref=weakref(source)
    if host_node()==null:return
    var ui: Control=source.host.get_ref()
    bind_overlay(ui,ui.bag);sequence=[];reserve.set_pressed_no_signal(false)
    refresh();popup_centered();available.grab_focus()
func refresh() -> void:
    var source:=host_node()
    if source==null:return
    source.refresh();choices=BUDGET.catalog(source.report).values();available.clear()
    for choice in choices:available.add_item(String(choice.name)+" · "+str(choice.cost))
    if not choices.is_empty():available.select(0)
    render();status.text="已重读当前资源。草案只保留在本次窗口，不会写入归途。"
func render() -> void:
    var source:=host_node()
    if source==null:return
    var selected:=planned.get_selected_items()
    planned.clear()
    var known:=BUDGET.catalog(source.report)
    for id in sequence:planned.add_item(String(known.get(id,{}).get("name","当前未知动作")))
    if not sequence.is_empty():planned.select(mini(selected[0] if not selected.is_empty() else sequence.size()-1,sequence.size()-1))
    detail.text=BUDGET.describe(BUDGET.preview(source.report,sequence,reserve.button_pressed))
func append_action() -> void:
    if not visible or host_node()==null:return
    if sequence.size()>=BUDGET.LIMIT:status.text="草案已满八项，先移除一项再加入。";return
    var selected:=available.get_selected_items()
    if selected.is_empty():return
    sequence.append(String(choices[selected[0]].id));render()
func remove_action() -> void:
    if not visible or host_node()==null or planned.get_selected_items().is_empty():return
    sequence.remove_at(planned.get_selected_items()[0]);render()
func move_action(delta: int) -> void:
    if not visible or host_node()==null or planned.get_selected_items().is_empty() or delta not in [-1,1]:return
    var index:=int(planned.get_selected_items()[0]);var target:=index+delta
    if target<0 or target>=sequence.size():return
    var id: Variant=sequence[index];sequence[index]=sequence[target];sequence[target]=id
    planned.select(target);render()
func _process(_delta: float) -> void:
    if visible and host_node()==null:hide()
