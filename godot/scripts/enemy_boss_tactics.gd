extends RefCounted
## How a boss picks, times and carries out its arena tactics: spacing, repositioning and evading player commands.
## Moved out of enemy_actor.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func boss_tactical_enabled(actor: Node) -> bool:
    return actor.is_boss and bool(actor.ai_profile.get("tactical_ai", true))


static func move_boss_tactical(actor: Node, delta: float, target: CharacterBody2D) -> void:
    var dx = target.global_position.x - actor.global_position.x
    var distance := absf(dx)
    actor._prepare_boss_tactic(target, distance)
    var moved := false
    var movement_direction := 0.0
    var move_multiplier := 1.0
    match actor.boss_tactic:
        "press":
            movement_direction = signf(dx)
            move_multiplier = float(actor.ai_profile.get("pressure_speed_multiplier", 1.08))
            actor.boss_press_timer += delta
            actor.last_ai_decision = "tactic:press"
        "evade":
            movement_direction = -signf(dx)
            move_multiplier = float(actor.ai_profile.get("evade_speed_multiplier", 1.18))
            actor.boss_press_timer = maxf(0.0, actor.boss_press_timer - delta * 1.4)
            actor.last_ai_decision = "tactic:evade"
        "reposition":
            var reposition_dx = actor.boss_reposition_target_x - actor.global_position.x
            if absf(reposition_dx) > 8.0:
                movement_direction = signf(reposition_dx)
                move_multiplier = float(actor.ai_profile.get("reposition_speed_multiplier", 1.04))
            actor.last_ai_decision = "tactic:reposition"
        "space":
            movement_direction = actor._boss_spacing_direction(distance, dx)
            move_multiplier = float(actor.ai_profile.get("spacing_speed_multiplier", 0.72))
            actor.boss_press_timer = maxf(0.0, actor.boss_press_timer - delta)
            actor.last_ai_decision = "tactic:space"
        "guard":
            actor.boss_press_timer = maxf(0.0, actor.boss_press_timer - delta * 0.55)
            actor.last_ai_decision = "tactic:guard"
        _:
            actor.boss_press_timer = maxf(0.0, actor.boss_press_timer - delta * 0.45)
            actor.last_ai_decision = "tactic:observe"
    if movement_direction != 0.0:
        actor.position.x += movement_direction * actor._movement_speed() * move_multiplier * delta
        moved = true
    actor._clamp_movement_bounds()
    if moved:
        actor.direction = -1 if movement_direction < 0.0 else 1
        actor._set_sprite_flip(actor.direction < 0)
    elif target != null:
        actor._face_target(target)
    actor._set_enemy_animation("walk" if moved else "idle")


static func prepare_boss_tactic(actor: Node, target: CharacterBody2D, distance: float = -1.0) -> void:
    if target == null:
        actor.boss_tactic = "observe"
        actor.boss_tactic_timer = 0.0
        return
    var measured_distance := distance
    if measured_distance < 0.0:
        measured_distance = absf(target.global_position.x - actor.global_position.x)
    if actor.boss_tactic_timer <= 0.0 or actor._boss_tactic_finished(target, measured_distance):
        actor._choose_boss_tactic(target, measured_distance)


static func boss_tactic_finished(actor: Node, target: CharacterBody2D, distance: float) -> bool:
    var preferred := float(actor.ai_profile.get("preferred_range", 118.0))
    var close_range := float(actor.ai_profile.get("close_range", maxf(56.0, preferred * 0.62)))
    if actor.boss_tactic == "press":
        return distance <= preferred * 0.92 or actor.boss_press_timer >= float(actor.ai_profile.get("max_press_time", 1.25))
    if actor.boss_tactic == "evade":
        return distance >= preferred * 1.22 or actor._boss_at_arena_edge()
    if actor.boss_tactic == "reposition":
        return absf(actor.global_position.x - actor.boss_reposition_target_x) <= 10.0
    if actor.boss_tactic == "space":
        return distance >= close_range and distance <= preferred * 1.18
    return false


