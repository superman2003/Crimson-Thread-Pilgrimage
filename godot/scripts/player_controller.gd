extends CharacterBody2D

signal hp_changed(value: int)
signal player_respawned
signal energy_changed(value: int, maximum: int)
var arrival_guard_timer := 0.0

signal ability_action(ability_id: String, origin: Vector2, direction: Vector2)
signal heal_state_changed(state: String)
signal skill_cast(skill_id: String)

@export var debug_invulnerable := false
@export var bell_guard_unlocked := false
@export var thorn_downstrike_unlocked := false
@export var lantern_phase_unlocked := false
@export var crown_resonance_unlocked := false
@export var heal_duration := 0.85
@export var heal_amount := 1
var build_system: RefCounted = null
var selected_skill: Dictionary = {}
var build_profile: Dictionary = {}
var heal_timer := 0.0
var heal_reserved_cost := 0
var heal_reserved_loss_ratio := 1.0
var heal_reservation_generation := 0
var guard_timer := 0.0
var guard_cooldown := 0.0
var guard_refunded := false
var guard_initial_duration := 0.42
var resonance_cooldown := 0.0
var phase_active := false
var phase_energy_fraction := 0.0
var phase_safe_position := Vector2.ZERO
var phase_exceptions: Array[PhysicsBody2D] = []
var attack_vfx_started := false
var attack_windup := 0.06
var attack_active_time := 0.22
var active_skill: Dictionary = {}
var skill_effect_started := false
var traversal_downstrike_active := false
var build_baseline: Dictionary = {}
var wall_jump_lock := 0.0
var line_stacks := 0
var line_expiry := 0.0
var bell_pressure := 0
var heal_speed_timer := 0.0
var heal_stability_timer := 0.0
var status_resist_timer := 0.0
## Thread drawn from practice racks stays at the rack: leaving takes back
## whatever of it is still unspent, so racks cannot fill the meter for a fight.
var practice_energy := 0
## C04: the last cast skill lets a practice rack tell which skill hit it.
var last_skill_cast := ""
var last_skill_cast_msec := -100000
var heal_reserved_practice := 0
const PRACTICE_ENERGY_RADIUS := 520.0
var crosscut_refund_paid := false
var seal_presentation: Node2D = null
var seal_recovery_shown := false
var skill_displacement_done := 0.0

func _seal_present(id: String, stage: String) -> void:
    if seal_presentation == null and ResourceLoader.exists("res://scripts/seal_presentation.gd"):
        seal_presentation = Node2D.new()
        seal_presentation.set_script(load("res://scripts/seal_presentation.gd"))
        add_child(seal_presentation)
    if seal_presentation != null:
        seal_presentation.set("muted", float(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))) <= -70.0 if AudioServer.get_bus_index("SFX") >= 0 else false)
        seal_presentation.set("reduced_flash", not bool(_accessibility().get("flash_enabled", true)))
        seal_presentation.play_action(id, stage, facing, {"range":attack_range})


func _seal_mechanism_ready() -> bool:
    return bool(build_profile.get("mechanism_unlocked", true)) and (_crest() != "crimson" or bool(build_profile.get("crimson_repaired", true)))

func get_seal_mechanism_snapshot() -> Dictionary:
    var state := {"label":"线势", "stacks":line_stacks, "max_stacks":3, "remaining":line_expiry}
    if _crest() == "bell":
        state = {"label":"钟压", "stacks":bell_pressure, "max_stacks":2, "remaining":0.0}
    elif _crest() == "salt":
        var count := 0
        for enemy in get_tree().get_nodes_in_group("enemy"):
            if enemy.has_method("world_residency_active") and not enemy.world_residency_active():
                continue
            if enemy.get("salt_mark_timer") != null and float(enemy.get("salt_mark_timer")) > 0.0:
                count += 1
        state = {"label":"盐记", "stacks":count, "max_stacks":0, "remaining":0.0}
    state["unlocked"] = _seal_mechanism_ready()
    state["heal_effect"] = "疾行" if heal_speed_timer > 0.0 else "抗击退" if heal_stability_timer > 0.0 else ""
    state["heal_remaining"] = maxf(heal_speed_timer,heal_stability_timer)
    return state

func get_seal_combat_state() -> Dictionary:
    return {"crest": String(build_profile.get("crest_id", "crimson")), "line_stacks": line_stacks, "bell_pressure": bell_pressure, "line_expiry": line_expiry, "heal_speed": heal_speed_timer, "heal_stability": heal_stability_timer}

func _seal_tick(delta: float) -> void:
    line_expiry = maxf(0.0, line_expiry - delta)
    if line_expiry <= 0.0:
        line_stacks = 0
    heal_speed_timer = maxf(0.0, heal_speed_timer - delta)
    heal_stability_timer = maxf(0.0, heal_stability_timer - delta)
    status_resist_timer = maxf(0.0, status_resist_timer - delta)
    _settle_practice_energy()

func _settle_practice_energy() -> void:
    practice_energy = mini(practice_energy, energy)
    if practice_energy <= 0:
        practice_energy = 0
        return
    for node in get_tree().get_nodes_in_group("enemy"):
        if node is Node2D and (node.has_meta("seal_training_target") or node.has_meta("tool_training_target")) and node.global_position.distance_to(global_position) <= PRACTICE_ENERGY_RADIUS:
            return
    var unspent := practice_energy
    practice_energy = 0
    gain_energy(-unspent)

func _heal_airborne() -> bool:
    return bool(build_profile.get("heal_airborne", false))

func _crest() -> String:
    return String(build_profile.get("crest_id", "crimson"))

func _basic_seal_hit() -> void:
    if _crest() == "crimson" and _seal_mechanism_ready():
        line_stacks = mini(3, line_stacks + 1)
        line_expiry = 3.5

func _seal_heal_completed() -> void:
    if _crest() == "crimson":
        heal_speed_timer = maxf(0.0,float(build_profile.get("heal_move_duration",2.5)))
    elif _crest() == "bell":
        heal_stability_timer = maxf(0.0,float(build_profile.get("heal_knockback_duration",4.0)))
    elif _crest() == "salt":
        for enemy in get_tree().get_nodes_in_group("enemy"):
            if enemy.has_method("world_residency_active") and not enemy.world_residency_active():
                continue
            if enemy is Node2D and enemy.global_position.distance_to(global_position) <= 240.0 and enemy.has_method("extend_salt_mark_once"):
                enemy.extend_salt_mark_once(maxf(0.0,float(build_profile.get("heal_mark_extension",2.0))))
    if float(build_profile.get("status_buildup_mult", 1.0)) < 1.0:
        status_resist_timer = 3.0



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
const PLAYER_MANIFEST := "res://assets/sprites/player/generated_hero_v3/manifest.json"
# Runtime registration of the existing four idle poses, in source-texture pixels.
# Midpoint of the two opaque boot soles (y=276..281), not cape/weapon bounds.
# The source poses change their stance slightly; this removes the whole-body
# side-to-side drift without replacing the authored breathing/cape frames.
const IDLE_FOOT_CENTER_X := [186.223262, 187.667973, 186.765838, 185.263814]
# Preserve the authored nominal cadence (285 px/s, four poses at 12 fps), but
# advance it from collision-resolved ground travel rather than a wall clock.
const RUN_CYCLE_DISTANCE := 95.0
const GROUND_MOTION_EPSILON := 1.0
const CAMERA_FOCUS := preload("res://scripts/camera_focus.gd")
var camera_focus := CAMERA_FOCUS.new()
const ROOM_CAMERA := preload("res://scripts/room_camera.gd")
var room_camera := ROOM_CAMERA.new()

const HIT_FLASH_SHADER := preload("res://shaders/hit_flash.gdshader")
const CONTACT_ART := preload("res://scripts/player_contact_art.gd")
const ABILITY_ART := preload("res://scripts/player_ability_art.gd")
const HOOK_ART := preload("res://scripts/player_hook_art.gd")
const DASH_ART := preload("res://scripts/player_dash_art.gd")
const HURT_ART := preload("res://scripts/player_hurt_art.gd")
const MOVEMENT_ART := preload("res://scripts/player_movement_art.gd")
const HEAL_ART := preload("res://scripts/player_heal_art.gd")
const GUARD_ART := preload("res://scripts/player_guard_art.gd")
const VISUAL_POLICY := preload("res://scripts/combat_visual_policy.gd")
const MELEE_FEEDBACK := preload("res://scripts/player_melee_feedback.gd")
const HAZARD_POGO := preload("res://scripts/hazard_pogo.gd")
const LAYERED_IDLE := preload("res://scripts/player_layered_idle.gd")
var layered_idle: Node2D

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
## One pending combat command; seconds of simulation time, independent of FPS.
@export_range(0.0, 0.25, 0.01) var action_buffer_time: float = 0.10
@export var jump_cut_multiplier: float = 0.48
@export var dash_time: float = 0.16
@export var dash_cooldown_time: float = 0.60
## When false the dash input is ignored; unlocked by the thread_dash pickup
## in ability-gated chapters (main_level syncs this from inventory state).
@export var dash_unlocked: bool = true
## When false wall-grip is inert (behaviour identical to pre-ch2 builds);
## unlocked by the silk_wall_grip pickup (main_level syncs from inventory).
@export var wall_grip_unlocked: bool = false
## Inventory IDs: double_thread_jump and echo_hook. main_level owns unlock state.
@export var double_jump_unlocked: bool = false
@export var double_jump_velocity: float = -650.0
@export var thread_grapple_unlocked: bool = false
@export var grapple_range: float = 430.0
@export var grapple_speed: float = 1000.0
@export var grapple_timeout: float = 0.60
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
var buffered_action: StringName = &""
var action_buffer_timer := 0.0
var buffered_direction := Vector2.ZERO
var dash_timer: float = 0.0
var dash_cooldown: float = 0.0
var land_timer: float = 0.0
var attack_timer: float = 0.0
var hurt_timer: float = 0.0
var death_timer: float = 0.0
# Presentation only: do not add a gameplay lock or change the 0.9-second death.
const DEATH_FADE_SECONDS := 0.16
const RESPAWN_REVEAL_SECONDS := 0.18
var respawn_reveal_timer := 0.0
var skill_cooldown: float = 0.0
var heal_cooldown: float = 0.0
var attack_duration: float = 0.34
var current_attack: StringName = &"attack_1"
var attack_damage: int = 1
var attack_range: float = 82.0
var attack_height: float = 72.0
var attack_forward_offset: float = 48.0
var current_attack_direction: Vector2 = Vector2.RIGHT
# Chosen once when a horizontal ground slash starts at running speed, so the
# legs keep striding instead of switching drawings mid-swing.
var run_attack_pose := false
const RUN_ATTACK_MIN_SPEED_RATIO := 0.5
# Up/down slashes keep the drawing family (ground or air) they started with;
# the upward slash's small hop must not swap poses mid-swing.
var attack_started_grounded := true
var enemy_contact_guard_timer: float = 0.0
## Seconds a spike bounce keeps hazard contact from dealing damage.
var hazard_pogo_guard_timer: float = 0.0
var hit_targets: Dictionary = {}
var attack_pogo_paid := false
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
var air_jump_available: bool = true
var grapple_anchor: Node2D = null
var grapple_timer: float = 0.0
var grapple_recovery_timer := 0.0
const GRAPPLE_RECOVERY_TIME := 0.10
var grapple_line: Line2D = null
var wall_slide_audio: AudioStreamPlayer2D = null
## 由 main_level 按章节 art theme 写入（moss/copper/salt/fiber/obsidian）。
var footstep_material: String = "moss"
var footstep_distance: float = 0.0
var ground_motion_x := 0.0
var ground_motion_speed := 0.0
var run_cycle_phase := 0.0
## 普攻三采样顺序轮换游标。
var attack_sample_index: int = 0
## 钩索挂住/收线一次性标记（每次挥钩在 _start_attack 重置）。
var hook_latch_played: bool = false
var hook_reel_played: bool = false
## UI 输入闸（共享契约）：main_level 在任一 overlay（背包/地图/对话/设置）开合时
## 用 player.set("ui_input_locked", opened) 同步；为 true 时忽略 move_left/right
## 与 aim_up/down，不影响 Esc/UI 键与既有暂停逻辑。
var ui_input_locked: bool = false:
    set(value):
        ui_input_locked = value
        if value:
            _clear_action_buffer()
            jump_buffer_timer = 0.0
            camera_focus.clear_look()
