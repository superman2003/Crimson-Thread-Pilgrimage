extends Node
## One settings entry. Features own separate auxiliary files and production paths.
const CONTEXT := preload("res://journey/core/context.gd")
const UI := preload("res://journey/core/ui.gd")
# export-discovery: res://journey/features/*.gd
const FEATURE_PATH := "res://journey/features"
var context: RefCounted
var features: Dictionary = {}
var selected := "chronicle"
var owner_ref: WeakRef
var entry: Button
var dialog: Window
var content: VBoxContainer
var menu: VBoxContainer
var status: Label
var elapsed := 0.0
var refreshing := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    get_tree().node_added.connect(_consider)
    call_deferred("_discover_world")

func _consider(node: Node) -> void:
    if node.get_script() != null and node.get_script().resource_path == "res://scripts/main_level.gd":
        call_deferred("_discover_world")

func _discover_world() -> void:
    if is_instance_valid(_owner()):
        return
    for node in get_tree().root.get_children():
        if node.get_script() != null and node.get_script().resource_path == "res://scripts/main_level.gd" and bool(node.get("world_mode")):
            owner_ref = weakref(node)
            return

func _owner() -> Node:
    var node: Node = owner_ref.get_ref() if owner_ref != null else null
    return node if is_instance_valid(node) and not node.is_queued_for_deletion() else null

func _process(delta: float) -> void:
    elapsed += delta
    if elapsed < 0.1:
        return
    var step := elapsed
    elapsed = 0.0
    var owner := _owner()
    if owner == null:
        _retire()
        _discover_world()
        return
    if not bool(owner.get("initial_region_ready")) or not is_instance_valid(owner.get("ui_shell")):
        return
    if context == null or context.store.scope != String(owner.world_save_path).sha256_text():
        _retire()
        _attach(owner)
    if context == null:
        return
    var snapshot: Dictionary = context.update()
    for feature in features.values():
        feature.tick(snapshot, step)
    if is_instance_valid(entry):
        entry.visible = owner.active_overlay == "settings" and not bool(owner.world_loading)
    if is_instance_valid(dialog) and dialog.visible and owner.active_overlay != "settings":
        close()

func _attach(owner: Node) -> void:
    context = CONTEXT.new()
    context.bind(owner)
    context.refresh_requested.connect(refresh)
    context.message_requested.connect(_message)
    context.close_requested.connect(close)
    features.clear()
    var files := DirAccess.get_files_at(FEATURE_PATH)
    files.sort()
    for file in files:
        var name := String(file).trim_suffix(".remap")
        if not name.ends_with(".gd"):
            continue
        var script: Script = load(FEATURE_PATH.path_join(name))
        if script == null:
            continue
        var feature: RefCounted = script.new()
        if not feature.has_method("descriptor") or not feature.has_method("setup"):
            continue
        var id := String(feature.descriptor().get("id", ""))
        if id.is_empty() or features.has(id):
            continue
        feature.setup(context)
        features[id] = feature
    entry = owner.ui_shell._button(owner.ui_shell.settings, "旅途工作台", Vector2(650, 60), Vector2(320, 30), open)
    entry.name = "JourneyWorkbenchEntry"
    entry.tooltip_text = "旅途记录、规划与只读分析；辅助记录按存档槽隔离。"
    owner.ui_shell.settings.visibility_changed.connect(_settings_visibility)

func _settings_visibility() -> void:
    var owner := _owner()
    if owner == null or not is_instance_valid(owner.ui_shell) or not owner.ui_shell.settings.visible:
        close()

func open() -> void:
    var owner := _owner()
    if owner == null or owner.active_overlay != "settings" or context == null:
        return
    context.update()
    if not is_instance_valid(dialog):
        _build_dialog(owner)
    refresh()
    dialog.popup_centered_clamped(Vector2i(1100, 650), 0.94)

func _build_dialog(owner: Node) -> void:
    dialog = Window.new()
    dialog.name = "JourneyWorkbenchWindow"
    dialog.title = "巡礼工作台"
    dialog.min_size = Vector2i(760, 480)
    dialog.exclusive = true
    dialog.transient = true
    dialog.wrap_controls = false
    dialog.close_requested.connect(close)
    owner.ui_shell.settings.add_child(dialog)
    owner.ui_shell.register_text_entry_window(dialog)
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side in ["left", "top", "right", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 14)
    dialog.add_child(margin)
    var outer := UI.column(margin, true)
    var heading := UI.row(outer)
    UI.label(heading, "巡礼工作台", true)
    UI.button(heading, "返回设置", close)
    var split := HSplitContainer.new()
    split.size_flags_vertical = Control.SIZE_EXPAND_FILL
    outer.add_child(split)
    var navigation := ScrollContainer.new()
    navigation.custom_minimum_size.x = 200
    navigation.follow_focus = true
    split.add_child(navigation)
    menu = UI.column(navigation)
    content = UI.scroll(split)
    content.custom_minimum_size.x = 510
    status = UI.hint(outer, "辅助记录与游戏主档分开；分析页不会消耗物资。")
    dialog.window_input.connect(_window_input)

func _window_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        var focus := dialog.gui_get_focus_owner()
        if not focus is LineEdit and not focus is TextEdit:
            close()
            dialog.set_input_as_handled()

func refresh() -> void:
    if refreshing or not is_instance_valid(content):
        return
    refreshing = true
    call_deferred("_refresh_now")

func _refresh_now() -> void:
    refreshing = false
    if not is_instance_valid(content) or context == null:
        return
    UI.clear(menu)
    UI.clear(content)
    var keys := features.keys()
    keys.sort()
    if not features.has(selected) and not keys.is_empty():
        selected = String(keys[0])
    for id in keys:
        var feature: RefCounted = features[id]
        var button := UI.button(menu, String(feature.descriptor().name), _select.bind(String(id)))
        button.tooltip_text = String(feature.descriptor().get("summary", ""))
        button.button_pressed = id == selected
    if features.has(selected):
        features[selected].draw(content)
    else:
        UI.hint(content, "尚无可用的工作台模块。")

func _select(id: String) -> void:
    if features.has(selected):
        features[selected].release()
    selected = id
    context.update()
    refresh()

func _message(message: String) -> void:
    if is_instance_valid(status):
        status.text = message

func close() -> void:
    if is_instance_valid(dialog):
        dialog.hide()
    for feature in features.values():
        feature.release()
    if is_instance_valid(entry) and entry.is_visible_in_tree():
        entry.grab_focus()

func _retire() -> void:
    close()
    for feature in features.values():
        feature.shutdown()
    if is_instance_valid(dialog):
        dialog.queue_free()
    if is_instance_valid(entry):
        entry.queue_free()
    dialog = null
    entry = null
    content = null
    menu = null
    features.clear()
    context = null

func _exit_tree() -> void:
    _retire()
