extends RefCounted
## Melee attacks: starting a swing, hit resolution, gate strikes and hazard pogo, hit feedback, and the hitbox geometry.
## Moved out of player_controller.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.
const HAZARD_POGO := preload("res://scripts/hazard_pogo.gd")
const HOOK_ART := preload("res://scripts/player_hook_art.gd")

static func start_attack(player: Node, animation: StringName, allow_traversal_action: bool = true, queued_direction: Vector2 = Vector2.ZERO) -> void:
    player._clear_action_buffer()
    player.grapple_recovery_timer = 0.0
    if animation == &"attack_1" and player._crest() == "bell":
        animation = &"attack_2"
    player.active_skill.clear()
    player.current_attack = animation
    player.current_attack_direction = player._read_attack_direction() if queued_direction == Vector2.ZERO else queued_direction
    if animation == &"hook_throw":
        player.current_attack_direction = Vector2(float(player.facing), 0.0)
    player.attack_started_grounded = player.is_on_floor()
    player.run_attack_pose = animation == &"attack_1" and player.is_on_floor() and absf(player.current_attack_direction.y) <= 0.5 \
        and absf(player.velocity.x) >= player.speed * player.RUN_ATTACK_MIN_SPEED_RATIO and player._has_pose(&"run_attack")
    if animation == &"hook_throw":
        player.attack_duration = 0.42
        player.attack_damage = 1
        player.attack_range = 150.0
        player.attack_height = 92.0
        player.attack_forward_offset = 72.0
    elif animation == &"attack_2":
        player.attack_duration = 0.48
        player.attack_damage = 2
        player.attack_range = 126.0
        player.attack_height = 108.0
        player.attack_forward_offset = 54.0
    else:
        player.attack_duration = 0.34
        player.attack_damage = 1
        player.attack_range = 86.0
        player.attack_height = 92.0
        player.attack_forward_offset = 48.0
    if absf(player.current_attack_direction.x) > 0.1:
        player.velocity.x += player.current_attack_direction.x * (player.attack_lunge if player.is_on_floor() else player.attack_lunge * 0.45)
    elif player.current_attack_direction.y < -0.5:
        player.velocity.y = minf(player.velocity.y, -110.0)
    if player._crest() == "bell" and player._seal_mechanism_ready() and animation == &"attack_2" and player.bell_pressure > 0:
        player.attack_damage += player.bell_pressure
    player.attack_damage = maxi(1, player.attack_damage + int(player.build_profile.attack_bonus)) if player.build_profile.has("attack_bonus") else maxi(1, int(ceil(float(player.attack_damage) * float(player.build_profile.get("attack_damage_mult", 1.0)))))
    var reach := float(player.build_profile.get("attack_reach_mult", 1.0))
    player.attack_range *= reach
    player.attack_height *= reach
    player.attack_forward_offset *= reach
    player.attack_duration /= maxf(0.25, float(player.build_profile.get("attack_speed_mult", 1.0)))
    player.attack_windup = minf(0.10 if animation == &"attack_2" else 0.06, player.attack_duration * 0.25)
    player.attack_active_time = player.attack_duration * 0.52
    player.traversal_downstrike_active = allow_traversal_action and player.current_attack_direction.y > 0.5 and animation != &"hook_throw" and player.thorn_downstrike_unlocked and not player.is_on_floor()
    if player.traversal_downstrike_active:
        player.velocity.y = maxf(player.velocity.y, 760.0)
        player.ability_action.emit("thorn_downstrike", player.global_position, Vector2.DOWN)
    player.attack_vfx_started = false
    player.attack_timer = player.attack_duration
    player.enemy_contact_guard_timer = maxf(player.enemy_contact_guard_timer, player.enemy_contact_guard_time)
    player.hit_targets.clear()
    player.attack_pogo_paid = false
    player.gate_strike_paid = false
    player.hook_latch_played = false
    player.hook_reel_played = false
    player._sync_attack_hitbox()
    player._play(animation, true)
    if animation == &"hook_throw":
        player._play_sfx("hook", -6.0)
    elif animation != &"attack_2":
        player._play_attack_swing_sfx()


