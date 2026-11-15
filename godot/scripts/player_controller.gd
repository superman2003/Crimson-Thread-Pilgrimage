extends CharacterBody2D
const PLAYER_SEALS := preload("res://scripts/player_seals.gd")
const PLAYER_AUDIO := preload("res://scripts/player_audio.gd")
const PLAYER_EFFECTS := preload("res://scripts/player_effects.gd")
const PLAYER_TRAVERSAL := preload("res://scripts/player_traversal.gd")
const PLAYER_ATTACK := preload("res://scripts/player_attack.gd")
const PLAYER_ANIMATION := preload("res://scripts/player_animation.gd")
const PLAYER_ABILITIES := preload("res://scripts/player_abilities.gd")
const PLAYER_SPRITES := preload("res://scripts/player_sprites.gd")

signal hp_changed(value: int)
signal player_respawned
signal energy_changed(value: int, maximum: int)
var arrival_guard_timer := 0.0
var combat_effect_generation := 0

signal ability_action(ability_id: String, origin: Vector2, direction: Vector2)
signal heal_state_changed(state: String)
## A strike met breakable terrain it did not break (no thorn downstrike).
signal gate_struck(gate: Node, point: Vector2)
signal skill_cast(skill_id: String)
## Post-acceptance observations; consumers cannot change combat outcomes.
signal combat_observed(event: Dictionary)

@export var debug_invulnerable := false
## Journey difficulty (difficulty_setting.gd): whole masks added to each hit,
## and seconds of extra safety after one. Both are 0 on the standard tier.
var difficulty_damage_bonus := 0
var difficulty_mercy := 0.0
var mercy_timer := 0.0
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
var heal_voice: Node
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
var gate_strike_paid := false
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
var last_skill_cast_serial := 0
var heal_reserved_practice := 0
const PRACTICE_ENERGY_RADIUS := 520.0
var crosscut_refund_paid := false
var seal_presentation: Node2D = null
var seal_recovery_shown := false
var skill_displacement_done := 0.0

func _seal_present(id: String, stage: String) -> void:
    PLAYER_SEALS.seal_present(self, id, stage)


func _seal_mechanism_ready() -> bool:
    return PLAYER_SEALS.seal_mechanism_ready(self)

func get_seal_mechanism_snapshot() -> Dictionary:
    return PLAYER_SEALS.get_seal_mechanism_snapshot(self)

func get_seal_combat_state() -> Dictionary:
    return PLAYER_SEALS.get_seal_combat_state(self)

func _seal_tick(delta: float) -> void:
    PLAYER_SEALS.seal_tick(self, delta)

func _settle_practice_energy() -> void:
    PLAYER_SEALS.settle_practice_energy(self)

func _heal_airborne() -> bool:
    return PLAYER_SEALS.heal_airborne(self)

func _crest() -> String:
    return PLAYER_SEALS.crest(self)

func _basic_seal_hit() -> void:
    PLAYER_SEALS.basic_seal_hit(self)

