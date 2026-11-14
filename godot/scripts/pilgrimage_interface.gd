extends Control
const SPACING := preload("res://scripts/ui_spacing_scale.gd")

const TYPE := preload("res://scripts/ui_type_scale.gd")
const PROMPT_BINDINGS := preload("res://scripts/input_prompt_bindings.gd")
const ART := preload("res://scripts/hand_drawn_assets.gd")
const DIALOG_FOCUS := preload("res://scripts/dialog_focus_bridge.gd")
const READING_SCROLL := preload("res://scripts/reading_scroll.gd")
const FONT := preload("res://assets/fonts/GlobalTypeface.otf")
const INSCRIBED_BUTTON := preload("res://scripts/pilgrimage_button.gd")
static var _survey_font: FontFile
const CHROME := preload("res://scripts/pilgrimage_chrome.gd")
const HUD_OCCLUSION := preload("res://scripts/hud_occlusion.gd")
const HEAL_READOUT := preload("res://scripts/heal_resource_readout.gd")
const DIALOG_READING := preload("res://scripts/dialog_reading_adapter.gd")
var dialog_reading: Node
var healing_payment: Label
var healing_payment_track: Control
const IVORY := Color("e8d7b8")
const GOLD := Color("bca07a")
const MUTED := Color("a2b3aa")
const RED := Color("c85450")
const LOCKED_CONTROL_TINT := Color(1,1,1,0.72)
const NORMAL_CONTROL_TINT := Color.WHITE
var level: Node
var hud_card: Control
var location_rule: Control
var hearts: Label
var hud_crest: TextureRect
var health_glyphs: Control
var modal_shade: ColorRect
var tactical_cards: Array[Panel]=[]
## U03: per-group HUD alpha while the fight is behind it ("top" / "tactical").
var hud_group_alpha := {"top":1.0,"tactical":1.0}
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
var thread_thresholds: Control
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
var bag_footer_hint: Label
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
var dialogue_inquiry_button: Button
var narrative_inquiry_desk: AcceptDialog
var dialogue_continue_button: Button
var dialogue_route_button: Button
const READING_SESSION := preload("res://scripts/world_reading_session.gd")
var reading_session_scope := ""
var reading_session_host: WeakRef
var reading_session_generation := 0
var pending_journal_restore: Callable
var pending_dialogue_restore: Callable
var dialogue_reading := preload("res://scripts/dialogue_reading_memory.gd").new()
var dialogue_reading_key := ""
var settings: ColorRect
var legacy_settings: Label
var toast: Label
var toast_age := 0.0
var last_toast := ""
var audio_save_toast := ""
var settings_sliders: Dictionary={}
var settings_labels: Dictionary={}
var build_panel: ColorRect
var build_grid: VBoxContainer
var build_detail: RichTextLabel
var build_summary: Label
var build_tabs: Array[Button]=[]
var build_category := "契印"
var equipment_filter:=preload("res://scripts/equipment_catalog_filter.gd").new()
var equipment_search: LineEdit
var equipment_compatible: CheckBox
var equipment_scroll: ScrollContainer
var build_selection := ""
var loadout_dialog: ConfirmationDialog
var loadout_manager: ConfirmationDialog
var loadout_restore_dialog: ConfirmationDialog
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
var resupply_planner_button: Button
var resupply_planner: ConfirmationDialog
var combat_status: Label
var energy_status: Label
var healing_bar: ProgressBar
var healing_status: Label
var tutorial_hint: Label
var accessibility_path := "user://pilgrimage_accessibility.cfg"
var controller_comfort_dialog: ConfirmationDialog
var accessibility_controls: Dictionary={}
var settings_persistence:=preload("res://scripts/settings_persistence.gd").new()
var settings_save_notice: Label
var settings_save_retry: Button
var accessibility_toggles: Dictionary={}
var accessibility: Dictionary={"danger_captions":false,"danger_caption_limit":2,"danger_caption_contrast":true,"npc_landmarks":true,"controller_deadzone":0.2,"subtitle_speed":1.0,"subtitle_size":21,"flash_enabled":true,"vibration_enabled":true,"vibration_strength":1.0,"camera_shake":1.0,"camera_lookahead":1.0,"observation_mode":0,"observation_delay":0.35,"observation_distance":1.0,"tutorial_hints":false,"navigation_assist":false}
## Fixture hook for the reading stick; NAN reads real connected pads.
var reading_axis_override := NAN
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
## The HUD build line reads names, stock and slot dormancy, all derived from
## build state; a full snapshot costs ~5ms, so it is rebuilt only on change.
var combat_snapshot: Dictionary = {}
var combat_snapshot_key := 0
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
var journal_catalog := preload("res://scripts/journal_catalog.gd").new()
var journal_tools: HBoxContainer
var journal_search: LineEdit
var journal_unread: CheckButton
var journal_stars: CheckButton
var journal_sort: OptionButton
var journal_count: Label
var journal_mark_button: Button
var journal_star_button: Button
var journal_batch_button: Button
var journal_batch_dialog: ConfirmationDialog
var journal_source_dialog: AcceptDialog
var journal_current_document: Dictionary={}
var journal_documents: Array=[]
var text_entry_windows: Array[WeakRef]=[]
var modal_closed_frame := -1
var wish_confirmation: ConfirmationDialog
var craft_cart: ConfirmationDialog
var craft_cart_button: Button
var save_desk: ConfirmationDialog
var journal_preferences_path:="user://journal_reading_preferences.json"
var journal_reading := preload("res://scripts/journal_reading.gd").new()
var journal_reading_key := ""
var journal_reading_text := ""
var journal_restore_pending := false
var bag_scroll: ScrollContainer
var construction_complete := false
var inventory_build_selection := ""

