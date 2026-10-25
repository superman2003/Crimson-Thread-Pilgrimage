extends Node
const DIRECTORY := preload("res://scripts/map_directory_runtime.gd")
const PLAN := preload("res://scripts/expedition_plan.gd")
const JOURNAL := preload("res://scripts/pilgrimage_cartography.gd")
var ui: Control
var plan:=PLAN.new()
var window: AcceptDialog
var search: LineEdit
var catalog: ItemList
var itinerary: ItemList
var detail: RichTextLabel
var visible_rows: Array=[]
var known: Array=[]
var catalog_key:=""
var plan_key:=""
var selected_from_plan:=false
var add_button: Button
var view_button: Button
var done_button: Button
var hud: Label
var elapsed:=0.0

static func install(shell: Control) -> void:
    if not shell.level.world_mode:return
    var desk:=new();desk.name="ExpeditionDesk";shell.add_child(desk);desk.setup(shell)

func setup(shell: Control) -> void:
    ui=shell
    plan.configure(String(ui.level.world_save_path))
    var button: Button=ui._button(ui.level.map_panel,"多站行程",Vector2(860,585),Vector2(134,32),open)
    button.name="ExpeditionDeskButton";button.add_theme_font_size_override("font_size",13)
    hud=ui._label(ui,"",Vector2(895,260),Vector2(355,76),14,ui.GOLD)
    hud.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;hud.clip_text=true

func _build() -> void:
    window=preload("res://scripts/journey_desk_window.gd").new();window.name="ExpeditionDeskWindow"
    ui.level.map_panel.add_child(window);window.title="多站行程规划";window.bind_overlay(ui,ui.level.map_panel)
    window.text(window.column,"从已补绘地点安排最多六站，调整顺序、勾选与暂停。规划不会传送或补绘，也不代替现场能力门。",42)
    search=window.search(window.column,"搜索已知地点、区域与公开说明",func(_value: String):refresh())
    var columns: HBoxContainer=window.row(window.column)
    catalog=ItemList.new();catalog.custom_minimum_size=Vector2(435,220);columns.add_child(catalog)
    itinerary=ItemList.new();itinerary.custom_minimum_size=Vector2(435,220);columns.add_child(itinerary)
    catalog.item_selected.connect(func(index: int):catalog_key=String(visible_rows[index].key);selected_from_plan=false;_selection())
    itinerary.item_selected.connect(func(index: int):plan_key=String(plan.state.stops[index]);selected_from_plan=true;_selection())
    var actions: HBoxContainer=window.row(window.column)
    add_button=window.button(actions,"加入行程",func():act("add"))
    window.button(actions,"移除所选站",func():act("remove"))
    window.button(actions,"上移",func():act("up"));window.button(actions,"下移",func():act("down"))
    done_button=window.button(actions,"勾选 / 撤销",func():act("done"))
    view_button=window.button(actions,"查看此站地图",view_selected)
    detail=RichTextLabel.new();detail.custom_minimum_size=Vector2(900,110);window.column.add_child(detail)
    var controls: HBoxContainer=window.row(window.column)
    window.button(controls,"开始 / 继续",func():act("start"))
    window.button(controls,"暂停",func():act("pause"))
    window.button(controls,"重排行程进度",func():act("reset"))
    window.footer()

func open() -> void:
    if ui.level.active_overlay!="map" or ui.level.world_loading:return
    if not is_instance_valid(window):_build()
    refresh();window.popup_centered();search.grab_focus()

func _row(key: String) -> Dictionary:
    for row in known:
        if row.key==key:return row
    return {}

