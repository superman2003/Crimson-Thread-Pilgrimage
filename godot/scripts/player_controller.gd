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
    "hurt": "res://assets/audio/sfx/player_hurt.ogg",
    # 自产 SFX 包（tools/generate_sfx_pack.py，project-generated CC0，音频规格 §4）。
    "pogo": "res://assets/audio/sfx/generated/player_pogo_bounce.ogg",
    "wall_grip_attach": "res://assets/audio/sfx/generated/player_wall_grip_attach.ogg",
    "wall_slide_loop": "res://assets/audio/sfx/generated/player_wall_slide_loop.ogg",
    "death_cocoon": "res://assets/audio/sfx/generated/player_death_cocoon.ogg",
    "respawn_weave": "res://assets/audio/sfx/generated/player_respawn_weave.ogg",
    # 普攻三采样轮换（音频规格 §4.1）；旧 attack.ogg 保留为兜底。
    "attack_v1": "res://assets/audio/sfx/generated/player_attack_01.ogg",
    "attack_v2": "res://assets/audio/sfx/generated/player_attack_02.ogg",
    "attack_v3": "res://assets/audio/sfx/generated/player_attack_03.ogg",
    # 钩索挂住/收线（asset_ready 接线）：挂住=钩击命中确认，收线=命中窗关闭回收。
    "hook_latch": "res://assets/audio/sfx/generated/player_hook_latch.ogg",
    "hook_reel": "res://assets/audio/sfx/generated/player_hook_reel.ogg",
    # 落地分档（音频规格 §4.1）：按触地前下落速度选软/硬采样。
    "land_soft": "res://assets/audio/sfx/generated/player_land_soft.ogg",
    "land_hard": "res://assets/audio/sfx/generated/player_land_hard.ogg",
    # 章节 beat 叠层（audio_visual_manifest chapter beats，ch2 雨铸运河 / ch4 断弦温室）：
    # 材质条件由 main_level 写入的 footstep_material 判定（copper=ch2、fiber=ch4）。
    "ch02_beat_wall_grip_drip": "res://assets/audio/sfx/generated/ch02_rain_foundry_canal_beat_01_audio.ogg",
    "ch02_beat_echo_hook": "res://assets/audio/sfx/generated/ch02_rain_foundry_canal_beat_02_audio.ogg",
    "ch04_beat_thorn_downstrike": "res://assets/audio/sfx/generated/ch04_broken_string_greenhouse_beat_01_audio.ogg"
}

## AudioDirector 声部契约（并行实现于 scripts/audio_director.gd）：脚本缺席时放行，
## 存在时每次播放前先过静态 request_voice（同 key 最小间隔/并发上限/全局声部抢占）。
const AUDIO_DIRECTOR_PATH := "res://scripts/audio_director.gd"
static var audio_director_script: GDScript = null

