extends RefCounted
## Authored exploration framing, below event locks. No scene or player references.
const LOCK_ID := "exploration_room"
const EDGE_MARGIN := 24.0
var zones: Array[Dictionary] = []
var current: Dictionary = {}
var display_bounds := Rect2()

func _rect(value: Variant) -> Rect2:
    if not value is Array or value.size() != 4:
        return Rect2()
    for number in value:
        if not (number is int or number is float) or not is_finite(float(number)):
            return Rect2()
    var result := Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
    return result if result.size.x > 0 and result.size.y > 0 and result.end.is_finite() else Rect2()

func configure(rooms: Array, focus: RefCounted) -> void:
    if not is_instance_valid(focus):return
    focus.remove_lock(LOCK_ID)
    zones.clear()
    current = {}
    display_bounds = Rect2()
    var ids: Dictionary = {}
    for room in rooms:
        if not room is Dictionary:
            continue
        var id: Variant = room.get("id")
        if not id is String or id.is_empty() or ids.has(id):continue
        var raw: Variant = room.get("visit_rects", [room.get("layout_rect", [])])
        if not raw is Array:continue
        var bounds := _rect(room.get("camera_bounds", []))
        var triggers: Array[Rect2] = []
        for value in raw:
            var rect := _rect(value)
            if rect.has_area(): triggers.append(rect)
        if bounds.has_area() and not triggers.is_empty():
            zones.append({"id": id, "bounds": bounds, "triggers": triggers})
            ids[id] = true

func _area_at(zone: Dictionary, point: Vector2, padding: float = 0.0) -> float:
    var smallest := INF
    for rect in zone.get("triggers", []):
        if rect.grow(padding).has_point(point): smallest = minf(smallest, rect.get_area())
    return smallest

func _inside_entry(zone: Dictionary, point: Vector2) -> bool:
    for rect in zone.get("triggers", []):
        # A fixed 24px inset erased triggers <=48px wide/high. Keep a
        # decisive interior on each axis, even for narrow authored passages.
        var inset: Vector2 = rect.size.min(Vector2.ONE * EDGE_MARGIN * 4.0) * 0.25
        if Rect2(rect.position + inset, rect.size - inset * 2.0).has_point(point):
            return true
    return false

func update(focus: RefCounted, point: Vector2, delta: float = 0.0) -> void:
    if not is_instance_valid(focus) or not point.is_finite():return
    delta = maxf(0.0, delta) if is_finite(delta) else 0.0
    var candidate: Dictionary = {}
    var area := INF
    for zone in zones:
        var size := _area_at(zone, point)
        if size < area or (size < INF and size == area and String(zone.id) < String(candidate.get("id", ""))):
            candidate = zone
            area = size
    # Retain the previous zone at a doorway, until the next room is entered
    # decisively. Deeper nested pockets can still take precedence.
    if not current.is_empty() and _area_at(current, point, EDGE_MARGIN) < INF and (_area_at(current, point) == INF or candidate.is_empty() or not _inside_entry(candidate, point)):
        candidate = current
    var changed := String(candidate.get("id", "")) != String(current.get("id", ""))
    current = candidate
    if current.is_empty():
        focus.remove_lock(LOCK_ID)
        display_bounds = Rect2()
        return
    var target: Rect2 = current.bounds
    if delta <= 0.0 or not display_bounds.has_area():
        display_bounds = target
    else:
        var weight := 1.0 - exp(-delta * 8.0)
        display_bounds = Rect2(display_bounds.position.lerp(target.position, weight), display_bounds.size.lerp(target.size, weight))
    if changed or not focus.locks.has(LOCK_ID) or not display_bounds.is_equal_approx(focus.locks[LOCK_ID].bounds):
        focus.push_lock(LOCK_ID, display_bounds, 10)
