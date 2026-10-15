extends SceneTree
## Acceptance for the incremental target preflight contract. The suite checks
## parity against fixed legacy error messages, bounded admission, and the
## source-isolation boundary before the loader starts a handoff.
const ROUTES := preload("res://scripts/world_routes.gd")
const COORD := preload("res://scripts/world_coordinates.gd")
const VALIDATOR := preload("res://scripts/world_config_validator.gd")
const LOADER := preload("res://scripts/world_region_loader.gd")
const STATE := preload("res://scripts/world_state.gd")
const INCREMENTAL_COPY := preload("res://scripts/world_variant_copy_job.gd")
const ROUTE_OVERLAY_JOB := preload("res://scripts/world_route_overlay_job.gd")
const SAVE := "user://world_preflight_budget_validation.json"
const REGIONS := ["demo_ch01_moss_bell_court", "demo_ch02_rain_foundry_canal",
	"demo_ch03_saltwhite_archive", "demo_ch04_broken_string_greenhouse",
	"demo_ch05_obsidian_pilgrim_road", "demo_ch06_silent_crown_core"]
var checks := 0
var failures: Array[String] = []
var scene: Node
var _observer_loader: Variant
var _observer_triggered := false
var _observer_saw_final := false
var _observer_mode := "mid"
var _operation_done := false
var _operation_result := false
var _synthetic_source_size := -1

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for region_id in REGIONS:
		_validator_production_region(region_id)
	_validator_fixed_errors()
	_validator_synthetic_cursor()
	_incremental_copy_pathological()
	_route_overlay_pathological()
	await _loader_preflight_checks()
	await _pending_gap_check()
	await _passage_preflight_check()
	await _teardown_check()
	_cleanup()
	if failures.is_empty():
		print("WORLD PREFLIGHT BUDGET PASS checks=%d" % checks)
		quit(0)
	else:
		for failure in failures: push_error(failure)
		print("WORLD PREFLIGHT BUDGET FAIL checks=%d failures=%d" % [checks, failures.size()])
		quit(1)

func _validator_production_region(region_id: String) -> void:
	var path := ROUTES.config_path(region_id)
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var entry_array: Array = raw.get("player_start", [120, 500])
	var entry := Vector2(float(entry_array[0]), float(entry_array[1]))
	var validator = VALIDATOR.new()
	validator.begin(raw, path, entry)
	var sync_loader = LOADER.new()
	var legacy_started := Time.get_ticks_usec()
	var legacy_result: Dictionary = sync_loader.validate_config(raw, path, entry)
	var legacy_usec := Time.get_ticks_usec() - legacy_started
	var legacy_error: String = sync_loader.last_error
	var steps := 0
	var previous := 0.0
	var incremental_started := Time.get_ticks_usec()
	while true:
		var finished: bool = validator.step()
		_check(validator.progress >= previous, region_id + " validator progress is monotonic")
		previous = validator.progress
		if finished: break
		steps += 1
	var incremental_usec := Time.get_ticks_usec() - incremental_started
	_check(validator.error.is_empty(), region_id + " production raw config validates")
	_check(validator.result == legacy_result and validator.error == legacy_error, region_id + " sync loader validator matches incremental plan")
	_check(validator.progress == 1.0 and validator.done, region_id + " terminal validator progress is 1")
	_check(validator.result == ROUTES.apply_to(raw), region_id + " production config preserves route overlay")
	_check(Vector2(validator.result.world.width, validator.result.world.height) == COORD.region_bounds(region_id).size, region_id + " post-overlay dimensions match world coordinate manifest")
	_check(steps > 10, region_id + " validation traverses incremental operations")
	_check(validator.route_copy_steps > 10 and validator.max_route_copy_step_usec >= 0, region_id + " route snapshot copying yields across incremental batches")
	_check(validator.route_overlay_steps > 10 and validator.max_route_overlay_step_usec >= 0, region_id + " route overlay scans and appends over multiple validator steps")
	if region_id == REGIONS[0]:
		print("ROUTE CONFIG METRICS legacy_usec=%d incremental_cpu_usec=%d validator_steps=%d copy_batches=%d copy_begin_max_usec=%d copy_batch_max_usec=%d overlay_operations=%d overlay_begin_max_usec=%d overlay_batch_max_usec=%d" % [legacy_usec, incremental_usec, steps, validator.route_copy_steps, validator.max_route_copy_begin_usec, validator.max_route_copy_step_usec, validator.route_overlay_steps, validator.max_route_overlay_begin_usec, validator.max_route_overlay_step_usec])

