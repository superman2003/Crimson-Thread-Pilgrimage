extends RefCounted
const LOADER_STAGING := preload("res://scripts/loader_staging.gd")
const LEVEL_HOST := preload("res://scripts/level_host.gd")
## Budgeted region preparation: async preflight, catalogue region preparation, construction, eviction and finishing within the frame budget.
## Moved out of world_region_loader.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.
const CHARACTER_ART_WARM_JOB := preload("res://scripts/character_art_warm_job.gd")
const CONFIG_VALIDATOR := preload("res://scripts/world_config_validator.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const VARIANT_COPY_JOB := preload("res://scripts/world_variant_copy_job.gd")

static func _init_preflight_metrics(loader: RefCounted) -> void:
    loader.last_transition["preflight_cursor"] = 0
    loader.last_transition["preflight_batches"] = 0
    loader.last_transition["preflight_work_usec"] = 0
    loader.last_transition["preflight_wall_usec"] = 0
    loader.last_transition["preflight_operation_usec"] = {}
    loader.last_transition["preflight_batch_operations"] = []
    loader.last_transition["preflight_cancelled"] = false
    loader.last_transition["preflight_done"] = false
    loader.last_transition["preflight_progress"] = 0.0
    loader.last_transition["preflight_max_operations"] = 0
    loader.last_transition["preflight_max_batch_usec"] = 0
    loader.last_transition["preflight_copy_steps"] = 0
    loader.last_transition["preflight_copy_edges"] = 0
    loader.last_transition["preflight_copy_batches"] = 0
    loader.last_transition["preflight_copy_work_usec"] = 0
    loader.last_transition["preflight_copy_wall_usec"] = 0
    loader.last_transition["preflight_copy_max_step_edges"] = 0
    loader.last_transition["preflight_copy_max_batch_usec"] = 0
    loader.last_transition["preflight_copy_batch_steps"] = []
    loader.last_transition["preflight_copy_batch_edges"] = []
    loader.last_transition["preflight_copy_batch_work_usec"] = []
    loader.last_transition["preflight_copy_batch_wall_usec"] = []
    loader.last_transition["json_background"] = false
    loader.last_transition["json_wait_frames"] = 0
    loader.last_transition["json_worker_is_main"] = true
    loader.last_transition["json_worker_usec"] = 0
    loader.last_transition["json_bytes"] = 0


static func _copy_borrowed_config_async(loader: RefCounted, borrowed: Variant, host: Node) -> Dictionary:
    var copy_job = VARIANT_COPY_JOB.new()
    copy_job.begin(borrowed)
    var copy_wall_started := Time.get_ticks_usec()
    while not copy_job.done:
        var batch_started := Time.get_ticks_usec()
        var steps := 0
        var batch_edges := 0
        var batch_work_usec := 0
        while not copy_job.done and steps < loader.MAX_OPERATIONS_PER_FRAME:
            if steps > 0 and Time.get_ticks_usec() - batch_started >= loader.FRAME_BUDGET_USEC:
                break
            var copy_step_started := Time.get_ticks_usec()
            var copied := copy_job.step(512)
            var copy_step_usec := Time.get_ticks_usec() - copy_step_started
            if copied <= 0:
                break
            steps += 1
            loader.last_transition["preflight_copy_steps"] = int(loader.last_transition["preflight_copy_steps"]) + 1
            loader.last_transition["preflight_copy_edges"] = int(loader.last_transition["preflight_copy_edges"]) + copied
            loader.last_transition["preflight_copy_work_usec"] = int(loader.last_transition["preflight_copy_work_usec"]) + copy_step_usec
            loader.last_transition["preflight_copy_max_step_edges"] = maxi(int(loader.last_transition["preflight_copy_max_step_edges"]), copied)
            batch_edges += copied
            batch_work_usec += copy_step_usec
        var batch_wall_usec := Time.get_ticks_usec() - batch_started
        loader.last_transition["preflight_copy_max_batch_usec"] = maxi(int(loader.last_transition["preflight_copy_max_batch_usec"]), batch_wall_usec)
        var batch_steps_list: Array = loader.last_transition["preflight_copy_batch_steps"]
        batch_steps_list.append(steps)
        loader.last_transition["preflight_copy_batch_steps"] = batch_steps_list
        var batch_edges_list: Array = loader.last_transition["preflight_copy_batch_edges"]
        batch_edges_list.append(batch_edges)
        loader.last_transition["preflight_copy_batch_edges"] = batch_edges_list
        var batch_work_list: Array = loader.last_transition["preflight_copy_batch_work_usec"]
        batch_work_list.append(batch_work_usec)
        loader.last_transition["preflight_copy_batch_work_usec"] = batch_work_list
        var batch_wall_list: Array = loader.last_transition["preflight_copy_batch_wall_usec"]
        batch_wall_list.append(batch_wall_usec)
        loader.last_transition["preflight_copy_batch_wall_usec"] = batch_wall_list
        loader.last_transition["preflight_copy_batches"] = int(loader.last_transition["preflight_copy_batches"]) + 1
        await loader._next_process_frame(host.get_tree())
        loader.last_transition["preflight_copy_wall_usec"] = Time.get_ticks_usec() - copy_wall_started
        if not loader._alive(host):
            loader.last_transition["preflight_cancelled"] = true
            return {"cancelled": true, "result": null}
        loader._cancel_input()
        if loader.cancel_requested:
            loader.last_transition["preflight_cancelled"] = true
            return {"cancelled": true, "result": null}
    return {"cancelled": false, "result": copy_job.result}


static func _read_config_background_async(loader: RefCounted, path: String, host: Node, json_started: int, wall_started: int) -> Dictionary:
    # A cancelled read still owns its thread until completion. Wait in
    # frames before admitting the next one, never queue unbounded work.
    var ticket := 0
    while true:
        if ticket == 0 and not loader.config_read_job.busy():
            ticket = loader.config_read_job.request(path)
            if ticket == 0:
                loader.last_error = "无法启动区域后台读取。"
                break
        loader.last_transition["json_background"] = true
        # Yield even when a tiny file has already completed: the caller
        # always gets a cancellation window before validator/handoff.
        await loader._next_process_frame(host.get_tree())
        loader.last_transition["json_wait_frames"] += 1
        if not loader._alive(host):
            loader.config_read_job.discard(ticket)
            return {"cancelled": true, "raw": null}
        loader._cancel_input()
        if loader.cancel_requested:
            loader.config_read_job.discard(ticket)
            loader.last_transition["preflight_cancelled"] = true
            loader.last_transition["preflight_json_usec"] = Time.get_ticks_usec() - json_started
            loader.last_transition["preflight_wall_usec"] = Time.get_ticks_usec() - wall_started
            return {"cancelled": true, "raw": null}
        if ticket != 0 and not loader.config_read_job.busy():
            break
    if ticket == 0:
        return {"cancelled": false, "raw": null}
    var read: Dictionary = loader.config_read_job.take(ticket)
    loader.last_error = String(read.get("error", "目标区域后台读取已失效。"))
    loader.last_transition["json_worker_usec"] = int(read.get("worker_usec", 0))
    loader.last_transition["json_bytes"] = int(read.get("bytes", 0))
    loader.last_transition["json_worker_is_main"] = read.get("worker_is_main", true)
    return {"cancelled": false, "raw": read.get("raw")}


static func _validate_config_budgeted_async(loader: RefCounted, parsed: Variant, path: String, entry: Vector2, host: Node, wall_started: int) -> Dictionary:
    var validator = CONFIG_VALIDATOR.new()
    validator.begin(parsed, path, entry)
    while not validator.done:
        var batch_started := Time.get_ticks_usec()
        var operations := 0
        while not validator.done and operations < loader.MAX_OPERATIONS_PER_FRAME:
            # The budget admits the next bounded validator step; one step is
            # indivisible and may itself exceed the nominal 2ms admission.
            if operations > 0 and Time.get_ticks_usec() - batch_started >= loader.FRAME_BUDGET_USEC:
                break
            var operation_started := Time.get_ticks_usec()
            validator.step()
            var operation_usec := Time.get_ticks_usec() - operation_started
            var opname := String(validator.operation_name)
            var timings: Dictionary = loader.last_transition["preflight_operation_usec"]
            timings[opname] = int(timings.get(opname, 0)) + operation_usec
            loader.last_transition["preflight_work_usec"] = int(loader.last_transition["preflight_work_usec"]) + operation_usec
            loader.last_transition["preflight_cursor"] = int(loader.last_transition["preflight_cursor"]) + 1
            loader.last_transition["preflight_operation_usec"] = timings
            operations += 1
        loader.last_transition["preflight_batches"] = int(loader.last_transition["preflight_batches"]) + 1
        var batch_usec := Time.get_ticks_usec() - batch_started
        loader.last_transition["preflight_max_operations"] = maxi(int(loader.last_transition["preflight_max_operations"]), operations)
        loader.last_transition["preflight_max_batch_usec"] = maxi(int(loader.last_transition["preflight_max_batch_usec"]), batch_usec)
        var counts: Array = loader.last_transition["preflight_batch_operations"]
        counts.append(operations)
        loader.last_transition["preflight_batch_operations"] = counts
        loader.last_transition["preflight_done"] = validator.done
        loader.last_transition["preflight_progress"] = validator.progress
        if is_instance_valid(loader.loading_label):
            loader.loading_label.text = "正在检查旧路… %d%%\nEsc 返回来路" % int(validator.progress * 100.0)
        # Yield on the final batch too. The source is not handed off until the
        # caller resumes here and observes that cancellation was not requested.
        await loader._next_process_frame(host.get_tree())
        loader.last_transition["preflight_wall_usec"] = Time.get_ticks_usec() - wall_started
        if not loader._alive(host):
            loader.last_transition["preflight_cancelled"] = true
            return {}
        loader._cancel_input()
        if loader.cancel_requested:
            loader.last_transition["preflight_cancelled"] = true
            return {}
    loader.last_transition["preflight_wall_usec"] = Time.get_ticks_usec() - wall_started
    loader.last_error = validator.error
    var validated_route_generation: int = int(validator._manifest_generation)
    if not validator.result.is_empty() and ROUTES.cached_generation() != validated_route_generation:
        loader.last_error = "巡礼路线版本在预检完成时已变化，请重试。"
        return {}
    loader.last_transition["preflight_route_generation"] = validated_route_generation
    return validator.result


static func preflight_async(loader: RefCounted, path: String, entry: Vector2, prefetch: RefCounted, host: Node) -> Dictionary:
    loader.last_error = ""
    # Foreground travel owns the shared reader from here. A discarded neighbor
    # read may still run; the existing frame loop waits for it before request.
    if prefetch != null:
        prefetch.cancel_config()
    var wall_started := Time.get_ticks_usec()
    var json_started := Time.get_ticks_usec()
    _init_preflight_metrics(loader)
    var parsed: Variant = null
    if not entry.is_finite() or not FileAccess.file_exists(path):
        loader.last_error = "目标位置或区域文件无效。"
    else:
        # Foreground preflight owns the same sole reader used by neighbor
        # requests. Refresh a cold/stale route manifest before config parsing
        # or the cache-only validator starts; background staging observes the
        # foreground phase and drops its unpublished result.
        if not ROUTES.cache_is_current():
            if not await loader._prepare_routes_manifest(host, host.get_tree()):
                if loader.last_error.is_empty():
                    loader.last_error = "区域路线清单尚未准备好。"
                loader.last_transition["preflight_wall_usec"] = Time.get_ticks_usec() - wall_started
                return {}
        if not ROUTES.cache_is_current():
            loader.last_error = "区域路线清单在预检开始前已失效。"
            loader.last_transition["preflight_wall_usec"] = Time.get_ticks_usec() - wall_started
            return {}
        loader.last_transition["preflight_route_generation"] = ROUTES.cached_generation()
        var borrowed: Variant = prefetch._cached_raw_borrow(path) if prefetch != null else null
        if borrowed != null:
            var copied := await _copy_borrowed_config_async(loader, borrowed, host)
            if bool(copied.get("cancelled", false)):
                return {}
            parsed = copied.get("result")
        if parsed == null:
            var bg := await _read_config_background_async(loader, path, host, json_started, wall_started)
            if bool(bg.get("cancelled", false)):
                return {}
            parsed = bg.get("raw")
    loader.last_transition["preflight_json_usec"] = Time.get_ticks_usec() - json_started
    if not loader.last_error.is_empty():
        loader.last_transition["preflight_wall_usec"] = Time.get_ticks_usec() - wall_started
        return {}
    return await _validate_config_budgeted_async(loader, parsed, path, entry, host, wall_started)


static func evict_budgeted(loader: RefCounted, host: Node) -> bool:
    # Snapshot only the nodes that belong to this generation. Freed entries may
    # be invalidated by another node's exit callback; never dereference them.
    var children: Array = LEVEL_HOST.children(host)
    var cursor := 0
    while cursor < children.size():
        var started := Time.get_ticks_usec()
        var operations := 0
        while cursor < children.size() and operations < loader.MAX_OPERATIONS_PER_FRAME:
            if operations > 0 and Time.get_ticks_usec() - started >= loader.FRAME_BUDGET_USEC:
                break
            var child: Variant = children[cursor]
            cursor += 1
            # A destination waiting hidden for handover is not the departing region.
            if not is_instance_valid(child) or child == host.player or child == host.world_passage or child.has_meta(LEVEL_HOST.META) or not LEVEL_HOST.owns(host, child):
                continue
            child.get_parent().remove_child(child)
            child.free()
            loader.unloaded_nodes += 1
            operations += 1
        loader._measure_batch(operations, started, "max_unload_operations")
        await loader._next_process_frame(host.get_tree())
        if not loader._alive(host):
            return false
        loader._cancel_input()
        # Cancellation cannot leave old physics half resident; finish retirement
        # before restoring the source from its immutable settled snapshot.
    return true


static func _acquire_catalog_ticket_async(loader: RefCounted, host: Node, region_id: String, path: String, tree: SceneTree, expected_generation: int, route_generation: int, cancellable: bool, read_ahead: Dictionary) -> Dictionary:
    var wait_frames := 0
    var ticket := 0
    var overlap_frames := 0
    if not read_ahead.is_empty():
        # Only the adjacent catalog job may claim this construct-owned ticket.
        # Its predecessor must have crossed a real merge cancellation window.
        if not loader._catalog_context_valid(host, tree, expected_generation, route_generation, cancellable) or String(read_ahead.path) != path or String(read_ahead.region_id) != region_id or int(read_ahead.host_id) != host.get_instance_id() or int(read_ahead.tree_id) != tree.get_instance_id() or int(read_ahead.generation) != expected_generation or int(read_ahead.route_generation) != route_generation or int(read_ahead.yield_frames) < 1:
            loader.last_error = "物品目录预读归属已失效。"
            loader._discard_catalog_staging(host, read_ahead)
            return {"ok": false}
        ticket = int(read_ahead.ticket)
        overlap_frames = int(read_ahead.yield_frames)
        wait_frames = overlap_frames
        read_ahead.clear()
    while ticket == 0:
        if not loader._catalog_context_valid(host, tree, expected_generation, route_generation, cancellable):
            loader._discard_catalog_staging(host, read_ahead)
            return {"ok": false}
        if loader.config_read_job.closed:
            loader.last_error = "物品目录后台读取服务已关闭。"
            loader._discard_catalog_staging(host, read_ahead)
            return {"ok": false}
        # A completed ticket still belongs to its current owner. Wait for
        # take/discard just as the modern manifest path does; never steal it.
        if not loader.config_read_job.busy() and not loader.config_read_job.has_pending_ticket():
            ticket = loader.config_read_job.request(path)
            if ticket == 0:
                loader.last_error = "无法启动物品目录后台读取。"
                loader._discard_catalog_staging(host, read_ahead)
                return {"ok": false}
        # Even a tiny completed read must offer a cancellation window.
        await loader._next_process_frame(tree)
        wait_frames += 1
        loader._cancel_input()
        if not loader._catalog_context_valid(host, tree, expected_generation, route_generation, cancellable):
            loader.config_read_job.discard(ticket)
            loader._discard_catalog_staging(host, read_ahead)
            return {"ok": false}
    while loader.config_read_job.busy():
        await loader._next_process_frame(tree)
        wait_frames += 1
        loader._cancel_input()
        if not loader._catalog_context_valid(host, tree, expected_generation, route_generation, cancellable):
            loader.config_read_job.discard(ticket)
            loader._discard_catalog_staging(host, read_ahead)
            return {"ok": false}
    return {"ok": true, "ticket": ticket, "wait_frames": wait_frames, "overlap_frames": overlap_frames}


static func _merge_catalog_sources_budgeted_async(loader: RefCounted, host: Node, path: String, stamp: int, route_catalog: Dictionary, catalog: Dictionary, record: Dictionary, tree: SceneTree, expected_generation: int, route_generation: int, cancellable: bool, read_ahead: Dictionary, merge_batch_started: int) -> bool:
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
        while source_index < sources.size() and operations < loader.MAX_OPERATIONS_PER_FRAME:
            if operations > 0 and Time.get_ticks_usec() - frame_started >= loader.FRAME_BUDGET_USEC: break
            if not loader._catalog_context_valid(host, tree, expected_generation, route_generation, cancellable) or FileAccess.get_modified_time(path) != stamp:
                loader.last_error = "物品目录在交接期间发生变化。"
                loader._discard_catalog_staging(host, read_ahead)
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
        await loader._next_process_frame(tree)
        if not read_ahead.is_empty(): read_ahead.yield_frames += 1
        loader._cancel_input()
        merge_batch_started = Time.get_ticks_usec()
    return true


static func prepare_catalog_region_async(loader: RefCounted, host: Node, region_id: String, route_catalog: Dictionary, tree: SceneTree, expected_generation: int, route_generation: int, cancellable: bool, source_path: String = "", read_ahead: Dictionary = {}, next_region_id: String = "") -> bool:
    var path := source_path if not source_path.is_empty() else "res://data/%s.json" % region_id
    var wall_started := Time.get_ticks_usec()
    var acquired := await _acquire_catalog_ticket_async(loader, host, region_id, path, tree, expected_generation, route_generation, cancellable, read_ahead)
    if not bool(acquired.get("ok", false)):
        return false
    var read: Dictionary = loader.config_read_job.take(int(acquired.ticket))
    var raw: Variant = read.get("raw")
    if not String(read.get("error", "物品目录读取票据已失效。")).is_empty() or not raw is Dictionary:
        loader.last_error = String(read.get("error", "物品目录读取票据已失效。"))
        if loader.last_error.is_empty(): loader.last_error = "物品目录记录无法读取。"
        loader._discard_catalog_staging(host, read_ahead)
        return false
    var stamp := int(read.get("stamp", -1))
    var record := {"region_id": region_id, "path": path, "stamp": stamp, "bytes": read.get("bytes", 0),
        "worker_is_main": read.get("worker_is_main", true), "worker_usec": read.get("worker_usec", 0),
        "generation": expected_generation, "route_generation": route_generation, "merged_entries": 0, "merge_work_usec": 0, "max_merge_step_usec": 0, "merge_batches": 0, "max_merge_edges": 0, "wait_frames": int(acquired.wait_frames), "read_overlap_frames": int(acquired.overlap_frames), "wall_usec": 0}
    var reads: Array = loader.last_transition.get("catalog_reads", [])
    reads.append(record)
    loader.last_transition["catalog_reads"] = reads
    var inventory: Variant = raw.get("inventory", {})
    var catalog: Variant = inventory.get("catalog", {}) if inventory is Dictionary else null
    if not catalog is Dictionary:
        loader.last_error = "物品目录格式无效。"
        loader._discard_catalog_staging(host, read_ahead)
        return false
    if not loader._catalog_context_valid(host, tree, expected_generation, route_generation, cancellable) or FileAccess.get_modified_time(path) != stamp:
        loader.last_error = "物品目录在预读交接前发生变化。"
        loader._discard_catalog_staging(host, read_ahead)
        return false
    var merge_batch_started := Time.get_ticks_usec()
    if not next_region_id.is_empty():
        # The current result has been taken; the sole reader is free. Keep the
        # next raw result private while this source merges in authored order.
        var next_path := "res://data/%s.json" % next_region_id
        var next_ticket: int = loader.config_read_job.request(next_path)
        if next_ticket == 0:
            loader.last_error = "无法启动下一物品目录后台读取。"
            loader._discard_catalog_staging(host, read_ahead)
            return false
        read_ahead.merge({"ticket": next_ticket, "path": next_path, "region_id": next_region_id,
            "host_id": host.get_instance_id(), "tree_id": tree.get_instance_id(),
            "generation": expected_generation, "route_generation": route_generation, "yield_frames": 0})
    if not await _merge_catalog_sources_budgeted_async(loader, host, path, stamp, route_catalog, catalog, record, tree, expected_generation, route_generation, cancellable, read_ahead, merge_batch_started):
        return false
    if not loader._catalog_context_valid(host, tree, expected_generation, route_generation, cancellable) or FileAccess.get_modified_time(path) != stamp:
        loader._discard_catalog_staging(host, read_ahead)
        return false
    record.wall_usec = Time.get_ticks_usec() - wall_started
    return true


static func _run_prepare_jobs_budgeted_async(loader: RefCounted, host: Node, target: Dictionary, prepare_tree: SceneTree, prepare_generation: int, prepare_route_generation: int, cancellable: bool, catalog_read_ahead: Dictionary) -> bool:
    var prepare_wall_started := Time.get_ticks_usec()
    var prepare_jobs: Array = LOADER_STAGING.hold_back(loader, host._region_prepare_jobs(target))
    loader.last_transition["prepare_plan_usec"] = Time.get_ticks_usec() - prepare_wall_started
    var prepare_role := "target" if cancellable else "rollback"
    var prepare_cursor := 0
    loader.last_transition["prepare_jobs"] = prepare_jobs.size()
    loader.last_transition["prepare_cursor"] = 0
    loader.last_transition["prepare_batches"] = 0
    loader.last_transition["prepare_batch_operations"] = []
    loader.last_transition["prepare_work_usec"] = 0
    loader.last_transition["prepare_wall_usec"] = 0
    loader.last_transition["max_prepare_operations"] = 0
    loader.last_transition["max_prepare_batch_usec"] = 0
    loader.last_transition["max_prepare_job_usec"] = 0
    loader.last_transition["prepare_operation_usec"] = {}
    while prepare_cursor < prepare_jobs.size():
        if not loader._catalog_context_valid(host, prepare_tree, prepare_generation, prepare_route_generation, cancellable):
            loader._discard_catalog_staging(host, catalog_read_ahead)
            loader._finalize_prepare_metrics(prepare_role, prepare_wall_started)
            return false
        var prepare_batch_started := Time.get_ticks_usec()
        var prepare_operations := 0
        var catalog_yielded := false
        while prepare_cursor < prepare_jobs.size() and prepare_operations < loader.MAX_OPERATIONS_PER_FRAME:
            # The budget admits the next job; one job itself cannot be
            # preempted and may exceed the nominal frame budget.
            if prepare_operations > 0 and Time.get_ticks_usec() - prepare_batch_started >= loader.FRAME_BUDGET_USEC:
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
                if not await loader._prepare_catalog_region_async(host, String(prepare_args[0]), prepare_args[1], prepare_tree, prepare_generation, prepare_route_generation, cancellable, "", catalog_read_ahead, next_region_id):
                    loader._discard_catalog_staging(host, catalog_read_ahead)
                    loader._finalize_prepare_metrics(prepare_role, prepare_wall_started)
                    return false
                # The final merge already yielded and checked the lease.
                # No synchronous prepare job has run in this resumed frame.
                catalog_yielded = true
                # Worker wait/merge yields are outside the synchronous job budget.
                prepare_batch_started = Time.get_ticks_usec()
                job_started = prepare_batch_started
            else:
                if not loader._catalog_context_valid(host, prepare_tree, prepare_generation, prepare_route_generation, cancellable):
                    loader._discard_catalog_staging(host, catalog_read_ahead)
                    loader._finalize_prepare_metrics(prepare_role, prepare_wall_started)
                    return false
                if prepare_method == "_commit_world_catalog_prepare":
                    for read in loader.last_transition.get("catalog_reads", []):
                        if FileAccess.get_modified_time(String(read.path)) != int(read.stamp):
                            loader.last_error = "物品目录在发布前发生变化。"
                            loader._discard_catalog_staging(host, catalog_read_ahead)
                            loader._finalize_prepare_metrics(prepare_role, prepare_wall_started)
                            return false
                prepare_result = host.callv(prepare_method, prepare_args)
            var job_usec := Time.get_ticks_usec() - job_started
            if prepare_method == "_prepare_world_catalog_region":
                var catalog_reads: Array = loader.last_transition.catalog_reads
                var catalog_read: Dictionary = catalog_reads.back()
                job_usec += int(catalog_read.merge_work_usec)
            # Keep one duration per operation index, rather than a per-method
            # aggregate, so reports can identify expensive individual jobs.
            var operation_key := "%d:%s" % [prepare_cursor, prepare_method]
            var operation_timings: Dictionary = loader.last_transition["prepare_operation_usec"]
            operation_timings[operation_key] = maxi(int(operation_timings.get(operation_key, 0)), job_usec)
            loader.last_transition["prepare_operation_usec"] = operation_timings
            loader.last_transition["max_prepare_job_usec"] = maxi(int(loader.last_transition["max_prepare_job_usec"]), job_usec)
            loader.last_transition["prepare_work_usec"] = int(loader.last_transition["prepare_work_usec"]) + job_usec
            # The catalog index job expands into one measured job per authored
            # route. Insert them before the plan's catalog commit job.
            if prepare_method == "_prepare_world_catalog_jobs" and prepare_result is Array:
                var expanded_jobs: Array = prepare_result
                for expanded_index in range(expanded_jobs.size()):
                    prepare_jobs.insert(prepare_cursor + 1 + expanded_index, expanded_jobs[expanded_index])
                loader.last_transition["prepare_jobs"] = prepare_jobs.size()
            prepare_cursor += 1
            prepare_operations += 1
            loader.last_transition["prepare_cursor"] = prepare_cursor
            if prepare_method == "_prepare_world_catalog_region":
                break
        var prepare_batch_usec := Time.get_ticks_usec() - prepare_batch_started
        loader.last_transition["prepare_batches"] = int(loader.last_transition["prepare_batches"]) + 1
        var batch_operation_counts: Array = loader.last_transition["prepare_batch_operations"]
        batch_operation_counts.append(prepare_operations)
        loader.last_transition["prepare_batch_operations"] = batch_operation_counts
        loader.last_transition["max_prepare_operations"] = maxi(int(loader.last_transition["max_prepare_operations"]), prepare_operations)
        loader.last_transition["max_prepare_batch_usec"] = maxi(int(loader.last_transition["max_prepare_batch_usec"]), prepare_batch_usec)
        if is_instance_valid(loader.loading_label):
            loader.loading_label.text = ("正在接通旧路… 准备 %d / %d\nEsc 返回来路" if cancellable else "正在返回来路… 准备 %d / %d") % [prepare_cursor, prepare_jobs.size()]
        # Synchronous batches, including the final one, retain their boundary
        # before build. Catalog tasks have already yielded after their final
        # merge; waiting a second empty frame delays every cold region read.
        if not catalog_yielded:
            await loader._next_process_frame(prepare_tree)
        if not loader._catalog_context_valid(host, prepare_tree, prepare_generation, prepare_route_generation, cancellable):
            loader._discard_catalog_staging(host, catalog_read_ahead)
            loader._finalize_prepare_metrics(prepare_role, prepare_wall_started)
            return false
        loader._cancel_input()
    loader._finalize_prepare_metrics(prepare_role, prepare_wall_started)
    if cancellable and loader.cancel_requested:
        loader._discard_catalog_staging(host, catalog_read_ahead)
        return false
    if not catalog_read_ahead.is_empty():
        loader.last_error = "物品目录预读未完成交接。"
        loader._discard_catalog_staging(host, catalog_read_ahead)
        return false
    return true


static func _warm_character_art_budgeted_async(loader: RefCounted, host: Node, prepare_tree: SceneTree, prepare_generation: int, prepare_route_generation: int, cancellable: bool) -> bool:
    # Cover the entire target region, including NPCs outside the landing
    # top-k and original portrait atlases, before any actor can be published.
    # Collectibles and held inventory use the same bounded resource owners;
    # their first atlas decode must not land in a build/UI job.
    var art_job = CHARACTER_ART_WARM_JOB.new()
    var inventory_art_ids: Array = []
    for item_id in host.inventory_counts:
        if int(host.inventory_counts[item_id]) > 0: inventory_art_ids.append(item_id)
    inventory_art_ids.append("currency")
    art_job.begin(host.config, [], false, inventory_art_ids)
    var art_started := Time.get_ticks_usec()
    var art_batches := 0
    while not art_job.done:
        if not loader._catalog_context_valid(host, prepare_tree, prepare_generation, prepare_route_generation, cancellable):
            art_job.cancel()
            return false
        art_job.step(loader.MAX_OPERATIONS_PER_FRAME, loader.FRAME_BUDGET_USEC)
        art_batches += 1
        await loader._next_process_frame(prepare_tree)
        if not loader._catalog_context_valid(host, prepare_tree, prepare_generation, prepare_route_generation, cancellable):
            art_job.cancel()
            return false
        loader._cancel_input()
    loader.last_transition["character_art_batches"] = art_batches
    loader.last_transition["character_art_textures"] = art_job.paths.size()
    loader.last_transition["character_art_scanned"] = art_job.scanned
    loader.last_transition["item_art_scanned"] = art_job.item_scanned
    loader.last_transition["item_art_textures"] = art_job.item_paths.size()
    loader.last_transition["item_art_paths"] = art_job.item_paths.duplicate()
    loader.last_transition["character_art_max_operations"] = art_job.max_step_operations
    loader.last_transition["character_art_wall_usec"] = Time.get_ticks_usec() - art_started
    if not String(art_job.error).is_empty():
        loader.last_error = String(art_job.error)
        return false
    return true


static func _run_build_jobs_budgeted_async(loader: RefCounted, host: Node, prepare_tree: SceneTree, prepare_generation: int, prepare_route_generation: int, cancellable: bool, catalog_read_ahead: Dictionary) -> bool:
    var jobs: Array = LOADER_STAGING.hold_back(loader, host._region_build_jobs())
    var cursor := 0
    loader.last_transition["jobs"] = jobs.size()
    loader.last_transition["build_cursor"] = 0
    loader.last_transition["build_batches"] = 0
    while cursor < jobs.size():
        if cancellable and loader.cancel_requested:
            return false
        var started := Time.get_ticks_usec()
        var operations := 0
        while cursor < jobs.size() and operations < loader.MAX_OPERATIONS_PER_FRAME:
            if operations > 0 and Time.get_ticks_usec() - started >= loader.FRAME_BUDGET_USEC:
                break
            var job: Dictionary = jobs[cursor]
            var job_started := Time.get_ticks_usec()
            host.callv(job.method, job.args)
            var job_usec := Time.get_ticks_usec() - job_started
            # Names the job behind max_batch_usec so the next stall is findable.
            if job_usec > int(loader.last_transition.get("max_build_job_usec", 0)):
                loader.last_transition["max_build_job_usec"] = job_usec
                loader.last_transition["max_build_job"] = String(job.method)
            loader._record_background_job(loader.last_transition, String(job.method), job_usec)
            # Slowest instance per build method, so each stall can be named.
            var build_timings: Dictionary = loader.last_transition.get("build_operation_usec", {})
            build_timings[String(job.method)] = maxi(int(build_timings.get(String(job.method), 0)), job_usec)
            loader.last_transition["build_operation_usec"] = build_timings
            cursor += 1
            operations += 1
        loader._measure_batch(operations, started, "max_build_operations")
        loader.last_transition["build_cursor"] = cursor
        loader.last_transition["build_batches"] += 1
        if is_instance_valid(loader.loading_label):
            loader.loading_label.text = ("正在接通旧路… %d / %d\nEsc 返回来路" if cancellable else "正在返回来路… %d / %d") % [cursor, jobs.size()]
        await loader._next_process_frame(host.get_tree())
        if not loader._catalog_context_valid(host, prepare_tree, prepare_generation, prepare_route_generation, cancellable):
            loader._discard_catalog_staging(host, catalog_read_ahead)
            return false
        loader._cancel_input()
    return true


static func construct_budgeted(loader: RefCounted, host: Node, target: Dictionary, cancellable: bool) -> bool:
    var prepare_tree := host.get_tree()
    var prepare_generation = loader.generation
    var prepare_route_generation = ROUTES.cached_generation()
    loader.last_transition["catalog_reads"] = []
    # One optional next-read ticket is owned by this invocation, never a
    # shared cache or a second reader. Every failure path drains its ownership.
    var catalog_read_ahead := {}
    if not await _run_prepare_jobs_budgeted_async(loader, host, target, prepare_tree, prepare_generation, prepare_route_generation, cancellable, catalog_read_ahead):
        return false
    if not await _warm_character_art_budgeted_async(loader, host, prepare_tree, prepare_generation, prepare_route_generation, cancellable):
        return false
    if not await loader._warm_region_textures(host, prepare_tree, prepare_generation, prepare_route_generation, cancellable):
        return false
    if not await _run_build_jobs_budgeted_async(loader, host, prepare_tree, prepare_generation, prepare_route_generation, cancellable, catalog_read_ahead):
        return false
    if not await loader._await_player_art(host, prepare_tree, prepare_generation, prepare_route_generation, cancellable):
        return false
    return not (cancellable and loader.cancel_requested)


static func finish_budgeted(loader: RefCounted, host: Node, cancellable: bool) -> bool:
    var finish_tree := host.get_tree()
    var jobs: Array = LOADER_STAGING.hold_back(loader, host._region_finish_jobs())
    var cursor := 0
    var wall_started := Time.get_ticks_usec()
    loader.last_transition["commit_jobs"] = jobs.size()
    while cursor < jobs.size():
        if loader.phase == "startup" and not loader._startup_config_context_valid(host, finish_tree, loader.last_transition.startup_config_lease): return false
        if cancellable and loader.cancel_requested:
            return false
        var started := Time.get_ticks_usec()
        var operations := 0
        while cursor < jobs.size() and operations < loader.MAX_OPERATIONS_PER_FRAME:
            if operations > 0 and Time.get_ticks_usec() - started >= loader.FRAME_BUDGET_USEC:
                break
            var job: Dictionary = jobs[cursor]
            var job_started := Time.get_ticks_usec()
            host.callv(job.method, job.args)
            if String(job.method) == "_finish_region_spawn" and is_instance_valid(host.get("player")):
                loader.player_art_resources.clear()
            var job_usec := Time.get_ticks_usec() - job_started
            var key: String = job.method if job.args.is_empty() else (String(job.args[0]) if job.args[0] is String else "%s:%s" % [job.method, str(job.args[0])])
            if key == "install_desk":
                key += ":%d" % int(job.args[1][0])
            var timings: Dictionary = loader.last_transition.get("commit_operation_usec", {})
            timings[key] = maxi(int(timings.get(key, 0)), job_usec)
            loader.last_transition["commit_operation_usec"] = timings
            loader.last_transition["max_commit_job_usec"] = maxi(int(loader.last_transition.get("max_commit_job_usec", 0)), job_usec)
            cursor += 1
            operations += 1
            loader.last_transition["commit_cursor"] = cursor
            loader.last_transition["commit_job"] = key
        var batch_usec := Time.get_ticks_usec() - started
        loader.last_transition["commit_work_usec"] = int(loader.last_transition.get("commit_work_usec", 0)) + batch_usec
        loader.last_transition["max_commit_batch_usec"] = maxi(int(loader.last_transition.get("max_commit_batch_usec", 0)), batch_usec)
        loader.last_transition["commit_batches"] = int(loader.last_transition.get("commit_batches", 0)) + 1
        loader._measure_batch(operations, started, "max_commit_operations")
        if is_instance_valid(loader.loading_label):
            loader.loading_label.text = ("正在整理行囊… %d / %d\nEsc 返回来路" if cancellable else "正在返回来路… %d / %d") % [cursor, jobs.size()]
        # Even the last batch yields before publication, so Escape/host exit
        # cannot publish a destination whose fully constructed UI was cancelled.
        await loader._next_process_frame(host.get_tree())
        if not loader._alive(host):
            return false
        if loader.phase == "startup" and not loader._startup_config_context_valid(host, finish_tree, loader.last_transition.startup_config_lease): return false
        loader._cancel_input()
    loader.last_transition["commit_wall_usec"] = Time.get_ticks_usec() - wall_started
    if cancellable and loader.cancel_requested:
        return false
    var warmed: bool = await loader._warm_arrival_save_backup(host,cancellable)
    loader.last_transition["commit_wall_usec"] = Time.get_ticks_usec() - wall_started
    return warmed
