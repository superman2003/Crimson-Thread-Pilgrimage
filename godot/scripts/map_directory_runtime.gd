extends RefCounted
const INDEX = preload("res://scripts/map_directory.gd")
const JOURNAL = preload("res://scripts/pilgrimage_cartography.gd")
const ATLAS = preload("res://scripts/world_atlas.gd")
const ROUTES = preload("res://scripts/world_routes.gd")
const PINS = preload("res://scripts/map_player_pins.gd")
const PIN_VIEW = preload("res://scripts/map_player_pins_runtime.gd")

static func setup(level: Node) -> void:
    if not level.world_mode or level.map_panel==null or level.map_panel.has_node("MapDirectoryButton"):return
    var host: WeakRef=weakref(level);var panel: WeakRef=weakref(level.map_panel)
    var button: Button=level.ui_shell._button(level.map_panel,"已知地点目录",Vector2(1008,585),Vector2(134,32),func():
        var owner: Variant=host.get_ref();var map: Variant=panel.get_ref()
        if _owns(owner,map):open(owner))
    button.name="MapDirectoryButton"
    button.add_theme_font_size_override("font_size",13)
    button.tooltip_text="搜索已购且已补绘的房间、能力门、危险、捷径和自定义图钉；只改变视野。"
    var status: Label=level.map_panel.get_node_or_null("PlayerPinStatus")
    if status!=null:status.size.x=965;status.clip_text=true
    level.map_text.size.x=965

static func _owns(level: Variant, panel: Variant) -> bool:
    return is_instance_valid(level) and level.is_inside_tree() and not level.is_queued_for_deletion() and is_instance_valid(panel) and panel==level.map_panel and panel.is_inside_tree() and not panel.is_queued_for_deletion()

static func configurations(level: Node) -> Dictionary:
    var configs:={}
    var journals: Variant=level.story_flags.get(JOURNAL.KEY,{})
    if not journals is Dictionary:return configs
    for id in journals:
        if not id is String or not journals[id] is Dictionary or not journals[id].get("owned") is bool or not journals[id].owned:continue
        if id==String(level.config.id):configs[id]=level.config
        elif not ROUTES.cached_config_path(id).is_empty():
            var config:=ATLAS.configuration(id)
            if not config.is_empty():configs[id]=config
    return configs

static func rows(level: Node) -> Array:
    return INDEX.records(configurations(level),level.story_flags,level.inventory_counts,level.opened_shortcuts)

static func open(level: Node) -> void:
    if level.active_overlay!="map" or not level.map_panel.visible or level.world_loading:return
    var dialog: AcceptDialog=level.map_panel.get_node_or_null("MapDirectoryDialog")
    if dialog==null:
        dialog=preload("res://scripts/map_directory_dialog.gd").new()
        dialog.name="MapDirectoryDialog";level.map_panel.add_child(dialog)
        level.ui_shell.register_text_entry_window(dialog)
        var reference: WeakRef=weakref(dialog)
        level.map_panel.visibility_changed.connect(func():
            var window:=reference.get_ref() as AcceptDialog
            if is_instance_valid(window) and not window.get_parent().is_visible_in_tree():window.hide())
    var host: WeakRef=weakref(level);var panel: WeakRef=weakref(level.map_panel)
    dialog.open(rows(level),func(row: Dictionary):
        var owner: Variant=host.get_ref();var map: Variant=panel.get_ref()
        return focus(owner,row) if _owns(owner,map) else {"ok":false,"reason":"地图已经关闭或重建。"})

static func focus(level: Node, candidate: Dictionary) -> Dictionary:
    if level.active_overlay!="map" or not level.map_panel.visible or level.world_loading or level.chapter_transitioning:return {"ok":false,"reason":"请在当前地图中查看。"}
    for row in rows(level):
        if row.key!=candidate.get("key",""):continue
        # Rebuild from current knowledge; never trust a stale supplied point.
        if not level.world_map_view and row.region!=String(level.config.id):level.world_map_view=true;level._refresh_map_overlay()
        var point:=PIN_VIEW.project(level,row.region,row.point)
        if not level.survey_map_view.center_on(point):return {"ok":false,"reason":"当前地图无法框取此处。"}
        PIN_VIEW._notify(level,"正在查看「%s」；角色与旅途进度不变。" % String(row.title))
        return {"ok":true}
    return {"ok":false,"reason":"地点已不在已购且已补绘的记录中。"}
