extends RefCounted
## Running an attack: start, wind-up, aim, active frames, authored combos, recovery and contact damage.
## Moved out of enemy_actor.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.
const BOSS_STYLE := preload("res://scripts/boss_combat_style.gd")
const COMBAT_AUDIO := preload("res://scripts/enemy_combat_audio.gd")
const MINOR_SKILL_ART := preload("res://scripts/minor_enemy_skill_art.gd")
const BOSS_SKILL_ART := preload("res://scripts/boss_skill_art.gd")

static func try_start_attack(actor: Node, target: CharacterBody2D) -> bool:
    if actor.ai_commands.is_empty() or not actor._has_line_of_sight(target):
        return false
    var desire_threshold: float = actor._attack_desire_threshold()
    if actor._boss_tactical_enabled():
        actor._prepare_boss_tactic(target)
        if ["evade", "reposition", "observe"].has(actor.boss_tactic):
            actor.last_ai_decision = "tactic:" + actor.boss_tactic
            return false
        if actor.boss_tactic == "space" and actor.attack_desire < desire_threshold * 1.12:
            actor.last_ai_decision = "tactic:space"
            return false
    if actor.attack_desire < desire_threshold and actor._player_command_pressure(actor.last_player_command) < 0.85:
        actor.last_ai_decision = "build_desire"
        return false
    var candidates: Array = []
    for command in actor.ai_commands:
        var id := String(command.get("id", "attack"))
        if float(actor.cooldowns.get(id, 0.0)) <= 0.0 and actor._attack_can_reach_target(command, target):
            candidates.append(command)
    if candidates.is_empty():
        return false
    # Take turns: a crowd circles while two of them press, elites cut the line.
    actor.waiting_for_turn = not actor.is_boss and not actor.is_elite and actor._count_other_attackers(target) >= actor.MAX_SIMULTANEOUS_ATTACKERS
    if actor.waiting_for_turn:
        actor.last_ai_decision = "wait_turn"
        return false
    var chosen: Dictionary = actor._choose_attack(candidates, target)
    actor.attack_repeat_count = actor.attack_repeat_count + 1 if String(chosen.get("id", "")) == actor.last_attack_id else 0
    actor._face_target(target)
    actor._begin_attack(chosen)
    return true


