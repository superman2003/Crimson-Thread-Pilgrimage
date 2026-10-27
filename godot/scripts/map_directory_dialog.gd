extends AcceptDialog
const FLOORS = preload("res://scripts/map_floor_labels.gd")
const INDEX = preload("res://scripts/map_directory.gd")
var rows: Array = []
var visible_rows: Array = []
var locate: Callable
var search: LineEdit
var kinds: OptionButton
var regions: OptionButton
var floors: OptionButton
var sort_order: OptionButton
var previous_button: Button
var next_button: Button
var cursor: Label
var count: Label
var list: ItemList
var detail: RichTextLabel
var clue_states: OptionButton
var locate_button: Button
const KINDS := ["all","room","gate","shortcut","hazard","pin","clue"]

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
    regions.item_selected.connect(func(_index: int):_rebuild_floors();_refresh())
    kinds=OptionButton.new();scope.add_child(kinds)
    for text in ["全部类型","房间","能力门","捷径","危险","图钉","入口线索"]:kinds.add_item(text)
    search.text_changed.connect(func(_value: String):_refresh())
    kinds.item_selected.connect(func(_index: int):
        if KINDS[kinds.selected]!="clue":clue_states.select(0)
        _refresh())
    sort_order=OptionButton.new();scope.add_child(sort_order)
    for label in ["原目录顺序","区域与名称","类型与名称","地点名称"]:sort_order.add_item(label)
    sort_order.item_selected.connect(func(_index: int):_refresh())
    floors=OptionButton.new();scope.add_child(floors)
    floors.tooltip_text="只列当前已购、已补绘条目的作者层位；贯层通道单独标注。"
    floors.item_selected.connect(func(_index: int):_refresh())
    clue_states=OptionButton.new();column.add_child(clue_states)
    for value in [["全部线索状态",""],["只看待回访入口","noticed"],["只看已找到入口","found"]]:
        clue_states.add_item(value[0]);clue_states.set_item_metadata(clue_states.item_count-1,value[1])
    clue_states.item_selected.connect(func(index: int):
        if index>0:kinds.select(KINDS.find("clue"))
        _refresh())
    count=Label.new();column.add_child(count)
    list=ItemList.new();list.custom_minimum_size=Vector2(710,260);list.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(list)
    list.item_selected.connect(func(_index: int):_selection())
    list.item_activated.connect(func(_index: int):_locate_selected())
    var navigation:=HBoxContainer.new();column.add_child(navigation)
    previous_button=Button.new();previous_button.text="上一处";navigation.add_child(previous_button);previous_button.pressed.connect(func():step_selection(-1))
    cursor=Label.new();cursor.size_flags_horizontal=Control.SIZE_EXPAND_FILL;cursor.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;navigation.add_child(cursor)
    next_button=Button.new();next_button.text="下一处";navigation.add_child(next_button);next_button.pressed.connect(func():step_selection(1))
    detail=RichTextLabel.new();detail.custom_minimum_size=Vector2(710,110);detail.bbcode_enabled=false;detail.scroll_active=true;detail.focus_mode=Control.FOCUS_ALL;column.add_child(detail)
    locate_button=Button.new();locate_button.text="在地图中查看此处";column.add_child(locate_button)
    locate_button.pressed.connect(_locate_selected)
    list.gui_input.connect(_list_input)
    get_ok_button().text="返回地图"

func open(records: Array, action: Callable) -> void:
    rows=records.duplicate(true);locate=action
    floors.clear()
    regions.clear();regions.add_item("全部已知区域");regions.set_item_metadata(0,"")
    for region in INDEX.regions(rows):
        regions.add_item(String(region.name));regions.set_item_metadata(regions.item_count-1,String(region.id))
    search.set_text("");kinds.select(0);regions.select(0);clue_states.select(0);_rebuild_floors();_refresh()
    popup_centered()
    search.grab_focus()