func _seal_heal_completed() -> void:
    PLAYER_SEALS.seal_heal_completed(self)



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
    # 可破地面被普通一击敲到：只开裂、不碎（棘线下劈才能击碎）。
    "downstrike_crack": "res://assets/audio/sfx/generated/player_downstrike_crack.ogg",
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
    # 动作同步（S02）：二段跳、钟壳格挡、疗伤完成/打断各用自己的声音。
    "double_jump": "res://assets/audio/sfx/generated/player_double_jump_wings.ogg",
    "guard_block": "res://assets/audio/sfx/generated/player_guard_block.ogg",
    "guard_perfect": "res://assets/audio/sfx/generated/player_guard_perfect.ogg",
    "bind_tighten": "res://assets/audio/sfx/generated/player_bind_tighten.ogg",
    "bind_interrupt": "res://assets/audio/sfx/generated/player_bind_interrupt.ogg",
    # 疗伤引导循环：整段引导都在响，音高随进度上扬，完成或打断即停。
    "bind_channel": "res://assets/audio/sfx/generated/player_bind_channel.ogg",
    # 章节 beat 叠层（audio_visual_manifest chapter beats，ch2 雨铸运河 / ch4 断弦温室）：
    # 材质条件由 main_level 写入的 footstep_material 判定（copper=ch2、fiber=ch4）。
    "ch02_beat_wall_grip_drip": "res://assets/audio/sfx/generated/ch02_rain_foundry_canal_beat_01_audio.ogg",
    "ch02_beat_echo_hook": "res://assets/audio/sfx/generated/ch02_rain_foundry_canal_beat_02_audio.ogg",
    "ch04_beat_thorn_downstrike": "res://assets/audio/sfx/generated/ch04_broken_string_greenhouse_beat_01_audio.ogg",
    # 灯影相位进入（manifest ch05_beat_01 灯芯吸入声）：各区通用，此前进入相位无声。
    "phase_enter": "res://assets/audio/sfx/generated/ch05_obsidian_pilgrim_road_beat_01_audio.ogg",
    # ch3 beat `bell_guard`（manifest ch03_beat_02）：盐白书库（salt 主题）完美格挡叠钟壳回流声。
    "ch03_beat_guard_ring": "res://assets/audio/sfx/generated/ch03_saltwhite_archive_beat_02_audio.ogg"
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
const PLAYER_MANIFEST := "res://assets/sprites/player/thread_doll_v1/manifest.json"
# Runtime registration of the existing four idle poses, in source-texture pixels.
# Midpoint of the two opaque boot soles (y=276..281), not cape/weapon bounds.
# The source poses change their stance slightly; this removes the whole-body
# side-to-side drift without replacing the authored breathing/cape frames.
const IDLE_FOOT_CENTER_X := [186.223262, 187.667973, 186.765838, 185.263814]
var idle_foot_centers: Array = IDLE_FOOT_CENTER_X.duplicate()
var grounded_pose_foot_centers: Dictionary = {}
var pose_thread_anchors: Dictionary = {}
var use_layered_idle := false
# The gait owns the world stride; collision-resolved travel advances both the
# continuous planted-foot rig and its fallback/export pose sequence.
const RUN_GAIT := preload("res://scripts/thread_doll_run_cycle.gd")
const RUN_CYCLE_DISTANCE := RUN_GAIT.CYCLE_DISTANCE
const GROUNDED_RUN := preload("res://scripts/thread_doll_run_presentation.gd")
const RUN_RIG_MAX_SLOPE := 0.3
var grounded_run: Node2D
var use_grounded_run := false
const GROUND_TURN_DURATION := .12
var ground_turn_time := 0.0
var ground_turn_from := 1
var last_ground_direction := 0
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
## C01: jump/dash may cut a nail swing's or hook throw's recovery, but the rest
## of that recovery is still owed before the next strike (attack, hook throw, art).
var attack_cancel_lock := 0.0
## Diagnostic: swings whose recovery was cut by a jump or dash.
var recovery_cancel_count := 0
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
## Heal channel loop (bind_channel): the whole channel is voiced, whatever the
## seal's heal time, and the pitch rises with its progress.
var bind_channel_audio: AudioStreamPlayer2D
const BIND_CHANNEL_PITCH := Vector2(0.92, 1.12)
## 由 main_level 按章节 art theme 写入（moss/copper/salt/fiber/obsidian）。
var footstep_material: String = "moss"
## Foot contacts crossed by the run cycle since the last footstep update.
var footstep_contacts := 0
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
    if use_grounded_run:
        grounded_run = GROUNDED_RUN.new()
        if not grounded_run.attach(sprite):
            grounded_run.free()
            grounded_run = null
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
        ground_turn_time = 0.0
        last_ground_direction = 0
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
    if mercy_timer > 0.0:
        mercy_timer -= delta

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
    attack_cancel_lock = maxf(0.0, attack_cancel_lock - delta)
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
    if wall_grip_unlocked and not is_on_floor() and is_on_wall() and _can_grip_current_wall() and dash_timer <= 0.0 and grapple_timer <= 0.0 and heal_timer <= 0.0 and velocity.y > 0.0:
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
    var recovery_open := attack_timer <= 0.0 or _attack_recovery_cancelable()
    if jump_buffer_timer > 0.0 and coyote_timer > 0.0 and dash_timer <= 0.0 and heal_timer <= 0.0 and recovery_open and hurt_timer <= 0.0:
        _cancel_attack_recovery()
        velocity.y = jump_velocity
        coyote_timer = 0.0
        jump_buffer_timer = 0.0
        _play(&"jump_start")
        _play_sfx("jump", -6.0)
    elif jump_buffer_timer > 0.0 and dash_timer <= 0.0 and wall_grip_unlocked and not is_on_floor() and is_on_wall() and _can_grip_current_wall() and heal_timer <= 0.0 and recovery_open and hurt_timer <= 0.0:
        # 蹬墙跳：离墙水平 420 / 垂直 -640，播 wall_slide 帧。
        _cancel_attack_recovery()
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

    elif Input.is_action_just_pressed("jump") and double_jump_unlocked and air_jump_available and not is_on_floor() and dash_timer <= 0.0 and heal_timer <= 0.0 and recovery_open and hurt_timer <= 0.0:
        _cancel_attack_recovery()
        ability_action.emit("double_thread_jump", global_position, Vector2.UP)
        air_jump_available = false
        velocity.y = double_jump_velocity
        jump_buffer_timer = 0.0
        coyote_timer = 0.0
        wall_sliding = false
        _play(&"jump_start")
        _play_sfx("double_jump", -6.0)
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

    if _consume_action_input(&"attack") or _consume_action_input(&"hook"):
        pass
    elif Input.is_action_just_pressed("skill_1") and _can_start_action() and attack_cancel_lock <= 0.0:
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
func _can_grip_current_wall() -> bool:
    return PLAYER_TRAVERSAL.can_grip_current_wall(self)

