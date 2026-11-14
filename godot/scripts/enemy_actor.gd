extends Area2D

const SOUND_FILTER := preload("res://scripts/enemy_sound_filter.gd")
const CONTACT_ART := preload("res://scripts/player_contact_art.gd")
const VISUAL_POLICY := preload("res://scripts/combat_visual_policy.gd")

const ORIGINAL_ART := preload("res://scripts/hand_drawn_assets.gd")
const MOTION_TRANSITIONS := preload("res://scripts/enemy_motion_transitions.gd")
var motion_transitions := MOTION_TRANSITIONS.new()
const ATTACK_EFFECT := preload("res://scripts/enemy_attack_effect.gd")
const COMBAT_AUDIO := preload("res://scripts/enemy_combat_audio.gd")
const STREAM_SOURCE := preload("res://scripts/audio_stream_source.gd")
const BOSS_SKILL_ART := preload("res://scripts/boss_skill_art.gd")
const BOSS_STYLE := preload("res://scripts/boss_combat_style.gd")
var boss_skill_texture: Texture2D
const MINOR_SKILL_ART := preload("res://scripts/minor_enemy_skill_art.gd")
const BOSS_TACTICS := preload("res://scripts/enemy_boss_tactics.gd")
const ENEMY_PRESENTATION := preload("res://scripts/enemy_presentation.gd")
const ENEMY_EFFECTS := preload("res://scripts/enemy_effects.gd")
const ENEMY_AUDIO := preload("res://scripts/enemy_audio.gd")
const ENEMY_ENGAGEMENT := preload("res://scripts/enemy_engagement.gd")
const ENEMY_ATTACK_CHOICE := preload("res://scripts/enemy_attack_choice.gd")
const ENEMY_ATTACK_PHASES := preload("res://scripts/enemy_attack_phases.gd")
var minor_skill_texture: Texture2D
var locomotion := "ground"
var flight_clock := 0.0
var hover_height := 0.0
var attack_elapsed := 0.0
var attack_recovery := false
var recovery_velocity_x := 0.0
var boss_target_history: Array[Vector2] = []
var boss_attack_history: Array[Vector2] = []
var boss_history_clock := 0.0
var boss_blink_destination := Vector2.ZERO
var combo_visual_stage := ""
var combo_origin_direction := 1
var attack_start_position := Vector2.ZERO
var attack_target := Vector2.ZERO
var trail_clock := 0.0
var battle_phase := 1
var phase_pause := 0.0
var snare_timer := 0.0
var salt_mark_timer := 0.0
var salt_mark_extended := false
var interference_timer := 0.0
var lure_timer := 0.0
var lure_position := Vector2.ZERO
var trip_timer := 0.0
var combat_resistance: Dictionary = {}

func world_residency_active() -> bool:
    return not has_meta("world_residency_active") or bool(get_meta("world_residency_active", true))

func apply_salt_mark(seconds: float) -> void:
    salt_mark_timer = maxf(0.0, seconds)
    salt_mark_extended = false

func consume_salt_mark() -> bool:
    var present := salt_mark_timer > 0.0
    clear_salt_mark()
    return present

func extend_salt_mark_once(seconds: float) -> void:
    if salt_mark_timer > 0.0 and not salt_mark_extended:
        salt_mark_timer += minf(2.0, maxf(0.0, seconds))
        salt_mark_extended = true

func clear_salt_mark() -> void:
    salt_mark_timer = 0.0
    salt_mark_extended = false

func apply_stagger(seconds: float) -> void:
    if not is_boss and not dying:
        trip_timer = maxf(trip_timer, minf(0.6, seconds))

func apply_trip(seconds: float) -> void:
    if not bool(combat_resistance.get("trip_immune", is_boss)):
        trip_timer = maxf(trip_timer, minf(1.0, seconds))
        attack_recovery=false
        recovery_velocity_x=0.0
        _cancel_unarmed_attack_effects()
        _clear_telegraph()
        state = "recover"
        state_timer = maxf(state_timer, trip_timer)

func apply_target_interference(seconds: float) -> void:
    if not is_boss:
        interference_timer = maxf(interference_timer, minf(3.0, seconds))

func investigate_lure(point: Vector2, seconds: float) -> void:
    if bool(combat_resistance.get("lure_immune", is_boss)) or not bool(ai_profile.get("lure_eligible", not is_boss)) or dying or state in ["windup", "active"]:
        return
    if is_inside_tree():
        if get_parent().has_method("_ensure_collision_segment"):
            get_parent()._ensure_collision_segment(global_position + Vector2(0, -24), point)
        if get_parent().has_method("_rock_ray_hit") and not get_parent()._rock_ray_hit(global_position + Vector2(0, -24), point).is_empty():
            return
        var lure_ray := PhysicsRayQueryParameters2D.create(global_position + Vector2(0,-24), point, 1)
        lure_ray.collide_with_areas = false
        # Like sight, a lure is hidden by terrain, not by the Player's body.
        lure_ray.exclude = ATTACK_EFFECT.player_bodies(get_tree())
        if not get_world_2d().direct_space_state.intersect_ray(lure_ray).is_empty():
            return
    lure_position = point
    lure_timer = maxf(lure_timer, minf(2.0, seconds))

var original_visual := false
var authored_combat_sequences: Array=[]
var owned_attack_effects: Array[Node2D] = []
var combat_tweens: Array[Tween] = []
var combat_visuals_paused := false
var animation_was_playing := false

func _update_locomotion(delta: float, target: CharacterBody2D) -> void:
    if locomotion=="stationary":
        global_position=spawn_position
        return
    if locomotion=="flight":
        if state=="active" and String(active_attack.get("type",""))=="dive":
            return
        flight_clock+=delta
        var desired := spawn_position.y+sin(flight_clock*2.8+start_x*.01)*11
        var aggro_range := float(ai_profile.get("aggro_range", 220.0 if not is_boss else 460.0))
        var target_engaged := target != null and _target_inside_leash(target) and _target_in_engage_window(target, aggro_range) and _has_line_of_sight(target)
        var returning_home := not is_boss and leash_radius > 0.0 and (absf(global_position.x - spawn_position.x) > leash_radius or _should_return_to_spawn(target, aggro_range))
        # Keep the authored boss tracking rule intact. Ordinary flyers only
        # follow a visible target inside their territory, so remote/rest targets
        # cannot pull them away from their home pocket while horizontal patrol idles.
        var should_track_target := target != null if is_boss else target_engaged and not returning_home
        if should_track_target and state not in ["windup","active"]:
            desired=clampf(target.global_position.y-90,spawn_position.y-65,spawn_position.y+75)+sin(flight_clock*3)*8
        var candidate := Vector2(global_position.x,move_toward(global_position.y,desired,85*delta))
        var level := get_parent()
        if not level.has_method("_enemy_spawn_rect_clear") or level._enemy_spawn_rect_clear(candidate,24,float(get_meta("spawn_visual_height",60)),String(get_meta("platform_id",""))):
            global_position=candidate
        return
    if state=="active" and String(active_attack.get("type",""))=="vault":
        return
    var terrain: Node = get_parent().get("chapter_terrain")
    if terrain!=null:
        var floor_y: float = terrain.floor_height(global_position.x,spawn_position.y+40,210)
        if is_finite(floor_y):
            global_position.y=floor_y-40

func _effect(effect_kind: String, point: Vector2, vel: Vector2, command: Dictionary, warning: float, lifetime: float) -> Node2D:
    return ENEMY_EFFECTS.effect(self, effect_kind, point, vel, command, warning, lifetime)

func _spawn_command_effects(command: Dictionary, warning: bool) -> void:
    ENEMY_EFFECTS.spawn_command_effects(self, command, warning)

signal died(spawn_id: String, is_boss: bool, kind: String)

