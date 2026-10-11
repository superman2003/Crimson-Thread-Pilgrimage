extends Control

const ART := preload("res://scripts/hand_drawn_assets.gd")
const FONT := preload("res://assets/fonts/NotoSansSC.ttf")
const IVORY := Color("e8ddc3")
const GOLD := Color("b5a17c")
const MUTED := Color("999b96")
const RED := Color("b65d59")
var level: Node
var hud_card: Control
var hearts: Label
var thread_bar: ProgressBar
var currency: Label
var location: Label
var prompt: Label
var boss_name: Label
var boss_bar: ProgressBar
var pinned: Label
var bag: ColorRect
var bag_grid: GridContainer
var bag_tabs: Array[Button]=[]
var bag_category := "全部"
var bag_icon: TextureRect
var bag_name: Label
var bag_category_label: Label
var bag_description: RichTextLabel
var bag_pin: Button
var bag_currency: Label
var legacy_bag_text: Label
var legacy_bag_detail: Label
var dialogue: ColorRect
var dialogue_name: Label
var dialogue_identity: Label
var dialogue_body: Label
var dialogue_scroll: ScrollContainer
var dialogue_hint: Label
var dialogue_portrait: TextureRect
var dialogue_area: Area2D
var dialogue_quest_button: Button
var settings: ColorRect
var legacy_settings: Label
var toast: Label
var toast_age := 0.0
var last_toast := ""
var settings_sliders: Dictionary={}
var settings_labels: Dictionary={}
var build_panel: ColorRect
var build_grid: VBoxContainer
var build_detail: RichTextLabel
var build_summary: Label
var build_tabs: Array[Button]=[]
var build_category := "契印"
var build_selection := ""
var build_assign_slot := 0
var build_slot_buttons: Array[Button]=[]
var combat_status: Label
var energy_status: Label
var healing_bar: ProgressBar
var tutorial_hint: Label
var accessibility_path := "user://pilgrimage_accessibility.cfg"
var accessibility: Dictionary={"subtitle_speed":1.0,"subtitle_size":21,"flash_enabled":true,"vibration_enabled":true,"camera_shake":1.0,"camera_lookahead":1.0,"tutorial_hints":true}
var remap_target := ""
var remap_buttons: Dictionary={}
var remap_status: Label
var last_overlay := ""
var build_refresh_elapsed := 0.0
var last_build_signature := ""
var applied_player: Node
var save_slot_buttons: Dictionary={}
var journal_selection := 0

const REMAPPABLE_ACTIONS := {"jump":"跳跃","attack":"普攻","heal":"治疗","skill_1":"施放技能","skill_cycle":"切换技能","tool_cast":"使用战具","tool_cycle":"切换战具","dash":"冲刺","interact":"互动"}

func bind(runtime: Node) -> void:
    level=runtime
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    var ui_theme := Theme.new()
    ui_theme.default_font=FONT
    ui_theme.default_font_size=18
    theme=ui_theme
    _load_accessibility()
    _build_hud()
    _build_bag()
    _build_dialogue()
    _build_settings()
    _build_build_panel()
    _bind_ui_navigation()

func _label(parent: Node, text: String, position_value: Vector2, size_value: Vector2, font_size: int=18, tint: Color=IVORY) -> Label:
    var label:=Label.new()
    label.text=text
    label.position=position_value
    label.size=size_value
    label.add_theme_font_size_override("font_size",font_size)
    label.add_theme_color_override("font_color",tint)
    label.mouse_filter=Control.MOUSE_FILTER_IGNORE
    parent.add_child(label)
    return label

func _style(tint: Color, border: Color, width: int=1) -> StyleBoxFlat:
    var style:=StyleBoxFlat.new()
    style.bg_color=tint
    style.border_color=border
    style.set_border_width_all(width)
    style.set_corner_radius_all(3)
    style.content_margin_left=10
    style.content_margin_right=10
    return style

func _button(parent: Node, text: String, position_value: Vector2, size_value: Vector2, action: Callable) -> Button:
    var button:=Button.new()
    button.text=text
    button.position=position_value
    button.size=size_value
    button.add_theme_font_size_override("font_size",17)
    button.add_theme_color_override("font_color",IVORY)
    button.add_theme_stylebox_override("normal",_style(Color("252a2c"),Color("4c514d")))
    button.add_theme_stylebox_override("hover",_style(Color("343838"),GOLD))
    button.add_theme_stylebox_override("focus",_style(Color(0,0,0,0),GOLD,2))
    button.add_theme_stylebox_override("pressed",_style(Color("3c3332"),RED,2))
    button.pressed.connect(action)
    parent.add_child(button)
    return button

func _panel(parent: Node, title: String, position_value: Vector2, size_value: Vector2) -> ColorRect:
    var root:=ColorRect.new()
    root.position=position_value
    root.size=size_value
    root.color=Color(0.035,0.047,0.053,.98)
    root.visible=false
    parent.add_child(root)
    frame(root)
    _label(root,title,Vector2(32,22),Vector2(size_value.x-120,44),30)
    _button(root,"返回",Vector2(size_value.x-91,24),Vector2(62,34),func():level._close_overlays())
    return root

func frame(control: Control) -> void:
    var outer:=Panel.new()
    outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    outer.mouse_filter=Control.MOUSE_FILTER_IGNORE
    outer.add_theme_stylebox_override("panel",_style(Color(0,0,0,0),Color(.55,.49,.37,.6)))
    control.add_child(outer)
    for x in [16.0,control.size.x-16]:
        var ornament:=Label.new()
        ornament.text="◇"
        ornament.position=Vector2(x-8,8)
        ornament.add_theme_color_override("font_color",GOLD)
        ornament.mouse_filter=Control.MOUSE_FILTER_IGNORE
        control.add_child(ornament)

func _icon(parent: Node, asset: Texture2D, position_value: Vector2, size_value: Vector2) -> TextureRect:
    var icon:=TextureRect.new()
    icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    icon.texture=asset
    icon.position=position_value
    icon.size=size_value
    icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
    parent.add_child(icon)
    return icon

