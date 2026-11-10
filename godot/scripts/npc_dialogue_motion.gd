extends AnimatedSprite2D
## Keep authored greeting/talk clocks local to this NPC and its conversation.
var conversation_active := false
var speech_active := false
var presentation_state: StringName = &"idle"
var _speech_player: WeakRef
var _voiced_until := 0.0
var _outside_flip_h := false
var _clocks: Dictionary = {}
const APPROACH_COOLDOWN_MSEC := 8000
var last_approach_greeting_msec := -APPROACH_COOLDOWN_MSEC

func _init() -> void:
    animation_finished.connect(_finish_greeting)

func _ready() -> void:
    var area := get_parent() as Area2D
    if area!=null and not area.body_entered.is_connected(_approached):
        area.body_entered.connect(_approached)

func _approached(body: Node2D) -> void:
    if body.is_in_group("player"): greet_on_approach()

func greet_on_approach() -> bool:
    if conversation_active or (animation==&"greet" and is_playing()): return false
    var now := Time.get_ticks_msec()
    if now-last_approach_greeting_msec<APPROACH_COOLDOWN_MSEC: return false
    if not _start_greeting(): return false
    last_approach_greeting_msec=now
    return true

func begin_conversation() -> void:
    # Showing another line/topic must not restart a greeting or its talk loop.
    if conversation_active: return
    _outside_flip_h = flip_h
    conversation_active = true
    if animation==&"greet" and is_playing(): return
    if not _start_greeting(): _talk_or_idle()

func face_listener(x: float) -> void:
    if conversation_active and absf(x-global_position.x)>1.0:
        flip_h = x < global_position.x

func accepts_utterance() -> bool:
    return conversation_active and is_inside_tree() and not is_queued_for_deletion()

func begin_utterance(player: AudioStreamPlayer, voiced_until: float) -> void:
    if not conversation_active or not is_instance_valid(player): return
    _speech_player = weakref(player)
    _voiced_until = voiced_until
    _refresh_speech()

func end_utterance() -> void:
    _speech_player = null
    speech_active = false
    _talk_or_idle()

func _process(_delta: float) -> void:
    if conversation_active: _refresh_speech()

func _refresh_speech() -> void:
    var player: AudioStreamPlayer = _speech_player.get_ref() as AudioStreamPlayer if _speech_player != null else null
    var speaking := (is_instance_valid(player) and player.is_inside_tree() and not player.is_queued_for_deletion()
        and player.playing and not player.stream_paused and player.get_playback_position() < _voiced_until)
    if speaking != speech_active:
        speech_active = speaking
        _talk_or_idle()

func _remember_clock() -> void:
    if animation in [&"idle", &"talk"]:
        _clocks[animation] = Vector2(frame, frame_progress)

func _play_loop(action: StringName) -> void:
    if animation == action and is_playing(): return
    _remember_clock()
    play(action)
    if _clocks.has(action):
        var clock: Vector2 = _clocks[action]
        set_frame_and_progress(mini(int(clock.x), sprite_frames.get_frame_count(action)-1), clock.y)

func _start_greeting() -> bool:
    if not _usable(&"greet") or sprite_frames.get_animation_loop(&"greet"): return false
    _remember_clock()
    play(&"greet")
    set_frame_and_progress(0,0.0)
    presentation_state = &"greet"
    return true

func end_conversation() -> void:
    conversation_active = false
    speech_active = false
    _speech_player = null
    flip_h = _outside_flip_h
    presentation_state = &"idle"
    if _usable(&"idle"): _play_loop(&"idle")
    else: stop()

func _finish_greeting() -> void:
    if animation != &"greet": return
    if conversation_active: _talk_or_idle()
    elif _usable(&"idle"):
        presentation_state = &"idle"
        _play_loop(&"idle")
    else: stop()

func _talk_or_idle() -> void:
    if animation==&"greet" and is_playing(): return
    presentation_state = &"talk" if conversation_active and speech_active else &"listen" if conversation_active else &"idle"
    if conversation_active and speech_active and _usable(&"talk"): _play_loop(&"talk")
    elif _usable(&"idle"): _play_loop(&"idle")
    else: stop()

func _usable(action: StringName) -> bool:
    return sprite_frames != null and sprite_frames.has_animation(action) \
        and sprite_frames.get_frame_count(action)>0 and sprite_frames.get_animation_speed(action)>0
