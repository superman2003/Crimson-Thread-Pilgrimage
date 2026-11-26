extends Node
## One settings entry. Features own separate auxiliary files and production paths.
const CONTEXT := preload("res://journey/core/context.gd")
const UI := preload("res://journey/core/ui.gd")
# export-discovery: res://journey/features/*.gd
const FEATURE_PATH := "res://journey/features"
# These record live input or world state from the first observation tick.
const OBSERVERS := [preload("res://journey/features/caseboard.gd"),
    preload("res://journey/features/chronicle.gd"), preload("res://journey/features/input_diagnostics.gd"),
    preload("res://journey/features/supplies.gd"), preload("res://journey/features/trajectory.gd")]
var feature_scripts: Dictionary = {}
var pending_paths: Array[String] = []
var feature_job := preload("res://scripts/background_resource_job.gd").new()
var loading_feature := false
var discard_loading_feature := false
var context: RefCounted
var features: Dictionary = {}
var selected := "chronicle"
var owner_ref: WeakRef
var bound_ui_ref: WeakRef
var entry: Button
var dialog: Window
var content: VBoxContainer
var menu: VBoxContainer
var status: Label
var elapsed := 0.0
var refreshing := false
var activated := false
var background_recording := false

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

func _has_active_session() -> bool:
    for feature in features.values():
        if feature == null:
            continue
        var live: Variant = feature.get("live")
        if live is Dictionary and not live.is_empty():
            return true
        if live is Object and is_instance_valid(live):
            return true
        var active_state: Variant = feature.get("active")
        if active_state is Dictionary and not active_state.is_empty():
            return true
        var session: Variant = feature.get("session")
        if session is Object and is_instance_valid(session):
            return true
    return false

func _should_tick_observers() -> bool:
    if not activated:
        return false
    if is_instance_valid(dialog) and dialog.visible:
        return true
    return background_recording or _has_active_session()

func _process(delta: float) -> void:
    if not activated:
        # Idle fast-path during normal gameplay: zero 30-module preloads, zero
        # 10 Hz deep copies, and zero synchronous auxiliary disk writes.
        _rebind_ui()
        var idle_owner := _owner()
        if idle_owner == null:
            _retire_ui()
            _discover_world()
        return
    # Region arrival can replace the UI shell; rebind the entry on the next
    # frame rather than the next 0.1 s observation tick.
    _rebind_ui()
    var dialog_open: bool = is_instance_valid(dialog) and dialog.visible
    if dialog_open:
        if not pending_paths.is_empty() or loading_feature:
            _warm_feature()
    elif loading_feature and feature_job.ready():
        feature_job.take()
        loading_feature = false
        discard_loading_feature = false
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
    if context != null and context.store.scope != String(owner.world_save_path).sha256_text():
        _retire()
        return
    if not _should_tick_observers():
        return
    if context == null:
        _attach(owner)
    if context == null:
        return
    _rebind_ui()
    var snapshot: Dictionary = context.update()
    for feature in features.values():
        feature.tick(snapshot, step)
    if is_instance_valid(dialog) and dialog.visible and owner.active_overlay != "settings":
        close()

func _rebind_ui() -> void:
    var owner := _owner()
    if owner == null or not bool(owner.get("initial_region_ready")) or not is_instance_valid(owner.get("ui_shell")):
        return
    bind_region_ui(owner)

func bind_region_ui(owner: Node) -> void:
    # Both arrival paths call this from the final HUD construction job, before
    # publishing a region. Entry presence must not depend on a later frame.
    if _owner() != owner:
        _retire()
        owner_ref = weakref(owner)
    if not is_instance_valid(entry) or bound_ui_ref == null or bound_ui_ref.get_ref() != owner.ui_shell:
        _retire_ui()
        _attach_ui(owner)

func _discover_features() -> void:
    for script: Script in OBSERVERS:
        feature_scripts[script.resource_path] = script
    var files := DirAccess.get_files_at(FEATURE_PATH)
    files.sort()
    for file in files:
        var name := String(file).trim_suffix(".remap")
        var path := FEATURE_PATH.path_join(name)
        if name.ends_with(".gd") and not feature_scripts.has(path) and not pending_paths.has(path):
            pending_paths.append(path)

