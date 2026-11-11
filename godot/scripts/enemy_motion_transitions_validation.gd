extends SceneTree
## Positioned production-actor fixture with the real AnimatedSprite2D clock.
## It verifies presentation/interruptions, not a natural-route playthrough.
const ENEMY := preload("res://scripts/enemy_actor.gd")
const ART := preload("res://scripts/hand_drawn_assets.gd")
const RETIRE := preload("res://scripts/audio_retirement.gd")
var checks := 0
var failures := 0
var seen := {}
var output := ""

class Stage extends Node2D:
    var chapter_terrain: Node = null

func _initialize() -> void:call_deferred("run")

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("ENEMY_MOTION_TRANSITIONS: "+label)

func current_texture(actor) -> Texture2D:
    var sprite: AnimatedSprite2D = actor.animated_sprite
    return sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame)

func face(actor, flip: bool) -> void:
    actor.requested_sprite_flip = not flip if actor.sprite_faces_left else flip
    actor._apply_sprite_flip()

func wait_seconds(seconds: float) -> void:
    await create_timer(seconds).timeout

func watch(actor) -> void:
    var sprite: AnimatedSprite2D = actor.animated_sprite
    if sprite.animation in [&"turn",&"brake"]:
        seen["%s#%d" % [sprite.animation,sprite.frame]]=true

func finish(actor) -> void:
    var deadline := Time.get_ticks_msec()+1500
    while not actor.motion_transitions.active.is_empty() and Time.get_ticks_msec()<deadline:
        await process_frame
    check(actor.motion_transitions.active.is_empty(),"real animation clock finishes gesture")

