extends RefCounted
## Choosing and posing the player's animation: ground motion, run pose, sprite anchor and attack poses.
## Moved out of player_controller.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func update_ground_motion(player: Node, delta: float, platform_motion: Vector2 = Vector2.ZERO) -> void:
    player.ground_turn_time = maxf(0.0, player.ground_turn_time - delta)
    player.ground_motion_x = 0.0
    player.ground_motion_speed = 0.0
    if not player.is_on_floor() or delta <= 0.0:
        player.ground_turn_time = 0.0
        player.last_ground_direction = 0
        return
    # get_position_delta excludes teleports/room handoffs before move_and_slide.
    # Subtract carrier travel so standing on a lift does not make the legs run.
    player.ground_motion_x = player.get_position_delta().x - platform_motion.x
    player.ground_motion_speed = absf(player.ground_motion_x) / delta
    if player.ground_motion_speed <= player.GROUND_MOTION_EPSILON:
        player.ground_motion_x = 0.0
        player.ground_motion_speed = 0.0
        return
    var travel_direction: int = player.signi(player.ground_motion_x)
    if player.last_ground_direction != 0 and travel_direction != player.last_ground_direction and player.ground_motion_speed < player.speed * .6 and player._can_start_action() and player._has_pose(&"turn"):
        player.ground_turn_from = player.last_ground_direction
        player.ground_turn_time = player.GROUND_TURN_DURATION
    player.last_ground_direction = travel_direction
    # The run pose is driven by this phase; its two foot contacts are poses 0
    # (left) and the half cycle (right). Count crossings for the footstep sound.
    var half_cycles = player.run_cycle_phase * 2.0 + absf(player.ground_motion_x) / player.RUN_CYCLE_DISTANCE * 2.0
    player.footstep_contacts += int(floor(half_cycles)) - int(floor(player.run_cycle_phase * 2.0))
    player.run_cycle_phase = fposmod(player.run_cycle_phase + absf(player.ground_motion_x) / player.RUN_CYCLE_DISTANCE, 1.0)


static func pose_ground_run(player: Node) -> void:
    player._play(&"run")
    player.sprite.pause()
    var count = player.sprite.sprite_frames.get_frame_count(&"run")
    var phase = player.run_cycle_phase * count
    player.sprite.set_frame_and_progress(clampi(int(phase), 0, count - 1), fposmod(phase, 1.0))
    # Gameplay facing still responds immediately to input/queued attacks.
    # Only the walking silhouette waits for actual motion to reverse, avoiding
    # backwards skating during the existing acceleration/deceleration curve.
    player.sprite.flip_h = player.ground_motion_x < 0.0
    player._sync_sprite_pose_anchor()


static func sync_sprite_pose_anchor(player: Node) -> void:
    player.sprite.offset = Vector2.ZERO
    if player.sprite.animation == &"idle" and player.sprite.frame < player.idle_foot_centers.size():
        var correction: float = float(player.idle_foot_centers[0]) - float(player.idle_foot_centers[player.sprite.frame])
        player.sprite.offset.x = correction * (-1.0 if player.sprite.flip_h else 1.0)
    elif player.grounded_pose_foot_centers.has(String(player.sprite.animation)):
        var centers: Array = player.grounded_pose_foot_centers[String(player.sprite.animation)]
        if player.sprite.frame < centers.size():
            var correction: float = float(player.idle_foot_centers[0]) - float(centers[player.sprite.frame])
            player.sprite.offset.x = correction * (-1.0 if player.sprite.flip_h else 1.0)
    if is_instance_valid(player.layered_idle):
        player.layered_idle.sync_pose()
    if is_instance_valid(player.grounded_run):
        var floor_normal = player.get_floor_normal() if player.is_on_floor() else Vector2.UP
        # Pressed into a wall at a ledge corner the floor normal can lean 45°;
        # the leg rig only reaches on the gentle slopes it was authored for.
        var slope := clampf(-floor_normal.x / minf(floor_normal.y, -0.01), -player.RUN_RIG_MAX_SLOPE, player.RUN_RIG_MAX_SLOPE)
        player.grounded_run.sync(player.run_cycle_phase, slope * (-1.0 if player.sprite.flip_h else 1.0))


