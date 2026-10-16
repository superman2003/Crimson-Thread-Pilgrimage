extends SceneTree
## Explicit landing/state fixtures, not seamless crossing or natural combat.
const ROUTES := preload("res://scripts/world_routes.gd")
const COORD := preload("res://scripts/world_coordinates.gd")
const GAMEPLAY := preload("res://scripts/world_gameplay_prefetch.gd")
const STATE := preload("res://scripts/world_state.gd")
const SAVE := "user://neighbor_gameplay_validation.json"
const CACHE_RETRY := "user://world_shared_metadata_retry.json"
const CACHE_OTHER := "user://world_shared_metadata_other.json"
const MASK := 1 << 22
var scene: Node
var checks := 0
var failures: Array[String] = []
var metrics: Array = []
var observed: Dictionary = {}
var churn: Dictionary = {}
var runtime_probe: RefCounted
var shared_metadata_baseline: Dictionary = {}
var shared_metadata_signature: Dictionary = {}
var diagnostic_started := 0
var diagnostic_stage := ""
var diagnostic_stage_started := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok: failures.append(message)
func frames(count: int) -> void:
    for unused in count:
        await physics_frame
        await process_frame
func stage(label: String, details: Dictionary = {}) -> void:
    var now := Time.get_ticks_msec()
    print("NEIGHBOR GAMEPLAY STAGE ", JSON.stringify({"stage": label,
        "elapsed_ms": now - diagnostic_started, "previous": diagnostic_stage,
        "previous_ms": now - diagnostic_stage_started, "checks": checks,
        "failures": failures.size(), "details": details}))
    diagnostic_stage = label
    diagnostic_stage_started = now
func prefetch_progress(pref: RefCounted) -> Dictionary:
    # Bounded scalar summaries only; never retain/dump source data or actors.
    var regions: Array = []
    for id in pref.gameplay.regions.keys().slice(0, 2):
        var cache: Dictionary = pref.gameplay.regions[id]
        var planner: Variant = cache.get("plan_job")
        regions.append({"id": id, "phase": "idle" if planner == null else String(planner.phase),
            "complete": cache.get("plan_complete", true), "pending": cache.pending.size(),
            "actors": cache.actors.size(), "operations": 0 if planner == null else planner.operation_count})
    var geometry: Array = []
    for id in pref.entities.keys().slice(0, 2):
        geometry.append({"id": id, "pending": pref.entities[id].pending.size()})
    return {"desired": pref.desired.keys().slice(0, 2), "configs": pref.configs.keys().slice(0, 2),
        "config_region": String(pref.config_task.get("region", "")),
        "validation_operation": "idle" if pref.config_validator == null else String(pref.config_validator.operation_name),
        "entity_builds": pref.entity_builds, "entity_releases": pref.entity_releases,
        "gameplay_builds": pref.gameplay.builds, "gameplay_releases": pref.gameplay.releases,
        "geometry": geometry, "gameplay": regions, "jobs": pref.jobs.size(), "queue": pref.queue.size(),
        "generation": pref.generation, "loader_generation": scene.world_loader.generation,
        "route_generation": pref.route_cache_generation, "route_current": ROUTES.cached_generation()}
func transition_progress(label: String, started: int, steps: int) -> void:
    var loader: RefCounted = scene.world_loader
    var progress: Dictionary = {}
    for key in ["rolled_back", "preflight_copy_steps", "preflight_copy_edges", "preflight_copy_batches",
            "preflight_copy_work_usec", "preflight_copy_wall_usec", "preflight_cursor", "preflight_batches",
            "preflight_work_usec", "preflight_wall_usec", "json_wait_frames",
            "prepare_cursor", "prepare_jobs", "prepare_batches", "prepare_work_usec",
            "prepare_wall_usec", "jobs", "batches", "commit_cursor", "commit_jobs", "commit_job",
            "commit_work_usec", "commit_wall_usec"]:
        if loader.last_transition.has(key): progress[key] = loader.last_transition[key]
    print("NEIGHBOR GAMEPLAY TRANSITION ", JSON.stringify({"label": label,
        "elapsed_ms": Time.get_ticks_msec() - started, "total_ms": Time.get_ticks_msec() - diagnostic_started,
        "frames": steps, "phase": loader.phase, "cancel_requested": loader.cancel_requested,
        "gameplay_hits": scene.world_prefetch.gameplay.hits,
        "region": String(scene.config.get("id", "")),
        "loading": loader.loading_label.text if is_instance_valid(loader.loading_label) else "",
        "progress": progress}))
