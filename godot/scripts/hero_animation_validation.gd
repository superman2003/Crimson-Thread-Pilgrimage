extends SceneTree
## State/pose contract: damage window, interruptible heal and short dash.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func run() -> void:
    var player: Node = load("res://scenes/Player.tscn").instantiate()
    root.add_child(player)
    player.set_physics_process(false)
    await process_frame
    var sprite: AnimatedSprite2D = player.sprite
    check(sprite.sprite_frames.get_frame_count("run")==4,"four authored run poses loaded")
    check(sprite.sprite_frames.get_frame_texture("run",0).get_size()==Vector2(384,384),"padded runtime frames loaded")
    player.current_attack=&"attack_1"
    player.current_attack_direction=Vector2.RIGHT
    player.attack_duration=0.5
    player.attack_windup=0.1
    player.attack_active_time=0.2
    for data in [[0.0,0],[0.075,1],[0.15,2],[0.299,2],[0.4,3]]:
        player.attack_timer=0.5-float(data[0])
        player._update_attack_pose()
        check(sprite.frame==int(data[1]),"attack pose follows phase at "+str(data[0]))
        check(not sprite.is_playing(),"attack phase owns pose playback")
    player.attack_timer=0
    player.heal_timer=player.heal_duration*0.25
    player._update_animation(0)
    check(sprite.animation==&"heal" and sprite.frame==3,"heal reaches final pose")
    player.hurt_timer=0.1
    player._update_animation(0)
    check(sprite.animation==&"hurt","hurt interrupts heal pose")
    player.hurt_timer=0
    player.heal_timer=0
    player.dash_timer=player.dash_time*0.1
    player._update_animation(1)
    check(sprite.animation==&"dash" and sprite.frame==3,"short dash reaches authored recovery pose")
    player.dash_timer=0
    player.velocity=Vector2(0,-100)
    player._play(&"jump_start",true)
    player._update_animation(0)
    check(sprite.animation==&"jump_start","takeoff survives same-tick airborne selection")
    player.death_timer=0.2
    player.attack_timer=0.2
    player.heal_timer=0.2
    player.restore_at_save_point()
    check(player.death_timer==0 and player.attack_timer==0 and player.heal_timer==0,"respawn clears transient actions")
    player.queue_free()
    await process_frame
    print("HERO_ANIMATION_VALIDATION checks=%d failures=%d" % [checks,failures])
    quit(0 if failures==0 else 1)