const SFX := {
    # 普通敌前摇弃用 player_hook.ogg 复用，改走合成包 windup_light 低配版（升调压量播放）。
    "enemy_windup": "res://assets/audio/sfx/generated/boss_windup_light.ogg",
    "enemy_attack": "res://assets/audio/sfx/enemy_hit.ogg",
    # 自产 SFX 包（tools/generate_sfx_pack.py，project-generated CC0，音频规格 §4.3）。
    "hit_kill": "res://assets/audio/sfx/generated/player_attack_kill.ogg",
    # 受击材质三档（soft/shell/armor）：按敌人死亡材质族分派，替换旧 轻/重 两档。
    "hit_soft": "res://assets/audio/sfx/generated/enemy_hit_soft.ogg",
    "hit_shell": "res://assets/audio/sfx/generated/enemy_hit_shell.ogg",
    "hit_armor": "res://assets/audio/sfx/generated/enemy_hit_armor.ogg",
    "death_moss": "res://assets/audio/sfx/generated/enemy_death_moss.ogg",
    "death_copper": "res://assets/audio/sfx/generated/enemy_death_copper.ogg",
    "death_salt": "res://assets/audio/sfx/generated/enemy_death_salt.ogg",
    "death_fiber": "res://assets/audio/sfx/generated/enemy_death_fiber.ogg",
    "death_obsidian": "res://assets/audio/sfx/generated/enemy_death_obsidian.ogg",
    "death_silent": "res://assets/audio/sfx/generated/enemy_death_silent.ogg",
    "boss_death": "res://assets/audio/sfx/generated/boss_death_slowmo.ogg",
    # Boss 前摇分档（asset_ready 接线）：damage>=2 大招走 lethal 档。
    "boss_windup_light": "res://assets/audio/sfx/generated/boss_windup_light.ogg",
    "boss_windup_lethal": "res://assets/audio/sfx/generated/boss_windup_lethal.ogg",
    # 精英遭遇仪式起手（encounter_role 含 elite 的敌人首次进战）。
    "elite_ritual_start": "res://assets/audio/sfx/generated/elite_ritual_start.ogg",
    # B01 职责提示：伏击现身、报警、支援引导各有专属声音（_role_cue）。
    "role_ambush_reveal": "res://assets/audio/sfx/generated/enemy_ambush_reveal.ogg",
    "role_alarm_call": "res://assets/audio/sfx/generated/enemy_alarm_call.ogg",
    "role_support_mend": "res://assets/audio/sfx/generated/enemy_support_mend.ogg",
    # 章节 beat 叠层（audio_visual_manifest chapter beats）：章节条件按敌人材质
    # （death_sfx_key，main_level 按章节 art theme 写入）或 boss kind 判定。
    "ch02_beat_water_hammer": "res://assets/audio/sfx/generated/ch02_rain_foundry_canal_beat_03_audio.ogg",
    "ch03_beat_contract_break": "res://assets/audio/sfx/generated/ch03_saltwhite_archive_beat_03_audio.ogg",
    "ch05_beat_silent_order": "res://assets/audio/sfx/generated/ch05_obsidian_pilgrim_road_beat_02_audio.ogg",
    "ch06_beat_crown_resonance": "res://assets/audio/sfx/generated/ch06_silent_crown_core_beat_02_audio.ogg",
    "ch03_beat_delayed_shadow": "res://assets/audio/sfx/generated/ch03_saltwhite_archive_beat_01_audio.ogg",
    "ch05_beat_parade": "res://assets/audio/sfx/generated/ch05_obsidian_pilgrim_road_beat_03_audio.ogg"
}
## Boss 四件套（roar/phase_shift/atk_light/atk_heavy）按 boss kind → 章节短号取合成包音源。
const BOSS_SFX_CHAPTER := {
    "rust_crown_guardian": "ch01",
    "sunken_hammer_smith": "ch02",
    "saltwhite_contract_judge": "ch03",
    "broken_string_gardener": "ch04",
    "silent_pilgrim_commander": "ch05",
    "silent_crown_core": "ch06"
}
## 材质族 → 受击档（音频规格 §4.3）：苔/藤=软质、盐/寂=甲壳、铜/曜=重甲。
const HIT_TIER_BY_MATERIAL := {
    "death_moss": "hit_soft",
    "death_fiber": "hit_soft",
    "death_salt": "hit_shell",
    "death_silent": "hit_shell",
    "death_copper": "hit_armor",
    "death_obsidian": "hit_armor"
}
## AudioDirector 声部契约（并行实现于 scripts/audio_director.gd）：脚本缺席时放行。
const AUDIO_DIRECTOR_PATH := "res://scripts/audio_director.gd"
static var audio_director_script: GDScript = null
const HIT_FLASH_SHADER := preload("res://shaders/hit_flash.gdshader")
## 命中瞬间全身白闪：50ms 保持，随后 70ms 连续淡出。
const FLASH_TOTAL_TIME := 0.12
const FLASH_HALF_TIME := 0.07
## 击退指数衰减时间常数（规格 §3.2）。
const KNOCKBACK_TAU := 0.09

@export var spawn_id: String = ""
@export var kind: String = "moss_larva"
@export var patrol_distance: float = 90.0
@export var speed: float = 42.0
@export var hp: int = 2
@export var damage: int = 1
@export var is_boss: bool = false
@export var asset_path: String = ""
@export var leash_radius: float = 240.0
## 死亡材质音（音频规格 §4.3 六材质）：main_level 按章节 art theme 写入
## death_moss/copper/salt/fiber/obsidian/silent 之一。
@export var death_sfx_key: String = "death_moss"
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
## Box swept against terrain when an attack moves the actor. It keeps the
## configured footprint even when the hit box is fitted to the drawn body.
var motion_box_size := Vector2.ZERO
var motion_box_offset := Vector2.ZERO
var hurtbox_authored := false

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
var flash_started_process_frame: int = -1
var contact_timer: float = 0.0
var state_timer: float = 0.0
var attack_has_hit := false
var ai_profile: Dictionary = {}
var boss_brain: Node
var attack_execution_serial := 0
var attack_completed_serial := -1
var ai_commands: Array = []
var cooldowns: Dictionary = {}
var active_attack: Dictionary = {}
var state := "patrol"
var attack_desire: float = 0.0
## The commander's parade footfalls under its charge windup; cut when it ends.
var parade_voice: Node = null
var last_player_command := "none"
var last_ai_decision := "patrol"
var last_attack_id := ""
# Regular-enemy decision making. Seeded per spawn so prebuilt neighbours and
# live actors stay in step; bosses keep their tactical layer.
const MAX_SIMULTANEOUS_ATTACKERS := 2
const ATTACKER_COORDINATION_RADIUS := 560.0
const TARGET_MEMORY_SECONDS := 2.4
## B01 species roles (original_creature_combat.json tactical_role). Most roles
## keep the shared decision layer; ambush, alarm and guard change who engages,
## who is told and where a lost target is searched for.
const TACTICAL_ROLES := ["patrol", "ambush", "guard", "ranged", "aerial", "alarm", "support", "boss"]
const AMBUSH_TRIGGER_RANGE := 150.0
const ALARM_RADIUS := 420.0
const ALARM_COOLDOWN := 8.0
const SUPPORT_RADIUS := 260.0
const SUPPORT_WINDUP := 0.9
const SUPPORT_COOLDOWN := 8.0
var support_cooldown := 0.0
## A revealed ambusher holds this long before moving or striking.
const AMBUSH_REVEAL_HOLD := 0.35
var reveal_hold := 0.0
## Waiting at a post or lurking is not combat; the music layer reads this.
const CALM_DECISIONS := ["patrol", "return", "lurk", "hold_post", "return_post"]
## Role cues raised by this actor (diagnostic; audio is skipped headless).
var role_cue_counts := {}
var support_target: WeakRef
const ATTACK_ROLES := {
    "anti_air": ["nova", "fan", "projectile", "mortar"],
    "counter": ["guard", "retreat", "feint", "blink", "melee", "combo"],
    "punish": ["lunge", "dive", "vault", "wave", "rootline", "pool", "combo"],
    "gap_closer": ["lunge", "dive", "vault", "projectile", "fan", "mortar", "blink", "beam"],
    "area": ["wave", "rootline", "pool", "nova"],
}
var ai_rng := RandomNumberGenerator.new()
var combat_audio_rng := RandomNumberGenerator.new()
var combat_audio_last_variant: Dictionary = {}
var completed_attack_count := 0
var ai_clock := 0.0
var attack_repeat_count := 0
var waiting_for_turn := false
var last_seen_position := Vector2.ZERO
var memory_timer := 0.0
var tactical_role := "patrol"
var alarm_cooldown := 0.0
## Searching a point another actor called out; already clamped to this territory.
var alarm_search := false
## Allies told by this actor's most recent alarm (diagnostic, not gameplay).
var alarm_alerted := 0
var patrol_direction := 1
var patrol_pause_timer := 0.0
var recent_hit_times: Array[float] = []
var poise_timer := 0.0
var poise_cooldown := 0.0
var backstep_cooldown := 0.0
var command_read_count := 0
var boss_tactic := "observe"
var boss_tactic_timer := 0.0
var boss_press_timer := 0.0
var boss_reposition_target_x := 0.0
var sprite: Node2D
var animated_sprite: AnimatedSprite2D
var frame_fit: Dictionary = {}
var frame_fit_scale := 1.0
var frame_fit_pivot := Vector2.ZERO
## Wing beat of redrawn hover loops (data/creature_wing_flap.json), drawn by the
## sprite shader. Keyed by animation; empty for every other creature.
const WING_FLAP_PATH := "res://data/creature_wing_flap.json"
var wing_flap: Dictionary = {}
var wing_flap_active := false
var wing_flap_phase := 0.0
var telegraph: Polygon2D
var telegraph_tween: Tween
var windup_vfx: Line2D
var windup_vfx_tween: Tween
var requested_sprite_flip := false
var current_animation_has_explicit_direction := false
# A held wind-up (charge) or travelling strike (travel) switches from its
# one-shot cels to an authored loop once the one-shot has been shown; a
# recovery bridge hands over to the shared recovery (or idle) the same way.
const POSE_LOOP_LEAD := {"windup": 0.42, "active": 0.2, "recover": 0.18}
var pose_loop_animation := ""
var pose_loop_at := 0.0
## A follow-up that is not a loop (a bridge's shared recovery) is fitted to the
## time left in the state instead of playing at its own speed.
var pose_loop_fit := 0.0
const POSE_TIMING := preload("res://scripts/enemy_animation_timing.gd")
var pose_loop_role := ""
var pose_holding_charge := false
var pose_travel_stretch := false
var pose_visual_clock := 0.0
var pose_owned_frames: SpriteFrames
var pose_source_frames: SpriteFrames
var pose_feedback_time := 0.0
var pose_feedback_duration := 0.10
var pose_feedback_was_active := false
var flash_materials: Array = []
var knockback_velocity := 0.0
var dying := false
## 遭遇编制角色（generated 章节配置 enemy_spawns.encounter_role，如 elite_duo/preboss_elite；
## 手工章节无此字段 → 空串天然静默）。
var encounter_role := ""
# Elite spawns use the species' "elite" profile: more health, +damage on every
# attack, a slightly larger silhouette and an extra signature attack.
var is_elite := false
## 首次进战宣告一次性标记（Boss 开场吼 / 精英仪式起手）。
var engage_announced := false
## Boss 半血相变音一次性标记（纯音频钩子，无 HP 阶段行为机）。
var boss_phase_shift_played := false


