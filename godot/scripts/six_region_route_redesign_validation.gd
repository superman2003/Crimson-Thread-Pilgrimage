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
const CIRCUITS := [
    [
        ["shrine approach and return", Vector2(1170, 3612), [
            [WALK, Vector2(1420, 3692)], [WALK, Vector2(1685, 3752)],
            [WALK, Vector2(1420, 3692)], [WALK, Vector2(1160, 3612)]]],
        ["shrine and court connect past the pipe junction", Vector2(1670, 3752), [
            [WALK_GROUNDED, Vector2(2630, 3892)], [WALK_GROUNDED, Vector2(1680, 3752)]]],
        ["stairwell rises through the court grate", Vector2(2434, 3912), [
            [JUMP, Vector2(2434, 3820)]]],
        ["central bell rise", Vector2(2585, 3892), [
            [JUMP, Vector2(2610, 3800)], [JUMP, Vector2(2740, 3708)], [JUMP, Vector2(2660, 3616)],
            [JUMP, Vector2(2770, 3518)], [JUMP, Vector2(2650, 3432)], [JUMP, Vector2(2750, 3340)]]],
        ["attic lookout approach", Vector2(4200, 910), [
            [JUMP, Vector2(4300, 846)], [JUMP, Vector2(4390, 716)]]],
    ],
    [
        ["shrine and flume connect under the roof", Vector2(2986, 1240), [
            [WALK_GROUNDED, Vector2(3440, 1320)], [WALK_GROUNDED, Vector2(2986, 1240)]]],
        ["flume drop to pump", Vector2(3590, 1320), [
            [WALK, Vector2(3775, 1456)], [WALK, Vector2(3640, 1580)],
            [WALK, Vector2(3550, 1700)]]],
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
            for step in route[2]:
                if not await reach(step[0], step[1]):
                    check(false, "%s / %s: landed at %s heading for %s" % [id, route[0], player.position, step[1]])
                    break
                check(true, "")
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


func reach(kind: int, landing: Vector2) -> bool:
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
        if kind == WALK_GROUNDED:
            if world.world_passage.active:
                break
            airborne = 0 if player.is_on_floor() else airborne + 1
            if airborne > 3:
                break
        if (kind != JUMP or tick >= 8) and landed(landing):
            release_input()
            return true
    release_input()
    return false


func landed(point: Vector2) -> bool:
    return player.is_on_floor() and absf(player.position.x - point.x) < 19.0 and absf(player.position.y - point.y) < 9.0


func release_input() -> void:
    for action in ["move_left", "move_right", "jump"]:
        Input.action_release(action)


func frames(count: int) -> void:
    for frame in count:
        await physics_frame
        await process_frame
