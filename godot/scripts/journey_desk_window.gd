extends AcceptDialog
## Shared accessible shell; each desk supplies its own model and actions.
var column: VBoxContainer
var status: Label
const LAYOUT:=preload("res://scripts/journey_window_layout.gd")
var body: ScrollContainer
var preferred_size:=Vector2i(960,610)
var last_fit:=Vector2i.ZERO
var ui_ref: WeakRef
var overlay_ref: WeakRef
var viewport_ref: WeakRef
var overlay_callback: Callable
var resize_pending:=false
var reading_pending:=false

func _ready() -> void:
    min_size = Vector2i(960, 610)
    body=ScrollContainer.new()
    body.name="JourneyWindowScroll"
    body.follow_focus=true
    body.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
    body.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
    add_child(body)
    column = VBoxContainer.new()
    column.custom_minimum_size.x = 920
    column.add_theme_constant_override("separation", 9)
    body.add_child(column)
    column.child_entered_tree.connect(_content_added)
    get_ok_button().text = "返回"
    about_to_popup.connect(_prepare_popup)

func text(parent: Node, value: String, height: float = 0.0) -> Label:
    var label := Label.new()
    label.text = value
    label.add_theme_font_size_override("font_size",21)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.custom_minimum_size = Vector2(880, height)
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(label)
    return label

func row(parent: Node) -> HBoxContainer:
    var result := HBoxContainer.new()
    result.add_theme_constant_override("separation", 8)
    parent.add_child(result)
    return result

func button(parent: Node, title_text: String, callback: Callable) -> Button:
    var result := Button.new()
    result.text = title_text
    result.custom_minimum_size.y = 32
    result.add_theme_font_size_override("font_size", 15)
    result.pressed.connect(callback)
    parent.add_child(result)
    return result

func search(parent: Node, hint: String, changed: Callable) -> LineEdit:
    var result := LineEdit.new()
    result.placeholder_text = hint
    result.max_length = 80
    result.custom_minimum_size.y = 34
    result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    result.text_changed.connect(changed)
    parent.add_child(result)
    return result

func footer() -> void:
    status = text(column, "", 38)
    status.add_theme_font_size_override("font_size", 14)

func bind_overlay(ui: Control, overlay: Control) -> void:
    ui_ref=weakref(ui)
    ui.register_text_entry_window(self)
    var previous: Control=overlay_ref.get_ref() if overlay_ref!=null else null
    if previous!=overlay:
        if is_instance_valid(previous) and overlay_callback.is_valid() and previous.visibility_changed.is_connected(overlay_callback):
            previous.visibility_changed.disconnect(overlay_callback)
        overlay_ref=weakref(overlay)
        var reference: WeakRef=weakref(self)
        var owner: WeakRef=weakref(overlay)
        overlay_callback=func():
            var window:=reference.get_ref() as Window
            var source:=owner.get_ref() as Control
            if is_instance_valid(window) and (not is_instance_valid(source) or not source.is_visible_in_tree()):window.hide()
        overlay.visibility_changed.connect(overlay_callback)
    _watch_viewport()

func _watch_viewport() -> void:
    if get_parent()==null:return
    var viewport:=get_parent().get_viewport()
    var old: Viewport=viewport_ref.get_ref() if viewport_ref!=null else null
    if old==viewport:return
    if is_instance_valid(old) and old.size_changed.is_connected(_viewport_resized):old.size_changed.disconnect(_viewport_resized)
    viewport_ref=weakref(viewport)
    viewport.size_changed.connect(_viewport_resized)

func _content_added(node: Node) -> void:
    if not node.child_entered_tree.is_connected(_content_added):node.child_entered_tree.connect(_content_added)
    for child in node.get_children():_content_added(child)
    if reading_pending:return
    reading_pending=true
    _refresh_reading.call_deferred()

func _refresh_reading() -> void:
    reading_pending=false
    if visible:_apply_reading()

func _prepare_popup() -> void:
    _watch_viewport()
    _apply_reading()
    _fit_window()

func _apply_reading() -> void:
    var ui: Control=ui_ref.get_ref() if ui_ref!=null else null
    var reading: Variant=21
    if is_instance_valid(ui):
        var preferences: Variant=ui.get("accessibility")
        if preferences is Dictionary:reading=preferences.get("subtitle_size",21)
    LAYOUT.apply_reading(column,reading)

func _viewport_resized() -> void:
    if resize_pending:return
    resize_pending=true
    _refit_visible.call_deferred()

func _refit_visible() -> void:
    resize_pending=false
    if visible:_fit_window()

func _fit_window() -> void:
    var viewport: Viewport=viewport_ref.get_ref() if viewport_ref!=null else null
    if not is_instance_valid(viewport):return
    if min_size!=last_fit:preferred_size=min_size
    var plan:=LAYOUT.frame(viewport.get_visible_rect(),preferred_size)
    if not plan.ok:return
    var rect: Rect2i=plan.rect
    last_fit=rect.size
    min_size=rect.size
    size=rect.size
    position=rect.position

func _exit_tree() -> void:
    var overlay: Control=overlay_ref.get_ref() if overlay_ref!=null else null
    if is_instance_valid(overlay) and overlay_callback.is_valid() and overlay.visibility_changed.is_connected(overlay_callback):
        overlay.visibility_changed.disconnect(overlay_callback)
    var viewport: Viewport=viewport_ref.get_ref() if viewport_ref!=null else null
    if is_instance_valid(viewport) and viewport.size_changed.is_connected(_viewport_resized):
        viewport.size_changed.disconnect(_viewport_resized)