func _build_hud() -> void:
    hud_card=Control.new()
    hud_card.position=Vector2(28,24)
    hud_card.size=Vector2(260,100)
    hud_card.mouse_filter=Control.MOUSE_FILTER_IGNORE
    add_child(hud_card)
    hearts=_label(hud_card,"",Vector2(0,0),Vector2(260,42),29)
    _icon(hud_card,ART.item("thread_burst"),Vector2(2,47),Vector2(32,32))
    _label(hud_card,"绯线",Vector2(45,42),Vector2(65,24),14,GOLD)
    thread_bar=ProgressBar.new()
    thread_bar.position=Vector2(45,71)
    thread_bar.size=Vector2(165,5)
    thread_bar.custom_minimum_size=Vector2(0,5)
    thread_bar.show_percentage=false
    thread_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
    thread_bar.add_theme_stylebox_override("background",_style(Color("24272c"),Color("424747")))
    thread_bar.add_theme_stylebox_override("fill",_style(RED,RED,0))
    thread_bar.add_theme_constant_override("outline_size",0)
    thread_bar.add_theme_font_size_override("font_size",1)
    thread_bar.size=Vector2(165,5)
    hud_card.add_child(thread_bar)
    _icon(self,ART.item("currency"),Vector2(1080,26),Vector2(30,30))
    currency=_label(self,"0",Vector2(1118,29),Vector2(132,30),22)
    location=_label(self,"",Vector2(390,25),Vector2(500,30),19,GOLD)
    location.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    toast=_label(self,"",Vector2(330,87),Vector2(620,56),17,IVORY)
    toast.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    toast.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    prompt=_label(self,"",Vector2(390,577),Vector2(500,40),19,IVORY)
    prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    prompt.add_theme_color_override("font_shadow_color",Color(0,0,0,.9))
    prompt.add_theme_constant_override("shadow_offset_x",2)
    prompt.add_theme_constant_override("shadow_offset_y",2)
    energy_status=_label(hud_card,"",Vector2(106,42),Vector2(145,24),14,GOLD)
    combat_status=_label(self,"",Vector2(28,94),Vector2(420,78),14,IVORY)
    combat_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    healing_bar=ProgressBar.new()
    healing_bar.position=Vector2(28,178)
    healing_bar.size=Vector2(220,8)
    healing_bar.show_percentage=false
    healing_bar.max_value=1.0
    healing_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
    healing_bar.visible=false
    add_child(healing_bar)
    pinned=_label(self,"",Vector2(28,192),Vector2(290,45),15,MUTED)
    pinned.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    tutorial_hint=_label(self,"",Vector2(28,648),Vector2(535,58),13,MUTED)
    tutorial_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    _button(self,"B  构筑",Vector2(875,674),Vector2(95,30),_request_build_toggle)
    _button(self,"Tab  行囊",Vector2(978,674),Vector2(100,30),func():level._toggle_backpack())
    _button(self,"M  地图",Vector2(1088,674),Vector2(85,30),func():level._toggle_map())
    _button(self,"V  设置",Vector2(1181,674),Vector2(85,30),func():level._toggle_audio_settings())
    boss_name=_label(self,"",Vector2(330,635),Vector2(620,27),18,GOLD)
    boss_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    boss_bar=ProgressBar.new()
    boss_bar.position=Vector2(348,667)
    boss_bar.size=Vector2(584,5)
    boss_bar.show_percentage=false
    boss_bar.add_theme_font_size_override("font_size",1)
    boss_bar.add_theme_constant_override("outline_size",0)
    boss_bar.add_theme_stylebox_override("background",_style(Color("20262a"),GOLD))
    boss_bar.add_theme_stylebox_override("fill",_style(Color("a16f5e"),Color("a16f5e"),0))
    boss_bar.size=Vector2(584,5)
    boss_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
    add_child(boss_bar)

func _build_bag() -> void:
    bag=_panel(self,"巡礼行囊",Vector2(85,54),Vector2(1110,600))
    bag.name="BackpackOverlay"
    _label(bag,"器物有用途，旧物有来处。",Vector2(34,70),Vector2(640,30),16,MUTED)
    _icon(bag,ART.item("currency"),Vector2(848,31),Vector2(28,28))
    bag_currency=_label(bag,"",Vector2(883,32),Vector2(120,30),20,GOLD)
    var categories:= ["全部","织具","遗物","材料","要物","旅记"]
    for i in categories.size():
        var category: String=categories[i]
        var button:=_button(bag,category,Vector2(34+i*108,119),Vector2(100,38),func():
            bag_category=category
            refresh_inventory())
        bag_tabs.append(button)
    var scroll:=ScrollContainer.new()
    scroll.position=Vector2(34,180)
    scroll.size=Vector2(645,357)
    scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    bag.add_child(scroll)
    bag_grid=GridContainer.new()
    bag_grid.columns=6
    bag_grid.add_theme_constant_override("h_separation",9)
    bag_grid.add_theme_constant_override("v_separation",10)
    scroll.add_child(bag_grid)
    var divider:=ColorRect.new()
    divider.position=Vector2(704,178)
    divider.size=Vector2(1,357)
    divider.color=Color(.52,.46,.35,.45)
    divider.mouse_filter=Control.MOUSE_FILTER_IGNORE
    bag.add_child(divider)
    bag_icon=_icon(bag,null,Vector2(834,166),Vector2(95,95))
    bag_name=_label(bag,"",Vector2(734,273),Vector2(342,34),23)
    bag_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    bag_category_label=_label(bag,"",Vector2(734,314),Vector2(342,26),15,GOLD)
    bag_category_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    bag_description=RichTextLabel.new()
    bag_description.position=Vector2(738,354)
    bag_description.size=Vector2(330,160)
    bag_description.add_theme_font_size_override("normal_font_size",17)
    bag_description.add_theme_color_override("default_color",IVORY)
    bag_description.scroll_active=true
    bag.add_child(bag_description)
    bag_pin=_button(bag,"钉在旅记",Vector2(738,533),Vector2(330,35),_pin_item)
    _label(bag,"W/S 查看  ·  点击分类与物品  ·  Esc 返回",Vector2(34,552),Vector2(645,30),15,MUTED)
    legacy_bag_text=_label(bag,"",Vector2.ZERO,Vector2.ZERO)
    legacy_bag_detail=_label(bag,"",Vector2.ZERO,Vector2.ZERO)
    legacy_bag_text.visible=false
    legacy_bag_detail.visible=false

func _matches(category: String) -> bool:
    match bag_category:
        "织具":return category in ["Tools","Abilities","Charms","Upgrades"]
        "遗物":return category=="Relics"
        "材料":return category=="Materials"
        "要物":return category in ["Quest","Combat"]
    return true

func refresh_inventory() -> void:
    if bag_grid==null:return
    for node in bag_grid.get_children():
        bag_grid.remove_child(node)
        node.queue_free()
    bag_currency.text=str(level.currency_count)
    if bag_category=="旅记":
        _refresh_journal()
        return
    bag_grid.columns=6
    var selected := _reconcile_inventory_selection()
    for item_value in _visible_inventory_ids():
        var item_id:=String(item_value)
        var button:=_button(bag_grid,"",Vector2.ZERO,Vector2(94,98),func():
            level.backpack_selection=level.backpack_entry_ids.find(item_id)
            level._refresh_backpack_detail()
            refresh_inventory())
        button.set_meta("item_id",item_id)
        button.custom_minimum_size=Vector2(94,98)
        if item_id==selected:
            button.add_theme_stylebox_override("normal",_style(Color("343531"),GOLD,2))
        _icon(button,ART.item(item_id),Vector2(15,8),Vector2(64,58))
        var count: int=level.currency_count if item_id=="currency" else int(level.inventory_counts.get(item_id,0))
        var name_label:=_label(button,level._item_display_name(item_id),Vector2(4,70),Vector2(87,22),12)
        name_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
        _label(button,str(count),Vector2(59,48),Vector2(30,23),13,GOLD)
    for tab in bag_tabs:
        tab.add_theme_stylebox_override("normal",_style(Color("343531") if tab.text==bag_category else Color("252a2c"),GOLD if tab.text==bag_category else Color("4c514d")))
    bag_pin.disabled=selected.is_empty()
    if selected.is_empty():
        bag_icon.texture=null
        bag_name.text="这一分类暂无物品"
        bag_category_label.text=bag_category
        bag_description.text=""
        bag_pin.text="钉在旅记"
    else:
        _show_inventory_detail(selected)


