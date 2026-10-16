extends SceneTree
## Detached landing geometry fixtures. Not continuous crossing or natural play.
const ROUTES := preload("res://scripts/world_routes.gd")
const BODY := preload("res://scripts/world_platform_body.gd")
const SAVE := "user://world_neighbor_entities_validation.json"
const MASK := 1 << 21
var scene: Node2D
var checks := 0
var failures: Array[String] = []

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
    # Explicit roles and implicit bridge/shaft/step one-way conventions.
    for role in ["", "one_way", "decorative", "no_collision"]:
        for id in ["fixture", "bridge_fixture", "step_fixture", "shaft_bridge_fixture"]:
            var rect := Rect2(50, 80, 140, 25)
            var reference: StaticBody2D = scene._platform(id, rect, Color.WHITE, "moss_stone", role)
            var detached := BODY.create(id, rect, role)
            _check(_geometry(reference) == _geometry(detached), "shared factory preserves role and one-way convention")
            detached.free()
            reference.free()
    var pref: RefCounted = scene.world_prefetch
    var source := String(scene.config.id)
    var flags: Dictionary = scene.story_flags.duplicate(true)
    var inventory: Dictionary = scene.inventory_counts.duplicate(true)
    var nodes := scene.get_child_count()
    scene.player.global_position = (scene.get_node("moss_rain_pipe").global_position + scene.get_node("moss_archive_return").global_position) * 0.5
    await _warm(pref, "initial_two_neighbors")
    var before: Dictionary = pref.snapshot()
    _check(before.entity_regions == 2 and before.entity_bodies > 0, "two landing caches contain real detached bodies")
    _check(before.entity_bodies <= 48 and before.max_entities <= 48, "two regions and 24 bodies each bounded")
    var refs: Array = []
    for region in pref.entities:
        _check(pref.entities[region].bodies.size() <= 24, "each region bound")
        for id in pref.entities[region].bodies:
            var record: Dictionary = pref.entities[region].bodies[id]
            var body: StaticBody2D = record.body
            refs.append(body)
            _check(not body.is_inside_tree() and body.get_parent() == null and body.get_child_count() <= 1, "warm body has no active-world ownership or visuals")
            _check(not scene._is_post_boss_blocker(id) and not record.data.has("terrain_id"), "stateful and terrain ownership excluded")
            body.collision_layer = MASK
            var point: Vector2 = body.position
            var ray := PhysicsRayQueryParameters2D.create(point - Vector2(0, 500), point + Vector2(0, 500), MASK)
            _check(root.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(), "detached collider absent from source physics space")
            body.collision_layer = 1
    _check(scene.get_child_count() == nodes and scene.story_flags == flags and scene.inventory_counts == inventory and String(scene.config.id) == source, "warming leaves active tree and progression intact")
    var target := "demo_ch03_saltwhite_archive"
    var archive: Node2D = scene.get_node("moss_archive_return")
    scene._activate_world_portal(archive)
    _check(String(scene.config.id) == source and not scene.chapter_transitioning, "prebuilt geometry cannot bypass far-side latch")
    var portal: Dictionary = archive.get_meta("world_portal_data")
    scene.story_flags["world_shortcut_" + String(portal.get("requires_shortcut", ""))] = true
    scene._activate_world_portal(archive)
    _check(String(scene.config.id) == source and not scene.chapter_transitioning, "prebuilt geometry cannot bypass missing ability after latch opens")
    scene.story_flags = flags.duplicate(true)
    var record: Dictionary = pref.entities[target].bodies.values()[0]
    var mismatch: Dictionary = record.data.duplicate(true)
    mismatch.rect[2] += 1
    _check(pref.take_platform(target, mismatch) == null and is_instance_valid(record.body), "descriptor mismatch cannot consume warmed body")
    # Keep actual instance IDs, then build the real target with normal art.
    var ids: Dictionary = {}
    for id in pref.entities[target].bodies:
        ids[id] = pref.entities[target].bodies[id].body.get_instance_id()
    var entry: Vector2 = pref.desired[target].entry
    var hits: int = pref.entity_hits
    scene._travel_world(ROUTES.config_path(target), entry)
    await _frames(2)
    var adopted := 0
    for id in ids:
        if scene.world_platforms.resident.has(id):
            var body: StaticBody2D = scene.world_platforms.resident[id]
            _check(body.get_instance_id() == ids[id], "real arrival adopts exact prefetched body instance")
            _check(body.get_parent() == scene and body.get_children().any(func(node): return node is CanvasItem and not node is CollisionShape2D), "adopted geometry receives normal target visuals")
            adopted += 1
    _check(adopted > 0 and pref.entity_hits - hits == adopted, "arrival uses cache rather than constructing duplicate geometry")
    scene.player.global_position = Vector2(-100000, -100000)
    pref.step(scene, 1)
    _check(pref.entities.is_empty(), "generation change invalidates unused detached geometry")
    await _retire(pref)
    for body in refs:
        if is_instance_valid(body):
            _check(body.is_inside_tree() and body.get_parent() == scene, "only transferred bodies survive old cache retirement")
    # Reload a source neighbor cache, invalidate its recorded timestamp.
    scene._travel_world(ROUTES.config_path(source), Vector2(120, 500))
    await _frames(2)
    scene.player.global_position = scene.get_node("moss_rain_pipe").global_position
    await _warm(pref, "reload_source_neighbor")
    var region: String = pref.entities.keys()[0]
    var item: Dictionary = pref.entities[region].bodies.values()[0]
    var stale: Variant = item.body
    pref.configs[region].stamp = -1
    _check(pref.take_platform(region, item.data) == null and not pref.entities.has(region), "timestamp mismatch invalidates stale geometry before adoption")
    await _warm(pref, "stale_config_rebuild")
    _check(not is_instance_valid(stale), "stale geometry retires while fresh cache warms")
    _check(pref.configs[region].stamp != -1 and pref.entities.has(region), "timestamp change rebuilds fresh cache")
    var retired: Array = []
    for cache in pref.entities.values():
        for value in cache.bodies.values():
            retired.append(value.body)
    scene.player.global_position = Vector2(-100000, -100000)
    pref.step(scene, 1)
    await _retire(pref)
    _check(pref.entities.is_empty() and retired.all(func(body): return not is_instance_valid(body)), "leaving radius releases all untransferred bodies")
    print("NEIGHBOR ENTITY METRICS ", JSON.stringify(pref.snapshot()))
    pref.shutdown()
    _check(pref.entities.is_empty() and pref.jobs.is_empty(), "shutdown drains resources and geometry")
    scene.free()
    current_scene = null
    await _frames(2)
    _clean()
    if failures.is_empty():
        print("WORLD NEIGHBOR ENTITIES PASS: %d checks" % checks)
        call_deferred("quit", 0)
    else:
        for message in failures:
            push_error(message)
        call_deferred("quit", 1)

