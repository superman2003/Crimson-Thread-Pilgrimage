extends SceneTree
## Polygon/physics fixtures, not natural play or a performance benchmark.
const TERRAIN := preload("res://scripts/chapter_terrain.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const COORDINATES := preload("res://scripts/world_coordinates.gd")
const ACTIVE := 1 << 23
const REFERENCE := 1 << 22
const SAVE := "user://terrain_collision_streaming_validation.json"
var checks := 0
var failures: Array[String] = []
var metrics: Array = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    root.process_mode = Node.PROCESS_MODE_DISABLED
    for id in COORDINATES.manifest().regions:
        await _region(id)
    await _budget()
    await _host()
    print("TERRAIN COLLISION METRICS ", JSON.stringify(metrics))
    if failures.is_empty():
        print("TERRAIN COLLISION STREAMING PASS: %d checks" % checks)
        call_deferred("quit", 0)
    else:
        for message in failures:
            push_error(message)
        call_deferred("quit", 1)

func _region(id: String) -> void:
    var config: Dictionary = ROUTES.apply_to(JSON.parse_string(FileAccess.get_file_as_string(ROUTES.config_path(id))))
    var reference := TERRAIN.new()
    root.add_child(reference)
    reference.position = Vector2(100000, 0)
    reference.configure(config, String(config.art_theme))
    for body in reference.get_children():
        body.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
        body.collision_layer = REFERENCE
    var terrain := TERRAIN.new()
    root.add_child(terrain)
    var focus := Vector2(config.player_start[0], config.player_start[1])
    terrain.configure(config, String(config.art_theme), true, focus, true)
    for body in terrain.get_children():
        body.collision_layer = ACTIVE
    _check(terrain.collision_regions == reference.collision_regions, id + " complete immutable polygons unchanged")
    var arrival: Dictionary = terrain.collision_snapshot()
    _check(arrival.resident < arrival.authored, id + " unloaded distant polygon nodes")
    for index in range(terrain.collision_records.size()):
        var record: Dictionary = terrain.collision_records[index]
        terrain.warm_collision_focus(record.bounds.get_center())
        await _frames(2)
        var node: CollisionPolygon2D = terrain.resident_collisions[index]
        _check(node.polygon == reference.collision_records[index].polygon, id + " authored polygon geometry unchanged")
        _check(node.one_way_collision == reference.collision_records[index].one_way and node.one_way_collision_margin == 2, id + " one-way properties unchanged")
        for needed in range(terrain.collision_records.size()):
            if terrain.critical_bounds.intersects(terrain.collision_records[needed].bounds):
                _check(terrain.resident_collisions.has(needed), id + " mandatory window coverage")
        var bounds: Rect2 = record.bounds
        for fraction in [0.2, 0.5, 0.8]:
            var x: float = bounds.position.x + bounds.size.x * float(fraction)
            var from := Vector2(x, bounds.position.y - 24)
            var to := Vector2(x, bounds.end.y + 24)
            var actual := _ray(from, to, ACTIVE)
            var expected := _ray(from + reference.position, to + reference.position, REFERENCE)
            var metadata: Dictionary = terrain.terrain_ray_hit(from, to)
            _check(actual.is_empty() == expected.is_empty(), id + " actual polygon ray matches fully resident")
            _check(metadata.is_empty() == expected.is_empty(), id + " immutable polygon ray matches fully resident")
            if not expected.is_empty():
                var native: Vector2 = expected.position - reference.position
                if not actual.is_empty():
                    _check(actual.position.distance_to(native) < 0.02, id + " actual slope hit exact")
                if not metadata.is_empty():
                    _check(metadata.position.distance_to(native) < 0.02, id + " fallback slope hit exact")
    terrain.warm_collision_focus(Vector2(-100000, -100000))
    _check(terrain.resident_collisions.is_empty(), id + " offworld retires all unheld polygons")
    if not terrain.collision_records.is_empty():
        var center: Vector2 = terrain.collision_records[0].bounds.get_center()
        terrain.ensure_collision_segment(center - Vector2(0, 500), center + Vector2(0, 500))
        terrain.warm_collision_focus(Vector2(-100000, -100000))
        _check(terrain.resident_collisions.has(0), id + " remote segment pins polygon")
        await _frames(4)
        terrain.warm_collision_focus(Vector2(-100000, -100000))
        _check(terrain.collision_pins.is_empty() and terrain.resident_collisions.is_empty(), id + " query pins expire")
    terrain.update_collision_window(focus, Vector2(9000, -8000), 0.25)
    for needed in range(terrain.collision_records.size()):
        if terrain.critical_bounds.intersects(terrain.collision_records[needed].bounds):
            _check(terrain.resident_collisions.has(needed), id + " fast movement sweep covered")
    terrain.warm_collision_focus(Vector2(-100000, -100000))
    var before: int = terrain.collision_loads
    terrain.update_collision_window(Vector2(-100000, -100000), Vector2.ZERO, 0)
    _check(terrain.collision_loads == before, id + " empty prefetch does not build unrelated polygons")
    for support in terrain.support_rects:
        terrain.hold_collision_support(support)
    terrain.warm_collision_focus(Vector2(-100000, -100000))
    for held in terrain.collision_holds:
        _check(terrain.resident_collisions.has(held), id + " actor support survives retirement")
    terrain.close_collisions()
    terrain.warm_collision_focus(focus)
    _check(terrain.collision_records.is_empty() and terrain.resident_collisions.is_empty(), id + " closed generation cannot recreate")
    metrics.append({"region": id, "authored_polygons": arrival.authored, "arrival_polygons_without_actors": arrival.resident})
    terrain.free()
    reference.free()
    await _frames(2)

func _budget() -> void:
    var terrain := TERRAIN.new()
    root.add_child(terrain)
    terrain.prepare_config({}, "moss_cavern", false, true)
    for i in range(8):
        var x := 1000 + i * 70
        terrain._build_landform({"id": "budget_%d" % i, "surface": [[x, 0], [x + 40, 0]], "depth": 40})
    terrain.update_collision_window(Vector2.ZERO, Vector2.ZERO, 0)
    _check(terrain.collision_loads <= 2, "speculative work admits at most two polygons")
    var before: int = terrain.collision_loads
    terrain.update_collision_window(Vector2.ZERO, Vector2.ZERO, 0)
    _check(terrain.collision_loads - before <= 2, "next frame prefetch stays bounded")
    terrain.warm_collision_focus(Vector2(1200, 0))
    _check(terrain.resident_collisions.size() == 8, "mandatory critical window is complete")
    _check(not terrain.critical_collision_ready(), "cold critical creation waits for physics sync")
    await _frames(2)
    _check(terrain.critical_collision_ready(), "critical sync releases after physics step")
    var removed: int = terrain.collision_releases
    terrain.update_collision_window(Vector2(-100000, -100000), Vector2.ZERO, 0)
    _check(terrain.collision_releases - removed <= 2, "ordinary retirement admits at most two polygons")
    terrain.free()
    await _frames(2)

func _host() -> void:
    for suffix in ["", ".bak", ".tmp"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
    var scene: Node2D = load("res://scenes/World.tscn").instantiate()
    scene.world_resume = false
    scene.world_save_path = SAVE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene = scene
    for id in COORDINATES.manifest().regions:
        var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROUTES.config_path(id)))
        scene._travel_world(ROUTES.config_path(id), Vector2(config.player_start[0], config.player_start[1]))
        await _frames(2)
        var terrain: Node2D = scene.chapter_terrain
        var snapshot: Dictionary = terrain.collision_snapshot()
        _check(snapshot.enabled and snapshot.resident <= snapshot.authored, id + " actual host enables polygon residency")
        for actor in scene.get_children():
            if actor.has_meta("platform_id"):
                var support := String(actor.get_meta("platform_id"))
                if terrain.support_rects.has(support):
                    for index in range(terrain.collision_records.size()):
                        if terrain.support_rects[support].grow(8).intersects(terrain.collision_records[index].bounds):
                            _check(terrain.collision_holds.has(index), id + " actual live actor terrain support held")
        metrics.append({"region": id, "host_authored": snapshot.authored, "host_arrival": snapshot.resident, "actor_supports": snapshot.held})
    var terrain: Node2D = scene.chapter_terrain
    terrain._build_landform({"id": "remote_fixture_slope", "surface": [[30000, 20], [30300, -40]], "depth": 80})
    var from := Vector2(30150, -100)
    var to := Vector2(30150, 100)
    scene._ensure_collision_segment(from, to)
    var hit: Dictionary = scene._rock_ray_hit(from, to)
    _check(not hit.is_empty() and hit.get("authored_static", false) and hit.position.distance_to(Vector2(30150, -10)) < 0.02, "host immutable terrain ray works before physics sync")
    var effect := Area2D.new()
    effect.set_script(load("res://scripts/enemy_attack_effect.gd"))
    effect.position = from
    effect.velocity = Vector2(0, 2000)
    effect.duration = 5
    scene.add_child(effect)
    effect._physics_process(0.1)
    _check(effect.is_queued_for_deletion(), "actual remote hostile projectile stops at slope before sync")
    await _frames(2)
    terrain.close_collisions()
    _check(terrain.terrain_ray_hit(from, to).is_empty(), "closed departing host ignores immutable terrain query")
    scene.free()
    current_scene = null
    await _frames(2)
    for suffix in ["", ".bak", ".tmp"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))

func _ray(from: Vector2, to: Vector2, mask: int) -> Dictionary:
    return root.world_2d.direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(from, to, mask))

func _frames(count: int) -> void:
    for i in range(count):
        await physics_frame
        await process_frame

func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures.append(message)
