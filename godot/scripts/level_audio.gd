extends RefCounted
## Level-side audio: buses, BGM switching, low-HP heartbeat and one-shot sound effects. Chapter reverb stays in main_level.gd, where the room-reverb contract reads it.
## Moved out of main_level.gd unchanged in behaviour; the level keeps one-line
## methods of the same names, so callers and validations are unaffected.
const AUDIO_DIRECTOR_SCRIPT := preload("res://scripts/audio_director.gd")

static func build_audio(level: Node) -> void:
    level._begin_audio()
    level._start_audio_explore()
    level._start_audio_ambience()


static func begin_audio(level: Node) -> void:
    if level.config.is_empty():
        return
    level._ensure_audio_buses()
    level._apply_chapter_reverb(String(level.config.get("id", "")))
    # AudioDirector 一期：不注册 autoload，由本函数实例化挂树（headless 验证脚本
    # 不跑主场景时 instance 保持 null，各薄封装回退旧行为）。
    level.audio_director = AUDIO_DIRECTOR_SCRIPT.new()
    level.audio_director.name = "AudioDirector"
    level.audio_director.autoplay_enabled = level._should_autoplay_audio()
    level.add_child(level.audio_director)
    if level._should_autoplay_audio():
        # 探索播放器仍叫 BgmPlayer、挂本节点、bus=BGM（audio_visual_validation 口径）。
        level._ensure_bgm_player()
        level.audio_director.attach_explore_player(level.bgm_player)
    level.audio_director.prepare_chapter(String(level.config.get("id", "")))


static func start_audio_explore(level: Node) -> void:
    if not level.is_queued_for_deletion() and is_instance_valid(level.audio_director) and level.audio_director.autoplay_enabled:
        level.audio_director._play_explore_track(level.audio_director._explore_track_path())


static func start_audio_ambience(level: Node) -> void:
    if not level.is_queued_for_deletion() and is_instance_valid(level.audio_director) and level.audio_director.autoplay_enabled:
        level.audio_director._start_ambience()


static func bind_audio_settings_key(level: Node) -> void:
    if not InputMap.has_action("audio_settings"):
        InputMap.add_action("audio_settings")
    if InputMap.action_get_events("audio_settings").is_empty():
        var event := InputEventKey.new()
        event.physical_keycode = KEY_V
        InputMap.action_add_event("audio_settings", event)


static func ensure_audio_buses(level: Node) -> void:
    for bus_name in level.AUDIO_BUSES:
        if AudioServer.get_bus_index(bus_name) == -1:
            AUDIO_DIRECTOR_SCRIPT._ensure_bus(String(bus_name), "Master")
        var bus_index := AudioServer.get_bus_index(bus_name)
        AudioServer.set_bus_volume_db(bus_index, float(level.AUDIO_BUS_DEFAULT_VOLUME_DB.get(bus_name, 0.0)))
    for reverb_bus_name in ["SFX", "Ambience"]:
        var reverb_bus := AudioServer.get_bus_index(reverb_bus_name)
        if reverb_bus != -1 and level._find_bus_effect(reverb_bus, "AudioEffectReverb") == -1:
            AudioServer.add_bus_effect(reverb_bus, AudioEffectReverb.new())
    level.low_hp_audio_active = false
    var bgm_bus := AudioServer.get_bus_index("BGM")
    if bgm_bus != -1:
        var stale_lowpass: int = level._find_bus_effect(bgm_bus, "AudioEffectLowPassFilter")
        if stale_lowpass != -1:
            AudioServer.remove_bus_effect(bgm_bus, stale_lowpass)
    # 子总线（MusicExplore/MusicCombat/MusicStinger/SFX*/ReverbZone）转调 director 幂等补建。
    AUDIO_DIRECTOR_SCRIPT.ensure_sub_buses()


static func duck_bgm(level: Node, duck_db: float, seconds: float) -> void:
    var director: AUDIO_DIRECTOR_SCRIPT = AUDIO_DIRECTOR_SCRIPT.instance
    if director != null and director.is_inside_tree():
        director.duck(duck_db, seconds)
        return
    var bus_index := AudioServer.get_bus_index("BGM")
    if bus_index == -1 or not level.is_inside_tree():
        return
    if level.bgm_duck_tween != null and level.bgm_duck_tween.is_valid():
        level.bgm_duck_tween.kill()
    var base_db := float(level.AUDIO_BUS_DEFAULT_VOLUME_DB.get("BGM", 0.0))
    var ducked_db := base_db + minf(duck_db, 0.0)
    level.bgm_duck_tween = level._region_tween()
    level.bgm_duck_tween.tween_method(level._set_bgm_bus_volume_db, AudioServer.get_bus_volume_db(bus_index), ducked_db, 0.35)
    level.bgm_duck_tween.tween_interval(maxf(seconds, 0.0))
    level.bgm_duck_tween.tween_method(level._set_bgm_bus_volume_db, ducked_db, base_db, 0.6)


