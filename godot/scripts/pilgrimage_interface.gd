extends Control

const PROMPT_BINDINGS := preload("res://scripts/input_prompt_bindings.gd")
const ART := preload("res://scripts/hand_drawn_assets.gd")
const FONT := preload("res://assets/fonts/GlobalTypeface.otf")
const INSCRIBED_BUTTON := preload("res://scripts/pilgrimage_button.gd")
static var _survey_font: FontFile
const CHROME := preload("res://scripts/pilgrimage_chrome.gd")
const IVORY := Color("e8d7b8")
const GOLD := Color("bca07a")
const MUTED := Color("a2b3aa")
const RED := Color("c85450")
var level: Node
var hud_card: Control
var location_rule: Control
var hearts: Label
var hud_crest: TextureRect
var health_glyphs: Control
var modal_shade: ColorRect
var tactical_cards: Array[Panel]=[]
var tactical_icons: Array[TextureRect]=[]
var tactical_names: Array[Label]=[]
var tactical_values: Array[Label]=[]
var mechanism_status: Label
var quick_actions: Array[Button]=[]
var build_heading: Label
var build_emblem: TextureRect
var build_art: Control
var build_art_caption: Label
var tactical_signatures: Array[String]=["","","",""]
var thread_bar: ProgressBar
var currency: Label
var currency_emblem: TextureRect
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
var dialogue_continue_button: Button
var dialogue_route_button: Button
var dialogue_reading := preload("res://scripts/dialogue_reading_memory.gd").new()
var dialogue_reading_key := ""
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
var loadout_dialog: ConfirmationDialog
var pending_loadout_action := ""
var pending_loadout_name := ""
var build_assign_slot := 0
var build_slot_buttons: Array[Button]=[]
var build_family := "combat_accessory"
var family_selector_buttons: Array[Button]=[]
var clear_family_slot_button: Button
var resupply_preview_button: Button
var resupply_confirm_button: Button
var resupply_quote: Dictionary={}
var combat_status: Label
var energy_status: Label
var healing_bar: ProgressBar
var healing_status: Label
var tutorial_hint: Label
var accessibility_path := "user://pilgrimage_accessibility.cfg"
var accessibility: Dictionary={"subtitle_speed":1.0,"subtitle_size":21,"flash_enabled":true,"vibration_enabled":true,"vibration_strength":1.0,"camera_shake":1.0,"camera_lookahead":1.0,"tutorial_hints":false,"navigation_assist":false}
var remap_target := ""
# Polling Input ignores handled events; keep captured input out of the level loop.
var remap_capture_frame := -1
var remap_buttons: Dictionary={}
var remap_status: Label
var reset_bindings_button: Button
var last_overlay := ""
var overlay_focus_memory: Dictionary = {}
var build_refresh_elapsed := 0.0
var last_build_signature := ""
var applied_player: Node
var save_slot_buttons: Dictionary={}
var journey_history_button: Button
var journey_history_dialog: AcceptDialog
var journey_history_text: RichTextLabel
var journey_history_close_frame := -1
var journal_selection := 0
var journal_filter := "all"
var journal_filter_buttons: Dictionary = {}
var journal_filters: HBoxContainer
var journal_memory: Dictionary = {}
var journal_reading := preload("res://scripts/journal_reading.gd").new()
var journal_reading_key := ""
var journal_reading_text := ""
var journal_restore_pending := false
var bag_scroll: ScrollContainer
var construction_complete := false
var inventory_build_selection := ""

const BINDING_POLICY = preload("res://scripts/input_binding_policy.gd")
var binding_recovery_notice := ""

const REMAPPABLE_ACTIONS := {"jump":"跳跃","attack":"普攻","heal":"治疗","skill_1":"施放技能","skill_cycle":"切换技能","tool_cast":"使用战具","tool_cycle":"切换战具","dash":"冲刺","interact":"互动",
    # U06: movement and the four permanent abilities are remappable too.
    "move_left":"左移","move_right":"右移","aim_up":"向上","aim_down":"向下",
    "hook":"回声钩索","bell_guard":"钟壳格挡","lantern_phase":"灯影相位","crown_resonance":"王冠共鸣",
    "inventory":"行囊","map":"地图","audio_settings":"设置"}
const REMAP_COLUMNS := 4
## Bindings as the game ships them, recorded once per run before saved ones apply.
static var default_bindings: Dictionary = {}

func bind(runtime: Node) -> void:
    begin_bind(runtime)
    for method in build_steps():
        call(method)
    finish_bind()

static func build_steps() -> Array[String]:
    return ["_build_hud", "_build_bag", "_build_dialogue", "_build_settings", "_build_build_panel"]

## Inscribed title artwork is 1-2 MB per image. Each region rebuilds the UI
## shell, and freeing the old one released these textures, so every transition
## decoded them from disk again (~30 ms each; T03). Keep one shared copy.
static var _inscription_marks: Dictionary = {}

static func inscription_mark(id: String) -> Texture2D:
    if not _inscription_marks.has(id):
        _inscription_marks[id] = load("res://assets/ui/inscription/v2/%s.png" % id)
    return _inscription_marks[id]

static func survey_font() -> FontFile:
    # Keep the zoomable map's glyph cache across region-owned HUD lifetimes.
    # The shared font retains no level, node or signal references.
    if _survey_font==null:
        _survey_font=FONT.duplicate()
        _survey_font.multichannel_signed_distance_field=true
    return _survey_font

static func display_font() -> FontFile:
    # A duplicate with this same font as its own fallback produced different
    # glyph-cache pixels before/after opening the map. Share the primary font.
    return FONT

func begin_bind(runtime: Node) -> void:
    construction_complete=false
    set_process(false)
    set_process_input(false)
    level=runtime
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    var ui_theme := Theme.new()
    ui_theme.default_font=FONT
    ui_theme.default_font_size=18
    ui_theme.set_font("font","Button",display_font())
    theme=ui_theme
    _install_theme(ui_theme)
    modal_shade=ColorRect.new()
    modal_shade.color=Color(0.015,0.025,0.03,0.78)
    modal_shade.size=Vector2(1280,720)
    modal_shade.z_index=5
    modal_shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
    modal_shade.visible=false
    add_child(modal_shade)
    # Install navigation defaults first; saved bindings then replace them.
    _bind_ui_navigation()
    _load_accessibility()

func finish_bind() -> void:
    if settings!=null and not settings.visibility_changed.is_connected(_remap_visibility_changed):
        settings.visibility_changed.connect(_remap_visibility_changed)
    if not get_viewport().size_changed.is_connected(_fit_viewport):
        get_viewport().size_changed.connect(_fit_viewport)
    if not get_viewport().gui_focus_changed.is_connected(_remember_gui_focus):
        get_viewport().gui_focus_changed.connect(_remember_gui_focus)
    if not Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
        Input.joy_connection_changed.connect(_on_joy_connection_changed)
    _fit_viewport()
    construction_complete=true
    set_process(true)
    set_process_input(true)

## Styles and geometry are set while the control is outside the tree (cheap:
## no text to shape yet); text is assigned only after it joins the tree. Text
## shaped outside the tree costs ~4 ms per control, which made each region's UI
## rebuild stall for 100+ ms in one loading step (T03).
func _label(parent: Node, text: String, position_value: Vector2, size_value: Vector2, font_size: int=18, tint: Color=IVORY) -> Label:
    var label:=Label.new()
    label.position=position_value
    label.size=size_value
    label.add_theme_font_size_override("font_size",font_size)
    if font_size>=20:
        label.add_theme_font_override("font",display_font())
    label.add_theme_color_override("font_shadow_color",Color(0,0,0,.7))
    label.add_theme_constant_override("shadow_offset_y",1)
    label.add_theme_color_override("font_color",tint)
    label.mouse_filter=Control.MOUSE_FILTER_IGNORE
    parent.add_child(label)
    label.text=text
    return label

func _style(tint: Color, border: Color, width: int=1) -> StyleBoxFlat:
    var style:=StyleBoxFlat.new()
    style.bg_color=tint
    # Native borders stay clear; etched strokes are drawn once by the button.
    style.border_color=Color(0,0,0,0)
    style.set_border_width_all(width)
    style.set_corner_radius_all(0)
    style.corner_detail=1
    style.content_margin_top=4
    style.content_margin_bottom=4
    style.content_margin_left=10
    style.content_margin_right=10
    return style

func _meter_style(tint: Color) -> StyleBoxFlat:
    var result:=_style(tint,tint,0)
    result.content_margin_left=0
    result.content_margin_right=0
    result.content_margin_top=0
    result.content_margin_bottom=0
    result.set_corner_radius_all(2)
    return result

func _tab_style(selected: bool) -> StyleBoxFlat:
    var result:=_style(Color(0,0,0,0),RED if selected else Color("43504a"),0)
    result.border_width_bottom=2 if selected else 1
    result.set_corner_radius_all(0)
    return result

func _button(parent: Node, text: String, position_value: Vector2, size_value: Vector2, action: Callable) -> Button:
    var button:=INSCRIBED_BUTTON.new()
    button.position=position_value
    button.size=size_value
    button.add_theme_font_size_override("font_size",17)
    button.add_theme_color_override("font_color",IVORY)
    button.add_theme_stylebox_override("normal",_style(Color(.01,.025,.028,.35),Color("61553f")))
    button.add_theme_stylebox_override("hover",_style(Color(.18,.06,.055,.25),RED))
    button.add_theme_stylebox_override("focus",_style(Color(0,0,0,0),GOLD,2))
    button.add_theme_stylebox_override("pressed",_style(Color(.25,.07,.06,.3),RED,2))
    button.add_theme_color_override("font_disabled_color",MUTED.darkened(0.3))
    button.add_theme_stylebox_override("disabled",_style(Color("182025"),Color("303c3d")))
    button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
    button.focus_mode=Control.FOCUS_ALL
    button.pressed.connect(action)
    parent.add_child(button)
    button.text=text
    return button

func _panel(parent: Node, title: String, position_value: Vector2, size_value: Vector2) -> ColorRect:
    var root:=ColorRect.new()
    root.position=position_value
    root.size=size_value
    root.color=Color(0,0,0,0)
    root.z_index=10
    root.visible=false
    parent.add_child(root)
    frame(root)
    var marks := {"契印与构筑":["seal","行装与构筑"],"巡礼行囊":["inventory","器物与旧物"],"设置与无障碍":["settings","声音与无障碍"]}
    if marks.has(title):
        var mark: Array=marks[title]
        var title_mark:=_icon(root,inscription_mark(String(mark[0])),Vector2(26,5),Vector2(166,82))
        title_mark.name="InscribedTitle"
        var subtitle:=_label(root,String(mark[1]),Vector2(198,24),Vector2(310,28),18,GOLD)
        subtitle.name="InscriptionSubtitle"
        subtitle.add_theme_font_override("font",display_font())
        _label(root,"绯线巡礼  /  归途手札",Vector2(200,58),Vector2(380,20),11,MUTED)
    elif not title.is_empty():
        _label(root,title,Vector2(34,16),Vector2(size_value.x*0.65,44),30)
    _button(root,"返回",Vector2(size_value.x-91,24),Vector2(62,34),func():level._close_overlays())
    return root

func frame(control: Control) -> void:
    control.z_index=10
    var chrome:=CHROME.new()
    chrome.kind="dialogue" if control==dialogue else "frame"
    chrome.size=control.size
    chrome.mouse_filter=Control.MOUSE_FILTER_IGNORE
    control.add_child(chrome)
    control.move_child(chrome,0)

func _well(parent: Control, point: Vector2, dimensions: Vector2) -> void:
    var well:=CHROME.new()
    well.kind="well"
    well.position=point
    well.size=dimensions
    well.mouse_filter=Control.MOUSE_FILTER_IGNORE
    parent.add_child(well)
    parent.move_child(well,1)

func _fit_viewport() -> void:
    var available:=get_viewport_rect().size
    var factor:=minf(available.x/1280.0,available.y/720.0)
    set_anchors_preset(Control.PRESET_TOP_LEFT)
    size=Vector2(1280,720)
    scale=Vector2.ONE*factor
    position=(available-Vector2(1280,720)*factor)*0.5
    if modal_shade!=null:
        modal_shade.position=-position/factor
        modal_shade.size=available/factor

