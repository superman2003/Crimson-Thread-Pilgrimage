extends SceneTree
## Pure planner/cache fixtures. No scene assets, natural route, FPS or frame-time
## claim: timings compare the old synchronous oracle with bounded planner calls.
const GAMEPLAY := preload("res://scripts/world_gameplay_prefetch.gd")
const JOB := preload("res://scripts/world_gameplay_plan_job.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const VALIDATOR := preload("res://scripts/world_config_validator.gd")
const SOURCE_PATH := "res://data/demo_ch01_moss_bell_court.json"
const OTHER_PATH := "res://data/demo_ch02_rain_foundry_canal.json"
const REGION := "planner_fixture"
const STEP_CAP := 32
const COPY_EDGE_CAP := 64
const SCENARIO_LIMIT := 100000

class FixtureHost:
    extends Node
    var calls := 0
    var received: Array = []
    func _create_gameplay_prefab(kind: String, data: Dictionary, _config: Dictionary) -> Area2D:
        calls += 1
        received.append({"kind": kind, "data": data})
        var actor := Area2D.new()
        actor.set_meta("descriptor", data)
        actor.add_child(Node.new())
        return actor

var checks := 0
var failures: Array[String] = []
var metrics: Array = []
var cancellation_cases := 0
var lease_cases := 0
var authored_landings := 0
var accepted_duplicate_cases := 0
var fixture_host: FixtureHost

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)
        print("GAMEPLAY PLAN FAIL ", label)

func _equal(left: Variant, right: Variant) -> bool:
    # Dictionary/Array == has an engine recursion ceiling; deep-copy fixtures
    # need exact comparison without treating recursion diagnostics as a pass.
    var pending: Array = [[left, right]]
    while not pending.is_empty():
        var pair: Array = pending.pop_back()
        var a: Variant = pair[0]
        var b: Variant = pair[1]
        if a is Dictionary:
            if not b is Dictionary or a.size() != b.size(): return false
            for key in a:
                if not b.has(key): return false
                pending.append([a[key], b[key]])
        elif a is Array:
            if not b is Array or a.size() != b.size(): return false
            for index in a.size(): pending.append([a[index], b[index]])
        elif a != b:
            return false
    return true

func _descriptor(id: String, point: Vector2, kind: String = "moss_larva") -> Dictionary:
    return {"id": id, "position": [point.x, point.y], "kind": kind,
        "payload": {"dialogue": [{"text": id}], "values": [1, 2, 3]}}

func _configuration(count: int = 20) -> Dictionary:
    var config := {"enemy_spawns": [], "npcs": [], "save_points": [], "interactives": [],
        "ai_profiles": {"moss_larva": {"commands": [{"delay": 0.2, "pattern": [1, 2, 3]}]}}}
    for index in count:
        var point := Vector2(index % 32, (index / 32) % 24)
        for field in GAMEPLAY.FIELDS:
            var kind := "lever" if field == "interactives" else "moss_larva"
            config[field].append(_descriptor("%s_%05d" % [field, index], point, kind))
    return config

func _deep_configuration() -> Dictionary:
    var config := _configuration(8)
    for field in GAMEPLAY.FIELDS:
        for descriptor in config[field]:
            var chain: Dictionary = descriptor.payload
            for index in 48:
                chain["nested"] = {"depth": index, "array": [index, {"value": index}]}
                chain = chain.nested
            for index in 1024:
                descriptor.payload.values.append({"index": index, "text": "bounded winner payload"})
    return config

