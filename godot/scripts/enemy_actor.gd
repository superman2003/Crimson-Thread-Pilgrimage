extends Area2D

const ORIGINAL_ART := preload("res://scripts/hand_drawn_assets.gd")
const ATTACK_EFFECT := preload("res://scripts/enemy_attack_effect.gd")
var locomotion := "ground"
var flight_clock := 0.0
var hover_height := 0.0
var attack_elapsed := 0.0
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
        _cancel_attack_effects()
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
        if not get_world_2d().direct_space_state.intersect_ray(lure_ray).is_empty():
            return
    lure_position = point
    lure_timer = maxf(lure_timer, minf(2.0, seconds))

var original_visual := false
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
        if target!=null and state not in ["windup","active"]:
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
    var effect := ATTACK_EFFECT.new()
    effect.effect_kind=effect_kind
    effect.position=point
    effect.velocity=vel
    effect.heading=vel.normalized() if vel.length()>0 else Vector2(attack_direction,0)
    effect.arm_delay=warning
    effect.duration=warning+lifetime
    effect.radius=float(command.get("radius",11))
    effect.length=float(command.get("beam_length",360))
    if effect_kind == "beam" and is_inside_tree():
        if get_parent().has_method("_ensure_collision_segment"):
            get_parent()._ensure_collision_segment(point, point + effect.heading * effect.length)
        var query := PhysicsRayQueryParameters2D.create(point, point + effect.heading * effect.length, 1)
        query.collide_with_areas = false
        var obstruction := get_world_2d().direct_space_state.intersect_ray(query)
        if get_parent().has_method("_rock_ray_hit"):
            var rock: Dictionary = get_parent()._rock_ray_hit(point, point + effect.heading * effect.length)
            if not rock.is_empty() and (obstruction.is_empty() or point.distance_squared_to(rock.position) < point.distance_squared_to(obstruction.position)):
                obstruction = rock
        if not obstruction.is_empty():
            effect.length = minf(effect.length, point.distance_to(obstruction.position))
    effect.set_meta("blockable", bool(command.get("blockable", true)))
    effect.damage=int(command.get("damage",damage))
    effect.gravity=float(command.get("gravity",0))
    effect.snare=float(command.get("snare",0))
    effect.skin=String(command.get("skin","thorn"))
    effect.returning=bool(command.get("returning",false))
    effect.steering=float(command.get("steering",0))
    effect.impact_pool=bool(command.get("impact_pool",false))
    effect.owner_actor=self
    # Freed Object references cannot be converted to a typed lambda argument.
    # Prune in place, retaining the typed array and never dereferencing stale nodes.
    for index in range(owned_attack_effects.size() - 1, -1, -1):
        var previous = owned_attack_effects[index]
        if not is_instance_valid(previous) or previous.is_queued_for_deletion():
            owned_attack_effects.remove_at(index)
    owned_attack_effects.append(effect)
    effect.tint=Color.html("#"+String(command.get("telegraph","c99558")))
    get_parent().add_child(effect)
    return effect

func _spawn_command_effects(command: Dictionary, warning: bool) -> void:
    var type := String(command.get("type","melee"))
    var origin := global_position+Vector2(attack_direction*18,-22)
    var aim := (attack_target-origin).normalized()
    var count := int(command.get("shot_count",1))
    var projectile_speed := float(command.get("projectile_speed",220))
    if type in ["projectile","fan","nova","mortar","wave"]:
        for i in range(count):
            var velocity_value := aim*projectile_speed
            if type=="fan":
                var spread := float(command.get("spread",.5))
                velocity_value=aim.rotated((float(i)/maxi(1,count-1)-.5)*spread)*projectile_speed
            elif type=="nova":
                velocity_value=Vector2.from_angle(float(i)/count*TAU)*projectile_speed
            elif type=="mortar":
                velocity_value=Vector2(attack_direction*(projectile_speed+i*52),-260-i*30)
            elif type=="wave":
                velocity_value=Vector2((-1 if i%2==0 else 1)*(projectile_speed+floori(i/2)*float(command.get("speed_step",0))),0)
            var point := global_position+Vector2(0,24) if type=="wave" else origin
            _effect("wave" if type=="wave" else "projectile",point,velocity_value,command,0,3.0)
    elif type=="beam":
        var warn := float(command.get("windup",.6)) if warning else .05
        _effect("beam",origin,aim,command,warn,float(command.get("hazard_life",.4)))
    elif type in ["pool","rootline"]:
        for i in range(count):
            var x := attack_target.x+(i-(count-1)*.5)*float(command.get("spacing",90))
            var floor_y := attack_target.y+42
            if type=="rootline" and not bool(command.get("targeted",false)):
                x=global_position.x+attack_direction*(i+1)*float(command.get("spacing",90))
                floor_y=global_position.y+40
            var terrain: Node=get_parent().get("chapter_terrain")
            if terrain!=null:
                var sampled: float=terrain.floor_height(x,floor_y,210)
                if is_finite(sampled):floor_y=sampled
            var delay: float = (float(command.get("windup",.6)) if warning else 0.0)+float(command.get("warning",.65))+i*(.12 if type=="rootline" else 0.0)
            _effect("eruption" if type=="rootline" else "pool",Vector2(x,floor_y-5),Vector2.ZERO,command,delay,float(command.get("hazard_life",.7)))
    elif type=="blink":
        var x := attack_target.x-attack_direction*float(command.get("blink_offset",115))
        global_position.x=clampf(x,platform_min_x,platform_max_x)
        var target := _target_player()
        if target!=null:_face_target(target)
        origin=global_position+Vector2(direction*20,-24)
        _effect("projectile",origin,(attack_target-origin).normalized()*projectile_speed,command,.12,2.5)

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
    # 章节 beat 叠层（audio_visual_manifest chapter beats）：章节条件按敌人材质
    # （death_sfx_key，main_level 按章节 art theme 写入）或 boss kind 判定。
    "ch02_beat_water_hammer": "res://assets/audio/sfx/generated/ch02_rain_foundry_canal_beat_03_audio.ogg",
    "ch03_beat_contract_break": "res://assets/audio/sfx/generated/ch03_saltwhite_archive_beat_03_audio.ogg",
    "ch05_beat_silent_order": "res://assets/audio/sfx/generated/ch05_obsidian_pilgrim_road_beat_02_audio.ogg",
    "ch06_beat_crown_resonance": "res://assets/audio/sfx/generated/ch06_silent_crown_core_beat_02_audio.ogg"
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
## 白闪曲线（规格 §3.1）：3 帧纯白 → 2 帧半白，共 ≈83ms。
const FLASH_TOTAL_TIME := 0.083
const FLASH_HALF_TIME := 0.033
## 击退指数衰减时间常数（规格 §3.2）。
const KNOCKBACK_TAU := 0.06

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
var boss_tactic := "observe"
var boss_tactic_timer := 0.0
var boss_press_timer := 0.0
var boss_reposition_target_x := 0.0
var sprite: Node2D
var animated_sprite: AnimatedSprite2D
var telegraph: Polygon2D
var telegraph_tween: Tween
var requested_sprite_flip := false
var current_animation_has_explicit_direction := false
var flash_materials: Array = []
var knockback_velocity := 0.0
var dying := false
## 遭遇编制角色（generated 章节配置 enemy_spawns.encounter_role，如 elite_duo/preboss_elite；
## 手工章节无此字段 → 空串天然静默）。
var encounter_role := ""
## 首次进战宣告一次性标记（Boss 开场吼 / 精英仪式起手）。
var engage_announced := false
## Boss 半血相变音一次性标记（纯音频钩子，无 HP 阶段行为机）。
var boss_phase_shift_played := false


