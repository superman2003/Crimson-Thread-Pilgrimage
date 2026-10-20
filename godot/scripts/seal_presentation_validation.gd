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
    presentation.play_action("cleave", "active")
    var evicted_voice: AudioStreamPlayer2D = presentation._voices.back()
    for unused in range(PRESENTATION.MAX_VOICES):
        presentation.play_action("needle", "active")
    _check(evicted_voice.is_queued_for_deletion() and not evicted_voice.playing and evicted_voice.stream == null, "voice cap releases playback before queued deletion")
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
    # Retire while the cue is still playing; waiting for completion hid the
    # shutdown race seen by world_upgrade on fast headless CI runners.
    presentation.muted = false
    presentation.play_action("cleave", "active")
    var retiring_voice: AudioStreamPlayer2D = presentation._voices.back()
    _check(retiring_voice.playing, "cleave cue active before retirement")
    root.remove_child(presentation)
    _check(not retiring_voice.playing and retiring_voice.stream == null, "retirement releases live playback and stream")
    _check(presentation._streams.is_empty() and presentation._voices.is_empty(), "retirement clears local audio ownership")
    presentation.free()
    await process_frame
    await _global_trace_budget()
    print("SEAL_PRESENTATION_VALIDATION: %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)

func _global_trace_budget() -> void:
    var policy := preload("res://scripts/combat_visual_policy.gd")
    var stage := Node2D.new(); root.add_child(stage)
    stage.z_index = 200
    var actors: Array[Node2D] = []
    for index in range(20):
        var actor := PRESENTATION.new(); actor.muted = true; stage.add_child(actor); actors.append(actor)
        actor.play_action("needle", "active")
    var traces := get_nodes_in_group(policy.ACTION_TRACE_GROUP)
    _check(traces.size() == policy.MAX_ACTION_TRACES, "twenty owners share eight harmless action traces")
    for trace in traces:
        _check(not trace.z_as_relative and trace.z_index == policy.BLADE_Z, "parent decorative Z cannot raise an action trace over danger")
    for actor in actors: actor.cue_unblockable(Vector2(50, 60))
    for actor in actors:
        var warning = actor._effects.back()
        _check(warning.action_id == "unblockable" and warning.z_index == policy.WARNING_Z and not warning.z_as_relative, "saturated cosmetics cannot reject or lower a real unblockable cue")
        for burst in range(12): actor.play_action("cleave", "active")
        _check(not warning.is_queued_for_deletion(), "ordinary attacks never evict an existing warning")
    _check(get_nodes_in_group(policy.ACTION_TRACE_GROUP).size() == policy.MAX_ACTION_TRACES, "warnings do not consume or expand decorative capacity")
    actors[0].queue_free(); await process_frame
    actors.back().play_action("needle", "active")
    var active := 0
    for trace in get_nodes_in_group(policy.ACTION_TRACE_GROUP):
        if not trace.is_queued_for_deletion(): active += 1
    _check(active == policy.MAX_ACTION_TRACES, "retiring an owner releases its cosmetic slot immediately")
    stage.queue_free(); await process_frame; await process_frame
    _check(get_nodes_in_group(policy.ACTION_TRACE_GROUP).is_empty(), "scene retirement releases all global trace membership")
