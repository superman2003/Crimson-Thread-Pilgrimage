extends RefCounted
## The bag page: building it, filtering and refreshing inventory, item details, pins and selection.
## Moved out of pilgrimage_interface.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.
const ART := preload("res://scripts/hand_drawn_assets.gd")
const SPACING := preload("res://scripts/ui_spacing_scale.gd")

const TYPE := preload("res://scripts/ui_type_scale.gd")

static func build_bag(ui: Node) -> void:
    ui.bag=ui._panel(ui,"巡礼行囊",Vector2(85,54),Vector2(1110,600))
    ui.bag.name="BackpackOverlay"
    ui._well(ui.bag,Vector2(724,136),Vector2(356,444))
    ui._well(ui.bag,Vector2(26,186),Vector2(665,354))
    ui._label(ui.bag,"器物有用途，旧物有来处。",Vector2(34,101),Vector2(260,26),16,ui.MUTED)
    ui._icon(ui.bag,ART.item("currency"),Vector2(848,31),Vector2(28,28))
    ui.bag_currency=ui._label(ui.bag,"",Vector2(883,32),Vector2(120,30),20,ui.GOLD)
    var categories:= ["全部","织具","遗物","材料","要物","旅记"]
    for i in categories.size():
        var category: String=categories[i]
        var button = ui._button(ui.bag,category,Vector2(34+i*108,136),Vector2(100,38),func():
            ui.bag_category=category
            ui.refresh_inventory())
        ui.bag_tabs.append(button)
        button.set_meta("inscription_tab",true)
        button.add_theme_font_size_override("font_size",20)
    var scroll:=ScrollContainer.new()
    scroll.position=Vector2(34,194)
    scroll.size=Vector2(645,337)
    scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    ui.bag.add_child(scroll)
    ui.bag_scroll=scroll
    ui.journal_filters=HBoxContainer.new()
    ui.journal_filters.position=Vector2(34,189)
    ui.journal_filters.add_theme_constant_override("separation",SPACING.ROW)
    ui.journal_filters.visible=false
    ui.bag.add_child(ui.journal_filters)
    var filters:=[["all","全部"],["main","主线"],["quest","委托"],["evidence","证词"],["enemy","敌人"],["ending","结局"],["guide","手册"],["ability","能力"],["people","人物"],["voice","自述"]]
    var filter_width = floorf((645.0-(filters.size()-1)*float(SPACING.ROW))/filters.size())
    for pair in filters:
        var filter_id:=String(pair[0])
        var filter_button = ui._button(ui.journal_filters,String(pair[1]),Vector2.ZERO,Vector2(filter_width,28),func():
            ui.journal_filter=filter_id
            ui.journal_selection=0
            ui.bag_scroll.scroll_vertical=0
            ui.refresh_inventory())
        filter_button.custom_minimum_size=Vector2(filter_width,28)
        filter_button.add_theme_font_size_override("font_size",TYPE.CONTROL)
        ui.journal_filter_buttons[filter_id]=filter_button
    ui.journal_tools=HBoxContainer.new()
    ui.journal_tools.position=Vector2(34,222)
    ui.journal_tools.size=Vector2(645,30)
    ui.journal_tools.add_theme_constant_override("separation",8)
    ui.bag.add_child(ui.journal_tools)
    # Enter the tree before setting text: shaping text on a detached control
    # costs several ms each (see the 10-21 UI rebuild report).
    ui.journal_search=LineEdit.new()
    ui.journal_search.custom_minimum_size=Vector2(236,30)
    ui.journal_search.add_theme_font_size_override("font_size",TYPE.CONTROL)
    ui.journal_tools.add_child(ui.journal_search)
    ui.journal_search.placeholder_text="搜索已知记录 · Ctrl+F"
    ui.journal_search.tooltip_text="只搜索已知标题和正文。空格分词；双引号或中文引号查短语；-词语 排除匹配。"
    ui.journal_search.max_length=80
    ui.journal_search.text_changed.connect(func(_value: String):ui.journal_selection=0;ui.refresh_inventory())
    ui.journal_unread=CheckButton.new()
    ui.journal_unread.add_theme_font_size_override("font_size",TYPE.CONTROL)
    ui.journal_tools.add_child(ui.journal_unread)
    ui.journal_unread.text="仅未读"
    ui.journal_unread.toggled.connect(func(_value: bool):ui.journal_selection=0;ui.refresh_inventory())
    ui.journal_stars=CheckButton.new()
    ui.journal_stars.add_theme_font_size_override("font_size",TYPE.CONTROL)
    ui.journal_tools.add_child(ui.journal_stars)
    ui.journal_stars.text="仅收藏"
    ui.journal_stars.toggled.connect(func(_value: bool):ui.journal_selection=0;ui.refresh_inventory())
    ui.journal_sort=OptionButton.new()
    ui.journal_sort.add_theme_font_size_override("font_size",TYPE.CONTROL)
    ui.journal_sort.custom_minimum_size=Vector2(127,30)
    ui.journal_tools.add_child(ui.journal_sort)
    ui.journal_sort.add_item("旅途顺序")
    ui.journal_sort.add_item("按标题")
    ui.journal_sort.add_item("未读优先")
    preload("res://scripts/journal_find_dialog.gd").install(ui)
    ui.journal_sort.item_selected.connect(func(_index: int):ui.journal_selection=0;ui.refresh_inventory())
    ui.journal_count=ui._label(ui.bag,"",Vector2(34,255),Vector2(645,20),12,ui.MUTED)
    ui.bag_grid=GridContainer.new()
    ui.bag_grid.columns=6
    ui.bag_grid.add_theme_constant_override("h_separation",SPACING.ROW)
    ui.bag_grid.add_theme_constant_override("v_separation",10)
    scroll.add_child(ui.bag_grid)
    var divider:=ColorRect.new()
    divider.position=Vector2(704,178)
    divider.size=Vector2(1,357)
    divider.color=Color(.52,.46,.35,.45)
    divider.mouse_filter=Control.MOUSE_FILTER_IGNORE
    ui.bag.add_child(divider)
    ui.bag_icon=ui._icon(ui.bag,null,Vector2(834,166),Vector2(95,95))
    ui.bag_name=ui._label(ui.bag,"",Vector2(734,273),Vector2(342,34),23)
    ui.bag_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    ui.bag_category_label=ui._label(ui.bag,"",Vector2(734,314),Vector2(342,26),TYPE.BODY,ui.GOLD)
    ui.bag_category_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    ui.bag_description=RichTextLabel.new()
    ui.bag_description.position=Vector2(738,354)
    ui.bag_description.size=Vector2(330,160)
    ui.bag_description.add_theme_font_size_override("normal_font_size",TYPE.ACTION)
    ui.bag_description.add_theme_color_override("default_color",ui.IVORY)
    ui.bag_description.scroll_active=true
    ui.bag.add_child(ui.bag_description)
    ui.bag.visibility_changed.connect(ui._journal_bag_visibility_changed)
    ui.bag_pin=ui._button(ui.bag,"钉在旅记",Vector2(738,533),Vector2(330,35),ui._pin_item)
    ui.journal_mark_button=ui._button(ui.bag,"标为已读",Vector2(738,571),Vector2(160,27),ui._toggle_journal_read)
    ui.journal_star_button=ui._button(ui.bag,"收藏记录",Vector2(908,571),Vector2(160,27),ui._toggle_journal_star)
    ui.journal_mark_button.add_theme_font_size_override("font_size",TYPE.CONTROL)
    ui.journal_star_button.add_theme_font_size_override("font_size",TYPE.CONTROL)
    ui.journal_batch_button=ui._button(ui.bag,"筛选结果标已读",Vector2(562,571),Vector2(166,27),ui._open_journal_batch)
    ui.journal_batch_button.add_theme_font_size_override("font_size",TYPE.CONTROL)
    ui.journal_batch_button.tooltip_text="确认后，将当前筛选中最多256条已知记录标为已读；不推进任务。"
    ui.bag_footer_hint=ui._label(ui.bag,"",Vector2(34,552),Vector2(520,30),TYPE.CAPTION,ui.MUTED)
    ui._refresh_bag_footer_hint()
    ui.legacy_bag_text=ui._label(ui.bag,"",Vector2.ZERO,Vector2.ZERO)
    preload("res://scripts/resource_purpose_dialog.gd").setup(ui)
    preload("res://scripts/journal_mark_desk.gd").install(ui)
    ui.legacy_bag_detail=ui._label(ui.bag,"",Vector2.ZERO,Vector2.ZERO)
    ui.legacy_bag_text.visible=false
    ui.legacy_bag_detail.visible=false


