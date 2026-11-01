extends Control
var data: Dictionary = {}
var pages: Array = []
var page := 0
var body: Label
var heading: Label
var counter: Label
var previous_button: Button
var next_button: Button
var scroll: ScrollContainer
var query: LineEdit
var hit := 0
var hits: Array = []


func _init() -> void:
    custom_minimum_size = Vector2(480, 430)
    size_flags_horizontal = Control.SIZE_EXPAND_FILL


func configure(value: Dictionary) -> void:
    data = value.duplicate(true)
    pages = data.get("pages", [""])
    if pages.is_empty():
        pages = [""]
    page = clampi(int(data.get("page", 1)) - 1, 0, pages.size() - 1)
    if is_inside_tree():
        _show_page()


func _ready() -> void:
    var outer := VBoxContainer.new()
    outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    outer.add_theme_constant_override("separation", 8)
    add_child(outer)
    heading = Label.new()
    heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    heading.add_theme_font_size_override("font_size", 22)
    outer.add_child(heading)
    var navigation := HBoxContainer.new()
    outer.add_child(navigation)
    previous_button = Button.new()
    previous_button.text = "上一参考页"
    previous_button.pressed.connect(func(): _turn(-1))
    navigation.add_child(previous_button)
    counter = Label.new()
    counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    navigation.add_child(counter)
    next_button = Button.new()
    next_button.text = "下一参考页"
    next_button.pressed.connect(func(): _turn(1))
    navigation.add_child(next_button)
    scroll = ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.follow_focus = true
    outer.add_child(scroll)
    body = Label.new()
    body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.mouse_filter = Control.MOUSE_FILTER_PASS
    body.focus_mode = Control.FOCUS_ALL
    body.gui_input.connect(_body_input)
    scroll.add_child(body)
    var tools := HBoxContainer.new()
    outer.add_child(tools)
    query = LineEdit.new()
    query.placeholder_text = "查找当前章节中的字词"
    query.text = String(data.get("query", ""))
    query.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    query.text_submitted.connect(func(_value: String): _search())
    tools.add_child(query)
    var search := Button.new()
    search.text = "定位"
    search.pressed.connect(_search)
    tools.add_child(search)
    var next_hit := Button.new()
    next_hit.text = "下一命中页"
    next_hit.pressed.connect(_next_hit)
    tools.add_child(next_hit)
    var info := Label.new()
    info.text = "PageUp/PageDown翻参考页；页内可滚动。此处翻页和查找不会设置游戏任务标记。"
    info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    info.add_theme_font_size_override("font_size", 12)
    outer.add_child(info)
    _show_page()


func _show_page() -> void:
    if not is_instance_valid(body):
        return
    page = clampi(page, 0, pages.size() - 1)
    heading.text = String(data.get("title", "已知资料"))
    body.text = String(pages[page])
    body.add_theme_font_size_override("font_size", int(data.get("font_size", 20)))
    body.add_theme_constant_override("line_spacing", int(data.get("line_spacing", 6)))
    counter.text = "第%d / %d参考页" % [page + 1, pages.size()]
    previous_button.disabled = page == 0
    next_button.disabled = page == pages.size() - 1
    scroll.scroll_vertical = 0
    if not hits.is_empty():
        counter.text += " · 命中页%d个" % hits.size()


func _turn(offset: int) -> void:
    page = clampi(page + offset, 0, pages.size() - 1)
    _show_page()
    body.grab_focus()


func _body_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_PAGEUP:
            _turn(-1)
        elif event.keycode == KEY_PAGEDOWN:
            _turn(1)
        elif event.keycode == KEY_HOME and event.ctrl_pressed:
            page = 0
            _show_page()
        elif event.keycode == KEY_END and event.ctrl_pressed:
            page = pages.size() - 1
            _show_page()
        else:
            return
        body.accept_event()


func _search() -> void:
    hits = []
    hit = 0
    var text := query.text.strip_edges().to_lower()
    if not text.is_empty():
        for i in pages.size():
            if String(pages[i]).to_lower().contains(text):
                hits.append(i)
    if hits.is_empty():
        counter.text = "本章节没有命中页。" if not text.is_empty() else "请输入查找字词。"
        return
    page = int(hits[0])
    _show_page()
    body.tooltip_text = "命中字词：" + query.text


func _next_hit() -> void:
    if hits.is_empty():
        _search()
        return
    hit = (hit + 1) % hits.size()
    page = int(hits[hit])
    _show_page()
    body.grab_focus()
