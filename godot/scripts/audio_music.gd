extends RefCounted
## Music: the exploration track and its pause/resume, combat layer, boss music and phases, lullaby and stingers.
## Moved out of audio_director.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func play_explore_track(director: Node, path: String) -> void:
    if director.region_audio_released:
        return
    var stream = director.load_cached(path, true)
    if stream == null:
        return
    if director.explore_player == null or not is_instance_valid(director.explore_player):
        director.explore_player = AudioStreamPlayer.new()
        director.explore_player.name = "MusicExplorePlayer"
        director.explore_player.bus = director._bus_or("MusicExplore", "BGM")
        director.explore_player.volume_db = director.EXPLORE_DB
        director.add_child(director.explore_player)
    # Reapplying a region/room music state must not restart its audible phrase.
    if director.explore_player.stream == stream and (director.explore_player.playing or director.explore_player.stream_paused) and director._explore_path == path:
        return
    director._remember_explore_position()
    # A queued older region may still own the same phrase. Capture it before
    # transferring the lease; its later exit cannot overwrite this player.
    var previous_id := int(director._explore_owners.get(path, 0))
    var previous := instance_from_id(previous_id) as AudioDirector if previous_id != 0 else null
    if is_instance_valid(previous) and previous != director:
        previous._remember_explore_position()
    if director._explore_owners.get(director._explore_path, 0) == director.get_instance_id(): director._explore_owners.erase(director._explore_path)
    director._explore_path = path
    director._explore_session = director._explore_epoch
    director._explore_owners[path] = director.get_instance_id()
    director._kill_explore_tween()
    director.explore_player.stream_paused = false
    director.explore_player.stream = stream
    var position := float(director._explore_resume.get(path, 0.0))
    var length = stream.get_length()
    if not is_finite(position) or position < 0.0: position = 0.0
    director.explore_player.play(fposmod(position, length) if length > 0.0 else 0.0)
    # 章节起播淡入：从静音 0.8s 升到基准（转场后新章不撞门）。
    if director.is_inside_tree():
        director.explore_player.volume_db = director.SILENT_DB
        director.explore_tween = director.create_tween()
        director.explore_tween.tween_property(director.explore_player, "volume_db", director.EXPLORE_DB, director.CHAPTER_ENTER_EXPLORE_FADE_S)
    else:
        director.explore_player.volume_db = director.EXPLORE_DB


static func remember_explore_position(director: Node) -> void:
    if director._explore_session != director._explore_epoch or director._explore_owners.get(director._explore_path, 0) != director.get_instance_id(): return
    if not is_instance_valid(director.explore_player) or director.explore_player.stream == null: return
    if not director.explore_player.playing and not director.explore_player.stream_paused: return
    var position = director.explore_player.get_playback_position()
    if not is_finite(position) or position < 0.0: return
    director._explore_resume.erase(director._explore_path)
    director._explore_resume[director._explore_path] = position
    while director._explore_resume.size() > director.MAX_EXPLORE_BOOKMARKS: director._explore_resume.erase(director._explore_resume.keys()[0])


static func bus_or(director: Node, bus_name: String, fallback: String) -> String:
    if AudioServer.get_bus_index(bus_name) != -1:
        return bus_name
    return fallback if AudioServer.get_bus_index(fallback) != -1 else "Master"


static func kill_explore_tween(director: Node) -> void:
    if director.explore_tween != null and director.explore_tween.is_valid():
        director.explore_tween.kill()


static func fade_explore_to_pause(director: Node, seconds: float) -> void:
    if director.explore_player == null or not is_instance_valid(director.explore_player):
        return
    director._kill_explore_tween()
    if not director.is_inside_tree() or not director.explore_player.playing or director.explore_player.stream_paused:
        director.explore_player.stream_paused = true
        director.explore_player.volume_db = director.EXPLORE_DB
        return
    director.explore_tween = director.create_tween()
    director.explore_tween.tween_property(director.explore_player, "volume_db", director.SILENT_DB, seconds)
    director.explore_tween.tween_callback(director._finish_explore_pause)


