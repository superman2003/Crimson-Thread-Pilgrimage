extends Node
const CONTRACTS := preload("res://scripts/field_contracts.gd")
var ui: Control
var window: AcceptDialog
var list: ItemList
var detail: RichTextLabel
var query: LineEdit
var filter: OptionButton
var region_filter: OptionButton
var confirm: ConfirmationDialog
var rows: Array=[]
var selected:=""
var pending: Dictionary={}

static func install(shell: Control) -> void:
    var world: Variant=shell.level.get("world_mode")
    if not world is bool or not world:return
    var desk:=new();desk.name="FieldContractDesk";shell.add_child(desk);desk.setup(shell)

func setup(shell: Control) -> void:
    ui=shell
    var scroll: ScrollContainer=ui.build_grid.get_parent()
    scroll.size.y=minf(scroll.size.y,298.0)
    var button: Button=ui._button(ui.build_panel,"六区巡礼契约",Vector2(34,535),Vector2(175,30),open)
    button.name="FieldContractButton";button.add_theme_font_size_override("font_size",14)

func _build() -> void:
    window=preload("res://scripts/journey_desk_window.gd").new();window.name="FieldContractWindow"
    ui.build_panel.add_child(window);window.title="六区巡礼契约";window.bind_overlay(ui,ui.build_panel)
    window.text(window.column,"每区巡查与守路两份契约。最多同时三份；真实探索记录可回溯登记，巡礼印只领取一次。",42)
    var filters: HBoxContainer=window.row(window.column)
    query=window.search(filters,"搜索契约与已公开的步骤",func(_value: String):refresh())
    filter=OptionButton.new();filters.add_child(filter)
    for label in ["全部已知","可接取","进行中","已结算","待登记回礼"]:filter.add_item(label)
    filter.item_selected.connect(func(_index: int):refresh())
    region_filter=OptionButton.new();filters.add_child(region_filter)
    region_filter.item_selected.connect(func(_index: int):refresh())
    var columns: HBoxContainer=window.row(window.column)
    list=ItemList.new();list.custom_minimum_size=Vector2(315,310);columns.add_child(list)
    detail=RichTextLabel.new();detail.custom_minimum_size=Vector2(575,310);columns.add_child(detail)
    list.item_selected.connect(func(index: int):selected=String(rows[index].contract_id);_selection())
    var actions: HBoxContainer=window.row(window.column)
    window.button(actions,"接取所选",func():ask("accept"));window.button(actions,"确认登记与回礼",func():ask("claim"));window.button(actions,"取消所选",func():ask("cancel"))
    window.footer()
    confirm=ConfirmationDialog.new();confirm.title="核对巡礼契约";confirm.min_size=Vector2i(640,240);window.add_child(confirm);ui.register_text_entry_window(confirm)
    confirm.confirmed.connect(_confirm)
    window.visibility_changed.connect(func():
        if not window.visible:confirm.hide();pending={})

func open() -> void:
    if not ui.build_panel.is_visible_in_tree():return
    if not is_instance_valid(window):_build()
    refresh();window.popup_centered();query.grab_focus()

func refresh() -> void:
    var known:=CONTRACTS.entries(ui.level)
    var region:=String(region_filter.get_selected_metadata()) if region_filter.item_count>0 else ""
    region_filter.clear();region_filter.add_item("全部已知地区");region_filter.set_item_metadata(0,"")
    for place in CONTRACTS.regions(known):
        region_filter.add_item(String(place.name));var index:=region_filter.item_count-1
        region_filter.set_item_metadata(index,String(place.id))
        if place.id==region:region_filter.select(index)
    rows=[];list.clear()
    for row in CONTRACTS.browse(known,query.text,filter.selected,String(region_filter.get_selected_metadata())):
        rows.append(row);list.add_item(String(row.title)+(" · 已结算" if row.claimed else " · 可登记" if row.accepted and row.ready else " · 进行中" if row.accepted else " · 可接取"))
        if row.contract_id==selected:list.select(list.item_count-1)
    if list.get_selected_items().is_empty() and list.item_count>0:list.select(0);selected=String(rows[0].contract_id)
    if rows.is_empty():selected=""
    _selection()
    window.status.text="符合筛选%d / 已知%d份 · 待登记回礼%d份；操作仍须在钟龛旁确认。" % [rows.size(),known.size(),CONTRACTS.browse(known,"",4).size()]

func _selection() -> void:
    detail.text="尚无匹配的已知契约。"
    for row in rows:
        if row.contract_id!=selected:continue
        var lines: Array[String]=[String(row.title),String(row.description),""]
        for step in row.steps:lines.append(("● " if step.complete else "○ ")+String(step.label))
        lines.append("\n回礼："+String(row.reward_name)+" × 1\n"+String(row.guidance))
        detail.text="\n".join(lines)

func ask(action: String) -> void:
    var quote: Dictionary=CONTRACTS.quote(ui.level,selected,action)
    if not quote.ok:window.status.text=String(quote.reason);return
    pending={"id":selected,"action":action,"fingerprint":quote.fingerprint}
    confirm.dialog_text=String(quote.summary);confirm.popup_centered();confirm.get_cancel_button().grab_focus()

func _confirm() -> void:
    if pending.is_empty() or not window.visible:return
    var request:=pending.duplicate(true);pending={}
    var result: Dictionary=CONTRACTS.perform(ui.level,String(request.id),String(request.action),String(request.fingerprint))
    refresh();window.status.text=String(result.reason)
