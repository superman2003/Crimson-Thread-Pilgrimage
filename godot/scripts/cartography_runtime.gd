extends RefCounted
const JOURNAL := preload("res://scripts/pilgrimage_cartography.gd")
const SURFACE := preload("res://scripts/survey_map_surface.gd")
const INK := preload("res://scripts/hand_drawn_map_room.gd")
const KNOWLEDGE := preload("res://scripts/survey_map_knowledge.gd")
static func setup(level: Node) -> void:
    var sellers: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/cartography_sellers.json"))
    var seller: Dictionary = sellers.get(String(level.config.id),{})
    var area := level.get_node_or_null(NodePath(String(seller.get("npc_id","")))) as Area2D
    if area == null:
        push_error("Missing authored map NPC for " + String(level.config.id))
        return
    area.set_meta("map_seller_region",String(level.config.id))
    area.set_meta("map_seller_data",seller.duplicate(true))
    area.set_meta("interaction_label",String(area.get_meta("label","地图NPC"))+" · 交谈 / 购买本区地图")
    var dialog := ConfirmationDialog.new()
    dialog.name="MapPurchaseDialog"
    dialog.theme=level.ui_shell.theme.duplicate()
    dialog.theme.set_font("title_font","Window",preload("res://assets/fonts/NotoSansSC.ttf"))
    var frame:=StyleBoxFlat.new()
    frame.bg_color=Color("18252c")
    frame.border_color=Color("bda176")
    frame.set_border_width_all(2)
    dialog.theme.set_stylebox("panel","AcceptDialog",frame)
    dialog.get_label().autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    dialog.get_label().custom_minimum_size=Vector2(450,130)
    dialog.title=String(area.get_meta("label","地图NPC"))+" · 本区地图"
    dialog.dialog_text=String(seller.get("note",""))+"\n\n本区地图：%d枚松脂碎钱" % seller_price(seller)
    dialog.ok_button_text="购买底图"
    dialog.cancel_button_text="暂不购买"
    level.add_child(dialog)
    var talk := dialog.add_button("交谈",true,"talk")
    talk.name="MapSellerTalk"
    # Every seller stocks the two survey tools until the player owns them, so
    # missing one cartographer never locks out charting or positioning.
    var quill := dialog.add_button("盐墨绘针",false,"quill")
    quill.name="MapSellerQuill"
    var compass := dialog.add_button("钟骨罗盘",false,"compass")
    compass.name="MapSellerCompass"
    dialog.custom_action.connect(func(action: String):
        if action=="talk":
            level._close_overlays()
            level._talk_to_npc(area)
        elif action in ["quill","compass"]:
            purchase_tool(level,area,action)
            open_shop(level,area))
    dialog.confirmed.connect(func():
        purchase(level,area)
        level._close_overlays())
    dialog.canceled.connect(func():level._close_overlays())
static func open_shop(level: Node, area: Area2D) -> void:
    level._close_overlays()
    level.active_overlay="cartographer"
    level._sync_ui_input_lock()
    var dialog: ConfirmationDialog=level.get_node("MapPurchaseDialog")
    var is_owned := JOURNAL.owned(level.story_flags,String(level.config.id))
    var price := seller_price(area.get_meta("map_seller_data",{}))
    dialog.dialog_text=String(area.get_meta("map_seller_data",{}).get("note",""))+"\n\n"+("已获得此区域地图。安坐钟龛补绘途中笔记。" if is_owned else "本区地图：%d枚松脂碎钱 · 当前%d枚" % [price,level.currency_count])
    dialog.get_ok_button().disabled=is_owned or level.currency_count<price
    for kind in ["quill","compass"]:
        var button: Button=dialog.find_child("MapSeller"+kind.capitalize(),true,false)
        var tool_cost := tool_price(kind)
        button.visible=not owns_tool(level,kind)
        button.text=("盐墨绘针" if kind=="quill" else "钟骨罗盘")+" · %d枚" % tool_cost
        button.disabled=level.currency_count<tool_cost
        button.tooltip_text="安坐钟龛时把途中笔记补绘进所有已购地图。" if kind=="quill" else "行旅铭饰：装备后地图标出你的位置。"
    if not owns_tool(level,"quill"):
        dialog.dialog_text+="\n盐墨绘针：没有它，钟龛无法补绘途中笔记（笔记会保留）。"
    dialog.popup_centered(Vector2i(530,250))
    (dialog.get_ok_button() if not dialog.get_ok_button().disabled else dialog.get_cancel_button()).grab_focus()
