extends ConfirmationDialog
## Naming never edits the active build. The parent supplies durable actions.
var source := ""
var copy_mode := false
var query: Callable
var apply_action: Callable
var quote: Dictionary = {}
var target_input: LineEdit
var mode_buttons: Array[Button] = []
var explanation: Label
var error_label: Label

func _ready() -> void:
    title = "管理保存方案"
    dialog_hide_on_ok = false
    min_size = Vector2i(620, 300)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 14)
    add_child(column)
    explanation = Label.new()
    explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    explanation.custom_minimum_size.x = 580
    column.add_child(explanation)
    var modes := HBoxContainer.new()
    column.add_child(modes)
    for duplicate in [false, true]:
        var button := Button.new()
        button.text = "重命名原方案" if not duplicate else "复制保存方案"
        button.toggle_mode = true
        button.custom_minimum_size.x = 280
        modes.add_child(button)
        mode_buttons.append(button)
        button.pressed.connect(func():choose_copy_mode(duplicate))
    target_input = LineEdit.new()
    target_input.placeholder_text = "新名称，最多24个字"
    target_input.max_length = 24
    target_input.custom_minimum_size.y = 38
    target_input.text_changed.connect(func(_text: String):_refresh_quote())
    column.add_child(target_input)
    error_label = Label.new()
    error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    error_label.custom_minimum_size = Vector2(580, 55)
    column.add_child(error_label)
    confirmed.connect(_confirm_action)
    get_cancel_button().text = "保留原方案"

func open(name: String, quote_action: Callable, action: Callable) -> void:
    source = name
    query = quote_action
    apply_action = action
    target_input.text = source
    explanation.text = "原方案「%s」。重命名保留原位置；复制保留两份，最多8份。当前装备、材料、生命和战具次数均不会变化。" % source
    choose_copy_mode(false)
    popup_centered()
    get_cancel_button().grab_focus()

func choose_copy_mode(value: bool) -> void:
    copy_mode = value
    for index in mode_buttons.size():mode_buttons[index].set_pressed_no_signal((index == 1) == copy_mode)
    get_ok_button().text = "确认复制" if copy_mode else "确认重命名"
    _refresh_quote()

func _refresh_quote() -> void:
    var result: Variant = query.call(target_input.text, copy_mode) if query.is_valid() else {}
    quote = result.duplicate(true) if result is Dictionary else {}
    get_ok_button().disabled = not bool(quote.get("ok", false)) or not bool(quote.get("can_apply", false))
    error_label.text = String(quote.get("reason", "操作不可用"))
    if not get_ok_button().disabled:error_label.text = "新名称可用。确认后仅%s保存方案。" % ("复制" if copy_mode else "重命名")

func _confirm_action() -> void:
    var previous := quote.duplicate(true)
    _refresh_quote()
    if get_ok_button().disabled:return
    if previous.get("source_snapshot", {}) != quote.get("source_snapshot", {}):
        error_label.text = "原方案在窗口打开后发生变化，请复核并再次确认。"
        return
    if not apply_action.is_valid():return
    var result: Variant = apply_action.call(String(quote.target), copy_mode)
    if result is Dictionary and bool(result.get("ok", false)):hide()
    else:
        _refresh_quote()
        error_label.text = String(result.get("reason", "操作未完成")) if result is Dictionary else "操作未完成"