func _show_inventory_detail(selected: String) -> void:
    bag_icon.texture=ART.item(selected)
    bag_name.text=level._item_display_name(selected)
    bag_category_label.text=_category_name(String(level._item_data(selected).get("category","Currency")))+"  ·  "+str(level.currency_count if selected=="currency" else level.inventory_counts.get(selected,0))
    bag_description.text=level._item_display_description(selected)
    if bag_description.text.is_empty():bag_description.text="一路拾得的松脂碎片，可用来兑换巡礼所需。"
    bag_pin.text="取消旅记标记" if bool(level.story_flags.get("ui_pin_"+selected,false)) else "钉在旅记"
    for i in bag_tabs.size():
        bag_tabs[i].add_theme_stylebox_override("normal",_style(Color("343531") if bag_tabs[i].text==bag_category else Color("252a2c"),GOLD if bag_tabs[i].text==bag_category else Color("4c514d")))

func _category_name(category: String) -> String:
    return {"Tools":"织具","Abilities":"能力","Charms":"铭饰","Upgrades":"强化","Relics":"遗物","Quest":"要物","Materials":"材料","Combat":"印记","Currency":"碎钱"}.get(category,category)

func _pin_item() -> void:
    var id := _reconcile_inventory_selection()
    if id.is_empty():return
    var was_pinned:=bool(level.story_flags.get("ui_pin_"+id,false))
    for key in level.story_flags.keys():
        if String(key).begins_with("ui_pin_"):level.story_flags[key]=false
    level.story_flags["ui_pin_"+id]=not was_pinned
    refresh_inventory()

func _build_dialogue() -> void:
    dialogue=_panel(self,"",Vector2(72,374),Vector2(1136,300))
    dialogue.name="DialogueOverlay"
    dialogue_portrait=_icon(dialogue,null,Vector2(23,21),Vector2(173,191))
    dialogue_name=_label(dialogue,"",Vector2(221,19),Vector2(770,37),26,GOLD)
    dialogue_identity=_label(dialogue,"",Vector2(221,57),Vector2(770,28),14,MUTED)
    dialogue_scroll=ScrollContainer.new()
    dialogue_scroll.position=Vector2(221,93)
    dialogue_scroll.size=Vector2(854,140)
    dialogue_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    dialogue_scroll.focus_mode=Control.FOCUS_ALL
    dialogue.add_child(dialogue_scroll)
    dialogue_body=_label(dialogue_scroll,"",Vector2.ZERO,Vector2(854,140),int(accessibility["subtitle_size"]),IVORY)
    dialogue_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    dialogue_body.custom_minimum_size=Vector2(825,0)
    dialogue_body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    dialogue_hint=_label(dialogue,"F 继续  ·  Esc 离开",Vector2(24,270),Vector2(180,24),13,MUTED)
    _button(dialogue,"继续交谈",Vector2(221,250),Vector2(147,34),func():
        if is_instance_valid(dialogue_area):
            if level.world_mode:level._try_interact()
            else:level._talk_to_npc(dialogue_area))
    _button(dialogue,"问问道路",Vector2(380,250),Vector2(147,34),func():_topic("route"))
    dialogue_quest_button=_button(dialogue,"询问心愿",Vector2(540,250),Vector2(147,34),func():_topic("wish"))

func show_speaker(area: Area2D) -> void:
    dialogue_area=area
    dialogue_scroll.scroll_vertical=0
    dialogue_portrait.texture=ART.portrait(String(area.get_meta("npc_id","")))
    dialogue_hint.text="F 继续  ·  Esc 离开"
    var topics: Dictionary=area.get_meta("dialogue_topics",{})
    var quest: Dictionary=topics.get("quest",{})
    dialogue_quest_button.text="询问心愿"
    if not quest.is_empty():
        var required:=String(quest.get("item",""))
        if level.inventory_counts.has(required) and not bool(level.story_flags.get(String(quest.get("complete_flag","")),false)):
            dialogue_quest_button.text="交付信物"
    var sprite:=area.get_node_or_null("FriendlyFamilySprite") as AnimatedSprite2D
    if sprite!=null:sprite.play("talk")

func _topic(key: String) -> void:
    if not is_instance_valid(dialogue_area):return
    if level.world_mode:
        level._commit_world_dialogue()
        # A route/wish answer is not an unread final line from the story round.
        dialogue_area.set_meta("world_line_committed",true)
        dialogue_area.set_meta("world_displayed_index",-1)
    var topics: Dictionary=dialogue_area.get_meta("dialogue_topics",{})
    var line:=String(topics.get(key,"你若愿意听，我们就再坐一会儿。"))
    if key=="wish":
        var quest: Dictionary=topics.get("quest",{})
        if not quest.is_empty():
            var required:=String(quest.get("item",""))
            var flag:=String(quest.get("complete_flag",""))
            if level.inventory_counts.has(required) and not bool(level.story_flags.get(flag,false)):
                level._set_story_flag(flag)
                if bool(quest.get("consume",false)):
                    level.inventory_counts[required]=int(level.inventory_counts[required])-1
                    if int(level.inventory_counts[required])<=0:level.inventory_counts.erase(required)
                    if level.inventory_materials.has(required):
                        level.inventory_materials[required]=maxi(0,int(level.inventory_materials[required])-1)
                        if int(level.inventory_materials[required])==0:level.inventory_materials.erase(required)
                var reward:=String(quest.get("reward",""))
                if not reward.is_empty():level._add_inventory_item(reward,1,true)
                line=String(quest.get("thanks","我会记住你带回的消息。"))
            else:
                level._set_story_flag(String(quest.get("accept_flag","")))
    level._show_dialogue(dialogue_area,line)
    if level.world_mode:level._save_world()

func close_dialogue() -> void:
    if is_instance_valid(dialogue_area):
        var sprite:=dialogue_area.get_node_or_null("FriendlyFamilySprite") as AnimatedSprite2D
        if sprite!=null:sprite.play("idle")
    dialogue_area=null