func _install_theme(target: Theme) -> void:
    target.set_color("font_color","Label",IVORY)
    target.set_color("font_color","Button",IVORY)
    target.set_color("default_color","RichTextLabel",IVORY)
    target.set_color("title_color","Window",IVORY)
    target.set_font("title_font","Window",display_font())
    for state in ["embedded_border","embedded_unfocused_border"]:
        # Keep the engine's title/close-button margins and hit geometry.
        var window_style := ThemeDB.get_default_theme().get_stylebox(state,"Window").duplicate() as StyleBoxFlat
        if window_style != null:
            window_style.bg_color = Color("101f20")
            window_style.border_color = Color("101f20")
            window_style.shadow_color = Color(GOLD,0.5)
            window_style.shadow_size = 1
            target.set_stylebox(state,"Window",window_style)
    target.set_font_size("font_size","Button",17)
    target.set_color("font_hover_color","Button",IVORY)
    target.set_color("font_pressed_color","Button",IVORY)
    target.set_color("font_focus_color","Button",IVORY)
    target.set_color("font_disabled_color","Button",MUTED.darkened(0.3))
    # Native dialog buttons share the shell's ink/copper palette. Unlike the
    # inscribed buttons they have no drawn chrome, so their focus border must
    # live in the style itself rather than the transparent _style default.
    for state in ["normal", "hover", "pressed", "disabled", "focus"]:
        var background := Color("101f20")
        var border := GOLD.darkened(0.4)
        if state == "hover" or state == "pressed":
            background = Color("302220")
            border = RED
        elif state == "disabled":
            background = Color("182025")
            border = Color("303c3d")
        elif state == "focus":
            background = Color(0,0,0,0)
            border = GOLD
        var button_style := _style(background,border,2 if state == "focus" else 1)
        button_style.border_color = border
        target.set_stylebox(state,"Button",button_style)
        # Theme lookup tries this theme's Button entry before the engine's
        # CheckButton one, so pin settings toggles to their default chrome.
        target.set_stylebox(state,"CheckButton",ThemeDB.get_default_theme().get_stylebox(state,"CheckButton"))
    target.set_stylebox("panel","TooltipPanel",_style(Color("152229"),GOLD))
    target.set_color("font_color","TooltipLabel",IVORY)
    target.set_font_size("font_size","TooltipLabel",16)
    target.set_stylebox("scroll","VScrollBar",_style(Color("162027"),Color("162027"),0))
    target.set_stylebox("grabber","VScrollBar",_style(Color("706951"),Color("706951"),0))
    target.set_stylebox("grabber_highlight","VScrollBar",_style(GOLD,GOLD,0))
    target.set_stylebox("grabber_pressed","VScrollBar",_style(RED,RED,0))
    target.set_stylebox("slider","HSlider",_style(Color("26353a"),Color("4a5148")))
    target.set_stylebox("grabber_area","HSlider",_style(GOLD,GOLD,0))
    target.set_stylebox("grabber_area_highlight","HSlider",_style(IVORY,IVORY,0))
    target.set_stylebox("panel","AcceptDialog",_style(Color("10191f"),GOLD,2))
    target.set_font("font","OptionButton",display_font())
    target.set_font_size("font_size","OptionButton",16)
    target.set_color("font_color","OptionButton",IVORY)
    target.set_stylebox("normal","OptionButton",_style(Color("101f20"),Color("61553f")))
    target.set_stylebox("hover","OptionButton",_style(Color("2c2522"),RED))
    target.set_stylebox("pressed","OptionButton",_style(Color("302220"),RED))
    target.set_stylebox("focus","OptionButton",_style(Color(0,0,0,0),RED,1))
    target.set_stylebox("panel","PopupMenu",_style(Color("0b1c1e"),GOLD))
    target.set_stylebox("hover","PopupMenu",_style(Color("302220"),RED))
    target.set_color("font_color","PopupMenu",IVORY)
    target.set_font("font","PopupMenu",display_font())

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
    hud_card.position=Vector2(26,24)
    hud_card.size=Vector2(330,106)
    hud_card.mouse_filter=Control.MOUSE_FILTER_IGNORE
    add_child(hud_card)
    var backing:=CHROME.new()
    backing.kind="hud"
    backing.size=hud_card.size
    backing.mouse_filter=Control.MOUSE_FILTER_IGNORE
    hud_card.add_child(backing)
    hud_crest=_icon(hud_card,load("res://assets/ui/seals/crimson.svg"),Vector2(10,16),Vector2(55,55))
    health_glyphs=CHROME.new()
    health_glyphs.kind="health"
    health_glyphs.position=Vector2(77,7)
    health_glyphs.size=Vector2(205,46)
    hud_card.add_child(health_glyphs)
    hearts=_label(hud_card,"",Vector2(266,17),Vector2(55,27),17,IVORY)
    hearts.add_theme_font_override("font",display_font())
    hearts.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
    _label(hud_card,"绯线",Vector2(79,58),Vector2(65,22),13,GOLD).add_theme_font_override("font",display_font())
    energy_status=_label(hud_card,"",Vector2(205,58),Vector2(112,22),13,IVORY)
    energy_status.add_theme_font_override("font",display_font())
    energy_status.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
    thread_bar=ProgressBar.new()
    thread_bar.position=Vector2(80,85)
    thread_bar.size=Vector2(224,5)
    thread_bar.custom_minimum_size=Vector2(0,5)
    thread_bar.show_percentage=false
    thread_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
    thread_bar.add_theme_font_size_override("font_size",1)
    thread_bar.add_theme_constant_override("outline_size",0)
    thread_bar.add_theme_stylebox_override("background",_meter_style(Color("293237")))
    thread_bar.add_theme_stylebox_override("fill",_meter_style(RED))
    thread_bar.size=Vector2(224,5)
    hud_card.add_child(thread_bar)
    thread_bar.update_minimum_size()
    thread_bar.size=Vector2(224,5)
    currency_emblem=_icon(self,ART.item("currency"),Vector2(1130,31),Vector2(28,28))
    currency=_label(self,"0",Vector2(1168,30),Vector2(88,30),21,GOLD)
    location_rule=CHROME.new()
    location_rule.kind="location"
    location_rule.position=Vector2(443,24)
    location_rule.size=Vector2(394,51)
    add_child(location_rule)
    location=_label(self,"",Vector2(478,27),Vector2(324,38),25,IVORY)
    location.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    toast=_label(self,"",Vector2(395,102),Vector2(490,60),16,IVORY)
    toast.add_theme_stylebox_override("normal",_style(Color(0.04,0.07,0.08,0.94),Color("514e3e")))
    toast.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    toast.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    prompt=_label(self,"",Vector2(370,549),Vector2(540,42),18,IVORY)
    prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    prompt.clip_text=true
    prompt.add_theme_stylebox_override("normal",_style(Color(0.04,0.07,0.08,0.94),GOLD))
    combat_status=_label(self,"",Vector2(28,144),Vector2(360,76),13,IVORY)
    combat_status.visible=false
    mechanism_status=_label(self,"",Vector2(30,141),Vector2(360,26),13,GOLD)
    healing_status=_label(self,"",Vector2(30,169),Vector2(360,24),13,MUTED)
    healing_status.mouse_filter=Control.MOUSE_FILTER_PASS
    healing_status.add_theme_stylebox_override("normal",_meter_style(Color(0.04,0.07,0.08,0.9)))
    healing_bar=ProgressBar.new()
    healing_bar.position=Vector2(30,197)
    healing_bar.size=Vector2(300,6)
    healing_bar.show_percentage=false
    healing_bar.add_theme_font_size_override("font_size",1)
    healing_bar.add_theme_constant_override("outline_size",0)
    healing_bar.max_value=1.0
    healing_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
    healing_bar.add_theme_stylebox_override("background",_meter_style(Color("233039")))
    healing_bar.add_theme_stylebox_override("fill",_meter_style(IVORY))
    healing_bar.visible=false
    healing_bar.size=Vector2(300,6)
    add_child(healing_bar)
    healing_bar.update_minimum_size()
    healing_bar.size=Vector2(300,6)
    pinned=_label(self,"",Vector2(30,212),Vector2(300,45),13,MUTED)
    pinned.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    for index in 4:
        var card:=Panel.new()
        card.position=Vector2(28+index*105,610)
        card.size=Vector2(96,78)
        card.mouse_filter=Control.MOUSE_FILTER_IGNORE
        card.add_theme_stylebox_override("panel",_style(Color(0.04,0.07,0.08,0.94),Color("514e3e")))
        add_child(card)
        tactical_cards.append(card)
        var card_frame:=CHROME.new()
        card_frame.kind="tactical"
        card_frame.size=card.size
        card.add_child(card_frame)
        tactical_icons.append(_icon(card,null,Vector2(6,6),Vector2(46,46)))
        tactical_values.append(_label(card,"",Vector2(53,13),Vector2(39,30),13,GOLD))
        tactical_names.append(_label(card,"",Vector2(8,54),Vector2(83,20),11,IVORY))
        tactical_names[-1].text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    tutorial_hint=_label(self,"",Vector2(28,687),Vector2(620,23),11,MUTED)
    for entry in [["B  构筑",_request_build_toggle],["Tab  行囊",func():level._toggle_backpack()],["M  地图",func():level._toggle_map()],["V  设置",func():level._toggle_audio_settings()]]:
        quick_actions.append(_button(self,entry[0],Vector2(827+quick_actions.size()*108,673),Vector2(100,33),entry[1]))
    boss_name=_label(self,"",Vector2(395,593),Vector2(490,27),17,GOLD)
    boss_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    boss_bar=ProgressBar.new()
    boss_bar.position=Vector2(468,628)
    boss_bar.size=Vector2(344,7)
    boss_bar.show_percentage=false
    boss_bar.add_theme_font_size_override("font_size",1)
    boss_bar.add_theme_constant_override("outline_size",0)
    boss_bar.add_theme_stylebox_override("background",_meter_style(Color("20262a")))
    boss_bar.add_theme_stylebox_override("fill",_meter_style(RED))
    boss_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
    boss_bar.size=Vector2(344,7)
    add_child(boss_bar)
    boss_bar.update_minimum_size()
    boss_bar.size=Vector2(344,7)

func _build_bag() -> void:
    bag=_panel(self,"巡礼行囊",Vector2(85,54),Vector2(1110,600))
    bag.name="BackpackOverlay"
    _well(bag,Vector2(724,136),Vector2(356,444))
    _well(bag,Vector2(26,186),Vector2(665,354))
    _label(bag,"器物有用途，旧物有来处。",Vector2(34,101),Vector2(640,26),16,MUTED)
    _icon(bag,ART.item("currency"),Vector2(848,31),Vector2(28,28))
    bag_currency=_label(bag,"",Vector2(883,32),Vector2(120,30),20,GOLD)
    var categories:= ["全部","织具","遗物","材料","要物","旅记"]
    for i in categories.size():
        var category: String=categories[i]
        var button:=_button(bag,category,Vector2(34+i*108,136),Vector2(100,38),func():
            bag_category=category
            refresh_inventory())
        bag_tabs.append(button)
        button.set_meta("inscription_tab",true)
        button.add_theme_font_size_override("font_size",20)
    var scroll:=ScrollContainer.new()
    scroll.position=Vector2(34,194)
    scroll.size=Vector2(645,337)
    scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    bag.add_child(scroll)
    bag_scroll=scroll
    journal_filters=HBoxContainer.new()
    journal_filters.position=Vector2(34,189)
    journal_filters.add_theme_constant_override("separation",9)
    journal_filters.visible=false
    bag.add_child(journal_filters)
    var filters:=[["all","全部"],["main","主线"],["quest","委托"],["evidence","证词"],["enemy","敌人"],["ending","结局"],["guide","手册"],["voice","自述"]]
    var filter_width:=floorf((645.0-(filters.size()-1)*9.0)/filters.size())
    for pair in filters:
        var filter_id:=String(pair[0])
        var filter_button:=_button(journal_filters,String(pair[1]),Vector2.ZERO,Vector2(filter_width,28),func():
            journal_filter=filter_id
            journal_selection=0
            bag_scroll.scroll_vertical=0
            refresh_inventory())
        filter_button.custom_minimum_size=Vector2(filter_width,28)
        filter_button.add_theme_font_size_override("font_size",13)
        journal_filter_buttons[filter_id]=filter_button
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
    bag.visibility_changed.connect(_journal_bag_visibility_changed)
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
    if journal_filters!=null:
        journal_filters.visible=bag_category=="旅记"
        bag_scroll.position.y=226 if journal_filters.visible else 194
        bag_scroll.size.y=305 if journal_filters.visible else 337
    begin_inventory_refresh()
    if bag_category=="旅记":
        _refresh_journal()
        return
    for item_id in _visible_inventory_ids():
        append_inventory_item(item_id)
    finish_inventory_refresh()

func begin_inventory_refresh() -> void:
    _remember_journal_scroll()
    if bag_category!="旅记":
        journal_reading_key=""
        journal_restore_pending=false
    if bag_pin!=null:
        bag_pin.text="PgUp/PgDn · LB/RB 翻页" if bag_category=="旅记" else "钉在旅记"
        bag_pin.tooltip_text="Home 到开头，End 到末尾；切换记录后保留本次阅读位置。" if bag_category=="旅记" else ""
    (bag.get_node("InscribedTitle") as TextureRect).texture=inscription_mark("journal" if bag_category=="旅记" else "inventory")
    (bag.get_node("InscriptionSubtitle") as Label).text="证词与心愿" if bag_category=="旅记" else "器物与旧物"
    for node in bag_grid.get_children():
        bag_grid.remove_child(node)
        node.queue_free()
    bag_currency.text=str(level.currency_count)
    bag_grid.columns=6
    inventory_build_selection=_reconcile_inventory_selection()

func append_inventory_item(item_id: String) -> void:
    var button:=_button(bag_grid,"",Vector2.ZERO,Vector2(94,98),func():
        level.backpack_selection=level.backpack_entry_ids.find(item_id)
        level._refresh_backpack_detail()
        refresh_inventory())
    button.set_meta("item_id",item_id)
    button.custom_minimum_size=Vector2(94,98)
    if item_id==inventory_build_selection:
        button.add_theme_stylebox_override("normal",_style(Color(.2,.065,.055,.2),RED,2))
    _icon(button,ART.item(item_id),Vector2(15,8),Vector2(64,58))
    var count: int=level.currency_count if item_id=="currency" else int(level.inventory_counts.get(item_id,0))
    var name_label:=_label(button,level._item_display_name(item_id),Vector2(4,70),Vector2(87,22),12)
    name_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    _label(button,str(count),Vector2(59,48),Vector2(30,23),13,GOLD)

func finish_inventory_refresh() -> void:
    var selected := inventory_build_selection
    for tab in bag_tabs:
        tab.add_theme_stylebox_override("normal",_tab_style(tab.text==bag_category))
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
        bag_tabs[i].add_theme_stylebox_override("normal",_tab_style(bag_tabs[i].text==bag_category))

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
    dialogue.get_child(0).kind="dialogue"
    _well(dialogue,Vector2(18,16),Vector2(188,220))
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
    dialogue_body.add_theme_font_override("font",FONT)
    dialogue_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    dialogue_body.custom_minimum_size=Vector2(825,0)
    dialogue_body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    dialogue_hint=_label(dialogue,_dialogue_binding_hint(),Vector2(24,242),Vector2(180,50),13,MUTED)
    dialogue_hint.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    dialogue_hint.mouse_filter=Control.MOUSE_FILTER_PASS
    dialogue_continue_button=_button(dialogue,"继续交谈",Vector2(221,250),Vector2(147,34),func():
        if is_instance_valid(dialogue_area):
            if level.world_mode:level._try_interact()
            else:level._talk_to_npc(dialogue_area))
    dialogue_route_button=_button(dialogue,"问问道路",Vector2(380,250),Vector2(147,34),func():_topic("route"))
    dialogue_quest_button=_button(dialogue,"询问心愿",Vector2(540,250),Vector2(147,34),func():_topic("wish"))