static func purchase(level: Node, area: Area2D) -> Dictionary:
    if not level.world_mode or not is_instance_valid(area) or String(area.get_meta("map_seller_region",""))!=String(level.config.id) or level.player.global_position.distance_to(area.global_position)>150 or level.player.hp<=0 or level.player.death_timer>0 or level.chapter_transitioning:
        return {"ok":false,"reason":"请靠近本区地图NPC购买。"}
    var result := JOURNAL.purchase(level.story_flags,String(level.config.id),level.currency_count,seller_price(area.get_meta("map_seller_data",{})))
    if result.ok:
        level.currency_count=int(result.wallet)
        area.set_meta("interaction_label",String(area.get_meta("label","地图NPC"))+" · 交谈 / 已购地图")
        level._save_world()
        level._refresh_hud()
    level._toast(String(result.reason))
    return result
const COMPASS_PRICE := 15
static func tool_price(kind: String) -> int:
    return JOURNAL.QUILL_PRICE if kind=="quill" else COMPASS_PRICE
static func owns_tool(level: Node, kind: String) -> bool:
    if kind=="quill": return JOURNAL.has_quill(level.story_flags)
    return level.build_system!=null and level.build_system.state.unlocked_passives.has("compass")
static func purchase_tool(level: Node, area: Area2D, kind: String) -> Dictionary:
    if not level.world_mode or not is_instance_valid(area) or String(area.get_meta("map_seller_region",""))!=String(level.config.id) or level.player.global_position.distance_to(area.global_position)>150 or level.player.hp<=0 or level.player.death_timer>0 or level.chapter_transitioning:
        return {"ok":false,"reason":"请靠近地图NPC购买。"}
    if kind not in ["quill","compass"]: return {"ok":false,"reason":"没有这件工具。"}
    if owns_tool(level,kind):
        level._toast("已经有了。")
        return {"ok":false,"reason":"已经有了。"}
    var price := tool_price(kind)
    if level.currency_count<price:
        level._toast("需要%d枚松脂碎钱。" % price)
        return {"ok":false,"reason":"需要%d枚松脂碎钱。" % price}
    level.currency_count-=price
    var message := ""
    if kind=="quill":
        JOURNAL.grant_quill(level.story_flags)
        message="收好盐墨绘针。之后安坐钟龛，途中笔记会补绘进所有已购地图。"
    else:
        level.build_system.unlock_event("charm_compass_found")
        message="收好钟骨罗盘。装在行旅铭饰槽，地图就会标出你的位置。"
    level._save_world()
    level._refresh_hud()
    level._toast(message)
    return {"ok":true,"reason":message}
## Position on the map comes from an equipped compass, or the navigation-assist
## accessibility setting. Outside the world (single demos) it always shows.
static func shows_position(level: Node) -> bool:
    if not level.world_mode: return true
    if level.ui_shell!=null and bool(level.ui_shell.get_accessibility("navigation_assist",false)): return true
    return level.build_system!=null and level.build_system.state.passives.has("compass")
static func seller_price(seller: Dictionary) -> int:
    return int(seller.get("price", JOURNAL.PRICE))
static func public_room(room: Dictionary) -> bool:
    return String(room.get("kind","")) not in ["secret","reward","treasure","exit"] and not bool(room.get("hidden",false)) and not String(room.get("id","")).begins_with("upgrade_")
