extends AnimatedSprite2D
## Keep authored greeting/talk clocks local to this NPC and its conversation.
var conversation_active := false
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
    conversation_active = true
    if animation==&"greet" and is_playing(): return
    if not _start_greeting(): _talk_or_idle()

func _start_greeting() -> bool:
    if not _usable(&"greet") or sprite_frames.get_animation_loop(&"greet"): return false
    play(&"greet")
    set_frame_and_progress(0,0.0)
    return true

func end_conversation() -> void:
    conversation_active = false
    if _usable(&"idle"): play(&"idle")
    else: stop()

func _finish_greeting() -> void:
    if animation != &"greet": return
    if conversation_active: _talk_or_idle()
    elif _usable(&"idle"): play(&"idle")
    else: stop()

func _talk_or_idle() -> void:
    if _usable(&"talk"): play(&"talk")
    elif _usable(&"idle"): play(&"idle")
    else: stop()

func _usable(action: StringName) -> bool:
    return sprite_frames != null and sprite_frames.has_animation(action) \
        and sprite_frames.get_frame_count(action)>0 and sprite_frames.get_animation_speed(action)>0
