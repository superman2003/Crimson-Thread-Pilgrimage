extends SceneTree
## B02: every shrine and NPC in the six World regions is a quiet place to stand.
## With the Player parked on the spot and nearby enemies resident and running
## their normal AI for 1.5s, no enemy announces engagement and no HP is lost.
const ROUTES := preload("res://scripts/world_routes.gd")
const REGIONS := ["demo_ch01_moss_bell_court", "demo_ch02_rain_foundry_canal", "demo_ch03_saltwhite_archive",
    "demo_ch04_broken_string_greenhouse", "demo_ch05_obsidian_pilgrim_road", "demo_ch06_silent_crown_core"]
const WAIT_FRAMES := 90

var failures := 0
var checks := 0
var points := 0


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var world: Node = load("res://scenes/World.tscn").instantiate()
    world.world_resume = false
    world.world_save_path = "user://rest_point_safety.json"
    root.add_child(world)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(world)
    await _frames(10)
    world._close_overlays()
    for region: String in REGIONS:
        var path := ROUTES.config_path(region)
        var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
        if String(world.config.id) != region:
            var entry: Array = config.save_points[0].position
            var arrived: bool = await world.world_loader.replace_region_async(world, path, Vector2(entry[0], entry[1]))
            _check(arrived, region + " loads")
            if not arrived:
                continue
        await _frames(30)
        var spots: Array = []
        for npc: Dictionary in config.get("npcs", []):
            spots.append(["NPC", String(npc.id), npc.position])
        for save: Dictionary in config.get("save_points", []):
            spots.append(["shrine", String(save.id), save.position])
        for spot: Array in spots:
            await _wait_at(world, region, spot)
    _check(points >= 40, "rest points measured (%d)" % points)
    if failures > 0:
        print("REST_POINT_SAFETY_FAIL failures=%d checks=%d" % [failures, checks])
        call_deferred("quit", 1)
        return
    print("REST_POINT_SAFETY_PASS points=%d checks=%d" % [points, checks])
    call_deferred("quit", 0)


func _wait_at(world: Node, region: String, spot: Array) -> void:
    var position := Vector2(float(spot[2][0]), float(spot[2][1]))
    var player: CharacterBody2D = world.player
    player.global_position = position
    player.velocity = Vector2.ZERO
    player.restore_at_save_point()
    player.arrival_guard_timer = 0.0
    player.hurt_timer = 0.0
    player.enemy_contact_guard_timer = 0.0
    player.reset_camera_after_arrival()
    # The same arrival warm-up a real teleport performs, so nearby foes are resident.
    world._warm_arrival_cave()
    world._warm_arrival_terrain()
    world._warm_arrival_platforms()
    world.world_gameplay_residency.warm_enemy_arrival(world, position)
    await _frames(4)
    for enemy in get_nodes_in_group("enemy"):
        enemy.engage_announced = false
    var hp_before: int = player.hp
    for frame in WAIT_FRAMES:
        player.velocity.x = 0.0
        await physics_frame
    var engaged: Array = []
    for enemy in get_nodes_in_group("enemy"):
        if is_instance_valid(enemy) and enemy.engage_announced:
            engaged.append("%s:%s" % [enemy.spawn_id, enemy.kind])
    points += 1
    _check(engaged.is_empty(), "%s %s %s stays quiet; engaged %s" % [region, spot[0], spot[1], engaged])
    _check(player.hp == hp_before, "%s %s %s costs no HP while standing" % [region, spot[0], spot[1]])


func _frames(count: int) -> void:
    for index in count:
        await process_frame


func _check(condition: bool, label: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error("REST_POINT_SAFETY " + label)
