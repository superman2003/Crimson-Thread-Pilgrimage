extends RefCounted
## Session-owned camera limits and delayed observation, never player/world coordinates.
const LOOK_DELAY := 0.35
const LOOK_DISTANCE := 150.0
var region_bounds := Rect2()
var locks: Dictionary = {}
var active_lock := ""
var look_direction := 0
var look_timer := 0.0
var look_offset := 0.0

func clear_look() -> void:
    look_direction = 0
    look_timer = 0.0
    look_offset = 0.0

func configure(camera: Camera2D, bounds: Rect2) -> bool:
    if not _valid_bounds(bounds):
        return false
    locks.clear()
    active_lock = ""
    clear_look()
    region_bounds = bounds
    apply_limits(camera)
    return true

func push_lock(id: String, bounds: Rect2, priority: int = 0, prevent_up: bool = false, prevent_down: bool = false) -> bool:
    if id.is_empty() or not _valid_bounds(bounds):
        return false
    if _valid_bounds(region_bounds) and not region_bounds.intersects(bounds):
        return false
    locks[id] = {"bounds": bounds, "priority": priority, "prevent_up": prevent_up, "prevent_down": prevent_down}
    var selected := _select_lock()
    if (look_direction < 0 and bool(selected.get("prevent_up", false))) or (look_direction > 0 and bool(selected.get("prevent_down", false))):
        clear_look()
    return true

func remove_lock(id: String) -> void:
    locks.erase(id)

func _valid_bounds(bounds: Rect2) -> bool:
    return bounds.position.is_finite() and bounds.size.is_finite() and bounds.size.x > 0.0 and bounds.size.y > 0.0

func _select_lock() -> Dictionary:
    active_lock = ""
    var priority := -2147483648
    # Lexical tie-break keeps overlapping event locks independent of insertion order.
    var ids := locks.keys()
    ids.sort()
    for id in ids:
        var candidate: Dictionary = locks[id]
        if active_lock.is_empty() or int(candidate.priority) > priority:
            active_lock = String(id)
            priority = int(candidate.priority)
    return locks[active_lock] if not active_lock.is_empty() else {}

func effective_bounds(camera: Camera2D, selected: Dictionary) -> Rect2:
    if not _valid_bounds(region_bounds):
        return Rect2()
    var bounds: Rect2 = selected.get("bounds", region_bounds)
    bounds = bounds.intersection(region_bounds)
    if not _valid_bounds(bounds):
        return region_bounds
    var view_size := camera.get_viewport_rect().size / camera.zoom.abs().max(Vector2(0.01, 0.01))
    # A small arena cannot contain a whole viewport. Center it inside the region,
    # without changing zoom or reversing the legal limits.
    var size := bounds.size.max(view_size).min(region_bounds.size)
    var origin := bounds.get_center() - size * 0.5
    origin.x = clampf(origin.x, region_bounds.position.x, region_bounds.end.x - size.x)
    origin.y = clampf(origin.y, region_bounds.position.y, region_bounds.end.y - size.y)
    return Rect2(origin, size)

func apply_limits(camera: Camera2D) -> Dictionary:
    var selected := _select_lock()
    var bounds := effective_bounds(camera, selected)
    if not _valid_bounds(bounds):
        return selected
    camera.limit_left = floori(bounds.position.x)
    camera.limit_top = floori(bounds.position.y)
    camera.limit_right = ceili(bounds.end.x)
    camera.limit_bottom = ceili(bounds.end.y)
    return selected

func update(camera: Camera2D, delta: float, requested_direction: int, eligible: bool, strength: float) -> float:
    var selected := apply_limits(camera)
    var allowed := eligible and strength > 0.0
    if requested_direction < 0 and bool(selected.get("prevent_up", false)):
        allowed = false
    if requested_direction > 0 and bool(selected.get("prevent_down", false)):
        allowed = false
    var direction := requested_direction if allowed else 0
    if direction == 0:
        look_direction = 0
        look_timer = 0.0
    elif direction != look_direction:
        look_direction = direction
        look_timer = delta
    else:
        look_timer = minf(LOOK_DELAY, look_timer + delta)
    var target := float(direction) * LOOK_DISTANCE * strength if direction != 0 and look_timer >= LOOK_DELAY else 0.0
    # Player camera already eases this target; avoid a second observation filter.
    look_offset = target
    return look_offset
