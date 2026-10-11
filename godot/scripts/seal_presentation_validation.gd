extends SceneTree
const PRESENTATION := preload("res://scripts/seal_presentation.gd")
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
    presentation.queue_free()
    await process_frame
    print("SEAL_PRESENTATION_VALIDATION: %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)