const BINDING_POLICY = preload("res://scripts/input_binding_policy.gd")
const INTERFACE_SETTINGS := preload("res://scripts/interface_settings.gd")
const INTERFACE_BUILD_PANEL := preload("res://scripts/interface_build_panel.gd")
const INTERFACE_BUILD_REFRESH := preload("res://scripts/interface_build_refresh.gd")
const INTERFACE_JOURNAL := preload("res://scripts/interface_journal.gd")
const INTERFACE_DIALOGUE := preload("res://scripts/interface_dialogue.gd")
var binding_recovery_notice := ""
var build_shortcut: Node
var remap_scroll: ScrollContainer

const REMAPPABLE_ACTIONS := {"jump":"跳跃","attack":"普攻","heal":"治疗","skill_1":"施放技能","skill_cycle":"切换技能","tool_cast":"使用战具","tool_cycle":"切换战具","dash":"冲刺","interact":"互动",
    # U06: movement and the four permanent abilities are remappable too.
    "move_left":"左移","move_right":"右移","aim_up":"向上","aim_down":"向下",
    "hook":"回声钩索","bell_guard":"钟壳格挡","lantern_phase":"灯影相位","crown_resonance":"王冠共鸣",
    "inventory":"行囊","map":"地图","audio_settings":"设置","build_menu":"构筑"}
const REMAP_COLUMNS := 4
## Bindings as the game ships them, recorded once per run before saved ones apply.
static var default_bindings: Dictionary = {}

func bind(runtime: Node) -> void:
    begin_bind(runtime)
    for method in build_steps():
        call(method)
    finish_bind()

