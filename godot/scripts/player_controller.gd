extends CharacterBody2D

signal hp_changed(value: int)
signal player_respawned
signal energy_changed(value: int, maximum: int)

const SFX := {
    "attack": "res://assets/audio/sfx/player_attack.ogg",
    "hook": "res://assets/audio/sfx/player_hook.ogg",
    "skill": "res://assets/audio/sfx/heavy_hit.ogg",
    "dash": "res://assets/audio/sfx/player_dash.ogg",
    "jump": "res://assets/audio/sfx/player_jump.ogg",
    "heal": "res://assets/audio/sfx/player_heal.ogg",
    "hurt": "res://assets/audio/sfx/player_hurt.ogg"
}
const PLAYER_MANIFEST := "res://assets/sprites/player/generated_hero_v2/manifest.json"

@export var speed: float = 285.0
@export var jump_velocity: float = -710.0
@export var gravity: float = 1850.0
@export var dash_speed: float = 780.0
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12
@export var jump_cut_multiplier: float = 0.48
@export var dash_time: float = 0.16
@export var dash_cooldown_time: float = 0.60
@export var attack_lunge: float = 92.0
@export var downslash_bounce_velocity: float = -620.0
@export var enemy_contact_guard_time: float = 0.22
@export var max_hp: int = 5
@export var max_energy: int = 100
@export var skill_energy_cost: int = 30
@export var heal_energy_cost: int = 60
@export var energy_per_hit: int = 15
@export var energy_on_damage: int = 10

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var attack_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D

var hp: int = max_hp
var energy: int = 0
var facing: int = 1
var spawn_position: Vector2
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var dash_timer: float = 0.0
var dash_cooldown: float = 0.0
var land_timer: float = 0.0
var attack_timer: float = 0.0
var hurt_timer: float = 0.0
var death_timer: float = 0.0
var skill_cooldown: float = 0.0
var heal_cooldown: float = 0.0
var attack_duration: float = 0.34
var current_attack: StringName = &"attack_1"
var attack_damage: int = 1
var attack_range: float = 82.0
var attack_height: float = 72.0
var attack_forward_offset: float = 48.0
var current_attack_direction: Vector2 = Vector2.RIGHT
var enemy_contact_guard_timer: float = 0.0
var hit_targets: Dictionary = {}


func _ready() -> void:
    add_to_group("player")
    spawn_position = global_position
    _ensure_input_actions()
    _load_sprite_frames()
    attack_shape.disabled = true
    _sync_attack_hitbox()
    hp_changed.emit(hp)
    energy_changed.emit(energy, max_energy)


func _physics_process(delta: float) -> void:
    if death_timer > 0.0:
        death_timer -= delta
        if death_timer <= 0.0:
            _hard_respawn()
        _play(&"death")
        return

    if hurt_timer > 0.0:
        hurt_timer -= delta

    var was_on_floor := is_on_floor()
    if Input.is_action_just_pressed("jump"):
        jump_buffer_timer = jump_buffer_time
    else:
        jump_buffer_timer = maxf(0.0, jump_buffer_timer - delta)

    if is_on_floor():
        coyote_timer = coyote_time
    else:
        coyote_timer = maxf(0.0, coyote_timer - delta)
        velocity.y += gravity * delta

    dash_cooldown = maxf(0.0, dash_cooldown - delta)
    land_timer = maxf(0.0, land_timer - delta)
    skill_cooldown = maxf(0.0, skill_cooldown - delta)
    heal_cooldown = maxf(0.0, heal_cooldown - delta)
    enemy_contact_guard_timer = maxf(0.0, enemy_contact_guard_timer - delta)
    var input_axis := Input.get_axis("move_left", "move_right")

    if input_axis != 0.0:
        facing = signi(input_axis)
        sprite.flip_h = facing < 0
        _sync_attack_hitbox()

    if jump_buffer_timer > 0.0 and coyote_timer > 0.0 and dash_timer <= 0.0:
        velocity.y = jump_velocity
        coyote_timer = 0.0
        jump_buffer_timer = 0.0
        _play(&"jump_start")
        _play_sfx("jump", -6.0)

    if Input.is_action_just_released("jump") and velocity.y < 0.0:
        velocity.y *= jump_cut_multiplier

    if Input.is_action_just_pressed("dash") and dash_cooldown <= 0.0 and dash_timer <= 0.0:
        dash_timer = dash_time
        dash_cooldown = dash_cooldown_time
        velocity.y = 0.0
        velocity.x = dash_speed * facing
        _play(&"dash")
        _play_sfx("dash", -7.0)

    if Input.is_action_just_pressed("heal"):
        _try_heal()

    if Input.is_action_just_pressed("attack") and attack_timer <= 0.0 and dash_timer <= 0.0:
        _start_attack(&"attack_1")
    elif Input.is_action_just_pressed("hook") and attack_timer <= 0.0 and dash_timer <= 0.0:
        _start_attack(&"hook_throw")
    elif Input.is_action_just_pressed("skill_1") and attack_timer <= 0.0 and dash_timer <= 0.0:
        _try_skill_burst()

    if dash_timer > 0.0:
        dash_timer -= delta
        velocity.x = dash_speed * facing
        velocity.y = 0.0
    elif attack_timer <= 0.0:
        velocity.x = move_toward(velocity.x, input_axis * speed, speed * 9.5 * delta)
    else:
        velocity.x = move_toward(velocity.x, input_axis * speed * 0.45, speed * 5.0 * delta)

    _update_attack(delta)
    move_and_slide()
    if not was_on_floor and is_on_floor():
        land_timer = 0.14
        _spawn_land_vfx()
    _update_animation(input_axis)


