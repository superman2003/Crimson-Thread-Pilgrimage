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
const INTERFACE_HUD := preload("res://scripts/interface_hud.gd")
const INTERFACE_BAG := preload("res://scripts/interface_bag.gd")
const INTERFACE_THEME := preload("res://scripts/interface_theme.gd")
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
    return ["_build_hud", "_build_bag_frame", "_build_bag_list", "_build_bag_journal_tools", "_build_bag_detail", "_build_dialogue", "_begin_settings",
        "_build_settings_audio", "_build_settings_accessibility", "_build_settings_accessibility_tail",
        "_build_settings_controls", "_build_settings_controls_tail",
        "_finish_settings", "_install_settings_dialogs_a", "_install_settings_dialogs_b", "_finish_settings_refresh",
        "_build_build_panel"]

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

const DESKS := ["res://scripts/goal_desk.gd", "res://scripts/expedition_desk.gd", "res://scripts/practice_desk.gd",
    "res://scripts/settings_profiles_desk.gd", "res://scripts/combat_desk.gd", "res://scripts/field_contract_desk.gd",
    "res://scripts/sparring_desk.gd", "res://scripts/material_exchange_desk.gd", "res://scripts/danger_caption_desk.gd",
    "res://scripts/credits_reader.gd"]


## The region build installs the desks as separate jobs (install_desk) after
## this; direct callers get them here as before (T03: together with the scan
## below they were one 14-40 ms job).
func finish_bind(defer_desks: bool = false) -> void:
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
    # This region's nodes and the host's own children; never a second region
    # resident beside it (a destination built hidden, or the one it replaces).
    var scopes: Array[Node] = [self]
    if level is Node:
        scopes = []
        for child in preload("res://scripts/level_host.gd").children(level):
            if not child.has_meta(preload("res://scripts/level_host.gd").META):
                scopes.append(child)
    for scope in scopes:
        if scope is AcceptDialog: _bridge_dialog_focus(scope)
        for dialog in scope.find_children("*","AcceptDialog",true,false):_bridge_dialog_focus(dialog)
        # Dropdown popups are internal children that find_children does not list.
        for menu in scope.find_children("*","OptionButton",true,false)+scope.find_children("*","MenuButton",true,false):_bridge_dialog_focus(menu.get_popup())
    _fit_viewport()
    if not defer_desks:
        complete_bind()
        for index in range(DESKS.size()):
            install_desk(index)


## The interface accepts input and frames only from here on.
func complete_bind() -> void:
    construction_complete=true
    set_process(true)
    set_process_input(true)


func install_desk(index: int) -> void:
    load(DESKS[index]).install(self)

## Styles and geometry are set while the control is outside the tree (cheap:
## no text to shape yet); text is assigned only after it joins the tree. Text
## shaped outside the tree costs ~4 ms per control, which made each region's UI
## rebuild stall for 100+ ms in one loading step (T03).
func _label(parent: Node, text: String, position_value: Vector2, size_value: Vector2, font_size: int=18, tint: Color=IVORY) -> Label:
    return INTERFACE_THEME.label(self, parent, text, position_value, size_value, font_size, tint)

func _style(tint: Color, border: Color, width: int=1) -> StyleBoxFlat:
    return INTERFACE_THEME.style(self, tint, border, width)

func _meter_style(tint: Color) -> StyleBoxFlat:
    return INTERFACE_THEME.meter_style(self, tint)

func _tab_style(selected: bool) -> StyleBoxFlat:
    return INTERFACE_THEME.tab_style(self, selected)

func _button(parent: Node, text: String, position_value: Vector2, size_value: Vector2, action: Callable) -> Button:
    return INTERFACE_THEME.button(self, parent, text, position_value, size_value, action)

func _panel(parent: Node, title: String, position_value: Vector2, size_value: Vector2) -> ColorRect:
    return INTERFACE_THEME.panel(self, parent, title, position_value, size_value)

