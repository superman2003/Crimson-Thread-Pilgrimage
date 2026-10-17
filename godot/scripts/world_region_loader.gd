extends RefCounted
const CHARACTER_ART_WARM_JOB := preload("res://scripts/character_art_warm_job.gd")
## The World node is the persistent host. Only its region-owned children are
## evicted; the Player, WorldState and BuildSystem remain the same instances.
## This is a coarse active-region chunk, not yet distance-based room streaming.
const COORDINATES := preload("res://scripts/world_coordinates.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const CONFIG_READ_JOB := preload("res://scripts/world_config_read_job.gd")
var config_read_job := CONFIG_READ_JOB.new()
const CONFIG_VALIDATOR := preload("res://scripts/world_config_validator.gd")
const VARIANT_COPY_JOB := preload("res://scripts/world_variant_copy_job.gd")
const TRANSITION_TOKEN := preload("res://scripts/world_transition_token.gd")
const SESSION_FIELDS := ["player", "world_mode", "world_resume", "world_save_path",
    "world_startup_options_enabled", "world_save_blocked",
    "world_state", "world_slot", "world_loader", "build_system", "applied_build_profile",
    "world_catalog", "world_narrative", "world_write_error_shown", "world_prefetch", "world_passage",
    "world_shared_metadata_cache", "world_shared_metadata_reads", "world_shared_metadata_probes",
    "world_shared_metadata_bytes", "world_shared_metadata_parses", "world_shared_metadata_failures"]
var generation := 0
var active_region_id := ""
var phase := "idle"
var last_error := ""
var unloaded_nodes := 0
const MAX_OPERATIONS_PER_FRAME := 8
const FRAME_BUDGET_USEC := 2000
var cancel_requested := false
var shutting_down := false
var loading_canvas: CanvasLayer
var loading_label: Label
var last_transition: Dictionary = {}
var transition_token: RefCounted
var transition_serial := 0
var startup_token: RefCounted
# A speculative startup read stays private until the exact manifest is committed.
var startup_config_read_ahead: Dictionary = {}
# Startup owns its frame wakeups so whole-host shutdown can unwind its token
# before SceneTree stops emitting frames (including --quit-after).
signal _startup_frame_ready
var _startup_frame_tree: SceneTree
var manifest_refresh_running := false
var manifest_refresh_retry_after_msec := 0

func request_manifest_refresh(host: Node) -> void:
    if manifest_refresh_running or shutting_down or not _alive(host):
        return
    if Time.get_ticks_msec() < manifest_refresh_retry_after_msec:
        return
    if ROUTES.cache_is_current():
        return
    manifest_refresh_running = true
    _run_background_manifest_refresh(host)

func _run_background_manifest_refresh(host: Node) -> void:
    var tree := host.get_tree()
    while _alive(host) and host.get_tree() == tree and not shutting_down and phase == "idle" and config_read_job.busy():
        await tree.process_frame
    if not _alive(host) or host.get_tree() != tree or shutting_down or phase != "idle":
        manifest_refresh_running = false
        return
    manifest_refresh_running = false
    var refreshed: bool = await _prepare_routes_manifest(host, tree, true)
    if not _alive(host) or host.get_tree() != tree or phase != "idle":
        return
    if not refreshed:
        manifest_refresh_retry_after_msec = Time.get_ticks_msec() + 500
    elif host.has_method("_refresh_map_overlay") and host.get("active_overlay") == "map" and bool(host.get("world_map_view")):
        # A stale atlas intentionally draws nothing. Repaint the still-open
        # world view after publication, preserving its existing navigation state.
        host._refresh_map_overlay()

## Scene `_ready` must be fire-and-forget; this token gives the startup
## coroutine an owner that survives until success or host teardown.
func request_startup_region(host: Node, previous_mode: int) -> RefCounted:
    if shutting_down or not _alive(host) or phase != "idle":
        return null
    var token = TRANSITION_TOKEN.new()
    token.serial = transition_serial + 1
    transition_serial = token.serial
    startup_token = token
    phase = "startup"
    last_transition["startup_requested_frame"] = Engine.get_process_frames()
    last_transition["startup_requested_usec"] = Time.get_ticks_usec()
    _run_owned_startup(token, host, previous_mode)
    return token

func _run_owned_startup(token: RefCounted, host: Node, previous_mode: int) -> void:
    # The engine can still be attaching the main scene to the root while its
    # _ready runs. Reserve ownership now, but attach the root loading canvas
    # only after that scene-tree operation has finished.
    var tree: SceneTree = host.get_tree()
    await _next_process_frame(tree)
    if _alive(host) and host.get_tree() == tree:
        if token.cancelled:
            last_error = "初始区域加载已取消。"
            _show_startup_error(host)
        else:
            await initialize_startup_region(host, previous_mode)
    _discard_startup_config_read_ahead()
    token.finished = true
    if startup_token == token:
        startup_token = null
        _disconnect_startup_frames()
    if not _alive(host):
        phase = "idle"
        return
    host.process_mode = previous_mode

## Initial world boot uses the same bounded preparation/build/finish plan as
## travel. The synchronous initializer remains available to explicit fixtures.
func initialize_startup_region(host: Node, restore_process_mode: int = Node.PROCESS_MODE_INHERIT) -> bool:
    if not _alive(host):
        return false
    var tree: SceneTree = host.get_tree()
    phase = "startup"
    _show_loading_canvas(host)
    # Share the bounded JSON worker with foreground config reads. The ticket
    # ties the result to this startup generation and the manifest mtime.
    if not await _prepare_routes_manifest(host, tree):
        _discard_startup_config_read_ahead()
        if not _alive(host):
            phase = "idle"
            return false
        if last_error.is_empty():
            last_error = "区域路线清单后台读取或校验失败。"
        _show_startup_error(host)
        host.process_mode = restore_process_mode
        return false
    var startup_source_catalog: Dictionary = host.world_catalog
    var startup_route_generation := ROUTES.cached_generation()
    if host.has_method("_resolve_world_start_route") and not host._resolve_world_start_route():
        _discard_startup_config_read_ahead()
        last_error = "归途区域不在当前巡礼路线中。"
        _show_startup_error(host)
        host.process_mode = restore_process_mode
        return false
    var prepared: Dictionary = await _prepare_startup_config(host, tree)
    if not _alive(host) or host.get_tree() != tree:
        _clear_loading_canvas()
        phase = "idle"
        return false
    if prepared.is_empty():
        if last_error.is_empty(): last_error = "初始区域读取或验证期间发生变化。"
        _show_startup_error(host)
        host.process_mode = restore_process_mode
        return false
    var startup_config_lease: Dictionary = last_transition.startup_config_lease
    var built := await _construct_budgeted(host, prepared, false)
    if not _startup_config_context_valid(host, tree, startup_config_lease) or ROUTES.cached_generation() != startup_route_generation:
        built = false
        last_error = "区域路线清单在初始构建期间发生变化。"
    if not _alive(host) or host.get_tree() != tree or shutting_down:
        if is_instance_valid(host):
            host.world_catalog = startup_source_catalog
            _discard_catalog_staging(host)
        _clear_loading_canvas()
        phase = "idle"
        return false
    if built:
        built = await _finish_budgeted(host, false)
    if not _startup_config_context_valid(host, tree, startup_config_lease) or ROUTES.cached_generation() != startup_route_generation:
        built = false
        last_error = "区域路线清单在初始交接期间发生变化。"
    if not _alive(host) or host.get_tree() != tree or shutting_down:
        if is_instance_valid(host):
            host.world_catalog = startup_source_catalog
            _discard_catalog_staging(host)
        _clear_loading_canvas()
        phase = "idle"
        return false
    if built:
        host._publish_region()
    else:
        host.world_catalog = startup_source_catalog
        host.world_catalog_prepare_staging = {}
        last_error = "初始区域准备或构建任务未能完成。"
        _show_startup_error(host)
    if built:
        _clear_loading_canvas()
    if _alive(host) and host.get_tree() == tree:
        host.process_mode = restore_process_mode
    phase = "idle" if built else "startup_error"
    return built


## Startup has no travel entry until the route overlay is complete. The shared
## validator resolves the authored default then, or checks the saved override.
func _startup_config_context_valid(host: Variant, tree: SceneTree, lease: Dictionary) -> bool:
    return _alive(host) and (startup_token == null or not startup_token.cancelled) and host.get_tree() == tree and generation == int(lease.generation) and ROUTES.cached_generation() == int(lease.route_generation) and int(lease.route_generation) >= 0 and String(host.config_path) == String(lease.path) and host.entry_spawn_override_enabled == bool(lease.entry_enabled) and host.entry_spawn_override == lease.entry and (not lease.has("stamp") or FileAccess.get_modified_time(String(lease.path)) == int(lease.stamp))

func _discard_startup_config_read_ahead() -> void:
    if not startup_config_read_ahead.is_empty():
        config_read_job.discard(int(startup_config_read_ahead.ticket))
        startup_config_read_ahead.clear()

func _begin_startup_config_read_ahead(host: Node, tree: SceneTree, route_ticket: Dictionary) -> void:
    if phase != "startup" or not host.has_method("_resolve_world_start_route") or not startup_config_read_ahead.is_empty():
        return
    var chapters: Variant = route_ticket.manifest.get("chapters", {})
    if not chapters is Dictionary: return
    var start_region := String(host.world_start_region_id)
    var path := String(host.config_path) if start_region.is_empty() else "res://data/%s.json" % start_region
    var region_id := path.get_file().get_basename()
    # This is only a hint from the private manifest, not a published route.
    # Unknown/overridden paths use the normal validated startup admission.
    if path != "res://data/%s.json" % region_id or not chapters.has(region_id): return
    var ticket: int = config_read_job.request(path)
    # Speculation is optional: a failed launch falls back after manifest commit.
    if ticket == 0: return
    startup_config_read_ahead = {"ticket": ticket, "path": path,
        "host_id": host.get_instance_id(), "tree_id": tree.get_instance_id(),
        "generation": generation, "manifest_stamp": int(route_ticket.stamp),
        "route_generation": -1, "entry_enabled": host.entry_spawn_override_enabled,
        "entry": host.entry_spawn_override, "source_path": String(host.config_path),
        "start_region": start_region, "yield_frames": 0}

func _startup_config_read_ahead_source_valid(host: Node, tree: SceneTree) -> bool:
    if startup_config_read_ahead.is_empty(): return true
    var read: Dictionary = startup_config_read_ahead
    return _alive(host) and host.get_tree() == tree and host.get_instance_id() == int(read.host_id) and tree.get_instance_id() == int(read.tree_id) and generation == int(read.generation) and String(host.config_path) == String(read.source_path) and String(host.world_start_region_id) == String(read.start_region) and host.entry_spawn_override_enabled == bool(read.entry_enabled) and host.entry_spawn_override == read.entry and FileAccess.get_modified_time(ROUTES.ROUTES_PATH) == int(read.manifest_stamp)

func _prepare_startup_config(host: Node, tree: SceneTree) -> Dictionary:
    last_error = ""
    var wall_started := Time.get_ticks_usec()
    var lease := {"path": String(host.config_path), "generation": generation, "route_generation": ROUTES.cached_generation(),
        "entry_enabled": bool(host.entry_spawn_override_enabled), "entry": host.entry_spawn_override}
    last_transition["startup_config_lease"] = lease
    last_transition["startup_config_wait_frames"] = 0
    last_transition["startup_config_context_copy_batches"] = 0
    last_transition["startup_config_context_overlap_frames"] = 0
    last_transition["startup_config_context_copy_work_usec"] = 0
    last_transition["startup_config_context_copy_max_operations"] = 0
    last_transition["startup_config_context_copy_max_batch_usec"] = 0
    var ticket := 0
    last_transition["startup_config_manifest_overlap_frames"] = 0
    if not startup_config_read_ahead.is_empty():
        var ahead: Dictionary = startup_config_read_ahead
        if not _startup_config_context_valid(host, tree, lease) or host.get_instance_id() != int(ahead.host_id) or tree.get_instance_id() != int(ahead.tree_id) or int(lease.generation) != int(ahead.generation) or int(lease.route_generation) != int(ahead.route_generation) or String(lease.path) != String(ahead.path) or bool(lease.entry_enabled) != bool(ahead.entry_enabled) or lease.entry != ahead.entry or int(ahead.yield_frames) < 1 or FileAccess.get_modified_time(ROUTES.ROUTES_PATH) != int(ahead.manifest_stamp):
            _discard_startup_config_read_ahead()
            last_error = "初始区域预读归属已失效。"
            return {}
        ticket = int(ahead.ticket)
        last_transition.startup_config_manifest_overlap_frames = int(ahead.yield_frames)
        last_transition.startup_config_wait_frames = int(ahead.yield_frames)
        startup_config_read_ahead.clear()
    while ticket == 0:
        if not _startup_config_context_valid(host, tree, lease): return {}
        if config_read_job.closed:
            last_error = "初始区域后台读取服务已关闭。"
            return {}
        # A completed but unclaimed read still belongs to its accepted owner.
        # Match the modern manifest/catalog admission path without stealing it.
        if not config_read_job.busy() and not config_read_job.has_pending_ticket():
            ticket = config_read_job.request(String(lease.path))
            if ticket == 0:
                last_error = "无法启动初始区域后台读取。"
                return {}
            # The read owns only its JSON data. Copy the fixed route context
            # while it runs instead of spending a separate idle read frame.
            break
        await _next_process_frame(tree)
        last_transition.startup_config_wait_frames += 1
        if not _startup_config_context_valid(host, tree, lease):
            config_read_job.discard(ticket)
            return {}
    # The record-level validator contains hundreds of scalar checks. Running
    # eight on each main-thread frame adds over 120 frames before any build.
    # Give the sole reader a detached route context instead: it runs exactly
    # the same validator/overlay over private data without touching live caches.
    var region_id := String(lease.path).get_file().get_basename()
    var context := {"generation": int(lease.route_generation), "region_id": region_id,
        "known_region": COORDINATES.has_region(region_id), "path": ROUTES.cached_config_path(region_id),
        "world_size": COORDINATES.region_bounds(region_id).size,
        "bundle": ROUTES.cached_overlay_bundle(region_id)}
    var context_copy := VARIANT_COPY_JOB.new()
    context_copy.begin(context)
    last_transition["startup_config_context_copy_edges"] = 0
    last_transition["startup_config_context_max_step_edges"] = 0
    var validator_wall_started := Time.get_ticks_usec()
    while not context_copy.done:
        var started := Time.get_ticks_usec()
        var operations := 0
        while not context_copy.done and operations < MAX_OPERATIONS_PER_FRAME:
            if operations > 0 and Time.get_ticks_usec() - started >= FRAME_BUDGET_USEC: break
            var edges: int = context_copy.step(512)
            last_transition.startup_config_context_copy_edges += edges
            last_transition.startup_config_context_max_step_edges = maxi(last_transition.startup_config_context_max_step_edges, edges)
            operations += 1
        var work_usec := Time.get_ticks_usec() - started
        last_transition.startup_config_context_copy_batches += 1
        last_transition.startup_config_context_copy_work_usec += work_usec
        last_transition.startup_config_context_copy_max_operations = maxi(last_transition.startup_config_context_copy_max_operations, operations)
        last_transition.startup_config_context_copy_max_batch_usec = maxi(last_transition.startup_config_context_copy_max_batch_usec, work_usec)
        last_transition["startup_config_validator_operation"] = "route_context_copy"
        # This final-copy yield is also the read's cancellation window.
        # Keep its accepted ticket until both the read and private copy finish.
        await _next_process_frame(tree)
        last_transition.startup_config_context_overlap_frames += 1
        last_transition.startup_config_wait_frames += 1
        if not _startup_config_context_valid(host, tree, lease):
            config_read_job.discard(ticket)
            return {}
    while config_read_job.busy():
        await _next_process_frame(tree)
        last_transition.startup_config_wait_frames += 1
        if not _startup_config_context_valid(host, tree, lease):
            config_read_job.discard(ticket)
            return {}
    var read: Dictionary = config_read_job.take(ticket)
    last_error = String(read.get("error", "初始区域读取票据已失效。"))
    if not last_error.is_empty(): return {}
    lease["stamp"] = int(read.get("stamp", -1))
    last_transition["startup_config_worker_is_main"] = read.get("worker_is_main", true)
    last_transition["startup_config_worker_usec"] = read.get("worker_usec", 0)
    for key in ["open_usec", "read_usec", "parse_usec"]:
        last_transition["startup_config_" + key] = read.get(key, 0)
    last_transition["startup_config_bytes"] = read.get("bytes", 0)
    if not _startup_config_context_valid(host, tree, lease): return {}
    # No other task can acquire the reader between take and this admission:
    # phase=startup excludes background work, and no await follows the guard.
    ticket = config_read_job.request_validation(read.get("raw"), String(lease.path),
        lease.entry if lease.entry_enabled else Vector2.ZERO, not lease.entry_enabled, context_copy.result)
    if ticket == 0:
        last_error = "无法启动初始区域后台校验。"
        return {}
    last_transition["startup_config_validation_wait_frames"] = 0
    while true:
        # Always leave a cancellation window, even for an already-finished job.
        await _next_process_frame(tree)
        last_transition.startup_config_validation_wait_frames += 1
        if not _startup_config_context_valid(host, tree, lease):
            config_read_job.discard(ticket)
            return {}
        if not config_read_job.busy(): break
    var validated: Dictionary = config_read_job.take(ticket)
    last_transition["startup_config_validation_worker_is_main"] = validated.get("worker_is_main", true)
    last_transition["startup_config_validation_worker_usec"] = validated.get("worker_usec", 0)
    last_transition["startup_config_validation_steps"] = validated.get("validator_steps", 0)
    last_transition["startup_config_validator_operation"] = validated.get("validator_operation", "")
    last_transition["startup_config_validator_wall_usec"] = Time.get_ticks_usec() - validator_wall_started
    last_transition["startup_config_wall_usec"] = Time.get_ticks_usec() - wall_started
    last_error = String(validated.get("error", "初始区域校验票据已失效。"))
    return validated.get("prepared", {}) if last_error.is_empty() else {}



func _show_startup_error(host: Node) -> void:
    phase = "startup_error"
    host.world_initial_error = "旅途初始化失败：" + last_error
    printerr("WORLD STARTUP FAILED: " + last_error)
    # Region process loops deliberately remain gated. Recovery controls belong
    # to the root canvas, so they work even before a Player/UI was constructed.
    if not is_instance_valid(loading_canvas):
        _show_loading_canvas(host)
    loading_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
    loading_label.text = host.world_initial_error + "\n请检查游戏文件后重试。"
    var retry := Button.new()
    retry.name = "StartupRetry"
    retry.text = "重试加载"
    retry.add_theme_font_override("font", loading_label.get_theme_font("font"))
    retry.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    retry.offset_left = -100
    retry.offset_right = 100
    retry.offset_top = 70
    retry.offset_bottom = 114
    var slot: int = host.world_slot
    var save_path: String = host.world_save_path
    retry.pressed.connect(func():
        retry.disabled = true
        # Replace the failed host; partial construction cannot be reused. This
        # path reads the same slot and never saves the incomplete world.
        host.call_deferred("_replace_with_save_slot", slot, save_path))
    loading_canvas.add_child(retry)
    retry.grab_focus()

func _manifest_refresh_cancelled(background: bool) -> bool:
    if background:
        return phase != "idle"
    if phase == "startup" and startup_token != null and startup_token.cancelled:
        last_error = "初始区域加载已取消。"
        return true
    if phase != "preflight":
        return false
    _cancel_input()
    if cancel_requested:
        last_transition["preflight_cancelled"] = true
    return cancel_requested

func _prepare_routes_manifest(host: Node, tree: SceneTree, background: bool = false) -> bool:
    if not _alive(host) or host.get_tree() != tree or shutting_down:
        return false
    manifest_refresh_running = true
    var ticket_generation := generation + 1
    var ticket := 0
    while ticket == 0 and _alive(host) and host.get_tree() == tree and not shutting_down:
        if _manifest_refresh_cancelled(background):
            manifest_refresh_running = false
            return false
        if config_read_job.closed:
            break
        if config_read_job.busy() or config_read_job.has_pending_ticket():
            await _next_process_frame(tree)
            continue
        # With no worker or accepted owner, a rejected request is a launch
        # failure, not contention. Surface recovery instead of waiting forever.
        ticket = config_read_job.request(ROUTES.ROUTES_PATH)
        if ticket == 0:
            break
    if ticket == 0:
        manifest_refresh_running = false
        last_error = "无法启动区域路线清单后台读取。"
        return false
    # Always provide one cancellation window even if this small worker happens
    # to finish before the first status poll.
    await _next_process_frame(tree)
    if not _alive(host) or host.get_tree() != tree or shutting_down or _manifest_refresh_cancelled(background):
        config_read_job.discard(ticket)
        manifest_refresh_running = false
        return false
    while config_read_job.busy():
        await _next_process_frame(tree)
        if not _alive(host) or host.get_tree() != tree or shutting_down or _manifest_refresh_cancelled(background):
            config_read_job.discard(ticket)
            manifest_refresh_running = false
            return false
    if not _alive(host) or host.get_tree() != tree or shutting_down or _manifest_refresh_cancelled(background):
        config_read_job.discard(ticket)
        manifest_refresh_running = false
        return false
    var result: Dictionary = config_read_job.take(ticket)
    if not String(result.get("error", "")).is_empty():
        manifest_refresh_running = false
        last_error = String(result.error)
        return false
    var route_ticket: Dictionary = ROUTES.manifest_ticket(result, ticket_generation)
    if route_ticket.is_empty():
        manifest_refresh_running = false
        last_error = "区域路线清单校验未通过。"
        return false
    _begin_startup_config_read_ahead(host, tree, route_ticket)
    # Transfer the worker-owned parsed tree through the existing bounded copy
    # job. This keeps both recursive copying and cache publication off the
    # single synchronous handoff point. Each frame revalidates the file stamp.
    var copy_job := VARIANT_COPY_JOB.new()
    var copy_begin_started := Time.get_ticks_usec()
    copy_job.begin(route_ticket.manifest)
    var copy_begin_usec := Time.get_ticks_usec() - copy_begin_started
    var copy_started := Time.get_ticks_usec()
    var copy_batches := 0
    var copy_edges := 0
    var copy_max_step_usec := 0
    var copy_max_step_edges := 0
    var copy_max_operations := 0
    while not copy_job.done:
        var batch_started := Time.get_ticks_usec()
        var operations := 0
        while not copy_job.done and operations < MAX_OPERATIONS_PER_FRAME:
            if operations > 0 and Time.get_ticks_usec() - batch_started >= FRAME_BUDGET_USEC: break
            var step_started := Time.get_ticks_usec()
            var copied_edges: int = copy_job.step(512)
            var step_usec := Time.get_ticks_usec() - step_started
            copy_edges += copied_edges
            copy_max_step_edges = maxi(copy_max_step_edges, copied_edges)
            copy_max_step_usec = maxi(copy_max_step_usec, step_usec)
            operations += 1
        copy_max_operations = maxi(copy_max_operations, operations)
        copy_batches += 1
        if not startup_config_read_ahead.is_empty():
            startup_config_read_ahead.yield_frames += 1
        await _next_process_frame(tree)
        if not _alive(host) or host.get_tree() != tree or shutting_down or _manifest_refresh_cancelled(background) or not _startup_config_read_ahead_source_valid(host, tree):
            _discard_startup_config_read_ahead()
            manifest_refresh_running = false
            return false
        if ticket_generation != generation + 1 or int(route_ticket.stamp) != FileAccess.get_modified_time(ROUTES.ROUTES_PATH):
            _discard_startup_config_read_ahead()
            manifest_refresh_running = false
            last_error = "区域路线清单在交接期间发生变化。"
            return false
    route_ticket.manifest = copy_job.result
    if _manifest_refresh_cancelled(background):
        _discard_startup_config_read_ahead()
        manifest_refresh_running = false
        return false
    if not ROUTES.accept_manifest_ticket(route_ticket, ticket_generation):
        _discard_startup_config_read_ahead()
        manifest_refresh_running = false
        last_error = "区域路线清单校验未通过。"
        return false
    if not startup_config_read_ahead.is_empty():
        startup_config_read_ahead.route_generation = ROUTES.cached_generation()
    last_transition["route_manifest_worker_is_main"] = bool(result.get("worker_is_main", true))
    last_transition["route_manifest_worker_usec"] = int(result.get("worker_usec", 0))
    last_transition["route_manifest_bytes"] = int(result.get("bytes", 0))
    last_transition["route_manifest_copy_batches"] = copy_batches
    last_transition["route_manifest_copy_max_operations"] = copy_max_operations
    last_transition["route_manifest_copy_edges"] = copy_edges
    last_transition["route_manifest_copy_begin_usec"] = copy_begin_usec
    last_transition["route_manifest_copy_max_step_usec"] = copy_max_step_usec
    last_transition["route_manifest_copy_max_step_edges"] = copy_max_step_edges
    last_transition["route_manifest_copy_wall_usec"] = Time.get_ticks_usec() - copy_started
    manifest_refresh_running = false
    return true

func register_region(host: Node) -> void:
    active_region_id = String(host.config.get("id", ""))
    generation += 1

func snapshot(host: Node) -> Dictionary:
    return {"region_id": active_region_id, "generation": generation, "phase": phase,
        "resident_regions": 1 if not active_region_id.is_empty() else 0,
        "region_nodes": maxi(0, host.get_child_count() - 1),
        "unloaded_nodes": unloaded_nodes,
        "player_id": host.player.get_instance_id() if is_instance_valid(host.player) else 0,
        "world_bounds": COORDINATES.region_bounds(active_region_id)}

func preflight(path: String, entry: Vector2, prefetch: RefCounted = null) -> Dictionary:
    ROUTES.manifest_generation() # Explicit synchronous compatibility/oracle path.
    last_error = ""
    if prefetch != null:
        prefetch.cancel_config()
    if not entry.is_finite() or not FileAccess.file_exists(path):
        last_error = "目标位置或区域文件无效。"
        return {}
    var json_started := Time.get_ticks_usec()
    var parsed: Variant = prefetch.cached_raw(path) if prefetch != null else null
    if parsed == null:
        parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    last_transition["preflight_json_usec"] = Time.get_ticks_usec() - json_started
    return validate_config(parsed, path, entry)

func validate_config(parsed: Variant, path: String, entry: Vector2) -> Dictionary:
    last_error = ""
    ROUTES.manifest_generation() # Explicit synchronous compatibility/oracle path.
    var validator = CONFIG_VALIDATOR.new()
    validator.begin(parsed, path, entry)
    while not validator.done:
        validator.step()
    last_error = validator.error
    return validator.result

func _preflight_async(path: String, entry: Vector2, prefetch: RefCounted, host: Node) -> Dictionary:
    last_error = ""
    # Foreground travel owns the shared reader from here. A discarded neighbor
    # read may still run; the existing frame loop waits for it before request.
    if prefetch != null:
        prefetch.cancel_config()
    var wall_started := Time.get_ticks_usec()
    var json_started := Time.get_ticks_usec()
    last_transition["preflight_cursor"] = 0
    last_transition["preflight_batches"] = 0
    last_transition["preflight_work_usec"] = 0
    last_transition["preflight_wall_usec"] = 0
    last_transition["preflight_operation_usec"] = {}
    last_transition["preflight_batch_operations"] = []
    last_transition["preflight_cancelled"] = false
    last_transition["preflight_done"] = false
    last_transition["preflight_progress"] = 0.0
    last_transition["preflight_max_operations"] = 0
    last_transition["preflight_max_batch_usec"] = 0
    last_transition["preflight_copy_steps"] = 0
    last_transition["preflight_copy_edges"] = 0
    last_transition["preflight_copy_batches"] = 0
    last_transition["preflight_copy_work_usec"] = 0
    last_transition["preflight_copy_wall_usec"] = 0
    last_transition["preflight_copy_max_step_edges"] = 0
    last_transition["preflight_copy_max_batch_usec"] = 0
    last_transition["preflight_copy_batch_steps"] = []
    last_transition["preflight_copy_batch_edges"] = []
    last_transition["preflight_copy_batch_work_usec"] = []
    last_transition["preflight_copy_batch_wall_usec"] = []
    var parsed: Variant = null
    last_transition["json_background"] = false
    last_transition["json_wait_frames"] = 0
    last_transition["json_worker_is_main"] = true
    last_transition["json_worker_usec"] = 0
    last_transition["json_bytes"] = 0
    if not entry.is_finite() or not FileAccess.file_exists(path):
        last_error = "目标位置或区域文件无效。"
    else:
        # Foreground preflight owns the same sole reader used by neighbor
        # requests. Refresh a cold/stale route manifest before config parsing
        # or the cache-only validator starts; background staging observes the
        # foreground phase and drops its unpublished result.
        if not ROUTES.cache_is_current():
            if not await _prepare_routes_manifest(host, host.get_tree()):
                if last_error.is_empty():
                    last_error = "区域路线清单尚未准备好。"
                last_transition["preflight_wall_usec"] = Time.get_ticks_usec() - wall_started
                return {}
        if not ROUTES.cache_is_current():
            last_error = "区域路线清单在预检开始前已失效。"
            last_transition["preflight_wall_usec"] = Time.get_ticks_usec() - wall_started
            return {}
        last_transition["preflight_route_generation"] = ROUTES.cached_generation()
        var borrowed: Variant = prefetch._cached_raw_borrow(path) if prefetch != null else null
        if borrowed != null:
            var copy_job = VARIANT_COPY_JOB.new()
            copy_job.begin(borrowed)
            var copy_wall_started := Time.get_ticks_usec()
            while not copy_job.done:
                var batch_started := Time.get_ticks_usec()
                var steps := 0
                var batch_edges := 0
                var batch_work_usec := 0
                while not copy_job.done and steps < MAX_OPERATIONS_PER_FRAME:
                    if steps > 0 and Time.get_ticks_usec() - batch_started >= FRAME_BUDGET_USEC:
                        break
                    var copy_step_started := Time.get_ticks_usec()
                    var copied := copy_job.step(512)
                    var copy_step_usec := Time.get_ticks_usec() - copy_step_started
                    if copied <= 0:
                        break
                    steps += 1
                    last_transition["preflight_copy_steps"] = int(last_transition["preflight_copy_steps"]) + 1
                    last_transition["preflight_copy_edges"] = int(last_transition["preflight_copy_edges"]) + copied
                    last_transition["preflight_copy_work_usec"] = int(last_transition["preflight_copy_work_usec"]) + copy_step_usec
                    last_transition["preflight_copy_max_step_edges"] = maxi(int(last_transition["preflight_copy_max_step_edges"]), copied)
                    batch_edges += copied
                    batch_work_usec += copy_step_usec
                var batch_wall_usec := Time.get_ticks_usec() - batch_started
                last_transition["preflight_copy_max_batch_usec"] = maxi(int(last_transition["preflight_copy_max_batch_usec"]), batch_wall_usec)
                var batch_steps_list: Array = last_transition["preflight_copy_batch_steps"]
                batch_steps_list.append(steps)
                last_transition["preflight_copy_batch_steps"] = batch_steps_list
                var batch_edges_list: Array = last_transition["preflight_copy_batch_edges"]
                batch_edges_list.append(batch_edges)
                last_transition["preflight_copy_batch_edges"] = batch_edges_list
                var batch_work_list: Array = last_transition["preflight_copy_batch_work_usec"]
                batch_work_list.append(batch_work_usec)
                last_transition["preflight_copy_batch_work_usec"] = batch_work_list
                var batch_wall_list: Array = last_transition["preflight_copy_batch_wall_usec"]
                batch_wall_list.append(batch_wall_usec)
                last_transition["preflight_copy_batch_wall_usec"] = batch_wall_list
                last_transition["preflight_copy_batches"] = int(last_transition["preflight_copy_batches"]) + 1
                await host.get_tree().process_frame
                last_transition["preflight_copy_wall_usec"] = Time.get_ticks_usec() - copy_wall_started
                if not _alive(host):
                    last_transition["preflight_cancelled"] = true
                    return {}
                _cancel_input()
                if cancel_requested:
                    last_transition["preflight_cancelled"] = true
                    return {}
            parsed = copy_job.result
        else:
            parsed = null
        if parsed == null:
            # A cancelled read still owns its thread until completion. Wait in
            # frames before admitting the next one, never queue unbounded work.
            var ticket := 0
            while true:
                if ticket == 0 and not config_read_job.busy():
                    ticket = config_read_job.request(path)
                    if ticket == 0:
                        last_error = "无法启动区域后台读取。"
                        break
                last_transition["json_background"] = true
                # Yield even when a tiny file has already completed: the caller
                # always gets a cancellation window before validator/handoff.
                await host.get_tree().process_frame
                last_transition["json_wait_frames"] += 1
                if not _alive(host):
                    config_read_job.discard(ticket)
                    return {}
                _cancel_input()
                if cancel_requested:
                    config_read_job.discard(ticket)
                    last_transition["preflight_cancelled"] = true
                    last_transition["preflight_json_usec"] = Time.get_ticks_usec() - json_started
                    last_transition["preflight_wall_usec"] = Time.get_ticks_usec() - wall_started
                    return {}
                if ticket != 0 and not config_read_job.busy():
                    break
            if ticket != 0:
                var read: Dictionary = config_read_job.take(ticket)
                last_error = String(read.get("error", "目标区域后台读取已失效。"))
                parsed = read.get("raw")
                last_transition["json_worker_usec"] = int(read.get("worker_usec", 0))
                last_transition["json_bytes"] = int(read.get("bytes", 0))
                last_transition["json_worker_is_main"] = read.get("worker_is_main", true)
    last_transition["preflight_json_usec"] = Time.get_ticks_usec() - json_started
    if not last_error.is_empty():
        last_transition["preflight_wall_usec"] = Time.get_ticks_usec() - wall_started
        return {}
    var validator = CONFIG_VALIDATOR.new()
    validator.begin(parsed, path, entry)
    while not validator.done:
        var batch_started := Time.get_ticks_usec()
        var operations := 0
        while not validator.done and operations < MAX_OPERATIONS_PER_FRAME:
            # The budget admits the next bounded validator step; one step is
            # indivisible and may itself exceed the nominal 2ms admission.
            if operations > 0 and Time.get_ticks_usec() - batch_started >= FRAME_BUDGET_USEC:
                break
            var operation_started := Time.get_ticks_usec()
            validator.step()
            var operation_usec := Time.get_ticks_usec() - operation_started
            var opname := String(validator.operation_name)
            var timings: Dictionary = last_transition["preflight_operation_usec"]
            timings[opname] = int(timings.get(opname, 0)) + operation_usec
            last_transition["preflight_work_usec"] = int(last_transition["preflight_work_usec"]) + operation_usec
            last_transition["preflight_cursor"] = int(last_transition["preflight_cursor"]) + 1
            last_transition["preflight_operation_usec"] = timings
            operations += 1
        last_transition["preflight_batches"] = int(last_transition["preflight_batches"]) + 1
        var batch_usec := Time.get_ticks_usec() - batch_started
        last_transition["preflight_max_operations"] = maxi(int(last_transition["preflight_max_operations"]), operations)
        last_transition["preflight_max_batch_usec"] = maxi(int(last_transition["preflight_max_batch_usec"]), batch_usec)
        var counts: Array = last_transition["preflight_batch_operations"]
        counts.append(operations)
        last_transition["preflight_batch_operations"] = counts
        last_transition["preflight_done"] = validator.done
        last_transition["preflight_progress"] = validator.progress
        if is_instance_valid(loading_label):
            loading_label.text = "正在检查旧路… %d%%\nEsc 返回来路" % int(validator.progress * 100.0)
        # Yield on the final batch too. The source is not handed off until the
        # caller resumes here and observes that cancellation was not requested.
        await host.get_tree().process_frame
        last_transition["preflight_wall_usec"] = Time.get_ticks_usec() - wall_started
        if not _alive(host):
            last_transition["preflight_cancelled"] = true
            return {}
        _cancel_input()
        if cancel_requested:
            last_transition["preflight_cancelled"] = true
            return {}
    last_transition["preflight_wall_usec"] = Time.get_ticks_usec() - wall_started
    last_error = validator.error
    var validated_route_generation: int = int(validator._manifest_generation)
    if not validator.result.is_empty() and ROUTES.cached_generation() != validated_route_generation:
        last_error = "巡礼路线版本在预检完成时已变化，请重试。"
        return {}
    last_transition["preflight_route_generation"] = validated_route_generation
    return validator.result

func _finite_tuple(value: Variant, length: int) -> bool:
    if not value is Array or value.size() != length:
        return false
    for component in value:
        if typeof(component) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(component)):
            return false
    return true


