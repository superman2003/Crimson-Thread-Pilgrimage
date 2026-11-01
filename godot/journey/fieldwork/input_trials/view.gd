extends Control
var active := false
var paused := false
var text := ""
var amount := 0.0
var caption: Label
var hint: Label


func _init() -> void:
    custom_minimum_size = Vector2(480, 190)
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    focus_mode = Control.FOCUS_ALL
    mouse_filter = Control.MOUSE_FILTER_STOP


func configure(data: Dictionary) -> void:
    active = bool(data.get("active", false))
    text = String(data.get("text", ""))
    queue_redraw()


func _ready() -> void:
    var outer := VBoxContainer.new()
    outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    outer.offset_left = 20
    outer.offset_right = -20
    outer.offset_top = 24
    outer.offset_bottom = -30
    add_child(outer)
    caption = Label.new()
    caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
    caption.text = text
    caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    caption.add_theme_font_size_override("font_size", 19)
    caption.size_flags_vertical = Control.SIZE_EXPAND_FILL
    outer.add_child(caption)
    hint = Label.new()
    hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.add_theme_font_size_override("font_size", 13)
    hint.text = "点击聚焦此区域，再按提示动作。其它控件或文字框不会被记录；离开聚焦会暂停。"
    outer.add_child(hint)
    resized.connect(queue_redraw)
    focus_entered.connect(queue_redraw)
    focus_exited.connect(queue_redraw)


func update_state(value: String, is_paused: bool, progress: float) -> void:
    text = value
    paused = is_paused
    amount = clampf(progress, 0, 1)
    if is_instance_valid(caption):
        caption.text = text
    queue_redraw()


func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        grab_focus()
        accept_event()
        queue_redraw()


func _draw() -> void:
    var color := Color("122c2b") if has_focus() else Color("1c302d")
    if paused:
        color = Color("36382b")
    draw_rect(Rect2(Vector2.ZERO, size), color)
    draw_rect(
        Rect2(Vector2.ONE, size - Vector2(2, 2)),
        Color("d0b581") if has_focus() else Color("53695c"),
        false,
        2
    )
    draw_rect(Rect2(15, size.y - 18, maxf(1, size.x - 30), 5), Color("334b40"))
    draw_rect(Rect2(15, size.y - 18, maxf(0, (size.x - 30) * amount), 5), Color("c7b07a"))
