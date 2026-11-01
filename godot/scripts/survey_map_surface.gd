extends Control
## A quiet room silhouette. Room metadata retains the full survey geometry;
## the overview deliberately omits subpixel platforms and collision edges.
const PAPER := Color("172321")
const INK := Color("dfcfb0")
const MUTED := Color("8b9c90")
const ACCENT := Color("e7ad7f")
const GOLD := Color("bda176")
var base_rooms: Array[Rect2] = []
var charted_rooms: Array[Rect2] = []
var terrain: Array[PackedVector2Array] = []
var base_edges: Array[PackedVector2Array] = []
var charted_edges: Array[PackedVector2Array] = []

func prepare() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    base_edges = boundaries(base_rooms)
    charted_edges = boundaries(charted_rooms)
    queue_redraw()

static func boundaries(rooms: Array[Rect2]) -> Array[PackedVector2Array]:
    # Subtract covered spans from each rectangle side. This preserves holes
    # and disconnected pockets without outlining internal overlapping walls.
    var spans: Dictionary = {}
    for rect in rooms:
        for side in 4:
            var horizontal := side < 2
            var coordinate := (rect.position.y if side == 0 else rect.end.y) if horizontal else (rect.position.x if side == 2 else rect.end.x)
            var start := rect.position.x if horizontal else rect.position.y
            var finish := rect.end.x if horizontal else rect.end.y
            var outside := coordinate + (-0.001 if side in [0, 2] else 0.001)
            var remaining: Array[Vector2] = [Vector2(start, finish)]
            for other in rooms:
                var low := other.position.y if horizontal else other.position.x
                var high := other.end.y if horizontal else other.end.x
                if outside < low or outside > high: continue
                var cut_start := other.position.x if horizontal else other.position.y
                var cut_end := other.end.x if horizontal else other.end.y
                var next: Array[Vector2] = []
                for interval in remaining:
                    if cut_end <= interval.x or cut_start >= interval.y:
                        next.append(interval)
                    else:
                        if cut_start > interval.x: next.append(Vector2(interval.x, cut_start))
                        if cut_end < interval.y: next.append(Vector2(cut_end, interval.y))
                remaining = next
            var key := Vector2(1 if horizontal else 0, coordinate)
            if not spans.has(key): spans[key] = []
            spans[key].append_array(remaining)
    var result: Array[PackedVector2Array] = []
    for key: Vector2 in spans:
        var intervals: Array = spans[key]
        intervals.sort_custom(func(a: Vector2, b: Vector2): return a.x < b.x)
        var merged: Array[Vector2] = []
        for interval: Vector2 in intervals:
            if not merged.is_empty() and interval.x <= merged[-1].y + 0.001:
                merged[-1].y = maxf(merged[-1].y, interval.y)
            else:
                merged.append(interval)
        for interval in merged:
            var a := Vector2(interval.x, key.y) if key.x == 1 else Vector2(key.y, interval.x)
            var b := Vector2(interval.y, key.y) if key.x == 1 else Vector2(key.y, interval.y)
            result.append(PackedVector2Array([a, b]))
    return result

func _draw() -> void:
    for rect in base_rooms: draw_rect(rect, Color("18292a"))
    for polygon in base_edges: edge(polygon, Color("52635a"), 1.0)
    for rect in charted_rooms: draw_rect(rect, Color("263a36"))
    for polygon in charted_edges: edge(polygon, INK, 1.0)
    # No perimeter strokes on terrain: they previously turned every platform
    # into a tiny ladder and doubled shared room boundaries.
    for polygon in terrain:
        if polygon.size() >= 3:
            draw_colored_polygon(polygon, Color("263930"))

func edge(segment: PackedVector2Array, color: Color, width: float) -> void:
    draw_line(segment[0], segment[1], color, width, true)