func _seed_cache(id: String, entry: Vector2) -> RefCounted:
    var seed_started := Time.get_ticks_usec()
    var pref: RefCounted = scene.world_prefetch
    pref.shutdown()
    var shutdown_usec := Time.get_ticks_usec() - seed_started
    pref.generation = scene.world_loader.generation
    pref.selection_elapsed = -1000
    var path := ROUTES.config_path(id)
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
    var validated_at := Time.get_ticks_usec()
    var prepared: Dictionary = scene.world_loader.validate_config(raw, path, entry)
    var validation_usec := Time.get_ticks_usec() - validated_at
    check(not prepared.is_empty(), "canonical target validates")
    pref.desired = {id: {"path": path, "entry": entry, "distance": 0}}
    pref.configs = {id: {"raw": raw, "prepared": prepared, "stamp": FileAccess.get_modified_time(path)}}
    print("NEIGHBOR GAMEPLAY SEED ", JSON.stringify({"region": id, "elapsed_usec": Time.get_ticks_usec() - seed_started,
        "shutdown_usec": shutdown_usec, "read_usec": validated_at - seed_started - shutdown_usec,
        "validation_usec": validation_usec, "checks": checks, "failures": failures.size()}))
    return pref
func warm(pref: RefCounted, label: String = "cache_churn") -> void:
    var started := Time.get_ticks_msec()
    var deadline := started + 15000
    var report_at := started + 2000
    var steps := 0
    var work_usec := 0
    var max_step_usec := 0
    while Time.get_ticks_msec() < deadline:
        if runtime_probe != null: runtime_probe.frame()
        var built: int = pref.entity_builds + pref.gameplay.builds
        var retired: int = pref.entity_releases + pref.gameplay.releases
        var step_started := Time.get_ticks_usec()
        pref.step(scene,0)
        var step_usec := Time.get_ticks_usec() - step_started
        work_usec += step_usec
        max_step_usec = maxi(max_step_usec, step_usec)
        steps += 1
        check(pref.entity_builds + pref.gameplay.builds - built <= 2, "shared geometry/gameplay creation admission <=2")
        check(pref.entity_releases + pref.gameplay.releases - retired <= 2, "shared retirement admission <=2")
        check(pref.snapshot().owned_bodies <= 48 and pref.gameplay.owned() <= 24, "owned + pending retirement capacity bounded")
        var ready: bool = pref.entities.values().all(func(x): return x.pending.is_empty()) and pref.gameplay.regions.values().all(func(x): return x.plan_complete and x.pending.is_empty())
        var complete: bool = not pref.gameplay.regions.is_empty() and pref.gameplay.regions.size() == pref.desired.size() and ready
        if complete or Time.get_ticks_msec() >= report_at:
            print("NEIGHBOR GAMEPLAY WARM ", JSON.stringify({"label": label, "complete": complete,
                "elapsed_ms": Time.get_ticks_msec() - started, "steps": steps, "work_usec": work_usec,
                "max_step_usec": max_step_usec, "checks": checks, "failures": failures.size(),
                "prefetch": prefetch_progress(pref)}))
            report_at = Time.get_ticks_msec() + 2000
        if complete: return
        await process_frame
    print("NEIGHBOR GAMEPLAY WARM DEADLINE ", JSON.stringify({"label": label,
        "elapsed_ms": Time.get_ticks_msec() - started, "steps": steps, "work_usec": work_usec,
        "max_step_usec": max_step_usec, "checks": checks, "failures": failures.size(),
        "prefetch": prefetch_progress(pref)}))
    check(false, "warming finishes before fixture deadline")
func live(kind: String, data: Dictionary) -> Area2D:
    if kind != "enemy": return scene.get_node_or_null(NodePath(String(data.id)))
    for child in scene.get_children():
        if child.get_script() == scene.ENEMY_ACTOR_SCRIPT and child.spawn_id == String(data.id): return child
    return null
func signature(actor: Area2D) -> Array:
    var result: Array = [actor.position,actor.collision_layer,actor.collision_mask,actor.monitoring,actor.monitorable]
    if actor.get_script() == scene.ENEMY_ACTOR_SCRIPT:
        result.append([actor.spawn_id,actor.kind,actor.hp,actor.max_hp,actor.ai_profile,actor.spawn_position,actor.platform_min_x,actor.platform_max_x,actor.death_sfx_key])
    else:
        result.append([actor.get_meta("kind",""),actor.get_meta("label",""),actor.get_meta("dialogue",[]),actor.get_meta("world_location_state",""),actor.get_meta("activated",false),actor.get_meta("requires_keys",0),actor.get_meta("world_portal_data",{})])
    for child in actor.get_children():
        if child is CollisionShape2D:
            result.append([child.position,str(child.shape.get_class()),child.shape.size if child.shape is RectangleShape2D else child.shape.radius])
        elif child is AnimatedSprite2D:
            result.append([str(child.name) if not str(child.name).begins_with("@") else child.get_class(),child.position,child.scale,child.sprite_frames.get_animation_names(),child.animation,child.frame])
        elif child is Sprite2D:
            result.append([str(child.name) if not str(child.name).begins_with("@") else child.get_class(),child.position,child.scale,child.texture.get_size(),child.modulate])
    return result

