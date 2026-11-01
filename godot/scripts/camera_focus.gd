extends RefCounted
## Session-owned framing and limits. Never changes player/world coordinates.
const LOOK_DELAY := 0.35
const LOOK_DISTANCE := 150.0
const NEUTRAL_HEIGHT := 55.0
const FLOOR_REBASE_DISTANCE := 12.0
const OFFSET_RESPONSE := 5.0
# World-space center, separate from the Camera2D's inherited player transform.
# A jump inside the safe band must not move this target at all.
var follow_ready := false
var follow_center_y := 0.0
var follow_floor_y := 0.0
var follow_observation := 0.0
var follow_was_airborne := false
var follow_vertical_travel := false
var follow_vertical_direction := 0
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
    if not is_instance_valid(camera) or not _valid_bounds(bounds):
        return false
    locks.clear()
    active_lock = ""
    clear_look()
    follow_ready = false
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
    return bounds.position.is_finite() and bounds.size.is_finite() and bounds.end.is_finite() and bounds.size.x > 0.0 and bounds.size.y > 0.0

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
    if not is_instance_valid(camera) or not camera.is_inside_tree() or not camera.zoom.is_finite() or not _valid_bounds(region_bounds):
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

func update(camera: Camera2D, delta: float, requested_direction: int, eligible: bool, strength: float, delay: float = LOOK_DELAY) -> float:
    var selected := apply_limits(camera)
    delay = clampf(delay,0.15,1.0) if is_finite(delay) else LOOK_DELAY
    delta = maxf(0.0, delta) if is_finite(delta) else 0.0
    strength = clampf(strength, 0.0, 1.0) if is_finite(strength) else 0.0
    requested_direction = clampi(requested_direction, -1, 1)
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
        look_timer = minf(delay, look_timer + delta)
    var target := float(direction) * LOOK_DISTANCE * strength if direction != 0 and look_timer >= delay else 0.0
    # Player camera already eases this target; avoid a second observation filter.
    look_offset = target
    return look_offset


func reset_follow(point: Vector2) -> void:
    if not point.is_finite():return
    # Arrival/respawn owns the intentional cut. Ordinary room switches retain
    # this baseline and the existing eased room limits, without resetting scroll.
    follow_ready = true
    follow_center_y = point.y - NEUTRAL_HEIGHT
    follow_floor_y = point.y
    follow_observation = 0.0
    follow_was_airborne = false
    follow_vertical_travel = false
    follow_vertical_direction = 0


func follow_position(camera: Camera2D, point: Vector2, motion: Vector2, grounded: bool, delta: float, strength: float, observation: float) -> Vector2:
    if not is_instance_valid(camera):return Vector2(0, -NEUTRAL_HEIGHT)
    if not point.is_finite() or not camera.is_inside_tree():
        return camera.position if camera.position.is_finite() else Vector2(0, -NEUTRAL_HEIGHT)
    # One invalid sample must not contaminate the persistent follow baseline.
    if not motion.is_finite():motion = Vector2.ZERO
    delta = maxf(delta, 0.0) if is_finite(delta) else 0.0
    strength = clampf(strength, 0.0, 1.0) if is_finite(strength) else 0.0
    observation = clampf(observation, -LOOK_DISTANCE, LOOK_DISTANCE) if is_finite(observation) else 0.0
    if not follow_ready:
        reset_follow(point)
    var weight := 1.0 - exp(-maxf(delta, 0.0) * OFFSET_RESPONSE)
    var horizontal := lerpf(camera.position.x if is_finite(camera.position.x) else 0.0, clampf(motion.x * 0.18, -90.0, 90.0) * strength, weight)
    follow_observation = lerpf(follow_observation, observation, weight)
    if grounded:
        # Reframe a new platform layer, but ignore tiny floor-contact corrections.
        # Landing after genuine vertical travel also restores neutral framing.
        if absf(point.y - follow_floor_y) > FLOOR_REBASE_DISTANCE or (follow_was_airborne and follow_vertical_travel):
            follow_floor_y = point.y
            follow_center_y = point.y - NEUTRAL_HEIGHT
        follow_vertical_travel = false
        follow_vertical_direction = 0
    else:
        var half_height := camera.get_viewport_rect().size.y / maxf(absf(camera.zoom.y), 0.01) * 0.5
        # At 720p / 1.25 zoom, the ordinary 136px jump stays entirely inside
        # this band. Small viewports release earlier to keep head/feet visible.
        var upper_band := minf(160.0, maxf(24.0, half_height - 112.0))
        var lower_band := minf(100.0, maxf(24.0, half_height - 128.0))
        # Camera2D still provides its original world-position smoothing. Only
        # after leaving the safe band, compensate its lag so a fast shaft fall
        # reveals the landing route instead of letting the feet leave the view.
        # This safety follow remains active when optional lookahead is disabled.
        var lag := 1.0 / maxf(camera.position_smoothing_speed, 0.01) if camera.position_smoothing_enabled else 0.0
        if motion.y < 0.0 and point.y < follow_center_y - upper_band:
            follow_vertical_direction = -1
            follow_vertical_travel = true
        elif motion.y > 0.0 and point.y > follow_center_y + lower_band:
            follow_vertical_direction = 1
            follow_vertical_travel = true
        # Once a shaft traversal begins, continue its motion each frame instead
        # of repeatedly crossing a threshold and moving in visible stair steps.
        # Prediction must also retract when a wall, ceiling or air action slows
        # the body. A one-way min/max would retain obsolete high-speed lead and
        # let the still-smoothed screen move away from the stopped player.
        if follow_vertical_direction < 0 and motion.y <= 0.0:
            follow_center_y = point.y + upper_band + motion.y * lag
        elif follow_vertical_direction > 0 and motion.y >= 0.0:
            follow_center_y = point.y - lower_band + motion.y * lag
    follow_was_airborne = not grounded
    # Compensate inherited Y immediately; lerping this local offset would feed
    # the jump back into the camera. X/observation retain the existing response.
    # Authored room/Boss bounds and FeelKit offsets remain Camera2D-owned.
    return Vector2(horizontal, follow_center_y + follow_observation - point.y)