func _start_attack(animation: StringName) -> void:
    current_attack = animation
    current_attack_direction = _read_attack_direction()
    if animation == &"hook_throw":
        current_attack_direction = Vector2(float(facing), 0.0)
    if animation == &"hook_throw":
        attack_duration = 0.42
        attack_damage = 1
        attack_range = 150.0
        attack_height = 92.0
        attack_forward_offset = 72.0
    elif animation == &"attack_2":
        attack_duration = 0.48
        attack_damage = 2
        attack_range = 126.0
        attack_height = 108.0
        attack_forward_offset = 54.0
    else:
        attack_duration = 0.34
        attack_damage = 1
        attack_range = 86.0
        attack_height = 92.0
        attack_forward_offset = 48.0
    if absf(current_attack_direction.x) > 0.1:
        velocity.x += current_attack_direction.x * (attack_lunge if is_on_floor() else attack_lunge * 0.45)
    elif current_attack_direction.y < -0.5:
        velocity.y = minf(velocity.y, -110.0)
    attack_timer = attack_duration
    enemy_contact_guard_timer = maxf(enemy_contact_guard_timer, enemy_contact_guard_time)
    hit_targets.clear()
    _sync_attack_hitbox()
    _play(animation)
    if animation == &"hook_throw":
        _play_sfx("hook", -6.0)
    elif animation == &"attack_2":
        _play_sfx("skill", -7.0)
    else:
        _play_sfx("attack", -5.0)
    _spawn_attack_vfx(animation)


func _try_skill_burst() -> void:
    if skill_cooldown > 0.0 or energy < skill_energy_cost:
        return
    energy -= skill_energy_cost
    skill_cooldown = 2.4
    energy_changed.emit(energy, max_energy)
    _start_attack(&"attack_2")


func _try_heal() -> void:
    if heal_cooldown > 0.0 or hp >= max_hp or energy < heal_energy_cost or death_timer > 0.0:
        return
    energy -= heal_energy_cost
    hp = mini(max_hp, hp + 1)
    heal_cooldown = 0.55
    energy_changed.emit(energy, max_energy)
    hp_changed.emit(hp)
    _play_sfx("heal", -5.0)
    _spawn_heal_effect()
    _play(&"land")


func _update_attack(delta: float) -> void:
    if attack_timer <= 0.0:
        attack_shape.disabled = true
        return

    attack_timer = maxf(0.0, attack_timer - delta)
    var elapsed := attack_duration - attack_timer
    var active := false
    if current_attack == &"hook_throw":
        active = elapsed >= 0.08 and elapsed <= 0.36
    elif current_attack == &"attack_2":
        active = elapsed >= 0.07 and elapsed <= 0.34
    else:
        active = elapsed >= 0.06 and elapsed <= 0.28

    attack_shape.disabled = not active
    if active:
        _apply_attack_hits()


