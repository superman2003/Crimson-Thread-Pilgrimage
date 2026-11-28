extends RefCounted
## Configuring an enemy, elite profiles, hit reactions and the death dissolve, hurtbox fitting, timers and hit flash, arena clamping and respawn.
## Moved out of enemy_actor.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.
const BOSS_STYLE := preload("res://scripts/boss_combat_style.gd")
const CONTACT_ART := preload("res://scripts/player_contact_art.gd")
const ORIGINAL_ART := preload("res://scripts/hand_drawn_assets.gd")

static func configure(actor: Node, data: Dictionary, sprite_path: String, boss_flag: bool = false, profile: Dictionary = {}) -> void:
    actor.spawn_id = String(data.get("id", "enemy"))
    actor.kind = String(data.get("kind", "moss_larva"))
    actor.ai_rng.seed = hash(actor.spawn_id + ":" + actor.kind)
    actor.combat_audio_rng.seed = hash(actor.spawn_id + ":sound:" + actor.kind)
    actor.hp = int(data.get("hp", 2))
    actor.max_hp = actor.hp
    actor.damage = int(data.get("damage", 1))
    actor.patrol_distance = float(data.get("patrol", 80.0))
    actor.is_boss = boss_flag
    actor.encounter_role = String(data.get("encounter_role", ""))
    actor.speed = float(profile.get("move_speed", 34.0 if actor.is_boss else 42.0))
    actor.leash_radius = float(data.get("leash_radius", profile.get("leash_radius", 9999.0 if actor.is_boss else 240.0)))
    actor.asset_path = String(data.get("sprite", sprite_path))
    actor.sprite_parts = data.get("sprite_parts", [])
    actor.sprite_region = data.get("sprite_region", [])
    actor.sprite_regions = data.get("sprite_regions", {})
    actor.visual_scale = float(data.get("visual_scale", 0.0))
    actor.visual_offset = actor._vec2(data.get("visual_offset", [0, 0]))
    actor.body_size = actor._vec2_or(data.get("body_size", []), Vector2(132, 128) if actor.is_boss else Vector2(50, 46))
    actor.ground_clearance = float(data.get("clearance", 40.0))
    actor.hurtbox_size = actor._vec2_or(data.get("hurtbox_size", []), Vector2(142, 144) if actor.is_boss else Vector2(58, 56))
    actor.hurtbox_offset = actor._vec2_or(data.get("hurtbox_offset", []), Vector2(0, -40) if actor.is_boss else Vector2(0, -18))
    actor.sprite_faces_left = bool(data.get("sprite_faces_left", false))
    if data.has("visual_modulate"):
        actor.visual_modulate = Color.html("#" + String(data.get("visual_modulate", "ffffff")))
    if data.has("arena_min_x"):
        actor.arena_min_x = float(data.get("arena_min_x", -INF))
    if data.has("arena_max_x"):
        actor.arena_max_x = float(data.get("arena_max_x", INF))
    actor.combat_resistance = data.get("combat_resistance", {"trip_immune": actor.is_boss, "lure_immune": actor.is_boss, "snare_mult": 0.35 if actor.is_boss else 1.0})
    actor.ai_profile = profile.duplicate(true)
    var original_profile: Dictionary = ORIGINAL_ART.manifest("res://data/original_creature_combat.json").get(actor.kind,{})
    if not original_profile.is_empty():
        actor.ai_profile.merge(original_profile,true)
    # Room pacing is an explicit spawn override, after the species identity.
    # Tree-out prefabs and live actors use the same configure contract.
    var encounter_profile: Variant = data.get("encounter_profile", {})
    if encounter_profile is Dictionary:
        actor.ai_profile.merge(encounter_profile, true)
    if actor.is_boss:actor.ai_profile=BOSS_STYLE.apply(actor.kind,actor.ai_profile)
    actor.locomotion = String(actor.ai_profile.get("locomotion",data.get("locomotion","ground")))
    actor.hover_height = float(actor.ai_profile.get("hover_height",95)) if actor.locomotion=="flight" else 0.0
    actor.speed = float(actor.ai_profile.get("move_speed",actor.speed))
    var original_path = ORIGINAL_ART.character_manifest("original_creatures", actor.kind)
    var art_data = ORIGINAL_ART.manifest(original_path)
    if not art_data.is_empty():
        actor.asset_path=original_path
        actor.sprite_parts=[]
        actor.sprite_region=[]
        actor.sprite_regions={}
        actor.visual_scale=float(art_data.get("visual_scale",1))
        actor.visual_offset=actor._vec2(art_data.get("visual_offset",[0,0]))
        actor.visual_modulate=Color.WHITE
        actor.sprite_faces_left=false
        actor.original_visual=true
        actor.authored_combat_sequences=art_data.get("authored_combat_sequences",[])
        var h := float(art_data.get("display_height",90))
        if not data.has("hurtbox_offset"):
            actor.hurtbox_offset=Vector2(0,40-h*.5)
        if not data.has("body_size"):
            actor.body_size=Vector2(98 if actor.is_boss else 35,h*.72)
        if not data.has("hurtbox_size"):
            actor.hurtbox_size=Vector2(125 if actor.is_boss else 48,h*.84)
    actor.hurtbox_authored = data.has("hurtbox_size") or data.has("hurtbox_offset")
    actor.ai_profile["lure_eligible"] = bool(data.get("lure_eligible", actor.ai_profile.get("lure_eligible", not actor.is_boss and actor.locomotion != "stationary")))
    actor.is_elite = bool(data.get("elite", false)) and not actor.is_boss
    if actor.is_elite:
        var elite_profile: Dictionary = actor.ai_profile.elite if actor.ai_profile.get("elite") is Dictionary else {"hp_mult": 1.75, "damage_bonus": 1}
        apply_elite_profile(actor, elite_profile)
    actor.ai_commands = actor.ai_profile.get("attacks", [])
    for command in actor.ai_commands:
        actor.cooldowns[String(command.get("id", "attack"))] = float(command.get("start_cooldown", 0.0))
    actor.tactical_role = "boss" if actor.is_boss else String(actor.ai_profile.get("tactical_role", "patrol"))
    if not actor.TACTICAL_ROLES.has(actor.tactical_role): actor.tactical_role = "patrol"


