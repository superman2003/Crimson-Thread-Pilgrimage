## 音频总导演（音效与音乐设计规格 §2/§3/§5/§6 一期落地）：
## - 静态声部管理：同 key 最小间隔 / 同 key 并发上限 / 全局 24 声部，P0(0)>P1(1)>P2(2) 抢占。
## - 静态流缓存：load_cached 按 "path|looped" 键缓存解码流（负缓存 + 告警一次），
##   全项目音频加载统一走它，重复播放零磁盘 IO。
## - 章节音乐组：探索循环（ch01 沿用既有 bgm_ch01 ogg）+ 战斗层叠加 + Boss 曲
##   （终 Boss 三乐章切换）+ 钟龛摇篮曲 + 钟道站厅循环层，环境床与稀疏 one-shot 调度。
## - 运行时状态机（bind_runtime 注入 player/敌群）：战斗层轮询、摇篮曲距离、Boss 相位
##   由本节点 _process 自驱，main_level 只负责一行 bind。
## - 混音状态：对话/关键拾取 duck、房型混响 wet 微调、濒死低通扫频、死亡全局低通。
## - 用户四档音量（master/music/sfx/ambience）持久化 user://audio_settings.cfg。
## 不注册 autoload（headless 验证脚本不跑主场景）：由 main_level._build_audio
## 实例化并 add_child；_ready 赋 instance，_exit_tree 清空。
class_name AudioDirector
extends Node

static var instance: AudioDirector

# ---- 静态声部管理 ----
const MAX_GLOBAL_VOICES := 24
## Only unclaimed reservations expire; bound voices follow actual playback.
const VOICE_NOMINAL_MS := 900

static var _voice_serial := 0
static var _voice_entries: Array = []
static var _voice_last_ms: Dictionary = {}
static var _voice_last_ticket: Dictionary = {}

# ---- 静态流缓存（契约：键 "%s|%d" % [path, int(looped)]；缺失/解码失败缓存 null）----
static var _stream_cache: Dictionary = {}

# ---- 子总线（send 目标索引均低于新增总线，运行时补建安全）----
const MUSIC_SUB_BUSES := ["MusicExplore", "MusicCombat", "MusicStinger"]
const SFX_SUB_BUSES := ["SFXPlayer", "SFXEnemy", "SFXWorld"]
## Master 限幅器（规格 §5.1 总线目标电平的落地替代）：24 声部求和防削波。
const MASTER_LIMITER_CEILING_DB := -0.5

# ---- 电平常数（BGM 总线基准沿用旧 BgmPlayer -18dB 口径）----
const EXPLORE_DB := -18.0
const COMBAT_LAYER_DB := -16.0
const BOSS_DB := -16.0
const LULLABY_DB := -14.0
const STINGER_DB := -12.0
const TRANSIT_LOOP_DB := -10.0
const AMBIENCE_BED_DB := 0.0
const AMBIENCE_ONESHOT_DB := -6.0
const ANVIL_FAR_DB := -8.0
const SILENT_DB := -60.0

const BUS_DEFAULT_DB := {"Master": 0.0, "BGM": 0.0, "SFX": 0.0, "Ambience": -14.0, "UI": -10.0}
const USER_VOLUME_BUS := {"master": "Master", "music": "BGM", "sfx": "SFX", "ambience": "Ambience"}
const SETTINGS_PATH := "user://audio_settings.cfg"
var settings_path := SETTINGS_PATH

const DIALOGUE_MUSIC_DUCK_DB := -4.0
const DIALOGUE_AMBIENCE_DUCK_DB := -6.0
const LOW_HP_SWEEP_START_HZ := 2000.0
const LOW_HP_SWEEP_TARGET_HZ := 800.0
const LOW_HP_SWEEP_SECONDS := 2.0
const DEATH_LOWPASS_HZ := 300.0
const ROOM_REVERB_WET_DELTA := {"hub": 0.10, "vista": 0.10, "corridor": -0.08, "secret": -0.08}

# ---- 状态机 / 调度常数（间隔常量仅此一处，消除双写）----
const ONESHOT_INTERVAL_MIN_S := 45.0
const ONESHOT_INTERVAL_MAX_S := 120.0
const ANVIL_INTERVAL_MIN_S := 30.0
const ANVIL_INTERVAL_MAX_S := 75.0
const COMBAT_POLL_INTERVAL_S := 0.25
## 离战冷静期（防抽泵）：4s 无接敌才收战斗层。
const COMBAT_CALM_SECONDS := 4.0
const LULLABY_LEAVE_DISTANCE := 150.0

# ---- 淡入淡出时长（Boss 进出 / 摇篮曲交叉淡化 / 章节转场）----
const BOSS_ENTER_EXPLORE_FADE_S := 0.6
const BOSS_ENTER_COMBAT_FADE_S := 0.3
const BOSS_EXIT_FADE_S := 0.8
const BOSS_EXIT_EXPLORE_FADE_S := 1.2
const LULLABY_EXPLORE_FADE_S := 0.8
const EXPLORE_RESUME_FROM_DB := -12.0
const CHAPTER_EXIT_BGM_FADE_S := 0.5
const CHAPTER_ENTER_EXPLORE_FADE_S := 0.8
const TRANSIT_LOOP_FADE_OUT_S := 1.0

# ---- 章节音乐/环境资产表（音乐包 + 环境包清单）----
const CHAPTER_SLUGS := {
    "ch01": "ch01_moss_bell_court",
    "ch02": "ch02_rain_foundry_canal",
    "ch03": "ch03_saltwhite_archive",
    "ch04": "ch04_broken_string_greenhouse",
    "ch05": "ch05_obsidian_pilgrim_road",
    "ch06": "ch06_silent_crown_core"
}
const LEGACY_EXPLORE_CH01 := "res://assets/audio/bgm/ch01_cave_loop.ogg"
const LEGACY_BOSS_CH01 := "res://assets/audio/bgm/boss_rust_crown_loop.ogg"
## Boss kind → 章节 slug（rust_crown_guardian 沿用既有 boss_rust_crown_loop）。
const BOSS_CHAPTER_SLUG := {
    "sunken_hammer_smith": "ch02_rain_foundry_canal",
    "saltwhite_contract_judge": "ch03_saltwhite_archive",
    "broken_string_gardener": "ch04_broken_string_greenhouse",
    "silent_pilgrim_commander": "ch05_obsidian_pilgrim_road"
}
const FINAL_BOSS_ID := "silent_crown_core"
const FINAL_BOSS_MOVEMENTS := [
    "res://assets/audio/bgm/generated/boss_final_silent_crown_mvt1.ogg",
    "res://assets/audio/bgm/generated/boss_final_silent_crown_mvt2.ogg",
    "res://assets/audio/bgm/generated/boss_final_silent_crown_mvt3.ogg"
]
const STINGER_TRACKS := {
    "bellway_depart": "res://assets/audio/bgm/generated/bellway_depart_jingle.ogg",
    "bellway_arrive": "res://assets/audio/bgm/generated/bellway_arrive_jingle.ogg",
    "ending_a": "res://assets/audio/bgm/generated/ending_a_rebell.ogg",
    "ending_b": "res://assets/audio/bgm/generated/ending_b_severance.ogg",
    "ending_c": "res://assets/audio/bgm/generated/ending_c_reweave.ogg"
}
## 钟道站厅音乐层（transit 房低音量循环，on_room_changed 驱动）。
const BELLWAY_TRANSIT_LOOP := "res://assets/audio/bgm/generated/bellway_transit_loop.ogg"

