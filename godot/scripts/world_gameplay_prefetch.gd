extends RefCounted
## Detached gameplay and artwork only. Arrival binds interaction, narrative,
## support geometry and enemy signals to the persistent world's current state.
const PLAN_JOB := preload("res://scripts/world_gameplay_plan_job.gd")
const ART_WARM_JOB := preload("res://scripts/character_art_warm_job.gd")
# Secondary count cap; each operation is admitted only before the shared 2ms
# window expires. Avoid spreading cheap scans over excessive frames.
const MAX_PLAN_OPERATIONS := 32
const MAX_PER_REGION := 12
const MAX_TOTAL := 24
const HALF := Vector2(1280, 900)
const BUDGET_US := 2000
const LIMITS := {"enemy": 4, "npc": 3, "save_point": 2, "interaction": 3}
const FIELDS := {"enemy_spawns": "enemy", "npcs": "npc", "save_points": "save_point", "interactives": "interaction"}
var regions: Dictionary = {}
var retiring: Array[Node] = []
var builds := 0
var hits := 0
var releases := 0
var max_owned := 0
var max_children := 0
var generation := -1
var plan_operations := 0
var last_plan_operations := 0
var max_plan_operations := 0
var plan_scanned := 0
var plan_copy_edges := 0
var plan_compatibility_scanned := 0
var plan_compatibility_sorts := 0
var max_plan_compatibility_candidates := 0
var max_plan_compatibility_sort_usec := 0
var plan_completions := 0
var plan_cancellations := 0
var max_plan_step_usec := 0
var plan_operation_usec: Dictionary = {}
var _desired: Dictionary = {}
var _configs: Dictionary = {}

func synchronize(desired: Dictionary, configs: Dictionary, next_generation: int) -> void:
    # A frame that never reaches warm must not report the previous frame's work.
    last_plan_operations = 0
    if generation != next_generation:
        clear()
        generation = next_generation
    _desired = desired
    _configs = configs
    for id in regions.keys():
        if not _lease_current(id, regions[id]):
            release_region(id)
    for id in desired:
        if regions.has(id) or not configs.has(id) or configs[id].get("raw", {}).is_empty(): continue
        var record: Dictionary = configs[id]
        var job := PLAN_JOB.new()
        job.begin(record.prepared, desired[id].entry)
        # Synchronization records a lease only: no source scan, sort or copy.
        regions[id] = {"entry": desired[id].entry, "stamp": record.stamp, "path": desired[id].path,
            "generation": generation, "source_record": record, "raw": record.raw,
            "prepared": record.prepared, "plan_job": job, "plan_complete": false,
            "pending": [], "actors": {}, "art_warm_job": null, "art_ready": false, "art_error": ""}

func _lease_current(id: String, cache: Dictionary) -> bool:
    if cache.generation != generation or not _desired.has(id) or not _configs.has(id):
        return false
    var candidate: Dictionary = _desired[id]
    var record: Dictionary = _configs[id]
    # Published configs are immutable. Identity catches a replacement with the
    # same path/stamp; value checks catch a changed entrance or source lease.
    return not record.get("raw", {}).is_empty() and is_same(cache.source_record, record) \
        and is_same(cache.raw, record.get("raw")) and is_same(cache.prepared, record.get("prepared")) \
        and cache.entry == candidate.entry and cache.path == candidate.path \
        and cache.path == record.get("path", candidate.path) and cache.stamp == record.stamp \
        and cache.stamp == FileAccess.get_modified_time(cache.path)

