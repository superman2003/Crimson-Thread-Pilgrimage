extends Node2D
## In-world bronze signs and proximity pictograms. No route prose is drawn.
const COORD := preload("res://scripts/world_coordinates.gd")
const INK := Color(0.74, 0.77, 0.60)
var host: Node
var area: Area2D
var symbol := "rest"
var direction := Vector2.RIGHT
var physical_sign := false
var nearby := false
var gate_state := "open"
var key_hint := ""
var mount := "post"
var interaction_caption := ""
var _last_state: Array = []
var _prompt_box: StyleBoxFlat
const FONT := preload("res://assets/fonts/GlobalTypeface.otf")

static func caption_for(kind: String, label: String, key: String, recorded: bool=false, service: String="") -> String:
    var clean:=""
    for character in label:
        var code:=character.unicode_at(0)
        if code>=32 and code!=127:clean+=character
    clean=clean.strip_edges().left(24)
    var action: String={"save_point":"安坐","lever":"操作","npc":"交谈","world_portal":"通行","boss_gate":"钟门","death_cache":"找回","challenge_shrine":"查看挑战","hunt_track":"观察踪迹","ending_gate":"查看"}.get(kind,"互动")
    if kind=="history":
        action="重读旧物" if recorded else "观察旧物"
        if not recorded:clean=""
    if kind=="npc" and service in ["map","shop"]:action="查看报价"
    var text:=key+" · "+action
    if not clean.is_empty():text+="："+clean
    return text

static func region_symbol(region: String) -> String:
    for pair in [["ch01", "bell"], ["ch02", "forge"], ["ch03", "book"],
            ["ch04", "leaf"], ["ch05", "crystal"], ["ch06", "crown"]]:
        if region.contains(pair[0]):
            return pair[1]
    return "passage"

func configure_portal(data: Dictionary, region: String) -> void:
    symbol = region_symbol(String(data.get("target_config_id", "")))
    physical_sign = true
    mount = String(data.get("sign_mount", ["stone", "wall", "lantern"][posmod(String(data.get("id", "")).hash(), 3)]))
    var start := COORD.to_world(region, Vector2(data.position[0], data.position[1]))
    var spawn: Array = data.get("target_spawn", [0, 0])
    var end := COORD.to_world(String(data.get("target_config_id", "")), Vector2(spawn[0], spawn[1]))
    if start.is_finite() and end.is_finite():
        var delta := end - start
        direction = Vector2(signf(delta.x), 0) if absf(delta.x) >= absf(delta.y) else Vector2(0, signf(delta.y))
    queue_redraw()

func _process(_delta: float) -> void:
    if not is_instance_valid(host) or not is_instance_valid(area) or host.is_queued_for_deletion() or area.is_queued_for_deletion():
        nearby=false;key_hint="";interaction_caption="";visible=false
        set_process(false)
        return
    # Use the same chosen object/range as interaction, not a larger hint radius.
    nearby = area.is_visible_in_tree() and host.interaction_target(area) == area
    var kind:=String(area.get_meta("kind", ""))
    if kind == "npc":
        symbol = "map" if area.has_meta("map_seller_region") else "shop" if area.has_meta("shop_items") or area.has_meta("shop") else "talk"
    key_hint = host.ui_shell._short_binding("interact") if nearby and is_instance_valid(host.ui_shell) else ""
    var recorded:=false
    if kind=="history" and area.get("seen") is bool:recorded=bool(area.get("seen"))
    interaction_caption=caption_for(kind,String(area.get_meta("label","")),key_hint,recorded,symbol) if nearby and not key_hint.is_empty() else ""
    if nearby:
        host._show_first_interaction_hint(area)
    visible = physical_sign or nearby
    var state: Array=[symbol,nearby,gate_state,key_hint,interaction_caption,mount,physical_sign,scale]
    if state!=_last_state:
        _last_state=state
        queue_redraw()

