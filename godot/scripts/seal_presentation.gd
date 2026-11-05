extends Node2D
## Original needle/thread/copper action cues. Visual only: never mutates combat stats.
## Add as player child. Effects are world anchored and expire even if the player moves.
const RETIREMENT := preload("res://scripts/audio_retirement.gd")
const POLICY := preload("res://scripts/combat_visual_policy.gd")
const IDS := ["crimson", "bell", "salt", "cleave", "needle", "snare", "ward", "shockwave", "crosscut", "shard", "mine", "fog", "lure", "reflux", "spur", "shell", "stride", "mender", "needlecase"]
const MAX_EFFECTS := 8
const MAX_VOICES := 4
const AUDIO := preload("res://scripts/audio_director.gd")
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
        # Dedicated enemy warning remains visible; player attacks emit no lines.
        if action_id != "unblockable": return
        draw_line(Vector2(-15,-15),Vector2(15,15),Color("ee6a58"),4.0)
        draw_line(Vector2(15,-15),Vector2(-15,15),Color("ee6a58"),4.0)
        draw_line(Vector2(-20,-5),Vector2(-25,-5),Color("d4ad77"),2.0)
        draw_line(Vector2(20,5),Vector2(25,5),Color("d4ad77"),2.0)

func play_action(action_id: String, stage: String, _direction: int = 1, _details: Dictionary = {}) -> void:
    if not IDS.has(action_id) or not ["prepare", "active", "recovery"].has(stage):
        return
    if stage != "recovery":
        _sound(action_id + "_" + stage, global_position)

func play_hit(action_id: String, world_position: Vector2) -> void:
    if not IDS.has(action_id):
        return
    _sound(action_id + "_hit", world_position)

func cue_unblockable(world_position: Vector2) -> void:
    var trace := _trace("unblockable", "active", world_position, 1)
    if trace != null: trace.lifetime = 0.35
    _sound("unblockable", world_position)

func _trace(action_id: String, stage: String, world_position: Vector2, direction: int) -> ActionTrace:
    if action_id != "unblockable": return null
    _effects = _effects.filter(func(effect): return is_instance_valid(effect) and not effect.is_queued_for_deletion())
    if _effects.size() >= MAX_EFFECTS:
        var oldest_decoration := -1
        for index in range(_effects.size()):
            if _effects[index].action_id != "unblockable":
                oldest_decoration = index
                break
        if oldest_decoration >= 0:
            _effects[oldest_decoration].queue_free()
            _effects.remove_at(oldest_decoration)
        elif action_id == "unblockable":
            _effects.pop_front().queue_free()
        else:
            return null
    var trace := ActionTrace.new()
    trace.action_id = action_id
    trace.stage = stage
    trace.direction = 1 if direction >= 0 else -1
    trace.subtle = reduced_flash
    if not POLICY.attach_action_trace(self, trace, action_id == "unblockable"):
        return null
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
    var priority := 0 if cue == "unblockable" else 2
    if _voices.size() >= MAX_VOICES:
        var victim := -1
        var victim_priority := priority-1
        for index in _voices.size():
            var candidate_priority := int(_voices[index].get_meta("voice_priority",2))
            if candidate_priority >= priority and candidate_priority > victim_priority:
                victim=index
                victim_priority=candidate_priority
        if victim < 0:return
        var oldest := _voices.pop_at(victim) as AudioStreamPlayer2D
        _retire_voice(oldest)
        oldest.queue_free()
    var ticket := AUDIO.reserve_voice("seal_"+cue,priority,0,AUDIO.MAX_GLOBAL_VOICES)
    if ticket == 0:return
    var voice := AudioStreamPlayer2D.new()
    voice.set_meta("voice_priority",priority)
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
    AUDIO.start_reserved_voice(ticket,voice)
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
