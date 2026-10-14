extends Node2D

const GEOMETRY := preload("res://scripts/world_collision_geometry.gd")
var prefetch: RefCounted
var region_id := ""

const ROCK := preload("res://scripts/world_rock_material.gd")
var material_theme := "moss_cavern"
const ART := preload("res://scripts/hand_drawn_assets.gd")
var landforms: Array = []
var atlas: Texture2D
var regions: Array = []
var walk_distance := 0.0
var ramp_count := 0
var one_way_spans: Dictionary = {}
var all_one_way: Dictionary = {}
var collision_regions: Array[Dictionary] = []
const CHUNK_SIZE := 1024.0
const LOAD_MARGIN := 320.0
const KEEP_MARGIN := 900.0
const STREAM_BUDGET_US := 2000
var streaming := false
var visual_chunks: Dictionary = {}
var resident_chunks: Dictionary = {}
var streamed_loads := 0
var streamed_releases := 0
var view_bounds := Rect2()
# Collision geometry is immutable; only its tree-owned polygon nodes retire.
var collision_streaming := false
var collision_records: Array[Dictionary] = []
var resident_collisions: Dictionary = {}
var collision_pins: Dictionary = {}
var collision_holds: Dictionary = {}
var support_rects: Dictionary = {}
var critical_bounds := Rect2()
var collision_sync_until := 0
var collision_loads := 0
var collision_releases := 0
var collision_closed := false
const COLLISION_HALF := Vector2(960, 768)
const COLLISION_PRELOAD := 640.0
const COLLISION_KEEP := 1280.0

func configure(config: Dictionary, theme: String, enable_streaming: bool = false, initial_focus: Vector2 = Vector2.ZERO, enable_collision_streaming: bool = false) -> void:
    prepare_config(config, theme, enable_streaming, enable_collision_streaming)
    for value in landforms:
        _build_landform(value)
    if streaming:
        warm_focus(initial_focus)


## Metadata first; the host may then admit one landform at a time.
func prepare_config(config: Dictionary, theme: String, enable_streaming: bool = false, enable_collision_streaming: bool = false) -> void:
    name = "ChapterTerrain"
    material_theme = theme
    streaming = enable_streaming
    collision_streaming = enable_collision_streaming
    landforms = config.get("terrain", [])
    var directory := "res://assets/sprites/flat_maps/" + theme + "/"
    var data := ART.manifest(directory + "manifest.json")
    atlas = ART.texture(directory + "terrain_atlas.png")
    regions = data.get("terrain_regions", [])
    for platform in config.get("platforms", []):
        var terrain_id := String(platform.get("terrain_id", ""))
        if terrain_id.is_empty():
            continue
        var support: Array = platform.get("rect", [])
        if support.size() == 4:
            support_rects[String(platform.get("id", ""))] = Rect2(support[0], support[1], support[2], support[3])
        var one_way := String(platform.get("collision_role", "")) == "one_way"
        all_one_way[terrain_id] = bool(all_one_way.get(terrain_id, true)) and one_way
        if one_way:
            var rect: Array = platform.get("rect", [])
            if rect.size() == 4:
                if not one_way_spans.has(terrain_id):
                    one_way_spans[terrain_id] = []
                one_way_spans[terrain_id].append([float(rect[0]), float(rect[0]) + float(rect[2])])

func warm_focus(focus: Vector2) -> void:
    warm_collision_focus(focus)
    refresh_visual_chunks(Rect2(focus - Vector2(1280, 900), Vector2(2560, 1800)), true)

func _build_landform(data: Dictionary) -> void:
    var surface: Array = data.get("surface", [])
    if surface.size() < 2:
        return
    var depth := float(data.get("depth", 104))
    var body := StaticBody2D.new()
    body.name = String(data.get("id", "Ground"))
    body.set_meta("landform_kind", String(data.get("kind", "ground")))
    body.set_meta("terrain_surface", surface)
    if collision_streaming:
        body.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
    add_child(body)
    var spans: Array = one_way_spans.get(String(body.name), [])
    if bool(all_one_way.get(String(body.name), false)):
        spans = [[float(surface[0][0]), float(surface[-1][0])]]
    _build_collision_sections(body, surface, depth, spans)
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
            if streaming:
                _register_visual_face(body,left,right,depth)
            else:
                _textured_face(body,left,right,depth)
    if streaming:
        return
    var edge := Line2D.new()
    edge.name = "WalkableContour"
    edge.width = 1.4
    edge.default_color = Color(0.79,0.75,0.58,0.47)
    for point in surface:
        edge.add_point(Vector2(float(point[0]),float(point[1])))
    edge.z_index = -1
    body.add_child(edge)

