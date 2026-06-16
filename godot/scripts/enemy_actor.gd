extends Area2D

signal died(spawn_id: String, is_boss: bool, kind: String)

const SFX := {
    "enemy_hit": "res://assets/audio/sfx/enemy_hit.ogg",
    "heavy_hit": "res://assets/audio/sfx/heavy_hit.ogg",
    "enemy_windup": "res://assets/audio/sfx/player_hook.ogg",
    "enemy_attack": "res://assets/audio/sfx/enemy_hit.ogg",
    "boss_windup": "res://assets/audio/sfx/heavy_hit.ogg",
    "boss_attack": "res://assets/audio/sfx/player_attack.ogg"
}

@export var spawn_id: String = ""
@export var kind: String = "moss_larva"
@export var patrol_distance: float = 90.0
@export var speed: float = 42.0
@export var hp: int = 2
@export var damage: int = 1
@export var is_boss: bool = false
@export var asset_path: String = ""
@export var leash_radius: float = 240.0
var sprite_parts: Array = []
var sprite_region: Array = []
var sprite_regions: Dictionary = {}
var visual_scale: float = 0.0
var visual_offset := Vector2.ZERO
var visual_modulate := Color.WHITE
var sprite_faces_left := false
var sprite_base_position := Vector2.ZERO
var sprite_base_scale := Vector2.ONE
var body_size := Vector2.ZERO
var hurtbox_size := Vector2.ZERO
var hurtbox_offset := Vector2.ZERO

var start_x: float
var spawn_position := Vector2.ZERO
var max_hp: int = 2
var direction: int = 1
var attack_direction: int = 1
var arena_min_x := -INF
var arena_max_x := INF
var platform_min_x := -INF
var platform_max_x := INF
var flash_timer: float = 0.0
var contact_timer: float = 0.0
var state_timer: float = 0.0
var attack_has_hit := false
var ai_profile: Dictionary = {}
var ai_commands: Array = []
var cooldowns: Dictionary = {}
var active_attack: Dictionary = {}
var state := "patrol"
var attack_desire: float = 0.0
var last_player_command := "none"
var last_ai_decision := "patrol"
var last_attack_id := ""
var command_read_count := 0
var sprite: Node2D
var animated_sprite: AnimatedSprite2D
var telegraph: Polygon2D


func _ready() -> void:
    add_to_group("enemy")
    start_x = global_position.x
    spawn_position = global_position
    monitoring = true
    monitorable = true
    body_entered.connect(_on_body_entered)
    _build_shape()
    _build_sprite()


func _physics_process(delta: float) -> void:
    _tick_timers(delta)
    var target := _target_player()
    if target != null and not _is_attack_state():
        _face_target(target)
    if target != null:
        last_player_command = _read_player_command(target)
    else:
        last_player_command = "none"

    if state == "windup":
        _update_windup(delta)
    elif state == "active":
        _update_active(delta)
    elif state == "recover":
        _update_recover(delta)
    else:
        _update_patrol_or_aggro(delta, target)


func configure(data: Dictionary, sprite_path: String, boss_flag: bool = false, profile: Dictionary = {}) -> void:
    spawn_id = String(data.get("id", "enemy"))
    kind = String(data.get("kind", "moss_larva"))
    hp = int(data.get("hp", 2))
    max_hp = hp
    damage = int(data.get("damage", 1))
    patrol_distance = float(data.get("patrol", 80.0))
    is_boss = boss_flag
    speed = float(profile.get("move_speed", 34.0 if is_boss else 42.0))
    leash_radius = float(data.get("leash_radius", profile.get("leash_radius", 9999.0 if is_boss else 240.0)))
    asset_path = String(data.get("sprite", sprite_path))
    sprite_parts = data.get("sprite_parts", [])
    sprite_region = data.get("sprite_region", [])
    sprite_regions = data.get("sprite_regions", {})
    visual_scale = float(data.get("visual_scale", 0.0))
    visual_offset = _vec2(data.get("visual_offset", [0, 0]))
    body_size = _vec2_or(data.get("body_size", []), Vector2(132, 128) if is_boss else Vector2(50, 46))
    hurtbox_size = _vec2_or(data.get("hurtbox_size", []), Vector2(142, 144) if is_boss else Vector2(58, 56))
    hurtbox_offset = _vec2_or(data.get("hurtbox_offset", []), Vector2(0, -40) if is_boss else Vector2(0, -18))
    sprite_faces_left = bool(data.get("sprite_faces_left", false))
    if data.has("visual_modulate"):
        visual_modulate = Color.html("#" + String(data.get("visual_modulate", "ffffff")))
    if data.has("arena_min_x"):
        arena_min_x = float(data.get("arena_min_x", -INF))
    if data.has("arena_max_x"):
        arena_max_x = float(data.get("arena_max_x", INF))
    ai_profile = profile
    ai_commands = profile.get("attacks", [])
    for command in ai_commands:
        cooldowns[String(command.get("id", "attack"))] = float(command.get("start_cooldown", 0.0))


