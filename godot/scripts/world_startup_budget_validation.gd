extends SceneTree
## Compares the prior synchronous first-child construction with budgeted World
## startup in one process. Timings are observations, never hardware thresholds.
const WORLD_SCENE := "res://scenes/World.tscn"
const SAVE := "user://world_startup_budget_validation.json"

class SynchronousWorld:
	extends "res://scripts/main_level.gd"

	func _ready() -> void:
		_apply_cmdline_config_override()
		_prepare_world_start()
		world_loader = load("res://scripts/world_region_loader.gd").new()
		world_prefetch = load("res://scripts/world_prefetch.gd").new()
		world_passage = load("res://scripts/world_passage.gd").new()
		add_child(world_passage)
		world_passage.bind(self)
		_initialize_region()

var failures := 0

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

	var host: Node = load(WORLD_SCENE).instantiate()
	host.world_resume = false
	host.world_save_path = SAVE
	var attach_started := Time.get_ticks_usec()
	root.add_child(host)
	var first_frame_usec := Time.get_ticks_usec() - attach_started
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
	_check(int(metrics.get("max_prepare_operations", 99)) <= loader.MAX_OPERATIONS_PER_FRAME, "startup prepare batches honor the operation cap")
	_check(int(metrics.get("max_build_operations", 99)) <= loader.MAX_OPERATIONS_PER_FRAME, "startup build batches honor the operation cap")
	print("WORLD_STARTUP_TIMING sync_add_child_usec=%d budgeted_attach_usec=%d budgeted_total_usec=%d frames=%d max_observed_frame_gap_usec=%d prepare_work_usec=%d max_build_operations=%d" % [
		sync_attach_usec, first_frame_usec, total_startup_usec, frames, max_observed_frame_gap,
		int(metrics.get("prepare_work_usec", 0)), int(metrics.get("max_build_operations", 0))])
	# Teardown at both preparation and construction yields. Detached and freed
	# hosts must make their coroutine exit through its liveness guard.
	await _teardown_probe(false)
	await _teardown_probe(true)
	if is_instance_valid(host):
		root.remove_child(host)
		host.free()
	await process_frame
	if failures == 0:
		print("WORLD_STARTUP_BUDGET_VALIDATION_PASS")
	else:
		push_error("WORLD_STARTUP_BUDGET_VALIDATION_FAIL failures=%d" % failures)
	quit(0 if failures == 0 else 1)

func _teardown_probe(free_host: bool) -> void:
	var probe: Node = load(WORLD_SCENE).instantiate()
	probe.world_resume = false
	probe.world_save_path = SAVE
	root.add_child(probe)
	var loader: RefCounted = probe.world_loader
	var reached_build := false
	for _frame in range(600):
		await process_frame
		if not is_instance_valid(probe):
			break
		var state: Dictionary = loader.last_transition
		# The loader records max_build_operations only after a complete build
		# batch, immediately before its process_frame yield.
		if free_host and state.has("jobs") and state.has("max_build_operations"):
			reached_build = true
			break
		if not free_host and int(state.get("prepare_cursor", 0)) > 0:
			break
	_check(is_instance_valid(probe) and loader.phase == "startup", "teardown probe reaches an active startup yield")
	_check(reached_build if free_host else int(loader.last_transition.get("prepare_cursor", 0)) > 0,
		"teardown probe observes its requested preparation/build phase")
	if free_host:
		probe.free()
	else:
		root.remove_child(probe)
	for _frame in range(3):
		await process_frame
	_check(not is_instance_valid(probe) or not probe.is_inside_tree(), "startup coroutine exits cleanly after host teardown")
	if is_instance_valid(probe):
		probe.free()

func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	push_error("WORLD_STARTUP_BUDGET_CHECK_FAIL: " + label)
