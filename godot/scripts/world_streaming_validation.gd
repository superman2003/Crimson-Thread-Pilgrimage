extends SceneTree
## Graphics/configuration fixtures. Collisions stay fully resident by contract.
const TERRAIN := preload("res://scripts/chapter_terrain.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const COORDINATES := preload("res://scripts/world_coordinates.gd")
const STATE := preload("res://scripts/world_state.gd")
const PATH := "user://world_streaming_validation.json"
var checks := 0
var failures: Array[String] = []
var metrics: Array = []
var scene: Node

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    root.process_mode = Node.PROCESS_MODE_DISABLED
    for region_id in COORDINATES.manifest().regions:
        _terrain_checks(region_id)
    await _prefetch_checks()
    for suffix in ["", ".bak", ".tmp"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + suffix))
    if failures.is_empty():
        print("WORLD STREAMING PASS: %d checks; six-region visual coverage, unchanged collisions, bounded prefetch and stale-job retirement" % checks)
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)

func _terrain_checks(region_id: String) -> void:
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROUTES.config_path(region_id)))
    var config := ROUTES.apply_to(raw)
    var theme := String(config.art_theme)
    var reference := TERRAIN.new()
    root.add_child(reference)
    reference.configure(config, theme)
    var streamed := TERRAIN.new()
    root.add_child(streamed)
    var entry: Array = config.player_start
    var focus := Vector2(entry[0], entry[1])
    streamed.configure(config, theme, true, focus)
    _check(streamed.collision_regions == reference.collision_regions, region_id + " collision polygons identical")
    var collision_count := _collision_count(streamed)
    _check(collision_count == _collision_count(reference), region_id + " collision shape count identical")
    _check(streamed.walk_distance == reference.walk_distance and streamed.ramp_count == reference.ramp_count, region_id + " walkable statistics unchanged")
    var native_faces: Dictionary = {}
    var native_count := 0
    for body in reference.get_children():
        for face in body.get_children():
            if face is Polygon2D and not face.has_meta("independent_edge_art"):
                var signature := _signature(face.polygon)
                native_faces[signature] = int(native_faces.get(signature, 0)) + 1
                native_count += 1
    var described_faces := 0
    for record in streamed.visual_chunks.values():
        for points in record.faces:
            described_faces += 1
            # The authored floor rim covers the first strip of the stratum.
            # Compare the actual stone plane; rims are checked separately below.
            var stone: PackedVector2Array = points.duplicate()
            var inset := minf(12, (points[3].y - points[0].y) * 0.25)
            stone[0] += Vector2(0, inset)
            stone[1] += Vector2(0, inset)
            var signature := _signature(stone)
            _check(int(native_faces.get(signature, 0)) > 0, region_id + " chunk preserves native face geometry")
            native_faces[signature] = int(native_faces.get(signature, 0)) - 1
    _check(described_faces == native_count and native_faces.values().all(func(count): return count == 0), region_id + " no missing or duplicated source faces")
    var initial: Dictionary = streamed.streaming_snapshot()
    _check(initial.resident_faces < initial.faces, region_id + " arrival avoids building distant faces")
    var first_resident: int = initial.resident_faces
    var checked_chunks: Dictionary = {}
    # Sweep every real chunk, including edge/corner crossings and return trips.
    for key in streamed.visual_chunks:
        var center: Vector2 = streamed.visual_chunks[key].bounds.get_center()
        var view := Rect2(center - Vector2(640, 360), Vector2(1280, 720))
        streamed.refresh_visual_chunks(view, true)
        for resident in streamed.resident_chunks:
            if checked_chunks.has(resident): continue
            checked_chunks[resident] = true
            var chunk: Node = streamed.resident_chunks[resident]
            var stone_count := 0
            var rim_count := 0
            for face in chunk.get_children():
                if not face is Polygon2D: continue
                if face.has_meta("independent_edge_art"):
                    rim_count += 1
                    _check(String(face.get_meta("independent_edge_art")) == "floor", region_id + " streamed face retains floor rim")
                else:
                    stone_count += 1
            _check(stone_count == streamed.visual_chunks[resident].faces.size() and rim_count == stone_count, region_id + " each streamed stratum retains one independent rim")
        for candidate in streamed.visual_chunks:
            var record: Dictionary = streamed.visual_chunks[candidate]
            if view.intersects(record.bounds):
                _check(streamed.resident_chunks.has(candidate), region_id + " viewport coverage " + candidate)
        for resident in streamed.resident_chunks:
            _check(view.grow(streamed.KEEP_MARGIN).intersects(streamed.visual_chunks[resident].bounds), region_id + " residency respects hysteresis bounds")
        _check(_collision_count(streamed) == collision_count, region_id + " camera sweep cannot unload collision")
    _check(checked_chunks.size() == streamed.visual_chunks.size(), region_id + " every authored chunk examined")
    var view_offworld := Rect2(Vector2(-50000, -50000), Vector2(1280, 720))
    streamed.refresh_visual_chunks(view_offworld, true)
    _check(streamed.resident_chunks.is_empty(), region_id + " distant visuals released")
    _check(_collision_count(streamed) == collision_count, region_id + " offscreen terrain remains solid")
    var load_before: int = streamed.streamed_loads
    streamed.refresh_visual_chunks(Rect2(focus - Vector2(640, 360), Vector2(1280, 720)))
    _check(streamed.streamed_loads - load_before <= 2, region_id + " frame admits at most two new chunks")
    streamed.warm_focus(focus)
    _check(not streamed.resident_chunks.is_empty(), region_id + " respawn rewarms arrival geometry")
    metrics.append({"region": region_id, "faces": initial.faces, "arrival_faces": first_resident,
        "chunks": initial.chunks, "collision_shapes": collision_count, "released": streamed.streamed_releases})
    print("WORLD STREAMING REGION " + JSON.stringify(metrics[-1]))
    reference.free()
    streamed.free()

