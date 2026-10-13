extends RefCounted
const JOURNAL := preload("res://scripts/pilgrimage_cartography.gd")
const INK := preload("res://scripts/hand_drawn_map_room.gd")
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
    dialog.dialog_text=String(seller.get("note",""))+"\n\n本区地图：%d枚松脂碎钱" % JOURNAL.PRICE
    dialog.ok_button_text="购买底图"
    dialog.cancel_button_text="暂不购买"
    level.add_child(dialog)
    var talk := dialog.add_button("交谈",true,"talk")
    talk.name="MapSellerTalk"
    dialog.custom_action.connect(func(action: String):
        if action=="talk":
            level._close_overlays()
            level._talk_to_npc(area))
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
    dialog.dialog_text=String(area.get_meta("map_seller_data",{}).get("note",""))+"\n\n"+("已获得此区域地图。安坐钟龛补绘途中笔记。" if is_owned else "本区地图：%d枚松脂碎钱 · 当前%d枚" % [JOURNAL.PRICE,level.currency_count])
    dialog.get_ok_button().disabled=is_owned or level.currency_count<JOURNAL.PRICE
    dialog.popup_centered(Vector2i(530,250))
    (dialog.get_ok_button() if not dialog.get_ok_button().disabled else dialog.get_cancel_button()).grab_focus()
static func purchase(level: Node, area: Area2D) -> Dictionary:
    if not level.world_mode or not is_instance_valid(area) or String(area.get_meta("map_seller_region",""))!=String(level.config.id) or level.player.global_position.distance_to(area.global_position)>150 or level.player.hp<=0 or level.player.death_timer>0 or level.chapter_transitioning:
        return {"ok":false,"reason":"请靠近本区地图NPC购买。"}
    var result := JOURNAL.purchase(level.story_flags,String(level.config.id),level.currency_count)
    if result.ok:
        level.currency_count=int(result.wallet)
        area.set_meta("interaction_label",String(area.get_meta("label","地图NPC"))+" · 交谈 / 已购地图")
        level._save_world()
        level._refresh_hud()
    level._toast(String(result.reason))
    return result
static func public_room(room: Dictionary) -> bool:
    return String(room.get("kind","")) not in ["secret","reward","treasure","exit"] and not bool(room.get("hidden",false)) and not String(room.get("id","")).begins_with("upgrade_")
static func region_bounds(level: Node) -> Rect2:
    # Visibility never changes the coordinate frame. Reserve space for every
    # authored room without emitting its outline, label or connections.
    return level._map_layout_bounds(level.config.get("map_rooms",[]))
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
static func rect_polygon(rect: Rect2) -> PackedVector2Array:
    return PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
static func map_position(level: Node, room: Dictionary, point: Vector2, bounds: Rect2, draw_size: Vector2) -> Vector2:
    var physical: Rect2=level._room_layout_rect(room)
    var map_rect: Rect2=level._room_map_rect(room)
    if physical.size.x<=0 or physical.size.y<=0:
        return level._map_world_to_overlay(point,bounds,draw_size)
    return level._map_world_to_overlay(map_rect.position+map_rect.size*(point-physical.position)/physical.size,bounds,draw_size)