static func begin_attack(actor: Node, command: Dictionary) -> void:
    if actor.dying or actor.is_queued_for_deletion() or not actor.world_residency_active():
        return
    if not actor.is_boss and String(command.get("type",""))=="combo" and not command.has("combo_beats") and actor._attack_animation_base(command) in actor.authored_combat_sequences and MINOR_SKILL_ART.ready_for(actor,command):
        command=command.duplicate(true)
        var beats:=clampi(ceili(float(command.get("active",.6))/.2),2,4)
        var starts: Array=[]
        for index in beats:starts.append(float(index)/beats)
        command.combo_beats=starts
        command.combo_beat_width=.65/beats
        command.combo_alternate_sides=false
    actor.attack_execution_serial += 1
    actor.active_attack = command
    actor.attack_recovery=false
    actor.recovery_velocity_x=0.0
    actor.attack_elapsed=0
    actor.trail_clock=0
    actor.attack_start_position=actor.global_position
    var target_node: CharacterBody2D = actor._target_player()
    actor.attack_target=target_node.global_position-Vector2(0,42) if target_node!=null else actor.global_position+Vector2(actor.direction*140,-24)
    actor._aim_attack(command, target_node as CharacterBody2D)
    actor.attack_has_hit = false
    actor.attack_direction = actor.direction
    actor.combo_origin_direction=actor.attack_direction
    actor.combo_visual_stage=""
    actor.boss_attack_history=actor.boss_target_history.duplicate()
    if String(command.get("boss_pattern",""))=="mirror_committed_shift":actor.boss_blink_destination=BOSS_STYLE.blink_destination(actor,command)
    actor.last_attack_id = String(command.get("id", "attack"))
    actor.last_ai_decision = "attack:" + actor.last_attack_id
    if actor._boss_tactical_enabled():
        actor.boss_tactic = "attack"
        actor.boss_tactic_timer = float(command.get("windup", 0.25)) + float(command.get("active", 0.16))
        actor.boss_press_timer = maxf(0.0, actor.boss_press_timer - float(command.get("desire_cost", 0.72)) * 0.35)
    actor.attack_desire = maxf(0.0, actor.attack_desire - float(command.get("desire_cost", 0.72 if actor.is_boss else 0.86)))
    actor.state = "windup"
    actor.state_timer = float(command.get("windup", 0.25))
    actor.cooldowns[String(command.get("id", "attack"))] = float(command.get("cooldown", 1.2))
    if not actor.original_visual:
        actor._set_enemy_animation(String(command.get("animation", "attack")), true)
    actor._pose_sprite("windup", command)
    actor._play_attack_sfx("windup")
    actor._show_telegraph(command)
    actor._spawn_windup_vfx(command)
    if String(command.get("boss_pattern",""))=="mirror_committed_shift":BOSS_SKILL_ART.spawn_arrival(actor,command,actor.boss_blink_destination)
    if not bool(command.get("blockable", true)) and ResourceLoader.exists("res://scripts/seal_presentation.gd"):
        var presentation := Node2D.new()
        presentation.set_script(load("res://scripts/seal_presentation.gd"))
        actor.add_child(presentation)
        presentation.cue_unblockable(actor.global_position + Vector2(0,-65))
        var cleanup = actor.create_tween()
        cleanup.tween_interval(1.0)
        cleanup.tween_callback(presentation.queue_free)
    if String(command.get("type","")) in ["beam","pool","rootline"]:
        actor._spawn_command_effects(command,true)


static func update_windup(actor: Node, delta: float) -> void:
    actor.state_timer -= delta
    actor._advance_pose_loop()
    if actor.state_timer <= 0.0:
        actor.state = "active"
        actor._stop_parade_layer()
        actor.state_timer = float(actor.active_attack.get("active", 0.16))
        if actor.active_attack.has("combo_beats"):
            actor._update_authored_combo(0.0)
        else:
            actor._pose_sprite("active", actor.active_attack)
            actor._play_attack_sfx("active")
            actor._spawn_attack_burst_vfx(actor.active_attack)
        if String(actor.active_attack.get("type","")) not in ["beam","pool","rootline"]:
            actor._spawn_command_effects(actor.active_attack,false)


static func aim_attack(actor: Node, command: Dictionary, target: CharacterBody2D) -> void:
    # Aimed shots and dives commit at wind-up start to a capped partial lead on
    # the player's current motion; the telegraph and the release then agree, so
    # a player who changes direction during the wind-up still slips the shot.
    # Area attacks keep the spot their warning shows.
    var attack_type := String(command.get("type", ""))
    if target == null or not (attack_type in ["projectile", "fan", "blink", "dive", "vault"]):
        return
    var windup := float(command.get("windup", 0.4))
    var travel := float(command.get("active", 0.3)) * 0.5
    if attack_type in ["projectile", "fan"]:
        travel = actor.global_position.distance_to(target.global_position) / maxf(60.0, float(command.get("projectile_speed", 220.0)))
    actor.attack_target = actor._lead_target(target, windup + travel, 140.0)


