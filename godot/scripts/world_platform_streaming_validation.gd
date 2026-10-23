extends SceneTree
## State/physics fixtures; not natural combat or an FPS benchmark.
const ROUTES := preload("res://scripts/world_routes.gd")
const COORDINATES := preload("res://scripts/world_coordinates.gd")
const STATE := preload("res://scripts/world_state.gd")
const ATTACK := preload("res://scripts/enemy_attack_effect.gd")
const TOOL := preload("res://scripts/player_tool_effect.gd")
const PATH := "user://world_platform_streaming_validation.json"
const ACTIVE_LAYER := 1 << 24
const REFERENCE_LAYER := 1 << 25
var scene: Node2D
var checks := 0
var failures: Array[String] = []
var metrics: Array = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    root.process_mode = Node.PROCESS_MODE_DISABLED
    _clean()
    scene = load("res://scenes/World.tscn").instantiate()
    scene.world_resume = false
    scene.world_save_path = PATH
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene = scene
    await _frames(2)
    for id in COORDINATES.manifest().regions:
        await _region(id)
    await _remote_effects()
    var service: RefCounted = scene.world_platforms
    preload("res://scripts/audio_retirement.gd").retire_tree(scene)
    scene.free()
    current_scene = null
    await _frames(2)
    _check(service.closed and service.records.is_empty() and service.resident.is_empty(), "host exit releases platform references")
    service = null
    _check(await preload("res://scripts/audio_retirement.gd").drain(self), "platform fixture releases audio playback before exit")
    _clean()
    print("PLATFORM RESIDENCY METRICS ", JSON.stringify(metrics))
    if failures.is_empty():
        print("WORLD PLATFORM STREAMING PASS: %d checks; authored physics/visual parity, pins, blockers, arrival and teardown" % checks)
        call_deferred("quit", 0)
    else:
        for message in failures:
            push_error(message)
        call_deferred("quit", 1)

