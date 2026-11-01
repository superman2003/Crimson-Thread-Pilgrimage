extends ConfirmationDialog
## Session shopping list. Only the World's durable transaction can grant stock.
var rows: Array = []
var quantities: Dictionary = {}
var query: Callable
var purchase: Callable
var material_name: Callable
var quote: Dictionary = {}
var body: VBoxContainer
var choices: VBoxContainer
var row_scroll: ScrollContainer
var selection_summary: Label
var detail: RichTextLabel
var status: Label
var rebuilding := false

func _ready() -> void:
    title = "钟龛按需补给"
    wrap_controls=false
    size = Vector2i(680, 500)
    min_size = size
    dialog_hide_on_ok = false
    get_ok_button().text = "确认购买此清单"
    get_cancel_button().text = "取消"
    confirmed.connect(_confirm_purchase)
    body = VBoxContainer.new()
    body.add_theme_constant_override("separation", 8)
    add_child(body)
    var hint := Label.new()
    hint.text = "调整数量，上下移动优先顺序。资金不足时按此顺序部分补给。"
    body.add_child(hint)
    var presets:=HBoxContainer.new();body.add_child(presets)
    for pair in [["补齐缺额","full"],["每种一份","one"],["补到半满","half"],["全部清空","none"]]:
        var button:=Button.new();button.text=pair[0];presets.add_child(button)
        var mode: String=pair[1]
        button.pressed.connect(func():apply_preset(mode))
    selection_summary=Label.new();body.add_child(selection_summary)
    row_scroll=ScrollContainer.new();row_scroll.custom_minimum_size=Vector2(630,135);row_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(row_scroll)
    choices=VBoxContainer.new();choices.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row_scroll.add_child(choices)
    detail=RichTextLabel.new();detail.bbcode_enabled=false;detail.fit_content=false;detail.scroll_active=true;detail.selection_enabled=true
    detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail.custom_minimum_size=Vector2(630,145);body.add_child(detail)
    size_changed.connect(func():call_deferred("_layout_body"))
    status = Label.new()
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body.add_child(status)

func open(options: Array, quote_action: Callable, buy_action: Callable, names: Callable) -> void:
    rows.clear()
    quantities.clear()
    query = quote_action
    purchase = buy_action
    material_name = names
    for value in options:
        if not value is Dictionary or not bool(value.get("unlocked", false)):continue
        var row: Dictionary = value.duplicate(true)
        var id := String(row.get("id", ""))
        if id.is_empty() or quantities.has(id):continue
        rows.append(row)
        quantities[id] = maxi(0, int(row.get("capacity", 0)) - int(row.get("count", 0)))
    _rebuild_rows()
    status.text = "预览不会消费。购买前会重新核对钱包、库存和钟龛距离。"
    _refresh_quote()
    popup_centered(Vector2i(700,600))
    call_deferred("_layout_body")
    get_cancel_button().grab_focus()
    if rows.is_empty():status.text="尚无可补给的已获得战具。"

func plan() -> Dictionary:
    var order: Array = []
    for row in rows:order.append(String(row.id))
    return {"order": order, "limits": quantities.duplicate(true)}

func _rebuild_rows(focus_id: String = "") -> void:
    rebuilding = true
    for child in choices.get_children():
        choices.remove_child(child)
        child.queue_free()
    var focus_control: Control
    for index in rows.size():
        var row: Dictionary = rows[index]
        var id := String(row.id)
        var line := HBoxContainer.new()
        choices.add_child(line)
        var label := Label.new()
        label.text = "%d. %s  %d/%d" % [index + 1, String(row.get("name", id)), int(row.get("count", 0)), int(row.get("capacity", 0))]
        label.custom_minimum_size.x = 335
        line.add_child(label)
        var amount := SpinBox.new()
        amount.min_value = 0
        amount.max_value = maxi(0, int(row.get("capacity", 0)) - int(row.get("count", 0)))
        amount.step = 1
        amount.value = int(quantities[id])
        amount.custom_minimum_size.x = 110
        amount.tooltip_text = "购买份数；0表示跳过，不会购买其它未选战具。"
        line.add_child(amount)
        amount.value_changed.connect(func(value: float):
            quantities[id] = int(value)
            if not rebuilding:_refresh_quote())
        if id == focus_id:focus_control = amount.get_line_edit()
        for direction in [-1, 1]:
            var move := Button.new()
            move.text = "前移" if direction < 0 else "后移"
            move.disabled = index + direction < 0 or index + direction >= rows.size()
            move.tooltip_text = "修改补给优先顺序"
            line.add_child(move)
            move.pressed.connect(func():move_priority(id, direction))
    rebuilding = false
    if focus_control != null:focus_control.grab_focus()

