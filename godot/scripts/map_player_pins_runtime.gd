extends RefCounted
## Map-owned controls persist across redraws; markers follow the map transform.
const PINS := preload("res://scripts/map_player_pins.gd")
const ATLAS := preload("res://scripts/world_atlas.gd")
const COORD := preload("res://scripts/world_coordinates.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const SURVEY := preload("res://scripts/cartography_runtime.gd")

static func setup(level: Node) -> void:
    if not level.world_mode or level.survey_map_view == null or level.map_panel.get_node_or_null("PlayerPinToolbar") != null: return
    var view: Control = level.survey_map_view
    var toolbar := Control.new()
    toolbar.name = "PlayerPinToolbar"
    toolbar.position = Vector2(350, 18)
    toolbar.size = Vector2(580, 34)
    toolbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    level.map_panel.add_child(toolbar)
    var host_ref: WeakRef = weakref(level)
    var toolbar_ref: WeakRef = weakref(toolbar)
    var view_ref: WeakRef = weakref(view)
    var kinds := OptionButton.new()
    kinds.name = "PinKind"
    kinds.size = Vector2(96, 34)
    kinds.focus_mode = Control.FOCUS_ALL
    for index in PINS.KINDS.size(): kinds.add_item(PINS.SYMBOLS[index] + " " + PINS.NAMES[index], index)
    toolbar.add_child(kinds)
    var add_button: Button = level.ui_shell._button(toolbar, "标记当前位置", Vector2(102, 0), Vector2(140, 34), func():
        _dispatch(host_ref, toolbar_ref, view_ref, "add"))
    add_button.name = "PinCurrent"
    add_button.tooltip_text = "只在已购且已补绘的房间标记；鼠标也可在地图上右键放置。"
    var list := OptionButton.new()
    list.name = "PinList"
    list.position = Vector2(248, 0)
    list.size = Vector2(218, 34)
    list.clip_text = true
    list.focus_mode = Control.FOCUS_ALL
    toolbar.add_child(list)
    var delete_button: Button = level.ui_shell._button(toolbar, "删除图钉", Vector2(472, 0), Vector2(92, 34), func():
        _dispatch(host_ref, toolbar_ref, view_ref, "delete"))
    delete_button.name = "PinDelete"
    delete_button.tooltip_text = "删除列表中选中的自定义图钉。"
    list.item_selected.connect(func(_index: int):
        _dispatch(host_ref, toolbar_ref, view_ref, "selection"))
    view.secondary_pressed.connect(func(point: Vector2):
        _dispatch(host_ref, toolbar_ref, view_ref, "point", point))
    toolbar.tooltip_text = "目标 / 留意 / 回访 · 最多12个 · 右键标记，左键仍拖动 · 可用手柄聚焦按钮。"
    var status := Label.new()
    status.name = "PlayerPinStatus"
    status.position = Vector2(34, 583)
    status.size = Vector2(1108, 17)
    status.add_theme_font_size_override("font_size", 12)
    status.add_theme_color_override("font_color", Color("e7ad7f"))
    status.text = "右键标记已补绘房间 · 上方按钮支持键盘/手柄 · 最多12个"
    level.map_panel.add_child(status)

## Weak captures matter before the guard: Godot reports an engine error when
## invoking a lambda whose captured Node was freed, even if it checks liveness.
static func _dispatch(host_ref: WeakRef, toolbar_ref: WeakRef, view_ref: WeakRef, action: String, point: Vector2 = Vector2.ZERO) -> void:
    var level: Variant = host_ref.get_ref()
    var toolbar: Control = toolbar_ref.get_ref()
    var view: Control = view_ref.get_ref()
    if not _owns(level, toolbar, view): return
    match action:
        "add": add_current(level)
        "delete": delete_selected(level)
        "point": add_at_content(level, point)
        "selection": toolbar.get_node("PinDelete").disabled = toolbar.get_node("PinList").get_selected_id() <= 0 or level.world_save_blocked

static func _owns(level: Variant, toolbar: Control, view: Control) -> bool:
    return is_instance_valid(level) and level.is_inside_tree() and not level.is_queued_for_deletion() and is_instance_valid(toolbar) and toolbar.is_inside_tree() and not toolbar.is_queued_for_deletion() and is_instance_valid(view) and view.is_inside_tree() and not view.is_queued_for_deletion() and toolbar.get_parent() == level.map_panel and toolbar == level.map_panel.get_node_or_null("PlayerPinToolbar") and view.get_parent() == level.map_panel and view == level.survey_map_view

static func configurations(level: Node) -> Dictionary:
    var configs := {String(level.config.id): level.config}
    var ids := {}
    var raw: Variant = level.story_flags.get(PINS.KEY, [])
    if raw is Array:
        for index in mini(raw.size(), PINS.MAX_SCAN):
            if raw[index] is Dictionary and raw[index].get("region_id") is String: ids[raw[index].region_id] = true
    if level.world_map_view:
        for id in ROUTES.cached_chapters(): ids[String(id)] = true
    for id in ids:
        if configs.has(id) or ROUTES.cached_config_path(String(id)).is_empty(): continue
        var config := ATLAS.configuration(String(id))
        if not config.is_empty(): configs[id] = config
    return configs

static func refresh(level: Node) -> void:
    var toolbar: Control = level.map_panel.get_node_or_null("PlayerPinToolbar")
    if toolbar == null: return
    var configs := configurations(level)
    var known := PINS.visible(level.story_flags, configs)
    var list: OptionButton = toolbar.get_node("PinList")
    var selected := list.get_selected_id() if list.item_count > 0 else -1
    list.clear()
    list.add_item("图钉 %d / %d · 请选择" % [known.size(), PINS.LIMIT], -1)
    # OptionButton replaces negative explicit IDs with the index. Reserve zero
    # for the prompt and keep positive stored pin IDs unambiguous.
    list.set_item_id(0, 0)
    for record in known:
        var room: Dictionary = PINS.owner(configs[record.region_id], Vector2(record.position[0], record.position[1]))
        var title := String(configs[record.region_id].get("chapter_name", record.region_id)) + " · " + String(room.get("name", room.id))
        list.add_item(PINS.NAMES[PINS.KINDS.find(record.kind)] + str(record.id) + " · " + title, int(record.id))
        if int(record.id) == selected: list.select(list.item_count - 1)
        if not level.world_map_view and record.region_id != String(level.config.id): continue
        var marker := Label.new()
        marker.name = "PlayerMapPin_" + str(record.id)
        marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
        marker.text = PINS.SYMBOLS[PINS.KINDS.find(record.kind)] + str(record.id)
        marker.position = project(level, record.region_id, Vector2(record.position[0], record.position[1])) - Vector2(8, 12)
        marker.add_theme_font_size_override("font_size", 19)
        marker.add_theme_color_override("font_color", [Color("b35a38"), Color("9a342f"), Color("486f82")][PINS.KINDS.find(record.kind)])
        marker.set_meta("pin_id", int(record.id))
        marker.set_meta("region_id", record.region_id)
        marker.set_meta("local_position", Vector2(record.position[0], record.position[1]))
        level.map_draw_root.add_child(marker)
    toolbar.get_node("PinCurrent").disabled = level.world_save_blocked or not PINS.allowed(level.story_flags, String(level.config.id), level.config, level.player.global_position)
    toolbar.get_node("PinDelete").disabled = level.world_save_blocked or list.get_selected_id() <= 0
    level.survey_map_view.tooltip_text = "右键：在已购且已补绘房间放置所选类型图钉 · 左键拖动 / WASD / 左摇杆 平移 · 滚轮 / PgUp/PgDn / RB/LB 缩放 · Home / Y 复位"
    level.map_text.text += "    右键标记 · 上方按钮支持手柄"

static func project(level: Node, region: String, point: Vector2) -> Vector2:
    if level.world_map_view: return ATLAS.project(COORD.to_world(region, point), ATLAS.frame(level.map_draw_root.size))
    return level._map_world_to_overlay(point, SURVEY.region_bounds(level), level.map_draw_root.size)

static func unproject(level: Node, content_point: Vector2) -> Vector2:
    if level.world_map_view:
        var layout := ATLAS.frame(level.map_draw_root.size)
        return layout.bounds.position + (content_point - layout.offset) / layout.scale
    var bounds := SURVEY.region_bounds(level)
    var size: Vector2 = level.map_draw_root.size
    var scale := minf(size.x / bounds.size.x, size.y / bounds.size.y)
    return bounds.position + (content_point - (size - bounds.size * scale) * 0.5) / scale

static func _editable(level: Node) -> bool:
    return is_instance_valid(level) and level.is_inside_tree() and level.world_mode and level.active_overlay == "map" and level.map_panel.visible and not level.world_loading and not level.chapter_transitioning and not level.world_loader.shutting_down and level.world_loader.phase == "idle" and ROUTES.cached_generation() >= 0 and is_instance_valid(level.player) and level.player.hp > 0

static func _kind(level: Node) -> String:
    return PINS.KINDS[level.map_panel.get_node("PlayerPinToolbar/PinKind").selected]

static func add_current(level: Node) -> Dictionary:
    if not _editable(level): return {"ok": false, "reason": "请在当前地图中标记。"}
    if level.world_save_blocked: return _blocked(level)
    return _commit(level, PINS.add(level.story_flags, configurations(level), String(level.config.id), level.player.global_position, _kind(level)))

static func add_at_content(level: Node, content_point: Vector2) -> Dictionary:
    if not _editable(level): return {"ok": false, "reason": "地图已关闭或区域正在切换。"}
    if level.world_save_blocked: return _blocked(level)
    var point := unproject(level, content_point)
    var configs := configurations(level)
    var region := String(level.config.id)
    if level.world_map_view:
        region = ""
        var best := INF
        for id in configs:
            var local := COORD.to_local(id, point)
            var room := PINS.owner(configs[id], local)
            if room.is_empty(): continue
            var area := SURVEY.room_rect(room).get_area()
            if area < best:
                region = id
                best = area
        if not region.is_empty(): point = COORD.to_local(region, point)
    return _commit(level, PINS.add(level.story_flags, configs, region, point, _kind(level)))

static func delete_selected(level: Node) -> Dictionary:
    if not _editable(level): return {"ok": false, "reason": "请在当前地图中删除。"}
    if level.world_save_blocked: return _blocked(level)
    var list: OptionButton = level.map_panel.get_node("PlayerPinToolbar/PinList")
    return _commit(level, PINS.remove(level.story_flags, configurations(level), list.get_selected_id()))

static func _blocked(level: Node) -> Dictionary:
    var result := {"ok": false, "reason": "归途记录暂停写入，暂不能修改图钉。"}
    _notify(level, result.reason)
    return result

static func _notify(level: Node, message: String) -> void:
    var status: Label = level.map_panel.get_node_or_null("PlayerPinStatus")
    if status != null: status.text = message
    level._toast(message)

static func _commit(level: Node, result: Dictionary) -> Dictionary:
    if not result.ok:
        _notify(level, result.reason)
        return result
    var existed: bool = level.story_flags.has(PINS.KEY)
    var old: Variant = level.story_flags.get(PINS.KEY)
    level.story_flags[PINS.KEY] = result.records
    if not level._save_world():
        if existed: level.story_flags[PINS.KEY] = old
        else: level.story_flags.erase(PINS.KEY)
        result = {"ok": false, "reason": "图钉未能保存，本次修改已撤回。"}
    level._refresh_map_overlay()
    _notify(level, result.reason)
    return result