func metadata_signature() -> Dictionary:
    return {"campaign": scene.campaign.duplicate(true),
        "chapter_files": scene.chapter_file_configs.duplicate(true),
        "audio_visual_manifest": scene.audio_visual_manifest.duplicate(true),
        "item_lore": scene.item_lore.duplicate(true)}

func write_fixture(path: String, text: String) -> void:
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file != null:
        file.store_string(text)
        file.close()

func verify_shared_metadata_cache() -> void:
    shared_metadata_baseline = scene.world_shared_metadata_snapshot()
    shared_metadata_signature = metadata_signature()
    var reads: Dictionary = shared_metadata_baseline.reads
    var parses: Dictionary = shared_metadata_baseline.parses
    var bytes: Dictionary = shared_metadata_baseline.bytes
    var expected_paths: Array[String] = ["res://data/campaign_chapters.json", "res://data/audio_visual_manifest.json", "res://data/item_lore.json"]
    for chapter_name in ["ch02_rain_foundry_canal.json", "ch03_saltwhite_archive.json", "ch04_broken_string_greenhouse.json", "ch05_obsidian_pilgrim_road.json", "ch06_silent_crown_core.json"]:
        expected_paths.append("res://data/chapters/" + chapter_name)
    var expected_keys: Array[String] = []
    for expected_path in expected_paths:
        expected_keys.append(scene._world_shared_metadata_key(expected_path))
    expected_keys.sort()
    var actual_keys: Array = reads.keys()
    actual_keys.sort()
    check(actual_keys == expected_keys and reads.values().all(func(n): return int(n) == 1), "World host reads eight known immutable metadata sources once")
    check(parses == reads and bytes.size() == 8 and bytes.values().all(func(n): return int(n) > 0), "metadata parse/byte counters record actual successful source reads")
    var failures: Dictionary = shared_metadata_baseline.failures
    check(expected_keys.all(func(key): return int(failures.get(key, 0)) == 0), "all production metadata sources parse without failure")
    check(scene.campaign.get("chapters", []).size() == 6 and scene.chapter_file_configs.size() == 5 and not scene.audio_visual_manifest.get("runtime_events", {}).is_empty() and not scene.item_lore.is_empty(), "production metadata has expected campaign, chapter, audio, and lore contents")
    var campaign_path := "res://data/campaign_chapters.json"
    var campaign_key: String = scene._world_shared_metadata_key(campaign_path)
    var campaign_reads_before := int(scene.world_shared_metadata_reads.get(campaign_key, 0))
    var campaign_probes_before := int(scene.world_shared_metadata_probes.get(campaign_key, 0))
    var cached_campaign: Dictionary = scene._load_world_shared_json(campaign_path)
    var expected_campaign: Dictionary = cached_campaign.duplicate(true)
    if not cached_campaign.get("chapters", []).is_empty():
        cached_campaign.chapters[0]["name"] = "fixture mutation must not escape its copy"
    check(scene._load_world_shared_json(campaign_path) == expected_campaign, "caller mutation cannot alter cached campaign snapshot")
    check(int(scene.world_shared_metadata_probes.get(campaign_key, 0)) == campaign_probes_before + 2 and int(scene.world_shared_metadata_reads.get(campaign_key, 0)) == campaign_reads_before, "cache hits probe source metadata without rereading or reparsing content")

    for suffix in ["", ".tmp"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(CACHE_RETRY + suffix))
        DirAccess.remove_absolute(ProjectSettings.globalize_path(CACHE_OTHER + suffix))
    var missing: Dictionary = scene._load_world_shared_json(CACHE_RETRY)
    var retry_key: String = scene._world_shared_metadata_key(CACHE_RETRY)
    check(missing.is_empty() and not scene.world_shared_metadata_cache.has(retry_key), "missing shared metadata is not cached")
    write_fixture(CACHE_RETRY, "{")
    check(scene._load_world_shared_json(CACHE_RETRY).is_empty(), "malformed shared metadata is rejected")
    check(not scene.world_shared_metadata_cache.has(retry_key), "malformed shared metadata is not cached")
    write_fixture(CACHE_RETRY, "{}")
    var valid_empty: Dictionary = scene._load_world_shared_json(CACHE_RETRY)
    var empty_reads := int(scene.world_shared_metadata_reads.get(retry_key, 0))
    check(valid_empty.is_empty() and scene.world_shared_metadata_cache.has(retry_key), "valid empty JSON object is cached distinctly from failure")
    check(scene._load_world_shared_json(CACHE_RETRY).is_empty() and int(scene.world_shared_metadata_reads.get(retry_key, 0)) == empty_reads, "valid empty JSON cache avoids a redundant parse")
    write_fixture(CACHE_RETRY, "{\"value\":\"changed source\"}")
    var changed: Dictionary = scene._load_world_shared_json(CACHE_RETRY)
    check(changed.get("value", "") == "changed source", "mtime/size source change invalidates cached snapshot")
    changed["value"] = "mutated return value"
    check(scene._load_world_shared_json(CACHE_RETRY).get("value", "") == "changed source", "cache returns a deep copy after source refresh")
    write_fixture(CACHE_OTHER, "{\"value\":\"other path\"}")
    check(scene._load_world_shared_json(CACHE_OTHER).get("value", "") == "other path" and scene._load_world_shared_json(CACHE_RETRY).get("value", "") == "changed source", "canonical path keys isolate sources")
    var world_mode_before: bool = scene.world_mode
    scene.world_mode = false
    var other_key: String = scene._world_shared_metadata_key(CACHE_OTHER)
    var non_world_reads := int(scene.world_shared_metadata_reads.get(other_key, 0))
    check(scene._load_world_shared_json(CACHE_OTHER).get("value", "") == "other path" and int(scene.world_shared_metadata_reads.get(other_key, 0)) == non_world_reads, "non-World loading retains uncached behavior")
    scene.world_mode = world_mode_before
    scene.world_shared_metadata_cache.erase(retry_key)
    scene.world_shared_metadata_cache.erase(other_key)
    for suffix in ["", ".tmp"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(CACHE_RETRY + suffix))
        DirAccess.remove_absolute(ProjectSettings.globalize_path(CACHE_OTHER + suffix))
    for metrics_name in ["world_shared_metadata_reads", "world_shared_metadata_bytes", "world_shared_metadata_parses", "world_shared_metadata_failures", "world_shared_metadata_probes"]:
        var metrics: Dictionary = scene.get(metrics_name)
        metrics.erase(retry_key)
        metrics.erase(other_key)
    shared_metadata_baseline = scene.world_shared_metadata_snapshot()