static func apply_elite_profile(actor: Node, elite: Dictionary) -> void:
    actor.hp = maxi(actor.hp + 1, ceili(float(actor.hp) * float(elite.get("hp_mult", 1.75))))
    actor.max_hp = actor.hp
    var bonus := int(elite.get("damage_bonus", 1))
    actor.damage += bonus
    var attacks: Array = []
    for command: Dictionary in actor.ai_profile.get("attacks", []):
        var boosted := command.duplicate(true)
        boosted["damage"] = int(boosted.get("damage", 1)) + bonus
        attacks.append(boosted)
    for command: Dictionary in elite.get("attacks", []):
        attacks.append(command.duplicate(true))
    actor.ai_profile["attacks"] = attacks
    if actor.visual_scale > 0.0:
        actor.visual_scale *= float(elite.get("visual_scale_mult", 1.0))


static func contact_visual_call_serial(actor: Node) -> int:
    return int(actor.get_meta(CONTACT_ART.CALL_META, 0))


static func hit_is_armored(actor: Node) -> bool:
    # Poise: after being chained, the next attack shrugs off interruption.
    # Elites keep poise through every strike once it has begun.
    return (actor.poise_timer > 0.0 and actor.state in ["windup", "active"]) or (actor.is_elite and actor.state == "active")


