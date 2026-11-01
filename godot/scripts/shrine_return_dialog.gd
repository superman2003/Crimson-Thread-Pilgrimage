extends RefCounted
const NETWORK:=preload("res://scripts/shrine_return_network.gd")
const BUTTON:="ShrineReturnButton"
const WINDOW:="ShrineReturnWindow"
const QUOTE:="shrine_quote"

static func setup(level: Node) -> void:
    if not level.world_mode or not is_instance_valid(level.map_panel) or level.map_panel.has_node(BUTTON):return
    var host: WeakRef=weakref(level)
    var panel: WeakRef=weakref(level.map_panel)
    var button: Button=level.ui_shell._button(level.map_panel,"钟龛回访",Vector2(710,550),Vector2(134,32),func():open(host,panel))
    button.name=BUTTON
    button.add_theme_font_size_override("font_size",13)
    button.size=Vector2(134,32)
    button.tooltip_text="查看各区最近安坐的钟龛；先在当前钟龛安坐，再沿已开放钟路返回。"

static func valid(host: WeakRef, owner: WeakRef) -> bool:
    var level: Variant=host.get_ref()
    var panel: Variant=owner.get_ref()
    return is_instance_valid(level) and level.is_inside_tree() and not level.is_queued_for_deletion() and is_instance_valid(panel) and not panel.is_queued_for_deletion() and level.map_panel==panel

static func open(host: WeakRef, owner: WeakRef) -> void:
    if not valid(host,owner):return
    var level: Variant=host.get_ref()
    var panel: Control=owner.get_ref()
    if level.active_overlay!="map" or not panel.is_visible_in_tree() or level.world_loading:return
    var window:=panel.get_node_or_null(WINDOW) as ConfirmationDialog
    for child in panel.get_window().find_children("*","Window",true,false):
        if child is Window and child!=window and child.visible and child.exclusive:return
    if window==null:
        window=ConfirmationDialog.new()
        window.name=WINDOW
        window.title="钟龛回访 · 各区最近安坐处"
        window.theme=level.ui_shell.theme
        window.exclusive=true
        window.transient=true
        window.dialog_hide_on_ok=false
        window.min_size=Vector2i(800,510)
        window.ok_button_text="确认返回"
        window.cancel_button_text="留在这里"
        panel.add_child(window)
        var column:=VBoxContainer.new()
        column.custom_minimum_size=Vector2(740,390)
        window.add_child(column)
        var hint:=Label.new()
        hint.text="各区仅列出最近安坐且与原址一致的钟龛。未知站点不会列出。"
        hint.add_theme_font_size_override("font_size",16)
        column.add_child(hint)
        var list:=ItemList.new()
        list.name="Stations"
        list.custom_minimum_size=Vector2(740,190)
        column.add_child(list)
        var text:=RichTextLabel.new()
        text.name="Route"
        text.bbcode_enabled=false
        text.scroll_active=true
        text.custom_minimum_size=Vector2(740,160)
        text.add_theme_font_size_override("normal_font_size",17)
        text.add_theme_color_override("default_color",level.ui_shell.IVORY)
        column.add_child(text)
        var weak_window: WeakRef=weakref(window)
        list.item_selected.connect(func(index: int):select(host,owner,weak_window,index))
        window.confirmed.connect(func():confirm(host,owner,weak_window))
        window.canceled.connect(func():focus_source(host,owner))
        panel.visibility_changed.connect(func():
            var dialog: Variant=weak_window.get_ref()
            var parent: Variant=owner.get_ref()
            if is_instance_valid(dialog) and (not is_instance_valid(parent) or not parent.is_visible_in_tree()):dialog.hide())
        level.ui_shell.register_text_entry_window(window)
    var list:=window.find_child("Stations",true,false) as ItemList
    list.clear()
    var rows:=NETWORK.stations(level)
    window.set_meta("stations",rows)
    window.set_meta(QUOTE,{})
    for row in rows:list.add_item(String(row.region_name)+" · "+String(row.title))
    if rows.is_empty():
        window.find_child("Route",true,false).text="尚无可靠的钟龛安坐记录。正常探索并安坐后，再来查看。"
        window.get_ok_button().disabled=true
    else:
        list.select(0)
        select(host,owner,weakref(window),0)
    window.popup_centered()
    window.get_cancel_button().grab_focus()

static func select(host: WeakRef, owner: WeakRef, dialog: WeakRef, index: int) -> void:
    if not valid(host,owner):return
    var window:=dialog.get_ref() as ConfirmationDialog
    if not is_instance_valid(window):return
    var rows: Array=window.get_meta("stations",[])
    if index<0 or index>=rows.size():return
    var quote:=NETWORK.quote(host.get_ref(),String(rows[index].key))
    window.set_meta(QUOTE,quote)
    var text:=window.find_child("Route",true,false) as RichTextLabel
    text.text=String(quote.reason)
    if quote.ok:
        var names: Array[String]=[]
        for region in quote.path:names.append(String(NETWORK.NAMES[region]))
        text.text+="\n\n经过："+" → ".join(names)+"\n出发前必须成功写入归途记录；取消或写入失败留在原处。"
    window.get_ok_button().disabled=not quote.ok

static func confirm(host: WeakRef, owner: WeakRef, dialog: WeakRef) -> void:
    if not valid(host,owner):return
    var level: Variant=host.get_ref()
    var window:=dialog.get_ref() as ConfirmationDialog
    if not is_instance_valid(window) or not window.visible or level.active_overlay!="map":return
    var quote: Dictionary=window.get_meta(QUOTE,{})
    if not quote.get("ok",false):return
    var result:=NETWORK.begin(level,String(quote.target.key),String(quote.fingerprint))
    if not result.ok:
        window.find_child("Route",true,false).text=String(result.reason)
        window.get_ok_button().disabled=true
        window.set_meta(QUOTE,{})
        return
    window.hide()

static func focus_source(host: WeakRef, owner: WeakRef) -> void:
    if not valid(host,owner):return
    var panel: Control=owner.get_ref()
    if panel.is_visible_in_tree():panel.get_node(BUTTON).grab_focus()