func take_hit(amount: int, hit_direction: int) -> void:
    _play_sfx("heavy_hit" if amount >= 2 or is_boss else "enemy_hit", -6.0)
    _spawn_hit_spark(hit_direction)
    _set_enemy_animation("hurt")
    _pose_sprite("hurt")
    hp -= amount
    position.x += hit_direction * (9.0 if is_boss else 14.0)
    _clamp_movement_bounds()
    modulate = Color(1.0, 0.72, 0.55)
    flash_timer = 0.12
    if not is_boss and hp > 0:
        state = "recover"
        state_timer = 0.16
        _clear_telegraph()
    if hp <= 0:
        _set_enemy_animation("death")
        _pose_sprite("death")
        _clear_telegraph()
        died.emit(spawn_id, is_boss, kind)
        queue_free()


func get_hurtbox_rect() -> Rect2:
    var size := hurtbox_size if hurtbox_size != Vector2.ZERO else (Vector2(142, 144) if is_boss else Vector2(58, 56))
    var center := global_position + (hurtbox_offset if hurtbox_offset != Vector2.ZERO else (Vector2(0.0, -40.0) if is_boss else Vector2(0.0, -18.0)))
    return Rect2(center - size * 0.5, size)


func get_ai_debug_state() -> Dictionary:
    return {
        "ai_command_total": ai_commands.size(),
        "attack_desire": attack_desire,
        "attack_desire_threshold": _attack_desire_threshold(),
        "last_player_command": last_player_command,
        "last_ai_decision": last_ai_decision,
        "last_attack_id": last_attack_id,
        "reads_player_commands": true,
        "command_read_count": command_read_count,
        "aggro_vertical_tolerance": float(ai_profile.get("aggro_vertical_tolerance", 190.0 if is_boss else 118.0)),
        "attack_vertical_tolerance": float(ai_profile.get("attack_vertical_tolerance", 132.0 if is_boss else 72.0)),
        "max_attack_range": _max_attack_range(false)
    }


func _tick_timers(delta: float) -> void:
    contact_timer = maxf(0.0, contact_timer - delta)
    if flash_timer > 0.0:
        flash_timer -= delta
        if flash_timer <= 0.0:
            modulate = Color.WHITE
    for key in cooldowns.keys():
        cooldowns[key] = maxf(0.0, float(cooldowns[key]) - delta)


func _is_attack_state() -> bool:
    return state == "windup" or state == "active" or state == "recover"


func _clamp_to_arena() -> void:
    if arena_min_x >= arena_max_x:
        return
    global_position.x = clampf(global_position.x, arena_min_x, arena_max_x)


func _clamp_movement_bounds() -> void:
    _clamp_to_arena()
    if is_boss:
        return
    var min_x := -INF
    var max_x := INF
    if leash_radius > 0.0:
        min_x = spawn_position.x - leash_radius
        max_x = spawn_position.x + leash_radius
    if platform_min_x < platform_max_x:
        min_x = maxf(min_x, platform_min_x)
        max_x = minf(max_x, platform_max_x)
    if min_x >= max_x:
        return
    var clamped_x := clampf(global_position.x, min_x, max_x)
    if not is_equal_approx(clamped_x, global_position.x):
        var next_position := global_position
        next_position.x = clamped_x
        global_position = next_position
        direction *= -1
        _set_sprite_flip(direction < 0)


func set_platform_movement_bounds(min_x: float, max_x: float) -> void:
    platform_min_x = min_x
    platform_max_x = max_x


func reset_for_respawn() -> void:
    hp = max_hp
    global_position = spawn_position
    direction = 1
    attack_direction = 1
    attack_has_hit = false
    active_attack = {}
    state = "patrol"
    attack_desire = 0.0
    last_player_command = "none"
    last_ai_decision = "patrol"
    last_attack_id = ""
    state_timer = 0.0
    contact_timer = 0.0
    flash_timer = 0.0
    modulate = Color.WHITE
    monitoring = true
    monitorable = true
    _clear_telegraph()
    _set_enemy_animation("idle")
    _pose_sprite("idle")
    _set_sprite_flip(false)


func _target_player() -> CharacterBody2D:
    var nearest: CharacterBody2D = null
    var nearest_distance := INF
    for node in get_tree().get_nodes_in_group("player"):
        var candidate := node as CharacterBody2D
        if candidate == null or not is_instance_valid(candidate):
            continue
        var distance := global_position.distance_to(candidate.global_position)
        if distance < nearest_distance:
            nearest = candidate
            nearest_distance = distance
    return nearest


func _face_target(target: Node2D) -> void:
    if target.global_position.x == global_position.x:
        return
    direction = -1 if target.global_position.x < global_position.x else 1
    _set_sprite_flip(direction < 0)


func _update_patrol_or_aggro(delta: float, target: CharacterBody2D) -> void:
    var aggro_range := float(ai_profile.get("aggro_range", 220.0 if not is_boss else 460.0))
    var engaged := target != null and _target_inside_leash(target) and _target_in_engage_window(target, aggro_range)
    _update_attack_desire(delta, target, engaged)
    if _should_return_to_spawn(target, aggro_range):
        last_ai_decision = "return"
        _return_to_spawn(delta)
        return
    if engaged:
        if _try_start_attack(target):
            return
        _move_in_combat(delta, target)
        return
    last_ai_decision = "patrol"
    _patrol(delta)


