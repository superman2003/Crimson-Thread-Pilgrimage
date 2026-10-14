extends SceneTree
## Geometry/physics fixtures; not an FPS or natural combat completion claim.
const CAVE := preload("res://scripts/cave_world.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const COORDINATES := preload("res://scripts/world_coordinates.gd")
const ATTACK := preload("res://scripts/enemy_attack_effect.gd")
const TOOL := preload("res://scripts/player_tool_effect.gd")
var checks := 0
var failures: Array[String] = []
var metrics: Array = []

class Host extends Node2D:
    var player: Node2D
    var current_room_id := "fixture"
    var chapter_terrain: Node = null
    var cave_world: Node
    func _map_room_by_id(_id: String) -> Dictionary:
        return {}
    func _world_collision_ready() -> bool:
        return cave_world.critical_collision_ready()
    func _rock_ray_hit(from: Vector2, to: Vector2) -> Dictionary:
        return cave_world.rock_ray_hit(from, to)
    func _ensure_collision_segment(from: Vector2, to: Vector2) -> void:
        cave_world.ensure_collision_segment(from, to)

class DummyPlayer extends CharacterBody2D:
    var ui_input_locked := false

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    root.process_mode = Node.PROCESS_MODE_DISABLED
    for id in COORDINATES.manifest().regions:
        await _region(id)
    await _offscreen_effects()
    print("CAVE COLLISION METRICS ", JSON.stringify(metrics))
    if failures.is_empty():
        print("CAVE COLLISION STREAMING PASS: %d checks; authored parity, swept safety, hysteresis, ray pins and teardown" % checks)
        call_deferred("quit", 0)
    else:
        for message in failures:
            push_error(message)
        call_deferred("quit", 1)

func _region(id: String) -> void:
    var config: Dictionary = ROUTES.apply_to(JSON.parse_string(FileAccess.get_file_as_string(ROUTES.config_path(id))))
    var host := Host.new()
    root.add_child(host)
    var player := DummyPlayer.new()
    host.add_child(player)
    host.player = player
    var streamed := CAVE.new()
    host.add_child(streamed)
    host.cave_world = streamed
    var focus := Vector2(config.player_start[0], config.player_start[1])
    streamed.configure(config, String(config.art_theme), host, true, focus)
    var reference := CAVE.new()
    reference.position = Vector2(100000, 0)
    host.add_child(reference)
    reference.configure(config, String(config.art_theme), host)
    await _frames(2)
    _check(streamed.solid_rects == reference.solid_rects, id + " full authoritative rectangles preserved")
    var initial: Dictionary = streamed.collision_snapshot()
    _check(initial.resident_shapes < initial.authored_shapes, id + " arrival omits distant physical shapes")
    var seen: Dictionary = {}
    for key in streamed.collision_chunks:
        for index in streamed.collision_chunks[key].indices:
            _check(not seen.has(index), id + " each source rectangle has one owning chunk")
            seen[index] = true
    _check(seen.size() == streamed.solid_rects.size(), id + " no missing authored shapes")
    var samples: Array[Vector2] = [focus]
    for point in config.get("save_points", []):
        samples.append(Vector2(point.position[0], point.position[1]))
    # Pin every remote authored obstacle and compare actual physics ray hits
    # against an independent fully resident copy translated far away.
    var peak: int = initial.resident_shapes
    for rect in streamed.solid_rects:
        var center: Vector2 = rect.get_center()
        streamed.warm_collision_focus(center)
        await _frames(1)
        _coverage(streamed, id)
        var from := center - Vector2(100, 0)
        var to := center + Vector2(100, 0)
        var actual := _ray(from, to)
        var expected := _ray(from + reference.position, to + reference.position)
        _check(actual.is_empty() == expected.is_empty(), id + " source rectangle ray collision parity")
        if not actual.is_empty() and not expected.is_empty():
            _check(actual.position.is_equal_approx(expected.position - reference.position), id + " exact ray hit position")
        var authoritative: Dictionary = streamed.rock_ray_hit(from, to)
        _check(not expected.is_empty() and not authoritative.is_empty(), id + " reference and metadata rays hit authored rock")
        if not expected.is_empty() and not authoritative.is_empty():
            _check(authoritative.position.is_equal_approx(expected.position - reference.position), id + " descriptor hit matches full physics reference")
        var snap: Dictionary = streamed.collision_snapshot()
        peak = maxi(peak, snap.resident_shapes)
        _check(snap.resident_shapes <= snap.authored_shapes, id + " residency cannot duplicate shapes")
    for point in samples:
        streamed.update_collision_window(point, Vector2(8000, -6000), 0.25)
        _coverage(streamed, id + " high velocity swept window")
    streamed.warm_collision_focus(Vector2(-100000, -100000))
    _check(streamed.resident_collision_chunks.is_empty(), id + " all distant unpinned physics released")
    var far: Vector2 = streamed.solid_rects.back().get_center()
    streamed.ensure_collision_segment(far - Vector2(50, 0), far + Vector2(50, 0))
    _check(not streamed.resident_collision_chunks.is_empty(), id + " remote query acquires collision before ray")
    streamed.update_collision_window(focus, Vector2.ZERO, 0.0, true)
    for key in streamed.collision_pins:
        _check(streamed.resident_collision_chunks.has(key), id + " query pin prevents premature retirement")
    await _frames(4)
    streamed.update_collision_window(Vector2(-100000, -100000), Vector2.ZERO, 0.0, true)
    _check(streamed.collision_pins.is_empty() and streamed.resident_collision_chunks.is_empty(), id + " expired pins fully released")
    metrics.append({"region": id, "authored": initial.authored_shapes, "arrival": initial.resident_shapes, "chunks": initial.chunks, "peak": peak})
    host.free()
    await _frames(1)

func _coverage(cave: Node, label: String) -> void:
    for key in cave.collision_chunks:
        if cave.critical_bounds.intersects(cave.collision_chunks[key].bounds):
            _check(cave.resident_collision_chunks.has(key), label + " required chunk present")
    for key in cave.resident_collision_chunks:
        var body: StaticBody2D = cave.resident_collision_chunks[key]
        _check(body.collision_layer == 17 and body.collision_mask == 0, label + " terrain and sight bits unchanged")
        for shape in body.get_children():
            var index: int = shape.get_meta("authored_rock_index")
            var rect: Rect2 = cave.solid_rects[index]
            _check(shape.position == rect.get_center() and shape.shape.size == rect.size, label + " unsplit shape geometry unchanged")

func _offscreen_effects() -> void:
    var host := Host.new()
    root.add_child(host)
    var player := DummyPlayer.new()
    host.add_child(player)
    host.player = player
    player.add_to_group("player")
    var cave := CAVE.new()
    host.add_child(cave)
    host.cave_world = cave
    cave.configure({"cave_world": {"solid_rects": [[10000, -100, 60, 200]]}}, "moss_cavern", host, true, Vector2.ZERO)
    _check(cave.resident_collision_chunks.is_empty(), "offscreen effect fixture begins without remote rock")
    cave.ensure_collision_segment(Vector2(9950, 0), Vector2(10050, 0))
    print("IMMEDIATE_COLLISION_RAY visible=", not _ray(Vector2(9950, 0), Vector2(10050, 0)).is_empty())
    var effect := ATTACK.new()
    effect.position = Vector2(9950, 0)
    effect.velocity = Vector2(1000, 0)
    effect.duration = 5
    host.add_child(effect)
    effect._physics_process(0.1)
    _check(effect.is_queued_for_deletion(), "offscreen hostile projectile hits newly resident wall in same step")
    await _frames(2)
    var tool := TOOL.new()
    tool.payload = {"id": "needle", "duration": 5}
    tool.owner_player = player
    tool.position = Vector2(9950, 0)
    host.add_child(tool)
    cave.warm_collision_focus(Vector2.ZERO)
    tool._physics_process(0.2)
    _check(tool.is_queued_for_deletion() or tool.landed, "offscreen player tool cannot pass rock")
    await _frames(2)
    player.remove_from_group("player")
    var real_player: CharacterBody2D = load("res://scenes/Player.tscn").instantiate()
    real_player.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
    host.add_child(real_player)
    host.player = real_player
    real_player.position = Vector2(9950, 0)
    # Evict the remote fixture, reacquire it immediately before player motion,
    # and verify the actual controller holds that unsynchronized step.
    cave.collision_pins.clear()
    cave.warm_collision_focus(Vector2.ZERO)
    cave.warm_collision_focus(real_player.global_position)
    Input.action_press("move_right")
    var before: Vector2 = real_player.position
    real_player._physics_process(0.1)
    _check(real_player.position == before, "actual controller holds freshly acquired critical collision step")
    await _frames(1)
    real_player._physics_process(0.25)
    Input.action_release("move_right")
    _check(real_player.position.x < 10000 and real_player.position.x >= before.x, "actual controller collides after server synchronization")
    host.free()
    await _frames(2)

func _ray(from: Vector2, to: Vector2) -> Dictionary:
    var query := PhysicsRayQueryParameters2D.create(from, to, 16)
    query.collide_with_areas = false
    query.hit_from_inside = true
    return root.get_world_2d().direct_space_state.intersect_ray(query)

func _frames(count: int) -> void:
    for frame in range(count):
        await physics_frame
        await process_frame

func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures.append(message)
