extends AcceptDialog
const INDEX = preload("res://scripts/map_directory.gd")
var rows: Array = []
var visible_rows: Array = []
var locate: Callable
var search: LineEdit
var kinds: OptionButton
var regions: OptionButton
var count: Label
var list: ItemList
var detail: Label
var locate_button: Button
const KINDS := ["all","room","gate","shortcut","hazard","pin"]

func _ready() -> void:
    title="已补绘地点目录"
    min_size=Vector2i(800,570)
    var column:=VBoxContainer.new();column.add_theme_constant_override("separation",10);add_child(column)
    var filters:=HBoxContainer.new();column.add_child(filters)
    search=LineEdit.new();search.max_length=64;search.placeholder_text="搜索已知地点、区域或标记";search.size_flags_horizontal=Control.SIZE_EXPAND_FILL;filters.add_child(search)
    var clear:=Button.new();clear.text="清空搜索";filters.add_child(clear)
    clear.name="ClearSearch"
    clear.pressed.connect(func():search.clear();_refresh();search.grab_focus())
    search.text_submitted.connect(func(_text: String):
        if list.item_count>0:list.grab_focus())
    var scope:=HBoxContainer.new();column.add_child(scope)
    regions=OptionButton.new();regions.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scope.add_child(regions)
    regions.item_selected.connect(func(_index: int):_refresh())
    kinds=OptionButton.new();scope.add_child(kinds)
    for text in ["全部类型","房间","能力门","捷径","危险","图钉"]:kinds.add_item(text)
    search.text_changed.connect(func(_value: String):_refresh())
    kinds.item_selected.connect(func(_index: int):_refresh())
    count=Label.new();column.add_child(count)
    list=ItemList.new();list.custom_minimum_size=Vector2(710,260);list.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(list)
    list.item_selected.connect(func(_index: int):_selection())
    list.item_activated.connect(func(_index: int):_locate_selected())
    detail=Label.new();detail.custom_minimum_size=Vector2(710,85);detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(detail)
    locate_button=Button.new();locate_button.text="在地图中查看此处";column.add_child(locate_button)
    locate_button.pressed.connect(_locate_selected)
    get_ok_button().text="返回地图"

func open(records: Array, action: Callable) -> void:
    rows=records.duplicate(true);locate=action
    regions.clear();regions.add_item("全部已知区域");regions.set_item_metadata(0,"")
    for region in INDEX.regions(rows):
        regions.add_item(String(region.name));regions.set_item_metadata(regions.item_count-1,String(region.id))
    search.set_text("");kinds.select(0);regions.select(0);_refresh()
    popup_centered()
    search.grab_focus()

func _refresh() -> void:
    var selected_key:=""
    var old_selection:=list.get_selected_items()
    if not old_selection.is_empty() and old_selection[0]<visible_rows.size():selected_key=String(visible_rows[old_selection[0]].key)
    visible_rows=INDEX.search(rows,search.text,KINDS[kinds.selected],String(regions.get_selected_metadata()))
    list.clear()
    var selected_index:=0
    for row in visible_rows:list.add_item("%s · %s" % [String(row.region_name),String(row.title)])
    for index in visible_rows.size():
        if String(visible_rows[index].key)==selected_key:selected_index=index;break
    if list.item_count>0:list.select(selected_index)
    count.text="符合筛选 %d / 已知地点 %d · 仅列已购且已补绘的区域" % [visible_rows.size(),rows.size()]
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