static func plan(config: Dictionary, entry: Vector2) -> Array:
    var pending: Array = []
    var window := Rect2(entry - HALF, HALF * 2)
    for field in FIELDS:
        var category: String = FIELDS[field]
        var candidates: Array = []
        for data in config.get(field, []):
            var kind := String(data.get("kind", "")) if category == "interaction" else category
            if kind not in ["enemy", "npc", "save_point", "lever", "boss_gate", "world_portal"]: continue
            var position: Array = data.get("position", [])
            var id := String(data.get("id", ""))
            if position.size() != 2 or id.is_empty(): continue
            var point := Vector2(position[0], position[1])
            if not window.has_point(point): continue
            candidates.append({"key": kind + ":" + id, "kind": kind, "data": data.duplicate(true), "distance": point.distance_squared_to(entry)})
        candidates.sort_custom(func(a,b): return a.distance < b.distance or (a.distance == b.distance and a.key < b.key))
        candidates.resize(mini(candidates.size(), LIMITS[category]))
        pending.append_array(candidates)
    pending.sort_custom(func(a,b): return a.distance < b.distance or (a.distance == b.distance and a.key < b.key))
    return pending

func warm(host: Node, started: int, allowance: int) -> int:
    var count := 0
    last_plan_operations = 0
    for id in regions.keys():
        var cache: Dictionary = regions[id]
        if not _lease_current(id, cache):
            release_region(id)
            continue
        if not cache.plan_complete:
            var planner: RefCounted = cache.plan_job
            # Planning shares the caller's admission window with configuration,
            # textures, geometry and actor work. One operation cannot be
            # preempted; this is no single-step or frame-time guarantee.
            while not planner.done and last_plan_operations < MAX_PLAN_OPERATIONS and Time.get_ticks_usec() - started < BUDGET_US:
                var operation := String(planner.phase)
                var scanned_before: int = planner.scanned_count
                var edges_before: int = planner.copy_edges
                var compatibility_scanned_before: int = planner.compatibility_scanned
                var compatibility_sorts_before: int = planner.compatibility_sorts
                var step_started := Time.get_ticks_usec()
                var operations: int = planner.step(1)
                var elapsed := Time.get_ticks_usec() - step_started
                plan_operation_usec[operation] = int(plan_operation_usec.get(operation, 0)) + elapsed
                max_plan_step_usec = maxi(max_plan_step_usec, elapsed)
                last_plan_operations += operations
                plan_operations += operations
                plan_scanned += planner.scanned_count - scanned_before
                plan_copy_edges += planner.copy_edges - edges_before
                plan_compatibility_scanned += planner.compatibility_scanned - compatibility_scanned_before
                plan_compatibility_sorts += planner.compatibility_sorts - compatibility_sorts_before
                max_plan_compatibility_candidates = maxi(max_plan_compatibility_candidates, planner.max_compatibility_candidates)
                max_plan_compatibility_sort_usec = maxi(max_plan_compatibility_sort_usec, planner.max_compatibility_sort_usec)
            max_plan_operations = maxi(max_plan_operations, last_plan_operations)
            if planner.cancelled or not _lease_current(id, cache):
                release_region(id)
                continue
            if not planner.done:
                continue
            # Publish only a whole copied result belonging to the current lease.
            cache.pending = planner.result
            cache.plan_complete = true
            cache.plan_job = null
            cache.art_warm_job = ART_WARM_JOB.new()
            cache.art_warm_job.begin({}, cache.pending, true)
            plan_completions += 1
        if not cache.art_ready:
            var art_job: RefCounted = cache.art_warm_job
            if art_job == null or Time.get_ticks_usec() - started >= BUDGET_US: continue
            art_job.step(2, maxi(0, BUDGET_US - (Time.get_ticks_usec() - started)))
            if not art_job.done: continue
            if art_job.cancelled or not _lease_current(id, cache):
                release_region(id)
                continue
            if not String(art_job.error).is_empty():
                cache.art_error = art_job.error
                # Foreground preparation reports the failure. Speculation must
                # not create actors with a hidden synchronous PNG fallback.
                cache.pending = []
                continue
            cache.art_ready = true
            cache.art_warm_job = null
        while not cache.pending.is_empty():
            if Time.get_ticks_usec() - started >= BUDGET_US: return count
            # Exhausted creation capacity must not starve another region's
            # planning; its small operations do not acquire actor ownership.
            if count >= allowance or owned() >= MAX_TOTAL: break
            var job: Dictionary = cache.pending.pop_front()
            var actor: Area2D = host._create_gameplay_prefab(job.kind, job.data, cache.prepared)
            if actor == null: continue
            actor.position = Vector2(job.data.position[0], job.data.position[1])
            # Out-of-tree nodes have no physics space, groups or callback ticks.
            # Keep normal process/monitoring flags for canonical arrival.
            # Accepted route overlays can contain the same key twice. Keep
            # the old prefab owned until budgeted retirement, rather than
            # orphaning it when the last sorted winner replaces this slot.
            if cache.actors.has(job.key):
                var previous: Node = cache.actors[job.key].actor
                if is_instance_valid(previous): retiring.append(previous)
            cache.actors[job.key] = {"actor": actor, "data": job.data,
                "profile": cache.prepared.get("ai_profiles", {}).get(String(job.data.get("kind", "moss_larva")), {}).duplicate(true) if job.kind == "enemy" else {}}
            builds += 1
            count += 1
            max_owned = maxi(max_owned, owned())
            max_children = maxi(max_children, actor.get_child_count())
    return count

