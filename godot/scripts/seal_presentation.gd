extends Node2D
## Original needle/thread/copper action cues. Visual only: never mutates combat stats.
## Add as player child. Effects are world anchored and expire even if the player moves.
const RETIREMENT := preload("res://scripts/audio_retirement.gd")
const IDS := ["crimson", "bell", "salt", "cleave", "needle", "snare", "ward", "shockwave", "crosscut", "shard", "mine", "fog", "lure", "reflux", "spur", "shell", "stride", "mender", "needlecase"]
const MAX_EFFECTS := 8
const MAX_VOICES := 4
var muted := false
var reduced_flash := false
var _effects: Array[Node2D] = []
var _voices: Array[AudioStreamPlayer2D] = []
var _streams: Dictionary = {}

class ActionTrace extends Node2D:
    var action_id := "needle"
    var stage := "active"
    var direction := 1
    var span := 80.0
    var age := 0.0
    var lifetime := 0.24
    var subtle := false
    func _process(delta: float) -> void:
        age += delta
        if age >= lifetime:
            queue_free()
            return
        modulate.a = (0.55 if subtle else 0.85) * (1.0 - age / lifetime)
        queue_redraw()
    func _draw() -> void:
        var copper := Color("d4ad77")
        var thread := Color("be6871")
        var salt := Color("d6d3bd")
        var d := float(direction)
        var growth := clampf(age / maxf(0.04, lifetime * 0.35), 0.0, 1.0)
        var reach := span * (0.4 if stage == "prepare" else 1.0) * growth
        var tip := Vector2(reach * d, -10)
        if stage == "recovery":
            draw_line(Vector2(0, -10), Vector2(22 * d, -6), thread, 1.0)
            return
        match action_id:
            "ward", "bell":
                # Physical crossed needle supports and tension line, no bubble/shield aura.
                draw_line(Vector2(18 * d, -36), Vector2(39 * d, 10), copper, 3.0)
                draw_line(Vector2(40 * d, -36), Vector2(17 * d, 10), copper, 3.0)
                draw_line(Vector2(18 * d, -18), Vector2(38 * d, -18), thread, 2.0)
            "shockwave":
                draw_line(Vector2(0, 16), Vector2(reach * d, 16), copper, 3.0)
                for index in range(3):
                    var x := reach * d * float(index + 1) / 3.0
                    draw_line(Vector2(x, 16), Vector2(x + 8 * d, 3 + index * 3), copper, 2.0)
            "crosscut":
                draw_line(Vector2(-reach * 0.5, -27), Vector2(reach * 0.5, 10), thread, 3.0)
                draw_line(Vector2(reach * 0.5, -27), Vector2(-reach * 0.5, 10), copper, 2.0)
            "snare", "mine":
                for index in range(3):
                    var x := float(index - 1) * 17
                    draw_line(Vector2(x, -8), Vector2(x, 10), copper, 2.0)
                draw_line(Vector2(-20, 5), Vector2(20, -4), thread, 2.0)
                draw_line(Vector2(-20, -4), Vector2(20, 5), thread, 2.0)
            "fog", "salt":
                for index in range(5):
                    var x := float(index - 2) * 12
                    var y := -10 + sin(age * 8 + index) * 7
                    draw_line(Vector2(x, y), Vector2(x + 6, y - 2), salt, 2.0)
            "lure", "shard":
                draw_line(Vector2(-8, 4), Vector2(-6, -13), copper, 3.0)
                draw_line(Vector2(-6, -13), Vector2(6, -13), copper, 3.0)
                draw_line(Vector2(6, -13), Vector2(8, 4), copper, 3.0)
                draw_line(Vector2(-11, 7), Vector2(11, 7), copper, 2.0)
                draw_line(Vector2(0, 7), Vector2(0, 13), thread, 2.0)
            "unblockable":
                # Unified broken copper cross: reserves saturated red for this danger cue.
                draw_line(Vector2(-15, -15), Vector2(15, 15), Color("ee6a58"), 4.0)
                draw_line(Vector2(15, -15), Vector2(-15, 15), Color("ee6a58"), 4.0)
                draw_line(Vector2(-20, -5), Vector2(-25, -5), copper, 2.0)
                draw_line(Vector2(20, 5), Vector2(25, 5), copper, 2.0)
            _:
                draw_line(Vector2(0, -10), tip, salt, 2.0)
                draw_line(tip, tip + Vector2(-8 * d, -3), copper, 2.0)
                draw_polyline(PackedVector2Array([Vector2(0, -7), Vector2(reach * d * 0.4, -2), Vector2(reach * d * 0.7, -15), tip]), thread, 1.5)

