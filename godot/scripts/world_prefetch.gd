extends RefCounted
const COORDINATES := preload("res://scripts/world_coordinates.gd")
## Bounded detached landing geometry. Neighbors never enter source physics.
const GEOMETRY := preload("res://scripts/world_collision_geometry.gd")
const MAX_PLATFORMS := 12
const MAX_ROCK_CHUNKS := 6
const MAX_TERRAIN_POLYGONS := 6
const MAX_ROCK_SHAPES := 32
const MAX_POLYGON_POINTS := 256
const GAMEPLAY := preload("res://scripts/world_gameplay_prefetch.gd")
const CONFIG_VALIDATOR := preload("res://scripts/world_config_validator.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const MAX_CONFIG_OPERATIONS := 8
var gameplay := GAMEPLAY.new()
var rock_hits := 0
var terrain_hits := 0

const BODY := preload("res://scripts/world_platform_body.gd")
const MAX_BODIES_PER_REGION := 24
const LANDING_HALF := Vector2(1280, 900)
var entities: Dictionary = {}
var retiring: Array[Node] = []
var entity_builds := 0
var entity_hits := 0
var entity_releases := 0
var max_entities := 0
const RADIUS := 1400.0
const MAX_REGIONS := 2
const MAX_JOBS := 2
const BUDGET_US := 2000
const TEXTURES := ["rock_mass_large.png", "background.png", "platform_atlas.png", "decor_atlas.png", "terrain_atlas.png"]
var desired: Dictionary = {}
var configs: Dictionary = {}
var retained: Dictionary = {}
var jobs: Array[Dictionary] = []
var queue: Array[Dictionary] = []
var paths: Dictionary = {}
var generation := -1
var selection_elapsed := 1.0
var config_reads := 0
var cache_hits := 0
var failures := 0
var stale_results := 0
var max_jobs_seen := 0
var config_task: Dictionary = {}
var config_validator: RefCounted
var config_raw: Variant
var config_cancellations := 0
var config_entry_rechecks := 0
var config_validation_steps := 0
var config_validation_batches := 0
var last_config_operations := 0
var max_config_operations := 0
var max_config_step_usec := 0
var config_operation_usec: Dictionary = {}
var config_worker_usec := 0
var config_bytes := 0
var config_worker_is_main := true
var route_cache_generation := -2
var route_cache_seen := false

func step(host: Node, delta: float) -> void:
    last_config_operations = 0
    if not is_instance_valid(host.player):
        return
    var current_route_generation := ROUTES.cached_generation()
    if current_route_generation < 0:
        if route_cache_seen and route_cache_generation != -2:
            cancel_config()
            _clear_entities()
            configs.clear()
            retained.clear()
            paths.clear()
            route_cache_generation = -2
        if host.world_loader != null and host.world_loader.has_method("request_manifest_refresh"):
            host.world_loader.request_manifest_refresh(host)
    elif not route_cache_seen:
        # The first cache publication must not invalidate a caller's current
        # desired lease; fixtures and startup can seed it before this first
        # process poll. Only a later generation change requires reselection.
        route_cache_seen = true
        route_cache_generation = current_route_generation
    elif route_cache_generation != current_route_generation:
        cancel_config()
        _clear_entities()
        configs.clear()
        retained.clear()
        paths.clear()
        route_cache_generation = current_route_generation
        selection_elapsed = 1.0
    var started := Time.get_ticks_usec()
    if generation != host.world_loader.generation:
        cancel_config()
        generation = host.world_loader.generation
        _clear_entities()
        desired.clear()
        configs.clear()
        retained.clear()
        queue.clear()
        selection_elapsed = 1.0
    selection_elapsed += maxf(delta, 0)
    if selection_elapsed >= 0.25:
        selection_elapsed = 0
        _select(host)
    _invalidate_configs()
    if not config_task.is_empty() and not _config_task_current():
        cancel_config()
    gameplay.synchronize(desired, configs, generation)
    var retired := _retire_entities(started)
    gameplay.retire(started, 2 - retired)
    # Never block on load_threaded_get until its status is LOADED/FAILED.
    for index in range(jobs.size() - 1, -1, -1):
        var job := jobs[index]
        var status := ResourceLoader.load_threaded_get_status(job.path)
        if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
            continue
        if status == ResourceLoader.THREAD_LOAD_LOADED:
            var texture := ResourceLoader.load_threaded_get(job.path) as Texture2D
            if job.generation == generation and desired.has(job.region) and configs.has(job.region) and job.get("stamp", -1) == configs[job.region].stamp and texture != null:
                if not retained.has(job.region):
                    retained[job.region] = {}
                retained[job.region][job.path] = texture
            else:
                stale_results += 1
        else:
            failures += 1
        jobs.remove_at(index)
        if Time.get_ticks_usec() - started >= BUDGET_US:
            return
    if Time.get_ticks_usec() - started >= BUDGET_US:
        return
    _step_config(host, started)
    # Admission budget, not a guarantee that one engine operation takes <2ms.
    if not queue.is_empty() and jobs.size() < MAX_JOBS and Time.get_ticks_usec() - started < BUDGET_US:
        var job: Dictionary = queue.pop_front()
        var duplicate := false
        for active in jobs:
            if active.path == job.path:
                duplicate = true
                break
        if duplicate:
            queue.append(job)
        elif not ResourceLoader.exists(job.path):
            failures += 1
        elif ResourceLoader.load_threaded_request(job.path, "Texture2D") == OK:
            jobs.append(job)
            max_jobs_seen = maxi(max_jobs_seen, jobs.size())
        else:
            failures += 1
    if Time.get_ticks_usec() - started < BUDGET_US:
        gameplay.synchronize(desired, configs, generation)
        var built := _warm_entities(host, started)
        gameplay.warm(host, started, 2 - built)

func _invalidate_configs() -> void:
    for region_id in configs.keys():
        var current := desired.has(region_id)
        if current:
            var candidate: Dictionary = desired[region_id]
            var record: Dictionary = configs[region_id]
            current = record.stamp == FileAccess.get_modified_time(candidate.path) and record.get("path", candidate.path) == candidate.path
            if current and record.get("entry", candidate.entry) != candidate.entry:
                # Keep a fully validated region configuration across entrance
                # changes. Detached geometry/gameplay have their own entry
                # leases and still retire/rebuild below. A failed record has
                # no validated world and must retry for the new entrance.
                current = not record.raw.is_empty() and record.has("prepared") and CONFIG_VALIDATOR.entry_in_bounds(candidate.entry, record.prepared.world)
                if current:
                    record["entry"] = candidate.entry
                    config_entry_rechecks += 1
        if current:
            continue
        _release_entities(region_id)
        configs.erase(region_id)
        retained.erase(region_id)
        for index in range(queue.size() - 1, -1, -1):
            if queue[index].region == region_id:
                queue.remove_at(index)

func _config_task_current() -> bool:
    if config_task.is_empty() or config_task.generation != generation or not desired.has(config_task.region):
        return false
    var candidate: Dictionary = desired[config_task.region]
    return candidate.path == config_task.path and candidate.entry == config_task.entry and config_task.stamp == FileAccess.get_modified_time(config_task.path)

func cancel_config() -> void:
    if not config_task.is_empty():
        # The loader owns and drains the shared reader. Discard never joins a
        # running thread, and cannot erase a newer foreground ticket.
        config_task.reader.discard(config_task.ticket)
        config_cancellations += 1
    config_task = {}
    config_validator = null
    config_raw = null

func _step_config(host: Node, started: int) -> void:
    if host.world_loader.phase != "idle" or host.world_loader.shutting_down:
        cancel_config()
        return
    if config_task.is_empty():
        var reader: RefCounted = host.world_loader.config_read_job
        if reader.busy():
            return
        for region_id in desired:
            if configs.has(region_id):
                continue
            var candidate: Dictionary = desired[region_id]
            var ticket: int = reader.request(candidate.path)
            if ticket == 0:
                return
            config_task = {"region": region_id, "path": candidate.path, "entry": candidate.entry,
                "stamp": FileAccess.get_modified_time(candidate.path), "generation": generation,
                "reader": reader, "ticket": ticket}
            config_reads += 1
            # Even an already completed tiny read is observed on a later frame.
            return
        return
    if config_validator == null:
        if config_task.reader.busy():
            return
        var read: Dictionary = config_task.reader.take(config_task.ticket)
        config_worker_usec += int(read.get("worker_usec", 0))
        config_bytes += int(read.get("bytes", 0))
        config_worker_is_main = bool(read.get("worker_is_main", true))
        if not String(read.get("error", "失效票据")).is_empty():
            _publish_config({})
            return
        if int(read.get("stamp", -1)) != config_task.stamp:
            cancel_config()
            return
        config_task["size"] = int(read.get("bytes", -1))
        config_raw = read.get("raw")
        config_validator = CONFIG_VALIDATOR.new()
        config_validator.begin(config_raw, config_task.path, config_task.entry)
    # This is an admission budget shared with retirement, textures and prefab
    # warming. A validator step (including route overlay) is not preemptible.
    while not config_validator.done and last_config_operations < MAX_CONFIG_OPERATIONS and Time.get_ticks_usec() - started < BUDGET_US:
        var step_started := Time.get_ticks_usec()
        config_validator.step()
        var elapsed := Time.get_ticks_usec() - step_started
        var operation := String(config_validator.operation_name)
        config_operation_usec[operation] = int(config_operation_usec.get(operation, 0)) + elapsed
        max_config_step_usec = maxi(max_config_step_usec, elapsed)
        last_config_operations += 1
        config_validation_steps += 1
    if last_config_operations > 0:
        config_validation_batches += 1
        max_config_operations = maxi(max_config_operations, last_config_operations)
    if config_validator.done:
        _publish_config(config_validator.result)

func _publish_config(prepared: Dictionary) -> void:
    if not _config_task_current():
        cancel_config()
        return
    var region_id := String(config_task.region)
    var record := {"raw": {}, "stamp": config_task.stamp, "size": config_task.get("size", -1), "path": config_task.path, "entry": config_task.entry}
    if prepared.is_empty():
        failures += 1
    else:
        record.raw = config_raw
        record["prepared"] = prepared
        var theme := String(config_raw.get("art_theme", ""))
        if theme == "moss_bell":
            theme = "moss_cavern"
        for filename in TEXTURES:
            queue.append({"region": region_id, "path": "res://assets/sprites/flat_maps/%s/%s" % [theme, filename], "generation": generation, "stamp": record.stamp})
    configs[region_id] = record
    config_task = {}
    config_validator = null
    config_raw = null

func _release_entities(region_id: String) -> void:
    if not entities.has(region_id):
        return
    for category in ["bodies", "collisions"]:
        for record in entities[region_id][category].values():
            var body: Node = record.body
            if is_instance_valid(body):
                retiring.append(body)
    entities.erase(region_id)

func _retire_entities(started: int, eager: bool = false) -> int:
    var removed := 0
    while not retiring.is_empty():
        if not eager and (removed >= 2 or (removed > 0 and Time.get_ticks_usec() - started >= BUDGET_US)):
            return removed
        var body: Node = retiring.pop_front()
        if is_instance_valid(body):
            body.free()
            entity_releases += 1
        removed += 1
    return removed

func _clear_entities() -> void:
    for region_id in entities.keys():
        _release_entities(region_id)

func _warm_entities(host: Node, started: int) -> int:
    var built := 0
    for region_id in desired:
        if not configs.has(region_id) or configs[region_id].raw.is_empty():
            continue
        var candidate: Dictionary = desired[region_id]
        if entities.has(region_id) and entities[region_id].entry != candidate.entry:
            _release_entities(region_id)
        if not entities.has(region_id):
            entities[region_id] = {"entry": candidate.entry,
                "pending": _landing_plan(host, configs[region_id].prepared, candidate.entry),
                "bodies": {}, "collisions": {}}
        var record: Dictionary = entities[region_id]
        while not record.pending.is_empty():
            if built >= 2 or Time.get_ticks_usec() - started >= BUDGET_US or _entity_count() + retiring.size() >= MAX_REGIONS * MAX_BODIES_PER_REGION:
                return built
            var job: Dictionary = record.pending.pop_front()
            var data: Dictionary = job.data
            var body: Node
            if job.kind == "platform":
                var rect: Array = data.rect
                body = BODY.create(String(data.id), Rect2(rect[0], rect[1], rect[2], rect[3]), String(data.get("collision_role", "")))
                record.bodies[job.key] = {"body": body, "data": data}
            else:
                body = GEOMETRY.rock_body(job.key, data) if job.kind == "rock" else GEOMETRY.terrain_polygon(data)
                record.collisions[job.kind + ":" + job.key] = {"body": body, "data": data}
            entity_builds += 1
            built += 1
            max_entities = maxi(max_entities, _entity_count() + retiring.size())
    return built

func _entity_count() -> int:
    var count := 0
    for record in entities.values():
        count += record.bodies.size() + record.collisions.size()
    return count

func _landing_plan(host: Node, config: Dictionary, entry: Vector2) -> Array:
    var bounds := Rect2(entry - LANDING_HALF, LANDING_HALF * 2)
    var platforms: Array = []
    var rocks: Array = []
    var terrain: Array = []
    for data in config.get("platforms", []):
        if data.has("terrain_id") or host._is_post_boss_blocker(String(data.id)):
            continue
        var value: Array = data.rect
        var rect := Rect2(value[0], value[1], value[2], value[3])
        if bounds.intersects(rect):
            platforms.append({"kind": "platform", "key": String(data.id), "data": data.duplicate(true), "bounds": rect})
    var chunks := GEOMETRY.rock_chunks(config.get("cave_world", {}).get("solid_rects", []))
    for key in chunks:
        var data: Dictionary = chunks[key]
        if bounds.intersects(data.bounds) and data.indices.size() <= MAX_ROCK_SHAPES:
            rocks.append({"kind": "rock", "key": key, "data": data, "bounds": data.bounds})
    for landform in config.get("terrain", []):
        var surface: Array = landform.get("surface", [])
        var id := String(landform.get("id", "Ground"))
        var spans := GEOMETRY.terrain_spans(config, id, surface)
        var sections := GEOMETRY.terrain_sections(surface, float(landform.get("depth", 104)), spans)
        for index in range(sections.size()):
            var data: Dictionary = sections[index]
            if bounds.intersects(data.bounds) and data.polygon.size() <= MAX_POLYGON_POINTS:
                terrain.append({"kind": "terrain", "key": "%s:%d" % [id, index], "data": data, "bounds": data.bounds})
    var groups := [platforms, rocks, terrain]
    var limits := [MAX_PLATFORMS, MAX_ROCK_CHUNKS, MAX_TERRAIN_POLYGONS]
    var pending: Array = []
    for index in range(groups.size()):
        var group: Array = groups[index]
        group.sort_custom(func(a, b): return a.bounds.get_center().distance_squared_to(entry) < b.bounds.get_center().distance_squared_to(entry))
        group.resize(mini(group.size(), limits[index]))
        pending.append_array(group)
    pending.sort_custom(func(a, b): return a.bounds.get_center().distance_squared_to(entry) < b.bounds.get_center().distance_squared_to(entry))
    return pending

## Exact geometry and timestamp lease; transfer removes all cache ownership.
func take_collision(region_id: String, kind: String, key: String, data: Dictionary) -> Node:
    if not entities.has(region_id) or not desired.has(region_id) or not configs.has(region_id):
        return null
    if configs[region_id].stamp != FileAccess.get_modified_time(desired[region_id].path):
        _release_entities(region_id)
        return null
    var cache_key := kind + ":" + key
    if not entities[region_id].collisions.has(cache_key):
        return null
    var record: Dictionary = entities[region_id].collisions[cache_key]
    if record.data != data:
        return null
    entities[region_id].collisions.erase(cache_key)
    if kind == "rock":
        rock_hits += 1
    else:
        terrain_hits += 1
    return record.body

## Transfer ownership only to an already validated target's exact descriptor.
func take_platform(region_id: String, data: Dictionary) -> StaticBody2D:
    if not entities.has(region_id) or not desired.has(region_id) or not configs.has(region_id):
        return null
    if configs[region_id].stamp != FileAccess.get_modified_time(desired[region_id].path):
        _release_entities(region_id)
        return null
    var id := String(data.get("id", ""))
    if not entities[region_id].bodies.has(id):
        return null
    var record: Dictionary = entities[region_id].bodies[id]
    if record.data != data:
        return null
    entities[region_id].bodies.erase(id)
    entity_hits += 1
    return record.body

func _select(host: Node) -> void:
    var nearest: Dictionary = {}
    for portal in host.config.get("interactives", []):
        if String(portal.get("kind", "")) != "world_portal":
            continue
        var region_id := String(portal.get("target_config_id", ""))
        if region_id == String(host.config.id) or not COORDINATES.has_region(region_id):
            continue
        var point: Array = portal.get("position", [0, 0])
        var distance: float = host.player.global_position.distance_to(Vector2(point[0], point[1]))
        if distance > RADIUS or (nearest.has(region_id) and float(nearest[region_id].distance) <= distance):
            continue
        var entry: Array = portal.get("target_spawn", [0, 0])
        if not paths.has(region_id):
            paths[region_id] = host.WORLD_ROUTES_SCRIPT.cached_config_path(region_id)
        if String(paths[region_id]).is_empty():
            if host.world_loader != null and host.world_loader.has_method("request_manifest_refresh"):
                host.world_loader.request_manifest_refresh(host)
            continue
        nearest[region_id] = {"path": paths[region_id], "entry": Vector2(entry[0], entry[1]), "distance": distance}
    var ids: Array = nearest.keys()
    ids.sort_custom(func(a, b): return float(nearest[a].distance) < float(nearest[b].distance))
    var next: Dictionary = {}
    for index in mini(ids.size(), MAX_REGIONS):
        next[ids[index]] = nearest[ids[index]]
    desired = next
    for region_id in configs.keys():
        if not desired.has(region_id):
            configs.erase(region_id)
            retained.erase(region_id)
            _release_entities(region_id)
    for index in range(queue.size() - 1, -1, -1):
        if not desired.has(queue[index].region):
            queue.remove_at(index)

func cached_raw(path: String) -> Variant:
    var raw: Variant = _cached_raw_borrow(path)
    return raw.duplicate(true) if raw != null else null

## Loader-only lease: treat this Variant as immutable and copy it incrementally.
## Public cache access always returns detached caller-owned data.
func _cached_raw_borrow(path: String) -> Variant:
    for region_id in configs:
        var record: Dictionary = configs[region_id]
        if not desired.has(region_id) or desired[region_id].path != path:
            continue
        if record.stamp != FileAccess.get_modified_time(path) or record.raw.is_empty():
            return null
        # A cached body belongs to its original read, not a newly observed file
        # of equal second-resolution mtime. Legacy records must reread safely.
        var file := FileAccess.open(path, FileAccess.READ)
        if file == null: return null
        var size := file.get_length()
        file.close()
        if int(record.get("size", -1)) != size: return null
        cache_hits += 1
        return record.raw
    return null

func snapshot() -> Dictionary:
    var rocks := 0
    var polygons := 0
    for region in entities.values():
        for key in region.collisions:
            if String(key).begins_with("rock:"):
                rocks += 1
            else:
                polygons += 1
    var count := 0
    for textures in retained.values():
        count += textures.size()
    return {"gameplay": gameplay.snapshot(), "rock_chunks": rocks, "terrain_polygons": polygons, "rock_hits": rock_hits, "terrain_hits": terrain_hits, "retiring_bodies": retiring.size(), "owned_bodies": _entity_count() + retiring.size(), "entity_regions": entities.size(), "entity_bodies": _entity_count(), "entity_builds": entity_builds, "entity_hits": entity_hits, "entity_releases": entity_releases, "max_entities": max_entities,
        "config_pending": not config_task.is_empty(), "config_phase": "idle" if config_task.is_empty() else ("reading" if config_validator == null else "validating"),
        "config_cancellations": config_cancellations, "config_entry_rechecks": config_entry_rechecks, "config_validation_steps": config_validation_steps, "config_validation_batches": config_validation_batches,
        "last_config_operations": last_config_operations, "max_config_operations": max_config_operations, "max_config_step_usec": max_config_step_usec,
        "config_operation_usec": config_operation_usec.duplicate(), "config_worker_usec": config_worker_usec, "config_bytes": config_bytes, "config_worker_is_main": config_worker_is_main,
        "regions": configs.size(), "textures": count, "jobs": jobs.size(), "queued": queue.size(),
        "config_reads": config_reads, "cache_hits": cache_hits, "failures": failures,
        "stale_results": stale_results, "max_jobs": max_jobs_seen, "generation": generation}

func shutdown() -> void:
    cancel_config()
    # Only whole-journey teardown may wait for the <=2 outstanding jobs.
    # Godot has no threaded-load cancellation; drain requests to release them.
    for job in jobs:
        if ResourceLoader.load_threaded_get_status(job.path) in [ResourceLoader.THREAD_LOAD_IN_PROGRESS, ResourceLoader.THREAD_LOAD_LOADED]:
            ResourceLoader.load_threaded_get(job.path)
    _clear_entities()
    _retire_entities(Time.get_ticks_usec(), true)
    gameplay.shutdown()
    jobs.clear()
    queue.clear()
    configs.clear()
    retained.clear()
    desired.clear()
    paths.clear()