func _move_in_combat(delta: float, target: CharacterBody2D) -> void:
    var preferred := float(ai_profile.get("preferred_range", 54.0))
    var dx := target.global_position.x - global_position.x
    var distance := absf(dx)
    var moved := false
    var attack_range := _max_attack_range(false)
    var pressure_threshold := _attack_desire_threshold()
    var pressured := attack_desire >= pressure_threshold * 0.65
    var desired := preferred
    if pressured and attack_range > 0.0:
        desired = minf(preferred, maxf(34.0, attack_range * 0.70))
    var chase_speed := speed * (float(ai_profile.get("pressure_speed_multiplier", 1.18)) if pressured else 1.0)
    if attack_range > 0.0 and distance > attack_range - 10.0:
        position.x += signf(dx) * chase_speed * delta
        moved = true
        last_ai_decision = "press"
    elif distance > desired + 14.0:
        position.x += signf(dx) * chase_speed * delta
        moved = true
        last_ai_decision = "advance"
    elif distance < desired - 18.0 and not pressured:
        position.x -= signf(dx) * speed * 0.55 * delta
        moved = true
        last_ai_decision = "space"
    else:
        last_ai_decision = "threaten"
    _clamp_movement_bounds()
    _set_enemy_animation("walk" if moved else "idle")


func _patrol(delta: float) -> void:
    position.x += direction * speed * 0.72 * delta
    _set_enemy_animation("walk")
    if absf(global_position.x - start_x) > patrol_distance:
        direction *= -1
        _set_sprite_flip(direction < 0)
    _clamp_movement_bounds()


func _target_inside_leash(target: CharacterBody2D) -> bool:
    if target == null or is_boss or leash_radius <= 0.0:
        return true
    var target_from_spawn := absf(target.global_position.x - spawn_position.x)
    if target_from_spawn <= leash_radius:
        return true
    var attack_margin := float(ai_profile.get("leash_attack_margin", 42.0))
    return target_from_spawn <= leash_radius + attack_margin and _target_in_any_attack_window(target)


func _should_return_to_spawn(target: CharacterBody2D, aggro_range: float) -> bool:
    if is_boss or leash_radius <= 0.0:
        return false
    if absf(global_position.x - spawn_position.x) > leash_radius:
        return true
    if target == null:
        return false
    if _target_inside_leash(target) and _target_in_any_attack_window(target):
        return false
    var target_near_enemy := _target_in_engage_window(target, aggro_range)
    return target_near_enemy and not _target_inside_leash(target)


func _return_to_spawn(delta: float) -> void:
    var dx := spawn_position.x - global_position.x
    if absf(dx) <= 5.0:
        global_position = spawn_position
        direction = 1
        _set_sprite_flip(false)
        _set_enemy_animation("idle")
        return
    direction = -1 if dx < 0.0 else 1
    position.x += direction * speed * delta
    _clamp_movement_bounds()
    _set_sprite_flip(direction < 0)
    _set_enemy_animation("walk")


func _target_in_engage_window(target: CharacterBody2D, aggro_range: float) -> bool:
    if target == null:
        return false
    var dx := absf(target.global_position.x - global_position.x)
    var dy := absf(target.global_position.y - global_position.y)
    var vertical_tolerance := float(ai_profile.get("aggro_vertical_tolerance", 190.0 if is_boss else 118.0))
    return dx <= aggro_range and dy <= vertical_tolerance


func _target_in_any_attack_window(target: CharacterBody2D) -> bool:
    if target == null:
        return false
    for command in ai_commands:
        if command is Dictionary and _attack_can_reach_target(command, target, true):
            return true
    return false


func _attack_can_reach_target(command: Dictionary, target: CharacterBody2D, ignore_cooldown: bool = false) -> bool:
    if target == null:
        return false
    var id := String(command.get("id", "attack"))
    if not ignore_cooldown and float(cooldowns.get(id, 0.0)) > 0.0:
        return false
    var dx := absf(target.global_position.x - global_position.x)
    var dy := absf(target.global_position.y - global_position.y)
    var max_range := float(command.get("range", 70.0))
    var min_range := float(command.get("min_range", 0.0))
    return dx <= max_range and dx >= min_range and dy <= _command_vertical_tolerance(command)


func _command_vertical_tolerance(command: Dictionary) -> float:
    var fallback := maxf(72.0, float(command.get("hit_height", 58.0)) * 0.95)
    if is_boss:
        fallback = maxf(132.0, float(command.get("hit_height", 110.0)) * 0.98)
    return float(command.get("vertical_tolerance", ai_profile.get("attack_vertical_tolerance", fallback)))


func _max_attack_range(ready_only: bool = false) -> float:
    var result := 0.0
    for command in ai_commands:
        if not (command is Dictionary):
            continue
        var data: Dictionary = command
        if ready_only and float(cooldowns.get(String(data.get("id", "attack")), 0.0)) > 0.0:
            continue
        result = maxf(result, float(data.get("range", 0.0)))
    if result <= 0.0 and ready_only:
        return _max_attack_range(false)
    return result


func _attack_desire_threshold() -> float:
    return float(ai_profile.get("attack_desire_threshold", 0.52 if is_boss else 0.68))


func _update_attack_desire(delta: float, target: CharacterBody2D, engaged: bool) -> void:
    if target == null or not engaged:
        attack_desire = maxf(0.0, attack_desire - delta * float(ai_profile.get("attack_desire_decay", 0.78)))
        return
    var aggro_range := maxf(1.0, float(ai_profile.get("aggro_range", 220.0 if not is_boss else 460.0)))
    var dx := absf(target.global_position.x - global_position.x)
    var close_pressure := clampf((aggro_range - dx) / aggro_range, 0.0, 1.0) * 0.72
    var command_pressure := _player_command_pressure(last_player_command)
    var gain := float(ai_profile.get("attack_desire_gain", 1.12 if is_boss else 0.96))
    var max_desire := float(ai_profile.get("attack_desire_max", 2.4 if is_boss else 1.8))
    attack_desire = clampf(attack_desire + delta * (gain + close_pressure + command_pressure), 0.0, max_desire)