func _prefetch_checks() -> void:
    scene = load("res://scenes/World.tscn").instantiate()
    scene.world_resume = false
    scene.world_save_path = PATH
    root.add_child(scene)
    current_scene = scene
    await process_frame
    var host_id := scene.get_instance_id()
    var player_id: int = scene.player.get_instance_id()
    var prefetch_id: int = scene.world_prefetch.get_instance_id()
    var source := String(scene.config.id)
    var rain: Node2D = scene.get_node("moss_rain_pipe")
    var archive: Node2D = scene.get_node("moss_archive_return")
    scene.player.global_position = (rain.global_position + archive.global_position) * 0.5
    var journal: Dictionary = scene.story_flags.duplicate(true)
    var inventory: Dictionary = scene.inventory_counts.duplicate(true)
    var nodes := scene.get_child_count()
    var max_reads := 0
    var deadline := Time.get_ticks_msec() + 8000
    while Time.get_ticks_msec() < deadline:
        var before: int = scene.world_prefetch.config_reads
        scene.world_prefetch.step(scene, 1.0 / 60)
        max_reads = maxi(max_reads, scene.world_prefetch.config_reads - before)
        var status: Dictionary = scene.world_prefetch.snapshot()
        if status.regions == 2 and status.jobs == 0 and status.queued == 0 and status.textures == 10:
            break
        await process_frame
    var status: Dictionary = scene.world_prefetch.snapshot()
    _check(status.regions == 2 and status.textures == 10 and status.failures == 0, "two neighboring themes warmed successfully")
    _check(status.jobs <= 2 and status.max_jobs <= 2 and max_reads <= 1, "bounded worker jobs and config reads")
    _check(scene.get_child_count() == nodes and String(scene.config.id) == source, "prefetch does not attach neighbor nodes to active tree")
    _check(scene.story_flags == journal and scene.inventory_counts == inventory, "prefetch cannot grant maps, journals or abilities")
    var original_portals: Array = scene.config.interactives.duplicate(true)
    scene.config.interactives.append({"kind": "world_portal", "target_config_id": "unknown_prefetch_region", "position": [scene.player.position.x, scene.player.position.y]})
    scene.world_prefetch.step(scene, 0.25)
    _check(not scene.world_prefetch.desired.has("unknown_prefetch_region"), "unknown portal target cannot displace valid warm regions")
    _check(scene.world_prefetch.failures == 0, "unknown target cannot start invalid file/resource loads")
    scene.config.interactives = original_portals
    var target := "demo_ch03_saltwhite_archive"
    var path := ROUTES.config_path(target)
    var detached: Dictionary = scene.world_prefetch.cached_raw(path)
    _check(not detached.is_empty(), "nearby archive has cached raw configuration")
    if not detached.is_empty():
        detached.map_rooms.clear()
        var intact: Dictionary = scene.world_prefetch.cached_raw(path)
        _check(not intact.map_rooms.is_empty(), "configuration cache is detached from callers")
    var hits: int = scene.world_prefetch.cache_hits
    var data: Dictionary = archive.get_meta("world_portal_data")
    var point: Array = data.target_spawn
    _check(not scene.world_loader.preflight(path, Vector2(point[0], point[1]), scene.world_prefetch).is_empty(), "entry validation consumes cached config")
    _check(scene.world_prefetch.cache_hits > hits, "preflight is a real warm-cache hit")
    scene._activate_world_portal(archive)
    _check(String(scene.config.id) == source and not scene.chapter_transitioning, "warm cache cannot bypass missing jump ability")
    scene._travel_world(path, Vector2(point[0], point[1]))
    await process_frame
    await process_frame
    _check(scene.get_instance_id() == host_id and scene.player.get_instance_id() == player_id and scene.world_prefetch.get_instance_id() == prefetch_id, "prefetch survives ordinary region handoff")
    _check(scene.config.map_rooms.size() == ROUTES.apply_to(JSON.parse_string(FileAccess.get_file_as_string(path))).map_rooms.size(), "cached raw config is not overlaid twice")
    scene.world_prefetch.step(scene, 1.0 / 60)
    _check(scene.world_prefetch.generation == scene.world_loader.generation and not scene.world_prefetch.configs.has(target), "arrival invalidates old source-generation cache")
    # Transition with one outstanding job to prove stale completions are drained.
    deadline = Time.get_ticks_msec() + 2000
    while scene.world_prefetch.jobs.is_empty() and Time.get_ticks_msec() < deadline:
        scene.world_prefetch.step(scene, 1.0 / 60)
        await process_frame
    _check(not scene.world_prefetch.jobs.is_empty(), "stale-completion fixture has an outstanding request")
    scene._travel_world(ROUTES.config_path(source), Vector2(280, 3360))
    await process_frame
    scene.world_prefetch.step(scene, 1.0 / 60)
    _check(scene.world_prefetch.snapshot().regions <= 2 and scene.world_prefetch.snapshot().textures <= 10, "retained warm cache bounded after return")
    _check(scene.world_prefetch.stale_results > 0, "departed-generation texture completion discarded")
    scene.player.global_position = Vector2(8000, 6000)
    for unused in range(80):
        scene.world_prefetch.step(scene, 1.0 / 60)
        await process_frame
    _check(scene.world_prefetch.configs.is_empty() and scene.world_prefetch.retained.is_empty() and scene.world_prefetch.queue.is_empty(), "leaving portal neighborhood releases cache ownership")
    scene.world_prefetch.shutdown()
    _check(scene.world_prefetch.jobs.is_empty(), "journey shutdown drains worker requests")
    print("WORLD PREFETCH METRICS " + JSON.stringify(scene.world_prefetch.snapshot()))
    scene.queue_free()
    await process_frame
    await process_frame

func _signature(points: PackedVector2Array) -> String:
    return str(points)

func _collision_count(terrain: Node) -> int:
    var count := 0
    for body in terrain.get_children():
        for child in body.get_children():
            if child is CollisionPolygon2D:
                count += 1
    return count

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)
        print("WORLD STREAMING FAILED: " + label)