func _build_settings() -> void:
    settings=_panel(self,"设置与无障碍",Vector2(135,48),Vector2(1010,618))
    settings.name="AudioSettingsOverlay"
    _label(settings,"声音",Vector2(34,76),Vector2(440,30),20,GOLD)
    var rows: Array=level.AUDIO_SETTINGS_ROWS
    for i in rows.size():
        var key:=String(rows[i][0])
        settings_labels[key]=_label(settings,String(rows[i][1]).split(" ")[0],Vector2(34,118+i*43),Vector2(145,30),16)
        var slider:=HSlider.new()
        slider.position=Vector2(190,124+i*43)
        slider.size=Vector2(257,22)
        slider.min_value=0
        slider.max_value=100
        slider.step=1
        slider.value=level.audio_director.get_user_volume(key) if level.audio_director!=null else 100
        slider.value_changed.connect(func(value: float):
            level.settings_selection=i
            refresh_settings_selection()
            if level.audio_director!=null:level.audio_director.set_user_volume(key,value))
        settings.add_child(slider)
        settings_sliders[key]=slider
    _label(settings,"阅读与画面",Vector2(512,76),Vector2(440,30),20,GOLD)
    _accessibility_slider("subtitle_size","字幕字号",Vector2(512,117),17,26,1)
    _accessibility_slider("subtitle_speed","字幕速度",Vector2(512,160),0.5,2.0,0.25)
    _accessibility_slider("camera_shake","镜头震动",Vector2(512,203),0,1,0.25)
    _accessibility_slider("camera_lookahead","镜头前瞻",Vector2(512,246),0,1,0.25)
    _accessibility_toggle("flash_enabled","受击闪光",Vector2(512,299))
    _accessibility_toggle("vibration_enabled","手柄震动",Vector2(725,299))
    _accessibility_toggle("tutorial_hints","探索提示",Vector2(512,339))
    _label(settings,"按键重映射 · 选择动作后按键、按钮或推动扳机",Vector2(34,394),Vector2(928,28),17,GOLD)
    var action_index:=0
    for action in REMAPPABLE_ACTIONS:
        var action_id:=String(action)
        var button:=_button(settings,"",Vector2(34+(action_index%3)*311,426+(action_index/3)*33),Vector2(294,29),func():_begin_remap(action_id))
        button.add_theme_font_size_override("font_size",13)
        remap_buttons[action_id]=button
        action_index+=1
    remap_status=_label(settings,"Esc 取消重映射；方向键 / 手柄十字键选择，确认键操作。",Vector2(34,532),Vector2(927,35),13,MUTED)
    remap_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    for slot_index in 3:
        var slot:=slot_index+1
        save_slot_buttons[slot]=_button(settings,"存档槽 %d" % slot,Vector2(34+slot_index*219,573),Vector2(206,30),func():_select_save_slot(slot))
        save_slot_buttons[slot].add_theme_font_size_override("font_size",13)
        save_slot_buttons[slot].text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    _button(settings,"恢复当前槽备份",Vector2(691,573),Vector2(281,30),_restore_save_backup)
    legacy_settings=_label(settings,"",Vector2.ZERO,Vector2.ZERO)
    legacy_settings.visible=false
    refresh_settings_selection()
    _refresh_remap_labels()

func _accessibility_slider(key: String, title: String, point: Vector2, minimum: float, maximum: float, increment: float) -> void:
    var value_label:=_label(settings,"",point,Vector2(176,28),16)
    var slider:=HSlider.new()
    slider.position=point+Vector2(181,7)
    slider.size=Vector2(253,22)
    slider.min_value=minimum
    slider.max_value=maximum
    slider.step=increment
    slider.value=float(accessibility[key])
    value_label.text=title+"  "+str(slider.value)
    slider.value_changed.connect(func(value: float):
        accessibility[key]=int(value) if key=="subtitle_size" else value
        value_label.text=title+"  "+str(value)
        _save_accessibility()
        _apply_accessibility())
    settings.add_child(slider)

func _accessibility_toggle(key: String, title: String, point: Vector2) -> void:
    var toggle:=CheckButton.new()
    toggle.text=title
    toggle.position=point
    toggle.size=Vector2(206,35)
    toggle.button_pressed=bool(accessibility[key])
    toggle.toggled.connect(func(value: bool):
        accessibility[key]=value
        _save_accessibility()
        _apply_accessibility())
    settings.add_child(toggle)

func get_accessibility(key: String, fallback: Variant=null) -> Variant:
    return accessibility.get(key,fallback)

func _load_accessibility() -> void:
    var config:=ConfigFile.new()
    if config.load(accessibility_path)!=OK:return
    for key in accessibility:
        accessibility[key]=config.get_value("accessibility",key,accessibility[key])
    accessibility["subtitle_size"]=clampi(int(accessibility["subtitle_size"]),17,26)
    accessibility["subtitle_speed"]=clampf(float(accessibility["subtitle_speed"]),0.5,2.0)
    accessibility["camera_shake"]=clampf(float(accessibility["camera_shake"]),0,1)
    accessibility["camera_lookahead"]=clampf(float(accessibility["camera_lookahead"]),0,1)
    for action in REMAPPABLE_ACTIONS:
        if not InputMap.has_action(action):continue
        var events: Variant=config.get_value("bindings",action,[])
        if events is Array and not events.is_empty():
            InputMap.action_erase_events(action)
            for event in events:
                if event is InputEvent:InputMap.action_add_event(action,event)

func _save_accessibility() -> void:
    var config:=ConfigFile.new()
    for key in accessibility:config.set_value("accessibility",key,accessibility[key])
    for action in REMAPPABLE_ACTIONS:
        if InputMap.has_action(action):config.set_value("bindings",action,InputMap.action_get_events(action))
    var result:=config.save(accessibility_path)
    if result!=OK and toast!=null:toast.text="设置保存失败（%d），当前设置仍有效。" % result

func _apply_accessibility() -> void:
    if dialogue_body!=null:dialogue_body.add_theme_font_size_override("font_size",int(accessibility["subtitle_size"]))
    if build_detail!=null:build_detail.add_theme_font_size_override("normal_font_size",int(accessibility["subtitle_size"]))
    if level!=null and is_instance_valid(level.player):
        level.player.set_meta("accessibility",accessibility.duplicate())
        applied_player=level.player

func _begin_remap(action: String) -> void:
    remap_target=action
    remap_status.text="请为「%s」按一个键或手柄按钮；Esc 取消。" % REMAPPABLE_ACTIONS[action]

func _refresh_remap_labels() -> void:
    for action in remap_buttons:
        var names: Array[String]=[]
        if InputMap.has_action(action):
            for event in InputMap.action_get_events(action):names.append(_binding_name(event))
        remap_buttons[action].text=String(REMAPPABLE_ACTIONS[action])+" · "+(" / ".join(names) if not names.is_empty() else "未设置")
        remap_buttons[action].text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
        remap_buttons[action].tooltip_text=remap_buttons[action].text

func _input(event: InputEvent) -> void:
    if level==null:return
    if not settings.visible:remap_target=""
    if not remap_target.is_empty():
        if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
            remap_target=""
            remap_status.text="已取消重映射。"
            get_viewport().set_input_as_handled()
        elif (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventJoypadButton and event.pressed) or (event is InputEventJoypadMotion and absf(event.axis_value)>0.7):
            if event is InputEventKey and event.physical_keycode in [KEY_B,KEY_TAB,KEY_I,KEY_M,KEY_V]:
                remap_status.text="此输入保留给界面快捷键，请换一个输入或 Esc 取消。"
                get_viewport().set_input_as_handled()
                return
            if event is InputEventJoypadButton and event.button_index in [JOY_BUTTON_START,JOY_BUTTON_LEFT_STICK,JOY_BUTTON_RIGHT_STICK]:
                remap_status.text="此手柄按钮保留给界面入口，请换一个按钮或 Esc 取消。"
                get_viewport().set_input_as_handled()
                return
            var accepted:=event.duplicate() as InputEvent
            if accepted is InputEventJoypadMotion:accepted.axis_value=1.0 if accepted.axis_value>0 else -1.0
            var action:=remap_target
            var conflicts: Array[String]=[]
            # Only reject a duplicate on another gameplay action on the same device;
            # keyboard and controller bindings for one action remain independent.
            for other in InputMap.get_actions():
                if other==action or String(other).begins_with("ui_") or other=="close_overlay":continue
                if InputMap.event_is_action(accepted,other):conflicts.append(String(REMAPPABLE_ACTIONS.get(other,"其他动作")))
            if not conflicts.is_empty():
                remap_status.text="此输入已用于「%s」，请换一个输入或 Esc 取消。" % "、".join(conflicts)
                get_viewport().set_input_as_handled()
                return
            if not InputMap.has_action(action):InputMap.add_action(action)
            for old in InputMap.action_get_events(action):
                if (old is InputEventKey and accepted is InputEventKey) or ((old is InputEventJoypadButton or old is InputEventJoypadMotion) and (accepted is InputEventJoypadButton or accepted is InputEventJoypadMotion)):InputMap.action_erase_event(action,old)
            InputMap.action_add_event(action,accepted)
            remap_target=""
            _save_accessibility()
            _refresh_remap_labels()
            remap_status.text="已保存「%s」的新输入；另一种设备的绑定继续可用。" % REMAPPABLE_ACTIONS[action]
            get_viewport().set_input_as_handled()
        return
    if bag.visible and event is InputEventKey and event.pressed and event.physical_keycode in [KEY_UP,KEY_DOWN]:
        # Main polls these keys to move bag selection; consume GUI navigation
        # so one key never advances both the gameplay selection and focus.
        get_viewport().set_input_as_handled()
        return
    if (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_B) or (event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_LEFT_STICK):
        _request_build_toggle()
        get_viewport().set_input_as_handled()