static var _npc_voice_cache: Dictionary = {}
## Session-only phrase positions. Values are seconds/instance IDs, never streams.
static var _explore_resume: Dictionary = {}
static var _explore_owners: Dictionary = {}
static var _explore_epoch := 0
const MAX_EXPLORE_BOOKMARKS := 8
var _explore_path := ""
var _explore_session := 0
var _npc_voice_player: AudioStreamPlayer

var autoplay_enabled := true
var chapter_short_id := "ch01"
var explore_player: AudioStreamPlayer
var combat_player: AudioStreamPlayer
var boss_player: AudioStreamPlayer
var lullaby_player: AudioStreamPlayer
var stinger_player: AudioStreamPlayer
var transit_player: AudioStreamPlayer
var ambience_bed_player: AudioStreamPlayer
var oneshot_timer: Timer
var anvil_timer: Timer
var oneshot_variant_count := 0
var combat_active := false
var boss_active := false
var active_boss_id := ""
var boss_phase := 0
var lullaby_active := false
var low_hp_active := false
var dialogue_open := false
var user_volumes := {"master": 100.0, "music": 100.0, "sfx": 100.0, "ambience": 100.0}
var base_reverb_wet: Dictionary = {}
var duck_tween: Tween
var combat_tween: Tween
var lullaby_tween: Tween
var explore_tween: Tween
var boss_tween: Tween
var transit_tween: Tween
var low_hp_tween: Tween
var death_tween: Tween
var bus_tweens: Dictionary = {}
var reverb_tweens: Dictionary = {}
# ---- 运行时状态机（bind_runtime 注入；main_level 不再轮询）----
var runtime_player: Node
var get_enemies_source := Callable()
var ai_poll_accum := 0.0
var combat_calm_time := 0.0
var shrine_anchor := Vector2.ZERO
var shrine_engaged := false


func _ready() -> void:
    instance = self
    ensure_sub_buses()
    _load_user_volumes()


func _exit_tree() -> void:
    _remember_explore_position()
    if _explore_owners.get(_explore_path, 0) == get_instance_id():
        _explore_owners.erase(_explore_path)
    # Stop local envelopes before retirement. Global mix belongs to the latest
    # director; a queued old scene must never strip a new scene's death/HP filter.
    for tween in [duck_tween, combat_tween, lullaby_tween, explore_tween, boss_tween, transit_tween, low_hp_tween, death_tween]:
        if tween != null and tween.is_valid():
            tween.kill()
    for tween in bus_tweens.values() + reverb_tweens.values():
        if tween != null and tween.is_valid():
            tween.kill()
    for voice in [explore_player, combat_player, boss_player, lullaby_player, stinger_player, transit_player, ambience_bed_player, _npc_voice_player]:
        if voice != null and is_instance_valid(voice):
            voice.stop()
            voice.stream = null
    if instance != null and instance != self:
        return
    if instance == self:
        instance = null
    # 总线是全局状态：摘除死亡/濒死滤波，避免跨章节残留（音量复位由 main_level 兜底）。
    _clear_death_lowpass()
    if low_hp_active:
        set_low_hp(false)


## Legacy boolean admission remains available to probes; production uses a ticket
## so deferred playback cannot bind another request's reservation.
static func request_voice(key: String, priority: int = 1, min_interval_ms: int = 40, max_voices: int = 3) -> bool:
    return reserve_voice(key,priority,min_interval_ms,max_voices) != 0

static func reserve_voice(key: String, priority: int = 1, min_interval_ms: int = 40, max_voices: int = 3) -> int:
    var now := Time.get_ticks_msec()
    _prune_voices()
    if _voice_last_ms.has(key) and now-int(_voice_last_ms[key]) < min_interval_ms:return 0
    var same_key := 0
    for entry in _voice_entries:
        if String(entry.key)==key:same_key += 1
    if same_key >= max_voices:return 0
    if _voice_entries.size() >= MAX_GLOBAL_VOICES:
        var worst := -1
        var worst_priority := priority
        for index in _voice_entries.size():
            if int(_voice_entries[index].priority)>worst_priority:
                worst_priority=int(_voice_entries[index].priority)
                worst=index
        if worst < 0:return 0
        _remove_voice(worst,true)
    _voice_serial += 1
    _voice_last_ms[key]=now
    _voice_last_ticket[key]=_voice_serial
    _voice_entries.append({"ticket":_voice_serial,"key":key,"priority":priority,"end_ms":now+VOICE_NOMINAL_MS,"reserved_ms":now})
    return _voice_serial

## Claim and start in one synchronous operation; live voices never expire by
## nominal duration. Persistent players survive preemption for later reuse.
static func start_reserved_voice(ticket: int, voice: Node, persistent: bool = false) -> bool:
    _prune_voices()
    var target := -1
    for index in _voice_entries.size():
        if int(_voice_entries[index].ticket)==ticket and not _voice_entries[index].has("voice"):target=index
    if target < 0 or not is_instance_valid(voice) or not voice.is_inside_tree() or voice.is_queued_for_deletion() or not (voice is AudioStreamPlayer or voice is AudioStreamPlayer2D) or voice.stream == null:
        if target >= 0:release_ticket(ticket)
        for entry in _voice_entries:
            if _entry_voice(entry)==voice:return false
        if is_instance_valid(voice) and (voice is AudioStreamPlayer or voice is AudioStreamPlayer2D):
            voice.stop()
            if not persistent:voice.queue_free()
        return false
    # Reusing the dedicated NPC/wall player retires only its previous lease.
    for index in range(_voice_entries.size()-1,-1,-1):
        if index != target and _entry_voice(_voice_entries[index])==voice:
            _remove_voice(index,false)
            if index < target:target -= 1
    var finished := _forget_voice.bind(ticket)
    var exiting := _forget_voice.bind(ticket)
    _voice_entries[target].merge({"voice":weakref(voice),"persistent":persistent,"finished":finished,"exiting":exiting})
    voice.finished.connect(finished,CONNECT_ONE_SHOT)
    voice.tree_exiting.connect(exiting,CONNECT_ONE_SHOT)
    voice.play()
    return true

static func _entry_voice(entry: Dictionary) -> Node:
    return entry.voice.get_ref() if entry.has("voice") else null

static func _prune_voices() -> void:
    var now := Time.get_ticks_msec()
    for index in range(_voice_entries.size()-1,-1,-1):
        var entry: Dictionary=_voice_entries[index]
        var voice := _entry_voice(entry)
        if entry.has("voice"):
            if not is_instance_valid(voice) or not voice.is_inside_tree() or voice.is_queued_for_deletion() or not voice.has_stream_playback():_remove_voice(index,false)
        elif int(entry.end_ms)<=now:_remove_voice(index,false)

static func _forget_voice(ticket: int) -> void:
    for index in _voice_entries.size():
        if int(_voice_entries[index].ticket)==ticket:
            _remove_voice(index,false)
            return

static func _remove_voice(index: int, stop_playback: bool) -> void:
    var entry: Dictionary=_voice_entries[index]
    _voice_entries.remove_at(index)
    var voice := _entry_voice(entry)
    if not is_instance_valid(voice):return
    if entry.has("finished") and voice.finished.is_connected(entry.finished):voice.finished.disconnect(entry.finished)
    if entry.has("exiting") and voice.tree_exiting.is_connected(entry.exiting):voice.tree_exiting.disconnect(entry.exiting)
    if stop_playback:
        preload("res://scripts/audio_retirement.gd").watch_player(voice)
        voice.stop()
        if not bool(entry.get("persistent",false)):
            voice.stream=null
            voice.queue_free()