func _run_job(config: Dictionary, entry: Vector2, label: String) -> RefCounted:
    var started := Time.get_ticks_usec()
    var expected: Array = GAMEPLAY.plan(config, entry)
    var baseline_usec := Time.get_ticks_usec() - started
    var job := JOB.new()
    started = Time.get_ticks_usec()
    job.begin(config, entry)
    var begin_usec := Time.get_ticks_usec() - started
    _check(not job.done and job.result.is_empty() and job.operation_count == 0, label + " begin does no candidate work or publication")
    var zero_before: int = job.operation_count
    _check(job.step(0) == 0 and job.operation_count == zero_before, label + " zero allowance yields without work")
    var bounded := true
    var private_until_done := true
    var no_copy_during_scan := true
    var accounted := true
    var max_step_usec := 0
    var ordinary_max_step_usec := 0
    var compatibility_max_step_usec := 0
    var phase_timings: Dictionary = {}
    var total_step_usec := 0
    var slices := 0
    var phases: Dictionary = {}
    while not job.done and slices < SCENARIO_LIMIT:
        var phase := String(job.phase)
        phases[phase] = true
        var operations: int = job.operation_count
        var scanned: int = job.scanned_count
        var compatibility_scanned: int = job.compatibility_scanned
        var edges: int = job.copy_edges
        started = Time.get_ticks_usec()
        var consumed: int = job.step(1)
        var elapsed := Time.get_ticks_usec() - started
        total_step_usec += elapsed
        max_step_usec = maxi(max_step_usec, elapsed)
        if phase == "compatibility_sort": compatibility_max_step_usec = maxi(compatibility_max_step_usec, elapsed)
        else: ordinary_max_step_usec = maxi(ordinary_max_step_usec, elapsed)
        if not phase_timings.has(phase): phase_timings[phase] = {"operations": 0, "total_usec": 0, "max_usec": 0}
        phase_timings[phase].operations += consumed
        phase_timings[phase].total_usec += elapsed
        phase_timings[phase].max_usec = maxi(phase_timings[phase].max_usec, elapsed)
        bounded = bounded and consumed <= 1 and consumed >= 0 and job.scanned_count - scanned <= 1 and job.compatibility_scanned - compatibility_scanned <= 1 and job.copy_edges - edges <= COPY_EDGE_CAP
        accounted = accounted and job.operation_count - operations == consumed
        private_until_done = private_until_done and (job.done or job.result.is_empty())
        if phase in ["scan", "compatibility_scan", "compatibility_sort"]: no_copy_during_scan = no_copy_during_scan and job.copy_edges == edges
        slices += 1
    _check(job.done and not job.cancelled and job.phase == "done", label + " completes bounded work")
    _check(bounded and accounted and job.max_step_operations <= 1, label + " each slice obeys declared operation/scan/copy admission; compatibility sort is nonpreemptible")
    _check(private_until_done and no_copy_during_scan, label + " publishes atomically after winner copying")
    _check(job.result.size() <= GAMEPLAY.MAX_PER_REGION and job.max_retained_candidates <= GAMEPLAY.MAX_PER_REGION, label + " keeps category/global limits")
    _check(_equal(job.result, expected), label + " exact ordered descriptor parity with static oracle")
    var completed_operations: int = job.operation_count
    _check(job.step(8) == 0 and job.operation_count == completed_operations, label + " completed job cannot redo work")
    metrics.append({"scenario": label, "baseline_plan_usec": baseline_usec,
        "candidate_begin_usec": begin_usec, "candidate_step_total_usec": total_step_usec,
        "candidate_max_one_operation_usec": max_step_usec, "ordinary_max_one_operation_usec": ordinary_max_step_usec,
        "compatibility_max_sort_operation_usec": compatibility_max_step_usec, "compatibility_sorts": job.compatibility_sorts,
        "compatibility_scanned": job.compatibility_scanned, "max_compatibility_candidates": job.max_compatibility_candidates, "phase_timings": phase_timings, "slices": slices,
        "operations": job.operation_count, "scanned": job.scanned_count,
        "copy_edges": job.copy_edges, "max_retained_candidates": job.max_retained_candidates, "winners": job.result.size(), "phases": phases.keys()})
    return job

func _authored_parity() -> void:
    var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROUTES.ROUTES_PATH))
    var prepared: Dictionary = {}
    for id in manifest.chapters:
        var path := ROUTES.config_path(String(id))
        var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
        var entry := Vector2(raw.player_start[0], raw.player_start[1])
        var validator := VALIDATOR.new()
        validator.begin(raw, path, entry)
        var operations := 0
        while not validator.done and operations < SCENARIO_LIMIT:
            validator.step()
            operations += 1
        _check(validator.done and not validator.result.is_empty(), String(id) + " canonical fixture validates")
        if validator.result.is_empty(): continue
        prepared[id] = validator.result
        _run_job(validator.result, entry, String(id) + ":player_start")
    _check(prepared.size() == 6, "all six authored configurations covered")
    for source in prepared:
        for portal in prepared[source].get("interactives", []):
            if String(portal.get("kind", "")) != "world_portal": continue
            var target := String(portal.get("target_config_id", ""))
            var landing: Array = portal.get("target_spawn", [])
            _check(prepared.has(target) and landing.size() == 2, "authored portal has a known landing " + String(portal.id))
            if not prepared.has(target) or landing.size() != 2: continue
            _run_job(prepared[target], Vector2(landing[0], landing[1]), String(source) + ":" + String(portal.id))
            authored_landings += 1
    _check(authored_landings >= 68, "every authored world portal landing covered, including same-region returns")

