extends ConfirmationDialog
var owner_ref: WeakRef
var selected: Array[String]=[]
var switches: Dictionary={}
var quote: Dictionary={}
var rows: VBoxContainer
var summary: RichTextLabel
var plan: Dictionary={}
var query: LineEdit
var unfinished: CheckButton
var staged := false
var dependency_window: ConfirmationDialog
var dependency_quote: Dictionary={}
func _ready() -> void:
    title="工匠 · 多件制作清单"
    min_size=Vector2i(760,540);dialog_hide_on_ok=false
    var column:=VBoxContainer.new();column.add_theme_constant_override("separation",10);add_child(column)
    var intro:=Label.new();intro.text="最多选择8件；合计支付，一次记录。任一条件不足时整单不制作。";column.add_child(intro)
    var filters:=HBoxContainer.new();filters.add_theme_constant_override("separation",12);column.add_child(filters)
    query=LineEdit.new();query.placeholder_text="搜索制作名称";query.custom_minimum_size=Vector2(420,34);query.max_length=64;filters.add_child(query)
    unfinished=CheckButton.new();unfinished.text="隐藏已完成改制";filters.add_child(unfinished)
    query.text_changed.connect(func(_value: String):_render_recipes())
    query.text_submitted.connect(func(_value: String):_focus_first_recipe())
    unfinished.toggled.connect(func(_value: bool):_render_recipes())
    var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(700,180);column.add_child(scroll)
    rows=VBoxContainer.new();rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(rows)
    summary=RichTextLabel.new();summary.custom_minimum_size=Vector2(700,220);summary.bbcode_enabled=false;summary.scroll_active=true
    summary.focus_mode=Control.FOCUS_ALL;summary.add_theme_font_size_override("normal_font_size",17);column.add_child(summary)
    get_ok_button().text="核对整单";get_cancel_button().text="取消制作"
    add_button("规划前阶分批",true,"dependencies")
    var clear:=add_button("清空已选",true,"clear")
    clear.tooltip_text="只清空制作清单，不消费资源。筛选隐藏的选择也会清空。"
    custom_action.connect(func(action: String):
        if action=="dependencies" and visible:open_dependencies();return
        if action!="clear" or not visible:return
        selected.clear();staged=false;_render_recipes();_refresh_quote();get_cancel_button().grab_focus())
    confirmed.connect(_confirm_cart)
    visibility_changed.connect(func():
        if not visible and is_instance_valid(dependency_window):dependency_window.hide();dependency_quote={})
func setup(ui: Node) -> void:owner_ref=weakref(ui)
func open() -> void:
    var ui=owner_ref.get_ref()
    if not is_instance_valid(ui):return
    selected.clear();switches.clear();quote.clear();staged=false
    query.text="";unfinished.set_pressed_no_signal(false)
    _render_recipes();_refresh_quote();popup_centered();get_cancel_button().grab_focus()
func _render_recipes() -> void:
    var ui=owner_ref.get_ref()
    if not is_instance_valid(ui) or ui.is_queued_for_deletion() or not is_instance_valid(ui.level):return
    for child in rows.get_children():rows.remove_child(child);child.queue_free()
    switches.clear()
    var artisan: String=ui.level.near_artisan_id()
    var search:=query.text.strip_edges().to_lower()
    for id in ui.level.build_system.catalog.recipes:
        var recipe: Dictionary=ui.level.build_system.catalog.recipes[id]
        if not String(recipe.get("artisan","")) in ["",artisan]:continue
        var key:=String(id)
        var made: bool=ui.level.build_system.state.crafted.has(key)
        if unfinished.button_pressed and made:continue
        if not search.is_empty() and not String(recipe.name).to_lower().contains(search):continue
        var button:=CheckButton.new();button.text=String(recipe.name)+" · %d碎钱" % int(recipe.currency)+(" · 已完成" if made else "")
        rows.add_child(button);switches[key]=button
        button.set_pressed_no_signal(selected.has(key))
        button.toggled.connect(func(enabled: bool):set_recipe(key,enabled))
    if switches.is_empty():
        var empty:=Label.new();empty.text="当前筛选没有制作方案；已选清单仍保留。";rows.add_child(empty)
