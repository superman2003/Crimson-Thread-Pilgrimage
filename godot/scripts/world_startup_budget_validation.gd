extends SceneTree
## Compares the prior synchronous first-child construction with budgeted World
## startup in one process. Timings are observations, never hardware thresholds.
const WORLD_SCENE := "res://scenes/World.tscn"
const SAVE := "user://world_startup_budget_validation.json"
const RESUME_SAVE := "user://world_startup_resume_validation.json"
const ROUTES := preload("res://scripts/world_routes.gd")
const WORLD_STATE := preload("res://scripts/world_state.gd")
const COORDINATES := preload("res://scripts/world_coordinates.gd")

class SynchronousWorld:
	extends "res://scripts/main_level.gd"

	func _ready() -> void:
		_apply_cmdline_config_override()
		_prepare_world_start()
		# Explicit old synchronous baseline: prime the legacy manifest oracle and
		# resolve the initial region before `_initialize_region`.
		config_path = WORLD_ROUTES_SCRIPT.config_path("demo_ch01_moss_bell_court")
		world_loader = load("res://scripts/world_region_loader.gd").new()
		world_prefetch = load("res://scripts/world_prefetch.gd").new()
		world_passage = load("res://scripts/world_passage.gd").new()
		add_child(world_passage)
		world_passage.bind(self)
		_initialize_region()

var failures := 0

class FailedStartupHost:
	extends Node
	var world_initial_error := ""
	var world_slot := 2
	var world_save_path := "user://startup_failure_preserved.json"
	var retried_slot := 0
	var retried_path := ""
	func _replace_with_save_slot(slot: int, path: String) -> void:
		retried_slot = slot
		retried_path = path

class FailedManifestLoader:
	extends "res://scripts/world_region_loader.gd"
	func _prepare_routes_manifest(_host: Node, _tree: SceneTree, _background: bool = false) -> bool:
		last_error = "fixture unreadable route manifest"
		return false