func show_speaker(area: Area2D) -> void:
    dialogue_area=area
    dialogue_scroll.scroll_vertical=0
    dialogue_reading_key=_dialogue_reading_key(area,dialogue_body.text)
    var reading:=dialogue_reading.restore(dialogue_reading_key)
    if not reading.is_empty():_restore_dialogue_scroll(dialogue_reading_key,int(reading.scroll))
    var history := String(area.get_meta("kind",""))=="history"
    dialogue_portrait.texture=ART.item("moss_lens") if history else ART.portrait(String(area.get_meta("npc_id","")))
    dialogue_continue_button.text="记入旅记" if history else "继续交谈"
    dialogue_route_button.visible=not history
    dialogue_quest_button.visible=not history
    dialogue_hint.text=_dialogue_binding_hint()
    dialogue_hint.tooltip_text=dialogue_hint.text
    var topics: Dictionary=area.get_meta("dialogue_topics",{})
    var quest: Dictionary=topics.get("quest",{})
    dialogue_quest_button.text="询问心愿"
    if not quest.is_empty():
        var required:=String(quest.get("item",""))
        if level.wish_offering_available(required) and not bool(level.story_flags.get(String(quest.get("complete_flag","")),false)):
            dialogue_quest_button.text="交付信物"
    var sprite:=area.get_node_or_null("FriendlyFamilySprite") as AnimatedSprite2D
    if sprite!=null:sprite.play("talk")

func _topic(key: String) -> void:
    if not is_instance_valid(dialogue_area):return
    if level.world_mode and key == "wish":
        var topics: Dictionary = dialogue_area.get_meta("dialogue_topics", {})
        var quest: Dictionary = topics.get("quest", {})
        var result: Dictionary = level.perform_wish_topic(quest, dialogue_area)
        if not bool(result.get("ok", false)):
            level._toast(String(result.get("reason", "心愿尚未确认，请重试。")))
            return
        dialogue_area.set_meta("world_line_committed", true)
        dialogue_area.set_meta("world_displayed_index", -1)
        var line := String(quest.get("thanks", "我会记住你带回的消息。")) if bool(result.get("delivered", false)) else String(topics.get(key, "你若愿意听，我们就再坐一会儿。"))
        level._show_dialogue(dialogue_area, line)
        return
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
            if level.wish_offering_available(required) and not bool(level.story_flags.get(flag,false)):
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

func _dialogue_reading_key(area: Area2D,line: String) -> String:
    return "%s|%s|%s|%d|%s" % [String(level.config.get("id","")),String(area.get_meta("npc_id",area.name)),String(area.get_meta("dialogue_state","")),int(area.get_meta("world_displayed_index",-1)),line.sha256_text()]

func dialogue_reading_state(area: Area2D,line: String) -> Dictionary:
    return dialogue_reading.restore(_dialogue_reading_key(area,line))

func forget_dialogue_reading() -> void:
    dialogue_reading.forget(dialogue_reading_key)

func _restore_dialogue_scroll(key: String,value: int) -> void:
    await get_tree().process_frame
    if is_inside_tree() and key==dialogue_reading_key and dialogue.visible and is_instance_valid(dialogue_area):
        dialogue_scroll.scroll_vertical=value

func close_dialogue() -> void:
    if is_instance_valid(dialogue_area):
        if level.world_mode:
            var committed:=bool(dialogue_area.get_meta("world_line_committed",false)) and int(dialogue_area.get_meta("world_displayed_index",-1))>=0
            dialogue_reading.capture(dialogue_reading_key,dialogue_body.text.length(),dialogue_body.visible_characters,dialogue_scroll.scroll_vertical,committed)
        var sprite:=dialogue_area.get_node_or_null("FriendlyFamilySprite") as AnimatedSprite2D
        if sprite!=null:sprite.play("idle")
    dialogue_area=null
    dialogue_reading_key=""

func _build_settings() -> void:
    settings=_panel(self,"设置与无障碍",Vector2(135,48),Vector2(1010,618))
    settings.name="AudioSettingsOverlay"
    _well(settings,Vector2(22,98),Vector2(458,280))
    _well(settings,Vector2(500,98),Vector2(487,280))
    _label(settings,"声音",Vector2(34,100),Vector2(440,26),20,GOLD)
    var rows: Array=level.AUDIO_SETTINGS_ROWS
    for i in rows.size():
        var key:=String(rows[i][0])
        settings_labels[key]=_label(settings,String(rows[i][1]).split(" ")[0],Vector2(34,140+i*43),Vector2(145,30),16)
        var slider:=HSlider.new()
        slider.position=Vector2(190,146+i*43)
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
    _label(settings,"阅读、画面与手柄",Vector2(512,100),Vector2(440,26),20,GOLD)
    _accessibility_slider("subtitle_size","字幕字号",Vector2(512,136),17,26,1)
    _accessibility_slider("subtitle_speed","字幕速度",Vector2(512,170),0.5,2.0,0.25)
    _accessibility_slider("camera_shake","镜头震动",Vector2(512,204),0,1,0.25)
    _accessibility_slider("camera_lookahead","镜头前瞻",Vector2(512,238),0,1,0.25)
    _accessibility_slider("vibration_strength","手柄力度",Vector2(512,272),0,1,0.25)
    _accessibility_toggle("flash_enabled","受击闪光",Vector2(512,305))
    _accessibility_toggle("vibration_enabled","手柄震动",Vector2(725,305))
    _accessibility_toggle("tutorial_hints","探索提示",Vector2(512,339))
    _accessibility_toggle("navigation_assist","导航辅助",Vector2(725,339))
    _label(settings,"按键重映射 · 选择动作后按键、按钮或推动扳机",Vector2(34,384),Vector2(740,28),17,GOLD)
    reset_bindings_button=_button(settings,"恢复默认按键",Vector2(800,381),Vector2(172,28),_reset_bindings)
    reset_bindings_button.add_theme_font_size_override("font_size",13)
    var action_index:=0
    for action in REMAPPABLE_ACTIONS:
        var action_id:=String(action)
        var button:=_button(settings,"",Vector2(34+(action_index%REMAP_COLUMNS)*236,414+(action_index/REMAP_COLUMNS)*27),Vector2(226,26),func():_begin_remap(action_id))
        button.add_theme_font_size_override("font_size",12)
        remap_buttons[action_id]=button
        action_index+=1
    remap_status=_label(settings,"Esc 取消重映射；方向键 / 手柄十字键选择，确认键操作。",Vector2(34,549),Vector2(938,24),13,MUTED)
    if not binding_recovery_notice.is_empty():remap_status.text=binding_recovery_notice
    remap_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    for slot_index in 3:
        var slot:=slot_index+1
        save_slot_buttons[slot]=_button(settings,"存档槽 %d" % slot,Vector2(34+slot_index*219,573),Vector2(206,30),func():_select_save_slot(slot))
        save_slot_buttons[slot].add_theme_font_size_override("font_size",13)
        save_slot_buttons[slot].text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    _button(settings,"恢复当前槽备份",Vector2(691,573),Vector2(137,30),_restore_save_backup).add_theme_font_size_override("font_size",13)
    journey_history_button=_button(settings,"浏览旧旅途",Vector2(838,573),Vector2(134,30),_show_journey_history)
    journey_history_button.add_theme_font_size_override("font_size",13)
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
    settings.add_child(toggle)
    toggle.text=title
    toggle.position=point
    toggle.size=Vector2(206,35)
    toggle.button_pressed=bool(accessibility[key])
    toggle.toggled.connect(func(value: bool):
        accessibility[key]=value
        _save_accessibility()
        _apply_accessibility())

func get_accessibility(key: String, fallback: Variant=null) -> Variant:
    return accessibility.get(key,fallback)

func _load_accessibility() -> void:
    # Before any saved preference applies, even when there is no preference file yet.
    _record_default_bindings()
    var config:=ConfigFile.new()
    if config.load(accessibility_path)!=OK:return
    # A malformed preference must not prevent the settings screen from opening.
    for key in ["flash_enabled","vibration_enabled","tutorial_hints","navigation_assist"]:
        var value: Variant=config.get_value("accessibility",key,accessibility[key])
        if value is bool:accessibility[key]=value
    accessibility["subtitle_size"]=int(_finite_setting(config,"subtitle_size",17,26))
    accessibility["subtitle_speed"]=_finite_setting(config,"subtitle_speed",0.5,2.0)
    accessibility["camera_shake"]=_finite_setting(config,"camera_shake",0,1)
    accessibility["camera_lookahead"]=_finite_setting(config,"camera_lookahead",0,1)
    accessibility["vibration_strength"]=_finite_setting(config,"vibration_strength",0,1)
    var saved := {}
    for action in REMAPPABLE_ACTIONS:
        if config.has_section_key("bindings",action):saved[action]=config.get_value("bindings",action)
    var result: Dictionary=BINDING_POLICY.restore(BINDING_POLICY.snapshot(),saved,REMAPPABLE_ACTIONS)
    for action in REMAPPABLE_ACTIONS:
        if not result.bindings.has(action):continue
        InputMap.action_erase_events(action)
        for event in result.bindings[action]:InputMap.action_add_event(action,event)
    binding_recovery_notice="部分输入设置无效或冲突，已保留对应设备的可用绑定。" if result.rejected>0 else ""
    if remap_status!=null:
        remap_status.text=binding_recovery_notice if not binding_recovery_notice.is_empty() else "Esc 取消重映射；方向键 / 手柄十字键选择，确认键操作。"

func _finite_setting(config: ConfigFile, key: String, minimum: float, maximum: float) -> float:
    var value: Variant=config.get_value("accessibility",key,accessibility[key])
    if not (value is int or value is float) or not is_finite(float(value)):
        return float(accessibility[key])
    return clampf(float(value),minimum,maximum)

func _normalized_binding(value: Variant) -> InputEvent:
    return BINDING_POLICY.normalize(value)

func is_remapping_input() -> bool:
    return settings!=null and settings.visible and (not remap_target.is_empty() or Engine.get_process_frames()==remap_capture_frame)

func _remember_gui_focus(_focused: Control) -> void:
    if level==null or not is_instance_valid(level):return
    var focused:=get_viewport().gui_get_focus_owner()
    if not _is_navigable_focus(focused):return
    for overlay in ["settings","backpack","map","dialogue","build"]:
        var controls:=_overlay_controls(overlay)
        for control in controls:
            if control==focused or control.is_ancestor_of(focused):
                overlay_focus_memory[overlay]=weakref(focused)
                return
    var overlay:=String(level.active_overlay)
    if not overlay.is_empty():overlay_focus_memory[overlay]=weakref(focused)

func _is_navigable_focus(control: Control) -> bool:
    if not is_instance_valid(control) or not control.is_inside_tree() or not control.is_visible_in_tree():return false
    if control.focus_mode!=Control.FOCUS_ALL:return false
    if control is BaseButton and (control as BaseButton).disabled:return false
    return true

func _overlay_controls(overlay: String) -> Array[Control]:
    var root: Node=null
    match overlay:
        "settings":root=settings
        "backpack":root=bag
        "map":root=level.get("map_panel") if level!=null else null
        "dialogue":root=dialogue
        "build":root=build_panel
    var result: Array[Control]=[]
    if root is Control and is_instance_valid(root):_collect_navigable(root,result)
    return result

func _collect_navigable(node: Node, result: Array[Control]) -> void:
    for child in node.get_children():
        if child is Control:
            var control:=child as Control
            if _is_navigable_focus(control):result.append(control)
        _collect_navigable(child,result)

func _focus_overlay(overlay: String, restore: bool=true) -> void:
    var controls:=_overlay_controls(overlay)
    if controls.is_empty():return
    if restore and overlay_focus_memory.has(overlay):
        var reference: Variant=overlay_focus_memory[overlay]
        var remembered:=reference.get_ref() as Control if reference is WeakRef else null
        if controls.has(remembered) and _is_navigable_focus(remembered):
            remembered.grab_focus()
            return
    controls[0].grab_focus()

func _on_joy_connection_changed(_device: int, connected: bool) -> void:
    if not connected and not remap_target.is_empty():
        remap_target=""
        remap_capture_frame=Engine.get_process_frames()
        if is_instance_valid(remap_status):remap_status.text="手柄已断开，重映射已取消。"
    elif connected and level!=null and is_instance_valid(level):
        var overlay:=String(level.active_overlay)
        if not overlay.is_empty() and not _is_navigable_focus(get_viewport().gui_get_focus_owner()):
            call_deferred("_focus_overlay",overlay,true)

func _save_accessibility() -> void:
    var config:=ConfigFile.new()
    for key in accessibility:config.set_value("accessibility",key,accessibility[key])
    for action in REMAPPABLE_ACTIONS:
        if InputMap.has_action(action):config.set_value("bindings",action,InputMap.action_get_events(action))
    var result:=config.save(accessibility_path)
    if result!=OK and toast!=null:toast.text="设置保存失败（%d），当前设置仍有效。" % result

func _apply_accessibility() -> void:
    var feel := get_node_or_null("/root/FeelKit")
    if feel != null and feel.has_method("set_accessibility"):
        feel.set_accessibility(accessibility)
    if dialogue_body!=null:dialogue_body.add_theme_font_size_override("font_size",int(accessibility["subtitle_size"]))
    if build_detail!=null:build_detail.add_theme_font_size_override("normal_font_size",int(accessibility["subtitle_size"]))
    if level!=null and is_instance_valid(level.player):
        level.player.set_meta("accessibility",accessibility.duplicate())
        applied_player=level.player

func _record_default_bindings() -> void:
    if not default_bindings.is_empty():return
    for action in REMAPPABLE_ACTIONS:
        if not InputMap.has_action(action):continue
        var events: Array=[]
        for event in InputMap.action_get_events(action):events.append(event.duplicate())
        default_bindings[action]=events

## U06: one press puts every remappable action back to the shipped bindings.
func _reset_bindings() -> void:
    remap_target=""
    for action in default_bindings:
        InputMap.action_erase_events(action)
        for event in default_bindings[action]:InputMap.action_add_event(action,event.duplicate())
    _save_accessibility()
    _refresh_remap_labels()
    remap_status.text="已恢复全部默认按键；声音、字幕与画面设置不变。"