static func update_active(actor: Node, delta: float) -> void:
    # A zero step evaluates contact in place; only invalid or negative steps stop.
    if not is_finite(delta) or delta < 0.0: return
    delta = minf(delta, maxf(0.0, actor.state_timer))
    var previous_position = actor.global_position
    var attack_type := String(actor.active_attack.get("type", "melee"))
    actor.attack_elapsed+=delta
    var progress := clampf(actor.attack_elapsed/maxf(.01,float(actor.active_attack.get("active",.24))),0,1)
    var contact_live:=true
    if attack_type=="combo" and actor.active_attack.has("combo_beats"):contact_live=actor._update_authored_combo(progress)
    if actor.active_attack.has("contact_window"):
        var window: Array=actor.active_attack.contact_window
        contact_live=contact_live and progress>=float(window[0]) and progress<=float(window[1])
    if attack_type == "dive":
        actor.global_position=actor.attack_start_position.lerp(actor.attack_target,progress)
    elif attack_type == "vault":
        if String(actor.active_attack.get("boss_pattern",""))=="scissor_reversal":
            var distance:=float(actor.active_attack.get("lunge_speed",340))*float(actor.active_attack.get("active",.8))
            var x:=lerpf(0,-40,progress/.22) if progress<.22 else lerpf(-40,distance,(progress-.22)/.78)
            actor.global_position.x=actor.attack_start_position.x+actor.attack_direction*x
        else:actor.position.x+=actor.attack_direction*float(actor.active_attack.get("lunge_speed",240))*delta
        actor.global_position.y=actor.attack_start_position.y-sin(progress*PI)*float(actor.active_attack.get("jump_height",130))
    elif attack_type == "combo":
        if not actor.is_boss and actor.active_attack.has("combo_beats"):
            actor.position.x+=actor.combo_origin_direction*float(actor.active_attack.get("lunge_speed",125))*delta*(1.4 if contact_live else .25)
        elif contact_live:actor.position.x+=actor.attack_direction*float(actor.active_attack.get("lunge_speed",125))*delta
        if not actor.active_attack.has("combo_beats") and int(actor.attack_elapsed/.20)!=int((actor.attack_elapsed-delta)/.20):
            actor.attack_has_hit=false
            actor._play_combat_material(COMBAT_AUDIO.release_family(actor.kind,actor.locomotion,actor.active_attack),-12.0 if actor.is_boss else -15.0)
    elif attack_type == "lunge":
        actor.position.x += actor.attack_direction * float(actor.active_attack.get("lunge_speed", 220.0)) * delta
    elif attack_type == "retreat":
        actor.position.x -= actor.attack_direction * float(actor.active_attack.get("retreat_speed", 150.0)) * delta
    elif attack_type == "feint":
        var sway = sin(actor.state_timer * TAU * 8.0) * float(actor.active_attack.get("feint_sway", 78.0)) * delta
        actor.position.x += actor.attack_direction * sway
    actor._clamp_movement_bounds()
    actor.global_position = preload("res://scripts/enemy_motion_sweep.gd").constrain(actor, previous_position, actor.global_position)

    if contact_live and (attack_type in ["melee","aoe","lunge","retreat","feint","combo","guard","dive"] or (attack_type=="vault" and progress>.6)):
        actor._try_damage_player(actor.active_attack, previous_position)
    if actor.dying or actor.is_queued_for_deletion():
        return
    if bool(actor.active_attack.get("trail",false)):
        actor.trail_clock+=delta
        if actor.trail_clock>.16:
            actor.trail_clock=0
            actor._effect("pool",actor.global_position+Vector2(0,25),Vector2.ZERO,actor.active_attack,.35,1.1)

    actor.state_timer -= delta
    actor._advance_pose_loop()
    if actor.state_timer <= 0.0:
        actor.state = "recover"
        actor.attack_recovery=true
        actor.recovery_velocity_x=0.0
        if delta>0.0 and attack_type in ["lunge","dive","vault","retreat","combo"]:
            actor.recovery_velocity_x=clampf((actor.global_position.x-previous_position.x)/delta,-110.0 if actor.is_boss else -80.0,110.0 if actor.is_boss else 80.0)
        actor.state_timer = float(actor.active_attack.get("recover", 0.42))
        actor._pose_sprite("recover", actor.active_attack)
        actor._clear_telegraph()
        if attack_type=="vault":
            actor.global_position = preload("res://scripts/enemy_motion_sweep.gd").constrain(actor, actor.global_position, Vector2(actor.global_position.x, actor.attack_start_position.y))
            if actor.kind=="sunken_hammer_smith":actor._play_sfx("ch02_beat_water_hammer",-10.0)