static func finish_explore_pause(director: Node) -> void:
    if director.explore_player == null or not is_instance_valid(director.explore_player):
        return
    director.explore_player.stream_paused = true
    director.explore_player.volume_db = director.EXPLORE_DB


static func fade_explore_resume(director: Node, seconds: float) -> void:
    if director.explore_player == null or not is_instance_valid(director.explore_player):
        return
    director._kill_explore_tween()
    director.explore_player.stream_paused = false
    if not director.is_inside_tree():
        director.explore_player.volume_db = director.EXPLORE_DB
        return
    director.explore_player.volume_db = director.EXPLORE_DB + director.EXPLORE_RESUME_FROM_DB
    director.explore_tween = director.create_tween()
    director.explore_tween.tween_property(director.explore_player, "volume_db", director.EXPLORE_DB, seconds)


static func resume_region_music(director: Node, seconds: float) -> void:
    if director.in_transit_room:
        director._update_transit_loop(true)
    else:
        director._fade_explore_resume(seconds)


static func enter_combat(director: Node) -> void:
    director.ambient_soundscape.stop()
    director._stop_npc_landmarks()
    if director.boss_active or director.combat_active:
        return
    director.combat_active = true
    director._update_transit_loop(false)
    if director.lullaby_active:
        director.stop_lullaby()
    if not director.autoplay_enabled:
        return
    var path: String = director._combat_layer_path()
    if path.is_empty():
        if director.combat_tween != null and director.combat_tween.is_valid():director.combat_tween.kill()
        if is_instance_valid(director.combat_player):director.combat_player.stop()
        director._fade_explore_to_pause(0.8)
        return
    var stream = director.load_cached(path, true)
    if stream == null:
        return
    # These are independent compositions, so the encounter cue replaces the
    # exploration mix instead of claiming sample/phrase synchronization.
    director._fade_explore_to_pause(0.8)
    if director.combat_player == null or not is_instance_valid(director.combat_player):
        director.combat_player = AudioStreamPlayer.new()
        director.combat_player.name = "MusicCombatLayer"
        director.combat_player.bus = director._bus_or("MusicCombat", "BGM")
        director.combat_player.volume_db = director.SILENT_DB
        director.add_child(director.combat_player)
    if director.combat_tween != null and director.combat_tween.is_valid():
        director.combat_tween.kill()
    if director.combat_player.playing and director.combat_player.stream == stream:
        # 离战淡出中复进战：取消淡出直接回满（流走缓存无 IO，防抽泵）。
        director.combat_player.volume_db = director.COMBAT_LAYER_DB
        return
    director.combat_player.stream = stream
    director.combat_player.volume_db = director.SILENT_DB
    director.combat_player.play()
    if director.is_inside_tree():
        director.combat_tween = director.create_tween()
        director.combat_tween.tween_property(director.combat_player, "volume_db", director.COMBAT_LAYER_DB, 0.8)
    else:
        director.combat_player.volume_db = director.COMBAT_LAYER_DB


static func exit_combat(director: Node) -> void:
    if not director.combat_active:
        return
    director.combat_active = false
    if director.autoplay_enabled and not director.boss_active and not director.lullaby_active:
        director._resume_region_music(2.5)
    if director.combat_player == null or not is_instance_valid(director.combat_player) or not director.combat_player.playing:
        return
    if director.combat_tween != null and director.combat_tween.is_valid():
        director.combat_tween.kill()
    if director.is_inside_tree():
        director.combat_tween = director.create_tween()
        director.combat_tween.tween_property(director.combat_player, "volume_db", director.SILENT_DB, 2.5)
        director.combat_tween.tween_callback(director.combat_player.stop)
    else:
        director.combat_player.stop()


static func fade_out_combat_layer(director: Node) -> void:
    director.combat_active = false
    director.combat_calm_time = 0.0
    if director.combat_tween != null and director.combat_tween.is_valid():
        director.combat_tween.kill()
    if director.combat_player == null or not is_instance_valid(director.combat_player) or not director.combat_player.playing:
        return
    if not director.is_inside_tree():
        director.combat_player.stop()
        return
    director.combat_tween = director.create_tween()
    director.combat_tween.tween_property(director.combat_player, "volume_db", director.SILENT_DB, director.BOSS_ENTER_COMBAT_FADE_S)
    director.combat_tween.tween_callback(director.combat_player.stop)