func _synthetic_parity() -> void:
    _run_job({}, Vector2.ZERO, "empty_configuration")
    var excluded := {"enemy_spawns": [{"id": "missing_position"}, {"id": "bad_tuple", "position": [0]}, {"position": [0, 0]}],
        "interactives": []}
    for kind in ["chest", "pickup", "door", "story_trigger", ""]:
        excluded.interactives.append(_descriptor(kind + "_excluded", Vector2.ZERO, kind))
    _run_job(excluded, Vector2.ZERO, "excluded_kinds_and_incomplete_descriptors")
    var boundaries := {"npcs": []}
    for index in 8:
        var points := [-GAMEPLAY.HALF, Vector2(-GAMEPLAY.HALF.x, 0), Vector2(0, -GAMEPLAY.HALF.y),
            GAMEPLAY.HALF, Vector2(GAMEPLAY.HALF.x, 0), Vector2(0, GAMEPLAY.HALF.y), Vector2(1281, 901), Vector2(-1281, -901)]
        boundaries.npcs.append(_descriptor("edge_%d" % index, points[index]))
    var edge_job := _run_job(boundaries, Vector2.ZERO, "half_open_window_edges")
    _check(edge_job.result.size() == 3, "left/top edges included and right/bottom edges excluded")
    var ties := _configuration(0)
    for field in GAMEPLAY.FIELDS:
        for index in range(24, -1, -1):
            ties[field].append(_descriptor("tie_%02d" % index, Vector2(-100 if index % 2 else 100, 0), "world_portal" if field == "interactives" else "moss_larva"))
    var tie_job := _run_job(ties, Vector2.ZERO, "equal_distance_distinct_keys")
    _check(tie_job.result.size() == 12, "all four category quotas saturated")
    var identical := {"enemy_spawns": []}
    for index in 40: identical.enemy_spawns.append(_descriptor("duplicate", Vector2.ZERO))
    _run_job(identical, Vector2.ZERO, "duplicate_identical_descriptors")
    # Repeated raw IDs are rejected, but overlays are appended AFTER identity
    # validation. Preserve the oracle's unstable equal-key ordering rather
    # than assuming all accepted prepared snapshots have unique keys.
    var different := _configuration(0)
    for field in GAMEPLAY.FIELDS:
        for index in 40:
            var descriptor := _descriptor("duplicate", Vector2.ZERO, "lever" if field == "interactives" else "moss_larva")
            descriptor["ordinal"] = index
            different[field].append(descriptor)
    var duplicate_job := _run_job(different, Vector2.ZERO, "duplicate_different_payload_all_categories")
    _check(duplicate_job.compatibility_sorts == 4 and duplicate_job.max_compatibility_candidates == 40, "ambiguous equal-key payloads explicitly use legacy category sorts")
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE_PATH))
    for field in GAMEPLAY.FIELDS:
        var malformed: Dictionary = raw.duplicate(true)
        var duplicate: Dictionary = malformed[field][0].duplicate(true)
        duplicate["payload"] = {"different": true}
        malformed[field].append(duplicate)
        var validator := VALIDATOR.new()
        validator.begin(malformed, SOURCE_PATH, Vector2(raw.player_start[0], raw.player_start[1]))
        for unused in SCENARIO_LIMIT:
            if validator.done: break
            validator.step()
        _check(validator.done and validator.result.is_empty() and not validator.error.is_empty(), field + " raw duplicate IDs are rejected before route overlay")
    var large := {"enemy_spawns": []}
    for index in 12000:
        large.enemy_spawns.append(_descriptor("large_%05d" % (11999 - index), Vector2((index * 53) % 2001 - 1000, (index * 19) % 1601 - 800)))
    var large_job := _run_job(large, Vector2.ZERO, "large_12000_candidate_list")
    _check(large_job.scanned_count == 12000 and large_job.candidate_count == 12000 and large_job.max_retained_candidates == 4 and large_job.copy_edges < 100 and large_job.compatibility_sorts == 0 and large_job.result.size() == 4, "large list visits every candidate and retains only four winners")
    var deep := _deep_configuration()
    var deep_job := _run_job(deep, Vector2.ZERO, "deep_wide_payloads")
    _check(deep_job.copy_edges > 12000, "deep winner payload spans many bounded copy slices")
    var source_before: Dictionary = deep.duplicate(true)
    deep_job.result[0].data.payload.values[0] = "changed copy"
    deep_job.result[0].data.position[0] = 9000
    _check(_equal(deep, source_before), "nested result mutation cannot change source descriptors")
    var result_before: Array = deep_job.result.duplicate(true)
    deep.enemy_spawns[0].payload.dialogue[0].text = "changed source"
    deep.npcs[0].payload.values.clear()
    _check(_equal(deep_job.result, result_before), "nested source mutation cannot change completed defensive result")
    var batched := JOB.new()
    batched.begin(_configuration(), Vector2.ZERO)
    var bounded := true
    for unused in SCENARIO_LIMIT:
        if batched.done: break
        var before: int = batched.operation_count
        var used: int = batched.step(STEP_CAP)
        bounded = bounded and used <= STEP_CAP and batched.operation_count - before == used
    _check(batched.done and bounded and batched.max_step_operations <= STEP_CAP, "caller-selected multi-operation admission stays bounded")

