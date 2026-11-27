extends RefCounted
## Region transitions: warming textures, player art and the arrival save backup, async region replacement, owned transitions and shutdown.
## Moved out of world_region_loader.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.
const CHARACTER_ART_WARM_JOB := preload("res://scripts/character_art_warm_job.gd")
const PREFETCH := preload("res://scripts/world_prefetch.gd")
const RESOURCE_JOB := preload("res://scripts/background_resource_job.gd")
const ROUTES := preload("res://scripts/world_routes.gd")

static func shutdown(loader: RefCounted) -> void:
    # Observe the live owner before cancellation/join/clear. The existing
    # shutdown latch also makes repeated teardown emit at most once.
    if not loader.shutting_down and OS.is_stdout_verbose() and loader.last_transition.has("startup_requested_frame"):
        loader._write_startup_exit_snapshot(loader._startup_exit_snapshot())
    loader.shutting_down = true
    loader.cancel_requested = true
    # A destination being built hidden is dropped at once; its coroutine wakes
    # below, sees shutting_down and returns without touching the freed host.
    if not loader.staging.is_empty():
        var staged_root: Variant = loader.staging.root
        loader.staging = {}
        if is_instance_valid(staged_root):
            staged_root.free()
    if loader.transition_token != null:
        loader.transition_token.cancel()
    if loader.startup_token != null:
        loader.startup_token.cancel()
    loader._discard_startup_config_read_ahead()
    loader.config_read_job.shutdown()
    loader.save_backup_job.shutdown()
    if loader.player_art_job != null:
        loader.player_art_job.shutdown()
        loader.player_art_job = null
    loader.player_art_resources.clear()
    CHARACTER_ART_WARM_JOB.ART.shutdown_texture_requests()
    for job in loader.region_texture_jobs:
        job.worker.shutdown()
    loader.region_texture_jobs.clear()
    loader.region_texture_hold.clear()
    loader.phase = "idle"
    loader._clear_loading_canvas()
    loader._disconnect_startup_frames()
    # Owned startup/travel continuations see shutting_down and cannot publish.
    # Merely setting token.cancelled leaves its await stack alive if no next
    # SceneTree frame exists, which leaks the token on Godot 4.6.1 at exit.
    loader._wake_startup_frame()


static func warm_region_textures(loader: RefCounted, host: Node, tree: SceneTree, expected_generation: int, route_generation: int, cancellable: bool) -> bool:
    loader.region_texture_hold.clear()
    loader._poll_region_textures(false)
    var theme := String(host._art_theme_id()) if host.has_method("_art_theme_id") else ""
    var pending: Array[String] = []
    for path in loader.region_texture_paths(theme):
        if ResourceLoader.has_cached(path):
            # Already resident: hold it so it cannot be released mid-build.
            var resident := ResourceLoader.load(path, "Texture2D") as Texture2D
            if resident != null:
                loader.region_texture_hold.append(resident)
        else:
            pending.append(path)
    var started := Time.get_ticks_usec()
    var batches := 0
    loader.last_transition["region_texture_requested"] = pending.size()
    while not pending.is_empty() or not loader.region_texture_jobs.is_empty():
        while loader.region_texture_jobs.size() < PREFETCH.MAX_JOBS and not pending.is_empty():
            var path: String = pending.pop_front()
            var worker = RESOURCE_JOB.new()
            if worker.start(path, "Texture2D") == OK:
                loader.region_texture_jobs.append({"path": path, "worker": worker})
            else:
                loader.last_transition["region_texture_failures"] = int(loader.last_transition.get("region_texture_failures", 0)) + 1
        loader._poll_region_textures(true)
        if pending.is_empty() and loader.region_texture_jobs.is_empty():
            break
        batches += 1
        await loader._next_process_frame(tree)
        if not loader._catalog_context_valid(host, tree, expected_generation, route_generation, cancellable):
            loader.region_texture_hold.clear()
            return false
        loader._cancel_input()
    loader.last_transition["region_texture_held"] = loader.region_texture_hold.size()
    loader.last_transition["region_texture_batches"] = batches
    loader.last_transition["region_texture_wall_usec"] = Time.get_ticks_usec() - started
    return true