static func build_steps() -> Array[String]:
    return ["_build_hud", "_build_bag", "_build_dialogue", "_begin_settings",
        "_build_settings_audio", "_build_settings_accessibility", "_build_settings_controls",
        "_finish_settings", "_build_build_panel"]

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
    _sync_reading_session()
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
    # Every dialog under this shell, including ones desks create later, gets
    # its button row and content joined for d-pad navigation.
    if not get_tree().node_added.is_connected(_bridge_dialog_focus):
        get_tree().node_added.connect(_bridge_dialog_focus)
    var scope: Node=level if level is Node else self
    for dialog in scope.find_children("*","AcceptDialog",true,false):_bridge_dialog_focus(dialog)
    # Dropdown popups are internal children that find_children does not list.
    for menu in scope.find_children("*","OptionButton",true,false)+scope.find_children("*","MenuButton",true,false):_bridge_dialog_focus(menu.get_popup())
    _fit_viewport()
    construction_complete=true
    set_process(true)
    set_process_input(true)
    preload("res://scripts/goal_desk.gd").install(self)
    preload("res://scripts/expedition_desk.gd").install(self)
    preload("res://scripts/practice_desk.gd").install(self)
    preload("res://scripts/settings_profiles_desk.gd").install(self)
    preload("res://scripts/combat_desk.gd").install(self)
    preload("res://scripts/field_contract_desk.gd").install(self)
    preload("res://scripts/sparring_desk.gd").install(self)
    preload("res://scripts/material_exchange_desk.gd").install(self)
    preload("res://scripts/danger_caption_desk.gd").install(self)
    preload("res://scripts/credits_reader.gd").install(self)

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
    button.add_theme_font_size_override("font_size",TYPE.ACTION)
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
    healing_payment=HEAL_READOUT.create_label(self,display_font(),GOLD)
    healing_payment_track=preload("res://scripts/heal_reservation_track.gd").new()
    add_child(healing_payment_track)
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
    hearts=_label(hud_card,"",Vector2(266,17),Vector2(55,27),TYPE.ACTION,IVORY)
    hearts.add_theme_font_override("font",display_font())
    hearts.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
    _label(hud_card,"绯线",Vector2(79,58),Vector2(65,22),TYPE.CONTROL,GOLD).add_theme_font_override("font",display_font())
    energy_status=_label(hud_card,"",Vector2(205,58),Vector2(112,22),TYPE.CONTROL,IVORY)
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
    thread_thresholds=CHROME.new()
    thread_thresholds.kind="thresholds"
    thread_thresholds.position=Vector2(80,81)
    thread_thresholds.size=Vector2(224,13)
    hud_card.add_child(thread_thresholds)
    currency_emblem=_icon(self,ART.item("currency"),Vector2(1130,31),Vector2(28,28))
    currency=_label(self,"0",Vector2(1168,30),Vector2(88,30),TYPE.READING,GOLD)
    location_rule=CHROME.new()
    location_rule.kind="location"
    location_rule.position=Vector2(443,24)
    location_rule.size=Vector2(394,51)
    add_child(location_rule)
    location=_label(self,"",Vector2(478,27),Vector2(324,38),TYPE.HUD_PLACE,IVORY)
    location.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    toast=_label(self,"",Vector2(395,102),Vector2(490,60),TYPE.BODY,IVORY)
    toast.add_theme_stylebox_override("normal",_style(Color(0.04,0.07,0.08,0.94),Color("514e3e")))
    toast.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    toast.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    prompt=_label(self,"",Vector2(370,549),Vector2(540,42),TYPE.TITLE,IVORY)
    prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    prompt.clip_text=true
    prompt.add_theme_stylebox_override("normal",_style(Color(0.04,0.07,0.08,0.94),GOLD))
    combat_status=_label(self,"",Vector2(28,144),Vector2(360,76),TYPE.CONTROL,IVORY)
    combat_status.visible=false
    mechanism_status=_label(self,"",Vector2(30,141),Vector2(360,26),TYPE.CONTROL,GOLD)
    healing_status=_label(self,"",Vector2(30,169),Vector2(360,24),TYPE.CONTROL,MUTED)
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
    pinned=_label(self,"",Vector2(30,212),Vector2(300,45),TYPE.CONTROL,MUTED)
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
        tactical_values.append(_label(card,"",Vector2(53,13),Vector2(39,30),TYPE.CAPTION,GOLD))
        tactical_names.append(_label(card,"",Vector2(8,54),Vector2(83,20),TYPE.CAPTION,IVORY))
        tactical_names[-1].text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    tutorial_hint=_label(self,"",Vector2(28,687),Vector2(620,23),TYPE.CAPTION,MUTED)
    for entry in [["B  构筑",_request_build_toggle],["Tab  行囊",func():level._toggle_backpack()],["M  地图",func():level._toggle_map()],["V  设置",func():level._toggle_audio_settings()]]:
        quick_actions.append(_button(self,entry[0],Vector2(827+quick_actions.size()*108,673),Vector2(100,33),entry[1]))
    boss_name=_label(self,"",Vector2(395,593),Vector2(490,27),TYPE.ACTION,GOLD)
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
    _label(bag,"器物有用途，旧物有来处。",Vector2(34,101),Vector2(260,26),16,MUTED)
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
    journal_filters.add_theme_constant_override("separation",SPACING.ROW)
    journal_filters.visible=false
    bag.add_child(journal_filters)
    var filters:=[["all","全部"],["main","主线"],["quest","委托"],["evidence","证词"],["enemy","敌人"],["ending","结局"],["guide","手册"],["ability","能力"],["people","人物"],["voice","自述"]]
    var filter_width:=floorf((645.0-(filters.size()-1)*float(SPACING.ROW))/filters.size())
    for pair in filters:
        var filter_id:=String(pair[0])
        var filter_button:=_button(journal_filters,String(pair[1]),Vector2.ZERO,Vector2(filter_width,28),func():
            journal_filter=filter_id
            journal_selection=0
            bag_scroll.scroll_vertical=0
            refresh_inventory())
        filter_button.custom_minimum_size=Vector2(filter_width,28)
        filter_button.add_theme_font_size_override("font_size",TYPE.CONTROL)
        journal_filter_buttons[filter_id]=filter_button
    journal_tools=HBoxContainer.new()
    journal_tools.position=Vector2(34,222)
    journal_tools.size=Vector2(645,30)
    journal_tools.add_theme_constant_override("separation",8)
    bag.add_child(journal_tools)
    # Enter the tree before setting text: shaping text on a detached control
    # costs several ms each (see the 10-21 UI rebuild report).
    journal_search=LineEdit.new()
    journal_search.custom_minimum_size=Vector2(236,30)
    journal_search.add_theme_font_size_override("font_size",TYPE.CONTROL)
    journal_tools.add_child(journal_search)
    journal_search.placeholder_text="搜索已知记录 · Ctrl+F"
    journal_search.tooltip_text="只搜索已知标题和正文。空格分词；双引号或中文引号查短语；-词语 排除匹配。"
    journal_search.max_length=80
    journal_search.text_changed.connect(func(_value: String):journal_selection=0;refresh_inventory())
    journal_unread=CheckButton.new()
    journal_unread.add_theme_font_size_override("font_size",TYPE.CONTROL)
    journal_tools.add_child(journal_unread)
    journal_unread.text="仅未读"
    journal_unread.toggled.connect(func(_value: bool):journal_selection=0;refresh_inventory())
    journal_stars=CheckButton.new()
    journal_stars.add_theme_font_size_override("font_size",TYPE.CONTROL)
    journal_tools.add_child(journal_stars)
    journal_stars.text="仅收藏"
    journal_stars.toggled.connect(func(_value: bool):journal_selection=0;refresh_inventory())
    journal_sort=OptionButton.new()
    journal_sort.add_theme_font_size_override("font_size",TYPE.CONTROL)
    journal_sort.custom_minimum_size=Vector2(127,30)
    journal_tools.add_child(journal_sort)
    journal_sort.add_item("旅途顺序")
    journal_sort.add_item("按标题")
    journal_sort.add_item("未读优先")
    preload("res://scripts/journal_find_dialog.gd").install(self)
    journal_sort.item_selected.connect(func(_index: int):journal_selection=0;refresh_inventory())
    journal_count=_label(bag,"",Vector2(34,255),Vector2(645,20),12,MUTED)
    bag_grid=GridContainer.new()
    bag_grid.columns=6
    bag_grid.add_theme_constant_override("h_separation",SPACING.ROW)
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
    bag_category_label=_label(bag,"",Vector2(734,314),Vector2(342,26),TYPE.BODY,GOLD)
    bag_category_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    bag_description=RichTextLabel.new()
    bag_description.position=Vector2(738,354)
    bag_description.size=Vector2(330,160)
    bag_description.add_theme_font_size_override("normal_font_size",TYPE.ACTION)
    bag_description.add_theme_color_override("default_color",IVORY)
    bag_description.scroll_active=true
    bag.add_child(bag_description)
    bag.visibility_changed.connect(_journal_bag_visibility_changed)
    bag_pin=_button(bag,"钉在旅记",Vector2(738,533),Vector2(330,35),_pin_item)
    journal_mark_button=_button(bag,"标为已读",Vector2(738,571),Vector2(160,27),_toggle_journal_read)
    journal_star_button=_button(bag,"收藏记录",Vector2(908,571),Vector2(160,27),_toggle_journal_star)
    journal_mark_button.add_theme_font_size_override("font_size",TYPE.CONTROL)
    journal_star_button.add_theme_font_size_override("font_size",TYPE.CONTROL)
    journal_batch_button=_button(bag,"筛选结果标已读",Vector2(562,571),Vector2(166,27),_open_journal_batch)
    journal_batch_button.add_theme_font_size_override("font_size",TYPE.CONTROL)
    journal_batch_button.tooltip_text="确认后，将当前筛选中最多256条已知记录标为已读；不推进任务。"
    bag_footer_hint=_label(bag,"",Vector2(34,552),Vector2(520,30),TYPE.CAPTION,MUTED)
    _refresh_bag_footer_hint()
    legacy_bag_text=_label(bag,"",Vector2.ZERO,Vector2.ZERO)
    preload("res://scripts/resource_purpose_dialog.gd").setup(self)
    preload("res://scripts/journal_mark_desk.gd").install(self)
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
    if has_node("JournalMarkDesk"):get_node("JournalMarkDesk").refresh_launcher()
    if bag_category=="旅记":
        var sources:=preload("res://scripts/journal_sources.gd").links(String(journal_current_document.get("key","")),level.inventory_counts,level.story_flags)
        bag_pin.disabled=sources.is_empty()
        bag_pin.text="回看来源 · %d条" % sources.size() if not sources.is_empty() else "PgUp/PgDn · LB/RB 翻页"
        bag_pin.tooltip_text="回看本条引用的已知原始记录；关闭后回到原文。" if not sources.is_empty() else "Home 到开头，End 到末尾；切换记录后保留本次阅读位置。"
    if is_instance_valid(journal_source_dialog):journal_source_dialog.refresh_binding()
    if journal_filters!=null:
        journal_filters.visible=bag_category=="旅记"
        bag_scroll.position.y=279 if journal_filters.visible else 194
        bag_scroll.size.y=252 if journal_filters.visible else 337
        for control in [journal_tools,journal_count,journal_mark_button,journal_star_button,journal_batch_button]:control.visible=journal_filters.visible
    begin_inventory_refresh()
    if bag_category=="旅记":
        _refresh_journal()
        return
    for item_id in _visible_inventory_ids():
        append_inventory_item(item_id)
    finish_inventory_refresh()