func _try_start_grapple() -> bool:
    return PLAYER_TRAVERSAL.try_start_grapple(self)


func _update_grapple(delta: float) -> void:
    PLAYER_TRAVERSAL.update_grapple(self, delta)

## Cosmetic origin follows the painted knot; reach/obstruction rays keep their
## existing gameplay origin and cannot gain range from a drawing's hand motion.
func thread_origin_offset() -> Vector2:
    return PLAYER_TRAVERSAL.thread_origin_offset(self)


func _stop_grapple(recover: bool = false) -> void:
    PLAYER_TRAVERSAL.stop_grapple(self, recover)


func _reset_traversal_state() -> void:
    PLAYER_TRAVERSAL.reset_traversal_state(self)


func _spawn_double_jump_vfx() -> void:
    PLAYER_EFFECTS.spawn_double_jump_vfx(self)


func _start_attack(animation: StringName, allow_traversal_action: bool = true, queued_direction: Vector2 = Vector2.ZERO) -> void:
    PLAYER_ATTACK.start_attack(self, animation, allow_traversal_action, queued_direction)


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
    elif Input.is_action_just_pressed("hook"):
        # C01: a hook pressed during a swing, its owed recovery or a dash waits
        # like the nail does instead of being dropped.
        action = &"hook"
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
    if buffered_action != action:
        return false
    var dash := action == &"dash"
    if not dash and attack_cancel_lock > 0.0:
        # The buffered swing or hook waits out the cut recovery instead of being
        # lost, even when that recovery is longer than the input buffer and the
        # dash that cut it is still running.
        action_buffer_timer = maxf(action_buffer_timer, attack_cancel_lock + 0.05)
    if not _can_start_action(dash, dash):
        return false
    if dash and (not dash_unlocked or dash_cooldown > 0.0):
        return false
    if not dash and attack_cancel_lock > 0.0:
        return false
    var direction := buffered_direction
    # Consume before any signal/callback can re-enter action handling.
    _clear_action_buffer()
    if absf(direction.x) > 0.1:
        facing = signi(direction.x)
        sprite.flip_h = facing < 0
    if action == &"attack":
        _start_attack(&"attack_1", true, direction)
    elif action == &"hook":
        if not _try_start_grapple():
            _start_attack(&"hook_throw")
    else:
        _cancel_attack_recovery()
        _start_dash()
    return true


## A nail swing or hook throw (not a thread art) commits through its wind-up
## and active frames; only its recovery may be cut.
func _attack_recovery_cancelable() -> bool:
    if attack_timer <= 0.0 or not active_skill.is_empty() or current_attack not in [&"attack_1", &"attack_2", &"hook_throw"]:
        return false
    return attack_duration - attack_timer > attack_windup + attack_active_time


func _cancel_attack_recovery() -> void:
    if attack_timer <= 0.0:
        return
    attack_cancel_lock = attack_timer
    recovery_cancel_count += 1
    attack_timer = 0.0
    attack_shape.disabled = true
    traversal_downstrike_active = false
    run_attack_pose = false


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


func _can_start_action(allow_grapple: bool = false, allow_recovery_cancel: bool = false) -> bool:
    if get_parent().has_method("_walking_world_passage") and get_parent()._walking_world_passage():
        return false
    return death_timer <= 0.0 and hurt_timer <= 0.0 and (attack_timer <= 0.0 or (allow_recovery_cancel and _attack_recovery_cancelable())) and dash_timer <= 0.0 and (allow_grapple or grapple_timer <= 0.0) and heal_timer <= 0.0 and guard_timer <= 0.0 and not phase_active and not ui_input_locked