func _incremental_copy_pathological() -> void:
	var rows: Array = []
	for row_index in range(90):
		var row: Array = []
		for column_index in range(80):
			row.append({"id": "%d:%d" % [row_index, column_index], "value": [row_index, column_index]})
		rows.append(row)
	var source := {"rows": rows, "metadata": {"flags": [true, false], "nested": {"name": "route-copy-fixture"}}}
	var copier: RefCounted = INCREMENTAL_COPY.new()
	copier.begin(source)
	var batches := 0
	while not copier.done:
		var visited: int = copier.step(512)
		_check(visited <= 512, "incremental copy respects its per-step edge limit")
		batches += 1
	var copied: Dictionary = copier.result
	_check(batches > 10 and copier.edge_count > 7000, "large nested dictionary/array snapshot spans bounded edge batches")
	_check(copied == source, "incremental nested snapshot preserves exact values")
	copied.rows[0][0].value[0] = -1
	copied.metadata.nested.name = "changed-copy"
	_check(source.rows[0][0].value[0] == 0 and source.metadata.nested.name == "route-copy-fixture", "incremental snapshot has detached nested ownership")

func _route_overlay_pathological() -> void:
	var rooms: Array = []
	var interactives: Array = []
	var room_overrides: Array = []
	var portals: Array = []
	var catalog: Dictionary = {}
	for index in range(64):
		rooms.append({"id": "room_%d" % index, "name": "base_%d" % index})
		room_overrides.append({"id": "room_%d" % index, "nested": {"rank": index}})
		interactives.append({"id": "remove_%d" % index})
		portals.append({"id": "portal_%d" % index, "destination": {"x": index, "y": -index}})
		catalog["item_%d" % index] = {"kind": "upgrade", "cost": [index, index + 1]}
	rooms.append({"id": "room_0", "name": "duplicate target"})
	interactives.append({"id": "5"})
	var config := {"world": {"base": true}, "map_rooms": rooms, "terrain": [], "platforms": [],
		"locked_gates": [], "collectibles": [], "grapple_anchors": [], "save_points": [],
		"interactives": interactives, "inventory": {"catalog": {"old": {"kind": "keep"}}}}
	var wide_world: Dictionary = {}
	for index in range(96): wide_world["bound_%d" % index] = index
	var overlay := {"world_overrides": wide_world, "map_room_overrides": room_overrides,
		"remove_interactives": ["remove_0", "remove_1", "remove_2", 5, "portal_0"], "portals": portals,
		"inventory_catalog": catalog}
	var job: RefCounted = ROUTE_OVERLAY_JOB.new()
	job.begin(config, overlay, 7)
	var steps := 0
	var max_step_usec := 0
	while not job.done:
		var step_started := Time.get_ticks_usec()
		job.step()
		max_step_usec = maxi(max_step_usec, Time.get_ticks_usec() - step_started)
		steps += 1
	var result: Dictionary = job.result
	_check(job.total_operations > 1000 and steps < job.total_operations and job.max_batch_operations <= 32 and job.edge_steps > 1000, "large overlay traverses bounded target lookup, arrays and nested values")
	_check(result.world.size() == 97 and result.world.get("bound_95") == 95, "wide world override is fully applied")
	_check(result.map_rooms[63].nested.rank == 63 and result.map_rooms[64].nested.rank == 0, "room overrides reach every matching identifier")
	_check(result.interactives.size() == 126 and result.interactives[61].id == "5" and result.interactives[62].id == "portal_0" and result.interactives[125].id == "portal_63", "interactive removals and portal append preserve legacy typed matching and order")
	_check(result.inventory.catalog.size() == 65 and result.inventory.catalog.item_63.cost == [63, 64], "nested inventory catalog overlay is copied")
	result.map_rooms[0].nested.rank = -1
	_check(result.map_rooms[64].nested.rank == 0, "multiple matching targets receive independent nested copies")
	_check(config == result, "overlay job returns the uniquely owned config it updated")
	_check(overlay.portals[63].destination.x == 63 and overlay.inventory_catalog.item_63.cost == [63, 64], "overlay output does not mutate the source manifest")
	_check(result.world_routes_version == 7, "nonempty overlay writes its manifest version")
	var empty_config := {"id": "outside_world", "world": {}, "interactives": []}
	var empty_job: RefCounted = ROUTE_OVERLAY_JOB.new()
	empty_job.begin(empty_config, {}, 7)
	_check(empty_job.done and empty_job.result == empty_config and not empty_job.result.has("world_routes_version"), "empty overlay is a legacy no-op")
	print("ROUTE OVERLAY PATHOLOGICAL batches=%d operations=%d max_ops_per_batch=%d max_batch_usec=%d edges=%d" % [steps, job.total_operations, job.max_batch_operations, max_step_usec, job.edge_steps])

