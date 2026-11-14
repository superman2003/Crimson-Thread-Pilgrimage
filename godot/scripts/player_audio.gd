extends RefCounted
## Player sound: one-shots and voices, landing, wall-slide and bind loops, and footsteps.
## Moved out of player_controller.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func play_sfx(player: Node, audio_key: String, volume_db: float = -5.0, pitch_scale: float = 1.0, voice_key: String = "", voice_priority: int = 1) -> void:
    player._play_sfx_voice(audio_key, volume_db, pitch_scale, voice_key, voice_priority)


static func play_sfx_voice(player: Node, audio_key: String, volume_db: float = -5.0, pitch_scale: float = 1.0, voice_key: String = "", voice_priority: int = 1) -> Node:
    if not player._should_play_sfx():
        return null
    # 声部准入（AudioDirector 契约）：同 key 最小间隔/并发上限/全局 24 声部抢占。
    var resolved_voice_key := voice_key if not voice_key.is_empty() else "player_" + audio_key
    var voice_ticket = player._request_voice(resolved_voice_key, voice_priority)
    if voice_ticket == 0:
        return null
    var stream: AudioStream = player._load_sfx_stream(audio_key)
    if stream == null:
        # 声部回滚（AudioDirector 契约）：流缺失/解码失败时释放已占用的声部。
        player._release_voice(voice_ticket)
        return null
    var player_node := AudioStreamPlayer2D.new()
    player_node.name = "Sfx_" + audio_key
    player_node.set_meta("retire_after_playback",true)
    # 总线归位（音频规格 §5.1）：玩家动作音走 SFXPlayer 子总线，缺席时回落 SFX/Master。
    player_node.bus = player._sfx_bus_name()
    player_node.stream = stream
    player_node.volume_db = volume_db
    player_node.pitch_scale = pitch_scale
    player_node.max_distance = 900.0
    player.add_child(player_node)
    player_node.finished.connect(Callable(player_node, "queue_free"))
    player._start_voice(voice_ticket,player_node)
    return player_node


static func play_land_sfx(player: Node, fall_speed: float) -> void:
    if fall_speed >= 620.0:
        player._play_sfx("land_hard", -8.0, 1.0, "player_land")
    else:
        player._play_sfx("land_soft", -10.0, 1.0, "player_land")


static func sfx_bus_name(player: Node) -> String:
    if AudioServer.get_bus_index("SFXPlayer") != -1:
        return "SFXPlayer"
    return "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"


static func should_play_sfx(player: Node) -> bool:
    if DisplayServer.get_name() != "headless":
        return true
    for arg in OS.get_cmdline_args():
        if String(arg).contains("audio_visual_validation.gd"):
            return true
    return false


static func load_sfx_stream(player: Node, audio_key: String, looped: bool = false) -> AudioStream:
    return player._load_stream_for_path(String(player.SFX.get(audio_key, "")), looped)


static func update_wall_slide_audio(player: Node) -> void:
    if player.wall_sliding and not player.was_wall_sliding:
        player._play_sfx("wall_grip_attach", -7.0)
        # ch2 beat `wall_grip`（manifest ch02_beat_01）：雨铸运河（copper 主题）贴墙时
        # 吸附音 0.15s 后叠一层水滴尾音。
        if player.footstep_material == "copper":
            player.get_tree().create_timer(0.15).timeout.connect(func() -> void:
                if is_instance_valid(player):
                    player._play_sfx("ch02_beat_wall_grip_drip", -12.0))
        player._start_wall_slide_loop()
    elif not player.wall_sliding and player.was_wall_sliding:
        player._stop_wall_slide_loop()
    if player.wall_sliding and player.wall_slide_audio != null and is_instance_valid(player.wall_slide_audio):
        player.wall_slide_audio.pitch_scale = clampf(0.85 + player.velocity.y / maxf(player.wall_slide_max_speed, 1.0) * 0.35, 0.8, 1.35)
    player.was_wall_sliding = player.wall_sliding


