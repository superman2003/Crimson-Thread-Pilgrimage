extends AcceptDialog
const FIND:=preload("res://scripts/journal_literal_find.gd")
var host_ref: WeakRef
var launcher: Button
var query: LineEdit
var case_button: CheckButton
var previous: Button
var next: Button
var count_label: Label
var editor: TextEdit
var preview: Label
var report: Dictionary={}
var selected:=-1
var source:=""
var source_key:=""
var source_hash:=""
var source_scope:=""
var source_generation:=-1

static func install(ui: Control) -> void:
    if ui.bag.has_node("JournalDocumentFind"):return
    var dialog:=new();dialog.name="JournalDocumentFind";dialog.host_ref=weakref(ui)
    ui.bag.add_child(dialog);ui.register_text_entry_window(dialog)
    dialog.launcher=Button.new();dialog.launcher.text="本条查找";dialog.launcher.name="JournalFindButton"
    dialog.launcher.add_theme_font_size_override("font_size",13);dialog.launcher.custom_minimum_size=Vector2(72,30)
    dialog.launcher.tooltip_text="只查找当前选中记录的已公开正文；与左侧跨记录筛选分开。"
    ui.journal_tools.add_child(dialog.launcher);dialog.launcher.pressed.connect(dialog.open)
    ui.journal_tools.visibility_changed.connect(dialog.refresh_launcher)
    dialog.refresh_launcher()

func _ready() -> void:
    title="本条旅记 · 页内查找";min_size=Vector2i(920,600);get_ok_button().text="返回原阅读位置"
    var column:=VBoxContainer.new();column.custom_minimum_size.x=860;column.add_theme_constant_override("separation",9);add_child(column)
    var intro:=Label.new();intro.text="只读查看当前已知正文；按字面查找，不使用跨记录筛选语法。回车到下一处，Shift+回车到上一处。";intro.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;intro.custom_minimum_size.x=860;column.add_child(intro)
    var tools:=HBoxContainer.new();tools.add_theme_constant_override("separation",8);column.add_child(tools)
    query=LineEdit.new();query.placeholder_text="本条正文中的文字";query.max_length=FIND.MAX_QUERY;query.custom_minimum_size=Vector2(310,34);query.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tools.add_child(query)
    query.text_changed.connect(func(_value: String):rebuild());query.gui_input.connect(_query_input)
    case_button=CheckButton.new();case_button.text="区分大小写";tools.add_child(case_button);case_button.toggled.connect(func(_value: bool):rebuild())
    previous=_button(tools,"上一处",func():move(-1));next=_button(tools,"下一处",func():move(1))
    count_label=Label.new();column.add_child(count_label)
    editor=TextEdit.new();editor.editable=false;editor.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;editor.custom_minimum_size=Vector2(860,360);editor.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_child(editor)
    preview=Label.new();preview.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;preview.custom_minimum_size=Vector2(850,44);column.add_child(preview)
    visibility_changed.connect(_visibility_changed)
    confirmed.connect(_restore_focus);canceled.connect(_restore_focus)

func _button(parent: Node, caption: String, callback: Callable) -> Button:
    var button:=Button.new();button.text=caption;button.custom_minimum_size=Vector2(84,34);button.pressed.connect(callback);parent.add_child(button);return button

func _host() -> Control:
    var ui: Control=host_ref.get_ref() if host_ref!=null else null
    return ui if is_instance_valid(ui) and ui.is_inside_tree() and not ui.is_queued_for_deletion() else null

func _available(ui: Control) -> bool:
    return ui!=null and ui.bag.is_visible_in_tree() and ui.bag_category=="旅记" and not ui.journal_current_document.is_empty() and is_instance_valid(ui.bag_description) and String(ui.bag_description.text)==String(ui.journal_current_document.get("text",""))

func _bound() -> bool:
    var ui:=_host()
    return _available(ui) and source_key==String(ui.journal_current_document.get("key","")) and source_hash==String(ui.journal_current_document.get("fingerprint","")) and source_scope==String(ui.level.world_save_path) and source_generation==int(ui.reading_session_generation)

func refresh_launcher() -> void:
    if is_instance_valid(launcher):launcher.disabled=not _available(_host())
    if visible and not _bound():hide()

func open() -> void:
    var ui:=_host()
    if not _available(ui):return
    var document: Dictionary=ui.journal_current_document
    source=String(document.text);source_key=String(document.key);source_hash=String(document.fingerprint)
    source_scope=String(ui.level.world_save_path);source_generation=int(ui.reading_session_generation)
    title=String(document.title).left(100)+" · 本条查找"
    var reading: Variant=ui.accessibility.get("subtitle_size",21)
    var font:=clampi(int(reading),17,26) if typeof(reading) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(reading)) else 21
    editor.add_theme_font_size_override("font_size",font)
    query.set_block_signals(true);query.text="";query.set_block_signals(false)
    editor.text=FIND.normalized(source) if source.length()<=FIND.MAX_TEXT else "本条内容过长，请返回原旅记阅读；不会截断正文后声称已查遍。"
    rebuild(false);popup_centered();query.grab_focus()

func rebuild(require_visible: bool=true) -> void:
    if require_visible and (not visible or not _bound()):hide();return
    report=FIND.search(source,query.text,case_button.button_pressed);selected=-1
    editor.deselect();preview.text="";count_label.text=String(report.reason)
    previous.disabled=not report.ok or report.matches.is_empty();next.disabled=previous.disabled
    if not next.disabled:move(1,require_visible)

func move(direction: int, require_visible: bool=true) -> void:
    if require_visible and (not visible or not _bound()):hide();return
    if not report.get("ok",false):return
    var matches: Array=report.get("matches",[])
    selected=FIND.navigate(matches.size(),selected,direction)
    if selected<0:return
    var hit: Dictionary=matches[selected]
    editor.set_caret_line(int(hit.line));editor.set_caret_column(int(hit.column))
    editor.select(int(hit.line),int(hit.column),int(hit.end_line),int(hit.end_column));editor.center_viewport_to_caret()
    count_label.text="%d / %d%s · %s" % [selected+1,matches.size(),"（至少）" if report.limited else "",String(report.reason)]
    preview.text=String(hit.preview)

func _query_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER,KEY_KP_ENTER]:
        move(-1 if event.shift_pressed else 1);query.accept_event()

func _visibility_changed() -> void:
    if visible:return
    source="";source_key="";source_hash="";source_scope="";source_generation=-1;report={};selected=-1
    if is_instance_valid(editor):editor.text=""
    if is_instance_valid(preview):preview.text=""

func _restore_focus() -> void:
    if _available(_host()) and is_instance_valid(launcher):launcher.grab_focus()