func replace_region(host: Node, path: String, entry: Vector2) -> bool:
    # A rejected second request must not overwrite the in-flight preflight's
    # error field while its cache copy/reader is yielding between frames.
    if phase != "idle":
        return false
    if not is_instance_valid(host.player):
        last_error = "区域正在装载。"
        return false
    phase = "preflight"
    var target := preflight(path, entry, host.world_prefetch)
    if target.is_empty():
        phase = "idle"
        return false
    var previous_id := String(host.config.get("id", ""))
    var previous_mode: int = host.process_mode
    host.process_mode = Node.PROCESS_MODE_DISABLED
    # Remove phase collision exceptions while their old terrain still exists.
    host.player.prepare_region_handoff()
    # A build may refund part of an interrupted heal. Capture its settled
    # resource amount, rather than restoring the pre-cancellation snapshot.
    host._save_world()
    host.world_loading = true
    host._stop_region_tweens()
    host._release_region_audio()
    host._release_region_platforms()
    phase = "unloading"
    for child in host.get_children():
        if child == host.player or child == host.world_passage:
            continue
        host.remove_child(child)
        child.free()
        unloaded_nodes += 1
    _reset_region_fields(host)
    host.config_path = path
    host.world_loading = true
    host.chapter_transitioning = true
    host.entry_spawn_override_enabled = true
    host.entry_spawn_override = entry
    host.entered_from_config_id = previous_id
    host.transition_entry_message = "旧路重新接通 · " + String(target.get("name", ""))
    phase = "loading"
    host._initialize_region(target)
    host.chapter_transitioning = false
    host.player.reset_camera_after_arrival()
    host.process_mode = previous_mode
    phase = "idle"
    return true


