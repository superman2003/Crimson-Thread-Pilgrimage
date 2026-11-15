extends RefCounted
## Leash and engage windows, attack reach, attack desire and scoring, and reading the player's commands.
## Moved out of enemy_actor.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func patrol(actor: Node, delta: float) -> void:
    if actor.locomotion=="stationary":
        actor._set_enemy_animation("idle")
        return
    # Guards whose leash is tighter than their walk hold their post and look around.
    var walk_range = actor.patrol_distance if actor.leash_radius <= 0.0 else minf(actor.patrol_distance, actor.leash_radius - 50.0)
    if walk_range < 12.0:
        actor._set_enemy_animation("idle")
        if actor.patrol_pause_timer <= 0.0:
            actor.patrol_direction *= -1
            actor.direction = actor.patrol_direction
            actor._set_sprite_flip(actor.direction < 0)
            actor.patrol_pause_timer = actor.ai_rng.randf_range(1.6, 3.2)
        return
    if actor.patrol_pause_timer > 0.0:
        # Stop at the turn, glance back once, then carry on.
        actor._set_enemy_animation("idle")
        if actor.patrol_pause_timer <= delta:
            actor.direction = actor.patrol_direction
            actor._set_sprite_flip(actor.direction < 0)
        return
    actor.direction = actor.patrol_direction
    actor._set_sprite_flip(actor.direction < 0)
    actor.position.x += actor.direction * actor._movement_speed() * 0.72 * delta
    actor._set_enemy_animation("walk")
    var offset = actor.global_position.x - actor.start_x
    if absf(offset) > walk_range and signf(offset) == float(actor.patrol_direction):
        actor.patrol_direction *= -1
        actor.patrol_pause_timer = actor.ai_rng.randf_range(0.5, 1.3)
    actor._clamp_movement_bounds()


static func target_inside_leash(actor: Node, target: CharacterBody2D) -> bool:
    if target == null or actor.is_boss or actor.leash_radius <= 0.0:
        return true
    var target_from_spawn := absf(target.global_position.x - actor.spawn_position.x)
    if target_from_spawn <= actor.leash_radius:
        return true
    var attack_margin := float(actor.ai_profile.get("leash_attack_margin", 42.0))
    return target_from_spawn <= actor.leash_radius + attack_margin and actor._target_in_any_attack_window(target)


static func should_return_to_spawn(actor: Node, target: CharacterBody2D, aggro_range: float) -> bool:
    if actor.is_boss or actor.leash_radius <= 0.0:
        return false
    if absf(actor.global_position.x - actor.spawn_position.x) > actor.leash_radius:
        return true
    if target == null:
        return false
    if actor._target_inside_leash(target) and actor._target_in_any_attack_window(target):
        return false
    var target_near_enemy: bool = actor._target_in_engage_window(target, aggro_range)
    return target_near_enemy and not actor._target_inside_leash(target)


static func return_to_spawn(actor: Node, delta: float) -> void:
    var dx = actor.spawn_position.x - actor.global_position.x
    if absf(dx) <= 5.0:
        actor.global_position = actor.spawn_position
        actor.reset_physics_interpolation()
        actor.direction = 1
        actor._set_sprite_flip(false)
        actor._set_enemy_animation("idle")
        return
    actor.direction = -1 if dx < 0.0 else 1
    actor.position.x += actor.direction * actor._movement_speed() * delta
    actor._clamp_movement_bounds()
    actor._set_sprite_flip(actor.direction < 0)
    actor._set_enemy_animation("walk")


static func target_in_engage_window(actor: Node, target: CharacterBody2D, aggro_range: float) -> bool:
    if target == null:
        return false
    var dx := absf(target.global_position.x - actor.global_position.x)
    var dy := absf(target.global_position.y - actor.global_position.y)
    var vertical_tolerance := float(actor.ai_profile.get("aggro_vertical_tolerance", 190.0 if actor.is_boss else 118.0))
    return dx <= aggro_range and dy <= vertical_tolerance


static func target_in_any_attack_window(actor: Node, target: CharacterBody2D) -> bool:
    if target == null:
        return false
    for command in actor.ai_commands:
        if command is Dictionary and actor._attack_can_reach_target(command, target, true):
            return true
    return false


static func attack_can_reach_target(actor: Node, command: Dictionary, target: CharacterBody2D, ignore_cooldown: bool = false) -> bool:
    if target == null:
        return false
    if int(command.get("phase",1))>actor.battle_phase:
        return false
    var id := String(command.get("id", "attack"))
    if not ignore_cooldown and float(actor.cooldowns.get(id, 0.0)) > 0.0:
        return false
    var dx := absf(target.global_position.x - actor.global_position.x)
    var dy := absf(target.global_position.y - actor.global_position.y)
    var max_range := float(command.get("range", 70.0))
    var min_range := float(command.get("min_range", 0.0))
    return dx <= max_range and dx >= min_range and dy <= actor._command_vertical_tolerance(command)


