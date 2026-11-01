extends RefCounted
## U05: a controller had no way to scroll long text (journal bodies, item
## descriptions, desk detail panes, credits); only keyboard Page keys existed.
## While an overlay or dialog is open the right stick, unbound in play, scrolls
## the reading pane of the topmost context: the focused control's scrollable
## ancestor if any, otherwise that context's largest scrollable pane.
const SPEED := 900.0

## Strongest right-stick Y over connected pads, rescaled outside the deadzone.
static func stick_axis(deadzone: float) -> float:
    var strongest := 0.0
    for device in Input.get_connected_joypads():
        var value := Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y)
        if absf(value) > absf(strongest):
            strongest = value
    return rescale(strongest, deadzone)

static func rescale(value: float, deadzone: float) -> float:
    if not is_finite(value):
        return 0.0
    deadzone = clampf(deadzone, 0.0, 0.95) if is_finite(deadzone) else 0.2
    var magnitude := absf(value)
    if magnitude <= deadzone:
        return 0.0
    return signf(value) * minf(1.0, (magnitude - deadzone) / (1.0 - deadzone))

static func scrollable(control: Control) -> bool:
    if not control.is_visible_in_tree():
        return false
    var bar: VScrollBar = null
    if control is RichTextLabel and control.scroll_active:
        bar = control.get_v_scroll_bar()
    elif control is ScrollContainer and control.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
        bar = control.get_v_scroll_bar()
    return bar != null and bar.max_value - bar.page > 0.5

static func _visible_dialogs(node: Node, out: Array) -> Array:
    for child in node.get_children():
        if child is AcceptDialog and child.visible:
            out.append(child)
        if not (child is Window and not child.visible):
            _visible_dialogs(child, out)
    return out

## The innermost visible dialog under the shell, else the shell itself.
static func context(shell: Control) -> Node:
    var dialogs := _visible_dialogs(shell, [])
    var best: Node = shell
    for dialog in dialogs:
        if best == shell or best.is_ancestor_of(dialog) or (not dialog.is_ancestor_of(best) and dialog.has_focus()):
            best = dialog
    return best

static func _candidates(node: Node, out: Array) -> Array:
    for child in node.get_children():
        if child is Window:
            continue
        if child is Control:
            if not child.is_visible_in_tree():
                continue
            if scrollable(child):
                out.append(child)
        _candidates(child, out)
    return out

static func target(shell: Control) -> Control:
    var root := context(shell)
    var candidates := _candidates(root, [])
    if candidates.is_empty():
        return null
    var focus: Control = (root as Window).gui_get_focus_owner() if root is Window else shell.get_viewport().gui_get_focus_owner()
    var node: Node = focus
    while node != null and node != root:
        if node in candidates:
            return node
        node = node.get_parent()
    var largest: Control = candidates[0]
    for candidate in candidates:
        if candidate.get_global_rect().get_area() > largest.get_global_rect().get_area():
            largest = candidate
    return largest

## Returns the pane that moved, or null.
static func scroll(shell: Control, amount: float) -> Control:
    if amount == 0.0 or not is_finite(amount):
        return null
    var pane := target(shell)
    if pane == null:
        return null
    if pane is ScrollContainer:
        pane.scroll_vertical += int(round(amount))
    else:
        var bar: VScrollBar = pane.get_v_scroll_bar()
        bar.value = clampf(bar.value + amount, bar.min_value, bar.max_value - bar.page)
    return pane