var snare_timer := 0.0

func apply_snare(seconds: float) -> void:
    snare_timer=maxf(snare_timer, seconds * (float(build_profile.get("status_buildup_mult", 1.0)) if status_resist_timer > 0.0 else 1.0))


func _ready() -> void:
    add_to_group("player")
    spawn_position = global_position
    _ensure_input_actions()
    _load_sprite_frames()
    sprite.frame_changed.connect(_sync_sprite_pose_anchor)
    sprite.animation_changed.connect(_sync_sprite_pose_anchor)
    _sync_sprite_pose_anchor()
    attack_shape.disabled = true
    _sync_attack_hitbox()
    feel = get_node_or_null("/root/FeelKit")
    sprite_base_scale = sprite.scale
    flash_material = ShaderMaterial.new()
    flash_material.shader = HIT_FLASH_SHADER
    sprite.material = flash_material
    layered_idle = LAYERED_IDLE.new()
    if not layered_idle.attach(sprite):
        layered_idle.free()
        layered_idle = null
    build_baseline = {"max_hp": max_hp, "max_energy": max_energy, "speed": speed,
        "energy_per_hit": energy_per_hit, "heal_energy_cost": heal_energy_cost,
        "heal_amount": heal_amount, "heal_duration": heal_duration}
    phase_safe_position = global_position
    floor_snap_length=18.0
    floor_constant_speed=true
    hp_changed.emit(hp)
    energy_changed.emit(energy, max_energy)


func _physics_process(delta: float) -> void:
    # A newly acquired critical rock body needs one server synchronization.
    # Hold movement/actions for that step; preserve velocity/resources/cooldowns.
    if get_parent().has_method("_world_collision_ready") and not get_parent()._world_collision_ready():
        return
    if ui_input_locked:
        _interrupt_heal()
        _stop_phase()
        if flash_material != null and not bool(_accessibility().get("flash_enabled", true)):
            flash_material.set_shader_parameter("flash_amount", 0.0)
        return
    _update_respawn_reveal(delta)
    arrival_guard_timer = maxf(0.0, arrival_guard_timer - delta)
    if build_system != null and build_system.has_method("tick"):
        build_system.tick(delta)
    guard_timer = maxf(0.0, guard_timer - delta)
    guard_cooldown = maxf(0.0, guard_cooldown - delta)
    resonance_cooldown = maxf(0.0, resonance_cooldown - delta)
    wall_jump_lock = maxf(0.0, wall_jump_lock - delta)
    _update_phase(delta)
    _seal_tick(delta)
    _update_heal(delta)
    snare_timer=maxf(0,snare_timer-delta)
    if dash_timer>0:
        snare_timer=0
    if death_timer > 0.0:
        _clear_action_buffer()
        wall_sliding = false
        _update_wall_slide_audio()
        death_timer -= delta
        if death_timer <= 0.0:
            _hard_respawn()
            return
        _set_death_visibility(death_timer / DEATH_FADE_SECONDS)
        # A finished non-loop death must hold its terminal pose, not restart
        # whenever _play sees is_playing() == false during the remaining hold.
        if sprite.animation != &"death":
            _play(&"death")
        return

    if hurt_timer > 0.0:
        hurt_timer -= delta

    if self_flash_timer > 0.0:
        self_flash_timer -= delta
        if flash_material != null:
            flash_material.set_shader_parameter("flash_amount", 1.0 if self_flash_timer > 0.017 and bool(_accessibility().get("flash_enabled", true)) else 0.0)

    var was_on_floor := is_on_floor()
    if Input.is_action_just_pressed("jump"):
        jump_buffer_timer = jump_buffer_time
    else:
        jump_buffer_timer = maxf(0.0, jump_buffer_timer - delta)

    if is_on_floor():
        air_jump_available = true
        coyote_timer = coyote_time
    else:
        coyote_timer = maxf(0.0, coyote_timer - delta)
        if grapple_timer <= 0.0:
            velocity.y += gravity * delta

    dash_cooldown = maxf(0.0, dash_cooldown - delta)
    land_timer = maxf(0.0, land_timer - delta)
    grapple_recovery_timer = maxf(0.0, grapple_recovery_timer - delta)
    skill_cooldown = maxf(0.0, skill_cooldown - delta)
    heal_cooldown = maxf(0.0, heal_cooldown - delta)
    enemy_contact_guard_timer = maxf(0.0, enemy_contact_guard_timer - delta)
    hazard_pogo_guard_timer = maxf(0.0, hazard_pogo_guard_timer - delta)
    var input_axis := _move_axis()
    _sample_action_input(delta)

    if input_axis != 0.0 and attack_timer <= 0.0 and dash_timer <= 0.0 and heal_timer <= 0.0 and guard_timer <= 0.0:
        facing = signi(input_axis)
        sprite.flip_h = facing < 0
        _sync_attack_hitbox()

    # silk_wall_grip (ch2 能力)：解锁后贴墙减速下滑；未解锁时行为与旧版完全一致。
    wall_sliding = false
    if wall_grip_unlocked and not is_on_floor() and is_on_wall() and dash_timer <= 0.0 and grapple_timer <= 0.0 and heal_timer <= 0.0 and velocity.y > 0.0:
        var slide_wall_dir := signi(-get_wall_normal().x)
        if input_axis != 0.0 and signi(input_axis) == slide_wall_dir:
            wall_sliding = true
            if not was_wall_sliding:
                ability_action.emit("silk_wall_grip", global_position, Vector2(slide_wall_dir, 0))
            velocity.y = minf(velocity.y, wall_slide_max_speed)

    # A fresh jump cancels the pull; holding the original jump never spends the air jump.
    if grapple_timer > 0.0 and Input.is_action_just_pressed("jump"):
        _stop_grapple()
    if Input.is_action_just_pressed("jump"):
        grapple_recovery_timer = 0.0
    if jump_buffer_timer > 0.0 and coyote_timer > 0.0 and dash_timer <= 0.0 and heal_timer <= 0.0 and attack_timer <= 0.0 and hurt_timer <= 0.0:
        velocity.y = jump_velocity
        coyote_timer = 0.0
        jump_buffer_timer = 0.0
        _play(&"jump_start")
        _play_sfx("jump", -6.0)
    elif jump_buffer_timer > 0.0 and dash_timer <= 0.0 and wall_grip_unlocked and not is_on_floor() and is_on_wall() and heal_timer <= 0.0 and attack_timer <= 0.0 and hurt_timer <= 0.0:
        # 蹬墙跳：离墙水平 420 / 垂直 -640，播 wall_slide 帧。
        var jump_wall_dir := signi(-get_wall_normal().x)
        wall_jump_lock = 0.16
        ability_action.emit("silk_wall_grip", global_position, Vector2(-jump_wall_dir, -1))
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
        MOVEMENT_ART.wall_jump(self, jump_wall_dir)

    elif Input.is_action_just_pressed("jump") and double_jump_unlocked and air_jump_available and not is_on_floor() and dash_timer <= 0.0 and heal_timer <= 0.0 and attack_timer <= 0.0 and hurt_timer <= 0.0:
        ability_action.emit("double_thread_jump", global_position, Vector2.UP)
        air_jump_available = false
        velocity.y = double_jump_velocity
        jump_buffer_timer = 0.0
        coyote_timer = 0.0
        wall_sliding = false
        _play(&"jump_start")
        _play_sfx("jump", -6.0, 1.16)
        MOVEMENT_ART.double_jump(self)

    if Input.is_action_just_released("jump") and velocity.y < 0.0:
        velocity.y *= jump_cut_multiplier

    _consume_action_input(&"dash")

    if Input.is_action_just_pressed("bell_guard"):
        _try_guard()
    if Input.is_action_just_pressed("crown_resonance"):
        _try_resonance()
    if Input.is_action_just_pressed("heal"):
        _try_heal()

    if _consume_action_input(&"attack"):
        pass
    elif Input.is_action_just_pressed("hook") and _can_start_action():
        if not _try_start_grapple():
            _start_attack(&"hook_throw")
    elif Input.is_action_just_pressed("skill_1") and _can_start_action():
        _try_skill_burst()

    if heal_timer > 0.0 or guard_timer > 0.0:
        velocity.x = move_toward(velocity.x, 0.0, speed * 12.0 * delta)
    elif grapple_timer > 0.0:
        _update_grapple(delta)
    elif dash_timer > 0.0:
        dash_timer -= delta
        velocity.x = dash_speed * facing
        velocity.y = 0.0
        if dash_ghost_tick % 2 == 0:
            _spawn_dash_ghost()
        dash_ghost_tick += 1
        if dash_timer <= 0.0:
            _spawn_dash_trail()
    elif attack_timer <= 0.0 and wall_jump_lock <= 0.0 and hurt_timer <= 0.0:
        var movement_speed := speed * (1.12 if heal_speed_timer > 0.0 and is_on_floor() else 1.0) * (0.58 if snare_timer > 0.0 else 1.0)
        velocity.x = move_toward(velocity.x, input_axis * movement_speed, speed * 9.5 * delta)
    elif wall_jump_lock <= 0.0 and hurt_timer <= 0.0:
        var movement_speed := speed * (1.12 if heal_speed_timer > 0.0 and is_on_floor() else 1.0) * (0.58 if snare_timer > 0.0 else 1.0)
        velocity.x = move_toward(velocity.x, input_axis * movement_speed * 0.45, speed * 5.0 * delta)

    _update_attack(delta)
    var fall_speed := velocity.y
    var platform_motion := get_platform_velocity() * delta if was_on_floor else Vector2.ZERO
    move_and_slide()
    _update_ground_motion(delta, platform_motion)
    if not was_on_floor and is_on_floor():
        land_timer = 0.14
        pogo_chain = 0
        air_jump_available = true
        _play_land_sfx(fall_speed)
        MOVEMENT_ART.land(self, fall_speed)
        ABILITY_ART.downstrike(self)
    _update_wall_slide_audio()
    MOVEMENT_ART.wall_state(self)
    _update_footsteps(delta)
    _update_camera(delta)
    _update_animation(input_axis)



