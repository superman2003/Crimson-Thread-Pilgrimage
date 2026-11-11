extends RefCounted
## Optional authored presentation gestures. Combat, displacement, collision and
## hit reactions retain their production clocks; only idle/walk may yield here.
var active: StringName = &""
var pending_loop: StringName = &"idle"
var from_flip := false
var target_flip := false
var initialized := false
var was_moving := false
var previous_texture: Texture2D

func _available(actor, action: StringName) -> bool:
    return actor.original_visual and is_instance_valid(actor.animated_sprite) \
        and actor.animated_sprite.sprite_frames != null \
        and actor.animated_sprite.sprite_frames.has_animation(action) \
        and actor.animated_sprite.sprite_frames.get_frame_count(action) >= 2

func _eligible(actor) -> bool:
    return not actor.dying and not actor.is_queued_for_deletion() \
        and actor.state == "patrol" and actor.phase_pause <= 0 \
        and not actor.combat_visuals_paused and actor.world_residency_active()

func _texture(actor) -> Texture2D:
    var sprite: AnimatedSprite2D = actor.animated_sprite
    if sprite == null or sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(sprite.animation):return null
    return sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame)

func request_loop(actor, action: String, restart: bool) -> bool:
    if action in ["idle","walk"]:
        pending_loop = StringName(action)
        if not active.is_empty() and not restart:return true
    if not active.is_empty():cancel(actor)
    return false

func request_flip(actor, wanted: bool, allow_start: bool) -> bool:
    if not active.is_empty():
        actor.sprite.set("flip_h",from_flip)
        return true
    if allow_start and initialized and _eligible(actor) and _available(actor,&"turn") \
            and bool(actor.sprite.get("flip_h")) != wanted:
        _begin(actor,&"turn",wanted,_texture(actor))
        return true
    return false

func _begin(actor, action: StringName, wanted: bool, start_texture: Texture2D) -> void:
    var sprite: AnimatedSprite2D = actor.animated_sprite
    # Reuse the exact previously visible cel as this instance's starting pose.
    # Cached artwork and another creature's SpriteFrames remain immutable.
    if sprite.sprite_frames != actor.pose_owned_frames:
        actor.pose_source_frames = sprite.sprite_frames
        actor.pose_owned_frames = sprite.sprite_frames.duplicate(false) as SpriteFrames
        sprite.sprite_frames = actor.pose_owned_frames
    if start_texture != null:
        sprite.sprite_frames.set_frame(action,0,start_texture)
    from_flip = bool(sprite.flip_h)
    target_flip = wanted if action==&"turn" else from_flip
    active = action
    actor.current_animation_has_explicit_direction = false
    sprite.speed_scale = 1.0
    sprite.flip_h = from_flip
    sprite.play(action)
    sprite.set_frame_and_progress(0,0.0)

func tick(actor, motion: Vector2, previous_state: String) -> void:
    if not actor.original_visual or not is_instance_valid(actor.animated_sprite):return
    var moving := motion.length_squared() > .01
    if not active.is_empty():
        # An ordinary hit keeps its visible pose and white flash. Its short
        # empty-attack recovery may finish the gesture without changing size.
        var hit_recovery: bool = actor.state=="recover" and actor.active_attack.is_empty()
        if actor.state != "patrol" and not hit_recovery:cancel(actor)
    elif initialized and _eligible(actor) and previous_state=="patrol" \
            and was_moving and not moving and pending_loop==&"idle" and _available(actor,&"brake"):
        _begin(actor,&"brake",bool(actor.sprite.get("flip_h")),previous_texture)
    was_moving = moving if actor.state=="patrol" else false
    previous_texture = _texture(actor)
    initialized = true

func _restore_start(actor) -> void:
    if active.is_empty() or actor.pose_owned_frames==null or actor.pose_source_frames==null:return
    if actor.pose_source_frames.has_animation(active):
        actor.pose_owned_frames.set_frame(active,0,actor.pose_source_frames.get_frame_texture(active,0),
            actor.pose_source_frames.get_frame_duration(active,0))

func completed(actor) -> void:
    if active.is_empty() or actor.animated_sprite.animation!=active:return
    _restore_start(actor)
    actor.sprite.set("flip_h",target_flip)
    active = &""
    var sprite: AnimatedSprite2D = actor.animated_sprite
    var loop_name: StringName = pending_loop if sprite.sprite_frames.has_animation(pending_loop) else &"idle"
    sprite.speed_scale = 1.0
    sprite.play(loop_name)
    previous_texture = _texture(actor)

func cancel(actor) -> void:
    if active.is_empty():return
    _restore_start(actor)
    if is_instance_valid(actor.sprite):actor.sprite.set("flip_h",target_flip)
    active = &""

func suspend(actor) -> void:
    if not active.is_empty():
        cancel(actor)
        if is_instance_valid(actor.animated_sprite):actor.animated_sprite.pause()
    was_moving = false
    initialized = false
    previous_texture = null
