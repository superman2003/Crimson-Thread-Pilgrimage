extends RefCounted
## Taking damage and guard contact, projectile deflection, region hand-off, respawning and the debug and combat UI snapshots.
## Moved out of player_controller.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.
const ABILITY_ART := preload("res://scripts/player_ability_art.gd")
const CONTACT_ART := preload("res://scripts/player_contact_art.gd")
const DASH_ART := preload("res://scripts/player_dash_art.gd")
const GUARD_ART := preload("res://scripts/player_guard_art.gd")
const HOOK_ART := preload("res://scripts/player_hook_art.gd")
const HURT_ART := preload("res://scripts/player_hurt_art.gd")

static func _is_debug_invulnerable(player: Node) -> bool:
    return OS.is_debug_build() and player.debug_invulnerable


static func practice_guard_contact(player: Node, source_position: Vector2) -> bool:
    # A practice contact is eligible only while already guarding the correct side.
    # It cannot damage, begin a guard, heal, or exceed the real prepaid guard refund.
    var source_side = signf(source_position.x - player.global_position.x)
    if player.guard_timer <= 0.0 or player.hurt_timer > 0.0 or player.death_timer > 0.0 or _is_debug_invulnerable(player) or player.arrival_guard_timer > 0.0 or (source_side != 0.0 and int(source_side) != player.facing):
        return false
    player.take_damage(1, source_position, true)
    return player.guard_timer <= 0.0


static func take_damage(player: Node, amount: int, source_position: Vector2, blockable: bool) -> bool:
    if player.arrival_guard_timer > 0.0:
        return false
    if _is_debug_invulnerable(player):
        return false
    if player.hurt_timer > 0.0 or player.death_timer > 0.0 or player.mercy_timer > 0.0:
        return false
    if amount <= 0:
        return false
    player.camera_focus.clear_look()
    player._clear_action_buffer()
    var source_side = signf(source_position.x - player.global_position.x)
    if blockable and player.guard_timer > 0.0 and (source_side == 0.0 or int(source_side) == player.facing):
        var perfect = player.guard_timer >= player.guard_initial_duration - 0.14 and not player.guard_refunded
        if perfect:
            player.guard_refunded = true
            if player._crest() == "bell" and player._seal_mechanism_ready():
                player.bell_pressure = mini(2, player.bell_pressure + 1)
            # Guard refund stays below its payment: no repeatable energy source.
            player.gain_energy(4 if String(player.active_skill.get("kind", "")) != "defense" else 0)
            player.ability_action.emit("bell_guard", player.global_position, Vector2(player.facing, 0))
        player.guard_timer = 0.0
        player.hurt_timer = 0.12
        if String(player.active_skill.get("kind", "")) == "defense":
            player.attack_timer = minf(player.attack_timer, float(player.active_skill.get("recovery", 0.15)))
        player._play_sfx("guard_perfect" if perfect else "guard_block", -5.0, 1.0, "player_guard", 0)
        if perfect and player.footstep_material == "salt":
            player._play_sfx("ch03_beat_guard_ring", -10.0)
        GUARD_ART.blocked(player, perfect)
        player.combat_observed.emit({"kind":"guard","perfect":perfect})
        return false
    GUARD_ART.clear(player)
    CONTACT_ART.clear_player(player)
    ABILITY_ART.clear(player)
    HOOK_ART.clear(player)
    DASH_ART.clear(player)
    player.line_stacks = 0
    player.line_expiry = 0.0
    player._interrupt_heal()
    player._stop_phase()
    player._stop_grapple()
    player.guard_timer = 0.0
    # A damaging hit interrupts dash motion so the next tick preserves knockback.
    player.dash_timer = 0.0
    player.attack_timer = 0.0
    player.attack_shape.set_deferred("disabled", true)
    amount = maxi(1, int(ceil(float(amount) * float(player.build_profile.get("damage_taken_mult", 1.0)))))
    amount = maxi(1, amount + player.difficulty_damage_bonus)
    var hp_before_damage = player.hp
    player.hp = maxi(0, player.hp - amount)
    player.set_meta("_last_hurt_frame", Engine.get_physics_frames())
    player.hp_changed.emit(player.hp)
    player.combat_observed.emit({"kind":"hurt","damage":hp_before_damage-player.hp,"lethal":player.hp<=0})
    # P0 生死攸关音：声部抢占最高优先级。
    player._play_sfx("hurt", -6.0, 1.0, "", 0)
    if player.hp <= 0:
        player.bell_pressure = 0
        player.heal_speed_timer = 0.0
        player.heal_stability_timer = 0.0
        player.status_resist_timer = 0.0
        for enemy in player.get_tree().get_nodes_in_group("enemy"):
            if enemy.has_method("clear_salt_mark"):
                enemy.clear_salt_mark()
        player.death_timer = 0.9
        HURT_ART.died(player)
        player.respawn_reveal_timer = 0.0
        player._set_death_visibility(1.0)
        player.velocity = Vector2.ZERO
        player._stop_wall_slide_loop()
        # 死亡=绯线松脱（音频规格 §4.2 player_death）：无惨叫，只有线散与长呼气。
        player._play_sfx("death_cocoon", -5.0, 1.0, "", 0)
        if player.feel != null:
            player.feel.hitstop(200.0)
            player._add_trauma(0.60)
            player._black_frame(player.global_position, 3)
        player._play(&"death")
        return true
    HURT_ART.hurt(player, source_position)
    if player.feel != null:
        player.feel.hitstop(110.0)
        player._add_trauma(0.45)
        player._black_frame(player.global_position, 2)
    player.self_flash_timer = 0.05
    if player.flash_material != null:
        player.flash_material.set_shader_parameter("flash_amount", 1.0 if bool(player._accessibility().get("flash_enabled", true)) else 0.0)
    player.gain_energy(player.energy_on_damage)
    player.hurt_timer = 0.35
    player.mercy_timer = player.hurt_timer + player.difficulty_mercy if player.difficulty_mercy > 0.0 else 0.0
    var knockback_dir = signf(player.global_position.x - source_position.x)
    if knockback_dir == 0.0:
        knockback_dir = -player.facing
    if player.heal_stability_timer > 0.0:
        player.heal_stability_timer = 0.0
        player.velocity = Vector2.ZERO
    else:
        player.velocity = Vector2(knockback_dir * 260.0 * float(player.build_profile.get("knockback_mult", 1.0)), -170.0)
    player._play(&"hurt")
    return true