func _validate_fixture(raw: Dictionary, entry: Vector2, label: String) -> Dictionary:
    var validator := VALIDATOR.new()
    validator.begin(raw, SOURCE_PATH, entry)
    for unused in SCENARIO_LIMIT:
        if validator.done: break
        validator.step()
    _check(validator.done and not validator.result.is_empty(), label + " remains accepted by canonical validator")
    return validator.result

func _accepted_duplicate_parity() -> void:
    var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE_PATH))
    var portal: Dictionary = ROUTES.overlay_bundle(String(base.id)).overlay.portals[0]
    var entry := Vector2(portal.position[0], portal.position[1])
    # At 28 fillers this accepted raw+overlay pair previously reversed its
    # payload order compared with the original full-array sort_custom oracle.
    for filler_count in [1, 16, 28, 40, 64]:
        var raw: Dictionary = base.duplicate(true)
        for field in GAMEPLAY.FIELDS: raw[field] = []
        for index in filler_count:
            var filler := _descriptor("zzzz_%03d" % index, entry, "world_portal")
            filler["origin"] = "raw_filler"
            raw.interactives.append(filler)
        var duplicate: Dictionary = portal.duplicate(true)
        duplicate["origin"] = "raw_duplicate"
        duplicate["payload"] = {"nested": ["raw differs from authored overlay"]}
        raw.interactives.insert(filler_count / 2, duplicate)
        var prepared := _validate_fixture(raw, entry, "overlay duplicate %d" % filler_count)
        if prepared.is_empty(): continue
        _check(prepared.interactives.filter(func(item): return item.id == portal.id).size() == 2, "accepted route overlay really contains both equal-key payloads")
        var job := _run_job(prepared, entry, "accepted_raw_overlay_duplicate_%d" % filler_count)
        _check(job.compatibility_sorts == 1, "accepted overlay tie explicitly reports its unpreemptible compatibility sort")
        _check(job.result.filter(func(item): return item.key == "world_portal:" + String(portal.id)).size() == 2, "accepted duplicate keeps both selected payloads")
        accepted_duplicate_cases += 1
    var raw: Dictionary = base.duplicate(true)
    for field in GAMEPLAY.FIELDS: raw[field] = []
    # IDs are unique inside each field, yet the interactive kind can produce
    # the same output key as a source enemy. Preserve final-sort tie order too.
    for index in 4:
        var enemy := _descriptor("cross_%02d" % index, entry)
        enemy["origin"] = "enemy_field"
        raw.enemy_spawns.append(enemy)
        if index < 3:
            var interactive := _descriptor("cross_%02d" % index, entry, "enemy")
            interactive["origin"] = "interactive_field"
            raw.interactives.append(interactive)
    for index in 3: raw.npcs.append(_descriptor("npc_%d" % index, entry))
    for index in 2: raw.save_points.append(_descriptor("save_%d" % index, entry))
    var prepared := _validate_fixture(raw, entry, "cross-field key ties")
    if not prepared.is_empty():
        var job := _run_job(prepared, entry, "accepted_cross_field_equal_key_payloads")
        _check(job.result.size() == 12 and job.result.filter(func(item): return item.key == "enemy:cross_00").size() == 2, "cross-field duplicate keys retain both payloads inside all category quotas")
        accepted_duplicate_cases += 1

