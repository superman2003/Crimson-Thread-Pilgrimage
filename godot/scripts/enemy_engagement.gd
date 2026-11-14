extends RefCounted
## Targeting, line of sight, patrol and aggro, alarms, ally support and spacing while in combat.
## Moved out of enemy_actor.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func target_player(actor: Node) -> CharacterBody2D:
    if actor.lure_timer > 0.0:
        return null
    if actor.interference_timer > 0.0:
        for command in actor.ai_commands:
            if String(command.get("type", "")) in ["projectile", "beam", "throw"]:
                return null
    var nearest: CharacterBody2D = null
    var nearest_distance := INF
    for node in actor.get_tree().get_nodes_in_group("player"):
        var candidate := node as CharacterBody2D
        if candidate == null or not is_instance_valid(candidate):
            continue
        var distance = actor.global_position.distance_to(candidate.global_position)
        if distance < nearest_distance:
            nearest = candidate
            nearest_distance = distance
    return nearest


static func face_target(actor: Node, target: Node2D) -> void:
    if target.global_position.x == actor.global_position.x:
        return
    actor.direction = -1 if target.global_position.x < actor.global_position.x else 1
    actor._set_sprite_flip(actor.direction < 0)


static func has_line_of_sight(actor: Node, target: CollisionObject2D) -> bool:
    if target == null or not is_instance_valid(target) or not actor.is_inside_tree():
        return false
    if actor.get_parent().has_method("_ensure_collision_segment"):
        actor.get_parent()._ensure_collision_segment(actor.global_position + Vector2(0, -24), target.global_position + Vector2(0, -42))
    if actor.get_parent().has_method("_rock_ray_hit") and not actor.get_parent()._rock_ray_hit(actor.global_position + Vector2(0, -24), target.global_position + Vector2(0, -42)).is_empty():
        return false
    # Terrain occupies layer 1; player/enemy hurtboxes must not occlude sight.
    var query = PhysicsRayQueryParameters2D.create(actor.global_position + Vector2(0, -24), target.global_position + Vector2(0, -42), 1)
    query.exclude = [actor.get_rid(), target.get_rid()]
    query.collide_with_areas = false
    return actor.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


static func apply_snare(actor: Node, seconds: float) -> void:
    if is_finite(seconds) and seconds > 0.0 and not actor.dying:
        actor.snare_timer = maxf(actor.snare_timer, minf(seconds, 12.0) * float(actor.combat_resistance.get("snare_mult", 0.35 if actor.is_boss else 1.0)))


static func movement_speed(actor: Node) -> float:
    return 0.0 if actor.trip_timer > 0.0 else actor.speed * ((0.82 if actor.is_boss else 0.5) if actor.snare_timer > 0.0 else 1.0)