static func can_deflect_projectile(player: Node) -> bool:
    if player.attack_timer <= 0.0 or player.guard_timer > 0.0 or player.hurt_timer > 0.0 or player.death_timer > 0.0:
        return false
    if not player.active_skill.is_empty() and String(player.active_skill.get("kind", "")) not in ["melee", "thrust", "crosscut"]:
        return false
    var elapsed = player.attack_duration - player.attack_timer
    return elapsed >= player.attack_windup and elapsed <= player.attack_windup + player.attack_active_time


static func can_ignore_enemy_contact(player: Node, _source_position: Vector2) -> bool:
    if player.death_timer > 0.0 or player.hurt_timer > 0.0:
        return true
    if not player.active_skill.is_empty():
        return false
    if player.dash_timer > 0.0 or player.enemy_contact_guard_timer > 0.0:
        return true
    return false


static func set_spawn(player: Node, position_value: Vector2) -> void:
    player.spawn_position = position_value


static func prepare_region_handoff(player: Node) -> void:
    # Cancel references to the departing geometry without making travel a free
    # cooldown reset or restoring the already reserved healing energy.
    var dash_remaining = player.dash_cooldown
    var guard_remaining = player.guard_cooldown
    var grapple_remaining = player.grapple_recovery_timer
    player._reset_traversal_state()
    player.dash_cooldown = dash_remaining
    player.guard_cooldown = guard_remaining
    player.grapple_recovery_timer = grapple_remaining
    player.attack_vfx_started = false
    player.skill_effect_started = false
    player.skill_displacement_done = 0.0
    player.velocity = Vector2.ZERO
    player.ui_input_locked = false


static func respawn_at(player: Node, position_value: Vector2) -> void:
    player._reset_traversal_state()
    player.global_position = position_value
    player.velocity = Vector2.ZERO
    player.reset_camera_after_arrival()
    player.player_respawned.emit()


static func reset_camera_after_arrival(player: Node) -> void:
    player.camera_focus.clear_look()
    var camera = player.get_node_or_null("Camera2D") as Camera2D
    if camera != null:
        player.room_camera.update(player.camera_focus, player.global_position)
        player.camera_focus.apply_limits(camera)
        player.camera_focus.reset_follow(player.global_position)
        camera.position = Vector2(0, -55)
        camera.offset = Vector2.ZERO
        camera.rotation = 0.0
        camera.reset_smoothing()
    player.reset_physics_interpolation()
    if camera != null:
        camera.force_update_scroll()