var presentation_prepared := false

func prepare_presentation() -> void:
    if presentation_prepared: return
    _build_shape()
    _build_sprite()
    presentation_prepared = true

func _ready() -> void:
    add_to_group("enemy")
    if locomotion == "flight":
        global_position.y -= hover_height
    start_x = global_position.x
    spawn_position = global_position
    monitoring = true
    monitorable = true
    body_entered.connect(_on_body_entered)
    prepare_presentation()


func _physics_process(delta: float) -> void:
    if dying:
        return
    var player_node := _target_player()
    var ui_locked := player_node != null and bool(player_node.get("ui_input_locked"))
    _set_combat_visuals_paused(ui_locked)
    if ui_locked:
        return
    if is_boss and battle_phase == 1 and hp <= max_hp * float(ai_profile.get("phase_threshold",0.55)):
        battle_phase = 2
        phase_pause = 0.9
        _cancel_attack_effects()
        _clear_telegraph()
        state = "patrol"
        active_attack = {}
        _set_enemy_animation("phase")
        if get_parent().has_method("_toast"):
            get_parent()._toast(String(ai_profile.get("phase_name","第二阶段")))
    if phase_pause>0:
        phase_pause-=delta
        return
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
    _update_locomotion(delta,target)


func configure(data: Dictionary, sprite_path: String, boss_flag: bool = false, profile: Dictionary = {}) -> void:
    spawn_id = String(data.get("id", "enemy"))
    kind = String(data.get("kind", "moss_larva"))
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
    locomotion = String(ai_profile.get("locomotion",data.get("locomotion","ground")))
    hover_height = float(ai_profile.get("hover_height",95)) if locomotion=="flight" else 0.0
    speed = float(ai_profile.get("move_speed",speed))
    var original_path := "res://assets/sprites/original_creatures/"+kind+"/manifest.json"
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
        var h := float(art_data.get("display_height",90))
        if not data.has("hurtbox_offset"):
            hurtbox_offset=Vector2(0,40-h*.5)
        if not data.has("body_size"):
            body_size=Vector2(98 if is_boss else 35,h*.72)
        if not data.has("hurtbox_size"):
            hurtbox_size=Vector2(125 if is_boss else 48,h*.84)
    ai_profile["lure_eligible"] = bool(data.get("lure_eligible", ai_profile.get("lure_eligible", not is_boss and locomotion != "stationary")))
    ai_commands = ai_profile.get("attacks", [])
    for command in ai_commands:
        cooldowns[String(command.get("id", "attack"))] = float(command.get("start_cooldown", 0.0))


func take_hit(amount: int, hit_direction: int) -> void:
    if dying:
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
    _spawn_hit_spark(hit_direction)
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
    if _boss_tactical_enabled() and hp > 0:
        boss_tactic = "evade"
        boss_tactic_timer = float(ai_profile.get("hurt_evade_time", 0.42))
        boss_press_timer = 0.0
    if not is_boss and hp > 0:
        _cancel_attack_effects()
        active_attack = {}
        state = "recover"
        state_timer = 0.16
        _clear_telegraph()
    if hp <= 0:
        _begin_death_dissolve()