func _apply_attack_hits() -> void:
    var attack_size := _attack_size()
    var center := global_position + _attack_center_offset()
    var attack_rect := Rect2(center - attack_size * 0.5, attack_size)
    for node in get_tree().get_nodes_in_group("enemy"):
        if not is_instance_valid(node) or not node.has_method("take_hit"):
            continue
        var id := node.get_instance_id()
        if hit_targets.has(id):
            continue
        var hurtbox := Rect2(node.global_position - Vector2(34, 38), Vector2(68, 76))
        if node.has_method("get_hurtbox_rect"):
            hurtbox = node.get_hurtbox_rect()
        if attack_rect.intersects(hurtbox):
            hit_targets[id] = true
            node.take_hit(attack_damage, _attack_hit_direction())
            gain_energy(energy_per_hit)
            _apply_downslash_bounce(node.global_position)
            _spawn_hit_confirm_vfx(node.global_position, current_attack)


func _sync_attack_hitbox() -> void:
    attack_hitbox.position = _attack_center_offset()
    var rectangle := attack_shape.shape as RectangleShape2D
    if rectangle != null:
        rectangle.size = _attack_size()


func _read_attack_direction() -> Vector2:
    if Input.is_action_pressed("aim_down"):
        return Vector2.DOWN
    if Input.is_action_pressed("aim_up"):
        return Vector2.UP
    var input_axis := Input.get_axis("move_left", "move_right")
    if absf(input_axis) > 0.1:
        return Vector2(signf(input_axis), 0.0)
    return Vector2(float(facing), 0.0)


func _attack_size() -> Vector2:
    if current_attack != &"hook_throw" and absf(current_attack_direction.y) > 0.5:
        if current_attack == &"attack_2":
            return Vector2(104.0, 144.0)
        return Vector2(82.0, 120.0)
    return Vector2(attack_range, attack_height)


func _attack_center_offset() -> Vector2:
    if current_attack != &"hook_throw" and current_attack_direction.y < -0.5:
        return Vector2(0.0, -102.0)
    if current_attack != &"hook_throw" and current_attack_direction.y > 0.5:
        return Vector2(0.0, 18.0)
    return Vector2(attack_forward_offset * facing, -42.0)


func _attack_hit_direction() -> int:
    if absf(current_attack_direction.x) > 0.1:
        return signi(current_attack_direction.x)
    return facing


func _apply_downslash_bounce(_target_position: Vector2) -> void:
    if current_attack == &"hook_throw" or current_attack_direction.y <= 0.5:
        return
    velocity.y = downslash_bounce_velocity
    dash_timer = 0.0
    dash_cooldown = minf(dash_cooldown, 0.12)
    coyote_timer = 0.0
    jump_buffer_timer = 0.0
    enemy_contact_guard_timer = maxf(enemy_contact_guard_timer, enemy_contact_guard_time)


func gain_energy(amount: int) -> void:
    var before := energy
    energy = clampi(energy + amount, 0, max_energy)
    if energy != before:
        energy_changed.emit(energy, max_energy)


func _update_animation(input_axis: float) -> void:
    if hurt_timer > 0.0:
        _play(&"hurt")
    elif attack_timer > 0.0:
        _play(current_attack)
    elif dash_timer > 0.0:
        _play(&"dash")
    elif not is_on_floor():
        _play(&"jump_loop" if velocity.y < 0.0 else &"fall")
    elif land_timer > 0.0:
        _play(&"land")
    elif absf(input_axis) > 0.1:
        _play(&"run")
    else:
        _play(&"idle")


func _play(name: StringName) -> void:
    if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(name):
        return
    if sprite.animation != name:
        sprite.play(name)


func _play_sfx(audio_key: String, volume_db: float = -5.0) -> void:
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