func landing(id: String, entry: Vector2) -> void:
    var label := "landing_%d" % (metrics.size() + 1)
    stage(label + ":seed", {"region": id, "entry": [entry.x, entry.y]})
    var pref := _seed_cache(id,entry)
    var state: Dictionary = scene.story_flags.duplicate(true)
    var inventory: Dictionary = scene.inventory_counts.duplicate(true)
    var wallet: int = scene.currency_count
    var enemy_count := get_nodes_in_group("enemy").size()
    var node_count: int = scene.get_child_count()
    stage(label + ":warm")
    await warm(pref, label)
    stage(label + ":warm_checks")
    check(scene.story_flags == state and scene.inventory_counts == inventory and scene.currency_count == wallet and get_nodes_in_group("enemy").size() == enemy_count and scene.get_child_count() == node_count, "prebuild leaves active progression/inventory/groups/tree unchanged")
    var records: Dictionary = pref.gameplay.regions[id].actors.duplicate()
    check(records.size() <= GAMEPLAY.MAX_PER_REGION, "per-region actor limit")
    var before_hits: int = pref.gameplay.hits
    for key in records:
        var record: Dictionary = records[key]
        var actor: Area2D = record.actor
        var kind := String(key).get_slice(":",0)
        observed[kind] = true
        check(not actor.is_inside_tree() and actor.get_parent() == null and actor.get_child_count() >= 2, "detached actor includes collider + original visual")
        check(not actor.body_entered.is_connected(scene._on_interactable_entered.bind(actor)), "detached interaction has no live callback")
        actor.collision_layer = MASK
        var query := PhysicsPointQueryParameters2D.new()
        query.position = actor.position
        query.collision_mask = MASK
        query.collide_with_areas = true
        check(root.get_world_2d().direct_space_state.intersect_point(query).is_empty(), "detached Area absent from source physics")
        actor.collision_layer = 1
        var wrong: Dictionary = record.data.duplicate(true)
        wrong.position[0] += 1
        check(pref.gameplay.take(id,kind,wrong,record.profile) == null, "descriptor mismatch does not consume actor")
        if kind == "enemy":
            var wrong_profile: Dictionary = record.profile.duplicate(true)
            wrong_profile.fixture_mismatch = true
            check(pref.gameplay.take(id,kind,record.data,wrong_profile) == null, "AI profile lease cannot be substituted")
    stage(label + ":warm_arrival")
    scene._travel_world(ROUTES.config_path(id),entry)
    stage(label + ":warm_settle")
    await frames(2)
    stage(label + ":warm_parity")
    var metadata_after: Dictionary = scene.world_shared_metadata_snapshot()
    check(metadata_after.reads == shared_metadata_baseline.reads and metadata_after.parses == shared_metadata_baseline.parses and metadata_after.bytes == shared_metadata_baseline.bytes, "region arrival reuses immutable metadata without rereading or reparsing")
    check(metadata_signature() == shared_metadata_signature, "campaign, chapter, audio and lore metadata semantics survive region arrival")
    check(scene.current_campaign_chapter == scene._campaign_chapter_for_id(id), "current campaign chapter is resolved from the current region, not cached as region state")
    check(String(scene.config.get("id", "")) == id and String(scene.world_state.data.get("current_region", "")) == id, "region-specific config and saved progression still advance dynamically")
    var warm_signatures: Dictionary = {}
    for key in records:
        var record: Dictionary = records[key]
        var actor := live(String(key).get_slice(":",0),record.data)
        check(actor != null and actor == record.actor and actor.get_parent() == scene, "arrival adopts exact gameplay instance")
        if actor == null: continue
        warm_signatures[key] = signature(actor)
        if String(key).begins_with("enemy:"):
            check(actor.presentation_prepared and actor.is_in_group("enemy"), "enemy ready activates once with prepared artwork")
            check(actor.get_children().filter(func(x): return x is CollisionShape2D).size() == 1, "adoption does not duplicate enemy collision")
        else:
            check(actor.body_entered.is_connected(scene._on_interactable_entered.bind(actor)), "arrival binds current persistent host once")
            check(actor.has_node("Wayfinding"), "original sign added only on arrival")
    check(pref.gameplay.hits - before_hits == records.size(), "all planned actors reused")
    metrics.append({"region":id,"entry":[entry.x,entry.y],"adopted":records.size(),"kinds":records.keys()})
    stage(label + ":cold_arrival")
    pref.shutdown()
    scene._travel_world(ROUTES.config_path(id),entry)
    stage(label + ":cold_settle")
    await frames(2)
    stage(label + ":cold_parity")
    for key in warm_signatures:
        var actor := live(String(key).get_slice(":",0),records[key].data)
        var actual: Array = signature(actor) if actor != null else []
        if actual != warm_signatures[key]:
            print("GAMEPLAY_PARITY_DIFF ",JSON.stringify({"region":id,"entry":[entry.x,entry.y],"key":key,"warm":warm_signatures[key],"cold":actual}))
        check(actor != null and actual == warm_signatures[key], "warm arrival equals cold authored gameplay/artwork/state " + id + ":" + key)
    stage(label + ":complete")