func run() -> void:
    for argument in OS.get_cmdline_user_args():
        if String(argument).begins_with("--output="):output=String(argument).trim_prefix("--output=")
    root.size=Vector2i(960,540)
    root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
    RenderingServer.set_default_clear_color(Color(.06,.08,.09))
    var stage := Stage.new()
    root.add_child(stage)
    var actors: Array = []
    for index in 2:
        var actor := ENEMY.new()
        actor.configure({"kind":"moss_larva","id":"transition_%d" % index,"hp":999},"")
        actor.position=Vector2(400+index*140,300)
        stage.add_child(actor)
        actor.set_physics_process(false)
        actors.append(actor)
    var actor = actors[0]
    var twin = actors[1]
    var sprite: AnimatedSprite2D = actor.animated_sprite
    sprite.frame_changed.connect(watch.bind(actor))
    var shared: SpriteFrames = sprite.sprite_frames
    var original_turn: Texture2D = shared.get_frame_texture(&"turn",0)
    check(twin.animated_sprite.sprite_frames==shared,"actors initially share immutable cached frames")
    var rig_scale: Vector2 = sprite.scale
    var rig_position: Vector2 = sprite.position
    for action in [&"turn",&"brake"]:
        check(shared.get_frame_count(action)==7 and not shared.get_animation_loop(action),String(action)+" has six authored drawings and a starting pose")
        for index in shared.get_frame_count(action):
            check(shared.get_frame_texture(action,index).get_size()==Vector2(332,241),"every gesture pose has the fixed logical canvas")
    actor._set_enemy_animation("walk")
    sprite.set_frame_and_progress(3,.3)
    var visible := current_texture(actor)
    var initial_flip: bool = sprite.flip_h
    face(actor,not initial_flip)
    check(actor.motion_transitions.active.is_empty(),"spawn orientation changes immediately before first movement tick")
    face(actor,initial_flip)
    actor.motion_transitions.tick(actor,Vector2(1,0),"patrol")
    face(actor,not initial_flip)
    check(actor.motion_transitions.active==&"turn" and sprite.flip_h==initial_flip,"facing change starts authored pivot before horizontal flip")
    check(current_texture(actor)==visible,"pivot starts on the exact previously visible walking cel")
    check(sprite.sprite_frames!=shared and twin.animated_sprite.sprite_frames==shared,"gesture edits only this actor's frame bank")
    check(shared.get_frame_texture(&"turn",0)==original_turn,"cached starting pose remains immutable")
    actor._set_enemy_animation("idle")
    check(sprite.animation==&"turn","ordinary loop requests cannot overwrite a pivot")
    await finish(actor)
    check(sprite.flip_h!=initial_flip and sprite.animation==&"idle","completion commits facing and the latest requested loop")
    check(sprite.sprite_frames.get_frame_texture(&"turn",0)==original_turn,"completion restores the instance's original gesture start")
    for index in range(1,7):check(seen.has("turn#%d" % index),"actual playback visits turn drawing %d" % index)
    check(sprite.scale==rig_scale and sprite.position==rig_position,"turn keeps scale and local anchor exact")

    # Reverse request, pause on a painted pose, then request the other facing.
    face(actor,initial_flip)
    await wait_seconds(.055)
    actor._set_combat_visuals_paused(true)
    var held_frame := sprite.frame
    var held_progress := sprite.frame_progress
    await wait_seconds(.10)
    check(sprite.frame==held_frame and is_equal_approx(sprite.frame_progress,held_progress),"UI pause freezes the real gesture clock")
    face(actor,not initial_flip)
    check(sprite.flip_h!=initial_flip,"rapid reversal cannot flip midway through a pivot")
    actor._set_combat_visuals_paused(false)
    await finish(actor)
    check(sprite.flip_h==initial_flip,"paused reverse pivot completes in its captured direction")
    face(actor,not initial_flip)
    check(actor.motion_transitions.active==&"turn","latest facing can start the following pivot")
    var hit_texture := current_texture(actor)
    actor.take_hit(1,1)
    actor.motion_transitions.tick(actor,Vector2.ZERO,"patrol")
    check(current_texture(actor)==hit_texture and sprite.animation==&"turn","hit overlays the exact gesture pose already visible")
    check(actor.flash_timer>0 and actor.knockback_velocity>0,"accepted hit retains production flash and knockback")
    check(sprite.scale==rig_scale and sprite.position==rig_position,"accepted hit cannot resize or shift the local art rig")
    await finish(actor)
    actor.state="patrol"
    actor.active_attack={}

    # The actual measured movement feeds the presentation controller; no AI
    # timers or actor displacement are owned by that controller.
    actor._set_enemy_animation("walk")
    sprite.set_frame_and_progress(5,.2)
    var walk_texture := current_texture(actor)
    actor.motion_transitions.tick(actor,Vector2(1,0),"patrol")
    actor._set_enemy_animation("idle")
    var before: Vector2 = actor.position
    actor.motion_transitions.tick(actor,Vector2.ZERO,"patrol")
    check(sprite.animation==&"brake" and current_texture(actor)==walk_texture,"measured movement-to-idle starts on the last moving pose")
    check(actor.position==before,"braking presentation never moves the gameplay actor")
    await finish(actor)
    for index in range(1,7):check(seen.has("brake#%d" % index),"actual playback visits brake drawing %d" % index)
    actor.motion_transitions.tick(actor,Vector2.ZERO,"patrol")
    check(actor.motion_transitions.active.is_empty(),"continued idle does not restart braking")

    face(actor,not sprite.flip_h)
    var command: Dictionary = actor.ai_commands[0]
    actor.state="windup"
    actor.active_attack=command
    actor._pose_sprite("windup",command)
    check(actor.motion_transitions.active.is_empty() and sprite.animation!=&"turn","real attack poses interrupt presentation immediately")
    check(absf(actor._animation_seconds(String(sprite.animation))/sprite.speed_scale-float(command.windup))<.001,"attack windup retains the exact configured deadline")
    actor.state="patrol"
    actor.active_attack={}
    actor._set_enemy_animation("idle")
    face(actor,not sprite.flip_h)
    actor._set_enemy_animation("phase",true)
    check(actor.motion_transitions.active.is_empty(),"phase presentation interrupts movement gestures")
    actor._set_enemy_animation("idle")
    face(actor,not sprite.flip_h)
    actor.set_meta("world_residency_active",false)
    actor.motion_transitions.suspend(actor)
    check(actor.motion_transitions.active.is_empty() and not sprite.is_playing(),"retiring a room cancels and pauses its gesture")
    actor.set_meta("world_residency_active",true)
    actor._set_enemy_animation("idle")
    check(sprite.is_playing(),"returning to a resident room resumes its ordinary loop")
    check(sprite.scale==rig_scale and sprite.position==rig_position,"all interruption paths retain fixed rig geometry")
    var live := ENEMY.new()
    live.configure({"kind":"moss_larva","id":"transition_patrol","hp":999,"patrol":30},"")
    live.position=Vector2(700,300)
    stage.add_child(live)
    live.set_physics_process(false)
    live._physics_process(1.0/60.0)
    check(live.motion_transitions.initialized and live.animated_sprite.animation==&"walk","production physics hook observes patrol movement")
    live.position.x=live.start_x+31
    live._physics_process(1.0/60.0)
    var boundary: Vector2 = live.position
    live._physics_process(1.0/60.0)
    check(live.animated_sprite.animation==&"brake" and live.position==boundary,"production patrol pause triggers braking without extra displacement")
    await finish(live)
    live.patrol_pause_timer=.025
    live._physics_process(1.0/60.0)
    check(live.animated_sprite.animation==&"turn","production patrol reversal triggers the painted pivot")
    live.hide()
    live.motion_transitions.suspend(live)
    twin.motion_transitions.tick(twin,Vector2.ZERO,"patrol")
    face(twin,not twin.animated_sprite.flip_h)
    twin.take_hit(9999,1)
    check(twin.dying and twin.motion_transitions.active.is_empty() and twin.animated_sprite.animation==&"death","lethal hit immediately replaces the movement gesture with death")
    if not output.is_empty():
        DirAccess.make_dir_recursive_absolute(output)
        actor._set_flash_amount(0.0)
        actor.flash_timer=0.0
        await wait_seconds(.7)
        for action in [&"turn",&"brake"]:
            sprite.play(action)
            sprite.pause()
            for index in range(1,7):
                sprite.set_frame_and_progress(index,0.0)
                await RenderingServer.frame_post_draw
                check(root.get_texture().get_image().save_png(output+"/%s-%02d.png" % [action,index])==OK,"save actual rendered gesture pose")
    RETIRE.retire_tree(root)
    preload("res://scripts/audio_director.gd")._stream_cache.clear()
    stage.queue_free()
    await process_frame
    await process_frame
    check(await RETIRE.drain(self),"audio voices retired")
    print("ENEMY_MOTION_TRANSITIONS checks=%d failures=%d" % [checks,failures])
    quit(0 if failures==0 else 1)