func _begin_remap(action: String) -> void:
    if not REMAPPABLE_ACTIONS.has(action) or settings==null or not settings.is_visible_in_tree():return
    remap_target=action
    remap_status.text="请为「%s」按键、鼠标按钮或手柄输入；Esc 取消。" % REMAPPABLE_ACTIONS[action]

func _cancel_remap(reason: String) -> void:
    if remap_target.is_empty():return
    remap_target=""
    remap_capture_frame=Engine.get_process_frames()
    if is_instance_valid(remap_status):remap_status.text=reason

func _remap_visibility_changed() -> void:
    if not settings.is_visible_in_tree():_cancel_remap("已离开设置，重映射已取消。")

func _notification(what: int) -> void:
    if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
        _cancel_remap("窗口已失去焦点，重映射已取消；原绑定保留。")

func _refresh_remap_labels() -> void:
    for action in remap_buttons:
        var names: Array[String]=[]
        if InputMap.has_action(action):
            for event in InputMap.action_get_events(action):names.append(_binding_name(event))
        remap_buttons[action].text=String(REMAPPABLE_ACTIONS[action])+" · "+(" / ".join(names) if not names.is_empty() else "未设置")
        remap_buttons[action].text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
        remap_buttons[action].tooltip_text=remap_buttons[action].text

func _input(event: InputEvent) -> void:
    if level==null or not construction_complete:return
    PROMPT_BINDINGS.observe(event)
    if not settings.visible:remap_target=""
    if not remap_target.is_empty():
        remap_capture_frame=Engine.get_process_frames()
        if event is InputEventKey and event.pressed and (event.keycode==KEY_ESCAPE or event.physical_keycode==KEY_ESCAPE):
            remap_target=""
            remap_status.text="已取消重映射。"
            get_viewport().set_input_as_handled()
        elif (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventJoypadButton and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventJoypadMotion and absf(event.axis_value)>0.7):
            var accepted:=_normalized_binding(event)
            if accepted==null:
                get_viewport().set_input_as_handled()
                return
            if BINDING_POLICY.is_reserved(accepted):
                remap_status.text="此输入保留给界面快捷键，请换一个输入或 Esc 取消。"
                get_viewport().set_input_as_handled()
                return
            var action:=remap_target
            var conflicts: Array[String]=[]
            for other in BINDING_POLICY.conflicts(accepted,action,BINDING_POLICY.snapshot()):
                conflicts.append(String(REMAPPABLE_ACTIONS.get(other,"其他动作")))
            if not conflicts.is_empty():
                remap_status.text="此输入已用于「%s」，请换一个输入或 Esc 取消。" % "、".join(conflicts)
                get_viewport().set_input_as_handled()
                return
            if not InputMap.has_action(action):InputMap.add_action(action)
            for old in InputMap.action_get_events(action):
                if BINDING_POLICY.family(old)==BINDING_POLICY.family(accepted):InputMap.action_erase_event(action,old)
            InputMap.action_add_event(action,accepted)
            remap_target=""
            _save_accessibility()
            _refresh_remap_labels()
            remap_status.text="已保存「%s」的新输入；其余设备的绑定继续可用。" % REMAPPABLE_ACTIONS[action]
            get_viewport().set_input_as_handled()
        return
    if bag.visible and bag_category=="旅记":
        var step:=0
        if event is InputEventKey and event.pressed and not event.echo:
            var key: int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
            step={KEY_PAGEUP:-1,KEY_PAGEDOWN:1,KEY_HOME:-2,KEY_END:2}.get(key,0)
        elif event is InputEventJoypadButton and event.pressed:
            step=-1 if event.button_index==JOY_BUTTON_LEFT_SHOULDER else 1 if event.button_index==JOY_BUTTON_RIGHT_SHOULDER else 0
        if step!=0:
            _scroll_journal(step)
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
    _well(build_panel,Vector2(627,174),Vector2(457,368))
    _well(build_panel,Vector2(26,174),Vector2(588,368))
    build_art=CHROME.new()
    build_art.kind="seal_art"
    build_art.position=Vector2(288,192)
    build_art.size=Vector2(309,309)
    build_panel.add_child(build_art)
    build_art_caption=_label(build_panel,"以线缝名，借势出针。",Vector2(278,508),Vector2(332,28),18,GOLD)
    build_art_caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    build_summary=_label(build_panel,"",Vector2(34,101),Vector2(1030,26),16,GOLD)
    # Keep the six established pages while exposing both accessory families
    # through an explicit selector inside the 铭饰 page.
    var categories: Array[String]=["契印","技能","战具","铭饰","强化","构筑"]
    for i in categories.size():
        var category:=categories[i]
        var tab:=_button(build_panel,category,Vector2(34+i*173,135),Vector2(162,38),func():
            build_category=category
            build_selection=""
            if category=="铭饰":build_family="combat_accessory"
            refresh_build())
        tab.set_meta("build_category",category)
        tab.set_meta("inscription_tab",true)
        tab.add_theme_font_size_override("font_size",21)
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
    for family in ["combat_accessory","travel_accessory"]:
        var family_id:=String(family)
        var family_button:=_button(build_panel,family_id,Vector2(640+family_selector_buttons.size()*216,174),Vector2(207,33),func():
            build_family=family_id
            build_assign_slot=0
            build_selection=""
            refresh_build())
        family_selector_buttons.append(family_button)
    clear_family_slot_button=_button(build_panel,"卸下此槽装备",Vector2(640,252),Vector2(207,30),func():
        var family_id:=_build_family_for_page()
        if family_id.is_empty():return
        _perform_build_action("equip_family_slot","",{"family":family_id,"slot":build_assign_slot}))
    clear_family_slot_button.add_theme_font_size_override("font_size",13)
    build_emblem=_icon(build_panel,null,Vector2(645,290),Vector2(48,48))
    build_heading=_label(build_panel,"",Vector2(710,290),Vector2(350,45),23,GOLD)
    build_detail.position=Vector2(646,340)
    build_detail.size=Vector2(418,185)
    build_detail.add_theme_font_size_override("normal_font_size",18)
    build_detail.add_theme_color_override("default_color",IVORY)
    build_detail.scroll_active=true
    build_panel.add_child(build_detail)
    resupply_preview_button=_button(build_panel,"查看补给报价",Vector2(640,535),Vector2(200,30),_preview_tool_resupply)
    resupply_confirm_button=_button(build_panel,"确认购买补给",Vector2(850,535),Vector2(220,30),_confirm_tool_resupply)
    resupply_preview_button.add_theme_font_size_override("font_size",13)
    resupply_confirm_button.add_theme_font_size_override("font_size",13)
    resupply_confirm_button.disabled=true
    _label(build_panel,"点击 / 确认键执行  ·  方向键 / 手柄十字键选择  ·  Esc 返回",Vector2(34,572),Vector2(590,18),11,MUTED)

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

func _is_at_build_workstation(snapshot: Dictionary) -> bool:
    if snapshot.has("at_workstation"):
        return bool(snapshot.at_workstation)
    if level.has_method("is_near_shrine"):
        return bool(level.call("is_near_shrine"))
    # Legacy/demo adapters have no location state. The production adapter
    # supplies the authoritative live snapshot field above.
    return not level.has_method("_near_workstation") or bool(level.call("_near_workstation"))

func _skill_practiced(skill_id: String) -> bool:
    var flags: Variant=level.get("story_flags") if level!=null else null
    # Fixture adapters without story state are not gated.
    if not flags is Dictionary:return true
    return bool(flags.get("skill_practiced_"+skill_id,false))

func _has_patterns(recipe: Dictionary) -> bool:
    var counts: Variant=level.get("inventory_counts") if level!=null else null
    if not counts is Dictionary:return true
    for item in recipe.get("requires_items",[]):
        if int(counts.get(item,0))<=0:return false
    return true

## E04: who makes it, what pattern it needs, and what it changes, before any spending.
func _craft_lines(entry: Dictionary, snapshot: Dictionary) -> Array:
    var lines: Array=[]
    if bool(entry.get("crafted",false)):lines.append("\n◆ 已制作；每件只做一次。")
    if String(entry.get("kind",""))=="tool_capacity":
        var tool_name:=String(entry.get("target",""))
        for tool in snapshot.get("tools",[]):
            if String(tool.get("id",""))==tool_name:tool_name=String(tool.get("name",tool_name))
        var now:=int(entry.get("capacity_now",0))
        if bool(entry.get("crafted",false)):lines.append("%s 携带上限：%d（含改制 +%d）" % [tool_name,now,int(entry.get("amount",1))])
        else:lines.append("\n%s 携带上限：%d → %d" % [tool_name,now,now+int(entry.get("amount",1))])
        lines.append("改制不附带次数；多出的一份在钟龛按原价补给。")
        if not bool(entry.get("target_unlocked",true)):lines.append("◇ 先取得%s，工匠才能改制。" % tool_name)
    elif String(entry.get("kind",""))=="slot_part":
        lines.append("\n解锁：三枚契印的第 3 个行旅铭饰槽。各契印仍需先修复自己的专属机制。")
    elif String(entry.get("kind",""))=="passive":
        lines.append("制作后在钟龛选择铭饰槽装备；不会自动穿戴或补充生命、绯线。")
    var counts: Variant=level.get("inventory_counts") if level!=null else {}
    for item in entry.get("requires_items",[]):
        var owned: bool=counts is Dictionary and int(counts.get(item,0))>0
        var item_name:=String(level.call("_item_display_name",String(item))) if level!=null and level.has_method("_item_display_name") else String(item)
        lines.append("图样「%s」：%s" % [item_name,"已取得，制作时只给工匠看，不会收走" if owned else "未取得"])
        if not owned:lines.append("◇ "+String(entry.get("unlock_hint","")))
    var flags: Variant=level.get("story_flags") if level!=null else null
    var flag:=String(entry.get("requires_flag",""))
    if not flag.is_empty() and flags is Dictionary and not bool(flags.get(flag,false)):lines.append("◇ "+String(entry.get("requires_flag_hint","")))
    var artisan_name:=String(entry.get("artisan_name","工匠"))
    lines.append("制作者：%s" % artisan_name)
    if level!=null and level.has_method("near_artisan_id") and String(level.call("near_artisan_id"))!=String(entry.get("artisan","")):
        lines.append("◇ 要到%s面前才能制作。" % artisan_name)
    return lines

## C04: compare one 校习 direction with the untrained skill and the other direction.
func _skill_branch_lines(skill: Dictionary, recipe: Dictionary) -> Array:
    var lines: Array=[]
    var branches: Dictionary=skill.get("branches",{})
    var key:="a" if int(recipe.get("branch",1))==1 else "b"
    var other:="b" if key=="a" else "a"
    var current:=String(skill.get("branch",""))
    lines.append("\n%s · 当前：%s" % [String(skill.get("name","")),String(branches.get(current,{}).get("name","未校习")) if not current.is_empty() else "未校习"])
    lines.append("「%s」的改变：" % String(branches.get(key,{}).get("name","")))
    var labels:={"damage":"伤害","range":"距离","windup":"起手（秒）","recovery":"收势（秒）","duration":"持续（秒）","energy_cost":"绯线消耗","stagger":"踉跄（秒）"}
    var modifiers: Dictionary=branches.get(key,{}).get("modifiers",{})
    for stat in modifiers:
        var delta:=float(modifiers[stat])
        var amount:=str(int(delta)) if is_equal_approx(delta,roundf(delta)) else "%.2f" % delta
        lines.append("  %s %s%s" % [String(labels.get(stat,stat)),"+" if delta>0.0 else "",amount])
    lines.append("另一方向「%s」：%s" % [String(branches.get(other,{}).get("name","")),String(branches.get(other,{}).get("description",""))])
    lines.append("两个方向只能取其一；之后改选另一方向需再付全价。")
    if not _skill_practiced(String(recipe.get("target",""))):
        lines.append("◇ 先在练针架上用这个技能命中三次，练熟后才能选方向。")
    if level!=null and level.has_method("is_near_artisan") and not bool(level.call("is_near_artisan")):
        lines.append("◇ 校习要与织线学徒、雨铸匠或蜂蜡商人面对面进行。")
    return lines

func _family_row(snapshot: Dictionary, family_id: String) -> Dictionary:
    var families: Variant=snapshot.get("slot_families",{})
    if families is Dictionary and families.get(family_id) is Dictionary:return families[family_id]
    if families is Array:
        for value in families:
            if value is Dictionary and String(value.get("id",""))==family_id:return value
    return {}

func _family_slots(snapshot: Dictionary, family_id: String) -> Array:
    var layout: Variant=snapshot.get("slot_layout",{})
    if layout is Dictionary and layout.get(family_id) is Array:return layout[family_id]
    var row:=_family_row(snapshot,family_id)
    return row.get("slots",[]) if row.get("slots",[]) is Array else []

func _slot_dormancy_reason(slot: Dictionary, item_id: String) -> String:
    if item_id.is_empty():return ""
    if not bool(slot.get("unlocked",true)):return "槽位未解锁"
    var compatible: Array=slot.get("compatible",[])
    if not compatible.is_empty() and not compatible.has(item_id):return "装备与槽位不兼容"
    return ""

func _family_slot_dormancy_reason(snapshot: Dictionary,family_id: String,slot_index: int,item_id: String) -> String:
    if item_id.is_empty():return ""
    for slot_value in _family_slots(snapshot,family_id):
        var slot: Dictionary=slot_value
        if int(slot.get("index",-1))==slot_index:return _slot_dormancy_reason(slot,item_id)
    return ""

func _family_options(snapshot: Dictionary, family_id: String) -> Array:
    var row:=_family_row(snapshot,family_id)
    var options: Variant=row.get("options",[])
    if options is Array and not options.is_empty():return options
    var legacy_key: String={"tool":"tools","thread_skill":"skills","combat_accessory":"passive_options","travel_accessory":"passive_options"}.get(family_id,"")
    return snapshot.get(legacy_key,[]) if not legacy_key.is_empty() else []

func _build_family_for_page() -> String:
    match build_category:
        "技能":return "thread_skill"
        "战具":return "tool"
        "铭饰":return build_family
    return ""