static func start_wall_slide_loop(player: Node) -> void:
    if is_instance_valid(player.wall_slide_audio) and player.wall_slide_audio.playing:return
    if not player._should_play_sfx():
        return
    var voice_ticket = player._request_voice("player_wall_slide_loop", 1, 40, 1)
    if voice_ticket == 0:
        return
    if player.wall_slide_audio == null or not is_instance_valid(player.wall_slide_audio):
        player.wall_slide_audio = AudioStreamPlayer2D.new()
        player.wall_slide_audio.name = "SfxLoop_wall_slide"
        player.wall_slide_audio.bus = player._sfx_bus_name()
        player.wall_slide_audio.volume_db = -13.0
        player.wall_slide_audio.max_distance = 900.0
        player.add_child(player.wall_slide_audio)
    if player.wall_slide_audio.stream == null:
        # Region retirement releases streams while the persistent player survives.
        var stream: AudioStream = player._load_sfx_stream("wall_slide_loop", true)
        if stream == null:
            player._release_voice(voice_ticket)
            return
        player.wall_slide_audio.stream = stream
    if not player.wall_slide_audio.playing:
        player._start_voice(voice_ticket,player.wall_slide_audio,true)


static func start_bind_channel(player: Node) -> void:
    if not player._should_play_sfx():
        return
    var voice_ticket = player._request_voice("player_bind_channel", 1, 40, 1)
    if voice_ticket == 0:
        return
    if player.bind_channel_audio == null or not is_instance_valid(player.bind_channel_audio):
        player.bind_channel_audio = AudioStreamPlayer2D.new()
        player.bind_channel_audio.name = "SfxLoop_bind_channel"
        player.bind_channel_audio.bus = player._sfx_bus_name()
        player.bind_channel_audio.volume_db = -12.0
        player.bind_channel_audio.max_distance = 900.0
        player.add_child(player.bind_channel_audio)
    if player.bind_channel_audio.stream == null:
        # Region retirement releases streams while the persistent player survives.
        var stream: AudioStream = player._load_sfx_stream("bind_channel", true)
        if stream == null:
            player._release_voice(voice_ticket)
            return
        player.bind_channel_audio.stream = stream
    player.bind_channel_audio.pitch_scale = player.BIND_CHANNEL_PITCH.x
    if player.bind_channel_audio.playing:
        player._release_voice(voice_ticket)
        return
    player._start_voice(voice_ticket,player.bind_channel_audio,true)


static func stop_bind_channel(player: Node) -> void:
    if player.bind_channel_audio != null and is_instance_valid(player.bind_channel_audio) and player.bind_channel_audio.playing:
        player.bind_channel_audio.stop()


static func stop_wall_slide_loop(player: Node) -> void:
    if player.wall_slide_audio != null and is_instance_valid(player.wall_slide_audio) and player.wall_slide_audio.playing:
        player.wall_slide_audio.stop()


static func update_footsteps(player: Node, _delta: float) -> void:
    var contacts = player.footstep_contacts
    player.footstep_contacts = 0
    if contacts <= 0 or not player.is_on_floor() or player.dash_timer > 0.0 or player.attack_timer > 0.0 or player.ground_motion_speed < 60.0:
        return
    player._play_footstep()


static func play_footstep(player: Node) -> void:
    if not player._should_play_sfx():
        return
    var voice_ticket = player._request_voice("player_footstep", 2, 90, 2)
    if voice_ticket == 0:
        return
    var material_key := String(player.FOOTSTEP_MATERIAL_REMAP.get(player.footstep_material, player.footstep_material))
    var variants: Array = player.FOOTSTEP_VARIANTS.get(material_key, player.FOOTSTEP_VARIANTS["moss"])
    if variants.is_empty():
        player._release_voice(voice_ticket)
        return
    var path := String(variants[randi() % variants.size()])
    var stream = player._load_stream_for_path(path)
    if stream == null:
        player._release_voice(voice_ticket)
        return
    var player_node := AudioStreamPlayer2D.new()
    player_node.name = "SfxStep"
    player_node.set_meta("retire_after_playback",true)
    player_node.bus = player._sfx_bus_name()
    player_node.stream = stream
    player_node.volume_db = player.FOOTSTEP_VOLUME_DB
    # 变体随机轮播 + ±4% 随机变调（丝之歌式"连打不重样"的最低成本实现）。
    player_node.pitch_scale = float(player.FOOTSTEP_BASE_PITCH.get(material_key, 1.0)) * randf_range(0.96, 1.04)
    player_node.max_distance = 900.0
    player.add_child(player_node)
    player_node.finished.connect(Callable(player_node, "queue_free"))
    player._start_voice(voice_ticket,player_node)
