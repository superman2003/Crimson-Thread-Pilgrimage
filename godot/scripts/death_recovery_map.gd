extends RefCounted
const READOUT:=preload("res://scripts/death_recovery_readout.gd")
const ATLAS:=preload("res://scripts/world_atlas.gd")
const PINS:=preload("res://scripts/map_player_pins_runtime.gd")
const BUTTON:="DeathRecoveryButton"
const WINDOW:="DeathRecoveryWindow"
const RECT:=Rect2(810,18,126,34)

static func snapshot(level: Node) -> Dictionary:
    if level.world_state==null:return READOUT.describe({}, {}, {}, "")
    var cache: Variant=level.world_state.data.get("death_cache",{})
    var configs:={}
    if cache is Dictionary and cache.get("region_id") is String:
        var region:=String(cache.region_id)
        # Never load an undiscovered region just to describe its saved knot.
        if region==String(level.config.get("id","")):configs[region]=level.config
        else:
            var saved: Variant=level.world_state.data.get("regions",{})
            var record: Variant=saved.get(region,{}) if saved is Dictionary else {}
            var visits: Variant=record.get("visited_rooms",{}) if record is Dictionary else {}
            var known:=false
            if visits is Dictionary:
                for value in visits.values():
                    if value is bool and value:known=true;break
            if known:
                var data:=ATLAS.configuration(region)
                if not data.is_empty():configs[region]=data
    return READOUT.describe(cache,level.story_flags,configs,String(level.config.get("id","")))

static func setup(level: Node) -> void:
    if not level.world_mode or not is_instance_valid(level.map_panel) or level.map_panel.has_node(BUTTON):return
    var host: WeakRef=weakref(level)
    var parent: WeakRef=weakref(level.map_panel)
    var button: Button=level.ui_shell._button(level.map_panel,"归途结",RECT.position,RECT.size,func():open(host,parent))
    button.name=BUTTON
    button.add_theme_font_size_override("font_size",14)
    button.tooltip_text="查看遗留碎钱、已知落点与召回取舍；不会移动角色或花费资源。"
    var title:=level.map_panel.get_node_or_null("SurveyMapTitle") as Label
    if title!=null:
        title.size.x=640
        title.clip_text=true
        title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS

static func owns(host: WeakRef, parent: WeakRef) -> bool:
    var level: Variant=host.get_ref()
    var panel: Variant=parent.get_ref()
    return is_instance_valid(level) and level.is_inside_tree() and not level.is_queued_for_deletion() and is_instance_valid(panel) and panel.is_inside_tree() and not panel.is_queued_for_deletion() and level.map_panel==panel

static func usable(host: WeakRef, parent: WeakRef) -> bool:
    if not owns(host,parent):return false
    var level: Variant=host.get_ref()
    return level.active_overlay=="map" and level.map_panel.is_visible_in_tree() and not level.world_loading and not level.chapter_transitioning

static func refresh(level: Node, dialog: AcceptDialog, prefix: String="") -> void:
    render(level)
    var data:=snapshot(level)
    dialog.set_meta("knot_fingerprint",data.fingerprint)
    dialog.get_node("RecoveryText").text=prefix+String(data.text)
    dialog.get_node("RecoveryText").scroll_to_line(0)
    var locate:=dialog.find_child("LocateKnot",true,false) as Button
    locate.disabled=not data.locatable
    locate.tooltip_text="仅框取已购且已补绘的落点；不传送、不找回、不授予地图。" if data.locatable else "落点尚无可定位的已补绘记录。"
    if locate.disabled and locate.has_focus():dialog.get_ok_button().grab_focus()