static func attack_line_clear(player: Node, target: Vector2) -> bool:
    # Terrain occupies collision bit 1 (the same layer used by projectile and
    # placement rays). Actor hurtboxes must not turn a blocked melee ray into a
    # hit-through-wall result.
    var query = PhysicsRayQueryParameters2D.create(player.global_position + Vector2(0, -42), target, 1, [player.get_rid()])
    query.collide_with_areas = false
    var hit = player.get_world_2d().direct_space_state.intersect_ray(query)
    return hit.is_empty()


static func update_attack(player: Node, delta: float) -> void:
    if player.attack_timer <= 0.0:
        player.attack_shape.disabled = true
        return

    if not is_finite(delta) or delta <= 0.0: return
    var previous = player.attack_duration - player.attack_timer
    player.attack_timer = maxf(0.0, player.attack_timer - delta)
    var elapsed = player.attack_duration - player.attack_timer
    var window := preload("res://scripts/action_time_window.gd")
    var crossed: bool = window.intersects(previous, elapsed, player.attack_windup, player.attack_active_time)
    var active: bool = player.attack_timer > 0 and window.contains(elapsed, player.attack_windup, player.attack_active_time)
    var special = not player.active_skill.is_empty() and String(player.active_skill.get("kind", "melee")) not in ["melee", "thrust", "crosscut"]
    if crossed and not player.attack_vfx_started:
        player.attack_vfx_started = true
        # The heavy strike's impact peaks at once: play it with the strike, not the windup.
        if player.current_attack == &"attack_2" and player.active_skill.is_empty():
            player._play_sfx("skill", -7.0)
        if not player.active_skill.is_empty():
            player._seal_present(String(player.active_skill.get("id", "cleave")), "active")
        if not special: player._spawn_attack_vfx(player.current_attack)
    if crossed and special and not player.skill_effect_started:
        player.skill_effect_started = true
        player._apply_special_skill()
    player.attack_shape.disabled = not active or special
    if crossed and not special:
        if String(player.active_skill.get("id", "")) == "cleave":
            var progress := clampf((elapsed - player.attack_windup) / maxf(0.01, player.attack_active_time), 0.0, 1.0)
            var displacement := 64.0 * progress
            if displacement > player.skill_displacement_done:
                player.move_and_collide(Vector2(player.facing * (displacement - player.skill_displacement_done), 0))
                player.skill_displacement_done = displacement
        player._apply_attack_hits()
        if player.traversal_downstrike_active:
            for terrain in player.get_tree().get_nodes_in_group("fragile_terrain"):
                if terrain is Node2D and terrain.has_method("receive_ability_action") and terrain.global_position.distance_to(player.global_position) < 100.0:
                    terrain.receive_ability_action("thorn_downstrike", player.global_position, Vector2.DOWN)
    if not player.active_skill.is_empty() and elapsed >= player.attack_windup + player.attack_active_time and not player.seal_recovery_shown:
        player.seal_recovery_shown = true
        player._seal_present(String(player.active_skill.get("id", "cleave")), "recovery")