static func await_player_art(loader: RefCounted, host: Node, tree: SceneTree, expected_generation: int, route_generation: int, cancellable: bool) -> bool:
    if loader.player_art_job == null: return true
    var wait_frames := 0
    while not loader.player_art_job.ready():
        await loader._next_process_frame(tree)
        wait_frames += 1
        if not loader._catalog_context_valid(host, tree, expected_generation, route_generation, cancellable): return false
    var result: Dictionary = loader.player_art_job.take()
    loader.player_art_job = null
    loader.last_transition["player_art_wait_frames"] = wait_frames
    loader.last_transition["player_art_worker_usec"] = result.get("worker_usec", 0)
    loader.last_transition["player_art_worker_is_main"] = result.get("worker_is_main", true)
    loader.last_error = String(result.get("error", "主角素材预读结果无效。"))
    if not loader.last_error.is_empty(): return false
    loader.player_art_resources = result.get("textures", {})
    loader.last_transition["player_art_textures"] = loader.player_art_resources.size()
    loader.last_transition["player_art_optional_skipped"] = result.get("optional_skipped", []).size()
    return true


static func warm_arrival_save_backup(loader: RefCounted, host: Node, cancellable: bool) -> bool:
    if not host.world_mode or host.world_state == null or host.world_save_blocked or host.world_save_failure_injected_for_validation:
        return true
    var tree := host.get_tree()
    var expected_generation = loader.generation
    var route_generation = ROUTES.cached_generation()
    var began := Time.get_ticks_usec()
    var retiring_frames := 0
    # Rollback must not race a still-running source backup from the cancelled
    # target. Keep yielding; only whole-host shutdown joins an unfinished job.
    while loader.save_backup_job.busy():
        if not loader._catalog_context_valid(host,tree,expected_generation,route_generation,cancellable): return false
        await loader._next_process_frame(tree)
        retiring_frames += 1
        if not loader._alive(host): return false
        loader._cancel_input()
    if not loader._catalog_context_valid(host,tree,expected_generation,route_generation,cancellable): return false
    var admission_started := Time.get_ticks_usec()
    loader.save_backup_job.take()
    var digest: String = host.world_state.backup_source_hash(host.world_save_path)
    var already_verified: bool = not digest.is_empty() and host.world_state._backup_matches(host.world_save_path,digest)
    loader.last_transition["save_backup_already_verified"] = already_verified
    var admitted = not digest.is_empty() and not already_verified and loader.save_backup_job.begin(host.world_save_path,digest)
    loader.last_transition["save_backup_main_usec"] = Time.get_ticks_usec()-admission_started
    loader.last_transition["commit_work_usec"] = int(loader.last_transition.get("commit_work_usec",0))+int(loader.last_transition.save_backup_main_usec)
    loader._measure_batch(1,admission_started,"max_save_backup_operations")
    if not admitted:
        return true
    var frames := 0
    while loader.save_backup_job.busy():
        if not loader._catalog_context_valid(host,tree,expected_generation,route_generation,cancellable):
            return false
        await loader._next_process_frame(tree)
        frames += 1
        if not loader._alive(host): return false
        if loader.phase == "startup" and not loader._startup_config_context_valid(host,tree,loader.last_transition.startup_config_lease): return false
        loader._cancel_input()
    var result: Dictionary = loader.save_backup_job.take()
    result["wait_frames"] = frames
    result["retiring_frames"] = retiring_frames
    result["wall_usec"] = Time.get_ticks_usec()-began
    result["role"] = "startup" if loader.phase == "startup" else ("target" if cancellable else "rollback")
    var attempts: Array = loader.last_transition.get("save_backup_attempts",[])
    attempts.append(result)
    loader.last_transition["save_backup_attempts"] = attempts
    # Any stale/unwritable backup simply leaves write_candidate's original
    # verified-copy path in charge. Preparation cannot authorize a target write.
    return loader._catalog_context_valid(host,tree,expected_generation,route_generation,cancellable)