var presentation_prepared := false

func prepare_presentation() -> void:
    if presentation_prepared: return
    _build_shape()
    _build_sprite()
    _fit_hurtbox_to_art()
    if is_boss: boss_skill_texture = BOSS_SKILL_ART.texture_for(kind)
    MINOR_SKILL_ART.prepare(self)
    presentation_prepared = true

func _ready() -> void:
    physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
    add_to_group("enemy")
    if locomotion == "flight":
        global_position.y -= hover_height
    start_x = global_position.x
    spawn_position = global_position
    monitoring = true
    monitorable = true
    body_entered.connect(_on_body_entered)
    prepare_presentation()
    reset_physics_interpolation()
    _ensure_boss_brain()


func _ensure_boss_brain() -> void:
    if boss_brain != null or not _boss_behavior_enabled():return
    boss_brain = preload("res://scripts/boss_behavior_brain.gd").new()
    boss_brain.name = "BossBehaviorBrain"
    add_child(boss_brain)
    boss_brain.setup(self)

func _boss_behavior_enabled() -> bool:
    if not is_boss or not bool(ai_profile.get("tactical_ai",true)):return false
    if not BOSS_STYLE.catalog.bosses.has(kind):return false
    for command in ai_commands:
        if not String(command.get("boss_pattern", "")).is_empty():return true
    return false


func _physics_process(delta: float) -> void:
    var previous_position := global_position
    var previous_state := state
    _step_enemy(delta)
    if dying or is_queued_for_deletion() or combat_visuals_paused or not world_residency_active():
        if not world_residency_active():motion_transitions.suspend(self)
        return
    _advance_wing_flap(delta)
    _update_animation_motion(delta, previous_position, previous_state)
    motion_transitions.tick(self,global_position-previous_position,previous_state)

func _step_enemy(delta: float) -> void:
    # An interrupted or retired charge never leaves its footfalls running.
    if parade_voice != null and state != "windup":
        _stop_parade_layer()
    if dying or is_queued_for_deletion():
        return
    if not world_residency_active():
        if state == "support": _finish_support()
        return
    # UI pause must not depend on lure/interference target selection.
    var player_node := get_tree().get_first_node_in_group("player")
    var ui_locked: bool = player_node != null and (player_node.get("ui_input_locked") == true)
    _set_combat_visuals_paused(ui_locked)
    if ui_locked:
        return
    var movement_start:=global_position
    if is_boss and battle_phase == 1 and hp <= max_hp * float(ai_profile.get("phase_threshold",0.55)):
        if boss_brain != null:boss_brain.reset_plan()
        battle_phase = 2
        phase_pause = 0.9
        _cancel_attack_effects()
        _clear_telegraph()
        state = "patrol"
        active_attack = {}
        attack_recovery=false
        recovery_velocity_x=0.0
        pose_loop_animation = ""
        _set_enemy_animation("phase", true)
        _fit_animation_duration(phase_pause)
        BOSS_SKILL_ART.spawn_phase(self)
        if get_parent().has_method("_toast"):
            get_parent()._toast(String(ai_profile.get("phase_name","第二阶段")))
    if phase_pause>0:
        _tick_hit_flash(delta)
        phase_pause-=delta
        return
    _tick_timers(delta)
    var target := _target_player()
    BOSS_STYLE.remember(self,delta,target)
    if target != null and not _is_attack_state() and _is_aware_of(target):
        _face_target(target)
    if target != null:
        last_player_command = _read_player_command(target)
    else:
        last_player_command = "none"

    if boss_brain != null and _boss_behavior_enabled():boss_brain.observe(delta,target)
    if state == "support":
        _update_support(delta, target)
    elif state == "windup":
        _update_windup(delta)
    elif state == "active":
        _update_active(delta)
    elif state == "recover":
        _update_recover(delta)
    else:
        _update_patrol_or_aggro(delta, target)
    if not dying and not is_queued_for_deletion():
        _update_locomotion(delta,target)
        _sync_walk_cadence(delta,movement_start)


func _update_animation_motion(delta: float, previous_position: Vector2, previous_state: String) -> void:
    if not original_visual or sprite == null or animated_sprite == null or not is_finite(delta) or delta <= 0:
        return
    pose_visual_clock += delta
    var motion := global_position - previous_position
    var animation := String(animated_sprite.animation).trim_suffix("_left").trim_suffix("_right")
    # Ground walk cadence is owned by _sync_walk_cadence; pose feedback must
    # not replace its slower footwork rate after the actor has moved.
    if animation in ["walk", "move"] and state == "patrol" and (locomotion != "ground" or animation == "move"):
        var rate := motion.length() / delta if locomotion == "flight" else absf(motion.x) / delta
        if rate < .1 and locomotion != "flight":
            animated_sprite.pause()
        else:
            animated_sprite.speed_scale = clampf(rate / maxf(speed, .01), .6, 1.4)
            if not animated_sprite.is_playing(): animated_sprite.play()
    # Authored poses supply the movement. Runtime squash/stretch made a hit
    # restore a differently scaled sprite in one frame and looked like a pop.
    sprite.position = sprite_base_position
    sprite.scale = sprite_base_scale
    sprite.rotation = 0.0
    pose_feedback_time = 0.0
    pose_feedback_was_active = false