## 死亡溶解（规格 §3.4 简化通用版）：died 当帧发出、立即离开 enemy 组，
## 之后表现层溶解 0.45s（Boss 0.9s）再 queue_free——计数/掉落逻辑不受影响。
func _begin_death_dissolve() -> void:
    dying = true
    _cancel_attack_effects()
    monitoring = false
    monitorable = false
    remove_from_group("enemy")
    knockback_velocity = 0.0
    # 材质化死亡音（音频规格 §4.3）：挂到父节点播放，避免溶解 queue_free 截断尾音。
    _play_detached_sfx("boss_death" if is_boss else death_sfx_key, -4.0 if is_boss else -6.0)
    # ch3 beat `contract_break`（manifest ch03_beat_03）：盐白契约判官死亡时
    # 契约碎页散开——纸页撕裂与低频钟声叠层（同走独立宿主避免截断）。
    if is_boss and kind == "saltwhite_contract_judge":
        _play_detached_sfx("ch03_beat_contract_break", -8.0)
    _set_enemy_animation("death")
    _pose_sprite("death")
    _clear_telegraph()
    died.emit(spawn_id, is_boss, kind)
    if sprite == null or not is_instance_valid(sprite):
        queue_free()
        return
    var duration := 0.9 if is_boss else 0.45
    var tween := create_tween()
    tween.tween_interval(0.05)
    tween.tween_callback(func() -> void: _set_flash_amount(0.0))
    tween.tween_property(sprite, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    tween.parallel().tween_property(sprite, "position:y", sprite.position.y + 14.0, duration)
    tween.parallel().tween_property(sprite, "scale", sprite.scale * 0.90, duration)
    tween.finished.connect(Callable(self, "queue_free"))


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
    if flash_timer > 0.0:
        flash_timer -= delta
        if flash_timer <= 0.0:
            _set_flash_amount(0.0)
        else:
            _set_flash_amount(1.0 if flash_timer > FLASH_HALF_TIME else 0.5)
    if absf(knockback_velocity) > 0.0:
        position.x += knockback_velocity * delta
        knockback_velocity *= exp(-delta / KNOCKBACK_TAU)
        if absf(knockback_velocity) < 8.0:
            knockback_velocity = 0.0
        _clamp_movement_bounds()
    for key in cooldowns.keys():
        cooldowns[key] = maxf(0.0, float(cooldowns[key]) - delta)
    if boss_tactic_timer > 0.0:
        boss_tactic_timer = maxf(0.0, boss_tactic_timer - delta)


func _set_flash_amount(amount: float) -> void:
    for material_value in flash_materials:
        var material := material_value as ShaderMaterial
        if material != null:
            material.set_shader_parameter("flash_amount", amount)


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
    platform_min_x = min_x-100 if locomotion=="flight" else min_x
    platform_max_x = max_x+100 if locomotion=="flight" else max_x


func reset_for_respawn() -> void:
    if dying:
        return
    hp = max_hp
    knockback_velocity = 0.0
    _set_flash_amount(0.0)
    global_position = spawn_position
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
    if lure_timer > 0.0:
        return null
    if interference_timer > 0.0:
        for command in ai_commands:
            if String(command.get("type", "")) in ["projectile", "beam", "throw"]:
                return null
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


func _has_line_of_sight(target: CharacterBody2D) -> bool:
    if target == null or not is_instance_valid(target) or not is_inside_tree():
        return false
    if get_parent().has_method("_ensure_collision_segment"):
        get_parent()._ensure_collision_segment(global_position + Vector2(0, -24), target.global_position + Vector2(0, -42))
    if get_parent().has_method("_rock_ray_hit") and not get_parent()._rock_ray_hit(global_position + Vector2(0, -24), target.global_position + Vector2(0, -42)).is_empty():
        return false
    # Terrain occupies layer 1; player/enemy hurtboxes must not occlude sight.
    var query := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -24), target.global_position + Vector2(0, -42), 1)
    query.exclude = [get_rid(), target.get_rid()]
    query.collide_with_areas = false
    return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func apply_snare(seconds: float) -> void:
    if is_finite(seconds) and seconds > 0.0 and not dying:
        snare_timer = maxf(snare_timer, minf(seconds, 12.0) * float(combat_resistance.get("snare_mult", 0.35 if is_boss else 1.0)))


func _movement_speed() -> float:
    return 0.0 if trip_timer > 0.0 else speed * ((0.82 if is_boss else 0.5) if snare_timer > 0.0 else 1.0)


func _update_patrol_or_aggro(delta: float, target: CharacterBody2D) -> void:
    if lure_timer > 0.0 and not is_boss:
        var dx := lure_position.x - global_position.x
        var step := signf(dx) * minf(absf(dx), _movement_speed() * delta)
        var lure_ray := PhysicsRayQueryParameters2D.create(global_position + Vector2(0,-24), global_position + Vector2(step + signf(dx) * 24,-24), 1)
        lure_ray.collide_with_areas = false
        if get_world_2d().direct_space_state.intersect_ray(lure_ray).is_empty():
            global_position.x += step
        return
    var aggro_range := float(ai_profile.get("aggro_range", 220.0 if not is_boss else 460.0))
    var engaged := target != null and _target_inside_leash(target) and _target_in_engage_window(target, aggro_range) and _has_line_of_sight(target)
    if engaged and not engage_announced:
        _announce_engagement()
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
    if locomotion == "stationary":
        last_ai_decision="hold_position"
        _set_enemy_animation("idle")
        return
    if _boss_tactical_enabled():
        _move_boss_tactical(delta, target)
        return
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
    var chase_speed := _movement_speed() * (float(ai_profile.get("pressure_speed_multiplier", 1.18)) if pressured else 1.0)
    var movement_direction := 0.0
    if attack_range > 0.0 and distance > attack_range - 10.0:
        movement_direction = signf(dx)
        position.x += movement_direction * chase_speed * delta
        moved = true
        last_ai_decision = "press"
    elif distance > desired + 14.0:
        movement_direction = signf(dx)
        position.x += movement_direction * chase_speed * delta
        moved = true
        last_ai_decision = "advance"
    elif distance < desired - 18.0 and not pressured:
        movement_direction = -signf(dx)
        position.x += movement_direction * _movement_speed() * 0.55 * delta
        moved = true
        last_ai_decision = "space"
    else:
        last_ai_decision = "threaten"
    if moved and movement_direction != 0.0:
        direction = -1 if movement_direction < 0.0 else 1
        _set_sprite_flip(direction < 0)
    elif target != null:
        _face_target(target)
    _clamp_movement_bounds()
    _set_enemy_animation("walk" if moved else "idle")