func begin_inventory_refresh() -> void:
    if is_instance_valid(journal_source_dialog):journal_source_dialog.refresh_binding()
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
    _label(button,str(count),Vector2(59,48),Vector2(30,23),TYPE.CAPTION,GOLD)

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
    if bag_category=="旅记":
        _open_journal_sources()
        return
    var id := _reconcile_inventory_selection()
    if id.is_empty():return
    var was_pinned:=bool(level.story_flags.get("ui_pin_"+id,false))
    for key in level.story_flags.keys():
        if String(key).begins_with("ui_pin_"):level.story_flags[key]=false
    level.story_flags["ui_pin_"+id]=not was_pinned
    refresh_inventory()

func _build_dialogue() -> void:
    INTERFACE_DIALOGUE.build_dialogue(self)

func show_speaker(area: Area2D) -> void:
    INTERFACE_DIALOGUE.show_speaker(self, area)

func _speaker_motion(area, talking: bool) -> void:
    INTERFACE_DIALOGUE.speaker_motion(self, area, talking)

func _open_narrative_inquiries() -> void:
    INTERFACE_DIALOGUE.open_narrative_inquiries(self)

func _topic(key: String) -> void:
    INTERFACE_DIALOGUE.topic(self, key)

func _commit_wish_topic(quest: Dictionary, area: Area2D) -> bool:
    return INTERFACE_DIALOGUE.commit_wish_topic(self, quest, area)

func _dialogue_reading_key(area: Area2D,line: String) -> String:
    return INTERFACE_DIALOGUE.dialogue_reading_key(self, area, line)

func dialogue_reading_state(area: Area2D,line: String) -> Dictionary:
    return INTERFACE_DIALOGUE.dialogue_reading_state(self, area, line)

func forget_dialogue_reading() -> void:
    INTERFACE_DIALOGUE.forget_dialogue_reading(self)

func _restore_dialogue_scroll(key: String,value: int) -> void:
    INTERFACE_DIALOGUE.restore_dialogue_scroll(self, key, value)

func _apply_dialogue_scroll(key: String,value: int,request_generation: int) -> void:
    INTERFACE_DIALOGUE.apply_dialogue_scroll(self, key, value, request_generation)

func _remember_dialogue_reading() -> void:
    INTERFACE_DIALOGUE.remember_dialogue_reading(self)

func close_dialogue() -> void:
    INTERFACE_DIALOGUE.close_dialogue(self)

func _build_settings() -> void:
    INTERFACE_SETTINGS.build_settings(self)

func _begin_settings() -> void:
    INTERFACE_SETTINGS.begin_settings(self)

func _build_settings_audio() -> void:
    INTERFACE_SETTINGS.build_settings_audio(self)

func _build_settings_accessibility() -> void:
    INTERFACE_SETTINGS.build_settings_accessibility(self)

func _build_settings_controls() -> void:
    var remap_title:=_label(settings,"按键重映射",Vector2(34,384),Vector2(420,28),17,GOLD)
    remap_title.tooltip_text="选择动作后按键、鼠标按钮或推动扳机；方向键 / 手柄十字键选择。"
    remap_title.mouse_filter=Control.MOUSE_FILTER_PASS
    reset_bindings_button=_button(settings,"恢复默认按键",Vector2(800,381),Vector2(172,28),_reset_bindings)
    reset_bindings_button.add_theme_font_size_override("font_size",TYPE.CONTROL)
    remap_scroll=ScrollContainer.new()
    remap_scroll.name="RemapScroll"
    remap_scroll.position=Vector2(34,414)
    remap_scroll.size=Vector2(938,130)
    remap_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    remap_scroll.follow_focus=true
    settings.add_child(remap_scroll)
    var remap_grid:=GridContainer.new()
    remap_grid.columns=REMAP_COLUMNS
    remap_grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    remap_grid.add_theme_constant_override("h_separation",6)
    remap_grid.add_theme_constant_override("v_separation",1)
    remap_scroll.add_child(remap_grid)
    for action in REMAPPABLE_ACTIONS:
        var action_id:=String(action)
        var button:=_button(remap_grid,"",Vector2.ZERO,Vector2(224,26),func():_begin_remap(action_id))
        button.custom_minimum_size=Vector2(224,26)
        button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
        button.add_theme_font_size_override("font_size",12)
        remap_buttons[action_id]=button
    remap_status=_label(settings,"确认键改键  ·  Esc／手柄 B 取消",Vector2(34,549),Vector2(938,24),TYPE.CAPTION,MUTED)
    if not binding_recovery_notice.is_empty():remap_status.text=binding_recovery_notice
    remap_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART

func _finish_settings() -> void:
    INTERFACE_SETTINGS.finish_settings(self)

func _accessibility_slider(key: String, title: String, point: Vector2, minimum: float, maximum: float, increment: float) -> void:
    INTERFACE_SETTINGS.accessibility_slider(self, key, title, point, minimum, maximum, increment)

func _accessibility_toggle(key: String, title: String, point: Vector2) -> void:
    INTERFACE_SETTINGS.accessibility_toggle(self, key, title, point)

func get_accessibility(key: String, fallback: Variant=null) -> Variant:
    return INTERFACE_SETTINGS.get_accessibility(self, key, fallback)

func _load_accessibility() -> void:
    INTERFACE_SETTINGS.load_accessibility(self)

func _finite_setting(config: ConfigFile, key: String, minimum: float, maximum: float) -> float:
    return INTERFACE_SETTINGS.finite_setting(self, config, key, minimum, maximum)

func _normalized_binding(value: Variant) -> InputEvent:
    return BINDING_POLICY.normalize(value)

func is_remapping_input() -> bool:
    return INTERFACE_SETTINGS.is_remapping_input(self)

func _remember_gui_focus(_focused: Control) -> void:
    INTERFACE_SETTINGS.remember_gui_focus(self, _focused)

func _is_navigable_focus(control: Control) -> bool:
    return INTERFACE_SETTINGS.is_navigable_focus(self, control)

func _overlay_controls(overlay: String) -> Array[Control]:
    return INTERFACE_SETTINGS.overlay_controls(self, overlay)

func _collect_navigable(node: Node, result: Array[Control]) -> void:
    INTERFACE_SETTINGS.collect_navigable(self, node, result)

func _focus_overlay(overlay: String, restore: bool=true) -> void:
    INTERFACE_SETTINGS.focus_overlay(self, overlay, restore)

func _on_joy_connection_changed(_device: int, connected: bool) -> void:
    INTERFACE_SETTINGS.on_joy_connection_changed(self, _device, connected)

func _accessibility_config() -> ConfigFile:
    return INTERFACE_SETTINGS.accessibility_config(self)

func _save_accessibility() -> Error:
    return INTERFACE_SETTINGS.save_accessibility(self)

func _refresh_settings_save_notice() -> void:
    INTERFACE_SETTINGS.refresh_settings_save_notice(self)

func _retry_accessibility_save() -> void:
    INTERFACE_SETTINGS.retry_accessibility_save(self)

func _apply_controller_deadzone() -> void:
    INTERFACE_SETTINGS.apply_controller_deadzone(self)

func _sync_accessibility_controls() -> void:
    INTERFACE_SETTINGS.sync_accessibility_controls(self)

func _open_controller_comfort() -> void:
    INTERFACE_SETTINGS.open_controller_comfort(self)

func _ready() -> void:
    dialog_reading=DIALOG_READING.new()
    dialog_reading.name="DialogReadingAdapter"
    add_child(dialog_reading)

func _apply_accessibility() -> void:
    INTERFACE_SETTINGS.apply_accessibility(self)

func _record_default_bindings() -> void:
    INTERFACE_SETTINGS.record_default_bindings(self)

## U06: one press puts every remappable action back to the shipped bindings.
func _reset_bindings() -> void:
    INTERFACE_SETTINGS.reset_bindings(self)

func _begin_remap(action: String) -> void:
    INTERFACE_SETTINGS.begin_remap(self, action)

func _cancel_remap(reason: String) -> void:
    INTERFACE_SETTINGS.cancel_remap(self, reason)

func _remap_visibility_changed() -> void:
    INTERFACE_SETTINGS.remap_visibility_changed(self)

func _notification(what: int) -> void:
    if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
        _cancel_remap("窗口已失去焦点，重映射已取消；原绑定保留。")
        if is_instance_valid(build_shortcut):build_shortcut.clear()

func _refresh_remap_labels() -> void:
    INTERFACE_SETTINGS.refresh_remap_labels(self)

func _input(event: InputEvent) -> void:
    INTERFACE_SETTINGS.input(self, event)

func _bind_ui_navigation() -> void:
    INTERFACE_SETTINGS.bind_ui_navigation(self)

func _build_build_panel() -> void:
    INTERFACE_BUILD_PANEL.build_build_panel(self)

func _request_build_toggle() -> void:
    INTERFACE_BUILD_PANEL.request_build_toggle(self)

func _wire_equipment_result_focus() -> void:
    INTERFACE_BUILD_PANEL.wire_equipment_result_focus(self)

func _equipment_filter_changed() -> void:
    INTERFACE_BUILD_PANEL.equipment_filter_changed(self)

func _sync_equipment_filter(at_workstation: bool) -> void:
    INTERFACE_BUILD_PANEL.sync_equipment_filter(self, at_workstation)

func toggle_build() -> void:
    INTERFACE_BUILD_PANEL.toggle_build(self)

func close_build() -> void:
    INTERFACE_BUILD_PANEL.close_build(self)

func _build_snapshot() -> Dictionary:
    return INTERFACE_BUILD_PANEL.build_snapshot(self)

func _is_at_build_workstation(snapshot: Dictionary) -> bool:
    return INTERFACE_BUILD_PANEL.is_at_build_workstation(self, snapshot)

func _skill_practiced(skill_id: String) -> bool:
    return INTERFACE_BUILD_PANEL.skill_practiced(self, skill_id)

func _has_patterns(recipe: Dictionary) -> bool:
    return INTERFACE_BUILD_PANEL.has_patterns(self, recipe)

## E04: who makes it, what pattern it needs, and what it changes, before any spending.
func _craft_lines(entry: Dictionary, snapshot: Dictionary) -> Array:
    return INTERFACE_BUILD_PANEL.craft_lines(self, entry, snapshot)

