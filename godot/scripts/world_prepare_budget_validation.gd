extends SceneTree
## Exercises the shared preparation job plan and its transaction boundary.
## Timings are reported as observations; admission is verified by operation count.
const ROUTES := preload("res://scripts/world_routes.gd")
const COORD := preload("res://scripts/world_coordinates.gd")
const STATE := preload("res://scripts/world_state.gd")
const SAVE := "user://world_prepare_budget_validation.json"
const SHARED_PATHS := [
	"res://data/campaign_chapters.json",
	"res://data/audio_visual_manifest.json",
	"res://data/item_lore.json",
	"res://data/chapters/ch02_rain_foundry_canal.json",
	"res://data/chapters/ch03_saltwhite_archive.json",
	"res://data/chapters/ch04_broken_string_greenhouse.json",
	"res://data/chapters/ch05_obsidian_pilgrim_road.json",
	"res://data/chapters/ch06_silent_crown_core.json"
]

var checks := 0
var failures: Array[String] = []
var scene: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.process_mode = Node.PROCESS_MODE_DISABLED
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	scene = load("res://scenes/World.tscn").instantiate()
	scene.world_resume = false
	scene.world_save_path = SAVE
	root.add_child(scene)
	current_scene = scene
	await _frames(3)
	if not is_instance_valid(scene.player):
		_check(false, "World fixture starts with a player")
		_finish()
		return

	var player_id: int = scene.player.get_instance_id()
	var camera_id: int = scene.player.get_node("Camera2D").get_instance_id()
	var world_state_id: int = scene.world_state.get_instance_id()
	var build_id: int = scene.build_system.get_instance_id()
	var source_id := String(scene.config.id)
	var source_path := String(scene.config_path)
	scene.currency_count = 317
	scene.story_flags["prepare_budget_fixture"] = true
	scene.player.hp = mini(3, scene.player.max_hp)
	scene.player.energy = mini(51, scene.player.max_energy)
	scene._save_world()
	var baseline_cache := _metadata_snapshot()
	_check_cache_baseline(baseline_cache)
	# A complete async preparation must use several bounded batches and preserve
	# the cache held by the persistent World host.
	var target_id := _other_region(source_id)
	var target_path := ROUTES.config_path(target_id)
	var target_config: Dictionary = _read_json(target_path)
	var target_entry := _entry_for(target_config)
	var arrival_ok: bool = await scene.world_loader.replace_region_async(scene, target_path, target_entry)
	_check(arrival_ok and scene.world_loader.phase == "idle", "async arrival completes")
	var metric: Dictionary = scene.world_loader.last_transition.duplicate(true)
	_check_prepare_metrics(metric, "completed arrival")
	_check(scene.player.get_instance_id() == player_id and scene.player.get_node("Camera2D").get_instance_id() == camera_id, "player and camera persist through async arrival")
	_check(scene.world_state.get_instance_id() == world_state_id and scene.build_system.get_instance_id() == build_id, "save state and build system persist through async arrival")
	_check(scene.player.hp == mini(3, scene.player.max_hp) and scene.currency_count == 317 and bool(scene.story_flags.get("prepare_budget_fixture", false)), "settled resources and story progress survive arrival")
	_check(scene.player.collision_layer != 0 and scene.player.collision_mask != 0 and not scene.world_loading and not scene.chapter_transitioning, "arrival restores collisions and input state")
	_check(scene.world_loader.loading_canvas == null and scene.ui_shell.construction_complete and scene.ui_shell.is_processing_input(), "arrival publishes only a complete interactive UI")
	_check_cache_retained(baseline_cache, "first async arrival")
	var async_signature := _region_signature()
	var async_currency := int(scene.currency_count)
	var async_story := bool(scene.story_flags.get("prepare_budget_fixture", false))

	# The sync compatibility path must build the same region and keep cumulative
	# cache counters. A reset-to-one bug in the prior cache test cannot pass this.
	scene._travel_world(target_path, target_entry)
	await _frames(2)
	var sync_signature := _region_signature()
	if sync_signature != async_signature:
		print("ASYNC/SYNC SIGNATURE DIFF async=", JSON.stringify(async_signature), " sync=", JSON.stringify(sync_signature))
	_check(scene.config.id == target_id and sync_signature == async_signature, "synchronous travel matches async geometry and UI")
	_check(int(scene.currency_count) == async_currency and bool(scene.story_flags.get("prepare_budget_fixture", false)) == async_story, "synchronous revisit preserves global inventory progression")
	_check_cache_retained(baseline_cache, "synchronous revisit")

	# A bad preflight must leave the active transaction untouched, including its
	# generation. This is the boundary before any cancellable preparation work.
	var before_bad_generation: int = scene.world_loader.generation
	var before_bad_signature := _region_signature()
	var before_bad_position: Vector2 = scene.player.global_position
	var bad_result: bool = await scene.world_loader.replace_region_async(scene, "res://missing_prepare_target.json", Vector2.ZERO)
	_check(not bad_result and scene.world_loader.generation == before_bad_generation, "bad target is rejected without advancing generation")
	_check(scene.config.id == target_id and scene.player.global_position == before_bad_position and _region_signature() == before_bad_signature, "bad target leaves source region intact")

	# Cancel at the first observable preparation batch, around its midpoint, and
	# after the final preparation batch has yielded but before build/publication.
	for boundary in ["early", "mid", "final"]:
		var cancel_target_id := _other_region(String(scene.config.id))
		var cancel_target_path := ROUTES.config_path(cancel_target_id)
		var cancel_target_config: Dictionary = _read_json(cancel_target_path)
		await _cancel_during_prepare(boundary, cancel_target_id, cancel_target_path, _entry_for(cancel_target_config))
		_check_cache_retained(baseline_cache, boundary + " prepare rollback")

	# Force a cold catalog plan to exercise staging. Cancelling after a region has
	# been staged must not publish a partial shared catalog into the source host.
	var warm_catalog: Dictionary = scene.world_catalog.duplicate(true)
	scene.world_catalog = {}
	var cold_target_id := _other_region(String(scene.config.id))
	var cold_target_path := ROUTES.config_path(cold_target_id)
	var cold_target_config: Dictionary = _read_json(cold_target_path)
	var cold_entry := _entry_for(cold_target_config)
	scene._travel_world_async(cold_target_path, cold_entry)
	var saw_staged_catalog := false
	for frame in range(4000):
		if scene.world_loader.phase == "loading" and scene.world_catalog_prepare_staging.size() > 0:
			saw_staged_catalog = true
			_check(scene.world_catalog.is_empty(), "cold catalog remains unpublished while preparation is staged")
			scene.world_loader.cancel_transition()
			break
		await process_frame
	_check(saw_staged_catalog, "cold catalog cancellation reaches a populated staging boundary")
	await _wait_idle()
	_check(scene.config.id == target_id and scene.world_catalog == warm_catalog and scene.world_catalog_prepare_staging.is_empty(), "cold catalog rollback discards target staging and restores complete source catalog")
	_check(scene.currency_count == 317 and bool(scene.story_flags.get("prepare_budget_fixture", false)), "cold catalog rollback preserves settled progress")
	_check_cache_retained(baseline_cache, "cold catalog rollback")
	# Restore the fixture's pre-test warm catalog after proving no staged value
	# escaped. It is an in-memory fixture reset, not a product action.
	scene.world_catalog = warm_catalog

	# Host teardown during preparation must retire the root-owned loading canvas
	# and let the suspended transition coroutine observe that the host is gone.
	scene._travel_world_async(cold_target_path, cold_entry)
	var saw_prepare := false
	for frame in range(4000):
		if scene.world_loader.phase == "loading" and int(scene.world_loader.last_transition.get("prepare_jobs", 0)) > 0 and int(scene.world_loader.last_transition.get("prepare_cursor", 0)) > 0:
			saw_prepare = true
			break
		await process_frame
	_check(saw_prepare, "teardown reaches an in-flight preparation batch")
	var loader: RefCounted = scene.world_loader
	scene.free()
	current_scene = null
	await _frames(3)
	_check(loader.shutting_down and loader.loading_canvas == null, "host teardown shuts down loader and removes loading canvas")
	loader = null

	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	_finish()