static func update_patrol_or_aggro(actor: Node, delta: float, target: CharacterBody2D) -> void:
    if actor.lure_timer > 0.0 and not actor.is_boss:
        var dx = actor.lure_position.x - actor.global_position.x
        var step = signf(dx) * minf(absf(dx), actor._movement_speed() * delta)
        var lure_ray = PhysicsRayQueryParameters2D.create(actor.global_position + Vector2(0,-24), actor.global_position + Vector2(step + signf(dx) * 24,-24), 1)
        lure_ray.collide_with_areas = false
        lure_ray.exclude = actor.ATTACK_EFFECT.player_bodies(actor.get_tree())
        if actor.get_world_2d().direct_space_state.intersect_ray(lure_ray).is_empty():
            actor.global_position.x += step
        return
    var aggro_range := float(actor.ai_profile.get("aggro_range", 220.0 if not actor.is_boss else 460.0))
    var tracking = actor.memory_timer > 0.0
    var engage_range = actor._fresh_engage_range(aggro_range) if not tracking else aggro_range
    var engaged = target != null and actor._target_inside_leash(target) and actor._target_in_engage_window(target, engage_range) and actor._has_line_of_sight(target)
    if engaged and not actor.engage_announced:
        actor._announce_engagement()
    actor._update_attack_desire(delta, target, engaged)
    if engaged or actor.memory_timer <= 0.0:
        actor.alarm_search = false
    # While answering a call, only leaving the territory sends an ally home; the
    # player's own position (outside this leash) must not cancel the search.
    if actor._should_return_to_spawn(null if actor.alarm_search else target, aggro_range):
        actor.last_ai_decision = "return"
        actor._return_to_spawn(delta)
        return
    if engaged:
        if not tracking and actor.tactical_role == "ambush":
            actor._role_cue("ambush_reveal")
            actor.reveal_hold = actor.AMBUSH_REVEAL_HOLD
        if not tracking and actor.tactical_role == "alarm" and actor.alarm_cooldown <= 0.0:
            actor._raise_alarm(target)
        actor.last_seen_position = target.global_position
        actor.memory_timer = actor.TARGET_MEMORY_SECONDS
        if actor.reveal_hold > 0.0:
            # The reveal itself is the tell: face the player, then act.
            actor.last_ai_decision = "ambush:reveal"
            actor._face_target(target)
            actor._set_enemy_animation("idle")
            return
        if actor._boss_behavior_enabled():
            actor._ensure_boss_brain()
            actor.boss_brain.step(delta,target)
            return
        if actor.is_boss and actor.boss_brain != null and actor.ai_commands.is_empty():
            actor.boss_brain.reset_plan(false)
            return
        if actor._try_start_support():
            return
        if actor._try_start_attack(target):
            return
        actor._move_in_combat(delta, target)
        return
    if actor.boss_brain != null:actor.boss_brain.reset_plan()
    actor.waiting_for_turn = false
    if actor.memory_timer > 0.0 and not actor.is_boss:
        if actor.tactical_role == "guard":
            # A guard does not leave its post to search; it resumes watch.
            actor._return_to_post(delta, "hold_post")
            return
        actor._investigate(delta)
        return
    if actor.tactical_role == "ambush":
        actor._return_to_post(delta, "lurk")
        return
    if actor.tactical_role == "guard":
        actor._return_to_post(delta, "hold_post")
        return
    actor.last_ai_decision = "patrol"
    actor._patrol(delta)


static func fresh_engage_range(actor: Node, aggro_range: float) -> float:
    if actor.tactical_role != "ambush":
        return aggro_range
    return minf(aggro_range, float(actor.ai_profile.get("ambush_trigger_range", actor.AMBUSH_TRIGGER_RANGE)))


static func return_to_post(actor: Node, delta: float, waiting_decision: String) -> void:
    var dx = actor.spawn_position.x - actor.global_position.x
    if actor.locomotion == "stationary" or absf(dx) <= 6.0:
        actor.last_ai_decision = waiting_decision
        actor._set_enemy_animation("idle")
        return
    actor.last_ai_decision = "return_post"
    actor.direction = -1 if dx < 0.0 else 1
    actor._set_sprite_flip(actor.direction < 0)
    actor.position.x += actor.direction * minf(absf(dx), actor._movement_speed() * 0.6 * delta)
    actor._clamp_movement_bounds()
    actor._set_enemy_animation("walk")


static func raise_alarm(actor: Node, target: CharacterBody2D) -> void:
    actor.alarm_cooldown = actor.ALARM_COOLDOWN
    actor.alarm_alerted = 0
    actor._role_cue("alarm_call")
    for node in actor.get_tree().get_nodes_in_group("enemy"):
        if node == actor or not is_instance_valid(node) or node.is_queued_for_deletion() or not node.has_method("hear_alarm"):
            continue
        if node.has_method("world_residency_active") and not node.world_residency_active():
            continue
        if (node as Node2D).global_position.distance_to(actor.global_position) > actor.ALARM_RADIUS:
            continue
        if node.hear_alarm(target.global_position):
            actor.alarm_alerted += 1


static func hear_alarm(actor: Node, seen_at: Vector2) -> bool:
    if actor.is_boss or actor.dying or actor.memory_timer > 0.0 or actor._is_attack_state():
        return false
    # Search toward the call, but only to the edge of this actor's own territory.
    actor.last_seen_position = seen_at
    if actor.leash_radius > 0.0:
        var reach := maxf(0.0, actor.leash_radius - 20.0)
        actor.last_seen_position.x = clampf(seen_at.x, actor.spawn_position.x - reach, actor.spawn_position.x + reach)
    actor.memory_timer = actor.TARGET_MEMORY_SECONDS
    actor.alarm_search = true
    return true