## C04: compare one 校习 direction with the untrained skill and the other direction.
func _skill_branch_lines(skill: Dictionary, recipe: Dictionary) -> Array:
    return INTERFACE_BUILD_PANEL.skill_branch_lines(self, skill, recipe)

func _family_row(snapshot: Dictionary, family_id: String) -> Dictionary:
    return INTERFACE_BUILD_PANEL.family_row(self, snapshot, family_id)

func _family_slots(snapshot: Dictionary, family_id: String) -> Array:
    return INTERFACE_BUILD_PANEL.family_slots(self, snapshot, family_id)

## U02: what still opens a locked slot — the crest's own mechanism (its seal
## quest) and/or an artisan-made part — so a locked slot never reads as final.
func _slot_unlock_hints(snapshot: Dictionary, slot: Dictionary) -> Array[String]:
    return INTERFACE_BUILD_PANEL.slot_unlock_hints(self, snapshot, slot)

func _slot_dormancy_reason(slot: Dictionary, item_id: String) -> String:
    return INTERFACE_BUILD_PANEL.slot_dormancy_reason(self, slot, item_id)

func _family_slot_dormancy_reason(snapshot: Dictionary,family_id: String,slot_index: int,item_id: String) -> String:
    return INTERFACE_BUILD_PANEL.family_slot_dormancy_reason(self, snapshot, family_id, slot_index, item_id)

func _family_options(snapshot: Dictionary, family_id: String) -> Array:
    return INTERFACE_BUILD_PANEL.family_options(self, snapshot, family_id)

func _build_family_for_page() -> String:
    return INTERFACE_BUILD_PANEL.build_family_for_page(self)

func _family_entry(snapshot: Dictionary, family_id: String, id: String) -> Dictionary:
    return INTERFACE_BUILD_PANEL.family_entry(self, snapshot, family_id, id)

func _family_option_names(snapshot: Dictionary,family_id: String,ids: Array) -> Array[String]:
    return INTERFACE_BUILD_PANEL.family_option_names(self, snapshot, family_id, ids)

func _ensure_family_slot_buttons(snapshot: Dictionary, family_id: String, slots: Array) -> void:
    INTERFACE_BUILD_PANEL.ensure_family_slot_buttons(self, snapshot, family_id, slots)

func _family_count_summary(snapshot: Dictionary, family_id: String, slots: Array) -> String:
    return INTERFACE_BUILD_PANEL.family_count_summary(self, snapshot, family_id, slots)

func _all_family_count_summary(snapshot: Dictionary) -> String:
    return INTERFACE_BUILD_PANEL.all_family_count_summary(self, snapshot)

func _open_resupply_planner() -> void:
    INTERFACE_BUILD_PANEL.open_resupply_planner(self)

func _preview_tool_resupply() -> void:
    INTERFACE_BUILD_PANEL.preview_tool_resupply(self)

func _resupply_quote_text(quote: Dictionary) -> String:
    return INTERFACE_BUILD_PANEL.resupply_quote_text(self, quote)

func _resupply_tool_name(item_id: String) -> String:
    return INTERFACE_BUILD_PANEL.resupply_tool_name(self, item_id)

func _confirm_tool_resupply() -> void:
    INTERFACE_BUILD_PANEL.confirm_tool_resupply(self)

func refresh_build() -> void:
    INTERFACE_BUILD_REFRESH.refresh_build(self)

func _open_loadout_restore(name: String) -> void:
    INTERFACE_BUILD_REFRESH.open_loadout_restore(self, name)

func _open_loadout_manager(source: String) -> void:
    INTERFACE_BUILD_REFRESH.open_loadout_manager(self, source)

func _loadout_difference_text(preview: Dictionary, system: RefCounted) -> Array[String]:
    return INTERFACE_BUILD_REFRESH.loadout_difference_text(self, preview, system)

func _loadout_names(snapshot: Dictionary) -> Array[String]:
    return INTERFACE_BUILD_REFRESH.loadout_names(self, snapshot)

func _request_loadout_change(action: String, name: String) -> void:
    INTERFACE_BUILD_REFRESH.request_loadout_change(self, action, name)

func _confirm_loadout_change() -> void:
    INTERFACE_BUILD_REFRESH.confirm_loadout_change(self)

## The snapshot stores catalog ids; players only ever see the authored name.
func _build_entry_name(system: Variant, family: String, id: String) -> String:
    return INTERFACE_BUILD_REFRESH.build_entry_name(self, system, family, id)

func _entry_equipped_slots(snapshot: Dictionary, id: String) -> String:
    return INTERFACE_BUILD_REFRESH.entry_equipped_slots(self, snapshot, id)

func _loadout_quote(name: String) -> Dictionary:
    return INTERFACE_BUILD_REFRESH.loadout_quote(self, name)

func _loadout_preview(build: Dictionary, system: RefCounted) -> String:
    return INTERFACE_BUILD_REFRESH.loadout_preview(self, build, system)

func _show_build_detail(entry: Dictionary) -> void:
    INTERFACE_BUILD_REFRESH.show_build_detail(self, entry)

func _open_craft_cart() -> void:
    INTERFACE_BUILD_REFRESH.open_craft_cart(self)

func _perform_build_action(action: String, id: String, extra: Variant = -1) -> void:
    INTERFACE_BUILD_REFRESH.perform_build_action(self, action, id, extra)

func _open_save_desk(slot: int, action: String) -> void:
    INTERFACE_BUILD_REFRESH.open_save_desk(self, slot, action)

func _select_save_slot(slot: int) -> void:
    INTERFACE_BUILD_REFRESH.select_save_slot(self, slot)

func _restore_save_backup() -> void:
    INTERFACE_BUILD_REFRESH.restore_save_backup(self)