class FrameCadenceLoader:
	extends "res://scripts/world_region_loader.gd"
	var resumed_frames: Array[int] = []
	func initialize_startup_region(host: Node, _restore_process_mode: int = Node.PROCESS_MODE_INHERIT) -> bool:
		while _alive(host):
			resumed_frames.append(Engine.get_process_frames())
			await _next_process_frame(host.get_tree())
		return false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.process_mode = Node.PROCESS_MODE_DISABLED
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	# Synchronous baseline uses the same World host, config, overlays and build
	# jobs, with only the old synchronous _initialize_region call changed.
	var sync_fixture: Node = SynchronousWorld.new()
	sync_fixture.world_mode = true
	sync_fixture.world_resume = false
	sync_fixture.world_save_path = SAVE
	var sync_started := Time.get_ticks_usec()
	root.add_child(sync_fixture)
	var sync_attach_usec := Time.get_ticks_usec() - sync_started
	var sync_player_ready := is_instance_valid(sync_fixture.get("player"))
	sync_fixture.free()
	# Force the real World startup below through a cold route cache. The sync
	# loader above is an independent baseline; this count proves production did
	# not silently repair the cache through a convenience API on the main thread.
	ROUTES._cached_stamp = -1
	ROUTES._cached_data = {}
	ROUTES._cache_generation = 0
	ROUTES.sync_manifest_parses = 0

	var host: Node = load(WORLD_SCENE).instantiate()
	host.world_resume = false
	host.world_save_path = SAVE
	var attach_started := Time.get_ticks_usec()
	root.add_child(host)
	var first_frame_usec := Time.get_ticks_usec() - attach_started
	_check(host.world_loader.phase == "startup" and host.world_loader.startup_token != null,
		"startup reserves its owned task before leaving scene attachment")
	_check(not is_instance_valid(host.world_loader.loading_canvas),
		"startup waits for scene attachment before adding the root loading canvas")
	var total_started := Time.get_ticks_usec()
	var last_frame := Time.get_ticks_usec()
	var max_observed_frame_gap := 0
	var frames := 0
	while frames < 600 and is_instance_valid(host) and not bool(host.initial_region_ready):
		await process_frame
		var now := Time.get_ticks_usec()
		max_observed_frame_gap = maxi(max_observed_frame_gap, now - last_frame)
		last_frame = now
		frames += 1
	var total_startup_usec := Time.get_ticks_usec() - total_started
	var loader: RefCounted = host.world_loader
	var metrics: Dictionary = loader.last_transition.duplicate(true)
	_check(sync_player_ready, "synchronous baseline reaches first player during add_child")
	_check(bool(host.initial_region_ready) and not host.world_loading, "budgeted first region publishes and releases loading gate")
	_check(loader.startup_token == null and loader._startup_frame_tree == null,
		"successful owned startup releases its token and frame connection")
	_check(not bool(metrics.get("route_manifest_worker_is_main", true)), "cold World route manifest read and JSON parse run on the shared worker")
	_check(int(ROUTES.sync_manifest_parses) == 0, "cold production World startup never falls back to synchronous manifest parsing")
	_check(int(metrics.get("player_art_textures",0)) > 0 and bool(metrics.get("player_art_worker_is_main",true)) != preload("res://scripts/background_resource_job.gd").off_thread_loading_safe(), "actual startup warms the Player's body and layered idle on the private worker, or inline under the headless Dummy renderer")
	_check(loader.player_art_job == null and loader.player_art_resources.is_empty(), "ready Player owns its resource references and releases the temporary warmup owner")
	_check(ROUTES.cache_is_current() and not ROUTES.cached_config_path(String(host.config.get("id", ""))).is_empty(), "startup atomically publishes a current manifest before resolving the first region")
	_check(int(metrics.get("route_manifest_copy_batches", 0)) > 0 and int(metrics.get("route_manifest_copy_edges", 0)) > 0, "worker manifest ownership is handed off through incremental copy batches")
	_check(int(metrics.get("max_prepare_operations", 99)) <= loader.MAX_OPERATIONS_PER_FRAME, "startup prepare batches honor the operation cap")
	_check(int(metrics.get("max_build_operations", 99)) <= loader.MAX_OPERATIONS_PER_FRAME, "startup build batches honor the operation cap")
	print("WORLD_STARTUP_TIMING sync_add_child_usec=%d budgeted_attach_usec=%d budgeted_total_usec=%d frames=%d max_observed_frame_gap_usec=%d prepare_work_usec=%d max_build_operations=%d route_worker_is_main=%s route_worker_usec=%d route_copy_batches=%d route_copy_edges=%d route_copy_begin_usec=%d route_copy_max_step_usec=%d route_copy_max_step_edges=%d" % [
		sync_attach_usec, first_frame_usec, total_startup_usec, frames, max_observed_frame_gap,
		int(metrics.get("prepare_work_usec", 0)), int(metrics.get("max_build_operations", 0)), str(metrics.get("route_manifest_worker_is_main", true)), int(metrics.get("route_manifest_worker_usec", 0)), int(metrics.get("route_manifest_copy_batches", 0)), int(metrics.get("route_manifest_copy_edges", 0)), int(metrics.get("route_manifest_copy_begin_usec", 0)), int(metrics.get("route_manifest_copy_max_step_usec", 0)), int(metrics.get("route_manifest_copy_max_step_edges", 0))])
	# Teardown at both preparation and construction yields. Detached and freed
	# hosts must make their coroutine exit through its liveness guard.
	await _teardown_probe(false)
	await _teardown_probe(true)
	await _teardown_probe(true, true)
	await _early_teardown_probe()
	await _frame_cadence_probe()
	await _background_refresh_takeover_probe(host)
	await _cold_resume_probe()
	await _failure_recovery_probe()
	if is_instance_valid(host):
		root.remove_child(host)
		host.free()
	await process_frame
	if failures == 0:
		print("WORLD_STARTUP_BUDGET_VALIDATION_PASS")
	else:
		push_error("WORLD_STARTUP_BUDGET_VALIDATION_FAIL failures=%d" % failures)
	quit(0 if failures == 0 else 1)

func _early_teardown_probe() -> void:
	var probe: Node = load(WORLD_SCENE).instantiate()
	probe.world_resume = false
	probe.world_save_path = SAVE
	root.add_child(probe)
	var loader: RefCounted = probe.world_loader
	var token: RefCounted = loader.startup_token
	_check(loader.request_startup_region(probe, Node.PROCESS_MODE_INHERIT) == null,
		"a startup waiting for scene attachment rejects duplicate requests")
	var token_ref: WeakRef = weakref(token)
	var loader_ref: WeakRef = weakref(loader)
	var reader_ref: WeakRef = weakref(loader.config_read_job)
	probe.free()
	_check(token.finished and token.cancelled and loader.startup_token == null,
		"teardown before the first startup frame synchronously finishes the owned task")
	_check(loader.phase == "idle" and not is_instance_valid(loader.loading_canvas) and not loader.config_read_job.busy(),
		"early teardown starts no loading canvas or background read")
	_check(loader._startup_frame_tree == null,
		"early teardown disconnects its private frame wakeup")
	token = null
	loader = null
	_check(token_ref.get_ref() == null and loader_ref.get_ref() == null and reader_ref.get_ref() == null,
		"early teardown releases token, loader and reader without another process frame")

