extends RefCounted
## Native controls with containers, text wrapping and retained keyboard focus.
const GOLD := Color("cfb484")
const PAPER := Color("eadcc6")
const MUTED := Color("a3b3aa")

static func column(parent: Node, expand: bool = false) -> VBoxContainer:
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 10)
    box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    if expand:
        box.size_flags_vertical = Control.SIZE_EXPAND_FILL
    parent.add_child(box)
    return box

static func row(parent: Node) -> HBoxContainer:
    var box := HBoxContainer.new()
    box.add_theme_constant_override("separation", 8)
    box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(box)
    return box

static func label(parent: Node, text: String, heading: bool = false) -> Label:
    var control := Label.new()
    control.text = text
    control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    control.add_theme_font_size_override("font_size", 23 if heading else 17)
    control.add_theme_color_override("font_color", GOLD if heading else PAPER)
    parent.add_child(control)
    return control

static func hint(parent: Node, text: String) -> Label:
    var control := label(parent, text)
    control.add_theme_font_size_override("font_size", 14)
    control.add_theme_color_override("font_color", MUTED)
    return control

static func button(parent: Node, text: String, action: Callable, disabled: bool = false) -> Button:
    var control := Button.new()
    control.text = text
    control.disabled = disabled
    control.custom_minimum_size = Vector2(100, 36)
    control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    control.pressed.connect(action)
    parent.add_child(control)
    return control

static func edit(parent: Node, placeholder: String, value: String = "", maximum: int = 120) -> LineEdit:
    var control := LineEdit.new()
    control.placeholder_text = placeholder
    control.text = value
    control.max_length = maximum
    control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    control.custom_minimum_size.y = 36
    parent.add_child(control)
    return control

static func memo(parent: Node, value: String, height: float = 90) -> TextEdit:
    var control := TextEdit.new()
    control.text = value
    control.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
    control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    control.custom_minimum_size.y = height
    parent.add_child(control)
    return control

static func pick(parent: Node, entries: Array, selected: String = "") -> OptionButton:
    var control := OptionButton.new()
    control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for entry in entries:
        control.add_item(String(entry.get("name", entry.get("id", ""))))
        var index := control.item_count - 1
        control.set_item_metadata(index, String(entry.get("id", "")))
        if String(entry.get("id", "")) == selected:
            control.select(index)
    parent.add_child(control)
    return control

static func chosen(control: OptionButton) -> String:
    return String(control.get_selected_metadata()) if control.selected >= 0 else ""

static func toggle(parent: Node, text: String, value: bool, action: Callable) -> CheckButton:
    var control := CheckButton.new()
    control.text = text
    control.button_pressed = value
    control.toggled.connect(action)
    parent.add_child(control)
    return control

static func spin(parent: Node, value: float, minimum: float, maximum: float, step: float = 1.0) -> SpinBox:
    var control := SpinBox.new()
    control.min_value = minimum
    control.max_value = maximum
    control.step = step
    control.value = value
    control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(control)
    return control

static func card(parent: Node) -> VBoxContainer:
    var panel := PanelContainer.new()
    var style := StyleBoxFlat.new()
    style.bg_color = Color("152829")
    style.border_color = Color("6e6250")
    style.set_border_width_all(1)
    style.content_margin_left = 12
    style.content_margin_right = 12
    style.content_margin_top = 10
    style.content_margin_bottom = 10
    panel.add_theme_stylebox_override("panel", style)
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(panel)
    return column(panel)

static func progress(parent: Node, value: float, maximum: float) -> ProgressBar:
    var control := ProgressBar.new()
    control.max_value = maxf(1.0, maximum)
    control.value = clampf(value, 0, control.max_value)
    control.custom_minimum_size.y = 20
    control.show_percentage = false
    parent.add_child(control)
    return control

static func clear(parent: Node) -> void:
    for child in parent.get_children():
        parent.remove_child(child)
        child.queue_free()

static func scroll(parent: Node) -> VBoxContainer:
    var container := ScrollContainer.new()
    container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    container.size_flags_vertical = Control.SIZE_EXPAND_FILL
    container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    container.follow_focus = true
    parent.add_child(container)
    return column(container)

static func divider(parent: Node) -> void:
    parent.add_child(HSeparator.new())
