extends RefCounted
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

## Scene `_ready` must be fire-and-forget; this token gives the startup
## coroutine an owner that survives until success or host teardown.
func request_startup_region(host: Node, previous_mode: int) -> RefCounted:
    if shutting_down or not _alive(host) or phase != "idle":
        return null
    var token = TRANSITION_TOKEN.new()
    token.serial = transition_serial + 1
    transition_serial = token.serial
    startup_token = token
    _run_owned_startup(token, host, previous_mode)
    return token

func _run_owned_startup(token: RefCounted, host: Node, previous_mode: int) -> void:
    if not token.cancelled and _alive(host):
        await initialize_startup_region(host, previous_mode)
    token.finished = true
    if startup_token == token:
        startup_token = null
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
        if not _alive(host):
            phase = "idle"
            return false
        if last_error.is_empty():
            last_error = "区域路线清单后台读取或校验失败。"
        _show_startup_error(host)
        host.process_mode = restore_process_mode
        return false
    var built := await _construct_budgeted(host, {}, false)
    if not _alive(host) or host.get_tree() != tree or shutting_down:
        _clear_loading_canvas()
        phase = "idle"
        return false
    if built:
        built = await _finish_budgeted(host, false)
    if not _alive(host) or host.get_tree() != tree or shutting_down:
        _clear_loading_canvas()
        phase = "idle"
        return false
    if built:
        host._publish_region()
    else:
        last_error = "初始区域准备或构建任务未能完成。"
        _show_startup_error(host)
    if built:
        _clear_loading_canvas()
    if _alive(host) and host.get_tree() == tree:
        host.process_mode = restore_process_mode
    phase = "idle" if built else "startup_error"
    return built

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

func _prepare_routes_manifest(host: Node, tree: SceneTree) -> bool:
    if not _alive(host) or host.get_tree() != tree or shutting_down:
        return false
    var ticket_generation := generation + 1
    var ticket := config_read_job.request(ROUTES.ROUTES_PATH)
    if ticket == 0:
        last_error = "无法启动区域路线清单后台读取。"
        return false
    # Always provide one cancellation window even if this small worker happens
    # to finish before the first status poll.
    await tree.process_frame
    if not _alive(host) or host.get_tree() != tree or shutting_down:
        config_read_job.discard(ticket)
        return false
    while config_read_job.busy():
        await tree.process_frame
        if not _alive(host) or host.get_tree() != tree or shutting_down:
            config_read_job.discard(ticket)
            return false
    if not _alive(host) or host.get_tree() != tree or shutting_down:
        config_read_job.discard(ticket)
        return false
    var result: Dictionary = config_read_job.take(ticket)
    if not String(result.get("error", "")).is_empty():
        last_error = String(result.error)
        return false
    var route_ticket: Dictionary = ROUTES.manifest_ticket(result, ticket_generation)
    if not ROUTES.accept_manifest_ticket(route_ticket, ticket_generation):
        last_error = "区域路线清单校验未通过。"
        return false
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


func shutdown() -> void:
    shutting_down = true
    cancel_requested = true
    if transition_token != null:
        transition_token.cancel()
    if startup_token != null:
        startup_token.cancel()
    config_read_job.shutdown()
    phase = "idle"
    _clear_loading_canvas()


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


func _construct_budgeted(host: Node, target: Dictionary, cancellable: bool) -> bool:
    var prepare_wall_started := Time.get_ticks_usec()
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
        if cancellable and cancel_requested:
            _finalize_prepare_metrics(prepare_role, prepare_wall_started)
            return false
        var prepare_batch_started := Time.get_ticks_usec()
        var prepare_operations := 0
        while prepare_cursor < prepare_jobs.size() and prepare_operations < MAX_OPERATIONS_PER_FRAME:
            # The budget admits the next job; one job itself cannot be
            # preempted and may exceed the nominal frame budget.
            if prepare_operations > 0 and Time.get_ticks_usec() - prepare_batch_started >= FRAME_BUDGET_USEC:
                break
            var prepare_job: Dictionary = prepare_jobs[prepare_cursor]
            var prepare_method := String(prepare_job.get("method", ""))
            var prepare_args: Array = prepare_job.get("args", [])
            var job_started := Time.get_ticks_usec()
            var prepare_result: Variant = host.callv(prepare_method, prepare_args)
            var job_usec := Time.get_ticks_usec() - job_started
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
        var prepare_batch_usec := Time.get_ticks_usec() - prepare_batch_started
        last_transition["prepare_batches"] = int(last_transition["prepare_batches"]) + 1
        var batch_operation_counts: Array = last_transition["prepare_batch_operations"]
        batch_operation_counts.append(prepare_operations)
        last_transition["prepare_batch_operations"] = batch_operation_counts
        last_transition["max_prepare_operations"] = maxi(int(last_transition["max_prepare_operations"]), prepare_operations)
        last_transition["max_prepare_batch_usec"] = maxi(int(last_transition["max_prepare_batch_usec"]), prepare_batch_usec)
        if is_instance_valid(loading_label):
            loading_label.text = ("正在接通旧路… 准备 %d / %d\nEsc 返回来路" if cancellable else "正在返回来路… 准备 %d / %d") % [prepare_cursor, prepare_jobs.size()]
        # Yield after every batch, including the final one, so Escape and host
        # teardown can be observed before any build jobs are created.
        await host.get_tree().process_frame
        if not _alive(host):
            _finalize_prepare_metrics(prepare_role, prepare_wall_started)
            return false
        _cancel_input()
    _finalize_prepare_metrics(prepare_role, prepare_wall_started)
    if cancellable and cancel_requested:
        return false
    var jobs: Array = host._region_build_jobs()
    var cursor := 0
    last_transition["jobs"] = jobs.size()
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
        if is_instance_valid(loading_label):
            loading_label.text = ("正在接通旧路… %d / %d\nEsc 返回来路" if cancellable else "正在返回来路… %d / %d") % [cursor, jobs.size()]
        await host.get_tree().process_frame
        if not _alive(host):
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
        "max_prepare_operations", "max_prepare_batch_usec", "max_prepare_job_usec", "prepare_operation_usec"]
    var attempt: Dictionary = {"role": role}
    for key in metric_keys:
        var value: Variant = last_transition.get(key, null)
        attempt[key] = value.duplicate(true) if value is Array or value is Dictionary else value
    var attempts: Array = last_transition.get("prepare_attempts", [])
    attempts.append(attempt)
    last_transition["prepare_attempts"] = attempts
    last_transition["%s_prepare" % role] = attempt.duplicate(true)


func _finish_budgeted(host: Node, cancellable: bool) -> bool:
    var jobs: Array = host._region_finish_jobs()
    var cursor := 0
    var wall_started := Time.get_ticks_usec()
    last_transition["commit_jobs"] = jobs.size()
    while cursor < jobs.size():
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
        await host.get_tree().process_frame
        if not _alive(host):
            return false
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
    # Preserve the source through validation. Capture settled departure data only
    # after the final validator batch has yielded and survived cancellation.
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
    if built:
        phase = "committing"
        built = await _finish_budgeted(host, true)
    if not _alive(host):
        _clear_loading_canvas()
        return false
    if not built:
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
        if not await _construct_budgeted(host, source_config, false):
            _clear_loading_canvas()
            return false
        if not await _finish_budgeted(host, false):
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