func _player_command_pressure(command: String) -> float:
    if ["slash_forward", "slash_up", "slash_down", "skill"].has(command):
        return 1.10
    if ["dash_toward", "hook"].has(command):
        return 0.88
    if ["heal", "falling_attack"].has(command):
        return 0.72
    if ["jump", "fall", "run_toward"].has(command):
        return 0.28
    return 0.0


func _attack_candidate_score(command: Dictionary, target: CharacterBody2D) -> float:
    var score := float(command.get("priority", 1.0)) * 10.0
    var attack_type := String(command.get("type", "melee"))
    var dx := absf(target.global_position.x - global_position.x)
    var max_range := maxf(1.0, float(command.get("range", 70.0)))
    score += clampf(1.0 - absf(max_range * 0.55 - dx) / max_range, 0.0, 1.0) * 2.2
    if ["slash_forward", "dash_toward", "hook"].has(last_player_command):
        if attack_type == "retreat" or attack_type == "aoe" or attack_type == "melee":
            score += 3.0
    elif ["slash_down", "jump", "falling_attack"].has(last_player_command):
        if attack_type == "aoe" or attack_type == "shockwave":
            score += 2.4
    elif last_player_command == "heal":
        if attack_type == "lunge" or attack_type == "shockwave":
            score += 2.8
    elif attack_type == "lunge":
        score += 1.0
    return score


func _read_player_command(target: CharacterBody2D) -> String:
    command_read_count += 1
    if _float_property(target, "death_timer", 0.0) > 0.0:
        return "dead"
    var attack_timer_value := _float_property(target, "attack_timer", 0.0)
    if attack_timer_value > 0.0:
        var attack_name := String(target.get("current_attack"))
        var attack_vector := _vector2_property(target, "current_attack_direction", Vector2(float(_player_facing(target)), 0.0))
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
    if _float_property(target, "dash_timer", 0.0) > 0.0:
        return "dash_toward" if signf(velocity_value.x) == -float(direction) else "dash_away"
    if _float_property(target, "heal_cooldown", 0.0) > 0.0:
        return "heal"
    if velocity_value.y > 180.0 and target.global_position.y < global_position.y - 26.0:
        return "falling_attack"
    if velocity_value.y < -120.0:
        return "jump"
    if velocity_value.y > 140.0:
        return "fall"
    if absf(velocity_value.x) > 120.0:
        return "run_toward" if signf(velocity_value.x) == -float(direction) else "run_away"
    return "idle"


func _player_facing(target: CharacterBody2D) -> int:
    var value := int(_float_property(target, "facing", 1.0))
    return -1 if value < 0 else 1


func _float_property(node: Object, key: String, fallback: float) -> float:
    var value = node.get(key)
    if value == null:
        return fallback
    return float(value)


func _vector2_property(node: Object, key: String, fallback: Vector2) -> Vector2:
    var value = node.get(key)
    if typeof(value) == TYPE_VECTOR2:
        return value
    return fallback


func _try_start_attack(target: CharacterBody2D) -> bool:
    if ai_commands.is_empty():
        return false
    var desire_threshold := _attack_desire_threshold()
    if attack_desire < desire_threshold and _player_command_pressure(last_player_command) < 0.85:
        last_ai_decision = "build_desire"
        return false
    var candidates: Array = []
    for command in ai_commands:
        var id := String(command.get("id", "attack"))
        if float(cooldowns.get(id, 0.0)) <= 0.0 and _attack_can_reach_target(command, target):
            candidates.append(command)
    if candidates.is_empty():
        return false
    candidates.sort_custom(func(a, b): return _attack_candidate_score(a, target) > _attack_candidate_score(b, target))
    _begin_attack(candidates[0])
    return true


func _begin_attack(command: Dictionary) -> void:
    active_attack = command
    attack_has_hit = false
    attack_direction = direction
    last_attack_id = String(command.get("id", "attack"))
    last_ai_decision = "attack:" + last_attack_id
    attack_desire = maxf(0.0, attack_desire - float(command.get("desire_cost", 0.72 if is_boss else 0.86)))
    state = "windup"
    state_timer = float(command.get("windup", 0.25))
    cooldowns[String(command.get("id", "attack"))] = float(command.get("cooldown", 1.2))
    _set_enemy_animation("attack")
    _pose_sprite("windup", command)
    _play_attack_sfx("windup")
    _spawn_windup_vfx(command)
    _show_telegraph(command)


func _update_windup(delta: float) -> void:
    state_timer -= delta
    if state_timer <= 0.0:
        state = "active"
        state_timer = float(active_attack.get("active", 0.16))
        _pose_sprite("active", active_attack)
        _play_attack_sfx("active")
        _spawn_attack_burst_vfx(active_attack)