static func release_ticket(ticket: int) -> void:
    for index in _voice_entries.size():
        var entry: Dictionary=_voice_entries[index]
        if int(entry.ticket)==ticket:
            if int(_voice_last_ticket.get(entry.key,-1))==ticket:
                _voice_last_ms.erase(entry.key)
                _voice_last_ticket.erase(entry.key)
            _remove_voice(index,true)
            return

## Compatibility rollback affects an unclaimed reservation only.
static func release_voice(key: String) -> void:
    for index in range(_voice_entries.size()-1,-1,-1):
        if String(_voice_entries[index].key)==key and not _voice_entries[index].has("voice"):
            release_ticket(int(_voice_entries[index].ticket))
            return

static func active_voice_count() -> int:
    _prune_voices()
    return _voice_entries.size()

## 幂等补建子总线；UI 总线保证干声（无混响）。main_level._ensure_audio_buses 转调。
## SFXDry（send→Master 干声，濒死心跳等不吃章节混响）；Master 挂限幅器防求和削波。
static func ensure_sub_buses() -> void:
    for bus_name in MUSIC_SUB_BUSES:
        _ensure_bus(String(bus_name), "BGM")
    for bus_name in SFX_SUB_BUSES:
        _ensure_bus(String(bus_name), "SFX")
    _ensure_bus("SFXDry", "Master")
    _ensure_bus("ReverbZone", "Master")
    var reverb_zone := AudioServer.get_bus_index("ReverbZone")
    if reverb_zone != -1 and _find_bus_effect(reverb_zone, "AudioEffectReverb") == -1:
        AudioServer.add_bus_effect(reverb_zone, AudioEffectReverb.new())
    var master_index := AudioServer.get_bus_index("Master")
    if master_index != -1 and _find_bus_effect(master_index, "AudioEffectLimiter") == -1:
        var limiter := AudioEffectLimiter.new()
        limiter.ceiling_db = MASTER_LIMITER_CEILING_DB
        AudioServer.add_bus_effect(master_index, limiter)
    var ui_index := AudioServer.get_bus_index("UI")
    if ui_index != -1:
        var stale := _find_bus_effect(ui_index, "AudioEffectReverb")
        while stale != -1:
            AudioServer.remove_bus_effect(ui_index, stale)
            stale = _find_bus_effect(ui_index, "AudioEffectReverb")


static func _ensure_bus(bus_name: String, send_to: String) -> void:
    # Godot 4.6.1 add_bus/set_bus_send do not lock the driver. The mixer reads
    # bus_map and send concurrently, including with a complete default layout.
    # Hold one non-yielding transaction through creation, naming and routing;
    # the driver's recursive mutex also covers set_bus_name's internal lock.
    AudioServer.lock()
    if AudioServer.get_bus_index(bus_name) == -1:
        AudioServer.add_bus()
        AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
    var index := AudioServer.get_bus_index(bus_name)
    var send := send_to if AudioServer.get_bus_index(send_to) != -1 else "Master"
    if AudioServer.get_bus_send(index) != send:
        AudioServer.set_bus_send(index, send)
    AudioServer.unlock()


static func _find_bus_effect(bus_index: int, effect_class: String) -> int:
    if bus_index < 0:
        return -1
    for effect_index in AudioServer.get_bus_effect_count(bus_index):
        var effect := AudioServer.get_bus_effect(bus_index, effect_index)
        if effect != null and effect.get_class() == effect_class:
            return effect_index
    return -1


## 统一流缓存入口（契约）：键 "path|int(looped)"。looped=true 的流在入缓存前
## 置好循环标记（ogg.loop / wav LOOP_FORWARD + 按位深与声道数换算的帧数）；
## 文件缺失/解码失败缓存 null（负缓存）并 push_warning 一次。
## 调用点不许原地改缓存流的 loop——需要不同循环语义就用对应键取。
static func load_cached(path: String, looped: bool = false) -> AudioStream:
    var cache_key := "%s|%d" % [path, int(looped)]
    if _stream_cache.has(cache_key):
        return _stream_cache[cache_key]
    var stream := _load_stream(path)
    if stream == null:
        push_warning("AudioDirector.load_cached: 音频缺失或解码失败: " + path)
        _stream_cache[cache_key] = null
        return null
    if looped:
        var ogg := stream as AudioStreamOggVorbis
        if ogg != null:
            ogg.loop = true
        var wav := stream as AudioStreamWAV
        if wav != null:
            wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
            wav.loop_begin = 0
            wav.loop_end = _wav_frame_count(wav)
    _stream_cache[cache_key] = stream
    return stream


## WAV 帧数：字节数 / (位深字节 × 声道数)。生成包为 16bit，8bit 流按 1 字节兜底。
static func _wav_frame_count(wav: AudioStreamWAV) -> int:
    var bytes_per_sample := 2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1
    var channels := 2 if wav.stereo else 1
    return wav.data.size() / (bytes_per_sample * channels)


## 音频加载沿用直读惯例（无 .import，headless 安全）。仅供 load_cached 内部使用。
static func _load_stream(path: String) -> AudioStream:
    if path.is_empty() or not FileAccess.file_exists(path):
        return null
    if path.ends_with(".ogg"):
        return AudioStreamOggVorbis.load_from_file(path)
    if path.ends_with(".wav"):
        return AudioStreamWAV.load_from_file(path)
    return null


static func _short_chapter_id(chapter_id: String) -> String:
    for part in chapter_id.split("_"):
        var token := String(part)
        if token.length() >= 3 and token.begins_with("ch") and token.substr(2).is_valid_int():
            return token
    return "ch01"


# ---- 运行时状态机（战斗层轮询 / 摇篮曲距离 / Boss 相位；main_level 迁入）----

## main_level 注入 player 与敌群来源（func() -> Array，通常 group "enemy"）。
func bind_runtime(player: Node, get_enemies: Callable) -> void:
    runtime_player = player
    get_enemies_source = get_enemies


## 钟龛安坐：记录锚点并起摇篮曲；玩家走远由 _process 距离机自动收场。
func engage_shrine(anchor: Vector2) -> void:
    shrine_anchor = anchor
    shrine_engaged = true
    start_lullaby()


func _process(delta: float) -> void:
    _tick_shrine_lullaby()
    ai_poll_accum += delta
    if ai_poll_accum < COMBAT_POLL_INTERVAL_S:
        return
    var tick := ai_poll_accum
    ai_poll_accum = 0.0
    var enemies := _runtime_enemies()
    _tick_combat_layer(tick, enemies)
    _tick_boss_phase(enemies)


func _runtime_enemies() -> Array:
    if get_enemies_source.is_valid():
        var result: Variant = get_enemies_source.call()
        if typeof(result) == TYPE_ARRAY:
            return result
    return []


## 摇篮曲距离机：走远（>150px）收场；仍坐龛中且摇篮曲被 Boss 战打断过，
## Boss 收尾后在此自然重触发（修 Boss×摇篮曲互斥后的恢复路径）。
func _tick_shrine_lullaby() -> void:
    if not shrine_engaged:
        return
    var player_2d := runtime_player as Node2D
    if player_2d == null or not is_instance_valid(player_2d):
        return
    if player_2d.global_position.distance_to(shrine_anchor) > LULLABY_LEAVE_DISTANCE:
        shrine_engaged = false
        stop_lullaby()
    elif not lullaby_active and not boss_active:
        start_lullaby()