func _reach_phase(job: RefCounted, phase: String) -> bool:
    for unused in SCENARIO_LIMIT:
        if job.phase == phase: return true
        if job.done: return false
        job.step(1)
    return false

func _pause_for_cancellation(job: RefCounted, phase: String) -> bool:
    if not _reach_phase(job, phase): return false
    if phase == "scan":
        while job.scanned_count < 2 and job.phase == phase: job.step(1)
        return job.phase == phase and job.scanned_count >= 2
    if phase == "compatibility_scan":
        while job.compatibility_scanned < 2 and job.phase == phase: job.step(1)
        return job.phase == phase and job.compatibility_scanned >= 2
    if phase == "copy":
        while job.copy_edges < COPY_EDGE_CAP * 2 and job.phase == phase: job.step(1)
        return job.phase == phase and job.copy_edges >= COPY_EDGE_CAP * 2
    return job.phase == phase

func _pure_cancellation() -> void:
    for phase in ["scan", "copy", "publish", "compatibility_scan", "compatibility_sort"]:
        var job := JOB.new()
        var config := _deep_configuration()
        if phase.begins_with("compatibility"):
            config = _configuration(0)
            for index in 80:
                var descriptor := _descriptor("repeated", Vector2.ZERO)
                descriptor["ordinal"] = index
                config.enemy_spawns.append(descriptor)
        job.begin(config, Vector2.ZERO)
        _check(_pause_for_cancellation(job, phase), "pure cancel fixture reaches actual work in " + phase)
        _check(job.result.is_empty() and not job.done, "pure " + phase + " result remains private")
        job.cancel()
        var before: int = job.operation_count
        _check(job.cancelled and job.result.is_empty() and job.step(100) == 0 and job.operation_count == before, "cancel in " + phase + " cannot resume or publish")
        job.cancel()
        _check(job.result.is_empty(), "cancel in " + phase + " is idempotent")
        job.begin(_configuration(1), Vector2.ZERO)
        _check(not job.cancelled and job.result.is_empty(), "cancelled helper can start a clean new job")
        _check(_reach_phase(job, "done") and job.result == GAMEPLAY.plan(_configuration(1), Vector2.ZERO), "retry after " + phase + " cannot inherit stale candidates")
        cancellation_cases += 1

func _lease(config: Dictionary) -> Dictionary:
    return {"desired": {REGION: {"path": SOURCE_PATH, "entry": Vector2.ZERO}},
        "configs": {REGION: {"raw": {"id": REGION}, "prepared": config,
            "stamp": FileAccess.get_modified_time(SOURCE_PATH)}}, "generation": 10}

func _new_cache(lease: Dictionary) -> RefCounted:
    var cache := GAMEPLAY.new()
    cache.synchronize(lease.desired, lease.configs, lease.generation)
    _check(cache.regions.has(REGION) and not cache.regions[REGION].plan_complete and cache.regions[REGION].pending.is_empty(), "synchronize creates a private unscheduled plan")
    _check(cache.plan_operations == 0 and cache.builds == 0, "synchronize does not scan/copy/create gameplay")
    return cache

func _warm_to_phase(cache: RefCounted, phase: String) -> RefCounted:
    var job: RefCounted = cache.regions[REGION].plan_job
    # Drive the real helper one operation at a time so invalidation can land
    # exactly at the requested boundary, without pretending this is gameplay.
    _check(_pause_for_cancellation(job, phase), "lease fixture reaches actual work in " + phase)
    _check(not cache.regions[REGION].plan_complete and cache.regions[REGION].pending.is_empty() and cache.owned() == 0, phase + " cannot expose partial pending actors")
    return job