func _validator_fixed_errors() -> void:
	var region_id := REGIONS[0]
	var path := ROUTES.config_path(region_id)
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var entry := Vector2(120, 500)
	var cases: Array[Dictionary] = []
	var bad = base.duplicate(true); bad["map_rooms"] = "bad"; cases.append({"raw": bad, "error": "目标区域缺少地形与房间记录。", "name": "header map_rooms type uses legacy header error"})
	bad = base.duplicate(true); bad["platforms"] = "bad"; cases.append({"raw": bad, "error": "目标区域的platforms记录无效。", "name": "platform field type"})
	bad = base.duplicate(true); bad["platforms"].append(17); cases.append({"raw": bad, "error": "目标区域的platforms条目无效。", "name": "platform record type"})
	bad = base.duplicate(true); bad["platforms"].append({"id":"nonfinite_fixture", "rect":[NAN, 0, 20, 20]}); cases.append({"raw": bad, "error": "目标区域的platforms坐标无效。", "name": "platform nonfinite generic coordinate precedes identity"})
	bad = base.duplicate(true); bad["terrain"][0]["surface"] = [[0, INF]]; cases.append({"raw": bad, "error": "目标区域地形轮廓坐标无效。", "name": "terrain point finite"})
	bad = base.duplicate(true); bad["enemy_spawns"][0]["position"] = [INF, 2]; cases.append({"raw": bad, "error": "目标区域的enemy_spawns坐标无效。", "name": "enemy generic coordinate precedes identity"})
	bad = base.duplicate(true); bad["enemy_spawns"][0]["id"] = 42; cases.append({"raw": bad, "error": "目标区域的enemy_spawns身份无效或重复。", "name": "enemy identity type"})
	bad = base.duplicate(true); bad["interactives"][0]["interaction_size"] = []; cases.append({"raw": bad, "error": "目标区域的interaction_size尺寸无效。", "name": "empty interaction size is invalid"})
	bad = base.duplicate(true); bad["interactives"].append(bad["interactives"][0].duplicate(true)); cases.append({"raw": bad, "error": "目标区域的interactives身份无效或重复。", "name": "duplicate interactive identity"})
	bad = base.duplicate(true); bad["enemy_spawns"][0]["body_size"] = []; _fixed_case(bad, "", "empty enemy body size retains legacy exception", path, entry)
	bad = base.duplicate(true); bad["terrain"].append(bad["terrain"][0].duplicate(true)); cases.append({"raw": bad, "error": "目标区域地形身份无效或重复。", "name": "duplicate terrain identity"})
	bad = base.duplicate(true); bad["terrain"][0]["depth"] = 0; cases.append({"raw": bad, "error": "目标区域地形厚度无效。", "name": "terrain depth positive"})
	bad = base.duplicate(true); bad["ai_profiles"] = []; cases.append({"raw": bad, "error": "目标区域的敌人行为记录无效。", "name": "profile container"})
	bad = base.duplicate(true); bad["cave_world"]["solid_rects"] = [[0,0,0,10]]; cases.append({"raw": bad, "error": "目标区域岩层坐标或尺寸无效。", "name": "cave rectangle dimensions"})
	for field in ["map_rooms", "platforms", "terrain", "locked_gates", "collectibles", "interactives", "npcs", "enemy_spawns", "save_points", "hazards", "grapple_anchors", "cave_lifts", "environment_blocks"]:
		bad = base.duplicate(true); bad[field] = "wrong type"
		var type_error := "目标区域缺少地形与房间记录。" if field == "map_rooms" else "目标区域的%s记录无效。" % field
		cases.append({"raw": bad, "error": type_error, "name": field + " requires its legacy array error"})
		bad = base.duplicate(true); bad[field] = base.get(field, []).duplicate(true); bad[field].append({"position":[0, NAN]})
		cases.append({"raw": bad, "error": "目标区域的%s坐标无效。" % field, "name": field + " finite coordinate tuple"})
	for field in ["enemy_spawns", "npcs", "save_points", "interactives"]:
		if not base.get(field, []).is_empty():
			bad = base.duplicate(true); bad[field].append(bad[field][0].duplicate(true))
			cases.append({"raw": bad, "error": "目标区域的%s身份无效或重复。" % field, "name": field + " duplicate identity"})
	for size_field in ["interaction_size", "body_size", "hurtbox_size"]:
		bad = base.duplicate(true)
		var record_field := "interactives" if size_field == "interaction_size" else "enemy_spawns"
		if not bad[record_field].is_empty():
			bad[record_field][0][size_field] = [0, 12]
			cases.append({"raw": bad, "error": "目标区域的%s尺寸无效。" % size_field, "name": size_field + " rejects nonpositive dimensions"})
	bad = base.duplicate(true); bad.platforms.append({"id":"overlay_duplicate_fixture", "rect":[0,0,20,20]})
	# An authored ID colliding with a route-injected platform is validated only
	# after apply_to; this raw collision uses an existing overlay ID when present.
	var overlay: Dictionary = ROUTES._data().get("chapters", {}).get(region_id, {})
	if not overlay.get("platforms", []).is_empty():
		bad = base.duplicate(true); bad.platforms.append(overlay.platforms[0].duplicate(true))
		cases.append({"raw": bad, "error": "目标区域的平台身份重复。", "name": "post-overlay duplicate platform identity"})
	for size_field in ["body_size", "hurtbox_size"]:
		bad = base.duplicate(true)
		bad["enemy_spawns"][0][size_field] = {}
		cases.append({"raw": bad, "name": "dictionary " + size_field,
			"error": "目标区域的%s尺寸无效。" % size_field})
	for item in cases:
		_fixed_case(item.raw, item.error, item.name, path, entry)
	# Route overlays are applied before world size and platform identity checks.
	var region_with_overlay := "demo_ch01_moss_bell_court"
	var overlay_path := ROUTES.config_path(region_with_overlay)
	var overlay_raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(overlay_path))
	var overlay_validator = VALIDATOR.new()
	overlay_validator.begin(overlay_raw, overlay_path, entry)
	while not overlay_validator.step(): pass
	_check(overlay_validator.result == ROUTES.apply_to(overlay_raw), "post-overlay output is exact")

