extends RefCounted
## Casting skills and tools, healing (readiness, channel, interruption), build stats, guard and resonance.
## Moved out of player_controller.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.
const ABILITY_ART := preload("res://scripts/player_ability_art.gd")
const GUARD_ART := preload("res://scripts/player_guard_art.gd")
const HEAL_ART := preload("res://scripts/player_heal_art.gd")

static func get_cast_readiness(player: Node, skill_id: String = "") -> Dictionary:
    if player.hp <= 0 or player.death_timer > 0.0:
        return {"available":false, "text":"复生中", "detail":"等待复生后使用。"}
    if not player._can_start_action():
        return {"available":false, "text":"动作中", "detail":"当前动作或界面结束后可用。"}
    if not skill_id.is_empty():
        if player.attack_cancel_lock > 0.0:
            return {"available":false, "text":"收势", "detail":"取消的挥针仍在收势。"}
        if player.skill_cooldown > 0.0:
            return {"available":false, "text":"%.1fs" % player.skill_cooldown, "detail":"上一招仍在收势。"}
        if skill_id == "shockwave" and not player.is_on_floor():
            return {"available":false, "text":"需落地", "detail":"钟鸣震波需要接触地面。"}
    return {"available":true}


static func configure_selected_skill(player: Node, skill: Dictionary) -> void:
    player.selected_skill = skill.duplicate(true)


static func try_skill_burst(player: Node) -> void:
    player.cast_selected_skill()


static func cast_selected_skill(player: Node, slot: int = -1) -> bool:
    if not player._can_start_action() or player.skill_cooldown > 0.0 or player.attack_cancel_lock > 0.0:
        return false
    var payload: Dictionary
    if player.build_system != null and player.build_system.has_method("try_cast"):
        var preview: Dictionary = player.build_system.selected_skill() if slot < 0 else player.build_system.selected_skill(slot)
        if String(preview.get("id", "")) == "shockwave" and not player.is_on_floor():
            return false
        payload = player.build_system.try_cast(player.energy) if slot < 0 else player.build_system.try_cast(player.energy, slot)
        if not bool(payload.get("ok", false)):
            return false
    else:
        payload = player.selected_skill.duplicate(true) if not player.selected_skill.is_empty() else {"id": "thread_burst", "kind": "melee", "energy_cost": player.skill_energy_cost, "damage": 2, "range": 126.0, "windup": 0.1, "active": 0.22, "recovery": 0.16, "cooldown": 2.4}
    var cost := int(payload.get("energy_cost", player.skill_energy_cost))
    if player.energy < cost:
        return false
    if String(payload.get("id", "")) == "shockwave" and not player.is_on_floor():
        return false
    player.gain_energy(-cost)
    var old_velocity = player.velocity
    player._start_attack(&"attack_2", false)
    player.velocity = old_velocity
    player.active_skill = payload.duplicate(true)
    player.enemy_contact_guard_timer = 0.0
    player.attack_damage = maxi(1, int(payload.get("damage", 2)))
    player.active_skill["empowered"] = player.line_stacks >= 3 and player._crest() == "crimson" and player._seal_mechanism_ready()
    if bool(player.active_skill.empowered):
        player.line_stacks = 0
        player.line_expiry = 0.0
    player.crosscut_refund_paid = false
    if player._crest() == "bell" and player._seal_mechanism_ready() and String(payload.get("id", "")) == "shockwave" and player.bell_pressure > 0:
        player.attack_damage += player.bell_pressure
        player.active_skill["stagger"] = player.bell_pressure * 0.3
        player.bell_pressure = 0
    player.attack_range = float(payload.get("range", 126.0))
    if bool(player.active_skill.get("empowered", false)) and String(payload.get("id", "")) == "cleave":
        player.attack_range *= 1.35
    if String(payload.get("id", "")) == "crosscut":
        player.attack_forward_offset = 0.0
        player.attack_range *= 2.0
        player.current_attack_direction = Vector2(player.facing, 0)
    player.attack_windup = float(payload.get("windup", payload.get("warmup", 0.1)))
    player.attack_active_time = float(payload.get("active", 0.18))
    if String(payload.get("kind", "")) == "defense":
        player.attack_active_time = clampf(float(payload.get("duration", 0.5)), 0.1, 0.65)
    player.attack_duration = player.attack_windup + player.attack_active_time + float(payload.get("recovery", 0.2))
    player.attack_timer = player.attack_duration
    player.skill_effect_started = false
    player.skill_cooldown = 0.0 if player.build_system != null else float(payload.get("cooldown", 2.4))
    player._sync_attack_hitbox()
    player.seal_recovery_shown = false
    player.skill_displacement_done = 0.0
    player._seal_present(String(payload.get("id", "cleave")), "prepare")
    player.last_skill_cast = String(payload.get("id", ""))
    player.last_skill_cast_msec = Time.get_ticks_msec()
    player.last_skill_cast_serial += 1
    player.skill_cast.emit(String(payload.get("skill_id", payload.get("id", "thread_burst"))))
    return true