func configure(data: Dictionary, sprite_path: String, boss_flag: bool = false, profile: Dictionary = {}) -> void:
    spawn_id = String(data.get("id", "enemy"))
    kind = String(data.get("kind", "moss_larva"))
    ai_rng.seed = hash(spawn_id + ":" + kind)
    combat_audio_rng.seed = hash(spawn_id + ":sound:" + kind)
    hp = int(data.get("hp", 2))
    max_hp = hp
    damage = int(data.get("damage", 1))
    patrol_distance = float(data.get("patrol", 80.0))
    is_boss = boss_flag
    encounter_role = String(data.get("encounter_role", ""))
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
    combat_resistance = data.get("combat_resistance", {"trip_immune": is_boss, "lure_immune": is_boss, "snare_mult": 0.35 if is_boss else 1.0})
    ai_profile = profile.duplicate(true)
    var original_profile: Dictionary = ORIGINAL_ART.manifest("res://data/original_creature_combat.json").get(kind,{})
    if not original_profile.is_empty():
        ai_profile.merge(original_profile,true)
    # Room pacing is an explicit spawn override, after the species identity.
    # Tree-out prefabs and live actors use the same configure contract.
    var encounter_profile: Variant = data.get("encounter_profile", {})
    if encounter_profile is Dictionary:
        ai_profile.merge(encounter_profile, true)
    if is_boss:ai_profile=BOSS_STYLE.apply(kind,ai_profile)
    locomotion = String(ai_profile.get("locomotion",data.get("locomotion","ground")))
    hover_height = float(ai_profile.get("hover_height",95)) if locomotion=="flight" else 0.0
    speed = float(ai_profile.get("move_speed",speed))
    var original_path := ORIGINAL_ART.character_manifest("original_creatures", kind)
    var art_data := ORIGINAL_ART.manifest(original_path)
    if not art_data.is_empty():
        asset_path=original_path
        sprite_parts=[]
        sprite_region=[]
        sprite_regions={}
        visual_scale=float(art_data.get("visual_scale",1))
        visual_offset=_vec2(art_data.get("visual_offset",[0,0]))
        visual_modulate=Color.WHITE
        sprite_faces_left=false
        original_visual=true
        authored_combat_sequences=art_data.get("authored_combat_sequences",[])
        var h := float(art_data.get("display_height",90))
        if not data.has("hurtbox_offset"):
            hurtbox_offset=Vector2(0,40-h*.5)
        if not data.has("body_size"):
            body_size=Vector2(98 if is_boss else 35,h*.72)
        if not data.has("hurtbox_size"):
            hurtbox_size=Vector2(125 if is_boss else 48,h*.84)
    hurtbox_authored = data.has("hurtbox_size") or data.has("hurtbox_offset")
    ai_profile["lure_eligible"] = bool(data.get("lure_eligible", ai_profile.get("lure_eligible", not is_boss and locomotion != "stationary")))
    is_elite = bool(data.get("elite", false)) and not is_boss and ai_profile.get("elite") is Dictionary
    if is_elite:
        _apply_elite_profile(ai_profile.elite)
    ai_commands = ai_profile.get("attacks", [])
    for command in ai_commands:
        cooldowns[String(command.get("id", "attack"))] = float(command.get("start_cooldown", 0.0))
    tactical_role = "boss" if is_boss else String(ai_profile.get("tactical_role", "patrol"))
    if not TACTICAL_ROLES.has(tactical_role): tactical_role = "patrol"


func _apply_elite_profile(elite: Dictionary) -> void:
    hp = maxi(hp + 1, ceili(float(hp) * float(elite.get("hp_mult", 1.75))))
    max_hp = hp
    var bonus := int(elite.get("damage_bonus", 1))
    damage += bonus
    var attacks: Array = []
    for command: Dictionary in ai_profile.get("attacks", []):
        var boosted := command.duplicate(true)
        boosted["damage"] = int(boosted.get("damage", 1)) + bonus
        attacks.append(boosted)
    for command: Dictionary in elite.get("attacks", []):
        attacks.append(command.duplicate(true))
    ai_profile["attacks"] = attacks
    if visual_scale > 0.0:
        visual_scale *= float(elite.get("visual_scale_mult", 1.0))


func contact_visual_call_serial() -> int:
    return int(get_meta(CONTACT_ART.CALL_META, 0))


func take_hit(amount: int, hit_direction: int) -> void:
    var contact_call := CONTACT_ART.begin_receiver_call(self)
    if dying or is_queued_for_deletion() or not world_residency_active() or amount <= 0:
        return
    if bool(ai_profile.get("front_guard",false)) and String(active_attack.get("type",""))=="guard" and state in ["windup","active"] and hit_direction==-direction:
        attack_desire+=.6
        _play_attack_sfx("windup")
        return
    # 受击分档（音频规格 §4.3）：致命一击独立，其余按敌人材质族走 soft/shell/armor 三档。
    if hp - amount <= 0:
        _play_sfx("hit_kill", -5.0, 1.0, 0)
    else:
        _play_sfx(_hit_tier_key(), -6.0)
    _spawn_hit_spark(hit_direction, contact_call)
    var armored := hp - amount > 0 and ((not is_boss and _hit_is_armored()) or (is_boss and _is_attack_state()))
    if not armored:
        pose_loop_animation = ""
        # A hit overlays the pose already on screen. Swapping to an unrelated
        # hurt cel at the white-flash boundary caused a visible size jump.
        if not original_visual:
            _set_enemy_animation("hurt")
            _pose_sprite("hurt")
    hp -= amount
    if is_boss and not boss_phase_shift_played and hp > 0 and hp * 2 <= max_hp:
        # Boss 半血相变音（音频规格 §4.4）：纯音频钩子，不改战术行为机；
        # 正式 HP 阶段系统落地后迁移到相变处（终 Boss 走 director 三乐章）。
        boss_phase_shift_played = true
        _play_sfx(_boss_sfx_key("phase_shift"), -5.0, 1.0, 0)
        # ch6 beat `crown_resonance`（manifest ch06_beat_02）：线之冠核心相变时
        # 三线绷响+低频脉冲叠层（D–A–B♭ 动机）。
        if kind == "silent_crown_core":
            _play_sfx("ch06_beat_crown_resonance", -7.0)
    var base_speed := 140.0 if is_boss else (460.0 if amount >= 2 else 320.0)
    knockback_velocity = float(hit_direction) * base_speed * (1.4 if hp <= 0 else 1.0)
    _set_flash_amount(1.0)
    flash_timer = FLASH_TOTAL_TIME
    flash_started_process_frame = Engine.get_process_frames()
    if _boss_tactical_enabled() and hp > 0:
        boss_tactic = "evade"
        boss_tactic_timer = float(ai_profile.get("hurt_evade_time", 0.42))
        boss_press_timer = 0.0
    if not is_boss and hp > 0:
        _react_to_hit(hit_direction)
    if hp <= 0:
        _begin_death_dissolve()


func _hit_is_armored() -> bool:
    # Poise: after being chained, the next attack shrugs off interruption.
    # Elites keep poise through every strike once it has begun.
    return (poise_timer > 0.0 and state in ["windup", "active"]) or (is_elite and state == "active")


func _react_to_hit(hit_direction: int) -> void:
    recent_hit_times.append(ai_clock)
    while not recent_hit_times.is_empty() and ai_clock - recent_hit_times[0] > 1.4:
        recent_hit_times.pop_front()
    var target := _target_player()
    if target != null:
        last_seen_position = target.global_position
        memory_timer = TARGET_MEMORY_SECONDS
    attack_desire += 0.25
    if _hit_is_armored():
        knockback_velocity *= 0.35
        return
    _cancel_unarmed_attack_effects()
    attack_recovery=false
    recovery_velocity_x=0.0
    active_attack = {}
    pose_loop_animation = ""
    state = "recover"
    state_timer = 0.16
    if not original_visual:_fit_animation_duration(state_timer)
    _clear_telegraph()
    if recent_hit_times.size() >= 3 and poise_cooldown <= 0.0:
        poise_timer = 1.8
        poise_cooldown = 4.5
        attack_desire = maxf(attack_desire, _attack_desire_threshold())
    # Close-range ground fighters hop clear of a combo instead of eating it.
    var close_fighter := locomotion == "ground" and float(ai_profile.get("preferred_range", 54.0)) < 120.0
    if close_fighter and recent_hit_times.size() >= 2 and backstep_cooldown <= 0.0:
        knockback_velocity = float(hit_direction) * 560.0
        backstep_cooldown = 3.0


