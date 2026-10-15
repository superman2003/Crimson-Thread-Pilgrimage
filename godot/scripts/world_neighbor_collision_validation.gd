extends SceneTree
## Explicit landing-cache fixtures, not continuous crossing or natural play.
const GEOMETRY := preload("res://scripts/world_collision_geometry.gd")
const PREFETCH := preload("res://scripts/world_prefetch.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const COORDINATES := preload("res://scripts/world_coordinates.gd")
const SAVE := "user://world_neighbor_collision_validation.json"
const MASK := 1 << 21
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
    scene.world_save_path = SAVE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene = scene
    await _frames(2)
    _mixed_sections()
    _invalid_geometry()
    _complex_limits()
    for id in COORDINATES.manifest().regions:
        await _region(String(id))
    # Every authored cross-region landing, including the far-side shortcuts.
    # Fixture positioning does not bypass or count as natural gate traversal.
    for source_id in ROUTES._data().chapters:
        for portal in ROUTES._data().chapters[source_id].get("portals", []):
            var target := String(portal.get("target_config_id", ""))
            if target == String(source_id) or not COORDINATES.has_region(target):
                continue
            var value: Array = portal.target_spawn
            await _region(target, Vector2(value[0], value[1]))
    await _invalidation()
    print("NEIGHBOR COLLISION METRICS ", JSON.stringify(metrics))
    scene.free()
    scene = null
    current_scene = null
    await _frames(2)
    _clean()
    if failures.is_empty():
        print("WORLD NEIGHBOR COLLISION PASS: %d checks" % checks)
        quit(0)
    else:
        for message in failures:
            push_error(message)
        quit(1)

func _mixed_sections() -> void:
    var surface := [[0, 100], [100, 130], [200, 100]]
    var sections := GEOMETRY.terrain_sections(surface, 40, [[50, 150]])
    _check(sections.size() == 3, "mixed slope split at exact one-way boundaries")
    _check(sections[0].one_way == false and sections[1].one_way and not sections[2].one_way, "solid/one-way/solid roles preserved")
    _check(sections[1].polygon[0] == Vector2(50, 115) and sections[1].polygon[2] == Vector2(150, 115), "sloped cut points exact")
    var config := {"platforms": [{"terrain_id": "slope", "rect": [50, 115, 100, 20], "collision_role": "one_way"}, {"terrain_id": "slope", "rect": [0, 100, 50, 20]}]}
    _check(GEOMETRY.terrain_spans(config, "slope", surface) == [[50.0, 150.0]], "authored mixed platform spans retained")

func _invalid_geometry() -> void:
    var id := String(scene.config.id)
    var path := ROUTES.config_path(id)
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
    var point := Vector2(raw.player_start[0], raw.player_start[1])
    for value in [[], {"solid_rects": "bad"}, {"solid_rects": [[0, 0, -1, 4]]}, {"solid_rects": [[0, 0, INF, 4]]}, {"solid_rects": [[0, "bad", 4, 4]]}]:
        var invalid: Dictionary = raw.duplicate(true)
        invalid.cave_world = value
        _check(scene.world_loader.validate_config(invalid, path, point).is_empty(), "malformed rock rejected before allocation/unload")
    for value in [0, -1, "bad", INF]:
        var invalid: Dictionary = raw.duplicate(true)
        invalid.terrain[0].depth = value
        _check(scene.world_loader.validate_config(invalid, path, point).is_empty(), "invalid terrain depth rejected before allocation/unload")
    var duplicate: Dictionary = raw.duplicate(true)
    duplicate.terrain.append(duplicate.terrain[0].duplicate(true))
    _check(scene.world_loader.validate_config(duplicate, path, point).is_empty(), "duplicate terrain key rejected")

func _complex_limits() -> void:
    var pref := PREFETCH.new()
    var rects: Array = []
    for index in range(33):
        rects.append([0, 0, 5, 5])
    var surface: Array = []
    for index in range(129):
        surface.append([index, 10])
    var config := {"cave_world": {"solid_rects": rects}, "terrain": [{"id": "large", "surface": surface, "depth": 10}]}
    _check(pref._landing_plan(scene, config, Vector2.ZERO).is_empty(), "oversized rock chunks and polygons use active-arrival fallback")
    pref.shutdown()

func _seed(id: String, entry: Vector2) -> RefCounted:
    scene.world_prefetch.shutdown()
    var pref := PREFETCH.new()
    scene.world_prefetch = pref
    pref.generation = scene.world_loader.generation
    var path := ROUTES.config_path(id)
    var source_bytes := FileAccess.get_file_as_bytes(path)
    var raw: Dictionary = JSON.parse_string(source_bytes.get_string_from_utf8())
    var prepared: Dictionary = scene.world_loader.validate_config(raw, path, entry)
    _check(not prepared.is_empty(), id + " valid landing fixture")
    pref.desired[id] = {"path": path, "entry": entry, "distance": 0}
    pref.configs[id] = {"raw": raw, "prepared": prepared, "stamp": FileAccess.get_modified_time(path), "size": source_bytes.size()}
    return pref

func _warm(pref: RefCounted) -> void:
    for frame in range(100):
        var before: int = pref.entity_builds
        pref._warm_entities(scene, Time.get_ticks_usec())
        _check(pref.entity_builds - before <= 2 and pref.snapshot().owned_bodies <= 48, "combined geometry admission and ownership bounded")
        if pref.entities.values().all(func(record): return record.pending.is_empty()):
            return
        await process_frame
    _check(false, "geometry fixture warm deadline")

func _region(id: String, landing: Vector2 = Vector2.INF) -> void:
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROUTES.config_path(id)))
    var entry := landing if landing.is_finite() else Vector2(raw.player_start[0], raw.player_start[1])
    var pref := _seed(id, entry)
    var flags: Dictionary = scene.story_flags.duplicate(true)
    var inventory: Dictionary = scene.inventory_counts.duplicate(true)
    var tree_count := scene.get_child_count()
    await _warm(pref)
    var summary: Dictionary = pref.snapshot()
    _check(summary.rock_chunks > 0 and summary.terrain_polygons > 0, id + " landing has both rock and terrain caches")
    _check(summary.rock_chunks <= 6 and summary.terrain_polygons <= 6 and summary.entity_bodies <= 24, id + " category and regional limits")
    _check(scene.get_child_count() == tree_count and scene.story_flags == flags and scene.inventory_counts == inventory, id + " no neighbor gameplay or progression changes")
    var records: Dictionary = pref.entities[id].collisions.duplicate()
    for key in records:
        var record: Dictionary = records[key]
        var node: Node = record.body
        _check(node.get_parent() == null and not node.is_inside_tree(), id + " detached collision ownership")
        if String(key).begins_with("rock:"):
            var body: StaticBody2D = node
            body.collision_layer = MASK
            var rect: Rect2 = record.data.rects[0]
            var ray := PhysicsRayQueryParameters2D.create(rect.get_center() - Vector2(0, rect.size.y), rect.get_center() + Vector2(0, rect.size.y), MASK)
            _check(root.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(), id + " neighbor rock absent from source physics")
            body.collision_layer = 17
            _check(body.get_child_count() == record.data.rects.size() and body.get_child_count() <= 32, id + " shape count bounded")
        else:
            var polygon: CollisionPolygon2D = node
            _check(polygon.polygon == record.data.polygon and polygon.one_way_collision == record.data.one_way and polygon.one_way_collision_margin == 2, id + " detached polygon exact")
        var changed: Dictionary = record.data.duplicate(true)
        changed.bounds = changed.bounds.grow(1)
        var parts := String(key).split(":", true, 1)
        _check(pref.take_collision(id, parts[0], parts[1], changed) == null and is_instance_valid(node), id + " descriptor mismatch cannot consume cache")
    var player_id: int = scene.player.get_instance_id()
    scene._travel_world(ROUTES.config_path(id), entry)
    await _frames(2)
    _check(scene.player.get_instance_id() == player_id, id + " player persistent on real arrival")
    var rocks := 0
    var polygons := 0
    for key in records:
        var record: Dictionary = records[key]
        var node: Node = record.body
        if not is_instance_valid(node) or not node.is_inside_tree():
            continue
        if String(key).begins_with("rock:"):
            rocks += 1
            var chunk_key := String(key).trim_prefix("rock:")
            _check(scene.cave_world.resident_collision_chunks.get(chunk_key) == node and node.get_parent() == scene.cave_world.collision_root, id + " real arrival transfers original rock instance")
            _check(node.collision_layer == 17 and node.collision_mask == 0 and node.disable_mode == CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE, id + " rock physics and disabled-host semantics preserved")
            for offset in range(node.get_child_count()):
                var shape: CollisionShape2D = node.get_child(offset)
                _check(shape.position == record.data.rects[offset].get_center() and shape.shape.size == record.data.rects[offset].size, id + " rock geometry exact after transfer")
        else:
            polygons += 1
            _check(node in scene.chapter_terrain.resident_collisions.values() and node.get_parent().get_parent() == scene.chapter_terrain, id + " real arrival transfers original polygon instance")
            _check(node.polygon == record.data.polygon and node.one_way_collision == record.data.one_way, id + " terrain collision exact after transfer")
        _check(not pref.entities[id].collisions.has(key), id + " transferred node has no cache owner")
    _check(rocks > 0 and polygons > 0 and pref.rock_hits == rocks and pref.terrain_hits == polygons, id + " both arrival cache types actually adopted")
    metrics.append({"region": id, "entry": [entry.x, entry.y], "cached_rocks": summary.rock_chunks, "cached_polygons": summary.terrain_polygons, "adopted_rocks": rocks, "adopted_polygons": polygons})
    pref.shutdown()
    _check(pref.snapshot().owned_bodies == 0, id + " shutdown drains detached ownership")
    for key in records:
        var node: Node = records[key].body
        _check(not is_instance_valid(node) or node.is_inside_tree(), id + " only transferred nodes survive shutdown")