static func music_candidate(director: Node, path: String) -> AudioStream:
    var key := "%s|1" % path
    var now := Time.get_ticks_msec()
    if director._stream_cache.has(key) and director._stream_cache[key]==null:
        if now<int(director.music_retry_after.get(path,0)):return null
        director._stream_cache.erase(key)
    var stream = director.load_cached(path,true)
    if stream==null:
        director.music_retry_after.erase(path)
        director.music_retry_after[path]=now+1000
        while director.music_retry_after.size()>16:director.music_retry_after.erase(director.music_retry_after.keys()[0])
    else:director.music_retry_after.erase(path)
    return stream


static func start_boss_music(director: Node, boss_id: String) -> void:
    director.ambient_soundscape.stop()
    director._stop_npc_landmarks()
    if director.boss_active and director.active_boss_id == boss_id \
            and director.boss_player != null and is_instance_valid(director.boss_player) and director.boss_player.playing:
        return
    var stream: AudioStream
    if director.autoplay_enabled:
        stream=director._music_candidate(director.CROWN_ENTRANCE if boss_id == director.FINAL_BOSS_ID else director._boss_track_path(boss_id,1))
        if stream==null:return
    director.boss_active = true
    director._update_transit_loop(false)
    director.active_boss_id = boss_id
    director.boss_phase = 1
    director._fade_out_combat_layer()
    if not director.autoplay_enabled:
        return
    # 摇篮曲×Boss 互斥：boss_active 已置位，stop_lullaby 不会误恢复探索曲。
    if director.lullaby_active:
        director.stop_lullaby()
    if boss_id == director.FINAL_BOSS_ID:
        # 终 Boss 三乐章预载进流缓存：相变切换零磁盘 IO。
        for movement_path in director.FINAL_BOSS_MOVEMENTS:
            director.load_cached(String(movement_path), true)
    director._fade_explore_to_pause(director.BOSS_ENTER_EXPLORE_FADE_S)
    if director.boss_player == null or not is_instance_valid(director.boss_player):
        director.boss_player = AudioStreamPlayer.new()
        director.boss_player.name = "MusicBossPlayer"
        director.boss_player.bus = director._bus_or("MusicCombat", "BGM")
        director.add_child(director.boss_player)
    director._kill_boss_tween()
    director.boss_player.volume_db = director.BOSS_DB
    director.boss_player.stream = stream
    director.boss_player.play()
    if boss_id == director.FINAL_BOSS_ID and director.is_inside_tree():
        director.boss_tween = director.create_tween()
        director.boss_tween.tween_interval(director.CROWN_ENTRANCE_SECONDS)
        director.boss_tween.tween_callback(director._finish_crown_entrance)


static func finish_crown_entrance(director: Node) -> void:
    if not director.boss_active or director.active_boss_id != director.FINAL_BOSS_ID or director.boss_phase != 1 or not is_instance_valid(director.boss_player):return
    var stream: AudioStream = director._music_candidate(director._boss_track_path(director.FINAL_BOSS_ID,1))
    if stream != null:
        director.boss_player.stream = stream
        director.boss_player.play()


static func set_boss_phase(director: Node, p: int) -> void:
    var next_phase := clampi(p,1,3)
    if not director.boss_active or next_phase==director.boss_phase:return
    if not director.autoplay_enabled or director.active_boss_id!=director.FINAL_BOSS_ID:
        director.boss_phase=next_phase
        return
    if not is_instance_valid(director.boss_player):return
    var stream: AudioStream = director._music_candidate(director._boss_track_path(director.active_boss_id,next_phase))
    if stream==null:return
    director._kill_boss_tween()
    director.boss_player.stream=stream
    director.boss_player.play()
    director.boss_phase=next_phase