## Anchors are explicit world fixtures, never arbitrary scenery or enemies.
## K/X still performs the original combat hook when no reachable anchor is in aim.
func _try_start_grapple() -> bool:
    if not thread_grapple_unlocked or grapple_timer > 0.0:
        return false
    var origin := global_position + Vector2(0.0, -42.0)
    var aim := Vector2(float(facing), 0.0)
    if Input.is_action_pressed("aim_up"):
        aim = Vector2(float(facing) * 0.45, -1.0).normalized()
    elif Input.is_action_pressed("aim_down"):
        aim = Vector2(float(facing) * 0.45, 1.0).normalized()
    var best: Node2D = null
    var best_score := INF
    for candidate in get_tree().get_nodes_in_group("grapple_anchor"):
        if not candidate is Node2D or not candidate.is_inside_tree() or not candidate.is_visible_in_tree():
            continue
        if not bool(candidate.get_meta("grapple_enabled", true)):
            continue
        var offset: Vector2 = candidate.global_position - origin
        var distance := offset.length()
        if distance < 36.0 or distance > grapple_range:
            continue
        var alignment := aim.dot(offset.normalized())
        if alignment < 0.35:
            continue
        var query := PhysicsRayQueryParameters2D.create(origin, candidate.global_position, collision_mask, [get_rid()])
        var hit := get_world_2d().direct_space_state.intersect_ray(query)
        if not hit.is_empty() and hit.get("collider") != candidate:
            continue
        var score := distance + (1.0 - alignment) * grapple_range
        if score < best_score:
            best = candidate
            best_score = score
    if best == null:
        return false
    _clear_action_buffer()
    ability_action.emit("echo_hook", global_position, (best.global_position - origin).normalized())
    grapple_anchor = best
    grapple_timer = grapple_timeout
    grapple_recovery_timer = 0.0
    coyote_timer = 0.0
    jump_buffer_timer = 0.0
    wall_sliding = false
    grapple_line = Line2D.new()
    grapple_line.name = "TraversalThread"
    grapple_line.width = 3.0
    grapple_line.default_color = THREAD_T1_CORE
    grapple_line.z_index = 59
    add_child(grapple_line)
    _play(&"hook_throw")
    _play_sfx("hook_latch", -6.0)
    _play_sfx("hook_reel", -8.0)
    HOOK_ART.attached(self)
    return true


func _update_grapple(delta: float) -> void:
    if not is_instance_valid(grapple_anchor) or not grapple_anchor.is_inside_tree():
        _stop_grapple()
        return
    var offset := grapple_anchor.global_position - (global_position + Vector2(0.0, -42.0))
    grapple_timer = maxf(0.0, grapple_timer - delta)
    if offset.length() <= 36.0 or grapple_timer <= 0.0:
        _stop_grapple(true)
        velocity *= 0.35
        return
    # Sweep each physics tick instead of teleporting through solid terrain.
    var origin := global_position + Vector2(0.0, -42.0)
    var query := PhysicsRayQueryParameters2D.create(origin, grapple_anchor.global_position, collision_mask, [get_rid()])
    var hit := get_world_2d().direct_space_state.intersect_ray(query)
    if not hit.is_empty() and hit.get("collider") != grapple_anchor:
        _stop_grapple()
        return
    velocity = offset.normalized() * minf(grapple_speed, maxf(0.0, offset.length() - 30.0) / delta)
    if is_instance_valid(grapple_line):
        grapple_line.points = PackedVector2Array([Vector2(0.0, -42.0), to_local(grapple_anchor.global_position)])


func _stop_grapple(recover: bool = false) -> void:
    HOOK_ART.stopped(self, recover)
    grapple_timer = 0.0
    grapple_recovery_timer = GRAPPLE_RECOVERY_TIME if recover else 0.0
    grapple_anchor = null
    if is_instance_valid(grapple_line):
        grapple_line.queue_free()
    grapple_line = null


func _reset_traversal_state() -> void:
    CONTACT_ART.clear_player(self)
    ABILITY_ART.clear(self)
    HOOK_ART.clear(self)
    DASH_ART.clear(self)
    HURT_ART.clear(self)
    MOVEMENT_ART.clear(self)
    GUARD_ART.clear(self)
    VISUAL_POLICY.clear_secondary(self)
    respawn_reveal_timer = 0.0
    _set_death_visibility(1.0)
    camera_focus.clear_look()
    _clear_action_buffer()
    _stop_grapple()
    _interrupt_heal()
    HEAL_ART.clear(self)
    _stop_phase()
    guard_timer = 0.0
    guard_cooldown = 0.0
    active_skill.clear()
    traversal_downstrike_active = false
    wall_jump_lock = 0.0
    air_jump_available = true
    coyote_timer = 0.0
    jump_buffer_timer = 0.0
    dash_timer = 0.0
    dash_cooldown = 0.0
    attack_timer = 0.0
    land_timer = 0.0
    ground_motion_x = 0.0
    ground_motion_speed = 0.0
    run_cycle_phase = 0.0
    wall_sliding = false
    if is_instance_valid(attack_shape):
        attack_shape.set_deferred("disabled", true)


func _spawn_double_jump_vfx() -> void:
    for index in range(2):
        var thread := Line2D.new()
        thread.name = "DoubleJumpThread"
        thread.points = PackedVector2Array([Vector2(-24.0, -12.0 + index * 10.0), Vector2(0.0, 2.0 + index * 10.0), Vector2(24.0, -12.0 + index * 10.0)])
        thread.width = 3.0
        thread.default_color = THREAD_T2_CORE if index == 0 else THREAD_T1_CORE
        thread.z_index = 58
        if not VISUAL_POLICY.attach_secondary(self, thread, &"motion", self): continue
        var tween := thread.create_tween()
        tween.tween_property(thread, "scale", Vector2(1.5, 1.0), 0.22)
        tween.parallel().tween_property(thread, "modulate:a", 0.0, 0.22)
        tween.finished.connect(Callable(thread, "queue_free"))


func _start_attack(animation: StringName, allow_traversal_action: bool = true, queued_direction: Vector2 = Vector2.ZERO) -> void:
    _clear_action_buffer()
    grapple_recovery_timer = 0.0
    if animation == &"attack_1" and _crest() == "bell":
        animation = &"attack_2"
    active_skill.clear()
    current_attack = animation
    current_attack_direction = _read_attack_direction() if queued_direction == Vector2.ZERO else queued_direction
    if animation == &"hook_throw":
        current_attack_direction = Vector2(float(facing), 0.0)
    attack_started_grounded = is_on_floor()
    run_attack_pose = animation == &"attack_1" and is_on_floor() and absf(current_attack_direction.y) <= 0.5 \
        and absf(velocity.x) >= speed * RUN_ATTACK_MIN_SPEED_RATIO and _has_pose(&"run_attack")
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
    if _crest() == "bell" and _seal_mechanism_ready() and animation == &"attack_2" and bell_pressure > 0:
        attack_damage += bell_pressure
    attack_damage = maxi(1, attack_damage + int(build_profile.attack_bonus)) if build_profile.has("attack_bonus") else maxi(1, int(ceil(float(attack_damage) * float(build_profile.get("attack_damage_mult", 1.0)))))
    var reach := float(build_profile.get("attack_reach_mult", 1.0))
    attack_range *= reach
    attack_height *= reach
    attack_forward_offset *= reach
    attack_duration /= maxf(0.25, float(build_profile.get("attack_speed_mult", 1.0)))
    attack_windup = minf(0.10 if animation == &"attack_2" else 0.06, attack_duration * 0.25)
    attack_active_time = attack_duration * 0.52
    traversal_downstrike_active = allow_traversal_action and current_attack_direction.y > 0.5 and animation != &"hook_throw" and thorn_downstrike_unlocked and not is_on_floor()
    if traversal_downstrike_active:
        velocity.y = maxf(velocity.y, 760.0)
        ability_action.emit("thorn_downstrike", global_position, Vector2.DOWN)
    attack_vfx_started = false
    attack_timer = attack_duration
    enemy_contact_guard_timer = maxf(enemy_contact_guard_timer, enemy_contact_guard_time)
    hit_targets.clear()
    attack_pogo_paid = false
    hook_latch_played = false
    hook_reel_played = false
    _sync_attack_hitbox()
    _play(animation, true)
    if animation == &"hook_throw":
        _play_sfx("hook", -6.0)
    elif animation == &"attack_2":
        _play_sfx("skill", -7.0)
    else:
        _play_attack_swing_sfx()


## 普攻三采样顺序轮换 + 每次 ±4% 随机变调（音频规格 §4.1）；
## 合成包缺失时回落旧 player_attack.ogg。
func _play_attack_swing_sfx() -> void:
    var variant_keys := ["attack_v1", "attack_v2", "attack_v3"]
    var key: String = variant_keys[attack_sample_index % variant_keys.size()]
    attack_sample_index = (attack_sample_index + 1) % variant_keys.size()
    if not FileAccess.file_exists(String(SFX.get(key, ""))):
        key = "attack"
    _play_sfx(key, -5.0, randf_range(0.96, 1.04), "player_attack")


func _clear_action_buffer() -> void:
    buffered_action = &""
    action_buffer_timer = 0.0
    buffered_direction = Vector2.ZERO


func _sample_action_input(delta: float) -> void:
    action_buffer_timer = maxf(0.0, action_buffer_timer - delta)
    if action_buffer_timer <= 0.0:
        _clear_action_buffer()
    # Latest command replaces the pending command; holding never repeats it.
    # Preserve the existing dash priority when both buttons arrive in one tick.
    var action: StringName = &""
    if Input.is_action_just_pressed("dash") and dash_unlocked:
        action = &"dash"
    elif Input.is_action_just_pressed("attack"):
        action = &"attack"
    if action == &"":
        return
    buffered_action = action
    action_buffer_timer = action_buffer_time
    if action == &"attack":
        buffered_direction = _read_attack_direction()
    else:
        var axis := _move_axis()
        buffered_direction = Vector2(signf(axis) if absf(axis) > 0.1 else float(facing), 0.0)