func _show_journey_history() -> void:
    INTERFACE_BUILD_REFRESH.show_journey_history(self)

func _journey_history_closed() -> void:
    INTERFACE_BUILD_REFRESH.journey_history_closed(self)

func is_browsing_journey_history() -> bool:
    return INTERFACE_BUILD_REFRESH.is_browsing_journey_history(self)

func _refresh_save_slots() -> void:
    INTERFACE_BUILD_REFRESH.refresh_save_slots(self)

func _process(delta: float) -> void:
    if level==null or not construction_complete:return
    _sync_reading_session()
    if not String(level.active_overlay).is_empty() or has_modal_window():
        var reading_axis: float=reading_axis_override if is_finite(reading_axis_override) else READING_SCROLL.stick_axis(float(accessibility.get("controller_deadzone",0.2)))
        if reading_axis!=0.0:READING_SCROLL.scroll(self,reading_axis*READING_SCROLL.SPEED*delta)
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
        _refresh_thread_thresholds(player)
        _refresh_combat_status(player)
        _refresh_hud_occlusion(delta)
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

func _audio_save_feedback(saved: Dictionary) -> void:
    if not is_instance_valid(toast):return
    if not saved.get("persisted",true):
        audio_save_toast=String(saved.get("reason","音量尚未保存。"))
        toast.text=audio_save_toast
    elif not audio_save_toast.is_empty():
        if toast.text!=audio_save_toast:
            audio_save_toast=""
            return
        toast.text="音量已保存。"
        audio_save_toast=""
    else:return
    last_toast=toast.text
    toast_age=0.0
    toast.modulate.a=1.0

func refresh_settings_selection() -> void:
    var rows: Array=level.AUDIO_SETTINGS_ROWS
    var saved: Dictionary={"persisted":true,"reason":""}
    if level.audio_director!=null and level.audio_director.has_method("user_volume_save_status"):
        saved=level.audio_director.user_volume_save_status()
    for i in rows.size():
        var key := String(rows[i][0])
        if not settings_labels.has(key):continue
        var selected: bool = i==level._settings_selection_clamped()
        settings_labels[key].text=("▶ " if selected else "  ")+String(rows[i][1]).split(" ")[0]+(" *" if not saved.get("persisted",true) else "")
        settings_labels[key].tooltip_text=String(saved.get("reason",""))
        settings_labels[key].add_theme_color_override("font_color",GOLD if selected else IVORY)

func _binding_name(event: InputEvent) -> String:
    return PROMPT_BINDINGS.binding_label(event)

func _short_binding(action: String) -> String:
    return PROMPT_BINDINGS.action_label(action)

## The list is walked with the remappable up/down actions, so the footer names
## whatever they are bound to now instead of the default keys.
func _refresh_bag_footer_hint() -> void:
    if bag_footer_hint==null:return
    bag_footer_hint.text="%s/%s 查看  ·  %s 返回" % [_short_binding("aim_up"),_short_binding("aim_down"),_short_binding("close_overlay")]

func _refresh_quick_action_bindings() -> void:
    _refresh_bag_footer_hint()
    var actions := ["build_menu", "inventory", "map", "audio_settings"]
    var titles := ["构筑", "行囊", "地图", "设置"]
    for index in mini(quick_actions.size(), actions.size()):
        var hint := _short_binding(actions[index])
        quick_actions[index].text = hint + " " + titles[index]
        quick_actions[index].text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        quick_actions[index].tooltip_text = quick_actions[index].text

func _dialogue_binding_hint() -> String:
    var action := "继续查看 / 记入旅记" if is_instance_valid(dialogue_area) and String(dialogue_area.get_meta("kind",""))=="history" else "继续"
    return "%s %s\n%s 离开" % [_short_binding("interact"),action,_short_binding("close_overlay")]

func _combat_snapshot() -> Dictionary:
    var system: Variant=level.call("get_build_system") if level!=null and level.has_method("get_build_system") else null
    var source: Variant=system.get("state") if system is Object else null
    if not source is Dictionary:return _build_snapshot()
    var key:=hash([system.get_instance_id(),source])
    if combat_snapshot.is_empty() or key!=combat_snapshot_key:
        combat_snapshot=_build_snapshot()
        combat_snapshot_key=key
    return combat_snapshot

func _refresh_combat_status(player: Node) -> void:
    var state: Dictionary={}
    if player.has_method("get_combat_ui_state"):state=player.call("get_combat_ui_state")
    var snapshot:=_combat_snapshot()
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
    var paid:=HEAL_READOUT.apply(healing_payment,heal,int(player.energy),int(player.max_energy),level.active_overlay!="")
    if is_instance_valid(healing_payment_track):healing_payment_track.update_snapshot(paid,level.active_overlay!="")
    if is_instance_valid(pinned):pinned.position.y=248.0 if bool(paid.active) else 212.0
    # Full health leaves nothing to do: keep the corner quiet (U01 less text).
    healing_status.visible=not heal.is_empty() and level.active_overlay=="" and String(heal.get("reason",""))!="full_health"
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
    INTERFACE_JOURNAL.refresh_journal(self)

func _journal_presentation(entry: Dictionary) -> Dictionary:
    return INTERFACE_JOURNAL.journal_presentation(self, entry)

func _show_journal_record(entry: Dictionary) -> void:
    INTERFACE_JOURNAL.show_journal_record(self, entry)

func register_text_entry_window(window: Window) -> void:
    INTERFACE_JOURNAL.register_text_entry_window(self, window)

func _registered_window_visibility(reference: WeakRef) -> void:
    INTERFACE_JOURNAL.registered_window_visibility(self, reference)

func has_modal_window() -> bool:
    return INTERFACE_JOURNAL.has_modal_window(self)

func is_text_entry_focused() -> bool:
    return INTERFACE_JOURNAL.is_text_entry_focused(self)

func _journal_tools_focused() -> bool:
    return INTERFACE_JOURNAL.journal_tools_focused(self)

