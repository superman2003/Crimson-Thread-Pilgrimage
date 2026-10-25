extends ConfirmationDialog
var owner_ref: WeakRef
var selected: Array[String]=[]
var switches: Dictionary={}
var quote: Dictionary={}
var rows: VBoxContainer
var summary: Label
var staged := false
func _ready() -> void:
    title="工匠 · 多件制作清单"
    min_size=Vector2i(760,540);dialog_hide_on_ok=false
    var column:=VBoxContainer.new();column.add_theme_constant_override("separation",10);add_child(column)
    var intro:=Label.new();intro.text="最多选择8件；合计支付，一次记录。任一条件不足时整单不制作。";column.add_child(intro)
    var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(700,220);column.add_child(scroll)
    rows=VBoxContainer.new();rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(rows)
    summary=Label.new();summary.custom_minimum_size=Vector2(700,190);summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(summary)
    get_ok_button().text="核对整单";get_cancel_button().text="取消制作"
    confirmed.connect(_confirm_cart)
func setup(ui: Node) -> void:owner_ref=weakref(ui)
func open() -> void:
    var ui=owner_ref.get_ref()
    if not is_instance_valid(ui):return
    selected.clear();switches.clear();quote.clear();staged=false
    for child in rows.get_children():rows.remove_child(child);child.queue_free()
    var artisan: String=ui.level.near_artisan_id()
    for id in ui.level.build_system.catalog.recipes:
        var recipe: Dictionary=ui.level.build_system.catalog.recipes[id]
        if not String(recipe.get("artisan","")) in ["",artisan]:continue
        var key:=String(id)
        var button:=CheckButton.new();button.text=String(recipe.name)+" · %d碎钱" % int(recipe.currency)
        rows.add_child(button);switches[key]=button
        button.toggled.connect(func(enabled: bool):set_recipe(key,enabled))
    _refresh_quote();popup_centered();get_cancel_button().grab_focus()
func set_recipe(id: String, enabled: bool) -> void:
    if not switches.has(id):return
    if enabled and id not in selected:
        if selected.size()>=8:switches[id].set_pressed_no_signal(false);return
        selected.append(id)
    elif not enabled:selected.erase(id)
    switches[id].set_pressed_no_signal(enabled)
    staged=false;_refresh_quote()
func _refresh_quote() -> void:
    var ui=owner_ref.get_ref()
    if not is_instance_valid(ui):hide();return
    quote=ui.level.quote_craft_cart(selected)
    var lines: Array[String]=["已选 %d / 8 件" % selected.size()]
    if quote.has("currency_spent"):lines.append("碎钱合计 %d / 持有 %d" % [int(quote.currency_spent),ui.level.currency_count])
    for material in quote.get("materials",{}):lines.append("%s：%d / 持有 %d" % [ui.level._item_display_name(String(material)),int(quote.materials[material]),int(ui.level.inventory_counts.get(material,0))])
    if quote.get("ok",false):lines.append("制作后余额 %d；图样仅出示，不消耗。生命、能量与已有战具次数不补满。" % int(quote.wallet.currency))
    else:lines.append(String(quote.get("reason","请选择制作方案。")))
    summary.text="\n".join(lines)
    get_ok_button().disabled=not quote.get("ok",false)
    get_ok_button().text="核对整单"
func _confirm_cart() -> void:
    var ui=owner_ref.get_ref()
    if not is_instance_valid(ui):hide();return
    var fresh: Dictionary=ui.level.quote_craft_cart(selected)
    if not fresh.get("ok",false):_refresh_quote();staged=false;return
    if not quote.get("ok",false) or String(fresh.fingerprint)!=String(quote.fingerprint):
        _refresh_quote();staged=false;summary.text="条件或价格已变化，请重新核对。\n"+summary.text;get_cancel_button().grab_focus();return
    if not staged:
        staged=true;get_ok_button().text="确认整单并记录"
        summary.text="请再次确认整单。\n"+summary.text;get_cancel_button().grab_focus();return
    var result: Dictionary=ui.level.perform_build_action("craft_batch","",selected)
    if result.get("ok",false):hide();ui.refresh_build()
    else:_refresh_quote();staged=false;summary.text=String(result.get("reason","制作失败"))+"\n"+summary.text
