extends RefCounted
## Player volume and mute settings, their save file, and the bus levels derived from them.
## Moved out of audio_director.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func set_user_volume(director: Node, which: String, percent: float) -> void:
    if director.is_queued_for_deletion() or (is_instance_valid(director.instance) and director.instance != director):return
    if not director.USER_VOLUME_BUS.has(which) or not is_finite(percent):
        return
    director.user_volumes[which] = clampf(percent, 0.0, 100.0)
    director.volume_preferences_revision += 1
    director.volume_preferences_dirty = true
    director._apply_user_volume(which)
    director._save_user_volumes()


static func get_user_volume(director: Node, which: String) -> float:
    return float(director.user_volumes.get(which, 100.0))


static func apply_user_volume(director: Node, which: String) -> void:
    var bus_name := String(director.USER_VOLUME_BUS.get(which, "Master"))
    var target: float = director._bus_base_db(which)
    if which == "music":
        target = director._music_rest_db()
        # User volume updates the baseline without losing other transient leases.
    elif which == "ambience":
        target = director._ambience_rest_db()
    # A user edit owns the new level, including a dialogue/transition envelope
    # that was created with a previous slider value.
    var envelope: Tween = director.bus_tweens.get(bus_name)
    if envelope != null and envelope.is_valid():
        envelope.kill()
    director.bus_tweens.erase(bus_name)
    director._set_bus_db(bus_name, target)
    director._set_user_mute(bus_name, director.get_user_volume(which) <= 0.0)
    if which == "sfx":
        # Heartbeats stay dry (send -> Master), but still obey the SFX slider.
        director._set_bus_db("SFXDry", director._user_db("sfx"))
        director._set_user_mute("SFXDry", director.get_user_volume("sfx") <= 0.0)


static func set_user_mute(director: Node, bus_name: String, muted: bool) -> void:
    var index := AudioServer.get_bus_index(bus_name)
    if index >= 0:
        AudioServer.set_bus_mute(index, muted)


static func load_user_volumes(director: Node) -> void:
    director.volume_preferences.recover(director.settings_path)
    var cfg := ConfigFile.new()
    if cfg.load(director.settings_path) == OK:
        for which in director.user_volumes.keys():
            # cfg 容错：仅接受有限 float/int，非法值保持默认 100 且不回写污染存档。
            var raw: Variant = cfg.get_value("volumes", String(which), float(director.user_volumes[which]))
            if (typeof(raw) == TYPE_FLOAT or typeof(raw) == TYPE_INT) and is_finite(float(raw)):
                director.user_volumes[which] = clampf(float(raw), 0.0, 100.0)
    var session_key = ProjectSettings.globalize_path(director.settings_path)
    if director.pending_volume_sessions.has(session_key):
        var pending: Dictionary = director.pending_volume_sessions[session_key]
        director.user_volumes = pending["values"].duplicate(true)
        director.volume_preferences_dirty = true
        director.volume_preferences_error = int(pending.error)
    for which in director.user_volumes.keys():
        director._apply_user_volume(String(which))


static func save_user_volumes(director: Node) -> void:
    if director.volume_preferences_saving:return
    if director.is_queued_for_deletion() or (is_instance_valid(director.instance) and director.instance != director):return
    director.volume_preferences_saving = true
    var revision = director.volume_preferences_revision
    director.volume_preferences_error = director.volume_preferences.save(director.settings_path, director.user_volumes.duplicate(true))
    director.volume_preferences_saving = false
    director.volume_preferences_dirty = director.volume_preferences_error != OK or revision != director.volume_preferences_revision
    var session_key = ProjectSettings.globalize_path(director.settings_path)
    if director.volume_preferences_dirty:
        director.pending_volume_sessions[session_key] = {"values":director.user_volumes.duplicate(true),"error":director.volume_preferences_error}
    else:director.pending_volume_sessions.erase(session_key)


static func user_volume_save_status(director: Node) -> Dictionary:
    return {"persisted":not director.volume_preferences_dirty, "error":director.volume_preferences_error,
        "reason":"" if not director.volume_preferences_dirty else "带*的音量尚未保存，当前会话仍有效；再次调节音量可重试。"}


static func retry_user_volume_save(director: Node) -> Dictionary:
    if director.is_queued_for_deletion() or (is_instance_valid(director.instance) and director.instance != director):
        return {"persisted":false,"error":ERR_UNAVAILABLE,"reason":"当前声音设置页已失效。"}
    if director.volume_preferences_dirty:director._save_user_volumes()
    return director.user_volume_save_status()


static func user_db(director: Node, which: String) -> float:
    var percent: float = clampf(float(director.user_volumes.get(which, 100.0)), 0.0, 100.0)
    if percent <= 0.0:
        return -80.0
    return linear_to_db(percent / 100.0)


static func bus_base_db(director: Node, which: String) -> float:
    var bus_name := String(director.USER_VOLUME_BUS.get(which, "Master"))
    return float(director.BUS_DEFAULT_DB.get(bus_name, 0.0)) + director._user_db(which)


static func music_rest_db(director: Node) -> float:
    return director._bus_base_db("music") + (director.DIALOGUE_MUSIC_DUCK_DB if director.dialogue_open else 0.0)


static func ambience_rest_db(director: Node) -> float:
    return director._bus_base_db("ambience") + (director.DIALOGUE_AMBIENCE_DUCK_DB if director.dialogue_open else 0.0)


static func set_bus_db(director: Node, bus_name: String, value: float) -> void:
    var bus_index := AudioServer.get_bus_index(bus_name)
    if bus_index != -1:
        if bus_name == "BGM":
            director.music_mix_base_db = value
            director._render_music_mix()
        else:AudioServer.set_bus_volume_db(bus_index, value)


static func set_music_bus_db(director: Node, value: float) -> void:
    director._set_bus_db("BGM", value)


static func tween_bus_db(director: Node, bus_name: String, target: float, seconds: float) -> void:
    var bus_index := AudioServer.get_bus_index(bus_name)
    if bus_index == -1:
        return
    var old_tween: Tween = director.bus_tweens.get(bus_name)
    if old_tween != null and old_tween.is_valid():
        old_tween.kill()
    if not director.is_inside_tree():
        AudioServer.set_bus_volume_db(bus_index, target)
        return
    var tween = director.create_tween()
    var start = director.music_mix_base_db if bus_name == "BGM" else AudioServer.get_bus_volume_db(bus_index)
    tween.tween_method(func(value: float) -> void: director._set_bus_db(bus_name, value), start, target, seconds)
    director.bus_tweens[bus_name] = tween
