extends RefCounted
## Where an enemy stands: a safe spot on its platform, a fallback when the authored one is blocked, and how far it may patrol.
## Moved out of main_level.gd unchanged in behaviour; the level keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func resolve_enemy_spawn_position(level: Node, data: Dictionary) -> Vector2:
    var requested: Vector2 = level._vec2(data.get("position", [0, 0]))
    var clearance := float(data.get("clearance", 40.0))
    var requested_top: float = requested.y + clearance
    var explicit_platform := String(data.get("platform_id", ""))
    var best_platform_id := ""
    var best_rect := Rect2()
    var best_score := INF

    for platform in level.config.get("platforms", []):
        if not (platform is Dictionary):
            continue
        var platform_data: Dictionary = platform
        var platform_id := String(platform_data.get("id", ""))
        var rect: Rect2 = level._rect2(platform_data.get("rect", []))
        if not level._enemy_spawn_platform_allowed(platform_id, rect):
            continue
        if not explicit_platform.is_empty() and platform_id != explicit_platform:
            continue

        var margin := minf(38.0, rect.size.x * 0.22)
        var clamped_x := clampf(requested.x, rect.position.x + margin, rect.position.x + rect.size.x - margin)
        if explicit_platform.is_empty() and absf(clamped_x - requested.x) > 2.0:
            continue

        var score := absf(rect.position.y - requested_top) + absf(clamped_x - requested.x) * 0.25
        if score < best_score:
            best_score = score
            best_rect = rect
            best_platform_id = platform_id

    if best_score < INF:
        return level._safe_enemy_spawn_on_platform(data, requested, best_platform_id, best_rect, clearance)
    return level._fallback_enemy_spawn_position(data, requested, clearance)


static func safe_enemy_spawn_on_platform(level: Node, data: Dictionary, requested: Vector2, platform_id: String, rect: Rect2, clearance: float) -> Vector2:
    var half_width := float(data.get("spawn_half_width", 36.0))
    var visual_height := float(data.get("spawn_visual_height", level._enemy_spawn_visual_height(data)))
    var margin := maxf(half_width + 12.0, minf(54.0, rect.size.x * 0.24))
    var min_x := rect.position.x + margin
    var max_x := rect.position.x + rect.size.x - margin
    if min_x > max_x:
        var center_x := rect.position.x + rect.size.x * 0.5
        var center_position := Vector2(center_x, rect.position.y - clearance)
        if level._enemy_spawn_rect_clear(center_position, half_width, visual_height, platform_id):
            return center_position
        return level._fallback_enemy_spawn_position(data, requested, clearance, platform_id)

    var requested_x := clampf(requested.x, min_x, max_x)
    var candidate_xs: Array = [
        requested_x,
        requested_x - 70.0,
        requested_x + 70.0,
        requested_x - 140.0,
        requested_x + 140.0,
        min_x,
        max_x,
        rect.position.x + rect.size.x * 0.5
    ]
    var best_position := Vector2(requested_x, rect.position.y - clearance)
    var best_score := INF
    for candidate_value in candidate_xs:
        var x := clampf(float(candidate_value), min_x, max_x)
        var position_value := Vector2(x, rect.position.y - clearance)
        var score := absf(x - requested.x)
        # Clearance is pure geometry. A tied/worse candidate cannot replace
        # the first winner, so do not spend collision queries on that candidate.
        if score >= best_score:
            continue
        if not level._enemy_spawn_rect_clear(position_value, half_width, visual_height, platform_id):
            continue
        if score < best_score:
            best_score = score
            best_position = position_value
    if best_score < INF:
        return best_position
    return level._fallback_enemy_spawn_position(data, requested, clearance, platform_id)


static func fallback_enemy_spawn_position(level: Node, data: Dictionary, requested: Vector2, clearance: float, preferred_platform_id: String = "") -> Vector2:
    var half_width := float(data.get("spawn_half_width", 36.0))
    var visual_height := float(data.get("spawn_visual_height", level._enemy_spawn_visual_height(data)))
    var requested_top := requested.y + clearance
    var best_position := requested
    var best_score := INF
    for platform in level.config.get("platforms", []):
        if not (platform is Dictionary):
            continue
        var platform_data: Dictionary = platform
        var platform_id := String(platform_data.get("id", ""))
        var rect: Rect2 = level._rect2(platform_data.get("rect", []))
        if not level._enemy_spawn_platform_allowed(platform_id, rect):
            continue
        var margin := maxf(half_width + 12.0, minf(54.0, rect.size.x * 0.24))
        var min_x: float = rect.position.x + margin
        var max_x: float = rect.position.x + rect.size.x - margin
        if min_x > max_x:
            continue
        var candidate_xs: Array = [
            clampf(requested.x, min_x, max_x),
            rect.position.x + rect.size.x * 0.5,
            min_x,
            max_x
        ]
        var step := maxf(44.0, half_width * 1.5)
        var scan_x: float = min_x
        while scan_x <= max_x + 0.5:
            candidate_xs.append(scan_x)
            scan_x += step
        for candidate_value in candidate_xs:
            var x := clampf(float(candidate_value), min_x, max_x)
            var position_value := Vector2(x, rect.position.y - clearance)
            var platform_bias := 0.0 if platform_id == preferred_platform_id else 220.0
            var score := absf(rect.position.y - requested_top) * 1.8 + absf(x - requested.x) * 0.35 + platform_bias
            if score >= best_score:
                continue
            if not level._enemy_spawn_rect_clear(position_value, half_width, visual_height, platform_id):
                continue
            if score < best_score:
                best_score = score
                best_position = position_value
    if best_score >= INF:
        push_warning("No clear enemy spawn found for " + String(data.get("id", "enemy")) + "; check platform geometry.")
    return best_position


