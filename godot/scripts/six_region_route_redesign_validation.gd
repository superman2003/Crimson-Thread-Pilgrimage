extends SceneTree

const READY := preload("res://scripts/world_ready_validation_helper.gd")
const RETIRE := preload("res://scripts/audio_retirement.gd")
const AUDIO := preload("res://scripts/audio_director.gd")
const ROUTES := preload("res://scripts/world_routes.gd")

const REGIONS := [
    "demo_ch01_moss_bell_court",
    "demo_ch02_rain_foundry_canal",
    "demo_ch03_saltwhite_archive",
    "demo_ch04_broken_string_greenhouse",
    "demo_ch05_obsidian_pilgrim_road",
    "demo_ch06_silent_crown_core",
]
const WALK := 0
const JUMP := 1
const WALK_GROUNDED := 2
const CISTERN_TO_FIRST_SHRINE := [
    [WALK, Vector2(2880, 5500)], [WALK_GROUNDED, Vector2(2450, 5560)],
    [WALK, Vector2(2220, 5660)], [JUMP, Vector2(2195, 5568)], [JUMP, Vector2(2365, 5476)],
    [JUMP, Vector2(2195, 5384)], [JUMP, Vector2(2365, 5292)], [JUMP, Vector2(2195, 5200)],
    [JUMP, Vector2(2365, 5108)], [JUMP, Vector2(2195, 5016)], [JUMP, Vector2(2365, 4924)],
    [JUMP, Vector2(2275, 4832)], [WALK_GROUNDED, Vector2(2375, 4832)], [JUMP, Vector2(2421, 4740)],
    [JUMP, Vector2(2400, 4648)], [JUMP, Vector2(2365, 4556)], [JUMP, Vector2(2195, 4464)],
    [JUMP, Vector2(2365, 4372)], [JUMP, Vector2(2195, 4280)], [JUMP, Vector2(2365, 4188)],
    [JUMP, Vector2(2274, 4096)], [WALK_GROUNDED, Vector2(2375, 4096)], [JUMP, Vector2(2415, 4004)],
    [JUMP, Vector2(2426, 3862)], [WALK_GROUNDED, Vector2(2280, 3812)],
    [WALK_GROUNDED, Vector2(1670, 3752)],
]
const CIRCUITS := [
    [
        ["shrine approach and return", Vector2(1170, 3612), [
            [WALK, Vector2(1420, 3692)], [WALK, Vector2(1685, 3752)],
            [WALK, Vector2(1420, 3692)], [WALK, Vector2(1160, 3612)]]],
        ["shrine and court connect past the pipe junction", Vector2(1670, 3752), [
            [WALK_GROUNDED, Vector2(2630, 3892)], [WALK_GROUNDED, Vector2(1680, 3752)]]],
        ["stairwell rises through the court grate", Vector2(2434, 3912), [
            [JUMP, Vector2(2434, 3820)]]],
        ["central court to the bell lift and back", Vector2(2585, 3892), [
            [WALK_GROUNDED, Vector2(2654, 3892)], [JUMP, Vector2(2766, 3784)], [WALK_GROUNDED, Vector2(3074, 3608)],
            [JUMP, Vector2(2916, 3508)], [WALK_GROUNDED, Vector2(2630, 3299)],
            [JUMP, Vector2(2810, 3201)], [WALK_GROUNDED, Vector2(3185, 3020)],
            [JUMP, Vector2(3029, 2924)], [WALK_GROUNDED, Vector2(2597, 2868)],
            [JUMP, Vector2(2772, 2784)], [WALK_GROUNDED, Vector2(3050, 2730)],
            [JUMP, Vector2(2898, 2630)], [WALK_GROUNDED, Vector2(2516, 2472)],
            [JUMP, Vector2(2668, 2372)], [WALK_GROUNDED, Vector2(3694, 2126)],
            [JUMP, Vector2(3834, 2032)], [WALK_GROUNDED, Vector2(4070, 2032)],
            [WALK_GROUNDED, Vector2(3824, 2032)], [WALK, Vector2(3680, 2126)],
            [WALK_GROUNDED, Vector2(2658, 2372)], [WALK, Vector2(2495, 2472)],
            [WALK_GROUNDED, Vector2(2912, 2630)], [WALK, Vector2(3050, 2730)],
            [WALK_GROUNDED, Vector2(4290, 2740)], [WALK_GROUNDED, Vector2(2845, 2784)],
            [WALK, Vector2(2597, 2868)], [WALK_GROUNDED, Vector2(3029, 2924)],
            [WALK, Vector2(3185, 3020)], [WALK_GROUNDED, Vector2(2810, 3201)],
            [WALK, Vector2(2630, 3299)], [WALK_GROUNDED, Vector2(2916, 3508)],
            [WALK, Vector2(3074, 3608)], [WALK_GROUNDED, Vector2(2766, 3784)],
            [WALK, Vector2(2630, 3892)]], true],
        ["attic lookout approach", Vector2(4200, 910), [
            [JUMP, Vector2(4300, 846)], [JUMP, Vector2(4390, 716)]]],
        ["two levels of the cistern ring", Vector2(3140, 5120), [
            [WALK_GROUNDED, Vector2(3018, 5120)], [JUMP, Vector2(2927, 5024)],
            [JUMP, Vector2(2894, 4926)], [JUMP, Vector2(3040, 4830)]]],
        ["cistern ring, moss hollow and sluice loop", Vector2(3650, 5120), [
            [WALK, Vector2(2880, 5500)], [WALK_GROUNDED, Vector2(3550, 5420)],
            [WALK_GROUNDED, Vector2(3280, 5420)], [WALK_GROUNDED, Vector2(2970, 5500)],
            [WALK_GROUNDED, Vector2(2450, 5560)], [WALK, Vector2(2220, 5660)],
            [WALK_GROUNDED, Vector2(2310, 5660)], [JUMP, Vector2(2420, 5560)],
            [WALK_GROUNDED, Vector2(2970, 5500)], [WALK_GROUNDED, Vector2(3550, 5420)]]],
    ],
    [
        ["shrine and flume connect under the roof", Vector2(2986, 1240), [
            [WALK_GROUNDED, Vector2(3440, 1320)], [WALK_GROUNDED, Vector2(2986, 1240)]]],
        ["flume to pump and back to the shrine", Vector2(2986, 1240), [
            [WALK_GROUNDED, Vector2(3440, 1320)], [WALK_GROUNDED, Vector2(3725, 1378)],
            [WALK, Vector2(3845, 1490)], [WALK_GROUNDED, Vector2(3490, 1700)],
            [WALK_GROUNDED, Vector2(3848, 1490)], [JUMP, Vector2(3733, 1378)],
            [WALK_GROUNDED, Vector2(2986, 1240)]], true],
        ["tide shrine back to the undercanal", Vector2(1710, 4950), [
            [WALK_GROUNDED, Vector2(1649, 4950)], [JUMP, Vector2(1583, 4860)],
            [JUMP, Vector2(1750, 4760)], [WALK, Vector2(2047, 4800)]]],
        ["lower pump catch and exit", Vector2(2960, 3320), [
            [WALK, Vector2(3124, 3398)], [JUMP, Vector2(3250, 3320)]]],
        ["standpipe top dock", Vector2(1105, 1686), [
            [JUMP, Vector2(1243, 1658)], [JUMP, Vector2(1266, 1540)]]],
    ],
    [
        ["atrium floor to upper gallery", Vector2(2585, 2130), [
            [JUMP, Vector2(2702, 2032)], [JUMP, Vector2(2645, 1926)], [JUMP, Vector2(2770, 1812)],
            [WALK, Vector2(2950, 1812)], [JUMP, Vector2(3080, 1712)], [WALK, Vector2(3200, 1712)],
            [JUMP, Vector2(3295, 1622)], [JUMP, Vector2(3201, 1512)], [JUMP, Vector2(3300, 1400)]]],
        ["chute upper landing", Vector2(5300, 922), [
            [WALK, Vector2(5540, 986)], [WALK, Vector2(5660, 1248)]]],
    ],
    [
        ["south root road out and back", Vector2(990, 2420), [
            [WALK, Vector2(1560, 2474)], [WALK, Vector2(2360, 2458)], [WALK, Vector2(2800, 2422)],
            [WALK, Vector2(3400, 2484)], [WALK, Vector2(3800, 2452)], [WALK, Vector2(4450, 2432)],
            [WALK, Vector2(3800, 2452)], [WALK, Vector2(2800, 2422)], [WALK, Vector2(990, 2420)]]],
        ["vine ledges above the dock", Vector2(5288, 2300), [
            [JUMP, Vector2(5401, 2202)], [JUMP, Vector2(5455, 2128)],
            [JUMP, Vector2(5384, 2072)], [JUMP, Vector2(5520, 2000)]]],
    ],
    [
        ["lower road rest and climb", Vector2(2120, 2496), [
            [JUMP, Vector2(2025, 2442)], [JUMP, Vector2(1935, 2390)], [WALK, Vector2(1530, 2286)]]],
        ["watch tower steps", Vector2(3170, 1224), [
            [JUMP, Vector2(3265, 1122)], [JUMP, Vector2(3225, 1014)], [JUMP, Vector2(3300, 906)],
            [JUMP, Vector2(3243, 810)], [JUMP, Vector2(3325, 690)]]],
        ["grave terrace approach", Vector2(335, 1514), [
            [JUMP, Vector2(264, 1392)]]],
    ],
    [
        ["forecourt rib and return", Vector2(2348, 846), [
            [JUMP, Vector2(2496, 828)], [JUMP, Vector2(2475, 700)]]],
        ["east shoulder recovery", Vector2(4028, 940), [
            [WALK, Vector2(4168, 1060)], [JUMP, Vector2(4270, 1052)]]],
        ["core drop to bell vault", Vector2(3100, 1930), [
            [WALK, Vector2(2945, 2078)], [WALK, Vector2(2785, 2212)], [WALK, Vector2(2998, 2350)],
            [WALK, Vector2(2815, 2506)], [WALK, Vector2(2938, 2660)], [WALK, Vector2(2690, 2900)]]],
    ],
]