func _warm(pref: RefCounted, label: String) -> void:
    var started := Time.get_ticks_msec()
    var deadline := started + 10000
    var steps := 0
    while Time.get_ticks_msec() < deadline:
        var released: int = pref.entity_releases
        var before: int = pref.entity_builds
        pref.step(scene, 0.25)
        steps += 1
        _check(pref.entity_releases - released <= 2 and pref.snapshot().owned_bodies <= 48, "per-frame retirement and total ownership bounded")
        _check(pref.entity_builds - before <= 2, "per-frame build admission capped at two")
        if not pref.entities.is_empty() and pref.configs.size() == pref.desired.size() and not pref.snapshot().config_pending and pref.entities.values().all(func(record): return record.pending.is_empty()) and pref.jobs.is_empty() and pref.queue.is_empty():
            _warm_report(pref, label, started, steps, true)
            return
        await process_frame
    _warm_report(pref, label, started, steps, false)
    _check(false, "warm cache finishes in bounded fixture time (%s)" % label)

func _warm_report(pref: RefCounted, label: String, started: int, steps: int, complete: bool) -> void:
    # Counts and at most two region summaries; never dump source configs or nodes.
    var regions: Array = []
    for id in pref.entities.keys().slice(0, 2):
        var record: Dictionary = pref.entities[id]
        regions.append({"id": id, "pending": record.pending.size(),
            "bodies": record.bodies.size(), "collisions": record.collisions.size()})
    var gameplay_phases: Array = []
    for id in pref.gameplay.regions.keys().slice(0, 2):
        var cache: Dictionary = pref.gameplay.regions[id]
        var planner: Variant = cache.get("plan_job")
        gameplay_phases.append({"id": id,
            "phase": "idle" if planner == null else String(planner.phase),
            "pending": cache.pending.size(), "actors": cache.actors.size()})
    print("NEIGHBOR ENTITY WARM ", JSON.stringify({"label": label, "complete": complete,
        "elapsed_ms": Time.get_ticks_msec() - started, "steps": steps,
        "loader_phase": String(scene.world_loader.phase),
        "desired_regions": pref.desired.keys().slice(0, 2),
        "config_regions": pref.configs.keys().slice(0, 2),
        "config_region": String(pref.config_task.get("region", "")),
        "validation_operation": "idle" if pref.config_validator == null else String(pref.config_validator.operation_name),
        "entities": regions, "gameplay_phases": gameplay_phases,
        "snapshot": pref.snapshot()}))

func _retire(pref: RefCounted) -> void:
    for frame in range(100):
        if pref.retiring.is_empty():
            return
        var before: int = pref.entity_releases
        pref.step(scene, 0.25)
        _check(pref.entity_releases - before <= 2 and pref.snapshot().owned_bodies <= 48, "retirement queue obeys two-item and global ownership bounds")
        await process_frame
    _check(false, "retirement queue drains within bounded fixture frames")

func _geometry(body: StaticBody2D) -> Array:
    var result: Array = [body.position, body.collision_layer, body.collision_mask]
    for node in body.get_children():
        if node is CollisionShape2D:
            result.append([node.shape.size, node.one_way_collision, node.one_way_collision_margin])
    return result

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