func _fixed_case(raw: Variant, expected: String, label: String, path: String, entry: Vector2) -> void:
	var validator = VALIDATOR.new()
	validator.begin(raw, path, entry)
	while not validator.step(): pass
	_check(validator.error == expected, label + " matches frozen legacy diagnostic; got=" + validator.error)
	_check((expected.is_empty() and not validator.result.is_empty()) or (not expected.is_empty() and validator.result.is_empty()), label + " success/failure result shape")
	_check(validator.progress == 1.0, label + " terminal progress")

func _validator_synthetic_cursor() -> void:
	var region_id := REGIONS[0]
	var path := ROUTES.config_path(region_id)
	var raw: Dictionary = _make_synthetic_config(region_id)
	var validator = VALIDATOR.new()
	validator.begin(raw, path, Vector2(120,500))
	var seen := {}
	var steps := 0
	while true:
		var finished: bool = validator.step()
		seen[String(validator.operation_name)] = true
		if finished: break
		steps += 1
	_check(validator.error.is_empty(), "large synthetic validation succeeds")
	_check(steps > 1500 and validator.progress == 1.0, "record, point and identity cursor traverses large plan")
	for operation in ["records", "identity", "terrain", "cave_rectangle", "route_snapshot_copy", "route_lookup", "route_merge", "platform", "world_dimension", "entry"]:
		_check(seen.has(operation), "synthetic cursor measured " + operation)
	var invalid: Dictionary = raw.duplicate(true)
	invalid.terrain[-1].surface[2] = [0, NAN]
	var bad_validator = VALIDATOR.new()
	bad_validator.begin(invalid, path, Vector2(120,500))
	while not bad_validator.step(): pass
	_check(bad_validator.error == "目标区域地形轮廓坐标无效。", "late synthetic point preserves first error")

func _make_synthetic_config(region_id: String) -> Dictionary:
	var path := ROUTES.config_path(region_id)
	var source_bytes := FileAccess.get_file_as_bytes(path)
	_synthetic_source_size = source_bytes.size()
	var raw: Dictionary = JSON.parse_string(source_bytes.get_string_from_utf8())
	for index in range(240):
		raw.map_rooms.append({"id":"synthetic_room_%d" % index, "rect":[index * 10, 20, 80, 60]})
		raw.platforms.append({"id":"synthetic_platform_%d" % index, "rect":[index * 10, 800, 80, 12]})
		raw.terrain.append({"id":"synthetic_terrain_%d" % index, "depth":120, "surface":[[0, index], [20, index + 2], [40, index + 3]]})
		raw.cave_world.solid_rects.append([index, 1400, 32, 80])
		raw.interactives.append({"id":"synthetic_interactive_%d" % index, "position":[index, 400], "interaction_size":[32, 32]})
	return raw