static func choose_boss_tactic(actor: Node, target: CharacterBody2D, distance: float) -> void:
    var preferred := float(actor.ai_profile.get("preferred_range", 118.0))
    var attack_range: float = actor._max_attack_range(false)
    var ready_range: float = actor._max_attack_range(true)
    var close_range := float(actor.ai_profile.get("close_range", maxf(56.0, preferred * 0.62)))
    var pressure: float = actor._player_command_pressure(actor.last_player_command)
    var threshold: float = actor._attack_desire_threshold()
    if distance <= close_range or actor._boss_should_evade_player_command(pressure):
        actor._set_boss_tactic("evade", actor._boss_tactic_duration("evade", 0.42), target)
        return
    if actor.last_player_command == "heal" or actor.last_player_command == "run_away":
        actor._set_boss_tactic("press", actor._boss_tactic_duration("press", 0.72), target)
        return
    if actor.boss_press_timer >= float(actor.ai_profile.get("max_press_time", 1.25)):
        actor._set_boss_tactic("reposition", actor._boss_tactic_duration("reposition", 0.82), target)
        return
    if ready_range > 0.0 and distance > ready_range * 0.92:
        actor._set_boss_tactic("press", actor._boss_tactic_duration("press", 0.86), target)
        return
    if attack_range > 0.0 and distance > attack_range * 0.82:
        actor._set_boss_tactic("press", actor._boss_tactic_duration("press", 0.70), target)
        return
    if actor._boss_should_reposition(target, distance):
        actor._set_boss_tactic("reposition", actor._boss_tactic_duration("reposition", 0.78), target)
        return
    if actor.attack_desire < threshold * 0.66:
        actor._set_boss_tactic("observe", actor._boss_tactic_duration("observe", 0.34), target)
        return
    if distance < preferred * 0.92 or distance > preferred * 1.22:
        actor._set_boss_tactic("space", actor._boss_tactic_duration("space", 0.48), target)
        return
    actor._set_boss_tactic("guard", actor._boss_tactic_duration("guard", 0.36), target)


static func set_boss_tactic(actor: Node, next_tactic: String, duration: float, target: CharacterBody2D) -> void:
    actor.boss_tactic = next_tactic
    actor.boss_tactic_timer = maxf(0.08, duration)
    if actor.boss_tactic == "reposition":
        actor.boss_reposition_target_x = actor._boss_reposition_x(target)


static func boss_tactic_duration(actor: Node, tactic: String, fallback: float) -> float:
    var durations: Dictionary = actor.ai_profile.get("tactic_durations", {})
    return float(durations.get(tactic, actor.ai_profile.get(tactic + "_time", fallback)))


static func boss_should_evade_player_command(actor: Node, pressure: float) -> bool:
    if pressure < 1.0:
        return false
    return ["slash_forward", "slash_up", "slash_down", "dash_toward", "hook"].has(actor.last_player_command)


static func boss_should_reposition(actor: Node, target: CharacterBody2D, distance: float) -> bool:
    if not actor._boss_has_arena_bounds():
        return false
    var edge_margin := float(actor.ai_profile.get("arena_edge_margin", 150.0))
    if actor.global_position.x - actor._boss_min_x() < edge_margin or actor._boss_max_x() - actor.global_position.x < edge_margin:
        return true
    var preferred := float(actor.ai_profile.get("preferred_range", 118.0))
    return distance < preferred * 1.05 and actor.attack_desire >= actor._attack_desire_threshold() * 0.82 and actor.boss_tactic == "guard"


static func boss_spacing_direction(actor: Node, distance: float, dx: float) -> float:
    var preferred := float(actor.ai_profile.get("preferred_range", 118.0))
    if distance < preferred * 0.92:
        return -signf(dx)
    if distance > preferred * 1.22:
        return signf(dx)
    return 0.0


static func boss_reposition_x(actor: Node, target: CharacterBody2D) -> float:
    var min_x: float = actor._boss_min_x()
    var max_x: float = actor._boss_max_x()
    var margin := float(actor.ai_profile.get("arena_edge_margin", 150.0))
    if min_x >= max_x:
        return actor.spawn_position.x
    var midpoint = (min_x + max_x) * 0.5
    var desired = max_x - margin if target.global_position.x < midpoint else min_x + margin
    if absf(desired - actor.global_position.x) < margin * 0.75:
        desired = min_x + margin if desired > midpoint else max_x - margin
    return clampf(desired, min_x + 36.0, max_x - 36.0)


static func boss_has_arena_bounds(actor: Node) -> bool:
    return actor._boss_min_x() < actor._boss_max_x()


static func boss_min_x(actor: Node) -> float:
    if actor.arena_min_x < actor.arena_max_x:
        return actor.arena_min_x
    if actor.platform_min_x < actor.platform_max_x:
        return actor.platform_min_x
    return actor.spawn_position.x - 520.0


static func boss_max_x(actor: Node) -> float:
    if actor.arena_min_x < actor.arena_max_x:
        return actor.arena_max_x
    if actor.platform_min_x < actor.platform_max_x:
        return actor.platform_max_x
    return actor.spawn_position.x + 520.0


static func boss_at_arena_edge(actor: Node) -> bool:
    if not actor._boss_has_arena_bounds():
        return false
    var edge_margin := float(actor.ai_profile.get("arena_edge_margin", 150.0)) * 0.55
    return actor.global_position.x - actor._boss_min_x() <= edge_margin or actor._boss_max_x() - actor.global_position.x <= edge_margin