func _bind_ui_navigation() -> void:
    for pair in [["ui_up",JOY_BUTTON_DPAD_UP],["ui_down",JOY_BUTTON_DPAD_DOWN],["ui_left",JOY_BUTTON_DPAD_LEFT],["ui_right",JOY_BUTTON_DPAD_RIGHT],["ui_accept",JOY_BUTTON_A],["close_overlay",JOY_BUTTON_B],["inventory",JOY_BUTTON_START],["map",JOY_BUTTON_RIGHT_STICK],["interact",JOY_BUTTON_BACK]]:
        var action:=String(pair[0])
        if not InputMap.has_action(action):InputMap.add_action(action)
        var event:=InputEventJoypadButton.new()
        event.button_index=int(pair[1])
        if not InputMap.action_has_event(action,event):InputMap.action_add_event(action,event)

func _build_build_panel() -> void:
    build_panel=_panel(self,"契印与构筑",Vector2(85,54),Vector2(1110,600))
    build_panel.name="BuildOverlay"
    build_summary=_label(build_panel,"",Vector2(34,72),Vector2(1030,42),16,GOLD)
    var categories: Array[String]=["契印","技能","战具","铭饰","强化","构筑"]
    for i in categories.size():
        var category:=categories[i]
        var tab:=_button(build_panel,category,Vector2(34+i*173,121),Vector2(162,38),func():
            build_category=category
            build_selection=""
            refresh_build())
        build_tabs.append(tab)
    var scroll:=ScrollContainer.new()
    scroll.position=Vector2(34,180)
    scroll.size=Vector2(575,352)
    scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    build_panel.add_child(scroll)
    build_grid=VBoxContainer.new()
    build_grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    build_grid.add_theme_constant_override("separation",8)
    scroll.add_child(build_grid)
    build_detail=RichTextLabel.new()
    for slot_index in 2:
        var slot:=slot_index
        var slot_button:=_button(build_panel,"装备位置 %d" % (slot+1),Vector2(640+slot*216,174),Vector2(207,33),func():
            build_assign_slot=slot
            refresh_build())
        build_slot_buttons.append(slot_button)
    build_detail.position=Vector2(640,218)
    build_detail.size=Vector2(427,312)
    build_detail.add_theme_font_size_override("normal_font_size",18)
    build_detail.add_theme_color_override("default_color",IVORY)
    build_detail.scroll_active=true
    build_panel.add_child(build_detail)
    _label(build_panel,"点击 / 确认键执行  ·  方向键 / 手柄十字键选择  ·  Esc 返回",Vector2(34,553),Vector2(1000,28),14,MUTED)

func _request_build_toggle() -> void:
    if level!=null and level.active_overlay!="new_journey" and level.has_method("_toggle_build"):level.call("_toggle_build")

func toggle_build() -> void:
    build_panel.visible=not build_panel.visible
    if build_panel.visible:refresh_build()

func close_build() -> void:
    build_panel.visible=false

func _build_snapshot() -> Dictionary:
    if level==null or not level.has_method("get_build_system"):return {}
    var system: Variant=level.call("get_build_system")
    if system==null or not system.has_method("get_snapshot"):return {}
    var snapshot: Dictionary=system.call("get_snapshot")
    # Live cooldown belongs in HUD; it must not rebuild a focused menu every tick.
    for skill in snapshot.get("skills",[]):skill.erase("cooldown_remaining")
    return snapshot

func refresh_build() -> void:
    if build_grid==null:return
    var snapshot:=_build_snapshot()
    last_build_signature=JSON.stringify(snapshot)
    for child in build_grid.get_children():
        build_grid.remove_child(child)
        child.queue_free()
    if snapshot.is_empty():
        build_summary.text="行装系统尚未就绪"
        build_detail.text="请从完整世界入口开始巡礼。"
        return
    for slot_index in build_slot_buttons.size():
        var slot_button:=build_slot_buttons[slot_index]
        slot_button.visible=build_category in ["技能","战具"]
        slot_button.text=("▶ " if slot_index==build_assign_slot else "○ ")+"装备位置 %d" % (slot_index+1)
    build_summary.text="碎钱 %d · 铭饰容量 %d / %d · 契印、铭饰及构筑在钟龛调整" % [int(level.currency_count),int(snapshot.get("slots_used",0)),int(snapshot.get("slots_total",0))]
    var entries: Array=[]
    var action:=""
    match build_category:
        "契印":entries=snapshot.get("crests",[]);action="switch_crest"
        "技能":entries=snapshot.get("skills",[]);action="select_skill"
        "战具":entries=snapshot.get("tools",[]);action="select_tool"
        "铭饰":entries=snapshot.get("passive_options",[]);action="equip_passive"
        "强化":entries=snapshot.get("recipes",[]);action="transact"
        "构筑":
            for i in 3:
                var id:="巡礼方案 %d" % (i+1)
                var loadouts: Array=snapshot.get("loadouts",[])
                entries.append({"id":id,"name":id,"description":"保存当前契印、技能、战具和铭饰。恢复时仍会检查解锁与槽位条件。","unlocked":true,"exists":loadouts.has(id)})
    for tab in build_tabs:tab.add_theme_stylebox_override("normal",_style(Color("343531") if tab.text==build_category else Color("252a2c"),GOLD if tab.text==build_category else Color("4c514d")))
    if entries.is_empty():build_detail.text="此页暂无可用条目。"
    var first: Button
    for entry_value in entries:
        var entry: Dictionary=entry_value
        var id:=String(entry.get("id",entry.get("name","")))
        var text:=String(entry.get("name",id))
        if not bool(entry.get("unlocked",true)):text="◇ "+text+" · 未解锁"
        elif bool(entry.get("selected",false)):text="◆ "+text+" · 已装备"
        var equipped_slots:=_entry_equipped_slots(snapshot,id)
        if not equipped_slots.is_empty():text+=" · 位置 "+equipped_slots
        if entry.has("cost"):text+=" · 容量 %d" % int(entry.cost)
        if entry.has("count"):text+=" · %d/%d 次" % [int(entry.count),int(entry.get("capacity",entry.count))]
        if entry.has("level"):text+=" · Lv.%d" % int(entry.level)
        var button:=_button(build_grid,text,Vector2.ZERO,Vector2(563,54),func():
            build_selection=id
            if not bool(entry.get("unlocked",true)):
                _show_build_detail(entry)
                return
            _perform_build_action("restore_loadout" if build_category=="构筑" else action,id,build_assign_slot if build_category in ["技能","战具"] else -1))
        button.custom_minimum_size=Vector2(563,54)
        button.set_meta("build_id",id)
        button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
        var icon_path:="res://assets/ui/seals/%s.svg" % id
        if ResourceLoader.exists(icon_path):
            button.icon=load(icon_path)
            button.expand_icon=true
            button.add_theme_constant_override("icon_max_width",30)
        button.tooltip_text=String(entry.get("description",""))
        button.mouse_entered.connect(func():_show_build_detail(entry))
        button.focus_entered.connect(func():
            build_selection=id
            _show_build_detail(entry))
        if bool(entry.get("selected",false)):button.add_theme_stylebox_override("normal",_style(Color("343531"),GOLD,2))
        if first==null or id==build_selection:first=button
        if build_category=="构筑":
            var name_value:=id
            var save:=_button(build_grid,"保存为「%s」" % id,Vector2.ZERO,Vector2(563,36),func():_perform_build_action("save_loadout",name_value))
            save.custom_minimum_size=Vector2(563,36)
            button.text="恢复「%s」%s" % [id,"" if bool(entry.get("exists",false)) else " · 尚未保存"]
    if first!=null:
        if build_panel.visible:first.grab_focus()
        for value in entries:
            if String(value.get("id",value.get("name","")))==build_selection:
                _show_build_detail(value)
                return
        _show_build_detail(entries[0])