func _consume_action_input(action: StringName) -> bool:
    if buffered_action != action or not _can_start_action(action == &"dash"):
        return false
    if action == &"dash" and (not dash_unlocked or dash_cooldown > 0.0):
        return false
    var direction := buffered_direction
    # Consume before any signal/callback can re-enter action handling.
    _clear_action_buffer()
    if absf(direction.x) > 0.1:
        facing = signi(direction.x)
        sprite.flip_h = facing < 0
    if action == &"attack":
        _start_attack(&"attack_1", true, direction)
    else:
        _start_dash()
    return true


func _start_dash() -> void:
    _clear_action_buffer()
    _stop_grapple()
    dash_timer = dash_time
    dash_cooldown = dash_cooldown_time
    velocity.y = 0.0
    velocity.x = dash_speed * facing
    dash_ghost_tick = 0
    dash_start_position = global_position
    _sync_attack_hitbox()
    ability_action.emit("thread_dash", global_position, Vector2(facing, 0))
    if feel != null:
        _add_trauma(0.08)
    _play(&"dash")
    _play_sfx("dash", -7.0)


func _can_start_action(allow_grapple: bool = false) -> bool:
    if get_parent().has_method("_walking_world_passage") and get_parent()._walking_world_passage():
        return false
    return death_timer <= 0.0 and hurt_timer <= 0.0 and attack_timer <= 0.0 and dash_timer <= 0.0 and (allow_grapple or grapple_timer <= 0.0) and heal_timer <= 0.0 and guard_timer <= 0.0 and not phase_active and not ui_input_locked

## Read-only HUD query; shares the real action gate, including traversal handoff.
func get_cast_readiness(skill_id: String = "") -> Dictionary:
    if hp <= 0 or death_timer > 0.0:
        return {"available":false, "text":"复生中", "detail":"等待复生后使用。"}
    if not _can_start_action():
        return {"available":false, "text":"动作中", "detail":"当前动作或界面结束后可用。"}
    if not skill_id.is_empty():
        if skill_cooldown > 0.0:
            return {"available":false, "text":"%.1fs" % skill_cooldown, "detail":"上一招仍在收势。"}
        if skill_id == "shockwave" and not is_on_floor():
            return {"available":false, "text":"需落地", "detail":"钟鸣震波需要接触地面。"}
    return {"available":true}


func configure_selected_skill(skill: Dictionary) -> void:
    selected_skill = skill.duplicate(true)


func _try_skill_burst() -> void:
    cast_selected_skill()


func cast_selected_skill(slot: int = -1) -> bool:
    if not _can_start_action() or skill_cooldown > 0.0:
        return false
    var payload: Dictionary
    if build_system != null and build_system.has_method("try_cast"):
        var preview: Dictionary = build_system.selected_skill() if slot < 0 else build_system.selected_skill(slot)
        if String(preview.get("id", "")) == "shockwave" and not is_on_floor():
            return false
        payload = build_system.try_cast(energy) if slot < 0 else build_system.try_cast(energy, slot)
        if not bool(payload.get("ok", false)):
            return false
    else:
        payload = selected_skill.duplicate(true) if not selected_skill.is_empty() else {"id": "thread_burst", "kind": "melee", "energy_cost": skill_energy_cost, "damage": 2, "range": 126.0, "windup": 0.1, "active": 0.22, "recovery": 0.16, "cooldown": 2.4}
    var cost := int(payload.get("energy_cost", skill_energy_cost))
    if energy < cost:
        return false
    if String(payload.get("id", "")) == "shockwave" and not is_on_floor():
        return false
    gain_energy(-cost)
    var old_velocity := velocity
    _start_attack(&"attack_2", false)
    velocity = old_velocity
    active_skill = payload.duplicate(true)
    enemy_contact_guard_timer = 0.0
    attack_damage = maxi(1, int(payload.get("damage", 2)))
    active_skill["empowered"] = line_stacks >= 3 and _crest() == "crimson" and _seal_mechanism_ready()
    if bool(active_skill.empowered):
        line_stacks = 0
        line_expiry = 0.0
    crosscut_refund_paid = false
    if _crest() == "bell" and _seal_mechanism_ready() and String(payload.get("id", "")) == "shockwave" and bell_pressure > 0:
        attack_damage += bell_pressure
        active_skill["stagger"] = bell_pressure * 0.3
        bell_pressure = 0
    attack_range = float(payload.get("range", 126.0))
    if bool(active_skill.get("empowered", false)) and String(payload.get("id", "")) == "cleave":
        attack_range *= 1.35
    if String(payload.get("id", "")) == "crosscut":
        attack_forward_offset = 0.0
        attack_range *= 2.0
        current_attack_direction = Vector2(facing, 0)
    attack_windup = float(payload.get("windup", payload.get("warmup", 0.1)))
    attack_active_time = float(payload.get("active", 0.18))
    if String(payload.get("kind", "")) == "defense":
        attack_active_time = clampf(float(payload.get("duration", 0.5)), 0.1, 0.65)
    attack_duration = attack_windup + attack_active_time + float(payload.get("recovery", 0.2))
    attack_timer = attack_duration
    skill_effect_started = false
    skill_cooldown = 0.0 if build_system != null else float(payload.get("cooldown", 2.4))
    _sync_attack_hitbox()
    seal_recovery_shown = false
    skill_displacement_done = 0.0
    _seal_present(String(payload.get("id", "cleave")), "prepare")
    last_skill_cast = String(payload.get("id", ""))
    last_skill_cast_msec = Time.get_ticks_msec()
    skill_cast.emit(String(payload.get("skill_id", payload.get("id", "thread_burst"))))
    return true


func get_heal_readiness() -> Dictionary:
    # This snapshot is read by both the action and HUD; querying never reserves.
    var reason := "ready"
    if heal_timer > 0.0: reason = "channeling"
    elif death_timer > 0.0: reason = "dead"
    elif not _can_start_action(): reason = "busy"
    elif heal_cooldown > 0.0: reason = "cooldown"
    elif hp >= max_hp: reason = "full_health"
    elif energy < heal_energy_cost: reason = "energy"
    elif not is_on_floor() and not _heal_airborne(): reason = "airborne"
    elif absf(_move_axis()) > 0.1 or Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("dash"): reason = "moving"
    return {"available":reason=="ready", "reason":reason, "cost":heal_energy_cost,
        "missing_energy":maxi(0,heal_energy_cost-energy), "amount":mini(heal_amount,maxi(0,max_hp-hp)),
        "duration":heal_duration, "remaining":heal_timer, "cooldown":heal_cooldown,
        "interrupt_loss":int(ceil(heal_reserved_cost*heal_reserved_loss_ratio)) if heal_timer>0.0 else int(ceil(heal_energy_cost*clampf(float(build_profile.get("heal_interrupt_loss_ratio",1.0)),0.0,1.0)))}

func _try_heal() -> bool:
    if not bool(get_heal_readiness().available):
        return false
    _clear_action_buffer()
    # Publish the reservation before resource signals can reenter this action.
    heal_reservation_generation += 1
    var reservation_generation := heal_reservation_generation
    heal_reserved_cost = heal_energy_cost
    heal_reserved_loss_ratio = clampf(float(build_profile.get("heal_interrupt_loss_ratio",1.0)),0.0,1.0)
    heal_reserved_practice = mini(practice_energy, heal_reserved_cost)
    heal_timer = heal_duration
    velocity.x = 0.0
    gain_energy(-heal_reserved_cost)
    # A payment listener may cancel, change build, or begin a newer channel.
    if heal_reservation_generation != reservation_generation or heal_timer <= 0.0:
        return false
    HEAL_ART.start(self)
    _seal_present("heal", "prepare")
    _play_sfx("heal", -5.0)
    _play(&"heal")
    heal_state_changed.emit("started")
    return heal_reservation_generation == reservation_generation and heal_timer > 0.0


func _update_heal(delta: float) -> void:
    if heal_timer <= 0.0:
        return
    if (not is_on_floor() and not _heal_airborne()) or Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("dash") or absf(_move_axis()) > 0.1:
        _interrupt_heal()
        return
    heal_timer = maxf(0.0, heal_timer - delta)
    if heal_timer <= 0.0:
        heal_reservation_generation += 1
        heal_reserved_cost = 0
        heal_reserved_practice = 0
        hp = mini(max_hp, hp + heal_amount)
        heal_cooldown = 0.4
        # Settle the paid build before HP listeners can replace that build.
        _seal_heal_completed()
        HEAL_ART.completed(self)
        hp_changed.emit(hp)
        heal_state_changed.emit("completed")


func _interrupt_heal() -> void:
    if heal_timer > 0.0:
        var refund := heal_reserved_cost - int(ceil(heal_reserved_cost * heal_reserved_loss_ratio))
        # Clear the reservation and block recasts before emitting energy_changed.
        heal_reservation_generation += 1
        heal_reserved_cost = 0
        heal_timer = 0.0
        heal_cooldown = maxf(heal_cooldown, 0.3)
        var practice_refund := mini(refund, heal_reserved_practice)
        heal_reserved_practice = 0
        HEAL_ART.interrupted(self)
        gain_energy(refund)
        # A refund of practice thread stays practice thread.
        practice_energy = mini(energy, practice_energy + practice_refund)
        heal_state_changed.emit("interrupted")


func apply_build_stats(stats: Dictionary) -> void:
    # Finding a capacity reward is not an equipment change. Keep the current
    # attack/channel/guard and its original reservation; do not refill on pickup.
    if not build_profile.is_empty():
        var capacity_only := build_profile.duplicate(true)
        capacity_only["max_hp"] = stats.get("max_hp", max_hp)
        capacity_only["max_energy"] = stats.get("max_energy", max_energy)
        if capacity_only == stats and (max_hp != int(capacity_only.max_hp) or max_energy != int(capacity_only.max_energy)):
            build_profile = stats.duplicate(true)
            _apply_capacity_limits(stats)
            return
    # Settle the old channel under its original cost/loss and capacity first.
    _interrupt_heal()
    _clear_action_buffer()
    if build_baseline.is_empty():
        build_baseline = {"max_hp": max_hp, "max_energy": max_energy, "speed": speed, "energy_per_hit": energy_per_hit, "heal_energy_cost": heal_energy_cost, "heal_amount": heal_amount, "heal_duration": heal_duration}
    line_stacks = 0
    bell_pressure = 0
    line_expiry = 0.0
    heal_speed_timer = 0.0
    heal_stability_timer = 0.0
    status_resist_timer = 0.0
    attack_timer = 0.0
    active_skill.clear()
    for enemy in get_tree().get_nodes_in_group("enemy"):
        if enemy.has_method("clear_salt_mark"):
            enemy.clear_salt_mark()
    build_profile = stats.duplicate(true)
    max_hp = maxi(1, int(stats.get("max_hp", build_baseline.max_hp)))
    max_energy = maxi(1, int(stats.get("max_energy", build_baseline.max_energy)))
    speed = float(build_baseline.speed) * float(stats.get("move_mult", stats.get("speed_multiplier", 1.0)))
    energy_per_hit = maxi(0, int(stats.energy_per_hit)) if stats.has("energy_per_hit") else maxi(0, int(round(float(build_baseline.energy_per_hit) * float(stats.get("energy_gain_mult", 1.0)))))
    heal_energy_cost = maxi(1, int(stats.get("heal_cost", stats.get("heal_energy_cost", build_baseline.heal_energy_cost))))
    heal_amount = maxi(1, int(stats.get("heal_amount", build_baseline.heal_amount)))
    heal_duration = maxf(0.2, float(stats.get("heal_duration", build_baseline.heal_duration)))
    hp = mini(hp, max_hp)
    energy = mini(energy, max_energy)
    guard_timer = 0.0
    _stop_phase()
    hp_changed.emit(hp)
    energy_changed.emit(energy, max_energy)