## 战斗层轮询：0.25s 一拍读取敌人 combat_engaged()（巡逻、回位、蛰伏、守点之外
## 即视为交战；旧接口按 last_ai_decision 的 patrol/return 判定），离战 4s 冷静期才收层（防抽泵）。
func _tick_combat_layer(tick: float, enemies: Array) -> void:
    var engaged := false
    for enemy_variant in enemies:
        var enemy_node := enemy_variant as Node
        if enemy_node == null or not is_instance_valid(enemy_node) or enemy_node.get("is_boss") == true:
            continue
        if enemy_node.has_method("world_residency_active") and not enemy_node.world_residency_active(): continue
        var decision_value: Variant = enemy_node.get("last_ai_decision")
        if typeof(decision_value) != TYPE_STRING:
            continue
        var decision := String(decision_value)
        # Lurking ambushers and guards at their post are calm, not combat.
        var in_combat := bool(enemy_node.combat_engaged()) if enemy_node.has_method("combat_engaged") else decision != "patrol" and decision != "return"
        if not decision.is_empty() and in_combat:
            engaged = true
            # An encounter has one quiet material voice accent, never one per poll.
            if not combat_active:
                play_enemy_alert(String(enemy_node.get("kind")), enemy_node as Node2D)
            break
    if engaged:
        combat_calm_time = 0.0
        enter_combat()
    elif combat_active:
        combat_calm_time += tick
        if combat_calm_time >= COMBAT_CALM_SECONDS:
            combat_calm_time = 0.0
            exit_combat()


## 终 Boss 三乐章钩子：enemy_actor 无血量相变系统，按 hp/max_hp 阈值（2/3、1/3）
## 驱动 set_boss_phase；非终 Boss 由 set_boss_phase 侧忽略换曲。
func _tick_boss_phase(enemies: Array) -> void:
    if not boss_active:
        return
    for enemy_variant in enemies:
        var enemy_node := enemy_variant as Node
        if enemy_node == null or not is_instance_valid(enemy_node) or enemy_node.get("is_boss") != true:
            continue
        var hp_value: Variant = enemy_node.get("hp")
        var max_hp_value: Variant = enemy_node.get("max_hp")
        if typeof(hp_value) != TYPE_INT or typeof(max_hp_value) != TYPE_INT:
            return
        var ratio := float(hp_value) / maxf(1.0, float(max_hp_value))
        var phase := 1
        if ratio <= 1.0 / 3.0:
            phase = 3
        elif ratio <= 2.0 / 3.0:
            phase = 2
        set_boss_phase(phase)
        return


# ---- 章节选曲 ----

## 探索播放器由 main_level 注入（节点名 BgmPlayer、bus=BGM，验证脚本按此断言）。
func attach_explore_player(player: AudioStreamPlayer) -> void:
    explore_player = player


func set_chapter(chapter_id: String) -> void:
    chapter_short_id = _short_chapter_id(chapter_id)
    _capture_base_reverb()
    if not autoplay_enabled:
        return
    _play_explore_track(_explore_track_path())
    _start_ambience()


func _chapter_slug() -> String:
    return String(CHAPTER_SLUGS.get(chapter_short_id, "ch01_moss_bell_court"))


func _explore_track_path() -> String:
    if chapter_short_id == "ch01":
        return LEGACY_EXPLORE_CH01
    return "res://assets/audio/bgm/generated/%s_explore_loop.ogg" % _chapter_slug()


func _combat_layer_path() -> String:
    return "res://assets/audio/bgm/generated/%s_combat_layer.ogg" % _chapter_slug()


func _lullaby_path() -> String:
    return "res://assets/audio/bgm/generated/%s_shrine_lullaby.ogg" % _chapter_slug()


func _ambience_bed_path() -> String:
    return "res://assets/audio/ambience/amb_%s_bed.ogg" % chapter_short_id


func _boss_track_path(boss_id: String, phase: int) -> String:
    if boss_id == FINAL_BOSS_ID:
        return String(FINAL_BOSS_MOVEMENTS[clampi(phase, 1, 3) - 1])
    var slug := String(BOSS_CHAPTER_SLUG.get(boss_id, ""))
    if slug.is_empty():
        return LEGACY_BOSS_CH01
    return "res://assets/audio/bgm/generated/%s_boss_loop.ogg" % slug


func _play_explore_track(path: String) -> void:
    var stream := load_cached(path, true)
    if stream == null:
        return
    if explore_player == null or not is_instance_valid(explore_player):
        explore_player = AudioStreamPlayer.new()
        explore_player.name = "MusicExplorePlayer"
        explore_player.bus = _bus_or("MusicExplore", "BGM")
        explore_player.volume_db = EXPLORE_DB
        add_child(explore_player)
    # Reapplying a region/room music state must not restart its audible phrase.
    if explore_player.stream == stream and (explore_player.playing or explore_player.stream_paused) and _explore_path == path:
        return
    _remember_explore_position()
    # A queued older region may still own the same phrase. Capture it before
    # transferring the lease; its later exit cannot overwrite this player.
    var previous_id := int(_explore_owners.get(path, 0))
    var previous := instance_from_id(previous_id) as AudioDirector if previous_id != 0 else null
    if is_instance_valid(previous) and previous != self:
        previous._remember_explore_position()
    if _explore_owners.get(_explore_path, 0) == get_instance_id(): _explore_owners.erase(_explore_path)
    _explore_path = path
    _explore_session = _explore_epoch
    _explore_owners[path] = get_instance_id()
    _kill_explore_tween()
    explore_player.stream_paused = false
    explore_player.stream = stream
    var position := float(_explore_resume.get(path, 0.0))
    var length := stream.get_length()
    if not is_finite(position) or position < 0.0: position = 0.0
    explore_player.play(fposmod(position, length) if length > 0.0 else 0.0)
    # 章节起播淡入：从静音 0.8s 升到基准（转场后新章不撞门）。
    if is_inside_tree():
        explore_player.volume_db = SILENT_DB
        explore_tween = create_tween()
        explore_tween.tween_property(explore_player, "volume_db", EXPLORE_DB, CHAPTER_ENTER_EXPLORE_FADE_S)
    else:
        explore_player.volume_db = EXPLORE_DB


func _remember_explore_position() -> void:
    if _explore_session != _explore_epoch or _explore_owners.get(_explore_path, 0) != get_instance_id(): return
    if not is_instance_valid(explore_player) or explore_player.stream == null: return
    if not explore_player.playing and not explore_player.stream_paused: return
    var position := explore_player.get_playback_position()
    if not is_finite(position) or position < 0.0: return
    _explore_resume.erase(_explore_path)
    _explore_resume[_explore_path] = position
    while _explore_resume.size() > MAX_EXPLORE_BOOKMARKS: _explore_resume.erase(_explore_resume.keys()[0])


static func clear_exploration_resume() -> void:
    _explore_epoch += 1
    _explore_resume.clear()
    _explore_owners.clear()


func _bus_or(bus_name: String, fallback: String) -> String:
    if AudioServer.get_bus_index(bus_name) != -1:
        return bus_name
    return fallback if AudioServer.get_bus_index(fallback) != -1 else "Master"


# ---- 探索曲淡入淡出工具（Boss 进出 / 摇篮曲交叉淡化共用）----

func _kill_explore_tween() -> void:
    if explore_tween != null and explore_tween.is_valid():
        explore_tween.kill()