static func react_to_hit(actor: Node, hit_direction: int) -> void:
    actor.recent_hit_times.append(actor.ai_clock)
    while not actor.recent_hit_times.is_empty() and actor.ai_clock - actor.recent_hit_times[0] > 1.4:
        actor.recent_hit_times.pop_front()
    var target: CharacterBody2D = actor._target_player()
    if target != null:
        actor.last_seen_position = target.global_position
        actor.memory_timer = actor.TARGET_MEMORY_SECONDS
    actor.attack_desire += 0.25
    if hit_is_armored(actor):
        actor.knockback_velocity *= 0.35
        return
    actor._cancel_unarmed_attack_effects()
    actor.attack_recovery=false
    actor.recovery_velocity_x=0.0
    actor.active_attack = {}
    actor.pose_loop_animation = ""
    actor.state = "recover"
    actor.state_timer = 0.16
    if not actor.original_visual:actor._fit_animation_duration(actor.state_timer)
    actor._clear_telegraph()
    if actor.recent_hit_times.size() >= 3 and actor.poise_cooldown <= 0.0:
        actor.poise_timer = 1.8
        actor.poise_cooldown = 4.5
        actor.attack_desire = maxf(actor.attack_desire, actor._attack_desire_threshold())
    # Close-range ground fighters hop clear of a combo instead of eating it.
    var close_fighter = actor.locomotion == "ground" and float(actor.ai_profile.get("preferred_range", 54.0)) < 120.0
    if close_fighter and actor.recent_hit_times.size() >= 2 and actor.backstep_cooldown <= 0.0:
        actor.knockback_velocity = float(hit_direction) * 560.0
        actor.backstep_cooldown = 3.0


static func begin_death_dissolve(actor: Node) -> void:
    if actor.dying or actor.is_queued_for_deletion():
        return
    actor.dying = true
    if actor.boss_brain != null:actor.boss_brain.reset_plan()
    actor.active_attack = {}
    actor.state = "dead"
    actor._cancel_attack_effects()
    # Death may be triggered by an Area callback during physics flushing.
    actor.set_deferred("monitoring", false)
    actor.set_deferred("monitorable", false)
    actor.remove_from_group("enemy")
    actor.knockback_velocity = 0.0
    # 材质化死亡音（音频规格 §4.3）：挂到父节点播放，避免溶解 queue_free 截断尾音。
    actor._play_detached_sfx("boss_death" if actor.is_boss else actor.death_sfx_key, -4.0 if actor.is_boss else -6.0)
    # ch3 beat `contract_break`（manifest ch03_beat_03）：盐白契约判官死亡时
    # 契约碎页散开——纸页撕裂与低频钟声叠层（同走独立宿主避免截断）。
    if actor.is_boss and actor.kind == "saltwhite_contract_judge":
        actor._play_detached_sfx("ch03_beat_contract_break", -8.0)
    actor.pose_loop_animation = ""
    actor._set_enemy_animation("death")
    actor._pose_sprite("death")
    actor._clear_telegraph()
    actor.died.emit(actor.spawn_id, actor.is_boss, actor.kind)
    if actor.is_queued_for_deletion():
        return
    if actor.sprite == null or not is_instance_valid(actor.sprite):
        actor.queue_free()
        return
    var duration = 0.9 if actor.is_boss else 0.45
    actor._fit_animation_duration(duration)
    var tween = actor.create_tween()
    tween.tween_interval(0.05)
    tween.tween_callback(func() -> void: actor._set_flash_amount(0.0))
    tween.tween_property(actor.sprite, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    tween.parallel().tween_property(actor.sprite, "position:y", actor.sprite.position.y + 14.0, duration)
    tween.finished.connect(Callable(actor, "queue_free"))


static func fit_hurtbox_to_art(actor: Node) -> void:
    actor.motion_box_size = actor.hurtbox_size
    actor.motion_box_offset = actor.hurtbox_offset
    if actor.is_boss or actor.hurtbox_authored or not actor.original_visual or not is_instance_valid(actor.animated_sprite):
        return
    var frames = actor.animated_sprite.sprite_frames
    var animation = &"idle" if frames != null and frames.has_animation(&"idle") else actor.animated_sprite.animation
    var count = frames.get_frame_count(animation) if frames != null and frames.has_animation(animation) else 0
    var width := 0.0
    var height := 0.0
    var core := Rect2()
    var measured := 0
    for index in count:
        var drawn: Rect2 = drawn_body_rect(actor, animation, index)
        if drawn.has_area():
            width += drawn.size.x
            height += drawn.size.y
            core = drawn if measured == 0 else core.intersection(drawn)
            measured += 1
    if measured == 0 or not core.has_area():
        return
    # Keep the fixed box inside every idle pose, including the smallest one.
    # Averaging alone put part of it in the air as bees/lancers changed pose.
    actor.hurtbox_size = Vector2(clampf(maxf(actor.hurtbox_size.x, minf(width / measured * 0.62, core.size.x)), 40.0, 160.0), minf(height / measured * 0.84, core.size.y))
    actor.hurtbox_offset = core.get_center()


static func drawn_body_rect(actor: Node, animation: StringName, index: int) -> Rect2:
    var frames = actor.animated_sprite.sprite_frames
    if frames == null or not frames.has_animation(animation):
        return Rect2()
    var texture = frames.get_frame_texture(animation, index)
    if texture == null:
        return Rect2()
    var size = texture.get_size()
    var inner := Rect2(Vector2.ZERO, size)
    if texture is AtlasTexture:
        inner = Rect2(texture.margin.position, texture.region.size)
    var origin = (-size * 0.5 if actor.animated_sprite.centered else Vector2.ZERO) + actor.animated_sprite.offset
    var a = actor.animated_sprite.transform * (origin + inner.position)
    var b = actor.animated_sprite.transform * (origin + inner.end)
    return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())