static func can_receive_support(actor: Node) -> bool:
    return not actor.is_boss and actor.tactical_role != "support" and not actor.dying and not actor.is_queued_for_deletion() and actor.world_residency_active() and actor.hp > 0 and actor.hp < actor.max_hp


static func support_ally_valid(actor: Node, ally: Area2D) -> bool:
    return ally != null and ally != actor and ally.get_parent() == actor.get_parent() and ally.get_meta("optional_challenge_id", "") == actor.get_meta("optional_challenge_id", "") and ally.has_method("_can_receive_support") and ally._can_receive_support() and actor.global_position.distance_to(ally.global_position) <= actor.SUPPORT_RADIUS and absf(actor.global_position.y - ally.global_position.y) <= 90.0 and actor._has_line_of_sight(ally)


static func try_start_support(actor: Node) -> bool:
    if actor.tactical_role != "support" or actor.is_boss or actor.support_cooldown > 0.0 or actor.trip_timer > 0.0 or actor.lure_timer > 0.0 or actor.interference_timer > 0.0:
        return false
    var chosen: Area2D
    var lowest_health := 1.0
    var nearest := INF
    for node in actor.get_tree().get_nodes_in_group("enemy"):
        var ally := node as Area2D
        if not actor._support_ally_valid(ally): continue
        var health := float(ally.hp) / float(ally.max_hp)
        var distance = actor.global_position.distance_squared_to(ally.global_position)
        if health < lowest_health or (is_equal_approx(health, lowest_health) and distance < nearest):
            chosen = ally
            lowest_health = health
            nearest = distance
    if chosen == null: return false
    actor._clear_telegraph()
    actor.support_target = weakref(chosen)
    actor.support_cooldown = actor.SUPPORT_COOLDOWN  # interruptions still spend the attempt
    actor.state = "support"
    actor.state_timer = actor.SUPPORT_WINDUP
    actor.last_ai_decision = "support:windup"
    actor.waiting_for_turn = false
    # Directional clips read attack_direction while channeling; face the ally.
    actor._face_target(chosen)
    actor.attack_direction = actor.direction
    actor._set_enemy_animation("attack", true)
    actor._pose_sprite("windup")
    actor._fit_animation_duration(actor.SUPPORT_WINDUP)
    actor._role_cue("support_mend")
    if actor.MINOR_SKILL_ART.start_support(actor): return true
    var link := Line2D.new()
    link.name = "EnemySupportLink"
    link.width = 2.0
    link.default_color = Color(0.48, 0.88, 0.75, 0.9)
    actor.VISUAL_POLICY.place_danger(link, true)
    actor.add_child(link)
    actor.windup_vfx = link
    actor._update_support_link(chosen)
    return true


static func update_support_link(actor: Node, ally: Area2D) -> void:
    if actor.windup_vfx == null or not is_instance_valid(actor.windup_vfx): return
    var end = actor.to_local(ally.global_position + Vector2(0, -54))
    (actor.windup_vfx as Line2D).points = PackedVector2Array([Vector2(0, -48), end, end + Vector2(-8, 0), end + Vector2(0, -10), end + Vector2(8, 0), end + Vector2(0, 10), end])


static func update_support(actor: Node, delta: float, target: CharacterBody2D) -> void:
    var ally = actor.support_target.get_ref() as Area2D if actor.support_target != null else null
    var aggro_range := float(actor.ai_profile.get("aggro_range", 300.0))
    if not actor._support_ally_valid(ally) or target == null or not actor._target_inside_leash(target) or not actor._target_in_engage_window(target, aggro_range) or not actor._has_line_of_sight(target) or actor.lure_timer > 0.0 or actor.interference_timer > 0.0 or actor.trip_timer > 0.0:
        actor._finish_support()
        return
    actor._update_support_link(ally)
    actor.state_timer -= delta
    if actor.state_timer <= 0.0:
        ally.hp = mini(ally.max_hp, ally.hp + 1)
        actor.MINOR_SKILL_ART.release_support(actor,ally)
        actor._finish_support()


static func finish_support(actor: Node) -> void:
    actor._clear_telegraph()
    actor.state = "recover"
    actor.state_timer = 0.55
    actor.last_ai_decision = "support:recover"
    actor._pose_sprite("recover")


