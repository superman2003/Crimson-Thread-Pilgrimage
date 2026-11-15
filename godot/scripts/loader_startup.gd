extends RefCounted
## Loader start-up coroutines: background manifest refresh, the owned start-up run, the start-up region and its config, and the routes manifest.
## Moved out of world_region_loader.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.
const COORDINATES := preload("res://scripts/world_coordinates.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const VARIANT_COPY_JOB := preload("res://scripts/world_variant_copy_job.gd")

static func run_background_manifest_refresh(loader: RefCounted, host: Node) -> void:
    var tree := host.get_tree()
    while loader._alive(host) and host.get_tree() == tree and not loader.shutting_down and loader.phase == "idle" and loader.config_read_job.busy():
        await tree.process_frame
    if not loader._alive(host) or host.get_tree() != tree or loader.shutting_down or loader.phase != "idle":
        loader.manifest_refresh_running = false
        return
    loader.manifest_refresh_running = false
    var refreshed: bool = await loader._prepare_routes_manifest(host, tree, true)
    if not loader._alive(host) or host.get_tree() != tree or loader.phase != "idle":
        return
    if not refreshed:
        loader.manifest_refresh_retry_after_msec = Time.get_ticks_msec() + 500
    elif host.has_method("_refresh_map_overlay") and host.get("active_overlay") == "map" and bool(host.get("world_map_view")):
        # A stale atlas intentionally draws nothing. Repaint the still-open
        # world view after publication, preserving its existing navigation state.
        host._refresh_map_overlay()


static func run_owned_startup(loader: RefCounted, token: RefCounted, host: Node, previous_mode: int) -> void:
    # The engine can still be attaching the main scene to the root while its
    # _ready runs. Reserve ownership now, but attach the root loading canvas
    # only after that scene-tree operation has finished.
    var tree: SceneTree = host.get_tree()
    await loader._next_process_frame(tree)
    if loader._alive(host) and host.get_tree() == tree:
        if token.cancelled:
            loader.last_error = "初始区域加载已取消。"
            loader._show_startup_error(host)
        else:
            await loader.initialize_startup_region(host, previous_mode)
    loader._discard_startup_config_read_ahead()
    token.finished = true
    if loader.startup_token == token:
        loader.startup_token = null
        loader._disconnect_startup_frames()
    if not loader._alive(host):
        loader.phase = "idle"
        return
    host.process_mode = previous_mode


static func initialize_startup_region(loader: RefCounted, host: Node, restore_process_mode: int = Node.PROCESS_MODE_INHERIT) -> bool:
    if not loader._alive(host):
        return false
    var tree: SceneTree = host.get_tree()
    loader.phase = "startup"
    loader._show_loading_canvas(host)
    if not loader._begin_player_art(host):
        loader._show_startup_error(host)
        return false
    # Share the bounded JSON worker with foreground config reads. The ticket
    # ties the result to this startup generation and the manifest mtime.
    if not await loader._prepare_routes_manifest(host, tree):
        loader._discard_startup_config_read_ahead()
        if not loader._alive(host):
            loader.phase = "idle"
            return false
        if loader.last_error.is_empty():
            loader.last_error = "区域路线清单后台读取或校验失败。"
        loader._show_startup_error(host)
        host.process_mode = restore_process_mode
        return false
    var startup_source_catalog: Dictionary = host.world_catalog
    var startup_route_generation = ROUTES.cached_generation()
    if host.has_method("_resolve_world_start_route") and not host._resolve_world_start_route():
        loader._discard_startup_config_read_ahead()
        loader.last_error = "归途区域不在当前巡礼路线中。"
        loader._show_startup_error(host)
        host.process_mode = restore_process_mode
        return false
    var prepared: Dictionary = await loader._prepare_startup_config(host, tree)
    if not loader._alive(host) or host.get_tree() != tree:
        loader._clear_loading_canvas()
        loader.phase = "idle"
        return false
    if prepared.is_empty():
        if loader.last_error.is_empty(): loader.last_error = "初始区域读取或验证期间发生变化。"
        loader._show_startup_error(host)
        host.process_mode = restore_process_mode
        return false
    var startup_config_lease: Dictionary = loader.last_transition.startup_config_lease
    var built = await loader._construct_budgeted(host, prepared, false)
    if not loader._startup_config_context_valid(host, tree, startup_config_lease) or ROUTES.cached_generation() != startup_route_generation:
        built = false
        loader.last_error = "区域路线清单在初始构建期间发生变化。"
    if not loader._alive(host) or host.get_tree() != tree or loader.shutting_down:
        if is_instance_valid(host):
            host.world_catalog = startup_source_catalog
            loader._discard_catalog_staging(host)
        loader._clear_loading_canvas()
        loader.phase = "idle"
        return false
    if built:
        built = await loader._finish_budgeted(host, false)
    if not loader._startup_config_context_valid(host, tree, startup_config_lease) or ROUTES.cached_generation() != startup_route_generation:
        built = false
        loader.last_error = "区域路线清单在初始交接期间发生变化。"
    if not loader._alive(host) or host.get_tree() != tree or loader.shutting_down:
        if is_instance_valid(host):
            host.world_catalog = startup_source_catalog
            loader._discard_catalog_staging(host)
        loader._clear_loading_canvas()
        loader.phase = "idle"
        return false
    if built:
        host._publish_region()
    else:
        host.world_catalog = startup_source_catalog
        host.world_catalog_prepare_staging = {}
        if loader.last_error.is_empty(): loader.last_error = "初始区域准备或构建任务未能完成。"
        loader._show_startup_error(host)
    if built:
        loader._clear_loading_canvas()
    if loader._alive(host) and host.get_tree() == tree:
        host.process_mode = restore_process_mode
    loader.phase = "idle" if built else "startup_error"
    return built


static func prepare_startup_config(loader: RefCounted, host: Node, tree: SceneTree) -> Dictionary:
    loader.last_error = ""
    var wall_started := Time.get_ticks_usec()
    var lease = {"path": String(host.config_path), "generation": loader.generation, "route_generation": ROUTES.cached_generation(),
        "entry_enabled": bool(host.entry_spawn_override_enabled), "entry": host.entry_spawn_override}
    loader.last_transition["startup_config_lease"] = lease
    loader.last_transition["startup_config_wait_frames"] = 0
    loader.last_transition["startup_config_context_copy_batches"] = 0
    loader.last_transition["startup_config_context_overlap_frames"] = 0
    loader.last_transition["startup_config_context_copy_work_usec"] = 0
    loader.last_transition["startup_config_context_copy_max_operations"] = 0
    loader.last_transition["startup_config_context_copy_max_batch_usec"] = 0
    var ticket := 0
    loader.last_transition["startup_config_manifest_overlap_frames"] = 0
    if not loader.startup_config_read_ahead.is_empty():
        var ahead: Dictionary = loader.startup_config_read_ahead
        if not loader._startup_config_context_valid(host, tree, lease) or host.get_instance_id() != int(ahead.host_id) or tree.get_instance_id() != int(ahead.tree_id) or int(lease.generation) != int(ahead.generation) or int(lease.route_generation) != int(ahead.route_generation) or String(lease.path) != String(ahead.path) or bool(lease.entry_enabled) != bool(ahead.entry_enabled) or lease.entry != ahead.entry or int(ahead.yield_frames) < 1 or FileAccess.get_modified_time(ROUTES.ROUTES_PATH) != int(ahead.manifest_stamp):
            loader._discard_startup_config_read_ahead()
            loader.last_error = "初始区域预读归属已失效。"
            return {}
        ticket = int(ahead.ticket)
        loader.last_transition.startup_config_manifest_overlap_frames = int(ahead.yield_frames)
        loader.last_transition.startup_config_wait_frames = int(ahead.yield_frames)
        loader.startup_config_read_ahead.clear()
    while ticket == 0:
        if not loader._startup_config_context_valid(host, tree, lease): return {}
        if loader.config_read_job.closed:
            loader.last_error = "初始区域后台读取服务已关闭。"
            return {}
        # A completed but unclaimed read still belongs to its accepted owner.
        # Match the modern manifest/catalog admission path without stealing it.
        if not loader.config_read_job.busy() and not loader.config_read_job.has_pending_ticket():
            ticket = loader.config_read_job.request(String(lease.path))
            if ticket == 0:
                loader.last_error = "无法启动初始区域后台读取。"
                return {}
            # The read owns only its JSON data. Copy the fixed route context
            # while it runs instead of spending a separate idle read frame.
            break
        await loader._next_process_frame(tree)
        loader.last_transition.startup_config_wait_frames += 1
        if not loader._startup_config_context_valid(host, tree, lease):
            loader.config_read_job.discard(ticket)
            return {}
    # The record-level validator contains hundreds of scalar checks. Running
    # eight on each main-thread frame adds over 120 frames before any build.
    # Give the sole reader a detached route context instead: it runs exactly
    # the same validator/overlay over private data without touching live caches.
    var region_id := String(lease.path).get_file().get_basename()
    var context = {"generation": int(lease.route_generation), "region_id": region_id,
        "known_region": COORDINATES.has_region(region_id), "path": ROUTES.cached_config_path(region_id),
        "world_size": COORDINATES.region_bounds(region_id).size,
        "bundle": ROUTES.cached_overlay_bundle(region_id)}
    var context_copy = VARIANT_COPY_JOB.new()
    context_copy.begin(context)
    loader.last_transition["startup_config_context_copy_edges"] = 0
    loader.last_transition["startup_config_context_max_step_edges"] = 0
    var validator_wall_started := Time.get_ticks_usec()
    while not context_copy.done:
        var started := Time.get_ticks_usec()
        var operations := 0
        while not context_copy.done and operations < loader.MAX_OPERATIONS_PER_FRAME:
            if operations > 0 and Time.get_ticks_usec() - started >= loader.FRAME_BUDGET_USEC: break
            var edges: int = context_copy.step(512)
            loader.last_transition.startup_config_context_copy_edges += edges
            loader.last_transition.startup_config_context_max_step_edges = maxi(loader.last_transition.startup_config_context_max_step_edges, edges)
            operations += 1
        var work_usec := Time.get_ticks_usec() - started
        loader.last_transition.startup_config_context_copy_batches += 1
        loader.last_transition.startup_config_context_copy_work_usec += work_usec
        loader.last_transition.startup_config_context_copy_max_operations = maxi(loader.last_transition.startup_config_context_copy_max_operations, operations)
        loader.last_transition.startup_config_context_copy_max_batch_usec = maxi(loader.last_transition.startup_config_context_copy_max_batch_usec, work_usec)
        loader.last_transition["startup_config_validator_operation"] = "route_context_copy"
        # This final-copy yield is also the read's cancellation window.
        # Keep its accepted ticket until both the read and private copy finish.
        await loader._next_process_frame(tree)
        loader.last_transition.startup_config_context_overlap_frames += 1
        loader.last_transition.startup_config_wait_frames += 1
        if not loader._startup_config_context_valid(host, tree, lease):
            loader.config_read_job.discard(ticket)
            return {}
    while loader.config_read_job.busy():
        await loader._next_process_frame(tree)
        loader.last_transition.startup_config_wait_frames += 1
        if not loader._startup_config_context_valid(host, tree, lease):
            loader.config_read_job.discard(ticket)
            return {}
    var read: Dictionary = loader.config_read_job.take(ticket)
    loader.last_error = String(read.get("error", "初始区域读取票据已失效。"))
    if not loader.last_error.is_empty(): return {}
    lease["stamp"] = int(read.get("stamp", -1))
    loader.last_transition["startup_config_worker_is_main"] = read.get("worker_is_main", true)
    loader.last_transition["startup_config_worker_usec"] = read.get("worker_usec", 0)
    for key in ["open_usec", "read_usec", "parse_usec"]:
        loader.last_transition["startup_config_" + key] = read.get(key, 0)
    loader.last_transition["startup_config_bytes"] = read.get("bytes", 0)
    if not loader._startup_config_context_valid(host, tree, lease): return {}
    # No other task can acquire the reader between take and this admission:
    # phase=startup excludes background work, and no await follows the guard.
    ticket = loader.config_read_job.request_validation(read.get("raw"), String(lease.path),
        lease.entry if lease.entry_enabled else Vector2.ZERO, not lease.entry_enabled, context_copy.result)
    if ticket == 0:
        loader.last_error = "无法启动初始区域后台校验。"
        return {}
    loader.last_transition["startup_config_validation_wait_frames"] = 0
    while true:
        # Always leave a cancellation window, even for an already-finished job.
        await loader._next_process_frame(tree)
        loader.last_transition.startup_config_validation_wait_frames += 1
        if not loader._startup_config_context_valid(host, tree, lease):
            loader.config_read_job.discard(ticket)
            return {}
        if not loader.config_read_job.busy(): break
    var validated: Dictionary = loader.config_read_job.take(ticket)
    loader.last_transition["startup_config_validation_worker_is_main"] = validated.get("worker_is_main", true)
    loader.last_transition["startup_config_validation_worker_usec"] = validated.get("worker_usec", 0)
    loader.last_transition["startup_config_validation_steps"] = validated.get("validator_steps", 0)
    loader.last_transition["startup_config_validator_operation"] = validated.get("validator_operation", "")
    loader.last_transition["startup_config_validator_wall_usec"] = Time.get_ticks_usec() - validator_wall_started
    loader.last_transition["startup_config_wall_usec"] = Time.get_ticks_usec() - wall_started
    loader.last_error = String(validated.get("error", "初始区域校验票据已失效。"))
    return validated.get("prepared", {}) if loader.last_error.is_empty() else {}


static func prepare_routes_manifest(loader: RefCounted, host: Node, tree: SceneTree, background: bool = false) -> bool:
    if not loader._alive(host) or host.get_tree() != tree or loader.shutting_down:
        return false
    loader.manifest_refresh_running = true
    var ticket_generation = loader.generation + 1
    var ticket := 0
    while ticket == 0 and loader._alive(host) and host.get_tree() == tree and not loader.shutting_down:
        if loader._manifest_refresh_cancelled(background):
            loader.manifest_refresh_running = false
            return false
        if loader.config_read_job.closed:
            break
        if loader.config_read_job.busy() or loader.config_read_job.has_pending_ticket():
            await loader._next_process_frame(tree)
            continue
        # With no worker or accepted owner, a rejected request is a launch
        # failure, not contention. Surface recovery instead of waiting forever.
        ticket = loader.config_read_job.request(ROUTES.ROUTES_PATH)
        if ticket == 0:
            break
    if ticket == 0:
        loader.manifest_refresh_running = false
        loader.last_error = "无法启动区域路线清单后台读取。"
        return false
    # Always provide one cancellation window even if this small worker happens
    # to finish before the first status poll.
    await loader._next_process_frame(tree)
    if not loader._alive(host) or host.get_tree() != tree or loader.shutting_down or loader._manifest_refresh_cancelled(background):
        loader.config_read_job.discard(ticket)
        loader.manifest_refresh_running = false
        return false
    while loader.config_read_job.busy():
        await loader._next_process_frame(tree)
        if not loader._alive(host) or host.get_tree() != tree or loader.shutting_down or loader._manifest_refresh_cancelled(background):
            loader.config_read_job.discard(ticket)
            loader.manifest_refresh_running = false
            return false
    if not loader._alive(host) or host.get_tree() != tree or loader.shutting_down or loader._manifest_refresh_cancelled(background):
        loader.config_read_job.discard(ticket)
        loader.manifest_refresh_running = false
        return false
    var result: Dictionary = loader.config_read_job.take(ticket)
    if not String(result.get("error", "")).is_empty():
        loader.manifest_refresh_running = false
        loader.last_error = String(result.error)
        return false
    var route_ticket: Dictionary = ROUTES.manifest_ticket(result, ticket_generation)
    if route_ticket.is_empty():
        loader.manifest_refresh_running = false
        loader.last_error = "区域路线清单校验未通过。"
        return false
    loader._begin_startup_config_read_ahead(host, tree, route_ticket)
    # Transfer the worker-owned parsed tree through the existing bounded copy
    # job. This keeps both recursive copying and cache publication off the
    # single synchronous handoff point. Each frame revalidates the file stamp.
    var copy_job = VARIANT_COPY_JOB.new()
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
        while not copy_job.done and operations < loader.MAX_OPERATIONS_PER_FRAME:
            if operations > 0 and Time.get_ticks_usec() - batch_started >= loader.FRAME_BUDGET_USEC: break
            var step_started := Time.get_ticks_usec()
            var copied_edges: int = copy_job.step(512)
            var step_usec := Time.get_ticks_usec() - step_started
            copy_edges += copied_edges
            copy_max_step_edges = maxi(copy_max_step_edges, copied_edges)
            copy_max_step_usec = maxi(copy_max_step_usec, step_usec)
            operations += 1
        copy_max_operations = maxi(copy_max_operations, operations)
        copy_batches += 1
        if not loader.startup_config_read_ahead.is_empty():
            loader.startup_config_read_ahead.yield_frames += 1
        await loader._next_process_frame(tree)
        if not loader._alive(host) or host.get_tree() != tree or loader.shutting_down or loader._manifest_refresh_cancelled(background) or not loader._startup_config_read_ahead_source_valid(host, tree):
            loader._discard_startup_config_read_ahead()
            loader.manifest_refresh_running = false
            return false
        if ticket_generation != loader.generation + 1 or int(route_ticket.stamp) != FileAccess.get_modified_time(ROUTES.ROUTES_PATH):
            loader._discard_startup_config_read_ahead()
            loader.manifest_refresh_running = false
            loader.last_error = "区域路线清单在交接期间发生变化。"
            return false
    route_ticket.manifest = copy_job.result
    if loader._manifest_refresh_cancelled(background):
        loader._discard_startup_config_read_ahead()
        loader.manifest_refresh_running = false
        return false
    if not ROUTES.accept_manifest_ticket(route_ticket, ticket_generation):
        loader._discard_startup_config_read_ahead()
        loader.manifest_refresh_running = false
        loader.last_error = "区域路线清单校验未通过。"
        return false
    if not loader.startup_config_read_ahead.is_empty():
        loader.startup_config_read_ahead.route_generation = ROUTES.cached_generation()
    loader.last_transition["route_manifest_worker_is_main"] = bool(result.get("worker_is_main", true))
    loader.last_transition["route_manifest_worker_usec"] = int(result.get("worker_usec", 0))
    loader.last_transition["route_manifest_bytes"] = int(result.get("bytes", 0))
    loader.last_transition["route_manifest_copy_batches"] = copy_batches
    loader.last_transition["route_manifest_copy_max_operations"] = copy_max_operations
    loader.last_transition["route_manifest_copy_edges"] = copy_edges
    loader.last_transition["route_manifest_copy_begin_usec"] = copy_begin_usec
    loader.last_transition["route_manifest_copy_max_step_usec"] = copy_max_step_usec
    loader.last_transition["route_manifest_copy_max_step_edges"] = copy_max_step_edges
    loader.last_transition["route_manifest_copy_wall_usec"] = Time.get_ticks_usec() - copy_started
    loader.manifest_refresh_running = false
    return true
