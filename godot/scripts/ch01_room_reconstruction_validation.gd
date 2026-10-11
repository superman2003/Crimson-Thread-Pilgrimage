extends SceneTree
## Real player, initial single jump, five room pockets. Incidental combat is disabled.
var world: Node
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func tick(count: int) -> void:
    for i in count: await physics_frame
func release_inputs() -> void:
    for action in ["move_left","move_right","jump"]: Input.action_release(action)
func place(point: Vector2) -> void:
    release_inputs()
    world.player.global_position = point
    world.player.velocity = Vector2.ZERO
    world.player.jump_buffer_timer = 0.0
    world.player.coyote_timer = 0.0
    await tick(10)
    check(world.player.is_on_floor(),"Landing settles at "+str(point))
func walk(a: Vector2,b: Vector2,label: String) -> void:
    for direction in [1,-1]:
        await place(a if direction == 1 else b)
        var target: Vector2 = b if direction == 1 else a
        Input.action_press("move_right" if direction == 1 else "move_left")
        var clear := true
        for i in 100:
            await physics_frame
            var point: Vector2 = world.player.global_position
            clear = clear and not world.cave_world.intersects_rect(Rect2(point+Vector2(-17,-83),Vector2(34,82)))
            if (point.x-target.x)*direction >= 0: break
        release_inputs()
        check((world.player.global_position.x-target.x)*direction >= 0,label+" walking direction="+str(direction)+" at "+str(world.player.global_position))
        check(clear,label+" head and body outside rock")
func jump_to(start: Vector2,target: Vector2,label: String) -> void:
    await place(start)
    Input.action_press("jump")
    await tick(2)
    var clear := true
    var landed := false
    for i in 90:
        if i==12: Input.action_release("jump")
        var dx: float = target.x-world.player.global_position.x
        Input.action_release("move_left");Input.action_release("move_right")
        if absf(dx)>4: Input.action_press("move_right" if dx>0 else "move_left")
        await physics_frame
        var point: Vector2 = world.player.global_position
        clear = clear and not world.cave_world.intersects_rect(Rect2(point+Vector2(-17,-83),Vector2(34,82)))
        if i>8 and world.player.is_on_floor():
            landed = absf(point.y-target.y)<4 and absf(point.x-target.x)<20
            break
    release_inputs()
    check(landed,label+" reachable with initial single jump: "+str(world.player.global_position))
    check(clear,label+" jump headroom")
func run() -> void:
    world = load("res://scenes/World.tscn").instantiate()
    world.world_resume = false
    world.world_save_path = "user://room_validation.json"
    root.add_child(world)
    await tick(15)
    for enemy in get_nodes_in_group("enemy"): enemy.set_physics_process(false)
    world.player.debug_invulnerable = true
    check(not world.player.dash_unlocked and not world.player.double_jump_unlocked and not world.player.wall_grip_unlocked,"New journey has no traversal upgrades")
    await walk(Vector2(4580,2790),Vector2(4870,2790),"East balcony lower line")
    await jump_to(Vector2(4855,2790),Vector2(4855,2694),"Balcony lookout")
    await walk(Vector2(5920,2790),Vector2(6200,2790),"Rain overlook lower line")
    await jump_to(Vector2(6100,2790),Vector2(6100,2702),"Rain observation ledge")
    await walk(Vector2(3785,5420),Vector2(3875,5420),"Cistern landing pocket")
    await jump_to(Vector2(3850,5420),Vector2(3990,5356),"Sunken bell plinth")
    await tick(2)
    check(int(world.inventory_counts.get("energy_spindle",0))==1,"Actual plinth reward obtained through normal pickup")
    await jump_to(Vector2(3990,5356),Vector2(3830,5420),"Cistern return landing")
    await walk(Vector2(1470,5120),Vector2(1690,5120),"Maze shelter safe floor")
    await jump_to(Vector2(1480,5120),Vector2(1401,5064),"Root bench")
    await walk(Vector2(5280,3920),Vector2(5568,3920),"Boss shrine unobstructed retry")
    await jump_to(Vector2(5549,3920),Vector2(5549,3832),"Votive shelf")
    # Physical door contact, including jump attempts, must not cross the dash gate.
    await place(Vector2(3560,5420))
    Input.action_press("move_right")
    for i in 100:
        if i==12 or i==55: Input.action_press("jump")
        if i==14 or i==57: Input.action_release("jump")
        await physics_frame
    release_inputs()
    check(world.player.global_position.x<3680,"Basic jump cannot bypass deep gallery dash gate")
    for name in ["save_maze_respite","save_late_runback"]:
        var marker: Node2D = world.get_node(name)
        await place(marker.global_position+Vector2(0,40))
        check(absf(world.player.global_position.y-marker.global_position.y-40)<4,name+" unchanged recovery floor")
    var portal: Node2D = world.get_node("upgrade_echo_hook_1_access_a")
    await place(portal.global_position+Vector2(0,40))
    check(absf(world.player.global_position.x-4580)<2,"Existing hook workshop landing retained")
    # A local damage-enabled check: the workshop return landing must be safe
    # while its actual shield guard patrols. This is not a full campaign run.
    await place(Vector2(4580,2790))
    var guard: Node
    for actor in get_nodes_in_group("enemy"):
        if String(actor.spawn_id)=="E06": guard = actor
    check(guard!=null,"Balcony guard exists")
    if guard == null:
        quit(1)
        return
    check(absf(guard.spawn_position.x-4770)<2,"Guard placement preserves the workshop arrival buffer")
    guard.set_physics_process(true)
    world.player.debug_invulnerable = false
    var arrival_hp: int = world.player.hp
    await tick(240)
    check(world.player.hp==arrival_hp,"Workshop return has a safe pause with damage enabled")
    check(guard.hp>0,"Safe arrival does not remove its encounter")
    world.queue_free()
    await tick(3)
    print("CH01_ROOM_RECONSTRUCTION checks=%d failures=%d combat_scope=local_arrival" % [checks,failures])
    quit(0 if failures==0 else 1)
