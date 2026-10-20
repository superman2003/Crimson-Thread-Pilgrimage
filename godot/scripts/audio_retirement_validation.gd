extends SceneTree
const PRESENTATION := preload("res://scripts/seal_presentation.gd")
const RETIREMENT := preload("res://scripts/audio_retirement.gd")
const AUDIO_DIRECTOR := preload("res://scripts/audio_director.gd")
var failures := 0
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var topology_checks := preload("res://scripts/audio_bus_topology_validation.gd").new()
    await topology_checks.run(self, _check_volume)
    await preload("res://scripts/music_phrase_resume_validation.gd").new().run(self, _check_volume)
    var watches := RETIREMENT.observed
    var presentation := PRESENTATION.new()
    root.add_child(presentation)
    for i in range(12):
        presentation.play_action("cleave", "active")
    await physics_frame
    await process_frame
    var voice: AudioStreamPlayer2D = presentation._voices.back()
    var playback: WeakRef = weakref(voice.get_stream_playback())
    var wav: WeakRef = weakref(voice.stream)
    root.remove_child(presentation)
    if voice.playing or voice.stream != null or not presentation._streams.is_empty():
        failures += 1
    presentation.free()
    if RETIREMENT.observed - watches != 12:
        failures += 1
    if not await RETIREMENT.drain(self) or playback.get_ref() != null or wav.get_ref() != null:
        failures += 1

    # Exercise the actual Ogg resource classes used on BGM, ambience and UI
    # buses. Static cache ownership must end with the final audio scene, and
    # the retirement barrier waits on weak references to stream/playback.
    var container := Node.new()
    container.name = "OggRetirementFixture"
    root.add_child(container)
    var ogg_paths := [
        "res://assets/audio/bgm/generated/ch05_obsidian_pilgrim_road_explore_loop.ogg",
        "res://assets/audio/ambience/amb_ch05_os_2.ogg",
        "res://assets/audio/sfx/kenney/interface/open_001.ogg"
    ]
    var ogg_stream_refs: Array[WeakRef] = []
    var ogg_playback_refs: Array[WeakRef] = []
    for path in ogg_paths:
        var stream := AUDIO_DIRECTOR.load_cached(path, path != ogg_paths[2])
        if stream == null:
            failures += 1
            continue
        var ogg_player := AudioStreamPlayer.new()
        ogg_player.bus = "Master"
        ogg_player.stream = stream
        container.add_child(ogg_player)
        ogg_player.play()
        ogg_stream_refs.append(weakref(stream))
    await process_frame
    for child in container.get_children():
        var playback_ogg := (child as AudioStreamPlayer).get_stream_playback()
        if playback_ogg != null:
            ogg_playback_refs.append(weakref(playback_ogg))
    var retired_ogg := RETIREMENT.retire_tree(container)
    AUDIO_DIRECTOR._stream_cache.clear()
    AUDIO_DIRECTOR._npc_voice_cache.clear()
    container.queue_free()
    await process_frame
    if retired_ogg != 3 or not await RETIREMENT.drain(self):
        failures += 1
    for ref in ogg_playback_refs:
        if ref.get_ref() != null:
            failures += 1
    for ref in ogg_stream_refs:
        if ref.get_ref() != null:
            failures += 1
    var volume_checks := preload("res://scripts/audio_user_volume_validation.gd").new()
    await volume_checks.run(self, _check_volume)
    if failures > 0:
        push_error("audio retirement or user-volume regression failed")
    print("AUDIO RETIREMENT PASS: WAV/UI and Ogg BGM/ambience/UI playback/cache retirement, failures=%d" % failures)
    call_deferred("quit", 1 if failures > 0 else 0)

func _check_volume(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        push_error("FAIL: " + label)