func _focus_first_recipe() -> void:
    for button in switches.values():
        if button is BaseButton and not button.disabled:button.grab_focus();return
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
    if not is_instance_valid(ui) or ui.is_queued_for_deletion() or not is_instance_valid(ui.level):hide();return
    quote=ui.level.quote_craft_cart(selected)
    plan=preload("res://scripts/craft_material_plan.gd").report(ui.level.build_system,selected,ui.level._build_wallet_snapshot())
    summary.text="已选 %d / 8 件\n" % selected.size()+preload("res://scripts/craft_material_plan.gd").text(plan,
        func(id: String):return String(ui.level.build_system.catalog.recipes[id].name) if ui.level.build_system.catalog.recipes.has(id) else ui.level._item_display_name(id),
        func(id: String):return ui.level._item_display_description(id))
    if not quote.get("ok",false):summary.text+="\n当前工匠："+String(quote.get("reason","请选择制作方案。"))
    summary.scroll_to_line(0)
    get_ok_button().disabled=not quote.get("ok",false)
    get_ok_button().text="核对整单"
func _confirm_cart() -> void:
    if not visible or not is_inside_tree() or is_queued_for_deletion():return
    var ui=owner_ref.get_ref()
    if not is_instance_valid(ui) or ui.is_queued_for_deletion() or not is_instance_valid(ui.level):hide();return
    if not ui.build_panel.is_visible_in_tree():return
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

func _dependency_plan() -> Dictionary:
    var ui: Variant=owner_ref.get_ref() if owner_ref!=null else null
    if not is_instance_valid(ui) or not is_instance_valid(ui.level):return {"ok":false,"reason":"工匠界面已关闭。"}
    return preload("res://scripts/craft_dependency_plan.gd").plan(ui.level.build_system.catalog.recipes,ui.level.build_system.state.crafted,selected,ui.level.near_artisan_id())

func open_dependencies() -> void:
    dependency_quote=_dependency_plan()
    if not dependency_quote.ok:summary.text=String(dependency_quote.reason);return
    if not is_instance_valid(dependency_window):
        dependency_window=ConfirmationDialog.new();dependency_window.title="前阶改制分批核对"
        dependency_window.min_size=Vector2i(720,480);dependency_window.dialog_hide_on_ok=false
        dependency_window.get_ok_button().text="使用下一批清单"
        var text:=RichTextLabel.new();text.name="DependencyText";text.custom_minimum_size=Vector2(660,380)
        text.bbcode_enabled=false;text.focus_mode=Control.FOCUS_ALL;dependency_window.add_child(text)
        add_child(dependency_window)
        var ui: Variant=owner_ref.get_ref();ui.register_text_entry_window(dependency_window)
        dependency_window.confirmed.connect(_use_dependencies)
    dependency_window.get_node("DependencyText").text=preload("res://scripts/craft_dependency_plan.gd").describe(dependency_quote)
    dependency_window.popup_centered();dependency_window.get_cancel_button().grab_focus()

func _use_dependencies() -> void:
    if not visible or not dependency_window.visible:return
    var fresh:=_dependency_plan()
    if not fresh.ok:dependency_window.hide();summary.text=String(fresh.reason);return
    if fresh.fingerprint!=dependency_quote.get("fingerprint",""):
        dependency_quote=fresh
        dependency_window.get_node("DependencyText").text="前阶或目标已变化，请重新核对。\n"+preload("res://scripts/craft_dependency_plan.gd").describe(fresh)
        dependency_window.get_cancel_button().grab_focus();return
    selected.assign(fresh.batches[0].ids);staged=false
    dependency_window.hide();_render_recipes();_refresh_quote();get_cancel_button().grab_focus()
