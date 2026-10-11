extends Node2D

const ART := preload("res://scripts/hand_drawn_assets.gd")
var landforms: Array = []
var atlas: Texture2D
var regions: Array = []
var walk_distance := 0.0
var ramp_count := 0
var one_way_spans: Dictionary = {}
var all_one_way: Dictionary = {}
var collision_regions: Array[Dictionary] = []

func configure(config: Dictionary, theme: String) -> void:
    name = "ChapterTerrain"
    landforms = config.get("terrain", [])
    var directory := "res://assets/sprites/flat_maps/" + theme + "/"
    var data := ART.manifest(directory + "manifest.json")
    atlas = ART.texture(directory + "terrain_atlas.png")
    regions = data.get("terrain_regions", [])
    for platform in config.get("platforms", []):
        var terrain_id := String(platform.get("terrain_id", ""))
        if terrain_id.is_empty():
            continue
        var one_way := String(platform.get("collision_role", "")) == "one_way"
        all_one_way[terrain_id] = bool(all_one_way.get(terrain_id, true)) and one_way
        if one_way:
            var rect: Array = platform.get("rect", [])
            if rect.size() == 4:
                if not one_way_spans.has(terrain_id):
                    one_way_spans[terrain_id] = []
                one_way_spans[terrain_id].append([float(rect[0]), float(rect[0]) + float(rect[2])])
    for value in landforms:
        _build_landform(value)

func _build_landform(data: Dictionary) -> void:
    var surface: Array = data.get("surface", [])
    if surface.size() < 2:
        return
    var depth := float(data.get("depth", 104))
    var body := StaticBody2D.new()
    body.name = String(data.get("id", "Ground"))
    body.set_meta("landform_kind", String(data.get("kind", "ground")))
    body.set_meta("terrain_surface", surface)
    add_child(body)
    var spans: Array = one_way_spans.get(String(body.name), [])
    if bool(all_one_way.get(String(body.name), false)):
        spans = [[float(surface[0][0]), float(surface[-1][0])]]
    _build_collision_sections(body, surface, depth, spans)
    var variants: Array = data.get("texture_variants", [0,1,2])
    for i in range(surface.size()-1):
        var a := Vector2(float(surface[i][0]),float(surface[i][1]))
        var b := Vector2(float(surface[i+1][0]),float(surface[i+1][1]))
        if b.x <= a.x:
            continue
        walk_distance += b.x-a.x
        if absf(b.y-a.y)>1:
            ramp_count += 1
        var count := maxi(1,ceili((b.x-a.x)/270.0))
        for piece in range(count):
            var left := a.lerp(b,float(piece)/count)
            var right := a.lerp(b,float(piece+1)/count)
            _textured_face(body,left,right,depth,int(variants[(i+piece+body.name.hash())%variants.size()]))
    var edge := Line2D.new()
    edge.name = "WalkableContour"
    edge.width = 1.4
    edge.default_color = Color(0.79,0.75,0.58,0.47)
    for point in surface:
        edge.add_point(Vector2(float(point[0]),float(point[1])))
    edge.z_index = -1
    body.add_child(edge)

func _build_collision_sections(body: StaticBody2D, surface: Array, depth: float, spans: Array) -> void:
    var section := PackedVector2Array()
    var section_one_way := false
    for i in range(surface.size() - 1):
        var a := Vector2(float(surface[i][0]), float(surface[i][1]))
        var b := Vector2(float(surface[i + 1][0]), float(surface[i + 1][1]))
        if b.x <= a.x:
            continue
        var breaks: Array[float] = [a.x, b.x]
        for span in spans:
            for x in span:
                if float(x) > a.x and float(x) < b.x:
                    breaks.append(float(x))
        breaks.sort()
        for j in range(breaks.size() - 1):
            if is_equal_approx(breaks[j], breaks[j + 1]):
                continue
            var left := a.lerp(b, (breaks[j] - a.x) / (b.x - a.x))
            var right := a.lerp(b, (breaks[j + 1] - a.x) / (b.x - a.x))
            var midpoint := (left.x + right.x) * 0.5
            var one_way := false
            for span in spans:
                if midpoint >= float(span[0]) and midpoint <= float(span[1]):
                    one_way = true
                    break
            if not section.is_empty() and section_one_way != one_way:
                _add_collision_region(body, section, depth, section_one_way)
                section = PackedVector2Array()
            if section.is_empty():
                section.append(left)
                section_one_way = one_way
            section.append(right)
    if section.size() >= 2:
        _add_collision_region(body, section, depth, section_one_way)

func _add_collision_region(body: StaticBody2D, surface: PackedVector2Array, depth: float, one_way: bool) -> void:
    var polygon := surface.duplicate()
    for i in range(surface.size() - 1, -1, -1):
        polygon.append(surface[i] + Vector2(0, depth))
    var collision := CollisionPolygon2D.new()
    collision.polygon = polygon
    collision.one_way_collision = one_way
    collision.one_way_collision_margin = 2.0
    body.add_child(collision)
    var bounds := Rect2(polygon[0], Vector2.ZERO)
    for point in polygon:
        bounds = bounds.expand(point)
    collision_regions.append({"bounds": bounds, "polygon": polygon})

func intersects_rect(rect: Rect2) -> bool:
    var corners := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
    for region in collision_regions:
        if rect.intersects(region["bounds"]) and not Geometry2D.intersect_polygons(corners, region["polygon"]).is_empty():
            return true
    return false

func _textured_face(parent: Node, left: Vector2, right: Vector2, depth: float, variant: int) -> void:
    var panel := Polygon2D.new()
    panel.name = "HandPaintedStratum"
    panel.polygon = PackedVector2Array([left,right,right+Vector2(0,depth),left+Vector2(0,depth)])
    panel.z_index = -5
    if atlas != null and not regions.is_empty():
        var region := ART.rect(regions[posmod(variant,regions.size())])
        var x1 := region.position.x + region.size.x*0.11
        var x2 := region.end.x - region.size.x*0.11
        var top := region.position.y + region.size.y*0.10
        var bottom := region.position.y + region.size.y*0.83
        panel.texture = atlas
        panel.uv = PackedVector2Array([Vector2(x1,top),Vector2(x2,top),Vector2(x2,bottom),Vector2(x1,bottom)])
        panel.set_meta("original_map_asset", "terrain_atlas.png")
    else:
        panel.color = Color(0.17,0.20,0.18)
    parent.add_child(panel)

func floor_height(x: float, reference_y: float, tolerance: float = 180.0) -> float:
    var nearest := INF
    var distance := tolerance
    for data in landforms:
        var surface: Array = data.get("surface", [])
        for i in range(surface.size()-1):
            var a: Array = surface[i]
            var b: Array = surface[i+1]
            if x<float(a[0]) or x>float(b[0]) or float(b[0])<=float(a[0]):
                continue
            var y := lerpf(float(a[1]),float(b[1]),(x-float(a[0]))/(float(b[0])-float(a[0])))
            if absf(y-reference_y)<distance:
                distance=absf(y-reference_y)
                nearest=y
    return nearest