## 淡出至暂停（非硬停）：seconds 秒滑到静音后 stream_paused，音量复位基准备用。
func _fade_explore_to_pause(seconds: float) -> void:
    if explore_player == null or not is_instance_valid(explore_player):
        return
    _kill_explore_tween()
    if not is_inside_tree() or not explore_player.playing or explore_player.stream_paused:
        explore_player.stream_paused = true
        explore_player.volume_db = EXPLORE_DB
        return
    explore_tween = create_tween()
    explore_tween.tween_property(explore_player, "volume_db", SILENT_DB, seconds)
    explore_tween.tween_callback(_finish_explore_pause)


func _finish_explore_pause() -> void:
    if explore_player == null or not is_instance_valid(explore_player):
        return
    explore_player.stream_paused = true
    explore_player.volume_db = EXPLORE_DB


## 恢复：解除暂停，从基准 -12dB 淡回基准。
func _fade_explore_resume(seconds: float) -> void:
    if explore_player == null or not is_instance_valid(explore_player):
        return
    _kill_explore_tween()
    explore_player.stream_paused = false
    if not is_inside_tree():
        explore_player.volume_db = EXPLORE_DB
        return
    explore_player.volume_db = EXPLORE_DB + EXPLORE_RESUME_FROM_DB
    explore_tween = create_tween()
    explore_tween.tween_property(explore_player, "volume_db", EXPLORE_DB, seconds)


# ---- 探索/战斗音乐层（规格 §2.2）----

func enter_combat() -> void:
    if combat_active:
        return
    combat_active = true
    if not autoplay_enabled or boss_active:
        return
    var stream := load_cached(_combat_layer_path(), true)
    if stream == null:
        return
    if combat_player == null or not is_instance_valid(combat_player):
        combat_player = AudioStreamPlayer.new()
        combat_player.name = "MusicCombatLayer"
        combat_player.bus = _bus_or("MusicCombat", "BGM")
        combat_player.volume_db = SILENT_DB
        add_child(combat_player)
    if combat_tween != null and combat_tween.is_valid():
        combat_tween.kill()
    if combat_player.playing:
        # 离战淡出中复进战：取消淡出直接回满（流走缓存无 IO，防抽泵）。
        combat_player.volume_db = COMBAT_LAYER_DB
        return
    combat_player.stream = stream
    combat_player.volume_db = SILENT_DB
    combat_player.play()
    if is_inside_tree():
        combat_tween = create_tween()
        combat_tween.tween_property(combat_player, "volume_db", COMBAT_LAYER_DB, 0.8)
    else:
        combat_player.volume_db = COMBAT_LAYER_DB


func exit_combat() -> void:
    if not combat_active:
        return
    combat_active = false
    if combat_player == null or not is_instance_valid(combat_player) or not combat_player.playing:
        return
    if combat_tween != null and combat_tween.is_valid():
        combat_tween.kill()
    if is_inside_tree():
        combat_tween = create_tween()
        combat_tween.tween_property(combat_player, "volume_db", SILENT_DB, 2.5)
        combat_tween.tween_callback(combat_player.stop)
    else:
        combat_player.stop()


## Boss 进场收战斗层：0.3s 快速淡出后停（原为硬停）。
func _fade_out_combat_layer() -> void:
    if combat_tween != null and combat_tween.is_valid():
        combat_tween.kill()
    if combat_player == null or not is_instance_valid(combat_player) or not combat_player.playing:
        return
    if not is_inside_tree():
        combat_player.stop()
        return
    combat_tween = create_tween()
    combat_tween.tween_property(combat_player, "volume_db", SILENT_DB, BOSS_ENTER_COMBAT_FADE_S)
    combat_tween.tween_callback(combat_player.stop)


# ---- Boss 曲（规格 §3；终 Boss 三乐章）----

func start_boss_music(boss_id: String) -> void:
    if boss_active and active_boss_id == boss_id \
            and boss_player != null and is_instance_valid(boss_player) and boss_player.playing:
        return
    boss_active = true
    active_boss_id = boss_id
    boss_phase = 1
    if not autoplay_enabled:
        return
    # 摇篮曲×Boss 互斥：boss_active 已置位，stop_lullaby 不会误恢复探索曲。
    if lullaby_active:
        stop_lullaby()
    if boss_id == FINAL_BOSS_ID:
        # 终 Boss 三乐章预载进流缓存：相变切换零磁盘 IO。
        for movement_path in FINAL_BOSS_MOVEMENTS:
            load_cached(String(movement_path), true)
    _fade_out_combat_layer()
    _fade_explore_to_pause(BOSS_ENTER_EXPLORE_FADE_S)
    var stream := load_cached(_boss_track_path(boss_id, 1), true)
    if stream == null:
        return
    if boss_player == null or not is_instance_valid(boss_player):
        boss_player = AudioStreamPlayer.new()
        boss_player.name = "MusicBossPlayer"
        boss_player.bus = _bus_or("MusicCombat", "BGM")
        add_child(boss_player)
    _kill_boss_tween()
    boss_player.volume_db = BOSS_DB
    boss_player.stream = stream
    boss_player.play()


func set_boss_phase(p: int) -> void:
    if not boss_active or p == boss_phase:
        return
    boss_phase = clampi(p, 1, 3)
    if not autoplay_enabled or active_boss_id != FINAL_BOSS_ID:
        return
    if boss_player == null or not is_instance_valid(boss_player):
        return
    var stream := load_cached(_boss_track_path(active_boss_id, boss_phase), true)
    if stream == null:
        return
    boss_player.stream = stream
    boss_player.play()


func stop_boss_music() -> void:
    if not boss_active and active_boss_id.is_empty():
        return
    boss_active = false
    active_boss_id = ""
    boss_phase = 0
    _kill_boss_tween()
    if boss_player != null and is_instance_valid(boss_player) and boss_player.playing:
        if is_inside_tree():
            # Boss 曲 0.8s 淡出（原为硬停）。
            boss_tween = create_tween()
            boss_tween.tween_property(boss_player, "volume_db", SILENT_DB, BOSS_EXIT_FADE_S)
            boss_tween.tween_callback(_finish_boss_stop)
        else:
            _finish_boss_stop()
    if autoplay_enabled and not lullaby_active:
        # 探索曲从 -12dB 1.2s 淡入恢复。
        _fade_explore_resume(BOSS_EXIT_EXPLORE_FADE_S)


func _kill_boss_tween() -> void:
    if boss_tween != null and boss_tween.is_valid():
        boss_tween.kill()


func _finish_boss_stop() -> void:
    if boss_player != null and is_instance_valid(boss_player):
        boss_player.stop()
        boss_player.volume_db = BOSS_DB


# ---- 钟龛摇篮曲（规格 §2.1）----

func start_lullaby() -> void:
    if lullaby_active:
        return
    if boss_active:
        # Boss 战中不进摇篮曲且不置位（修死锁）：Boss 收尾后由 _tick_shrine_lullaby 重触发。
        return
    lullaby_active = true
    if not autoplay_enabled:
        return
    var stream := load_cached(_lullaby_path(), true)
    if stream == null:
        return
    if lullaby_player == null or not is_instance_valid(lullaby_player):
        lullaby_player = AudioStreamPlayer.new()
        lullaby_player.name = "MusicLullabyPlayer"
        lullaby_player.bus = _bus_or("MusicExplore", "BGM")
        add_child(lullaby_player)
    # 交叉淡化：探索曲 0.8s 淡出至暂停（非硬停），摇篮曲同步淡入。
    _fade_explore_to_pause(LULLABY_EXPLORE_FADE_S)
    lullaby_player.stream = stream
    lullaby_player.volume_db = SILENT_DB
    lullaby_player.play()
    if lullaby_tween != null and lullaby_tween.is_valid():
        lullaby_tween.kill()
    if is_inside_tree():
        lullaby_tween = create_tween()
        lullaby_tween.tween_property(lullaby_player, "volume_db", LULLABY_DB, 0.8)
    else:
        lullaby_player.volume_db = LULLABY_DB


