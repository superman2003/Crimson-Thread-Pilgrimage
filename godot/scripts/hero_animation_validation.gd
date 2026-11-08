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
    check(player.PLAYER_MANIFEST == "res://assets/sprites/player/thread_doll_v1/manifest.json", "default Player selects the cloth-thread body")
    var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(player.PLAYER_MANIFEST))
    check(is_equal_approx(player.RUN_CYCLE_DISTANCE,float(manifest.run_cycle_distance)), "running feet, footsteps and authored fallback use the same world stride")
    var expected_actions := ["idle","run","jump","landing","attack_1","air_attack","attack_2","down_attack","dash","wall_slide","hook_throw","phase","heal","skill_projectile","skill_control","skill_defense","hurt","death","guard","resonance","jump_start","jump_loop","fall","land","skill_melee","skill_wave","item_use","run_attack","up_attack","ground_down_attack","air_up_attack","turn"]
    check(sprite.sprite_frames.get_animation_names().size() == expected_actions.size(), "all 32 production actions are present without an empty default fallback")
    for action in expected_actions:
        check(sprite.sprite_frames.has_animation(action), action + " is available on the new body")
        for index in sprite.sprite_frames.get_frame_count(action):
            check(sprite.sprite_frames.get_frame_texture(action,index).resource_path.begins_with("res://assets/sprites/player/thread_doll_v1/frames/"), action + " never falls back to human artwork")
        check(player.pose_thread_anchors.get(action,[]).size() == sprite.sprite_frames.get_frame_count(action), action + " has a painted-knot attachment for every frame")
    for facing in [-1,1]:
        player.facing = facing
        sprite.flip_h = facing < 0
        player._pose_progress(&"hook_throw", .5)
        var point: Array = player.pose_thread_anchors.hook_throw[3]
        var local := Vector2(float(point[0])-192,float(point[1])-192)
        if facing < 0: local.x = -local.x
        check(player.thread_origin_offset().is_equal_approx(player.to_local(sprite.to_global(local))), "grapple ribbon follows the current painted knot in both facings")
    player.facing = 1
    sprite.flip_h = false
    # New drawings retain each original clock; aliases share authored cels.
    var motion_v7 := {"jump":[4,0.4], "jump_start":[4,2.0/18.0],
        "landing":[4,0.4], "land":[4,3.0/22.0], "dash":[6,0.4],
        "hurt":[6,0.4], "death":[6,0.4]}
    var authored: Dictionary = {}
    for anim in motion_v7:
        var spec: Array = motion_v7[anim]
        check(sprite.sprite_frames.get_frame_count(anim)==int(spec[0]),anim+" uses its complete new pose sequence")
        check(not sprite.sprite_frames.get_animation_loop(anim),anim+" remains non-looping")
        check(is_equal_approx(float(spec[0])/sprite.sprite_frames.get_animation_speed(anim),float(spec[1])),anim+" preserves its original playback length")
        for index in sprite.sprite_frames.get_frame_count(anim):
            var cel := sprite.sprite_frames.get_frame_texture(anim,index)
            check(cel!=null and cel.resource_path.contains("/thread_doll_v1/frames/"),anim+" uses versioned new artwork")
            check(cel!=null and cel.get_size()==Vector2(384,384) and cel.get_image().get_used_rect().has_area(),anim+" has complete padded imported pixels")
            if cel!=null: authored[cel.resource_path] = true
    check(authored.size()==26,"aliases share exactly twenty-six distinct newly drawn cels")
    var motion_v8 := {"guard":6, "heal":6, "hook_throw":6, "wall_slide":4, "phase":4,
        "resonance":6, "skill_projectile":6, "skill_control":6, "skill_defense":6}
    var ability_cels: Dictionary = {}
    for anim in motion_v8:
        var count := int(motion_v8[anim])
        check(sprite.sprite_frames.get_frame_count(anim)==count,anim+" loads every new ability cel")
        check(sprite.sprite_frames.get_animation_loop(anim)==(anim in ["wall_slide","phase"]),anim+" preserves loop behavior")
        check(is_equal_approx(count/sprite.sprite_frames.get_animation_speed(anim),0.4),anim+" preserves original nominal clock")
        for index in sprite.sprite_frames.get_frame_count(anim):
            var cel := sprite.sprite_frames.get_frame_texture(anim,index)
            check(cel!=null and cel.resource_path.contains("/thread_doll_v1/frames/"+anim+"_"),anim+" uses its own versioned artwork")
            check(cel!=null and cel.get_size()==Vector2(384,384) and cel.get_image().get_used_rect().has_area(),anim+" imports complete padded pixels")
            if cel!=null: ability_cels[cel.resource_path] = true
    check(ability_cels.size()==50,"nine ability families use fifty distinct new cels")
    for anim in ["idle","attack_2"]:
        var count := 8 if anim=="idle" else 6
        check(sprite.sprite_frames.get_frame_count(anim)==count,anim+" uses all complete-body new drawings")
        check(is_equal_approx(sprite.sprite_frames.get_animation_speed(anim),5.0 if anim=="idle" else 15.0),anim+" uses reviewed visual cadence")
        check(sprite.sprite_frames.get_animation_loop(anim)==(anim=="idle"),anim+" retains its intended loop behavior")
        for index in sprite.sprite_frames.get_frame_count(anim):
            var cel := sprite.sprite_frames.get_frame_texture(anim,index)
            check(cel!=null and cel.resource_path.contains("/thread_doll_v1/frames/"+anim+"_"),anim+" loads its versioned authored body cel")
    check(sprite.sprite_frames.get_frame_count("run")==8,"eight authored short-foot run cels loaded")
    check(player.grounded_run != null,"grounded running uses the continuous planted-foot rig")
    check(sprite.sprite_frames.get_frame_texture("run",0).get_size()==Vector2(384,384),"padded runtime frames loaded")
    for data in [["run_attack",6],["skill_melee",4],["skill_wave",4],["item_use",4],["attack_1",6],["up_attack",6],["ground_down_attack",6],["down_attack",6],["air_attack",6],["air_up_attack",6]]:
        var anim := String(data[0])
        check(sprite.sprite_frames.has_animation(anim) and sprite.sprite_frames.get_frame_count(anim)==int(data[1]),anim+" has its authored cels")
        for index in sprite.sprite_frames.get_frame_count(anim):
            var texture := sprite.sprite_frames.get_frame_texture(anim,index)
            check(texture.get_size()==Vector2(384,384) and texture.resource_path.contains("/thread_doll_v1/frames/"+anim+"_"),anim+" uses its own supplement cel "+str(index))
    for anim in ["jump_loop", "fall", "turn"]:
        check(sprite.sprite_frames.get_frame_count(anim) == 4 and not sprite.sprite_frames.get_animation_loop(anim), anim + " uses four authored settling cels")
        for index in 4:
            check(sprite.sprite_frames.get_frame_texture(anim, index).resource_path.contains("/thread_doll_v1/frames/"), anim + " uses versioned new artwork")
    player.velocity = Vector2(0, 100)
    player._update_animation(0)
    check(sprite.animation == &"fall" and sprite.frame == 0, "descent begins with its first authored cel")
    await create_timer(.3).timeout
    check(sprite.frame == 3 and not sprite.is_playing(), "descent settles on its final pose")
    player._update_animation(0)
    check(sprite.frame == 3 and not sprite.is_playing(), "long falls never restart the leg extension")
    check(sprite.sprite_frames.get_frame_texture("skill_melee",0)!=sprite.sprite_frames.get_frame_texture("attack_2",0),"heavy slash no longer borrows attack_2")
    player.current_attack=&"attack_1"
    player.current_attack_direction=Vector2.RIGHT
    player.attack_duration=0.5
    player.attack_windup=0.1
    player.attack_active_time=0.2
    # Six-cel attacks spend two cels each in wind-up, damage window and recovery.
    for data in [[0.0,0],[0.075,1],[0.15,2],[0.299,3],[0.35,4],[0.45,5]]:
        player.attack_timer=0.5-float(data[0])
        player._update_attack_pose()
        check(sprite.frame==int(data[1]),"attack pose follows phase at "+str(data[0]))
        check(not sprite.is_playing(),"attack phase owns pose playback")
    player.attack_timer=0.25
    player.attack_started_grounded=false
    for data in [[Vector2.RIGHT,&"air_attack"],[Vector2.UP,&"air_up_attack"],[Vector2.DOWN,&"down_attack"]]:
        player.current_attack_direction=data[0]
        player._update_attack_pose()
        check(sprite.animation==data[1],"airborne attack direction selects "+String(data[1]))
    player.current_attack_direction=Vector2.RIGHT
    player.attack_timer=0
    # Existing attack phase ownership must reach all six new casting poses.
    for kind in ["ranged", "control", "resonance"]:
        player.active_skill={"kind":kind}
        for data in [[0.0,0],[0.075,1],[0.15,2],[0.299,3],[0.35,4],[0.45,5]]:
            player.attack_timer=0.5-float(data[0])
            player._update_animation(0)
            var expected := "skill_projectile" if kind=="ranged" else ("skill_control" if kind=="control" else "resonance")
            check(sprite.animation==StringName(expected) and sprite.frame==int(data[1]),kind+" follows real windup/active/recovery phases")
    player.active_skill={"kind":"defense","duration":0.5}
    player.attack_timer=0.5
    player._update_animation(0)
    check(sprite.animation==&"skill_defense" and sprite.frame==0,"ward starts in its dedicated windup pose")
    player._apply_special_skill()
    player._update_animation(0)
    check(sprite.animation==&"guard" and sprite.frame==0,"live ward window takes over with raised guard")
    player.guard_timer=player.guard_initial_duration*0.01
    player._update_animation(0)
    check(sprite.animation==&"guard" and sprite.frame==5,"ward reaches final guard cel at actual expiry")
    player.guard_timer=0
    player.active_skill.clear()
    player.attack_timer=0
    for index in 6:
        player.heal_timer=player.heal_duration*(1.0-(float(index)+0.1)/6.0)
        player._update_animation(0)
        check(sprite.animation==&"heal" and sprite.frame==index,"heal advances all six poses on original heal duration")
    player.heal_timer=player.heal_duration*0.25
    player._update_animation(0)
    check(sprite.animation==&"heal" and sprite.frame==4,"heal progress selects the matching new pose")
    player.hurt_timer=0.1
    player._update_animation(0)
    check(sprite.animation==&"hurt","hurt interrupts heal pose")
    player.hurt_timer=0
    player.heal_timer=0
    player.dash_timer=player.dash_time*0.1
    player._update_animation(1)
    check(sprite.animation==&"dash" and sprite.frame==sprite.sprite_frames.get_frame_count(&"dash")-1,"short dash reaches authored recovery pose")
    player.dash_timer=0
    player.grapple_timer=player.grapple_timeout
    player._update_animation(0)
    check(sprite.animation==&"hook_throw" and sprite.frame==1,"grapple begins with release pose")
    player.grapple_timer=player.grapple_timeout-0.12
    for tick in 5:
        player._update_animation(0)
        check(sprite.frame==3 and not sprite.is_playing(),"pull pose never loops back to throwing")
    player._stop_grapple(true)
    player._update_animation(0)
    check(sprite.frame==4,"successful arrival displays recovery")
    player._stop_grapple()
    check(player.grapple_recovery_timer==0,"cancel clears recovery pose")
    player.velocity=Vector2(0,-100)
    player._play(&"jump_start",true)
    player._update_animation(0)
    check(sprite.animation==&"jump_start","takeoff survives same-tick airborne selection")
    player.death_timer=0.2
    player.attack_timer=0.2
    player.heal_timer=0.2
    player.restore_at_save_point()
    check(player.death_timer==0 and player.attack_timer==0 and player.heal_timer==0 and player.grapple_recovery_timer==0,"respawn clears transient actions")
    player.queue_free()
    await process_frame
    print("HERO_ANIMATION_VALIDATION checks=%d failures=%d" % [checks,failures])
    quit(0 if failures==0 else 1)
