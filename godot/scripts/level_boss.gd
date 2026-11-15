extends RefCounted
## Spawning the boss and boss trials, locking the arena and its camera, and where the boss gate stands.
## Moved out of main_level.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func spawn_boss(level: Node) -> void:
    if level.boss_spawned or level.demo_complete:
        return
    var boss_data: Dictionary = level.config.get("boss", {})
    level.boss_actor = Area2D.new()
    var clearance := float(boss_data.get("clearance", 40.0))
    level.boss_actor.position = level._resolve_enemy_spawn_position(boss_data)
    level.boss_actor.set_script(level.ENEMY_ACTOR_SCRIPT)
    var kind := String(boss_data.get("kind", "rust_crown_guardian"))
    var profiles: Dictionary = level.config.get("ai_profiles", {})
    var profile: Dictionary = profiles.get(kind, {})
    if profile.is_empty():
        push_warning("Missing boss AI profile: " + kind)
    level.boss_actor.configure(boss_data, level.SPRITES.get(kind, level.SPRITES["rust_crown_guardian"]), true, profile)
    level.boss_actor.set("death_sfx_key", level._enemy_death_sfx_key())
    var floor_platform_id: String = level._platform_under_position(level.boss_actor.position, clearance)
    if level.world_platforms != null:
        level._hold_actor_support(floor_platform_id)
    var bounds: Array = level._enemy_platform_movement_bounds(floor_platform_id, level.boss_actor.position, boss_data)
    if bounds.size() >= 2 and level.boss_actor.has_method("set_platform_movement_bounds"):
        level.boss_actor.set_platform_movement_bounds(float(bounds[0]), float(bounds[1]))
    level.boss_actor.died.connect(level._on_enemy_died)
    level.boss_actor.set_meta("platform_id", floor_platform_id)
    level.boss_actor.set_meta("spawn_half_width", float(boss_data.get("spawn_half_width", 84.0)))
    level.boss_actor.set_meta("spawn_visual_height", float(boss_data.get("spawn_visual_height", level._enemy_spawn_visual_height(boss_data))))
    level.add_child(level.boss_actor)
    level.boss_spawned = true
    # Boss 曲按章 boss kind 选曲（终 Boss silent_crown_core 三乐章由血量轮询驱动）。
    if level.audio_director != null:
        level.audio_director.start_boss_music(kind)
    else:
        level._switch_bgm("bgm_boss")
    # Boss 战开始 ducking 示范点（规格 §5.3）：入场威压瞬间压低 BGM 再回弹，
    # 覆盖 _debug_start_boss 与 _activate_boss_gate 两条激活路径。
    level.duck_bgm(-6.0, 1.5)
    level._toast("钟门深处 · " + level._boss_display_name(boss_data))
    level._refresh_hud()


static func start_boss_trial(level: Node) -> void:
    if level.world_gameplay_residency != null:
        level.world_gameplay_residency.clear_enemy_actors()
    for enemy_node in level.get_tree().get_nodes_in_group("enemy"):
        var enemy_area := enemy_node as Area2D
        if enemy_area == null or not is_instance_valid(enemy_area):
            continue
        if bool(enemy_area.get("is_boss")):
            continue
        if enemy_area.has_method("_cancel_attack_effects"):
            enemy_area._cancel_attack_effects()
        enemy_area.queue_free()
    level.enemy_defeated = level.enemy_total
    level._open_all_shortcuts(false)
    var boss_data: Dictionary = level.config.get("boss", {})
    var boss_position: Vector2 = level._vec2(boss_data.get("position", level.config.get("boss_checkpoint", level.active_spawn)))
    var trial_spawn: Vector2 = level._vec2(level.config.get("boss_checkpoint", boss_position + Vector2(-520.0, 0.0)))
    if trial_spawn == Vector2.ZERO:
        trial_spawn = boss_position + Vector2(-520.0, 0.0)
    level.active_spawn = trial_spawn
    level.active_save_point_id = "boss_trial"
    if level.player != null and is_instance_valid(level.player):
        level.player.global_position = trial_spawn
        if level.player.has_method("set_spawn"):
            level.player.set_spawn(trial_spawn)
        if level.player.has_method("restore_at_save_point"):
            level.player.restore_at_save_point()
        if level.player.has_method("reset_camera_after_arrival"):
            level.player.reset_camera_after_arrival()
    level._spawn_boss()
    if level.boss_spawned and not level.demo_complete:
        if level.boss_trial_mode or not level.config.get("interactives", []).is_empty():
            level._set_boss_arena_locked(true)
    level._update_room_visit()
    level._toast("试炼开始 · 苔钟守母已苏醒。")
    level._refresh_hud()