static func replace_region_async(loader: RefCounted, host: Node, path: String, entry: Vector2, rollback_entry: Vector2 = Vector2.INF, publish_flags: Dictionary = {}) -> bool:
    if loader.phase != "idle":
        return false
    if not loader._alive(host) or not is_instance_valid(host.player):
        loader.last_error = "区域正在装载。"
        return false
    var shrine_request = loader.shrine_return_request.duplicate(true)
    loader.phase = "preflight"
    loader.cancel_requested = false
    loader.last_error = ""
    loader.last_transition = {"source": String(host.config.get("id", "")), "target_path": path, "rolled_back": false}
    var previous_mode: int = host.process_mode
    host.process_mode = Node.PROCESS_MODE_DISABLED
    loader._show_loading_canvas(host)
    var target: Dictionary = await loader._preflight_async(path, entry, host.world_prefetch, host)
    if not loader._alive(host):
        loader._clear_loading_canvas()
        return false
    if target.is_empty():
        if loader.last_transition.get("preflight_cancelled", false):
            loader.last_error = "区域预检已取消。"
        host.process_mode = previous_mode
        loader._clear_loading_canvas()
        loader.phase = "idle"
        loader.cancel_requested = false
        return false
    # Pin the exact manifest generation accepted by the completed validator.
    # Capturing before _preflight_async would reject a legitimate cold-cache
    # refresh (and could validate against an uninitialized generation).
    var route_generation := int(loader.last_transition.get("preflight_route_generation", -1))
    if route_generation < 0 or ROUTES.cached_generation() != route_generation:
        loader.last_error = "区域路线清单在目标预检后已变化，请重试。"
        host.process_mode = previous_mode
        loader._clear_loading_canvas()
        loader.phase = "idle"
        loader.cancel_requested = false
        return false
    # Preserve the source through validation. Capture settled departure data only
    # after the final validator batch has yielded and survived cancellation.
    var source_catalog: Dictionary = host.world_catalog
    var source_config: Dictionary = host.config.duplicate(true)
    var source_path: String = host.config_path
    var source_position: Vector2 = host.player.global_position
    if not shrine_request.is_empty():
        var quote = preload("res://scripts/shrine_return_network.gd").quote(host,String(shrine_request.key),true)
        if not quote.ok or quote.fingerprint!=shrine_request.fingerprint or ROUTES.cached_config_path(quote.target.region)!=path or quote.target.position!=entry or not host._save_world():
            loader.last_error="钟路记录已变化或出发记录未能保存；你仍留在原钟龛。"
            host.process_mode=previous_mode
            loader._clear_loading_canvas()
            loader.phase="idle"
            loader.cancel_requested=false
            return false
    host.player.prepare_region_handoff()
    # A physical passage already checkpointed at its mouth. Its terminal
    # position is in transit space and must never replace the source save.
    var at_passage_terminal: bool = is_instance_valid(host.world_passage) and host.world_passage.active and host.world_passage.settling
    if shrine_request.is_empty() and not at_passage_terminal and not loader.checkpoint_departure(host):
        host.process_mode = previous_mode
        loader._clear_loading_canvas()
        loader.phase = "idle"
        loader.cancel_requested = false
        return false
    var player_layer: int = host.player.collision_layer
    var player_mask: int = host.player.collision_mask
    host.player.collision_layer = 0
    host.player.collision_mask = 0
    var source_state: Dictionary = host.world_state.data.duplicate(true)
    var source_build: Dictionary = host.build_system.serialize()
    var source_id := String(source_config.id)
    host.world_loading = true
    host.chapter_transitioning = true
    host.process_mode = Node.PROCESS_MODE_DISABLED
    host._stop_region_tweens()
    host._release_region_audio()
    host._release_region_platforms()
    loader.generation += 1 # invalidate departing callbacks before the first yield
    loader.cancel_requested = false
    loader.last_transition["source"] = source_id
    loader.last_transition["target"] = String(target.id)
    loader.phase = "unloading"
    if not await loader._evict_budgeted(host):
        loader._clear_loading_canvas()
        return false
    loader._set_destination(host, path, entry, source_id, target)
    loader.phase = "loading"
    var built = await loader._construct_budgeted(host, target, true)
    if ROUTES.cached_generation() != route_generation:
        built = false
        loader.last_error = "区域路线清单在目标区域构建期间发生变化。"
    if built:
        loader.phase = "committing"
        built = await loader._finish_budgeted(host, true)
    if ROUTES.cached_generation() != route_generation:
        built = false
        loader.last_error = "区域路线清单在目标区域交接期间发生变化。"
    if not loader._alive(host):
        if is_instance_valid(host):
            host.world_catalog = source_catalog
            loader._discard_catalog_staging(host)
        loader._clear_loading_canvas()
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
            if not await loader._prepare_routes_manifest(host, host.get_tree()):
                if loader._alive(host):
                    loader._show_startup_error(host)
                    host.process_mode = previous_mode
                else:
                    loader._clear_loading_canvas()
                return false
        loader.phase = "rollback"
        loader.last_transition["rolled_back"] = true
        host._stop_region_tweens()
        host._release_region_audio()
        host._release_region_platforms()
        if not await loader._evict_budgeted(host):
            loader._clear_loading_canvas()
            return false
        host.world_state.data = source_state
        host.build_system.restore(source_build)
        loader._set_destination(host, source_path, rollback_entry if rollback_entry.is_finite() else source_position, source_id, source_config)
        host.transition_entry_message = "已返回来路。"
        var rollback_tree := host.get_tree()
        var rollback_generation = loader.generation
        var rollback_route_generation = ROUTES.cached_generation()
        var restored = await loader._construct_budgeted(host, source_config, false)
        if not restored or not loader._catalog_context_valid(host, rollback_tree, rollback_generation, rollback_route_generation, false):
            if is_instance_valid(host):
                host.world_catalog = source_catalog
                loader._discard_catalog_staging(host)
            if loader._alive(host):
                loader.last_error = "返回来路时区域准备失败。"
                loader._show_startup_error(host)
                host.process_mode = previous_mode
            else:
                loader._clear_loading_canvas()
            return false
        restored = await loader._finish_budgeted(host, false)
        if not restored or not loader._catalog_context_valid(host, rollback_tree, rollback_generation, rollback_route_generation, false):
            if is_instance_valid(host):
                host.world_catalog = source_catalog
                loader._discard_catalog_staging(host)
            if loader._alive(host):
                loader.last_error = "返回来路时区域交接失败。"
                loader._show_startup_error(host)
                host.process_mode = previous_mode
            else:
                loader._clear_loading_canvas()
            return false
    # Only this small, non-yielding boundary may publish rewards and save the
    # destination. Rollback retires even partially constructed arrival/UI nodes.
    loader.phase = "publishing"
    var committed_at := Time.get_ticks_usec()
    if built and not publish_flags.is_empty():
        for flag in publish_flags:
            host.story_flags[String(flag)] = publish_flags[flag]
        host._refresh_world_portals()
    host._publish_region()
    loader.last_transition["publish_usec"] = Time.get_ticks_usec() - committed_at
    loader.last_transition["commit_usec"] = int(loader.last_transition.get("commit_work_usec", 0)) + int(loader.last_transition.publish_usec)
    host.player.reset_camera_after_arrival()
    host.player.collision_layer = player_layer
    host.player.collision_mask = player_mask
    host.process_mode = previous_mode
    host.chapter_transitioning = false
    loader.phase = "idle"
    loader._clear_loading_canvas()
    loader.last_error = "已返回来路，旅途记录仍在。" if not built else ""
    return built