func _rebuild_floors() -> void:
    var chosen := String(floors.get_selected_metadata()) if floors.item_count > 0 else ""
    floors.clear()
    floors.add_item("全部已知层位")
    floors.set_item_metadata(0, "")
    var selected_index := 0
    for floor in FLOORS.choices(rows, String(regions.get_selected_metadata())):
        floors.add_item(String(floor.name))
        var index := floors.item_count - 1
        floors.set_item_metadata(index, String(floor.id))
        if String(floor.id) == chosen:
            selected_index = index
    floors.select(selected_index)

func _refresh() -> void:
    var selected_key:=""
    var old_selection:=list.get_selected_items()
    if not old_selection.is_empty() and old_selection[0]<visible_rows.size():selected_key=String(visible_rows[old_selection[0]].key)
    visible_rows=INDEX.arrange(INDEX.search(rows,search.text,KINDS[kinds.selected],String(regions.get_selected_metadata()),String(clue_states.get_selected_metadata())),sort_order.selected)
    if floors.item_count > 0:
        visible_rows=FLOORS.filter_rows(visible_rows,String(floors.get_selected_metadata()))
    list.clear()
    var selected_index:=0
    for row in visible_rows:list.add_item("%s · %s" % [String(row.region_name),FLOORS.caption(row)+" · "+String(row.title)])
    for index in visible_rows.size():
        if String(visible_rows[index].key)==selected_key:selected_index=index;break
    if list.item_count>0:list.select(selected_index);list.ensure_current_is_visible()
    count.text="符合筛选 %d / 已知地点 %d · 仅列已购且已补绘的区域" % [visible_rows.size(),rows.size()]
    _selection()

func _selection() -> void:
    detail.scroll_to_line(0)
    var selection:=list.get_selected_items()
    locate_button.disabled=selection.is_empty()
    var index:=int(selection[0]) if not selection.is_empty() else -1
    previous_button.disabled=index<=0
    next_button.disabled=index<0 or index>=visible_rows.size()-1
    cursor.text="%d / %d" % [index+1,visible_rows.size()]
    var summary: Array[String]=[]
    var totals:=INDEX.counts(visible_rows)
    for kind in ["room","gate","shortcut","hazard","pin","clue"]:
        if int(totals.get(kind,0))>0:summary.append({"room":"房间","gate":"能力门","shortcut":"捷径","hazard":"危险","pin":"图钉","clue":"入口线索"}[kind]+str(totals[kind]))
    count.tooltip_text=" · ".join(summary)
    if selection.is_empty():detail.text="无符合筛选的已补绘地点。清空搜索或切换类型；未购/未补绘地点不会被列出。";return
    var row: Dictionary=visible_rows[selection[0]]
    detail.text="层位："+FLOORS.caption(row)+"\n"+String(row.detail)+"\n仅移动地图视野；不会传送、购买地图或补绘，也不提供玩家定位。"

func _locate_selected() -> void:
    var selection:=list.get_selected_items()
    if selection.is_empty() or not locate.is_valid():return
    var result: Variant=locate.call(visible_rows[selection[0]].duplicate(true))
    if result is Dictionary and bool(result.get("ok",false)):hide()
    else:detail.text=String(result.get("reason","该地点已不在已知地图中")) if result is Dictionary else "当前无法查看"

func step_selection(direction: int) -> void:
    if direction not in [-1,1]:return
    var selected:=list.get_selected_items()
    if selected.is_empty():return
    var index:=int(selected[0])+direction
    if index<0 or index>=visible_rows.size():return
    list.select(index);list.ensure_current_is_visible();_selection()

func _list_input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo:return
    if event.keycode==KEY_HOME and list.item_count>0:
        list.select(0);list.ensure_current_is_visible();_selection();list.accept_event()
    elif event.keycode==KEY_END and list.item_count>0:
        list.select(list.item_count-1);list.ensure_current_is_visible();_selection();list.accept_event()
    elif event.keycode==KEY_F and (event.ctrl_pressed or event.meta_pressed):
        search.grab_focus();search.select_all();list.accept_event()