func _sign_center() -> Vector2:
    if physical_sign:
        return Vector2(0, -136 if mount == "lantern" else -88 if mount == "wall" else -58)
    return Vector2(0, -91)

func _housing(c: Vector2, wide: bool) -> void:
    var w := 51.0 if wide else 25.0
    var h := 21.0 if wide else 25.0
    var dark := Color(0.10, 0.16, 0.15)
    var rim := Color(0.36, 0.44, 0.36)
    if mount == "lantern":
        # Closed chains and hood distinguish this from a doorway/open arch.
        var top := -266.0 if physical_sign else c.y - 49.0
        for x in [-w * 0.55, w * 0.55]:
            draw_line(Vector2(x, top), c + Vector2(x, -h), rim, 2.0, true)
        draw_colored_polygon(PackedVector2Array([c+Vector2(-w-5,-h),c+Vector2(-w+3,-h-9),c+Vector2(w-3,-h-9),c+Vector2(w+5,-h)]), dark)
        draw_rect(Rect2(c-Vector2(w,h),Vector2(w*2,h*2)), Color(0.15,0.23,0.20))
        draw_rect(Rect2(c-Vector2(w,h),Vector2(w*2,h*2)), rim, false, 3)
        draw_line(c+Vector2(-w-4,h+5),c+Vector2(w+4,h+5),rim,3,true)
        draw_line(c+Vector2(0,h+5),c+Vector2(0,h+14),rim,2,true)
        draw_colored_polygon(PackedVector2Array([c+Vector2(0,h+12),c+Vector2(5,h+18),c+Vector2(0,h+24),c+Vector2(-5,h+18)]),rim)
    elif mount == "stone":
        var feet := 36.0 if physical_sign else c.y + h + 5
        var slab := PackedVector2Array([c+Vector2(-w+5,-h),c+Vector2(w-7,-h-3),c+Vector2(w,-h+7),Vector2(c.x+w-3,feet),Vector2(c.x-w-2,feet),c+Vector2(-w,-h+9)])
        draw_colored_polygon(slab,dark)
        var edge := slab.duplicate()
        edge.append(slab[0])
        draw_polyline(edge,rim,2,true)
        draw_line(c+Vector2(w-8,h+1),c+Vector2(w-14,h+10),rim,1,true)
    else:
        if mount == "post":
            draw_line(Vector2(0,36),c+Vector2(0,-h),Color(0.15,0.20,0.16),8,true)
        else:
            draw_polyline(PackedVector2Array([c+Vector2(-w-16,-h-18),c+Vector2(-w-16,0),c+Vector2(-w,0)]),rim,4,true)
        var plank := PackedVector2Array([c+Vector2(-w,-h),c+Vector2(w-8,-h),c+Vector2(w,0),c+Vector2(w-8,h),c+Vector2(-w+3,h),c+Vector2(-w-3,1)])
        draw_colored_polygon(plank,dark)
        var edge := plank.duplicate()
        edge.append(plank[0])
        draw_polyline(edge,rim,2,true)
        draw_circle(c+Vector2(-w+7,0),1.5,INK)