static func get_motion_rect(actor: Node) -> Rect2:
    var size = actor.motion_box_size if actor.motion_box_size != Vector2.ZERO else (actor.hurtbox_size if actor.hurtbox_size != Vector2.ZERO else (Vector2(142, 144) if actor.is_boss else Vector2(58, 56)))
    var offset = actor.motion_box_offset if actor.motion_box_size != Vector2.ZERO else actor.hurtbox_offset
    var center = actor.global_position + (offset if offset != Vector2.ZERO else (Vector2(0.0, -40.0) if actor.is_boss else Vector2(0.0, -18.0)))
    return Rect2(center - size * 0.5, size)


static func get_hurtbox_rect(actor: Node) -> Rect2:
    var size = actor.hurtbox_size if actor.hurtbox_size != Vector2.ZERO else (Vector2(142, 144) if actor.is_boss else Vector2(58, 56))
    var center = actor.global_position + (actor.hurtbox_offset if actor.hurtbox_offset != Vector2.ZERO else (Vector2(0.0, -40.0) if actor.is_boss else Vector2(0.0, -18.0)))
    return Rect2(center - size * 0.5, size)


static func get_ai_debug_state(actor: Node) -> Dictionary:
    return {
        "behavior_tree": actor.boss_brain.debug_state() if actor.boss_brain != null else {},
        "ai_command_total": actor.ai_commands.size(),
        "attack_desire": actor.attack_desire,
        "attack_desire_threshold": actor._attack_desire_threshold(),
        "last_player_command": actor.last_player_command,
        "last_ai_decision": actor.last_ai_decision,
        "tactical_role": actor.tactical_role,
        "alarm_alerted": actor.alarm_alerted,
        "support_cooldown": actor.support_cooldown,
        "last_attack_id": actor.last_attack_id,
        "reads_player_commands": true,
        "command_read_count": actor.command_read_count,
        "aggro_vertical_tolerance": float(actor.ai_profile.get("aggro_vertical_tolerance", 190.0 if actor.is_boss else 118.0)),
        "attack_vertical_tolerance": float(actor.ai_profile.get("attack_vertical_tolerance", 132.0 if actor.is_boss else 72.0)),
        "max_attack_range": actor._max_attack_range(false),
        "tactical_ai": actor._boss_tactical_enabled(),
        "boss_tactic": actor.boss_tactic,
        "boss_tactic_timer": actor.boss_tactic_timer,
        "boss_press_timer": actor.boss_press_timer,
        "boss_reposition_target_x": actor.boss_reposition_target_x
    }