static func open(host: WeakRef, parent: WeakRef) -> void:
    if not usable(host,parent):return
    var level: Variant=host.get_ref()
    var panel: Control=parent.get_ref()
    var dialog:=panel.get_node_or_null(WINDOW) as AcceptDialog
    for child in panel.get_window().find_children("*","Window",true,false):
        if child is Window and child!=dialog and child.visible and child.exclusive:return
    if dialog==null:
        dialog=AcceptDialog.new()
        dialog.name=WINDOW
        dialog.title="归途结 · 失落与找回"
        dialog.theme=level.ui_shell.theme
        dialog.transient=true
        dialog.exclusive=true
        dialog.min_size=Vector2i(760,510)
        dialog.ok_button_text="返回地图"
        panel.add_child(dialog)
        var text:=RichTextLabel.new()
        text.name="RecoveryText"
        text.bbcode_enabled=false
        text.scroll_active=true
        text.focus_mode=Control.FOCUS_ALL
        text.custom_minimum_size=Vector2(700,390)
        text.add_theme_font_size_override("normal_font_size",18)
        dialog.add_child(text)
        var locate_button:=dialog.add_button("在图上查看",false,"locate")
        locate_button.name="LocateKnot"
        dialog.add_button("刷新记录",true,"refresh")
        var window: WeakRef=weakref(dialog)
        dialog.custom_action.connect(func(action: String):
            if not usable(host,parent) or not is_instance_valid(window.get_ref()):return
            if action=="refresh":refresh(host.get_ref(),window.get_ref())
            elif action=="locate":locate(host,parent,window))
        dialog.confirmed.connect(func():restore_focus(host,parent))
        dialog.canceled.connect(func():restore_focus(host,parent))
        panel.visibility_changed.connect(func():
            var target: Variant=window.get_ref()
            var owner: Variant=parent.get_ref()
            if is_instance_valid(target) and (not is_instance_valid(owner) or not owner.is_visible_in_tree()):target.hide())
        level.ui_shell.register_text_entry_window(dialog)
    refresh(level,dialog)
    dialog.popup_centered()
    dialog.get_ok_button().grab_focus()

static func locate(host: WeakRef, parent: WeakRef, window: WeakRef) -> void:
    if not usable(host,parent):return
    var level: Variant=host.get_ref()
    var dialog:=window.get_ref() as AcceptDialog
    if not is_instance_valid(dialog) or dialog.is_queued_for_deletion() or not dialog.visible:return
    var data:=snapshot(level)
    if not data.locatable or data.fingerprint!=String(dialog.get_meta("knot_fingerprint","")):
        refresh(level,dialog,"归途结或地图记录已变化，请重新核对。\n\n")
        return
    if not level.world_map_view and String(data.region)!=String(level.config.id):
        level.world_map_view=true
        level._refresh_map_overlay()
    var point:=PINS.project(level,String(data.region),data.point)
    if not is_instance_valid(level.survey_map_view) or not level.survey_map_view.center_on(point):
        refresh(level,dialog,"当前地图尚未准备好，请稍后重试。\n\n")
        return
    render(level)
    dialog.hide()
    restore_focus(host,parent)

static func restore_focus(host: WeakRef, parent: WeakRef) -> void:
    if not usable(host,parent):return
    var button:=parent.get_ref().get_node_or_null(BUTTON) as Button
    if is_instance_valid(button):button.grab_focus()

static func render(level: Node) -> void:
    var root: Control=level.map_draw_root
    if not is_instance_valid(root):return
    var old:=root.get_node_or_null("DeathRecoveryMarker")
    if old!=null:old.free()
    var data:=snapshot(level)
    if not data.locatable or (not level.world_map_view and String(data.region)!=String(level.config.id)):return
    var point:=PINS.project(level,String(data.region),data.point)
    if not point.is_finite():return
    var marker:=Label.new()
    marker.name="DeathRecoveryMarker"
    marker.text="◎ 归途结"
    marker.position=point-Vector2(10,14)
    marker.mouse_filter=Control.MOUSE_FILTER_IGNORE
    marker.add_theme_font_size_override("font_size",14)
    marker.add_theme_color_override("font_color",Color("e9c276"))
    marker.add_theme_color_override("font_outline_color",Color("18252c"))
    marker.add_theme_constant_override("outline_size",4)
    root.add_child(marker)