func refresh() -> void:
    known=DIRECTORY.rows(ui.level)
    visible_rows=preload("res://scripts/map_directory.gd").search(known,search.text)
    catalog.clear()
    var index_to_select:=-1
    for index in visible_rows.size():
        var row: Dictionary=visible_rows[index]
        catalog.add_item(String(row.region_name)+" · "+String(row.title))
        if row.key==catalog_key:index_to_select=index
    if index_to_select<0 and not visible_rows.is_empty():index_to_select=0;catalog_key=String(visible_rows[0].key)
    if index_to_select>=0:catalog.select(index_to_select)
    else:catalog_key=""
    itinerary.clear()
    for index in plan.state.stops.size():
        var key: String=plan.state.stops[index]
        var row:=_row(key)
        itinerary.add_item("%d. %s%s" % [index+1,"✓ " if plan.state.done.has(key) else "",String(row.get("title","地点暂不可见"))])
        if key==plan_key:itinerary.select(index)
    if not plan.state.stops.has(plan_key):plan_key=""
    _selection()
    window.status.text="%d/6站 · 已勾选%d · %s。%s" % [plan.state.stops.size(),plan.state.done.size(),"进行中" if plan.state.active else "暂停",plan.store.error]
    _refresh_hud()

func _selection() -> void:
    var key:=plan_key if selected_from_plan else catalog_key
    var row:=_row(key)
    add_button.disabled=selected_from_plan or row.is_empty() or plan.state.stops.has(key)
    done_button.disabled=not selected_from_plan or row.is_empty()
    view_button.disabled=row.is_empty()
    detail.text="请选择已知地点或行程中的一站。" if row.is_empty() else String(row.region_name)+" · "+String(row.title)+"\n"+String(row.detail)+"\n"+route_summary(row)

func route_summary(target: Dictionary) -> String:
    if not preload("res://scripts/cartography_runtime.gd").shows_position(ui.level):return "装备罗盘或开启导航辅助后，才可从当前房间预览已知邻接。"
    if String(target.region)!=String(ui.level.config.id):return "此站在另一地区；跨区路程请结合已知通道安排。"
    var ids: Array=[]
    var names:={}
    for room in ui.level.config.get("map_rooms",[]):
        # Full-room charting only: never bridge through an uncharted segment.
        if JOURNAL.charted_any(ui.level.story_flags,String(target.region),room):
            var parts: Array=JOURNAL.charted_parts(ui.level.story_flags,String(target.region),room)
            var area:=0.0
            for part in parts:area+=part.get_area()
            if area+1.0 < preload("res://scripts/cartography_runtime.gd").room_rect(room).get_area():continue
            ids.append(String(room.id));names[String(room.id)]=String(room.get("name",room.id))
    var path: Array=PLAN.path(ui.level.config,ids,String(ui.level.current_room_id),String(target.room_id),ui.level.inventory_counts,ui.level.opened_shortcuts)
    if path.is_empty():return "当前已知且能力/捷径条件满足的邻接链不足；请现场探索。"
    var labels: Array[String]=[]
    for id in path:labels.append(String(names[id]))
    return "已知邻接参考："+" → ".join(labels)+"。落点、敌人与实际通行仍须现场确认。"

func act(command: String) -> void:
    var key:=catalog_key if command=="add" else plan_key
    var result: Dictionary=plan.command(command,key,DIRECTORY.rows(ui.level))
    refresh();window.status.text=String(result.get("reason","行程已保存。"))

func view_selected() -> void:
    var key:=plan_key if selected_from_plan else catalog_key
    var result: Dictionary=DIRECTORY.focus(ui.level,{"key":key})
    if bool(result.get("ok",false)):window.hide()
    else:window.status.text=String(result.get("reason","地点已不可见。"))

func _refresh_hud() -> void:
    if not plan.state.active:hud.hide();return
    var next: Dictionary=plan.next_stop(DIRECTORY.rows(ui.level))
    hud.visible=plan.state.active and not next.is_empty() and String(ui.level.active_overlay).is_empty()
    hud.text="行程暂停：下一站暂不可见。" if next.has("unavailable") else "下一站 · "+String(next.get("region_name",""))+"\n"+String(next.get("title",""))

func _process(delta: float) -> void:
    if not is_instance_valid(ui) or not ui.construction_complete:return
    elapsed+=delta
    if elapsed<0.75:return
    elapsed=0.0
    if is_instance_valid(window) and window.visible:refresh()
    else:_refresh_hud()
