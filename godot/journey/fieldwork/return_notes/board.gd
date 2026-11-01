extends VBoxContainer
signal edit_requested(payload: Dictionary, room: String)
const COMPASS := preload("res://journey/fieldwork/landmarks/view.gd")
var data: Dictionary = {}
var rows: Array = []
var query: LineEdit
var sort: OptionButton
var tree: Tree
var notes: TextEdit
var edit_button: Button
var review_button: Button
var selected := ""


func _init() -> void:
    custom_minimum_size = Vector2(480, 500)
    size_flags_horizontal = Control.SIZE_EXPAND_FILL


func configure(value: Dictionary) -> void:
    data = value.duplicate(true)
    rows = data.get("rows", [])
    if is_inside_tree():
        _populate()


func _ready() -> void:
    var tabs := TabContainer.new()
    tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
    tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_child(tabs)
    var first := VBoxContainer.new()
    first.name = "复访问题"
    tabs.add_child(first)
    var tools := HBoxContainer.new()
    first.add_child(tools)
    query = LineEdit.new()
    query.placeholder_text = "搜索房间或个人问题"
    query.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    query.text_submitted.connect(func(_value: String): _populate())
    tools.add_child(query)
    var search := Button.new()
    search.text = "筛选"
    search.pressed.connect(_populate)
    tools.add_child(search)
    sort = OptionButton.new()
    for title in ["个人参考排序", "房间名称", "未核对优先"]:
        sort.add_item(title)
    sort.item_selected.connect(func(_index: int): _populate())
    tools.add_child(sort)
    tree = Tree.new()
    tree.columns = 4
    tree.hide_root = true
    tree.column_titles_visible = true
    tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
    tree.custom_minimum_size.y = 240
    for i in 4:
        tree.set_column_title(i, ["已知房间", "个人优先级", "直线距离", "个人核对"][i])
        tree.set_column_expand(i, true)
        tree.set_column_custom_minimum_width(i, 90)
    tree.item_selected.connect(_selected)
    first.add_child(tree)
    notes = TextEdit.new()
    notes.editable = false
    notes.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
    notes.custom_minimum_size.y = 100
    notes.placeholder_text = "选择一个已知房间，查看个人复访问题。"
    first.add_child(notes)
    var actions := HBoxContainer.new()
    first.add_child(actions)
    edit_button = Button.new()
    edit_button.text = "编辑此房间的复访候选"
    edit_button.disabled = true
    edit_button.pressed.connect(_edit)
    actions.add_child(edit_button)
    review_button = Button.new()
    review_button.text = "在新候选中标记已核对"
    review_button.disabled = true
    review_button.pressed.connect(_review)
    actions.add_child(review_button)
    var help := Label.new()
    help.text = "操作会打开新的辅助候选，仍需保存。个人核对不设置任何游戏进度。"
    help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    help.add_theme_font_size_override("font_size", 12)
    first.add_child(help)
    var compass: Control = COMPASS.new()
    compass.name = "已知地点方位"
    compass.configure(data.get("compass", {}))
    tabs.add_child(compass)
    _populate()


func _populate() -> void:
    if not is_instance_valid(tree):
        return
    tree.clear()
    var root := tree.create_item()
    var candidates := rows.duplicate(true)
    if sort.selected == 1:
        candidates.sort_custom(
            func(a: Dictionary, b: Dictionary):
                return String(a["房间"]).naturalnocasecmp_to(String(b["房间"])) < 0
        )
    elif sort.selected == 2:
        candidates.sort_custom(
            func(a: Dictionary, b: Dictionary):
                if a["已核对"] != b["已核对"]:
                    return not bool(a["已核对"])
                return float(a["个人优先级"]) > float(b["个人优先级"])
        )
    var term := query.text.strip_edges().to_lower()
    selected = ""
    for row in candidates:
        var text := String(row["房间"]) + " " + String(row["个人复查问题"])
        if not term.is_empty() and not text.to_lower().contains(term):
            continue
        var item := tree.create_item(root)
        item.set_text(0, String(row["房间"]))
        item.set_text(1, str(row["个人优先级"]))
        item.set_text(2, "%.1f" % float(row["直线距离"]))
        item.set_text(3, "已核对" if row["已核对"] else "待复查")
        item.set_metadata(0, row.duplicate(true))
        item.set_tooltip_text(0, String(row["房间"]) + "\n" + String(row["个人复查问题"]))
    edit_button.disabled = true
    review_button.disabled = true
    notes.text = ""


func _selected() -> void:
    var item := tree.get_selected()
    if item == null:
        return
    var row: Variant = item.get_metadata(0)
    if not row is Dictionary:
        return
    selected = String(row.id)
    notes.text = (
        String(row["房间"])
        + "\n\n"
        + String(row["个人复查问题"])
        + "\n\n直线距离只作参考；当前允许出边"
        + str(row["当前允许出边"])
        + "条。"
    )
    edit_button.disabled = false
    review_button.disabled = false


func _edit() -> void:
    if selected.is_empty() or not data.get("payload") is Dictionary:
        return
    edit_requested.emit(data.payload.duplicate(true), selected)


func _review() -> void:
    if selected.is_empty() or not data.get("payload") is Dictionary:
        return
    var payload: Dictionary = data.payload.duplicate(true)
    if not payload.reviewed.has(selected):
        payload.reviewed.append(selected)
    edit_requested.emit(payload, selected)


func current_selection() -> String:
    return selected
