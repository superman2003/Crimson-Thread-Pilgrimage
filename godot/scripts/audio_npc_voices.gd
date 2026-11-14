extends RefCounted
## NPC speech, enemy alerts and NPC sound landmarks.
## Moved out of audio_director.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func play_npc_voice(director: Node, npc_id: String, line: String, profile: String = "warm", speaker: Node = null, allow_voice: bool = true) -> bool:
    director._stop_npc_landmarks()
    if line.strip_edges().is_empty() or not director.is_inside_tree():
        return false
    var fingerprint := npc_id + "\n" + line
    if fingerprint == director._npc_voice_line: return false
    director.stop_npc_voice(false)
    director._npc_voice_line = fingerprint
    # Restoring a read line stays quiet, while still retiring a different line.
    if not allow_voice: return false
    var key := "npc_greeting_" + npc_id
    var voice_ticket = director.reserve_voice(key, 2, 450, 1)
    if voice_ticket == 0:
        return false
    # Audio-only hosts do not own character art; resolve that dependency only
    # when a conversation actually requests a phrase.
    var language = load(director.NPC_LANGUAGE_PATH) as Script
    if language == null:
        director.release_ticket(voice_ticket)
        return false
    var phrase: Dictionary = language.utterance(npc_id, line, profile)
    if phrase.is_empty():
        director.release_ticket(voice_ticket)
        return false
    var stream = director.load_cached(String(phrase.path))
    if stream == null:
        director.release_ticket(voice_ticket)
        return false
    if director._npc_voice_player == null or not is_instance_valid(director._npc_voice_player):
        director._npc_voice_player = AudioStreamPlayer.new()
        director._npc_voice_player.name = "NPCNonverbalVoice"
        director._npc_voice_player.bus = director._bus_or("SFXWorld", "SFX")
        director._npc_voice_player.finished.connect(director._npc_voice_finished)
        director.add_child(director._npc_voice_player)
    director._npc_voice_player.stream = stream
    director._npc_voice_player.pitch_scale = float(phrase.pitch_scale)
    director._npc_voice_player.volume_db = float(phrase.volume_db)
    if not director.start_reserved_voice(voice_ticket,director._npc_voice_player,true): return false
    director._npc_voice_ticket = voice_ticket
    if is_instance_valid(speaker) and speaker.has_method("begin_utterance"):
        director._npc_speaker = weakref(speaker)
        speaker.call("begin_utterance", director._npc_voice_player, float(phrase.voiced_until))
    return true


static func end_npc_speaker(director: Node) -> void:
    var speaker: Node = director._npc_speaker.get_ref() if director._npc_speaker != null else null
    director._npc_speaker = null
    if is_instance_valid(speaker) and not speaker.is_queued_for_deletion() and speaker.has_method("end_utterance"):
        speaker.call("end_utterance")


static func npc_voice_finished(director: Node) -> void:
    if is_instance_valid(director._npc_voice_player) and director._npc_voice_player.playing: return
    director._end_npc_speaker()
    director._npc_voice_ticket = 0


static func stop_npc_voice(director: Node, clear_line: bool = true) -> void:
    director._end_npc_speaker()
    if is_instance_valid(director._npc_voice_player):
        preload("res://scripts/audio_retirement.gd").watch_player(director._npc_voice_player)
        director._npc_voice_player.stop()
        director._npc_voice_player.stream = null
    if director._npc_voice_ticket != 0:
        director._forget_voice(director._npc_voice_ticket)
        director._npc_voice_ticket = 0
    if clear_line: director._npc_voice_line = ""


static func play_enemy_alert(director: Node, kind: String, source: Node2D = null) -> bool:
    var spatial := preload("res://scripts/spatial_enemy_alert.gd")
    var listener = director.runtime_player as Node2D
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
    if not director.is_inside_tree():return false
    var voice_ticket = director.reserve_voice(key,2,1800,1)
    if voice_ticket == 0:
        return false
    var path := "res://assets/audio/sfx/generated/enemy_hit_%s.ogg" % family
    var stream = director.load_cached(path)
    if stream == null:
        director.release_ticket(voice_ticket)
        return false
    var voice := spatial.new()
    voice.bus = director._bus_or("SFXEnemy", "SFX")
    voice.pitch_scale = 0.72 if family == "armor" else 1.24
    voice.stream = stream
    director.add_child(voice)
    if not voice.place(source.global_position, listener):
        voice.free()
        director.release_voice(key)
        return false
    voice.finished.connect(voice.queue_free)
    return director.start_reserved_voice(voice_ticket,voice)


static func set_npc_landmarks(director: Node, enabled: bool) -> void:
    director.npc_landmarks_enabled = enabled
    if not enabled:director._stop_npc_landmarks()
    else:director.landmark_next_ms=Time.get_ticks_msec()+1200


static func landmarks_allowed(director: Node) -> bool:
    if not director.is_inside_tree() or director.instance != director or not director.npc_landmarks_enabled or director.dialogue_open or director.combat_active or director.boss_active or director.shrine_engaged:return false
    if director.get_user_volume("master") <= 0 or director.get_user_volume("sfx") <= 0:return false
    if not is_instance_valid(director.runtime_player) or not director.runtime_player is Node2D or not director.runtime_player.is_inside_tree():return false
    if director.runtime_player.get("ui_input_locked") == true:return false
    var hp: Variant = director.runtime_player.get("hp")
    return not ((hp is int or hp is float) and hp <= 0)