func stop_lullaby() -> void:
    if not lullaby_active:
        return
    lullaby_active = false
    if lullaby_player != null and is_instance_valid(lullaby_player) and lullaby_player.playing:
        if lullaby_tween != null and lullaby_tween.is_valid():
            lullaby_tween.kill()
        if is_inside_tree():
            lullaby_tween = create_tween()
            lullaby_tween.tween_property(lullaby_player, "volume_db", SILENT_DB, 1.2)
            lullaby_tween.tween_callback(lullaby_player.stop)
        else:
            lullaby_player.stop()
    if autoplay_enabled and not boss_active:
        # 退出对称交叉淡化：探索曲 0.8s 淡入恢复。
        _fade_explore_resume(LULLABY_EXPLORE_FADE_S)


## 音乐性 stinger，走 MusicStinger 子总线。触发点约定：
## - "bellway_depart"/"bellway_arrive"：钟道启程/到站演出（预留接线）。
## - "ending_a"/"ending_b"/"ending_c"：main_level._activate_ending_gate 抉择确认后
##   紧随短 stinger 播三结局全曲。
func play_stinger(key: String) -> void:
    if not autoplay_enabled:
        return
    var stream := load_cached(String(STINGER_TRACKS.get(key, "")))
    if stream == null:
        return
    if stinger_player == null or not is_instance_valid(stinger_player):
        stinger_player = AudioStreamPlayer.new()
        stinger_player.name = "MusicStingerPlayer"
        stinger_player.bus = _bus_or("MusicStinger", "BGM")
        stinger_player.volume_db = STINGER_DB
        add_child(stinger_player)
    stinger_player.stream = stream
    stinger_player.play()


# ---- 环境床与稀疏 one-shot（规格 §4.6）----

func _start_ambience() -> void:
    var bed_stream := load_cached(_ambience_bed_path(), true)
    if bed_stream != null:
        if ambience_bed_player == null or not is_instance_valid(ambience_bed_player):
            ambience_bed_player = AudioStreamPlayer.new()
            ambience_bed_player.name = "AmbienceBedPlayer"
            ambience_bed_player.bus = _bus_or("Ambience", "Master")
            ambience_bed_player.volume_db = AMBIENCE_BED_DB
            add_child(ambience_bed_player)
        if ambience_bed_player.stream != bed_stream or not ambience_bed_player.playing:
            ambience_bed_player.stream = bed_stream
            ambience_bed_player.play()
    oneshot_variant_count = _probe_oneshot_variant_count()
    if oneshot_timer == null or not is_instance_valid(oneshot_timer):
        oneshot_timer = Timer.new()
        oneshot_timer.name = "AmbienceOneShotTimer"
        oneshot_timer.one_shot = true
        oneshot_timer.timeout.connect(_on_oneshot_timer)
        add_child(oneshot_timer)
    oneshot_timer.start(randf_range(ONESHOT_INTERVAL_MIN_S, ONESHOT_INTERVAL_MAX_S))
    if chapter_short_id == "ch02":
        # ch02 远砧：雨铸运河的远处锻打声，独立稀疏调度。
        if anvil_timer == null or not is_instance_valid(anvil_timer):
            anvil_timer = Timer.new()
            anvil_timer.name = "AmbienceAnvilTimer"
            anvil_timer.one_shot = true
            anvil_timer.timeout.connect(_on_anvil_timer)
            add_child(anvil_timer)
        anvil_timer.start(randf_range(ANVIL_INTERVAL_MIN_S, ANVIL_INTERVAL_MAX_S))


## one-shot 变体数按实际文件探测（当前各章 8 个；增删文件无需改码）。
func _probe_oneshot_variant_count() -> int:
    var count := 0
    while count < 32 and FileAccess.file_exists("res://assets/audio/ambience/amb_%s_os_%d.ogg" % [chapter_short_id, count + 1]):
        count += 1
    return count


func _on_oneshot_timer() -> void:
    if oneshot_variant_count > 0:
        var path := "res://assets/audio/ambience/amb_%s_os_%d.ogg" % [chapter_short_id, randi_range(1, oneshot_variant_count)]
        _play_ambience_oneshot(path, AMBIENCE_ONESHOT_DB)
    oneshot_timer.start(randf_range(ONESHOT_INTERVAL_MIN_S, ONESHOT_INTERVAL_MAX_S))


func _on_anvil_timer() -> void:
    _play_ambience_oneshot("res://assets/audio/ambience/amb_ch02_anvil_far.ogg", ANVIL_FAR_DB)
    anvil_timer.start(randf_range(ANVIL_INTERVAL_MIN_S, ANVIL_INTERVAL_MAX_S))


func _play_ambience_oneshot(path: String, volume_db: float) -> void:
    if not autoplay_enabled:
        return
    var voice_ticket := reserve_voice("amb_oneshot", 2, 250, 2)
    if voice_ticket == 0:
        return
    var stream := load_cached(path)
    if stream == null:
        release_ticket(voice_ticket)
        return
    var player_node := AudioStreamPlayer.new()
    player_node.name = "AmbienceOneShot"
    player_node.bus = _bus_or("Ambience", "Master")
    player_node.stream = stream
    player_node.volume_db = volume_db
    add_child(player_node)
    player_node.finished.connect(Callable(player_node, "queue_free"))
    start_reserved_voice(voice_ticket,player_node)


# ---- 混音状态（规格 §5.3/§5.5）----

## 兼容既有 duck_bgm 语义：BGM 总线压低 db、保持 hold 秒后回弹到基准。
## release 段不快照基准：每步实时读 _music_rest_db()，对话开合/用户调音量
## 与 duck 竞态时回弹不会打到过期终点。
func duck(db: float, hold: float, attack: float = 0.35, release: float = 0.6) -> void:
    var bus_index := AudioServer.get_bus_index("BGM")
    if bus_index == -1 or not is_inside_tree():
        return
    if duck_tween != null and duck_tween.is_valid():
        duck_tween.kill()
    var ducked_db := _music_rest_db() + minf(db, 0.0)
    duck_tween = create_tween()
    duck_tween.tween_method(_set_music_bus_db, AudioServer.get_bus_volume_db(bus_index), ducked_db, maxf(attack, 0.01))
    duck_tween.tween_interval(maxf(hold, 0.0))
    duck_tween.tween_method(func(t: float) -> void: _set_music_bus_db(lerpf(ducked_db, _music_rest_db(), t)), 0.0, 1.0, maxf(release, 0.01))
    duck_tween.tween_callback(func() -> void: _set_music_bus_db(_music_rest_db()))


func on_dialogue(open: bool) -> void:
    if open == dialogue_open:
        return
    dialogue_open = open
    if not open and _npc_voice_player != null and is_instance_valid(_npc_voice_player):
        _npc_voice_player.stop()
    # duck 与对话共写 BGM 总线：对话开合即中止在途 duck，由 rest 基准接管。
    if duck_tween != null and duck_tween.is_valid():
        duck_tween.kill()
    _tween_bus_db("BGM", _music_rest_db(), 0.25)
    _tween_bus_db("Ambience", _ambience_rest_db(), 0.25)