static func apply_attack_hits(player: Node) -> void:
    var attack_size: Vector2 = player._attack_size()
    var center = player.global_position + player._attack_center_offset()
    var attack_rect := Rect2(center - attack_size * 0.5, attack_size)
    for node in player.get_tree().get_nodes_in_group("enemy"):
        if not is_instance_valid(node) or not node.has_method("take_hit"):
            continue
        if node.has_method("world_residency_active") and not node.world_residency_active():
            continue
        var id := node.get_instance_id()
        if player.hit_targets.has(id):
            continue
        var hurtbox := Rect2(node.global_position - Vector2(34, 38), Vector2(68, 76))
        if node.has_method("get_hurtbox_rect"):
            hurtbox = node.get_hurtbox_rect()
        if attack_rect.intersects(hurtbox) and player._attack_line_clear(hurtbox.get_center()):
            player.hit_targets[id] = true
            var target_hp_before := int(node.get("hp"))
            var practice_contact: bool=node.has_meta("seal_training_target") or node.has_meta("tool_training_target")
            var contact_call: int = int(node.contact_visual_call_serial()) + 1 if node.has_method("contact_visual_call_serial") else -1
            node.take_hit(player.attack_damage, player._attack_hit_direction())
            var accepted := is_instance_valid(node) and int(node.get("hp")) < target_hp_before
            if not accepted:
                continue
            if not player.active_skill.is_empty() and node.has_method("report_skill_contact"):
                node.report_skill_contact(player,String(player.active_skill.get("id","")),player.last_skill_cast_serial)
            if player.current_attack == &"hook_throw" and not player.hook_latch_played:
                # 钩索"挂住"=钩击命中确认（与 hitstop 同拍）；每次挥钩仅播一次。
                player.hook_latch_played = true
                player._play_sfx("hook_latch", -6.0)
                HOOK_ART.latch(player, hurtbox.get_center())
                # ch2 beat `echo_hook`（manifest ch02_beat_02）：雨铸运河钩击命中后
                # 叠一拍水声回响（金属声后接水面回声，采样内已含节拍延迟）。
                if player.footstep_material == "copper":
                    player._play_sfx("ch02_beat_echo_hook", -10.0)
            var killed := not is_instance_valid(node) or int(node.get("hp")) <= 0
            var observed_boss: Variant=node.get("is_boss")
            player.combat_observed.emit({"kind":"strike","damage":maxi(0,target_hp_before-maxi(0,int(node.get("hp")))),"killed":killed,
                "boss":observed_boss is bool and observed_boss,"practice":node.has_meta("seal_training_target") or node.has_meta("tool_training_target")})
            if player.active_skill.is_empty():
                player.gain_energy(player.energy_per_hit,practice_contact)
                player._basic_seal_hit()
            elif String(player.active_skill.get("id", "")) == "crosscut" and bool(player.active_skill.get("empowered", false)) and not player.crosscut_refund_paid:
                player.gain_energy(mini(10, maxi(0, int(player.active_skill.get("energy_cost", 30)) - 1)),practice_contact)
                player.crosscut_refund_paid = true
            if player.active_skill.is_empty() and player._crest() == "bell" and player._seal_mechanism_ready() and player.bell_pressure > 0 and player.current_attack == &"attack_2":
                if node.has_method("apply_stagger"):
                    node.apply_stagger(player.bell_pressure * 0.3)
                player.bell_pressure = 0
            if not player.attack_pogo_paid:
                player._apply_downslash_bounce(node.global_position)
                player.attack_pogo_paid = true
            player._trigger_hit_feedback(killed)
            player._spawn_hit_confirm_vfx(node.global_position, player.current_attack, node, contact_call)
    player._try_gate_strike(attack_rect)
    player._try_hazard_pogo(attack_rect)


static func try_gate_strike(player: Node, attack_rect: Rect2) -> void:
    if player.gate_strike_paid or player.traversal_downstrike_active or player.current_attack == &"hook_throw":
        return
    for gate in player.get_tree().get_nodes_in_group("fragile_terrain"):
        if not gate is Node2D or not gate.has_meta("gate_size") or not gate.is_inside_tree():
            continue
        var size: Vector2 = gate.get_meta("gate_size")
        var rect := Rect2(gate.global_position - size * 0.5, size)
        if not attack_rect.intersects(rect):
            continue
        player.gate_strike_paid = true
        var point := Vector2(clampf(attack_rect.get_center().x, rect.position.x, rect.end.x),
            clampf(attack_rect.get_center().y, rect.position.y, rect.end.y))
        player._play_sfx("downstrike_crack", -6.0)
        player.gate_struck.emit(gate, point)
        return


static func try_hazard_pogo(player: Node, attack_rect: Rect2) -> void:
    if player.attack_pogo_paid or player.current_attack == &"hook_throw" or player.current_attack_direction.y <= 0.5:
        return
    for node in player.get_tree().get_nodes_in_group(HAZARD_POGO.GROUP):
        if not is_instance_valid(node) or not node is Node2D or not node.is_inside_tree():
            continue
        var surface: Rect2 = HAZARD_POGO.surface_rect(node)
        if surface.size == Vector2.ZERO or not attack_rect.intersects(surface):
            continue
        var contact := Vector2(clampf(player.global_position.x, surface.position.x, surface.end.x), surface.position.y + 1.0)
        if not player._attack_line_clear(contact):
            continue
        player._apply_downslash_bounce(contact)
        player.attack_pogo_paid = true
        player.hazard_pogo_guard_timer = HAZARD_POGO.CONTACT_GRACE
        player._spawn_hit_confirm_vfx(contact, player.current_attack)
        return