static func tick_npc_landmarks(director: Node) -> void:
    if not director._landmarks_allowed():director._stop_npc_landmarks();return
    var now := Time.get_ticks_msec()
    if now < director.landmark_next_ms:return
    var rows: Array=[]
    var sources: Array=[]
    for candidate in director.get_tree().get_nodes_in_group("npc_sound_landmark"):
        if not candidate is Node2D or not candidate.is_inside_tree() or not candidate.is_visible_in_tree() or candidate.is_queued_for_deletion():continue
        if candidate.get_world_2d()!=director.runtime_player.get_world_2d() or String(candidate.get_meta("kind",""))!="npc":continue
        rows.append({"id":String(candidate.get_meta("npc_id","")),"distance":candidate.global_position.distance_to(director.runtime_player.global_position)})
        sources.append(weakref(candidate))
    var selected = director.LANDMARK_SCHEDULE.choose(rows,director.landmark_times,now)
    if selected<0:
        director.landmark_next_ms=now+director.LANDMARK_SCHEDULE.RETRY_MS
        return
    var source: Variant=sources[selected].get_ref()
    if not is_instance_valid(source) or not director.play_npc_landmark(source):director.landmark_next_ms=now+director.LANDMARK_SCHEDULE.RETRY_MS


static func play_npc_landmark(director: Node, source: Node2D) -> bool:
    if not director._landmarks_allowed() or not is_instance_valid(source) or not source.is_inside_tree() or source.is_queued_for_deletion() or not source.is_visible_in_tree():return false
    if source.get_world_2d() != director.runtime_player.get_world_2d() or not source.global_position.is_finite() or source.global_position.distance_squared_to(director.runtime_player.global_position) > 650.0 * 650.0:return false
    if String(source.get_meta("kind","")) != "npc":return false
    var id := String(source.get_meta("npc_id",""))
    if id.is_empty():return false
    var now := Time.get_ticks_msec()
    if now < director.landmark_next_ms or now - int(director.landmark_times.get(id,-12001)) < 12000:return false
    var key := "npc_landmark_" + id
    var ticket = director.reserve_voice(key,3,12000,1)
    if ticket == 0:return false
    var voice := preload("res://scripts/npc_sound_landmark.gd").new()
    voice.name = "NPCSoundLandmark"
    voice.set_meta("npc_landmark",true)
    voice.set_meta("landmark_source",weakref(source))
    voice.stream = director.npc_voice_stream("dry" if id.contains("carto") else "low" if id.contains("smith") else "warm")
    director.add_child(voice)
    if not voice.place(source.global_position,director.runtime_player,-25.0):
        voice.free();director.release_ticket(ticket);return false
    voice.max_distance = 650.0
    voice.finished.connect(voice.queue_free)
    if not director.start_reserved_voice(ticket,voice):voice.free();director.release_ticket(ticket);return false
    director.landmark_times.erase(id);director.landmark_times[id] = now
    while director.landmark_times.size() > 64:director.landmark_times.erase(director.landmark_times.keys()[0])
    director.landmark_next_ms = now + director.LANDMARK_SCHEDULE.GLOBAL_GAP_MS
    return true


static func retire_invalid_landmarks(director: Node) -> void:
    var active: Array[AudioStreamPlayer2D]=[]
    for child in director.get_children():
        if not child is AudioStreamPlayer2D or not bool(child.get_meta("npc_landmark",false)):continue
        var reference: Variant=child.get_meta("landmark_source",null)
        var source: Variant=reference.get_ref() if reference is WeakRef else null
        var valid: bool=is_instance_valid(source) and source is Node2D and source.is_inside_tree() and not source.is_queued_for_deletion() and source.is_visible_in_tree()
        valid=valid and is_instance_valid(director.runtime_player) and director.runtime_player.is_inside_tree()
        if valid:valid=source.get_world_2d()==director.runtime_player.get_world_2d() and source.global_position.distance_to(director.runtime_player.global_position)<=director.LANDMARK_SCHEDULE.RANGE
        if not valid:
            preload("res://scripts/audio_retirement.gd").watch_player(child)
            child.stop();child.stream=null;child.queue_free()
        elif not child.is_queued_for_deletion() and child.has_method("refresh_spatial"):
            active.append(child)
    for index in director.landmark_spatial_refresh.choose(active.size(),Time.get_ticks_msec()):
        var voice:=active[index]
        var source: Node2D=voice.get_meta("landmark_source").get_ref()
        if not is_instance_valid(source) or not voice.refresh_spatial(source.global_position,director.runtime_player):
            preload("res://scripts/audio_retirement.gd").watch_player(voice)
            voice.stop();voice.stream=null;voice.queue_free()


static func stop_npc_landmarks(director: Node) -> void:
    for child in director.get_children():
        if child is AudioStreamPlayer2D and bool(child.get_meta("npc_landmark",false)):
            preload("res://scripts/audio_retirement.gd").watch_player(child)
            child.stop();child.stream = null;child.queue_free()


static func foreground_warning(director: Node, source: Node2D) -> void:
    if director.instance != director or not director.is_inside_tree() or not is_instance_valid(source) or not source.is_inside_tree() or not director.runtime_player is Node2D or not is_instance_valid(director.runtime_player):return
    if source.get_world_2d() != director.runtime_player.get_world_2d() or source.global_position.distance_squared_to(director.runtime_player.global_position) > 900.0 * 900.0:return
    director._stop_npc_landmarks()
    director.ambient_soundscape.stop()
    director.duck(-4.0,0.35,0.04,0.3)