func _apply_capacity_limits(stats: Dictionary) -> void:
    max_hp = maxi(1, int(stats.get("max_hp", max_hp)))
    max_energy = maxi(1, int(stats.get("max_energy", max_energy)))
    hp = mini(hp, max_hp)
    energy = mini(energy, max_energy)
    hp_changed.emit(hp)
    energy_changed.emit(energy, max_energy)


func _try_guard() -> bool:
    if not bell_guard_unlocked or not _can_start_action() or guard_cooldown > 0.0 or energy < 8:
        return false
    _clear_action_buffer()
    gain_energy(-8)
    guard_timer = 0.42
    guard_initial_duration = guard_timer
    guard_cooldown = 0.8
    guard_refunded = false
    ability_action.emit("bell_guard", global_position, Vector2(facing, 0))
    _play(&"guard")
    GUARD_ART.start(self)
    return true


func _try_resonance() -> bool:
    if not crown_resonance_unlocked or not _can_start_action() or resonance_cooldown > 0.0 or energy < 20:
        return false
    gain_energy(-20)
    resonance_cooldown = 1.4
    _start_attack(&"attack_2", false)
    active_skill = {"kind": "resonance", "range": 160.0, "damage": 1}
    skill_effect_started = false
    ability_action.emit("crown_resonance", global_position, Vector2(facing, 0))
    _ability_ring(160.0, THREAD_T3_CORE)
    ABILITY_ART.resonance(self)
    return true


func is_phasing() -> bool:
    return phase_active


func _update_phase(delta: float) -> void:
    if phase_active:
        if not Input.is_action_pressed("lantern_phase") or energy <= 0 or hurt_timer > 0.0 or death_timer > 0.0:
            _stop_phase()
            return
        phase_energy_fraction += delta * 24.0
        var drain := int(phase_energy_fraction)
        if drain > 0:
            phase_energy_fraction -= drain
            gain_energy(-drain)
        _sync_phase_gates()
        if _phase_position_clear():
            phase_safe_position = global_position
    elif lantern_phase_unlocked and Input.is_action_pressed("lantern_phase") and _can_start_action() and energy >= 8:
        gain_energy(-8)
        phase_active = true
        phase_energy_fraction = 0.0
        phase_safe_position = global_position
        _sync_phase_gates()
        ability_action.emit("lantern_phase", global_position, Vector2(facing, 0))
        _ability_ring(54.0, Color(0.5, 0.7, 1.0, 0.9))
        ABILITY_ART.phase_enter(self)


func _sync_phase_gates() -> void:
    for gate in get_tree().get_nodes_in_group("phase_gate"):
        if gate is PhysicsBody2D and not phase_exceptions.has(gate):
            add_collision_exception_with(gate)
            phase_exceptions.append(gate)


func _phase_position_clear() -> bool:
    var body_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
    if body_shape == null:
        return true
    var query := PhysicsShapeQueryParameters2D.new()
    query.shape = body_shape.shape
    query.transform = body_shape.global_transform
    query.collision_mask = collision_mask
    query.exclude = [get_rid()]
    for hit in get_world_2d().direct_space_state.intersect_shape(query):
        if hit.collider is PhysicsBody2D:
            return false
    return true


func _stop_phase() -> void:
    ABILITY_ART.phase_stop(self)
    if phase_active and is_inside_tree() and not _phase_position_clear():
        global_position = phase_safe_position
        velocity = Vector2.ZERO
    for gate in phase_exceptions:
        if is_instance_valid(gate):
            remove_collision_exception_with(gate)
    phase_exceptions.clear()
    phase_active = false
    phase_energy_fraction = 0.0


func _ability_ring(radius: float, color: Color) -> void:
    var ring := Line2D.new()
    ring.name = "AbilityPulse"
    ring.closed = true
    ring.width = 3.0
    ring.default_color = color
    for step in range(32):
        var angle := TAU * float(step) / 32.0
        ring.add_point(Vector2(cos(angle), sin(angle)) * radius + Vector2(0, -42))
    ring.z_index = 60
    if not VISUAL_POLICY.attach_secondary(self, ring, &"state", self): return
    var tween := ring.create_tween()
    tween.tween_property(ring, "modulate:a", 0.0, 0.3)
    tween.finished.connect(ring.queue_free)


func _update_camera(delta: float) -> void:
    var camera := get_node_or_null("Camera2D") as Camera2D
    if camera == null:
        return
    room_camera.update(camera_focus, global_position, delta)
    # Feet remain in view during falls; world-owned limits and zoom are preserved.
    var strength := clampf(float(_accessibility().get("camera_lookahead", 1.0)), 0.0, 1.0)
    var look_up := Input.is_action_pressed("aim_up")
    var look_down := Input.is_action_pressed("aim_down")
    var direction := 0 if look_up == look_down else (-1 if look_up else 1)
    var eligible := is_on_floor() and absf(velocity.x) < 12.0 and absf(_move_axis()) < 0.1 and land_timer <= 0.0 and _can_start_action()
    var observation: float = camera_focus.update(camera, delta, direction, eligible, strength)
    camera.position = camera_focus.follow_position(camera, global_position, velocity, is_on_floor(), delta, strength, observation)


func configure_camera_focus(bounds: Rect2) -> void:
    var camera := get_node_or_null("Camera2D") as Camera2D
    if camera != null:
        camera_focus.configure(camera, bounds)
        room_camera.configure([], camera_focus)


func configure_room_camera(rooms: Array) -> void:
    room_camera.configure(rooms, camera_focus)
    room_camera.update(camera_focus, global_position)
    var camera := get_node_or_null("Camera2D") as Camera2D
    if camera != null:
        camera_focus.apply_limits(camera)


func push_camera_lock(id: String, bounds: Rect2, priority: int = 0, prevent_up: bool = false, prevent_down: bool = false) -> bool:
    var accepted: bool = camera_focus.push_lock(id, bounds, priority, prevent_up, prevent_down)
    var camera := get_node_or_null("Camera2D") as Camera2D
    if camera != null:
        camera_focus.apply_limits(camera)
    return accepted


func remove_camera_lock(id: String) -> void:
    camera_focus.remove_lock(id)
    var camera := get_node_or_null("Camera2D") as Camera2D
    if camera != null:
        camera_focus.apply_limits(camera)


func _apply_special_skill() -> void:
    var kind := String(active_skill.get("kind", "melee"))
    var id := String(active_skill.get("id", ""))
    if kind == "ranged":
        cast_tool({"kind": "projectile", "damage": attack_damage, "range": attack_range, "duration": 1.2, "pierce": 1, "salt_mark": _crest() == "salt" and _seal_mechanism_ready(), "skill_effect": true})
    elif kind == "defense":
        guard_timer = minf(0.65, float(active_skill.get("duration", 0.5)))
        guard_initial_duration = guard_timer
        guard_refunded = false
        GUARD_ART.start(self)
    elif id == "shockwave" or kind == "shockwave":
        cast_tool({"kind": "wave", "damage": attack_damage, "range": attack_range, "duration": 0.8, "stagger": active_skill.get("stagger", 0.0), "skill_effect": true})
    elif kind == "control":
        cast_tool({"kind":"snare_field", "damage":attack_damage, "range":10000.0, "duration":maxf(0.4, float(active_skill.get("duration",1.5))), "salt_consume":_crest() == "salt" and _seal_mechanism_ready(), "skill_effect":true})
    elif kind == "resonance":
        var radius := float(active_skill.get("range", 160.0))
        _ability_ring(radius, THREAD_T2_CORE)
        for enemy in get_tree().get_nodes_in_group("enemy"):
            if enemy.has_method("world_residency_active") and not enemy.world_residency_active(): continue
            if enemy is Node2D and enemy.global_position.distance_to(global_position) <= radius and _attack_line_clear(enemy.global_position):
                if enemy.has_method("take_hit"):
                    enemy.take_hit(attack_damage, facing)



func cast_tool(payload: Dictionary) -> bool:
    # A ranged skill creates its effect inside its own active frame; public tool
    # use must otherwise obey the same channel/recovery gates as combat actions.
    var skill_emission := attack_timer > 0.0 and skill_effect_started and bool(payload.get("skill_effect", false))
    if not _can_start_action() and not skill_emission:
        return false
    var tool_id := String(payload.get("id", ""))
    if tool_id == "mine":
        var count := 0
        for effect in get_tree().get_nodes_in_group("player_trap"):
            if effect.get("owner_player") == self:
                count += 1
        if count >= 2:
            return false
    if String(payload.get("kind", "")) == "snare_field":
        for field in get_tree().get_nodes_in_group("player_snare_field"):
            if field.get("owner_player") == self:
                field.queue_free()
    var projectile := Node2D.new()
    projectile.set_script(load("res://scripts/player_tool_effect.gd"))
    projectile.set("payload", payload.duplicate(true))
    projectile.set("direction", facing)
    projectile.set("owner_player", self)
    get_parent().add_child(projectile)
    if not bool(payload.get("skill_effect", false)):
        _seal_present(String(payload.get("id", "shard")), "active")
    var spawn_offset := Vector2(facing * (90 if String(payload.get("kind", "")) == "snare_field" else 24), -6 if String(payload.get("kind", "")) in ["trap", "snare_field"] else -42)
    var spawn_origin := global_position + Vector2(0, spawn_offset.y)
    var spawn_position_effect := global_position + spawn_offset
    var placement_ray := PhysicsRayQueryParameters2D.create(spawn_origin, spawn_position_effect, 1, [get_rid()])
    var placement_hit := get_world_2d().direct_space_state.intersect_ray(placement_ray)
    if not placement_hit.is_empty():
        spawn_position_effect = placement_hit.position - Vector2(facing * 8, 0)
    projectile.global_position = spawn_position_effect
    if not bool(payload.get("skill_effect", false)):
        attack_timer = 0.35
        attack_duration = 0.35
        attack_windup = 0.35
        attack_active_time = 0.0
        active_skill = {"id": String(payload.get("id", "shard")), "kind": "tool"}
        skill_effect_started = true
    return true


func _attack_line_clear(target: Vector2) -> bool:
    # Terrain occupies collision bit 1 (the same layer used by projectile and
    # placement rays). Actor hurtboxes must not turn a blocked melee ray into a
    # hit-through-wall result.
    var query := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -42), target, 1, [get_rid()])
    query.collide_with_areas = false
    var hit := get_world_2d().direct_space_state.intersect_ray(query)
    return hit.is_empty()