func _spawn_heal_effect() -> void:
    for index in range(3):
        _add_heal_ring(22.0 + float(index) * 15.0, 0.10 * float(index))
    for index in range(8):
        var thread := Line2D.new()
        thread.name = "HealThread"
        var x := -34.0 + float(index) * 9.7
        thread.points = PackedVector2Array([Vector2(x, -18.0), Vector2(x + 4.0, -76.0)])
        thread.width = 2.0
        thread.default_color = Color(0.56, 1.0, 0.70, 0.82)
        thread.z_index = 44
        add_child(thread)
        var tween := create_tween()
        tween.tween_property(thread, "position:y", -18.0, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
        tween.parallel().tween_property(thread, "modulate:a", 0.0, 0.42)
        tween.finished.connect(Callable(thread, "queue_free"))


func _add_heal_ring(radius: float, delay: float) -> void:
    var ring := Line2D.new()
    ring.name = "HealEffectRing"
    var points := PackedVector2Array()
    for step in range(32):
        var angle := TAU * float(step) / 32.0
        points.append(Vector2(cos(angle), sin(angle)) * radius + Vector2(0.0, -44.0))
    ring.points = points
    ring.closed = true
    ring.width = 3.0
    ring.default_color = Color(0.74, 1.0, 0.58, 0.92)
    ring.z_index = 45
    add_child(ring)
    ring.scale = Vector2(0.38, 0.38)
    var tween := create_tween()
    tween.tween_interval(delay)
    tween.tween_property(ring, "scale", Vector2(1.9, 1.9), 0.46).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.46)
    tween.finished.connect(Callable(ring, "queue_free"))


func _spawn_attack_vfx(animation: StringName) -> void:
    if animation == &"hook_throw":
        _spawn_hook_trail_vfx()
    elif animation == &"attack_2":
        _spawn_skill_slash_vfx()
    else:
        _spawn_slash_vfx()


func _spawn_slash_vfx() -> void:
    var slash := Line2D.new()
    slash.name = "AttackSlashVfx"
    slash.width = 5.0
    slash.default_color = Color(1.0, 0.92, 0.58, 0.90)
    slash.z_index = 60
    var points := PackedVector2Array()
    var center := _attack_center_offset()
    if current_attack_direction.y < -0.5:
        points.append(center + Vector2(-38.0, 22.0))
        points.append(center + Vector2(0.0, -42.0))
        points.append(center + Vector2(38.0, 22.0))
    elif current_attack_direction.y > 0.5:
        points.append(center + Vector2(-38.0, -22.0))
        points.append(center + Vector2(0.0, 44.0))
        points.append(center + Vector2(38.0, -22.0))
    else:
        for step in range(10):
            var angle := lerpf(-0.95, 0.95, float(step) / 9.0)
            points.append(center + Vector2(cos(angle) * 45.0 * facing, sin(angle) * 28.0))
    slash.points = points
    add_child(slash)
    var tween := create_tween()
    tween.tween_property(slash, "scale", Vector2(1.28, 1.28), 0.15)
    tween.parallel().tween_property(slash, "modulate:a", 0.0, 0.15)
    tween.finished.connect(Callable(slash, "queue_free"))


func _spawn_hook_trail_vfx() -> void:
    var trail := Line2D.new()
    trail.name = "HookTrailVfx"
    trail.width = 3.0
    trail.default_color = Color(0.50, 1.0, 0.95, 0.88)
    trail.z_index = 58
    trail.points = PackedVector2Array([
        Vector2(16.0 * facing, -46.0),
        Vector2(70.0 * facing, -54.0),
        Vector2(145.0 * facing, -38.0)
    ])
    add_child(trail)
    var hook_tip := Polygon2D.new()
    hook_tip.name = "HookTipVfx"
    hook_tip.polygon = PackedVector2Array([
        Vector2(150.0 * facing, -38.0),
        Vector2(128.0 * facing, -50.0),
        Vector2(132.0 * facing, -27.0)
    ])
    hook_tip.color = Color(0.68, 1.0, 0.86, 0.86)
    hook_tip.z_index = 59
    add_child(hook_tip)
    var tween := create_tween()
    tween.tween_property(trail, "modulate:a", 0.0, 0.22)
    tween.parallel().tween_property(hook_tip, "modulate:a", 0.0, 0.22)
    tween.finished.connect(Callable(trail, "queue_free"))
    tween.finished.connect(Callable(hook_tip, "queue_free"))