## 死亡溶解（规格 §3.4 简化通用版）：died 当帧发出、立即离开 enemy 组，
## 之后表现层溶解 0.45s（Boss 0.9s）再 queue_free——计数/掉落逻辑不受影响。
func _begin_death_dissolve() -> void:
    if dying or is_queued_for_deletion():
        return
    dying = true
    if boss_brain != null:boss_brain.reset_plan()
    active_attack = {}
    state = "dead"
    _cancel_attack_effects()
    # Death may be triggered by an Area callback during physics flushing.
    set_deferred("monitoring", false)
    set_deferred("monitorable", false)
    remove_from_group("enemy")
    knockback_velocity = 0.0
    # 材质化死亡音（音频规格 §4.3）：挂到父节点播放，避免溶解 queue_free 截断尾音。
    _play_detached_sfx("boss_death" if is_boss else death_sfx_key, -4.0 if is_boss else -6.0)
    # ch3 beat `contract_break`（manifest ch03_beat_03）：盐白契约判官死亡时
    # 契约碎页散开——纸页撕裂与低频钟声叠层（同走独立宿主避免截断）。
    if is_boss and kind == "saltwhite_contract_judge":
        _play_detached_sfx("ch03_beat_contract_break", -8.0)
    pose_loop_animation = ""
    _set_enemy_animation("death")
    _pose_sprite("death")
    _clear_telegraph()
    died.emit(spawn_id, is_boss, kind)
    if is_queued_for_deletion():
        return
    if sprite == null or not is_instance_valid(sprite):
        queue_free()
        return
    var duration := 0.9 if is_boss else 0.45
    _fit_animation_duration(duration)
    var tween := create_tween()
    tween.tween_interval(0.05)
    tween.tween_callback(func() -> void: _set_flash_amount(0.0))
    tween.tween_property(sprite, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    tween.parallel().tween_property(sprite, "position:y", sprite.position.y + 14.0, duration)
    tween.finished.connect(Callable(self, "queue_free"))


## C01: field enemies were hittable only through a fixed 48px-wide box while
## their drawn bodies are 70-180px wide, so swings at a visible flank missed.
## Fit the hit box to the drawn idle body (core 62% of its width, centred on it
## vertically); authored boxes, Bosses and contact damage are unchanged.
func _fit_hurtbox_to_art() -> void:
    motion_box_size = hurtbox_size
    motion_box_offset = hurtbox_offset
    if is_boss or hurtbox_authored or not original_visual or not is_instance_valid(animated_sprite):
        return
    var frames := animated_sprite.sprite_frames
    var animation := &"idle" if frames != null and frames.has_animation(&"idle") else animated_sprite.animation
    var count := frames.get_frame_count(animation) if frames != null and frames.has_animation(animation) else 0
    var width := 0.0
    var height := 0.0
    var core := Rect2()
    var measured := 0
    for index in count:
        var drawn := _drawn_body_rect(animation, index)
        if drawn.has_area():
            width += drawn.size.x
            height += drawn.size.y
            core = drawn if measured == 0 else core.intersection(drawn)
            measured += 1
    if measured == 0 or not core.has_area():
        return
    # Keep the fixed box inside every idle pose, including the smallest one.
    # Averaging alone put part of it in the air as bees/lancers changed pose.
    hurtbox_size = Vector2(clampf(maxf(hurtbox_size.x, minf(width / measured * 0.62, core.size.x)), 40.0, 160.0), minf(height / measured * 0.84, core.size.y))
    hurtbox_offset = core.get_center()


## Opaque part of one animation frame in this actor's local space.
func _drawn_body_rect(animation: StringName, index: int) -> Rect2:
    var frames := animated_sprite.sprite_frames
    if frames == null or not frames.has_animation(animation):
        return Rect2()
    var texture := frames.get_frame_texture(animation, index)
    if texture == null:
        return Rect2()
    var size := texture.get_size()
    var inner := Rect2(Vector2.ZERO, size)
    if texture is AtlasTexture:
        inner = Rect2(texture.margin.position, texture.region.size)
    var origin := (-size * 0.5 if animated_sprite.centered else Vector2.ZERO) + animated_sprite.offset
    var a := animated_sprite.transform * (origin + inner.position)
    var b := animated_sprite.transform * (origin + inner.end)
    return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())


func get_motion_rect() -> Rect2:
    var size := motion_box_size if motion_box_size != Vector2.ZERO else (hurtbox_size if hurtbox_size != Vector2.ZERO else (Vector2(142, 144) if is_boss else Vector2(58, 56)))
    var offset := motion_box_offset if motion_box_size != Vector2.ZERO else hurtbox_offset
    var center := global_position + (offset if offset != Vector2.ZERO else (Vector2(0.0, -40.0) if is_boss else Vector2(0.0, -18.0)))
    return Rect2(center - size * 0.5, size)


func get_hurtbox_rect() -> Rect2:
    var size := hurtbox_size if hurtbox_size != Vector2.ZERO else (Vector2(142, 144) if is_boss else Vector2(58, 56))
    var center := global_position + (hurtbox_offset if hurtbox_offset != Vector2.ZERO else (Vector2(0.0, -40.0) if is_boss else Vector2(0.0, -18.0)))
    return Rect2(center - size * 0.5, size)


func get_ai_debug_state() -> Dictionary:
    return {
        "behavior_tree": boss_brain.debug_state() if boss_brain != null else {},
        "ai_command_total": ai_commands.size(),
        "attack_desire": attack_desire,
        "attack_desire_threshold": _attack_desire_threshold(),
        "last_player_command": last_player_command,
        "last_ai_decision": last_ai_decision,
        "tactical_role": tactical_role,
        "alarm_alerted": alarm_alerted,
        "support_cooldown": support_cooldown,
        "last_attack_id": last_attack_id,
        "reads_player_commands": true,
        "command_read_count": command_read_count,
        "aggro_vertical_tolerance": float(ai_profile.get("aggro_vertical_tolerance", 190.0 if is_boss else 118.0)),
        "attack_vertical_tolerance": float(ai_profile.get("attack_vertical_tolerance", 132.0 if is_boss else 72.0)),
        "max_attack_range": _max_attack_range(false),
        "tactical_ai": _boss_tactical_enabled(),
        "boss_tactic": boss_tactic,
        "boss_tactic_timer": boss_tactic_timer,
        "boss_press_timer": boss_press_timer,
        "boss_reposition_target_x": boss_reposition_target_x
    }


func _tick_timers(delta: float) -> void:
    snare_timer = maxf(0.0, snare_timer - delta)
    salt_mark_timer = maxf(0.0, salt_mark_timer - delta)
    interference_timer = maxf(0.0, interference_timer - delta)
    lure_timer = maxf(0.0, lure_timer - delta)
    trip_timer = maxf(0.0, trip_timer - delta)
    contact_timer = maxf(0.0, contact_timer - delta)
    ai_clock += delta
    memory_timer = maxf(0.0, memory_timer - delta)
    alarm_cooldown = maxf(0.0, alarm_cooldown - delta)
    support_cooldown = maxf(0.0, support_cooldown - delta)
    reveal_hold = maxf(0.0, reveal_hold - delta)
    poise_timer = maxf(0.0, poise_timer - delta)
    poise_cooldown = maxf(0.0, poise_cooldown - delta)
    backstep_cooldown = maxf(0.0, backstep_cooldown - delta)
    patrol_pause_timer = maxf(0.0, patrol_pause_timer - delta)
    _tick_hit_flash(delta)
    if absf(knockback_velocity) > 0.0:
        var decay := exp(-maxf(0.0,delta)/KNOCKBACK_TAU)
        var start := global_position
        var finish := start+Vector2(knockback_velocity*KNOCKBACK_TAU*(1.0-decay),0)
        global_position = preload("res://scripts/enemy_motion_sweep.gd").constrain(self,start,finish) if is_inside_tree() else finish
        knockback_velocity = 0.0 if absf(global_position.x-finish.x)>.01 else knockback_velocity*decay
        if absf(knockback_velocity) < 8.0:
            knockback_velocity = 0.0
        _clamp_movement_bounds()
    for key in cooldowns.keys():
        cooldowns[key] = maxf(0.0, float(cooldowns[key]) - delta)
    if boss_tactic_timer > 0.0:
        boss_tactic_timer = maxf(0.0, boss_tactic_timer - delta)


func _tick_hit_flash(delta: float) -> void:
    if flash_timer > 0.0:
        # Physics catch-up may run several times before the next presentation.
        # Do not consume a new hit's entire flash before it can be drawn.
        if Engine.get_process_frames() > flash_started_process_frame:
            flash_timer = maxf(0.0,flash_timer-delta)
        if flash_timer <= 0.0:
            _set_flash_amount(0.0)
        else:
            _set_flash_amount(1.0 if flash_timer > FLASH_HALF_TIME else flash_timer/FLASH_HALF_TIME)