func _update_attack(delta: float) -> void:
    if attack_timer <= 0.0:
        attack_shape.disabled = true
        return

    attack_timer = maxf(0.0, attack_timer - delta)
    var elapsed := attack_duration - attack_timer
    var active := elapsed >= attack_windup and elapsed <= attack_windup + attack_active_time
    var special := not active_skill.is_empty() and String(active_skill.get("kind", "melee")) not in ["melee", "thrust", "crosscut"]
    if not active_skill.is_empty() and elapsed > attack_windup + attack_active_time and not seal_recovery_shown:
        seal_recovery_shown = true
        _seal_present(String(active_skill.get("id", "cleave")), "recovery")
    if active and not attack_vfx_started:
        attack_vfx_started = true
        if not active_skill.is_empty():
            _seal_present(String(active_skill.get("id", "cleave")), "active")
        if not special:
            _spawn_attack_vfx(current_attack)
    if active and special and not skill_effect_started:
        skill_effect_started = true
        _apply_special_skill()
    attack_shape.disabled = not active or special
    if active and not special:
        if String(active_skill.get("id", "")) == "cleave":
            var progress := clampf((elapsed - attack_windup) / maxf(0.01, attack_active_time), 0.0, 1.0)
            var displacement := 64.0 * progress
            if displacement > skill_displacement_done:
                move_and_collide(Vector2(facing * (displacement - skill_displacement_done), 0))
                skill_displacement_done = displacement
        _apply_attack_hits()
        if traversal_downstrike_active:
            for terrain in get_tree().get_nodes_in_group("fragile_terrain"):
                if terrain is Node2D and terrain.has_method("receive_ability_action") and terrain.global_position.distance_to(global_position) < 100.0:
                    terrain.receive_ability_action("thorn_downstrike", global_position, Vector2.DOWN)


func _apply_attack_hits() -> void:
    var attack_size := _attack_size()
    var center := global_position + _attack_center_offset()
    var attack_rect := Rect2(center - attack_size * 0.5, attack_size)
    for node in get_tree().get_nodes_in_group("enemy"):
        if not is_instance_valid(node) or not node.has_method("take_hit"):
            continue
        if node.has_method("world_residency_active") and not node.world_residency_active():
            continue
        var id := node.get_instance_id()
        if hit_targets.has(id):
            continue
        var hurtbox := Rect2(node.global_position - Vector2(34, 38), Vector2(68, 76))
        if node.has_method("get_hurtbox_rect"):
            hurtbox = node.get_hurtbox_rect()
        if attack_rect.intersects(hurtbox) and _attack_line_clear(hurtbox.get_center()):
            hit_targets[id] = true
            var target_hp_before := int(node.get("hp"))
            var contact_call: int = int(node.contact_visual_call_serial()) + 1 if node.has_method("contact_visual_call_serial") else -1
            node.take_hit(attack_damage, _attack_hit_direction())
            var accepted := is_instance_valid(node) and int(node.get("hp")) < target_hp_before
            if not accepted:
                continue
            if current_attack == &"hook_throw" and not hook_latch_played:
                # 钩索"挂住"=钩击命中确认（与 hitstop 同拍）；每次挥钩仅播一次。
                hook_latch_played = true
                _play_sfx("hook_latch", -6.0)
                HOOK_ART.latch(self, hurtbox.get_center())
                # ch2 beat `echo_hook`（manifest ch02_beat_02）：雨铸运河钩击命中后
                # 叠一拍水声回响（金属声后接水面回声，采样内已含节拍延迟）。
                if footstep_material == "copper":
                    _play_sfx("ch02_beat_echo_hook", -10.0)
            var killed := not is_instance_valid(node) or int(node.get("hp")) <= 0
            var energy_before := energy
            if active_skill.is_empty():
                gain_energy(energy_per_hit)
                _basic_seal_hit()
            elif String(active_skill.get("id", "")) == "crosscut" and bool(active_skill.get("empowered", false)) and not crosscut_refund_paid:
                gain_energy(mini(10, maxi(0, int(active_skill.get("energy_cost", 30)) - 1)))
                crosscut_refund_paid = true
            if is_instance_valid(node) and (node.has_meta("seal_training_target") or node.has_meta("tool_training_target")):
                practice_energy += energy - energy_before
            if active_skill.is_empty() and _crest() == "bell" and _seal_mechanism_ready() and bell_pressure > 0 and current_attack == &"attack_2":
                if node.has_method("apply_stagger"):
                    node.apply_stagger(bell_pressure * 0.3)
                bell_pressure = 0
            if not attack_pogo_paid:
                _apply_downslash_bounce(node.global_position)
                attack_pogo_paid = true
            _trigger_hit_feedback(killed)
            _spawn_hit_confirm_vfx(node.global_position, current_attack, node, contact_call)
    _try_hazard_pogo(attack_rect)


## A downslash that meets static spikes bounces like an enemy hit, but awards no
## thread and no hit feedback. Terrain between the player and spikes blocks it.
func _try_hazard_pogo(attack_rect: Rect2) -> void:
    if attack_pogo_paid or current_attack == &"hook_throw" or current_attack_direction.y <= 0.5:
        return
    for node in get_tree().get_nodes_in_group(HAZARD_POGO.GROUP):
        if not is_instance_valid(node) or not node is Node2D or not node.is_inside_tree():
            continue
        var surface: Rect2 = HAZARD_POGO.surface_rect(node)
        if surface.size == Vector2.ZERO or not attack_rect.intersects(surface):
            continue
        var contact := Vector2(clampf(global_position.x, surface.position.x, surface.end.x), surface.position.y + 1.0)
        if not _attack_line_clear(contact):
            continue
        _apply_downslash_bounce(contact)
        attack_pogo_paid = true
        hazard_pogo_guard_timer = HAZARD_POGO.CONTACT_GRACE
        _spawn_hit_confirm_vfx(contact, current_attack)
        return


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
    if feel.has_method("melee_rumble"):
        feel.melee_rumble(current_attack, killed, current_attack_direction)
    _add_trauma(trauma)
    if killed:
        _flash_screen(Color.WHITE, 0.08, 1)


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
    velocity.y = downslash_bounce_velocity * float(build_profile.get("downstrike_bounce_mult", 1.0))
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
    # Spending uses rack-earned practice thread first.
    if amount < 0:
        practice_energy = maxi(0, practice_energy - (before - energy))
    if energy != before:
        energy_changed.emit(energy, max_energy)


func _update_ground_motion(delta: float, platform_motion: Vector2 = Vector2.ZERO) -> void:
    ground_motion_x = 0.0
    ground_motion_speed = 0.0
    if not is_on_floor() or delta <= 0.0:
        return
    # get_position_delta excludes teleports/room handoffs before move_and_slide.
    # Subtract carrier travel so standing on a lift does not make the legs run.
    ground_motion_x = get_position_delta().x - platform_motion.x
    ground_motion_speed = absf(ground_motion_x) / delta
    if ground_motion_speed <= GROUND_MOTION_EPSILON:
        ground_motion_x = 0.0
        ground_motion_speed = 0.0
        return
    run_cycle_phase = fposmod(run_cycle_phase + absf(ground_motion_x) / RUN_CYCLE_DISTANCE, 1.0)


func _pose_ground_run() -> void:
    _play(&"run")
    sprite.pause()
    var count := sprite.sprite_frames.get_frame_count(&"run")
    var phase := run_cycle_phase * count
    sprite.set_frame_and_progress(clampi(int(phase), 0, count - 1), fposmod(phase, 1.0))
    # Gameplay facing still responds immediately to input/queued attacks.
    # Only the walking silhouette waits for actual motion to reverse, avoiding
    # backwards skating during the existing acceleration/deceleration curve.
    sprite.flip_h = ground_motion_x < 0.0
    _sync_sprite_pose_anchor()


func _sync_sprite_pose_anchor() -> void:
    sprite.offset = Vector2.ZERO
    if sprite.animation == &"idle" and sprite.frame < IDLE_FOOT_CENTER_X.size():
        var correction: float = IDLE_FOOT_CENTER_X[0] - IDLE_FOOT_CENTER_X[sprite.frame]
        sprite.offset.x = correction * (-1.0 if sprite.flip_h else 1.0)
    if is_instance_valid(layered_idle):
        layered_idle.sync_pose()


func _update_animation(_input_axis: float) -> void:
    sprite.flip_h = facing < 0
    if hurt_timer > 0.0:
        _play(&"hurt")
    elif heal_timer > 0.0:
        _pose_progress(&"heal", 1.0 - heal_timer / maxf(heal_duration, 0.01))
    elif guard_timer > 0.0:
        _pose_progress(&"guard", 1.0 - guard_timer / maxf(guard_initial_duration, 0.01))
    elif attack_timer > 0.0:
        _update_attack_pose()
    elif grapple_timer > 0.0:
        # Hold the pull pose; do not replay release every 0.4 seconds.
        var elapsed := grapple_timeout - grapple_timer
        _pose_progress(&"hook_throw", 0.25 if elapsed < 0.05 else 0.5)
    elif dash_timer > 0.0:
        _pose_progress(&"dash", 1.0 - dash_timer / maxf(dash_time, 0.01))
    elif wall_sliding and not is_on_floor():
        _play(&"wall_slide")
    elif phase_active:
        _play(&"phase")
    elif grapple_recovery_timer > 0.0:
        _pose_progress(&"hook_throw", 0.75)
    elif not is_on_floor():
        if velocity.y < 0.0 and sprite.animation == &"jump_start" and sprite.is_playing():
            return # Preserve takeoff instead of replacing it on the same tick.
        _play(&"jump_loop" if velocity.y < 0.0 else &"fall")
    elif ground_motion_speed > GROUND_MOTION_EPSILON:
        _pose_ground_run()
    elif land_timer > 0.0:
        _pose_progress(&"land", 1.0 - land_timer / 0.14)
    else:
        _play(&"idle")
    _sync_sprite_pose_anchor()


func _play(name: StringName, restart: bool = false) -> void:
    if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(name):
        return
    if restart:
        sprite.stop()
    if sprite.animation != name or not sprite.is_playing() or restart:
        sprite.play(name)
    _sync_sprite_pose_anchor()


func _has_pose(name: StringName) -> bool:
    return sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(name)


func _pose_progress(name: StringName, progress: float) -> void:
    if not sprite.sprite_frames.has_animation(name):
        return
    _play(name)
    sprite.pause()
    var count := sprite.sprite_frames.get_frame_count(name)
    sprite.set_frame_and_progress(clampi(int(progress * count), 0, count - 1), 0.0)