func _warm_feature() -> void:
    var script: Script
    if loading_feature:
        if not feature_job.ready():
            return
        script = feature_job.take().get("resource") as Script
        loading_feature = false
        if discard_loading_feature:
            discard_loading_feature = false
            return
    elif not pending_paths.is_empty():
        var path: String = pending_paths.pop_front()
        if feature_job.start(path, "GDScript") == OK:
            loading_feature = true
            return
        script = load(path) as Script
    if script != null:
        feature_scripts[script.resource_path] = script
        if context != null and context.level() != null:
            _install_feature(script)
    if pending_paths.is_empty() and not loading_feature and is_instance_valid(dialog) and dialog.visible:
        _refresh_menu()

func _install_feature(script: Script) -> void:
    var feature: RefCounted = script.new()
    if not feature.has_method("descriptor") or not feature.has_method("setup"):
        return
    var id := String(feature.descriptor().get("id", ""))
    if not id.is_empty() and not features.has(id):
        feature.setup(context)
        features[id] = feature

func _attach(owner: Node) -> void:
    context = CONTEXT.new()
    context.bind(owner)
    context.refresh_requested.connect(refresh)
    context.message_requested.connect(_message)
    context.close_requested.connect(close)
    features.clear()
    for script: Script in feature_scripts.values():
        _install_feature(script)
    bind_region_ui(owner)

func _attach_ui(owner: Node) -> void:
    bound_ui_ref = weakref(owner.ui_shell)
    entry = owner.ui_shell._button(owner.ui_shell.settings, "旅途工作台", Vector2(650, 60), Vector2(320, 30), open)
    entry.name = "JourneyWorkbenchEntry"
    entry.tooltip_text = "旅途记录、规划与只读分析；辅助记录按存档槽隔离。"
    # The entry can be rebuilt on the same shell; connect its settings once.
    if not owner.ui_shell.settings.visibility_changed.is_connected(_settings_visibility):
        owner.ui_shell.settings.visibility_changed.connect(_settings_visibility)

func _settings_visibility() -> void:
    var owner := _owner()
    if owner == null or not is_instance_valid(owner.ui_shell) or not owner.ui_shell.settings.visible:
        close()

func open() -> void:
    var owner := _owner()
    if owner == null or owner.active_overlay != "settings":
        return
    activated = true
    discard_loading_feature = false
    _discover_features()
    # The entry is bound during HUD construction; the context otherwise waits
    # for the next observation tick, so an early press would do nothing.
    if context == null and bool(owner.get("initial_region_ready")):
        _attach(owner)
    if context == null:
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
    UI.toggle(heading, "探索时后台记录", background_recording, func(value: bool): background_recording = value)
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
    _refresh_menu()
    UI.clear(content)
    if features.has(selected):
        features[selected].draw(content)
    else:
        UI.hint(content, "尚无可用的工作台模块。")

func _refresh_menu() -> void:
    var focus := menu.get_viewport().gui_get_focus_owner()
    var focused_id := String(focus.get_meta("feature_id", "")) if is_instance_valid(focus) and focus.get_parent() == menu else ""
    UI.clear(menu)
    var keys := features.keys()
    keys.sort()
    if not features.has(selected) and not keys.is_empty():
        selected = String(keys[0])
    for id in keys:
        var feature: RefCounted = features[id]
        var button := UI.button(menu, String(feature.descriptor().name), _select.bind(String(id)))
        button.set_meta("feature_id", id)
        button.tooltip_text = String(feature.descriptor().get("summary", ""))
        button.button_pressed = id == selected
        if id == focused_id: button.grab_focus()

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
    pending_paths.clear()
    if loading_feature:
        if feature_job.ready():
            feature_job.take()
            loading_feature = false
            discard_loading_feature = false
        else:
            discard_loading_feature = true
    if is_instance_valid(dialog):
        dialog.hide()
    for feature in features.values():
        feature.release()
    if is_instance_valid(entry) and entry.is_visible_in_tree():
        entry.grab_focus()

func _retire_ui() -> void:
    close()
    if is_instance_valid(dialog):
        dialog.queue_free()
    if is_instance_valid(entry):
        entry.queue_free()
    dialog = null
    entry = null
    content = null
    menu = null
    status = null
    bound_ui_ref = null

func _retire() -> void:
    _retire_ui()
    activated = false
    pending_paths.clear()
    discard_loading_feature = false
    for feature in features.values():
        feature.shutdown()
    features.clear()
    context = null

func _exit_tree() -> void:
    feature_job.shutdown()
    _retire()