func _invalidation() -> void:
    var id := "demo_ch02_rain_foundry_canal"
    var pref := _seed(id, Vector2(200, 720))
    await _warm(pref)
    var key: String = pref.entities[id].collisions.keys()[0]
    var record: Dictionary = pref.entities[id].collisions[key]
    var parts := key.split(":", true, 1)
    pref.configs[id].stamp = -1
    _check(pref.take_collision(id, parts[0], parts[1], record.data) == null and pref.entities.is_empty(), "timestamp lease rejects entire stale geometry cache")
    pref.desired.clear()
    await _drain(pref)
    _check(not is_instance_valid(record.body), "timestamp-invalid collision retires")
    pref = _seed(id, Vector2(200, 720))
    await _warm(pref)
    var old: Array = []
    for value in pref.entities[id].collisions.values():
        old.append(value.body)
    pref.desired.clear()
    scene.player.global_position = Vector2(-100000, -100000)
    scene.world_loader.generation += 1
    var before: int = pref.entity_releases
    pref.step(scene, 1)
    _check(pref.entities.is_empty() and pref.entity_releases - before <= 2, "generation invalidates synchronously but retires across frames")
    await _drain(pref)
    _check(old.all(func(node): return not is_instance_valid(node)), "generation retires every untransferred geometry node")
    pref.shutdown()

func _drain(pref: RefCounted) -> void:
    for frame in range(100):
        if pref.retiring.is_empty():
            return
        var before: int = pref.entity_releases
        pref._retire_entities(Time.get_ticks_usec())
        _check(pref.entity_releases - before <= 2 and pref.snapshot().owned_bodies <= 48, "combined geometry retirement bounded")
        await process_frame
    _check(false, "geometry retirement deadline")

func _frames(count: int) -> void:
    for i in range(count):
        await physics_frame
        await process_frame

func _clean() -> void:
    for suffix in ["", ".bak", ".tmp"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))

func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures.append(message)