## Read-only HUD query; shares the real action gate, including traversal handoff.
func get_cast_readiness(skill_id: String = "") -> Dictionary:
    return PLAYER_ABILITIES.get_cast_readiness(self, skill_id)


func configure_selected_skill(skill: Dictionary) -> void:
    PLAYER_ABILITIES.configure_selected_skill(self, skill)


func _try_skill_burst() -> void:
    PLAYER_ABILITIES.try_skill_burst(self)


func cast_selected_skill(slot: int = -1) -> bool:
    return PLAYER_ABILITIES.cast_selected_skill(self, slot)


func get_heal_readiness() -> Dictionary:
    return PLAYER_ABILITIES.get_heal_readiness(self)

func _try_heal() -> bool:
    return PLAYER_ABILITIES.try_heal(self)


func _update_heal(delta: float) -> void:
    PLAYER_ABILITIES.update_heal(self, delta)


func _interrupt_heal() -> void:
    PLAYER_ABILITIES.interrupt_heal(self)


func apply_build_stats(stats: Dictionary) -> void:
    PLAYER_ABILITIES.apply_build_stats(self, stats)


func _apply_capacity_limits(stats: Dictionary) -> void:
    PLAYER_ABILITIES.apply_capacity_limits(self, stats)


func _try_guard() -> bool:
    return PLAYER_ABILITIES.try_guard(self)


func _try_resonance() -> bool:
    return PLAYER_ABILITIES.try_resonance(self)


func is_phasing() -> bool:
    return phase_active


func _update_phase(delta: float) -> void:
    PLAYER_TRAVERSAL.update_phase(self, delta)


func _sync_phase_gates() -> void:
    PLAYER_TRAVERSAL.sync_phase_gates(self)


func _phase_position_clear() -> bool:
    return PLAYER_TRAVERSAL.phase_position_clear(self)


func _stop_phase() -> void:
    PLAYER_TRAVERSAL.stop_phase(self)


func _update_camera(delta: float) -> void:
    PLAYER_TRAVERSAL.update_camera(self, delta)


func configure_camera_focus(bounds: Rect2) -> void:
    PLAYER_TRAVERSAL.configure_camera_focus(self, bounds)


func configure_room_camera(rooms: Array) -> void:
    PLAYER_TRAVERSAL.configure_room_camera(self, rooms)


func push_camera_lock(id: String, bounds: Rect2, priority: int = 0, prevent_up: bool = false, prevent_down: bool = false) -> bool:
    return PLAYER_TRAVERSAL.push_camera_lock(self, id, bounds, priority, prevent_up, prevent_down)


func remove_camera_lock(id: String) -> void:
    PLAYER_TRAVERSAL.remove_camera_lock(self, id)


func _apply_special_skill() -> void:
    PLAYER_ABILITIES.apply_special_skill(self)



func cast_tool(payload: Dictionary) -> bool:
    return PLAYER_ABILITIES.cast_tool(self, payload)


func _attack_line_clear(target: Vector2) -> bool:
    return PLAYER_ATTACK.attack_line_clear(self, target)


func _update_attack(delta: float) -> void:
    PLAYER_ATTACK.update_attack(self, delta)


func _apply_attack_hits() -> void:
    PLAYER_ATTACK.apply_attack_hits(self)


## Breakable floors answer an ordinary strike with a crack, once per swing, so
## the player learns the floor gives way to a stronger blow. No text: abilities
## not yet found are not named. The thorn downstrike itself breaks the floor.
func _try_gate_strike(attack_rect: Rect2) -> void:
    PLAYER_ATTACK.try_gate_strike(self, attack_rect)


## A downslash that meets static spikes bounces like an enemy hit, but awards no
## thread and no hit feedback. Terrain between the player and spikes blocks it.
func _try_hazard_pogo(attack_rect: Rect2) -> void:
    PLAYER_ATTACK.try_hazard_pogo(self, attack_rect)


## 命中反馈分档（规格 §2.1/§2.2）：hitstop + trauma + 击杀闪帧。
func _trigger_hit_feedback(killed: bool) -> void:
    PLAYER_ATTACK.trigger_hit_feedback(self, killed)


func _sync_attack_hitbox() -> void:
    PLAYER_ATTACK.sync_attack_hitbox(self)


func _read_attack_direction() -> Vector2:
    return PLAYER_ATTACK.read_attack_direction(self)


