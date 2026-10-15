extends SceneTree
## Isolated input/combat and real first-court views. Not a natural campaign clear.
const FOCUS := preload("res://scripts/camera_focus.gd")
const ROOMS := preload("res://scripts/room_camera.gd")
const SAVE := preload("res://scripts/world_state.gd")
var checks := 0
var failures: Array[String] = []
var healing_events: Array[String] = []
var capture := false

func _initialize() -> void:
    capture = "--capture" in OS.get_cmdline_user_args()
    call_deferred("run")

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label)

func frames(count: int = 3) -> void:
    for i in count:
        await physics_frame
        await process_frame

func release() -> void:
    for action in ["heal", "move_left", "move_right", "jump", "dash", "attack"]:
        Input.action_release(action)

func run() -> void:
    root.size = Vector2i(1280,720)
    _zone_rules()
    await _healing_and_duel()
    await _first_court()
    release()
    await frames()
    for label in failures: push_error(label)
    print("FIRST_COURT_EXPERIENCE checks=%d failures=%d fixture_scope=local_damage_and_room_views" % [checks,failures.size()])
    call_deferred("quit", 0 if failures.is_empty() else 1)

func _zone_rules() -> void:
    var focus = FOCUS.new()
    focus.region_bounds = Rect2(0,0,5000,3000)
    var rooms = ROOMS.new()
    rooms.configure([
        {"id":"hall", "layout_rect":[0,0,2000,2000], "camera_bounds":[0,0,2100,2100]},
        {"id":"pocket", "layout_rect":[600,400,400,300], "camera_bounds":[400,200,1000,600]},
        {"id":"bad", "layout_rect":[0,0,100,100], "camera_bounds":[0,0,-1,600]}
    ],focus)
    check(rooms.zones.size()==2,"Invalid authored bounds do not create a zone")
    rooms.update(focus,Vector2(500,500))
    check(rooms.current.id=="hall","Outer hall is selected")
    rooms.update(focus,Vector2(605,500),1.0/60)
    check(rooms.current.id=="hall","Doorway edge does not oscillate into nested pocket")
    rooms.update(focus,Vector2(650,500),1.0/60)
    check(rooms.current.id=="pocket","Entering nested pocket selects its smaller view")
    check(rooms.display_bounds.position.x > 0 and rooms.display_bounds.position.x < 400,"Room transition blends instead of snapping the full limit")
    for i in 60: rooms.update(focus,Vector2(650,500),1.0/60)
    check(rooms.display_bounds.position.distance_to(Vector2(400,200))<1,"Room transition reaches authored framing")
    rooms.update(focus,Vector2(1008,500),1.0/60)
    check(rooms.current.id=="pocket","Return doorway retains the room within hysteresis")
    rooms.update(focus,Vector2(1050,500),1.0/60)
    check(rooms.current.id=="hall","Leaving beyond doorway margin restores the hall")
    focus.push_lock("boss_arena",Rect2(500,300,1400,800),100,true,true)
    rooms.update(focus,Vector2(650,500))
    check(focus._select_lock().priority==100,"Boss event overrides exploration bounds")
    focus.remove_lock("boss_arena")
    check(focus._select_lock().priority==10,"Releasing event restores exploration framing")
    rooms.update(focus,Vector2(4000,2500))
    check(not focus.locks.has(ROOMS.LOCK_ID),"Outside authored rooms returns to regional follow")
    rooms.configure([],focus)
    check(rooms.zones.is_empty() and rooms.current.is_empty(),"Region/passage reconfiguration clears all room state")

