extends Node2D

const ART := preload("res://scripts/hand_drawn_assets.gd")
var landforms: Array = []
var atlas: Texture2D
var regions: Array = []
var walk_distance := 0.0
var ramp_count := 0

func configure(config: Dictionary, theme: String) -> void:
    name = "ChapterTerrain"
    landforms = config.get("terrain", [])
    var directory := "res://assets/sprites/flat_maps/" + theme + "/"
    var data := ART.manifest(directory + "manifest.json")
    atlas = ART.texture(directory + "terrain_atlas.png")
    regions = data.get("terrain_regions", [])
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
    var points := PackedVector2Array()
    for point in surface:
        points.append(Vector2(float(point[0]), float(point[1])))
    for i in range(surface.size()-1, -1, -1):
        points.append(Vector2(float(surface[i][0]), float(surface[i][1])+depth))
    var collision := CollisionPolygon2D.new()
    collision.polygon = points
    body.add_child(collision)
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