func _boss_tactical_enabled() -> bool:
    return is_boss and bool(ai_profile.get("tactical_ai", true))


func _move_boss_tactical(delta: float, target: CharacterBody2D) -> void:
    var dx := target.global_position.x - global_position.x
    var distance := absf(dx)
    _prepare_boss_tactic(target, distance)
    var moved := false
    var movement_direction := 0.0
    var move_multiplier := 1.0
    match boss_tactic:
        "press":
            movement_direction = signf(dx)
            move_multiplier = float(ai_profile.get("pressure_speed_multiplier", 1.08))
            boss_press_timer += delta
            last_ai_decision = "tactic:press"
        "evade":
            movement_direction = -signf(dx)
            move_multiplier = float(ai_profile.get("evade_speed_multiplier", 1.18))
            boss_press_timer = maxf(0.0, boss_press_timer - delta * 1.4)
            last_ai_decision = "tactic:evade"
        "reposition":
            var reposition_dx := boss_reposition_target_x - global_position.x
            if absf(reposition_dx) > 8.0:
                movement_direction = signf(reposition_dx)
                move_multiplier = float(ai_profile.get("reposition_speed_multiplier", 1.04))
            last_ai_decision = "tactic:reposition"
        "space":
            movement_direction = _boss_spacing_direction(distance, dx)
            move_multiplier = float(ai_profile.get("spacing_speed_multiplier", 0.72))
            boss_press_timer = maxf(0.0, boss_press_timer - delta)
            last_ai_decision = "tactic:space"
        "guard":
            boss_press_timer = maxf(0.0, boss_press_timer - delta * 0.55)
            last_ai_decision = "tactic:guard"
        _:
            boss_press_timer = maxf(0.0, boss_press_timer - delta * 0.45)
            last_ai_decision = "tactic:observe"
    if movement_direction != 0.0:
        position.x += movement_direction * _movement_speed() * move_multiplier * delta
        moved = true
    _clamp_movement_bounds()
    if moved:
        direction = -1 if movement_direction < 0.0 else 1
        _set_sprite_flip(direction < 0)
    elif target != null:
        _face_target(target)
    _set_enemy_animation("walk" if moved else "idle")


func _prepare_boss_tactic(target: CharacterBody2D, distance: float = -1.0) -> void:
    if target == null:
        boss_tactic = "observe"
        boss_tactic_timer = 0.0
        return
    var measured_distance := distance
    if measured_distance < 0.0:
        measured_distance = absf(target.global_position.x - global_position.x)
    if boss_tactic_timer <= 0.0 or _boss_tactic_finished(target, measured_distance):
        _choose_boss_tactic(target, measured_distance)


func _boss_tactic_finished(target: CharacterBody2D, distance: float) -> bool:
    var preferred := float(ai_profile.get("preferred_range", 118.0))
    var close_range := float(ai_profile.get("close_range", maxf(56.0, preferred * 0.62)))
    if boss_tactic == "press":
        return distance <= preferred * 0.92 or boss_press_timer >= float(ai_profile.get("max_press_time", 1.25))
    if boss_tactic == "evade":
        return distance >= preferred * 1.22 or _boss_at_arena_edge()
    if boss_tactic == "reposition":
        return absf(global_position.x - boss_reposition_target_x) <= 10.0
    if boss_tactic == "space":
        return distance >= close_range and distance <= preferred * 1.18
    return false


func _choose_boss_tactic(target: CharacterBody2D, distance: float) -> void:
    var preferred := float(ai_profile.get("preferred_range", 118.0))
    var attack_range := _max_attack_range(false)
    var ready_range := _max_attack_range(true)
    var close_range := float(ai_profile.get("close_range", maxf(56.0, preferred * 0.62)))
    var pressure := _player_command_pressure(last_player_command)
    var threshold := _attack_desire_threshold()
    if distance <= close_range or _boss_should_evade_player_command(pressure):
        _set_boss_tactic("evade", _boss_tactic_duration("evade", 0.42), target)
        return
    if last_player_command == "heal" or last_player_command == "run_away":
        _set_boss_tactic("press", _boss_tactic_duration("press", 0.72), target)
        return
    if boss_press_timer >= float(ai_profile.get("max_press_time", 1.25)):
        _set_boss_tactic("reposition", _boss_tactic_duration("reposition", 0.82), target)
        return
    if ready_range > 0.0 and distance > ready_range * 0.92:
        _set_boss_tactic("press", _boss_tactic_duration("press", 0.86), target)
        return
    if attack_range > 0.0 and distance > attack_range * 0.82:
        _set_boss_tactic("press", _boss_tactic_duration("press", 0.70), target)
        return
    if _boss_should_reposition(target, distance):
        _set_boss_tactic("reposition", _boss_tactic_duration("reposition", 0.78), target)
        return
    if attack_desire < threshold * 0.66:
        _set_boss_tactic("observe", _boss_tactic_duration("observe", 0.34), target)
        return
    if distance < preferred * 0.92 or distance > preferred * 1.22:
        _set_boss_tactic("space", _boss_tactic_duration("space", 0.48), target)
        return
    _set_boss_tactic("guard", _boss_tactic_duration("guard", 0.36), target)


func _set_boss_tactic(next_tactic: String, duration: float, target: CharacterBody2D) -> void:
    boss_tactic = next_tactic
    boss_tactic_timer = maxf(0.08, duration)
    if boss_tactic == "reposition":
        boss_reposition_target_x = _boss_reposition_x(target)