static func set_boss_arena_locked(level: Node, locked: bool) -> void:
    if locked:
        level._lock_boss_camera()
        if level.boss_arena_lock_body != null and is_instance_valid(level.boss_arena_lock_body):
            return
        var lock_rect: Rect2 = level._boss_arena_lock_rect()
        var material: String = level._theme_boss_material()
        level.boss_arena_lock_body = level._platform("boss_arena_lock_wall", lock_rect, level._color("2a1715"), material)
        level.boss_arena_lock_body.set_meta("temporary_boss_lock", true)
        if level.player != null and is_instance_valid(level.player):
            var safe_x = lock_rect.position.x + lock_rect.size.x + 54.0
            if level.player.global_position.x < safe_x:
                level.player.global_position = Vector2(safe_x, level.player.global_position.y)
                level.player.set("velocity", Vector2.ZERO)
        level._toast("钟门已合，战斗开始。")
        return

    if level.boss_arena_lock_body != null and is_instance_valid(level.boss_arena_lock_body):
        level._spawn_route_open_effect(level.boss_arena_lock_body.global_position)
        level.boss_arena_lock_body.queue_free()
    level.boss_arena_lock_body = null
    if is_instance_valid(level.player):
        level.player.remove_camera_lock("boss_arena")


static func lock_boss_camera(level: Node) -> void:
    if not is_instance_valid(level.player):
        return
    var boss_data: Dictionary = level.config.get("boss", {})
    var point: Vector2 = level._vec2(boss_data.get("position", level.active_spawn))
    var left := float(boss_data.get("arena_min_x", point.x - 360.0))
    var right := float(boss_data.get("arena_max_x", point.x + 360.0))
    var floor_y = point.y + 40.0
    # Floor/jump/telegraph framing comes from the real arena, not map rectangles.
    level.player.push_camera_lock("boss_arena", Rect2(left - 100.0, floor_y - 520.0, right - left + 200.0, 620.0), 100, true, true)


static func boss_arena_lock_rect(level: Node) -> Rect2:
    var boss_data: Dictionary = level.config.get("boss", {})
    if boss_data.has("lock_rect"):
        return level._rect2(boss_data.get("lock_rect", []))
    var gate_position: Vector2 = level._boss_gate_position()
    var floor_top: float = level._floor_top_near_x(gate_position.x)
    var height := float(boss_data.get("lock_height", 315.0))
    var width := float(boss_data.get("lock_width", 46.0))
    var lock_x := float(boss_data.get("lock_x", gate_position.x - 172.0))
    return Rect2(lock_x, floor_top - height, width, height + 44.0)


static func boss_gate_position(level: Node) -> Vector2:
    for interactive in level.config.get("interactives", []):
        if not (interactive is Dictionary):
            continue
        var data: Dictionary = interactive
        if String(data.get("kind", "")) == "boss_gate":
            return level._vec2(data.get("position", level.config.get("boss_checkpoint", level.active_spawn)))
    return level._vec2(level.config.get("boss_checkpoint", level.active_spawn))


static func floor_top_near_x(level: Node, world_x: float) -> float:
    var best_y := 540.0
    var best_score := INF
    for platform in level.config.get("platforms", []):
        if not (platform is Dictionary):
            continue
        var data: Dictionary = platform
        var rect: Rect2 = level._rect2(data.get("rect", []))
        if rect.size.x <= 0.0 or rect.size.y <= 0.0:
            continue
        if world_x < rect.position.x - 8.0 or world_x > rect.position.x + rect.size.x + 8.0:
            continue
        if rect.size.y > 90.0:
            continue
        var score = rect.position.y
        if score < best_score:
            best_score = score
            best_y = rect.position.y
    return best_y