static func get_heal_readiness(player: Node) -> Dictionary:
    # This snapshot is read by both the action and HUD; querying never reserves.
    var reason := "ready"
    if player.heal_timer > 0.0: reason = "channeling"
    elif player.death_timer > 0.0: reason = "dead"
    elif not player._can_start_action(): reason = "busy"
    elif player.heal_cooldown > 0.0: reason = "cooldown"
    elif player.hp >= player.max_hp: reason = "full_health"
    elif player.energy < player.heal_energy_cost: reason = "energy"
    elif not player.is_on_floor() and not player._heal_airborne(): reason = "airborne"
    elif absf(player._move_axis()) > 0.1 or Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("dash"): reason = "moving"
    return {"available":reason=="ready", "reason":reason, "cost":player.heal_energy_cost,
        "reserved":player.heal_reserved_cost if player.heal_timer>0.0 else 0,
        "missing_energy":maxi(0,player.heal_energy_cost-player.energy), "amount":mini(player.heal_amount,maxi(0,player.max_hp-player.hp)),
        "duration":player.heal_duration, "remaining":player.heal_timer, "cooldown":player.heal_cooldown,
        "interrupt_loss":int(ceil(player.heal_reserved_cost*player.heal_reserved_loss_ratio)) if player.heal_timer>0.0 else int(ceil(player.heal_energy_cost*clampf(float(player.build_profile.get("heal_interrupt_loss_ratio",1.0)),0.0,1.0)))}


static func try_heal(player: Node) -> bool:
    if not bool(player.get_heal_readiness().available):
        return false
    player._clear_action_buffer()
    # Publish the reservation before resource signals can reenter this action.
    player.heal_reservation_generation += 1
    var reservation_generation = player.heal_reservation_generation
    player.heal_reserved_cost = player.heal_energy_cost
    player.heal_reserved_loss_ratio = clampf(float(player.build_profile.get("heal_interrupt_loss_ratio",1.0)),0.0,1.0)
    player.heal_reserved_practice = mini(player.practice_energy, player.heal_reserved_cost)
    player.heal_timer = player.heal_duration
    player.velocity.x = 0.0
    player.gain_energy(-player.heal_reserved_cost)
    # A payment listener may cancel, change build, or begin a newer channel.
    if player.heal_reservation_generation != reservation_generation or player.heal_timer <= 0.0:
        return false
    HEAL_ART.start(player)
    player._seal_present("heal", "prepare")
    player.heal_voice = player._play_sfx_voice("heal", -5.0)
    player._start_bind_channel()
    player._play(&"heal")
    player.heal_state_changed.emit("started")
    return player.heal_reservation_generation == reservation_generation and player.heal_timer > 0.0