func _register_visual_face(body: StaticBody2D, left: Vector2, right: Vector2, depth: float) -> void:
    var points := PackedVector2Array([left, right, right + Vector2(0, depth), left + Vector2(0, depth)])
    var center := (left + right) * 0.5
    var key := "%s:%d:%d" % [body.name, floori(center.x / CHUNK_SIZE), floori(center.y / CHUNK_SIZE)]
    var bounds := Rect2(points[0], Vector2.ZERO)
    for point in points:
        bounds = bounds.expand(point)
    if not visual_chunks.has(key):
        visual_chunks[key] = {"parent": body, "bounds": bounds, "faces": []}
    visual_chunks[key].bounds = visual_chunks[key].bounds.merge(bounds)
    visual_chunks[key].faces.append(points)

func _process(_delta: float) -> void:
    if not streaming:
        return
    var inverse := get_global_transform_with_canvas().affine_inverse()
    var screen := get_viewport_rect()
    var first := inverse * screen.position
    var bounds := Rect2(first, Vector2.ZERO)
    for point in [Vector2(screen.end.x, screen.position.y), screen.end, Vector2(screen.position.x, screen.end.y)]:
        bounds = bounds.expand(inverse * point)
    refresh_visual_chunks(bounds)

func refresh_visual_chunks(bounds: Rect2, eager: bool = false) -> void:
    if not streaming or not bounds.has_area():
        return
    view_bounds = bounds
    var load_bounds := bounds.grow(LOAD_MARGIN)
    var keep_bounds := bounds.grow(KEEP_MARGIN)
    for key in resident_chunks.keys():
        if not keep_bounds.intersects(visual_chunks[key].bounds):
            var node: Node = resident_chunks[key]
            node.get_parent().remove_child(node)
            node.free()
            resident_chunks.erase(key)
            streamed_releases += 1
    var pending: Array = []
    for key in visual_chunks:
        if not resident_chunks.has(key) and load_bounds.intersects(visual_chunks[key].bounds):
            pending.append(key)
    pending.sort_custom(func(a, b): return visual_chunks[a].bounds.get_center().distance_squared_to(bounds.get_center()) < visual_chunks[b].bounds.get_center().distance_squared_to(bounds.get_center()))
    var started := Time.get_ticks_usec()
    var created := 0
    for key in pending:
        if not eager and (created >= 2 or Time.get_ticks_usec() - started >= STREAM_BUDGET_US):
            break
        var record: Dictionary = visual_chunks[key]
        var chunk := Node2D.new()
        chunk.name = "TerrainVisualChunk"
        chunk.set_meta("stream_chunk_id", key)
        record.parent.add_child(chunk)
        for points in record.faces:
            var face := ROCK.stratum(chunk,points[0],points[1],points[3].y-points[0].y,material_theme)
            face.name = "HandPaintedStratum"
            face.z_index = -5
        # Reassemble consecutive top edges without drawing joins across gaps.
        var edge: Line2D = null
        for points in record.faces:
            if edge == null or not edge.get_point_position(edge.get_point_count() - 1).is_equal_approx(points[0]):
                edge = Line2D.new()
                edge.name = "WalkableContour"
                edge.width = 1.4
                edge.default_color = Color(0.79,0.75,0.58,0.47)
                edge.z_index = -1
                chunk.add_child(edge)
                edge.add_point(points[0])
            edge.add_point(points[1])
        resident_chunks[key] = chunk
        streamed_loads += 1
        created += 1

func streaming_snapshot() -> Dictionary:
    var total_faces := 0
    var resident_faces := 0
    for key in visual_chunks:
        total_faces += visual_chunks[key].faces.size()
        if resident_chunks.has(key):
            resident_faces += visual_chunks[key].faces.size()
    return {"enabled": streaming, "chunks": visual_chunks.size(), "resident": resident_chunks.size(),
        "faces": total_faces, "resident_faces": resident_faces,
        "loaded": streamed_loads, "released": streamed_releases,
        "collision_regions": collision_regions.size()}

func _build_collision_sections(body: StaticBody2D, surface: Array, depth: float, spans: Array) -> void:
    var sections := GEOMETRY.terrain_sections(surface, depth, spans)
    for section_index in range(sections.size()):
        var data: Dictionary = sections[section_index]
        collision_regions.append({"bounds": data.bounds, "polygon": data.polygon})
        var index := collision_records.size()
        collision_records.append({"bounds": data.bounds, "polygon": data.polygon,
            "parent": body, "one_way": data.one_way, "cache_key": "%s:%d" % [body.name, section_index]})
        if not collision_streaming:
            _create_collision(index)

func _create_collision(index: int) -> void:
    if collision_closed or resident_collisions.has(index):
        return
    var record: Dictionary = collision_records[index]
    var data := {"bounds": record.bounds, "polygon": record.polygon, "one_way": record.one_way}
    var node: CollisionPolygon2D = prefetch.take_collision(region_id, "terrain", record.cache_key, data) if prefetch != null else null
    if node == null:
        node = GEOMETRY.terrain_polygon(data)
    record.parent.add_child(node)
    resident_collisions[index] = node
    collision_loads += 1