static func enemy_spawn_visual_height(level: Node, data: Dictionary) -> float:
    var original_path := String(data.get("sprite",""))
    if original_path.contains("original_creatures"):
        return maxf(20,float(level.ORIGINAL_ART.manifest(original_path).get("display_height",90))-40)
    var region: Array = data.get("sprite_region", [])
    var region_height := 72.0
    if region.size() >= 4:
        region_height = float(region[3])
    var scale_value := float(data.get("visual_scale", 1.0))
    var offset: Vector2 = level._vec2(data.get("visual_offset", [0, 0]))
    var sprite_center_above_origin: float = 18.0 - offset.y
    return clampf(sprite_center_above_origin + region_height * scale_value * 0.5 + 12.0, 48.0, 116.0)


static func enemy_spawn_rect_clear(level: Node, position_value: Vector2, half_width: float = 36.0, visual_height: float = 104.0, floor_platform_id: String = "") -> bool:
    var actor_rect := Rect2(position_value + Vector2(-half_width, -visual_height), Vector2(half_width * 2.0, visual_height + 8.0))
    if level.chapter_terrain != null and level.chapter_terrain.intersects_rect(actor_rect):
        return false
    if level.cave_world != null and level.cave_world.intersects_rect(actor_rect):
        return false
    for platform in level.config.get("platforms", []):
        if not (platform is Dictionary):
            continue
        var platform_data: Dictionary = platform
        if not String(platform_data.get("terrain_id", "")).is_empty():
            continue # The anchor rectangle was replaced by a continuous terrain polygon.
        var platform_id := String(platform_data.get("id", ""))
        if platform_id == floor_platform_id:
            continue
        var rect: Rect2 = level._rect2(platform_data.get("rect", []))
        if rect.size.x <= 0.0 or rect.size.y <= 0.0:
            continue
        if rect.position.y >= position_value.y + 10.0:
            continue
        if actor_rect.intersects(rect):
            return false
    return true


static func enemy_spawn_platform_allowed(level: Node, platform_id: String, rect: Rect2) -> bool:
    if rect.size.x <= 0.0 or rect.size.y <= 0.0:
        return false
    var lowered := platform_id.to_lower()
    if lowered.contains("wall") or lowered.contains("gate") or lowered.contains("locked"):
        return false
    if rect.size.x < 86.0 or rect.size.y > 90.0:
        return false
    return true


static func enemy_platform_movement_bounds(level: Node, platform_id: String, spawn_position: Vector2, data: Dictionary) -> Array:
    if platform_id.is_empty():
        return []
    var floor_rect := Rect2()
    for platform in level.config.get("platforms", []):
        if not (platform is Dictionary):
            continue
        var platform_data: Dictionary = platform
        if String(platform_data.get("id", "")) == platform_id:
            floor_rect = level._rect2(platform_data.get("rect", []))
            break
    if floor_rect.size.x <= 0.0:
        return []

    var half_width := float(data.get("spawn_half_width", 36.0))
    var visual_height := float(data.get("spawn_visual_height", level._enemy_spawn_visual_height(data)))
    var margin := maxf(half_width + 12.0, minf(54.0, floor_rect.size.x * 0.24))
    var min_x := floor_rect.position.x + margin
    var max_x := floor_rect.position.x + floor_rect.size.x - margin
    if min_x >= max_x:
        return []

    var center_x := clampf(spawn_position.x, min_x, max_x)
    var step := maxf(8.0, minf(18.0, half_width * 0.45))
    var left := center_x
    var right := center_x
    # T03: the walk tests up to ~100 positions; each full clearance query
    # scanned every platform and rock rect (10–60 ms per enemy in one build
    # frame). Collect once what can touch this floor's swept band, then test
    # the same positions against only those (same results, same order).
    var obstacles: Dictionary = level._enemy_walk_obstacles(Rect2(min_x - step - half_width, spawn_position.y - visual_height, max_x - min_x + 2.0 * (step + half_width), visual_height + 8.0).grow(1.0), spawn_position.y, platform_id)
    while left - step >= min_x and level._enemy_walk_clear(Vector2(left - step, spawn_position.y), half_width, visual_height, obstacles):
        left -= step
    while right + step <= max_x and level._enemy_walk_clear(Vector2(right + step, spawn_position.y), half_width, visual_height, obstacles):
        right += step
    if right - left < half_width:
        return [left-0.05, right+0.05]
    return [left, right]