func _reset_region_fields(host: Node) -> void:
    # Get typed defaults from a detached controller, without running _ready.
    # New region fields therefore cannot accidentally inherit the previous zone.
    var defaults: Node = host.get_script().new()
    for property in defaults.get_property_list():
        var name := String(property.name)
        if (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0 or name in SESSION_FIELDS:
            continue
        var value: Variant = defaults.get(name)
        host.set(name, value.duplicate(true) if value is Array or value is Dictionary else value)
    defaults.free()


## Escape requests rollback while geometry or arrival/UI jobs are incomplete. Permanent
## progress is restored from the settled departure snapshot; transient attacks
## are cancelled and source enemies are reconstructed, as on ordinary revisit.
func cancel_transition() -> void:
    if phase in ["preflight", "unloading", "loading", "committing"]:
        cancel_requested = true


## Preserve normal frame boundaries. Only an owned startup uses the private
## signal; foreground travel and background refresh retain their existing waits.
func _next_process_frame(tree: SceneTree) -> Signal:
    if startup_token == null:
        return tree.process_frame
    if _startup_frame_tree != tree:
        _disconnect_startup_frames()
        _startup_frame_tree = tree
        tree.process_frame.connect(_wake_startup_frame)
    return _startup_frame_ready

func _wake_startup_frame() -> void:
    _startup_frame_ready.emit()

func _disconnect_startup_frames() -> void:
    if is_instance_valid(_startup_frame_tree) and _startup_frame_tree.process_frame.is_connected(_wake_startup_frame):
        _startup_frame_tree.process_frame.disconnect(_wake_startup_frame)
    _startup_frame_tree = null

## A scalar-only exit snapshot keeps verbose release failures diagnosable even
## when the frame deadline stops startup before publication. Never emit the
## lease, config, save, paths, or token payload from last_transition.
func _startup_exit_snapshot() -> Dictionary:
    var stage := "manifest"
    if last_transition.has("startup_config_context_copy_batches"): stage = "config_read_context"
    if last_transition.has("startup_config_validation_wait_frames"): stage = "config_validation"
    if last_transition.has("prepare_jobs"): stage = "prepare"
    if last_transition.has("jobs"): stage = "build"
    if last_transition.has("commit_jobs"): stage = "finish"
    if not active_region_id.is_empty() and startup_token == null: stage = "published"
    var snapshot := {
        "phase": phase if phase in ["idle", "startup", "startup_error"] else "other",
        "stage": stage, "generation": generation,
        "elapsed_frames": maxi(0, Engine.get_process_frames() - int(last_transition.get("startup_requested_frame", Engine.get_process_frames()))),
        "elapsed_usec": maxi(0, Time.get_ticks_usec() - int(last_transition.get("startup_requested_usec", Time.get_ticks_usec()))),
        "startup_pending": startup_token != null,
        "startup_cancelled": startup_token != null and startup_token.cancelled,
        "shutting_down": shutting_down, "cancel_requested": cancel_requested,
        "reader_busy": config_read_job.busy(),
        "reader_pending": config_read_job.has_pending_ticket(), "reader_closed": config_read_job.closed}
    for key in ["route_manifest_copy_batches", "route_manifest_worker_usec", "route_manifest_copy_wall_usec",
            "startup_config_wait_frames", "startup_config_worker_usec", "startup_config_manifest_overlap_frames",
            "startup_config_open_usec", "startup_config_read_usec", "startup_config_parse_usec", "startup_config_context_copy_batches",
            "startup_config_context_overlap_frames", "startup_config_context_copy_work_usec",
            "startup_config_validation_wait_frames", "startup_config_validation_worker_usec", "startup_config_wall_usec",
            "prepare_cursor", "prepare_jobs", "prepare_batches", "prepare_work_usec", "prepare_wall_usec",
            "jobs", "build_cursor", "build_batches", "commit_cursor", "commit_jobs", "commit_batches",
            "commit_work_usec", "commit_wall_usec", "max_build_operations", "max_commit_operations", "max_batch_usec"]:
        var value: Variant = last_transition.get(key, 0)
        snapshot[key] = value if value is int or value is float else -1
    snapshot["catalog_read_count"] = 0
    for key in ["wait_frames", "read_overlap_frames", "worker_usec", "merge_frame_batches"]:
        snapshot["catalog_" + key] = 0
    var reads: Variant = last_transition.get("catalog_reads", [])
    if reads is Array:
        for read in reads:
            if not read is Dictionary: continue
            snapshot.catalog_read_count += 1
            for key in ["wait_frames", "read_overlap_frames", "worker_usec", "merge_frame_batches"]:
                var value: Variant = read.get(key, 0)
                if value is int or value is float: snapshot["catalog_" + key] += value
    return snapshot

func _write_startup_exit_snapshot(snapshot: Dictionary) -> void:
    print("WORLD_STARTUP_EXIT " + JSON.stringify(snapshot))

func shutdown() -> void:
    # Observe the live owner before cancellation/join/clear. The existing
    # shutdown latch also makes repeated teardown emit at most once.
    if not shutting_down and OS.is_stdout_verbose() and last_transition.has("startup_requested_frame"):
        _write_startup_exit_snapshot(_startup_exit_snapshot())
    shutting_down = true
    cancel_requested = true
    if transition_token != null:
        transition_token.cancel()
    if startup_token != null:
        startup_token.cancel()
    _discard_startup_config_read_ahead()
    config_read_job.shutdown()
    phase = "idle"
    _clear_loading_canvas()
    _disconnect_startup_frames()
    # All startup continuations see shutting_down and return without publishing.
    # Merely setting token.cancelled leaves its await stack alive if no next
    # SceneTree frame exists, which leaks the token on Godot 4.6.1 at exit.
    _wake_startup_frame()


func _clear_loading_canvas() -> void:
    if is_instance_valid(loading_canvas):
        loading_canvas.queue_free()
    loading_canvas = null
    loading_label = null


func _show_loading_canvas(host: Node) -> void:
    loading_canvas = CanvasLayer.new()
    loading_canvas.layer = 100
    host.get_tree().root.add_child(loading_canvas)
    var shade := ColorRect.new()
    shade.color = Color(0.035, 0.025, 0.045, 1.0)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    loading_canvas.add_child(shade)
    loading_label = Label.new()
    loading_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    loading_label.add_theme_font_override("font", load("res://assets/fonts/NotoSansSC.ttf"))
    loading_label.add_theme_font_size_override("font_size", 22)
    loading_canvas.add_child(loading_label)
    loading_label.text = "正在接通旧路…\nEsc 返回来路"


func _alive(host: Variant) -> bool:
    return not shutting_down and is_instance_valid(host) and host.is_inside_tree()


func _cancel_input() -> void:
    if Input.is_physical_key_pressed(KEY_ESCAPE):
        cancel_transition()


func _measure_batch(operations: int, started: int, metric: String) -> void:
    last_transition[metric] = maxi(int(last_transition.get(metric, 0)), operations)
    last_transition["max_batch_usec"] = maxi(int(last_transition.get("max_batch_usec", 0)), Time.get_ticks_usec() - started)
    last_transition["batches"] = int(last_transition.get("batches", 0)) + 1


func _evict_budgeted(host: Node) -> bool:
    # Snapshot only the nodes that belong to this generation. Freed entries may
    # be invalidated by another node's exit callback; never dereference them.
    var children: Array = host.get_children()
    var cursor := 0
    while cursor < children.size():
        var started := Time.get_ticks_usec()
        var operations := 0
        while cursor < children.size() and operations < MAX_OPERATIONS_PER_FRAME:
            if operations > 0 and Time.get_ticks_usec() - started >= FRAME_BUDGET_USEC:
                break
            var child: Variant = children[cursor]
            cursor += 1
            if not is_instance_valid(child) or child == host.player or child == host.world_passage or child.get_parent() != host:
                continue
            host.remove_child(child)
            child.free()
            unloaded_nodes += 1
            operations += 1
        _measure_batch(operations, started, "max_unload_operations")
        await host.get_tree().process_frame
        if not _alive(host):
            return false
        _cancel_input()
        # Cancellation cannot leave old physics half resident; finish retirement
        # before restoring the source from its immutable settled snapshot.
    return true



## Sequential cold-catalog reads share the loader's single ticket service.
## Parsed region trees are worker-owned; only catalog entries survive handoff.
func _catalog_context_valid(host: Variant, tree: SceneTree, expected_generation: int, route_generation: int, cancellable: bool) -> bool:
    return _alive(host) and (phase != "startup" or not last_transition.has("startup_config_lease") or _startup_config_context_valid(host, tree, last_transition.startup_config_lease)) and host.get_tree() == tree and generation == expected_generation and route_generation >= 0 and ROUTES.cached_generation() == route_generation and (not cancellable or not cancel_requested)

func _discard_catalog_lookahead(read_ahead: Dictionary) -> void:
    if not read_ahead.is_empty():
        config_read_job.discard(int(read_ahead.ticket))
        read_ahead.clear()

func _discard_catalog_staging(host: Variant, read_ahead: Dictionary = {}) -> void:
    _discard_catalog_lookahead(read_ahead)
    if is_instance_valid(host):
        host.world_catalog_prepare_staging = {}

func _prepare_catalog_region_async(host: Node, region_id: String, route_catalog: Dictionary, tree: SceneTree, expected_generation: int, route_generation: int, cancellable: bool, source_path: String = "", read_ahead: Dictionary = {}, next_region_id: String = "") -> bool:
    var path := source_path if not source_path.is_empty() else "res://data/%s.json" % region_id
    var wall_started := Time.get_ticks_usec()
    var wait_frames := 0
    var ticket := 0
    var overlap_frames := 0
    if not read_ahead.is_empty():
        # Only the adjacent catalog job may claim this construct-owned ticket.
        # Its predecessor must have crossed a real merge cancellation window.
        if not _catalog_context_valid(host, tree, expected_generation, route_generation, cancellable) or String(read_ahead.path) != path or String(read_ahead.region_id) != region_id or int(read_ahead.host_id) != host.get_instance_id() or int(read_ahead.tree_id) != tree.get_instance_id() or int(read_ahead.generation) != expected_generation or int(read_ahead.route_generation) != route_generation or int(read_ahead.yield_frames) < 1:
            last_error = "物品目录预读归属已失效。"
            _discard_catalog_staging(host, read_ahead)
            return false
        ticket = int(read_ahead.ticket)
        overlap_frames = int(read_ahead.yield_frames)
        wait_frames = overlap_frames
        read_ahead.clear()
    while ticket == 0:
        if not _catalog_context_valid(host, tree, expected_generation, route_generation, cancellable):
            _discard_catalog_staging(host, read_ahead)
            return false
        if config_read_job.closed:
            last_error = "物品目录后台读取服务已关闭。"
            _discard_catalog_staging(host, read_ahead)
            return false
        # A completed ticket still belongs to its current owner. Wait for
        # take/discard just as the modern manifest path does; never steal it.
        if not config_read_job.busy() and not config_read_job.has_pending_ticket():
            ticket = config_read_job.request(path)
            if ticket == 0:
                last_error = "无法启动物品目录后台读取。"
                _discard_catalog_staging(host, read_ahead)
                return false
        # Even a tiny completed read must offer a cancellation window.
        await _next_process_frame(tree)
        wait_frames += 1
        _cancel_input()
        if not _catalog_context_valid(host, tree, expected_generation, route_generation, cancellable):
            config_read_job.discard(ticket)
            _discard_catalog_staging(host, read_ahead)
            return false
    while config_read_job.busy():
        await _next_process_frame(tree)
        wait_frames += 1
        _cancel_input()
        if not _catalog_context_valid(host, tree, expected_generation, route_generation, cancellable):
            config_read_job.discard(ticket)
            _discard_catalog_staging(host, read_ahead)
            return false
    var read: Dictionary = config_read_job.take(ticket)
    var raw: Variant = read.get("raw")
    if not String(read.get("error", "物品目录读取票据已失效。")).is_empty() or not raw is Dictionary:
        last_error = String(read.get("error", "物品目录读取票据已失效。"))
        if last_error.is_empty(): last_error = "物品目录记录无法读取。"
        _discard_catalog_staging(host, read_ahead)
        return false
    var stamp := int(read.get("stamp", -1))
    var record := {"region_id": region_id, "path": path, "stamp": stamp, "bytes": read.get("bytes", 0),
        "worker_is_main": read.get("worker_is_main", true), "worker_usec": read.get("worker_usec", 0),
        "generation": expected_generation, "route_generation": route_generation, "merged_entries": 0, "merge_work_usec": 0, "max_merge_step_usec": 0, "merge_batches": 0, "max_merge_edges": 0, "wait_frames": wait_frames, "read_overlap_frames": overlap_frames, "wall_usec": 0}
    var reads: Array = last_transition.get("catalog_reads", [])
    reads.append(record)
    last_transition["catalog_reads"] = reads
    var inventory: Variant = raw.get("inventory", {})
    var catalog: Variant = inventory.get("catalog", {}) if inventory is Dictionary else null
    if not catalog is Dictionary:
        last_error = "物品目录格式无效。"
        _discard_catalog_staging(host, read_ahead)
        return false
    if not _catalog_context_valid(host, tree, expected_generation, route_generation, cancellable) or FileAccess.get_modified_time(path) != stamp:
        last_error = "物品目录在预读交接前发生变化。"
        _discard_catalog_staging(host, read_ahead)
        return false
    var merge_batch_started := Time.get_ticks_usec()
    if not next_region_id.is_empty():
        # The current result has been taken; the sole reader is free. Keep the
        # next raw result private while this source merges in authored order.
        var next_path := "res://data/%s.json" % next_region_id
        var next_ticket: int = config_read_job.request(next_path)
        if next_ticket == 0:
            last_error = "无法启动下一物品目录后台读取。"
            _discard_catalog_staging(host, read_ahead)
            return false
        read_ahead.merge({"ticket": next_ticket, "path": next_path, "region_id": next_region_id,
            "host_id": host.get_instance_id(), "tree_id": tree.get_instance_id(),
            "generation": expected_generation, "route_generation": route_generation, "yield_frames": 0})
    # Avoid cloning the whole region. Region and route dictionaries already
    # have private ownership; route entries overwrite local entries, then the
    # first route in authored order wins the global key.
    var sources := [route_catalog, catalog]
    var source_index := 0
    var keys: Array = sources[0].keys()
    var cursor := 0
    record["merge_frame_batches"] = 0
    record["max_merge_operations"] = 0
    while source_index < sources.size():
        # Include next-thread admission in this first merge frame's budget.
        var frame_started := merge_batch_started
        var operations := 0
        while source_index < sources.size() and operations < MAX_OPERATIONS_PER_FRAME:
            if operations > 0 and Time.get_ticks_usec() - frame_started >= FRAME_BUDGET_USEC: break
            if not _catalog_context_valid(host, tree, expected_generation, route_generation, cancellable) or FileAccess.get_modified_time(path) != stamp:
                last_error = "物品目录在交接期间发生变化。"
                _discard_catalog_staging(host, read_ahead)
                return false
            if cursor >= keys.size():
                source_index += 1
                if source_index < sources.size(): keys = sources[source_index].keys()
                cursor = 0
                continue
            var source: Dictionary = sources[source_index]
            var merge_started := Time.get_ticks_usec()
            var batch_edges := mini(64, keys.size() - cursor)
            var end := cursor + batch_edges
            while cursor < end:
                var key: Variant = keys[cursor]
                if not host.world_catalog_prepare_staging.has(key):
                    host.world_catalog_prepare_staging[key] = source[key]
                    record.merged_entries += 1
                cursor += 1
            var merge_usec := Time.get_ticks_usec() - merge_started
            record.merge_batches += 1
            record.max_merge_edges = maxi(record.max_merge_edges, batch_edges)
            record.merge_work_usec += merge_usec
            record.max_merge_step_usec = maxi(record.max_merge_step_usec, merge_usec)
            operations += 1
        record.merge_frame_batches += 1
        record.max_merge_operations = maxi(record.max_merge_operations, operations)
        # The two short catalog sources can share a bounded frame batch.
        # Still yield after the last chunk so cancellation/stamp changes cannot
        # publish populated staging without their normal observation window.
        await _next_process_frame(tree)
        if not read_ahead.is_empty(): read_ahead.yield_frames += 1
        _cancel_input()
        merge_batch_started = Time.get_ticks_usec()
    if not _catalog_context_valid(host, tree, expected_generation, route_generation, cancellable) or FileAccess.get_modified_time(path) != stamp:
        _discard_catalog_staging(host, read_ahead)
        return false
    record.wall_usec = Time.get_ticks_usec() - wall_started
    return true


func _construct_budgeted(host: Node, target: Dictionary, cancellable: bool) -> bool:
    var prepare_wall_started := Time.get_ticks_usec()
    var prepare_tree := host.get_tree()
    var prepare_generation := generation
    var prepare_route_generation := ROUTES.cached_generation()
    last_transition["catalog_reads"] = []
    # One optional next-read ticket is owned by this invocation, never a
    # shared cache or a second reader. Every failure path drains its ownership.
    var catalog_read_ahead := {}
    var prepare_jobs: Array = host._region_prepare_jobs(target)
    last_transition["prepare_plan_usec"] = Time.get_ticks_usec() - prepare_wall_started
    var prepare_role := "target" if cancellable else "rollback"
    var prepare_cursor := 0
    last_transition["prepare_jobs"] = prepare_jobs.size()
    last_transition["prepare_cursor"] = 0
    last_transition["prepare_batches"] = 0
    last_transition["prepare_batch_operations"] = []
    last_transition["prepare_work_usec"] = 0
    last_transition["prepare_wall_usec"] = 0
    last_transition["max_prepare_operations"] = 0
    last_transition["max_prepare_batch_usec"] = 0
    last_transition["max_prepare_job_usec"] = 0
    last_transition["prepare_operation_usec"] = {}
    while prepare_cursor < prepare_jobs.size():
        if not _catalog_context_valid(host, prepare_tree, prepare_generation, prepare_route_generation, cancellable):
            _discard_catalog_staging(host, catalog_read_ahead)
            _finalize_prepare_metrics(prepare_role, prepare_wall_started)
            return false
        var prepare_batch_started := Time.get_ticks_usec()
        var prepare_operations := 0
        var catalog_yielded := false
        while prepare_cursor < prepare_jobs.size() and prepare_operations < MAX_OPERATIONS_PER_FRAME:
            # The budget admits the next job; one job itself cannot be
            # preempted and may exceed the nominal frame budget.
            if prepare_operations > 0 and Time.get_ticks_usec() - prepare_batch_started >= FRAME_BUDGET_USEC:
                break
            var prepare_job: Dictionary = prepare_jobs[prepare_cursor]
            var prepare_method := String(prepare_job.get("method", ""))
            var prepare_args: Array = prepare_job.get("args", [])
            if prepare_method == "_prepare_world_catalog_region" and prepare_operations > 0:
                break
            var job_started := Time.get_ticks_usec()
            var prepare_result: Variant
            if prepare_method == "_prepare_world_catalog_region":
                var next_region_id := ""
                if prepare_cursor + 1 < prepare_jobs.size():
                    var next_job: Dictionary = prepare_jobs[prepare_cursor + 1]
                    if String(next_job.get("method", "")) == "_prepare_world_catalog_region":
                        next_region_id = String(next_job.args[0])
                if not await _prepare_catalog_region_async(host, String(prepare_args[0]), prepare_args[1], prepare_tree, prepare_generation, prepare_route_generation, cancellable, "", catalog_read_ahead, next_region_id):
                    _discard_catalog_staging(host, catalog_read_ahead)
                    _finalize_prepare_metrics(prepare_role, prepare_wall_started)
                    return false
                # The final merge already yielded and checked the lease.
                # No synchronous prepare job has run in this resumed frame.
                catalog_yielded = true
                # Worker wait/merge yields are outside the synchronous job budget.
                prepare_batch_started = Time.get_ticks_usec()
                job_started = prepare_batch_started
            else:
                if not _catalog_context_valid(host, prepare_tree, prepare_generation, prepare_route_generation, cancellable):
                    _discard_catalog_staging(host, catalog_read_ahead)
                    _finalize_prepare_metrics(prepare_role, prepare_wall_started)
                    return false
                if prepare_method == "_commit_world_catalog_prepare":
                    for read in last_transition.get("catalog_reads", []):
                        if FileAccess.get_modified_time(String(read.path)) != int(read.stamp):
                            last_error = "物品目录在发布前发生变化。"
                            _discard_catalog_staging(host, catalog_read_ahead)
                            _finalize_prepare_metrics(prepare_role, prepare_wall_started)
                            return false
                prepare_result = host.callv(prepare_method, prepare_args)
            var job_usec := Time.get_ticks_usec() - job_started
            if prepare_method == "_prepare_world_catalog_region":
                var catalog_reads: Array = last_transition.catalog_reads
                var catalog_read: Dictionary = catalog_reads.back()
                job_usec += int(catalog_read.merge_work_usec)
            # Keep one duration per operation index, rather than a per-method
            # aggregate, so reports can identify expensive individual jobs.
            var operation_key := "%d:%s" % [prepare_cursor, prepare_method]
            var operation_timings: Dictionary = last_transition["prepare_operation_usec"]
            operation_timings[operation_key] = maxi(int(operation_timings.get(operation_key, 0)), job_usec)
            last_transition["prepare_operation_usec"] = operation_timings
            last_transition["max_prepare_job_usec"] = maxi(int(last_transition["max_prepare_job_usec"]), job_usec)
            last_transition["prepare_work_usec"] = int(last_transition["prepare_work_usec"]) + job_usec
            # The catalog index job expands into one measured job per authored
            # route. Insert them before the plan's catalog commit job.
            if prepare_method == "_prepare_world_catalog_jobs" and prepare_result is Array:
                var expanded_jobs: Array = prepare_result
                for expanded_index in range(expanded_jobs.size()):
                    prepare_jobs.insert(prepare_cursor + 1 + expanded_index, expanded_jobs[expanded_index])
                last_transition["prepare_jobs"] = prepare_jobs.size()
            prepare_cursor += 1
            prepare_operations += 1
            last_transition["prepare_cursor"] = prepare_cursor
            if prepare_method == "_prepare_world_catalog_region":
                break
        var prepare_batch_usec := Time.get_ticks_usec() - prepare_batch_started
        last_transition["prepare_batches"] = int(last_transition["prepare_batches"]) + 1
        var batch_operation_counts: Array = last_transition["prepare_batch_operations"]
        batch_operation_counts.append(prepare_operations)
        last_transition["prepare_batch_operations"] = batch_operation_counts
        last_transition["max_prepare_operations"] = maxi(int(last_transition["max_prepare_operations"]), prepare_operations)
        last_transition["max_prepare_batch_usec"] = maxi(int(last_transition["max_prepare_batch_usec"]), prepare_batch_usec)
        if is_instance_valid(loading_label):
            loading_label.text = ("正在接通旧路… 准备 %d / %d\nEsc 返回来路" if cancellable else "正在返回来路… 准备 %d / %d") % [prepare_cursor, prepare_jobs.size()]
        # Synchronous batches, including the final one, retain their boundary
        # before build. Catalog tasks have already yielded after their final
        # merge; waiting a second empty frame delays every cold region read.
        if not catalog_yielded:
            await _next_process_frame(prepare_tree)
        if not _catalog_context_valid(host, prepare_tree, prepare_generation, prepare_route_generation, cancellable):
            _discard_catalog_staging(host, catalog_read_ahead)
            _finalize_prepare_metrics(prepare_role, prepare_wall_started)
            return false
        _cancel_input()
    _finalize_prepare_metrics(prepare_role, prepare_wall_started)
    if cancellable and cancel_requested:
        _discard_catalog_staging(host, catalog_read_ahead)
        return false
    if not catalog_read_ahead.is_empty():
        last_error = "物品目录预读未完成交接。"
        _discard_catalog_staging(host, catalog_read_ahead)
        return false
    # Cover the entire target region, including NPCs outside the landing
    # top-k and original portrait atlases, before any actor can be published.
    var art_job := CHARACTER_ART_WARM_JOB.new()
    art_job.begin(host.config)
    var art_started := Time.get_ticks_usec()
    var art_batches := 0
    while not art_job.done:
        if not _catalog_context_valid(host, prepare_tree, prepare_generation, prepare_route_generation, cancellable):
            art_job.cancel()
            return false
        art_job.step(MAX_OPERATIONS_PER_FRAME, FRAME_BUDGET_USEC)
        art_batches += 1
        await _next_process_frame(prepare_tree)
        if not _catalog_context_valid(host, prepare_tree, prepare_generation, prepare_route_generation, cancellable):
            art_job.cancel()
            return false
        _cancel_input()
    last_transition["character_art_batches"] = art_batches
    last_transition["character_art_textures"] = art_job.paths.size()
    last_transition["character_art_scanned"] = art_job.scanned
    last_transition["character_art_max_operations"] = art_job.max_step_operations
    last_transition["character_art_wall_usec"] = Time.get_ticks_usec() - art_started
    if not String(art_job.error).is_empty():
        last_error = String(art_job.error)
        return false
    var jobs: Array = host._region_build_jobs()
    var cursor := 0
    last_transition["jobs"] = jobs.size()
    last_transition["build_cursor"] = 0
    last_transition["build_batches"] = 0
    while cursor < jobs.size():
        if cancellable and cancel_requested:
            return false
        var started := Time.get_ticks_usec()
        var operations := 0
        while cursor < jobs.size() and operations < MAX_OPERATIONS_PER_FRAME:
            if operations > 0 and Time.get_ticks_usec() - started >= FRAME_BUDGET_USEC:
                break
            var job: Dictionary = jobs[cursor]
            host.callv(job.method, job.args)
            cursor += 1
            operations += 1
        _measure_batch(operations, started, "max_build_operations")
        last_transition["build_cursor"] = cursor
        last_transition["build_batches"] += 1
        if is_instance_valid(loading_label):
            loading_label.text = ("正在接通旧路… %d / %d\nEsc 返回来路" if cancellable else "正在返回来路… %d / %d") % [cursor, jobs.size()]
        await _next_process_frame(host.get_tree())
        if not _catalog_context_valid(host, prepare_tree, prepare_generation, prepare_route_generation, cancellable):
            _discard_catalog_staging(host, catalog_read_ahead)
            return false
        _cancel_input()
    return not (cancellable and cancel_requested)


func _finalize_prepare_metrics(role: String, wall_started: int) -> void:
    last_transition["prepare_wall_usec"] = Time.get_ticks_usec() - wall_started
    # Compatibility metric: prepare_usec retains the old synchronous-work
    # meaning and excludes yielded frame time.
    last_transition["prepare_usec"] = int(last_transition.get("prepare_work_usec", 0))
    var metric_keys := ["prepare_jobs", "prepare_cursor", "prepare_batches", "prepare_batch_operations",
        "prepare_work_usec", "prepare_wall_usec", "prepare_plan_usec", "prepare_usec",
        "max_prepare_operations", "max_prepare_batch_usec", "max_prepare_job_usec", "prepare_operation_usec", "catalog_reads"]
    var attempt: Dictionary = {"role": role}
    for key in metric_keys:
        var value: Variant = last_transition.get(key, null)
        attempt[key] = value.duplicate(true) if value is Array or value is Dictionary else value
    var attempts: Array = last_transition.get("prepare_attempts", [])
    attempts.append(attempt)
    last_transition["prepare_attempts"] = attempts
    last_transition["%s_prepare" % role] = attempt.duplicate(true)


func _finish_budgeted(host: Node, cancellable: bool) -> bool:
    var finish_tree := host.get_tree()
    var jobs: Array = host._region_finish_jobs()
    var cursor := 0
    var wall_started := Time.get_ticks_usec()
    last_transition["commit_jobs"] = jobs.size()
    while cursor < jobs.size():
        if phase == "startup" and not _startup_config_context_valid(host, finish_tree, last_transition.startup_config_lease): return false
        if cancellable and cancel_requested:
            return false
        var started := Time.get_ticks_usec()
        var operations := 0
        while cursor < jobs.size() and operations < MAX_OPERATIONS_PER_FRAME:
            if operations > 0 and Time.get_ticks_usec() - started >= FRAME_BUDGET_USEC:
                break
            var job: Dictionary = jobs[cursor]
            var job_started := Time.get_ticks_usec()
            host.callv(job.method, job.args)
            var job_usec := Time.get_ticks_usec() - job_started
            var key: String = job.method if job.args.is_empty() else String(job.args[0])
            var timings: Dictionary = last_transition.get("commit_operation_usec", {})
            timings[key] = maxi(int(timings.get(key, 0)), job_usec)
            last_transition["commit_operation_usec"] = timings
            last_transition["max_commit_job_usec"] = maxi(int(last_transition.get("max_commit_job_usec", 0)), job_usec)
            cursor += 1
            operations += 1
            last_transition["commit_cursor"] = cursor
            last_transition["commit_job"] = key
        var batch_usec := Time.get_ticks_usec() - started
        last_transition["commit_work_usec"] = int(last_transition.get("commit_work_usec", 0)) + batch_usec
        last_transition["max_commit_batch_usec"] = maxi(int(last_transition.get("max_commit_batch_usec", 0)), batch_usec)
        last_transition["commit_batches"] = int(last_transition.get("commit_batches", 0)) + 1
        _measure_batch(operations, started, "max_commit_operations")
        if is_instance_valid(loading_label):
            loading_label.text = ("正在整理行囊… %d / %d\nEsc 返回来路" if cancellable else "正在返回来路… %d / %d") % [cursor, jobs.size()]
        # Even the last batch yields before publication, so Escape/host exit
        # cannot publish a destination whose fully constructed UI was cancelled.
        await _next_process_frame(host.get_tree())
        if not _alive(host):
            return false
        if phase == "startup" and not _startup_config_context_valid(host, finish_tree, last_transition.startup_config_lease): return false
        _cancel_input()
    last_transition["commit_wall_usec"] = Time.get_ticks_usec() - wall_started
    return not (cancellable and cancel_requested)


func _set_destination(host: Node, path: String, entry: Vector2, previous_id: String, target: Dictionary) -> void:
    _reset_region_fields(host)
    host.config_path = path
    host.world_loading = true
    host.chapter_transitioning = true
    host.entry_spawn_override_enabled = true
    host.entry_spawn_override = entry
    host.entered_from_config_id = previous_id
    host.transition_entry_message = "旧路重新接通 · " + String(target.get("name", ""))


func replace_region_async(host: Node, path: String, entry: Vector2, rollback_entry: Vector2 = Vector2.INF, publish_flags: Dictionary = {}) -> bool:
    if phase != "idle":
        return false
    if not _alive(host) or not is_instance_valid(host.player):
        last_error = "区域正在装载。"
        return false
    phase = "preflight"
    cancel_requested = false
    last_error = ""
    last_transition = {"source": String(host.config.get("id", "")), "target_path": path, "rolled_back": false}
    var previous_mode: int = host.process_mode
    host.process_mode = Node.PROCESS_MODE_DISABLED
    _show_loading_canvas(host)
    var target: Dictionary = await _preflight_async(path, entry, host.world_prefetch, host)
    if not _alive(host):
        _clear_loading_canvas()
        return false
    if target.is_empty():
        if last_transition.get("preflight_cancelled", false):
            last_error = "区域预检已取消。"
        host.process_mode = previous_mode
        _clear_loading_canvas()
        phase = "idle"
        cancel_requested = false
        return false
    # Pin the exact manifest generation accepted by the completed validator.
    # Capturing before _preflight_async would reject a legitimate cold-cache
    # refresh (and could validate against an uninitialized generation).
    var route_generation := int(last_transition.get("preflight_route_generation", -1))
    if route_generation < 0 or ROUTES.cached_generation() != route_generation:
        last_error = "区域路线清单在目标预检后已变化，请重试。"
        host.process_mode = previous_mode
        _clear_loading_canvas()
        phase = "idle"
        cancel_requested = false
        return false
    # Preserve the source through validation. Capture settled departure data only
    # after the final validator batch has yielded and survived cancellation.
    var source_catalog: Dictionary = host.world_catalog
    var source_config: Dictionary = host.config.duplicate(true)
    var source_path: String = host.config_path
    var source_position: Vector2 = host.player.global_position
    var player_layer: int = host.player.collision_layer
    var player_mask: int = host.player.collision_mask
    host.player.collision_layer = 0
    host.player.collision_mask = 0
    host.player.prepare_region_handoff()
    host._save_world()
    var source_state: Dictionary = host.world_state.data.duplicate(true)
    var source_build: Dictionary = host.build_system.serialize()
    var source_id := String(source_config.id)
    host.world_loading = true
    host.chapter_transitioning = true
    host.process_mode = Node.PROCESS_MODE_DISABLED
    host._stop_region_tweens()
    host._release_region_audio()
    host._release_region_platforms()
    generation += 1 # invalidate departing callbacks before the first yield
    cancel_requested = false
    last_transition["source"] = source_id
    last_transition["target"] = String(target.id)
    phase = "unloading"
    if not await _evict_budgeted(host):
        _clear_loading_canvas()
        return false
    _set_destination(host, path, entry, source_id, target)
    phase = "loading"
    var built := await _construct_budgeted(host, target, true)
    if ROUTES.cached_generation() != route_generation:
        built = false
        last_error = "区域路线清单在目标区域构建期间发生变化。"
    if built:
        phase = "committing"
        built = await _finish_budgeted(host, true)
    if ROUTES.cached_generation() != route_generation:
        built = false
        last_error = "区域路线清单在目标区域交接期间发生变化。"
    if not _alive(host):
        if is_instance_valid(host):
            host.world_catalog = source_catalog
            _discard_catalog_staging(host)
        _clear_loading_canvas()
        return false
    if not built:
        # Catalog commit swaps the dictionary rather than mutating the source.
        # A later prepare/build/finish invalidation must restore that snapshot.
        host.world_catalog = source_catalog
        host.world_catalog_prepare_staging = {}
        # A changed manifest stamp makes cached_generation() invalid. Repair
        # it through the same reader before admitting rollback preparation.
        # If the new file itself is unusable, retain gated physics/gameplay and
        # expose the existing retry control instead of stranding phase rollback.
        if not ROUTES.cache_is_current():
            if not await _prepare_routes_manifest(host, host.get_tree()):
                if _alive(host):
                    _show_startup_error(host)
                    host.process_mode = previous_mode
                else:
                    _clear_loading_canvas()
                return false
        phase = "rollback"
        last_transition["rolled_back"] = true
        host._stop_region_tweens()
        host._release_region_audio()
        host._release_region_platforms()
        if not await _evict_budgeted(host):
            _clear_loading_canvas()
            return false
        host.world_state.data = source_state
        host.build_system.restore(source_build)
        _set_destination(host, source_path, rollback_entry if rollback_entry.is_finite() else source_position, source_id, source_config)
        host.transition_entry_message = "已返回来路。"
        var rollback_tree := host.get_tree()
        var rollback_generation := generation
        var rollback_route_generation := ROUTES.cached_generation()
        var restored := await _construct_budgeted(host, source_config, false)
        if not restored or not _catalog_context_valid(host, rollback_tree, rollback_generation, rollback_route_generation, false):
            if is_instance_valid(host):
                host.world_catalog = source_catalog
                _discard_catalog_staging(host)
            if _alive(host):
                last_error = "返回来路时区域准备失败。"
                _show_startup_error(host)
                host.process_mode = previous_mode
            else:
                _clear_loading_canvas()
            return false
        restored = await _finish_budgeted(host, false)
        if not restored or not _catalog_context_valid(host, rollback_tree, rollback_generation, rollback_route_generation, false):
            if is_instance_valid(host):
                host.world_catalog = source_catalog
                _discard_catalog_staging(host)
            if _alive(host):
                last_error = "返回来路时区域交接失败。"
                _show_startup_error(host)
                host.process_mode = previous_mode
            else:
                _clear_loading_canvas()
            return false
    # Only this small, non-yielding boundary may publish rewards and save the
    # destination. Rollback retires even partially constructed arrival/UI nodes.
    phase = "publishing"
    var committed_at := Time.get_ticks_usec()
    if built and not publish_flags.is_empty():
        for flag in publish_flags:
            host.story_flags[String(flag)] = publish_flags[flag]
        host._refresh_world_portals()
    host._publish_region()
    last_transition["publish_usec"] = Time.get_ticks_usec() - committed_at
    last_transition["commit_usec"] = int(last_transition.get("commit_work_usec", 0)) + int(last_transition.publish_usec)
    host.player.reset_camera_after_arrival()
    host.player.collision_layer = player_layer
    host.player.collision_mask = player_mask
    host.process_mode = previous_mode
    host.chapter_transitioning = false
    phase = "idle"
    _clear_loading_canvas()
    last_error = "已返回来路，旅途记录仍在。" if not built else ""
    return built


## Passage observers can leave the tree while their terminal load is yielding.
## Keep the async owner here; the passage observes its independent token and
## retains its existing collision, retry and source-mouth rollback behavior.
func request_passage_transition(host: Node, path: String, entry: Vector2, rollback_entry: Vector2) -> RefCounted:
    if phase != "idle" or shutting_down or not _alive(host):
        return null
    transition_serial += 1
    var token = TRANSITION_TOKEN.new()
    token.serial = transition_serial
    transition_token = token
    _run_owned_passage_transition(token, host, path, entry, rollback_entry)
    return token

func _run_owned_passage_transition(token: RefCounted, host: Node, path: String, entry: Vector2, rollback_entry: Vector2) -> void:
    var result := false
    if not token.cancelled and _alive(host):
        result = await replace_region_async(host, path, entry, rollback_entry)
    token.succeeded = result
    token.finished = true
    if transition_token == token:
        transition_token = null
    if token.cancelled or not _alive(host):
        phase = "idle"
        cancel_requested = false
    # Finish the passage in this same non-yielding publishing boundary. Frame
    # polling would expose a committed save while the passage is still active.
    token.completed.emit()


func start_region_transition(host: Node, path: String, entry: Vector2) -> void:
    request_region_transition(host, path, entry)

func request_region_transition(host: Node, path: String, entry: Vector2, publish_flags: Dictionary = {}) -> RefCounted:
    if phase != "idle" or shutting_down or not _alive(host):
        return null
    transition_serial += 1
    var token = TRANSITION_TOKEN.new()
    token.serial = transition_serial
    transition_token = token
    _run_owned_transition(token, host, path, entry, publish_flags)
    return token

func _run_owned_transition(token: RefCounted, host: Node, path: String, entry: Vector2, publish_flags: Dictionary) -> void:
    var result := false
    if not token.cancelled and _alive(host):
        result = await replace_region_async(host, path, entry, Vector2.INF, publish_flags)
    token.succeeded = result
    token.finished = true
    if transition_token == token:
        transition_token = null
    if _alive(host):
        host.world_portal_request_pending = false
    if token.cancelled or not _alive(host):
        phase = "idle"
        cancel_requested = false
        return
    if not result:
        host.chapter_transitioning = false
        if is_instance_valid(host.audio_director):
            host.audio_director.cancel_chapter_transition()
        host._toast(last_error)