static func matches(ui: Node, category: String) -> bool:
    match ui.bag_category:
        "织具":return category in ["Tools","Abilities","Charms","Upgrades"]
        "遗物":return category=="Relics"
        "材料":return category=="Materials"
        "要物":return category in ["Quest","Combat"]
    return true


static func refresh_inventory(ui: Node) -> void:
    if ui.bag_grid==null:return
    if ui.has_node("JournalMarkDesk"):ui.get_node("JournalMarkDesk").refresh_launcher()
    if ui.bag_category=="旅记":
        var sources = preload("res://scripts/journal_sources.gd").links(String(ui.journal_current_document.get("key","")),ui.level.inventory_counts,ui.level.story_flags)
        ui.bag_pin.disabled=sources.is_empty()
        ui.bag_pin.text="回看来源 · %d条" % sources.size() if not sources.is_empty() else "PgUp/PgDn · LB/RB 翻页"
        ui.bag_pin.tooltip_text="回看本条引用的已知原始记录；关闭后回到原文。" if not sources.is_empty() else "Home 到开头，End 到末尾；切换记录后保留本次阅读位置。"
    if is_instance_valid(ui.journal_source_dialog):ui.journal_source_dialog.refresh_binding()
    if ui.journal_filters!=null:
        ui.journal_filters.visible=ui.bag_category=="旅记"
        ui.bag_scroll.position.y=279 if ui.journal_filters.visible else 194
        ui.bag_scroll.size.y=252 if ui.journal_filters.visible else 337
        for control in [ui.journal_tools,ui.journal_count,ui.journal_mark_button,ui.journal_star_button,ui.journal_batch_button]:control.visible=ui.journal_filters.visible
    ui.begin_inventory_refresh()
    if ui.bag_category=="旅记":
        ui._refresh_journal()
        return
    for item_id in ui._visible_inventory_ids():
        ui.append_inventory_item(item_id)
    ui.finish_inventory_refresh()


