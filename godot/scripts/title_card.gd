extends CanvasLayer
## Launch title shown over the loaded world: continue, start over, or quit.
## Only a player launching the game sees it. Validations instantiate World
## themselves, and a headless run has nobody to press a button.
const TYPE := preload("res://scripts/ui_type_scale.gd")
const PROGRESS := preload("res://scripts/journey_progress.gd")
const CLOSE_OWNER_NAME := "PilgrimageApplicationClose"
static var shown := false
signal chosen(action: String)
var level: Node
var buttons := {}
var slot_buttons := {}
var utility_buttons := {}
var kept_audio_mode := Node.PROCESS_MODE_INHERIT
var kept_bgm_mode := Node.PROCESS_MODE_INHERIT
var holding_pause := false
var launch_card := false

static func wanted(world: Node, display: String, arguments: PackedStringArray) -> bool:
    if shown or display=="headless":return false
    for argument in arguments:
        if argument in ["--skip-title","--new-game","--script","-s"] or argument.begins_with("--save-slot=") or argument.begins_with("--quit-after"):
            return false
    return world.is_inside_tree() and world.get_tree().current_scene==world

## Called by World once its first region is published.
static func present(world: Node, has_journey: bool) -> Node:
    var arguments:=OS.get_cmdline_args();arguments.append_array(OS.get_cmdline_user_args())
    if not wanted(world,DisplayServer.get_name(),arguments):return null
    var card := open(world,has_journey)
    if card != null:
        card.launch_card = true
    return card

static func open(world: Node, has_journey: bool) -> Node:
    shown=true
    var card:=new();card.setup(world,has_journey);world.add_child(card)
    card.hold()
    return card

func setup(world: Node, has_journey: bool) -> void:
    level=world;name="TitleCard";layer=60;process_mode=Node.PROCESS_MODE_ALWAYS
    var shade:=ColorRect.new();shade.name="Shade";shade.color=Color(0.03,0.02,0.03,0.9)
    shade.set_anchors_preset(Control.PRESET_FULL_RECT);shade.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(shade)
    var centre:=CenterContainer.new();centre.set_anchors_preset(Control.PRESET_FULL_RECT);add_child(centre)
    # Same frame and typeface as the in-game pages.
    var shell: Variant=world.get("ui_shell")
    if shell is Control and is_instance_valid(shell) and shell.theme!=null:centre.theme=shell.theme
    var column:=VBoxContainer.new();column.add_theme_constant_override("separation",16);centre.add_child(column)
    var heading:=Label.new();heading.name="Heading";heading.text="绯线巡礼";heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    heading.add_theme_font_size_override("font_size",TYPE.BANNER);column.add_child(heading)
    var gap:=Control.new();gap.custom_minimum_size=Vector2(0,16);column.add_child(gap)
    for entry in [["continue","继续旅途" if has_journey else "开始旅途"],["new","新旅途"],["rush","首领连战"],["achievements","成就"],["quit","退出"]]:
        # A first launch has nothing to replace.
        if entry[0]=="new" and not has_journey:continue
        if entry[0]=="rush" and not preload("res://scripts/boss_rush.gd").available():continue
        var action:=String(entry[0])
        var button:=Button.new();button.text=entry[1];button.custom_minimum_size=Vector2(280,44)
        button.add_theme_font_size_override("font_size",TYPE.TITLE)
        button.pressed.connect(func():choose(action))
        column.add_child(button);buttons[action]=button
    if world.has_method("get_save_slots"):
        var slots_heading:=Label.new();slots_heading.text="存档槽"
        slots_heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
        slots_heading.add_theme_font_size_override("font_size",TYPE.CAPTION)
        column.add_child(slots_heading)
        var slots_row:=HBoxContainer.new();slots_row.alignment=BoxContainer.ALIGNMENT_CENTER
        slots_row.add_theme_constant_override("separation",10);column.add_child(slots_row)
        var active_slot:=int(world.get("world_slot")) if world.get("world_slot")!=null else 1
        for row_val in world.call("get_save_slots"):
            var row: Dictionary=row_val
            var slot_idx:=int(row.get("slot",1))
            var summary:=_slot_summary(row,slot_idx==active_slot)
            var slot_btn:=Button.new();slot_btn.text=summary;slot_btn.custom_minimum_size=Vector2(210,56)
            slot_btn.add_theme_font_size_override("font_size",TYPE.CAPTION)
            slot_btn.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
            slot_btn.pressed.connect(func():select_slot(slot_idx))
            slots_row.add_child(slot_btn);slot_buttons[slot_idx]=slot_btn
    if shell is Control and is_instance_valid(shell):
        var util_row:=HBoxContainer.new();util_row.alignment=BoxContainer.ALIGNMENT_CENTER
        util_row.add_theme_constant_override("separation",10);column.add_child(util_row)
        for util in [["settings","设置"],["language",_language_button_label()],["credits","来源与许可"]]:
            var uid:=String(util[0])
            var ubtn:=Button.new();ubtn.text=String(util[1]);ubtn.custom_minimum_size=Vector2(132,34)
            ubtn.add_theme_font_size_override("font_size",TYPE.CONTROL)
            ubtn.pressed.connect(func():_choose_utility(uid))
            util_row.add_child(ubtn);utility_buttons[uid]=ubtn
    buttons["continue"].call_deferred("grab_focus")