func invalid_descriptors() -> void:
    var path := ROUTES.config_path(String(scene.config.id))
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
    var entry := Vector2(raw.player_start[0],raw.player_start[1])
    for field in ["enemy_spawns","npcs","save_points","interactives"]:
        var malformed: Dictionary = raw.duplicate(true)
        malformed[field].append(malformed[field][0].duplicate(true))
        check(scene.world_loader.validate_config(malformed,path,entry).is_empty(), "duplicate gameplay identity rejected before prebuild")
        malformed = raw.duplicate(true)
        malformed[field][0].erase("position")
        check(scene.world_loader.validate_config(malformed,path,entry).is_empty(), "missing gameplay position rejected before allocation")
    for value in [[],[0,40],[-1,40],[INF,40],["bad",40]]:
        var malformed: Dictionary = raw.duplicate(true)
        malformed.interactives[0].interaction_size = value
        check(scene.world_loader.validate_config(malformed,path,entry).is_empty(), "bad interaction dimensions rejected")
    for value in [[], "invalid", {String(raw.enemy_spawns[0].kind): []}]:
        var malformed: Dictionary = raw.duplicate(true)
        malformed.ai_profiles = value
        check(scene.world_loader.validate_config(malformed,path,entry).is_empty(), "malformed enemy profile rejected before prebuild")
    var defaults: Dictionary = raw.duplicate(true)
    defaults.enemy_spawns[0].body_size = []
    defaults.enemy_spawns[0].hurtbox_size = []
    check(not scene.world_loader.validate_config(defaults,path,entry).is_empty(), "empty enemy sizes retain authored defaults")