func _update_active(delta: float) -> void:
    var attack_type := String(active_attack.get("type", "melee"))
    if attack_type == "lunge":
        position.x += attack_direction * float(active_attack.get("lunge_speed", 220.0)) * delta
    elif attack_type == "retreat":
        position.x -= attack_direction * float(active_attack.get("retreat_speed", 150.0)) * delta
    elif attack_type == "feint":
        var sway := sin(state_timer * TAU * 8.0) * float(active_attack.get("feint_sway", 78.0)) * delta
        position.x += attack_direction * sway
    _clamp_movement_bounds()

    _try_damage_player(active_attack)

    state_timer -= delta
    if state_timer <= 0.0:
        state = "recover"
        state_timer = float(active_attack.get("recover", 0.42))
        _pose_sprite("recover", active_attack)
        _clear_telegraph()


func _update_recover(delta: float) -> void:
    state_timer -= delta
    if state_timer <= 0.0:
        active_attack = {}
        state = "patrol"
        _set_enemy_animation("idle")
        _pose_sprite("idle")


func _try_damage_player(command: Dictionary) -> void:
    if attack_has_hit:
        return
    var target := _target_player()
    if target == null:
        return

    var attack_type := String(command.get("type", "melee"))
    var dir := attack_direction if _is_attack_state() else direction
    var center := global_position + Vector2(dir * float(command.get("offset", 44.0)), -26.0)
    var size := Vector2(float(command.get("hit_width", 76.0)), float(command.get("hit_height", 58.0)))
    if attack_type == "aoe":
        center = global_position + Vector2(0.0, -24.0)
        size = Vector2(float(command.get("hit_width", 150.0)), float(command.get("hit_height", 88.0)))
    elif attack_type == "shockwave":
        center = global_position + Vector2(dir * float(command.get("offset", 102.0)), -14.0)
        size = Vector2(float(command.get("hit_width", 220.0)), float(command.get("hit_height", 42.0)))
    elif attack_type == "retreat":
        center = global_position + Vector2(dir * float(command.get("offset", 64.0)), -30.0)
        size = Vector2(float(command.get("hit_width", 118.0)), float(command.get("hit_height", 64.0)))
    elif attack_type == "feint":
        center = global_position + Vector2(dir * float(command.get("offset", 54.0)), -34.0)
        size = Vector2(float(command.get("hit_width", 104.0)), float(command.get("hit_height", 72.0)))
    var attack_rect := Rect2(center - size * 0.5, size)
    var player_rect := Rect2(target.global_position - Vector2(24.0, 84.0), Vector2(48.0, 88.0))
    if attack_rect.intersects(player_rect):
        target.take_damage(int(command.get("damage", damage)), global_position)
        attack_has_hit = true


func _show_telegraph(command: Dictionary) -> void:
    _clear_telegraph()
    telegraph = Polygon2D.new()
    var attack_type := String(command.get("type", "melee"))
    var color := Color.html("#" + String(command.get("telegraph", "d66b3d")))
    color.a = 0.34
    var width := float(command.get("hit_width", 84.0))
    var height := float(command.get("hit_height", 58.0))
    var dir := attack_direction if _is_attack_state() else direction
    var offset := dir * float(command.get("offset", 44.0))
    if attack_type == "aoe":
        offset = 0.0
        width = float(command.get("hit_width", 150.0))
        height = float(command.get("hit_height", 88.0))
    elif attack_type == "shockwave":
        offset = dir * float(command.get("offset", 102.0))
        width = float(command.get("hit_width", 220.0))
        height = float(command.get("hit_height", 42.0))
    elif attack_type == "retreat":
        offset = dir * float(command.get("offset", 64.0))
        width = float(command.get("hit_width", 118.0))
        height = float(command.get("hit_height", 64.0))
    elif attack_type == "feint":
        offset = dir * float(command.get("offset", 54.0))
        width = float(command.get("hit_width", 104.0))
        height = float(command.get("hit_height", 72.0))
    telegraph.polygon = PackedVector2Array([
        Vector2(offset - width * 0.5, -26.0 - height * 0.5),
        Vector2(offset + width * 0.5, -26.0 - height * 0.5),
        Vector2(offset + width * 0.5, -26.0 + height * 0.5),
        Vector2(offset - width * 0.5, -26.0 + height * 0.5)
    ])
    telegraph.color = color
    telegraph.z_index = 8
    add_child(telegraph)
    var tween := create_tween()
    tween.set_loops(3)
    tween.tween_property(telegraph, "scale", Vector2(1.08, 1.08), 0.08)
    tween.tween_property(telegraph, "scale", Vector2(1.0, 1.0), 0.08)


func _clear_telegraph() -> void:
    if telegraph != null and is_instance_valid(telegraph):
        telegraph.queue_free()
    telegraph = null


func _on_body_entered(body: Node) -> void:
    if contact_timer > 0.0:
        return
    if body.has_method("can_ignore_enemy_contact") and body.can_ignore_enemy_contact(global_position):
        contact_timer = 0.12
        return
    if body.has_method("take_damage"):
        contact_timer = 0.65
        body.take_damage(damage, global_position)


func _build_shape() -> void:
    var shape := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = body_size if body_size != Vector2.ZERO else (Vector2(132, 128) if is_boss else Vector2(50, 46))
    shape.shape = rectangle
    add_child(shape)