func _set_flash_amount(amount: float) -> void:
    for material_value in flash_materials:
        var material := material_value as ShaderMaterial
        if material != null:
            material.set_shader_parameter("flash_amount", amount)


func _is_attack_state() -> bool:
    return state in ["windup", "active", "recover", "support"]


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
    platform_min_x = min_x-100 if locomotion=="flight" else min_x
    platform_max_x = max_x+100 if locomotion=="flight" else max_x


func reset_for_respawn() -> void:
    if dying or is_queued_for_deletion():
        return
    if boss_brain != null:boss_brain.reset_plan()
    attack_execution_serial += 1
    attack_completed_serial = -1
    CONTACT_ART.clear_receiver(self)
    _cancel_attack_effects()
    _clear_telegraph()
    for tween in combat_tweens:
        if is_instance_valid(tween) and tween.is_valid():
            tween.kill()
    combat_tweens.clear()
    for child in get_children():
        if (child is Line2D and String(child.name).begins_with("OriginalAttack")) or child.name in ["EnemyWindupVfx", "BossAttackBurstVfx", "EnemyAttackBurstVfx", "HitSpark"]:
            child.queue_free()
    battle_phase = 1
    phase_pause = 0.0
    attack_elapsed = 0.0
    attack_recovery=false
    recovery_velocity_x=0.0
    completed_attack_count=0
    boss_target_history.clear()
    boss_attack_history.clear()
    boss_history_clock=0.0
    combo_visual_stage=""
    trail_clock = 0.0
    cooldowns.clear()
    for command in ai_commands:
        cooldowns[String(command.get("id", "attack"))] = float(command.get("start_cooldown", 0.0))
    hp = max_hp
    knockback_velocity = 0.0
    _set_flash_amount(0.0)
    global_position = spawn_position
    reset_physics_interpolation()
    direction = 1
    attack_direction = 1
    attack_has_hit = false
    active_attack = {}
    state = "patrol"
    attack_desire = 0.0
    snare_timer = 0.0
    clear_salt_mark()
    interference_timer = 0.0
    lure_timer = 0.0
    trip_timer = 0.0
    last_player_command = "none"
    last_ai_decision = "patrol"
    last_attack_id = ""
    boss_tactic = "observe"
    boss_tactic_timer = 0.0
    boss_press_timer = 0.0
    boss_reposition_target_x = spawn_position.x
    engage_announced = false
    boss_phase_shift_played = false
    memory_timer = 0.0
    alarm_cooldown = 0.0
    alarm_alerted = 0
    alarm_search = false
    support_cooldown = 0.0
    reveal_hold = 0.0
    role_cue_counts.clear()
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
    return ENEMY_ENGAGEMENT.target_player(self)


func _face_target(target: Node2D) -> void:
    ENEMY_ENGAGEMENT.face_target(self, target)


func _has_line_of_sight(target: CollisionObject2D) -> bool:
    return ENEMY_ENGAGEMENT.has_line_of_sight(self, target)


func apply_snare(seconds: float) -> void:
    ENEMY_ENGAGEMENT.apply_snare(self, seconds)


func _movement_speed() -> float:
    return ENEMY_ENGAGEMENT.movement_speed(self)


func _update_patrol_or_aggro(delta: float, target: CharacterBody2D) -> void:
    ENEMY_ENGAGEMENT.update_patrol_or_aggro(self, delta, target)


## An ambusher reveals itself only once the player is close; after that, and
## for every role while tracking, the species' ordinary aggro range applies.
func _fresh_engage_range(aggro_range: float) -> float:
    return ENEMY_ENGAGEMENT.fresh_engage_range(self, aggro_range)


## Ambushers and guards wait at their spawn instead of patrolling or searching.
func _return_to_post(delta: float, waiting_decision: String) -> void:
    ENEMY_ENGAGEMENT.return_to_post(self, delta, waiting_decision)


## Bells, horns and banners tell nearby idle allies where the player was seen.
## Allies still need their own line of sight to engage and keep their leash.
func _raise_alarm(target: CharacterBody2D) -> void:
    ENEMY_ENGAGEMENT.raise_alarm(self, target)


func hear_alarm(seen_at: Vector2) -> bool:
    return ENEMY_ENGAGEMENT.hear_alarm(self, seen_at)


## A flag bearer can mend one wounded ally while it sees the player. It keeps
## its ordinary attacks when alone; support never heals a boss or another
## supporter. A weak target and release-time checks prevent delayed cross-room
## healing, resurrection and keeping retired actors alive.
func _can_receive_support() -> bool:
    return ENEMY_ENGAGEMENT.can_receive_support(self)


func _support_ally_valid(ally: Area2D) -> bool:
    return ENEMY_ENGAGEMENT.support_ally_valid(self, ally)


func _try_start_support() -> bool:
    return ENEMY_ENGAGEMENT.try_start_support(self)


func _update_support_link(ally: Area2D) -> void:
    ENEMY_ENGAGEMENT.update_support_link(self, ally)


func _update_support(delta: float, target: CharacterBody2D) -> void:
    ENEMY_ENGAGEMENT.update_support(self, delta, target)


func _finish_support() -> void:
    ENEMY_ENGAGEMENT.finish_support(self)


func _investigate(delta: float) -> void:
    ENEMY_ENGAGEMENT.investigate(self, delta)


func _move_in_combat(delta: float, target: CharacterBody2D) -> void:
    ENEMY_ENGAGEMENT.move_in_combat(self, delta, target)


func _ally_queue_offset(target: CharacterBody2D) -> float:
    return ENEMY_ENGAGEMENT.ally_queue_offset(self, target)


func _boss_tactical_enabled() -> bool:
    return BOSS_TACTICS.boss_tactical_enabled(self)


func _move_boss_tactical(delta: float, target: CharacterBody2D) -> void:
    BOSS_TACTICS.move_boss_tactical(self, delta, target)


func _prepare_boss_tactic(target: CharacterBody2D, distance: float = -1.0) -> void:
    BOSS_TACTICS.prepare_boss_tactic(self, target, distance)


func _boss_tactic_finished(target: CharacterBody2D, distance: float) -> bool:
    return BOSS_TACTICS.boss_tactic_finished(self, target, distance)


func _choose_boss_tactic(target: CharacterBody2D, distance: float) -> void:
    BOSS_TACTICS.choose_boss_tactic(self, target, distance)


func _set_boss_tactic(next_tactic: String, duration: float, target: CharacterBody2D) -> void:
    BOSS_TACTICS.set_boss_tactic(self, next_tactic, duration, target)


func _boss_tactic_duration(tactic: String, fallback: float) -> float:
    return BOSS_TACTICS.boss_tactic_duration(self, tactic, fallback)


func _boss_should_evade_player_command(pressure: float) -> bool:
    return BOSS_TACTICS.boss_should_evade_player_command(self, pressure)


func _boss_should_reposition(target: CharacterBody2D, distance: float) -> bool:
    return BOSS_TACTICS.boss_should_reposition(self, target, distance)


func _boss_spacing_direction(distance: float, dx: float) -> float:
    return BOSS_TACTICS.boss_spacing_direction(self, distance, dx)


func _boss_reposition_x(target: CharacterBody2D) -> float:
    return BOSS_TACTICS.boss_reposition_x(self, target)


func _boss_has_arena_bounds() -> bool:
    return BOSS_TACTICS.boss_has_arena_bounds(self)


func _boss_min_x() -> float:
    return BOSS_TACTICS.boss_min_x(self)


func _boss_max_x() -> float:
    return BOSS_TACTICS.boss_max_x(self)


func _boss_at_arena_edge() -> bool:
    return BOSS_TACTICS.boss_at_arena_edge(self)


func _patrol(delta: float) -> void:
    ENEMY_ATTACK_CHOICE.patrol(self, delta)


func _target_inside_leash(target: CharacterBody2D) -> bool:
    return ENEMY_ATTACK_CHOICE.target_inside_leash(self, target)


func _should_return_to_spawn(target: CharacterBody2D, aggro_range: float) -> bool:
    return ENEMY_ATTACK_CHOICE.should_return_to_spawn(self, target, aggro_range)


func _return_to_spawn(delta: float) -> void:
    ENEMY_ATTACK_CHOICE.return_to_spawn(self, delta)


