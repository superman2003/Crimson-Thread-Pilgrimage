extends AcceptDialog
## Shared accessible shell; each desk supplies its own model and actions.
var column: VBoxContainer
var status: Label

func _ready() -> void:
    min_size = Vector2i(960, 610)
    column = VBoxContainer.new()
    column.custom_minimum_size.x = 920
    column.add_theme_constant_override("separation", 9)
    add_child(column)
    get_ok_button().text = "返回"

func text(parent: Node, value: String, height: float = 0.0) -> Label:
    var label := Label.new()
    label.text = value
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
    ui.register_text_entry_window(self)
    var reference: WeakRef = weakref(self)
    overlay.visibility_changed.connect(func():
        var window := reference.get_ref() as Window
        if is_instance_valid(window) and not overlay.is_visible_in_tree():window.hide())