func _slot_summary(row: Dictionary, is_current: bool) -> String:
    var slot_idx:=int(row.get("slot",1))
    var prefix:="▶ 槽位 %d" % slot_idx if is_current else "槽位 %d" % slot_idx
    if not bool(row.get("exists",false)):
        return prefix + "\n尚无记录"
    if not bool(row.get("valid",false)):
        return prefix + "\n记录需恢复"
    var region_id:=String(row.get("region_id",row.get("current_region","")))
    var region:="旧旅途区域"
    if FileAccess.file_exists("res://scripts/save_inspector.gd"):
        var inspector_script: Variant=load("res://scripts/save_inspector.gd")
        if inspector_script!=null:
            region=String(inspector_script.REGION_NAMES.get(region_id,"旧旅途区域"))
    var pct:=int(row.get("completion",0))
    var secs:=int(row.get("play_seconds",0))
    if secs<=0 and not String(row.get("path","")).is_empty():
        secs=PROGRESS.recorded(String(row.get("path","")))
    return "%s\n%s · %d%% · %s" % [prefix,region,pct,PROGRESS.clock_text(secs)]

func _language_button_label() -> String:
    var startup := get_node_or_null("/root/GameLanguageSettings")
    var prefs: Variant = startup.preferences if startup != null else null
    if prefs == null and FileAccess.file_exists("res://scripts/display_dialog.gd"):
        var display_script: Variant = load("res://scripts/display_dialog.gd")
        if display_script != null:
            prefs = display_script.language
    if prefs != null and String(prefs.locale) == "en":
        return "Language: EN"
    return "语言：中文" + " / EN"

func _choose_utility(action: String) -> void:
    if is_queued_for_deletion():return
    if action=="language":
        var startup := get_node_or_null("/root/GameLanguageSettings")
        var prefs: Variant = startup.preferences if startup != null else null
        if prefs == null and FileAccess.file_exists("res://scripts/display_dialog.gd"):
            var display_script: Variant = load("res://scripts/display_dialog.gd")
            if display_script != null:
                prefs = display_script.language
        if prefs == null and FileAccess.file_exists("res://scripts/ui_language.gd"):
            var lang_script: Variant = load("res://scripts/ui_language.gd")
            if lang_script != null:
                prefs = lang_script.new()
                prefs.initialize()
        if prefs == null:
            return
        var next_locale := "en" if String(prefs.locale) != "en" else "zh_CN"
        prefs.choose(next_locale)
        if utility_buttons.has("language"):
            utility_buttons["language"].text = _language_button_label()
        return
    if action=="settings":
        release()
        if is_instance_valid(level) and level.has_method("_toggle_audio_settings"):
            level._toggle_audio_settings()
        chosen.emit("settings");queue_free()
        return
    if action=="credits":
        release()
        if is_instance_valid(level) and level.has_method("_toggle_audio_settings"):
            level._toggle_audio_settings()
            var shell: Variant = level.get("ui_shell")
            if shell is Control and is_instance_valid(shell):
                var desk: Node = (shell as Control).get_node_or_null("CreditsReader")
                if desk != null and desk.has_method("open"):
                    desk.call_deferred("open")
        chosen.emit("credits");queue_free()