## 材质化脚步（音频规格 §4.2；Kenney Impact Sounds，CC0）：
## 苔=grass、铜=concrete、盐=snow、藤=wood、曜=concrete 变体（运行时降 pitch 0.82
## 得到致密石面质感）；材质由 main_level 按章节 art theme 写入 footstep_material。
const FOOTSTEP_VARIANTS := {
    "moss": [
        "res://assets/audio/sfx/kenney/impact/footstep_grass_000.ogg",
        "res://assets/audio/sfx/kenney/impact/footstep_grass_001.ogg",
        "res://assets/audio/sfx/kenney/impact/footstep_grass_002.ogg",
        "res://assets/audio/sfx/kenney/impact/footstep_grass_003.ogg",
        "res://assets/audio/sfx/kenney/impact/footstep_grass_004.ogg"
    ],
    "copper": [
        "res://assets/audio/sfx/kenney/impact/footstep_concrete_000.ogg",
        "res://assets/audio/sfx/kenney/impact/footstep_concrete_001.ogg",
        "res://assets/audio/sfx/kenney/impact/footstep_concrete_002.ogg",
        "res://assets/audio/sfx/kenney/impact/footstep_concrete_003.ogg",
        "res://assets/audio/sfx/kenney/impact/footstep_concrete_004.ogg"
    ],
    "salt": [
        "res://assets/audio/sfx/kenney/impact/footstep_snow_000.ogg",
        "res://assets/audio/sfx/kenney/impact/footstep_snow_001.ogg",
        "res://assets/audio/sfx/kenney/impact/footstep_snow_002.ogg",
        "res://assets/audio/sfx/kenney/impact/footstep_snow_003.ogg",
        "res://assets/audio/sfx/kenney/impact/footstep_snow_004.ogg"
    ],
    "fiber": [
        "res://assets/audio/sfx/kenney/impact/footstep_wood_000.ogg",
        "res://assets/audio/sfx/kenney/impact/footstep_wood_001.ogg",
        "res://assets/audio/sfx/kenney/impact/footstep_wood_002.ogg",
        "res://assets/audio/sfx/kenney/impact/footstep_wood_003.ogg",
        "res://assets/audio/sfx/kenney/impact/footstep_wood_004.ogg"
    ],
    "obsidian": [
        "res://assets/audio/sfx/kenney/impact/footstep_concrete_000.ogg",
        "res://assets/audio/sfx/kenney/impact/footstep_concrete_001.ogg",
        "res://assets/audio/sfx/kenney/impact/footstep_concrete_002.ogg",
        "res://assets/audio/sfx/kenney/impact/footstep_concrete_003.ogg",
        "res://assets/audio/sfx/kenney/impact/footstep_concrete_004.ogg"
    ],
    # 自产脚步扩充（tools 合成管线，CC0）：玻璃=温室碎晶面、wet=雨铸运河积水面。
    "glass": [
        "res://assets/audio/sfx/generated_footsteps/footstep_glass_000.ogg",
        "res://assets/audio/sfx/generated_footsteps/footstep_glass_001.ogg",
        "res://assets/audio/sfx/generated_footsteps/footstep_glass_002.ogg",
        "res://assets/audio/sfx/generated_footsteps/footstep_glass_003.ogg",
        "res://assets/audio/sfx/generated_footsteps/footstep_glass_004.ogg"
    ],
    "wet": [
        "res://assets/audio/sfx/generated_footsteps/footstep_wet_000.ogg",
        "res://assets/audio/sfx/generated_footsteps/footstep_wet_001.ogg",
        "res://assets/audio/sfx/generated_footsteps/footstep_wet_002.ogg",
        "res://assets/audio/sfx/generated_footsteps/footstep_wet_003.ogg",
        "res://assets/audio/sfx/generated_footsteps/footstep_wet_004.ogg"
    ]
}
const FOOTSTEP_BASE_PITCH := {"obsidian": 0.82}
## 静态材质重映射：工程无逐 tile surface_tag，脚步材质由 main_level 按章节主题一刀切
## 写入 footstep_material；播放端把 ch04 温室（fiber 主题）重定向到 glass、
## ch02 雨铸运河（copper 主题）重定向到 wet，主题映射表本身不动。
const FOOTSTEP_MATERIAL_REMAP := {"fiber": "glass", "copper": "wet"}
## 脚步压低音量（规格要求约 -14dB），避免盖过攻击/能力等动作音。
const FOOTSTEP_VOLUME_DB := -14.0
## 步距（像素）：跑速 285 时约 3.2 步/秒，与 10fps 四帧 run 循环观感一致。
const FOOTSTEP_STRIDE := 88.0
const PLAYER_MANIFEST := "res://assets/sprites/player/generated_hero_v2/manifest.json"
const HIT_FLASH_SHADER := preload("res://shaders/hit_flash.gdshader")

## 绯线视觉语言色值（docs/spec/20260726160500000 §1.2）
const THREAD_T1_CORE := Color(1.0, 0.957, 0.902, 0.92)
const THREAD_T1_GLOW := Color(0.902, 0.224, 0.314, 0.55)
const THREAD_T2_CORE := Color(0.902, 0.224, 0.314, 0.88)
const THREAD_T2_GLOW := Color(1.0, 0.549, 0.478, 0.30)
const THREAD_T3_CORE := Color(0.949, 0.757, 0.306, 0.92)
const THREAD_T3_GLOW := Color(0.902, 0.224, 0.314, 0.35)