func _boss_tactic_duration(tactic: String, fallback: float) -> float:
    var durations: Dictionary = ai_profile.get("tactic_durations", {})
    return float(durations.get(tactic, ai_profile.get(tactic + "_time", fallback)))


func _boss_should_evade_player_command(pressure: float) -> bool:
    if pressure < 1.0:
        return false
    return ["slash_forward", "slash_up", "slash_down", "dash_toward", "hook"].has(last_player_command)


func _boss_should_reposition(target: CharacterBody2D, distance: float) -> bool:
    if not _boss_has_arena_bounds():
        return false
    var edge_margin := float(ai_profile.get("arena_edge_margin", 150.0))
    if global_position.x - _boss_min_x() < edge_margin or _boss_max_x() - global_position.x < edge_margin:
        return true
    var preferred := float(ai_profile.get("preferred_range", 118.0))
    return distance < preferred * 1.05 and attack_desire >= _attack_desire_threshold() * 0.82 and boss_tactic == "guard"


func _boss_spacing_direction(distance: float, dx: float) -> float:
    var preferred := float(ai_profile.get("preferred_range", 118.0))
    if distance < preferred * 0.92:
        return -signf(dx)
    if distance > preferred * 1.22:
        return signf(dx)
    return 0.0


func _boss_reposition_x(target: CharacterBody2D) -> float:
    var min_x := _boss_min_x()
    var max_x := _boss_max_x()
    var margin := float(ai_profile.get("arena_edge_margin", 150.0))
    if min_x >= max_x:
        return spawn_position.x
    var midpoint := (min_x + max_x) * 0.5
    var desired := max_x - margin if target.global_position.x < midpoint else min_x + margin
    if absf(desired - global_position.x) < margin * 0.75:
        desired = min_x + margin if desired > midpoint else max_x - margin
    return clampf(desired, min_x + 36.0, max_x - 36.0)


func _boss_has_arena_bounds() -> bool:
    return _boss_min_x() < _boss_max_x()


func _boss_min_x() -> float:
    if arena_min_x < arena_max_x:
        return arena_min_x
    if platform_min_x < platform_max_x:
        return platform_min_x
    return spawn_position.x - 520.0


func _boss_max_x() -> float:
    if arena_min_x < arena_max_x:
        return arena_max_x
    if platform_min_x < platform_max_x:
        return platform_max_x
    return spawn_position.x + 520.0


func _boss_at_arena_edge() -> bool:
    if not _boss_has_arena_bounds():
        return false
    var edge_margin := float(ai_profile.get("arena_edge_margin", 150.0)) * 0.55
    return global_position.x - _boss_min_x() <= edge_margin or _boss_max_x() - global_position.x <= edge_margin


func _patrol(delta: float) -> void:
    if locomotion=="stationary":
        _set_enemy_animation("idle")
        return
    position.x += direction * _movement_speed() * 0.72 * delta
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
    position.x += direction * _movement_speed() * delta
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
    if int(command.get("phase",1))>battle_phase:
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
    if ai_commands.is_empty() or not _has_line_of_sight(target):
        return false
    var desire_threshold := _attack_desire_threshold()
    if _boss_tactical_enabled():
        _prepare_boss_tactic(target)
        if ["evade", "reposition", "observe"].has(boss_tactic):
            last_ai_decision = "tactic:" + boss_tactic
            return false
        if boss_tactic == "space" and attack_desire < desire_threshold * 1.12:
            last_ai_decision = "tactic:space"
            return false
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
    if candidates.size()>1:
        var alternatives := candidates.filter(func(c): return String(c.get("id",""))!=last_attack_id)
        if not alternatives.is_empty():
            candidates=alternatives
    candidates.sort_custom(func(a, b): return _attack_candidate_score(a, target) > _attack_candidate_score(b, target))
    _face_target(target)
    _begin_attack(candidates[0])
    return true


func _begin_attack(command: Dictionary) -> void:
    active_attack = command
    attack_elapsed=0
    trail_clock=0
    attack_start_position=global_position
    var target_node := _target_player()
    attack_target=target_node.global_position-Vector2(0,42) if target_node!=null else global_position+Vector2(direction*140,-24)
    attack_has_hit = false
    attack_direction = direction
    last_attack_id = String(command.get("id", "attack"))
    last_ai_decision = "attack:" + last_attack_id
    if _boss_tactical_enabled():
        boss_tactic = "attack"
        boss_tactic_timer = float(command.get("windup", 0.25)) + float(command.get("active", 0.16))
        boss_press_timer = maxf(0.0, boss_press_timer - float(command.get("desire_cost", 0.72)) * 0.35)
    attack_desire = maxf(0.0, attack_desire - float(command.get("desire_cost", 0.72 if is_boss else 0.86)))
    state = "windup"
    state_timer = float(command.get("windup", 0.25))
    cooldowns[String(command.get("id", "attack"))] = float(command.get("cooldown", 1.2))
    _set_enemy_animation(String(command.get("animation", "attack")))
    _pose_sprite("windup", command)
    _play_attack_sfx("windup")
    _spawn_windup_vfx(command)
    _show_telegraph(command)
    if not bool(command.get("blockable", true)) and ResourceLoader.exists("res://scripts/seal_presentation.gd"):
        var presentation := Node2D.new()
        presentation.set_script(load("res://scripts/seal_presentation.gd"))
        add_child(presentation)
        presentation.cue_unblockable(global_position + Vector2(0,-65))
        var cleanup := create_tween()
        cleanup.tween_interval(1.0)
        cleanup.tween_callback(presentation.queue_free)
    if String(command.get("type","")) in ["beam","pool","rootline"]:
        _spawn_command_effects(command,true)