func on_key_item_pickup() -> void:
    duck(-6.0, 1.4)


## 章节转场（main_level._activate_chapter_exit 调用）：BGM 总线 0.5s 淡出；
## 新章 _ensure_audio_buses + _load_user_volumes 会复位到用户基准。
func begin_chapter_transition() -> void:
    if duck_tween != null and duck_tween.is_valid():
        duck_tween.kill()
    _tween_bus_db("BGM", SILENT_DB, CHAPTER_EXIT_BGM_FADE_S)


func cancel_chapter_transition() -> void:
    var transition: Tween = bus_tweens.get("BGM")
    if transition != null and transition.is_valid():
        transition.kill()
    bus_tweens.erase("BGM")
    _apply_user_volume("music")


## 房型混响微调：hub/vista wet +0.10、corridor/secret wet -0.08，0.6s tween 回归基准。
## transit 房同时驱动钟道站厅音乐层。
func on_room_changed(kind: String) -> void:
    _update_transit_loop(kind == "transit")
    var delta := float(ROOM_REVERB_WET_DELTA.get(kind, 0.0))
    for bus_name in ["SFX", "Ambience"]:
        var reverb := _bus_reverb(String(bus_name))
        if reverb == null:
            continue
        var target: float = clampf(float(base_reverb_wet.get(bus_name, reverb.wet)) + delta, 0.0, 1.0)
        var old_tween: Tween = reverb_tweens.get(bus_name)
        if old_tween != null and old_tween.is_valid():
            old_tween.kill()
        if not is_inside_tree():
            reverb.wet = target
            continue
        var tween := create_tween()
        tween.tween_property(reverb, "wet", target, 0.6)
        reverb_tweens[bus_name] = tween


## 钟道站厅音乐层：transit 房以 -10dB 在 MusicStinger 总线起 bellway_transit_loop
## 循环，离开 transit 房 1s 淡出。
func _update_transit_loop(in_transit: bool) -> void:
    if in_transit:
        if not autoplay_enabled:
            return
        if transit_tween != null and transit_tween.is_valid():
            transit_tween.kill()
        if transit_player != null and is_instance_valid(transit_player) and transit_player.playing:
            transit_player.volume_db = TRANSIT_LOOP_DB
            return
        var stream := load_cached(BELLWAY_TRANSIT_LOOP, true)
        if stream == null:
            return
        if transit_player == null or not is_instance_valid(transit_player):
            transit_player = AudioStreamPlayer.new()
            transit_player.name = "BellwayTransitLoop"
            transit_player.bus = _bus_or("MusicStinger", "BGM")
            add_child(transit_player)
        transit_player.stream = stream
        transit_player.volume_db = TRANSIT_LOOP_DB
        transit_player.play()
        return
    if transit_player == null or not is_instance_valid(transit_player) or not transit_player.playing:
        return
    if transit_tween != null and transit_tween.is_valid():
        transit_tween.kill()
    if not is_inside_tree():
        transit_player.stop()
        return
    transit_tween = create_tween()
    transit_tween.tween_property(transit_player, "volume_db", SILENT_DB, TRANSIT_LOOP_FADE_OUT_S)
    transit_tween.tween_callback(transit_player.stop)


## 濒死低通扫频：2kHz 起 2s 滑到 800Hz。关断需当帧移除效果
## （audio_visual_validation 同帧断言），反向扫频以瞬时摘除代偿。
func set_low_hp(active: bool) -> void:
    if active == low_hp_active:
        return
    low_hp_active = active
    var bus_index := AudioServer.get_bus_index("BGM")
    if bus_index == -1:
        return
    if low_hp_tween != null and low_hp_tween.is_valid():
        low_hp_tween.kill()
    var effect_index := _find_bus_effect(bus_index, "AudioEffectLowPassFilter")
    if active:
        var lowpass: AudioEffectLowPassFilter
        if effect_index == -1:
            lowpass = AudioEffectLowPassFilter.new()
            lowpass.cutoff_hz = LOW_HP_SWEEP_START_HZ
            AudioServer.add_bus_effect(bus_index, lowpass)
        else:
            lowpass = AudioServer.get_bus_effect(bus_index, effect_index) as AudioEffectLowPassFilter
        if lowpass == null:
            return
        if is_inside_tree():
            low_hp_tween = create_tween()
            low_hp_tween.tween_property(lowpass, "cutoff_hz", LOW_HP_SWEEP_TARGET_HZ, LOW_HP_SWEEP_SECONDS)
        else:
            lowpass.cutoff_hz = LOW_HP_SWEEP_TARGET_HZ
    elif effect_index != -1:
        AudioServer.remove_bus_effect(bus_index, effect_index)


## 玩家死亡：全总线 300Hz 低通（挂 Master）+ duck，1.6s 后自清防跨场景残留。
func on_player_death() -> void:
    duck(-10.0, 1.2)
    var master_index := AudioServer.get_bus_index("Master")
    if master_index == -1:
        return
    if _find_bus_effect(master_index, "AudioEffectLowPassFilter") == -1:
        var lowpass := AudioEffectLowPassFilter.new()
        lowpass.cutoff_hz = DEATH_LOWPASS_HZ
        AudioServer.add_bus_effect(master_index, lowpass)
    if death_tween != null and death_tween.is_valid():
        death_tween.kill()
    if is_inside_tree():
        death_tween = create_tween()
        death_tween.tween_interval(1.6)
        death_tween.tween_callback(_clear_death_lowpass)
    else:
        _clear_death_lowpass()


func _clear_death_lowpass() -> void:
    var master_index := AudioServer.get_bus_index("Master")
    if master_index == -1:
        return
    var effect_index := _find_bus_effect(master_index, "AudioEffectLowPassFilter")
    if effect_index != -1:
        AudioServer.remove_bus_effect(master_index, effect_index)


# ---- 用户音量（持久化 user://audio_settings.cfg）----

func set_user_volume(which: String, percent: float) -> void:
    if not USER_VOLUME_BUS.has(which) or not is_finite(percent):
        return
    user_volumes[which] = clampf(percent, 0.0, 100.0)
    _apply_user_volume(which)
    _save_user_volumes()


func get_user_volume(which: String) -> float:
    return float(user_volumes.get(which, 100.0))


func _apply_user_volume(which: String) -> void:
    var bus_name := String(USER_VOLUME_BUS.get(which, "Master"))
    var target := _bus_base_db(which)
    if which == "music":
        target = _music_rest_db()
        # 用户改音乐音量直写 BGM 总线：中止在途 duck，避免回弹覆盖新基准。
        if duck_tween != null and duck_tween.is_valid():
            duck_tween.kill()
    elif which == "ambience":
        target = _ambience_rest_db()
    # A user edit owns the new level, including a dialogue/transition envelope
    # that was created with a previous slider value.
    var envelope: Tween = bus_tweens.get(bus_name)
    if envelope != null and envelope.is_valid():
        envelope.kill()
    bus_tweens.erase(bus_name)
    _set_bus_db(bus_name, target)
    _set_user_mute(bus_name, get_user_volume(which) <= 0.0)
    if which == "sfx":
        # Heartbeats stay dry (send -> Master), but still obey the SFX slider.
        _set_bus_db("SFXDry", _user_db("sfx"))
        _set_user_mute("SFXDry", get_user_volume("sfx") <= 0.0)


func _set_user_mute(bus_name: String, muted: bool) -> void:
    var index := AudioServer.get_bus_index(bus_name)
    if index >= 0:
        AudioServer.set_bus_mute(index, muted)


