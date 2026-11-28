extends SceneTree
## Positioned production-actor fixture with the real AnimatedSprite2D clock.
## It verifies presentation/interruptions, not a natural-route playthrough.
const ENEMY := preload("res://scripts/enemy_actor.gd")
const ART := preload("res://scripts/hand_drawn_assets.gd")
const RETIRE := preload("res://scripts/audio_retirement.gd")
const GROUND_MOTION := preload("res://scripts/character_ground_motion.gd")
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


func check_grounded_locomotion(stage: Node2D) -> void:
    const GROUND_Y := 860.0
    var terrain := StaticBody2D.new()
    var ramp := CollisionPolygon2D.new()
    ramp.polygon = PackedVector2Array([
        Vector2(20, GROUND_Y), Vector2(300, GROUND_Y), Vector2(420, GROUND_Y - 60),
        Vector2(720, GROUND_Y - 60), Vector2(720, GROUND_Y + 100), Vector2(20, GROUND_Y + 100),
    ])
    terrain.add_child(ramp)
    stage.add_child(terrain)

    var walker := ENEMY.new()
    walker.configure({"id": "grounded_patrol", "kind": "moss_larva", "patrol": 185.0, "leash_radius": 1000.0,
        "encounter_profile": {"move_speed": 120.0, "aggro_range": 400.0, "preferred_range": 80.0}}, "")
    walker.position = Vector2(160, GROUND_Y - 40)
    stage.add_child(walker)
    var body: CharacterBody2D = walker.ground_body
    check(body != null, "ordinary enemy uses a separate terrain body")
    if body == null:
        walker.queue_free()
        terrain.queue_free()
        return
    check(body.collision_layer == 0 and walker is Area2D and walker.monitorable,
        "terrain movement is separate from the enemy damage area")
    var gait := walker.speed * 0.72
    var rate_limit := walker.speed * GROUND_MOTION.ACCELERATION / Engine.physics_ticks_per_second
    var previous_speed := 0.0
    var max_change := 0.0
    var max_x := walker.position.x
    var startup_steps := 0
    var braking_steps := 0
    var grounded_on_ramp := 0
    var saw_pause := false
    var reversed := false
    for tick in 300:
        await physics_frame
        var vx := body.velocity.x
        max_change = maxf(max_change, absf(vx - previous_speed))
        if not saw_pause and previous_speed < vx and vx < gait - 0.1:
            startup_steps += 1
        if not saw_pause and vx > 0.1 and vx < previous_speed:
            braking_steps += 1
        if body.global_position.x > 316.0 and body.global_position.x < 344.0 and body.is_on_floor():
            grounded_on_ramp += 1
        max_x = maxf(max_x, walker.position.x)
        saw_pause = saw_pause or walker.patrol_pause_timer > 0.0
        if saw_pause and vx < -0.1:
            reversed = true
            break
        previous_speed = vx
    check(startup_steps >= 3 and braking_steps >= 2 and max_change <= rate_limit + 0.7,
        "live patrol accelerates, brakes and reverses on the shared speed curve")
    check(grounded_on_ramp > 10 and walker.position.y <= GROUND_Y - 45.0,
        "walking enemies use physical floor contact on the ramp")
    check(reversed and max_x > 342.0 and max_x <= 345.15,
        "ordinary patrol pauses at the turn and remains inside its authored range (x %.3f, peak %.3f, paused %s, turned %s)"
            % [walker.position.x, max_x, saw_pause, reversed])

    var wall := StaticBody2D.new()
    var wall_shape := CollisionShape2D.new()
    var box := RectangleShape2D.new()
    box.size = Vector2(20, 240)
    wall_shape.shape = box
    wall.position = Vector2(510, GROUND_Y - 150)
    wall.add_child(wall_shape)
    stage.add_child(wall)
    walker.patrol_distance = 12.0
    walker.ai_commands = []
    var player := CharacterBody2D.new()
    player.position = Vector2(650, GROUND_Y - 60)
    player.add_to_group("player")
    var player_shape := CollisionShape2D.new()
    var player_box := RectangleShape2D.new()
    player_box.size = Vector2(34, 84)
    player_shape.shape = player_box
    player_shape.position.y = -42.0
    player.add_child(player_shape)
    stage.add_child(player)
    walker.last_seen_position = Vector2(630, GROUND_Y - 100)
    walker.memory_timer = 4.0
    walker.ai_profile["aggro_range"] = 700.0
    var blocked := false
    for tick in 160:
        await physics_frame
        if body.is_on_wall():
            blocked = true
            break
    await physics_frame
    check(blocked and walker.position.x + walker.body_size.x * 0.5 <= 500.1,
        "last-seen pursuit stops at a real wall")
    check(walker.animated_sprite.animation != &"walk", "walking animation stops when the enemy is blocked")
    wall.queue_free()
    player.position = Vector2(673, GROUND_Y - 60)
    for tick in 160:
        await physics_frame
        if walker.position.x > 541.0:
            break
    check(walker.position.x > 541.0 and walker.last_ai_decision in ["press", "advance"],
        "a visible target resumes the pursuit once the path opens")
    var chase_speed := body.velocity.x
    walker.ai_profile["preferred_range"] = 124.0
    player.position.x = walker.position.x + 42.0
    var retreated := false
    var reverse_change := 0.0
    for tick in 55:
        await physics_frame
        var vx := body.velocity.x
        reverse_change = maxf(reverse_change, absf(vx - chase_speed))
        chase_speed = vx
        if vx < -1.0 and walker.last_ai_decision == "space":
            retreated = true
            break
    check(retreated and reverse_change <= rate_limit + 0.7,
        "standoff AI eases out of a chase before retreating (last %s, peak speed change %.3f)"
            % [walker.last_ai_decision, reverse_change])

    # A wind-up can begin while a walker is moving. Patrol momentum must
    # not carry damage or move the telegraphed origin.
    var windup_position := walker.global_position
    walker._begin_attack({"id": "grounded_windup", "type": "melee", "windup": 0.25, "active": 0.12})
    for tick in 5:
        await physics_frame
    check(walker.state == "windup" and walker.global_position.is_equal_approx(windup_position)
        and body.velocity.is_zero_approx(), "attack wind-up holds its origin and drops walk momentum")
    walker.reset_for_respawn()
    check(walker.global_position == walker.spawn_position and body.velocity.is_zero_approx(),
        "respawn clears ground velocity and restores the original spawn")
    print("ENEMY_GROUND_MOTION startup=%d braking=%d ramp=%d max_speed_change=%.3f"
        % [startup_steps, braking_steps, grounded_on_ramp, max_change])
    RETIRE.retire_tree(walker)
    walker.queue_free()
    player.queue_free()
    terrain.queue_free()
    await process_frame