@export var speed: float = 285.0
@export var jump_velocity: float = -710.0
@export var gravity: float = 1850.0
@export var dash_speed: float = 780.0
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12
@export var jump_cut_multiplier: float = 0.48
@export var dash_time: float = 0.16
@export var dash_cooldown_time: float = 0.60
## When false the dash input is ignored; unlocked by the thread_dash pickup
## in ability-gated chapters (main_level syncs this from inventory state).
@export var dash_unlocked: bool = true
## When false wall-grip is inert (behaviour identical to pre-ch2 builds);
## unlocked by the silk_wall_grip pickup (main_level syncs from inventory).
@export var wall_grip_unlocked: bool = false
@export var wall_slide_max_speed: float = 90.0
@export var wall_jump_horizontal: float = 420.0
@export var wall_jump_vertical: float = -640.0
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
var feel: Node = null
var flash_material: ShaderMaterial = null
var self_flash_timer: float = 0.0
var sprite_base_scale: Vector2 = Vector2.ONE
var pogo_chain: int = 0
var dash_ghost_tick: int = 0
var dash_start_position: Vector2 = Vector2.ZERO
var was_dashing: bool = false
var wall_sliding: bool = false
var was_wall_sliding: bool = false
var wall_slide_audio: AudioStreamPlayer2D = null
## 由 main_level 按章节 art theme 写入（moss/copper/salt/fiber/obsidian）。
var footstep_material: String = "moss"
var footstep_distance: float = 0.0
## 普攻三采样顺序轮换游标。
var attack_sample_index: int = 0
## 钩索挂住/收线一次性标记（每次挥钩在 _start_attack 重置）。
var hook_latch_played: bool = false
var hook_reel_played: bool = false
## UI 输入闸（共享契约）：main_level 在任一 overlay（背包/地图/对话/设置）开合时
## 用 player.set("ui_input_locked", opened) 同步；为 true 时忽略 move_left/right
## 与 aim_up/down，不影响 Esc/UI 键与既有暂停逻辑。
var ui_input_locked: bool = false
var snare_timer := 0.0

func apply_snare(seconds: float) -> void:
    snare_timer=maxf(snare_timer,seconds)


func _ready() -> void:
    add_to_group("player")
    spawn_position = global_position
    _ensure_input_actions()
    _load_sprite_frames()
    attack_shape.disabled = true
    _sync_attack_hitbox()
    feel = get_node_or_null("/root/FeelKit")
    sprite_base_scale = sprite.scale
    flash_material = ShaderMaterial.new()
    flash_material.shader = HIT_FLASH_SHADER
    sprite.material = flash_material
    floor_snap_length=18.0
    floor_constant_speed=true
    hp_changed.emit(hp)
    energy_changed.emit(energy, max_energy)


func _physics_process(delta: float) -> void:
    if ui_input_locked:
        return
    snare_timer=maxf(0,snare_timer-delta)
    if dash_timer>0:
        snare_timer=0
    if death_timer > 0.0:
        wall_sliding = false
        _update_wall_slide_audio()
        death_timer -= delta
        if death_timer <= 0.0:
            _hard_respawn()
        _play(&"death")
        return

    if hurt_timer > 0.0:
        hurt_timer -= delta

    if self_flash_timer > 0.0:
        self_flash_timer -= delta
        if flash_material != null:
            flash_material.set_shader_parameter("flash_amount", 1.0 if self_flash_timer > 0.017 else 0.0)

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
    var input_axis := _move_axis()

    if input_axis != 0.0:
        facing = signi(input_axis)
        sprite.flip_h = facing < 0
        _sync_attack_hitbox()

    # silk_wall_grip (ch2 能力)：解锁后贴墙减速下滑；未解锁时行为与旧版完全一致。
    wall_sliding = false
    if wall_grip_unlocked and not is_on_floor() and is_on_wall() and dash_timer <= 0.0 and velocity.y > 0.0:
        var slide_wall_dir := signi(-get_wall_normal().x)
        if input_axis != 0.0 and signi(input_axis) == slide_wall_dir:
            wall_sliding = true
            velocity.y = minf(velocity.y, wall_slide_max_speed)

    if jump_buffer_timer > 0.0 and coyote_timer > 0.0 and dash_timer <= 0.0:
        velocity.y = jump_velocity
        coyote_timer = 0.0
        jump_buffer_timer = 0.0
        _play(&"jump_start")
        _play_sfx("jump", -6.0)
    elif jump_buffer_timer > 0.0 and dash_timer <= 0.0 and wall_grip_unlocked and not is_on_floor() and is_on_wall():
        # 蹬墙跳：离墙水平 420 / 垂直 -640，播 wall_slide 帧。
        var jump_wall_dir := signi(-get_wall_normal().x)
        velocity.x = -float(jump_wall_dir) * wall_jump_horizontal
        velocity.y = wall_jump_vertical
        facing = -jump_wall_dir
        sprite.flip_h = facing < 0
        _sync_attack_hitbox()
        jump_buffer_timer = 0.0
        coyote_timer = 0.0
        wall_sliding = false
        _play(&"wall_slide")
        _play_sfx("jump", -6.0)

    if Input.is_action_just_released("jump") and velocity.y < 0.0:
        velocity.y *= jump_cut_multiplier

    if Input.is_action_just_pressed("dash") and dash_unlocked and dash_cooldown <= 0.0 and dash_timer <= 0.0:
        dash_timer = dash_time
        dash_cooldown = dash_cooldown_time
        velocity.y = 0.0
        velocity.x = dash_speed * facing
        dash_ghost_tick = 0
        dash_start_position = global_position
        if feel != null:
            feel.add_trauma(0.08)
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
        if dash_ghost_tick % 2 == 0:
            _spawn_dash_ghost()
        dash_ghost_tick += 1
        if dash_timer <= 0.0:
            _spawn_dash_trail()
    elif attack_timer <= 0.0:
        var movement_speed := speed * (0.58 if snare_timer > 0.0 else 1.0)
        velocity.x = move_toward(velocity.x, input_axis * movement_speed, speed * 9.5 * delta)
    else:
        var movement_speed := speed * (0.58 if snare_timer > 0.0 else 1.0)
        velocity.x = move_toward(velocity.x, input_axis * movement_speed * 0.45, speed * 5.0 * delta)

    _update_attack(delta)
    var fall_speed := velocity.y
    move_and_slide()
    if not was_on_floor and is_on_floor():
        land_timer = 0.14
        pogo_chain = 0
        _play_land_sfx(fall_speed)
        _spawn_land_vfx()
    _update_wall_slide_audio()
    _update_footsteps(delta)
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
    hook_latch_played = false
    hook_reel_played = false
    _sync_attack_hitbox()
    _play(animation)
    if animation == &"hook_throw":
        _play_sfx("hook", -6.0)
    elif animation == &"attack_2":
        _play_sfx("skill", -7.0)
    else:
        _play_attack_swing_sfx()
    _spawn_attack_vfx(animation)