var checks := 0
var regions := 0
var failures: Array[String] = []
var world: Node
var player: CharacterBody2D

func _initialize() -> void:
    call_deferred("run")


func run() -> void:
    for index in REGIONS.size():
        var id: String = REGIONS[index]
        world = load("res://scenes/World.tscn").instantiate()
        world.config_path = ROUTES.config_path(id)
        world.world_resume = false
        world.world_save_path = "user://six_region_routes_validation.json"
        root.add_child(world)
        await READY.wait_for(world)
        current_scene = world
        player = world.player
        player.debug_invulnerable = true
        check(world.config.id == id and not player.dash_unlocked and not player.double_jump_unlocked,
            "%s starts with ordinary movement" % id)

        for route in CIRCUITS[index]:
            if not await place(route[1]):
                check(false, "%s / %s: start %s could not settle" % [id, route[0], route[1]])
                continue
            var require_headroom: bool = route.size() == 4 and route[3]
            for step in route[2]:
                if not await reach(step[0], step[1], require_headroom):
                    check(false, "%s / %s: landed at %s heading for %s" % [id, route[0], player.position, step[1]])
                    break
                check(true, "")
        if index == 0:
            await check_solid_underside(Vector2(2920, 3636), "terrain_court_station_ramp")
            await check_solid_underside(Vector2(3550, 2252), "terrain_court_upper_ramp")
            await check_cistern_gate()
        elif index == 1:
            await check_solid_underside(Vector2(3846, 1622), "terrain_flume_return")
        release_input()
        RETIRE.retire_tree(world)
        world.queue_free()
        await process_frame
        await process_frame
        AUDIO._stream_cache.clear()
        AUDIO._npc_voice_cache.clear()
        check(await RETIRE.drain(self), "%s releases audio" % id)
        regions += 1
    print("SIX_REGION_ROUTES regions=%d checks=%d failures=%d" % [regions, checks, failures.size()])
    for failure in failures:
        push_error(failure)
    quit(0 if failures.is_empty() else 1)