func _update_attack_pose() -> void:
    var animation := current_attack
    var kind := String(active_skill.get("kind", ""))
    if kind == "tool": animation = &"item_use"
    elif kind == "resonance": animation = &"resonance"
    elif not active_skill.is_empty():
        if kind == "ranged": animation = &"skill_projectile"
        elif kind == "defense": animation = &"skill_defense"
        elif String(active_skill.get("id", "")) == "shockwave": animation = &"skill_wave"
        elif kind == "control": animation = &"skill_control"
        else: animation = &"skill_melee"
    elif current_attack != &"hook_throw":
        if current_attack_direction.y > 0.5:
            animation = &"ground_down_attack" if attack_started_grounded and _has_pose(&"ground_down_attack") else &"down_attack"
        elif current_attack_direction.y < -0.5 and _has_pose(&"up_attack"):
            animation = &"up_attack" if attack_started_grounded or not _has_pose(&"air_up_attack") else &"air_up_attack"
        elif not is_on_floor(): animation = &"air_attack"
        elif run_attack_pose and current_attack == &"attack_1": animation = &"run_attack"
    var elapsed := attack_duration - attack_timer
    var progress := 0.0
    if kind == "tool":
        progress = elapsed / maxf(attack_duration, 0.01)
    elif _has_pose(animation) and sprite.sprite_frames.get_frame_count(animation) >= 6:
        # Six authored cels: two each for wind-up, slash and recovery, so no
        # single pose is held through the whole damage window.
        var recovery_start := attack_windup + attack_active_time
        if elapsed < attack_windup:
            progress = elapsed / maxf(attack_windup, 0.01) / 3.0
        elif elapsed <= recovery_start:
            progress = (1.0 + (elapsed - attack_windup) / maxf(attack_active_time, 0.01)) / 3.0
        else:
            progress = (2.0 + (elapsed - recovery_start) / maxf(attack_duration - recovery_start, 0.01)) / 3.0
    elif elapsed < attack_windup:
        progress = 0.5 * elapsed / maxf(attack_windup, 0.01)
    elif elapsed <= attack_windup + attack_active_time:
        progress = 0.25 if current_attack == &"hook_throw" else 0.5
    else:
        progress = 0.75
    _pose_progress(animation, progress)


func _play_sfx(audio_key: String, volume_db: float = -5.0, pitch_scale: float = 1.0, voice_key: String = "", voice_priority: int = 1) -> void:
    if not _should_play_sfx():
        return
    # 声部准入（AudioDirector 契约）：同 key 最小间隔/并发上限/全局 24 声部抢占。
    var resolved_voice_key := voice_key if not voice_key.is_empty() else "player_" + audio_key
    var voice_ticket := _request_voice(resolved_voice_key, voice_priority)
    if voice_ticket == 0:
        return
    var stream := _load_sfx_stream(audio_key)
    if stream == null:
        # 声部回滚（AudioDirector 契约）：流缺失/解码失败时释放已占用的声部。
        _release_voice(voice_ticket)
        return
    var player_node := AudioStreamPlayer2D.new()
    player_node.name = "Sfx_" + audio_key
    player_node.set_meta("retire_after_playback",true)
    # 总线归位（音频规格 §5.1）：玩家动作音走 SFXPlayer 子总线，缺席时回落 SFX/Master。
    player_node.bus = _sfx_bus_name()
    player_node.stream = stream
    player_node.volume_db = volume_db
    player_node.pitch_scale = pitch_scale
    player_node.max_distance = 900.0
    add_child(player_node)
    player_node.finished.connect(Callable(player_node, "queue_free"))
    _start_voice(voice_ticket,player_node)


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
## 返回 0 拒绝，正数为唯一票据；-1 为脚本缺席的局部验证回退。
static func _request_voice(key: String, priority: int = 1, min_interval_ms: int = 40, max_voices: int = 3) -> int:
    if not _ensure_audio_director():
        return -1
    return int(audio_director_script.reserve_voice(key, priority, min_interval_ms, max_voices))


## 绑定唯一票据并开始播放。
static func _start_voice(ticket: int, voice: Node, persistent: bool = false) -> void:
    if ticket == -1:
        voice.play()
    elif _ensure_audio_director():
        audio_director_script.start_reserved_voice(ticket,voice,persistent)

## 拿不到流时只回滚这张票据，不影响同 key 的其他声音。
static func _release_voice(ticket: int) -> void:
    if _ensure_audio_director() and audio_director_script.has_method("release_ticket"):
        audio_director_script.release_ticket(ticket)


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
    if not VISUAL_POLICY.attach_secondary(parent_node, ghost, &"motion", self): return
    ghost.global_transform = sprite.global_transform
    var tween := ghost.create_tween()
    tween.tween_property(ghost, "self_modulate:a", 0.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tween.parallel().tween_property(ghost, "scale", ghost.scale * 0.94, 0.24)
    tween.finished.connect(Callable(ghost, "queue_free"))


## 冲刺线迹（规格 §2.3）：起点→终点一条 T2 主线，结束后从尾端收回（收线律）。
func _spawn_dash_trail() -> void:
    DASH_ART.finished(self)


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
    if is_instance_valid(wall_slide_audio) and wall_slide_audio.playing:return
    if not _should_play_sfx():
        return
    var voice_ticket := _request_voice("player_wall_slide_loop", 1, 40, 1)
    if voice_ticket == 0:
        return
    if wall_slide_audio == null or not is_instance_valid(wall_slide_audio):
        wall_slide_audio = AudioStreamPlayer2D.new()
        wall_slide_audio.name = "SfxLoop_wall_slide"
        wall_slide_audio.bus = _sfx_bus_name()
        wall_slide_audio.volume_db = -13.0
        wall_slide_audio.max_distance = 900.0
        add_child(wall_slide_audio)
    if wall_slide_audio.stream == null:
        # Region retirement releases streams while the persistent player survives.
        var stream := _load_sfx_stream("wall_slide_loop", true)
        if stream == null:
            _release_voice(voice_ticket)
            return
        wall_slide_audio.stream = stream
    if not wall_slide_audio.playing:
        _start_voice(voice_ticket,wall_slide_audio,true)


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
    var voice_ticket := _request_voice("player_footstep", 2, 90, 2)
    if voice_ticket == 0:
        return
    var material_key := String(FOOTSTEP_MATERIAL_REMAP.get(footstep_material, footstep_material))
    var variants: Array = FOOTSTEP_VARIANTS.get(material_key, FOOTSTEP_VARIANTS["moss"])
    if variants.is_empty():
        _release_voice(voice_ticket)
        return
    var path := String(variants[randi() % variants.size()])
    var stream := _load_stream_for_path(path)
    if stream == null:
        _release_voice(voice_ticket)
        return
    var player_node := AudioStreamPlayer2D.new()
    player_node.name = "SfxStep"
    player_node.set_meta("retire_after_playback",true)
    player_node.bus = _sfx_bus_name()
    player_node.stream = stream
    player_node.volume_db = FOOTSTEP_VOLUME_DB
    # 变体随机轮播 + ±4% 随机变调（丝之歌式"连打不重样"的最低成本实现）。
    player_node.pitch_scale = float(FOOTSTEP_BASE_PITCH.get(material_key, 1.0)) * randf_range(0.96, 1.04)
    player_node.max_distance = 900.0
    add_child(player_node)
    player_node.finished.connect(Callable(player_node, "queue_free"))
    _start_voice(voice_ticket,player_node)


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
        if not VISUAL_POLICY.attach_secondary(self, thread, &"state", self): continue
        var tween := thread.create_tween()
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
    if not VISUAL_POLICY.attach_secondary(self, ring, &"state", self): return
    ring.scale = Vector2(0.38, 0.38)
    var tween := ring.create_tween()
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
    MELEE_FEEDBACK.spawn_swing(self, sprite, attack_active_time, _accessibility())


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
    HOOK_ART.combat(self)


func _spawn_skill_slash_vfx() -> void:
    if CONTACT_ART.supported_slash(self):
        CONTACT_ART.skill_slash(self)
    else:
        _spawn_legacy_skill_slash_vfx()


func _spawn_legacy_skill_slash_vfx() -> void:
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
    if not VISUAL_POLICY.attach_secondary_batch(self, [burst, ring], &"state", self): return
    var tween := burst.create_tween()
    tween.tween_property(burst, "scale", Vector2(1.22, 1.22), 0.22)
    tween.parallel().tween_property(burst, "modulate:a", 0.0, 0.22)
    tween.parallel().tween_property(ring, "scale", Vector2(1.8, 1.8), 0.22)
    tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.22)
    tween.finished.connect(Callable(burst, "queue_free"))
    tween.finished.connect(Callable(ring, "queue_free"))


func _spawn_hit_confirm_vfx(world_position: Vector2, animation: StringName, receiver: Node2D = null, contact_call: int = -1) -> void:
    MELEE_FEEDBACK.spawn_hit(get_parent() as Node2D, world_position + Vector2(0.0, -28.0), current_attack_direction, animation, _accessibility(), receiver, contact_call, self)


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
    if not VISUAL_POLICY.attach_secondary(self, dust, &"motion", self): return
    var tween := dust.create_tween()
    tween.tween_property(dust, "scale", Vector2(1.7, 1.0), 0.18)
    tween.parallel().tween_property(dust, "modulate:a", 0.0, 0.18)
    tween.finished.connect(Callable(dust, "queue_free"))


func practice_guard_contact(source_position: Vector2) -> bool:
    # A practice contact is eligible only while already guarding the correct side.
    # It cannot damage, begin a guard, heal, or exceed the real prepaid guard refund.
    var source_side := signf(source_position.x - global_position.x)
    if guard_timer <= 0.0 or hurt_timer > 0.0 or death_timer > 0.0 or debug_invulnerable or arrival_guard_timer > 0.0 or (source_side != 0.0 and int(source_side) != facing):
        return false
    take_damage(1, source_position, true)
    return guard_timer <= 0.0


