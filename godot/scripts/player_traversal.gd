extends RefCounted
## Wall grip and grappling, phasing through gates, traversal resets, and the follow camera with its room locks.
## Moved out of player_controller.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.
const ABILITY_ART := preload("res://scripts/player_ability_art.gd")
const HOOK_ART := preload("res://scripts/player_hook_art.gd")

static func can_grip_current_wall(player: Node) -> bool:
    for index in range(player.get_slide_collision_count()):
        var contact = player.get_slide_collision(index)
        if absf(contact.get_normal().x) < 0.5:
            continue
        var collider = contact.get_collider()
        if is_instance_valid(collider) and not bool(collider.get_meta("wall_grip_disabled", false)):
            return true
    return false


static func try_start_grapple(player: Node) -> bool:
    if not player.thread_grapple_unlocked or player.grapple_timer > 0.0:
        return false
    var origin = player.global_position + Vector2(0.0, -42.0)
    var aim := Vector2(float(player.facing), 0.0)
    if Input.is_action_pressed("aim_up"):
        aim = Vector2(float(player.facing) * 0.45, -1.0).normalized()
    elif Input.is_action_pressed("aim_down"):
        aim = Vector2(float(player.facing) * 0.45, 1.0).normalized()
    var best: Node2D = null
    var best_score := INF
    for candidate in player.get_tree().get_nodes_in_group("grapple_anchor"):
        if not preload("res://scripts/grapple_path.gd").available(candidate): continue
        var offset: Vector2 = candidate.global_position - origin
        var distance := offset.length()
        if distance < 36.0 or distance > player.grapple_range:
            continue
        var alignment := aim.dot(offset.normalized())
        if alignment < 0.35:
            continue
        if not preload("res://scripts/grapple_path.gd").clear(player, candidate): continue
        var score = distance + (1.0 - alignment) * player.grapple_range
        if preload("res://scripts/grapple_path.gd").preferred(score, candidate, best_score, best):
            best = candidate
            best_score = score
    if best == null:
        return false
    player._clear_action_buffer()
    player.ability_action.emit("echo_hook", player.global_position, (best.global_position - origin).normalized())
    player.grapple_anchor = best
    player.grapple_timer = player.grapple_timeout
    player.grapple_recovery_timer = 0.0
    player.coyote_timer = 0.0
    player.jump_buffer_timer = 0.0
    player.wall_sliding = false
    player.grapple_line = Line2D.new()
    player.grapple_line.name = "TraversalThread"
    player.grapple_line.width = 3.0
    player.grapple_line.default_color = player.THREAD_T1_CORE
    player.grapple_line.z_index = 59
    player.add_child(player.grapple_line)
    player._play(&"hook_throw")
    player._play_sfx("hook_latch", -6.0)
    player._play_sfx("hook_reel", -8.0)
    player.HOOK_ART.attached(player)
    return true


static func update_grapple(player: Node, delta: float) -> void:
    if not is_finite(delta) or delta <= 0.0: return
    if not preload("res://scripts/grapple_path.gd").available(player.grapple_anchor):
        player._stop_grapple()
        return
    var offset = player.grapple_anchor.global_position - (player.global_position + Vector2(0.0, -42.0))
    player.grapple_timer = maxf(0.0, player.grapple_timer - delta)
    if offset.length() <= 36.0 or player.grapple_timer <= 0.0:
        player._stop_grapple(true)
        player.velocity *= 0.35
        return
    # Sweep each physics tick instead of teleporting through solid terrain.
    if offset.length() > player.grapple_range * 1.15 or not preload("res://scripts/grapple_path.gd").clear(player, player.grapple_anchor):
        player._stop_grapple()
        return
    player.velocity = offset.normalized() * minf(player.grapple_speed, maxf(0.0, offset.length() - 30.0) / delta)
    if is_instance_valid(player.grapple_line):
        player.grapple_line.points = PackedVector2Array([player.thread_origin_offset(), player.to_local(player.grapple_anchor.global_position)])