## 普攻三采样顺序轮换 + 每次 ±4% 随机变调（音频规格 §4.1）；
## 合成包缺失时回落旧 player_attack.ogg。
func _play_attack_swing_sfx() -> void:
    var variant_keys := ["attack_v1", "attack_v2", "attack_v3"]
    var key: String = variant_keys[attack_sample_index % variant_keys.size()]
    attack_sample_index = (attack_sample_index + 1) % variant_keys.size()
    if not FileAccess.file_exists(String(SFX.get(key, ""))):
        key = "attack"
    _play_sfx(key, -5.0, randf_range(0.96, 1.04), "player_attack")


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
        if elapsed > 0.36 and not hook_reel_played:
            # 收线音对齐 0.22s 钩索回收淡出（命中窗关闭点）；待真正钩环抓取
            # 位移机制落地后，此音迁移到位移开始点。
            hook_reel_played = true
            _play_sfx("hook_reel", -8.0)
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
            if current_attack == &"hook_throw" and not hook_latch_played:
                # 钩索"挂住"=钩击命中确认（与 hitstop 同拍）；每次挥钩仅播一次。
                hook_latch_played = true
                _play_sfx("hook_latch", -6.0)
                # ch2 beat `echo_hook`（manifest ch02_beat_02）：雨铸运河钩击命中后
                # 叠一拍水声回响（金属声后接水面回声，采样内已含节拍延迟）。
                if footstep_material == "copper":
                    _play_sfx("ch02_beat_echo_hook", -10.0)
            var killed := not is_instance_valid(node) or int(node.get("hp")) <= 0
            gain_energy(energy_per_hit)
            _apply_downslash_bounce(node.global_position)
            _trigger_hit_feedback(killed)
            _spawn_hit_confirm_vfx(node.global_position, current_attack)


## 命中反馈分档（规格 §2.1/§2.2）：hitstop + trauma + 击杀闪帧。
func _trigger_hit_feedback(killed: bool) -> void:
    if feel == null:
        return
    var is_downslash := current_attack != &"hook_throw" and current_attack_direction.y > 0.5
    var stop_ms := 45.0
    var trauma := 0.16
    if current_attack == &"attack_2":
        stop_ms = 120.0 if killed else 75.0
        trauma = 0.30
    elif is_downslash:
        stop_ms = 50.0 if killed else 40.0
        trauma = 0.12
    elif current_attack == &"hook_throw":
        stop_ms = 50.0
        trauma = 0.14
    elif killed:
        stop_ms = 90.0
    feel.hitstop(stop_ms)
    feel.add_trauma(trauma)
    if killed:
        feel.flash_screen(Color.WHITE, 0.08, 1)


func _sync_attack_hitbox() -> void:
    attack_hitbox.position = _attack_center_offset()
    var rectangle := attack_shape.shape as RectangleShape2D
    if rectangle != null:
        rectangle.size = _attack_size()