func take_damage(amount: int, source_position: Vector2 = global_position, blockable: bool = true) -> void:
    if arrival_guard_timer > 0.0:
        return
    if debug_invulnerable:
        return
    if hurt_timer > 0.0 or death_timer > 0.0:
        return
    if amount <= 0:
        return
    camera_focus.clear_look()
    _clear_action_buffer()
    var source_side := signf(source_position.x - global_position.x)
    if blockable and guard_timer > 0.0 and (source_side == 0.0 or int(source_side) == facing):
        var perfect := guard_timer >= guard_initial_duration - 0.14 and not guard_refunded
        if perfect:
            guard_refunded = true
            if _crest() == "bell" and _seal_mechanism_ready():
                bell_pressure = mini(2, bell_pressure + 1)
            # Guard refund stays below its payment: no repeatable energy source.
            gain_energy(4 if String(active_skill.get("kind", "")) != "defense" else 0)
            ability_action.emit("bell_guard", global_position, Vector2(facing, 0))
        guard_timer = 0.0
        hurt_timer = 0.12
        GUARD_ART.blocked(self, perfect)
        return
    GUARD_ART.clear(self)
    CONTACT_ART.clear_player(self)
    ABILITY_ART.clear(self)
    HOOK_ART.clear(self)
    DASH_ART.clear(self)
    line_stacks = 0
    line_expiry = 0.0
    _interrupt_heal()
    _stop_phase()
    _stop_grapple()
    guard_timer = 0.0
    # A damaging hit interrupts dash motion so the next tick preserves knockback.
    dash_timer = 0.0
    attack_timer = 0.0
    attack_shape.set_deferred("disabled", true)
    amount = maxi(1, int(ceil(float(amount) * float(build_profile.get("damage_taken_mult", 1.0)))))
    hp = maxi(0, hp - amount)
    hp_changed.emit(hp)
    # P0 生死攸关音：声部抢占最高优先级。
    _play_sfx("hurt", -6.0, 1.0, "", 0)
    if hp <= 0:
        bell_pressure = 0
        heal_speed_timer = 0.0
        heal_stability_timer = 0.0
        status_resist_timer = 0.0
        for enemy in get_tree().get_nodes_in_group("enemy"):
            if enemy.has_method("clear_salt_mark"):
                enemy.clear_salt_mark()
        death_timer = 0.9
        HURT_ART.died(self)
        respawn_reveal_timer = 0.0
        _set_death_visibility(1.0)
        velocity = Vector2.ZERO
        _stop_wall_slide_loop()
        # 死亡=绯线松脱（音频规格 §4.2 player_death）：无惨叫，只有线散与长呼气。
        _play_sfx("death_cocoon", -5.0, 1.0, "", 0)
        if feel != null:
            feel.hitstop(200.0)
            _add_trauma(0.60)
            _black_frame(global_position, 3)
        _play(&"death")
        return
    HURT_ART.hurt(self, source_position)
    if feel != null:
        feel.hitstop(110.0)
        _add_trauma(0.45)
        _black_frame(global_position, 2)
    self_flash_timer = 0.05
    if flash_material != null:
        flash_material.set_shader_parameter("flash_amount", 1.0 if bool(_accessibility().get("flash_enabled", true)) else 0.0)
    gain_energy(energy_on_damage)
    hurt_timer = 0.35
    var knockback_dir := signf(global_position.x - source_position.x)
    if knockback_dir == 0.0:
        knockback_dir = -facing
    if heal_stability_timer > 0.0:
        heal_stability_timer = 0.0
        velocity = Vector2.ZERO
    else:
        velocity = Vector2(knockback_dir * 260.0 * float(build_profile.get("knockback_mult", 1.0)), -170.0)
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
        if not VISUAL_POLICY.attach_secondary(parent_node, thread, &"state", self): continue
        var tween := thread.create_tween()
        tween.tween_property(thread, "position", origin + tip * 0.8, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tween.parallel().tween_property(thread, "modulate:a", 0.0, 0.25)
        tween.finished.connect(Callable(thread, "queue_free"))


func can_deflect_projectile() -> bool:
    if attack_timer <= 0.0 or guard_timer > 0.0 or hurt_timer > 0.0 or death_timer > 0.0:
        return false
    if not active_skill.is_empty() and String(active_skill.get("kind", "")) not in ["melee", "thrust", "crosscut"]:
        return false
    var elapsed := attack_duration - attack_timer
    return elapsed >= attack_windup and elapsed <= attack_windup + attack_active_time


func can_ignore_enemy_contact(_source_position: Vector2) -> bool:
    if death_timer > 0.0 or hurt_timer > 0.0:
        return true
    if not active_skill.is_empty():
        return false
    if dash_timer > 0.0 or enemy_contact_guard_timer > 0.0:
        return true
    return false


func set_spawn(position_value: Vector2) -> void:
    spawn_position = position_value


func prepare_region_handoff() -> void:
    # Cancel references to the departing geometry without making travel a free
    # cooldown reset or restoring the already reserved healing energy.
    var dash_remaining := dash_cooldown
    var guard_remaining := guard_cooldown
    var grapple_remaining := grapple_recovery_timer
    _reset_traversal_state()
    dash_cooldown = dash_remaining
    guard_cooldown = guard_remaining
    grapple_recovery_timer = grapple_remaining
    attack_vfx_started = false
    skill_effect_started = false
    skill_displacement_done = 0.0
    velocity = Vector2.ZERO
    ui_input_locked = false


func respawn_at(position_value: Vector2) -> void:
    _reset_traversal_state()
    global_position = position_value
    velocity = Vector2.ZERO
    reset_camera_after_arrival()
    player_respawned.emit()


func reset_camera_after_arrival() -> void:
    camera_focus.clear_look()
    var camera := get_node_or_null("Camera2D") as Camera2D
    if camera != null:
        room_camera.update(camera_focus, global_position)
        camera_focus.apply_limits(camera)
        camera_focus.reset_follow(global_position)
        camera.position = Vector2(0, -55)
        camera.offset = Vector2.ZERO
        camera.rotation = 0.0
        camera.reset_smoothing()
        camera.force_update_scroll()


func _set_death_visibility(amount: float) -> void:
    # The hit-flash shader writes COLOR itself, so CanvasItem alpha alone does
    # not fade the authored player or the idle layers using this material.
    if flash_material != null:
        flash_material.set_shader_parameter("presentation_alpha", clampf(amount, 0.0, 1.0))


func _update_respawn_reveal(delta: float) -> void:
    if respawn_reveal_timer <= 0.0:
        return
    respawn_reveal_timer = maxf(0.0, respawn_reveal_timer - delta)
    _set_death_visibility(1.0 - respawn_reveal_timer / RESPAWN_REVEAL_SECONDS)


func _hard_respawn() -> void:
    snare_timer = 0.0
    hp = max_hp
    energy = 0
    hp_changed.emit(hp)
    energy_changed.emit(energy, max_energy)
    respawn_at(spawn_position)
    # 钟龛复活（音频规格 §4.2 player_respawn）：龛铃三音上行 + 吸气。
    _play_sfx("respawn_weave", -7.0, 1.0, "", 0)
    _play(&"idle")
    respawn_reveal_timer = RESPAWN_REVEAL_SECONDS
    _set_death_visibility(0.0)
    HURT_ART.respawned(self)


func restore_at_save_point() -> void:
    _reset_traversal_state()
    snare_timer = 0.0
    hp = max_hp
    energy = max_energy
    practice_energy = 0
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

    var scale_value := float(data.get("sprite_scale", 0.66))
    sprite.scale = Vector2.ONE * scale_value
    var position_value: Array = data.get("sprite_position", [0, -50])
    sprite.position = Vector2(float(position_value[0]), float(position_value[1]))
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
        "double_jump_unlocked": double_jump_unlocked,
        "air_jump_available": air_jump_available,
        "thread_grapple_unlocked": thread_grapple_unlocked,
        "grappling": grapple_timer > 0.0,
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
    # E is traversal phase; combat skills use L. Do not leave a legacy E event.
    if InputMap.has_action("skill_1"):
        for existing in InputMap.action_get_events("skill_1"):
            if existing is InputEventKey and existing.physical_keycode == KEY_E:
                InputMap.action_erase_event("skill_1", existing)
    _bind_key("skill_1", [KEY_L])
    _bind_key("bell_guard", [KEY_Q])
    _bind_key("lantern_phase", [KEY_E])
    _bind_key("crown_resonance", [KEY_R])
    _bind_key("heal", [KEY_H])
    _bind_joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
    _bind_joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
    _bind_joy_axis("aim_up", JOY_AXIS_LEFT_Y, -1.0)
    _bind_joy_axis("aim_down", JOY_AXIS_LEFT_Y, 1.0)
    _bind_joy("attack", JOY_BUTTON_X)
    _bind_joy("jump", JOY_BUTTON_A)
    _bind_joy("dash", JOY_BUTTON_B)
    _bind_joy("skill_1", JOY_BUTTON_Y)
    _bind_joy("hook", JOY_BUTTON_RIGHT_SHOULDER)
    _bind_joy("heal", JOY_BUTTON_LEFT_SHOULDER)
    _bind_joy("bell_guard", JOY_BUTTON_DPAD_LEFT)
    _bind_joy("lantern_phase", JOY_BUTTON_DPAD_RIGHT)
    _bind_joy("crown_resonance", JOY_BUTTON_DPAD_UP)
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


func _bind_joy(action_name: StringName, button: JoyButton) -> void:
    if not InputMap.has_action(action_name):
        InputMap.add_action(action_name)
    for event in InputMap.action_get_events(action_name):
        if event is InputEventJoypadButton and event.button_index == button:
            return
    var joy := InputEventJoypadButton.new()
    joy.button_index = button
    InputMap.action_add_event(action_name, joy)


func _accessibility() -> Dictionary:
    return get_meta("accessibility", {})


func _add_trauma(amount: float) -> void:
    if feel != null:
        feel.add_trauma(amount * clampf(float(_accessibility().get("camera_shake", 1.0)), 0.0, 1.0))


func _flash_screen(color: Color, duration: float, frames: int) -> void:
    if feel != null and bool(_accessibility().get("flash_enabled", true)):
        feel.flash_screen(color, duration, frames)


func _black_frame(point: Vector2, frames: int) -> void:
    if feel != null and bool(_accessibility().get("flash_enabled", true)):
        feel.black_frame(point, frames)


func get_combat_ui_state() -> Dictionary:
    var skill := selected_skill
    if build_system != null and build_system.has_method("selected_skill"):
        skill = build_system.selected_skill()
    return {"heal_progress": 1.0 - heal_timer / maxf(0.2, heal_duration) if heal_timer > 0.0 else 0.0,
        "heal_active": heal_timer > 0.0, "heal_cost": heal_energy_cost, "heal":get_heal_readiness(),
        "skill_name": String(skill.get("name", skill.get("label", skill.get("id", "绯线震击")))),
        "skill_cooldown": float(skill.get("cooldown_remaining", skill_cooldown)), "skill_cost": int(skill.get("energy_cost", skill_energy_cost)),
        "guard_cooldown": guard_cooldown, "phase_active": phase_active,
        "equipment_name": "", "equipment_count": 0}


func _bind_joy_axis(action_name: StringName, axis: JoyAxis, axis_value: float) -> void:
    if not InputMap.has_action(action_name):
        InputMap.add_action(action_name, 0.3)
    for event in InputMap.action_get_events(action_name):
        if event is InputEventJoypadMotion and event.axis == axis and event.axis_value == axis_value:
            return
    var joy := InputEventJoypadMotion.new()
    joy.axis = axis
    joy.axis_value = axis_value
    InputMap.action_add_event(action_name, joy)


func _exit_tree() -> void:
    CONTACT_ART.clear_player(self)
    ABILITY_ART.clear(self)
    HOOK_ART.clear(self)
    DASH_ART.clear(self)
    HURT_ART.clear(self)
    MOVEMENT_ART.clear(self)
    HEAL_ART.clear(self)
    GUARD_ART.clear(self)
    VISUAL_POLICY.clear_secondary(self)