static func set_bgm_bus_volume_db(level: Node, value: float) -> void:
    var bus_index := AudioServer.get_bus_index("BGM")
    if bus_index != -1:
        AudioServer.set_bus_volume_db(bus_index, value)


static func set_low_hp_audio(level: Node, active: bool) -> void:
    if active == level.low_hp_audio_active:
        return
    level.low_hp_audio_active = active
    if active:
        level._start_low_hp_heartbeat()
    else:
        level._stop_low_hp_heartbeat()
    # AudioDirector 在场时低通改扫频版（2kHz→800Hz 2s；关断当帧摘除），缺席回退旧行为。
    var director: AUDIO_DIRECTOR_SCRIPT = AUDIO_DIRECTOR_SCRIPT.instance
    if director != null:
        director.set_low_hp(active)
        return
    var bus_index := AudioServer.get_bus_index("BGM")
    if bus_index == -1:
        return
    var effect_index: int = level._find_bus_effect(bus_index, "AudioEffectLowPassFilter")
    if active and effect_index == -1:
        var lowpass := AudioEffectLowPassFilter.new()
        lowpass.cutoff_hz = level.LOW_HP_LOWPASS_CUTOFF_HZ
        AudioServer.add_bus_effect(bus_index, lowpass)
    elif not active and effect_index != -1:
        AudioServer.remove_bus_effect(bus_index, effect_index)


static func start_low_hp_heartbeat(level: Node) -> void:
    if not level._should_autoplay_audio():
        return
    if level.low_hp_heartbeat_player == null or not is_instance_valid(level.low_hp_heartbeat_player):
        # 循环标记由 load_cached(looped=true) 在入缓存前置好，不再原地改流。
        var stream = AUDIO_DIRECTOR_SCRIPT.load_cached(String(level.AUDIO.get("low_hp_heartbeat", "")), true)
        if stream == null:
            return
        level.low_hp_heartbeat_player = AudioStreamPlayer.new()
        level.low_hp_heartbeat_player.name = "LowHpHeartbeat"
        # 濒死心跳走 SFXDry（send→Master 干声）：不吃章节混响，贴耳而非贴房间。
        level.low_hp_heartbeat_player.bus = level._first_existing_bus(["SFXDry", "SFX", "Master"])
        level.low_hp_heartbeat_player.stream = stream
        level.low_hp_heartbeat_player.volume_db = -10.0
        level.add_child(level.low_hp_heartbeat_player)
    if not level.low_hp_heartbeat_player.playing:
        var ticket = AUDIO_DIRECTOR_SCRIPT.reserve_voice("low_hp_heartbeat",0,0,1)
        if ticket != 0:AUDIO_DIRECTOR_SCRIPT.start_reserved_voice(ticket,level.low_hp_heartbeat_player,true)


static func first_existing_bus(level: Node, bus_names: Array) -> String:
    for bus_name in bus_names:
        if AudioServer.get_bus_index(String(bus_name)) != -1:
            return String(bus_name)
    return "Master"


static func stop_low_hp_heartbeat(level: Node) -> void:
    if level.low_hp_heartbeat_player != null and is_instance_valid(level.low_hp_heartbeat_player) and level.low_hp_heartbeat_player.playing:
        level.low_hp_heartbeat_player.stop()


static func should_autoplay_audio(level: Node) -> bool:
    if DisplayServer.get_name() != "headless":
        return true
    for arg in OS.get_cmdline_args():
        if String(arg).contains("audio_visual_validation.gd"):
            return true
    return false


static func switch_bgm(level: Node, audio_key: String) -> void:
    var stream = AUDIO_DIRECTOR_SCRIPT.load_cached(String(level.AUDIO.get(audio_key, "")), true)
    if stream == null:
        return
    level._ensure_bgm_player()
    if level.bgm_player.stream == stream and level.bgm_player.playing:
        return
    level.bgm_player.stream = stream
    level.bgm_player.play()


static func ensure_bgm_player(level: Node) -> void:
    if level.bgm_player != null and is_instance_valid(level.bgm_player):
        return
    level.bgm_player = AudioStreamPlayer.new()
    level.bgm_player.name = "BgmPlayer"
    level.bgm_player.bus = "BGM" if AudioServer.get_bus_index("BGM") != -1 else "Master"
    level.bgm_player.volume_db = -18.0
    level.add_child(level.bgm_player)


