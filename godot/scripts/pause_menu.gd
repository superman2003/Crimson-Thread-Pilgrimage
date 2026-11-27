extends CanvasLayer
## System pause menu opened by Escape during active exploration or from UI
## shortcuts. Pauses the SceneTree without toggling `ui_input_locked`, so an
## active heal channel freezes cleanly instead of cancelling and wasting energy.
const TYPE := preload("res://scripts/ui_type_scale.gd")
const TITLE_CARD := preload("res://scripts/title_card.gd")
const CLOSE_OWNER_NAME := "PilgrimageApplicationClose"
const NODE_NAME := "PauseMenu"
static var closed_frame := -1
static var closed_physics_frame := -1
signal closed(action: String)
var level: Node
var buttons: Dictionary = {}
var status_label: Label
var pending_discard_action := ""
var kept_audio_mode := Node.PROCESS_MODE_INHERIT
var kept_bgm_mode := Node.PROCESS_MODE_INHERIT
var holding_pause := false
var opened_frame := -1

static func is_open(world: Node) -> bool:
    if not is_instance_valid(world):
        return false
    var existing := world.get_node_or_null(NODE_NAME)
    return existing != null and not existing.is_queued_for_deletion()

static func toggle(world: Node) -> Node:
    if not is_instance_valid(world):
        return null
    var existing := world.get_node_or_null(NODE_NAME)
    if existing != null and not existing.is_queued_for_deletion():
        existing.choose("resume")
        return null
    return open(world)

static func open(world: Node) -> Node:
    if not is_instance_valid(world) or not world.is_inside_tree():
        return null
    if is_open(world):
        return world.get_node(NODE_NAME)
    var menu := new()
    menu.setup(world)
    world.add_child(menu)
    menu.hold()
    return menu

func setup(world: Node) -> void:
    level = world
    name = NODE_NAME
    layer = 59
    process_mode = Node.PROCESS_MODE_ALWAYS
    opened_frame = Engine.get_process_frames()
    var shade := ColorRect.new()
    shade.name = "Shade"
    shade.color = Color(0.02, 0.025, 0.03, 0.84)
    shade.set_anchors_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(shade)
    var centre := CenterContainer.new()
    centre.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(centre)
    var shell: Variant = world.get("ui_shell")
    if shell is Control and is_instance_valid(shell) and shell.theme != null:
        centre.theme = shell.theme
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(360, 0)
    centre.add_child(panel)
    var margin := MarginContainer.new()
    for side in ["left", "top", "right", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 24)
    panel.add_child(margin)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 12)
    margin.add_child(column)
    var heading := Label.new()
    heading.name = "Heading"
    heading.text = "暂停"
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    heading.add_theme_font_size_override("font_size", TYPE.BANNER)
    column.add_child(heading)
    var entries := [
        ["resume", "继续旅途"],
        ["settings", "设置与无障碍"],
        ["new_journey", "新旅途"],
        ["title", "保存并返回标题"],
        ["quit", "保存并退出"],
    ]
    var world_mode: bool = world.get("world_mode") == true
    var has_new_dialog: bool = world.get("new_journey_dialog") is ConfirmationDialog and is_instance_valid(world.get("new_journey_dialog"))
    for entry in entries:
        var action := String(entry[0])
        if action == "new_journey" and (not world_mode or not has_new_dialog):
            continue
        if action == "title" and not world_mode:
            continue
        var button := Button.new()
        button.text = String(entry[1])
        button.custom_minimum_size = Vector2(280, 42)
        button.add_theme_font_size_override("font_size", TYPE.TITLE)
        button.pressed.connect(func(): choose(action))
        column.add_child(button)
        buttons[action] = button
    status_label = Label.new()
    status_label.name = "SaveStatus"
    status_label.visible = false
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.add_theme_font_size_override("font_size", TYPE.CAPTION)
    if shell is Control and is_instance_valid(shell) and shell.get("RED") is Color:
        status_label.add_theme_color_override("font_color", shell.get("RED"))
    column.add_child(status_label)
    var discard_btn := Button.new()
    discard_btn.name = "DiscardLeaveButton"
    discard_btn.visible = false
    discard_btn.custom_minimum_size = Vector2(280, 38)
    discard_btn.add_theme_font_size_override("font_size", TYPE.CONTROL)
    discard_btn.pressed.connect(func(): choose("discard_leave"))
    column.add_child(discard_btn)
    buttons["discard_leave"] = discard_btn
    var hint := Label.new()
    hint.text = "Esc / 手柄 B 继续"
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.add_theme_font_size_override("font_size", TYPE.CAPTION)
    column.add_child(hint)
    buttons["resume"].call_deferred("grab_focus")