func _region(id: String) -> void:
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROUTES.config_path(id)))
    var focus := Vector2(raw.player_start[0], raw.player_start[1])
    var departed: RefCounted = scene.world_platforms
    scene._travel_world(ROUTES.config_path(id), focus)
    _check(departed.closed and departed.records.is_empty() and departed.resident.is_empty(), id + " departed service cannot recreate stale platforms")
    departed = null
    await _frames(2)
    var service: RefCounted = scene.world_platforms
    var initial: Dictionary = service.snapshot()
    for bad in [{"rect": [0, 0, 30, 20]}, {"id": "bad", "rect": [0, 0, 0, 20]}]:
        var invalid: Dictionary = raw.duplicate(true)
        invalid.platforms = [bad]
        _check(scene.world_loader.validate_config(invalid, ROUTES.config_path(id), focus).is_empty(), id + " invalid platform rejected before eviction")
    var duplicate: Dictionary = raw.duplicate(true)
    duplicate.platforms = [{"id": "duplicate", "rect": [0, 0, 30, 20]}, {"id": "duplicate", "rect": [100, 0, 30, 20]}]
    _check(scene.world_loader.validate_config(duplicate, ROUTES.config_path(id), focus).is_empty(), id + " duplicate platform rejected before eviction")
    _check(initial.authored > initial.resident, id + " initial arrival omits distant platforms")
    var references := Node2D.new()
    references.position = Vector2(100000, 0)
    references.name = "PlatformReference"
    scene.add_child(references)
    var ref_by_id: Dictionary = {}
    for platform in scene.config.platforms:
        if platform.has("terrain_id"):
            _check(not service.records.has(String(platform.id)), id + " terrain ownership unchanged")
            continue
        if scene._is_post_boss_blocker(String(platform.id)):
            _check(not service.records.has(String(platform.id)), id + " stateful blocker never enters ordinary registry")
            continue
        var data: Dictionary = platform
        var body: StaticBody2D = scene._make_region_platform(data)
        body.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
        body.collision_layer = REFERENCE_LAYER
        scene.remove_child(body)
        references.add_child(body)
        body.name = String(data.id)
        ref_by_id[String(data.id)] = body
    var peak: int = initial.resident
    for platform_id in service.records:
        var rect: Rect2 = service.records[platform_id].bounds
        service.warm(scene, rect.get_center())
        await _frames(1)
        var body: StaticBody2D = service.resident[platform_id]
        var reference: StaticBody2D = ref_by_id[platform_id]
        _check(_signature(body) == _signature(reference), id + " original collision role/shape and sprite metadata " + platform_id)
        for resident in service.resident.values():
            resident.collision_layer = ACTIVE_LAYER
        var from := rect.get_center() - Vector2(rect.size.x * 0.5 + 20, 0)
        var to := rect.get_center() + Vector2(rect.size.x * 0.5 + 20, 0)
        var actual := _ray(from, to, ACTIVE_LAYER)
        var expected := _ray(from + references.position, to + references.position, REFERENCE_LAYER)
        _check(actual.is_empty() == expected.is_empty(), id + " actual/full platform ray agreement")
        if not actual.is_empty() and not expected.is_empty():
            _check(actual.position.is_equal_approx(expected.position - references.position), id + " exact authored ray hit")
        var authoritative: Dictionary = service.ray_hit(scene, from, to)
        _check(authoritative.is_empty() == expected.is_empty(), id + " metadata collision agrees with full resident physics")
        if not authoritative.is_empty() and not expected.is_empty():
            _check(authoritative.position.is_equal_approx(expected.position - references.position), id + " metadata nearest hit agreement")
        for required in service.records:
            if service.load_bounds.intersects(service.records[required].bounds):
                _check(service.resident.has(required), id + " visible/critical platform available")
        peak = maxi(peak, service.snapshot().resident)
        _check(service.snapshot().resident <= initial.authored, id + " no duplicate platform ownership")
    for checkpoint in scene.config.get("save_points", []):
        var point := Vector2(checkpoint.position[0], checkpoint.position[1])
        service.update(scene, point, Vector2(8000, -6000), 0.25)
        for required in service.records:
            if service.critical_bounds.intersects(service.records[required].bounds):
                _check(service.resident.has(required), id + " swept checkpoint coverage")
    service.warm(scene, Vector2(-100000, -100000))
    _check(service.resident.size() == service.held.size(), id + " only live actor supports survive far retirement")
    for support in service.held:
        _check(service.resident.has(support) and is_instance_valid(service.resident[support]), id + " live actor support remains resident")
    if not service.records.is_empty():
        var target: String = service.records.keys()[0]
        var center: Vector2 = service.records[target].bounds.get_center()
        service.ensure_segment(scene, center - Vector2(20, 0), center + Vector2(20, 0))
        service.warm(scene, Vector2(-100000, -100000))
        _check(service.resident.has(target), id + " short-lived query pin prevents retirement")
        await _frames(4)
        service.warm(scene, Vector2(-100000, -100000))
        _check(service.pins.is_empty() and service.resident.size() == service.held.size(), id + " expired pins do not retain distant platforms")
    # Ordinary residency must never resurrect a stateful post-boss wall.
    scene._open_post_boss_route()
    await _frames(2)
    for platform in scene.config.platforms:
        if scene._is_post_boss_blocker(String(platform.id)):
            _check(scene.get_node_or_null(String(platform.id)) == null, id + " opened post-boss wall absent")
    service.warm(scene, focus)
    var saved := STATE.new()
    _check(saved.read(PATH) and saved.data.current_region == id, id + " valid persistent location unaffected")
    references.free()
    await _frames(2)
    metrics.append({"region": id, "ordinary_authored": initial.authored, "arrival_resident": initial.resident, "sweep_peak": peak, "actor_supports": initial.held})

func _remote_effects() -> void:
    var data := {"id": "offscreen_test_wall", "rect": [12000, -100, 64, 200]}
    scene.world_platforms.register(scene, data, scene.player.global_position)
    _check(not scene.world_platforms.resident.has(data.id), "remote wall starts without live node")
    var effect := ATTACK.new()
    effect.position = Vector2(11950, 0)
    effect.velocity = Vector2(1000, 0)
    effect.duration = 5
    scene.add_child(effect)
    effect._physics_process(0.1)
    _check(effect.is_queued_for_deletion(), "remote hostile projectile stops at ordinary platform before sync")
    await _frames(2)
    var tool := TOOL.new()
    tool.payload = {"id": "needle", "duration": 5}
    tool.owner_player = scene.player
    tool.position = Vector2(11950, 0)
    scene.add_child(tool)
    tool._physics_process(0.2)
    _check(tool.is_queued_for_deletion() or tool.landed, "remote player tool stops at ordinary platform")
    await _frames(2)

func _signature(body: Node) -> Array:
    var result: Array = []
    for child in body.get_children():
        if child is CollisionShape2D:
            result.append([child.position, child.shape.size, child.one_way_collision, child.one_way_collision_margin])
        if child is Sprite2D:
            result.append([child.position, child.scale, child.flip_h, child.modulate, child.get_meta("original_map_asset", ""), child.region_rect])
    return result

func _ray(from: Vector2, to: Vector2, mask: int) -> Dictionary:
    var query := PhysicsRayQueryParameters2D.create(from, to, mask)
    query.hit_from_inside = true
    query.collide_with_areas = false
    return root.get_world_2d().direct_space_state.intersect_ray(query)

func _frames(count: int) -> void:
    for frame in range(count):
        await physics_frame
        await process_frame

func _clean() -> void:
    for suffix in ["", ".tmp", ".bak"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + suffix))

func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures.append(message)