static func trigger_hit_feedback(player: Node, killed: bool) -> void:
    if player.feel == null:
        return
    var is_downslash = player.current_attack != &"hook_throw" and player.current_attack_direction.y > 0.5
    var stop_ms := 45.0
    var trauma := 0.16
    if player.current_attack == &"attack_2":
        stop_ms = 120.0 if killed else 75.0
        trauma = 0.30
    elif is_downslash:
        stop_ms = 50.0 if killed else 40.0
        trauma = 0.12
    elif player.current_attack == &"hook_throw":
        stop_ms = 50.0
        trauma = 0.14
    elif killed:
        stop_ms = 90.0
    player.feel.hitstop(stop_ms)
    if player.feel.has_method("melee_rumble"):
        player.feel.melee_rumble(player.current_attack, killed, player.current_attack_direction)
    player._add_trauma(trauma)
    if killed:
        player._flash_screen(Color.WHITE, 0.08, 1)


static func sync_attack_hitbox(player: Node) -> void:
    player.attack_hitbox.position = player._attack_center_offset()
    var rectangle = player.attack_shape.shape as RectangleShape2D
    if rectangle != null:
        rectangle.size = player._attack_size()


static func read_attack_direction(player: Node) -> Vector2:
    if not player.ui_input_locked and Input.is_action_pressed("aim_down"):
        return Vector2.DOWN
    if not player.ui_input_locked and Input.is_action_pressed("aim_up"):
        return Vector2.UP
    var input_axis: float = player._move_axis()
    if absf(input_axis) > 0.1:
        return Vector2(signf(input_axis), 0.0)
    return Vector2(float(player.facing), 0.0)


static func move_axis(player: Node) -> float:
    if player.ui_input_locked:
        return 0.0
    return Input.get_axis("move_left", "move_right")


static func attack_size(player: Node) -> Vector2:
    if player.current_attack != &"hook_throw" and absf(player.current_attack_direction.y) > 0.5:
        if player.current_attack == &"attack_2":
            return Vector2(104.0, 144.0)
        return Vector2(82.0, 120.0)
    return Vector2(player.attack_range, player.attack_height)


static func attack_center_offset(player: Node) -> Vector2:
    if player.current_attack != &"hook_throw" and player.current_attack_direction.y < -0.5:
        return Vector2(0.0, -102.0)
    if player.current_attack != &"hook_throw" and player.current_attack_direction.y > 0.5:
        return Vector2(0.0, 18.0)
    return Vector2(player.attack_forward_offset * player.facing, -42.0)


static func attack_hit_direction(player: Node) -> int:
    if absf(player.current_attack_direction.x) > 0.1:
        return player.signi(player.current_attack_direction.x)
    return player.facing


static func apply_downslash_bounce(player: Node, _target_position: Vector2) -> void:
    if player.current_attack == &"hook_throw" or player.current_attack_direction.y <= 0.5:
        return
    player.velocity.y = player.downslash_bounce_velocity * float(player.build_profile.get("downstrike_bounce_mult", 1.0))
    player.dash_timer = 0.0
    player.dash_cooldown = minf(player.dash_cooldown, 0.12)
    player.coyote_timer = 0.0
    player.jump_buffer_timer = 0.0
    player.enemy_contact_guard_timer = maxf(player.enemy_contact_guard_timer, player.enemy_contact_guard_time)
    player._play_pogo_squash()
    player.pogo_chain = mini(player.pogo_chain + 1, 4)
    # pogo=敲钟（音频规格 §4.2）：D5 小铜铃自产音源，连击保留半音阶 pitch 爬升。
    player._play_sfx("pogo", -6.0, pow(2.0, float(player.pogo_chain) / 12.0))
    # ch4 beat `thorn_downstrike`（manifest ch04_beat_01）：断弦温室（fiber 主题）
    # 下劈命中反弹时叠短促木质裂声。
    if player.footstep_material == "fiber":
        player._play_sfx("ch04_beat_thorn_downstrike", -11.0)


static func play_pogo_squash(player: Node) -> void:
    if player.sprite == null:
        return
    player.sprite.scale = player.sprite_base_scale * Vector2(0.86, 1.14)
    var tween = player.create_tween()
    tween.tween_interval(0.033)
    tween.tween_property(player.sprite, "scale", player.sprite_base_scale * Vector2(1.12, 0.84), 0.033)
    tween.tween_property(player.sprite, "scale", player.sprite_base_scale, 0.10).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