func _build_sprite() -> void:
    if not sprite_parts.is_empty():
        sprite = _build_part_sprite()
    elif asset_path.ends_with(".json"):
        animated_sprite = AnimatedSprite2D.new()
        animated_sprite.name = "EnemyAnimatedSprite"
        animated_sprite.sprite_frames = _load_enemy_sprite_frames(asset_path)
        animated_sprite.play("idle")
        sprite = animated_sprite
    else:
        var static_sprite := Sprite2D.new()
        static_sprite.name = "EnemySprite"
        static_sprite.texture = _load_texture_resource(asset_path)
        if sprite_region.size() >= 4:
            static_sprite.region_enabled = true
            static_sprite.region_rect = Rect2(float(sprite_region[0]), float(sprite_region[1]), float(sprite_region[2]), float(sprite_region[3]))
        sprite = static_sprite
    sprite.position = (Vector2(0, -30) if is_boss else Vector2(0, -18)) + visual_offset
    var scale_value := visual_scale if visual_scale > 0.0 else (1.45 if is_boss else 0.78)
    sprite.scale = Vector2(scale_value, scale_value)
    sprite.modulate = visual_modulate
    sprite_base_position = sprite.position
    sprite_base_scale = sprite.scale
    _apply_sprite_region("idle")
    add_child(sprite)


func _build_part_sprite() -> Node2D:
    var root := Node2D.new()
    root.name = "EnemyPartSprite"
    for part_value in sprite_parts:
        if not (part_value is Dictionary):
            continue
        var part: Dictionary = part_value
        var path := String(part.get("path", ""))
        var texture := _load_texture_resource(path)
        if texture == null:
            continue
        var part_sprite := Sprite2D.new()
        part_sprite.name = String(part.get("name", "MonsterPart"))
        part_sprite.texture = texture
        part_sprite.position = _vec2(part.get("offset", [0, 0]))
        var scale_value := float(part.get("scale", 1.0))
        part_sprite.scale = Vector2(scale_value, scale_value)
        part_sprite.rotation_degrees = float(part.get("rotation", 0.0))
        part_sprite.z_index = int(part.get("z", 0))
        if part.has("modulate"):
            part_sprite.modulate = Color.html("#" + String(part.get("modulate", "ffffff")))
        root.add_child(part_sprite)
    return root


func _load_enemy_sprite_frames(manifest_path: String) -> SpriteFrames:
    var file := FileAccess.open(manifest_path, FileAccess.READ)
    if file == null:
        return null
    var data = JSON.parse_string(file.get_as_text())
    if typeof(data) != TYPE_DICTIONARY:
        return null
    var frames := SpriteFrames.new()
    if frames.has_animation("default"):
        frames.remove_animation("default")
    for animation in data.get("animations", []):
        if typeof(animation) != TYPE_DICTIONARY:
            continue
        var animation_name := String(animation.get("name", "idle"))
        frames.add_animation(animation_name)
        frames.set_animation_speed(animation_name, float(animation.get("fps", 8.0)))
        frames.set_animation_loop(animation_name, bool(animation.get("loop", true)))
        for frame_path in animation.get("frames", []):
            var texture := _load_texture_resource(String(frame_path))
            if texture != null:
                frames.add_frame(animation_name, texture)
    return frames


func _vec2(value: Variant) -> Vector2:
    if typeof(value) != TYPE_ARRAY or value.size() < 2:
        return Vector2.ZERO
    return Vector2(float(value[0]), float(value[1]))


func _vec2_or(value: Variant, fallback: Vector2) -> Vector2:
    if typeof(value) != TYPE_ARRAY or value.size() < 2:
        return fallback
    return Vector2(float(value[0]), float(value[1]))


func _load_texture_resource(path: String) -> Texture2D:
    if ResourceLoader.exists(path):
        var texture := load(path) as Texture2D
        if texture != null:
            return texture
    if not FileAccess.file_exists(path):
        return null
    var image := Image.load_from_file(path)
    if image == null:
        return null
    return ImageTexture.create_from_image(image)


func _set_sprite_flip(flip_value: bool) -> void:
    if sprite != null:
        sprite.set("flip_h", not flip_value if sprite_faces_left else flip_value)


func _set_enemy_animation(animation_name: String) -> void:
    _apply_sprite_region(animation_name)
    if animated_sprite == null or animated_sprite.sprite_frames == null:
        return
    var next_animation := animation_name
    if not animated_sprite.sprite_frames.has_animation(next_animation):
        next_animation = "idle"
    if animated_sprite.animation != next_animation:
        animated_sprite.play(next_animation)


func _apply_sprite_region(animation_name: String) -> void:
    if sprite == null or not (sprite is Sprite2D):
        return
    var sprite_2d := sprite as Sprite2D
    var region_value: Array = []
    if sprite_regions.has(animation_name):
        region_value = sprite_regions.get(animation_name, [])
    elif animation_name == "walk" and sprite_regions.has("move"):
        region_value = sprite_regions.get("move", [])
    elif animation_name == "hurt" and sprite_regions.has("hit"):
        region_value = sprite_regions.get("hit", [])
    elif animation_name == "death" and sprite_regions.has("dead"):
        region_value = sprite_regions.get("dead", [])
    elif sprite_regions.has("idle"):
        region_value = sprite_regions.get("idle", [])
    else:
        region_value = sprite_region
    if region_value.size() < 4:
        return
    sprite_2d.region_enabled = true
    sprite_2d.region_rect = Rect2(float(region_value[0]), float(region_value[1]), float(region_value[2]), float(region_value[3]))