func _loader_preflight_checks() -> void:
	scene = await _new_scene()
	if scene == null: return
	var loader: Variant = scene.world_loader
	var source_generation: int = loader.generation
	var target := ROUTES.config_path(REGIONS[1])
	var synthetic := _make_synthetic_config(REGIONS[1])
	scene.world_prefetch.desired[REGIONS[1]] = {"path":target, "entry":Vector2(120,500)}
	scene.world_prefetch.configs[REGIONS[1]] = {"raw":synthetic, "stamp":FileAccess.get_modified_time(target), "size":_synthetic_source_size}
	# An unsaved currency delta proves that preflight cancellation cannot eagerly
	# commit the departure checkpoint before target validation succeeds.
	scene.currency_count += 17
	scene._toggle_map()
	_check(scene.active_overlay == "map" and bool(scene.player.get("ui_input_locked")), "overlay fixture opens real source map and locks gameplay input")
	# Map opening queues its real SFX attachment. Settle fixture setup before
	# taking exact node identities; do not exclude audio nodes from isolation.
	await process_frame
	await process_frame
	_check(scene.pending_sfx_players.is_empty(), "source map fixture finishes deferred audio attachment before snapshot")
	var baseline := _source_snapshot(scene)
	var invalid_path := "res://data/not_a_region.json"
	var invalid_ok: bool = await loader.replace_region_async(scene, invalid_path, Vector2(120,500))
	_check(not invalid_ok and loader.phase == "idle", "invalid target rejection returns idle")
	_check(_source_snapshot(scene) == baseline, "invalid target leaves complete source snapshot untouched")
	_check(not scene.world_loading and not scene.chapter_transitioning and scene.active_overlay == "map" and bool(scene.player.get("ui_input_locked")), "invalid target preserves source map and input lock")
	for boundary in ["early", "mid", "final"]:
		_arm_cancel_observer(loader, boundary)
		_launch_replace(scene, target, Vector2(120,500))
		await _wait_operation()
		_check(not _operation_result and bool(loader.last_transition.get("preflight_cancelled", false)), boundary + " preflight cancellation is observed")
		var batch_count := int(loader.last_transition.get("preflight_batches", 0))
		_check(int(loader.last_transition.get("preflight_cursor", 0)) > 0 and batch_count >= (1 if boundary == "early" else 2), boundary + " traverses real budget batches")
		_check(int(loader.last_transition.get("preflight_max_operations", 99)) <= 8, boundary + " admission never exceeds eight operations")
		_check(int(loader.last_transition.get("preflight_work_usec", 0)) > 0 and int(loader.last_transition.get("preflight_wall_usec", 0)) >= int(loader.last_transition.get("preflight_work_usec", 0)), boundary + " records work and elapsed time")
		if boundary == "final": _check(_observer_saw_final, "observer cancelled from the true final-yield window")
		_check(_same_source_snapshot(scene, baseline, boundary + " cancellation"), boundary + " cancellation preserves source nodes, state and save")
		_check(loader.generation == source_generation and int(loader.unloaded_nodes) == int(baseline.unloaded_nodes), boundary + " cancellation precedes generation handoff and eviction")
		_check(not scene.world_loading and not scene.chapter_transitioning and scene.active_overlay == "map", boundary + " preserves loading/input/overlay state")
		_check(not is_instance_valid(loader.loading_canvas) and scene.ui_canvas.visible, boundary + " releases canvas and restores UI")
		_check(scene.player.collision_layer == int(baseline.collision_layer) and scene.player.collision_mask == int(baseline.collision_mask), boundary + " preserves collision state")
		_check(scene.active_overlay == "map" and bool(scene.player.get("ui_input_locked")), boundary + " keeps the original map and input lock")
		_check(_assert_preflight_metrics(loader.last_transition, boundary), boundary + " metric counters reconcile")
		var metric_line := {"cursor":loader.last_transition.preflight_cursor, "batches":loader.last_transition.preflight_batches,
			"max_operations":loader.last_transition.preflight_max_operations, "json_usec":loader.last_transition.preflight_json_usec,
			"work_usec":loader.last_transition.preflight_work_usec, "wall_usec":loader.last_transition.preflight_wall_usec,
			"max_batch_usec":loader.last_transition.preflight_max_batch_usec, "done":loader.last_transition.preflight_done,
			"progress":loader.last_transition.preflight_progress, "observer_final":_observer_saw_final}
		print("WORLD_PREFLIGHT_BOUNDARY %s %s" % [boundary, JSON.stringify(metric_line)])
	# A cached target with a late invalid surface point must fail before source
	# save/handoff just like an invalid path; restore the valid cache afterward.
	var late_bad: Dictionary = synthetic.duplicate(true)
	late_bad.terrain[-1].surface[2] = [0, INF]
	scene.world_prefetch.configs[REGIONS[1]]["raw"] = late_bad
	var bad_source_snapshot := _source_snapshot(scene)
	_launch_replace(scene, target, Vector2(120,500))
	await _wait_operation()
	_check(not _operation_result and loader.phase == "idle" and loader.last_error == "目标区域地形轮廓坐标无效。", "late cached invalid point reports the frozen legacy error")
	_check(_same_source_snapshot(scene, bad_source_snapshot, "late invalid target"), "late invalid target preserves source, cache and save")
	scene.world_prefetch.configs[REGIONS[1]]["raw"] = synthetic
	scene._close_overlays()
	_check(scene.active_overlay.is_empty() and not bool(scene.player.get("ui_input_locked")), "test closes source map before transition fixtures")
	# Now exercise cancellation after handoff has begun. Publication flags must
	# remain private until destination commit, even when build work was started.
	var fake := Area2D.new()
	fake.set_meta("world_portal_data", {"id":"build_cancel_fixture", "target_config_id":REGIONS[1], "target_spawn":[120,500], "kind":"world_portal", "unlock_shortcut_id":"build_cancel_fixture"})
	if scene.world_prefetch.configs.has(REGIONS[1]): scene.world_prefetch.configs.erase(REGIONS[1])
	if scene.world_prefetch.desired.has(REGIONS[1]): scene.world_prefetch.desired.erase(REGIONS[1])
	scene._activate_world_portal(fake)
	for frame in range(2000):
		if loader.phase in ["loading", "committing"]: break
		await process_frame
	_check(loader.phase in ["loading", "committing"], "target build/commit cancellation boundary reached")
	loader.cancel_transition()
	for frame in range(4000):
		if loader.phase == "idle" and not scene.world_portal_request_pending: break
		await process_frame
	_check(String(scene.config.id) == REGIONS[0] and not scene.story_flags.get("world_shortcut_build_cancel_fixture", false), "cancelled build cannot publish portal shortcut")
	_check(scene.world_state.data.current_region == REGIONS[0] and scene.player.collision_layer == 1, "cancelled build restores source and player physics")
	_check(not scene.world_portal_request_pending and scene.world_loader.phase == "idle", "cancelled build releases portal queue")
	_check(is_instance_valid(scene.player) and String(scene.config.id) == REGIONS[0], "build rollback retains persistent player and source region")
	fake.free()
	var target_fake := Area2D.new()
	target_fake.set_meta("world_portal_data", {"id":"budget_fixture_portal", "target_config_id":REGIONS[1], "target_spawn":[120,500], "kind":"world_portal", "unlock_shortcut_id":"budget_fixture_shortcut"})
	scene._activate_world_portal(target_fake)
	for frame in range(4000):
		if not scene.world_portal_request_pending and loader.phase == "idle": break
		await process_frame
	_check(String(scene.config.id) == REGIONS[1] and scene.story_flags.get("world_shortcut_budget_fixture_shortcut", false), "successful portal publishes shortcut with destination")
	var saved := STATE.new(); _check(saved.read(SAVE) and saved.data.story_flags.get("world_shortcut_budget_fixture_shortcut", false), "published shortcut survives restart")
	target_fake.free()