func _cancel_during_prepare(boundary: String, target_id: String, target_path: String, target_entry: Vector2) -> void:
	var source_id := String(scene.config.id)
	scene.currency_count = 317
	scene.story_flags["prepare_budget_fixture"] = true
	scene._save_world()
	var source_position: Vector2 = scene.player.global_position
	var source_signature := _region_signature()
	var source_state: Dictionary = scene.world_state.data.duplicate(true)
	_check(int(source_state.get("currency", -1)) == 317, boundary + " fixture records the settled departure currency")
	var source_catalog: Dictionary = scene.world_catalog.duplicate(true)
	var source_generation: int = scene.world_loader.generation
	scene._travel_world_async(target_path, target_entry)
	var reached := false
	for frame in range(5000):
		if scene.world_loader.phase == "loading" and String(scene.world_loader.last_transition.get("source", "")) == source_id and String(scene.world_loader.last_transition.get("target", "")) == target_id:
			var jobs := int(scene.world_loader.last_transition.get("prepare_jobs", 0))
			var cursor := int(scene.world_loader.last_transition.get("prepare_cursor", 0))
			if jobs > 0:
				if boundary == "early" and cursor > 0 and cursor < jobs:
					reached = true
				elif boundary == "mid" and cursor >= int(ceil(float(jobs) / 2.0)) and cursor < jobs:
					reached = true
				elif boundary == "final" and cursor == jobs:
					reached = true
		if reached:
			break
		await process_frame
	_check(reached, "reaches " + boundary + " preparation yield")
	if not reached:
		return
	var current_metric: Dictionary = scene.world_loader.last_transition
	_check(int(current_metric.get("prepare_cursor", 0)) <= int(current_metric.get("prepare_jobs", 0)), boundary + " cursor does not exceed plan")
	_check(scene.config.id == target_id and scene.world_loading and scene.chapter_transitioning, boundary + " target remains unpublished during preparation")
	_check(scene.world_state.data.current_region == source_id and int(scene.world_state.data.currency) == int(source_state.currency), boundary + " destination progress and reward are not published")
	_check(scene.world_state.data.regions == source_state.regions, boundary + " target discovery and rewards remain unpublished in the save transaction")
	_check(scene.world_catalog == source_catalog, boundary + " preparation does not mutate live catalog")
	var stale_generation := source_generation
	var flags_before_stale_call: Dictionary = scene.story_flags.duplicate(true)
	scene._run_region_deferred(stale_generation, "_set_story_flag", ["prepare_stale_callback"])
	_check(scene.story_flags == flags_before_stale_call, boundary + " deferred work from the previous generation is ignored")
	scene.world_loader.cancel_transition()
	await _wait_idle()
	var completed_transition: Dictionary = scene.world_loader.last_transition
	_check(completed_transition.rolled_back, boundary + " marks rollback")
	var target_prepare: Dictionary = completed_transition.get("target_prepare", {})
	var rollback_prepare: Dictionary = completed_transition.get("rollback_prepare", {})
	_check(not target_prepare.is_empty() and int(target_prepare.get("prepare_cursor", 0)) > 0 and int(target_prepare.get("prepare_cursor", 0)) <= int(target_prepare.get("prepare_jobs", -1)), boundary + " retains cancelled target preparation metrics")
	_check(not rollback_prepare.is_empty() and int(rollback_prepare.get("prepare_cursor", -1)) == int(rollback_prepare.get("prepare_jobs", -2)) and int(rollback_prepare.get("max_prepare_operations", 99)) <= 8, boundary + " retains completed rollback preparation metrics")
	_check(scene.config.id == source_id and scene.player.global_position == source_position, boundary + " restores source and exact position")
	_check(_region_signature() == source_signature, boundary + " reconstructs source geometry/UI")
	_check(scene.world_state.data.current_region == source_state.current_region and scene.currency_count == 317 and scene.story_flags.prepare_budget_fixture, boundary + " retains settled save/progression")
	_check(scene.world_catalog == source_catalog and scene.world_catalog_prepare_staging.is_empty(), boundary + " does not leak target catalog work")
	_check(scene.world_loader.generation > stale_generation, boundary + " invalidates callbacks from the departing generation")
	_check(not scene.world_loading and not scene.chapter_transitioning and scene.world_loader.loading_canvas == null, boundary + " releases loading state")
	_check(scene.player.collision_layer != 0 and scene.player.collision_mask != 0 and scene.ui_shell.construction_complete and scene.ui_shell.is_processing_input(), boundary + " restores active collision and complete input UI")
	_check(scene.process_mode == Node.PROCESS_MODE_INHERIT or scene.process_mode == Node.PROCESS_MODE_PAUSABLE, boundary + " re-enables the source host")
	var restored := STATE.new()
	_check(restored.read(SAVE) and restored.data.current_region == source_id and restored.data.currency == 317, boundary + " persists source after rollback")
	# Keep later scenarios on the original source even if the cancellation API
	# restores from a save checkpoint that changed harmless fixture fields.
	scene._save_world()

