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

func bind(runtime: Node) -> void:
    level=runtime
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    var ui_theme := Theme.new()
    ui_theme.default_font=FONT
    ui_theme.default_font_size=18
    theme=ui_theme
    _build_hud()
    _build_bag()
    _build_dialogue()
    _build_settings()

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
    pinned=_label(self,"",Vector2(28,127),Vector2(290,45),15,MUTED)
    pinned.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
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
    var categories:= ["全部","织具","遗物","材料","要物"]
    for i in categories.size():
        var category: String=categories[i]
        var button:=_button(bag,category,Vector2(34+i*124,119),Vector2(112,38),func():
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
    return {"Tools":"织具","Abilities":"能力","Charms":"护符","Upgrades":"强化","Relics":"遗物","Quest":"要物","Materials":"材料","Combat":"印记","Currency":"碎钱"}.get(category,category)

func _pin_item() -> void:
    var id := _reconcile_inventory_selection()
    if id.is_empty():return
    var was_pinned:=bool(level.story_flags.get("ui_pin_"+id,false))
    for key in level.story_flags.keys():
        if String(key).begins_with("ui_pin_"):level.story_flags[key]=false
    level.story_flags["ui_pin_"+id]=not was_pinned
    refresh_inventory()

func _build_dialogue() -> void:
    dialogue=_panel(self,"",Vector2(72,438),Vector2(1136,236))
    dialogue.name="DialogueOverlay"
    dialogue_portrait=_icon(dialogue,null,Vector2(23,21),Vector2(173,191))
    dialogue_name=_label(dialogue,"",Vector2(221,19),Vector2(770,37),26,GOLD)
    dialogue_identity=_label(dialogue,"",Vector2(221,57),Vector2(770,28),14,MUTED)
    dialogue_body=_label(dialogue,"",Vector2(221,93),Vector2(854,78),21,IVORY)
    dialogue_body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    dialogue_hint=_label(dialogue,"F 继续  ·  Esc 离开",Vector2(24,206),Vector2(180,24),13,MUTED)
    _button(dialogue,"继续交谈",Vector2(221,186),Vector2(147,34),func():
        if is_instance_valid(dialogue_area):level._talk_to_npc(dialogue_area))
    _button(dialogue,"问问道路",Vector2(380,186),Vector2(147,34),func():_topic("route"))
    dialogue_quest_button=_button(dialogue,"询问心愿",Vector2(540,186),Vector2(147,34),func():_topic("wish"))

func show_speaker(area: Area2D) -> void:
    dialogue_area=area
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

func close_dialogue() -> void:
    if is_instance_valid(dialogue_area):
        var sprite:=dialogue_area.get_node_or_null("FriendlyFamilySprite") as AnimatedSprite2D
        if sprite!=null:sprite.play("idle")
    dialogue_area=null

func _build_settings() -> void:
    settings=_panel(self,"声音与氛围",Vector2(345,175),Vector2(590,355))
    settings.name="AudioSettingsOverlay"
    var rows: Array=level.AUDIO_SETTINGS_ROWS
    for i in rows.size():
        var key:=String(rows[i][0])
        settings_labels[key]=_label(settings,String(rows[i][1]).split(" ")[0],Vector2(34,96+i*51),Vector2(145,30),18)
        var slider:=HSlider.new()
        slider.position=Vector2(194,105+i*51)
        slider.size=Vector2(340,22)
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
    legacy_settings=_label(settings,"",Vector2.ZERO,Vector2.ZERO)
    legacy_settings.visible=false
    refresh_settings_selection()

func _process(delta: float) -> void:
    if level==null:return
    if settings.visible:
        refresh_settings_selection()
    if settings.visible and level.audio_director!=null:
        for key in settings_sliders:
            settings_sliders[key].set_value_no_signal(level.audio_director.get_user_volume(key))
    var player: Node=level.player
    if player!=null:
        var hp: int=int(player.hp)
        hearts.text="● ".repeat(maxi(0,hp))+"○ ".repeat(maxi(0,5-hp))
        hearts.modulate=RED if hp<=1 else IVORY
        thread_bar.max_value=player.max_energy
        thread_bar.value=player.energy
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