static func run_owned_passage_transition(loader: RefCounted, token: RefCounted, host: Node, path: String, entry: Vector2, rollback_entry: Vector2) -> void:
    var result := false
    if not token.cancelled and loader._alive(host):
        result = await loader.replace_region_async(host, path, entry, rollback_entry)
    token.succeeded = result
    token.finished = true
    if loader.transition_token == token:
        loader.transition_token = null
        loader._disconnect_startup_frames_if_idle()
    if token.cancelled or not loader._alive(host):
        loader.phase = "idle"
        loader.cancel_requested = false
    # Finish the passage in this same non-yielding publishing boundary. Frame
    # polling would expose a committed save while the passage is still active.
    token.completed.emit()


static func run_owned_transition(loader: RefCounted, token: RefCounted, host: Node, path: String, entry: Vector2, publish_flags: Dictionary) -> void:
    var result := false
    if not token.cancelled and loader._alive(host):
        result = await loader.replace_region_async(host, path, entry, Vector2.INF, publish_flags)
    token.succeeded = result
    token.finished = true
    if loader.transition_token == token:
        loader.transition_token = null
        loader._disconnect_startup_frames_if_idle()
    if loader._alive(host):
        host.world_portal_request_pending = false
    if token.cancelled or not loader._alive(host):
        loader.phase = "idle"
        loader.cancel_requested = false
        return
    if not result:
        host.chapter_transitioning = false
        if is_instance_valid(host.audio_director):
            host.audio_director.cancel_chapter_transition()
        host._toast(loader.last_error)