static func room_terrain(level: Node, room: Dictionary, polygons: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
    var physical: Rect2=level._room_layout_rect(room)
    var contours: Array[PackedVector2Array]=[]
    if physical.size.x<=0 or physical.size.y<=0: return contours
    for polygon in polygons:
        var fragments: Array[PackedVector2Array]=Geometry2D.intersect_polygons(polygon,rect_polygon(physical))
        # Nested pockets belong to their own exploration record. Charting the
        # enclosing hall must not disclose their terrain before resting.
        for other in level.config.get("map_rooms",[]):
            if String(other.id)==String(room.id): continue
            var pocket: Rect2=level._room_layout_rect(other)
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
    level.map_text.add_theme_color_override("font_color",Color("60452b") if enabled else Color("dae6d5"))
    for child in level.map_panel.get_children():
        if child is Label:
            child.add_theme_color_override("font_color",Color("60452b") if enabled else Color("b5a17c"))
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
        notice.add_theme_color_override("font_color",Color("60452b"))
        notice.add_theme_font_size_override("font_size",21)
        host.add_child(notice)
        level.map_text.text="M / Esc 返回 · Tab 世界总览"
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
    var label_bounds: Array[Rect2]=[]
    for connection in level.config.get("connections",[]):
        var a:=String(connection.get("from",""))
        var b:=String(connection.get("to",""))
        if not ids.has(a) or not ids.has(b): continue
        var detailed:=JOURNAL.charted(level.story_flags,id,a) and JOURNAL.charted(level.story_flags,id,b)
        var line:=Line2D.new()
        line.name="SurveyEdge_"+a+"_"+b
        line.width=2.0 if detailed else 1.0
        line.default_color=Color("60452b") if detailed else Color(0.38,0.27,0.17,0.20)
        line.set_meta("charted",detailed)
        for room_id in [a,b]:
            var rect: Rect2=level._room_map_rect(level._map_room_by_id(room_id))
            line.add_point(level._map_world_to_overlay(rect.get_center(),bounds,draw_size))
        host.add_child(line)
    for room in rooms:
        var room_id:=String(room.id)
        var detailed:=JOURNAL.charted(level.story_flags,id,room_id)
        var map_rect: Rect2=level._room_map_rect(room)
        var top_left: Vector2=level._map_world_to_overlay(map_rect.position,bounds,draw_size)
        var rect:=Rect2(top_left,level._map_world_to_overlay(map_rect.end,bounds,draw_size)-top_left)
        if rect.size.x<=0 or rect.size.y<=0: continue
        var outline: Control=INK.new()
        outline.name="SurveyRoom_"+room_id
        outline.position=rect.position
        outline.size=rect.size
        outline.detailed=detailed
        outline.seed_value=room_id.hash()
        if detailed: outline.contours=room_terrain(level,room,terrain)
        outline.mouse_filter=Control.MOUSE_FILTER_PASS if detailed else Control.MOUSE_FILTER_IGNORE
        if detailed: outline.tooltip_text=level._room_name(room_id)
        outline.set_meta("charted",detailed)
        host.add_child(outline)
        var title_text: String=level._room_name(room_id)
        var title_size:=host.get_theme_font("font").get_string_size(title_text,HORIZONTAL_ALIGNMENT_LEFT,-1,12)
        var title_rect:=Rect2(rect.position+Vector2(0,-16),Vector2(title_size.x,16))
        var show_title: bool=(detailed and rect.size.x>=title_size.x+8) or String(room.get("kind","")) in ["hub","vista","entry"]
        for occupied in label_bounds:
            if occupied.grow(3).intersects(title_rect): show_title=false
        if show_title:
            label_bounds.append(title_rect)
            var title:=Label.new()
            title.name="SurveyLabel_"+room_id
            title.text=title_text
            title.position=title_rect.position
            title.mouse_filter=Control.MOUSE_FILTER_IGNORE
            title.add_theme_font_size_override("font_size",12)
            title.add_theme_color_override("font_color",Color("60452b"))
            host.add_child(title)
    for data in level.config.get("interactives",[])+level.config.get("save_points",[]):
        var point: Vector2=level._vec2(data.get("position",[0,0]))
        var room: Dictionary=level._room_for_position(point)
        if not JOURNAL.charted(level.story_flags,id,String(room.get("id",""))): continue
        var kind:=String(data.get("kind","save_point"))
        if kind not in ["save_point","world_portal","boss_gate"]: continue
        var marker:=Label.new()
        marker.name="SurveyPin_"+String(data.get("id","pin"))
        marker.position=map_position(level,room,point,bounds,draw_size)-Vector2(6,9)
        marker.text="◇" if kind=="world_portal" else "◎" if kind=="save_point" else "×"
        marker.add_theme_color_override("font_color",Color("7b4232"))
        host.add_child(marker)
    # Position is a navigation aid, not a newly inked room outline.
    var current: Dictionary=level._room_for_position(level.player.global_position)
    if ids.has(String(current.get("id",""))):
        var dot:=Label.new()
        dot.name="SurveyPlayerMarker"
        dot.position=map_position(level,current,level.player.global_position,bounds,draw_size)-Vector2(6,9)
        dot.text="◆"
        dot.add_theme_color_override("font_color",Color("a14c3a"))
        host.add_child(dot)
    level.map_text.text="手绘旅册 · 已补绘 %d室 · 待补绘 %d笔\n浅墨：底图轮廓 · 深墨：真实地形 · ◆你的位置 · ◎钟龛 · ◇旧路\n途中笔记不会立即展开详细地图；安坐任意钟龛，补绘已购地区。\nM / Esc 返回 · Tab 世界总览" % [journal.charted.size(),journal.pending.size()]
