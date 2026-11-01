extends "res://scripts/journey_desk_window.gd"
const MODEL:=preload("res://scripts/material_conversion_plan.gd")
const SOURCE:=preload("res://scripts/material_conversion_plan_source.gd")

var shell_ref: WeakRef
var parent_ref: WeakRef
var context: Dictionary={}
var result: Dictionary={}
var job: RefCounted
var target: OptionButton
var required: SpinBox
var budget: SpinBox
var reserve: SpinBox
var compute: Button
var cancel: Button
var refresh_button: Button
var detail: RichTextLabel
var counter: Label
var request: Dictionary={}
var elapsed:=0.0

func _ready() -> void:
    super._ready()
    title="已知材料兑换链"
    text(column,"只在已到地区、已持有对应巡礼印的兑换中，按目标持有量规划。预算与另行保留的松脂共同限制花费；不执行任何交易。",64)
    var destination:=row(column)
    caption(destination,"目标材料")
    target=OptionButton.new()
    target.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    destination.add_child(target)
    target.item_selected.connect(_selection_changed)
    caption(destination,"希望持有")
    required=quantity(destination,1,999999,1)
    var money_row:=row(column)
    caption(money_row,"最多花费")
    budget=quantity(money_row,0,9999999,0)
    caption(money_row,"另行保留")
    reserve=quantity(money_row,0,9999999,0)
    var actions:=row(column)
    compute=button(actions,"计算只读兑换链",start)
    cancel=button(actions,"取消本次计算",cancel_search)
    refresh_button=button(actions,"重新读取库存与机会",refresh_context)
    counter=text(column,"",32)
    detail=RichTextLabel.new()
    detail.custom_minimum_size=Vector2(900,260)
    detail.bbcode_enabled=false
    detail.focus_mode=Control.FOCUS_ALL
    column.add_child(detail)
    footer()
    visibility_changed.connect(_closed)
    tree_exiting.connect(cancel_search)
    set_process(true)

func caption(parent: Node,value: String) -> void:
    var label:=Label.new()
    label.text=value
    label.add_theme_font_size_override("font_size",17)
    parent.add_child(label)

func quantity(parent: Node,minimum: int,maximum: int,value: int) -> SpinBox:
    var field:=SpinBox.new()
    field.min_value=minimum
    field.max_value=maximum
    field.step=1
    field.value=value
    field.custom_minimum_size=Vector2(140,34)
    parent.add_child(field)
    field.value_changed.connect(_quantity_changed)
    return field

func setup(shell: Control,parent: Window) -> void:
    shell_ref=weakref(shell)
    parent_ref=weakref(parent)
    bind_overlay(shell,shell.build_panel)
    parent.visibility_changed.connect(_parent_changed)

func shell() -> Control:
    var node: Variant=shell_ref.get_ref() if shell_ref!=null else null
    return node if is_instance_valid(node) and not node.is_queued_for_deletion() else null

func parent_window() -> Window:
    var node: Variant=parent_ref.get_ref() if parent_ref!=null else null
    return node if is_instance_valid(node) and not node.is_queued_for_deletion() else null

func open() -> void:
    var owner:=shell()
    var parent:=parent_window()
    if owner==null or parent==null or not parent.visible or not owner.build_panel.visible:return
    refresh_context()
    popup_centered()
    if target.item_count>0:target.grab_focus()
    else:get_ok_button().grab_focus()

func refresh_context() -> void:
    cancel_search()
    var owner:=shell()
    context={}
    request={}
    result={}
    detail.text=""
    target.clear()
    if owner==null:return
    context=SOURCE.snapshot(owner.level)
    if context.is_empty():
        status.text="旅途尚未准备好，未读取兑换。"
        compute.disabled=true
        return
    for id in context.targets:
        target.add_item(owner.level._item_display_name(String(id)))
        target.set_item_metadata(target.item_count-1,id)
    var money: Variant=context.money
    budget.set_value_no_signal(int(money) if MODEL.natural(money,9999999) else 0)
    reserve.set_value_no_signal(0)
    required.set_value_no_signal(1)
    compute.disabled=target.item_count==0
    cancel.disabled=true
    counter.text="已知且已有凭证的兑换机会：%d条。" % context.recipes.size()
    status.text="先选择目标与预算；所有变化只影响本窗口。"

func invalidate(reason: String) -> void:
    cancel_search()
    request={}
    result={}
    detail.text=""
    status.text=reason

func _selection_changed(_index: int) -> void:
    invalidate("目标已改变，请重新计算。")

func _quantity_changed(_value: float) -> void:
    invalidate("数量或预算已改变，请重新计算。")

func start() -> void:
    if not visible or context.is_empty() or target.selected<0:return
    var owner:=shell()
    if owner==null:return
    var current:=SOURCE.snapshot(owner.level)
    if current.get("fingerprint")!=context.get("fingerprint"):
        invalidate("库存、凭证或地区已改变，请重新读取机会。")
        return
    var allowance:=SOURCE.allowance(context.money,budget.value,reserve.value)
    if not allowance.ok:
        invalidate(String(allowance.reason))
        return
    cancel_search()
    result={}
    detail.text=""
    request={
        "target":String(target.get_item_metadata(target.selected)),
        "required":int(required.value),
        "spendable":int(allowance.spendable),
        "reserve":int(reserve.value),
        "fingerprint":String(context.fingerprint)
    }
    job=MODEL.begin(context.recipes,context.inventory,request.spendable,request.target,request.required)
    compute.disabled=true
    cancel.disabled=false
    status.text="正在分帧核对预算；可随时取消，不会交易。"

func cancel_search() -> void:
    if job!=null and not job.done:
        job.cancel()
        if is_instance_valid(status):status.text="本次规划已取消，没有执行交易。"
    job=null
    if is_instance_valid(compute):compute.disabled=context.is_empty() or target.item_count==0
    if is_instance_valid(cancel):cancel.disabled=true

func _process(delta: float) -> void:
    if not visible:return
    var owner:=shell()
    var parent:=parent_window()
    if owner==null or parent==null or not parent.visible:
        hide()
        return
    if context.is_empty():return
    elapsed+=maxf(delta,0.0)
    if elapsed>=0.25:
        elapsed=0.0
        var current:=SOURCE.snapshot(owner.level)
        if current.get("fingerprint")!=context.get("fingerprint"):
            invalidate("库存、地图知识、凭证或地区已改变。旧规划已清除，请重新读取。")
            context={}
            target.clear()
            counter.text=""
            compute.disabled=true
            return
    if job==null:return
    job.advance(8)
    counter.text="已核对状态 %d；生成状态 %d。" % [job.popped,job.generated]
    if not job.done:return
    var latest:=SOURCE.snapshot(owner.level)
    if latest.get("fingerprint")!=request.get("fingerprint"):
        invalidate("计算期间库存或机会已改变，未发布旧规划。")
        context={}
        target.clear()
        counter.text=""
        compute.disabled=true
        return
    result=job.result.duplicate(true)
    job=null
    cancel.disabled=true
    compute.disabled=false
    detail.text=SOURCE.describe(owner.level,context,request.target,request.required,result,request.spendable,request.reserve)
    status.text="只读规划已完成；请到真实钟龛逐次核对。" if result.ok else String(result.reason)

func _parent_changed() -> void:
    var parent:=parent_window()
    if parent==null or not parent.visible:hide()

func _closed() -> void:
    if visible:return
    cancel_search()
    context={}
    request={}
    result={}
    if is_instance_valid(detail):detail.text=""
    if is_instance_valid(target):target.clear()
    if is_instance_valid(counter):counter.text=""
