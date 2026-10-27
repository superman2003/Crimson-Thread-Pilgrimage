extends AcceptDialog
const MODEL:=preload("res://scripts/resource_purpose_ledger.gd")
var host: WeakRef
var report: Dictionary={}
var selected:="currency"
var resources: ItemList
var detail: RichTextLabel
var ready_only: CheckButton
var refresh_button: Button

func _ready() -> void:
    title="资源用途核对"
    min_size=Vector2i(880,580)
    get_ok_button().text="返回行囊"
    var column:=VBoxContainer.new()
    column.add_theme_constant_override("separation",12)
    add_child(column)
    var explanation:=Label.new()
    explanation.text="核对当前资源与已解锁用途；不会购买、制作、补给或施放。"
    column.add_child(explanation)
    var filters:=HBoxContainer.new()
    column.add_child(filters)
    ready_only=CheckButton.new()
    ready_only.text="只看未完成且所示条件已齐"
    filters.add_child(ready_only)
    refresh_button=Button.new()
    refresh_button.text="刷新当前资源"
    filters.add_child(refresh_button)
    ready_only.toggled.connect(func(_value: bool):render_detail())
    refresh_button.pressed.connect(refresh)
    var body:=HBoxContainer.new()
    column.add_child(body)
    resources=ItemList.new()
    resources.custom_minimum_size=Vector2(250,440)
    body.add_child(resources)
    resources.item_selected.connect(func(index: int):
        selected=String(resources.get_item_metadata(index))
        render_detail())
    detail=RichTextLabel.new()
    detail.custom_minimum_size=Vector2(580,440)
    detail.bbcode_enabled=false
    detail.scroll_active=true
    detail.focus_mode=Control.FOCUS_ALL
    detail.add_theme_font_size_override("normal_font_size",17)
    body.add_child(detail)
    confirmed.connect(return_focus)
    canceled.connect(return_focus)

func usable() -> bool:
    if host==null:return false
    var ui: Variant=host.get_ref()
    return is_instance_valid(ui) and ui.is_inside_tree() and not ui.is_queued_for_deletion() and is_instance_valid(ui.level) and not ui.level.is_queued_for_deletion() and is_instance_valid(ui.bag) and ui.bag.is_visible_in_tree() and ui.level.active_overlay=="backpack"

func open(ui: Control) -> void:
    host=weakref(ui)
    if not usable():return
    selected="currency"
    ready_only.set_pressed_no_signal(false)
    refresh()
    popup_centered()
    resources.grab_focus()

func refresh() -> void:
    if not usable():return
    var ui: Variant=host.get_ref()
    var level: Node=ui.level
    var items: Dictionary={}
    for id in level.inventory_counts:items[id]=level._item_data(String(id)).duplicate(true)
    var wallet:={"currency":level.currency_count,"inventory_counts":level.inventory_counts.duplicate(true)}
    report=MODEL.collect(level.get_build_system(),wallet,level.story_flags,items,level.player.energy,level.player.max_energy,level.player.get_combat_ui_state().get("heal",{}))
    report["observed_sources"]=MODEL.observed_sources(level.config,level.world_collected_ids,level.visited_rooms,level.inventory_counts)
    resources.clear()
    if not report.ok:detail.text=String(report.reason);return
    var selection:=0
    for row in report.rows:
        var index:=resources.add_item("%s · %d" % [row.name,row.count])
        resources.set_item_metadata(index,row.id)
        if row.id==selected:selection=index
    resources.select(selection)
    selected=String(resources.get_item_metadata(selection))
    render_detail()

func render_detail() -> void:
    if not usable() or not report.get("ok",false):return
    var ui: Variant=host.get_ref()
    for row in report.rows:
        if row.id==selected:
            detail.text=MODEL.describe(report,row,ready_only.button_pressed,func(id: String):return ui.level._item_display_name(id))
            detail.scroll_to_line(0)
            return

func return_focus() -> void:
    if not usable():return
    var ui: Variant=host.get_ref()
    var button:=ui.bag.get_node_or_null("ResourcePurposeButton") as Button
    if button!=null and button.is_visible_in_tree():button.grab_focus()

static func setup(ui: Control) -> void:
    var dialog: AcceptDialog=load("res://scripts/resource_purpose_dialog.gd").new()
    dialog.name="ResourcePurposeWindow"
    ui.add_child(dialog)
    var button: Button=ui._button(ui.bag,"资源用途核对",Vector2(510,94),Vector2(180,34),func():dialog.open(ui))
    button.name="ResourcePurposeButton"
    button.add_theme_font_size_override("font_size",15)
    ui.bag.visibility_changed.connect(func():
        if not ui.bag.visible:dialog.hide();dialog.report={})
