extends RefCounted
## Shared immutable collision descriptors and detached factories. No scene,
## gameplay, texture or audio ownership; callers attach only validated geometry.
const ROCK_CHUNK_SIZE := 1024.0

static func rock_chunks(values: Array) -> Dictionary:
    var chunks: Dictionary = {}
    for index in range(values.size()):
        var value: Array = values[index]
        var rect := Rect2(value[0], value[1], value[2], value[3])
        var center := rect.get_center()
        var key := "%d:%d" % [floori(center.x / ROCK_CHUNK_SIZE), floori(center.y / ROCK_CHUNK_SIZE)]
        if not chunks.has(key):
            chunks[key] = {"bounds": rect, "indices": [], "rects": []}
        chunks[key].bounds = chunks[key].bounds.merge(rect)
        chunks[key].indices.append(index)
        chunks[key].rects.append(rect)
    return chunks

static func rock_body(key: String, data: Dictionary) -> StaticBody2D:
    var body := StaticBody2D.new()
    body.name = "RockChunk_" + key.replace(":", "_")
    body.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
    body.collision_layer = 17
    body.collision_mask = 0
    for offset in range(data.indices.size()):
        var index: int = data.indices[offset]
        var rect: Rect2 = data.rects[offset]
        var collision := CollisionShape2D.new()
        collision.name = "Rock_%d" % index
        collision.set_meta("authored_rock_index", index)
        var shape := RectangleShape2D.new()
        shape.size = rect.size
        collision.position = rect.get_center()
        collision.shape = shape
        body.add_child(collision)
    return body

static func terrain_spans(config: Dictionary, id: String, surface: Array) -> Array:
    var spans: Array = []
    var found := false
    var all_one_way := true
    for platform in config.get("platforms", []):
        if String(platform.get("terrain_id", "")) != id:
            continue
        found = true
        var one_way := String(platform.get("collision_role", "")) == "one_way"
        all_one_way = all_one_way and one_way
        if one_way:
            var rect: Array = platform.rect
            spans.append([float(rect[0]), float(rect[0]) + float(rect[2])])
    if found and all_one_way and surface.size() >= 2:
        return [[float(surface[0][0]), float(surface[-1][0])]]
    return spans

static func terrain_sections(surface: Array, depth: float, spans: Array) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var section := PackedVector2Array()
    var section_one_way := false
    for i in range(surface.size() - 1):
        var a := Vector2(surface[i][0], surface[i][1])
        var b := Vector2(surface[i + 1][0], surface[i + 1][1])
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
                result.append(_section(section, depth, section_one_way))
                section = PackedVector2Array()
            if section.is_empty():
                section.append(left)
                section_one_way = one_way
            section.append(right)
    if section.size() >= 2:
        result.append(_section(section, depth, section_one_way))
    return result

static func _section(surface: PackedVector2Array, depth: float, one_way: bool) -> Dictionary:
    var polygon := surface.duplicate()
    for index in range(surface.size() - 1, -1, -1):
        polygon.append(surface[index] + Vector2(0, depth))
    var bounds := Rect2(polygon[0], Vector2.ZERO)
    for point in polygon:
        bounds = bounds.expand(point)
    return {"bounds": bounds, "polygon": polygon, "one_way": one_way}

static func terrain_polygon(data: Dictionary) -> CollisionPolygon2D:
    var node := CollisionPolygon2D.new()
    node.polygon = data.polygon
    node.one_way_collision = data.one_way
    node.one_way_collision_margin = 2.0
    return node