func _family_entry(snapshot: Dictionary, family_id: String, id: String) -> Dictionary:
    for value in _family_options(snapshot,family_id):
        if value is Dictionary and String(value.get("id",""))==id:return value
    return {}

func _family_option_names(snapshot: Dictionary,family_id: String,ids: Array) -> Array[String]:
    var names: Array[String]=[]
    for value in ids:
        var id:=String(value)
        var entry: Dictionary=_family_entry(snapshot,family_id,id)
        names.append(String(entry.get("name",id)))
    return names

func _ensure_family_slot_buttons(snapshot: Dictionary, family_id: String, slots: Array) -> void:
    if not slots.is_empty():build_assign_slot=clampi(build_assign_slot,0,slots.size()-1)
    while build_slot_buttons.size()<slots.size():
        var slot_index:=build_slot_buttons.size()
        var button:=_button(build_panel,"",Vector2.ZERO,Vector2(207,33),func():
            build_assign_slot=slot_index
            refresh_build())
        build_slot_buttons.append(button)
    while build_slot_buttons.size()>slots.size():
        var old: Button=build_slot_buttons.pop_back()
        old.queue_free()
    var offset_y:=212 if build_category=="铭饰" else 174
    var slot_left:=640.0
    var slot_gap:=8.0
    var slot_width:=minf(207.0,(float(build_panel.size.x)-26.0-slot_left-slot_gap*maxi(0,slots.size()-1))/maxi(1,slots.size()))
    var options:=_family_options(snapshot,family_id)
    for index in build_slot_buttons.size():
        var slot: Dictionary=slots[index]
        var button: Button=build_slot_buttons[index]
        button.position=Vector2(slot_left+index*(slot_width+slot_gap),offset_y)
        button.size.x=slot_width
        button.custom_minimum_size.x=slot_width
        button.visible=true
        var equipped_id:=String(slot.get("equipped_id",""))
        var equipped:=_family_entry(snapshot,family_id,equipped_id)
        var dormant_reason:=_slot_dormancy_reason(slot,equipped_id)
        var label:=String(slot.get("name","位置 %d" % (index+1)))
        if label.is_empty():label="位置 %d" % (index+1)
        if not bool(slot.get("unlocked",true)):label="🔒 "+label
        if not equipped_id.is_empty():
            label+=" · "+String(equipped.get("name",equipped_id))
            if not dormant_reason.is_empty():label+=" · 休眠"
        else:label+=" · 空"
        button.text=("▶ " if index==build_assign_slot else "○ ")+label
        button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
        button.disabled=not bool(slot.get("unlocked",true))
        var compatible_ids: Array=slot.get("compatible",[])
        var compatible_names:=_family_option_names(snapshot,family_id,compatible_ids)
        var tooltip:=label+"\n"
        if button.disabled:
            tooltip+="此槽位尚未解锁"
            if not dormant_reason.is_empty():tooltip+="\n休眠装备："+String(equipped.get("name",equipped_id))+"\n未激活："+dormant_reason
        else:
            tooltip+="当前装备："+(String(equipped.get("name",equipped_id)) if not equipped_id.is_empty() else "空")
            if not dormant_reason.is_empty():tooltip+="\n未激活："+dormant_reason
            tooltip+="\n兼容："+("、".join(compatible_names) if not compatible_names.is_empty() else "不限")
        button.tooltip_text=tooltip
        button.add_theme_stylebox_override("normal",_tab_style(index==build_assign_slot))
        button.focus_neighbor_left=button.get_path_to(build_slot_buttons[index-1]) if index>0 else NodePath("")
        button.focus_neighbor_right=button.get_path_to(build_slot_buttons[index+1]) if index+1<build_slot_buttons.size() else NodePath("")
    for index in range(slots.size(),build_slot_buttons.size()):build_slot_buttons[index].hide()

func _family_count_summary(snapshot: Dictionary, family_id: String, slots: Array) -> String:
    var active:=0
    var unlocked:=0
    var dormant:=0
    for slot_value in slots:
        var slot: Dictionary=slot_value
        if bool(slot.get("unlocked",true)):unlocked+=1
        var item_id:=String(slot.get("equipped_id",""))
        if item_id.is_empty():continue
        if _slot_dormancy_reason(slot,item_id).is_empty():active+=1
        else:dormant+=1
    var row:=_family_row(snapshot,family_id)
    return "%s 有效 %d / %d（已解锁 %d 槽 · 休眠 %d）" % [String(row.get("name",family_id)),active,slots.size(),unlocked,dormant]

func _all_family_count_summary(snapshot: Dictionary) -> String:
    var parts: Array[String]=[]
    for family_id in ["tool","combat_accessory","travel_accessory","thread_skill"]:
        var slots:=_family_slots(snapshot,family_id)
        if slots.is_empty():continue
        var active:=0
        var dormant:=0
        for value in slots:
            var slot: Dictionary=value
            var item_id:=String(slot.get("equipped_id",""))
            if item_id.is_empty():continue
            if _slot_dormancy_reason(slot,item_id).is_empty():active+=1
            else:dormant+=1
        var family:=_family_row(snapshot,family_id)
        parts.append("%s %d/%d%s" % [String(family.get("name",family_id)),active,slots.size()," · 休眠 %d" % dormant if dormant>0 else ""])
    return " · ".join(parts)

func _preview_tool_resupply() -> void:
    resupply_quote={}
    if level==null or not level.has_method("perform_build_action"):
        build_heading.text="战具补给报价"
        build_detail.text="补给报价不可用。"
        build_detail.scroll_to_line(0)
        resupply_confirm_button.disabled=true
        return
    var quote: Variant=level.call("perform_build_action","quote_resupply")
    if not quote is Dictionary:
        build_heading.text="战具补给报价"
        build_detail.text="补给报价暂不可用。"
        build_detail.scroll_to_line(0)
        resupply_confirm_button.disabled=true
        return
    resupply_quote=quote.duplicate(true)
    build_heading.text="战具补给报价"
    build_detail.text=_resupply_quote_text(resupply_quote)
    build_detail.scroll_to_line(0)
    resupply_confirm_button.disabled=not bool(resupply_quote.get("ok",false))

func _resupply_quote_text(quote: Dictionary) -> String:
    if not bool(quote.get("ok",false)):
        return "补给不可购买 · "+String(quote.get("reason","当前无可补给内容"))
    var lines: Array[String]=["补给预览 · 确认前不会扣除任何货币"]
    var charges: Variant=quote.get("charges",quote.get("refill",{}))
    if charges is Dictionary:
        for id in charges:
            var amount: Variant=charges[id]
            if amount is Dictionary:amount=amount.get("amount",amount.get("charges",0))
            if int(amount)>0:lines.append("%s +%d" % [_resupply_tool_name(String(id)),int(amount)])
    var cost: Variant=quote.get("cost",{})
    if cost is Dictionary:
        if int(cost.get("currency",0))>0:lines.append("碎钱：%d" % int(cost.currency))
        var materials: Variant=cost.get("materials",{})
        if materials is Dictionary:
            for material in materials:
                lines.append("%s：%d" % [level._item_display_name(String(material)) if level.has_method("_item_display_name") else String(material),int(materials[material])])
    return "\n".join(lines)

func _resupply_tool_name(item_id: String) -> String:
    var snapshot: Dictionary=_build_snapshot()
    var entry: Dictionary=_family_entry(snapshot,"tool",item_id)
    var localized_name:=String(entry.get("name",""))
    if not localized_name.is_empty():return localized_name
    if level!=null and level.has_method("_item_display_name"):
        return String(level.call("_item_display_name",item_id))
    return item_id

func _confirm_tool_resupply() -> void:
    if resupply_quote.is_empty() or not bool(resupply_quote.get("ok",false)):return
    var current: Variant=level.call("perform_build_action","quote_resupply") if level!=null and level.has_method("perform_build_action") else {}
    if not current is Dictionary or not bool(current.get("ok",false)):
        resupply_quote=current if current is Dictionary else {}
        build_heading.text="战具补给报价"
        build_detail.text="先前报价已失效。\n\n"+_resupply_quote_text(resupply_quote)
        build_detail.scroll_to_line(0)
        resupply_confirm_button.disabled=true
        return
    if current.get("charges",{})!=resupply_quote.get("charges",{}) or current.get("cost",{})!=resupply_quote.get("cost",{}):
        resupply_quote=current.duplicate(true)
        build_heading.text="战具补给报价"
        build_detail.text="钱包或库存已变化，请复核最新报价后再次确认。\n\n"+_resupply_quote_text(resupply_quote)
        build_detail.scroll_to_line(0)
        resupply_confirm_button.disabled=false
        return
    resupply_quote={}
    _perform_build_action("resupply_tools","",{})

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
    var at_workstation:=_is_at_build_workstation(snapshot)
    var at_artisan:=not at_workstation and level!=null and level.has_method("is_near_artisan") and bool(level.call("is_near_artisan"))
    var seal_page:=at_workstation and build_category=="契印"
    build_art.visible=seal_page
    build_art_caption.visible=seal_page
    build_emblem.position=Vector2(645,188 if seal_page else 290)
    build_heading.position=Vector2(710,188 if seal_page else 290)
    build_detail.position=Vector2(646,245 if seal_page else 340)
    build_detail.size=Vector2(418,280 if seal_page else 185)
    if not at_workstation and not at_artisan:
        for tab in build_tabs:tab.hide()
        for button in family_selector_buttons:button.hide()
        for button in build_slot_buttons:button.hide()
        clear_family_slot_button.hide()
        resupply_preview_button.hide()
        resupply_confirm_button.hide()
        build_summary.text="巡行配置 · 碎钱 %d · 钟龛可调整四类装备并查看补给报价" % int(level.currency_count)
        build_detail.text="离开钟龛时，行装只允许切换已配置的技能与战具。请前往钟龛调整装备；技能校习请找织线学徒、雨铸匠或蜂蜡商人。"
        var current_skill:=String(snapshot.get("skill","未配置"))
        var current_tool:=String(snapshot.get("tool","未配置"))
        var cycle_skill:=_button(build_grid,"切换技能 · 当前 %s" % current_skill,Vector2.ZERO,Vector2(563,58),func():_perform_build_action("cycle_skill",""))
        cycle_skill.custom_minimum_size=Vector2(563,64)
        cycle_skill.focus_mode=Control.FOCUS_ALL
        var cycle_tool:=_button(build_grid,"切换战具 · 当前 %s" % current_tool,Vector2.ZERO,Vector2(563,58),func():_perform_build_action("cycle_tool",""))
        cycle_tool.custom_minimum_size=Vector2(563,64)
        cycle_tool.focus_mode=Control.FOCUS_ALL
        var current_focus:=get_viewport().gui_get_focus_owner()
        if build_panel.visible and (current_focus==null or not build_panel.is_ancestor_of(current_focus)):cycle_skill.grab_focus()
        return
    if at_artisan and build_category!="强化":
        build_category="强化"
        build_selection=""
    for tab in build_tabs:tab.visible=not at_artisan or String(tab.get_meta("build_category",""))=="强化"
    if at_artisan:
        build_summary.text="工匠 · 碎钱 %d · 此处校习技能、改制战具；装备调整请回钟龛" % int(level.currency_count)
    else:
        build_summary.text="碎钱 %d · 饰品容量 %d / %d · %s" % [int(level.currency_count),int(snapshot.get("slots_used",0)),int(snapshot.get("slots_total",0)),_all_family_count_summary(snapshot)]
    var family_id:=_build_family_for_page()
    var slots:=_family_slots(snapshot,family_id) if not family_id.is_empty() else []
    var has_typed_layout: bool=snapshot.get("slot_layout",{}).has(family_id) if snapshot.get("slot_layout",{}) is Dictionary and not family_id.is_empty() else false
    _ensure_family_slot_buttons(snapshot,family_id,slots) if has_typed_layout else _ensure_family_slot_buttons(snapshot,"",[])
    for index in family_selector_buttons.size():
        var family_button: Button=family_selector_buttons[index]
        var accessory_id: String=["combat_accessory","travel_accessory"][index]
        var family_info:=_family_row(snapshot,accessory_id)
        family_button.text=String(family_info.get("name",accessory_id))
        family_button.visible=build_category=="铭饰"
        family_button.add_theme_stylebox_override("normal",_tab_style(build_family==accessory_id))
    clear_family_slot_button.visible=has_typed_layout and not slots.is_empty()
    if clear_family_slot_button.visible:
        var selected_slot: Dictionary=slots[build_assign_slot]
        clear_family_slot_button.disabled=not bool(selected_slot.get("unlocked",false)) or String(selected_slot.get("equipped_id","")).is_empty()
    var skill_family:=_family_row(snapshot,"thread_skill")
    var tool_family:=_family_row(snapshot,"tool")
    if not skill_family.is_empty():build_tabs[1].text=String(skill_family.get("name","技能"))
    if not tool_family.is_empty():build_tabs[2].text=String(tool_family.get("name","战具"))
    for index in build_slot_buttons.size():
        if not has_typed_layout:build_slot_buttons[index].visible=build_category in ["技能","战具"] and index<2
    resupply_preview_button.visible=build_category=="战具"
    resupply_confirm_button.visible=build_category=="战具"
    resupply_confirm_button.disabled=resupply_quote.is_empty() or not bool(resupply_quote.get("ok",false))
    var entries: Array=[]
    var action:=""
    match build_category:
        "契印":entries=snapshot.get("crests",[]);action="switch_crest"
        "技能":entries=_family_options(snapshot,"thread_skill");action="equip_family_slot"
        "战具":entries=_family_options(snapshot,"tool");action="equip_family_slot"
        "铭饰":entries=_family_options(snapshot,build_family);action="equip_family_slot"
        "强化":
            entries=snapshot.get("recipes",[])
            action="transact"
            # E04: beside an artisan, that artisan's own 改制 come first.
            var here:=String(level.call("near_artisan_id")) if at_artisan and level.has_method("near_artisan_id") else ""
            if not here.is_empty():
                var own: Array=[]
                var rest: Array=[]
                for recipe in entries:(own if String(recipe.get("artisan",""))==here else rest).append(recipe)
                entries=own+rest
        "构筑":
            for id in _loadout_names(snapshot):
                var loadouts: Array=snapshot.get("loadouts",[])
                entries.append({"id":id,"name":id,"description":"保存当前契印、技能、战具和铭饰。恢复时仍会检查解锁与槽位条件。","unlocked":true,"exists":loadouts.has(id)})
    for tab in build_tabs:tab.add_theme_stylebox_override("normal",_tab_style(String(tab.get_meta("build_category",""))==build_category))
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
        if entry.has("count"):
            text+=" · %d/%d 次" % [int(entry.count),int(entry.get("capacity",entry.count))]
            if int(entry.count)<=0:text+=" · 已用尽"
        if entry.get("branch","") is String and not String(entry.get("branch","")).is_empty():text+=" · 校习："+String(entry.get("branches",{}).get(String(entry.branch),{}).get("name",""))
        if String(entry.get("kind",""))=="skill_branch":
            if bool(entry.get("current",false)):text="◆ "+text+" · 当前方向"
            elif not _skill_practiced(String(entry.get("target",""))):text+=" · 需先练熟"
        elif String(entry.get("kind","")) in ["tool_capacity","slot_part","passive"]:
            if bool(entry.get("crafted",false)):text="◆ "+text+" · 已制作"
            else:
                text+=" · "+String(entry.get("artisan_name","工匠"))
                if not _has_patterns(entry):text+=" · 缺图样"
        var slot: Dictionary=slots[build_assign_slot] if has_typed_layout and build_assign_slot<slots.size() else {}
        var compatible: Array=slot.get("compatible",[]) if not slot.is_empty() else []
        var item_family:=String(entry.get("slot_family",family_id))
        var can_assign: bool=bool(entry.get("unlocked",true)) and (not has_typed_layout or (bool(slot.get("unlocked",false)) and item_family==family_id and (compatible.is_empty() or compatible.has(id))))
        if has_typed_layout and not compatible.is_empty() and not compatible.has(id):text="× "+text+" · 不兼容"
        var button:=_button(build_grid,text,Vector2.ZERO,Vector2(563,54),func():
            build_selection=id
            if not bool(entry.get("unlocked",true)):
                _show_build_detail(entry)
                return
            if has_typed_layout and not can_assign:
                _show_build_detail(entry)
                return
            if has_typed_layout:
                _perform_build_action("equip_family_slot",id,{"family":family_id,"slot":build_assign_slot})
            else:
                var fallback_action: String=action
                if build_category=="技能":fallback_action="select_skill"
                elif build_category=="战具":fallback_action="select_tool"
                elif build_category=="铭饰":fallback_action="equip_passive"
                _perform_build_action("restore_loadout" if build_category=="构筑" else fallback_action,id,build_assign_slot if build_category in ["技能","战具"] else -1))
        button.custom_minimum_size=Vector2(563,64)
        if seal_page:
            button.custom_minimum_size=Vector2(230,66)
            button.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
            button.set_meta("inscription_tab",true)
        button.alignment=HORIZONTAL_ALIGNMENT_LEFT
        button.add_theme_font_size_override("font_size",17)
        button.set_meta("build_id",id)
        button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
        button.disabled=not can_assign and build_category in ["技能","战具","铭饰"]
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
        if bool(entry.get("selected",false)):button.add_theme_stylebox_override("normal",_style(Color(.2,.065,.055,.2),RED,2))
        if first==null or id==build_selection:first=button
        if build_category=="构筑":
            var name_value:=id
            var preview:=_loadout_quote(id)
            button.disabled=not bool(preview.get("can_restore",false))
            button.tooltip_text=String(preview.get("reason","可在钟龛恢复"))
            var save:=_button(build_grid,("覆盖" if bool(entry.get("exists",false)) else "保存为")+"「%s」" % id,Vector2.ZERO,Vector2(563,36),func():_request_loadout_change("save_loadout",name_value))
            save.custom_minimum_size=Vector2(563,36)
            save.set_meta("build_id",id)
            save.focus_entered.connect(func():
                build_selection=id
                _show_build_detail(entry))
            save.mouse_entered.connect(func():_show_build_detail(entry))
            if first==button and button.disabled:first=save
            button.text="恢复「%s」%s" % [id,"" if bool(entry.get("exists",false)) else " · 尚未保存"]
            if bool(entry.get("exists",false)):
                var remove:=_button(build_grid,"删除「%s」" % id,Vector2.ZERO,Vector2(563,30),func():_request_loadout_change("delete_loadout",name_value))
                remove.custom_minimum_size=Vector2(563,30)
                remove.set_meta("loadout_delete",id)
    if first!=null:
        var current_focus:=get_viewport().gui_get_focus_owner()
        if build_panel.visible and (current_focus==null or not build_panel.is_ancestor_of(current_focus)):first.grab_focus()
        for value in entries:
            if String(value.get("id",value.get("name","")))==build_selection:
                _show_build_detail(value)
                return
        _show_build_detail(entries[0])

