extends RefCounted
## Start-up support for the region loader: config read-ahead, the start-up error screen, cancelled manifest refreshes, exit snapshots and the loading canvas.
## Moved out of world_region_loader.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.
const ROUTES := preload("res://scripts/world_routes.gd")

static func discard_startup_config_read_ahead(loader: RefCounted) -> void:
    if not loader.startup_config_read_ahead.is_empty():
        loader.config_read_job.discard(int(loader.startup_config_read_ahead.ticket))
        loader.startup_config_read_ahead.clear()


static func begin_startup_config_read_ahead(loader: RefCounted, host: Node, tree: SceneTree, route_ticket: Dictionary) -> void:
    if loader.phase != "startup" or not host.has_method("_resolve_world_start_route") or not loader.startup_config_read_ahead.is_empty():
        return
    var chapters: Variant = route_ticket.manifest.get("chapters", {})
    if not chapters is Dictionary: return
    var start_region := String(host.world_start_region_id)
    var path := String(host.config_path) if start_region.is_empty() else "res://data/%s.json" % start_region
    var region_id := path.get_file().get_basename()
    # This is only a hint from the private manifest, not a published route.
    # Unknown/overridden paths use the normal validated startup admission.
    if path != "res://data/%s.json" % region_id or not chapters.has(region_id): return
    var ticket: int = loader.config_read_job.request(path)
    # Speculation is optional: a failed launch falls back after manifest commit.
    if ticket == 0: return
    loader.startup_config_read_ahead = {"ticket": ticket, "path": path,
        "host_id": host.get_instance_id(), "tree_id": tree.get_instance_id(),
        "generation": loader.generation, "manifest_stamp": int(route_ticket.stamp),
        "route_generation": -1, "entry_enabled": host.entry_spawn_override_enabled,
        "entry": host.entry_spawn_override, "source_path": String(host.config_path),
        "start_region": start_region, "yield_frames": 0}


static func startup_config_read_ahead_source_valid(loader: RefCounted, host: Node, tree: SceneTree) -> bool:
    if loader.startup_config_read_ahead.is_empty(): return true
    var read: Dictionary = loader.startup_config_read_ahead
    return loader._alive(host) and host.get_tree() == tree and host.get_instance_id() == int(read.host_id) and tree.get_instance_id() == int(read.tree_id) and loader.generation == int(read.generation) and String(host.config_path) == String(read.source_path) and String(host.world_start_region_id) == String(read.start_region) and host.entry_spawn_override_enabled == bool(read.entry_enabled) and host.entry_spawn_override == read.entry and FileAccess.get_modified_time(ROUTES.ROUTES_PATH) == int(read.manifest_stamp)


static func show_startup_error(loader: RefCounted, host: Node) -> void:
    loader.phase = "startup_error"
    host.world_initial_error = "旅途初始化失败：" + loader.last_error
    printerr("WORLD STARTUP FAILED: " + loader.last_error)
    # Region process loops deliberately remain gated. Recovery controls belong
    # to the root canvas, so they work even before a Player/UI was constructed.
    if not is_instance_valid(loader.loading_canvas):
        loader._show_loading_canvas(host)
    loader.loading_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
    loader.loading_label.text = host.world_initial_error + "\n请检查游戏文件后重试。"
    var retry := Button.new()
    retry.name = "StartupRetry"
    retry.text = "重试加载"
    retry.add_theme_font_override("font", loader.loading_label.get_theme_font("font"))
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
    loader.loading_canvas.add_child(retry)
    retry.grab_focus()


static func manifest_refresh_cancelled(loader: RefCounted, background: bool) -> bool:
    if background:
        return loader.phase != "idle"
    if loader.phase == "startup" and loader.startup_token != null and loader.startup_token.cancelled:
        loader.last_error = "初始区域加载已取消。"
        return true
    if loader.phase == "staging":
        return loader.cancel_requested
    if loader.phase != "preflight":
        return false
    loader._cancel_input()
    if loader.cancel_requested:
        loader.last_transition["preflight_cancelled"] = true
    return loader.cancel_requested


static func disconnect_startup_frames(loader: RefCounted) -> void:
    if is_instance_valid(loader._startup_frame_tree) and loader._startup_frame_tree.process_frame.is_connected(loader._wake_startup_frame):
        loader._startup_frame_tree.process_frame.disconnect(loader._wake_startup_frame)
    loader._startup_frame_tree = null


