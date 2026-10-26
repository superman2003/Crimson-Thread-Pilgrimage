extends RefCounted
## Logical 1280x720 UI layout. Window scaling remains the shell's responsibility.
## Keep the clipped map canvas separate from controls and readable explanations.
const VIEW := Rect2(34,78,1108,462)
const TOOLBAR := Rect2(34,550,668,34)
const DIRECTORY := Rect2(1008,550,134,32)
const EXPEDITION := Rect2(860,550,134,32)
const STATUS := Rect2(34,590,965,17)
const LEGEND := Rect2(34,610,965,18)
const HELP := Rect2(1008,590,134,32)
const HELP_BUTTON := "MapLegendButton"
const HELP_WINDOW := "MapLegendWindow"

static func place(control: Control, rect: Rect2) -> void:
    if not is_instance_valid(control):return
    control.position=rect.position
    control.size=rect.size

static func apply(level: Node) -> void:
    if not is_instance_valid(level) or not level.get("world_mode"):return
    var panel: Control=level.get("map_panel")
    if not is_instance_valid(panel):return
    var view: Control=level.get("survey_map_view")
    var content: Control=level.get("map_draw_root")
    # Initial sizing precedes the first map draw. Reapplying the same layout
    # neither resets the camera nor discards its per-region pan/zoom memory.
    if is_instance_valid(content):content.size=VIEW.size
    if is_instance_valid(view):place(view,VIEW)
    var toolbar:=panel.get_node_or_null("PlayerPinToolbar") as Control
    if toolbar!=null:place(toolbar,TOOLBAR)
    place(panel.get_node_or_null("MapDirectoryButton") as Control,DIRECTORY)
    place(panel.get_node_or_null("ExpeditionDeskButton") as Control,EXPEDITION)
    var status:=panel.get_node_or_null("PlayerPinStatus") as Label
    if status!=null:
        status.clip_text=true
        status.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
        place(status,STATUS)
        status.tooltip_text=status.text
    var legend: Label=level.get("map_text")
    if is_instance_valid(legend):
        legend.autowrap_mode=TextServer.AUTOWRAP_OFF
        legend.max_lines_visible=1
        legend.clip_text=true
        legend.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
        place(legend,LEGEND)
    if panel.has_node(HELP_BUTTON):
        place(panel.get_node(HELP_BUTTON) as Control,HELP)
        return
    var host: WeakRef=weakref(level)
    var parent: WeakRef=weakref(panel)
    var button: Button=level.ui_shell._button(panel,"地图说明",HELP.position,HELP.size,func():open_help(host,parent))
    button.name=HELP_BUTTON
    button.add_theme_font_size_override("font_size",13)
    button.tooltip_text="完整阅读当前地图的路线/危险说明和图钉提示；支持键盘和手柄焦点。"

static func owns(host: WeakRef, parent: WeakRef) -> bool:
    var level: Variant=host.get_ref()
    var panel: Variant=parent.get_ref()
    return is_instance_valid(level) and level.is_inside_tree() and not level.is_queued_for_deletion() and is_instance_valid(panel) and panel.is_inside_tree() and not panel.is_queued_for_deletion() and level.map_panel==panel

static func open_help(host: WeakRef, parent: WeakRef) -> void:
    if not owns(host,parent):return
    var level: Variant=host.get_ref()
    var panel: Control=parent.get_ref()
    if level.active_overlay!="map" or not panel.is_visible_in_tree() or level.world_loading:return
    var window:=panel.get_node_or_null(HELP_WINDOW) as AcceptDialog
    # A previous region may still be queued for deletion with its modal alive.
    # Respect the native root's current exclusive child instead of opening two.
    for child in panel.get_window().find_children("*","Window",true,false):
        if child is Window and child!=window and child.visible and child.exclusive:return
    if window==null:
        window=AcceptDialog.new()
        window.name=HELP_WINDOW
        window.title="地图说明"
        window.transient=true
        window.exclusive=true
        window.min_size=Vector2i(780,500)
        window.theme=level.ui_shell.theme
        window.ok_button_text="返回地图"
        panel.add_child(window)
        var text:=RichTextLabel.new()
        text.name="LegendText"
        text.custom_minimum_size=Vector2(730,400)
        text.bbcode_enabled=false
        text.scroll_active=true
        text.focus_mode=Control.FOCUS_ALL
        text.add_theme_font_size_override("normal_font_size",17)
        text.add_theme_color_override("default_color",level.ui_shell.IVORY)
        window.add_child(text)
        level.ui_shell.register_text_entry_window(window)
        var weak_window: WeakRef=weakref(window)
        panel.visibility_changed.connect(func():
            var dialog: Variant=weak_window.get_ref()
            var owner: Variant=parent.get_ref()
            if is_instance_valid(dialog) and (not is_instance_valid(owner) or not owner.is_visible_in_tree()):dialog.hide())
        window.confirmed.connect(func():restore_focus(host,parent))
        window.canceled.connect(func():restore_focus(host,parent))
    var label:=window.get_node("LegendText") as RichTextLabel
    var message:=String(level.map_text.text) if is_instance_valid(level.map_text) else ""
    var status:=panel.get_node_or_null("PlayerPinStatus") as Label
    label.text="当前地图\n"+message
    if status!=null and not status.text.is_empty():label.text+="\n\n图钉提示\n"+status.text
    if message.is_empty():label.text="当前地图尚无额外说明。"
    label.scroll_to_line(0)
    window.popup_centered()
    window.get_ok_button().grab_focus()

static func restore_focus(host: WeakRef, parent: WeakRef) -> void:
    if not owns(host,parent):return
    var panel: Control=parent.get_ref()
    var button:=panel.get_node_or_null(HELP_BUTTON) as Button
    if panel.is_visible_in_tree() and is_instance_valid(button):button.grab_focus()