static func command_vertical_tolerance(actor: Node, command: Dictionary) -> float:
    var fallback := maxf(72.0, float(command.get("hit_height", 58.0)) * 0.95)
    if actor.is_boss:
        fallback = maxf(132.0, float(command.get("hit_height", 110.0)) * 0.98)
    return float(command.get("vertical_tolerance", actor.ai_profile.get("attack_vertical_tolerance", fallback)))


static func max_attack_range(actor: Node, ready_only: bool = false) -> float:
    var result := 0.0
    for command in actor.ai_commands:
        if not (command is Dictionary):
            continue
        var data: Dictionary = command
        if ready_only and float(actor.cooldowns.get(String(data.get("id", "attack")), 0.0)) > 0.0:
            continue
        result = maxf(result, float(data.get("range", 0.0)))
    if result <= 0.0 and ready_only:
        return actor._max_attack_range(false)
    return result


static func attack_desire_threshold(actor: Node) -> float:
    return float(actor.ai_profile.get("attack_desire_threshold", 0.52 if actor.is_boss else 0.68))


static func update_attack_desire(actor: Node, delta: float, target: CharacterBody2D, engaged: bool) -> void:
    if target == null or not engaged:
        actor.attack_desire = maxf(0.0, actor.attack_desire - delta * float(actor.ai_profile.get("attack_desire_decay", 0.78)))
        return
    var aggro_range := maxf(1.0, float(actor.ai_profile.get("aggro_range", 220.0 if not actor.is_boss else 460.0)))
    var dx := absf(target.global_position.x - actor.global_position.x)
    var close_pressure := clampf((aggro_range - dx) / aggro_range, 0.0, 1.0) * 0.72
    var command_pressure: float = actor._player_command_pressure(actor.last_player_command)
    var gain := float(actor.ai_profile.get("attack_desire_gain", 1.12 if actor.is_boss else 0.96))
    var max_desire := float(actor.ai_profile.get("attack_desire_max", 2.4 if actor.is_boss else 1.8))
    actor.attack_desire = clampf(actor.attack_desire + delta * (gain + close_pressure + command_pressure), 0.0, max_desire)


static func player_command_pressure(actor: Node, command: String) -> float:
    if ["slash_forward", "slash_up", "slash_down", "skill"].has(command):
        return 1.10
    if ["dash_toward", "hook"].has(command):
        return 0.88
    if ["heal", "falling_attack"].has(command):
        return 0.72
    if ["jump", "fall", "run_toward"].has(command):
        return 0.28
    return 0.0


static func attack_candidate_score(actor: Node, command: Dictionary, target: CharacterBody2D) -> float:
    var score := float(command.get("priority", 1.0)) * 10.0
    var dx := absf(target.global_position.x - actor.global_position.x)
    var max_range := maxf(1.0, float(command.get("range", 70.0)))
    score += clampf(1.0 - absf(max_range * 0.55 - dx) / max_range, 0.0, 1.0) * 2.2
    # Answer what the player is doing with the attack built for it.
    var airborne = ["jump", "fall", "falling_attack", "slash_up"].has(actor.last_player_command) or target.global_position.y < actor.global_position.y - 70.0
    if airborne and actor._attack_has_role(command, "anti_air"):
        score += 3.0
    if ["slash_forward", "slash_down", "dash_toward", "hook", "skill"].has(actor.last_player_command) and dx < 180.0 and actor._attack_has_role(command, "counter"):
        score += 3.0
    if actor.last_player_command == "heal" and actor._attack_has_role(command, "punish"):
        score += 3.2
    if (["run_away", "dash_away"].has(actor.last_player_command) or dx > max_range * 0.7) and actor._attack_has_role(command, "gap_closer"):
        score += 2.0
    if actor.last_player_command == "idle" and actor._attack_has_role(command, "area"):
        score += 1.0
    if bool(command.get("elite_only", false)):
        score += 1.5
    # Repeating the same move gets steadily less likely, but is never banned.
    if String(command.get("id", "")) == actor.last_attack_id:
        score -= 2.5 * float(1 + actor.attack_repeat_count)
    if String(command.get("boss_pattern",""))=="duel_parry" and not ["slash_forward","slash_up","slash_down","skill","dash_toward"].has(actor.last_player_command):score-=8.0
    return score


