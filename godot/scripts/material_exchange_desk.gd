extends Node
const MARKET := preload("res://scripts/material_exchange.gd")
var ui: Control
var window: AcceptDialog
var list: ItemList
var detail: Label
var amount: SpinBox
var maximum_button: Button
var review_button: Button
var rows: Array=[]
var confirm: ConfirmationDialog
var pending: Dictionary={}
var target_stock: SpinBox
var deficit_label: Label
var deficit_button: Button

static func install(shell: Control) -> void:
    var world: Variant=shell.level.get("world_mode")
    if not world is bool or not world:return
    var desk:=new();desk.name="MaterialExchangeDesk";shell.add_child(desk);desk.setup(shell)

func setup(shell: Control) -> void:
    ui=shell
    var button: Button=ui._button(ui.build_panel,"地区材料兑换",Vector2(405,535),Vector2(175,30),open)
    button.name="MaterialExchangeButton";button.add_theme_font_size_override("font_size",14)

func _build() -> void:
    window=preload("res://scripts/journey_desk_window.gd").new();window.title="地区材料兑换";ui.build_panel.add_child(window);window.bind_overlay(ui,ui.build_panel)
    window.text(window.column,"本区巡礼印作凭证，只兑换已到过的邻区材料。每份交出 3 份本区材料与 8 松脂，收入 1 份目标材料。每次最多十份，循环兑换始终亏损。",62)
    list=ItemList.new();list.custom_minimum_size=Vector2(880,150);window.column.add_child(list);list.item_selected.connect(func(_index: int):_default_target();refresh())
    var row: HBoxContainer=window.row(window.column)
    var label:=Label.new();label.text="兑换份数";row.add_child(label)
    amount=SpinBox.new();amount.min_value=1;amount.max_value=MARKET.LIMIT;amount.step=1;amount.value=1;row.add_child(amount);amount.value_changed.connect(func(_value: float):refresh())
    maximum_button=window.button(row,"选择当前最多可换",select_maximum)
    var planning: HBoxContainer=window.row(window.column)
    var target_label:=Label.new();target_label.text="希望目标材料持有总量";planning.add_child(target_label)
    target_stock=SpinBox.new();target_stock.min_value=0;target_stock.max_value=999999;target_stock.step=1;planning.add_child(target_stock)
    target_stock.value_changed.connect(func(_value: float):refresh())
    deficit_button=window.button(planning,"按目标选择份数",select_deficit)
    deficit_label=window.text(window.column,"",52)
    detail=window.text(window.column,"",110);review_button=window.button(window.column,"核对本次兑换",ask);window.footer()
    confirm=ConfirmationDialog.new();confirm.title="核对材料与费用";window.add_child(confirm);ui.register_text_entry_window(confirm);confirm.confirmed.connect(_confirm)
    window.visibility_changed.connect(func():
        if not window.visible:confirm.hide();pending={})

func open() -> void:
    if not ui.build_panel.is_visible_in_tree():return
    if not is_instance_valid(window):_build()
    rows=MARKET.entries(ui.level);list.clear()
    for row in rows:list.add_item(ui.level._item_display_name(String(row.input))+" → "+ui.level._item_display_name(String(row.output)))
    if not rows.is_empty():list.select(0)
    _default_target()
    refresh();window.popup_centered();amount.get_line_edit().grab_focus()

func refresh() -> void:
    maximum_button.disabled=true;review_button.disabled=true;deficit_button.disabled=true;deficit_label.text="请选择一条已知兑换。"
    if list.get_selected_items().is_empty():detail.text="先探索邻区，再带本区巡礼印回钟龛；未到地区不会提前列出。";return
    var row: Dictionary=rows[list.get_selected_items()[0]]
    var quote:=MARKET.quote(ui.level,String(row.id),amount.value)
    var available:=MARKET.maximum(ui.level,String(row.id))
    maximum_button.disabled=not available.ok
    review_button.disabled=not quote.ok
    detail.text=String(quote.summary) if quote.ok else String(quote.reason)
    detail.text+="\n现有本区材料：%d；目标材料：%d；松脂：%d。" % [int(ui.level.inventory_counts.get(row.input,0)),int(ui.level.inventory_counts.get(row.output,0)),int(ui.level.currency_count)]
    detail.text+="\n"+String(available.reason)
    var stock_plan:=_stock_plan(row)
    deficit_button.disabled=not stock_plan.ok
    deficit_label.text=String(stock_plan.reason)

func _default_target() -> void:
    if list.get_selected_items().is_empty():return
    var row: Dictionary=rows[list.get_selected_items()[0]]
    var held: Variant=ui.level.inventory_counts.get(row.output,0)
    target_stock.set_value_no_signal(minf(999999.0,float(held)+1.0) if preload("res://scripts/exchange_stock_plan.gd").counter(held) else 0)

func _stock_plan(row: Dictionary) -> Dictionary:
    return preload("res://scripts/exchange_stock_plan.gd").plan(ui.level.inventory_counts.get(row.output,0),target_stock.value,row.output_amount,func(count: int):return MARKET.quote(ui.level,String(row.id),count))

func select_deficit() -> void:
    if not window.visible or list.get_selected_items().is_empty():return
    var plan:=_stock_plan(rows[list.get_selected_items()[0]])
    if not plan.ok:refresh();window.status.text=String(plan.reason);return
    pending={};confirm.hide();amount.set_value_no_signal(int(plan.amount));refresh()
    window.status.text="已按目标选择份数；请核对收支，再确认兑换。"

func select_maximum() -> void:
    if not window.visible or list.get_selected_items().is_empty():return
    var row: Dictionary=rows[list.get_selected_items()[0]]
    var available:=MARKET.maximum(ui.level,String(row.id))
    if not available.ok:refresh();window.status.text=String(available.reason);return
    pending={};confirm.hide()
    amount.set_value_no_signal(float(available.maximum))
    refresh();window.status.text="已选择%d份；尚未兑换，请核对后确认。" % int(available.maximum)

func ask() -> void:
    if list.get_selected_items().is_empty():return
    var row: Dictionary=rows[list.get_selected_items()[0]]
    var quote:=MARKET.quote(ui.level,String(row.id),amount.value)
    if not quote.ok:window.status.text=quote.reason;return
    pending={"id":row.id,"amount":int(amount.value),"fingerprint":quote.fingerprint}
    confirm.dialog_text=String(quote.summary)+"\n"+preload("res://scripts/exchange_stock_plan.gd").balance(row,ui.level.inventory_counts,ui.level.currency_count,quote,func(id: String):return ui.level._item_display_name(id))+"\n保存失败不会扣除任何物品。"
    confirm.popup_centered();confirm.get_cancel_button().grab_focus()

func _confirm() -> void:
    if pending.is_empty() or not window.visible:return
    var request:=pending.duplicate(true);pending={}
    var result:=MARKET.perform(ui.level,String(request.id),request.amount,String(request.fingerprint))
    refresh();window.status.text=String(result.reason)