func _refresh_journal_actions() -> void:
    INTERFACE_JOURNAL.refresh_journal_actions(self)

func _journal_preference_result(result: Dictionary) -> void:
    INTERFACE_JOURNAL.journal_preference_result(self, result)

func _toggle_journal_read() -> void:
    INTERFACE_JOURNAL.toggle_journal_read(self)

func _toggle_journal_star() -> void:
    INTERFACE_JOURNAL.toggle_journal_star(self)

func _journal_batch_available() -> bool:
    return INTERFACE_JOURNAL.journal_batch_available(self)

func _journal_batch_documents() -> Array:
    return INTERFACE_JOURNAL.journal_batch_documents(self)

func _open_journal_sources() -> void:
    INTERFACE_JOURNAL.open_journal_sources(self)

func _open_journal_batch() -> void:
    INTERFACE_JOURNAL.open_journal_batch(self)

func _remember_journal_scroll(force: bool=false) -> void:
    INTERFACE_JOURNAL.remember_journal_scroll(self, force)

func _journal_bag_visibility_changed() -> void:
    INTERFACE_JOURNAL.journal_bag_visibility_changed(self)

func _restore_journal_scroll(key: String, text: String, offset: float, generation: int = -1) -> void:
    INTERFACE_JOURNAL.restore_journal_scroll(self, key, text, offset, generation)

func _apply_journal_scroll(key: String, text: String, offset: float, request_generation: int) -> void:
    INTERFACE_JOURNAL.apply_journal_scroll(self, key, text, offset, request_generation)

func _scroll_journal(step: int) -> void:
    INTERFACE_JOURNAL.scroll_journal(self, step)

func _ending_status_label(entry: Dictionary) -> String:
    if bool(entry.get("chosen",false)):return "已选择"
    if bool(entry.get("available",false)):return "可以选择"
    if String(entry.get("status",""))=="closed":return "已关闭"
    return "准备中"

func _hud_groups() -> Dictionary:
    return {"top":[hud_card,mechanism_status,healing_status,healing_bar,healing_payment,healing_payment_track,pinned],"tactical":tactical_cards}

## The player, enemies and their attacks take priority over HUD chrome: a group
## with any of them behind it on screen fades until the space is clear again.
func _refresh_hud_occlusion(delta: float) -> void:
    var occupants:=HUD_OCCLUSION.occupant_rects(level) if level.active_overlay=="" else ([] as Array[Rect2])
    var groups:=_hud_groups()
    for key in groups:
        var faded:=HUD_OCCLUSION.covered(HUD_OCCLUSION.group_rect(groups[key]),occupants)
        var alpha:=HUD_OCCLUSION.step_alpha(float(hud_group_alpha.get(key,1.0)),faded,delta)
        hud_group_alpha[key]=alpha
        for item in groups[key]:
            if is_instance_valid(item):(item as CanvasItem).modulate.a=alpha

## U03: the thread meter itself says whether a heal and the active thread art
## are affordable. Dormant or empty active skill slots draw no cost mark.
func _refresh_thread_thresholds(player: Node) -> void:
    # UI fixtures drive the HUD with lightweight players that have no heal cost.
    var heal_cost:=int(player.get("heal_energy_cost")) if "heal_energy_cost" in player else 0
    var skill_cost:=0
    var system: Variant=level.call("get_build_system") if level.has_method("get_build_system") else null
    if system!=null and system.has_method("selected_skill"):
        var skill: Dictionary=system.selected_skill()
        if not skill.is_empty():skill_cost=maxi(0,int(skill.get("energy_cost",0)))
    var energy:=int(player.energy)
    var maximum:=maxi(1,int(player.max_energy))
    if thread_thresholds.energy!=energy or thread_thresholds.heal_cost!=heal_cost or thread_thresholds.skill_cost!=skill_cost or thread_thresholds.maximum!=maximum:
        thread_thresholds.energy=energy
        thread_thresholds.heal_cost=heal_cost
        thread_thresholds.skill_cost=skill_cost
        thread_thresholds.maximum=maximum
        thread_thresholds.queue_redraw()


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

func _sync_reading_session() -> void:
    if not is_instance_valid(level):
        return
    var path: Variant = level.get("world_save_path")
    var save_path := String(path) if path is String else "session"
    var expected := READING_SESSION.scope(save_path)
    if reading_session_scope == expected and reading_session_host != null and reading_session_host.get_ref() == level:
        return
    var memory := READING_SESSION.acquire(level, save_path)
    journal_reading = memory.journal
    dialogue_reading = memory.dialogue
    reading_session_scope = expected
    reading_session_host = weakref(level)
    reading_session_generation += 1
    # Deferred restores from a former slot must not apply to its replacement.
    journal_reading_key = ""
    journal_reading_text = ""
    journal_restore_pending = false
    dialogue_reading_key = ""

func _bridge_dialog_focus(node: Node) -> void:
    # Map, recall and new-journey dialogs live under the level, not this shell.
    if node is AcceptDialog and (is_ancestor_of(node) or (level is Node and is_instance_valid(level) and level.is_ancestor_of(node))):
        DIALOG_FOCUS.install(node)
        # Every dialog is modal for polled page shortcuts, including the frame
        # it closes in, so joypad B (back) cancels only the dialog.
        register_text_entry_window(node)
    elif node is PopupMenu and (is_ancestor_of(node) or (level is Node and is_instance_valid(level) and level.is_ancestor_of(node))):
        # B/Escape closing a dropdown must not also close the page behind it.
        register_text_entry_window(node)

func _exit_tree() -> void:
    if get_tree().node_added.is_connected(_bridge_dialog_focus):get_tree().node_added.disconnect(_bridge_dialog_focus)
    # Snapshot reading numbers only; never commit a conversation or grant rewards.
    _remember_journal_scroll(true)
    _remember_dialogue_reading()
