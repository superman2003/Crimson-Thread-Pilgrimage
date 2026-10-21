extends SceneTree
## B01 species roles on production enemy actors: ambush reveal range and post,
## alarm calls bounded by radius/territory/cooldown, wall occlusion and chase
## disengage, guards holding post, and authored ambushers away from arrivals.
## Fixture target and walls; decisions, sight rays and movement are production.
const ENEMY := preload("res://scripts/enemy_actor.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const PROFILE_PATH := "res://data/original_creature_combat.json"
const REGIONS := ["demo_ch01_moss_bell_court", "demo_ch02_rain_foundry_canal", "demo_ch03_saltwhite_archive", "demo_ch04_broken_string_greenhouse", "demo_ch05_obsidian_pilgrim_road", "demo_ch06_silent_crown_core"]
const AMBUSH_ENTRANCE_CLEARANCE := 240.0
var checks := 0
var failures := 0
var stage: Node2D
var target: CharacterBody2D

func _initialize() -> void:
    call_deferred("run")

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(label)

func spawn(kind: String, id: String, at: Vector2, boss := false) -> Area2D:
    var enemy: Area2D = ENEMY.new()
    # Chapters pass the species profile, so territory matches the authored leash.
    var species: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH)).get(kind, {})
    enemy.configure({"id": id, "kind": kind, "hp": 6, "damage": 1, "patrol": 80.0}, "", boss, species)
    enemy.position = at
    stage.add_child(enemy)
    enemy.set_physics_process(false)
    return enemy

func step(enemy: Area2D, seen: CharacterBody2D, count := 1) -> void:
    for index in count:
        enemy._update_patrol_or_aggro(0.1, seen)

func wall(x: float) -> StaticBody2D:
    var body := StaticBody2D.new()
    body.collision_layer = 1
    var shape := CollisionShape2D.new()
    var rect := RectangleShape2D.new()
    rect.size = Vector2(20, 400)
    shape.shape = rect
    body.add_child(shape)
    body.position = Vector2(x, 200)
    stage.add_child(body)
    return body

func clear_stage() -> void:
    for child in stage.get_children():
        if child != target: child.free()
    await physics_frame
    await physics_frame

func run() -> void:
    stage = Node2D.new()
    root.add_child(stage)
    target = CharacterBody2D.new()
    target.add_to_group("player")
    stage.add_child(target)
    await process_frame
    await _data_contract()
    await _ambush()
    await _alarm()
    await _occlusion_and_disengage()
    await _guard_post()
    _ambush_placement()
    print("ENEMY_TACTICAL_ROLES checks=%d failures=%d" % [checks, failures])
    quit(0 if failures == 0 else 1)

func _data_contract() -> void:
    var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
    var counts := {}
    for kind in profiles:
        var entry: Dictionary = profiles[kind]
        var role := String(entry.get("tactical_role", ""))
        counts[role] = int(counts.get(role, 0)) + 1
        var motion := String(entry.locomotion)
        check(ENEMY.TACTICAL_ROLES.has(role), "%s has a known tactical role (%s)" % [kind, role])
        check((role == "boss") == bool(entry.get("tactical_ai", false)), "%s: only tactical bosses use the boss role" % kind)
        var consistent := true
        match role:
            "aerial": consistent = motion == "flight"
            "ranged": consistent = motion == "stationary" or float(entry.preferred_range) >= 120.0
            "ambush", "patrol": consistent = motion == "ground"
            "guard": consistent = motion == "stationary" or bool(entry.get("front_guard", false))
        check(consistent, "%s: %s role matches its locomotion and spacing" % [kind, role])
    for role in ENEMY.TACTICAL_ROLES:
        check(int(counts.get(role, 0)) > 0, "the roster includes at least one %s" % role)
    var bookmite := spawn("salt_bookmite", "role_probe", Vector2(0, 300))
    check(bookmite.tactical_role == "ambush" and bookmite.get_ai_debug_state().tactical_role == "ambush", "production actor reads its species role")
    var boss := spawn("rust_crown_guardian", "role_boss", Vector2(0, 300), true)
    check(boss.tactical_role == "boss" and not boss.hear_alarm(Vector2.ZERO), "bosses keep their own tactics and ignore alarms")
    var override: Area2D = ENEMY.new()
    override.configure({"id": "role_override", "kind": "salt_bookmite", "encounter_profile": {"tactical_role": "patrol"}}, "")
    check(override.tactical_role == "patrol", "a spawn can relax an entrance ambusher to patrol")
    override.free()
    await clear_stage()

func _ambush() -> void:
    var bookmite := spawn("salt_bookmite", "ambush_bookmite", Vector2(300, 300))
    var larva := spawn("moss_larva", "ambush_compare", Vector2(300, 600))
    target.position = Vector2(520, 300)
    await physics_frame
    step(bookmite, target, 10)
    check(bookmite.last_ai_decision == "lurk" and is_equal_approx(bookmite.global_position.x, 300.0), "ambusher stays hidden at its post outside its reveal range")
    check(bookmite.memory_timer == 0.0, "an unrevealed ambusher does not start tracking")
    target.position = Vector2(520, 600)
    await physics_frame
    step(larva, target)
    check(larva.memory_timer > 0.0, "a patrolling species engages at its ordinary aggro range")
    target.position = Vector2(420, 300)
    await physics_frame
    step(bookmite, target)
    check(bookmite.memory_timer > 0.0 and bookmite.last_ai_decision != "lurk", "ambusher reveals itself once the player is close")
    bookmite.state = "patrol"
    bookmite.global_position.x = 380.0
    bookmite.memory_timer = 0.0
    step(bookmite, null)
    check(bookmite.last_ai_decision == "return_post" and bookmite.global_position.x < 380.0, "after losing the player an ambusher walks back to its post")
    step(bookmite, null, 60)
    check(bookmite.last_ai_decision == "lurk" and absf(bookmite.global_position.x - 300.0) <= 6.0, "ambusher resumes waiting at its exact post")
    await clear_stage()