static func update_heal(player: Node, delta: float) -> void:
    if player.heal_timer <= 0.0:
        return
    if (not player.is_on_floor() and not player._heal_airborne()) or Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("dash") or absf(player._move_axis()) > 0.1:
        player._interrupt_heal()
        return
    player.heal_timer = maxf(0.0, player.heal_timer - delta)
    if is_instance_valid(player.bind_channel_audio) and player.bind_channel_audio.playing:
        var progress = 1.0 - player.heal_timer / maxf(player.heal_duration, 0.01)
        player.bind_channel_audio.pitch_scale = lerpf(player.BIND_CHANNEL_PITCH.x, player.BIND_CHANNEL_PITCH.y, clampf(progress, 0.0, 1.0))
    if player.heal_timer <= 0.0:
        player._stop_bind_channel()
        player.heal_reservation_generation += 1
        var completed_generation = player.heal_reservation_generation
        player.heal_reserved_cost = 0
        player.heal_reserved_practice = 0
        player.hp = mini(player.max_hp, player.hp + player.heal_amount)
        player.heal_cooldown = 0.4
        player._play_sfx("bind_tighten", -6.0)
        # Settle the paid build before HP listeners can replace that build.
        player._seal_heal_completed()
        HEAL_ART.completed(player)
        player.hp_changed.emit(player.hp)
        if player.heal_reservation_generation==completed_generation:
            player.heal_state_changed.emit("completed")


static func interrupt_heal(player: Node) -> void:
    player._stop_bind_channel()
    if player.heal_timer > 0.0:
        var settled:=preload("res://scripts/heal_refund_account.gd").settlement(
            player.heal_reserved_cost,player.heal_reserved_practice,player.heal_reserved_loss_ratio,
            player.energy,player.max_energy,player.practice_energy)
        # Clear the reservation and block recasts before emitting energy_changed.
        player.heal_reservation_generation += 1
        var settled_generation = player.heal_reservation_generation
        player.heal_reserved_cost = 0
        player.heal_timer = 0.0
        player.heal_cooldown = maxf(player.heal_cooldown, 0.3)
        player.heal_reserved_practice = 0
        HEAL_ART.interrupted(player)
        # The channel sound outlasts the channel; cut it where the thread snaps.
        if is_instance_valid(player.heal_voice) and not player.heal_voice.is_queued_for_deletion():
            player.heal_voice.stop()
            player.heal_voice.queue_free()
        player.heal_voice = null
        player._play_sfx("bind_interrupt", -6.0)
        # Publish provenance before gain_energy emits. Reentrant listeners may
        # leave practice or pay a newer heal before this call returns.
        player._apply_thread_balance(int(settled.energy_after),int(settled.practice_after))
        if player.heal_reservation_generation==settled_generation:
            player.heal_state_changed.emit("interrupted")