func _target_in_engage_window(target: CharacterBody2D, aggro_range: float) -> bool:
    return ENEMY_ATTACK_CHOICE.target_in_engage_window(self, target, aggro_range)


func _target_in_any_attack_window(target: CharacterBody2D) -> bool:
    return ENEMY_ATTACK_CHOICE.target_in_any_attack_window(self, target)


func _attack_can_reach_target(command: Dictionary, target: CharacterBody2D, ignore_cooldown: bool = false) -> bool:
    return ENEMY_ATTACK_CHOICE.attack_can_reach_target(self, command, target, ignore_cooldown)


func _command_vertical_tolerance(command: Dictionary) -> float:
    return ENEMY_ATTACK_CHOICE.command_vertical_tolerance(self, command)


func _max_attack_range(ready_only: bool = false) -> float:
    return ENEMY_ATTACK_CHOICE.max_attack_range(self, ready_only)


func _attack_desire_threshold() -> float:
    return ENEMY_ATTACK_CHOICE.attack_desire_threshold(self)


func _update_attack_desire(delta: float, target: CharacterBody2D, engaged: bool) -> void:
    ENEMY_ATTACK_CHOICE.update_attack_desire(self, delta, target, engaged)


func _player_command_pressure(command: String) -> float:
    return ENEMY_ATTACK_CHOICE.player_command_pressure(self, command)


func _attack_candidate_score(command: Dictionary, target: CharacterBody2D) -> float:
    return ENEMY_ATTACK_CHOICE.attack_candidate_score(self, command, target)


func _attack_has_role(command: Dictionary, role: String) -> bool:
    return ENEMY_ATTACK_CHOICE.attack_has_role(self, command, role)


func _choose_attack(candidates: Array, target: CharacterBody2D) -> Dictionary:
    return ENEMY_ATTACK_CHOICE.choose_attack(self, candidates, target)


func _count_other_attackers(target: CharacterBody2D) -> int:
    return ENEMY_ATTACK_CHOICE.count_other_attackers(self, target)


func _is_aware_of(target: CharacterBody2D) -> bool:
    return ENEMY_ATTACK_CHOICE.is_aware_of(self, target)


func _lead_target(target: CharacterBody2D, lead_seconds: float, max_lead: float) -> Vector2:
    return ENEMY_ATTACK_CHOICE.lead_target(self, target, lead_seconds, max_lead)


func _read_player_command(target: CharacterBody2D) -> String:
    return ENEMY_ATTACK_CHOICE.read_player_command(self, target)


func _player_facing(target: CharacterBody2D) -> int:
    return ENEMY_ATTACK_CHOICE.player_facing(self, target)


func _float_property(node: Object, key: String, fallback: float) -> float:
    return ENEMY_ATTACK_CHOICE.float_property(self, node, key, fallback)


func _vector2_property(node: Object, key: String, fallback: Vector2) -> Vector2:
    return ENEMY_ATTACK_CHOICE.vector2_property(self, node, key, fallback)


func _try_start_attack(target: CharacterBody2D) -> bool:
    return ENEMY_ATTACK_PHASES.try_start_attack(self, target)


func _begin_attack(command: Dictionary) -> void:
    ENEMY_ATTACK_PHASES.begin_attack(self, command)


func _update_windup(delta: float) -> void:
    ENEMY_ATTACK_PHASES.update_windup(self, delta)


func _aim_attack(command: Dictionary, target: CharacterBody2D) -> void:
    ENEMY_ATTACK_PHASES.aim_attack(self, command, target)


func _update_active(delta: float) -> void:
    ENEMY_ATTACK_PHASES.update_active(self, delta)

func _update_authored_combo(progress: float) -> bool:
    return ENEMY_ATTACK_PHASES.update_authored_combo(self, progress)


func _update_recover(delta: float) -> void:
    ENEMY_ATTACK_PHASES.update_recover(self, delta)

func _prepare_recovery_action(delta: float) -> void:
    ENEMY_ATTACK_PHASES.prepare_recovery_action(self, delta)

func _sync_walk_cadence(delta: float, previous: Vector2) -> void:
    ENEMY_ATTACK_PHASES.sync_walk_cadence(self, delta, previous)


func contact_attack_rect(command: Dictionary) -> Rect2:
    return ENEMY_ATTACK_PHASES.contact_attack_rect(self, command)


func _try_damage_player(command: Dictionary, previous_position: Vector2 = Vector2.INF) -> void:
    ENEMY_ATTACK_PHASES.try_damage_player(self, command, previous_position)


func _show_telegraph(command: Dictionary) -> void:
    ENEMY_EFFECTS.show_telegraph(self, command)


func _add_attack_type_signature(parent: Node2D, command: Dictionary, center: Vector2, width: float, height: float, dir: int) -> Line2D:
    return ENEMY_EFFECTS.add_attack_type_signature(self, parent, command, center, width, height, dir)


func _clear_telegraph() -> void:
    ENEMY_EFFECTS.clear_telegraph(self)


func _on_body_entered(body: Node) -> void:
    if dying or is_queued_for_deletion() or not world_residency_active() or contact_timer > 0.0:
        return
    if not is_instance_valid(body) or body.is_queued_for_deletion() or (body.get("ui_input_locked") == true):
        return
    if body.has_method("can_ignore_enemy_contact") and body.can_ignore_enemy_contact(global_position):
        contact_timer = 0.12
        return
    if body.has_method("take_damage"):
        contact_timer = 0.65
        body.take_damage(damage, global_position, false)


## Centre of the physical body, which never overlaps the terrain it touches.
func body_center() -> Vector2:
    for child in get_children():
        if child is CollisionShape2D:
            return child.global_position
    return global_position


func _build_shape() -> void:
    ENEMY_PRESENTATION.build_shape(self)


func _build_sprite() -> void:
    ENEMY_PRESENTATION.build_sprite(self)


## Frames were drawn one at a time and the same body differs in size between
## neighbours. The measured correction is applied where the frame is drawn, so
## sprite.scale and sprite.position keep their gameplay meaning.
func _apply_frame_fit() -> void:
    ENEMY_PRESENTATION.apply_frame_fit(self)


## The shader needs to know which wing the current frame shows and where that
## frame sits in its atlas. Clips without an entry keep their drawn wings.
func _apply_wing_flap() -> void:
    ENEMY_PRESENTATION.apply_wing_flap(self)


func _advance_wing_flap(delta: float) -> void:
    ENEMY_PRESENTATION.advance_wing_flap(self, delta)


## 受击白闪 Shader（规格 §3.1）：每个可见 sprite 挂一份独立 ShaderMaterial，
## modulate 乘法调制无法“变白”，必须走 shader mix。
func _attach_flash_materials() -> void:
    ENEMY_PRESENTATION.attach_flash_materials(self)


func _build_part_sprite() -> Node2D:
    return ENEMY_PRESENTATION.build_part_sprite(self)


func _load_enemy_sprite_frames(manifest_path: String) -> SpriteFrames:
    return ENEMY_PRESENTATION.load_enemy_sprite_frames(self, manifest_path)


func _vec2(value: Variant) -> Vector2:
    return ENEMY_PRESENTATION.vec2(self, value)


func _vec2_or(value: Variant, fallback: Vector2) -> Vector2:
    return ENEMY_PRESENTATION.vec2_or(self, value, fallback)


func _load_texture_resource(path: String) -> Texture2D:
    return ENEMY_PRESENTATION.load_texture_resource(self, path)


func _set_sprite_flip(flip_value: bool) -> void:
    ENEMY_PRESENTATION.set_sprite_flip(self, flip_value)


func _set_enemy_animation(animation_name: String, restart: bool = false) -> void:
    ENEMY_PRESENTATION.set_enemy_animation(self, animation_name, restart)


func _fit_animation_duration(duration: float, phase: String = "") -> void:
    ENEMY_PRESENTATION.fit_animation_duration(self, duration, phase)

func _animation_seconds(name: String) -> float:
    return ENEMY_PRESENTATION.animation_seconds(self, name)


func _resolve_directional_animation(animation_name: String) -> String:
    return ENEMY_PRESENTATION.resolve_directional_animation(self, animation_name)


## An attack's own cels are named after its id; without them it keeps the
## command's shared animation (normally the species' generic attack).
func _attack_animation_base(command: Dictionary) -> String:
    return ENEMY_PRESENTATION.attack_animation_base(self, command)