static func tick_timers(actor: Node, delta: float) -> void:
    actor.snare_timer = maxf(0.0, actor.snare_timer - delta)
    actor.salt_mark_timer = maxf(0.0, actor.salt_mark_timer - delta)
    actor.interference_timer = maxf(0.0, actor.interference_timer - delta)
    actor.lure_timer = maxf(0.0, actor.lure_timer - delta)
    actor.trip_timer = maxf(0.0, actor.trip_timer - delta)
    actor.contact_timer = maxf(0.0, actor.contact_timer - delta)
    actor.ai_clock += delta
    actor.memory_timer = maxf(0.0, actor.memory_timer - delta)
    actor.alarm_cooldown = maxf(0.0, actor.alarm_cooldown - delta)
    actor.support_cooldown = maxf(0.0, actor.support_cooldown - delta)
    actor.reveal_hold = maxf(0.0, actor.reveal_hold - delta)
    actor.poise_timer = maxf(0.0, actor.poise_timer - delta)
    actor.poise_cooldown = maxf(0.0, actor.poise_cooldown - delta)
    actor.backstep_cooldown = maxf(0.0, actor.backstep_cooldown - delta)
    actor.patrol_pause_timer = maxf(0.0, actor.patrol_pause_timer - delta)
    tick_hit_flash(actor, delta)
    if absf(actor.knockback_velocity) > 0.0:
        var decay = exp(-maxf(0.0,delta)/actor.KNOCKBACK_TAU)
        var start = actor.global_position
        var finish = start+Vector2(actor.knockback_velocity*actor.KNOCKBACK_TAU*(1.0-decay),0)
        actor.global_position = preload("res://scripts/enemy_motion_sweep.gd").constrain(actor,start,finish) if actor.is_inside_tree() else finish
        actor.knockback_velocity = 0.0 if absf(actor.global_position.x-finish.x)>.01 else actor.knockback_velocity*decay
        if absf(actor.knockback_velocity) < 8.0:
            actor.knockback_velocity = 0.0
        actor._clamp_movement_bounds()
    for key in actor.cooldowns.keys():
        actor.cooldowns[key] = maxf(0.0, float(actor.cooldowns[key]) - delta)
    if actor.boss_tactic_timer > 0.0:
        actor.boss_tactic_timer = maxf(0.0, actor.boss_tactic_timer - delta)


static func tick_hit_flash(actor: Node, delta: float) -> void:
    if actor.flash_timer > 0.0:
        # Physics catch-up may run several times before the next presentation.
        # Do not consume a new hit's entire flash before it can be drawn.
        if Engine.get_process_frames() > actor.flash_started_process_frame:
            actor.flash_timer = maxf(0.0,actor.flash_timer-delta)
        if actor.flash_timer <= 0.0:
            actor._set_flash_amount(0.0)
        else:
            actor._set_flash_amount(1.0 if actor.flash_timer > actor.FLASH_HALF_TIME else actor.flash_timer/actor.FLASH_HALF_TIME)


static func set_flash_amount(actor: Node, amount: float) -> void:
    for material_value in actor.flash_materials:
        var material := material_value as ShaderMaterial
        if material != null:
            material.set_shader_parameter("flash_amount", amount)


static func is_attack_state(actor: Node) -> bool:
    return actor.state in ["windup", "active", "recover", "support"]


static func clamp_to_arena(actor: Node) -> void:
    if actor.arena_min_x >= actor.arena_max_x:
        return
    actor.global_position.x = clampf(actor.global_position.x, actor.arena_min_x, actor.arena_max_x)


static func clamp_movement_bounds(actor: Node) -> void:
    clamp_to_arena(actor)
    if actor.is_boss:
        return
    var limits := movement_limits(actor)
    if limits.x >= limits.y:
        return
    var clamped_x := clampf(actor.global_position.x, limits.x, limits.y)
    if not is_equal_approx(clamped_x, actor.global_position.x):
        var next_position = actor.global_position
        next_position.x = clamped_x
        actor.global_position = next_position
        actor.direction *= -1
        actor._set_sprite_flip(actor.direction < 0)