static func play_sfx(level: Node, audio_key: String, volume_db: float = -7.0) -> void:
    if not level._should_autoplay_audio() or not level.is_inside_tree() or level.is_queued_for_deletion():
        return
    # 声部管理（规格 §5.4）：同 key 限频/并发 + 全局 24 声部，被拒即不播。
    var voice_ticket = AUDIO_DIRECTOR_SCRIPT.reserve_voice(audio_key)
    if voice_ticket == 0:
        return
    var stream: AudioStream = level._load_audio_stream(audio_key)
    if stream == null:
        # 声部回滚（契约 release_voice）：拿不到流就撤销刚批准的登记。
        AUDIO_DIRECTOR_SCRIPT.release_ticket(voice_ticket)
        return
    var player_node := AudioStreamPlayer.new()
    player_node.name = "Sfx_" + audio_key
    player_node.bus = level._sfx_bus_for_key(audio_key)
    player_node.stream = stream
    player_node.volume_db = volume_db
    var instance_id := player_node.get_instance_id()
    level.pending_sfx_players[instance_id] = {"player": player_node, "voice_ticket": voice_ticket}
    # Interactable signals can close an overlay while this level or one of its
    # children is entering/exiting the tree. Defer attachment until scene-tree
    # notifications finish, then play only after the player is actually inside.
    level.call_deferred("_attach_pending_sfx", instance_id)


static func attach_pending_sfx(level: Node, instance_id: int) -> void:
    if not level.pending_sfx_players.has(instance_id):
        return
    var pending: Dictionary = level.pending_sfx_players[instance_id]
    level.pending_sfx_players.erase(instance_id)
    var player_node: AudioStreamPlayer = pending.get("player")
    var voice_ticket := int(pending.get("voice_ticket",0))
    if not is_instance_valid(player_node):
        AUDIO_DIRECTOR_SCRIPT.release_ticket(voice_ticket)
        return
    if not level.is_inside_tree() or level.is_queued_for_deletion():
        player_node.free()
        AUDIO_DIRECTOR_SCRIPT.release_ticket(voice_ticket)
        return
    level.add_child(player_node)
    if not player_node.is_inside_tree():
        player_node.free()
        AUDIO_DIRECTOR_SCRIPT.release_ticket(voice_ticket)
        return
    player_node.finished.connect(Callable(player_node, "queue_free"))
    AUDIO_DIRECTOR_SCRIPT.start_reserved_voice(voice_ticket,player_node)


static func cancel_pending_sfx(level: Node) -> void:
    for pending_value in level.pending_sfx_players.values():
        var pending: Dictionary = pending_value
        var player_node: AudioStreamPlayer = pending.get("player")
        if is_instance_valid(player_node):
            player_node.free()
        AUDIO_DIRECTOR_SCRIPT.release_ticket(int(pending.get("voice_ticket",0)))
    level.pending_sfx_players.clear()


static func sfx_bus_for_key(level: Node, audio_key: String) -> String:
    if audio_key.begins_with("ui_"):
        if AudioServer.get_bus_index("UI") != -1:
            return "UI"
    elif AudioServer.get_bus_index("SFXWorld") != -1:
        return "SFXWorld"
    return "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"


static func load_audio_stream(level: Node, audio_key: String) -> AudioStream:
    # 统一走 AudioDirector 静态流缓存（契约 load_cached：直读 + 负缓存 + 告警一次）。
    return AUDIO_DIRECTOR_SCRIPT.load_cached(String(level.AUDIO.get(audio_key, "")))


static func play_sfx_persistent(level: Node, audio_key: String, volume_db: float = -7.0) -> void:
    if not level._should_autoplay_audio():
        return
    var voice_ticket = AUDIO_DIRECTOR_SCRIPT.reserve_voice(audio_key)
    if voice_ticket == 0:
        return
    var stream: AudioStream = level._load_audio_stream(audio_key)
    if stream == null or not level.is_inside_tree():
        # 声部回滚（契约 release_voice）：拿不到流/不在树上都不会真正发声。
        AUDIO_DIRECTOR_SCRIPT.release_ticket(voice_ticket)
        return
    var player_node := AudioStreamPlayer.new()
    player_node.name = "PersistentSfx_" + audio_key
    player_node.bus = level._sfx_bus_for_key(audio_key)
    player_node.stream = stream
    player_node.volume_db = volume_db
    level.get_tree().root.add_child(player_node)
    player_node.finished.connect(Callable(player_node, "queue_free"))
    AUDIO_DIRECTOR_SCRIPT.start_reserved_voice(voice_ticket,player_node)


static func play_sfx_random(level: Node, audio_keys: Array, volume_db: float = -7.0) -> void:
    if audio_keys.is_empty():
        return
    level._play_sfx(String(audio_keys[randi() % audio_keys.size()]), volume_db)