static func apply_build_stats(player: Node, stats: Dictionary) -> void:
    # Finding a capacity reward is not an equipment change. Keep the current
    # attack/channel/guard and its original reservation; do not refill on pickup.
    if not player.build_profile.is_empty():
        var capacity_only = player.build_profile.duplicate(true)
        capacity_only["max_hp"] = stats.get("max_hp", player.max_hp)
        capacity_only["max_energy"] = stats.get("max_energy", player.max_energy)
        if capacity_only == stats and (player.max_hp != int(capacity_only.max_hp) or player.max_energy != int(capacity_only.max_energy)):
            player.build_profile = stats.duplicate(true)
            player._apply_capacity_limits(stats)
            return
    # Settle the old channel under its original cost/loss and capacity first.
    player._interrupt_heal()
    player._clear_action_buffer()
    if player.build_baseline.is_empty():
        player.build_baseline = {"max_hp": player.max_hp, "max_energy": player.max_energy, "speed": player.speed, "energy_per_hit": player.energy_per_hit, "heal_energy_cost": player.heal_energy_cost, "heal_amount": player.heal_amount, "heal_duration": player.heal_duration}
    player.line_stacks = 0
    player.bell_pressure = 0
    player.line_expiry = 0.0
    player.heal_speed_timer = 0.0
    player.heal_stability_timer = 0.0
    player.status_resist_timer = 0.0
    player.attack_timer = 0.0
    player.attack_cancel_lock = 0.0
    player.active_skill.clear()
    for enemy in player.get_tree().get_nodes_in_group("enemy"):
        if enemy.has_method("clear_salt_mark"):
            enemy.clear_salt_mark()
    player.build_profile = stats.duplicate(true)
    player.max_hp = maxi(1, int(stats.get("max_hp", player.build_baseline.max_hp)))
    player.max_energy = maxi(1, int(stats.get("max_energy", player.build_baseline.max_energy)))
    player.speed = float(player.build_baseline.speed) * float(stats.get("move_mult", stats.get("speed_multiplier", 1.0)))
    player.energy_per_hit = maxi(0, int(stats.energy_per_hit)) if stats.has("energy_per_hit") else maxi(0, int(round(float(player.build_baseline.energy_per_hit) * float(stats.get("energy_gain_mult", 1.0)))))
    player.heal_energy_cost = maxi(1, int(stats.get("heal_cost", stats.get("heal_energy_cost", player.build_baseline.heal_energy_cost))))
    player.heal_amount = maxi(1, int(stats.get("heal_amount", player.build_baseline.heal_amount)))
    player.heal_duration = maxf(0.2, float(stats.get("heal_duration", player.build_baseline.heal_duration)))
    player.hp = mini(player.hp, player.max_hp)
    var bounded = preload("res://scripts/heal_refund_account.gd").change(0,player.energy,player.max_energy,player.practice_energy)
    player.energy=int(bounded.energy)
    player.practice_energy=int(bounded.practice)
    player.guard_timer = 0.0
    player._stop_phase()
    player.hp_changed.emit(player.hp)
    player.energy_changed.emit(player.energy, player.max_energy)


static func apply_capacity_limits(player: Node, stats: Dictionary) -> void:
    player.max_hp = maxi(1, int(stats.get("max_hp", player.max_hp)))
    player.max_energy = maxi(1, int(stats.get("max_energy", player.max_energy)))
    player.hp = mini(player.hp, player.max_hp)
    var bounded = preload("res://scripts/heal_refund_account.gd").change(0,player.energy,player.max_energy,player.practice_energy)
    player.energy=int(bounded.energy)
    player.practice_energy=int(bounded.practice)
    player.hp_changed.emit(player.hp)
    player.energy_changed.emit(player.energy, player.max_energy)


static func try_guard(player: Node) -> bool:
    if not player.bell_guard_unlocked or not player._can_start_action() or player.guard_cooldown > 0.0 or player.energy < 8:
        return false
    player._clear_action_buffer()
    player.gain_energy(-8)
    player.guard_timer = 0.42
    player.guard_initial_duration = player.guard_timer
    player.guard_cooldown = 0.8
    player.guard_refunded = false
    player.ability_action.emit("bell_guard", player.global_position, Vector2(player.facing, 0))
    player._play(&"guard")
    GUARD_ART.start(player)
    return true


static func try_resonance(player: Node) -> bool:
    if not player.crown_resonance_unlocked or not player._can_start_action() or player.resonance_cooldown > 0.0 or player.energy < 20:
        return false
    player.gain_energy(-20)
    player.resonance_cooldown = 1.4
    player._start_attack(&"attack_2", false)
    player.active_skill = {"kind": "resonance", "range": 160.0, "damage": 1}
    player.skill_effect_started = false
    player.ability_action.emit("crown_resonance", player.global_position, Vector2(player.facing, 0))
    ABILITY_ART.resonance(player)
    return true


