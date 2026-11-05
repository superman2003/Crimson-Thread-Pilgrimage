extends Node
## U01/U05: every page dialog under the shell follows the reading size, as the
## settings forms do. A dialog with one content column has its text scaled in
## place on each popup (scrolling parts give back height if it would leave the
## screen); a bare message box scales its text and buttons. Dialogs that
## already carry a journey or settings layout are left to it.
const POLICY := preload("res://scripts/journey_window_layout.gd")
const WATCHED := "dialog_reading_watched"
const MIN_HEIGHT := "dialog_reading_min_height"
const MIN_SCROLLER := 80.0
var scaled := 0
var pending_refresh := false

func _enter_tree() -> void:
    if not get_tree().node_added.is_connected(_node_added):
        get_tree().node_added.connect(_node_added)
    var pending: Array[Node] = [get_parent()]
    while not pending.is_empty():
        var node: Node = pending.pop_back()
        pending.append_array(node.get_children())
        _node_added(node)

func _exit_tree() -> void:
    if get_tree().node_added.is_connected(_node_added):
        get_tree().node_added.disconnect(_node_added)

func _node_added(node: Node) -> void:
    if not node is AcceptDialog or node.has_meta(WATCHED):
        return
    var shell := get_parent()
    if shell == null or not shell.is_ancestor_of(node):
        return
    node.set_meta(WATCHED, true)
    node.about_to_popup.connect(_popup_requested.bind(weakref(node)))

func _popup_requested(ref: WeakRef) -> void:
    # about_to_popup fires before popup() applies the authored size.
    call_deferred("_prepare", ref)

func _reading() -> int:
    var shell := get_parent()
    var value: Variant = shell.get_accessibility("subtitle_size", 21) if shell != null and shell.has_method("get_accessibility") else 21
    return POLICY.reading_size(value)

static func handled(host: AcceptDialog) -> bool:
    return host.get_node_or_null("SettingsDialogLayout") != null or host.get_node_or_null("JourneyWindowScroll") != null

static func content_column(host: AcceptDialog) -> Control:
    var controls: Array[Control] = []
    for child in host.get_children():
        if child is Control:
            controls.append(child)
    if controls.size() != 1:
        return null
    var only := controls[0]
    if only is ScrollContainer:
        var inner: Array[Control] = []
        for child in only.get_children():
            if child is Control:
                inner.append(child)
        return inner[0] if inner.size() == 1 else null
    return only

func _prepare(ref: WeakRef) -> void:
    var host: Variant = ref.get_ref()
    if not is_instance_valid(host) or host.is_queued_for_deletion() or not host.visible or handled(host):
        if is_instance_valid(host) and host.visible and not handled(host):
            _scale_bare(host)
        return
    var column := content_column(host)
    if column == null:
        _scale_bare(host)
        return
    # Scale in place. Installing the settings adapter would move or resize a
    # dialog's own scroll body (and the d-pad bridge's scrolled-to row with it);
    # text inside an existing scroll body simply scrolls.
    _watch_content(column)
    _scale_in_place(host, column)
    scaled += 1

## Rows built after the popup (search results, pages) take the same scale.
func _watch_content(node: Node) -> void:
    if not node.child_entered_tree.is_connected(_content_added):
        node.child_entered_tree.connect(_content_added)
    for child in node.get_children():
        _watch_content(child)

func _content_added(node: Node) -> void:
    _watch_content(node)
    if not pending_refresh:
        pending_refresh = true
        refresh.call_deferred()

func _scale_in_place(host: AcceptDialog, column: Control) -> void:
    for list in _scrollers(column):
        if list.has_meta(MIN_HEIGHT):
            list.custom_minimum_size.y = float(list.get_meta(MIN_HEIGHT))
    POLICY.apply_reading(column, _reading())
    _scale_bare(host)
    _fit_on_screen(host, column)

## Larger text must not push the window off screen: give back height from the
## parts that already scroll on their own, never below MIN_SCROLLER.
func _fit_on_screen(host: AcceptDialog, column: Control) -> void:
    var viewport := host.get_parent().get_viewport() if host.get_parent() != null else null
    if viewport == null:
        return
    var view: Dictionary = POLICY.frame(viewport.get_visible_rect(), Vector2i(8192, 8192))
    if not view.ok:
        return
    var budget: Vector2i = view.rect.size
    var over := int(ceil(host.get_contents_minimum_size().y)) - budget.y
    var lists := _scrollers(column)
    lists.sort_custom(func(a, b): return a.custom_minimum_size.y > b.custom_minimum_size.y)
    for list in lists:
        if over <= 0:
            break
        if not list.has_meta(MIN_HEIGHT):
            list.set_meta(MIN_HEIGHT, list.custom_minimum_size.y)
        var give := minf(float(over), list.custom_minimum_size.y - MIN_SCROLLER)
        if give > 0.0:
            list.custom_minimum_size.y -= give
            over -= int(give)
    var need := Vector2i(host.get_contents_minimum_size().ceil())
    host.size = Vector2i(maxi(host.size.x, need.x), maxi(need.y, mini(host.size.y, budget.y))).min(budget)
    var origin: Vector2i = view.rect.position
    host.position = Vector2i(clampi(host.position.x, origin.x, origin.x + budget.x - host.size.x),
        clampi(host.position.y, origin.y, origin.y + budget.y - host.size.y))

static func _scrollers(column: Control) -> Array[Control]:
    var found: Array[Control] = []
    var pending: Array[Node] = [column]
    while not pending.is_empty():
        var node: Node = pending.pop_back()
        pending.append_array(node.get_children())
        if node is ItemList or node is TextEdit or node is ScrollContainer or (node is RichTextLabel and node.scroll_active and not node.fit_content):
            if node.custom_minimum_size.y > MIN_SCROLLER or node.has_meta(MIN_HEIGHT):
                found.append(node)
    return found

func _scale_bare(host: AcceptDialog) -> void:
    var reading := _reading()
    if not String(host.dialog_text).is_empty():
        POLICY.apply_reading(host.get_label(), reading)
    POLICY.apply_reading(host.get_ok_button(), reading)
    if host is ConfirmationDialog:
        POLICY.apply_reading(host.get_cancel_button(), reading)

## Called when the reading size changes: open dialogs rescale at once.
func refresh() -> void:
    pending_refresh = false
    var pending: Array[Node] = [get_parent()]
    while not pending.is_empty():
        var node: Node = pending.pop_back()
        pending.append_array(node.get_children())
        if node is AcceptDialog and node.visible and node.has_meta(WATCHED) and not handled(node):
            var column := content_column(node)
            if column != null:
                _scale_in_place(node, column)
            else:
                _scale_bare(node)