func _update_windup(delta: float) -> void:
    state_timer -= delta
    if state_timer <= 0.0:
        state = "active"
        state_timer = float(active_attack.get("active", 0.16))
        _pose_sprite("active", active_attack)
        _play_attack_sfx("active")
        _spawn_attack_burst_vfx(active_attack)
        if String(active_attack.get("type","")) not in ["beam","pool","rootline"]:
            _spawn_command_effects(active_attack,false)


func _update_active(delta: float) -> void:
    var attack_type := String(active_attack.get("type", "melee"))
    attack_elapsed+=delta
    var progress := clampf(attack_elapsed/maxf(.01,float(active_attack.get("active",.24))),0,1)
    if attack_type == "dive":
        global_position=attack_start_position.lerp(attack_target,progress)
    elif attack_type == "vault":
        position.x+=attack_direction*float(active_attack.get("lunge_speed",240))*delta
        global_position.y=attack_start_position.y-sin(progress*PI)*float(active_attack.get("jump_height",130))
    elif attack_type == "combo":
        position.x+=attack_direction*float(active_attack.get("lunge_speed",125))*delta
        if int(attack_elapsed/.20)!=int((attack_elapsed-delta)/.20):
            attack_has_hit=false
    elif attack_type == "lunge":
        position.x += attack_direction * float(active_attack.get("lunge_speed", 220.0)) * delta
    elif attack_type == "retreat":
        position.x -= attack_direction * float(active_attack.get("retreat_speed", 150.0)) * delta
    elif attack_type == "feint":
        var sway := sin(state_timer * TAU * 8.0) * float(active_attack.get("feint_sway", 78.0)) * delta
        position.x += attack_direction * sway
    _clamp_movement_bounds()

    if attack_type in ["melee","aoe","lunge","retreat","feint","combo","guard","dive"] or (attack_type=="vault" and progress>.6):
        _try_damage_player(active_attack)
    if bool(active_attack.get("trail",false)):
        trail_clock+=delta
        if trail_clock>.16:
            trail_clock=0
            _effect("pool",global_position+Vector2(0,25),Vector2.ZERO,active_attack,.35,1.1)

    state_timer -= delta
    if state_timer <= 0.0:
        state = "recover"
        state_timer = float(active_attack.get("recover", 0.42))
        _pose_sprite("recover", active_attack)
        _clear_telegraph()
        if attack_type=="vault":
            global_position.y=attack_start_position.y


func _update_recover(delta: float) -> void:
    state_timer -= delta
    if state_timer <= 0.0:
        active_attack = {}
        state = "patrol"
        if _boss_tactical_enabled():
            boss_tactic = "reposition" if boss_press_timer >= float(ai_profile.get("max_press_time", 1.25)) * 0.72 else "guard"
            boss_tactic_timer = _boss_tactic_duration(boss_tactic, 0.34)
            var target := _target_player()
            if boss_tactic == "reposition" and target != null:
                boss_reposition_target_x = _boss_reposition_x(target)
        _set_enemy_animation("idle")
        _pose_sprite("idle")


func _try_damage_player(command: Dictionary) -> void:
    if attack_has_hit:
        return
    var target := _target_player()
    if target == null or not _has_line_of_sight(target):
        return

    var attack_type := String(command.get("type", "melee"))
    var dir := attack_direction if _is_attack_state() else direction
    var center := global_position + Vector2(dir * float(command.get("offset", 44.0)), float(command.get("offset_y",-26.0)))
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
        target.take_damage(int(command.get("damage", damage)), global_position, bool(command.get("blockable", true)))
        attack_has_hit = true
        if bool(command.get("leech",false)):
            hp=mini(max_hp,hp+1)


func _show_telegraph(command: Dictionary) -> void:
    _clear_telegraph()
    if original_visual:
        return
    var attack_type := String(command.get("type", "melee"))
    telegraph = Polygon2D.new()
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
    telegraph_tween = _combat_tween()
    telegraph_tween.set_loops(3)
    telegraph_tween.tween_property(telegraph, "scale", Vector2(1.08, 1.08), 0.08)
    telegraph_tween.tween_property(telegraph, "scale", Vector2(1.0, 1.0), 0.08)


func _clear_telegraph() -> void:
    if telegraph_tween != null and is_instance_valid(telegraph_tween) and telegraph_tween.is_valid():
        telegraph_tween.kill()
    telegraph_tween = null
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
        body.take_damage(damage, global_position, false)


func _build_shape() -> void:
    var shape := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = body_size if body_size != Vector2.ZERO else (Vector2(132, 128) if is_boss else Vector2(50, 46))
    shape.shape = rectangle
    if original_visual:
        shape.position=hurtbox_offset
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
    _attach_flash_materials()


## 受击白闪 Shader（规格 §3.1）：每个可见 sprite 挂一份独立 ShaderMaterial，
## modulate 乘法调制无法“变白”，必须走 shader mix。
func _attach_flash_materials() -> void:
    flash_materials.clear()
    var targets: Array = []
    if sprite is Sprite2D or sprite is AnimatedSprite2D:
        targets.append(sprite)
    else:
        for child in sprite.get_children():
            if child is Sprite2D or child is AnimatedSprite2D:
                targets.append(child)
    for target_value in targets:
        var target := target_value as CanvasItem
        var material := ShaderMaterial.new()
        material.shader = HIT_FLASH_SHADER
        target.material = material
        flash_materials.append(material)


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
    if manifest_path.contains("original_creatures"):
        return ORIGINAL_ART.frames(manifest_path)
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
    requested_sprite_flip = flip_value
    _apply_sprite_flip()