func _pose_sprite(pose_name: String, command: Dictionary = {}) -> void:
    if sprite == null:
        return
    _apply_sprite_region("attack" if pose_name == "windup" or pose_name == "active" else pose_name)
    var attack_type := String(command.get("type", "melee"))
    var pose_direction := attack_direction if pose_name == "windup" or pose_name == "active" or pose_name == "recover" else direction
    var lunge_bias := 10.0 if attack_type == "lunge" or attack_type == "melee" else 0.0
    var slam_bias := 10.0 if attack_type == "aoe" else 0.0
    var shock_bias := 14.0 if attack_type == "shockwave" else 0.0
    var power := float(command.get("pose_power", 1.25 if is_boss else 1.0))
    var target_position := sprite_base_position
    var target_scale := sprite_base_scale
    var target_rotation := 0.0
    var time := 0.10
    if pose_name == "windup":
        target_position += _pose_offset(command, "windup_offset", Vector2(-pose_direction * 12.0 * power, -7.0 - slam_bias * 0.45))
        target_scale = sprite_base_scale * _pose_scale(command, "windup_scale", Vector2(1.05 + 0.02 * power, 0.94))
        target_rotation = deg_to_rad(float(command.get("windup_rotation", -pose_direction * (6.0 + shock_bias * 0.30) * power)))
        time = float(command.get("windup", 0.22)) * 0.45
    elif pose_name == "active":
        target_position += _pose_offset(command, "active_offset", Vector2(pose_direction * (22.0 + lunge_bias + shock_bias) * power, slam_bias + 2.0))
        target_scale = sprite_base_scale * _pose_scale(command, "active_scale", Vector2(1.16 + 0.03 * power, 0.86))
        target_rotation = deg_to_rad(float(command.get("active_rotation", pose_direction * (11.0 + shock_bias * 0.24) * power)))
        time = 0.08
    elif pose_name == "recover":
        target_position += _pose_offset(command, "recover_offset", Vector2(-pose_direction * 8.0 * power, 3.0))
        target_scale = sprite_base_scale * _pose_scale(command, "recover_scale", Vector2(0.96, 1.04))
        target_rotation = deg_to_rad(float(command.get("recover_rotation", -pose_direction * 4.0 * power)))
        time = 0.12
    elif pose_name == "hurt":
        target_position += Vector2(-pose_direction * 8.0, -2.0)
        target_rotation = deg_to_rad(-pose_direction * 8.0)
        time = 0.06
    else:
        time = 0.12
    var tween := create_tween()
    tween.set_parallel(true)
    tween.tween_property(sprite, "position", target_position, maxf(0.04, time)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.tween_property(sprite, "scale", target_scale, maxf(0.04, time)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.tween_property(sprite, "rotation", target_rotation, maxf(0.04, time)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _pose_offset(command: Dictionary, key: String, fallback: Vector2) -> Vector2:
    if not command.has(key):
        return fallback
    var value = command.get(key)
    if typeof(value) != TYPE_ARRAY or value.size() < 2:
        return fallback
    var x := float(value[0])
    var y := float(value[1])
    if bool(command.get("mirror_pose_offset", true)):
        x *= float(attack_direction)
    return Vector2(x, y)


func _pose_scale(command: Dictionary, key: String, fallback: Vector2) -> Vector2:
    if not command.has(key):
        return fallback
    var value = command.get(key)
    if typeof(value) != TYPE_ARRAY or value.size() < 2:
        return fallback
    return Vector2(float(value[0]), float(value[1]))


func _play_sfx(audio_key: String, volume_db: float = -6.0) -> void:
    if not _should_play_sfx():
        return
    var stream := _load_sfx_stream(audio_key)
    if stream == null:
        return
    var player_node := AudioStreamPlayer2D.new()
    player_node.name = "Sfx_" + audio_key
    player_node.stream = stream
    player_node.volume_db = volume_db
    player_node.max_distance = 900.0
    add_child(player_node)
    player_node.finished.connect(Callable(player_node, "queue_free"))
    player_node.play()


func _play_attack_sfx(phase: String) -> void:
    if phase == "windup":
        _play_sfx("boss_windup" if is_boss else "enemy_windup", -9.0 if is_boss else -11.0)
    else:
        _play_sfx("boss_attack" if is_boss else "enemy_attack", -8.0 if is_boss else -10.0)


func _spawn_windup_vfx(command: Dictionary) -> void:
    var warning := Line2D.new()
    warning.name = "EnemyWindupVfx"
    var width := float(command.get("hit_width", 84.0))
    var height := float(command.get("hit_height", 58.0))
    var dir := attack_direction if _is_attack_state() else direction
    var offset := dir * float(command.get("offset", 44.0))
    var attack_type := String(command.get("type", "melee"))
    if attack_type == "aoe":
        offset = 0.0
    elif attack_type == "shockwave":
        offset = dir * float(command.get("offset", 102.0))
        width = float(command.get("hit_width", 220.0))
        height = float(command.get("hit_height", 42.0))
    elif attack_type == "retreat":
        offset = dir * float(command.get("offset", 64.0))
        width = float(command.get("hit_width", 118.0))
        height = float(command.get("hit_height", 64.0))
    elif attack_type == "feint":
        offset = dir * float(command.get("offset", 54.0))
        width = float(command.get("hit_width", 104.0))
        height = float(command.get("hit_height", 72.0))
    warning.points = PackedVector2Array([
        Vector2(offset - width * 0.5, -26.0 - height * 0.5),
        Vector2(offset + width * 0.5, -26.0 - height * 0.5),
        Vector2(offset + width * 0.5, -26.0 + height * 0.5),
        Vector2(offset - width * 0.5, -26.0 + height * 0.5),
        Vector2(offset - width * 0.5, -26.0 - height * 0.5)
    ])
    warning.width = 3.0 if is_boss else 2.0
    warning.default_color = Color(1.0, 0.72, 0.28, 0.92)
    warning.z_index = 22
    add_child(warning)
    var tween := create_tween()
    tween.tween_property(warning, "scale", Vector2(1.16, 1.16), float(command.get("windup", 0.25)))
    tween.parallel().tween_property(warning, "modulate:a", 0.0, float(command.get("windup", 0.25)))
    tween.finished.connect(Callable(warning, "queue_free"))


func _spawn_attack_burst_vfx(command: Dictionary) -> void:
    var burst := Line2D.new()
    burst.name = "BossAttackBurstVfx" if is_boss else "EnemyAttackBurstVfx"
    var attack_type := String(command.get("type", "melee"))
    var width := float(command.get("hit_width", 88.0))
    var height := float(command.get("hit_height", 58.0))
    var dir := attack_direction if _is_attack_state() else direction
    var offset := dir * float(command.get("offset", 48.0))
    if attack_type == "aoe":
        offset = 0.0
    elif attack_type == "shockwave":
        offset = dir * float(command.get("offset", 102.0))
        width = float(command.get("hit_width", 220.0))
        height = float(command.get("hit_height", 42.0))
    elif attack_type == "retreat":
        offset = dir * float(command.get("offset", 64.0))
        width = float(command.get("hit_width", 118.0))
        height = float(command.get("hit_height", 64.0))
    elif attack_type == "feint":
        offset = dir * float(command.get("offset", 54.0))
        width = float(command.get("hit_width", 104.0))
        height = float(command.get("hit_height", 72.0))
    burst.width = 5.0 if is_boss else 3.0
    burst.default_color = Color(1.0, 0.34, 0.22, 0.88) if is_boss else Color(1.0, 0.78, 0.34, 0.86)
    burst.z_index = 24
    if attack_type == "aoe":
        var points := PackedVector2Array()
        for step in range(26):
            var angle := TAU * float(step) / 26.0
            points.append(Vector2(cos(angle) * width * 0.46, sin(angle) * height * 0.46 - 26.0))
        burst.points = points
        burst.closed = true
    elif attack_type == "shockwave":
        burst.width = 6.0 if is_boss else 4.0
        burst.points = PackedVector2Array([
            Vector2(offset - width * 0.5, -14.0),
            Vector2(offset - width * 0.22, -30.0),
            Vector2(offset + width * 0.08, -8.0),
            Vector2(offset + width * 0.34, -28.0),
            Vector2(offset + width * 0.5, -12.0)
        ])
    elif attack_type == "retreat":
        burst.points = PackedVector2Array([
            Vector2(offset + width * 0.45, -62.0),
            Vector2(offset - width * 0.1, -36.0),
            Vector2(offset + width * 0.4, -10.0),
            Vector2(offset - width * 0.3, 2.0)
        ])
    elif attack_type == "feint":
        burst.points = PackedVector2Array([
            Vector2(offset - width * 0.35, -55.0),
            Vector2(offset + width * 0.28, -40.0),
            Vector2(offset - width * 0.08, -18.0),
            Vector2(offset + width * 0.42, 0.0)
        ])
    else:
        burst.points = PackedVector2Array([
            Vector2(offset - width * 0.48, -38.0),
            Vector2(offset, -18.0),
            Vector2(offset + width * 0.52, -42.0),
            Vector2(offset + width * 0.22, 4.0)
        ])
    add_child(burst)
    var tween := create_tween()
    tween.tween_property(burst, "scale", Vector2(1.35, 1.35), 0.18)
    tween.parallel().tween_property(burst, "modulate:a", 0.0, 0.18)
    tween.finished.connect(Callable(burst, "queue_free"))


func _should_play_sfx() -> bool:
    if DisplayServer.get_name() != "headless":
        return true
    for arg in OS.get_cmdline_args():
        if String(arg).contains("audio_visual_validation.gd"):
            return true
    return false


func _load_sfx_stream(audio_key: String) -> AudioStream:
    var path := String(SFX.get(audio_key, ""))
    if path.is_empty() or not FileAccess.file_exists(path):
        return null
    if path.ends_with(".ogg"):
        return AudioStreamOggVorbis.load_from_file(path)
    return load(path) as AudioStream


func _spawn_hit_spark(hit_direction: int) -> void:
    var spark := Line2D.new()
    spark.name = "HitSpark"
    spark.width = 4.0 if is_boss else 3.0
    spark.default_color = Color(1.0, 0.82, 0.38, 0.95)
    spark.z_index = 40
    var x := 24.0 * -hit_direction
    spark.points = PackedVector2Array([
        Vector2(x, -30.0),
        Vector2(x + 28.0 * hit_direction, -48.0),
        Vector2(x + 7.0 * hit_direction, -22.0),
        Vector2(x + 34.0 * hit_direction, -12.0)
    ])
    add_child(spark)
    var tween := create_tween()
    tween.tween_property(spark, "scale", Vector2(1.55, 1.55), 0.16)
    tween.parallel().tween_property(spark, "modulate:a", 0.0, 0.16)
    tween.finished.connect(Callable(spark, "queue_free"))