func _lease_cancellation() -> void:
    for phase in ["scan", "copy", "publish"]:
        for change in ["generation", "entry", "path", "record_path", "stamp", "record", "raw", "prepared", "raw_empty", "removed", "leave_range", "shutdown"]:
            var lease := _lease(_deep_configuration())
            var cache := _new_cache(lease)
            var stale := _warm_to_phase(cache, phase)
            var calls_before := fixture_host.calls
            var cancellations_before: int = cache.plan_cancellations
            match change:
                "generation": lease.generation += 1
                "entry": lease.desired[REGION].entry += Vector2(1, 0)
                "path": lease.desired[REGION].path = OTHER_PATH
                "record_path": lease.configs[REGION]["path"] = OTHER_PATH
                "stamp": lease.configs[REGION].stamp = -1
                "record": lease.configs[REGION] = lease.configs[REGION].duplicate(true)
                "raw": lease.configs[REGION].raw = lease.configs[REGION].raw.duplicate(true)
                "prepared": lease.configs[REGION].prepared = lease.configs[REGION].prepared.duplicate(true)
                "raw_empty": lease.configs[REGION].raw = {}
                "removed": lease.configs.erase(REGION)
                "leave_range": lease.desired.clear()
                "shutdown": cache.shutdown()
            if change == "generation":
                cache.synchronize(lease.desired, lease.configs, lease.generation)
            elif change != "shutdown":
                # warm() must recheck the held lease even if maps changed after
                # synchronize() and immediately before atomic publication.
                cache.warm(fixture_host, Time.get_ticks_usec(), 2)
            _check(stale.cancelled and stale.result.is_empty() and stale.step(100) == 0, "%s/%s stale helper cannot finish" % [phase, change])
            _check(cache.plan_cancellations == cancellations_before + 1 and cache.builds == 0 and fixture_host.calls == calls_before, "%s/%s invalidation cancels before any prefab construction" % [phase, change])
            _check(cache.owned() == 0 and cache.snapshot().pending == 0, "%s/%s leaves no partial publication or detached node" % [phase, change])
            cache.shutdown()
            lease_cases += 1

func _finish_cache(cache: RefCounted, allowance: int = 2) -> bool:
    var bounded := true
    var no_partial_nodes := true
    for unused in SCENARIO_LIMIT:
        var before: int = cache.builds
        cache.warm(fixture_host, Time.get_ticks_usec(), allowance)
        bounded = bounded and cache.last_plan_operations <= STEP_CAP and cache.builds - before <= allowance and cache.owned() <= GAMEPLAY.MAX_TOTAL
        no_partial_nodes = no_partial_nodes and cache.regions.values().all(func(region): return region.plan_complete or region.actors.is_empty())
        var complete: bool = cache.regions.values().all(func(region): return region.plan_complete and region.pending.is_empty())
        if complete:
            _check(bounded and no_partial_nodes and cache.max_plan_operations <= STEP_CAP, "runtime shares bounded planning/create admission and <=24 ownership")
            return true
    _check(false, "cache finishes before deterministic operation limit")
    return false