func _arm_cancel_observer(loader: Variant, mode: String) -> void:
	_observer_loader = loader
	_observer_mode = mode
	_observer_triggered = false
	_observer_saw_final = false
	process_frame.connect(_observe_cancel_boundary, CONNECT_ONE_SHOT)

func _observe_cancel_boundary() -> void:
	if not is_instance_valid(_observer_loader): return
	var cursor := int(_observer_loader.last_transition.get("preflight_cursor", 0))
	var done := bool(_observer_loader.last_transition.get("preflight_done", false))
	var ready := _observer_mode == "early" and cursor >= 1 or _observer_mode == "mid" and cursor >= 24 or _observer_mode == "final" and done
	if _observer_loader.phase == "preflight" and ready:
		_observer_saw_final = done
		_observer_loader.cancel_transition()
		_observer_triggered = true
	else:
		process_frame.connect(_observe_cancel_boundary, CONNECT_ONE_SHOT)

func _assert_preflight_metrics(metrics: Dictionary, boundary: String) -> bool:
	var operations: Array = metrics.get("preflight_batch_operations", [])
	var operation_usec: Dictionary = metrics.get("preflight_operation_usec", {})
	var admitted := 0
	for count in operations:
		if int(count) > 8: return false
		admitted += int(count)
	var measured_usec := 0
	for duration in operation_usec.values(): measured_usec += int(duration)
	var done := bool(metrics.get("preflight_done", false))
	var progress := float(metrics.get("preflight_progress", -1.0))
	return admitted == int(metrics.get("preflight_cursor", -1)) and measured_usec == int(metrics.get("preflight_work_usec", -2)) and (progress == 1.0 if done else progress >= 0.0 and progress < 1.0)

func _pending_gap_check() -> void:
	# Use a new source scene after the prior successful portal handoff.
	scene = await _new_scene()
	if scene == null: return
	var passage: Node = scene.world_passage
	var pipe_id := "moss_rain_pipe"
	var portal: Node = scene.get_node_or_null(pipe_id)
	if portal == null:
		_check(false, "real passage endpoint exists for queue-gap proof")
		return
	scene.player.global_position = portal.global_position
	_check(scene.active_overlay.is_empty() and not scene.chapter_transitioning and not scene.world_loading and scene.world_loader.phase == "idle", "queue-gap source preconditions are idle and overlay-free")
	_check(passage.begin(pipe_id), "queue-gap endpoint is independently open and in reach")
	passage._return_to_source(true)
	await process_frame
	_check(not passage.active and scene.active_overlay.is_empty() and scene.world_loader.phase == "idle", "passage fixture returned to neutral source")
	var gap_nodes := _node_ids(scene)
	var gap_config: Dictionary = scene.config.duplicate(true)
	var gap_state: Dictionary = scene.world_state.data.duplicate(true)
	var gap_position: Vector2 = scene.player.global_position
	var gap_bytes := _save_bytes()
	var fake := Area2D.new()
	fake.set_meta("world_portal_data", {"id":"budget_fixture_portal", "target_config_id":REGIONS[1], "target_spawn":[120,500], "kind":"world_portal", "unlock_shortcut_id":"budget_fixture_shortcut"})
	_arm_cancel_observer(scene.world_loader, "early")
	scene._activate_world_portal(fake)
	_check(scene.world_portal_request_pending and scene.world_loader.phase == "idle" and not scene.chapter_transitioning, "ordinary portal exposes deferred queue gap before loader starts")
	var accepted: bool = passage.begin(pipe_id)
	_check(not accepted and not passage.active, "pending request alone blocks passage begin before deferred loader phase")
	_check(scene.world_portal_request_pending and scene.world_loader.phase == "idle", "blocked passage attempt leaves queued portal intact")
	_check(_node_ids(scene) == gap_nodes and scene.config == gap_config and scene.world_state.data == gap_state and scene.player.global_position == gap_position, "pending guard preserves source objects, config, progress and pose")
	_check(_save_bytes() == gap_bytes, "pending guard makes no checkpoint write before deferred loader")
	var task_frame := 1200
	while task_frame > 0 and scene.world_loader.phase != "preflight":
		await process_frame
		task_frame -= 1
	_check(scene.world_loader.phase == "preflight", "deferred portal enters budgeted preflight")
	if scene.world_loader.phase == "preflight":
		# The ordinary portal coroutine owns pending cleanup once its request settles.
		# The observer was connected before activation so cancellation cannot race
		# through the preflight yield.
		for frame in range(1800):
			if _observer_triggered: break
			await process_frame
		for frame in range(1800):
			if scene.world_loader.phase == "idle" and not scene.world_portal_request_pending: break
			await process_frame
		_check(not scene.world_portal_request_pending and String(scene.config.id) == REGIONS[0], "cancelled queued portal releases pending without handoff")
		_check(not scene.story_flags.get("world_shortcut_budget_fixture_shortcut", false), "cancelled portal cannot publish shortcut")
		_check(not scene.chapter_transitioning and not scene.world_loading, "cancelled portal restores source state")
		_check(passage.begin(pipe_id), "passage can retry after queued request cancellation")
		passage._return_to_source(true)
	fake.free()