static func set_death_visibility(player: Node, amount: float) -> void:
    # The hit-flash shader writes COLOR itself, so CanvasItem alpha alone does
    # not fade the authored player or the idle layers using this material.
    if player.flash_material != null:
        player.flash_material.set_shader_parameter("presentation_alpha", clampf(amount, 0.0, 1.0))


static func update_respawn_reveal(player: Node, delta: float) -> void:
    if player.respawn_reveal_timer <= 0.0:
        return
    player.respawn_reveal_timer = maxf(0.0, player.respawn_reveal_timer - delta)
    player._set_death_visibility(1.0 - player.respawn_reveal_timer / player.RESPAWN_REVEAL_SECONDS)


static func hard_respawn(player: Node) -> void:
    player.snare_timer = 0.0
    player.hp = player.max_hp
    player.energy = 0
    player.practice_energy = 0
    player.hp_changed.emit(player.hp)
    player.energy_changed.emit(player.energy, player.max_energy)
    player.respawn_at(player.spawn_position)
    # 钟龛复活（音频规格 §4.2 player_respawn）：龛铃三音上行 + 吸气。
    player._play_sfx("respawn_weave", -7.0, 1.0, "", 0)
    player._play(&"idle")
    player.respawn_reveal_timer = player.RESPAWN_REVEAL_SECONDS
    player._set_death_visibility(0.0)
    HURT_ART.respawned(player)


static func restore_at_save_point(player: Node) -> void:
    player._reset_traversal_state()
    player.snare_timer = 0.0
    player.hp = player.max_hp
    player.energy = player.max_energy
    player.practice_energy = 0
    player.hurt_timer = 0.0
    player.death_timer = 0.0
    player.heal_cooldown = 0.0
    player.skill_cooldown = 0.0
    player.velocity = Vector2.ZERO
    player.hp_changed.emit(player.hp)
    player.energy_changed.emit(player.energy, player.max_energy)
    player._play(&"idle")


static func get_player_debug_state(player: Node) -> Dictionary:
    return {
        "player_manifest": player.PLAYER_MANIFEST,
        "speed": player.speed,
        "jump_velocity": player.jump_velocity,
        "gravity": player.gravity,
        "dash_speed": player.dash_speed,
        "coyote_time": player.coyote_time,
        "jump_buffer_time": player.jump_buffer_time,
        "jump_cut_multiplier": player.jump_cut_multiplier,
        "sprite_scale": player.sprite.scale if player.sprite != null else Vector2.ZERO,
        "animation_count": player.sprite.sprite_frames.get_animation_names().size() if player.sprite != null and player.sprite.sprite_frames != null else 0,
        "idle_frame_count": player.sprite.sprite_frames.get_frame_count(&"idle") if player.sprite != null and player.sprite.sprite_frames != null and player.sprite.sprite_frames.has_animation(&"idle") else 0,
        "directional_attack": true,
        "double_jump_unlocked": player.double_jump_unlocked,
        "air_jump_available": player.air_jump_available,
        "thread_grapple_unlocked": player.thread_grapple_unlocked,
        "grappling": player.grapple_timer > 0.0,
        "attack_direction": [player.current_attack_direction.x, player.current_attack_direction.y],
        "downslash_bounce_velocity": player.downslash_bounce_velocity,
        "enemy_contact_guard_time": player.enemy_contact_guard_time
    }


static func get_combat_ui_state(player: Node) -> Dictionary:
    var skill = player.selected_skill
    if player.build_system != null and player.build_system.has_method("selected_skill"):
        skill = player.build_system.selected_skill()
    return {"heal_progress": 1.0 - player.heal_timer / maxf(0.2, player.heal_duration) if player.heal_timer > 0.0 else 0.0,
        "heal_active": player.heal_timer > 0.0, "heal_cost": player.heal_energy_cost, "heal":player.get_heal_readiness(),
        "skill_name": String(skill.get("name", skill.get("label", skill.get("id", "绯线震击")))),
        "skill_cooldown": float(skill.get("cooldown_remaining", player.skill_cooldown)), "skill_cost": int(skill.get("energy_cost", player.skill_energy_cost)),
        "guard_cooldown": player.guard_cooldown, "phase_active": player.phase_active,
        "equipment_name": "", "equipment_count": 0}