func _runtime_publication() -> void:
    var config := _deep_configuration()
    var lease := _lease(config)
    var cache := _new_cache(lease)
    var retained_job: RefCounted = cache.regions[REGION].plan_job
    cache.warm(fixture_host, Time.get_ticks_usec(), 0)
    var retained_operations: int = retained_job.operation_count
    cache.synchronize(lease.desired, lease.configs, lease.generation)
    _check(is_same(cache.regions[REGION].plan_job, retained_job) and retained_job.operation_count == retained_operations and retained_operations > 0 and cache.last_plan_operations == 0, "unchanged synchronize keeps the in-progress job without rescanning")
    var source_children := fixture_host.get_child_count()
    var calls_before := fixture_host.calls
    var premature := false
    var bounded := true
    for unused in SCENARIO_LIMIT:
        var old_complete: bool = cache.regions[REGION].plan_complete
        cache.warm(fixture_host, Time.get_ticks_usec(), 0)
        bounded = bounded and cache.last_plan_operations <= STEP_CAP
        premature = premature or (not cache.regions[REGION].plan_complete and not cache.regions[REGION].pending.is_empty())
        _check(cache.builds == 0 and fixture_host.calls == calls_before, "zero actor allowance never constructs nodes during planning")
        if cache.regions[REGION].plan_complete:
            _check(not old_complete, "runtime completion is observed as a single publication")
            break
    _check(cache.regions[REGION].plan_complete and not premature and bounded, "planning completes independently with zero actor allowance")
    _check(_equal(cache.regions[REGION].pending, GAMEPLAY.plan(config, Vector2.ZERO)) and cache.plan_completions == 1, "runtime publishes complete exact oracle result once")
    _check(cache.snapshot().planning == 0 and cache.snapshot().pending == 12, "snapshot distinguishes planning from ready actor queue")
    _check(_finish_cache(cache), "published queue creates all selected actors")
    var actors: Dictionary = cache.regions[REGION].actors
    _check(actors.size() == 12 and fixture_host.get_child_count() == source_children, "detached prebuild leaves source tree unchanged")
    var actor_ids: Array = []
    for record in actors.values():
        actor_ids.append(record.actor.get_instance_id())
        _check(not record.actor.is_inside_tree() and record.actor.get_parent() == null and record.actor.get_child_count() == 1, "planned actor is fully detached until adoption")
    var first: Dictionary = actors.values()[0]
    first.data.payload.dialogue[0].text = "actor local mutation"
    _check(config.enemy_spawns[0].payload.dialogue[0].text != "actor local mutation", "actor descriptor cannot mutate configuration")
    var enemy: Dictionary = actors["enemy:enemy_spawns_00000"]
    config.ai_profiles.moss_larva.commands[0].pattern[0] = 777
    _check(enemy.profile.commands[0].pattern[0] == 1, "enemy profile lease is defensively isolated")
    var wrong: Dictionary = enemy.data.duplicate(true)
    wrong.position[0] += 1
    _check(cache.take(REGION, "enemy", wrong, enemy.profile) == null, "mismatched descriptor cannot take prepared actor")
    var taken: Area2D = cache.take(REGION, "enemy", enemy.data, enemy.profile)
    _check(taken == enemy.actor and cache.take(REGION, "enemy", enemy.data, enemy.profile) == null, "actor lease transfers exactly once")
    taken.free()
    var before: int = cache.releases
    cache.clear()
    while cache.owned() > 0:
        var released: int = cache.releases
        cache.retire(Time.get_ticks_usec(), 2)
        _check(cache.releases - released <= 2 and cache.owned() <= 24, "detached retirement honors shared two-operation allowance")
    _check(cache.releases - before == 11 and actor_ids.all(func(id): return not is_instance_id_valid(id)), "all created instances retire or transfer exactly once")
    cache.shutdown()
    cache.shutdown()
    _check(cache.owned() == 0 and cache.regions.is_empty(), "cache shutdown is idempotent")

func _duplicate_actor_ownership() -> void:
    var config := _configuration(0)
    for index in 2:
        var descriptor := _descriptor("same_lever", Vector2.ZERO, "lever")
        descriptor["ordinal"] = index
        config.interactives.append(descriptor)
    var expected: Array = GAMEPLAY.plan(config, Vector2.ZERO)
    for disposal in ["adopt", "shutdown", "saturated"]:
        var lease := _lease(config)
        var cache := _new_cache(lease)
        var reserve := 22 if disposal == "saturated" else 0
        var reserved_ids: Array = []
        for unused in reserve:
            var reserved := Area2D.new()
            reserved_ids.append(reserved.get_instance_id())
            cache.retiring.append(reserved)
        var calls_before := fixture_host.calls
        _check(_finish_cache(cache), "duplicate winners finish under shared creation admission")
        _check(cache.builds == 2 and fixture_host.calls - calls_before == 2 and cache.regions[REGION].actors.size() == 1 and cache.retiring.size() == reserve + 1 and cache.owned() == reserve + 2, "superseded duplicate actor remains owned on the retirement queue")
        var record: Dictionary = cache.regions[REGION].actors["lever:same_lever"]
        var latest: Area2D = record.actor
        var superseded: Node = cache.retiring.back()
        var ids := [latest.get_instance_id(), superseded.get_instance_id()]
        _check(latest != superseded and _equal(record.data, expected.back().data) and _equal(latest.get_meta("descriptor"), expected.back().data), "last oracle-sorted duplicate descriptor and instance remain adoptable")
        _check(cache.max_owned <= GAMEPLAY.MAX_TOTAL and cache.owned() <= GAMEPLAY.MAX_TOTAL, "duplicate replacement includes retiring instances in capacity")
        if disposal == "adopt":
            var adopted: Area2D = cache.take(REGION, "lever", expected.back().data)
            _check(adopted == latest and cache.owned() == 1 and is_instance_valid(superseded), "taking last duplicate transfers only its instance and retains previous ownership")
            var released: int = cache.retire(Time.get_ticks_usec(), 2)
            _check(released == 1 and not is_instance_id_valid(ids[1]) and is_instance_valid(adopted), "normal bounded retirement frees superseded actor without freeing adopted winner")
            adopted.free()
        cache.shutdown()
        _check(cache.owned() == 0 and ids.all(func(id): return not is_instance_id_valid(id)) and reserved_ids.all(func(id): return not is_instance_id_valid(id)), "duplicate teardown leaves no orphaned winner or superseded instance")