func _healing_and_duel() -> void:
    var stage := Node2D.new()
    root.add_child(stage)
    var floor_body := StaticBody2D.new()
    floor_body.position = Vector2(1100,3617)
    var collision := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = Vector2(2000,10)
    collision.shape = shape
    floor_body.add_child(collision)
    stage.add_child(floor_body)
    var player = load("res://scenes/Player.tscn").instantiate()
    stage.add_child(player)
    player.feel = null
    player.global_position = Vector2(1000,3612)
    player.heal_state_changed.connect(func(state: String): healing_events.append(state))
    await frames(15)
    check(player.is_on_floor(),"Healing fixture uses actual floor contact")
    player.hp = player.max_hp - 2
    player.energy = player.max_energy
    Input.action_press("move_right")
    Input.action_press("heal")
    await frames(1)
    check(player.energy == player.max_energy and player.heal_timer == 0,"Heal with existing movement input spends no resource")
    check(healing_events.is_empty(),"Rejected heal emits no started/interrupted event")
    release()
    await frames(15)
    var hp_before: int = player.hp
    Input.action_press("heal")
    await frames(1)
    Input.action_release("heal")
    check(player.energy == player.max_energy-player.heal_energy_cost and player.hp==hp_before,"Accepted heal reserves cost before restoring health")
    await frames(58)
    check(player.hp==hp_before+1 and healing_events==["started","completed"],"One press completes exactly one heal after its real input window")
    var energy_after: int = player.energy
    await frames(40)
    check(player.energy==energy_after and player.hp==hp_before+1,"Idle frames do not repeat healing or refund payment")
    player.energy=player.max_energy
    player.heal_cooldown=0
    healing_events.clear()
    Input.action_press("heal")
    await frames(2)
    Input.action_release("heal")
    Input.action_press("move_left")
    await frames(2)
    release()
    check(player.hp==hp_before+1 and player.energy==player.max_energy-player.heal_energy_cost,"Moving after accepted heal interrupts with its configured full loss")
    check(healing_events==["started","interrupted"],"Movement cancellation settles exactly once")
    await frames(45)
    # The actual authored first enemy and species profile, on a simple real floor.
    var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/demo_ch01_moss_bell_court.json"))
    var spawn: Dictionary = config.enemy_spawns[0]
    var enemy := Area2D.new()
    enemy.set_script(load("res://scripts/enemy_actor.gd"))
    enemy.configure(spawn,String(spawn.sprite),false,config.ai_profiles.moss_larva)
    enemy.position=Vector2(spawn.position[0],spawn.position[1])
    stage.add_child(enemy)
    check(enemy.ai_commands.size()==2 and enemy.ai_commands[0].type=="melee" and enemy.ai_commands[1].type=="lunge" and enemy.ai_commands[0].windup>=0.5 and enemy.ai_commands[1].windup>=0.5,"First duel retains two distinct, readable species attacks")
    check(minf(enemy.ai_commands[0].recover,enemy.ai_commands[1].recover) > player.heal_duration+0.2,"Both first-duel attacks have a genuine recovery window long enough to heal")
    player.global_position=Vector2(1140,3612)
    player.velocity=Vector2.ZERO
    player.hp=player.max_hp-1
    player.energy=player.max_energy
    player.heal_cooldown=0
    player.hurt_timer=0
    await frames(3)
    var reached_windup := false
    for i in 150:
        await frames(1)
        if enemy.state=="windup":
            reached_windup=true
            break
    check(reached_windup,"Damage-enabled first enemy naturally starts an attack")
    hp_before=player.hp
    healing_events.clear()
    Input.action_press("heal")
    await frames(1)
    Input.action_release("heal")
    await frames(38)
    check(player.hp < hp_before and player.heal_timer==0,"Actual enemy hit interrupts a greedy heal before completion")
    check(healing_events==["started","interrupted"],"Enemy interrupt settles once without a completion")
    # Withdraw while the previous attack finishes; approach a fresh windup,
    # rather than placing the player into a partially elapsed attack.
    player.global_position=Vector2(950,3612)
    player.velocity=Vector2.ZERO
    await frames(90)
    player.global_position=enemy.global_position+Vector2(-50,40)
    player.velocity=Vector2.ZERO
    player.hurt_timer=0
    player.energy=player.max_energy
    player.heal_cooldown=0
    reached_windup=false
    for i in 180:
        await frames(1)
        if enemy.state=="windup":
            reached_windup=true
            break
    check(reached_windup,"First enemy offers another readable attack without resetting its AI")
    Input.action_press("move_left")
    # The curl advances about 25 pixels and needs a longer retreat than a bite.
    await frames(24)
    release()
    var reached_recovery := false
    for i in 40:
        await frames(1)
        if enemy.state=="recover":
            reached_recovery=true
            break
    check(reached_recovery,"Retreating from windup reaches a genuine enemy recovery state")
    hp_before=player.hp
    healing_events.clear()
    Input.action_press("heal")
    await frames(1)
    Input.action_release("heal")
    await frames(54)
    check(player.hp==hp_before+1 and healing_events==["started","completed"],"Retreat then heal completes in actual recovery: hp=%d->%d events=%s enemy=%s player=%s" % [hp_before,player.hp,healing_events,enemy.state,player.global_position])
    enemy.queue_free()
    await frames(4)
    player.respawn_at(Vector2(1000,3612))
    player.hp=player.max_hp-1
    player.energy=player.max_energy
    player.heal_cooldown=0
    await frames(15)
    healing_events.clear()
    Input.action_press("heal")
    await frames(2)
    Input.action_release("heal")
    player.ui_input_locked=true
    await frames(4)
    var settled: int = player.energy
    player.ui_input_locked=false
    await frames(12)
    check(player.heal_timer==0 and player.energy==settled and healing_events==["started","interrupted"],"Menu lock settles healing and reopening does not replay it")
    stage.queue_free()
    await frames(4)