func invalidation() -> void:
    stage("invalidation:seed")
    var id := "demo_ch02_rain_foundry_canal"
    var entry := Vector2(330,720)
    var pref := _seed_cache(id,entry)
    await warm(pref, "invalidation:initial")
    var old: Array = pref.gameplay.regions[id].actors.values().map(func(x): return x.actor)
    var key: String = pref.gameplay.regions[id].actors.keys()[0]
    var record: Dictionary = pref.gameplay.regions[id].actors[key]
    pref.gameplay.regions[id].stamp = -1
    check(pref.gameplay.take(id,key.get_slice(":",0),record.data,record.profile) == null, "timestamp mismatch prevents adoption")
    await warm(pref, "invalidation:stale")
    check(old.all(func(x): return not is_instance_valid(x)), "stale actors retire before new lease warms")
    old = pref.gameplay.regions[id].actors.values().map(func(x): return x.actor)
    pref.desired = {}
    for unused in 100:
        pref.step(scene,0)
        if pref.gameplay.owned() == 0: break
        await process_frame
    check(pref.gameplay.owned() == 0 and old.all(func(x): return not is_instance_valid(x)), "leaving range drains detached actors")
    pref = _seed_cache(id,entry)
    await warm(pref, "invalidation:generation")
    old = pref.gameplay.regions[id].actors.values().map(func(x): return x.actor)
    pref.generation = -1
    pref.step(scene,0)
    pref.shutdown()
    check(old.all(func(x): return not is_instance_valid(x)) and pref.gameplay.owned() == 0, "generation change and teardown drain actor ownership")
    stage("invalidation:complete")
func two_neighbors() -> void:
    stage("two_neighbors:arrival")
    scene.world_prefetch.shutdown()
    scene._travel_world(ROUTES.config_path("demo_ch01_moss_bell_court"),Vector2(200,3360))
    var pref: RefCounted = scene.world_prefetch
    pref.selection_elapsed = 1
    pref.generation = -1
    scene.player.position = (scene.get_node("moss_rain_pipe").position + scene.get_node("moss_archive_return").position) * 0.5
    stage("two_neighbors:warm")
    await warm(pref, "two_neighbors")
    check(pref.desired.size() == 2 and pref.gameplay.regions.size() == 2, "two natural neighboring entrance caches prepared")
    check(pref.gameplay.owned() <= 24 and pref.snapshot().owned_bodies + pref.gameplay.owned() <= 72, "combined detached ownership bounded")
    var blocked := GAMEPLAY.new()
    blocked.synchronize(pref.desired,pref.configs,pref.generation)
    for unused in GAMEPLAY.MAX_TOTAL: blocked.retiring.append(Area2D.new())
    check(blocked.warm(scene,Time.get_ticks_usec(),2) == 0 and blocked.owned() == 24, "pending retirement consumes capacity before creation")
    blocked.shutdown()
    check(blocked.owned() == 0, "saturated cache teardown drains all actors")
    pref.shutdown()
    stage("two_neighbors:complete")

func cancellation() -> void:
    stage("cancellation:seed")
    var id := "demo_ch02_rain_foundry_canal"
    var pref := _seed_cache(id,Vector2(330,720))
    await warm(pref, "cancellation")
    var before_hits: int = pref.gameplay.hits
    var source := String(scene.config.id)
    var state: Dictionary = scene.story_flags.duplicate(true)
    var wallet: int = scene.currency_count
    stage("cancellation:request")
    var started := Time.get_ticks_msec()
    var report_at := started + 2000
    var waited_frames := 0
    scene._request_world_travel(ROUTES.config_path(id),Vector2(330,720))
    transition_progress("requested", started, waited_frames)
    for unused in 2000:
        if pref.gameplay.hits > before_hits or scene.world_loader.phase == "idle": break
        if Time.get_ticks_msec() >= report_at:
            transition_progress("await_partial_adoption", started, waited_frames)
            report_at = Time.get_ticks_msec() + 2000
        await process_frame
        waited_frames += 1
    transition_progress("partial_adoption_finished", started, waited_frames)
    check(pref.gameplay.hits > before_hits and scene.world_loader.phase == "loading", "cancel fixture reaches partially adopted target")
    stage("cancellation:rollback")
    scene.world_loader.cancel_transition()
    started = Time.get_ticks_msec()
    report_at = started + 2000
    waited_frames = 0
    for unused in 2000:
        if scene.world_loader.phase == "idle": break
        if Time.get_ticks_msec() >= report_at:
            transition_progress("await_rollback", started, waited_frames)
            report_at = Time.get_ticks_msec() + 2000
        await process_frame
        waited_frames += 1
    transition_progress("rollback_finished", started, waited_frames)
    check(scene.world_loader.last_transition.get("rolled_back",false) and String(scene.config.id) == source, "cancelled target rolls back source")
    check(scene.story_flags == state and scene.currency_count == wallet, "cancelled gameplay preserves source progress")
    var metadata_after: Dictionary = scene.world_shared_metadata_snapshot()
    check(metadata_after.reads == shared_metadata_baseline.reads and metadata_after.parses == shared_metadata_baseline.parses, "cancelled target preparation reuses immutable metadata")
    var saved := STATE.new()
    check(saved.read(SAVE) and saved.data.current_region == source, "partial destination never committed to disk")
    pref.shutdown()
    stage("cancellation:complete")

