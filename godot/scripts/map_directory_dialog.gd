extends AcceptDialog
const INDEX = preload("res://scripts/map_directory.gd")
var rows: Array = []
var visible_rows: Array = []
var locate: Callable
var search: LineEdit
var kinds: OptionButton
var list: ItemList
var detail: Label
var locate_button: Button
const KINDS := ["all","room","gate","shortcut","hazard","pin"]

func _ready() -> void:
    title="已补绘地点目录"
    min_size=Vector2i(760,530)
    var column:=VBoxContainer.new();column.add_theme_constant_override("separation",10);add_child(column)
    var filters:=HBoxContainer.new();column.add_child(filters)
    search=LineEdit.new();search.max_length=64;search.placeholder_text="搜索已知地点、区域或标记";search.size_flags_horizontal=Control.SIZE_EXPAND_FILL;filters.add_child(search)
    kinds=OptionButton.new();filters.add_child(kinds)
    for text in ["全部类型","房间","能力门","捷径","危险","图钉"]:kinds.add_item(text)
    search.text_changed.connect(func(_value: String):_refresh())
    kinds.item_selected.connect(func(_index: int):_refresh())
    list=ItemList.new();list.custom_minimum_size=Vector2(710,260);list.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(list)
    list.item_selected.connect(func(_index: int):_selection())
    detail=Label.new();detail.custom_minimum_size=Vector2(710,85);detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(detail)
    locate_button=Button.new();locate_button.text="在地图中查看此处";column.add_child(locate_button)
    locate_button.pressed.connect(_locate_selected)
    get_ok_button().text="返回地图"

func open(records: Array, action: Callable) -> void:
    rows=records.duplicate(true);locate=action
    search.text="";kinds.select(0);_refresh()
    popup_centered()
    search.grab_focus()

func _refresh() -> void:
    visible_rows=INDEX.search(rows,search.text,KINDS[kinds.selected])
    list.clear()
    for row in visible_rows:list.add_item("%s · %s" % [String(row.region_name),String(row.title)])
    if list.item_count>0:list.select(0)
    _selection()

func _selection() -> void:
    var selection:=list.get_selected_items()
    locate_button.disabled=selection.is_empty()
    if selection.is_empty():detail.text="无符合筛选的已补绘地点。清空搜索或切换类型；未购/未补绘地点不会被列出。";return
    var row: Dictionary=visible_rows[selection[0]]
    detail.text=String(row.detail)+"\n仅移动地图视野；不会传送、购买地图或补绘，也不提供玩家定位。"

func _locate_selected() -> void:
    var selection:=list.get_selected_items()
    if selection.is_empty() or not locate.is_valid():return
    var result: Variant=locate.call(visible_rows[selection[0]].duplicate(true))
    if result is Dictionary and bool(result.get("ok",false)):hide()
    else:detail.text=String(result.get("reason","该地点已不在已知地图中")) if result is Dictionary else "当前无法查看"
