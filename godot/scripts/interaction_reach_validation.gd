extends SceneTree
## Every F-interactable in each World region must win the real
## interaction_target() choice from some stretch of floor beside it. Two
## objects authored on (or within a few px of) the same spot leave one of them
## permanently unselectable: F always picks its neighbour. The Player is placed
## along the floor line under each object (feet 40px below, the authored
## convention) every 5px across the interaction reach; no input or physics
## step is needed because selection reads positions only.
const ROUTES := preload("res://scripts/world_routes.gd")
const PASSAGE := preload("res://scripts/world_passage.gd")
const REGIONS := ["demo_ch01_moss_bell_court", "demo_ch02_rain_foundry_canal", "demo_ch03_saltwhite_archive",
    "demo_ch04_broken_string_greenhouse", "demo_ch05_obsidian_pilgrim_road", "demo_ch06_silent_crown_core"]
const KINDS := ["lever", "boss_gate", "npc", "save_point", "chapter_exit", "ending_exit", "ending_gate", "world_portal", "death_cache", "history", "challenge_shrine", "hunt_track"]
const STEP := 5.0
const MIN_STRETCH := 20.0
const FEET := 40.0

var failures := 0
var checks := 0


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var world: Node = load("res://scenes/World.tscn").instantiate()
    world.world_resume = false
    world.world_save_path = "user://interaction_reach.json"
    root.add_child(world)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(world)
    await _frames(10)
    world._close_overlays()
    var total := 0
    var narrowest := INF
    for region: String in REGIONS:
        var path := ROUTES.config_path(region)
        var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
        var entry: Array = config.save_points[0].position
        if String(world.config.get("id", "")) != region:
            var arrived: bool = await world.world_loader.replace_region_async(world, path, Vector2(entry[0], entry[1]))
            _check(arrived, region + " loads")
            if not arrived:
                continue
        # Save points, shrines and props are built by deferred region jobs;
        # wait until the interactable set stops growing.
        var areas := _interactables(world)
        var stable := 0
        for frame in 600:
            await process_frame
            var now := _interactables(world)
            stable = stable + 1 if now.size() == areas.size() else 0
            areas = now
            if stable >= 60 and not world.world_loading:
                break
        var player: CharacterBody2D = world.player
        var spot: Vector2 = player.global_position
        _check(areas.size() >= 8, "%s has its interactables (%d)" % [region, areas.size()])
        for area in areas:
            if not is_instance_valid(area):
                continue
            # Nearby actors and props are resident only around the Player.
            player.global_position = area.global_position + Vector2(0, FEET)
            player.velocity = Vector2.ZERO
            for frame in 12:
                await physics_frame
            if not is_instance_valid(area):
                continue
            var stretch := _longest_stretch(world, player, area)
            total += 1
            narrowest = minf(narrowest, stretch)
            _check(stretch >= MIN_STRETCH, "%s %s (%s at %s) wins F from %.0fpx of floor" % [region, area.name, area.get_meta("kind", ""), str(area.global_position), stretch])
        player.global_position = spot
        await _frames(2)
    if failures > 0:
        print("INTERACTION_REACH_FAIL failures=%d checks=%d" % [failures, checks])
        quit(1)
        return
    print("INTERACTION_REACH_PASS interactables=%d narrowest=%.0f checks=%d" % [total, narrowest, checks])
    quit(0)


## Walk passages change region by walking through and are not F targets.
func _interactables(world: Node) -> Array:
    var rows: Array = []
    for child in world.get_children():
        if not is_instance_valid(child) or not child is Area2D or not child.is_visible_in_tree():
            continue
        var kind := String(child.get_meta("kind", ""))
        if not KINDS.has(kind) and not bool(child.get_meta("manual_pickup", false)):
            continue
        if kind == "world_portal" and not PASSAGE.endpoint(String(world.config.id), String(child.name)).is_empty():
            continue
        rows.append(child)
    return rows


func _longest_stretch(world: Node, player: CharacterBody2D, area: Area2D) -> float:
    var home := player.global_position
    var best := 0.0
    var run := 0.0
    var reach := float(world.INTERACTION_REACH)
    var x := -reach
    while x <= reach:
        player.global_position = area.global_position + Vector2(x, FEET)
        if world.interaction_target(area) == area:
            run += STEP
            best = maxf(best, run)
        else:
            run = 0.0
        x += STEP
    player.global_position = home
    return best


func _frames(count: int) -> void:
    for index in count:
        await process_frame


func _check(condition: bool, label: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error("INTERACTION_REACH " + label)