func _spawn_skill_slash_vfx() -> void:
    var burst := Line2D.new()
    burst.name = "SkillSlashVfx"
    burst.width = 7.0
    burst.default_color = Color(1.0, 0.36, 0.74, 0.88)
    burst.z_index = 61
    var burst_center := _attack_center_offset()
    if current_attack_direction.y < -0.5:
        burst.points = PackedVector2Array([
            burst_center + Vector2(-42.0, 26.0),
            burst_center + Vector2(-10.0, -48.0),
            burst_center + Vector2(12.0, -52.0),
            burst_center + Vector2(44.0, 24.0)
        ])
    elif current_attack_direction.y > 0.5:
        burst.points = PackedVector2Array([
            burst_center + Vector2(-44.0, -26.0),
            burst_center + Vector2(-10.0, 52.0),
            burst_center + Vector2(12.0, 48.0),
            burst_center + Vector2(42.0, -24.0)
        ])
    else:
        burst.points = PackedVector2Array([
            Vector2(20.0 * facing, -86.0),
            Vector2(56.0 * facing, -56.0),
            Vector2(84.0 * facing, -24.0),
            Vector2(112.0 * facing, 8.0)
        ])
    add_child(burst)
    var ring := Line2D.new()
    ring.name = "SkillBurstRingVfx"
    var points := PackedVector2Array()
    for step in range(28):
        var angle := TAU * float(step) / 28.0
        points.append(Vector2(cos(angle), sin(angle)) * 36.0 + burst_center)
    ring.points = points
    ring.closed = true
    ring.width = 3.0
    ring.default_color = Color(0.46, 1.0, 0.90, 0.70)
    ring.z_index = 60
    add_child(ring)
    var tween := create_tween()
    tween.tween_property(burst, "scale", Vector2(1.22, 1.22), 0.22)
    tween.parallel().tween_property(burst, "modulate:a", 0.0, 0.22)
    tween.parallel().tween_property(ring, "scale", Vector2(1.8, 1.8), 0.22)
    tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.22)
    tween.finished.connect(Callable(burst, "queue_free"))
    tween.finished.connect(Callable(ring, "queue_free"))


func _spawn_hit_confirm_vfx(world_position: Vector2, animation: StringName) -> void:
    var parent_node := get_parent()
    if parent_node == null:
        return
    var spark := Line2D.new()
    spark.name = "HitConfirmVfx"
    spark.global_position = world_position + Vector2(0.0, -28.0)
    spark.width = 4.0 if animation == &"attack_2" else 3.0
    spark.default_color = Color(1.0, 0.82, 0.26, 0.95)
    spark.z_index = 80
    spark.points = PackedVector2Array([
        Vector2(-18.0, -6.0),
        Vector2(0.0, 0.0),
        Vector2(18.0, -12.0),
        Vector2(4.0, 8.0),
        Vector2(22.0, 14.0)
    ])
    parent_node.add_child(spark)
    var tween := create_tween()
    tween.tween_property(spark, "scale", Vector2(1.7, 1.7), 0.16)
    tween.parallel().tween_property(spark, "modulate:a", 0.0, 0.16)
    tween.finished.connect(Callable(spark, "queue_free"))


func _spawn_land_vfx() -> void:
    var dust := Line2D.new()
    dust.name = "LandDustVfx"
    dust.points = PackedVector2Array([
        Vector2(-24.0, -3.0),
        Vector2(-8.0, 2.0),
        Vector2(8.0, 2.0),
        Vector2(24.0, -3.0)
    ])
    dust.width = 3.0
    dust.default_color = Color(0.64, 0.92, 0.56, 0.72)
    dust.z_index = 34
    add_child(dust)
    var tween := create_tween()
    tween.tween_property(dust, "scale", Vector2(1.7, 1.0), 0.18)
    tween.parallel().tween_property(dust, "modulate:a", 0.0, 0.18)
    tween.finished.connect(Callable(dust, "queue_free"))