func take(id: String, kind: String, data: Dictionary, profile: Dictionary = {}) -> Area2D:
    if not regions.has(id): return null
    var cache: Dictionary = regions[id]
    if not _lease_current(id, cache):
        release_region(id)
        return null
    var key := kind + ":" + String(data.get("id", ""))
    if not cache.actors.has(key): return null
    var record: Dictionary = cache.actors[key]
    if record.data != data or record.profile != profile: return null
    cache.actors.erase(key)
    hits += 1
    return record.actor

func release_region(id: String) -> void:
    if not regions.has(id): return
    var planner: RefCounted = regions[id].plan_job
    if planner != null:
        planner.cancel()
        plan_cancellations += 1
    var art_job: RefCounted = regions[id].get("art_warm_job")
    if art_job != null: art_job.cancel()
    for record in regions[id].actors.values():
        if is_instance_valid(record.actor): retiring.append(record.actor)
    regions.erase(id)

func clear() -> void:
    for id in regions.keys(): release_region(id)
    _desired = {}
    _configs = {}
    last_plan_operations = 0

func retire(started: int, allowance: int, eager: bool = false) -> int:
    var count := 0
    while not retiring.is_empty():
        if not eager and (count >= allowance or (count > 0 and Time.get_ticks_usec() - started >= BUDGET_US)): return count
        var actor: Node = retiring.pop_front()
        if is_instance_valid(actor):
            actor.free()
            releases += 1
        count += 1
    return count

func owned() -> int:
    var count := retiring.size()
    for cache in regions.values(): count += cache.actors.size()
    return count

func snapshot() -> Dictionary:
    var pending := 0
    var cached := 0
    var planning := 0
    for cache in regions.values():
        if not cache.plan_complete: planning += 1
        pending += cache.pending.size()
        cached += cache.actors.size()
    return {"regions": regions.size(), "cached": cached, "pending": pending, "retiring": retiring.size(), "owned": owned(), "max_owned": max_owned, "builds": builds, "hits": hits, "releases": releases, "max_children": max_children,
        "planning": planning, "plan_operations": plan_operations, "last_plan_operations": last_plan_operations,
        "max_plan_operations": max_plan_operations, "plan_scanned": plan_scanned, "plan_copy_edges": plan_copy_edges,
        "plan_completions": plan_completions, "plan_cancellations": plan_cancellations,
        "plan_compatibility_scanned": plan_compatibility_scanned, "plan_compatibility_sorts": plan_compatibility_sorts,
        "max_plan_compatibility_candidates": max_plan_compatibility_candidates,
        "max_plan_compatibility_sort_usec": max_plan_compatibility_sort_usec,
        "max_plan_step_usec": max_plan_step_usec, "plan_operation_usec": plan_operation_usec.duplicate()}

func shutdown() -> void:
    clear()
    retire(Time.get_ticks_usec(), MAX_TOTAL, true)
