extends RefCounted
## Detached gameplay and artwork only. Arrival binds interaction, narrative,
## support geometry and enemy signals to the persistent world's current state.
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

func synchronize(desired: Dictionary, configs: Dictionary, next_generation: int) -> void:
    if generation != next_generation:
        clear()
        generation = next_generation
    for id in regions.keys():
        if not desired.has(id) or not configs.has(id) or configs[id].get("raw", {}).is_empty() or regions[id].entry != desired[id].entry or regions[id].stamp != configs[id].stamp:
            release_region(id)
    for id in desired:
        if regions.has(id) or not configs.has(id) or configs[id].get("raw", {}).is_empty(): continue
        var record: Dictionary = configs[id]
        regions[id] = {"entry": desired[id].entry, "stamp": record.stamp, "path": desired[id].path,
            "prepared": record.prepared, "pending": plan(record.prepared, desired[id].entry), "actors": {}}

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
    for id in regions:
        var cache: Dictionary = regions[id]
        while not cache.pending.is_empty():
            if count >= allowance or owned() >= MAX_TOTAL or Time.get_ticks_usec() - started >= BUDGET_US: return count
            var job: Dictionary = cache.pending.pop_front()
            var actor: Area2D = host._create_gameplay_prefab(job.kind, job.data, cache.prepared)
            if actor == null: continue
            actor.position = Vector2(job.data.position[0], job.data.position[1])
            # Out-of-tree nodes have no physics space, groups or callback ticks.
            # Keep normal process/monitoring flags for canonical arrival.
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
    if cache.stamp != FileAccess.get_modified_time(cache.path):
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
    for record in regions[id].actors.values():
        if is_instance_valid(record.actor): retiring.append(record.actor)
    regions.erase(id)

func clear() -> void:
    for id in regions.keys(): release_region(id)

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
    for cache in regions.values():
        pending += cache.pending.size()
        cached += cache.actors.size()
    return {"regions": regions.size(), "cached": cached, "pending": pending, "retiring": retiring.size(), "owned": owned(), "max_owned": max_owned, "builds": builds, "hits": hits, "releases": releases, "max_children": max_children}

func shutdown() -> void:
    clear()
    retire(Time.get_ticks_usec(), MAX_TOTAL, true)