func _entry_equipped_slots(snapshot: Dictionary, id: String) -> String:
    if not build_category in ["技能","战具"]:return ""
    var system: Variant=level.call("get_build_system") if level.has_method("get_build_system") else null
    if system==null:return ""
    var equipped: Array=system.state.get("skills" if build_category=="技能" else "tools",[])
    var slots: Array[String]=[]
    for index in equipped.size():
        if String(equipped[index])==id:slots.append(str(index+1))
    return "/".join(slots)

func _loadout_preview(build: Dictionary, system: RefCounted) -> String:
    var crest_id:=String(build.get("crest","crimson"))
    var lines: Array[String]=["契印："+String(system.catalog.crests.get(crest_id,{}).get("name",crest_id))]
    for field in ["skills","tools","passives"]:
        var table: String={"skills":"skills","tools":"tools","passives":"passives"}[field]
        var title: String={"skills":"技能","tools":"战具","passives":"铭饰"}[field]
        var names: Array[String]=[]
        for id in build.get(field,[]):names.append(String(system.catalog[table].get(id,{}).get("name","未装备")))
        lines.append(title+"："+(" / ".join(names) if not names.is_empty() else "未装备"))
    return "\n".join(lines)

func _show_build_detail(entry: Dictionary) -> void:
    var lines: Array[String]=[String(entry.get("name",entry.get("id",""))),"",String(entry.get("description",""))]
    var snapshot:=_build_snapshot()
    if build_category=="构筑":
        var system: Variant=level.call("get_build_system")
        lines.append("\n当前整体配置\n"+_loadout_preview(system.state,system))
        var saved_build: Dictionary=system.state.loadouts.get(String(entry.get("id","")),{})
        if not saved_build.is_empty():lines.append("\n已保存配置\n"+_loadout_preview(saved_build,system))
        lines.append("生命、能量、次数与冷却不会因方案恢复刷新。")
    if entry.has("mechanism_unlocked") and not bool(entry.mechanism_unlocked):lines.append("\n◇ 专属机制尚未修复：基础战斗与永久探索能力仍可使用，完成来源委托后启用。")
    if entry.has("slots"):
        for crest in snapshot.get("crests",[]):
            if String(crest.get("id",""))!=String(snapshot.get("crest","")):continue
            lines.append("\n契印基础值 · 当前 → 所选")
            for pair in [["slots","铭饰槽"],["max_hp","生命"],["max_energy","绯线容量"],["heal_cost","治疗耗能"],["heal_amount","治疗恢复"]]:
                lines.append("%s：%s → %s" % [pair[1],str(crest.get(pair[0],0)),str(entry.get(pair[0],0))])
            lines.append("治疗时间：%.2f → %.2f 秒" % [float(crest.get("heal_duration",0)),float(entry.get("heal_duration",0))])
            lines.append("铭饰效果在装备后合并计算。")
    if String(entry.get("kind",""))=="skill" and entry.has("target"):
        for skill in snapshot.get("skills",[]):
            if String(skill.get("id",""))==String(entry.target):
                var level_value:=int(skill.get("level",0))
                lines.append("\n%s：Lv.%d → Lv.%d" % [String(skill.get("name","")),level_value,mini(2,level_value+1)] if level_value<2 else "\n此技能已达当前强化上限。")
                lines.append(String(skill.get("description","")))
    if not bool(entry.get("unlocked",true)):
        var unlock_hint:=String(entry.get("unlock_hint","继续探索、完成委托或挑战后获得。"))
        if not String(entry.get("unlock_item","")).is_empty():unlock_hint="需要取得「%s」。" % level._item_display_name(String(entry.unlock_item))
        lines.append("\n尚未解锁 · "+unlock_hint)
    for field in [["source","来源"],["attack_description","攻击"],["mechanism","专属机制"],["heal_effect","治疗完成"],["risk","动作风险与代价"],["synergy","契印协同"]]:
        if entry.has(field[0]):lines.append("\n%s：%s" % [field[1],str(entry[field[0]])])
    if build_category in ["技能","战具"]:lines.append("\n确认后装备到位置 %d；上方按钮选择位置。" % (build_assign_slot+1))
    if build_category=="战具":lines.append("钟龛休整免费补满；换装与恢复构筑不会补充次数。")
    if entry.has("cost"):
        var used:=int(snapshot.get("slots_used",0))
        var total:=int(snapshot.get("slots_total",0))
        if not bool(entry.get("selected",false)) and used+int(entry.cost)>total:lines.append("◇ 容量不足：需要 %d，剩余 %d。" % [int(entry.cost),maxi(0,total-used)])
    if entry.has("energy_cost"):lines.append("\n消耗绯线：%d" % int(entry.energy_cost))
    if entry.has("cooldown"):lines.append("冷却：%.1f 秒" % float(entry.cooldown))
    if entry.has("cost"):lines.append("铭饰容量消耗：%d；再次确认可卸下。" % int(entry.cost))
    if entry.has("count"):lines.append("剩余携带：%d / %d" % [int(entry.count),int(entry.get("capacity",entry.count))])
    if entry.has("currency"):lines.append("\n制作费用：%d 碎钱" % int(entry.currency))
    if entry.has("materials"):
        var materials: Dictionary=entry.materials
        for material in materials:lines.append("材料 %s：需要 %d / 持有 %d" % [level._item_display_name(String(material)),int(materials[material]),int(level.inventory_counts.get(material,0))])
    if bool(entry.get("selected",false)):lines.append("\n当前已装备。")
    build_detail.text="\n".join(lines)