func _set_enemy_animation(animation_name: String) -> void:
    var next_animation := _resolve_directional_animation(animation_name)
    if animated_sprite != null and animated_sprite.sprite_frames != null and not animated_sprite.sprite_frames.has_animation(next_animation):
        next_animation = "idle"
    current_animation_has_explicit_direction = _is_directional_animation_name(next_animation) and _has_enemy_animation(next_animation)
    _apply_sprite_region(next_animation)
    _apply_sprite_flip()
    if animated_sprite == null or animated_sprite.sprite_frames == null:
        return
    if next_animation in ["idle", "walk", "phase"]:
        animated_sprite.speed_scale = 1.0
    if animated_sprite.animation != next_animation:
        animated_sprite.play(next_animation)


func _resolve_directional_animation(animation_name: String) -> String:
    if _is_directional_animation_name(animation_name):
        return animation_name
    var direction_suffix := "_left" if (attack_direction if _is_attack_state() else direction) < 0 else "_right"
    var directional_animation := animation_name + direction_suffix
    if _has_enemy_animation(directional_animation):
        return directional_animation
    return animation_name


func _has_enemy_animation(animation_name: String) -> bool:
    if animated_sprite != null and animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(animation_name):
        return true
    return sprite_regions.has(animation_name)


func _is_directional_animation_name(animation_name: String) -> bool:
    return animation_name.ends_with("_left") or animation_name.ends_with("_right")


func _apply_sprite_flip() -> void:
    if sprite == null:
        return
    if current_animation_has_explicit_direction:
        sprite.set("flip_h", false)
        return
    sprite.set("flip_h", not requested_sprite_flip if sprite_faces_left else requested_sprite_flip)


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
    if original_visual:
        sprite.position=sprite_base_position
        sprite.scale=sprite_base_scale
        sprite.rotation=0
        sprite.modulate.a = .24 if pose_name=="windup" and bool(command.get("burrow",false)) else 1.0
        var animation_name := pose_name
        var requested := String(command.get("animation","attack"))
        if pose_name=="windup":
            animation_name=requested+"_windup" if _has_enemy_animation(requested+"_windup") else "windup"
        elif pose_name=="active":
            animation_name=requested if _has_enemy_animation(requested) else "attack"
        elif pose_name=="recover":
            animation_name="idle"
        _set_enemy_animation(animation_name)
        if animated_sprite!=null:
            animated_sprite.speed_scale=1.0
            if pose_name in ["windup","active"]:
                var frames := animated_sprite.sprite_frames
                var duration := float(command.get("windup" if pose_name=="windup" else "active",.3))
                animated_sprite.speed_scale=frames.get_frame_count(animation_name)/maxf(.01,frames.get_animation_speed(animation_name)*duration)
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
    var tween := _combat_tween()
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


func _play_sfx(audio_key: String, volume_db: float = -6.0, pitch_scale: float = 1.0, voice_priority: int = 1) -> void:
    if not _should_play_sfx():
        return
    # 声部准入（AudioDirector 契约）：同 key 最小间隔/并发上限/全局 24 声部抢占。
    if not _request_voice("enemy_" + audio_key, voice_priority):
        return
    var stream := _load_sfx_stream(audio_key)
    if stream == null:
        # 声部回滚（AudioDirector 契约）：流缺失/解码失败时释放已占用的声部。
        _release_voice("enemy_" + audio_key)
        return
    var player_node := AudioStreamPlayer2D.new()
    player_node.name = "Sfx_" + audio_key
    # 总线归位（音频规格 §5.1）：敌人/Boss 音走 SFXEnemy 子总线，缺席时回落 SFX/Master。
    player_node.bus = _sfx_bus_name()
    player_node.stream = stream
    player_node.volume_db = volume_db
    player_node.pitch_scale = pitch_scale
    player_node.max_distance = 900.0
    add_child(player_node)
    player_node.finished.connect(Callable(player_node, "queue_free"))
    player_node.play()


func _play_attack_sfx(phase: String) -> void:
    if phase == "windup":
        if is_boss:
            # Boss 前摇分档（音频规格 §4.4）：damage>=2（各 Boss aoe/shockwave 大招）走 lethal 档。
            _play_sfx("boss_windup_lethal" if _active_attack_is_heavy() else "boss_windup_light", -6.0)
        else:
            # 普通敌前摇=windup_light 低配版：升调 + 压量，与 Boss 档拉开距离。
            _play_sfx("enemy_windup", -13.0, 1.22)
        # ch5 beat `silent_order`（manifest ch05_beat_02）：黑曜巡礼道（obsidian 材质族）
        # 敌方前摇附一段低频压迫声（军令低鸣叠层）。
        if death_sfx_key == "death_obsidian":
            _play_sfx("ch05_beat_silent_order", -12.0)
    elif is_boss:
        # Boss 出招按档走本章四件套 atk_light/atk_heavy（替换 player_attack.ogg 复用）。
        _play_sfx(_boss_sfx_key("atk_heavy" if _active_attack_is_heavy() else "atk_light"), -7.0)
        # ch2 beat `boss_water_hammer`（manifest ch02_beat_03）：沉锤匠水锤大招落点
        # 叠半圆水浪声层。
        if kind == "sunken_hammer_smith" and _active_attack_is_heavy():
            _play_sfx("ch02_beat_water_hammer", -8.0)
    else:
        _play_sfx("enemy_attack", -10.0)


## 招式分档：优先读攻击条目 telegraph_tier（lethal/heavy 即重档），否则按 damage>=2 判定
## （全六章 Boss 攻击表 damage 恰分 1/2 两档）。
func _active_attack_is_heavy() -> bool:
    var tier := String(active_attack.get("telegraph_tier", ""))
    if not tier.is_empty():
        return tier == "lethal" or tier == "heavy"
    return int(active_attack.get("damage", damage)) >= 2