func move_priority(id: String, direction: int) -> void:
    if direction not in [-1, 1]:return
    for index in rows.size():
        if String(rows[index].id) != id:continue
        var target := index + direction
        if target < 0 or target >= rows.size():return
        var other: Dictionary = rows[target]
        rows[target] = rows[index]
        rows[index] = other
        _rebuild_rows(id)
        _refresh_quote()
        return

func _current_quote() -> Dictionary:
    if not query.is_valid():return {"ok": false, "reason": "报价不可用"}
    var result: Variant = query.call(plan())
    return result.duplicate(true) if result is Dictionary else {"ok": false, "reason": "报价不可用"}

func _refresh_quote() -> void:
    quote = _current_quote()
    get_ok_button().disabled = not bool(quote.get("ok", false)) or not has_selection()
    var requested_total:=0;var fulfilled_total:=0
    for id in quantities:
        requested_total+=int(quantities[id]);fulfilled_total+=int(quote.get("charges",{}).get(id,0))
    selection_summary.text="申请 %d 份 · 当前可购 %d 份 · 未满足 %d 份" % [requested_total,fulfilled_total,maxi(0,requested_total-fulfilled_total)]
    var lines: Array[String] = []
    for row in rows:
        var id := String(row.id)
        var bought := int(quote.get("charges", {}).get(id, 0))
        var requested := int(quantities.get(id, 0))
        if requested > 0:lines.append("%s：可购 %d / 申请 %d%s" % [String(row.get("name",id)),bought,requested," · 部分补给" if bought<requested else ""])
    var cost: Dictionary = quote.get("cost", {})
    lines.append("合计碎钱 %d" % int(cost.get("currency", 0)))
    for id in cost.get("materials", {}):
        var name := String(material_name.call(String(id))) if material_name.is_valid() else String(id)
        lines.append("%s ×%d" % [name, int(cost.materials[id])])
    if quote.get("remaining_wallet") is Dictionary:
        lines.append("购买后碎钱 %d" % int(quote.remaining_wallet.get("currency", 0)))
    lines.append_array(preload("res://scripts/resupply_budget.gd").lines(quote.get("budget", {}), material_name))
    if not bool(quote.get("ok", false)):lines.append(String(quote.get("reason", "当前不可购买")))
    detail.text = "\n".join(lines)

func _confirm_purchase() -> void:
    var previous := quote.duplicate(true)
    _refresh_quote()
    if not bool(quote.get("ok", false)) or not has_selection():
        status.text = "先前报价已失效，请调整清单或回到钟龛。"
        return
    if previous.get("charges", {}) != quote.get("charges", {}) or previous.get("cost", {}) != quote.get("cost", {}):
        status.text = "钱包或库存已变化；已更新报价，请复核后再次确认。"
        return
    if not purchase.is_valid():return
    var result: Variant = purchase.call(plan())
    if result is Dictionary and bool(result.get("ok", false)):
        hide()
    else:
        status.text = String(result.get("reason", "购买未完成")) if result is Dictionary else "购买未完成"
        _refresh_quote()

func has_selection() -> bool:
    for value in quantities.values():
        if int(value)>0:return true
    return false

func apply_preset(mode: String) -> void:
    if mode not in ["full","one","half","none"]:return
    for row in rows:
        var capacity:=maxi(0,int(row.get("capacity",0)))
        var count:=maxi(0,int(row.get("count",0)))
        var missing:=maxi(0,capacity-count)
        quantities[String(row.id)]={"full":missing,"one":mini(1,missing),"half":maxi(0,ceili(capacity*0.5)-count),"none":0}[mode]
    var offset:=row_scroll.scroll_vertical
    _rebuild_rows();row_scroll.set_deferred("scroll_vertical",offset);_refresh_quote()
    status.text="已更新申请；只有确认购买后才会扣款。" if has_selection() else "当前清单为空，不会自动补给其它战具。"

func _layout_body() -> void:
    if not is_instance_valid(body):return
    body.position=Vector2(12,12)
    body.size=Vector2(maxi(630,size.x-24),maxi(436,size.y-76))