static func attack_has_role(actor: Node, command: Dictionary, role: String) -> bool:
    if command.has("roles"):
        return Array(command.roles).has(role)
    if role == "anti_air" and String(command.get("mechanic", "")).contains("截空"):
        return true
    return actor.ATTACK_ROLES.get(role, []).has(String(command.get("type", "melee")))


static func choose_attack(actor: Node, candidates: Array, target: CharacterBody2D) -> Dictionary:
    if candidates.size() == 1:
        return candidates[0]
    var scores: Array[float] = []
    var best := -INF
    for command in candidates:
        var value: float = actor._attack_candidate_score(command, target)
        scores.append(value)
        best = maxf(best, value)
    # Softmax over scores: the best answer usually wins, close seconds still appear.
    var weights: Array[float] = []
    var total := 0.0
    for value in scores:
        var weight = exp((value - best) / 1.4)
        weights.append(weight)
        total += weight
    var roll = actor.ai_rng.randf() * total
    for index in candidates.size():
        roll -= weights[index]
        if roll <= 0.0:
            return candidates[index]
    return candidates.back()


static func count_other_attackers(actor: Node, target: CharacterBody2D) -> int:
    var count := 0
    for node in actor.get_tree().get_nodes_in_group("enemy"):
        if node == actor or not is_instance_valid(node) or bool(node.get("is_boss")):
            continue
        if node.has_method("world_residency_active") and not node.world_residency_active():
            continue
        if not (String(node.get("state")) in ["windup", "active"]):
            continue
        if (node as Node2D).global_position.distance_to(target.global_position) <= actor.ATTACKER_COORDINATION_RADIUS:
            count += 1
    return count


static func is_aware_of(actor: Node, target: CharacterBody2D) -> bool:
    if actor.is_boss or actor.memory_timer > 0.0:
        return true
    if actor.tactical_role == "ambush":
        # A lurking ambusher must not turn toward the player before it reveals.
        var reveal: float = actor._fresh_engage_range(float(actor.ai_profile.get("aggro_range", 220.0)))
        return actor._target_in_engage_window(target, reveal) and actor._has_line_of_sight(target)
    var aggro_range := float(actor.ai_profile.get("aggro_range", 220.0))
    return actor._target_in_engage_window(target, aggro_range * 1.1)


static func lead_target(actor: Node, target: CharacterBody2D, lead_seconds: float, max_lead: float) -> Vector2:
    # Partial lead toward where the player is heading; elites read it better.
    var accuracy = 0.85 if actor.is_elite else 0.6
    var lead = target.velocity * clampf(lead_seconds, 0.0, 1.2) * accuracy
    lead.x = clampf(lead.x, -max_lead, max_lead)
    lead.y = clampf(lead.y, -max_lead * 0.5, max_lead * 0.5)
    return target.global_position + lead - Vector2(0, 42)


static func read_player_command(actor: Node, target: CharacterBody2D) -> String:
    actor.command_read_count += 1
    if actor._float_property(target, "death_timer", 0.0) > 0.0:
        return "dead"
    var attack_timer_value: float = actor._float_property(target, "attack_timer", 0.0)
    if attack_timer_value > 0.0:
        var attack_name := String(target.get("current_attack"))
        var attack_vector: Vector2 = actor._vector2_property(target, "current_attack_direction", Vector2(float(actor._player_facing(target)), 0.0))
        if attack_name == "attack_2":
            return "skill"
        if attack_name == "hook_throw":
            return "hook"
        if attack_vector.y > 0.5:
            return "slash_down"
        if attack_vector.y < -0.5:
            return "slash_up"
        return "slash_forward"
    var velocity_value := target.velocity
    if actor._float_property(target, "dash_timer", 0.0) > 0.0:
        return "dash_toward" if signf(velocity_value.x) == -float(actor.direction) else "dash_away"
    if actor._float_property(target, "heal_timer", 0.0) > 0.0:
        return "heal"
    if velocity_value.y > 180.0 and target.global_position.y < actor.global_position.y - 26.0:
        return "falling_attack"
    if velocity_value.y < -120.0:
        return "jump"
    if velocity_value.y > 140.0:
        return "fall"
    if absf(velocity_value.x) > 120.0:
        return "run_toward" if signf(velocity_value.x) == -float(actor.direction) else "run_away"
    return "idle"


static func player_facing(actor: Node, target: CharacterBody2D) -> int:
    var value := int(actor._float_property(target, "facing", 1.0))
    return -1 if value < 0 else 1


static func float_property(actor: Node, node: Object, key: String, fallback: float) -> float:
    var value = node.get(key)
    if value == null:
        return fallback
    return float(value)


static func vector2_property(actor: Node, node: Object, key: String, fallback: Vector2) -> Vector2:
    var value = node.get(key)
    if typeof(value) == TYPE_VECTOR2:
        return value
    return fallback