func _loadout_names(snapshot: Dictionary) -> Array[String]:
    var result: Array[String]=[]
    for name in snapshot.get("loadouts",[]):
        if name is String and not result.has(name):result.append(name)
    for index in 8:
        var name:="巡礼方案 %d" % (index+1)
        if result.size()<8 and not result.has(name):result.append(name)
    result.sort()
    return result

func _request_loadout_change(action: String, name: String) -> void:
    if not build_panel.is_visible_in_tree() or build_category!="构筑":return
    if not _is_at_build_workstation(_build_snapshot()):return
    var exists: bool=_build_snapshot().get("loadouts",[]).has(name)
    if action=="save_loadout" and not exists:
        _perform_build_action(action,name)
        return
    if not exists or action not in ["save_loadout","delete_loadout"]:return
    if loadout_dialog==null:
        loadout_dialog=ConfirmationDialog.new()
        add_child(loadout_dialog)
        loadout_dialog.confirmed.connect(_confirm_loadout_change)
        loadout_dialog.canceled.connect(func():pending_loadout_action="";pending_loadout_name="")
    pending_loadout_action=action
    pending_loadout_name=name
    loadout_dialog.title="覆盖构筑方案" if action=="save_loadout" else "删除构筑方案"
    loadout_dialog.dialog_text=("用当前装备覆盖「%s」？旧方案将被替换。" if action=="save_loadout" else "删除「%s」？当前装备、资源和其它方案保留。") % name
    loadout_dialog.get_ok_button().text="确认覆盖" if action=="save_loadout" else "确认删除"
    loadout_dialog.get_cancel_button().text="保留原方案"
    loadout_dialog.popup_centered(Vector2i(500,160))
    loadout_dialog.get_cancel_button().grab_focus()

func _confirm_loadout_change() -> void:
    var action:=pending_loadout_action
    var name:=pending_loadout_name
    pending_loadout_action=""
    pending_loadout_name=""
    if not build_panel.is_visible_in_tree() or build_category!="构筑" or not _is_at_build_workstation(_build_snapshot()):return
    if action in ["save_loadout","delete_loadout"]:_perform_build_action(action,name)

func _entry_equipped_slots(snapshot: Dictionary, id: String) -> String:
    var family_id:=_build_family_for_page()
    if family_id.is_empty():return ""
    var layout: Variant=snapshot.get("slot_layout",{})
    var family_slots:=_family_slots(snapshot,family_id)
    if layout is Dictionary and layout.has(family_id):
        var active_positions: Array[String]=[]
        var dormant_positions: Array[String]=[]
        for slot_value in family_slots:
            var slot: Dictionary=slot_value
            if String(slot.get("equipped_id",""))!=id:continue
            var position:=str(int(slot.get("index",0))+1)
            if _slot_dormancy_reason(slot,id).is_empty():active_positions.append(position)
            else:dormant_positions.append(position)
        var result:="/".join(active_positions)
        if not dormant_positions.is_empty():result+=(" · " if not result.is_empty() else "")+"休眠 "+"/".join(dormant_positions)
        return result
    var equipped: Array=[]
    for slot_value in family_slots:
        var slot: Dictionary=slot_value
        if String(slot.get("equipped_id",""))==id:equipped.append(int(slot.get("index",equipped.size())))
    if equipped.is_empty():
        var system: Variant=level.call("get_build_system") if level.has_method("get_build_system") else null
        if system!=null:
            if family_id=="thread_skill":equipped=system.state.get("skills",[])
            elif family_id=="tool":equipped=system.state.get("tools",[])
            else:equipped=system.state.get("passives",[])
    var slots: Array[String]=[]
    if equipped.size()>0 and equipped[0] is String:
        for index in equipped.size():
            if String(equipped[index])==id:slots.append(str(index+1))
    else:
        for index in equipped:slots.append(str(int(index)+1))
    return "/".join(slots)

func _loadout_quote(name: String) -> Dictionary:
    var system: Variant=level.call("get_build_system")
    if system!=null and system.has_method("preview_loadout"):
        return system.preview_loadout(name,_is_at_build_workstation(_build_snapshot()))
    return {"can_restore":false,"reason":"方案预览尚未就绪"}

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
    if build_art!=null and entry.has("slots"):
        build_art.seal_id=String(entry.get("id","crimson"))
        build_art.queue_redraw()
    var entry_name:=String(entry.get("name",entry.get("id","")))
    build_heading.text=entry_name
    var icon_path:="res://assets/ui/seals/%s.svg" % String(entry.get("id",""))
    build_emblem.texture=load(icon_path) if ResourceLoader.exists(icon_path) else null
    var lines: Array[String]=[String(entry.get("description",""))]
    var snapshot:=_build_snapshot()
    var family_id:=_build_family_for_page()
    if not family_id.is_empty() and snapshot.get("slot_layout",{}) is Dictionary and snapshot.slot_layout.get(family_id) is Array:
        var slots: Array=snapshot.slot_layout[family_id]
        var family_info:=_family_row(snapshot,family_id)
        var family_names: Dictionary={"tool":"战具","combat_accessory":"战斗饰件","travel_accessory":"行旅饰件","thread_skill":"线技"}
        var family_name:=String(family_info.get("name",family_names.get(family_id,family_id)))
        lines.append("\n装备类别：%s" % family_name)
        lines.append(_family_count_summary(snapshot,family_id,slots))
        if build_assign_slot<slots.size():
            var target_slot: Dictionary=slots[build_assign_slot]
            var equipped_id:=String(target_slot.get("equipped_id",""))
            var current_entry:=_family_entry(snapshot,family_id,equipped_id)
            lines.append("\n目标位置：%d · %s" % [build_assign_slot+1,"已解锁" if bool(target_slot.get("unlocked",false)) else "未解锁"])
            lines.append("当前装备：%s" % String(current_entry.get("name",equipped_id if not equipped_id.is_empty() else "空")))
            if not bool(target_slot.get("unlocked",false)):
                lines.append("该槽位尚未解锁，无法装备。")
                if not bool(target_slot.get("part_ready",true)):
                    var part_entry: Dictionary={}
                    for recipe in snapshot.get("recipes",[]):
                        if String(recipe.get("id",""))==String(target_slot.get("part_recipe","")):part_entry=recipe
                    lines.append("◇ 需要工匠制作「%s」（%s）。" % [String(part_entry.get("name","承力扣")),String(part_entry.get("artisan_name","工匠"))])
            var compatible: Array=target_slot.get("compatible",[])
            if not compatible.is_empty():lines.append("兼容条目："+"、".join(_family_option_names(snapshot,family_id,compatible)))
            if not compatible.is_empty() and not compatible.has(String(entry.get("id",""))):
                lines.append("此条目与目标位置不兼容，装备请求会被拒绝。")
            if entry.has("cost"):
                var used:=int(snapshot.get("slots_used",0))
                var total:=int(snapshot.get("slots_total",0))
                var old_cost:=int(current_entry.get("cost",0))
                var projected:=used-old_cost+int(entry.cost)
                lines.append("容量比较：当前 %d / %d · 替换后 %d / %d" % [used,total,projected,total])
    if build_category=="构筑":
        var system: Variant=level.call("get_build_system")
        lines.append("\n当前整体配置\n"+_loadout_preview(system.state,system))
        var saved_value: Variant=system.state.loadouts.get(String(entry.get("id","")),{})
        var saved_build: Dictionary=saved_value if saved_value is Dictionary else {}
        if not saved_build.is_empty():lines.append("\n已保存配置\n"+_loadout_preview(saved_build,system))
        var preview:=_loadout_quote(String(entry.get("id","")))
        lines.append("\n恢复条件："+("可以恢复 · 不花碎钱或材料" if bool(preview.get("can_restore",false)) else String(preview.get("reason","当前不可恢复"))))
        var projected: Dictionary=preview.get("profile",{})
        if not projected.is_empty():
            lines.append("生命上限：%d → %d" % [int(level.player.max_hp),int(projected.get("max_hp",level.player.max_hp))])
            lines.append("绯线上限：%d → %d" % [int(level.player.max_energy),int(projected.get("max_energy",level.player.max_energy))])
            lines.append("陷阱触发宽高：%d%% → %d%%" % [int(round(float(level.player.build_profile.get("hazard_trigger_mult",1.0))*100)),int(round(float(projected.get("hazard_trigger_mult",1.0))*100))])
        lines.append("恢复不补充生命、绯线或次数，不清空冷却；超出新上限的生命与绯线会截断。")
    if entry.has("mechanism_unlocked") and not bool(entry.mechanism_unlocked):lines.append("\n◇ 专属机制尚未修复：基础战斗与永久探索能力仍可使用，完成来源委托后启用。")
    if entry.has("slots"):
        for crest in snapshot.get("crests",[]):
            if String(crest.get("id",""))!=String(snapshot.get("crest","")):continue
            lines.append("\n契印基础值 · 当前 → 所选")
            for pair in [["slots","铭饰槽"],["max_hp","生命"],["max_energy","绯线容量"],["heal_cost","治疗耗能"],["heal_amount","治疗恢复"]]:
                lines.append("%s：%s → %s" % [pair[1],str(crest.get(pair[0],0)),str(entry.get(pair[0],0))])
            lines.append("治疗时间：%.2f → %.2f 秒" % [float(crest.get("heal_duration",0)),float(entry.get("heal_duration",0))])
            lines.append("铭饰效果在装备后合并计算。")
    if String(entry.get("kind",""))=="skill_branch" and entry.has("target"):
        for skill in snapshot.get("skills",[]):
            if String(skill.get("id",""))==String(entry.target):
                lines.append_array(_skill_branch_lines(skill,entry))
    if String(entry.get("kind","")) in ["tool_capacity","slot_part","passive"]:lines.append_array(_craft_lines(entry,snapshot))
    if not bool(entry.get("unlocked",true)):
        var unlock_hint:=String(entry.get("unlock_hint","继续探索、完成委托或挑战后获得。"))
        if not String(entry.get("unlock_item","")).is_empty():unlock_hint="需要取得「%s」。" % level._item_display_name(String(entry.unlock_item))
        lines.append("\n尚未解锁 · "+unlock_hint)
    for field in [["source","来源"],["attack_description","攻击"],["mechanism","专属机制"],["heal_effect","治疗完成"],["risk","动作风险与代价"],["synergy","契印协同"],["practice","练习"],["encounter","适合遭遇"]]:
        if entry.has(field[0]):lines.append("\n%s：%s" % [field[1],str(entry[field[0]])])
    if not family_id.is_empty():lines.append("\n确认后装备到所选位置 %d；上方按钮选择位置。" % (build_assign_slot+1))
    if build_category=="战具":lines.append("钟龛补给需碎钱与材料，可先查看报价；换装与恢复构筑不会补充次数。")
    if entry.has("cost"):
        var used:=int(snapshot.get("slots_used",0))
        var total:=int(snapshot.get("slots_total",0))
        if not bool(entry.get("selected",false)) and used+int(entry.cost)>total:lines.append("◇ 容量不足：需要 %d，剩余 %d。" % [int(entry.cost),maxi(0,total-used)])
    if entry.has("energy_cost"):lines.append("\n消耗绯线：%d" % int(entry.energy_cost))
    if entry.has("cooldown"):lines.append("冷却：%.1f 秒" % float(entry.cooldown))
    if entry.has("cost"):lines.append("铭饰容量消耗：%d；再次确认可卸下。" % int(entry.cost))
    if entry.has("count"):lines.append("剩余携带：%d / %d" % [int(entry.count),int(entry.get("capacity",entry.count))])
    if entry.has("count") and int(entry.count)<=0:lines.append("\n当前携带量为零，不能使用此战具；可在钟龛先查看补给报价，再单独确认购买。")
    elif entry.has("count") and int(entry.count)<int(entry.get("capacity",entry.count)):lines.append("\n携带量不足上限；可在钟龛购买部分补给。")
    if entry.has("currency"):lines.append("\n制作费用：%d 碎钱" % int(entry.currency))
    if entry.has("materials"):
        var materials: Dictionary=entry.materials
        for material in materials:lines.append("材料 %s：需要 %d / 持有 %d" % [level._item_display_name(String(material)),int(materials[material]),int(level.inventory_counts.get(material,0))])
    if bool(entry.get("selected",false)):lines.append("\n当前已装备。")
    build_detail.text="\n".join(lines)