func take_damage(amount: int, source_position: Vector2 = global_position) -> void:
    if hurt_timer > 0.0 or death_timer > 0.0:
        return
    hp = maxi(0, hp - amount)
    hp_changed.emit(hp)
    _play_sfx("hurt", -6.0)
    if hp <= 0:
        death_timer = 0.9
        velocity = Vector2.ZERO
        _play(&"death")
        return
    gain_energy(energy_on_damage)
    hurt_timer = 0.35
    var knockback_dir := signf(global_position.x - source_position.x)
    if knockback_dir == 0.0:
        knockback_dir = -facing
    velocity = Vector2(knockback_dir * 260.0, -170.0)
    _play(&"hurt")


func can_ignore_enemy_contact(_source_position: Vector2) -> bool:
    if death_timer > 0.0 or hurt_timer > 0.0:
        return true
    if dash_timer > 0.0 or enemy_contact_guard_timer > 0.0:
        return true
    return attack_timer > 0.0 and current_attack != &"hook_throw"


func set_spawn(position_value: Vector2) -> void:
    spawn_position = position_value


func respawn_at(position_value: Vector2) -> void:
    global_position = position_value
    velocity = Vector2.ZERO
    player_respawned.emit()


func _hard_respawn() -> void:
    hp = max_hp
    energy = 0
    hp_changed.emit(hp)
    energy_changed.emit(energy, max_energy)
    respawn_at(spawn_position)
    _play(&"idle")


func restore_at_save_point() -> void:
    hp = max_hp
    energy = max_energy
    hurt_timer = 0.0
    death_timer = 0.0
    heal_cooldown = 0.0
    skill_cooldown = 0.0
    velocity = Vector2.ZERO
    hp_changed.emit(hp)
    energy_changed.emit(energy, max_energy)
    _play(&"idle")


func _load_sprite_frames() -> void:
    var file := FileAccess.open(PLAYER_MANIFEST, FileAccess.READ)
    if file == null:
        push_error("Missing player animation manifest.")
        return
    var data = JSON.parse_string(file.get_as_text())
    if typeof(data) != TYPE_DICTIONARY:
        push_error("Invalid lumen animation manifest.")
        return

    if data.has("frames"):
        sprite.sprite_frames = _load_generated_hero_frames(data)
        _play(&"idle")
        return

    var frames := SpriteFrames.new()
    for anim in data.get("animations", []):
        var anim_name: StringName = StringName(anim.get("name", "idle"))
        if not frames.has_animation(anim_name):
            frames.add_animation(anim_name)
        frames.set_animation_speed(anim_name, float(anim.get("fps", 8)))
        frames.set_animation_loop(anim_name, bool(anim.get("loop", true)))
        for frame_path in anim.get("frames", []):
            var texture := _load_texture_resource(String(frame_path))
            if texture != null:
                frames.add_frame(anim_name, texture)
    sprite.sprite_frames = frames
    _play(&"idle")


func _load_generated_hero_frames(data: Dictionary) -> SpriteFrames:
    var source_frames: Dictionary = data.get("frames", {})
    var frames := SpriteFrames.new()
    if frames.has_animation("default"):
        frames.remove_animation("default")
    var specs := [
        {"name": "idle", "fps": 1.0, "loop": false, "frames": ["idle_00"]},
        {"name": "run", "fps": 10.0, "loop": true, "frames": ["run_00", "run_01", "run_02", "run_03"]},
        {"name": "jump_start", "fps": 10.0, "loop": false, "frames": ["jump_00"]},
        {"name": "jump_loop", "fps": 8.0, "loop": true, "frames": ["jump_00"]},
        {"name": "fall", "fps": 8.0, "loop": true, "frames": ["fall_00"]},
        {"name": "land", "fps": 10.0, "loop": false, "frames": ["land_00"]},
        {"name": "dash", "fps": 12.0, "loop": false, "frames": ["dash_00"]},
        {"name": "wall_slide", "fps": 8.0, "loop": true, "frames": ["wall_cling_00"]},
        {"name": "attack_1", "fps": 14.0, "loop": false, "frames": ["attack_00", "attack_01", "attack_02", "attack_03"]},
        {"name": "attack_2", "fps": 14.0, "loop": false, "frames": ["attack_00", "skill_burst_00", "attack_02", "attack_03"]},
        {"name": "air_attack", "fps": 12.0, "loop": false, "frames": ["air_attack_00"]},
        {"name": "hook_throw", "fps": 12.0, "loop": false, "frames": ["hook_throw_00"]},
        {"name": "hurt", "fps": 8.0, "loop": false, "frames": ["hurt_00"]},
        {"name": "death", "fps": 8.0, "loop": false, "frames": ["death_00", "death_01", "death_02"]},
        {"name": "heal", "fps": 8.0, "loop": false, "frames": ["heal_00"]}
    ]
    for spec in specs:
        var animation_name := String(spec.get("name", "idle"))
        frames.add_animation(animation_name)
        frames.set_animation_speed(animation_name, float(spec.get("fps", 8.0)))
        frames.set_animation_loop(animation_name, bool(spec.get("loop", true)))
        for key in spec.get("frames", []):
            var texture := _load_texture_resource(_res_path_from_manifest(String(source_frames.get(String(key), ""))))
            if texture != null:
                frames.add_frame(animation_name, texture)
        if frames.get_frame_count(animation_name) == 0 and frames.has_animation("idle") and frames.get_frame_count("idle") > 0:
            frames.add_frame(animation_name, frames.get_frame_texture("idle", 0))
    return frames