## Boss 四件套键名：boss kind → 章节短号 → boss_chNN_<piece>。
func _boss_sfx_key(piece: String) -> String:
    return "boss_%s_%s" % [String(BOSS_SFX_CHAPTER.get(kind, "ch01")), piece]


## 受击材质档：Boss 一律重甲；普通敌按死亡材质族映射，未知材质回落软质。
func _hit_tier_key() -> String:
    if is_boss:
        return "hit_armor"
    return String(HIT_TIER_BY_MATERIAL.get(death_sfx_key, "hit_soft"))


## 首次进战宣告：Boss 开场吼 / 精英（encounter_role 含 elite）仪式起手；
## 手工章节 enemy_spawns 无 encounter_role → 空串静默，仅普通巡逻音。
func _announce_engagement() -> void:
    engage_announced = true
    if is_boss:
        _play_sfx(_boss_sfx_key("roar"), -4.0, 1.0, 0)
    elif encounter_role.contains("elite"):
        _play_sfx("elite_ritual_start", -6.0)


## 敌方音源总线：SFXEnemy（AudioDirector 子总线，send→SFX）→ SFX → Master 逐级回落。
func _sfx_bus_name() -> String:
    if AudioServer.get_bus_index("SFXEnemy") != -1:
        return "SFXEnemy"
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


## 独立宿主播放（死亡音专用）：播放器父挂 enemy 的父节点并定位到当前位置，
## 敌人节点溶解释放后尾音仍完整，播完自毁不泄漏。
func _play_detached_sfx(audio_key: String, volume_db: float = -6.0) -> void:
    if not _should_play_sfx():
        return
    # 死亡音属 P0：声部抢占最高优先级。
    if not _request_voice("enemy_" + audio_key, 0):
        return
    var stream := _load_sfx_stream(audio_key)
    if stream == null:
        # 声部回滚（AudioDirector 契约）：流缺失/解码失败时释放已占用的声部。
        _release_voice("enemy_" + audio_key)
        return
    var host := get_parent()
    if host == null:
        return
    var player_node := AudioStreamPlayer2D.new()
    player_node.name = "Sfx_" + audio_key
    player_node.bus = _sfx_bus_name()
    player_node.stream = stream
    player_node.volume_db = volume_db
    player_node.max_distance = 900.0
    host.add_child(player_node)
    player_node.global_position = global_position
    player_node.finished.connect(Callable(player_node, "queue_free"))
    player_node.play()


func _original_attack_arc(command: Dictionary, warning: bool) -> void:
    var type := String(command.get("type", "melee"))
    if type in ["beam", "pool", "rootline"]: return
    var line := Line2D.new()
    line.name = "OriginalAttackWarning" if warning else "OriginalAttackArc"
    line.width = 1.6 if warning else 3.5
    line.default_color = Color(.95,.77,.45,.68) if warning else Color(.86,.33,.25,.85)
    line.z_index = 8
    var points := PackedVector2Array()
    var reach := float(command.get("hit_width",80))*.62
    if type in ["projectile", "fan", "mortar", "nova"]:
        var aim := (attack_target-global_position-Vector2(0,-22)).normalized()
        points=PackedVector2Array([Vector2(0,-22),Vector2(0,-22)+aim*48,Vector2(0,-22)+aim*40+aim.orthogonal()*8])
    else:
        for i in range(18):
            var angle := lerpf(-1.25,1.25,float(i)/17)
            points.append(Vector2(attack_direction*(20+cos(angle)*reach),-26+sin(angle)*float(command.get("hit_height",70))*.55))
    line.points=points
    add_child(line)
    var tween := _combat_tween()
    tween.tween_property(line,"modulate:a",0.0,float(command.get("windup",.5)) if warning else .22)
    tween.finished.connect(line.queue_free)

func _spawn_windup_vfx(command: Dictionary) -> void:
    if original_visual:
        _original_attack_arc(command, true)
        return
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
    var tween := _combat_tween()
    tween.tween_property(warning, "scale", Vector2(1.16, 1.16), float(command.get("windup", 0.25)))
    tween.parallel().tween_property(warning, "modulate:a", 0.0, float(command.get("windup", 0.25)))
    tween.finished.connect(Callable(warning, "queue_free"))


func _spawn_attack_burst_vfx(command: Dictionary) -> void:
    if original_visual:
        _original_attack_arc(command, false)
        return
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
    var tween := _combat_tween()
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
    if path.is_empty() and audio_key.begins_with("boss_ch"):
        # Boss 四件套（roar/phase_shift/atk_light/atk_heavy × 六章）按键名直取合成包文件。
        path = "res://assets/audio/sfx/generated/%s.ogg" % audio_key
    return _load_stream_for_path(path)


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


func _spawn_hit_spark(hit_direction: int) -> void:
    var spark := Line2D.new()
    spark.name = "HitSpark"
    spark.width = 4.0 if is_boss else 3.0
    spark.default_color = Color(1.0, 0.957, 0.902, 0.95)
    spark.z_index = 40
    var x := 24.0 * -hit_direction
    spark.points = PackedVector2Array([
        Vector2(x, -30.0),
        Vector2(x + 28.0 * hit_direction, -48.0),
        Vector2(x + 7.0 * hit_direction, -22.0),
        Vector2(x + 34.0 * hit_direction, -12.0)
    ])
    add_child(spark)
    var tween := _combat_tween()
    tween.tween_property(spark, "scale", Vector2(1.55, 1.55), 0.16)
    tween.parallel().tween_property(spark, "modulate:a", 0.0, 0.16)
    tween.finished.connect(Callable(spark, "queue_free"))

func _cancel_attack_effects() -> void:
    for effect in owned_attack_effects:
        if is_instance_valid(effect) and not effect.is_queued_for_deletion():
            effect.cancel()
    owned_attack_effects.clear()

func _exit_tree() -> void:
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