func _advance_pose_loop() -> void:
    ENEMY_PRESENTATION.advance_pose_loop(self)


func _has_enemy_animation(animation_name: String) -> bool:
    return ENEMY_PRESENTATION.has_enemy_animation(self, animation_name)


func _is_directional_animation_name(animation_name: String) -> bool:
    return ENEMY_PRESENTATION.is_directional_animation_name(self, animation_name)


func _apply_sprite_flip(allow_motion: bool = true) -> void:
    ENEMY_PRESENTATION.apply_sprite_flip(self, allow_motion)

func _on_motion_animation_finished() -> void:
    ENEMY_PRESENTATION.on_motion_animation_finished(self)


func _apply_sprite_region(animation_name: String) -> void:
    ENEMY_PRESENTATION.apply_sprite_region(self, animation_name)


func _pose_sprite(pose_name: String, command: Dictionary = {}) -> void:
    ENEMY_PRESENTATION.pose_sprite(self, pose_name, command)


func _pose_offset(command: Dictionary, key: String, fallback: Vector2) -> Vector2:
    return ENEMY_PRESENTATION.pose_offset(self, command, key, fallback)


func _pose_scale(command: Dictionary, key: String, fallback: Vector2) -> Vector2:
    return ENEMY_PRESENTATION.pose_scale(self, command, key, fallback)


## S03: terrain between this actor and the player muffles its one-shots, using
## the same sight ray as the AI. Danger and confirm cues (voice priority 0:
## wind-ups, roars, phase shifts, kill confirms) stay clearly audible.
const SFX_OCCLUSION_DB := 10.0
const SFX_DANGER_OCCLUSION_DB := 4.0

func _sfx_listener() -> CollisionObject2D:
    return ENEMY_AUDIO.sfx_listener(self)

func _sfx_occluded() -> bool:
    return ENEMY_AUDIO.sfx_occluded(self)

func _sfx_volume(volume_db: float, voice_priority: int, occluded: Variant = null) -> float:
    return ENEMY_AUDIO.sfx_volume(self, volume_db, voice_priority, occluded)


func _play_sfx(audio_key: String, volume_db: float = -6.0, pitch_scale: float = 1.0, voice_priority: int = 1) -> void:
    ENEMY_AUDIO.play_sfx(self, audio_key, volume_db, pitch_scale, voice_priority)


func _stop_parade_layer() -> void:
    ENEMY_AUDIO.stop_parade_layer(self)


func _play_attack_sfx(phase: String) -> void:
    ENEMY_AUDIO.play_attack_sfx(self, phase)

func _play_combat_material(family: String, volume: float) -> bool:
    return ENEMY_AUDIO.play_combat_material(self, family, volume)


## 招式分档：优先读攻击条目 telegraph_tier（lethal/heavy 即重档），否则按 damage>=2 判定
## （全六章 Boss 攻击表 damage 恰分 1/2 两档）。
func _active_attack_is_heavy() -> bool:
    return ENEMY_AUDIO.active_attack_is_heavy(self)


## Boss 四件套键名：boss kind → 章节短号 → boss_chNN_<piece>。
func _boss_sfx_key(piece: String) -> String:
    return ENEMY_AUDIO.boss_sfx_key(self, piece)


## 受击材质档：Boss 一律重甲；普通敌按死亡材质族映射，未知材质回落软质。
func _hit_tier_key() -> String:
    return ENEMY_AUDIO.hit_tier_key(self)


## 首次进战宣告：Boss 开场吼 / 精英（encounter_role 含 elite）仪式起手；
## 手工章节 enemy_spawns 无 encounter_role → 空串静默，仅普通巡逻音。
## Each B01 role transition has its own sound. Reveal and alarm also draw a
## short ring on the warning layer (once per engagement, never budget-culled):
## a jagged burst for a reveal, two widening rings for a call.
func _role_cue(cue: String) -> void:
    ENEMY_AUDIO.role_cue(self, cue)


## Music/alert layer contract: an actor waiting at a post is not in combat.
func combat_engaged() -> bool:
    return ENEMY_AUDIO.combat_engaged(self)


func _announce_engagement() -> void:
    ENEMY_AUDIO.announce_engagement(self)


## 敌方音源总线：SFXEnemy（AudioDirector 子总线，send→SFX）→ SFX → Master 逐级回落。
func _sfx_bus_name() -> String:
    return ENEMY_AUDIO.sfx_bus_name(self)


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


## 独立宿主播放（死亡音专用）：播放器父挂 enemy 的父节点并定位到当前位置，
## 敌人节点溶解释放后尾音仍完整，播完自毁不泄漏。
func _play_detached_sfx(audio_key: String, volume_db: float = -6.0) -> void:
    ENEMY_AUDIO.play_detached_sfx(self, audio_key, volume_db)


func _original_attack_arc(command: Dictionary, warning: bool) -> void:
    ENEMY_EFFECTS.original_attack_arc(self, command, warning)

func _spawn_windup_vfx(command: Dictionary) -> void:
    ENEMY_EFFECTS.spawn_windup_vfx(self, command)


func _spawn_attack_burst_vfx(command: Dictionary) -> void:
    ENEMY_EFFECTS.spawn_attack_burst_vfx(self, command)


func _should_play_sfx() -> bool:
    return ENEMY_AUDIO.should_play_sfx(self)


func _load_sfx_stream(audio_key: String) -> AudioStream:
    return ENEMY_AUDIO.load_sfx_stream(self, audio_key)


## 流缓存（AudioDirector 契约）：全部音频加载改走静态缓存 load_cached（键 path|looped，
## 含负缓存）；脚本缺席或方法未落地时回退旧直读，保证 headless 局部验证可跑。
static func _load_stream_for_path(path: String, looped: bool = false) -> AudioStream:
    if path.is_empty():
        return null
    if _ensure_audio_director() and audio_director_script.has_method("load_cached"):
        return audio_director_script.load_cached(path, looped)
    return _load_stream_direct(path, looped)


static func _load_stream_direct(path: String, looped: bool = false) -> AudioStream:
    var stream:=STREAM_SOURCE.load_stream(path)
    if path.ends_with(".ogg"):
        var ogg:=stream as AudioStreamOggVorbis
        if ogg!=null:ogg.loop=looped
        return ogg
    if path.ends_with(".wav"):
        # 自产 SFX 包走 WAV 直读（Godot 4.6 headless 安全，无需 import 资源）。
        var wav:=stream as AudioStreamWAV
        if wav!=null:
            wav.loop_mode=AudioStreamWAV.LOOP_FORWARD if looped else AudioStreamWAV.LOOP_DISABLED
            if looped:
                wav.loop_begin=0
                wav.loop_end=wav.data.size()/((2 if wav.format==AudioStreamWAV.FORMAT_16_BITS else 1)*(2 if wav.stereo else 1))
        return wav
    return load(path) as AudioStream if ResourceLoader.exists(path,"AudioStream") else null


func _spawn_hit_spark(hit_direction: int, contact_call: int = -1) -> void:
    ENEMY_EFFECTS.spawn_hit_spark(self, hit_direction, contact_call)


func _cancel_attack_effects() -> void:
    ENEMY_EFFECTS.cancel_attack_effects(self)

func _cancel_unarmed_attack_effects() -> void:
    ENEMY_EFFECTS.cancel_unarmed_attack_effects(self)

func _exit_tree() -> void:
    CONTACT_ART.clear_receiver(self)
    _clear_telegraph()
    _cancel_attack_effects()

func _combat_tween() -> Tween:
    for index in range(combat_tweens.size() - 1, -1, -1):
        var previous = combat_tweens[index]
        if not is_instance_valid(previous) or not previous.is_valid():
            combat_tweens.remove_at(index)
    var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
    combat_tweens.append(tween)
    if combat_visuals_paused:
        tween.pause()
    return tween

func _set_combat_visuals_paused(paused: bool) -> void:
    if paused == combat_visuals_paused:
        return
    combat_visuals_paused = paused
    for tween in combat_tweens:
        if not is_instance_valid(tween) or not tween.is_valid():continue
        if paused:
            tween.pause()
        else:
            tween.play()
    if animated_sprite != null:
        if paused:
            animation_was_playing = animated_sprite.is_playing()
            animated_sprite.pause()
        elif animation_was_playing:
            animated_sprite.play()
