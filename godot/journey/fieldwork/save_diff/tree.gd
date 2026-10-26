extends VBoxContainer
var rows: Array = []
var tree: Tree
var details: TextEdit
var filter: LineEdit


func _init() -> void:
    custom_minimum_size = Vector2(480, 420)
    size_flags_horizontal = Control.SIZE_EXPAND_FILL


func configure(data: Dictionary) -> void:
    rows = data.get("rows", []).duplicate(true)
    if is_inside_tree():
        _populate()


func _ready() -> void:
    var tools := HBoxContainer.new()
    add_child(tools)
    filter = LineEdit.new()
    filter.placeholder_text = "筛选字段、旧值或新值"
    filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    tools.add_child(filter)
    var search := Button.new()
    search.text = "筛选"
    search.pressed.connect(_populate)
    tools.add_child(search)
    var collapse := Button.new()
    collapse.text = "折叠"
    collapse.pressed.connect(func(): _collapse(tree.get_root(), true))
    tools.add_child(collapse)
    var expand := Button.new()
    expand.text = "展开"
    expand.pressed.connect(func(): _collapse(tree.get_root(), false))
    tools.add_child(expand)
    tree = Tree.new()
    tree.columns = 4
    tree.hide_root = true
    tree.column_titles_visible = true
    tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
    tree.custom_minimum_size.y = 240
    for i in 4:
        tree.set_column_title(i, ["字段", "操作", "记录值", "当前值"][i])
        tree.set_column_expand(i, true)
        tree.set_column_custom_minimum_width(i, 60 if i == 1 else 100)
    tree.item_selected.connect(_selected)
    add_child(tree)
    details = TextEdit.new()
    details.editable = false
    details.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
    details.custom_minimum_size.y = 110
    details.placeholder_text = "选择一项差异，查看完整字段、记录值和当前值。"
    add_child(details)
    _populate()


func _short(value: String) -> String:
    return value.left(77) + "…" if value.length() > 80 else value


func _populate() -> void:
    if not is_instance_valid(tree):
        return
    tree.clear()
    var root := tree.create_item()
    var folders := {"": root}
    var query := filter.text.strip_edges().to_lower()
    for row in rows.slice(0, 256):
        var combined := (
            String(row.get("字段", ""))
            + " "
            + String(row.get("记录值", ""))
            + " "
            + String(row.get("当前值", ""))
        )
        if not query.is_empty() and not combined.to_lower().contains(query):
            continue
        var parts := String(row.get("字段", "")).trim_prefix("/").split("/", true)
        var path := ""
        var parent := root
        for i in maxi(0, parts.size() - 1):
            var part := String(parts[i])
            path += "/" + part
            if not folders.has(path):
                var item := tree.create_item(parent)
                item.set_text(0, part.replace("~1", "/").replace("~0", "~"))
                folders[path] = item
            parent = folders[path]
        parent = tree.create_item(parent)
        parent.set_text(0, String(parts[-1]).replace("~1", "/").replace("~0", "~"))
        parent.set_text(1, String(row.get("操作", "")))
        parent.set_text(2, _short(String(row.get("记录值", ""))))
        parent.set_text(3, _short(String(row.get("当前值", ""))))
        parent.set_tooltip_text(0, String(row.get("字段", "")))
        parent.set_tooltip_text(2, String(row.get("记录值", "")))
        parent.set_tooltip_text(3, String(row.get("当前值", "")))
        parent.set_metadata(0, row.duplicate(true))
    details.text = ""


func _selected() -> void:
    var item := tree.get_selected()
    if item == null:
        return
    var value: Variant = item.get_metadata(0)
    if not value is Dictionary:
        details.text = "这是字段分组，可展开查看子项。"
        return
    details.text = (
        "字段："
        + String(value.get("字段", ""))
        + "\n操作："
        + String(value.get("操作", ""))
        + "\n分类："
        + String(value.get("分类", ""))
        + "\n\n记录值：\n"
        + String(value.get("记录值", ""))
        + "\n\n当前值：\n"
        + String(value.get("当前值", ""))
    )


func _collapse(item: TreeItem, value: bool) -> void:
    if item == null:
        return
    var child := item.get_first_child()
    while child != null:
        child.collapsed = value
        _collapse(child, value)
        child = child.get_next()