func hold() -> void:
    if holding_pause:
        return
    if is_instance_valid(level):
        var director: Variant = level.get("audio_director")
        if director is Node and is_instance_valid(director):
            kept_audio_mode = director.process_mode
            director.process_mode = Node.PROCESS_MODE_ALWAYS
        var bgm: Variant = level.get("bgm_player")
        if bgm is Node and is_instance_valid(bgm):
            kept_bgm_mode = bgm.process_mode
            bgm.process_mode = Node.PROCESS_MODE_ALWAYS
    holding_pause = true
    if get_tree() != null:
        get_tree().paused = true

func release() -> void:
    if not holding_pause:
        return
    holding_pause = false
    if get_tree() != null:
        get_tree().paused = false
    if is_instance_valid(level):
        var director: Variant = level.get("audio_director")
        if director is Node and is_instance_valid(director):
            director.process_mode = kept_audio_mode
        var bgm: Variant = level.get("bgm_player")
        if bgm is Node and is_instance_valid(bgm):
            bgm.process_mode = kept_bgm_mode

func _exit_tree() -> void:
    if holding_pause:
        release()

func _mark_closed() -> void:
    closed_frame = Engine.get_process_frames()
    closed_physics_frame = Engine.get_physics_frames()
    if is_instance_valid(level):
        level.set_meta("pause_suppress_frame", closed_frame)
        level.set_meta("pause_resume_physics_frame", closed_physics_frame)
    for action_name in ["close_overlay", "dash", "jump"]:
        if InputMap.has_action(action_name):
            Input.action_release(action_name)
    if name == NODE_NAME:
        name = "PauseMenuClosing"

func _input(event: InputEvent) -> void:
    if is_queued_for_deletion() or Engine.get_process_frames() == opened_frame:
        return
    var cancel_key: bool = event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE)
    var cancel_pad: bool = event is InputEventJoypadButton and event.pressed and (event.button_index == JOY_BUTTON_B or event.button_index == JOY_BUTTON_START)
    if cancel_key or cancel_pad:
        get_viewport().set_input_as_handled()
        choose("resume")

func _save_if_ready() -> bool:
    if not is_instance_valid(level):
        return true
    if level.has_method("_save_world") and level.get("world_mode") == true and level.get("initial_region_ready") == true and level.get("world_loading") != true and level.get("chapter_transitioning") != true:
        return level._save_world() == true
    return true

func _show_save_failure(action: String) -> void:
    pending_discard_action = action
    if is_instance_valid(status_label):
        status_label.text = "保存失败，未退出。请检查磁盘空间或权限后重试。" if action == "quit" else "保存失败，未返回标题。请检查磁盘空间或权限后重试。"
        status_label.visible = true
    if buttons.has("discard_leave") and is_instance_valid(buttons["discard_leave"]):
        var btn: Button = buttons["discard_leave"]
        btn.text = "不保存直接退出" if action == "quit" else "不保存返回标题"
        btn.visible = true
        btn.grab_focus()

func _leave_world(action: String, discarded: bool = false) -> void:
    if action == "quit":
        _mark_closed()
        release()
        closed.emit(action)
        queue_free()
        var tree := get_tree()
        if tree != null:
            var owner := tree.root.get_node_or_null(NodePath(CLOSE_OWNER_NAME))
            if owner != null:
                if owner.has_method("request_close"):
                    owner.call("request_close", true)
                else:
                    tree.root.close_requested.emit()
            else:
                tree.quit()
        return
    if action == "title":
        _mark_closed()
        release()
        closed.emit(action)
        queue_free()
        if is_instance_valid(level):
            var has_journey := true
            if discarded:
                var save_path := String(level.get("world_save_path")) if level.get("world_save_path") != null else ""
                if not save_path.is_empty():
                    has_journey = FileAccess.file_exists(save_path)
            TITLE_CARD.open(level, has_journey)

func choose(action: String) -> void:
    if is_queued_for_deletion():
        return
    if action == "discard_leave":
        if pending_discard_action == "quit" or pending_discard_action == "title":
            _leave_world(pending_discard_action, true)
        return
    if action == "quit" or action == "title":
        if not _save_if_ready():
            _show_save_failure(action)
            return
        _leave_world(action, false)
        return
    _mark_closed()
    release()
    if action == "settings" and is_instance_valid(level) and level.has_method("_toggle_audio_settings"):
        level._toggle_audio_settings()
    elif action == "new_journey" and is_instance_valid(level):
        var dialog: Variant = level.get("new_journey_dialog")
        if dialog is ConfirmationDialog and is_instance_valid(dialog):
            dialog.popup_centered()
            level.set("active_overlay", "new_journey")
            if level.has_method("_sync_ui_input_lock"):
                level.call("_sync_ui_input_lock")
    closed.emit(action)
    queue_free()