func _passage_preflight_check() -> void:
	scene = await _new_scene()
	if scene == null: return
	var passage: Node = scene.world_passage
	var pipe: Node = scene.get_node_or_null("moss_rain_pipe")
	if pipe == null: _check(false, "passage cancellation source endpoint exists"); return
	scene.player.global_position = pipe.global_position
	var checkpoint: Vector2 = scene.active_spawn
	_check(passage.begin("moss_rain_pipe"), "passage enters source before terminal preflight")
	var passage_save_bytes := _save_bytes()
	var passage_save_mtime := FileAccess.get_modified_time(ProjectSettings.globalize_path(SAVE))
	var frozen_ids: Array[int] = []
	for record in passage.frozen: frozen_ids.append(record.node.get_instance_id())
	scene.player.global_position = passage.destination_point + Vector2(0, 40)
	_arm_cancel_observer(scene.world_loader, "final")
	passage.step()
	for frame in range(2000):
		if scene.world_loader.phase == "preflight": break
		await process_frame
	_check(scene.world_loader.phase == "preflight" and passage.settling and passage.active, "passage terminal starts asynchronous target preflight")
	if scene.world_loader.phase == "preflight":
		for frame in range(2000):
			if _observer_triggered: break
			await process_frame
		_check(_observer_triggered and _observer_saw_final, "passage cancel fired from final preflight yield")
		for frame in range(2000):
			if not passage.settling: break
			await process_frame
		_check(passage.active and passage.retry_blocked and String(scene.config.id) == REGIONS[0], "terminal preflight cancel retains transit source")
		var restored_ids: Array[int] = []
		for record in passage.frozen:
			if is_instance_valid(record.node): restored_ids.append(record.node.get_instance_id())
		_check(restored_ids == frozen_ids and scene.player.collision_layer == 64 and scene.player.collision_mask == 64, "cancel retains frozen source refs and transit collision")
		var saved := STATE.new(); _check(saved.read(SAVE) and saved.data.current_region == REGIONS[0] and saved.resume_local_position() == checkpoint, "cancel retains source checkpoint")
		_check(_save_bytes() == passage_save_bytes and FileAccess.get_modified_time(ProjectSettings.globalize_path(SAVE)) == passage_save_mtime, "passage preflight cancellation does not rewrite source save")
		passage._return_to_source(true)
		_check(not passage.active and scene.ui_canvas.visible and scene.player.collision_layer == 1, "return restores source UI and collision")
		_check(passage.begin("moss_rain_pipe"), "passage retry remains available after cancelled preflight")
		passage._return_to_source(true)
		var normal_layer: int = scene.player.collision_layer
		var normal_mask: int = scene.player.collision_mask
		_check(passage.begin("moss_rain_pipe"), "passage can retry terminal after rollback")
		scene.player.global_position = passage.destination_point + Vector2(0, 40)
		passage.step()
		for frame in range(4000):
			if not passage.settling and scene.world_loader.phase == "idle": break
			await process_frame
		_check(String(scene.config.id) == REGIONS[1] and not passage.active, "successful passage terminal publishes destination")
		_check(scene.player.collision_layer == normal_layer and scene.player.collision_mask == normal_mask, "successful passage arrival restores original collision")