func _frame_cadence_probe() -> void:
	var probe := Node.new()
	root.add_child(probe)
	var loader := FrameCadenceLoader.new()
	var token: RefCounted = loader.request_startup_region(probe, Node.PROCESS_MODE_INHERIT)
	for _frame in range(5):
		await process_frame
	var once_per_frame := loader.resumed_frames.size() >= 3
	for index in range(1, loader.resumed_frames.size()):
		once_per_frame = once_per_frame and loader.resumed_frames[index] == loader.resumed_frames[index - 1] + 1
	_check(once_per_frame, "owned startup resumes exactly once per real process frame")
	loader.shutdown()
	loader.shutdown()
	_check(probe.is_inside_tree() and token.finished and token.cancelled and loader.startup_token == null and loader._startup_frame_tree == null,
		"explicit and repeated shutdown synchronously finish startup while its host remains attached")
	probe.free()

func _failure_recovery_probe() -> void:
	var probe := FailedStartupHost.new()
	root.add_child(probe)
	var loader := FailedManifestLoader.new()
	var file := FileAccess.open(probe.world_save_path, FileAccess.WRITE)
	file.store_string("original save bytes")
	file.close()
	var token: RefCounted = loader.request_startup_region(probe, Node.PROCESS_MODE_INHERIT)
	for _frame in range(3):
		if token.finished:
			break
		await process_frame
	_check(token.finished and loader.startup_token == null and loader._startup_frame_tree == null,
		"failed owned startup releases its token and frame connection")
	_check(loader.phase == "startup_error" and is_instance_valid(loader.loading_label) and loader.loading_label.text.contains("fixture unreadable"), "startup failure keeps a visible actionable error")
	var retry: Button = loader.loading_canvas.get_node("StartupRetry")
	_check(retry.has_focus() and not retry.disabled, "startup recovery is keyboard and controller focusable")
	retry.pressed.emit()
	await process_frame
	_check(probe.retried_slot == 2 and probe.retried_path == probe.world_save_path, "retry replaces the failed host using the same save slot")
	_check(FileAccess.get_file_as_string(probe.world_save_path) == "original save bytes", "startup failure and retry do not overwrite the save")
	loader.shutdown()
	probe.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://startup_failure_preserved.json"))
	await process_frame

func _background_refresh_takeover_probe(host: Node) -> void:
	var loader: RefCounted = host.world_loader
	var prior_generation := ROUTES._cache_generation
	ROUTES._cached_stamp = -1
	loader.phase = "idle"
	host.world_loading = true # Keep ordinary prefetch asleep; this probe owns the refresh request.
	loader.request_manifest_refresh(host)
	await process_frame
	loader.phase = "preflight" # Foreground takes priority while manifest handoff is pending.
	for _frame in range(120):
		# Cancellation discards ownership without joining a running reader.
		# Foreground admission waits for that abandoned worker to finish.
		if not loader.manifest_refresh_running and not loader.config_read_job.busy():
			break
		await process_frame
	_check(not loader.manifest_refresh_running and ROUTES.cached_generation() < 0,
		"foreground takeover discards background manifest staging without publishing it")
	var path := "res://data/demo_ch01_moss_bell_court.json"
	var foreground_ticket: int = loader.config_read_job.request(path)
	_check(foreground_ticket != 0, "foreground config read acquires the sole reader after canceled handoff")
	for _frame in range(120):
		if not loader.config_read_job.busy():
			break
		await process_frame
	_check(not loader.config_read_job.take(foreground_ticket).is_empty(), "foreground worker ticket completes before neighbor route refresh resumes")
	loader.phase = "idle"
	loader.request_manifest_refresh(host)
	for _frame in range(120):
		if ROUTES.cache_is_current() and ROUTES.cached_generation() > prior_generation:
			break
		await process_frame
	_check(ROUTES.cache_is_current() and ROUTES.cached_generation() > prior_generation,
		"abandoned refresh retries through the same worker after foreground completion")
	_check(ROUTES.sync_manifest_parses == 0, "runtime refresh and takeover never invoke synchronous manifest parsing")
	host.world_loading = false
	loader.phase = "idle"