func _draw() -> void:
    var c := _sign_center()
    if physical_sign or nearby:
        _housing(c,physical_sign)
        _icon(symbol,c+Vector2(-12,0) if physical_sign else c,0.78 if physical_sign else 0.9)
    if physical_sign:
        var tail := c+Vector2(21,0)-direction*10
        var tip := c+Vector2(21,0)+direction*10
        draw_line(tail,tip,INK,2.5,true)
        var normal := Vector2(-direction.y,direction.x)
        draw_polyline(PackedVector2Array([tip-direction*6+normal*5,tip,tip-direction*6-normal*5]),INK,2.5,true)
        if gate_state != "open":
            _icon("lock" if gate_state == "far_side" else "ability",c+Vector2(0,39),0.65)
    if nearby and not key_hint.is_empty():
        var font := FONT
        # Small scene signs keep their interaction key at a readable size.
        var text_scale := 1.0 / maxf(0.1, minf(scale.x, scale.y))
        var font_size := ceili(14 * text_scale)
        var width := font.get_string_size(interaction_caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
        var anchor := c+Vector2(-width/2,-44)
        draw_style_box(_key_box(),Rect2(anchor-Vector2(6,16)*text_scale,Vector2(width+12*text_scale,23*text_scale)))
        draw_string(font,anchor,interaction_caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,INK)

func _key_box() -> StyleBoxFlat:
    if _prompt_box!=null:return _prompt_box
    var box := StyleBoxFlat.new()
    box.bg_color = Color(0.05,0.08,0.07,0.9)
    box.border_color = INK
    box.set_border_width_all(1)
    box.set_corner_radius_all(4)
    _prompt_box=box
    return box

func _stroke(points: Array, center: Vector2, scale_value: float) -> void:
    var path := PackedVector2Array()
    for point in points:
        path.append(center + Vector2(point[0],point[1])*scale_value)
    draw_polyline(path, INK, 2.2, true)

func _icon(kind: String, c: Vector2, s: float) -> void:
    match kind:
        "rest": # One flame glyph for every rest/checkpoint, including hidden ones.
            _stroke([[-11,10],[-13,0],[-5,-9],[-3,0],[4,-15],[11,-3],[12,5],[5,11],[-11,10]],c,s)
            _stroke([[-15,15],[15,15]],c,s)
        "bell":
            _stroke([[-13,9],[-9,3],[-8,-8],[-4,-12],[4,-12],[8,-8],[9,3],[13,9],[-13,9]],c,s)
            _stroke([[-3,13],[3,13]],c,s)
        "forge":
            _stroke([[-14,-3],[14,-3],[6,3],[4,9],[10,13],[-10,13],[-4,9],[-6,3],[-14,-3]],c,s)
            _stroke([[0,-7],[4,-14]],c,s)
        "book", "map":
            _stroke([[-14,-11],[-2,-8],[0,-5],[2,-8],[14,-11],[14,10],[2,13],[0,10],[-2,13],[-14,10],[-14,-11]],c,s)
            _stroke([[0,-5],[0,10]],c,s)
            if kind == "map":
                _stroke([[-10,2],[-5,-2],[5,5],[10,0]],c,s)
        "leaf":
            _stroke([[-12,12],[-12,-2],[-5,-11],[13,-13],[11,5],[2,12],[-12,12],[8,-8]],c,s)
        "crystal":
            _stroke([[0,-15],[12,-3],[8,13],[-8,13],[-12,-3],[0,-15],[0,13]],c,s)
        "crown":
            _stroke([[-13,12],[-15,-10],[-6,0],[0,-14],[6,0],[15,-10],[13,12],[-13,12]],c,s)
        "lock":
            _stroke([[-10,0],[-10,13],[10,13],[10,0],[-10,0],[-7,0],[-7,-9],[0,-13],[7,-9],[7,0]],c,s)
        "ability":
            _stroke([[0,-14],[11,0],[0,14],[-11,0],[0,-14]],c,s)
            _stroke([[0,-6],[0,6]],c,s)
        "lever":
            _stroke([[-12,13],[12,13],[5,7],[-5,7],[-12,13]],c,s)
            _stroke([[0,7],[9,-12]],c,s)
        "shop":
            _stroke([[-12,-5],[-10,13],[10,13],[12,-5],[-12,-5],[-6,-5],[-6,-12],[6,-12],[6,-5]],c,s)
        "talk":
            _stroke([[-14,-11],[14,-11],[14,7],[0,7],[-8,14],[-8,7],[-14,7],[-14,-11]],c,s)
        _:
            _stroke([[-10,13],[-10,-10],[10,-10],[10,13]],c,s)
