extends Node
const MODEL := preload("res://scripts/goal_desk_model.gd")
var ui: Control
var model := MODEL.new()
var window: AcceptDialog
var query: LineEdit
var mode: OptionButton
var list: ItemList
var detail: RichTextLabel
var note: LineEdit
var pin_button: Button
var first_button: Button
var remove_button: Button
var note_button: Button
var hud_option: CheckButton
var hud: Label
var visible_rows: Array = []
var selected := ""
var elapsed := 0.0
var signature := ""
var cleanup: ConfirmationDialog
var cleanup_quote: Dictionary={}
var wish_manifest: AcceptDialog

static func install(shell: Control) -> void:
    var world: Variant=shell.level.get("world_mode")
    if not world is bool or not world:return
    var desk := new()
    desk.name = "GoalDesk"
    shell.add_child(desk)
    desk.setup(shell)

func setup(shell: Control) -> void:
    ui = shell
    model.configure(String(ui.level.world_save_path))
    var button: Button = ui._button(ui.bag,"任务追踪工作台",Vector2(730,99),Vector2(170,30),open)
    button.name = "GoalDeskButton"
    button.add_theme_font_size_override("font_size",14)
    hud = ui._label(ui,"",Vector2(895,120),Vector2(355,135),14,ui.IVORY)
    hud.name = "GoalWatchlist"
    hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hud.clip_text = true
    _refresh_hud()

func open_wish_manifest() -> void:
    if not is_instance_valid(window) or not window.visible or not ui.bag.is_visible_in_tree() or ui.level.world_loading:return
    if not is_instance_valid(wish_manifest):
        wish_manifest=preload("res://scripts/known_wish_dialog.gd").new()
        wish_manifest.name="KnownWishManifestWindow";window.add_child(wish_manifest)
        var reference: WeakRef=weakref(wish_manifest)
        var parent_ref: WeakRef=weakref(window)
        window.visibility_changed.connect(func():
            var child:=reference.get_ref() as Window
            var parent:=parent_ref.get_ref() as Window
            if is_instance_valid(child) and (not is_instance_valid(parent) or not parent.visible):child.hide())
    wish_manifest.open_for(self)

func rows() -> Array:
    var level: Node = ui.level
    if level.world_narrative == null:return []
    var progress: Dictionary = level.world_narrative.evaluate_progress(level.inventory_counts,level.story_flags)
    var records: Array = []
    var main: Variant = progress.get("main_line",{})
    if main is Dictionary and not main.is_empty():
        var entry: Dictionary = main.duplicate(true)
        entry.record_kind = "main"
        records.append(entry)
    for raw in progress.get("quests",[]):
        var entry: Dictionary = raw.duplicate(true)
        entry.record_kind = "quest"
        records.append(entry)
    records.append_array(preload("res://scripts/field_contracts.gd").entries(level,true))
    var result: Array = []
    for entry in records:
        var presentation: Dictionary = ui._journal_presentation(entry)
        var complete := String(entry.get("status","")) == "complete"
        if entry.record_kind == "main":
            var steps: Array = entry.get("steps",[])
            complete = not steps.is_empty() and steps.all(func(step):return bool(step.get("complete",false)))
        result.append({"key":String(entry.record_kind)+":"+String(entry.get("id","main")),"title":String(entry.get("title","当前主线")),
            "text":String(presentation.text),"complete":complete,"entry":entry})
    return result

func _build() -> void:
    window = preload("res://scripts/journey_desk_window.gd").new()
    window.name = "GoalDeskWindow"
    ui.bag.add_child(window)
    window.title = "任务追踪工作台"
    window.bind_overlay(ui,ui.bag)
    window.text(window.column,"追踪最多三项已知主线/委托，置顶决定HUD顺序。备注只属于本存档，不修改剧情。",42)
    var filters: HBoxContainer = window.row(window.column)
    query = window.search(filters,"搜索公开步骤或当前存档的追踪备注",func(_value: String):refresh())
    mode = OptionButton.new();filters.add_child(mode)
    for title_text in ["全部目标","进行中","已完成","已追踪目标"]:mode.add_item(title_text)
    mode.item_selected.connect(func(_index: int):refresh())
    var columns: HBoxContainer = window.row(window.column)
    list = ItemList.new();list.custom_minimum_size=Vector2(350,280);columns.add_child(list)
    list.item_selected.connect(func(index: int):selected=String(visible_rows[index].key);_selection())
    detail = RichTextLabel.new();detail.custom_minimum_size=Vector2(540,280);detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL;columns.add_child(detail)
    var actions: HBoxContainer = window.row(window.column)
    pin_button = window.button(actions,"追踪此目标",func():act("pin"))
    first_button = window.button(actions,"设为首要",func():act("first"))
    remove_button = window.button(actions,"取消追踪",func():act("remove"))
    window.button(actions,"在旅记阅读",_read_selected)
    hud_option = CheckButton.new();hud_option.text="显示HUD追踪";actions.add_child(hud_option)
    hud_option.toggled.connect(func(value: bool):act("hud",value))
    var notes: HBoxContainer = window.row(window.column)
    note = window.search(notes,"当前目标备注，最多160字",func(_value: String):pass);note.max_length=160
    note_button = window.button(notes,"保存备注",func():act("note",note.text))
    window.button(window.column,"整理已完成追踪",ask_cleanup)
    var wish_button: Button=window.button(window.column,"已询问心愿交付清单",open_wish_manifest)
    wish_button.name="KnownWishManifestButton"
    window.footer()

