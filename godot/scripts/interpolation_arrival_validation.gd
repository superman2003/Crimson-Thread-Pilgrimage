extends SceneTree
## Real production teleport/animation handlers, sampled between physics ticks.
## Run with a real renderer at --fixed-fps 240 and production 60 Hz physics.
const PLAYER_SCENE = preload("res://scenes/Player.tscn")
const RETIRE = preload("res://scripts/audio_retirement.gd")
var checks := 0
var failures := 0

class Stage extends Node2D:
    var chapter_terrain: Node = null

class MarkerEnemy extends "res://scripts/enemy_actor.gd":
    func _draw() -> void:draw_rect(Rect2(-8,-8,16,16),Color.MAGENTA)
    func _effect(_kind: String, _point: Vector2, _velocity: Vector2, _command: Dictionary, _delay: float, _life: float) -> Node2D:return null
    func _play_attack_sfx(_phase: String) -> void:pass

class MarkerPlayer extends "res://scripts/player_controller.gd":
    var arrival_calls := 0
    func _draw() -> void:draw_rect(Rect2(-8,-8,16,16),Color.MAGENTA)
    func reset_camera_after_arrival() -> void:
        arrival_calls += 1
        super()

class TrialLevel extends "res://scripts/main_level.gd":
    # Exercise the real two trial entry points while isolating unrelated world
    # streaming, audio, rewards and encounter scheduling.
    func _ready() -> void:pass
    func _open_all_shortcuts(_show_toast: bool = true) -> void:pass
    func _spawn_boss() -> void:pass
    func _update_room_visit() -> void:pass
    func _toast(_text: String) -> void:pass
    func _refresh_hud() -> void:pass
    func _set_boss_arena_locked(_locked: bool) -> void:pass
    func _clear_active_challenge(_grant_if_empty: bool) -> void:pass
    func _defer_region_call(_method: StringName, _arguments: Array = []) -> void:pass

func _initialize() -> void:call_deferred("run")

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("INTERPOLATION_ARRIVAL: " + label)

func settle(node: Node2D) -> void:
    node.global_position = Vector2(120,140)
    node.reset_physics_interpolation()
    for tick in 3:await physics_frame

func marker_x() -> float:
    var pixels := root.get_texture().get_image()
    var total := 0
    var sum_x := 0.0
    for x in range(20,940):
        var color := pixels.get_pixel(x,140)
        if color.r > .99 and color.g < .01 and color.b > .99:
            total += 1
            sum_x += x
    return sum_x/total if total > 0 else -1.0

func visible_arrival(node: Node2D, label: String) -> void:
    var sampled := 0
    for frame in 5:
        await process_frame
        await RenderingServer.frame_post_draw
        var fraction := Engine.get_physics_interpolation_fraction()
        if fraction <= .05 or fraction >= .95:continue
        var x := marker_x()
        if sampled == 0:
            print("ARRIVAL_SAMPLE %s physics_x=%.1f rendered_x=%.1f fraction=%.3f" % [label,node.global_position.x,x,fraction])
        check(x >= 0,label+" produces visible marker pixels")
        check(absf(x-(node.global_position.x-.5))<2,label+" renders at its landing between physics ticks")
        sampled += 1
    check(sampled > 0,label+" samples a fractional render frame")

func run() -> void:
    if DisplayServer.get_name() == "headless":
        check(false,"real GL is required for interpolation pixels")
        print("INTERPOLATION_ARRIVAL checks=%d failures=%d" % [checks,failures])
        quit(1)
        return
    check(Engine.physics_ticks_per_second==60,"production physics clock remains 60Hz")
    root.size = Vector2i(960,240)
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    RenderingServer.set_default_clear_color(Color.BLACK)
    var stage := Stage.new()
    root.add_child(stage)
    for boss in [true,false]:
        var actor := MarkerEnemy.new()
        actor.configure({"kind":"silent_pilgrim_commander" if boss else "moss_larva","id":"interpolation_marker","hp":999},"",boss)
        actor.position = Vector2(120,140)
        stage.add_child(actor)
        actor.set_physics_process(false)
        actor.sprite.hide()
        await settle(actor)
        actor.attack_direction = 1
        actor.attack_target = Vector2(915,140)
        actor.boss_blink_destination = Vector2(800,140)
        var command := {"id":"interpolation_probe","type":"blink","blink_offset":115}
        if boss:command.boss_pattern="mirror_committed_shift"
        await physics_frame
        actor._spawn_command_effects(command,false)
        check(actor.global_position.is_equal_approx(Vector2(800,140)),"blink preserves its authored destination")
        await visible_arrival(actor,"authored Boss blink" if boss else "generic enemy blink")
        # A normal pose change in the render callback must preserve the ongoing
        # movement's interpolation, including calls selecting the same pose.
        await settle(actor)
        await physics_frame
        actor.global_position.x = 800
        await process_frame
        actor._set_enemy_animation("idle")
        var moving_sampled := false
        for frame in 3:
            await process_frame
            await RenderingServer.frame_post_draw
            var fraction := Engine.get_physics_interpolation_fraction()
            if fraction > .05 and fraction < .95:
                var x := marker_x()
                check(x > 120 and x < 790,"pose-only change retains movement interpolation")
                moving_sampled = true
                break
        check(moving_sampled,"pose change samples a fractional render frame")
        RETIRE.retire_tree(actor)
        actor.queue_free()
        await process_frame
        await process_frame

    var level := TrialLevel.new()
    root.add_child(level)
    level.set_process(false)
    level.set_physics_process(false)
    level.boss_trial_mode = true
    level.config = {"boss":{"position":[820,140]},"boss_checkpoint":[800,140]}
    var player = PLAYER_SCENE.instantiate()
    player.set_script(MarkerPlayer)
    level.add_child(player)
    player.set_physics_process(false)
    player.sprite.hide()
    player.get_node("Camera2D").enabled=false
    level.player=player
    await settle(player)
    var calls: int=player.arrival_calls
    await physics_frame
    level._start_boss_trial()
    check(player.arrival_calls==calls+1,"trial start uses the real arrival/camera reset")
    check(player.global_position.is_equal_approx(Vector2(800,140)),"trial start keeps checkpoint position")
    check(player.hp==player.max_hp and player.energy==player.max_energy,"trial start still restores player resources")
    await visible_arrival(player,"Boss trial start")
    await settle(player)
    calls=player.arrival_calls
    await physics_frame
    level._reset_encounters_after_player_death()
    check(player.arrival_calls==calls+1,"trial reset uses the real arrival/camera reset")
    check(player.global_position.is_equal_approx(Vector2(800,140)),"trial reset keeps checkpoint position")
    await visible_arrival(player,"Boss trial reset")
    RETIRE.retire_tree(level)
    level.queue_free()
    stage.queue_free()
    await process_frame
    await process_frame
    check(await RETIRE.drain(self),"arrival regression releases audio")
    print("INTERPOLATION_ARRIVAL checks=%d failures=%d" % [checks,failures])
    quit(0 if failures==0 else 1)