func _check_prepare_metrics(metric: Dictionary, label: String) -> void:
	var jobs := int(metric.get("prepare_jobs", 0))
	var cursor := int(metric.get("prepare_cursor", -1))
	var batches := int(metric.get("prepare_batches", 0))
	_check(jobs > 8 and cursor == jobs, label + " completes its preparation job plan")
	_check(batches > 1 and int(metric.get("max_prepare_operations", 99)) <= 8, label + " spans bounded preparation batches")
	var batch_operations: Array = metric.get("prepare_batch_operations", [])
	_check(batch_operations.size() == batches and batch_operations.all(func(value): return int(value) > 0 and int(value) <= 8), label + " records each batch within the operation cap")
	var admitted := 0
	for value in batch_operations:
		admitted += int(value)
	_check(admitted == cursor, label + " accounts for every admitted prepare operation")
	_check(metric.get("prepare_operation_usec", {}).size() == jobs, label + " records each operation duration")
	_check(int(metric.get("prepare_work_usec", -1)) >= 0 and int(metric.get("prepare_wall_usec", -1)) >= int(metric.get("prepare_work_usec", 0)), label + " reports prepare work and wall timing")
	_check(int(metric.get("max_prepare_job_usec", -1)) >= 0 and int(metric.get("max_prepare_batch_usec", -1)) >= 0, label + " reports largest operation and batch timings")
	_check(int(metric.get("prepare_usec", -1)) == int(metric.get("prepare_work_usec", -2)), label + " legacy prepare timing aliases measured work")
	print("PREPARE TIMING ", label, " work_us=", metric.get("prepare_work_usec"), " wall_us=", metric.get("prepare_wall_usec"), " max_job_us=", metric.get("max_prepare_job_usec"), " batches=", batches, " max_ops=", metric.get("max_prepare_operations"))