func _perform_build_action(action: String, id: String, slot: int = -1) -> void:
    if level==null or not level.has_method("perform_build_action"):return
    var result: Variant=level.call("perform_build_action",action,id,slot)
    refresh_build()
    if result is Dictionary:
        var message:=String(result.get("reason","已完成" if bool(result.get("ok",false)) else "条件不足"))
        if message.is_empty():message="构筑已更新并保存。" if bool(result.get("ok",false)) else "当前条件不足。"
        toast.text=message
        toast_age=0.0
        build_detail.text+="\n\n"+message

func _select_save_slot(slot: int) -> void:
    if not level.has_method("select_save_slot"):
        remap_status.text="当前入口尚未支持多存档。"
        return
    var result: bool=level.call("select_save_slot",slot)
    remap_status.text="已切换到存档槽 %d。" % slot if result else "存档切换失败；当前进度未被覆盖。"

func _restore_save_backup() -> void:
    if not level.has_method("restore_save_backup"):
        remap_status.text="当前入口尚未支持备份恢复。"
        return
    var result: bool=level.call("restore_save_backup")
    remap_status.text="已恢复当前槽备份。" if result else "未找到可恢复的有效备份。"

func _refresh_save_slots() -> void:
    if not level.has_method("get_save_slots"):return
    for value in level.call("get_save_slots"):
        var entry: Dictionary=value
        var slot:=int(entry.get("slot",0))
        if not save_slot_buttons.has(slot):continue
        var button: Button=save_slot_buttons[slot]
        var status:="新旅途"
        if bool(entry.get("exists",false)):
            status="%d 区 · %d 钱" % [int(entry.get("regions",0)),int(entry.get("currency",0))] if bool(entry.get("valid",false)) else "记录损坏"
        button.text="槽 %d · %s" % [slot,status]
        button.tooltip_text="读取失败：%s。原文件会保留，请恢复备份。" % String(entry.get("error","未知错误")) if bool(entry.get("exists",false)) and not bool(entry.get("valid",false)) else "切换前会保存当前进度。\n"+status

func _process(delta: float) -> void:
    if level==null:return
    if applied_player!=level.player:_apply_accessibility()
    if last_overlay!=String(level.active_overlay):
        last_overlay=String(level.active_overlay)
        if last_overlay=="build":refresh_build()
        elif last_overlay=="settings":
            _refresh_save_slots()
            settings_sliders.values()[0].grab_focus()
        elif last_overlay=="backpack" and not bag_tabs.is_empty():bag_tabs[0].grab_focus()
        elif last_overlay=="dialogue":dialogue_quest_button.grab_focus()
        elif last_overlay=="":
            var focused:=get_viewport().gui_get_focus_owner()
            if focused!=null:focused.release_focus()
    if build_panel.visible and last_overlay!="build":build_panel.visible=false
    build_refresh_elapsed+=delta
    if build_panel.visible and build_refresh_elapsed>=0.4:
        build_refresh_elapsed=0.0
        if JSON.stringify(_build_snapshot())!=last_build_signature:refresh_build()
    if settings.visible:
        refresh_settings_selection()
    if settings.visible and level.audio_director!=null:
        for key in settings_sliders:
            settings_sliders[key].set_value_no_signal(level.audio_director.get_user_volume(key))
    var player: Node=level.player
    if player!=null:
        var hp: int=int(player.hp)
        hearts.text="● ".repeat(maxi(0,hp))+"○ ".repeat(maxi(0,int(player.max_hp)-hp))
        hearts.modulate=RED if hp<=1 else IVORY
        thread_bar.max_value=player.max_energy
        thread_bar.value=player.energy
        energy_status.text="%d / %d" % [int(player.energy),int(player.max_energy)]
        _refresh_combat_status(player)
    tutorial_hint.visible=bool(accessibility.get("tutorial_hints",true)) and level.active_overlay==""
    if tutorial_hint.visible:
        tutorial_hint.text="跳跃：%s  ·  普攻：%s  ·  治疗：%s\nB 构筑 · 未解锁技能与战具可在构筑页查看条件" % [_short_binding("jump"),_short_binding("attack"),_short_binding("heal")]
    currency.text=str(level.currency_count)
    var room: Dictionary=level._map_room_by_id(level.current_room_id)
    location.text=String(room.get("name",room.get("label",level.config.get("chapter_name","绯线巡礼"))))
    toast_age+=delta
    if toast.text!=last_toast:
        last_toast=toast.text
        toast_age=0
    toast.modulate.a=clampf(5.5-toast_age,0,1)
    prompt.visible=level.active_overlay==""
    if prompt.visible:
        var area: Area2D=level._nearest_interactable(140)
        if area==null:
            prompt.text=""
        else:
            var kind:=String(area.get_meta("kind",""))
            prompt.text="F · "+String(area.get_meta("interaction_label",("与 "+String(area.get_meta("label",area.name))+" 交谈") if kind=="npc" else area.get_meta("label","触碰旧机关")))
    var actor: Node=level.boss_actor
    var show_boss: bool = actor!=null and is_instance_valid(actor) and not level.demo_complete and level.active_overlay==""
    boss_name.visible=show_boss
    boss_bar.visible=show_boss
    if show_boss:
        boss_name.text=level._boss_display_name(level.config.get("boss",{}))+"  ·  "+("第二乐章" if int(actor.battle_phase)==2 else "第一乐章")
        boss_bar.max_value=actor.max_hp
        boss_bar.value=actor.hp
    pinned.text=""
    for key in level.story_flags.keys():
        if String(key).begins_with("ui_pin_") and bool(level.story_flags[key]):
            pinned.text="旅记 · "+level._item_display_name(String(key).trim_prefix("ui_pin_"))
            break

func _visible_inventory_ids() -> Array[String]:
    var ids: Array[String] = []
    for value in level.backpack_entry_ids:
        var id := String(value)
        if id=="currency":
            if bag_category=="全部":ids.append(id)
            continue
        if _matches(String(level._item_data(id).get("category",""))):
            ids.append(id)
    return ids

func _reconcile_inventory_selection() -> String:
    var visible_ids := _visible_inventory_ids()
    if visible_ids.is_empty():
        level.backpack_selection=-1
        return ""
    var index: int = level._backpack_selection_clamped()
    var selected := String(level.backpack_entry_ids[index]) if index >= 0 else ""
    if not visible_ids.has(selected):
        selected=visible_ids[0]
        level.backpack_selection=level.backpack_entry_ids.find(selected)
        level._refresh_backpack_detail()
    return selected

func move_inventory_selection(delta: int) -> void:
    if bag_category=="旅记":
        if bag_grid.get_child_count()>0:journal_selection=wrapi(journal_selection+delta,0,bag_grid.get_child_count())
        return
    var selected := _reconcile_inventory_selection()
    var visible_ids := _visible_inventory_ids()
    if visible_ids.is_empty():return
    var next_id := visible_ids[wrapi(visible_ids.find(selected)+delta,0,visible_ids.size())]
    level.backpack_selection=level.backpack_entry_ids.find(next_id)