func cache_churn() -> void:
    scene._travel_world(ROUTES.config_path("demo_ch01_moss_bell_court"),Vector2(200,3360))
    var pref: RefCounted = scene.world_prefetch
    pref.shutdown()
    pref.generation = scene.world_loader.generation
    pref.selection_elapsed = -1000
    var baseline_nodes := scene.get_child_count()
    var baseline_enemies := get_nodes_in_group("enemy").size()
    var baseline_state: Dictionary = scene.story_flags.duplicate(true)
    var source_position: Vector2 = scene.player.position
    var source_portals: Array = scene.config.interactives.duplicate(true)
    var focus: Vector2 = (scene.get_node("moss_rain_pipe").position + scene.get_node("moss_archive_return").position) * 0.5
    var old_actors: Array = []
    var before_builds: int = pref.gameplay.builds
    var before_releases: int = pref.gameplay.releases
    var before_config_reads: int = pref.config_reads
    var before_validation_steps: int = pref.config_validation_steps
    var before_entry_rechecks: int = pref.config_entry_rechecks
    var churn_started := Time.get_ticks_usec()
    runtime_probe = preload("res://scripts/world_runtime_probe.gd").new()
    runtime_probe.capture("baseline", scene)
    # Repeated two-neighbor, changed-entry and leave-range leases in one host.
    # Retirements deliberately overlap new plans; no per-cycle shutdown.
    for cycle in 80:
        scene.config.interactives = source_portals.duplicate(true)
        for portal in scene.config.interactives:
            if String(portal.get("target_config_id","")) in ["demo_ch02_rain_foundry_canal", "demo_ch03_saltwhite_archive"]:
                portal.target_spawn[0] += (cycle % 2) * 120
        scene.player.position = focus
        pref.selection_elapsed = 1
        var cycle_reads: int = pref.config_reads
        var cycle_steps: int = pref.config_validation_steps
        await warm(pref)
        if cycle % 5 != 0:
            check(pref.config_reads == cycle_reads and pref.config_validation_steps == cycle_steps, "changed entrance reuses validated region data during churn")
        check(old_actors.all(func(x): return not is_instance_valid(x)), "changed entry releases previous gameplay lease")
        old_actors = []
        for cache in pref.gameplay.regions.values():
            old_actors.append_array(cache.actors.values().map(func(x): return x.actor))
        if cycle % 5 == 4:
            scene.player.position = Vector2(8000,6000)
            pref.selection_elapsed = 1
            for unused in 80:
                var built: int = pref.entity_builds + pref.gameplay.builds
                var released: int = pref.entity_releases + pref.gameplay.releases
                pref.step(scene,0)
                check(pref.entity_builds + pref.gameplay.builds - built <= 2 and pref.entity_releases + pref.gameplay.releases - released <= 2, "leave-range shared frame admission bounded")
                if pref.gameplay.owned() == 0 and pref.snapshot().owned_bodies == 0: break
                await process_frame
            check(old_actors.all(func(x): return not is_instance_valid(x)), "leave-range lease drains during churn")
        runtime_probe.capture("cycle_%d" % (cycle + 1), scene)
        if cycle % 10 == 9:
            print("NEIGHBOR CHURN PROGRESS ", JSON.stringify({"cycles":cycle + 1,"config_reads":pref.config_reads - before_config_reads,"validation_steps":pref.config_validation_steps - before_validation_steps,"entry_rechecks":pref.config_entry_rechecks - before_entry_rechecks,"elapsed_usec":Time.get_ticks_usec() - churn_started}))
    pref.shutdown()
    scene.config.interactives = source_portals
    scene.player.position = source_position
    # One-shot SFX are attached deferred so they cannot add children while a
    # scene-tree notification is active. This fixture disables the level tree,
    # so temporarily let only the one-shot players process while the last toast
    # finishes; gameplay and its entities remain frozen.
    var sfx_settle_frames := 0
    var previous_sfx_process_modes: Dictionary = {}
    while sfx_settle_frames < 180:
        var active_sfx := scene.get_children().filter(func(child): return child is AudioStreamPlayer and String(child.name).begins_with("Sfx_"))
        var pending_players: Array = []
        for pending_value in scene.pending_sfx_players.values():
            var pending: Dictionary = pending_value
            var player: AudioStreamPlayer = pending.get("player")
            if is_instance_valid(player):
                pending_players.append(player)
        for player in active_sfx + pending_players:
            var instance_id: int = player.get_instance_id()
            if not previous_sfx_process_modes.has(instance_id):
                previous_sfx_process_modes[instance_id] = player.process_mode
            player.process_mode = Node.PROCESS_MODE_ALWAYS
        if active_sfx.is_empty() and pending_players.is_empty():
            break
        await frames(1)
        sfx_settle_frames += 1
    var remaining_sfx := scene.get_children().filter(func(child): return child is AudioStreamPlayer and String(child.name).begins_with("Sfx_"))
    var sfx_restore_candidates: Array = remaining_sfx.duplicate()
    for pending_value in scene.pending_sfx_players.values():
        var pending: Dictionary = pending_value
        var player: AudioStreamPlayer = pending.get("player")
        if is_instance_valid(player):
            sfx_restore_candidates.append(player)
    for child in sfx_restore_candidates:
        var instance_id: int = child.get_instance_id()
        if previous_sfx_process_modes.has(instance_id):
            child.process_mode = int(previous_sfx_process_modes[instance_id])
    check(remaining_sfx.is_empty() and scene.pending_sfx_players.is_empty(), "one-shot SFX retire after cache churn")
    check(old_actors.all(func(x): return not is_instance_valid(x)) and pref.gameplay.owned() == 0 and pref.snapshot().owned_bodies == 0, "churn teardown releases all detached objects")
    check(pref.gameplay.builds - before_builds == pref.gameplay.releases - before_releases, "every churn-built gameplay actor retired exactly once")
    check(scene.get_child_count() == baseline_nodes and get_nodes_in_group("enemy").size() == baseline_enemies and scene.story_flags == baseline_state, "80 cache cycles leave source tree groups and progress untouched")
    check(pref.config_reads - before_config_reads == 32 and pref.config_entry_rechecks - before_entry_rechecks == 128, "80 cycles reload only after 16 leave-range batches and recheck other entrances")
    runtime_probe.capture("settled", scene)
    check(runtime_probe.samples.size() == 82, "trend records baseline, all 80 cycles and settled retirement")
    var trend: Dictionary = runtime_probe.summary()
    runtime_probe = null
    churn = {"runtime_trend":trend,"cycles":80,"builds":pref.gameplay.builds-before_builds,"releases":pref.gameplay.releases-before_releases,"config_reads":pref.config_reads-before_config_reads,"validation_steps":pref.config_validation_steps-before_validation_steps,"entry_rechecks":pref.config_entry_rechecks-before_entry_rechecks,"elapsed_usec":Time.get_ticks_usec()-churn_started,"final":pref.snapshot(),"memory_soak":false}