func _first_court() -> void:
    var world = load("res://scenes/World.tscn").instantiate()
    world.world_resume=false
    world.world_save_path="user://first_court_experience.json"
    root.add_child(world)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(world)
    current_scene=world
    await frames(8)
    world.set_process(false)
    world.player.set_physics_process(false)
    for enemy in get_nodes_in_group("enemy"): enemy.set_physics_process(false)
    check(preload("res://scripts/world_ready_validation_helper.gd").original_camera_zones(world)==42,"All 42 authored first-court rooms have dedicated framing")
    var camera: Camera2D = world.player.get_node("Camera2D")
    for zone in world.player.room_camera.zones:
        world.player.global_position=zone.triggers[0].get_center()
        world.player.reset_camera_after_arrival()
        var half := Vector2(root.size)/camera.zoom*0.5
        var center := camera.get_screen_center_position()
        var screen := Rect2(center-half,half*2)
        check(screen.has_point(world.player.global_position+Vector2(0,-40)),String(zone.id)+" camera contains player body at authored room center")
        check(camera.limit_left<camera.limit_right and camera.limit_top<camera.limit_bottom,String(zone.id)+" camera limits stay ordered")
    for view in [["entry",Vector2(350,3400)],["first_duel",Vector2(1050,3612)],["shrine",Vector2(1810,3752)],["hub",Vector2(2580,3892)],["pre_boss",Vector2(5420,3920)]]:
        world.player.global_position=view[1]
        world.player.reset_camera_after_arrival()
        world._update_room_visit()
        await frames(20)
        check(absf(camera.get_screen_center_position().y-world.player.global_position.y)<270,String(view[0])+" player footing stays in view")
        if String(view[0]) == "entry":
            for child in world.get_children():
                if child.has_node("WorldPortalArch"):
                    check(not child.get_node("WorldPortalArch").visible,"Legacy route has no luminous doorway overlay")
                    check(child.get_node("Wayfinding").scale.x < 0.8,"Route sign remains compact beside the first landing")
        if capture:
            world.ui_shell.toast.text=""
            await RenderingServer.frame_post_draw
            DirAccess.make_dir_recursive_absolute("res://../artifacts/first_court")
            root.get_texture().get_image().save_png("res://../artifacts/first_court/"+String(view[0])+".png")
    # Real movement and grounded tutorial adapter, with actors paused in this view fixture.
    world.player.respawn_at(Vector2(350,3400))
    world.player.set_physics_process(true)
    world._warm_arrival_cave()
    world._warm_arrival_terrain()
    world._warm_arrival_platforms()
    await frames(15)
    world.current_room_id="entry_bell"
    world.story_flags.erase("tutorial_action_seen_jump")
    world.ui_shell.toast_age=6
    world._update_first_journey_hint()
    check(bool(world.story_flags.get("tutorial_action_seen_jump",false)),"Safe first jump encounter teaches exactly once")
    world.toast_label.text="sentinel"
    world.ui_shell.toast_age=6
    world._update_first_journey_hint()
    check(world.toast_label.text=="sentinel","Returning to entry does not repeat jump instructions")
    world.player.respawn_at(Vector2(1710,3752))
    world._warm_arrival_cave()
    world._warm_arrival_terrain()
    world._warm_arrival_platforms()
    await frames(15)
    world.current_room_id="first_bell_shrine"
    world.player.hp=world.player.max_hp-1
    world.player.energy=world.player.max_energy
    world.story_flags.erase("tutorial_action_seen_heal")
    world.ui_shell.toast_age=6
    world.active_overlay="map"
    world._update_first_journey_hint()
    check(not world.story_flags.has("tutorial_action_seen_heal"),"Menu does not consume unseen healing lesson")
    world.active_overlay=""
    world.ui_shell.toast_age=6
    world._update_first_journey_hint()
    check(bool(world.story_flags.get("tutorial_action_seen_heal",false)),"Injured player with energy receives first healing lesson in safe shrine")
    check(world.toast_label.text.contains(world.ui_shell._short_binding("heal")),"Lesson uses current input binding")
    var saved = SAVE.new()
    check(saved.read(world.world_save_path) and bool(saved.data.story_flags.get("tutorial_action_seen_heal",false)),"First lesson persists through the actual save adapter")
    world.player.hp=world.player.max_hp
    world.story_flags.erase("tutorial_action_seen_tool")
    world.ui_shell.toast_age=6
    world._update_first_journey_hint()
    check(bool(world.story_flags.get("tutorial_action_seen_tool",false)),"Safe shrine introduces the equipped tool once")
    check(world.toast_label.text.contains(world.ui_shell._short_binding("tool_cast")),"Tool lesson follows current remapping")
    world.toast_label.text="sentinel"
    world.ui_shell.toast_age=6
    world._update_first_journey_hint()
    check(world.toast_label.text=="sentinel","Second shrine stop does not repeat tool instruction")
    world.player.respawn_at(Vector2(250,3400))
    world._warm_arrival_cave()
    world._warm_arrival_terrain()
    world._warm_arrival_platforms()
    await frames(15)
    world.current_room_id="entry_bell"
    world.story_flags.erase("tutorial_action_seen_move")
    world.ui_shell.toast_age=6
    world._update_first_journey_hint()
    check(bool(world.story_flags.get("tutorial_action_seen_move",false)),"Entry teaches movement before its jump obstacle")
    world.player.global_position=Vector2(5800,3980)
    world.player.reset_camera_after_arrival()
    world._set_boss_arena_locked(true)
    world.player.room_camera.update(world.player.camera_focus,world.player.global_position)
    world.player.camera_focus.apply_limits(camera)
    check(world.player.camera_focus.active_lock=="boss_arena","Production Boss seal overrides first-court room view")
    world._set_boss_arena_locked(false)
    check(world.player.camera_focus.active_lock=="exploration_room","Production seal release restores first-court room view")
    world._set_boss_arena_locked(true)
    world.player.respawn_at(Vector2(350,3400))
    check(world.player.camera_focus.active_lock=="exploration_room" and world.player.room_camera.current.id=="entry_bell","Actual respawn signal clears Boss event and selects the recovery room")
    check(camera.get_screen_center_position().distance_to(world.player.global_position)<240,"Respawn visible center is correct immediately, before a render tick")
    world.queue_free()
    await frames(4)