func frame(control: Control) -> void:
    INTERFACE_THEME.frame(self, control)

func _well(parent: Control, point: Vector2, dimensions: Vector2) -> void:
    INTERFACE_THEME.well(self, parent, point, dimensions)

func _fit_viewport() -> void:
    INTERFACE_THEME.fit_viewport(self)

func _install_theme(target: Theme) -> void:
    INTERFACE_THEME.install_theme(self, target)

func _icon(parent: Node, asset: Texture2D, position_value: Vector2, size_value: Vector2) -> TextureRect:
    return INTERFACE_THEME.icon(self, parent, asset, position_value, size_value)

func _build_hud() -> void:
    INTERFACE_HUD.build_hud(self)

## Whole bag for direct callers; the region build runs its three parts as
## separate jobs (T03: the bag was one 19-28 ms job).
func _build_bag() -> void:
    INTERFACE_BAG.build_bag(self)

func _build_bag_frame() -> void:
    INTERFACE_BAG.build_bag_frame(self)

func _build_bag_list() -> void:
    INTERFACE_BAG.build_bag_list(self)

func _build_bag_journal_tools() -> void:
    INTERFACE_BAG.build_bag_journal_tools(self)

func _build_bag_detail() -> void:
    INTERFACE_BAG.build_bag_detail(self)

func _matches(category: String) -> bool:
    return INTERFACE_BAG.matches(self, category)

func refresh_inventory() -> void:
    INTERFACE_BAG.refresh_inventory(self)

func begin_inventory_refresh() -> void:
    INTERFACE_BAG.begin_inventory_refresh(self)

func append_inventory_item(item_id: String) -> void:
    INTERFACE_BAG.append_inventory_item(self, item_id)

func finish_inventory_refresh() -> void:
    INTERFACE_BAG.finish_inventory_refresh(self)


func _pin_item() -> void:
    INTERFACE_BAG.pin_item(self)

func _build_dialogue() -> void:
    INTERFACE_DIALOGUE.build_dialogue(self)

func show_speaker(area: Area2D) -> void:
    INTERFACE_DIALOGUE.show_speaker(self, area)


func _open_narrative_inquiries() -> void:
    INTERFACE_DIALOGUE.open_narrative_inquiries(self)

func _topic(key: String) -> void:
    INTERFACE_DIALOGUE.topic(self, key)

func _commit_wish_topic(quest: Dictionary, area: Area2D) -> bool:
    return INTERFACE_DIALOGUE.commit_wish_topic(self, quest, area)


func dialogue_reading_state(area: Area2D,line: String) -> Dictionary:
    return INTERFACE_DIALOGUE.dialogue_reading_state(self, area, line)

func forget_dialogue_reading() -> void:
    INTERFACE_DIALOGUE.forget_dialogue_reading(self)

func _restore_dialogue_scroll(key: String,value: int) -> void:
    INTERFACE_DIALOGUE.restore_dialogue_scroll(self, key, value)

func _apply_dialogue_scroll(key: String,value: int,request_generation: int) -> void:
    INTERFACE_DIALOGUE.apply_dialogue_scroll(self, key, value, request_generation)


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

func _build_settings_accessibility_tail() -> void:
    INTERFACE_SETTINGS.build_settings_accessibility_tail(self)

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
    _remap_grid=remap_grid
    _add_remap_buttons(0, int(REMAPPABLE_ACTIONS.size() / 2.0))

## Second half of the remap buttons and the status line (T03: one job each).
func _build_settings_controls_tail() -> void:
    _add_remap_buttons(int(REMAPPABLE_ACTIONS.size() / 2.0), REMAPPABLE_ACTIONS.size())
    remap_status=_label(settings,"确认键改键  ·  Esc／手柄 B 取消",Vector2(34,549),Vector2(938,24),TYPE.CAPTION,MUTED)
    if not binding_recovery_notice.is_empty():remap_status.text=binding_recovery_notice
    remap_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART

var _remap_grid: GridContainer

func _add_remap_buttons(from: int, to: int) -> void:
    var actions: Array = REMAPPABLE_ACTIONS.keys()
    for index in range(from, to):
        var action_id:=String(actions[index])
        var button:=_button(_remap_grid,"",Vector2.ZERO,Vector2(224,26),func():_begin_remap(action_id))
        button.custom_minimum_size=Vector2(224,26)
        button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
        button.add_theme_font_size_override("font_size",12)
        remap_buttons[action_id]=button

func _finish_settings() -> void:
    INTERFACE_SETTINGS.finish_settings(self)

func _install_settings_dialogs_a() -> void:
    INTERFACE_SETTINGS.install_settings_dialogs(self, 0)

func _install_settings_dialogs_b() -> void:
    INTERFACE_SETTINGS.install_settings_dialogs(self, 1)

func _finish_settings_refresh() -> void:
    INTERFACE_SETTINGS.finish_settings_refresh(self)


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


func _open_controller_comfort() -> void:
    INTERFACE_SETTINGS.open_controller_comfort(self)

func _ready() -> void:
    dialog_reading=DIALOG_READING.new()
    dialog_reading.name="DialogReadingAdapter"
    add_child(dialog_reading)

func _apply_accessibility() -> void:
    INTERFACE_SETTINGS.apply_accessibility(self)


## U06: one press puts every remappable action back to the shipped bindings.
func _reset_bindings() -> void:
    INTERFACE_SETTINGS.reset_bindings(self)

func _begin_remap(action: String) -> void:
    INTERFACE_SETTINGS.begin_remap(self, action)


func _remap_visibility_changed() -> void:
    INTERFACE_SETTINGS.remap_visibility_changed(self)

func _notification(what: int) -> void:
    if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
        INTERFACE_SETTINGS.cancel_remap(self, "窗口已失去焦点，重映射已取消；原绑定保留。")
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


func _show_build_detail(entry: Dictionary) -> void:
    INTERFACE_BUILD_REFRESH.show_build_detail(self, entry)

func _open_craft_cart() -> void:
    INTERFACE_BUILD_REFRESH.open_craft_cart(self)

func _perform_build_action(action: String, id: String, extra: Variant = -1) -> void:
    INTERFACE_BUILD_REFRESH.perform_build_action(self, action, id, extra)


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
            INTERFACE_BUILD_REFRESH.refresh_save_slots(self)
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
        INTERFACE_HUD.refresh_thread_thresholds(self, player)
        _refresh_combat_status(player)
        INTERFACE_HUD.refresh_hud_occlusion(self, delta)
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
    return INTERFACE_BAG.visible_inventory_ids(self)

func _reconcile_inventory_selection() -> String:
    return INTERFACE_BAG.reconcile_inventory_selection(self)

func move_inventory_selection(delta: int) -> void:
    INTERFACE_BAG.move_inventory_selection(self, delta)

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
    INTERFACE_HUD.refresh_combat_status(self, player)


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
    return INTERFACE_HUD.ending_status_label(self, entry)

func _hud_groups() -> Dictionary:
    return INTERFACE_HUD.hud_groups(self)

## The player, enemies and their attacks take priority over HUD chrome: a group
## with any of them behind it on screen fades until the space is clear again.

## U03: the thread meter itself says whether a heal and the active thread art
## are affordable. Dormant or empty active skill slots draw no cost mark.


func _skill_readiness(item: Dictionary, remaining: float, active: bool) -> Dictionary:
    return INTERFACE_HUD.skill_readiness(self, item, remaining, active)

func _refresh_tactical_cards(snapshot: Dictionary, build_state: Dictionary, system: Variant) -> void:
    INTERFACE_HUD.refresh_tactical_cards(self, snapshot, build_state, system)

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
    INTERFACE_DIALOGUE.remember_dialogue_reading(self)
