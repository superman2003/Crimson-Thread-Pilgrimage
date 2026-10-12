extends RefCounted
const COORDINATES := preload("res://scripts/world_coordinates.gd")
## A bounded warm cache, never an instantiated neighboring region or a journal.
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
            if job.generation == generation and desired.has(job.region) and texture != null:
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
        if configs.has(region_id):
            continue
        var candidate: Dictionary = desired[region_id]
        var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(candidate.path))
        config_reads += 1
        if host.world_loader.validate_config(parsed, candidate.path, candidate.entry).is_empty():
            failures += 1
            configs[region_id] = {"raw": {}, "stamp": FileAccess.get_modified_time(candidate.path)}
        else:
            configs[region_id] = {"raw": parsed, "stamp": FileAccess.get_modified_time(candidate.path)}
            var theme := String(parsed.get("art_theme", ""))
            if theme == "moss_bell":
                theme = "moss_cavern"
            for filename in TEXTURES:
                queue.append({"region": region_id, "path": "res://assets/sprites/flat_maps/%s/%s" % [theme, filename], "generation": generation})
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
    return {"regions": configs.size(), "textures": count, "jobs": jobs.size(), "queued": queue.size(),
        "config_reads": config_reads, "cache_hits": cache_hits, "failures": failures,
        "stale_results": stale_results, "max_jobs": max_jobs_seen, "generation": generation}

func shutdown() -> void:
    # Only whole-journey teardown may wait for the <=2 outstanding jobs.
    # Godot has no threaded-load cancellation; drain requests to release them.
    for job in jobs:
        if ResourceLoader.load_threaded_get_status(job.path) in [ResourceLoader.THREAD_LOAD_IN_PROGRESS, ResourceLoader.THREAD_LOAD_LOADED]:
            ResourceLoader.load_threaded_get(job.path)
    jobs.clear()
    queue.clear()
    configs.clear()
    retained.clear()
    desired.clear()
    paths.clear()
