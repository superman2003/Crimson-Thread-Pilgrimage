extends SceneTree
const PRESENTATION := preload("res://scripts/seal_presentation.gd")
const AUDIO_RETIREMENT := preload("res://scripts/audio_retirement_probe.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
    call_deferred("_run")
func _check(condition: bool, label: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        print("FAIL: " + label)
func _run() -> void:
    var presentation := PRESENTATION.new()
    root.add_child(presentation)
    for action in PRESENTATION.IDS:
        var icon := load("res://assets/ui/seals/" + action + ".svg") as Texture2D
        _check(icon != null and icon.get_width() == 64 and icon.get_height() == 64, action + " distinct icon imports")
        for stage in ["prepare", "active", "hit"]:
            var stream := load("res://assets/audio/seals/" + action + "_" + stage + ".wav") as AudioStreamWAV
            _check(stream != null and stream.get_length() >= 0.1 and stream.get_length() <= 0.3, action + "/" + stage + " finite cue")
        presentation.play_action(action, "prepare", -1)
        presentation.play_action(action, "active", 1)
        presentation.play_action(action, "recovery", 1)
        presentation.play_hit(action, Vector2(100, 100))
        _check(presentation.active_effect_count() <= PRESENTATION.MAX_EFFECTS, "action burst effect cap")
        _check(presentation._voices.size() <= PRESENTATION.MAX_VOICES, "action burst audio cap")
    presentation.cue_unblockable(Vector2(150, 100))
    _check(presentation.active_effect_count() <= 8, "danger cue shares bounded pool")
    var anchored = presentation._effects.back()
    var before: Vector2 = anchored.global_position
    presentation.position += Vector2(500, 500)
    _check(anchored.global_position.is_equal_approx(before), "effects stay at world origin during movement")
    var count := presentation.active_effect_count()
    presentation.play_action("invalid", "active")
    _check(presentation.active_effect_count() == count, "unknown action rejected")
    await create_timer(0.65).timeout
    _check(presentation.active_effect_count() == 0, "all traces expire")
    presentation.muted = true
    presentation._voices = presentation._voices.filter(func(voice): return is_instance_valid(voice))
    var voice_count := presentation._voices.size()
    presentation.play_action("needle", "active")
    _check(presentation._voices.size() == voice_count, "mute produces no audio player")
    await create_timer(0.4).timeout
    var audio_refs := AUDIO_RETIREMENT.stream_refs(presentation)
    presentation.queue_free()
    await process_frame
    _check(await AUDIO_RETIREMENT.wait_for_release(self, audio_refs), "expired presentation releases audio resources")
    # Retire a scene with an unfinished cue, rather than only after expiry.
    var retiring := PRESENTATION.new()
    root.add_child(retiring)
    retiring.play_action("cleave", "active")
    _check(retiring._voices.size() == 1, "retirement fixture starts a real cue")
    var retiring_voice: AudioStreamPlayer2D = retiring._voices[0]
    audio_refs = AUDIO_RETIREMENT.stream_refs(retiring)
    root.remove_child(retiring)
    _check(not retiring_voice.playing and retiring_voice.stream == null, "retirement stops and detaches unfinished playback")
    _check(retiring._voices.is_empty() and retiring._streams.is_empty(), "retirement releases voice and stream caches")
    retiring.free()
    _check(await AUDIO_RETIREMENT.wait_for_release(self, audio_refs), "unfinished playback resources retire before shutdown")
    var retained := AudioStreamWAV.new()
    var retained_refs := [weakref(retained)]
    _check(not await AUDIO_RETIREMENT.wait_for_release(self, retained_refs, 10), "retained resource fails bounded retirement wait")
    retained = null
    _check(await AUDIO_RETIREMENT.wait_for_release(self, retained_refs), "released resource completes retirement wait")
    print("SEAL_PRESENTATION_VALIDATION: %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)
