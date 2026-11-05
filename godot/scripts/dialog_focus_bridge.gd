extends RefCounted
## U02/U06: Godot searches d-pad focus neighbours only inside one top-level
## control of a Window, and skips list items clipped by a ScrollContainer. A
## dialog's OK/Cancel row and its content are separate top-level controls, so a
## dialog that opens on its (safe) Cancel button left a controller unable to
## reach any option above it, and long lists stopped at their visible end.
## Whenever a dialog is shown or its focus moves (content is often rebuilt),
## fill only the missing links; authored neighbours always keep priority.
const OWN_TOP := "dialog_bridge_top"
const OWN_BOTTOM := "dialog_bridge_bottom"
const PENDING := "dialog_bridge_pending"
const RELINK := "dialog_bridge_relink"

static func install(dialog: AcceptDialog) -> void:
    if dialog.has_meta("dialog_focus_bridge"):
        return
    dialog.set_meta("dialog_focus_bridge", true)
    var reference: WeakRef = weakref(dialog)
    # One deferred pass per frame; the dialog may be freed before it runs.
    var run := func():
        var owner := reference.get_ref() as AcceptDialog
        if is_instance_valid(owner):
            owner.remove_meta(PENDING)
            link(owner)
    var relink := func(_control: Variant = null):
        var owner := reference.get_ref() as AcceptDialog
        if is_instance_valid(owner) and owner.visible and not owner.has_meta(PENDING):
            owner.set_meta(PENDING, true)
            run.call_deferred()
    dialog.set_meta(RELINK, relink)
    dialog.visibility_changed.connect(relink)
    dialog.gui_focus_changed.connect(relink)
    # Layout adapters resize a dialog after it opens; positions change then.
    dialog.size_changed.connect(relink)

static func row_buttons(dialog: AcceptDialog) -> Array:
    var result: Array = []
    var row := dialog.get_ok_button().get_parent()
    for child in row.get_children(true):
        if child is BaseButton and child.is_visible_in_tree() and child.focus_mode != Control.FOCUS_NONE:
            result.append(child)
    return result

## Focusable visible controls under node, outside the button row and nested
## windows. Disabled buttons are included: the d-pad can still land on them.
static func content_controls(node: Node, row: Node, result: Array) -> Array:
    for child in node.get_children():
        if child is Window or child == row:
            continue
        if child is Control:
            if not child.is_visible_in_tree():
                continue
            if child is SpinBox:
                # Its editable field is an internal child and owns the focus.
                result.append(child.get_line_edit())
            elif child.focus_mode != Control.FOCUS_NONE:
                result.append(child)
        content_controls(child, row, result)
    return result

static func _usable(control: Control) -> bool:
    return not (control is BaseButton and control.disabled)

static func _claim(control: Control, property: String, meta: String, target: Control) -> void:
    control.set(property, control.get_path_to(target))
    control.set_meta(meta, true)

static func _release(control: Control) -> void:
    if control.has_meta(OWN_TOP):
        control.focus_neighbor_top = NodePath()
        control.remove_meta(OWN_TOP)
    if control.has_meta(OWN_BOTTOM):
        control.focus_neighbor_bottom = NodePath()
        control.remove_meta(OWN_BOTTOM)

static func link(dialog: AcceptDialog) -> Dictionary:
    if not is_instance_valid(dialog) or not dialog.visible:
        return {}
    var buttons := row_buttons(dialog)
    var row := dialog.get_ok_button().get_parent()
    var content := content_controls(dialog, row, [])
    # Links depend on positions: re-run whenever a container re-sorts.
    var relink: Variant = dialog.get_meta(RELINK, null)
    if relink is Callable:
        for container in dialog.find_children("*", "Container", true, false):
            if container.get_window() == dialog and not container.sort_children.is_connected(relink):
                container.sort_children.connect(relink)
    for control in content + buttons:
        _release(control)
    var usable: Array = content.filter(_usable)
    if buttons.is_empty() or usable.is_empty():
        return {"buttons": buttons.size(), "content": content.size()}
    # Lists: chain consecutive stacked items so clipped ones stay reachable.
    var chained := 0
    for scroll in dialog.find_children("*", "ScrollContainer", true, false):
        if scroll.get_window() != dialog or not scroll.is_visible_in_tree():
            continue
        var items := content_controls(scroll, row, [])
        # The chain reaches clipped rows; the view must follow the focus there.
        if items.size() > 1:
            scroll.follow_focus = true
        for index in range(items.size() - 1):
            var above: Control = items[index]
            var below: Control = items[index + 1]
            if below.get_global_rect().position.y < above.get_global_rect().end.y - 1.0:
                continue
            if above.focus_neighbor_bottom.is_empty():
                _claim(above, "focus_neighbor_bottom", OWN_BOTTOM, below)
                chained += 1
            if below.focus_neighbor_top.is_empty():
                _claim(below, "focus_neighbor_top", OWN_TOP, above)
    var lowest: Control = usable[0]
    for control in usable:
        var rect: Rect2 = control.get_global_rect()
        var best: Rect2 = lowest.get_global_rect()
        if rect.end.y > best.end.y + 0.5 or (absf(rect.end.y - best.end.y) <= 0.5 and rect.position.x < best.position.x):
            lowest = control
    var focus := dialog.gui_get_focus_owner()
    # Some dialogs hide OK and keep only their own added buttons.
    var default_button: Control = buttons[0]
    if focus in buttons:
        default_button = focus
    elif dialog is ConfirmationDialog and dialog.get_cancel_button() in buttons:
        default_button = dialog.get_cancel_button()
    elif dialog.get_ok_button() in buttons:
        default_button = dialog.get_ok_button()
    for button in buttons:
        if button.focus_neighbor_top.is_empty():
            _claim(button, "focus_neighbor_top", OWN_TOP, lowest)
    var linked := 0
    for control in content:
        if not control.focus_neighbor_bottom.is_empty():
            continue
        # Clipped scroll content can get a "bottom" neighbour that is above it.
        var below: Control = control.find_valid_focus_neighbor(SIDE_BOTTOM)
        if below == null or below.get_global_rect().position.y < control.get_global_rect().end.y - 1.0:
            _claim(control, "focus_neighbor_bottom", OWN_BOTTOM, default_button)
            linked += 1
    return {"buttons": buttons.size(), "content": content.size(), "lowest": lowest, "default": default_button, "linked": linked, "chained": chained}
