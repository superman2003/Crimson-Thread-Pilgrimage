extends RefCounted
## Sampling and consuming buffered action input, attack recovery cancels, dashing and thread balance.
## Moved out of player_controller.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func play_attack_swing_sfx(player: Node) -> void:
    var variant_keys := ["attack_v1", "attack_v2", "attack_v3"]
    var key: String = variant_keys[player.attack_sample_index % variant_keys.size()]
    player.attack_sample_index = (player.attack_sample_index + 1) % variant_keys.size()
    if not FileAccess.file_exists(String(player.SFX.get(key, ""))):
        key = "attack"
    player._play_sfx(key, -5.0, randf_range(0.96, 1.04), "player_attack")


static func clear_action_buffer(player: Node) -> void:
    player.buffered_action = &""
    player.action_buffer_timer = 0.0
    player.buffered_direction = Vector2.ZERO


static func sample_action_input(player: Node, delta: float) -> void:
    player.action_buffer_timer = maxf(0.0, player.action_buffer_timer - delta)
    if player.action_buffer_timer <= 0.0:
        player._clear_action_buffer()
    # Latest command replaces the pending command; holding never repeats it.
    # Preserve the existing dash priority when both buttons arrive in one tick.
    var resumed: bool = player.has_method("_just_resumed_from_pause") and bool(player.call("_just_resumed_from_pause"))
    var action: StringName = &""
    if not resumed and Input.is_action_just_pressed("dash") and player.dash_unlocked:
        action = &"dash"
    elif Input.is_action_just_pressed("attack"):
        action = &"attack"
    elif Input.is_action_just_pressed("hook"):
        # C01: a hook pressed during a swing, its owed recovery or a dash waits
        # like the nail does instead of being dropped.
        action = &"hook"
    if action == &"":
        return
    player.buffered_action = action
    player.action_buffer_timer = player.action_buffer_time
    if action == &"attack":
        player.buffered_direction = player._read_attack_direction()
    else:
        var axis: float = player._move_axis()
        player.buffered_direction = Vector2(signf(axis) if absf(axis) > 0.1 else float(player.facing), 0.0)


static func consume_action_input(player: Node, action: StringName) -> bool:
    if player.buffered_action != action:
        return false
    var dash := action == &"dash"
    if not dash and player.attack_cancel_lock > 0.0:
        # The buffered swing or hook waits out the cut recovery instead of being
        # lost, even when that recovery is longer than the input buffer and the
        # dash that cut it is still running.
        player.action_buffer_timer = maxf(player.action_buffer_timer, player.attack_cancel_lock + 0.05)
    if not player._can_start_action(dash, dash):
        return false
    if dash and (not player.dash_unlocked or player.dash_cooldown > 0.0):
        return false
    if not dash and player.attack_cancel_lock > 0.0:
        return false
    var direction = player.buffered_direction
    # Consume before any signal/callback can re-enter action handling.
    player._clear_action_buffer()
    if absf(direction.x) > 0.1:
        player.facing = player.signi(direction.x)
        player.sprite.flip_h = player.facing < 0
    if action == &"attack":
        player._start_attack(&"attack_1", true, direction)
    elif action == &"hook":
        if not player._try_start_grapple():
            player._start_attack(&"hook_throw")
    else:
        cancel_attack_recovery(player)
        player._start_dash()
    return true


static func attack_recovery_cancelable(player: Node) -> bool:
    if player.attack_timer <= 0.0 or not player.active_skill.is_empty() or player.current_attack not in [&"attack_1", &"attack_2", &"hook_throw"]:
        return false
    return player.attack_duration - player.attack_timer > player.attack_windup + player.attack_active_time


static func cancel_attack_recovery(player: Node) -> void:
    if player.attack_timer <= 0.0:
        return
    player.attack_cancel_lock = player.attack_timer
    player.recovery_cancel_count += 1
    player.attack_timer = 0.0
    player.attack_shape.disabled = true
    player.traversal_downstrike_active = false
    player.run_attack_pose = false


static func start_dash(player: Node) -> void:
    player._clear_action_buffer()
    player._stop_grapple()
    player.dash_timer = player.dash_time
    player.dash_cooldown = player.dash_cooldown_time
    player.velocity.y = 0.0
    player.velocity.x = player.dash_speed * player.facing
    player.dash_ghost_tick = 0
    player.dash_start_position = player.global_position
    player._sync_attack_hitbox()
    player.ability_action.emit("thread_dash", player.global_position, Vector2(player.facing, 0))
    if player.feel != null:
        player._add_trauma(0.08)
    player._play(&"dash")
    player._play_sfx("dash", -7.0)


static func can_start_action(player: Node, allow_grapple: bool = false, allow_recovery_cancel: bool = false) -> bool:
    if player.get_parent().has_method("_walking_world_passage") and player.get_parent()._walking_world_passage():
        return false
    return player.death_timer <= 0.0 and player.hurt_timer <= 0.0 and (player.attack_timer <= 0.0 or (allow_recovery_cancel and player._attack_recovery_cancelable())) and player.dash_timer <= 0.0 and (allow_grapple or player.grapple_timer <= 0.0) and player.heal_timer <= 0.0 and player.guard_timer <= 0.0 and not player.phase_active and not player.ui_input_locked


static func apply_thread_balance(player: Node, next_energy: int, next_practice: int) -> void:
    var before = player.energy
    player.energy=clampi(next_energy,0,player.max_energy)
    player.practice_energy=clampi(next_practice,0,player.energy)
    if player.energy != before:
        player.energy_changed.emit(player.energy, player.max_energy)