func _read_attack_direction() -> Vector2:
    if not ui_input_locked and Input.is_action_pressed("aim_down"):
        return Vector2.DOWN
    if not ui_input_locked and Input.is_action_pressed("aim_up"):
        return Vector2.UP
    var input_axis := _move_axis()
    if absf(input_axis) > 0.1:
        return Vector2(signf(input_axis), 0.0)
    return Vector2(float(facing), 0.0)


## UI 输入闸（共享契约）：overlay 打开时移动/瞄准输入归零。
func _move_axis() -> float:
    if ui_input_locked:
        return 0.0
    return Input.get_axis("move_left", "move_right")


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
    _play_pogo_squash()
    pogo_chain = mini(pogo_chain + 1, 4)
    # pogo=敲钟（音频规格 §4.2）：D5 小铜铃自产音源，连击保留半音阶 pitch 爬升。
    _play_sfx("pogo", -6.0, pow(2.0, float(pogo_chain) / 12.0))
    # ch4 beat `thorn_downstrike`（manifest ch04_beat_01）：断弦温室（fiber 主题）
    # 下劈命中反弹时叠短促木质裂声。
    if footstep_material == "fiber":
        _play_sfx("ch04_beat_thorn_downstrike", -11.0)


## pogo 压缩–弹射形变（规格 §2.2）：压缩 → 拉伸 → 弹性回正。
func _play_pogo_squash() -> void:
    if sprite == null:
        return
    sprite.scale = sprite_base_scale * Vector2(0.86, 1.14)
    var tween := create_tween()
    tween.tween_interval(0.033)
    tween.tween_property(sprite, "scale", sprite_base_scale * Vector2(1.12, 0.84), 0.033)
    tween.tween_property(sprite, "scale", sprite_base_scale, 0.10).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


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
    elif wall_sliding and not is_on_floor():
        _play(&"wall_slide")
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


func _play_sfx(audio_key: String, volume_db: float = -5.0, pitch_scale: float = 1.0, voice_key: String = "", voice_priority: int = 1) -> void:
    if not _should_play_sfx():
        return
    # 声部准入（AudioDirector 契约）：同 key 最小间隔/并发上限/全局 24 声部抢占。
    var resolved_voice_key := voice_key if not voice_key.is_empty() else "player_" + audio_key
    if not _request_voice(resolved_voice_key, voice_priority):
        return
    var stream := _load_sfx_stream(audio_key)
    if stream == null:
        # 声部回滚（AudioDirector 契约）：流缺失/解码失败时释放已占用的声部。
        _release_voice(resolved_voice_key)
        return
    var player_node := AudioStreamPlayer2D.new()
    player_node.name = "Sfx_" + audio_key
    # 总线归位（音频规格 §5.1）：玩家动作音走 SFXPlayer 子总线，缺席时回落 SFX/Master。
    player_node.bus = _sfx_bus_name()
    player_node.stream = stream
    player_node.volume_db = volume_db
    player_node.pitch_scale = pitch_scale
    player_node.max_distance = 900.0
    add_child(player_node)
    player_node.finished.connect(Callable(player_node, "queue_free"))
    player_node.play()


## 落地分档（音频规格 §4.1）：按触地前一帧的下落速度选软/硬落地采样。
func _play_land_sfx(fall_speed: float) -> void:
    if fall_speed >= 620.0:
        _play_sfx("land_hard", -8.0, 1.0, "player_land")
    else:
        _play_sfx("land_soft", -10.0, 1.0, "player_land")


## 玩家音源总线：SFXPlayer（AudioDirector 子总线，send→SFX）→ SFX → Master 逐级回落。
func _sfx_bus_name() -> String:
    if AudioServer.get_bus_index("SFXPlayer") != -1:
        return "SFXPlayer"
    return "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"


## AudioDirector 脚本懒加载（headless 局部验证时脚本可缺席）。
static func _ensure_audio_director() -> bool:
    if audio_director_script == null and ResourceLoader.exists(AUDIO_DIRECTOR_PATH):
        audio_director_script = load(AUDIO_DIRECTOR_PATH)
    return audio_director_script != null


## AudioDirector.request_voice 静态转调：脚本尚未落盘（headless 局部验证）时放行，
## 返回 false 表示本次不播。
static func _request_voice(key: String, priority: int = 1, min_interval_ms: int = 40, max_voices: int = 3) -> bool:
    if not _ensure_audio_director():
        return true
    return bool(audio_director_script.request_voice(key, priority, min_interval_ms, max_voices))


## AudioDirector.release_voice 静态转调（声部回滚契约）：拿不到流时释放已批准的声部。
static func _release_voice(key: String) -> void:
    if _ensure_audio_director() and audio_director_script.has_method("release_voice"):
        audio_director_script.release_voice(key)