static func region_bounds(level: Node) -> Rect2:
    # Visibility never changes the coordinate frame. Reserve space for every
    # authored room without emitting its outline, label or connections.
    var bounds := Rect2()
    for room in level.config.get("map_rooms", []):
        var rect := room_rect(room)
        if rect.size.x <= 0 or rect.size.y <= 0: continue
        bounds = rect if bounds.size == Vector2.ZERO else bounds.merge(rect)
    return bounds.grow(180)

static func terrain_polygons(level: Node) -> Array[PackedVector2Array]:
    var polygons: Array[PackedVector2Array]=[]
    if level.chapter_terrain!=null:
        for region in level.chapter_terrain.collision_regions:
            polygons.append(region.polygon)
    for platform in level.config.get("platforms",[]):
        if not String(platform.get("terrain_id","")).is_empty(): continue
        var rect: Rect2=level._rect2(platform.rect)
        polygons.append(rect_polygon(rect))
    return polygons
## Charted sections of a partly explored large room, in overlay coordinates.
static func map_parts(level: Node, id: String, room: Dictionary, bounds: Rect2, draw_size: Vector2) -> Array[Rect2]:
    var result: Array[Rect2]=[]
    for part in JOURNAL.charted_parts(level.story_flags,id,room):
        var top_left: Vector2=level._map_world_to_overlay(part.position,bounds,draw_size)
        result.append(Rect2(top_left,level._map_world_to_overlay(part.end,bounds,draw_size)-top_left))
    return result
static func rect_polygon(rect: Rect2) -> PackedVector2Array:
    return PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
static func map_position(level: Node, room: Dictionary, point: Vector2, bounds: Rect2, draw_size: Vector2) -> Vector2:
    return level._map_world_to_overlay(point, bounds, draw_size)