static func apply_special_skill(player: Node) -> void:
    var kind := String(player.active_skill.get("kind", "melee"))
    var id := String(player.active_skill.get("id", ""))
    if kind == "ranged":
        player.cast_tool({"kind": "projectile", "damage": player.attack_damage, "range": player.attack_range, "duration": 1.2, "pierce": 1, "salt_mark": player._crest() == "salt" and player._seal_mechanism_ready(), "skill_effect": true})
    elif kind == "defense":
        player.guard_timer = minf(0.65, float(player.active_skill.get("duration", 0.5)))
        player.guard_initial_duration = player.guard_timer
        player.guard_refunded = false
        GUARD_ART.start(player)
    elif id == "shockwave" or kind == "shockwave":
        player.cast_tool({"kind": "wave", "damage": player.attack_damage, "range": player.attack_range, "duration": 0.8, "stagger": player.active_skill.get("stagger", 0.0), "skill_effect": true})
    elif kind == "control":
        player.cast_tool({"kind":"snare_field", "damage":player.attack_damage, "range":10000.0, "duration":maxf(0.4, float(player.active_skill.get("duration",1.5))), "salt_consume":player._crest() == "salt" and player._seal_mechanism_ready(), "skill_effect":true})
    elif kind == "resonance":
        var radius := float(player.active_skill.get("range", 160.0))
        for enemy in player.get_tree().get_nodes_in_group("enemy"):
            if enemy.has_method("world_residency_active") and not enemy.world_residency_active(): continue
            if enemy is Node2D and enemy.global_position.distance_to(player.global_position) <= radius and player._attack_line_clear(enemy.global_position):
                if enemy.has_method("take_hit"):
                    enemy.take_hit(player.attack_damage, player.facing)
                    if enemy.has_method("report_skill_contact"):enemy.report_skill_contact(player,id,player.last_skill_cast_serial)


static func cast_tool(player: Node, payload: Dictionary) -> bool:
    # A ranged skill creates its effect inside its own active frame; public tool
    # use must otherwise obey the same channel/recovery gates as combat actions.
    var skill_emission = player.attack_timer > 0.0 and player.skill_effect_started and bool(payload.get("skill_effect", false))
    if not player._can_start_action() and not skill_emission:
        return false
    var tool_id := String(payload.get("id", ""))
    if tool_id == "mine":
        var count := 0
        for effect in player.get_tree().get_nodes_in_group("player_trap"):
            if effect.get("owner_player") == player:
                count += 1
        if count >= 2:
            return false
    if String(payload.get("kind", "")) == "snare_field":
        for field in player.get_tree().get_nodes_in_group("player_snare_field"):
            if field.get("owner_player") == player:
                field.queue_free()
    var projectile := Node2D.new()
    projectile.set_script(load("res://scripts/player_tool_effect.gd"))
    var effect_payload:=payload.duplicate(true)
    if bool(payload.get("skill_effect",false)):
        effect_payload["practice_skill_id"]=String(player.active_skill.get("id",""))
        effect_payload["practice_cast_serial"]=player.last_skill_cast_serial
    projectile.set("payload", effect_payload)
    projectile.set("direction", player.facing)
    projectile.set("owner_player", player)
    player.get_parent().add_child(projectile)
    if not bool(payload.get("skill_effect", false)):
        player._seal_present(String(payload.get("id", "shard")), "active")
    var spawn_offset := Vector2(player.facing * (90 if String(payload.get("kind", "")) == "snare_field" else 24), -6 if String(payload.get("kind", "")) in ["trap", "snare_field"] else -42)
    var spawn_origin = player.global_position + Vector2(0, spawn_offset.y)
    var spawn_position_effect = player.global_position + spawn_offset
    var placement_ray = PhysicsRayQueryParameters2D.create(spawn_origin, spawn_position_effect, 1, [player.get_rid()])
    var placement_hit = player.get_world_2d().direct_space_state.intersect_ray(placement_ray)
    if not placement_hit.is_empty():
        spawn_position_effect = placement_hit.position - Vector2(player.facing * 8, 0)
    projectile.global_position = spawn_position_effect
    if not bool(payload.get("skill_effect", false)):
        player.attack_timer = 0.35
        player.attack_duration = 0.35
        player.attack_windup = 0.35
        player.attack_active_time = 0.0
        player.active_skill = {"id": String(payload.get("id", "shard")), "kind": "tool"}
        player.skill_effect_started = true
    return true