func _perform_build_action(action: String, id: String, extra: Variant = -1) -> void:
    if level==null or not level.has_method("perform_build_action"):return
    var result: Variant=level.call("perform_build_action",action,id,extra)
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

func _show_journey_history() -> void:
    if level == null or not level.has_method("get_journey_history"):return
    if journey_history_dialog == null:
        journey_history_dialog=AcceptDialog.new()
        journey_history_dialog.title="当前存档槽 · 旧旅途"
        journey_history_dialog.ok_button_text="返回设置"
        journey_history_dialog.min_size=Vector2i(760,480)
        add_child(journey_history_dialog)
        journey_history_text=RichTextLabel.new()
        journey_history_text.custom_minimum_size=Vector2(720,390)
        journey_history_text.bbcode_enabled=false
        journey_history_text.scroll_active=true
        journey_history_text.add_theme_font_size_override("normal_font_size",17)
        journey_history_dialog.add_child(journey_history_text)
        journey_history_dialog.confirmed.connect(_journey_history_closed)
        journey_history_dialog.canceled.connect(_journey_history_closed)
    var history: Dictionary=level.get_journey_history()
    var lines: Array[String]=["只读浏览；关闭后继续当前旅途。", ""]
    for row in history.entries:
        var date:=Time.get_datetime_string_from_unix_time(int(row.modified)).replace("T"," ")+" UTC"
        lines.append("归档 "+date+" · "+String(row.file))
        if not bool(row.valid):
            lines.append("无法读取此记录："+String(row.error)+"；文件仍保留。")
        else:
            lines.append("停留：%s · %d 区 / %d 房间 · 守门者 %d · 碎钱 %d" % [String(row.region_name),int(row.regions),int(row.rooms),int(row.bosses),int(row.currency)])
            if not String(row.ending).is_empty():lines.append("结局："+String({"ending_a":"重鸣","ending_b":"断冠","ending_c":"改写"}.get(row.ending,row.ending)))
        lines.append("")
    if int(history.total)==0:lines.append("还没有旧旅途。另起新旅途时，当前槽的旧进度会另存保留。")
    if int(history.total)>int(history.shown):lines.append("显示最近 %d / %d 份；更早的记录仍保留在存档目录。" % [int(history.shown),int(history.total)])
    journey_history_text.text="\n".join(lines)
    journey_history_text.scroll_to_line(0)
    journey_history_dialog.popup_centered()

func _journey_history_closed() -> void:
    journey_history_close_frame=Engine.get_process_frames()
    journey_history_button.grab_focus()

func is_browsing_journey_history() -> bool:
    return (journey_history_dialog != null and journey_history_dialog.visible) or journey_history_close_frame==Engine.get_process_frames()

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
    if level==null or not construction_complete:return
    _refresh_quick_action_bindings()
    if dialogue.visible:
        dialogue_hint.text=_dialogue_binding_hint()
        dialogue_hint.tooltip_text=dialogue_hint.text
    modal_shade.visible=not String(level.active_overlay).is_empty()
    hud_card.visible=not modal_shade.visible
    location_rule.visible=not modal_shade.visible
    location.visible=not modal_shade.visible
    currency.visible=not modal_shade.visible
    currency_emblem.visible=not modal_shade.visible
    mechanism_status.visible=not modal_shade.visible
    for card in tactical_cards:card.visible=not modal_shade.visible
    for button in quick_actions:button.visible=not modal_shade.visible
    if applied_player!=level.player:_apply_accessibility()
    if last_overlay!=String(level.active_overlay):
        last_overlay=String(level.active_overlay)
        if last_overlay=="build":
            refresh_build()
            _focus_overlay(last_overlay)
        elif last_overlay=="settings":
            _refresh_save_slots()
            _focus_overlay(last_overlay)
        elif last_overlay in ["backpack","map","dialogue","build"]:_focus_overlay(last_overlay)
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
        hearts.text="%d / %d" % [hp,int(player.max_hp)]
        if health_glyphs.hp!=maxi(0,hp) or health_glyphs.maximum!=maxi(1,int(player.max_hp)):
            health_glyphs.hp=maxi(0,hp)
            health_glyphs.maximum=maxi(1,int(player.max_hp))
            health_glyphs.queue_redraw()
        hearts.modulate=RED if hp<=1 else IVORY
        thread_bar.max_value=player.max_energy
        thread_bar.value=player.energy
        energy_status.text="%d / %d" % [int(player.energy),int(player.max_energy)]
        _refresh_combat_status(player)
    tutorial_hint.visible=bool(accessibility.get("tutorial_hints",true)) and level.active_overlay==""
    if tutorial_hint.visible:
        tutorial_hint.text="%s 跳跃   /   %s 普攻   /   %s 治疗" % [_short_binding("jump"),_short_binding("attack"),_short_binding("heal")]
    currency.text=str(level.currency_count)
    var room: Dictionary=level._map_room_by_id(level.current_room_id)
    location.text=String(room.get("name",room.get("label",level.config.get("chapter_name","绯线巡礼"))))
    toast_age+=delta
    if toast.text!=last_toast:
        last_toast=toast.text
        toast_age=0
    toast.visible=not toast.text.is_empty()
    toast.modulate.a=clampf(5.5-toast_age,0,1)
    # Interaction is shown at the object by WorldWayfinding.
    prompt.visible=false
    prompt.text=""
    var actor: Node=level.boss_actor if is_instance_valid(level.boss_actor) else null
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
        if bag_grid.get_child_count()>0:
            journal_selection=wrapi(journal_selection+delta,0,bag_grid.get_child_count())
            journal_memory[journal_filter]=String(bag_grid.get_child(journal_selection).get_meta("journal_key",""))
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
    return PROMPT_BINDINGS.binding_label(event)

func _short_binding(action: String) -> String:
    return PROMPT_BINDINGS.action_label(action)

func _refresh_quick_action_bindings() -> void:
    var actions := ["", "inventory", "map", "audio_settings"]
    var titles := ["构筑", "行囊", "地图", "设置"]
    for index in mini(quick_actions.size(), actions.size()):
        var hint := ("手柄 L3" if PROMPT_BINDINGS.controller_device >= 0 else "B") if index == 0 else _short_binding(actions[index])
        quick_actions[index].text = hint + " " + titles[index]
        quick_actions[index].text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        quick_actions[index].tooltip_text = quick_actions[index].text

func _dialogue_binding_hint() -> String:
    var action := "继续查看 / 记入旅记" if is_instance_valid(dialogue_area) and String(dialogue_area.get_meta("kind",""))=="history" else "继续"
    return "%s %s\n%s 离开" % [_short_binding("interact"),action,_short_binding("close_overlay")]

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
            var dormant_reason:=_family_slot_dormancy_reason(snapshot,"thread_skill",slot,id)
            var status:=("休眠："+dormant_reason) if not dormant_reason.is_empty() else "%.1fs" % remaining if remaining>0 else "就绪"
            skill_lines.append("%s%d %s %s" % ["▶" if slot==int(build_state.get("active_skill_slot",0)) and dormant_reason.is_empty() else "○",slot+1,String(skill.get("name",id)),status])
    for slot in equipped_tools.size():
        var id:=String(equipped_tools[slot])
        if id.is_empty():tool_lines.append("○%d 未携带战具" % (slot+1));continue
        for tool in snapshot.get("tools",[]):
            if String(tool.get("id",""))==id:
                var dormant_reason:=_family_slot_dormancy_reason(snapshot,"tool",slot,id)
                var status:="休眠："+dormant_reason if not dormant_reason.is_empty() else "%d次" % int(tool.get("count",0))
                tool_lines.append("%s%d %s %s" % ["▶" if slot==int(build_state.get("active_tool_slot",0)) and dormant_reason.is_empty() else "○",slot+1,String(tool.get("name",id)),status])
    combat_status.text=" · ".join(skill_lines)+"\n"+" · ".join(tool_lines)
    if player.has_method("get_seal_mechanism_snapshot"):
        var mechanism: Dictionary=player.call("get_seal_mechanism_snapshot")
        var maximum:=int(mechanism.get("max_stacks",mechanism.get("max",3)))
        var amount:=int(mechanism.get("stacks",mechanism.get("value",0)))
        mechanism_status.text=String(mechanism.get("label",mechanism.get("name","契印")))+"  "+("%d / %d" % [amount,maximum] if maximum>0 else "%d 个目标" % amount)
        if not bool(mechanism.get("unlocked",true)):
            mechanism_status.text=String(mechanism.get("label","契印"))+" · 尚未修复"
        elif float(mechanism.get("remaining",0.0))>0.0 and amount>0:
            mechanism_status.text+=" · %.1fs" % float(mechanism.remaining)
        if float(mechanism.get("heal_remaining",0.0))>0.0:
            mechanism_status.text+=" · %s %.1fs" % [String(mechanism.get("heal_effect","治疗效果")),float(mechanism.heal_remaining)]
        combat_status.text+="\n"+mechanism_status.text
    var heal: Dictionary=state.get("heal",{})
    healing_status.visible=not heal.is_empty() and level.active_overlay==""
    if not heal.is_empty():
        var reason := String(heal.get("reason","busy"))
        var status: String = {"ready":"可用 +%d" % int(heal.get("amount",1)),"channeling":"治疗中 %.1fs" % float(heal.get("remaining",0.0)),
            "dead":"等待复生","busy":"动作中","full_health":"生命已满","energy":"缺 %d 绯线" % int(heal.get("missing_energy",0)),
            "airborne":"落地后可用","moving":"停稳后可用","cooldown":"冷却 %.1fs" % float(heal.get("cooldown",0.0))}.get(reason,"动作中")
        healing_status.text="[%s] 治疗 %d · %s" % [_short_binding("heal"),int(heal.get("cost",0)),status]
        healing_status.tooltip_text="消耗 %d 绯线 · 恢复 %d 生命 · %.2f秒\n中断损失 %d 绯线；移动、跳跃、冲刺或受击会中断。" % [int(heal.get("cost",0)),int(heal.get("amount",0)),float(heal.get("duration",0.0)),int(heal.get("interrupt_loss",0))]
        healing_status.add_theme_color_override("font_color",GOLD if bool(heal.get("available",false)) else IVORY if reason=="channeling" else MUTED)
    healing_bar.visible=bool(state.get("heal_active",false)) and level.active_overlay==""
    healing_bar.value=clampf(float(state.get("heal_progress",0)),0,1)
    if healing_bar.visible:combat_status.text+=" · 治疗中"
    combat_status.visible=false
    _refresh_tactical_cards(snapshot,build_state,system)