static func thread_origin_offset(player: Node) -> Vector2:
    var anchors: Array = player.pose_thread_anchors.get(String(player.sprite.animation), [])
    if anchors.is_empty(): return Vector2(0,-42)
    var point: Array = anchors[clampi(player.sprite.frame,0,anchors.size()-1)]
    var local := Vector2(float(point[0]),float(point[1])) - Vector2(192,192)
    if player.sprite.flip_h: local.x = -local.x
    return player.to_local(player.sprite.to_global(local + player.sprite.offset))


static func stop_grapple(player: Node, recover: bool = false) -> void:
    HOOK_ART.stopped(player, recover)
    player.grapple_timer = 0.0
    player.grapple_recovery_timer = player.GRAPPLE_RECOVERY_TIME if recover else 0.0
    player.grapple_anchor = null
    if is_instance_valid(player.grapple_line):
        player.grapple_line.queue_free()
    player.grapple_line = null


static func reset_traversal_state(player: Node) -> void:
    player.combat_effect_generation += 1
    if player.is_inside_tree():
        for effect in player.get_tree().get_nodes_in_group("player_combat_effect"):
            if is_instance_valid(effect) and effect.get("owner_player") == player and effect.has_method("cancel"): effect.cancel()
    player.CONTACT_ART.clear_player(player)
    player.ABILITY_ART.clear(player)
    player.HOOK_ART.clear(player)
    player.DASH_ART.clear(player)
    player.HURT_ART.clear(player)
    player.MOVEMENT_ART.clear(player)
    player.GUARD_ART.clear(player)
    player.VISUAL_POLICY.clear_secondary(player)
    player.respawn_reveal_timer = 0.0
    player._set_death_visibility(1.0)
    player.camera_focus.clear_look()
    player._clear_action_buffer()
    player._stop_grapple()
    player._interrupt_heal()
    player.HEAL_ART.clear(player)
    player._stop_phase()
    player.guard_timer = 0.0
    player.guard_cooldown = 0.0
    player.active_skill.clear()
    player.traversal_downstrike_active = false
    player.wall_jump_lock = 0.0
    player.air_jump_available = true
    player.coyote_timer = 0.0
    player.jump_buffer_timer = 0.0
    player.dash_timer = 0.0
    player.dash_cooldown = 0.0
    player.attack_timer = 0.0
    player.attack_cancel_lock = 0.0
    player.land_timer = 0.0
    player.ground_motion_x = 0.0
    player.ground_motion_speed = 0.0
    player.run_cycle_phase = 0.0
    player.ground_turn_time = 0.0
    player.last_ground_direction = 0
    player.wall_sliding = false
    if is_instance_valid(player.attack_shape):
        player.attack_shape.set_deferred("disabled", true)


static func update_phase(player: Node, delta: float) -> void:
    if player.phase_active:
        if not Input.is_action_pressed("lantern_phase") or player.energy <= 0 or player.hurt_timer > 0.0 or player.death_timer > 0.0:
            player._stop_phase()
            return
        player.phase_energy_fraction += delta * 24.0
        var drain := int(player.phase_energy_fraction)
        if drain > 0:
            player.phase_energy_fraction -= drain
            player.gain_energy(-drain)
        player._sync_phase_gates()
        if player._phase_position_clear():
            player.phase_safe_position = player.global_position
    elif player.lantern_phase_unlocked and Input.is_action_pressed("lantern_phase") and player._can_start_action() and player.energy >= 8:
        player.gain_energy(-8)
        player.phase_active = true
        player.phase_energy_fraction = 0.0
        player.phase_safe_position = player.global_position
        player._sync_phase_gates()
        player.ability_action.emit("lantern_phase", player.global_position, Vector2(player.facing, 0))
        player.ABILITY_ART.phase_enter(player)
        player._play_sfx("phase_enter", -8.0)