## UI 输入闸（共享契约）：overlay 打开时移动/瞄准输入归零。
func _move_axis() -> float:
    return PLAYER_ATTACK.move_axis(self)


func _attack_size() -> Vector2:
    return PLAYER_ATTACK.attack_size(self)


func _attack_center_offset() -> Vector2:
    return PLAYER_ATTACK.attack_center_offset(self)


func _attack_hit_direction() -> int:
    return PLAYER_ATTACK.attack_hit_direction(self)


func _apply_downslash_bounce(_target_position: Vector2) -> void:
    PLAYER_ATTACK.apply_downslash_bounce(self, _target_position)


## pogo 压缩–弹射形变（规格 §2.2）：压缩 → 拉伸 → 弹性回正。
func _play_pogo_squash() -> void:
    PLAYER_ATTACK.play_pogo_squash(self)


func gain_energy(amount: int, practice_gain: bool = false) -> void:
    var change:=preload("res://scripts/heal_refund_account.gd").change(amount,energy,max_energy,practice_energy,practice_gain)
    _apply_thread_balance(int(change.energy),int(change.practice))

func _apply_thread_balance(next_energy: int, next_practice: int) -> void:
    var before := energy
    energy=clampi(next_energy,0,max_energy)
    practice_energy=clampi(next_practice,0,energy)
    if energy != before:
        energy_changed.emit(energy, max_energy)


func _update_ground_motion(delta: float, platform_motion: Vector2 = Vector2.ZERO) -> void:
    PLAYER_ANIMATION.update_ground_motion(self, delta, platform_motion)


func _pose_ground_run() -> void:
    PLAYER_ANIMATION.pose_ground_run(self)


func _sync_sprite_pose_anchor() -> void:
    PLAYER_ANIMATION.sync_sprite_pose_anchor(self)


func _update_animation(_input_axis: float) -> void:
    PLAYER_ANIMATION.update_animation(self, _input_axis)


func _play(name: StringName, restart: bool = false) -> void:
    PLAYER_ANIMATION.play(self, name, restart)


func _has_pose(name: StringName) -> bool:
    return PLAYER_ANIMATION.has_pose(self, name)


func _pose_progress(name: StringName, progress: float) -> void:
    PLAYER_ANIMATION.pose_progress(self, name, progress)


func _update_attack_pose() -> void:
    PLAYER_ANIMATION.update_attack_pose(self)


func _play_sfx(audio_key: String, volume_db: float = -5.0, pitch_scale: float = 1.0, voice_key: String = "", voice_priority: int = 1) -> void:
    PLAYER_AUDIO.play_sfx(self, audio_key, volume_db, pitch_scale, voice_key, voice_priority)


## Same as _play_sfx, returning the playing node so a cut-short action can stop it.
func _play_sfx_voice(audio_key: String, volume_db: float = -5.0, pitch_scale: float = 1.0, voice_key: String = "", voice_priority: int = 1) -> Node:
    return PLAYER_AUDIO.play_sfx_voice(self, audio_key, volume_db, pitch_scale, voice_key, voice_priority)


## 落地分档（音频规格 §4.1）：按触地前一帧的下落速度选软/硬落地采样。
func _play_land_sfx(fall_speed: float) -> void:
    PLAYER_AUDIO.play_land_sfx(self, fall_speed)


## 玩家音源总线：SFXPlayer（AudioDirector 子总线，send→SFX）→ SFX → Master 逐级回落。
func _sfx_bus_name() -> String:
    return PLAYER_AUDIO.sfx_bus_name(self)


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
    PLAYER_EFFECTS.spawn_dash_ghost(self)


## 冲刺线迹（规格 §2.3）：起点→终点一条 T2 主线，结束后从尾端收回（收线律）。
func _spawn_dash_trail() -> void:
    DASH_ART.finished(self)


func _should_play_sfx() -> bool:
    return PLAYER_AUDIO.should_play_sfx(self)


func _load_sfx_stream(audio_key: String, looped: bool = false) -> AudioStream:
    return PLAYER_AUDIO.load_sfx_stream(self, audio_key, looped)


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
    PLAYER_AUDIO.update_wall_slide_audio(self)


func _start_wall_slide_loop() -> void:
    PLAYER_AUDIO.start_wall_slide_loop(self)


func _start_bind_channel() -> void:
    PLAYER_AUDIO.start_bind_channel(self)


func _stop_bind_channel() -> void:
    PLAYER_AUDIO.stop_bind_channel(self)


