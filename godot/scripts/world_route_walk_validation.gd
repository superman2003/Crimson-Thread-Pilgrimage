extends SceneTree
## Navigation acceptance uses live Player input and collision physics only.
## Enemy damage is suppressed with an explicit debug flag, so this is not a combat playthrough.
const SAVE := "user://test_world_walk.json"
var scene: Node
var failures := 0
var frames := 0
var jump_hold := 0
var jump_rearm := 0
var steps := 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for suffix in ["", ".tmp", ".bak"]:
        if FileAccess.file_exists(SAVE + suffix):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
    scene = load("res://scenes/World.tscn").instantiate()
    scene.world_resume = false
    scene.world_save_path = SAVE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene = scene
    await _tick(15)
    _check(not scene.inventory_counts.has("double_thread_jump"), "fresh start lacks double jump")
    await _walk(Vector2(410,3400), "initial lift")
    await _interact("moss_salt_lift_lower", "demo_ch01_moss_bell_court", Vector2(4850,610))
    await _walk(Vector2(5240,560), "first salt obstruction", true)
    _check(scene.player.position.x < 5080, "salt gate blocks unupgraded player")
    _check(not scene.inventory_counts.has("testimony_returned_name"), "salt reward cannot be collected before ability")
    await _walk(Vector2(4850,650), "return from obstruction")
    await _interact("moss_salt_lift_upper", "demo_ch01_moss_bell_court", Vector2(410,3360))
    for p in [Vector2(640,3452),Vector2(870,3532),Vector2(1130,3612),Vector2(1420,3692),Vector2(1790,3752)]:
        await _walk(p,"moss drainage")
    await _interact("moss_rain_pipe", "demo_ch02_rain_foundry_canal", Vector2(330,720))
    for p in [Vector2(620,812),Vector2(960,880),Vector2(1350,836),Vector2(1700,920)]:
        await _walk(p,"rain repair route")
    _check(scene.inventory_counts.has("silk_wall_grip"), "wall grip obtained by walking into pickup")
    await _walk(Vector2(1350,836), "rain riser return")
    await _interact("rain_archive_riser", "demo_ch03_saltwhite_archive", Vector2(430,2580))
    for p in [Vector2(700,2570),Vector2(1050,2620),Vector2(1430,2556),Vector2(1760,2612),Vector2(2090,2548),Vector2(1930,2442),Vector2(1740,2350),Vector2(1510,2240)]:
        await _walk(p,"archive candle route",false,p.x == 1510)
    _check(scene.inventory_counts.has("double_thread_jump"), "double jump obtained in archive")
    await _walk(Vector2(1610,2240),"archive return line")
    await _interact("archive_moss_return", "demo_ch01_moss_bell_court", Vector2(280,3360))
    await _walk(Vector2(410,3400), "old lift revisited")
    await _interact("moss_salt_lift_lower", "demo_ch01_moss_bell_court", Vector2(4850,610))
    await _walk(Vector2(5240,560), "salt testimony revisited")
    await _tick(3)
    Input.action_press("interact")
    # The host polls F during _process; hold through a render tick rather
    # than assuming one physics signal includes a render tick on every runner.
    await process_frame
    await _tick()
    Input.action_release("interact")
    await _tick(4)
    _check(scene.inventory_counts.has("testimony_returned_name"), "return unlocks testimony reward through F pickup")
    await _walk(Vector2(5340,560), "permanent shortcut upper")
    await _interact("moss_salt_shortcut_upper", "demo_ch01_moss_bell_court", Vector2(200,3360))
    _check(bool(scene.story_flags.get("world_shortcut_salt_return", false)), "salt return shortcut persists after regional lift")
    await _interact("moss_salt_shortcut_lower", "demo_ch01_moss_bell_court", Vector2(5340,520))
    _check(scene.inventory_counts.has("double_thread_jump") and scene.inventory_counts.has("testimony_returned_name"), "ability and reward retained on shortcut return")
    _release()
    scene.queue_free()
    await process_frame
    scene = load("res://scenes/World.tscn").instantiate()
    scene.world_save_path = SAVE
    scene.world_resume = true
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene = scene
    await _tick(15)
    _check(scene.inventory_counts.has("testimony_returned_name") and scene.inventory_counts.has("double_thread_jump"), "restart restores earned ability and unique testimony")
    _check(bool(scene.story_flags.get("world_shortcut_salt_return", false)), "restart restores permanent salt shortcut")
    _check(str(scene.config.id) == "demo_ch01_moss_bell_court" and scene.player.position.x < 500, "restart restores last region at its remembered bell shrine")
    _release()
    print("WORLD_ROUTE_WALK_VALIDATION steps=%d physics_frames=%d failures=%d damage_suppression=true" % [steps,frames,failures])
    quit(0 if failures == 0 else 1)

