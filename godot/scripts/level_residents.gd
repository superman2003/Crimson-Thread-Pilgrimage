extends RefCounted
## Enemy platforms and walk obstacles, gameplay prefabs, resident NPC interactions and creating enemies.
## Moved out of main_level.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func platform_under_position(level: Node, position_value: Vector2, clearance: float = 40.0) -> String:
    var expected_top := position_value.y + clearance
    for platform in level.config.get("platforms", []):
        if not (platform is Dictionary):
            continue
        var platform_data: Dictionary = platform
        var platform_id := String(platform_data.get("id", ""))
        var rect: Rect2 = level._rect2(platform_data.get("rect", []))
        if not level._enemy_spawn_platform_allowed(platform_id, rect):
            continue
        if position_value.x >= rect.position.x - 1.0 and position_value.x <= rect.position.x + rect.size.x + 1.0 and absf(rect.position.y - expected_top) <= 8.0:
            return platform_id
    return ""


static func enemy_walk_obstacles(level: Node, sweep: Rect2, floor_y: float, floor_platform_id: String) -> Dictionary:
    var rects: Array[Rect2] = []
    if level.cave_world != null:
        for solid in level.cave_world.solid_rects:
            if solid.intersects(sweep): rects.append(solid)
    for platform in level.config.get("platforms", []):
        if not (platform is Dictionary):
            continue
        var platform_data: Dictionary = platform
        if not String(platform_data.get("terrain_id", "")).is_empty():
            continue
        if String(platform_data.get("id", "")) == floor_platform_id:
            continue
        var rect: Rect2 = level._rect2(platform_data.get("rect", []))
        if rect.size.x <= 0.0 or rect.size.y <= 0.0 or rect.position.y >= floor_y + 10.0:
            continue
        if rect.intersects(sweep): rects.append(rect)
    return {"rects": rects, "terrain": level.chapter_terrain != null and level.chapter_terrain.intersects_rect(sweep)}


static func enemy_walk_clear(level: Node, position_value: Vector2, half_width: float, visual_height: float, obstacles: Dictionary) -> bool:
    var actor_rect := Rect2(position_value + Vector2(-half_width, -visual_height), Vector2(half_width * 2.0, visual_height + 8.0))
    if obstacles.terrain and level.chapter_terrain.intersects_rect(actor_rect):
        return false
    for rect in obstacles.rects:
        if actor_rect.intersects(rect):
            return false
    return true


static func spawn_normal_enemies(level: Node) -> void:
    for spawn in level.config.get("enemy_spawns", []):
        if spawn is Dictionary:
            level._enemy(spawn)


static func take_gameplay_prefab(level: Node, kind: String, data: Dictionary, profile: Dictionary = {}) -> Area2D:
    if not level.world_mode or level.world_prefetch == null or not level.world_prefetch.synchronize_route_cache():
        return null
    return level.world_prefetch.gameplay.take(String(level.config.id), kind, data, profile)


static func make_enemy_prefab(level: Node, data: Dictionary, profile: Dictionary) -> Area2D:
    var enemy := Area2D.new()
    enemy.set_script(level.ENEMY_ACTOR_SCRIPT)
    var kind := String(data.get("kind", "moss_larva"))
    enemy.configure(data, level.SPRITES.get(kind, level.SPRITES["moss_larva"]), false, profile)
    enemy.prepare_presentation()
    return enemy


static func create_gameplay_prefab(level: Node, kind: String, data: Dictionary, prepared: Dictionary) -> Area2D:
    match kind:
        "enemy": return level._make_enemy_prefab(data, prepared.get("ai_profiles", {}).get(String(data.get("kind", "moss_larva")), {}))
        "npc": return level._make_npc(data)
        "save_point": return level._make_save_point(data)
        "lever": return level._make_lever(data)
        "boss_gate": return level._make_boss_door(data)
        "world_portal": return level._make_world_portal(data)
    return null


static func build_resident_interaction(level: Node, kind: String, data: Dictionary) -> Area2D:
    match kind:
        "npc": level._npc(data)
        "save_point": level._save_point(data)
        "lever": level._lever(data)
    return level.get_node_or_null(NodePath(String(data.get("id", "")))) as Area2D