func _cold_resume_probe() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RESUME_SAVE + suffix))
	var region := "demo_ch02_rain_foundry_canal"
	var entry := Vector2(120, 500)
	var state = WORLD_STATE.new()
	state.data.current_region = region
	state.data.entry = [entry.x, entry.y]
	state.data.world_location = COORDINATES.location(region, entry)
	_check(state.write(RESUME_SAVE), "resume fixture writes a valid off-first-region save")
	ROUTES._cached_stamp = -1
	ROUTES._cached_data = {}
	ROUTES._cache_generation = 0
	ROUTES.sync_manifest_parses = 0
	var host: Node = load(WORLD_SCENE).instantiate()
	host.world_save_path = RESUME_SAVE
	root.add_child(host)
	for _frame in range(600):
		if not is_instance_valid(host) or bool(host.initial_region_ready):
			break
		await process_frame
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json" % region))
	var oracle: Dictionary = ROUTES.apply_to(raw)
	_check(bool(host.initial_region_ready) and String(host.config.get("id", "")) == region,
		"cold resume resolves saved region only after worker manifest publication")
	_check(host.entry_spawn_override_enabled and host.entry_spawn_override == entry,
		"cold resume preserves saved local position")
	_check(host.config.get("world_routes_version") == oracle.get("world_routes_version") and host.config.get("world") == oracle.get("world") and host.config.get("map_rooms") == oracle.get("map_rooms"),
		"cold resumed region overlay matches independent synchronous oracle")
	_check(ROUTES.sync_manifest_parses == 0 and not bool(host.world_loader.last_transition.get("route_manifest_worker_is_main", true)),
		"cold resume keeps manifest parse on worker with no sync cache repair")
	# Exercise the real foreground travel path with an invalidated route cache.
	# The preflight must refresh through the loader's single worker before the
	# cache-only validator runs, then pin that validator's route generation.
	var prior_generation := ROUTES.cached_generation()
	ROUTES._cached_stamp = -1
	ROUTES.sync_manifest_parses = 0
	var target_id := "demo_ch01_moss_bell_court"
	var target_path := "res://data/%s.json" % target_id
	var target_raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(target_path))
	var target_entry := Vector2(target_raw.player_start[0], target_raw.player_start[1])
	var traveled: bool = await host.world_loader.replace_region_async(host, target_path, target_entry)
	_check(traveled and String(host.config.get("id", "")) == target_id and host.world_loader.phase == "idle",
		"foreground async travel refreshes a stale manifest and reaches its destination")
	_check(ROUTES.cached_generation() > prior_generation and ROUTES.cache_is_current(),
		"foreground travel publishes the refreshed manifest before validating and building")
	_check(ROUTES.sync_manifest_parses == 0 and not bool(host.world_loader.last_transition.get("route_manifest_worker_is_main", true)),
		"stale-cache foreground preflight reads and parses through the worker, never sync fallback")
	_check(int(host.world_loader.last_transition.get("preflight_route_generation", -1)) == ROUTES.cached_generation(),
		"foreground build pin equals the generation used by the completed validator")
	host.free()
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RESUME_SAVE + suffix))

func _teardown_probe(free_host: bool, at_final_finish: bool = false) -> void:
	var probe: Node = load(WORLD_SCENE).instantiate()
	probe.world_resume = false
	probe.world_save_path = SAVE
	root.add_child(probe)
	var loader: RefCounted = probe.world_loader
	var reached_build := false
	var reached_final_finish := false
	for _frame in range(600):
		await process_frame
		if not is_instance_valid(probe):
			break
		var state: Dictionary = loader.last_transition
		# The loader records max_build_operations only after a complete build
		# batch, immediately before its process_frame yield.
		if at_final_finish:
			if int(state.get("commit_jobs", 0)) > 0 and int(state.get("commit_cursor", 0)) == int(state.get("commit_jobs", 0)):
				reached_final_finish = true
				break
		elif free_host and state.has("jobs") and state.has("max_build_operations"):
			reached_build = true
			break
		if not free_host and int(state.get("prepare_cursor", 0)) > 0:
			break
	_check(is_instance_valid(probe) and loader.phase == "startup", "teardown probe reaches an active startup yield")
	_check(reached_final_finish if at_final_finish else (reached_build if free_host else int(loader.last_transition.get("prepare_cursor", 0)) > 0),
		"teardown probe observes its requested preparation/build phase")
	_check(not probe.initial_region_ready, "interrupted startup has not published before teardown")
	var token_ref: WeakRef = weakref(loader.startup_token)
	var loader_ref: WeakRef = weakref(loader)
	var reader_ref: WeakRef = weakref(loader.config_read_job)
	if free_host:
		probe.free()
	else:
		root.remove_child(probe)
	_check(loader.startup_token == null and token_ref.get_ref() == null and loader._startup_frame_tree == null,
		"interrupted startup releases its token and frame connection synchronously")
	for _frame in range(3):
		await process_frame
	_check(not is_instance_valid(probe) or not probe.is_inside_tree(), "startup coroutine exits cleanly after host teardown")
	if is_instance_valid(probe):
		probe.free()
	loader = null
	_check(loader_ref.get_ref() == null and reader_ref.get_ref() == null,
		"interrupted startup leaves no loader or reader after its host is freed")

func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	push_error("WORLD_STARTUP_BUDGET_CHECK_FAIL: " + label)