func hold_collision_support(platform_id: String) -> void:
    if not collision_streaming or collision_closed or not support_rects.has(platform_id):
        return
    var bounds: Rect2 = support_rects[platform_id].grow(8)
    for index in range(collision_records.size()):
        if bounds.intersects(collision_records[index].bounds):
            collision_holds[index] = true
            _create_collision(index)

func warm_collision_focus(focus: Vector2) -> void:
    update_collision_window(focus, Vector2.ZERO, 0, true)

func update_collision_window(focus: Vector2, velocity: Vector2, delta: float, eager: bool = false) -> void:
    if not collision_streaming or collision_closed or not focus.is_finite() or not velocity.is_finite():
        return
    var point := to_local(focus)
    var sweep := velocity * clampf(delta, 0, 0.25)
    critical_bounds = Rect2(point - COLLISION_HALF, COLLISION_HALF * 2).expand(point + sweep - COLLISION_HALF).expand(point + sweep + COLLISION_HALF)
    var frame := Engine.get_physics_frames()
    for index in collision_pins.keys():
        if int(collision_pins[index]) < frame:
            collision_pins.erase(index)
    for index in range(collision_records.size()):
        if critical_bounds.intersects(collision_records[index].bounds) and not resident_collisions.has(index):
            _create_collision(index)
            collision_sync_until = frame + 1
    var keep := critical_bounds.grow(COLLISION_KEEP)
    var started := Time.get_ticks_usec()
    var count := 0
    for index in resident_collisions.keys():
        if not collision_holds.has(index) and not collision_pins.has(index) and not keep.intersects(collision_records[index].bounds):
            if not eager and (count >= 2 or (count > 0 and Time.get_ticks_usec() - started >= STREAM_BUDGET_US)):
                break
            var node: Node = resident_collisions[index]
            node.get_parent().remove_child(node)
            node.free()
            resident_collisions.erase(index)
            collision_releases += 1
            count += 1
    var pending: Array[int] = []
    for index in range(collision_records.size()):
        if not resident_collisions.has(index) and critical_bounds.grow(COLLISION_PRELOAD).intersects(collision_records[index].bounds):
            pending.append(index)
    pending.sort_custom(func(a, b): return collision_records[a].bounds.get_center().distance_squared_to(point) < collision_records[b].bounds.get_center().distance_squared_to(point))
    started = Time.get_ticks_usec()
    count = 0
    for index in pending:
        if not eager and (count >= 2 or (count > 0 and Time.get_ticks_usec() - started >= STREAM_BUDGET_US)):
            break
        _create_collision(index)
        count += 1

func ensure_collision_segment(from: Vector2, to: Vector2) -> void:
    if not collision_streaming or collision_closed or not from.is_finite() or not to.is_finite():
        return
    var bounds := Rect2(to_local(from), Vector2.ZERO).expand(to_local(to)).grow(16)
    for index in range(collision_records.size()):
        if bounds.intersects(collision_records[index].bounds):
            _create_collision(index)
            collision_pins[index] = Engine.get_physics_frames() + 2

func terrain_ray_hit(from: Vector2, to: Vector2) -> Dictionary:
    if not collision_streaming or collision_closed or not from.is_finite() or not to.is_finite():
        return {}
    var start := to_local(from)
    var finish := to_local(to)
    var nearest := INF
    var hit := Vector2.ZERO
    for record in collision_regions:
        var polygon: PackedVector2Array = record.polygon
        # Physics ray queries exclude inside starts by default. Only edges count.
        if Geometry2D.is_point_in_polygon(start, polygon):
            continue
        for i in range(polygon.size()):
            var contact: Variant = Geometry2D.segment_intersects_segment(start, finish, polygon[i], polygon[(i + 1) % polygon.size()])
            if contact != null and start.distance_squared_to(contact) < nearest:
                nearest = start.distance_squared_to(contact)
                hit = contact
    return {} if not is_finite(nearest) else {"position": to_global(hit), "authored_static": true}

func critical_collision_ready() -> bool:
    return not collision_streaming or Engine.get_physics_frames() >= collision_sync_until

func collision_snapshot() -> Dictionary:
    return {"enabled": collision_streaming, "authored": collision_records.size(), "resident": resident_collisions.size(), "held": collision_holds.size(), "pins": collision_pins.size(), "loads": collision_loads, "releases": collision_releases}

func close_collisions() -> void:
    collision_closed = true
    prefetch = null
    resident_collisions.clear()
    collision_pins.clear()
    collision_holds.clear()
    collision_records.clear()
    support_rects.clear()

func _exit_tree() -> void:
    close_collisions()

func intersects_rect(rect: Rect2) -> bool:
    var corners := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
    for region in collision_regions:
        if rect.intersects(region["bounds"]) and not Geometry2D.intersect_polygons(corners, region["polygon"]).is_empty():
            return true
    return false

func _textured_face(parent: Node, left: Vector2, right: Vector2, depth: float) -> void:
    var panel := ROCK.stratum(parent,left,right,depth,material_theme)
    panel.name = "HandPaintedStratum"
    panel.z_index = -5


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