static func begin_inventory_refresh(ui: Node) -> void:
    if is_instance_valid(ui.journal_source_dialog):ui.journal_source_dialog.refresh_binding()
    ui._remember_journal_scroll()
    if ui.bag_category!="旅记":
        ui.journal_reading_key=""
        ui.journal_restore_pending=false
    if ui.bag_pin!=null:
        ui.bag_pin.text="PgUp/PgDn · LB/RB 翻页" if ui.bag_category=="旅记" else "钉在旅记"
        ui.bag_pin.tooltip_text="Home 到开头，End 到末尾；切换记录后保留本次阅读位置。" if ui.bag_category=="旅记" else ""
    (ui.bag.get_node("InscribedTitle") as TextureRect).texture=ui.inscription_mark("journal" if ui.bag_category=="旅记" else "inventory")
    (ui.bag.get_node("InscriptionSubtitle") as Label).text="证词与心愿" if ui.bag_category=="旅记" else "器物与旧物"
    for node in ui.bag_grid.get_children():
        ui.bag_grid.remove_child(node)
        node.queue_free()
    ui.bag_currency.text=str(ui.level.currency_count)
    ui.bag_grid.columns=6
    ui.inventory_build_selection=ui._reconcile_inventory_selection()


static func append_inventory_item(ui: Node, item_id: String) -> void:
    var button = ui._button(ui.bag_grid,"",Vector2.ZERO,Vector2(94,98),func():
        ui.level.backpack_selection=ui.level.backpack_entry_ids.find(item_id)
        ui.level._refresh_backpack_detail()
        ui.refresh_inventory())
    button.set_meta("item_id",item_id)
    button.custom_minimum_size=Vector2(94,98)
    if item_id==ui.inventory_build_selection:
        button.add_theme_stylebox_override("normal",ui._style(Color(.2,.065,.055,.2),ui.RED,2))
    ui._icon(button,ART.item(item_id),Vector2(15,8),Vector2(64,58))
    var count: int=ui.level.currency_count if item_id=="currency" else int(ui.level.inventory_counts.get(item_id,0))
    var name_label: Label = ui._label(button,ui.level._item_display_name(item_id),Vector2(4,70),Vector2(87,22),12)
    name_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    ui._label(button,str(count),Vector2(59,48),Vector2(30,23),TYPE.CAPTION,ui.GOLD)