func _capacity_and_deadline() -> void:
    var lease := _lease(_configuration())
    var cache := _new_cache(lease)
    var operations: int = cache.plan_operations
    var calls_before := fixture_host.calls
    cache.warm(fixture_host, Time.get_ticks_usec() - GAMEPLAY.BUDGET_US - 1, 2)
    _check(cache.plan_operations == operations and fixture_host.calls == calls_before, "expired shared deadline admits no planning or actor creation")
    for unused in GAMEPLAY.MAX_TOTAL: cache.retiring.append(Area2D.new())
    for unused in SCENARIO_LIMIT:
        cache.warm(fixture_host, Time.get_ticks_usec(), 2)
        if cache.regions[REGION].plan_complete and cache.regions[REGION].art_ready: break
    _check(cache.regions[REGION].plan_complete and cache.regions[REGION].art_ready and cache.builds == 0 and cache.owned() == 24, "planning and artwork preparation progress under saturated ownership without allocating actors")
    var retired: int = cache.retire(Time.get_ticks_usec(), 2)
    var built: int = cache.warm(fixture_host, Time.get_ticks_usec(), 2)
    _check(retired == 2 and built == 2 and cache.owned() == 24, "retired capacity is reused without exceeding total actor ownership")
    cache.shutdown()
    _check(cache.owned() == 0 and cache.builds == 2, "saturated teardown frees retiring and cached actors")
    var two := _lease(_configuration())
    two.desired["second"] = two.desired[REGION].duplicate(true)
    two.configs["second"] = two.configs[REGION].duplicate(true)
    cache = _new_cache(two)
    var planning_bounded := true
    for unused in SCENARIO_LIMIT:
        cache.warm(fixture_host, Time.get_ticks_usec(), 0)
        planning_bounded = planning_bounded and cache.last_plan_operations <= STEP_CAP
        if cache.snapshot().planning == 0: break
    _check(cache.snapshot().planning == 0 and cache.snapshot().pending == 24 and cache.owned() == 0 and cache.builds == 0 and planning_bounded, "two neighbors both finish planning without actor allowance or region starvation")
    _check(_finish_cache(cache) and cache.owned() == 24 and cache.regions.size() == 2, "two neighboring plans share operation budget and fill at most 24 actors")
    cache.shutdown()
    _check(cache.owned() == 0, "two-neighbor teardown drains ownership")

func _run() -> void:
    fixture_host = FixtureHost.new()
    root.add_child(fixture_host)
    _authored_parity()
    _synthetic_parity()
    _accepted_duplicate_parity()
    _pure_cancellation()
    _lease_cancellation()
    _runtime_publication()
    _duplicate_actor_ownership()
    _capacity_and_deadline()
    fixture_host.free()
    print("GAMEPLAY PLAN METRICS ", JSON.stringify({"scope": "pure planner and detached mock-host fixtures; not natural play or FPS", "authored_configurations": 6,
        "authored_portal_landings": authored_landings, "accepted_duplicate_cases": accepted_duplicate_cases, "pure_cancellation_stages": cancellation_cases,
        "lease_cancellation_cases": lease_cases, "planning_operation_cap": STEP_CAP,
        "copy_edges_per_operation_cap": COPY_EDGE_CAP, "compatibility_sort_is_unpreemptible": true, "timings": metrics}))
    if failures.is_empty():
        print("WORLD_GAMEPLAY_PLAN checks=%d failures=0" % checks)
        quit(0)
    else:
        for failure in failures: push_error(failure)
        quit(1)