func _alarm() -> void:
    # The near ally cannot see the player through a wall; only the bell can.
    var bell := spawn("spore_bellmaker", "alarm_bell", Vector2(200, 300))
    var near := spawn("moss_larva", "alarm_near", Vector2(0, 300))
    var far := spawn("moss_larva", "alarm_far", Vector2(-400, 300))
    var late := spawn("moss_larva", "alarm_late", Vector2(-60, 300))
    var blocker := wall(100)
    target.position = Vector2(260, 300)
    late.memory_timer = 0.5  # already searching: not counted as newly told
    await physics_frame
    await physics_frame
    step(near, target)
    check(near.memory_timer == 0.0, "the walled-off ally cannot see the player by itself")
    step(bell, target)
    check(bell.alarm_alerted == 1 and bell.alarm_cooldown > 0.0, "the bell alerts exactly the idle ally inside its radius")
    check(near.memory_timer > 0.0 and is_equal_approx(near.last_seen_position.x, 260.0), "the ally is told where the player was seen")
    check(far.memory_timer == 0.0, "allies beyond the alarm radius stay unaware")
    var engaged := false
    for index in 80:
        step(near, target)
        if near.last_ai_decision in ["press", "advance", "threaten", "space"] or near.state == "windup":
            engaged = true
            break
    check(engaged, "the alerted ally walks toward the call until it sees and engages the player")
    var repeat := spawn("moss_larva", "alarm_repeat", Vector2(100, 600))
    bell.memory_timer = 0.0
    step(bell, target)
    check(repeat.memory_timer == 0.0, "the alarm has a cooldown instead of ringing every frame")
    blocker.free()
    var edge := spawn("moss_larva", "alarm_edge", Vector2(-300, 300))
    target.position = Vector2(400, 300)
    edge.hear_alarm(target.global_position)
    check(is_equal_approx(edge.last_seen_position.x, -20.0), "a distant call is searched for only to the edge of the ally's own territory")
    var quiet := spawn("moss_larva", "alarm_quiet_caller", Vector2(500, 600))
    var bystander := spawn("moss_larva", "alarm_bystander", Vector2(300, 600))
    target.position = Vector2(620, 600)
    await physics_frame
    step(quiet, target)
    check(quiet.memory_timer > 0.0 and bystander.memory_timer == 0.0, "non-alarm species do not call allies")
    await clear_stage()

func _occlusion_and_disengage() -> void:
    var larva := spawn("moss_larva", "sight_larva", Vector2(300, 300))
    target.position = Vector2(450, 300)
    var blocker := wall(375)
    await physics_frame
    await physics_frame
    step(larva, target)
    check(larva.memory_timer == 0.0 and larva.last_ai_decision == "patrol", "a terrain wall blocks sight inside aggro range")
    blocker.free()
    await physics_frame
    await physics_frame
    step(larva, target)
    check(larva.memory_timer > 0.0, "the same player is engaged once the wall is gone")
    larva.state = "patrol"
    blocker = wall(375)
    await physics_frame
    await physics_frame
    step(larva, target)
    check(larva.last_ai_decision == "investigate", "losing sight starts a search of the last-seen point")
    larva.memory_timer = 0.0
    step(larva, target)
    check(larva.last_ai_decision == "patrol", "the search ends and the enemy disengages to its patrol")
    await clear_stage()

func _guard_post() -> void:
    var sentinel := spawn("gear_sentinel", "guard_sentinel", Vector2(300, 300))
    target.position = Vector2(420, 300)
    await physics_frame
    step(sentinel, target)
    check(sentinel.memory_timer > 0.0, "the guard engages a visible intruder")
    sentinel.state = "patrol"
    sentinel.global_position.x = 360.0
    step(sentinel, null)
    check(sentinel.last_ai_decision == "return_post" and sentinel.global_position.x < 360.0, "a guard returns to its post instead of searching the last-seen point")
    step(sentinel, null, 40)
    check(sentinel.last_ai_decision == "hold_post" and absf(sentinel.global_position.x - 300.0) <= 6.0, "the guard holds its post while still alert")
    await clear_stage()

func _ambush_placement() -> void:
    var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
    var routes: Dictionary = ROUTES.cached_data()
    var ambushers := 0
    for region in REGIONS:
        var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json" % region))
        var arrivals: Array = []
        for portal in routes.get("chapters", {}).get(region, {}).get("portals", []):
            arrivals.append(Vector2(portal.position[0], portal.position[1]))
        if config.has("player_start"):
            arrivals.append(Vector2(config.player_start[0], config.player_start[1]))
        for spawn_data in config.get("enemy_spawns", []):
            var role := String(spawn_data.get("encounter_profile", {}).get("tactical_role", profiles.get(String(spawn_data.get("kind", "")), {}).get("tactical_role", "")))
            if role != "ambush":
                continue
            ambushers += 1
            var at := Vector2(spawn_data.position[0], spawn_data.position[1])
            var nearest := INF
            for point in arrivals: nearest = minf(nearest, at.distance_to(point))
            check(nearest >= AMBUSH_ENTRANCE_CLEARANCE, "%s %s ambusher is %.0fpx from the nearest arrival" % [region, spawn_data.id, nearest])
    check(ambushers >= 6, "authored rooms still contain real ambushers (%d)" % ambushers)