func refresh_settings_selection() -> void:
    var rows: Array=level.AUDIO_SETTINGS_ROWS
    for i in rows.size():
        var key := String(rows[i][0])
        if not settings_labels.has(key):continue
        var selected: bool = i==level._settings_selection_clamped()
        settings_labels[key].text=("▶ " if selected else "  ")+String(rows[i][1]).split(" ")[0]
        settings_labels[key].add_theme_color_override("font_color",GOLD if selected else IVORY)

func _binding_name(event: InputEvent) -> String:
    if event is InputEventJoypadMotion:
        if event.axis==JOY_AXIS_TRIGGER_LEFT:return "手柄 L2" if event.axis_value>0 else "手柄 L2 反向"
        if event.axis==JOY_AXIS_TRIGGER_RIGHT:return "手柄 R2" if event.axis_value>0 else "手柄 R2 反向"
        return "手柄轴 %d %s" % [event.axis,"＋" if event.axis_value>0 else "－"]
    return event.as_text()

func _short_binding(action: String) -> String:
    if InputMap.has_action(action):
        var events:=InputMap.action_get_events(action)
        if not events.is_empty():return _binding_name(events[0])
    return "未设置"

func _refresh_combat_status(player: Node) -> void:
    var state: Dictionary={}
    if player.has_method("get_combat_ui_state"):state=player.call("get_combat_ui_state")
    var snapshot:=_build_snapshot()
    var skill_lines: Array[String]=[]
    var tool_lines: Array[String]=[]
    var system: Variant=level.call("get_build_system") if level.has_method("get_build_system") else null
    var build_state: Dictionary=system.state if system!=null else {}
    var equipped_skills: Array=build_state.get("skills",[build_state.get("skill","cleave")])
    var equipped_tools: Array=build_state.get("tools",[build_state.get("tool","shard")])
    for slot in equipped_skills.size():
        var id:=String(equipped_skills[slot])
        if id.is_empty():skill_lines.append("○%d 未装备技能" % (slot+1));continue
        for skill in snapshot.get("skills",[]):
            if String(skill.get("id",""))!=id:continue
            var remaining:=float(system.cooldowns.get(id,0)) if system!=null else float(state.get("skill_cooldown",0))
            var status:="%.1fs" % remaining if remaining>0 else "就绪"
            skill_lines.append("%s%d %s %s" % ["▶" if slot==int(build_state.get("active_skill_slot",0)) else "○",slot+1,String(skill.get("name",id)),status])
    for slot in equipped_tools.size():
        var id:=String(equipped_tools[slot])
        if id.is_empty():tool_lines.append("○%d 未携带战具" % (slot+1));continue
        for tool in snapshot.get("tools",[]):
            if String(tool.get("id",""))==id:tool_lines.append("%s%d %s %d次" % ["▶" if slot==int(build_state.get("active_tool_slot",0)) else "○",slot+1,String(tool.get("name",id)),int(tool.get("count",0))])
    combat_status.text=" · ".join(skill_lines)+"\n"+" · ".join(tool_lines)
    if player.has_method("get_seal_mechanism_snapshot"):
        var mechanism: Dictionary=player.call("get_seal_mechanism_snapshot")
        var maximum:=int(mechanism.get("max_stacks",mechanism.get("max",3)))
        var amount:=int(mechanism.get("stacks",mechanism.get("value",0)))
        combat_status.text+="\n"+String(mechanism.get("label",mechanism.get("name","契印")))+" "+("%d / %d" % [amount,maximum] if maximum>0 else "%d 个目标" % amount)
    healing_bar.visible=bool(state.get("heal_active",false)) and level.active_overlay==""
    healing_bar.value=clampf(float(state.get("heal_progress",0)),0,1)
    if healing_bar.visible:combat_status.text+=" · 治疗中"
    combat_status.visible=level.active_overlay==""


func _refresh_journal() -> void:
    bag_grid.columns=2
    bag_pin.disabled=true
    bag_name.text="六区证词与委托"
    bag_category_label.text="旅途记录"
    bag_icon.texture=ART.item("moss_lens")
    bag_description.text="委托随跨区推进更新。证词按实际拾取记录；缺页只提示线索。"
    for tab in bag_tabs:tab.add_theme_stylebox_override("normal",_style(Color("343531") if tab.text==bag_category else Color("252a2c"),GOLD if tab.text==bag_category else Color("4c514d")))
    if not bool(level.get("world_mode")):
        bag_description.text="完整互联世界旅途中会记录跨区委托与六区证词。"
        return
    var narrative: Variant=level.get("world_narrative")
    if narrative==null:return
    var records: Array=[]
    if narrative.has_method("quest_journal"):
        for value in narrative.call("quest_journal",level.inventory_counts,level.story_flags):
            var entry: Dictionary=value.duplicate(true)
            entry["record_kind"]="quest"
            records.append(entry)
    if narrative.has_method("evaluate_evidence"):
        var evidence: Dictionary=narrative.call("evaluate_evidence",level.inventory_counts,level.story_flags)
        for value in evidence.get("entries",[]):
            var entry: Dictionary=value.duplicate(true)
            entry["record_kind"]="evidence"
            records.append(entry)
    var selected_button: Button
    for record_index in records.size():
        var value: Variant=records[record_index]
        var entry: Dictionary=value
        var title:=String(entry.get("title",entry.get("id","")))
        var status:="已发现" if bool(entry.get("acquired",false)) else "待发现"
        if entry.record_kind=="quest":status="已完成" if String(entry.get("status",""))=="complete" else "进行中"
        var button:=_button(bag_grid,title+"\n"+status,Vector2.ZERO,Vector2(309,74),func():_show_journal_record(entry))
        button.custom_minimum_size=Vector2(309,74)
        button.tooltip_text=title+" · "+status
        button.focus_entered.connect(func():
            journal_selection=record_index
            _show_journal_record(entry))
        button.mouse_entered.connect(func():_show_journal_record(entry))
        if record_index==journal_selection:selected_button=button
    if not records.is_empty():
        journal_selection=clampi(journal_selection,0,records.size()-1)
        _show_journal_record(records[journal_selection])
        if selected_button!=null and bag.visible:selected_button.grab_focus()

func _show_journal_record(entry: Dictionary) -> void:
    bag_name.text=String(entry.get("title",entry.get("id","")))
    var lines: Array[String]=[]
    if String(entry.get("record_kind",""))=="quest":
        bag_category_label.text="委托 · "+("已完成" if String(entry.get("status",""))=="complete" else "进行中")
        lines.append(String(entry.get("description","")))
        for step in entry.get("steps",[]):lines.append(("● " if bool(step.get("complete",false)) else "○ ")+String(step.get("label","")))
        lines.append("\n"+String(entry.get("guidance","")))
        if String(entry.get("status",""))=="complete":lines.append("奖励已领取。" if bool(entry.get("reward_claimed",false)) else "可以返回委托人领取奖励。")
    else:
        var acquired:=bool(entry.get("acquired",false))
        bag_category_label.text="证词 · "+("已发现" if acquired else "缺页")
        lines.append(String(entry.get("claim","")) if acquired else "尚未拾得这页证词。")
        lines.append("\n线索："+String(entry.get("location_hint","留意区域中的遗物与生产设施。")))
    bag_description.text="\n".join(lines)