static func investigate(actor: Node, delta: float) -> void:
    # Lost sight: walk to where the player was last seen, then look around.
    actor.last_ai_decision = "investigate"
    var dx = actor.last_seen_position.x - actor.global_position.x
    var limit_ok = actor.leash_radius <= 0.0 or absf(actor.last_seen_position.x - actor.spawn_position.x) <= actor.leash_radius
    if actor.locomotion == "stationary" or absf(dx) <= 14.0 or not limit_ok:
        actor._set_enemy_animation("idle")
        if fposmod(actor.ai_clock, 0.9) < delta:
            actor.direction *= -1
            actor._set_sprite_flip(actor.direction < 0)
        return
    actor.direction = -1 if dx < 0.0 else 1
    actor._set_sprite_flip(actor.direction < 0)
    actor.position.x += actor.direction * actor._movement_speed() * 0.85 * delta
    actor._clamp_movement_bounds()
    actor._set_enemy_animation("walk")


static func move_in_combat(actor: Node, delta: float, target: CharacterBody2D) -> void:
    if actor.locomotion == "stationary":
        actor.last_ai_decision="hold_position"
        actor._set_enemy_animation("idle")
        return
    if actor._boss_tactical_enabled():
        actor._move_boss_tactical(delta, target)
        return
    var preferred := float(actor.ai_profile.get("preferred_range", 54.0))
    var dx = target.global_position.x - actor.global_position.x
    var distance := absf(dx)
    var moved := false
    var attack_range: float = actor._max_attack_range(false)
    var pressure_threshold: float = actor._attack_desire_threshold()
    var pressured = actor.attack_desire >= pressure_threshold * 0.65
    var desired := preferred
    if pressured and attack_range > 0.0:
        desired = minf(preferred, maxf(34.0, attack_range * 0.70))
    if actor.waiting_for_turn:
        # Circle just outside the player's reach until an attacker slot frees.
        desired = maxf(desired, 150.0)
        pressured = false
    desired += actor._ally_queue_offset(target)
    var chase_speed: float = actor._movement_speed() * (float(actor.ai_profile.get("pressure_speed_multiplier", 1.18)) if pressured else 1.0)
    var movement_direction := 0.0
    if attack_range > 0.0 and distance > attack_range - 10.0 and distance > desired + 14.0:
        movement_direction = signf(dx)
        actor.position.x += movement_direction * chase_speed * delta
        moved = true
        actor.last_ai_decision = "press"
    elif distance > desired + 14.0:
        movement_direction = signf(dx)
        actor.position.x += movement_direction * chase_speed * delta
        moved = true
        actor.last_ai_decision = "advance"
    elif distance < desired - 18.0 and (not pressured or (not actor.is_boss and preferred >= 120.0)):
        # Ordinary profiles authored with a long preferred_range (ranged/air
        # roles) keep their standoff under pressure. Boss spacing remains on
        # its original pressure-forward rule.
        movement_direction = -signf(dx)
        actor.position.x += movement_direction * actor._movement_speed() * 0.55 * delta
        moved = true
        actor.last_ai_decision = "space"
    else:
        actor.last_ai_decision = "threaten"
    if moved and movement_direction != 0.0:
        actor.direction = -1 if movement_direction < 0.0 else 1
        actor._set_sprite_flip(actor.direction < 0)
    elif target != null:
        actor._face_target(target)
    actor._clamp_movement_bounds()
    actor._set_enemy_animation("walk" if moved else "idle")


static func ally_queue_offset(actor: Node, target: CharacterBody2D) -> float:
    # A ground ally already closer on the same side: hang back instead of stacking.
    if actor.is_boss or actor.locomotion != "ground":
        return 0.0
    var my_side = signf(actor.global_position.x - target.global_position.x)
    var my_distance := absf(actor.global_position.x - target.global_position.x)
    for node in actor.get_tree().get_nodes_in_group("enemy"):
        if node == actor or not is_instance_valid(node) or bool(node.get("is_boss")) or String(node.get("locomotion")) != "ground":
            continue
        var other := node as Node2D
        var other_distance := absf(other.global_position.x - target.global_position.x)
        if signf(other.global_position.x - target.global_position.x) == my_side and other_distance < my_distance and my_distance - other_distance < 70.0 and absf(other.global_position.y - actor.global_position.y) < 60.0:
            return 60.0
    return 0.0