static func stop_boss_music(director: Node) -> void:
    if not director.boss_active and director.active_boss_id.is_empty():
        return
    director.boss_active = false
    director.active_boss_id = ""
    director.boss_phase = 0
    director._kill_boss_tween()
    if director.boss_player != null and is_instance_valid(director.boss_player) and director.boss_player.playing:
        if director.is_inside_tree():
            # Boss 曲 0.8s 淡出（原为硬停）。
            director.boss_tween = director.create_tween()
            director.boss_tween.tween_property(director.boss_player, "volume_db", director.SILENT_DB, director.BOSS_EXIT_FADE_S)
            director.boss_tween.tween_callback(director._finish_boss_stop)
        else:
            director._finish_boss_stop()
    if director.autoplay_enabled and not director.lullaby_active:
        # 探索曲从 -12dB 1.2s 淡入恢复。
        director._resume_region_music(director.BOSS_EXIT_EXPLORE_FADE_S)


static func kill_boss_tween(director: Node) -> void:
    if director.boss_tween != null and director.boss_tween.is_valid():
        director.boss_tween.kill()


static func finish_boss_stop(director: Node) -> void:
    if director.boss_player != null and is_instance_valid(director.boss_player):
        director.boss_player.stop()
        director.boss_player.volume_db = director.BOSS_DB


static func start_lullaby(director: Node) -> void:
    if director.lullaby_active:
        return
    if director.boss_active or director.combat_active:
        # Active threats keep the shrine poll pending until the calm window ends.
        return
    var stream: AudioStream
    if director.autoplay_enabled:
        stream=director._music_candidate(director._lullaby_path())
        if stream==null:return
    director._fade_out_combat_layer()
    director.lullaby_active = true
    director._update_transit_loop(false)
    if not director.autoplay_enabled:
        return
    if director.lullaby_player == null or not is_instance_valid(director.lullaby_player):
        director.lullaby_player = AudioStreamPlayer.new()
        director.lullaby_player.name = "MusicLullabyPlayer"
        director.lullaby_player.bus = director._bus_or("MusicExplore", "BGM")
        director.add_child(director.lullaby_player)
    # 交叉淡化：探索曲 0.8s 淡出至暂停（非硬停），摇篮曲同步淡入。
    director._fade_explore_to_pause(director.LULLABY_EXPLORE_FADE_S)
    director.lullaby_player.stream = stream
    director.lullaby_player.volume_db = director.SILENT_DB
    director.lullaby_player.play()
    if director.lullaby_tween != null and director.lullaby_tween.is_valid():
        director.lullaby_tween.kill()
    if director.is_inside_tree():
        director.lullaby_tween = director.create_tween()
        director.lullaby_tween.tween_property(director.lullaby_player, "volume_db", director.LULLABY_DB, 0.8)
    else:
        director.lullaby_player.volume_db = director.LULLABY_DB


static func stop_lullaby(director: Node) -> void:
    if not director.lullaby_active:
        return
    director.lullaby_active = false
    if director.lullaby_player != null and is_instance_valid(director.lullaby_player) and director.lullaby_player.playing:
        if director.lullaby_tween != null and director.lullaby_tween.is_valid():
            director.lullaby_tween.kill()
        if director.is_inside_tree():
            director.lullaby_tween = director.create_tween()
            director.lullaby_tween.tween_property(director.lullaby_player, "volume_db", director.SILENT_DB, 1.2)
            director.lullaby_tween.tween_callback(director.lullaby_player.stop)
        else:
            director.lullaby_player.stop()
    if director.autoplay_enabled and not director.boss_active and not director.combat_active:
        # 退出对称交叉淡化：探索曲 0.8s 淡入恢复。
        director._resume_region_music(director.LULLABY_EXPLORE_FADE_S)


static func play_stinger(director: Node, key: String) -> void:
    if not director.autoplay_enabled:
        return
    var stream = director.load_cached(String(director.STINGER_TRACKS.get(key, "")))
    if stream == null:
        return
    if director.stinger_player == null or not is_instance_valid(director.stinger_player):
        director.stinger_player = AudioStreamPlayer.new()
        director.stinger_player.name = "MusicStingerPlayer"
        director.stinger_player.bus = director._bus_or("MusicStinger", "BGM")
        director.stinger_player.volume_db = director.STINGER_DB
        director.add_child(director.stinger_player)
    director.stinger_player.stream = stream
    director.stinger_player.play()