func _metadata_snapshot() -> Dictionary:
	return scene.world_shared_metadata_snapshot()

func _check_cache_baseline(snapshot: Dictionary) -> void:
	var expected: Array[String] = []
	for path in SHARED_PATHS:
		expected.append(scene._world_shared_metadata_key(path))
	expected.sort()
	var actual: Array = snapshot.get("cache_paths", []).duplicate()
	actual.sort()
	_check(actual == expected, "initial World host caches the eight shared metadata sources")
	var reads: Dictionary = snapshot.get("reads", {})
	var parses: Dictionary = snapshot.get("parses", {})
	var bytes: Dictionary = snapshot.get("bytes", {})
	_check(reads.size() == 8 and reads.values().all(func(value): return int(value) == 1), "each shared metadata source has one cumulative body read")
	_check(parses == reads and bytes.size() == 8 and bytes.values().all(func(value): return int(value) > 0), "metadata parse and byte counters record those reads")
	_check(snapshot.get("failures", {}).values().all(func(value): return int(value) == 0), "production metadata has no cache load failures")

func _check_cache_retained(baseline: Dictionary, label: String) -> void:
	var current := _metadata_snapshot()
	var expected_paths: Array = baseline.get("cache_paths", []).duplicate()
	var current_paths: Array = current.get("cache_paths", []).duplicate()
	expected_paths.sort()
	current_paths.sort()
	_check(current_paths == expected_paths, label + " retains the same metadata cache entries")
	for field in ["reads", "parses", "bytes", "failures"]:
		_check(current.get(field, {}) == baseline.get(field, {}), label + " preserves cumulative " + field + " counters")
	var before_probes: Dictionary = baseline.get("probes", {})
	var after_probes: Dictionary = current.get("probes", {})
	var all_probes_advanced := true
	for key in before_probes:
		if int(after_probes.get(key, 0)) <= int(before_probes[key]):
			all_probes_advanced = false
		_check(int(after_probes.get(key, 0)) >= int(before_probes[key]), label + " probe counter never resets for " + String(key))
	_check(all_probes_advanced, label + " probes every cached source without resetting its cumulative counter")

