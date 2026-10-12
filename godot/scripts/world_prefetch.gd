extends RefCounted
const COORDINATES := preload("res://scripts/world_coordinates.gd")
## Bounded resources and detached ordinary platform bodies; no neighbor gameplay.
const BODY := preload("res://scripts/world_platform_body.gd")
const MAX_BODIES_PER_REGION := 24
const LANDING_HALF := Vector2(1280, 900)
var entities: Dictionary = {}
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

func step(host: Node, delta: float) -> void:
    if not is_instance_valid(host.player):
        return
    var started := Time.get_ticks_usec()
    if generation != host.world_loader.generation:
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
    # One JSON read at most per frame; an individual read cannot be preempted.
    for region_id in desired:
        var candidate: Dictionary = desired[region_id]
        if configs.has(region_id):
            if configs[region_id].stamp == FileAccess.get_modified_time(candidate.path):
                continue
            _release_entities(region_id)
            configs.erase(region_id)
            retained.erase(region_id)
            for index in range(queue.size() - 1, -1, -1):
                if queue[index].region == region_id:
                    queue.remove_at(index)
        var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(candidate.path))
        config_reads += 1
        var prepared: Dictionary = host.world_loader.validate_config(parsed, candidate.path, candidate.entry)
        if prepared.is_empty():
            failures += 1
            configs[region_id] = {"raw": {}, "stamp": FileAccess.get_modified_time(candidate.path)}
        else:
            configs[region_id] = {"raw": parsed, "prepared": prepared, "stamp": FileAccess.get_modified_time(candidate.path)}
            var theme := String(parsed.get("art_theme", ""))
            if theme == "moss_bell":
                theme = "moss_cavern"
            for filename in TEXTURES:
                queue.append({"region": region_id, "path": "res://assets/sprites/flat_maps/%s/%s" % [theme, filename], "generation": generation, "stamp": configs[region_id].stamp})
        break
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
        _warm_entities(host, started)

func _release_entities(region_id: String) -> void:
    if not entities.has(region_id):
        return
    for record in entities[region_id].bodies.values():
        var body: StaticBody2D = record.body
        if is_instance_valid(body):
            body.free()
            entity_releases += 1
    entities.erase(region_id)

func _clear_entities() -> void:
    for region_id in entities.keys():
        _release_entities(region_id)

func _warm_entities(host: Node, started: int) -> void:
    var built := 0
    for region_id in desired:
        if not configs.has(region_id) or configs[region_id].raw.is_empty():
            continue
        var candidate: Dictionary = desired[region_id]
        if entities.has(region_id) and entities[region_id].entry != candidate.entry:
            _release_entities(region_id)
        if not entities.has(region_id):
            var pending: Array = []
            var bounds := Rect2(candidate.entry - LANDING_HALF, LANDING_HALF * 2)
            for platform in configs[region_id].prepared.get("platforms", []):
                if platform.has("terrain_id") or host._is_post_boss_blocker(String(platform.id)):
                    continue
                var value: Array = platform.rect
                if bounds.intersects(Rect2(value[0], value[1], value[2], value[3])):
                    pending.append(platform.duplicate(true))
            pending.sort_custom(func(a, b): return Vector2(a.rect[0], a.rect[1]).distance_squared_to(candidate.entry) < Vector2(b.rect[0], b.rect[1]).distance_squared_to(candidate.entry))
            pending.resize(mini(pending.size(), MAX_BODIES_PER_REGION))
            entities[region_id] = {"entry": candidate.entry, "pending": pending, "bodies": {}}
        var record: Dictionary = entities[region_id]
        while not record.pending.is_empty():
            if built >= 2 or Time.get_ticks_usec() - started >= BUDGET_US:
                return
            var data: Dictionary = record.pending.pop_front()
            var rect: Array = data.rect
            var body := BODY.create(String(data.id), Rect2(rect[0], rect[1], rect[2], rect[3]), String(data.get("collision_role", "")))
            record.bodies[String(data.id)] = {"body": body, "data": data}
            entity_builds += 1
            built += 1
            max_entities = maxi(max_entities, _entity_count())

func _entity_count() -> int:
    var count := 0
    for record in entities.values():
        count += record.bodies.size()
    return count

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
            paths[region_id] = host.WORLD_ROUTES_SCRIPT.config_path(region_id)
        if String(paths[region_id]).is_empty():
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
    for region_id in configs:
        var record: Dictionary = configs[region_id]
        if not desired.has(region_id) or desired[region_id].path != path:
            continue
        if record.stamp != FileAccess.get_modified_time(path) or record.raw.is_empty():
            return null
        cache_hits += 1
        return record.raw.duplicate(true)
    return null

func snapshot() -> Dictionary:
    var count := 0
    for textures in retained.values():
        count += textures.size()
    return {"entity_regions": entities.size(), "entity_bodies": _entity_count(), "entity_builds": entity_builds, "entity_hits": entity_hits, "entity_releases": entity_releases, "max_entities": max_entities,
        "regions": configs.size(), "textures": count, "jobs": jobs.size(), "queued": queue.size(),
        "config_reads": config_reads, "cache_hits": cache_hits, "failures": failures,
        "stale_results": stale_results, "max_jobs": max_jobs_seen, "generation": generation}

func shutdown() -> void:
    # Only whole-journey teardown may wait for the <=2 outstanding jobs.
    # Godot has no threaded-load cancellation; drain requests to release them.
    for job in jobs:
        if ResourceLoader.load_threaded_get_status(job.path) in [ResourceLoader.THREAD_LOAD_IN_PROGRESS, ResourceLoader.THREAD_LOAD_LOADED]:
            ResourceLoader.load_threaded_get(job.path)
    _clear_entities()
    jobs.clear()
    queue.clear()
    configs.clear()
    retained.clear()
    desired.clear()
    paths.clear()