func _teardown_check() -> void:
	scene = await _new_scene()
	if scene == null: return
	var loader: Variant = scene.world_loader
	_launch_replace(scene, ROUTES.config_path(REGIONS[1]), Vector2(120,500))
	while loader.phase != "preflight": await process_frame
	var canvas: Variant = loader.loading_canvas
	scene.free()
	scene = null
	await _wait_operation()
	for frame in range(3): await process_frame
	_check(not is_instance_valid(canvas) or not canvas.is_inside_tree(), "scene teardown releases loading UI without touching freed host")

func _launch_replace(host: Node, path: String, entry: Vector2, flags: Dictionary = {}) -> void:
	_operation_done = false
	_operation_result = false
	call_deferred("_replace_runner", host, path, entry, flags)

func _replace_runner(host: Node, path: String, entry: Vector2, flags: Dictionary) -> void:
	_operation_result = await host.world_loader.replace_region_async(host, path, entry, Vector2.INF, flags)
	_operation_done = true

func _wait_operation() -> void:
	for frame in range(3000):
		if _operation_done: return
		await process_frame
	_check(false, "async loader runner completed within frame limit")

func _new_scene() -> Node:
	if is_instance_valid(scene):
		scene.queue_free()
		scene = null
		await process_frame
	var result: Node = load("res://scenes/World.tscn").instantiate()
	result.world_resume = false
	result.world_save_path = SAVE
	root.add_child(result)
	current_scene = result
	var startup_deadline := Time.get_ticks_msec() + 15000
	while is_instance_valid(result) and not bool(result.get("initial_region_ready")) and Time.get_ticks_msec() < startup_deadline:
		await process_frame
	var startup_ready := is_instance_valid(result) and bool(result.get("initial_region_ready")) and is_instance_valid(result.get("player"))
	_check(startup_ready, "world fixture waits for the actual budgeted startup to publish its player")
	if not startup_ready:
		return null
	result.process_mode = Node.PROCESS_MODE_DISABLED
	return result

func _node_ids(host: Node) -> Array[int]:
	var ids: Array[int] = []
	for child in host.get_children(): ids.append(child.get_instance_id())
	return ids

func _source_snapshot(host: Node) -> Dictionary:
	var save_path := ProjectSettings.globalize_path(SAVE)
	return {
		"nodes": _node_ids(host), "player_id": host.player.get_instance_id(),
		"position": host.player.global_position, "velocity": host.player.velocity,
		"collision_layer": host.player.collision_layer, "collision_mask": host.player.collision_mask,
		"process_mode": host.process_mode, "player_process_mode": host.player.process_mode,
		"world_loading": host.world_loading, "chapter_transitioning": host.chapter_transitioning,
		"overlay": host.active_overlay, "ui_visible": host.ui_canvas.visible,
		"ui_input_locked": bool(host.player.get("ui_input_locked")),
		"host_physics": host.is_physics_processing(), "player_physics": host.player.is_physics_processing(),
		"config": host.config.duplicate(true),
		"currency": host.currency_count, "story": host.story_flags.duplicate(true),
		"state": host.world_state.data.duplicate(true), "build": host.build_system.serialize(),
		"prefetch_configs": host.world_prefetch.configs.duplicate(true),
		"prefetch_desired": host.world_prefetch.desired.duplicate(true),
		"shared_metadata": host.world_shared_metadata_cache.duplicate(true),
		"shared_metadata_reads": host.world_shared_metadata_reads.duplicate(true),
		"shared_metadata_probes": host.world_shared_metadata_probes.duplicate(true),
		"shared_metadata_bytes": host.world_shared_metadata_bytes.duplicate(true),
		"shared_metadata_parses": host.world_shared_metadata_parses.duplicate(true),
		"shared_metadata_failures": host.world_shared_metadata_failures.duplicate(true),
		"generation": host.world_loader.generation, "unloaded_nodes": host.world_loader.unloaded_nodes,
		"save_bytes": _save_bytes(), "save_mtime": FileAccess.get_modified_time(save_path)
	}

func _same_source_snapshot(host: Node, expected: Dictionary, label: String) -> bool:
	var actual := _source_snapshot(host)
	var changed: Array[String] = []
	for key in expected:
		if actual.get(key) != expected[key]:
			changed.append(String(key))
	if not changed.is_empty(): print("WORLD_PREFLIGHT_SNAPSHOT_DIFF %s %s" % [label, ",".join(changed)])
	return changed.is_empty()

func _save_bytes() -> PackedByteArray:
	var file := FileAccess.open(SAVE, FileAccess.READ)
	return file.get_buffer(file.get_length()) if file != null else PackedByteArray()

func _cleanup() -> void:
	if is_instance_valid(scene): scene.queue_free()
	for suffix in ["", ".bak", ".tmp", ".previous"]:
		var absolute := ProjectSettings.globalize_path(SAVE + suffix)
		if FileAccess.file_exists(SAVE + suffix): DirAccess.remove_absolute(absolute)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		print("WORLD_PREFLIGHT_FAIL " + label)