func check_solid_underside(feet: Vector2, terrain_id: String) -> void:
    player.global_position = feet
    player.velocity = Vector2.ZERO
    world._warm_arrival_terrain()
    await physics_frame
    var collision := KinematicCollision2D.new()
    var hit := player.test_move(Transform2D(0.0, feet), Vector2.UP * 42.0, collision)
    var body: Node = world.chapter_terrain.get_node_or_null(terrain_id)
    check(body != null and hit and collision.get_collider() == body and collision.get_normal().y > 0.5,
        "%s physically blocks an upward body sweep through the stone" % terrain_id)


func check_cistern_gate() -> void:
    const GATE := "gate_dash_deep"
    var gate: StaticBody2D = world.locked_gate_bodies.get(GATE)
    check(is_instance_valid(gate) and not player.dash_unlocked, "the deep cistern starts with the dash gate closed")
    if not is_instance_valid(gate):
        return
    var sign: Node2D = gate.get_node_or_null("AbilityGateSign")
    check(await place(Vector2(3560, 5120)), "the upper approach settles on the cistern ring")
    Input.action_press("move_right")
    await frames(105)
    release_input()
    check(player.is_on_floor() and player.position.x >= 3810.0 and absf(player.position.y - 5120.0) < 2.0,
        "walking against the end of the ring stays on the grate instead of dropping behind the gate: %s" % player.position)

    check(await place(Vector2(3550, 5420)), "the dash gate has a safe approach from the hollow")
    Input.action_press("move_right")
    await frames(65)
    release_input()
    check(player.is_on_floor() and player.position.x < gate.position.x and not sign.showing_return,
        "the closed gate blocks the reward approach and names the required ability")

    # Simulate a player who reached the old pocket before the grate existed.
    check(await place(Vector2(3780, 5420)), "the old gate-side landing remains solid")
    check(sign.showing_return and sign.caption() == "↑ " + world.tr("水窖环廊"),
        "the inside face points up to the return route")
    for landing in [Vector2(3776, 5324), Vector2(3798, 5222), Vector2(3810, 5120)]:
        var reached := await reach(JUMP, landing)
        check(reached, "the old landing can reach %s with a normal jump: %s" % [landing, player.position])
        if not reached:
            break
    check(await reach(WALK_GROUNDED, Vector2(3650, 5120)) and not player.dash_unlocked,
        "the return grate reconnects to the cistern ring without the ability")
    for step in CISTERN_TO_FIRST_SHRINE:
        var reached := await reach(step[0], step[1])
        check(reached, "the uninterrupted way from the cistern back to the first shrine reaches %s: %s"
            % [step[1], player.position])
        if not reached:
            break

    world._add_inventory_item("thread_dash", 1, false)
    world._refresh_ability_gates()
    check(await place(Vector2(3550, 5420)), "start the earned-ability route from the hollow")
    check(player.dash_unlocked and not world.locked_gate_bodies.has(GATE)
        and await reach(WALK_GROUNDED, Vector2(3850, 5420)),
        "owning Crimson Dash opens the gate to a continuous floor")
    check(await reach(JUMP, Vector2(3990, 5356)), "a normal jump reaches the spindle plinth")
    check(int(world.inventory_counts.get("energy_spindle", 0)) == 1,
        "the player can collect the spindle through the intended entrance")