static func update_authored_combo(actor: Node, progress: float) -> bool:
    var beat = BOSS_STYLE.combo_stage(actor.active_attack,progress)
    if String(beat.key)!=actor.combo_visual_stage:
        actor.combo_visual_stage=String(beat.key)
        BOSS_SKILL_ART.clear(actor)
        MINOR_SKILL_ART.clear(actor)
        if String(beat.phase)!="recover":
            var clip = actor.active_attack.duplicate(true)
            clip[String(beat.phase)]=maxf(.04,(float(beat.end)-float(beat.start))*float(actor.active_attack.active))
            var alternate:=bool(actor.active_attack.get("combo_alternate_sides",actor.is_boss))
            actor.attack_direction=actor.combo_origin_direction*(-1 if alternate and int(beat.index)%2==1 else 1)
            actor.direction=actor.attack_direction
            actor._set_sprite_flip(actor.direction<0)
            if bool(beat.contact):
                actor.attack_has_hit=false
                actor._play_attack_sfx("active")
                actor._spawn_attack_burst_vfx(actor.active_attack)
            actor._pose_sprite(String(beat.phase),clip)
    return bool(beat.contact)


static func update_recover(actor: Node, delta: float) -> void:
    if actor.attack_recovery and not actor.active_attack.is_empty():
        actor._prepare_recovery_action(delta)
        if actor.trip_timer<=0.0 and absf(actor.recovery_velocity_x)>.1:
            var previous = actor.global_position
            actor.global_position=preload("res://scripts/enemy_motion_sweep.gd").constrain(actor,previous,previous+Vector2(actor.recovery_velocity_x*minf(delta,maxf(0.0,actor.state_timer)),0))
            actor._clamp_movement_bounds()
            actor.recovery_velocity_x*=exp(-delta/.07)
    actor.state_timer -= delta
    actor._advance_pose_loop()
    if actor.state_timer <= 0.0:
        var finished_attack = actor.attack_recovery
        actor.attack_recovery=false
        actor.recovery_velocity_x=0.0
        actor.active_attack = {}
        actor.state = "patrol"
        if finished_attack:
            actor.completed_attack_count+=1
            actor.attack_completed_serial=actor.attack_execution_serial
        if actor._boss_tactical_enabled() and not actor._boss_behavior_enabled():
            var take_step = actor.locomotion!="stationary" and actor.completed_attack_count>0 and actor.completed_attack_count%3==0
            actor.boss_tactic = "reposition" if take_step or actor.boss_press_timer >= float(actor.ai_profile.get("max_press_time", 1.25)) * 0.72 else "guard"
            actor.boss_tactic_timer = actor._boss_tactic_duration(actor.boss_tactic, 0.38 if take_step else 0.34)
            var target: CharacterBody2D = actor._target_player()
            if actor.boss_tactic == "reposition" and target != null:
                actor.boss_reposition_target_x = actor._boss_reposition_x(target)
        actor._pose_sprite("idle")
        # Decide the next stance in the same physics step, with no mandatory
        # rendered idle frame between a completed recovery and a walk/attack.
        var next_target: CharacterBody2D = actor._target_player()
        if next_target != null:
            actor._update_patrol_or_aggro(0.0,next_target)