static func release_resident_interaction(level: Node, kind: String, id: String, area: Area2D) -> bool:
    if not is_instance_valid(area):
        return true
    if kind == "npc":
        var memory_key := String(level.config.get("id", "")) + ":" + id
        level.npc_residency_memory[memory_key] = {
            "dialogue_index": int(area.get_meta("dialogue_index", 0)),
            "dialogue_state_indices": area.get_meta("dialogue_state_indices", {}).duplicate(true)
        }
    elif kind == "save_point":
        var memory_key := String(level.config.get("id", "")) + ":" + id
        level.save_point_residency_memory[memory_key] = bool(area.get_meta("activated", false))
    if level.nearby_interactable == area:
        level.nearby_interactable = null
    if level.ui_shell != null and level.ui_shell.dialogue_area == area:
        return false
    var owned_tweens: Variant = area.get_meta("residency_tweens", [])
    if owned_tweens is Array:
        for tween in owned_tweens:
            if tween is Tween:
                if tween.is_valid(): tween.kill()
                level.region_tweens.erase(tween)
        area.remove_meta("residency_tweens")
    if area.get_parent() == level:
        level.remove_child(area)
    area.free()
    return true


static func world_npc_residency_position(level: Node, npc_id: String, fallback: Vector2) -> Vector2:
    if not level.world_mode or level.world_narrative == null:
        return fallback
    var state: Dictionary = level.world_narrative.npc_world_state(npc_id, level.story_flags)
    var region_id := "demo_" + String(state.get("region", ""))
    if region_id == String(level.config.get("id", "")) and state.has("position"):
        return level._vec2(state.position)
    return fallback


static func enemy(level: Node, data: Dictionary) -> Area2D:
    var clearance := float(data.get("clearance", 40.0))
    var kind := String(data.get("kind", "moss_larva"))
    var profiles: Dictionary = level.config.get("ai_profiles", {})
    var profile: Dictionary = profiles.get(kind, {})
    if profile.is_empty():
        push_warning("Missing normal enemy AI profile: " + kind)
    var enemy: Area2D = level._take_gameplay_prefab("enemy", data, profile)
    if enemy == null: enemy = level._make_enemy_prefab(data, profile)
    # Collision clearance and support depend on the active destination, never
    # on the region in which the detached actor was prepared.
    enemy.position = level._resolve_enemy_spawn_position(data)
    enemy.set("death_sfx_key", level._enemy_death_sfx_key())
    var floor_platform_id: String = level._platform_under_position(enemy.position, clearance)
    if level.world_platforms != null:
        level._hold_actor_support(floor_platform_id)
    var bounds: Array = level._enemy_platform_movement_bounds(floor_platform_id, enemy.position, data)
    if bounds.size() >= 2 and enemy.has_method("set_platform_movement_bounds"):
        enemy.set_platform_movement_bounds(float(bounds[0]), float(bounds[1]))
    enemy.died.connect(level._on_enemy_died)
    enemy.set_meta("platform_id", floor_platform_id)
    enemy.set_meta("spawn_half_width", float(data.get("spawn_half_width", 36.0)))
    enemy.set_meta("spawn_visual_height", float(data.get("spawn_visual_height", level._enemy_spawn_visual_height(data))))
    if String(enemy.locomotion)=="flight":
        while enemy.hover_height>35 and not level._enemy_spawn_rect_clear(enemy.position-Vector2(0,enemy.hover_height),24,level._enemy_spawn_visual_height(data),floor_platform_id):
            enemy.hover_height-=10
        if not level._enemy_spawn_rect_clear(enemy.position-Vector2(0,enemy.hover_height),24,level._enemy_spawn_visual_height(data),floor_platform_id):
            for offset in [-48.0,48.0,-96.0,96.0]:
                var candidate = enemy.position+Vector2(offset,-enemy.hover_height)
                if level._enemy_spawn_rect_clear(candidate,24,level._enemy_spawn_visual_height(data),floor_platform_id):
                    enemy.position.x=candidate.x
                    break
    level.add_child(enemy)
    if level.world_mode and level.world_gameplay_residency != null:
        level.world_gameplay_residency.adopt_enemy(enemy)
    return enemy