func check_waterwheel_gait(stage: Node2D) -> void:
    const PATH := "res://assets/sprites/original_creatures/waterwheel_knight/motion_redraw_manifest.json"
    const ATLAS := "res://assets/sprites/original_creatures/waterwheel_knight/waterwheel_gait_00.png"
    var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/demo_ch02_rain_foundry_canal.json"))
    check(ART.collect_region_assets(config).textures.has(ATLAS), "waterwheel gait atlas belongs to production prewarm")
    var bank := ART.frames(PATH)
    check(bank != null, "production waterwheel frame bank loads")
    if bank == null:return
    for action in [&"turn", &"brake"]:
        var present := bank.has_animation(action) and bank.get_frame_count(action) == 7
        check(present, "ordinary waterwheel has seven authored cels: " + String(action))
        if not present:continue
        var expected := 0.18 if action == &"turn" else 0.16
        check(not bank.get_animation_loop(action) and is_equal_approx(7.0 / bank.get_animation_speed(action), expected),
            "ordinary waterwheel gesture is a short, non-looping transition: " + String(action))
        var regions := {}
        var fixed_canvas := true
        for i in range(7):
            var texture: AtlasTexture = bank.get_frame_texture(action, i)
            fixed_canvas = fixed_canvas and texture.get_size() == Vector2(376,230)
            if i > 0:regions[texture.region] = true
        check(fixed_canvas and regions.size()==6, "six distinct waterwheel drawings retain the logical canvas: " + String(action))
    if not bank.has_animation(&"brake"):return
    var knight := ENEMY.new()
    knight.configure({"kind":"waterwheel_knight","id":"gait_subpixel_contact"}, "")
    knight.position=Vector2(80,300)
    stage.add_child(knight)
    knight.set_physics_process(false)
    knight._set_enemy_animation("walk")
    var last_walk := current_texture(knight)
    knight.motion_transitions.tick(knight,Vector2(.05,0),"patrol")
    knight._set_enemy_animation("idle")
    knight.motion_transitions.tick(knight,Vector2.ZERO,"patrol")
    check(knight.animated_sprite.animation==&"brake" and current_texture(knight)==last_walk,
        "subpixel walking step followed by the real stop preserves the last visible pose")
    check(knight.position==Vector2(80,300),"authored brake never moves the gameplay actor")
    knight.queue_free()



func run() -> void:
    for argument in OS.get_cmdline_user_args():
        if String(argument).begins_with("--output="):output=String(argument).trim_prefix("--output=")
    root.size=Vector2i(960,540)
    root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
    RenderingServer.set_default_clear_color(Color(.06,.08,.09))
    var stage := Stage.new()
    root.add_child(stage)
    check_waterwheel_gait(stage)
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
    await check_grounded_locomotion(stage)
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