static func prepare_recovery_action(actor: Node, delta: float) -> void:
    var duration:=maxf(.01,float(actor.active_attack.get("recover",.42)))
    if actor.state_timer>duration*.5:return
    var target: CharacterBody2D = actor._target_player()
    if target==null or not actor._target_inside_leash(target) or not actor._has_line_of_sight(target):return
    if not actor._target_in_engage_window(target,float(actor.ai_profile.get("aggro_range",220.0 if not actor.is_boss else 460.0))):return
    # Plan during the last half, but never start the next attack before the
    # authored recovery/cooldown. A small remaining desire margin keeps a tell.
    var cap = actor._attack_desire_threshold()*.8
    if actor.attack_desire<cap:
        actor._update_attack_desire(delta,target,true)
        actor.attack_desire=minf(actor.attack_desire,cap)


static func sync_walk_cadence(actor: Node, delta: float, previous: Vector2) -> void:
    if delta<=0.0 or actor.locomotion!="ground" or actor.animated_sprite==null or not String(actor.animated_sprite.animation).begins_with("walk"):return
    var actual_speed:=absf(actor.global_position.x-previous.x)/delta
    if actual_speed<.1:
        actor._set_enemy_animation("idle")
    else:
        actor.animated_sprite.speed_scale=clampf(actual_speed/maxf(1.0,actor.speed),.28,1.5)


static func contact_attack_rect(actor: Node, command: Dictionary) -> Rect2:
    # Shared by the contact strike and its attached material. Artwork never
    # changes reach or creates a separate travelling damage object.
    var attack_type := String(command.get("type", "melee"))
    var dir = actor.attack_direction if actor._is_attack_state() else actor.direction
    var center = actor.global_position + Vector2(dir * float(command.get("offset", 44.0)), float(command.get("offset_y",-26.0)))
    var size := Vector2(float(command.get("hit_width", 76.0)), float(command.get("hit_height", 58.0)))
    if attack_type == "aoe":
        center = actor.global_position + Vector2(0.0, -24.0)
        size = Vector2(float(command.get("hit_width", 150.0)), float(command.get("hit_height", 88.0)))
    elif attack_type == "shockwave":
        center = actor.global_position + Vector2(dir * float(command.get("offset", 102.0)), -14.0)
        size = Vector2(float(command.get("hit_width", 220.0)), float(command.get("hit_height", 42.0)))
    elif attack_type == "retreat":
        center = actor.global_position + Vector2(dir * float(command.get("offset", 64.0)), -30.0)
        size = Vector2(float(command.get("hit_width", 118.0)), float(command.get("hit_height", 64.0)))
    elif attack_type == "feint":
        center = actor.global_position + Vector2(dir * float(command.get("offset", 54.0)), -34.0)
        size = Vector2(float(command.get("hit_width", 104.0)), float(command.get("hit_height", 72.0)))
    return Rect2(center - size * 0.5, size)


static func try_damage_player(actor: Node, command: Dictionary, previous_position: Vector2 = Vector2.INF) -> void:
    if actor.attack_has_hit or actor.dying or actor.is_queued_for_deletion() or not actor.world_residency_active():
        return
    var target: CharacterBody2D = actor._target_player()
    if target == null or target.is_queued_for_deletion() or (target.get("ui_input_locked") == true) or not actor._has_line_of_sight(target):
        return
    var attack_rect: Rect2 = actor.contact_attack_rect(command)
    var player_rect := Rect2(target.global_position - Vector2(24.0, 84.0), Vector2(48.0, 88.0))
    var crossed = previous_position.is_finite() and preload("res://scripts/enemy_motion_sweep.gd").contact(previous_position, actor.global_position, attack_rect, player_rect)
    if crossed or attack_rect.intersects(player_rect):
        actor.attack_has_hit = true
        var accepted = preload("res://scripts/damage_contact.gd").apply(target, int(command.get("damage", actor.damage)), actor.global_position, bool(command.get("blockable", true)))
        if accepted and not actor.dying and not actor.is_queued_for_deletion():actor._play_combat_material("impact",-12.0)
        if accepted and not actor.dying and not actor.is_queued_for_deletion() and bool(command.get("leech",false)):
            actor.hp=mini(actor.max_hp,actor.hp+1)
