extends Node
## Read-only native reader; closing the settings owner also closes this window.
var ui: Control
var model:=preload("res://scripts/credits_catalog.gd").new()
var window: AcceptDialog
var search: LineEdit
var category: OptionButton
var list: ItemList
var reader: RichTextLabel
var status: Label
var selected:=""
var last_selected:=""
var rows: Array[Dictionary]=[]
var groups: Array[String]=[]
var launcher: Button
var positions: Dictionary={}
var generation:=0
var catalog_identity:=""

static func install(shell: Control) -> void:
    if shell.has_node("CreditsReader"):return
    var desk:=new();desk.name="CreditsReader";shell.add_child(desk);desk.setup(shell)

func setup(shell: Control) -> void:
    ui=shell
    var subtitle:=ui.settings.get_node_or_null("InscriptionSubtitle") as Label
    if subtitle!=null:subtitle.size.x=200
    launcher=ui._button(ui.settings,"来源与许可",Vector2(420,20),Vector2(160,32),open)
    launcher.name="CreditsReaderButton";launcher.add_theme_font_size_override("font_size",15)
    launcher.tooltip_text="在游戏内阅读发行包附带的项目与第三方来源文件。"

func _build() -> void:
    window=AcceptDialog.new();window.name="CreditsReaderWindow";window.title="来源与许可"
    window.min_size=Vector2i(960,610);ui.settings.add_child(window);ui.register_text_entry_window(window)
    var column:=VBoxContainer.new();column.add_theme_constant_override("separation",10);window.add_child(column)
    var intro:=Label.new();intro.custom_minimum_size=Vector2(910,44);intro.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    intro.text="以下为发行包附带的项目说明与来源文件原文。项目代码许可不替代各素材自己的条款；来源说明也可能包含未随包分发的开发边界记录。"
    column.add_child(intro)
    var filters:=HBoxContainer.new();column.add_child(filters)
    search=LineEdit.new();search.placeholder_text="按名称或来源路径检索";search.max_length=80
    search.size_flags_horizontal=Control.SIZE_EXPAND_FILL;search.custom_minimum_size.y=34
    filters.add_child(search);search.text_changed.connect(func(_text: String):refresh())
    category=OptionButton.new();category.custom_minimum_size=Vector2(180,34);filters.add_child(category)
    category.item_selected.connect(func(_index: int):refresh())
    var columns:=HBoxContainer.new();columns.add_theme_constant_override("separation",12);column.add_child(columns)
    list=ItemList.new();list.custom_minimum_size=Vector2(270,350);columns.add_child(list)
    list.item_selected.connect(show_document)
    reader=RichTextLabel.new();reader.custom_minimum_size=Vector2(630,350)
    reader.bbcode_enabled=false;reader.selection_enabled=true;reader.scroll_active=true;reader.focus_mode=Control.FOCUS_ALL
    columns.add_child(reader)
    var navigation:=HBoxContainer.new();column.add_child(navigation)
    for entry in [["回到正文开头",top],["到正文末尾",bottom],["清除检索",clear_search]]:
        var button:=Button.new();button.text=entry[0];button.custom_minimum_size=Vector2(200,32)
        button.pressed.connect(entry[1]);navigation.add_child(button)
    status=Label.new();status.custom_minimum_size=Vector2(910,42);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    column.add_child(status);window.get_ok_button().text="返回设置"
    ui.settings.visibility_changed.connect(func():
        if is_instance_valid(window) and not ui.settings.is_visible_in_tree():window.hide())
    window.visibility_changed.connect(func():
        if not window.visible:
            remember_position();generation+=1;selected="";reader.text="")

func open() -> void:
    if not is_instance_valid(ui) or not ui.settings.is_visible_in_tree():return
    if not is_instance_valid(window):_build()
    model.load_catalog()
    var identity:=var_to_str(model.entries).sha256_text()
    if identity!=catalog_identity:positions={};last_selected="";catalog_identity=identity
    groups=model.groups();category.clear()
    for name in groups:category.add_item(name)
    category.select(0);search.set_text("");selected=last_selected
    var preferences: Variant=ui.get("accessibility")
    var size:=21
    if preferences is Dictionary and typeof(preferences.get("subtitle_size")) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(preferences.subtitle_size)):
        size=clampi(int(preferences.subtitle_size),17,26)
    reader.add_theme_font_size_override("normal_font_size",size)
    refresh();window.popup_centered();search.grab_focus()

func refresh() -> void:
    if not is_instance_valid(list):return
    var group:=groups[category.selected] if category.selected>=0 and category.selected<groups.size() else "全部"
    remember_position()
    rows=model.select(search.text,group);list.clear()
    var chosen:=-1
    for entry in rows:
        list.add_item(String(entry.title));list.set_item_tooltip(list.item_count-1,String(entry.source))
        if entry.id==selected:chosen=list.item_count-1
    if chosen<0 and not rows.is_empty():chosen=0
    if chosen>=0:list.select(chosen);show_document(chosen)
    else:
        selected="";reader.text="没有符合检索条件的来源文件。" if model.error.is_empty() else model.error
        status.text="0项。清除检索可返回全部来源。" if model.error.is_empty() else model.error

func show_document(index: int) -> void:
    if index<0 or index>=rows.size():return
    remember_position();generation+=1
    selected=String(rows[index].id)
    var result:=model.document(selected)
    if result.ok:last_selected=selected
    reader.text=String(result.text) if result.ok else String(result.reason)
    reader.scroll_to_line(0)
    if result.ok:restore_position.call_deferred(selected,generation)
    status.text=("%d / %d · %s\n可选择正文复制；此窗口只阅读，不打开外部网站或修改旅途。" % [index+1,rows.size(),String(rows[index].source)]) if result.ok else String(result.reason)

func top() -> void:
    if is_instance_valid(window) and window.visible:reader.scroll_to_line(0);reader.grab_focus()
func bottom() -> void:
    if is_instance_valid(window) and window.visible:reader.scroll_to_line(maxi(0,reader.get_line_count()-1));reader.grab_focus()
func clear_search() -> void:
    if not is_instance_valid(window) or not window.visible:return
    search.text="";category.select(0);refresh();search.grab_focus()

func remember_position() -> void:
    if selected.is_empty() or not is_instance_valid(reader) or reader.text.is_empty():return
    positions[selected]=reader.get_v_scroll_bar().value

func restore_position(id: String, version: int) -> void:
    if not is_instance_valid(window) or not window.visible or version!=generation or id!=selected:return
    var bar:=reader.get_v_scroll_bar()
    var previous: Variant=positions.get(id,0.0)
    if typeof(previous) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(previous)):return
    bar.value=clampf(float(previous),0.0,maxf(0.0,bar.max_value-bar.page))