static func room_terrain(level: Node, room: Dictionary, polygons: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
    return room_terrain_config(level.config, room, polygons)
static func room_terrain_config(config: Dictionary, room: Dictionary, polygons: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
    var physical := room_rect(room)
    var contours: Array[PackedVector2Array]=[]
    if physical.size.x<=0 or physical.size.y<=0: return contours
    for polygon in polygons:
        var fragments: Array[PackedVector2Array]=Geometry2D.intersect_polygons(polygon,rect_polygon(physical))
        # Nested pockets belong to their own exploration record. Charting the
        # enclosing hall must not disclose their terrain before resting.
        for other in config.get("map_rooms",[]):
            if String(other.id)==String(room.id): continue
            var pocket := room_rect(other)
            if pocket.get_area()>=physical.get_area() or not physical.intersects(pocket): continue
            var remaining: Array[PackedVector2Array]=[]
            for fragment in fragments:
                remaining.append_array(exclude_pocket(fragment,pocket))
            fragments=remaining
        for fragment in fragments:
            var normalized:=PackedVector2Array()
            for point in fragment:
                normalized.append((point-physical.position)/physical.size)
            contours.append(normalized)
    return contours
static func room_rect(room: Dictionary) -> Rect2:
    var value: Array = room.get("layout_rect", room.get("play_rect", []))
    return Rect2(value[0], value[1], value[2], value[3]) if value.size() >= 4 else Rect2()
static func exclude_pocket(polygon: PackedVector2Array, pocket: Rect2) -> Array[PackedVector2Array]:
    var bounds:=Rect2(polygon[0],Vector2.ZERO)
    for point in polygon: bounds=bounds.expand(point)
    if not bounds.intersects(pocket): return [polygon]
    var cut:=bounds.intersection(pocket)
    var result: Array[PackedVector2Array]=[]
    # Four disjoint slabs avoid hole loops (which draw_colored_polygon would
    # otherwise fill back in and disclose an uncharted nested pocket).
    var slabs: Array[Rect2]=[
        Rect2(bounds.position,Vector2(cut.position.x-bounds.position.x,bounds.size.y)),
        Rect2(Vector2(cut.end.x,bounds.position.y),Vector2(bounds.end.x-cut.end.x,bounds.size.y)),
        Rect2(Vector2(cut.position.x,bounds.position.y),Vector2(cut.size.x,cut.position.y-bounds.position.y)),
        Rect2(Vector2(cut.position.x,cut.end.y),Vector2(cut.size.x,bounds.end.y-cut.end.y))]
    for slab in slabs:
        if slab.size.x>0 and slab.size.y>0:
            result.append_array(Geometry2D.intersect_polygons(polygon,rect_polygon(slab)))
    return result
static func paper(level: Node, enabled: bool) -> void:
    var art: TextureRect=level.map_panel.get_node("MapBackgroundArt")
    art.texture=load("res://assets/ui/cartography/survey_paper.svg") if enabled else level._load_texture_resource(level._theme_map_background_texture())
    art.modulate=Color.WHITE if enabled else Color(1,1,1,0.07)
    level.map_text.add_theme_color_override("font_color",SURFACE.INK if enabled else Color("dae6d5"))
    for child in level.map_panel.get_children():
        if child is Label:
            child.add_theme_color_override("font_color",SURFACE.INK if enabled else Color("b5a17c"))
static func render(level: Node) -> void:
    paper(level,true)
    if level.wish_panel!=null: level.wish_panel.visible=false
    var id := String(level.config.id)
    var journal := JOURNAL.region(level.story_flags,id)
    var host: Control=level.map_draw_root
    if not bool(journal.owned):
        var notice := Label.new()
        notice.name="MapNotPurchased"
        notice.position=Vector2(100,100)
        notice.size=Vector2(870,180)
        notice.text="还未获得此区域地图"
        notice.add_theme_color_override("font_color",SURFACE.INK)
        notice.add_theme_font_size_override("font_size",21)
        host.add_child(notice)
        level.map_text.text="%s / %s 返回 · %s 世界总览" % [level.ui_shell._short_binding("map"),level.ui_shell._short_binding("close_overlay"),level.ui_shell._short_binding("inventory")]
        return
    var rooms: Array=[]
    var ids := {}
    for value in level.config.get("map_rooms",[]):
        if public_room(value) or JOURNAL.charted(level.story_flags,id,String(value.id)):
            rooms.append(value)
            ids[String(value.id)]=true
    var bounds: Rect2=region_bounds(level)
    var draw_size: Vector2=host.size
    var terrain: Array[PackedVector2Array]=terrain_polygons(level)
    var surface := SURFACE.new()
    surface.name = "SurveySilhouette"
    surface.size = host.size
    host.add_child(surface)
    for room in rooms:
        var room_id:=String(room.id)
        var detailed:=JOURNAL.charted(level.story_flags,id,room_id)
        var map_rect: Rect2=room_rect(room)
        var top_left: Vector2=level._map_world_to_overlay(map_rect.position,bounds,draw_size)
        var rect:=Rect2(top_left,level._map_world_to_overlay(map_rect.end,bounds,draw_size)-top_left)
        if rect.size.x<=0 or rect.size.y<=0: continue
        var outline: Control=INK.new()
        outline.name="SurveyRoom_"+room_id
        outline.position=rect.position
        outline.size=rect.size
        outline.draw_ink=false
        outline.detailed=detailed
        # A large room explored only in part shows just its charted sections.
        var parts: Array[Rect2]=[]
        if detailed and not JOURNAL.charted_whole(level.story_flags,id,room): parts=map_parts(level,id,room,bounds,draw_size)
        if not detailed: surface.base_rooms.append(rect)
        elif parts.is_empty(): surface.charted_rooms.append(rect)
        else:
            if public_room(room): surface.base_rooms.append(rect)
            surface.charted_rooms.append_array(parts)
        outline.seed_value=room_id.hash()
        if detailed:
            outline.contours=room_terrain(level,room,terrain)
            for contour in outline.contours:
                var points := PackedVector2Array()
                for point in contour: points.append(rect.position + point * rect.size)
                if parts.is_empty():
                    surface.terrain.append(points)
                    continue
                for part in parts:
                    surface.terrain.append_array(Geometry2D.intersect_polygons(points,rect_polygon(part)))
        outline.set_meta("charted_sections",parts.size())
        outline.mouse_filter=Control.MOUSE_FILTER_PASS
        outline.tooltip_text=level._room_name(room_id)
        outline.set_meta("charted",detailed)
        host.add_child(outline)
    surface.prepare()
    for data in level.config.get("interactives",[])+level.config.get("save_points",[]):
        var point: Vector2=level._vec2(data.get("position",[0,0]))
        var room: Dictionary=level._room_for_position(point)
        if not JOURNAL.charted_at(level.story_flags,id,room,point): continue
        var kind:=String(data.get("kind","save_point"))
        if kind not in ["save_point","world_portal","boss_gate"]: continue
        var marker:=Label.new()
        marker.mouse_filter=Control.MOUSE_FILTER_PASS
        marker.tooltip_text=String(data.get("name",data.get("label","钟龛" if kind=="save_point" else "旧路")))
        marker.name="SurveyPin_"+String(data.get("id","pin"))
        marker.position=map_position(level,room,point,bounds,draw_size)-Vector2(6,9)
        marker.text="◇" if kind=="world_portal" else "◎" if kind=="save_point" else "×"
        marker.add_theme_color_override("font_color",SURFACE.GOLD)
        host.add_child(marker)
    for record in KNOWLEDGE.marker_records(level.config, level.story_flags, id, level.inventory_counts):
        var room: Dictionary = KNOWLEDGE.owner_room(level.config, record.rect)
        var marker := Label.new()
        marker.name = ("SurveyHazard_" if record.kind == "hazard" else "SurveyGate_") + String(record.id)
        marker.mouse_filter = Control.MOUSE_FILTER_PASS
        marker.tooltip_text = String(record.tooltip) # Legend and conditions stay in hover text.
        marker.text = String(record.text)
        marker.position = map_position(level, room, record.rect.get_center(), bounds, draw_size) - Vector2(7, 10)
        marker.add_theme_color_override("font_color", Color("b44e43") if record.kind == "hazard" else SURFACE.GOLD)
        host.add_child(marker)
    for record in KNOWLEDGE.shortcut_records(level.config, level.story_flags, id, level.opened_shortcuts):
        var room: Dictionary = KNOWLEDGE.owner_room(level.config, record.rect)
        var marker := Label.new()
        marker.name = "SurveyShortcut_" + String(record.id)
        marker.mouse_filter = Control.MOUSE_FILTER_PASS
        marker.tooltip_text = String(record.tooltip)
        marker.text = String(record.text)
        marker.position = map_position(level, room, record.rect.get_center(), bounds, draw_size) - Vector2(7, 10)
        marker.add_theme_color_override("font_color", SURFACE.GOLD if record.open else Color("8d6a5a"))
        host.add_child(marker)
    # Position is a navigation aid, not a newly inked room outline.
    var current: Dictionary=level._room_for_position(level.player.global_position)
    var positioned := shows_position(level)
    if positioned and ids.has(String(current.get("id",""))):
        var dot:=Label.new()
        dot.mouse_filter=Control.MOUSE_FILTER_IGNORE
        dot.name="SurveyPlayerMarker"
        dot.position=map_position(level,current,level.player.global_position,bounds,draw_size)-Vector2(6,9)
        dot.text="◆"
        dot.add_theme_color_override("font_color",SURFACE.ACCENT)
        host.add_child(dot)
    level.map_text.text=("◆ 位置" if positioned else "无罗盘·看地标")+"    ◎ 钟龛    ◇ 旧路    ⇆/⊣ 捷径    WASD / 摇杆平移 · PgUp/PgDn / 肩键缩放    %s 世界地图    %s / %s 返回" % [level.ui_shell._short_binding("inventory"),level.ui_shell._short_binding("map"),level.ui_shell._short_binding("close_overlay")]
    level.map_text.tooltip_text="已补绘 %d 室，待补绘 %d 笔。安坐钟龛可补绘途中笔记；大厅与长井按走过的段落补绘；悬停查看房间名称。" % [JOURNAL.charted_room_count(level.story_flags,id),journal.pending.size()]