func select_slot(slot_idx: int) -> void:
    if is_queued_for_deletion():return
    var active_slot:=int(level.get("world_slot")) if is_instance_valid(level) and level.get("world_slot")!=null else 1
    if slot_idx == active_slot:
        choose("continue");return
    release()
    if is_instance_valid(level) and level.has_method("select_save_slot"):
        var skip_save: bool = launch_card or level.get("world_save_blocked") == true
        var switched := false
        if skip_save:
            switched = bool(level.call("select_save_slot", slot_idx, true))
        else:
            switched = bool(level.select_save_slot(slot_idx))
        if not switched:
            # Target slot damaged or blocked; open Settings so player sees recovery UI.
            if level.has_method("_toggle_audio_settings"):
                level._toggle_audio_settings()
    chosen.emit("slot_%d" % slot_idx);queue_free()

## The world waits behind the card: enemies cannot reach a player who has not
## pressed anything yet. Music keeps playing.
func hold() -> void:
    if holding_pause:return
    if is_instance_valid(level):
        var director: Variant=level.get("audio_director")
        if director is Node and is_instance_valid(director):
            kept_audio_mode=director.process_mode;director.process_mode=Node.PROCESS_MODE_ALWAYS
        var bgm: Variant=level.get("bgm_player")
        if bgm is Node and is_instance_valid(bgm):
            kept_bgm_mode=bgm.process_mode;bgm.process_mode=Node.PROCESS_MODE_ALWAYS
    holding_pause=true
    if get_tree()!=null:
        get_tree().paused=true

func release() -> void:
    if not holding_pause:return
    holding_pause=false
    if get_tree()!=null:
        get_tree().paused=false
    if is_instance_valid(level):
        level.set_meta("pause_resume_physics_frame", Engine.get_physics_frames())
        var director: Variant=level.get("audio_director")
        if director is Node and is_instance_valid(director):director.process_mode=kept_audio_mode
        var bgm: Variant=level.get("bgm_player")
        if bgm is Node and is_instance_valid(bgm):bgm.process_mode=kept_bgm_mode
    for action_name in ["jump", "dash"]:
        if InputMap.has_action(action_name):
            Input.action_release(action_name)

func _exit_tree() -> void:
    if holding_pause:
        release()

func choose(action: String) -> void:
    if is_queued_for_deletion():return
    if action=="quit":
        chosen.emit(action)
        var tree:=get_tree()
        if tree!=null:
            var owner:=tree.root.get_node_or_null(NodePath(CLOSE_OWNER_NAME))
            if owner!=null:
                if owner.has_method("request_close"):
                    owner.call("request_close", true)
                else:
                    tree.root.close_requested.emit()
            else:
                tree.quit()
        return
    if action=="achievements":
        show_achievements();return
    release()
    if action=="rush":
        chosen.emit(action);queue_free()
        preload("res://scripts/boss_rush.gd").new().begin(level)
        return
    if action=="new":
        # Same confirmation and backup as F9; cancelling returns to the journey.
        var dialog: Variant=level.get("new_journey_dialog")
        if dialog is ConfirmationDialog and is_instance_valid(dialog):
            dialog.popup_centered();level.set("active_overlay","new_journey")
            if level.has_method("_sync_ui_input_lock"):level.call("_sync_ui_input_lock")
    chosen.emit(action);queue_free()

## Earned and unearned alike; the world stays held behind the card.
func show_achievements() -> void:
    var window:=get_node_or_null("Achievements") as AcceptDialog
    if window==null:
        window=AcceptDialog.new();window.name="Achievements";window.title="成就";window.min_size=Vector2i(460,420)
        window.process_mode=Node.PROCESS_MODE_ALWAYS
        var shell: Variant=level.get("ui_shell") if is_instance_valid(level) else null
        if shell is Control and is_instance_valid(shell) and shell.theme!=null:
            window.theme=shell.theme
        add_child(window)
        var column:=VBoxContainer.new();window.add_child(column)
        var list:=ItemList.new();list.name="List";list.custom_minimum_size=Vector2(420,340);column.add_child(list)
        if FileAccess.file_exists("res://scripts/settings_dialog_layout.gd"):
            var layout_script: Variant=load("res://scripts/settings_dialog_layout.gd")
            if layout_script!=null:
                layout_script.install(window,column,Vector2i(460,420))
        window.visibility_changed.connect(func():
            if not window.visible and buttons.has("achievements"):buttons["achievements"].grab_focus())
    var list:=window.find_child("List",true,false) as ItemList
    preload("res://scripts/achievements.gd").fill(list)
    window.popup_centered();list.grab_focus()