static func startup_exit_snapshot(loader: RefCounted) -> Dictionary:
    var stage := "manifest"
    if loader.last_transition.has("startup_config_context_copy_batches"): stage = "config_read_context"
    if loader.last_transition.has("startup_config_validation_wait_frames"): stage = "config_validation"
    if loader.last_transition.has("prepare_jobs"): stage = "prepare"
    if loader.last_transition.has("jobs"): stage = "build"
    if loader.last_transition.has("commit_jobs"): stage = "finish"
    if not loader.active_region_id.is_empty() and loader.startup_token == null: stage = "published"
    var snapshot := {
        "phase": loader.phase if loader.phase in ["idle", "startup", "startup_error"] else "other",
        "stage": stage, "generation": loader.generation,
        "elapsed_frames": maxi(0, Engine.get_process_frames() - int(loader.last_transition.get("startup_requested_frame", Engine.get_process_frames()))),
        "elapsed_usec": maxi(0, Time.get_ticks_usec() - int(loader.last_transition.get("startup_requested_usec", Time.get_ticks_usec()))),
        "startup_pending": loader.startup_token != null,
        "startup_cancelled": loader.startup_token != null and loader.startup_token.cancelled,
        "shutting_down": loader.shutting_down, "cancel_requested": loader.cancel_requested,
        "reader_busy": loader.config_read_job.busy(),
        "reader_pending": loader.config_read_job.has_pending_ticket(), "reader_closed": loader.config_read_job.closed,
        "player_art_pending": loader.player_art_job != null, "player_art_retained": loader.player_art_resources.size(),
        "player_art_worker_is_main": bool(loader.last_transition.get("player_art_worker_is_main", true))}
    for key in ["route_manifest_copy_batches", "route_manifest_worker_usec", "route_manifest_copy_wall_usec",
            "startup_config_wait_frames", "startup_config_worker_usec", "startup_config_manifest_overlap_frames",
            "startup_config_open_usec", "startup_config_read_usec", "startup_config_parse_usec", "startup_config_context_copy_batches",
            "startup_config_context_overlap_frames", "startup_config_context_copy_work_usec",
            "startup_config_validation_wait_frames", "startup_config_validation_worker_usec", "startup_config_wall_usec",
            "prepare_cursor", "prepare_jobs", "prepare_batches", "prepare_work_usec", "prepare_wall_usec",
            "jobs", "build_cursor", "build_batches", "commit_cursor", "commit_jobs", "commit_batches",
            "commit_work_usec", "commit_wall_usec", "max_build_operations", "max_commit_operations", "max_batch_usec",
            "player_art_wait_frames", "player_art_worker_usec", "player_art_textures", "player_art_optional_skipped"]:
        var value: Variant = loader.last_transition.get(key, 0)
        snapshot[key] = value if value is int or value is float else -1
    snapshot["catalog_read_count"] = 0
    for key in ["wait_frames", "read_overlap_frames", "worker_usec", "merge_frame_batches"]:
        snapshot["catalog_" + key] = 0
    var reads: Variant = loader.last_transition.get("catalog_reads", [])
    if reads is Array:
        for read in reads:
            if not read is Dictionary: continue
            snapshot.catalog_read_count += 1
            for key in ["wait_frames", "read_overlap_frames", "worker_usec", "merge_frame_batches"]:
                var value: Variant = read.get(key, 0)
                if value is int or value is float: snapshot["catalog_" + key] += value
    return snapshot


static func clear_loading_canvas(loader: RefCounted) -> void:
    if is_instance_valid(loader.loading_canvas):
        loader.loading_canvas.queue_free()
    loader.loading_canvas = null
    loader.loading_label = null


static func show_loading_canvas(loader: RefCounted, host: Node) -> void:
    loader.loading_canvas = CanvasLayer.new()
    loader.loading_canvas.layer = 100
    host.get_tree().root.add_child(loader.loading_canvas)
    var shade := ColorRect.new()
    shade.color = Color(0.035, 0.025, 0.045, 1.0)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    loader.loading_canvas.add_child(shade)
    loader.loading_label = Label.new()
    loader.loading_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    loader.loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    loader.loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    loader.loading_label.add_theme_font_override("font", load("res://assets/fonts/GlobalTypeface.otf"))
    loader.loading_label.add_theme_font_size_override("font_size", 21)
    loader.loading_canvas.add_child(loader.loading_label)
    if loader.phase == "startup":
        loader.loading_label.text = "正在准备旅途…"
    else:
        loader.loading_label.text = "正在接通旧路…\nEsc 返回来路"