func _load_user_volumes() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(settings_path) == OK:
        for which in user_volumes.keys():
            # cfg 容错：仅接受有限 float/int，非法值保持默认 100 且不回写污染存档。
            var raw: Variant = cfg.get_value("volumes", String(which), float(user_volumes[which]))
            if (typeof(raw) == TYPE_FLOAT or typeof(raw) == TYPE_INT) and is_finite(float(raw)):
                user_volumes[which] = clampf(float(raw), 0.0, 100.0)
    for which in user_volumes.keys():
        _apply_user_volume(String(which))


func _save_user_volumes() -> void:
    var cfg := ConfigFile.new()
    for which in user_volumes.keys():
        cfg.set_value("volumes", String(which), float(user_volumes[which]))
    cfg.save(settings_path)


# ---- 电平/混响工具 ----

func _user_db(which: String) -> float:
    var percent: float = clampf(float(user_volumes.get(which, 100.0)), 0.0, 100.0)
    if percent <= 0.0:
        return -80.0
    return linear_to_db(percent / 100.0)


func _bus_base_db(which: String) -> float:
    var bus_name := String(USER_VOLUME_BUS.get(which, "Master"))
    return float(BUS_DEFAULT_DB.get(bus_name, 0.0)) + _user_db(which)


func _music_rest_db() -> float:
    return _bus_base_db("music") + (DIALOGUE_MUSIC_DUCK_DB if dialogue_open else 0.0)


func _ambience_rest_db() -> float:
    return _bus_base_db("ambience") + (DIALOGUE_AMBIENCE_DUCK_DB if dialogue_open else 0.0)


func _set_bus_db(bus_name: String, value: float) -> void:
    var bus_index := AudioServer.get_bus_index(bus_name)
    if bus_index != -1:
        AudioServer.set_bus_volume_db(bus_index, value)


func _set_music_bus_db(value: float) -> void:
    _set_bus_db("BGM", value)


func _tween_bus_db(bus_name: String, target: float, seconds: float) -> void:
    var bus_index := AudioServer.get_bus_index(bus_name)
    if bus_index == -1:
        return
    var old_tween: Tween = bus_tweens.get(bus_name)
    if old_tween != null and old_tween.is_valid():
        old_tween.kill()
    if not is_inside_tree():
        AudioServer.set_bus_volume_db(bus_index, target)
        return
    var tween := create_tween()
    tween.tween_method(func(value: float) -> void: _set_bus_db(bus_name, value), AudioServer.get_bus_volume_db(bus_index), target, seconds)
    bus_tweens[bus_name] = tween


func _capture_base_reverb() -> void:
    for bus_name in ["SFX", "Ambience"]:
        var reverb := _bus_reverb(String(bus_name))
        if reverb != null:
            base_reverb_wet[bus_name] = reverb.wet


func _bus_reverb(bus_name: String) -> AudioEffectReverb:
    var bus_index := AudioServer.get_bus_index(bus_name)
    if bus_index == -1:
        return null
    var effect_index := _find_bus_effect(bus_index, "AudioEffectReverb")
    if effect_index == -1:
        return null
    return AudioServer.get_bus_effect(bus_index, effect_index) as AudioEffectReverb



## Short original nonverbal greeting. The Chinese subtitle carries all meaning;
## this is deliberately not synthetic Chinese speech or a borrowed game voice.
## One dedicated player replaces the previous greeting; no syllable-per-letter spam.
func play_npc_voice(npc_id: String, line: String, profile: String = "warm") -> bool:
    if line.strip_edges().is_empty() or not is_inside_tree():
        return false
    var key := "npc_greeting_" + npc_id
    var voice_ticket := reserve_voice(key, 2, 450, 1)
    if voice_ticket == 0:
        return false
    var stream := npc_voice_stream(profile)
    if _npc_voice_player == null or not is_instance_valid(_npc_voice_player):
        _npc_voice_player = AudioStreamPlayer.new()
        _npc_voice_player.name = "NPCNonverbalVoice"
        _npc_voice_player.bus = _bus_or("SFXWorld", "SFX")
        _npc_voice_player.volume_db = -13.0
        add_child(_npc_voice_player)
    _npc_voice_player.stream = stream
    _npc_voice_player.pitch_scale = 0.96 + float(abs(npc_id.hash()) % 9) * 0.01
    return start_reserved_voice(voice_ticket,_npc_voice_player,true)


static func npc_voice_stream(profile: String) -> AudioStreamWAV:
    var frequencies := {"warm": 185.0, "bright": 315.0, "low": 105.0, "hushed": 235.0, "dry": 155.0}
    var resolved := profile if frequencies.has(profile) else "warm"
    if _npc_voice_cache.has(resolved):
        return _npc_voice_cache[resolved]
    var frequency := float(frequencies[resolved])
    var sample_rate := 22050
    var duration := 0.24 if resolved != "hushed" else 0.19
    var frames := int(duration * sample_rate)
    var bytes := PackedByteArray()
    bytes.resize(frames * 2)
    for index in frames:
        var t := float(index) / float(sample_rate)
        var progress := float(index) / float(frames)
        # Smooth breath envelope, harmonic vowel and gentle rising inflection.
        var envelope := sin(PI * progress) * sin(PI * progress)
        var phase := TAU * frequency * (t + 0.12 * t * t / duration)
        var voice := sin(phase) * 0.67 + sin(phase * 2.0) * 0.21 + sin(phase * 3.0) * 0.08
        var pulse := 0.72 + 0.28 * sin(TAU * 7.0 * t)
        bytes.encode_s16(index * 2, int(clampf(voice * envelope * pulse * 0.38, -1.0, 1.0) * 32767.0))
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = sample_rate
    stream.data = bytes
    _npc_voice_cache[resolved] = stream
    return stream


## Optional vocal accent for enemy alert, separate from existing impact/death SFX.
## Call only on an AI transition into aggro, not every AI poll or strike.
func play_enemy_alert(kind: String, source: Node2D = null) -> bool:
    var spatial := preload("res://scripts/spatial_enemy_alert.gd")
    var listener := runtime_player as Node2D
    if not is_instance_valid(source) or not is_instance_valid(listener): return false
    if source.is_queued_for_deletion() or listener.is_queued_for_deletion(): return false
    if not source.is_inside_tree() or not listener.is_inside_tree(): return false
    if source.get_world_2d() != listener.get_world_2d(): return false
    if not spatial.in_range(source.global_position, listener.global_position): return false
    var family := "soft"
    if kind.contains("knight") or kind.contains("lancer") or kind.contains("spearman"):
        family = "armor"
    elif kind.contains("mite") or kind.contains("crawler") or kind.contains("bee"):
        family = "shell"
    var key := "enemy_alert_" + family
    if not is_inside_tree():return false
    var voice_ticket := reserve_voice(key,2,1800,1)
    if voice_ticket == 0:
        return false
    var path := "res://assets/audio/sfx/generated/enemy_hit_%s.ogg" % family
    var stream := load_cached(path)
    if stream == null:
        release_ticket(voice_ticket)
        return false
    var voice := spatial.new()
    voice.bus = _bus_or("SFXEnemy", "SFX")
    voice.pitch_scale = 0.72 if family == "armor" else 1.24
    voice.stream = stream
    add_child(voice)
    if not voice.place(source.global_position, listener):
        voice.free()
        release_voice(key)
        return false
    voice.finished.connect(voice.queue_free)
    return start_reserved_voice(voice_ticket,voice)