static func finish_inventory_refresh(ui: Node) -> void:
    var selected = ui.inventory_build_selection
    for tab in ui.bag_tabs:
        tab.add_theme_stylebox_override("normal",ui._tab_style(tab.text==ui.bag_category))
    ui.bag_pin.disabled=selected.is_empty()
    if selected.is_empty():
        ui.bag_icon.texture=null
        ui.bag_name.text="这一分类暂无物品"
        ui.bag_category_label.text=ui.bag_category
        ui.bag_description.text=""
        ui.bag_pin.text="钉在旅记"
    else:
        show_inventory_detail(ui, selected)


static func show_inventory_detail(ui: Node, selected: String) -> void:
    ui.bag_icon.texture=ART.item(selected)
    ui.bag_name.text=ui.level._item_display_name(selected)
    ui.bag_category_label.text=category_name(ui, String(ui.level._item_data(selected).get("category","Currency")))+"  ·  "+str(ui.level.currency_count if selected=="currency" else ui.level.inventory_counts.get(selected,0))
    ui.bag_description.text=ui.level._item_display_description(selected)
    if ui.bag_description.text.is_empty():ui.bag_description.text="一路拾得的松脂碎片，可用来兑换巡礼所需。"
    ui.bag_pin.text="取消旅记标记" if bool(ui.level.story_flags.get("ui_pin_"+selected,false)) else "钉在旅记"
    for i in ui.bag_tabs.size():
        ui.bag_tabs[i].add_theme_stylebox_override("normal",ui._tab_style(ui.bag_tabs[i].text==ui.bag_category))


static func category_name(ui: Node, category: String) -> String:
    return {"Tools":"织具","Abilities":"能力","Charms":"铭饰","Upgrades":"强化","Relics":"遗物","Quest":"要物","Materials":"材料","Combat":"印记","Currency":"碎钱"}.get(category,category)


static func pin_item(ui: Node) -> void:
    if ui.bag_category=="旅记":
        ui._open_journal_sources()
        return
    var id: String = ui._reconcile_inventory_selection()
    if id.is_empty():return
    var was_pinned:=bool(ui.level.story_flags.get("ui_pin_"+id,false))
    for key in ui.level.story_flags.keys():
        if String(key).begins_with("ui_pin_"):ui.level.story_flags[key]=false
    ui.level.story_flags["ui_pin_"+id]=not was_pinned
    ui.refresh_inventory()


static func visible_inventory_ids(ui: Node) -> Array[String]:
    var ids: Array[String] = []
    for value in ui.level.backpack_entry_ids:
        var id := String(value)
        if id=="currency":
            if ui.bag_category=="全部":ids.append(id)
            continue
        if ui._matches(String(ui.level._item_data(id).get("category",""))):
            ids.append(id)
    return ids


static func reconcile_inventory_selection(ui: Node) -> String:
    var visible_ids: Array[String] = ui._visible_inventory_ids()
    if visible_ids.is_empty():
        ui.level.backpack_selection=-1
        return ""
    var index: int = ui.level._backpack_selection_clamped()
    var selected := String(ui.level.backpack_entry_ids[index]) if index >= 0 else ""
    if not visible_ids.has(selected):
        selected=visible_ids[0]
        ui.level.backpack_selection=ui.level.backpack_entry_ids.find(selected)
        ui.level._refresh_backpack_detail()
    return selected


static func move_inventory_selection(ui: Node, delta: int) -> void:
    if ui.bag_category=="旅记":
        if ui.bag_grid.get_child_count()>0:
            ui.journal_selection=wrapi(ui.journal_selection+delta,0,ui.bag_grid.get_child_count())
            ui.journal_memory[ui.journal_filter]=String(ui.bag_grid.get_child(ui.journal_selection).get_meta("journal_key",""))
        return
    var selected: String = ui._reconcile_inventory_selection()
    var visible_ids: Array[String] = ui._visible_inventory_ids()
    if visible_ids.is_empty():return
    var next_id = visible_ids[wrapi(visible_ids.find(selected)+delta,0,visible_ids.size())]
    ui.level.backpack_selection=ui.level.backpack_entry_ids.find(next_id)