func open() -> void:
    if not ui.bag.is_visible_in_tree() or ui.level.world_loading:return
    if not is_instance_valid(window):_build()
    refresh()
    window.popup_centered()
    query.grab_focus()

func refresh() -> void:
    if not is_instance_valid(window):return
    var known := rows()
    visible_rows = MODEL.filter_rows(known,query.text,mode.selected,model.state)
    visible_rows.sort_custom(func(a: Dictionary,b: Dictionary):
        var first: int = model.state.pins.find(a.key)
        var second: int = model.state.pins.find(b.key)
        return (first if first>=0 else 100) < (second if second>=0 else 100))
    list.clear()
    var index_to_select := 0
    for index in visible_rows.size():
        var row: Dictionary = visible_rows[index]
        list.add_item(("★ " if model.state.pins.has(row.key) else "")+String(row.title)+(" · 已完成" if row.complete else ""))
        if row.key == selected:index_to_select=index
    if not visible_rows.is_empty():list.select(index_to_select);selected=String(visible_rows[index_to_select].key)
    else:selected=""
    hud_option.set_pressed_no_signal(bool(model.state.hud))
    window.status.text="已知目标 %d · 已追踪 %d/3。%s" % [known.size(),model.state.pins.size(),model.store.error]
    _selection()
    _refresh_hud()

func _selected_row() -> Dictionary:
    for row in visible_rows:
        if row.key==selected:return row
    return {}

func _selection() -> void:
    var row := _selected_row()
    var pinned: bool = model.state.pins.has(selected)
    pin_button.disabled=row.is_empty() or pinned
    first_button.disabled=not pinned
    remove_button.disabled=not pinned
    note_button.disabled=not pinned
    note.editable=pinned
    note.text=String(model.state.notes.get(selected,""))
    detail.text="没有符合条件的已知目标。清空搜索或切换筛选。" if row.is_empty() else String(row.title)+"\n\n"+String(row.text)
    if not row.is_empty():detail.text="下一步："+preload("res://scripts/goal_watchlist_review.gd").next_hint(row)+"\n\n"+detail.text

func act(command: String, value: Variant = null) -> void:
    var result: Dictionary = model.change(command,selected,rows(),value)
    refresh()
    window.status.text=String(result.get("reason","已保存。"))

func _read_selected() -> void:
    var row := _selected_row()
    if row.is_empty():return
    window.hide()
    ui.bag_category="旅记"
    ui.journal_filter="all"
    ui.refresh_inventory()
    ui._show_journal_record(row.entry)

func _refresh_hud() -> void:
    var lines: Array[String]=preload("res://scripts/goal_watchlist_review.gd").hud_lines(model.state,rows())
    hud.text="追踪目标\n"+"\n".join(lines)
    hud.visible=bool(model.state.hud) and not lines.is_empty() and String(ui.level.active_overlay).is_empty()

func _process(delta: float) -> void:
    if not is_instance_valid(ui) or not ui.construction_complete:return
    elapsed+=delta
    if elapsed<0.5:return
    elapsed=0.0
    var current:=JSON.stringify(rows())
    if current!=signature:
        signature=current
        if is_instance_valid(window) and window.visible:refresh()
    _refresh_hud()

func ask_cleanup() -> void:
    if not is_instance_valid(window) or not window.visible:return
    cleanup_quote=preload("res://scripts/goal_watchlist_review.gd").quote(model.state,rows())
    if not cleanup_quote.ok:window.status.text=String(cleanup_quote.reason);return
    if not is_instance_valid(cleanup):
        cleanup=ConfirmationDialog.new();cleanup.title="整理已完成追踪";cleanup.min_size=Vector2i(650,300)
        cleanup.get_ok_button().text="确认整理追踪";window.add_child(cleanup);ui.register_text_entry_window(cleanup)
        cleanup.confirmed.connect(_apply_cleanup)
        window.visibility_changed.connect(func():
            if not window.visible:cleanup.hide();cleanup_quote={})
    cleanup.dialog_text=String(cleanup_quote.summary);cleanup.popup_centered();cleanup.get_cancel_button().grab_focus()

func _apply_cleanup() -> void:
    if not window.visible or cleanup_quote.is_empty():return
    var result:=preload("res://scripts/goal_watchlist_review.gd").apply(model,rows(),String(cleanup_quote.get("fingerprint","")))
    cleanup_quote={};refresh();window.status.text=String(result.reason)