func _region_signature() -> Dictionary:
	var result := {"region": String(scene.config.get("id", "")),
		"hazards": int(scene.hazard_total), "collectibles": int(scene.collectible_total),
		"saves": int(scene.save_point_total), "gates": scene.locked_gate_bodies.keys(),
		"types": {}, "enemy_positions": [], "static_positions": [], "collision_geometry": [], "shapes": 0, "polygons": 0,
		"ui": {"buttons": [], "items": [], "panels": []}}
	_walk(scene, result)
	result.enemy_positions.sort()
	result.static_positions.sort()
	result.collision_geometry.sort()
	result.gates.sort()
	_walk_ui(scene.ui_canvas, result.ui)
	result.ui.buttons.sort()
	result.ui.items.sort()
	result.ui.panels.sort_custom(func(a: Array, b: Array): return a[0] < b[0])
	return result

func _walk(node: Node, result: Dictionary) -> void:
	if node.has_meta("rim_chunk"):
		return
	if node == scene.player or node is CanvasLayer or node is Window or node is AudioStreamPlayer or node is AudioStreamPlayer2D or node == scene.audio_director or node == scene.metsys_bridge:
		return
	var kind := node.get_class()
	result.types[kind] = int(result.types.get(kind, 0)) + 1
	if node is CollisionShape2D:
		result.shapes += 1
		if node.get_parent() is StaticBody2D and not _streamed_geometry_name(String(node.get_parent().name)):
			var shape: Shape2D = node.shape
			var descriptor: Array = [String(node.get_parent().name), str(node.get_parent().global_position), String(shape.get_class()), str(node.position)]
			if shape is RectangleShape2D:
				descriptor.append(str(shape.size))
			elif shape is CircleShape2D:
				descriptor.append(str(shape.radius))
			elif shape is CapsuleShape2D:
				descriptor.append(str([shape.radius, shape.height]))
			elif shape is ConvexPolygonShape2D:
				descriptor.append(str(shape.points))
			result.collision_geometry.append(str(descriptor))
	if node is CollisionPolygon2D:
		result.polygons += 1
		if node.get_parent() is StaticBody2D and not _streamed_geometry_name(String(node.get_parent().name)):
			result.collision_geometry.append(str([String(node.get_parent().name), str(node.get_parent().global_position), "CollisionPolygon2D", str(node.position), str(node.polygon)]))
	if node is StaticBody2D and not _streamed_geometry_name(String(node.name)):
		result.static_positions.append(str([String(node.name), str(node.global_position)]))
	if node.is_in_group("enemy") and node is Node2D:
		result.enemy_positions.append(str(node.position))
	for child in node.get_children():
		_walk(child, result)

func _streamed_geometry_name(node_name: String) -> bool:
	return node_name.begins_with("RockChunk_") or node_name.begins_with("Terrain") or node_name.begins_with("terrain_")

func _walk_ui(node: Node, signature: Dictionary) -> void:
	if node is Button:
		signature.buttons.append(node.text)
	if node.has_meta("item_id"):
		signature.items.append(String(node.get_meta("item_id")))
	if String(node.name) in ["BackpackOverlay", "DialogueOverlay", "AudioSettingsOverlay", "BuildOverlay", "CourtMapOverlay"]:
		signature.panels.append([String(node.name), str(node.position), str(node.size)])
	for child in node.get_children():
		_walk_ui(child, signature)

func _other_region(exclude: String) -> String:
	for region_id in COORD.manifest().regions:
		if String(region_id) != exclude:
			return String(region_id)
	return exclude

func _read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func _entry_for(config: Dictionary) -> Vector2:
	var value: Array = config.get("player_start", [120, 500])
	return Vector2(float(value[0]), float(value[1]))

func _wait_idle() -> void:
	for frame in range(5000):
		if scene.world_loader.phase == "idle":
			return
		await process_frame
	_check(false, "transition returns to idle within fixture deadline")

func _frames(count: int) -> void:
	for frame in range(count):
		await process_frame

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("WORLD PREPARE BUDGET PASS: %d checks; cache continuity, bounded preparation, parity, cancellation, rollback, and teardown" % checks)
		call_deferred("quit", 0)
	else:
		for failure in failures:
			push_error(failure)
		call_deferred("quit", 1)