func play_action(action_id: String, stage: String, direction: int = 1, details: Dictionary = {}) -> void:
    if not IDS.has(action_id) or not ["prepare", "active", "recovery"].has(stage):
        return
    var trace := _trace(action_id, stage, global_position, direction)
    trace.span = clampf(float(details.get("range", 80.0)), 16.0, 240.0)
    trace.lifetime = {"prepare": 0.16, "active": 0.25, "recovery": 0.13}[stage]
    if stage != "recovery":
        _sound(action_id + "_" + stage, global_position)

func play_hit(action_id: String, world_position: Vector2) -> void:
    if not IDS.has(action_id):
        return
    var trace := _trace(action_id, "active", world_position, 1)
    trace.span = 20
    trace.lifetime = 0.13
    _sound(action_id + "_hit", world_position)

func cue_unblockable(world_position: Vector2) -> void:
    var trace := _trace("unblockable", "active", world_position, 1)
    trace.lifetime = 0.35
    _sound("unblockable", world_position)

func _trace(action_id: String, stage: String, world_position: Vector2, direction: int) -> ActionTrace:
    _effects = _effects.filter(func(effect): return is_instance_valid(effect) and not effect.is_queued_for_deletion())
    if _effects.size() >= MAX_EFFECTS:
        _effects.pop_front().queue_free()
    var trace := ActionTrace.new()
    trace.action_id = action_id
    trace.stage = stage
    trace.direction = 1 if direction >= 0 else -1
    trace.subtle = reduced_flash
    trace.z_index = 8
    add_child(trace)
    trace.top_level = true
    trace.global_position = world_position
    _effects.append(trace)
    return trace

func _sound(cue: String, world_position: Vector2) -> void:
    if muted:
        return
    var path := "res://assets/audio/seals/" + cue + ".wav"
    if not _streams.has(cue):
        if not ResourceLoader.exists(path):
            return
        _streams[cue] = load(path)
    _voices = _voices.filter(func(voice): return is_instance_valid(voice) and not voice.is_queued_for_deletion())
    if _voices.size() >= MAX_VOICES:
        var oldest := _voices.pop_front() as AudioStreamPlayer2D
        _retire_voice(oldest)
        oldest.queue_free()
    var voice := AudioStreamPlayer2D.new()
    voice.stream = _streams[cue]
    voice.volume_db = -6
    voice.max_distance = 1200
    if AudioServer.get_bus_index("SFX") >= 0:
        voice.bus = "SFX"
    add_child(voice)
    voice.top_level = true
    voice.global_position = world_position
    voice.finished.connect(voice.queue_free)
    voice.tree_exiting.connect(_retire_voice.bind(voice))
    _voices.append(voice)
    voice.play()
    RETIREMENT.watch(voice)

func active_effect_count() -> int:
    return _effects.filter(func(effect): return is_instance_valid(effect) and not effect.is_queued_for_deletion()).size()


func _retire_voice(voice: AudioStreamPlayer2D) -> void:
    # Node deletion alone can leave the AudioServer playback holding its WAV
    # until a later mix tick, especially with accelerated headless physics.
    voice.stop()
    voice.stream = null


func _exit_tree() -> void:
    for voice in _voices:
        if is_instance_valid(voice):
            _retire_voice(voice)
    _voices.clear()
    _streams.clear()