func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)


func place(landing: Vector2) -> bool:
    release_input()
    player.global_position = landing - Vector2(0, 8)
    player.velocity = Vector2.ZERO
    world._warm_arrival_cave()
    world._warm_arrival_terrain()
    world._warm_arrival_platforms()
    player.reset_camera_after_arrival()
    await frames(10)
    return landed(landing)


func reach(kind: int, landing: Vector2, require_headroom: bool = false) -> bool:
    release_input()
    await frames(3)
    if kind == JUMP:
        Input.action_press("jump")
    var budget := 90 + ceili(absf(landing.x - player.position.x) / 3.0)
    var airborne := 0
    for tick in budget:
        var dx := landing.x - player.position.x
        var direction := signf(dx) if absf(dx) > 8.0 else 0.0
        Input.action_release("move_left")
        Input.action_release("move_right")
        if direction != 0.0:
            Input.action_press("move_right" if direction > 0.0 else "move_left")
        await frames(1)
        if require_headroom and player.is_on_ceiling():
            print("ROUTE_CEILING_CONTACT at=%s target=%s" % [player.position, landing])
            break
        if kind == WALK_GROUNDED:
            if world.world_passage.active:
                break
            airborne = 0 if can_snap_to_route_floor() else airborne + 1
            if airborne > 3:
                print("ROUTE_LOST_FLOOR at=%s target=%s" % [player.position, landing])
                break
        if (kind != JUMP or tick >= 8) and landed(landing):
            release_input()
            return true
    release_input()
    return false


func can_snap_to_route_floor() -> bool:
    if player.is_on_floor():
        return true
    # At a slope-to-flat join, Godot can clear the floor flag before the next snap.
    var contact := KinematicCollision2D.new()
    var snap := -player.up_direction * player.floor_snap_length
    return player.test_move(player.global_transform, snap, contact) \
        and contact.get_normal().dot(player.up_direction) >= cos(player.floor_max_angle)


func landed(point: Vector2) -> bool:
    return player.is_on_floor() and absf(player.position.x - point.x) < 19.0 and absf(player.position.y - point.y) < 9.0


func release_input() -> void:
    for action in ["move_left", "move_right", "jump"]:
        Input.action_release(action)


func frames(count: int) -> void:
    for frame in count:
        await physics_frame
        await process_frame