## 冲刺残影（规格 §2.3）：每 2 物理帧留 1 影，绯红加法混合，前重后轻褪色。
func _spawn_dash_ghost() -> void:
    var parent_node := get_parent()
    if parent_node == null or sprite == null or sprite.sprite_frames == null:
        return
    var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
    if texture == null:
        return
    var ghost := Sprite2D.new()
    ghost.name = "DashGhost"
    ghost.texture = texture
    ghost.flip_h = sprite.flip_h
    ghost.offset = sprite.offset
    ghost.self_modulate = Color(THREAD_T2_CORE.r, THREAD_T2_CORE.g, THREAD_T2_CORE.b, 0.55)
    ghost.z_index = 55
    var ghost_material := CanvasItemMaterial.new()
    ghost_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    ghost.material = ghost_material
    parent_node.add_child(ghost)
    ghost.global_transform = sprite.global_transform
    var tween := ghost.create_tween()
    tween.tween_property(ghost, "self_modulate:a", 0.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tween.parallel().tween_property(ghost, "scale", ghost.scale * 0.94, 0.24)
    tween.finished.connect(Callable(ghost, "queue_free"))


## 冲刺线迹（规格 §2.3）：起点→终点一条 T2 主线，结束后从尾端收回（收线律）。
func _spawn_dash_trail() -> void:
    var parent_node := get_parent()
    if parent_node == null:
        return
    var from := dash_start_position + Vector2(0.0, -34.0)
    var to := global_position + Vector2(0.0, -34.0)
    if from.distance_to(to) < 24.0:
        return
    var trail := Line2D.new()
    trail.name = "DashTrailVfx"
    trail.width = 3.0
    trail.default_color = THREAD_T2_CORE
    trail.z_index = 56
    trail.points = PackedVector2Array([from, to])
    parent_node.add_child(trail)
    var glow := Line2D.new()
    glow.name = "DashTrailGlow"
    glow.width = 3.0 * 2.6
    glow.default_color = THREAD_T2_GLOW
    glow.z_index = 55
    glow.points = PackedVector2Array([from, to])
    var glow_material := CanvasItemMaterial.new()
    glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    glow.material = glow_material
    parent_node.add_child(glow)
    var tween := trail.create_tween()
    tween.tween_method(func(t: float) -> void:
        var retracted := PackedVector2Array([from.lerp(to, t), to])
        if is_instance_valid(trail):
            trail.points = retracted
        if is_instance_valid(glow):
            glow.points = retracted
    , 0.0, 1.0, 0.20)
    tween.finished.connect(Callable(trail, "queue_free"))
    tween.finished.connect(Callable(glow, "queue_free"))


func _should_play_sfx() -> bool:
    if DisplayServer.get_name() != "headless":
        return true
    for arg in OS.get_cmdline_args():
        if String(arg).contains("audio_visual_validation.gd"):
            return true
    return false


func _load_sfx_stream(audio_key: String, looped: bool = false) -> AudioStream:
    return _load_stream_for_path(String(SFX.get(audio_key, "")), looped)


## 流缓存（AudioDirector 契约）：全部音频加载改走静态缓存 load_cached（键 path|looped，
## 含负缓存）；脚本缺席或方法未落地时回退旧直读，保证 headless 局部验证可跑。
static func _load_stream_for_path(path: String, looped: bool = false) -> AudioStream:
    if path.is_empty():
        return null
    if _ensure_audio_director() and audio_director_script.has_method("load_cached"):
        return audio_director_script.load_cached(path, looped)
    return _load_stream_direct(path, looped)


static func _load_stream_direct(path: String, looped: bool = false) -> AudioStream:
    if not FileAccess.file_exists(path):
        return null
    if path.ends_with(".ogg"):
        var ogg := AudioStreamOggVorbis.load_from_file(path)
        if ogg != null and looped:
            ogg.loop = true
        return ogg
    if path.ends_with(".wav"):
        # 自产 SFX 包走 WAV 直读（Godot 4.6 headless 安全，无需 import 资源）。
        var wav := AudioStreamWAV.load_from_file(path)
        if wav != null and looped:
            wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
            wav.loop_begin = 0
            # 16bit 帧数按实际声道数折算，避免立体声 loop_end 超界一倍。
            wav.loop_end = wav.data.size() / (4 if wav.stereo else 2)
        return wav
    return load(path) as AudioStream


## 蹬墙攀滑音频（音频规格 §4.2 wall_grip/wall_slide_loop）：
## attach 一次性吸附音 + 可循环摩擦 loop，下滑速度映射音高；离墙/死亡即停，
## 循环播放器挂在玩家节点下随场景销毁，不泄漏。
func _update_wall_slide_audio() -> void:
    if wall_sliding and not was_wall_sliding:
        _play_sfx("wall_grip_attach", -7.0)
        # ch2 beat `wall_grip`（manifest ch02_beat_01）：雨铸运河（copper 主题）贴墙时
        # 吸附音 0.15s 后叠一层水滴尾音。
        if footstep_material == "copper":
            get_tree().create_timer(0.15).timeout.connect(func() -> void:
                if is_instance_valid(self):
                    _play_sfx("ch02_beat_wall_grip_drip", -12.0))
        _start_wall_slide_loop()
    elif not wall_sliding and was_wall_sliding:
        _stop_wall_slide_loop()
    if wall_sliding and wall_slide_audio != null and is_instance_valid(wall_slide_audio):
        wall_slide_audio.pitch_scale = clampf(0.85 + velocity.y / maxf(wall_slide_max_speed, 1.0) * 0.35, 0.8, 1.35)
    was_wall_sliding = wall_sliding


func _start_wall_slide_loop() -> void:
    if not _should_play_sfx():
        return
    if not _request_voice("player_wall_slide_loop", 1, 40, 1):
        return
    if wall_slide_audio == null or not is_instance_valid(wall_slide_audio):
        # looped=true 走独立缓存键（AudioDirector 契约）：不原地改缓存流的 loop 标记。
        var stream := _load_sfx_stream("wall_slide_loop", true)
        if stream == null:
            _release_voice("player_wall_slide_loop")
            return
        wall_slide_audio = AudioStreamPlayer2D.new()
        wall_slide_audio.name = "SfxLoop_wall_slide"
        wall_slide_audio.bus = _sfx_bus_name()
        wall_slide_audio.stream = stream
        wall_slide_audio.volume_db = -13.0
        wall_slide_audio.max_distance = 900.0
        add_child(wall_slide_audio)
    if not wall_slide_audio.playing:
        wall_slide_audio.play()


func _stop_wall_slide_loop() -> void:
    if wall_slide_audio != null and is_instance_valid(wall_slide_audio) and wall_slide_audio.playing:
        wall_slide_audio.stop()


## 材质化脚步触发（音频规格 §4.2）：地面横移时按"距离积分"计步——
## 每累计 FOOTSTEP_STRIDE 像素触发一步，比动画帧回调更抗速度突变。
func _update_footsteps(delta: float) -> void:
    if not is_on_floor() or dash_timer > 0.0 or attack_timer > 0.0 or absf(velocity.x) < 60.0:
        # 停步/离地时把计步器压到半步：再起步时第一声脚步很快落地，不抢拍。
        footstep_distance = FOOTSTEP_STRIDE * 0.55
        return
    footstep_distance += absf(velocity.x) * delta
    if footstep_distance >= FOOTSTEP_STRIDE:
        footstep_distance = 0.0
        _play_footstep()


func _play_footstep() -> void:
    if not _should_play_sfx():
        return
    if not _request_voice("player_footstep", 2, 90, 2):
        return
    var material_key := String(FOOTSTEP_MATERIAL_REMAP.get(footstep_material, footstep_material))
    var variants: Array = FOOTSTEP_VARIANTS.get(material_key, FOOTSTEP_VARIANTS["moss"])
    if variants.is_empty():
        return
    var path := String(variants[randi() % variants.size()])
    var stream := _load_stream_for_path(path)
    if stream == null:
        _release_voice("player_footstep")
        return
    var player_node := AudioStreamPlayer2D.new()
    player_node.name = "SfxStep"
    player_node.bus = _sfx_bus_name()
    player_node.stream = stream
    player_node.volume_db = FOOTSTEP_VOLUME_DB
    # 变体随机轮播 + ±4% 随机变调（丝之歌式"连打不重样"的最低成本实现）。
    player_node.pitch_scale = float(FOOTSTEP_BASE_PITCH.get(material_key, 1.0)) * randf_range(0.96, 1.04)
    player_node.max_distance = 900.0
    add_child(player_node)
    player_node.finished.connect(Callable(player_node, "queue_free"))
    player_node.play()


func _spawn_heal_effect() -> void:
    for index in range(3):
        _add_heal_ring(22.0 + float(index) * 15.0, 0.10 * float(index))
    for index in range(8):
        var thread := Line2D.new()
        thread.name = "HealThread"
        var x := -34.0 + float(index) * 9.7
        thread.points = PackedVector2Array([Vector2(x, -18.0), Vector2(x + 4.0, -76.0)])
        thread.width = 2.0
        thread.default_color = Color(THREAD_T3_CORE.r, THREAD_T3_CORE.g, THREAD_T3_CORE.b, 0.82)
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
    ring.default_color = THREAD_T3_CORE
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
    slash.default_color = THREAD_T1_CORE
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
    var glow := _make_glow_twin(slash, 2.2, THREAD_T1_GLOW)
    add_child(glow)
    add_child(slash)
    var tween := create_tween()
    tween.tween_property(slash, "scale", Vector2(1.28, 1.28), 0.15)
    tween.parallel().tween_property(slash, "modulate:a", 0.0, 0.15)
    tween.parallel().tween_property(glow, "scale", Vector2(1.28, 1.28), 0.15)
    tween.parallel().tween_property(glow, "modulate:a", 0.0, 0.15)
    tween.finished.connect(Callable(slash, "queue_free"))
    tween.finished.connect(Callable(glow, "queue_free"))


## 辉光复线（规格 §1.2）：同路径宽复线 + 加法混合，构成廉价 2D 辉光。
func _make_glow_twin(line: Line2D, width_ratio: float, glow_color: Color) -> Line2D:
    var glow := Line2D.new()
    glow.name = String(line.name) + "Glow"
    glow.points = line.points
    glow.width = line.width * width_ratio
    glow.default_color = glow_color
    glow.z_index = line.z_index - 1
    var glow_material := CanvasItemMaterial.new()
    glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    glow.material = glow_material
    return glow


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
    spark.default_color = THREAD_T1_CORE
    spark.z_index = 80
    spark.modulate = Color(1.0, 1.0, 1.0, 1.0).lerp(Color(THREAD_T1_GLOW.r, THREAD_T1_GLOW.g, THREAD_T1_GLOW.b, 1.0), 0.25)
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
    # P0 生死攸关音：声部抢占最高优先级。
    _play_sfx("hurt", -6.0, 1.0, "", 0)
    _spawn_thread_snap_vfx(source_position)
    if hp <= 0:
        death_timer = 0.9
        velocity = Vector2.ZERO
        _stop_wall_slide_loop()
        # 死亡=绯线松脱（音频规格 §4.2 player_death）：无惨叫，只有线散与长呼气。
        _play_sfx("death_cocoon", -5.0, 1.0, "", 0)
        if feel != null:
            feel.hitstop(200.0)
            feel.add_trauma(0.60)
            feel.black_frame(global_position, 3)
        _play(&"death")
        return
    if feel != null:
        feel.hitstop(110.0)
        feel.add_trauma(0.45)
        feel.black_frame(global_position, 2)
    self_flash_timer = 0.05
    if flash_material != null:
        flash_material.set_shader_parameter("flash_amount", 1.0)
    gain_energy(energy_on_damage)
    hurt_timer = 0.35
    var knockback_dir := signf(global_position.x - source_position.x)
    if knockback_dir == 0.0:
        knockback_dir = -facing
    velocity = Vector2(knockback_dir * 260.0, -170.0)
    _play(&"hurt")


## 受伤丝线崩断（规格 §2.10）：从受击点向外 5 条绯线绷断飞散。
func _spawn_thread_snap_vfx(source_position: Vector2) -> void:
    var parent_node := get_parent()
    if parent_node == null:
        return
    var origin := global_position + Vector2(0.0, -34.0)
    var away := signf(global_position.x - source_position.x)
    if away == 0.0:
        away = -float(facing)
    for index in range(5):
        var thread := Line2D.new()
        thread.name = "ThreadSnapVfx"
        var angle := -PI * 0.5 + (float(index) - 2.0) * 0.42 + away * 0.3
        var length := 20.0 + float(index % 3) * 7.0
        var tip := Vector2(cos(angle), sin(angle)) * length
        thread.points = PackedVector2Array([Vector2.ZERO, tip])
        thread.width = 3.0
        thread.default_color = THREAD_T2_CORE
        thread.z_index = 80
        thread.position = origin
        parent_node.add_child(thread)
        var tween := thread.create_tween()
        tween.tween_property(thread, "position", origin + tip * 0.8, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tween.parallel().tween_property(thread, "modulate:a", 0.0, 0.25)
        tween.finished.connect(Callable(thread, "queue_free"))


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
    # 钟龛复活（音频规格 §4.2 player_respawn）：龛铃三音上行 + 吸气。
    _play_sfx("respawn_weave", -7.0, 1.0, "", 0)
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