func _res_path_from_manifest(path: String) -> String:
    if path.begins_with("res://"):
        return path
    if path.begins_with("godot/"):
        return "res://" + path.substr("godot/".length())
    return path


func get_player_debug_state() -> Dictionary:
    return {
        "player_manifest": PLAYER_MANIFEST,
        "speed": speed,
        "jump_velocity": jump_velocity,
        "gravity": gravity,
        "dash_speed": dash_speed,
        "coyote_time": coyote_time,
        "jump_buffer_time": jump_buffer_time,
        "jump_cut_multiplier": jump_cut_multiplier,
        "sprite_scale": sprite.scale if sprite != null else Vector2.ZERO,
        "animation_count": sprite.sprite_frames.get_animation_names().size() if sprite != null and sprite.sprite_frames != null else 0,
        "idle_frame_count": sprite.sprite_frames.get_frame_count(&"idle") if sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"idle") else 0,
        "directional_attack": true,
        "attack_direction": [current_attack_direction.x, current_attack_direction.y],
        "downslash_bounce_velocity": downslash_bounce_velocity,
        "enemy_contact_guard_time": enemy_contact_guard_time
    }


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


func _ensure_input_actions() -> void:
    _bind_key("move_left", [KEY_A, KEY_LEFT])
    _bind_key("move_right", [KEY_D, KEY_RIGHT])
    _bind_key("aim_up", [KEY_W, KEY_UP])
    _bind_key("aim_down", [KEY_S, KEY_DOWN])
    _bind_key("jump", [KEY_SPACE])
    _bind_key("dash", [KEY_SHIFT])
    _bind_mouse("attack", [MOUSE_BUTTON_LEFT])
    _bind_key("attack", [KEY_J])
    _bind_key("hook", [KEY_K, KEY_X])
    _bind_key("skill_1", [KEY_E])
    _bind_mouse("heal", [MOUSE_BUTTON_RIGHT])
    _bind_key("interact", [KEY_F])
    _bind_key("inventory", [KEY_TAB, KEY_I])
    _bind_key("map", [KEY_M])
    _bind_key("close_overlay", [KEY_ESCAPE])


func _bind_key(action_name: StringName, keys: Array[int]) -> void:
    if not InputMap.has_action(action_name):
        InputMap.add_action(action_name)
    for keycode in keys:
        var exists := false
        for existing in InputMap.action_get_events(action_name):
            if existing is InputEventKey and existing.physical_keycode == keycode:
                exists = true
                break
        if exists:
            continue
        var event := InputEventKey.new()
        event.physical_keycode = keycode
        InputMap.action_add_event(action_name, event)


func _bind_mouse(action_name: StringName, buttons: Array[int]) -> void:
    if not InputMap.has_action(action_name):
        InputMap.add_action(action_name)
    for button in buttons:
        var exists := false
        for existing in InputMap.action_get_events(action_name):
            if existing is InputEventMouseButton and existing.button_index == button:
                exists = true
                break
        if exists:
            continue
        var event := InputEventMouseButton.new()
        event.button_index = button
        InputMap.action_add_event(action_name, event)


func signi(value: float) -> int:
    return -1 if value < 0.0 else 1