func run() -> void:
    diagnostic_started = Time.get_ticks_msec()
    diagnostic_stage_started = diagnostic_started
    stage("startup")
    root.process_mode = Node.PROCESS_MODE_DISABLED
    for suffix in ["",".bak",".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE+suffix))
    scene = load("res://scenes/World.tscn").instantiate()
    scene.world_resume = false
    scene.world_save_path = SAVE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene = scene
    await frames(2)
    stage("invalid_descriptors")
    invalid_descriptors()
    stage("shared_metadata")
    verify_shared_metadata_cache()
    for id in COORD.manifest().regions:
        var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROUTES.config_path(id)))
        await landing(id,Vector2(raw.player_start[0],raw.player_start[1]))
    for id in COORD.manifest().regions:
        var raw := ROUTES.apply_to(JSON.parse_string(FileAccess.get_file_as_string(ROUTES.config_path(id))))
        for portal in raw.interactives:
            if String(portal.get("kind","")) == "world_portal":
                await landing(String(portal.target_config_id),Vector2(portal.target_spawn[0],portal.target_spawn[1]))
    # All regions/portal landings are covered above. Add the two categories
    # outside those landing windows without repeating entire-region rebuilds.
    var authored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROUTES.config_path("demo_ch01_moss_bell_court")))
    for data in authored.interactives:
        if String(data.get("kind","")) in ["lever","boss_gate"]:
            await landing("demo_ch01_moss_bell_court",Vector2(data.position[0],data.position[1]))
    for kind in ["enemy","npc","save_point","lever","boss_gate","world_portal"]: check(observed.has(kind), "canonical fixtures cover " + kind)
    await invalidation()
    await two_neighbors()
    await cancellation()
    stage("teardown")
    var stats: Dictionary = scene.world_prefetch.snapshot()
    scene.free()
    current_scene = null
    await frames(2)
    # Rendered frames are not AudioServer mix ticks. The production teardown
    # already retires voices; assert that their weakly tracked ownership ends.
    check(await preload("res://scripts/audio_retirement.gd").drain(self, 1000), "AudioServer releases retired gameplay playback before shutdown")
    for suffix in ["",".bak",".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE+suffix))
    stage("complete")
    print("NEIGHBOR GAMEPLAY METRICS ",JSON.stringify({"landings":metrics,"final":stats,"churn":churn,"fixture_positioning":true,"combat_acceptance":false}))
    for message in failures: push_error(message)
    print("WORLD_NEIGHBOR_GAMEPLAY checks=%d failures=%d" % [checks,failures.size()])
    quit(0 if failures.is_empty() else 1)