func _refresh_journal() -> void:
    bag_grid.columns=2
    bag_pin.disabled=true
    bag_name.text="六区旅途记录"
    bag_category_label.text="旅途记录"
    bag_icon.texture=ART.item("moss_lens")
    if journal_reading_key.is_empty():bag_description.text="按分类查看主线、委托、证词、已击败敌人与结局；只显示旅途中已知的内容。"
    for filter_id in journal_filter_buttons:journal_filter_buttons[filter_id].add_theme_stylebox_override("normal",_tab_style(filter_id==journal_filter))
    for tab in bag_tabs:tab.add_theme_stylebox_override("normal",_tab_style(tab.text==bag_category))
    if not bool(level.get("world_mode")):
        bag_description.text="完整互联世界旅途中会记录跨区委托与六区证词。"
        return
    var narrative: Variant=level.get("world_narrative")
    if narrative==null:return
    var guide_bindings: Dictionary={}
    for action in ["jump","attack","heal","skill_1","interact","map"]:guide_bindings[action]=_short_binding(action)
    var heal: Dictionary={}
    if is_instance_valid(level.player) and level.player.has_method("get_combat_ui_state"):heal=level.player.get_combat_ui_state().get("heal",{})
    var recall:=preload("res://scripts/death_recall.gd")
    var records: Array=preload("res://scripts/field_guide.gd").records(heal,guide_bindings,recall.bosses_defeated(level.story_flags)>=recall.REQUIRED_BOSSES)
    records.append_array(preload("res://scripts/scene_history.gd").records(level.story_flags))
    records.append_array(preload("res://scripts/protagonist_voice.gd").records(level.inventory_counts))
    var progress: Dictionary={}
    if narrative.has_method("evaluate_progress"):
        progress=narrative.call("evaluate_progress",level.inventory_counts,level.story_flags)
    if not progress.is_empty():
        # N05: the main line leads the journal, so its conditions are always traceable.
        if progress.get("main_line") is Dictionary and not progress.main_line.is_empty():
            var main_entry: Dictionary=progress.main_line.duplicate(true)
            main_entry["record_kind"]="main"
            records.push_front(main_entry)
        for value in progress.get("quests",[]):
            var entry: Dictionary=value.duplicate(true)
            entry["record_kind"]="quest"
            records.append(entry)
        for value in progress.get("known_entries",progress.get("entries",[])):
            var entry: Dictionary=value.duplicate(true)
            entry["record_kind"]="evidence"
            records.append(entry)
        # The canonical evaluator returns no ending records before the final
        # choice is encountered; keep that withholding intact in the journal.
        for value in progress.get("endings",[]):
            var entry: Dictionary=value.duplicate(true)
            entry["record_kind"]="ending"
            records.append(entry)
    else:
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
    records.append_array(preload("res://scripts/enemy_journal.gd").records(level.story_flags))
    if journal_filter!="all":records=records.filter(func(entry):return String(entry.get("record_kind",""))==journal_filter)
    var remembered:=String(journal_memory.get(journal_filter,""))
    for index in records.size():
        if String(records[index].get("record_kind",""))+":"+String(records[index].get("id",""))==remembered:journal_selection=index
    journal_selection=clampi(journal_selection,0,maxi(0,records.size()-1))
    if records.is_empty():
        journal_reading_key=""
        journal_restore_pending=false
        bag_name.text="尚无敌人记录" if journal_filter=="enemy" else "这一分类暂无记录"
        bag_description.text="击败后会留下战斗笔记；未交战的敌人不会提前列出。" if journal_filter=="enemy" else "继续探索并与人物交谈，已知的记录会保存在这里。"
        if journal_filter=="voice":
            bag_name.text="尚无自述"
            bag_description.text="获得新的永久能力后，这里会留下一句旅途自述。"
    var selected_button: Button
    for record_index in records.size():
        var value: Variant=records[record_index]
        var entry: Dictionary=value
        var title:=String(entry.get("title",entry.get("id","")))
        var status:="已发现" if bool(entry.get("acquired",false)) else "待发现"
        if entry.record_kind=="quest":status="已完成" if String(entry.get("status",""))=="complete" else "进行中"
        elif entry.record_kind=="main":status="主线"
        elif entry.record_kind=="guide":status="可回看"
        elif entry.record_kind=="voice":status="旅途自述"
        elif entry.record_kind=="enemy":status="已击败"
        elif entry.record_kind=="ending":status=_ending_status_label(entry)
        var button:=_button(bag_grid,title+"\n"+status,Vector2.ZERO,Vector2(309,74),func():_show_journal_record(entry))
        button.custom_minimum_size=Vector2(309,74)
        button.tooltip_text=title+" · "+status
        var record_key:=String(entry.record_kind)+":"+String(entry.get("id",""))
        button.set_meta("journal_key",record_key)
        button.focus_entered.connect(func():
            journal_selection=record_index
            journal_memory[journal_filter]=record_key
            _show_journal_record(entry))
        button.mouse_entered.connect(func():_show_journal_record(entry))
        if record_index==journal_selection:selected_button=button
    if not records.is_empty():
        journal_selection=clampi(journal_selection,0,records.size()-1)
        _show_journal_record(records[journal_selection])
        if selected_button!=null and bag.visible:selected_button.grab_focus()

func _show_journal_record(entry: Dictionary) -> void:
    _remember_journal_scroll()
    bag_name.text=String(entry.get("title",entry.get("id","")))
    var lines: Array[String]=[]
    if bool(entry.get("history_note",false)):
        bag_category_label.text="环境见闻 · 已观察"
        lines.append(String(entry.get("text","")))
        lines.append("\n地点："+String(entry.get("place","")))
        lines.append("\n环境见闻保留了观察，不计入六区原始证词。")
    elif String(entry.get("record_kind",""))=="voice":
        bag_category_label.text="自述 · 获得能力之后"
        lines.append(String(entry.get("description","")))
    elif String(entry.get("record_kind",""))=="guide":
        bag_category_label.text="操作手册 · 当前规则"
        lines.append(String(entry.get("description","")))
    elif String(entry.get("record_kind",""))=="ending":
        var chosen:=bool(entry.get("chosen",false))
        var ready:=bool(entry.get("available",false))
        bag_category_label.text="结局选择 · "+_ending_status_label(entry)
        if not String(entry.get("message","")).is_empty():lines.append(String(entry.message))
        for requirement in entry.get("known_missing",[]):
            var clue: Dictionary=requirement
            var clue_line:=String(clue.get("label","已知线索"))
            if not String(clue.get("region","")).is_empty():clue_line+=" · "+String(clue.region)
            lines.append("○ "+clue_line)
            if not String(clue.get("hint","")).is_empty():lines.append("  "+String(clue.hint))
        var hidden_count:=int(entry.get("hidden_missing_count",0))
        if hidden_count>0:lines.append("\n另有 %d 项线索尚未在旅记中确认。" % hidden_count)
        if ready or chosen:
            var consequences: Variant=entry.get("consequences",{})
            if consequences is Dictionary and not consequences.is_empty():
                lines.append("\n结局影响")
                for consequence in entry.get("consequence_rows",[]):
                    lines.append("· %s：%s" % [String(consequence.get("title","六城")),String(consequence.get("text",""))])
        if chosen and not entry.get("aftermath_rows",[]).is_empty():
            lines.append("\n各地变化")
            for row in entry.get("aftermath_rows",[]):
                if bool(row.get("seen",false)):lines.append("● %s：%s" % [String(row.get("region_name","")),String(row.get("text",""))])
                else:lines.append("○ %s：回到那里的钟龛看看。" % String(row.get("region_name","")))
    elif String(entry.get("record_kind",""))=="enemy":
        bag_category_label.text="敌人 · 已击败"
        lines.append(String(entry.get("description","")))
        lines.append("\n战斗笔记按已击败种类保存；休息后敌人复现不会重复添加。")
    elif String(entry.get("record_kind",""))=="main":
        bag_category_label.text="主线"
        lines.append(String(entry.get("goal","")))
        for step in entry.get("steps",[]):lines.append(("● " if bool(step.get("complete",false)) else "○ ")+String(step.get("label","")))
        lines.append("\n"+String(entry.get("guidance","")))
    elif String(entry.get("record_kind",""))=="quest":
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
        if acquired:
            var witness: Dictionary=entry.get("scene_witness",{})
            if not witness.is_empty():
                lines.append("\n场景印证 · "+String(witness.get("title","遗留痕迹")))
                lines.append(String(witness.get("text","")))
            for connection in entry.get("connections",[]):
                lines.append("\n互证："+String(connection))
    var text:="\n".join(lines)
    var key:=String(entry.get("record_kind",""))+":"+String(entry.get("id",""))
    if journal_reading_key==key and bag_description.text==text:return
    bag_description.text=text
    journal_reading_key=key if bag.is_visible_in_tree() else ""
    journal_reading_text=text
    journal_restore_pending=not journal_reading_key.is_empty()
    call_deferred("_restore_journal_scroll",key,text,journal_reading.resume(key,text))

func _remember_journal_scroll(force: bool=false) -> void:
    if bag_description==null or journal_reading_key.is_empty() or journal_restore_pending:return
    if force or bag.is_visible_in_tree():journal_reading.capture(journal_reading_key,journal_reading_text,bag_description.get_v_scroll_bar().value)

func _journal_bag_visibility_changed() -> void:
    if not bag.is_visible_in_tree():
        _remember_journal_scroll(true)
        journal_reading_key=""
        journal_restore_pending=false

func _restore_journal_scroll(key: String, text: String, offset: float) -> void:
    await get_tree().process_frame
    if is_inside_tree() and bag.is_visible_in_tree() and journal_reading_key==key and bag_description.text==text:
        var bar:=bag_description.get_v_scroll_bar()
        bar.value=clampf(offset,bar.min_value,maxf(bar.min_value,bar.max_value-bar.page))
        journal_restore_pending=false

func _scroll_journal(step: int) -> void:
    if bag_description==null:return
    var bar:=bag_description.get_v_scroll_bar()
    var maximum:=maxf(bar.min_value,bar.max_value-bar.page)
    if absi(step)==2:bar.value=bar.min_value if step<0 else maximum
    else:bar.value=clampf(bar.value+step*maxf(64.0,bag_description.size.y*0.8),bar.min_value,maximum)
    _remember_journal_scroll()

func _ending_status_label(entry: Dictionary) -> String:
    if bool(entry.get("chosen",false)):return "已选择"
    if bool(entry.get("available",false)):return "可以选择"
    if String(entry.get("status",""))=="closed":return "已关闭"
    return "准备中"

func _skill_readiness(item: Dictionary, remaining: float, active: bool) -> Dictionary:
    var cost := maxi(0, int(item.get("energy_cost", 0)))
    var energy := int(level.player.energy) if level != null and is_instance_valid(level.player) else 0
    var detail := "需要 %d 绯线；当前 %d。" % [cost, energy]
    if remaining > 0.0:
        return {"text":"%.1fs" % remaining, "available":false, "detail":"冷却中。" + detail}
    if level != null and is_instance_valid(level.player) and level.player.has_method("get_cast_readiness"):
        var action: Dictionary = level.player.get_cast_readiness(String(item.get("id","")))
        if not bool(action.available):return {"text":action.text,"available":false,"detail":String(action.detail)+detail}
    if energy < cost:
        return {"text":"缺%d" % (cost - energy), "available":false, "detail":"绯线不足。" + detail}
    return {"text":_short_binding("skill_1") if active else "待切换", "available":true, "detail":detail}

func _refresh_tactical_cards(snapshot: Dictionary, build_state: Dictionary, system: Variant) -> void:
    var crest_id:=String(build_state.get("crest","crimson"))
    if hud_crest.get_meta("crest_id","")!=crest_id:
        hud_crest.set_meta("crest_id",crest_id)
        var crest_path:="res://assets/ui/seals/%s.svg" % crest_id
        hud_crest.texture=load(crest_path) if ResourceLoader.exists(crest_path) else null
    for index in tactical_cards.size():
        var is_skill:=index<2
        var slot:=index%2
        var equipped: Array=build_state.get("skills" if is_skill else "tools",[])
        var id:=String(equipped[slot]) if slot<equipped.size() else ""
        var family_id:="thread_skill" if is_skill else "tool"
        var dormant_reason:=_family_slot_dormancy_reason(snapshot,family_id,slot,id)
        var path:="res://assets/ui/seals/%s.svg" % id
        if tactical_icons[index].get_meta("asset_id","")!=id:
            tactical_icons[index].set_meta("asset_id",id)
            tactical_icons[index].texture=load(path) if not id.is_empty() and ResourceLoader.exists(path) else null
        tactical_names[index].text="未装备" if is_skill else "未携带"
        tactical_values[index].text="—"
        var active:=slot==int(build_state.get("active_skill_slot" if is_skill else "active_tool_slot",0)) and dormant_reason.is_empty()
        var signature:=id+str(active)+dormant_reason
        if tactical_signatures[index]!=signature:
            tactical_signatures[index]=signature
            tactical_cards[index].set_meta("inscription_active",active)
            tactical_cards[index].get_child(0).queue_redraw()
            var card_style:=_style(Color(.025,.065,.07,.94),RED if active else Color("65583f"))
            card_style.border_width_bottom=2 if active else 1
            tactical_cards[index].add_theme_stylebox_override("panel",card_style)
        for item in snapshot.get("skills" if is_skill else "tools",[]):
            if String(item.get("id",""))!=id:continue
            var item_name:=String(item.get("name",id))
            tactical_names[index].text=("休眠 · "+item_name) if not dormant_reason.is_empty() else item_name
            tactical_cards[index].tooltip_text="未激活："+dormant_reason if not dormant_reason.is_empty() else item_name
            if not dormant_reason.is_empty():
                tactical_values[index].text=dormant_reason
                tactical_icons[index].modulate=Color(0.45,0.45,0.45)
                break
            if is_skill:
                var remaining:=float(system.cooldowns.get(id,0)) if system!=null else 0.0
                var readiness := _skill_readiness(item,remaining,active)
                tactical_values[index].text=String(readiness.text)
                tactical_cards[index].tooltip_text=item_name+" · "+String(readiness.detail)
                tactical_icons[index].modulate=Color.WHITE if readiness.available else Color(0.45,0.45,0.45)
            else:
                var count := int(item.get("count",0))
                var readiness: Dictionary = level.get_tool_readiness(id) if level.has_method("get_tool_readiness") else {"available":count>0,"text":"" if count>0 else "已用尽","detail":""}
                tactical_values[index].text=String(readiness.text) if not String(readiness.text).is_empty() else "× %d" % count
                tactical_cards[index].tooltip_text=item_name+" · 剩余 %d / %d 次。" % [count,int(item.get("capacity",count))]+String(readiness.detail)
                tactical_icons[index].modulate=Color.WHITE if bool(readiness.available) else Color(0.45,0.45,0.45)