static func update_animation(player: Node, _input_axis: float) -> void:
    player.sprite.flip_h = player.facing < 0
    if not player.is_on_floor() or not player._can_start_action():
        player.ground_turn_time = 0.0
    if player.hurt_timer > 0.0:
        player._play(&"hurt")
    elif player.heal_timer > 0.0:
        player._pose_progress(&"heal", 1.0 - player.heal_timer / maxf(player.heal_duration, 0.01))
    elif player.guard_timer > 0.0:
        player._pose_progress(&"guard", 1.0 - player.guard_timer / maxf(player.guard_initial_duration, 0.01))
    elif player.attack_timer > 0.0:
        player._update_attack_pose()
    elif player.grapple_timer > 0.0:
        # Hold the pull pose; do not replay release every 0.4 seconds.
        var elapsed = player.grapple_timeout - player.grapple_timer
        player._pose_progress(&"hook_throw", 0.25 if elapsed < 0.05 else 0.5)
    elif player.dash_timer > 0.0:
        player._pose_progress(&"dash", 1.0 - player.dash_timer / maxf(player.dash_time, 0.01))
    elif player.wall_sliding and not player.is_on_floor():
        player._play(&"wall_slide")
    elif player.phase_active:
        player._play(&"phase")
    elif player.grapple_recovery_timer > 0.0:
        player._pose_progress(&"hook_throw", 0.75)
    elif not player.is_on_floor():
        if player.velocity.y < 0.0 and player.sprite.animation == &"jump_start" and player.sprite.is_playing():
            return # Preserve takeoff instead of replacing it on the same tick.
        var air_pose: StringName = &"jump_loop" if player.velocity.y < 0.0 else &"fall"
        if player.sprite.animation != air_pose:
            player._play(air_pose, true)
        # The four authored air cels settle into their terminal pose. Replaying
        # the first tuck/extension on every loop creates a visible knee snap.
    elif player.ground_turn_time > 0.0:
        player._pose_progress(&"turn", 1.0 - player.ground_turn_time / player.GROUND_TURN_DURATION)
        player.sprite.flip_h = player.ground_turn_from < 0
    elif player.ground_motion_speed > player.GROUND_MOTION_EPSILON:
        player._pose_ground_run()
    elif player.land_timer > 0.0:
        player._pose_progress(&"land", 1.0 - player.land_timer / 0.14)
    else:
        player._play(&"idle")
    player._sync_sprite_pose_anchor()


static func play(player: Node, name: StringName, restart: bool = false) -> void:
    if player.sprite.sprite_frames == null or not player.sprite.sprite_frames.has_animation(name):
        return
    if restart:
        player.sprite.stop()
    if player.sprite.animation != name or not player.sprite.is_playing() or restart:
        player.sprite.play(name)
    player._sync_sprite_pose_anchor()


static func has_pose(player: Node, name: StringName) -> bool:
    return player.sprite != null and player.sprite.sprite_frames != null and player.sprite.sprite_frames.has_animation(name)


static func pose_progress(player: Node, name: StringName, progress: float) -> void:
    if not player.sprite.sprite_frames.has_animation(name):
        return
    player._play(name)
    player.sprite.pause()
    var count = player.sprite.sprite_frames.get_frame_count(name)
    player.sprite.set_frame_and_progress(clampi(int(progress * count), 0, count - 1), 0.0)


static func update_attack_pose(player: Node) -> void:
    var animation = player.current_attack
    var kind := String(player.active_skill.get("kind", ""))
    if kind == "tool": animation = &"item_use"
    elif kind == "resonance": animation = &"resonance"
    elif not player.active_skill.is_empty():
        if kind == "ranged": animation = &"skill_projectile"
        elif kind == "defense": animation = &"skill_defense"
        elif String(player.active_skill.get("id", "")) == "shockwave": animation = &"skill_wave"
        elif kind == "control": animation = &"skill_control"
        else: animation = &"skill_melee"
    elif player.current_attack != &"hook_throw":
        if player.current_attack_direction.y > 0.5:
            animation = &"ground_down_attack" if player.attack_started_grounded and player._has_pose(&"ground_down_attack") else &"down_attack"
        elif player.current_attack_direction.y < -0.5 and player._has_pose(&"up_attack"):
            animation = &"up_attack" if player.attack_started_grounded or not player._has_pose(&"air_up_attack") else &"air_up_attack"
        elif not player.is_on_floor(): animation = &"air_attack"
        elif player.run_attack_pose and player.current_attack == &"attack_1": animation = &"run_attack"
    var elapsed = player.attack_duration - player.attack_timer
    var progress := 0.0
    if kind == "tool":
        progress = elapsed / maxf(player.attack_duration, 0.01)
    elif player._has_pose(animation) and player.sprite.sprite_frames.get_frame_count(animation) >= 6:
        # Six authored cels: two each for wind-up, slash and recovery, so no
        # single pose is held through the whole damage window.
        var recovery_start = player.attack_windup + player.attack_active_time
        if elapsed < player.attack_windup:
            progress = elapsed / maxf(player.attack_windup, 0.01) / 3.0
        elif elapsed <= recovery_start:
            progress = (1.0 + (elapsed - player.attack_windup) / maxf(player.attack_active_time, 0.01)) / 3.0
        else:
            progress = (2.0 + (elapsed - recovery_start) / maxf(player.attack_duration - recovery_start, 0.01)) / 3.0
    elif elapsed < player.attack_windup:
        progress = 0.5 * elapsed / maxf(player.attack_windup, 0.01)
    elif elapsed <= player.attack_windup + player.attack_active_time:
        progress = 0.25 if player.current_attack == &"hook_throw" else 0.5
    else:
        progress = 0.75
    player._pose_progress(animation, progress)