static func sync_phase_gates(player: Node) -> void:
    for gate in player.get_tree().get_nodes_in_group("phase_gate"):
        if gate is PhysicsBody2D and not player.phase_exceptions.has(gate):
            player.add_collision_exception_with(gate)
            player.phase_exceptions.append(gate)


static func phase_position_clear(player: Node) -> bool:
    var body_shape = player.get_node_or_null("CollisionShape2D") as CollisionShape2D
    if body_shape == null:
        return true
    var query := PhysicsShapeQueryParameters2D.new()
    query.shape = body_shape.shape
    query.transform = body_shape.global_transform
    query.collision_mask = player.collision_mask
    query.exclude = [player.get_rid()]
    for hit in player.get_world_2d().direct_space_state.intersect_shape(query):
        if hit.collider is PhysicsBody2D:
            return false
    return true


static func stop_phase(player: Node) -> void:
    ABILITY_ART.phase_stop(player)
    if player.phase_active and player.is_inside_tree() and not player._phase_position_clear():
        player.global_position = player.phase_safe_position
        player.velocity = Vector2.ZERO
    for gate in player.phase_exceptions:
        if is_instance_valid(gate):
            player.remove_collision_exception_with(gate)
    player.phase_exceptions.clear()
    player.phase_active = false
    player.phase_energy_fraction = 0.0


static func update_camera(player: Node, delta: float) -> void:
    var camera = player.get_node_or_null("Camera2D") as Camera2D
    if camera == null:
        return
    player.room_camera.update(player.camera_focus, player.global_position, delta)
    # Feet remain in view during falls; world-owned limits and zoom are preserved.
    var strength := clampf(float(player._accessibility().get("camera_lookahead", 1.0)), 0.0, 1.0)
    var look_up := Input.is_action_pressed("aim_up")
    var look_down := Input.is_action_pressed("aim_down")
    var direction := 0 if look_up == look_down else (-1 if look_up else 1)
    var eligible = player.is_on_floor() and absf(player.velocity.x) < 12.0 and absf(player._move_axis()) < 0.1 and player.land_timer <= 0.0 and player._can_start_action()
    var observation_strength: float = preload("res://scripts/camera_observation_preferences.gd").strength(player._accessibility(),strength)
    var observation_delay: float = preload("res://scripts/camera_observation_preferences.gd").normalize(player._accessibility()).observation_delay
    var observation: float = player.camera_focus.update(camera, delta, direction, eligible, observation_strength, observation_delay)
    camera.position = player.camera_focus.follow_position(camera, player.global_position, player.velocity, player.is_on_floor(), delta, strength, observation)


static func configure_camera_focus(player: Node, bounds: Rect2) -> void:
    var camera = player.get_node_or_null("Camera2D") as Camera2D
    if camera != null:
        player.camera_focus.configure(camera, bounds)
        player.room_camera.configure([], player.camera_focus)


static func configure_room_camera(player: Node, rooms: Array) -> void:
    player.room_camera.configure(rooms, player.camera_focus)
    player.room_camera.update(player.camera_focus, player.global_position)
    var camera = player.get_node_or_null("Camera2D") as Camera2D
    if camera != null:
        player.camera_focus.apply_limits(camera)


static func push_camera_lock(player: Node, id: String, bounds: Rect2, priority: int = 0, prevent_up: bool = false, prevent_down: bool = false) -> bool:
    var accepted: bool = player.camera_focus.push_lock(id, bounds, priority, prevent_up, prevent_down)
    var camera = player.get_node_or_null("Camera2D") as Camera2D
    if camera != null:
        player.camera_focus.apply_limits(camera)
    return accepted


static func remove_camera_lock(player: Node, id: String) -> void:
    player.camera_focus.remove_lock(id)
    var camera = player.get_node_or_null("Camera2D") as Camera2D
    if camera != null:
        player.camera_focus.apply_limits(camera)
