extends AcceptDialog
## Explicitly advance every line. Closing midway commits nothing.
const INQUIRIES := preload("res://scripts/narrative_inquiries.gd")
var ui_ref: WeakRef
var area_ref: WeakRef
var questions: VBoxContainer
var body: Label
var scroll: ScrollContainer
var selected: Dictionary = {}
var line_index := -1

func _ready() -> void:
    title = "沿着线索追问"
    min_size = Vector2i(710, 450)
    size = min_size
    dialog_hide_on_ok = false
    var layout := VBoxContainer.new()
    layout.add_theme_constant_override("separation", 14)
    add_child(layout)
    scroll = ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(650, 340)
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    layout.add_child(scroll)
    var content := VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(content)
    questions = VBoxContainer.new()
    questions.add_theme_constant_override("separation", 10)
    content.add_child(questions)
    body = Label.new()
    body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_child(body)
    get_ok_button().text = "下一句"
    add_cancel_button("暂时离开")
    add_button("返回问题", false, "questions")
    confirmed.connect(_advance)
    custom_action.connect(func(action: String):
        if action == "questions":
            _show_questions())
    visibility_changed.connect(_visibility_changed)
    set_process(false)

func open(ui: Node, area: Area2D) -> void:
    ui_ref = weakref(ui)
    area_ref = weakref(area)
    _show_questions()
    popup_centered()
    set_process(true)

func _visibility_changed() -> void:
    if not visible:
        selected = {}
        line_index = -1
        set_process(false)
        var ui: Variant = ui_ref.get_ref() if ui_ref != null else null
        if is_instance_valid(ui):
            ui.set("modal_closed_frame", Engine.get_process_frames())
            var button: Button = ui.get("dialogue_inquiry_button")
            if is_instance_valid(button) and button.is_visible_in_tree():
                button.grab_focus()

func _context() -> Dictionary:
    var ui: Variant = ui_ref.get_ref() if ui_ref != null else null
    var area: Variant = area_ref.get_ref() if area_ref != null else null
    if not INQUIRIES.can_talk(ui, area):
        return {}
    return {"ui": ui, "area": area, "level": ui.level}

func _process(_delta: float) -> void:
    if _context().is_empty():
        hide()

func _show_questions() -> void:
    selected = {}
    line_index = -1
    for child in questions.get_children():
        questions.remove_child(child)
        child.queue_free()
    questions.show()
    body.text = "只追问已经找到的线索。回答可以中途离开，读完并记下后才进入人物旅记。"
    get_ok_button().disabled = true
    var context := _context()
    if context.is_empty():
        hide()
        return
    var level: Node = context.level
    var rows := INQUIRIES.available(String(context.area.get_meta("npc_id", "")), level.inventory_counts, level.story_flags)
    var first: Button
    for row in rows:
        var button := Button.new()
        button.text = ("已记下 · " if row.recorded else "追问 · ") + String(row.question)
        button.custom_minimum_size = Vector2(620, 42)
        button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        questions.add_child(button)
        button.pressed.connect(_select.bind(String(row.id)))
        if first == null:
            first = button
    if first != null:
        first.grab_focus()
    else:
        body.text = "眼下没有可以继续追问的已知线索。"
    scroll.scroll_vertical = 0

func _select(id: String) -> void:
    var context := _context()
    if context.is_empty():
        hide()
        return
    selected = INQUIRIES.quote(INQUIRIES.find(id), context.level.inventory_counts, context.level.story_flags)
    if selected.is_empty():
        _show_questions()
        return
    questions.hide()
    line_index = 0
    get_ok_button().disabled = false
    _show_line()
    get_ok_button().grab_focus()

func _show_line() -> void:
    body.text = "我问：%s\n\n%s\n\n%d / %d" % [selected.question, selected.lines[line_index], line_index + 1, selected.lines.size()]
    get_ok_button().text = "记下这次追问" if line_index == selected.lines.size() - 1 else "下一句"
    scroll.scroll_vertical = 0

func _advance() -> void:
    if selected.is_empty():
        return
    var context := _context()
    if context.is_empty():
        hide()
        return
    if line_index < selected.lines.size() - 1:
        line_index += 1
        _show_line()
        return
    var result := INQUIRIES.commit(context.ui, context.area, String(selected.id), String(selected.fingerprint), line_index)
    if result.ok:
        _show_questions()
        body.text = "这次追问已记入行囊的「人物」分类。"
    else:
        body.text = String(result.reason)
        # Keep the selected version for a save retry; condition changes require
        # returning to the list and explicitly reading the new answer.