func _stop_wall_slide_loop() -> void:
    PLAYER_AUDIO.stop_wall_slide_loop(self)


## 材质化脚步触发（音频规格 §4.2）：跑步姿态由位移相位驱动，脚步声在相位
## 跨过左右两个落脚姿态时触发，与画面上的落脚同拍（不再另按固定步距计步）。
func _update_footsteps(_delta: float) -> void:
    PLAYER_AUDIO.update_footsteps(self, _delta)


func _play_footstep() -> void:
    PLAYER_AUDIO.play_footstep(self)


func _spawn_heal_effect() -> void:
    PLAYER_EFFECTS.spawn_heal_effect(self)


func _add_heal_ring(radius: float, delay: float) -> void:
    PLAYER_EFFECTS.add_heal_ring(self, radius, delay)


func _spawn_attack_vfx(animation: StringName) -> void:
    PLAYER_EFFECTS.spawn_attack_vfx(self, animation)


func _spawn_hook_trail_vfx() -> void:
    HOOK_ART.combat(self)


func _spawn_skill_slash_vfx() -> void:
    PLAYER_EFFECTS.spawn_skill_slash_vfx(self)


func _spawn_hit_confirm_vfx(world_position: Vector2, animation: StringName, receiver: Node2D = null, contact_call: int = -1) -> void:
    MELEE_FEEDBACK.spawn_hit(get_parent() as Node2D, world_position + Vector2(0.0, -28.0), current_attack_direction, animation, _accessibility(), receiver, contact_call, self)


func _spawn_land_vfx() -> void:
    PLAYER_EFFECTS.spawn_land_vfx(self)


func practice_guard_contact(source_position: Vector2) -> bool:
    # A practice contact is eligible only while already guarding the correct side.
    # It cannot damage, begin a guard, heal, or exceed the real prepaid guard refund.
    var source_side := signf(source_position.x - global_position.x)
    if guard_timer <= 0.0 or hurt_timer > 0.0 or death_timer > 0.0 or debug_invulnerable or arrival_guard_timer > 0.0 or (source_side != 0.0 and int(source_side) != facing):
        return false
    take_damage(1, source_position, true)
    return guard_timer <= 0.0


func take_damage(amount: int, source_position: Vector2 = global_position, blockable: bool = true) -> bool:
    if arrival_guard_timer > 0.0:
        return false
    if debug_invulnerable:
        return false
    if hurt_timer > 0.0 or death_timer > 0.0 or mercy_timer > 0.0:
        return false
    if amount <= 0:
        return false
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
        _play_sfx("guard_perfect" if perfect else "guard_block", -5.0, 1.0, "player_guard", 0)
        if perfect and footstep_material == "salt":
            _play_sfx("ch03_beat_guard_ring", -10.0)
        GUARD_ART.blocked(self, perfect)
        combat_observed.emit({"kind":"guard","perfect":perfect})
        return false
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
    amount = maxi(1, amount + difficulty_damage_bonus)
    var hp_before_damage := hp
    hp = maxi(0, hp - amount)
    hp_changed.emit(hp)
    combat_observed.emit({"kind":"hurt","damage":hp_before_damage-hp,"lethal":hp<=0})
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
        return true
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
    mercy_timer = hurt_timer + difficulty_mercy if difficulty_mercy > 0.0 else 0.0
    var knockback_dir := signf(global_position.x - source_position.x)
    if knockback_dir == 0.0:
        knockback_dir = -facing
    if heal_stability_timer > 0.0:
        heal_stability_timer = 0.0
        velocity = Vector2.ZERO
    else:
        velocity = Vector2(knockback_dir * 260.0 * float(build_profile.get("knockback_mult", 1.0)), -170.0)
    _play(&"hurt")
    return true


## 受伤丝线崩断（规格 §2.10）：从受击点向外 5 条绯线绷断飞散。
func _spawn_thread_snap_vfx(source_position: Vector2) -> void:
    PLAYER_EFFECTS.spawn_thread_snap_vfx(self, source_position)


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
    reset_physics_interpolation()
    if camera != null:
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
    practice_energy = 0
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
    PLAYER_SPRITES.load_sprite_frames(self)


func _load_generated_hero_frames(data: Dictionary) -> SpriteFrames:
    return PLAYER_SPRITES.load_generated_hero_frames(self, data)


func _res_path_from_manifest(path: String) -> String:
    return PLAYER_SPRITES.res_path_from_manifest(self, path)


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
    return PLAYER_SPRITES.load_texture_resource(self, path)


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