static func movement_limits(actor: Node) -> Vector2:
    var min_x: float = actor.arena_min_x if actor.arena_min_x < actor.arena_max_x else -INF
    var max_x: float = actor.arena_max_x if actor.arena_min_x < actor.arena_max_x else INF
    if actor.leash_radius > 0.0:
        min_x = maxf(min_x, actor.spawn_position.x - actor.leash_radius)
        max_x = minf(max_x, actor.spawn_position.x + actor.leash_radius)
    if actor.platform_min_x < actor.platform_max_x:
        min_x = maxf(min_x, actor.platform_min_x)
        max_x = minf(max_x, actor.platform_max_x)
    return Vector2(min_x, max_x)


static func set_platform_movement_bounds(actor: Node, min_x: float, max_x: float) -> void:
    actor.platform_min_x = min_x-100 if actor.locomotion=="flight" else min_x
    actor.platform_max_x = max_x+100 if actor.locomotion=="flight" else max_x


static func reset_for_respawn(actor: Node) -> void:
    if actor.dying or actor.is_queued_for_deletion():
        return
    if actor.boss_brain != null:actor.boss_brain.reset_plan()
    actor.attack_execution_serial += 1
    actor.attack_completed_serial = -1
    CONTACT_ART.clear_receiver(actor)
    actor._cancel_attack_effects()
    actor._clear_telegraph()
    for tween in actor.combat_tweens:
        if is_instance_valid(tween) and tween.is_valid():
            tween.kill()
    actor.combat_tweens.clear()
    for child in actor.get_children():
        if (child is Line2D and String(child.name).begins_with("OriginalAttack")) or child.name in ["EnemyWindupVfx", "BossAttackBurstVfx", "EnemyAttackBurstVfx", "HitSpark"]:
            child.queue_free()
    actor.battle_phase = 1
    actor.phase_pause = 0.0
    actor.attack_elapsed = 0.0
    actor.attack_recovery=false
    actor.recovery_velocity_x=0.0
    actor.completed_attack_count=0
    actor.boss_target_history.clear()
    actor.boss_attack_history.clear()
    actor.boss_history_clock=0.0
    actor.combo_visual_stage=""
    actor.trail_clock = 0.0
    actor.cooldowns.clear()
    for command in actor.ai_commands:
        actor.cooldowns[String(command.get("id", "attack"))] = float(command.get("start_cooldown", 0.0))
    actor.hp = actor.max_hp
    actor.knockback_velocity = 0.0
    if actor.ground_body != null:
        actor.ground_body.velocity = Vector2.ZERO
    actor._set_flash_amount(0.0)
    actor.global_position = actor.spawn_position
    actor.reset_physics_interpolation()
    actor.direction = 1
    actor.attack_direction = 1
    actor.attack_has_hit = false
    actor.active_attack = {}
    actor.state = "patrol"
    actor.attack_desire = 0.0
    actor.snare_timer = 0.0
    actor.clear_salt_mark()
    actor.interference_timer = 0.0
    actor.lure_timer = 0.0
    actor.trip_timer = 0.0
    actor.last_player_command = "none"
    actor.last_ai_decision = "patrol"
    actor.last_attack_id = ""
    actor.boss_tactic = "observe"
    actor.boss_tactic_timer = 0.0
    actor.boss_press_timer = 0.0
    actor.boss_reposition_target_x = actor.spawn_position.x
    actor.engage_announced = false
    actor.boss_phase_shift_played = false
    actor.memory_timer = 0.0
    actor.alarm_cooldown = 0.0
    actor.alarm_alerted = 0
    actor.alarm_search = false
    actor.support_cooldown = 0.0
    actor.reveal_hold = 0.0
    actor.role_cue_counts.clear()
    actor.state_timer = 0.0
    actor.contact_timer = 0.0
    actor.flash_timer = 0.0
    actor.modulate = Color.WHITE
    actor.monitoring = true
    actor.monitorable = true
    actor._clear_telegraph()
    actor._set_enemy_animation("idle")
    actor._pose_sprite("idle")
    actor._set_sprite_flip(false)