func _tick(count: int = 1) -> void:
    for unused in range(count):
        if is_instance_valid(scene) and is_instance_valid(scene.player):
            scene.player.debug_invulnerable = true
        await physics_frame
        frames += 1
        for child in root.get_children():
            if child.get("world_mode") == true and not child.is_queued_for_deletion():
                scene = child

func _walk(target: Vector2, label: String, obstruction: bool = false, immediate_jump: bool = false) -> void:
    steps += 1
    _release()
    await _tick(2)
    jump_hold = 0
    jump_rearm = 0
    if immediate_jump:
        Input.action_press("jump")
        jump_hold = 45
    for frame in range(700):
        var player: CharacterBody2D = scene.player
        var dx: float = target.x - player.global_position.x
        var rise: float = player.global_position.y - target.y
        if absf(dx) < 16 and absf(rise) < 50 and player.is_on_floor():
            _release()
            print("WALK %s reached %s" % [label,str(player.global_position)])
            return
        _axis(signf(dx) if absf(dx) > 8 else 0)
        if jump_hold > 0:
            jump_hold -= 1
            if jump_hold == 0:
                Input.action_release("jump")
                jump_rearm = 4
        elif jump_rearm > 0:
            jump_rearm -= 1
        elif player.is_on_floor():
            var ahead := player.global_position + Vector2(signf(dx)*52,-3)
            var query := PhysicsRayQueryParameters2D.create(ahead,ahead+Vector2(0,90),1,[player.get_rid()])
            var gap: bool = player.get_world_2d().direct_space_state.intersect_ray(query).is_empty()
            if (rise > 25 and absf(dx)<165) or (gap and absf(dx)>50) or (player.is_on_wall() and absf(dx)>30):
                Input.action_press("jump")
                jump_hold = 45
        elif player.double_jump_unlocked and rise > 50 and player.velocity.y > -100 and player.air_jump_available and jump_hold == 0 and jump_rearm == 0:
            Input.action_press("jump")
            jump_hold = 35
        await _tick()
        if obstruction and frame > 90 and player.global_position.x > 5035:
            _release()
            print("WALK %s observed blocked at %s" % [label,str(player.global_position)])
            return
        if frame % 150 == 149:
            print("WALK pending %s target=%s position=%s velocity=%s floor=%s" % [label,str(target),str(player.global_position),str(player.velocity),str(player.is_on_floor())])
    _release()
    _check(false,"route failed: %s target=%s actual=%s" % [label,str(target),str(scene.player.global_position)])
    quit(1)
    await process_frame

func _interact(portal_id: String, target_region: String, spawn: Vector2) -> void:
    _release()
    await _tick(3)
    Input.action_press("interact")
    await process_frame
    await _tick()
    Input.action_release("interact")
    await process_frame
    if scene.world_passage.active:
        _axis(signf(scene.world_passage.destination_point.x - scene.world_passage.source_point.x))
        for frame in range(3600):
            await _tick()
            if not scene.world_passage.active:
                break
        _release()
        _check(not scene.world_passage.active, "full pipe walked with collision and input")
    for frame in range(2000):
        if not _transition_busy():
            break
        await process_frame
    _check(not _transition_busy(), "budgeted physical portal settles including deferred request and preflight")
    if _transition_busy():
        _release()
        quit(1)
        await process_frame
        return
    await _tick(15)
    _check(str(scene.config.id) == target_region and scene.player.global_position.distance_to(spawn) < 90, "physical portal %s arrives at destination" % portal_id)
    if failures > 0:
        print("WORLD_ROUTE_WALK_VALIDATION aborted actual=%s %s" % [str(scene.config.id),str(scene.player.global_position)])
        quit(1)
        await process_frame

func _transition_busy() -> bool:
    if not is_instance_valid(scene):
        return false
    var loader: Variant = scene.world_loader
    return scene.world_portal_request_pending or scene.chapter_transitioning or scene.world_loading or (is_instance_valid(loader) and loader.phase != "idle")

func _axis(direction: float) -> void:
    if direction > 0:
        Input.action_release("move_left"); Input.action_press("move_right")
    elif direction < 0:
        Input.action_release("move_right"); Input.action_press("move_left")
    else:
        Input.action_release("move_left"); Input.action_release("move_right")

func _release() -> void:
    for action in ["move_left","move_right","jump","interact"]:
        Input.action_release(action)

func _check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        push_error(label)
    else:
        print("PASS "+label)
