extends RefCounted
## Region state for the loader: snapshots, preflight and config validation, synchronous region replacement, batch measurement, catalogue staging, texture polling and prepare metrics.
## Moved out of world_region_loader.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.
const CONFIG_VALIDATOR := preload("res://scripts/world_config_validator.gd")
const COORDINATES := preload("res://scripts/world_coordinates.gd")
const PLAYER_ART_WARM_JOB := preload("res://scripts/player_art_warm_job.gd")
const ROUTES := preload("res://scripts/world_routes.gd")

static func snapshot(loader: RefCounted, host: Node) -> Dictionary:
    return {"region_id": loader.active_region_id, "generation": loader.generation, "phase": loader.phase,
        "resident_regions": 1 if not loader.active_region_id.is_empty() else 0,
        "region_nodes": maxi(0, host.get_child_count() - 1),
        "unloaded_nodes": loader.unloaded_nodes,
        "player_id": host.player.get_instance_id() if is_instance_valid(host.player) else 0,
        "world_bounds": COORDINATES.region_bounds(loader.active_region_id)}


static func preflight(loader: RefCounted, path: String, entry: Vector2, prefetch: RefCounted = null) -> Dictionary:
    ROUTES.manifest_generation() # Explicit synchronous compatibility/oracle path.
    loader.last_error = ""
    if prefetch != null:
        prefetch.cancel_config()
    if not entry.is_finite() or not FileAccess.file_exists(path):
        loader.last_error = "目标位置或区域文件无效。"
        return {}
    var json_started := Time.get_ticks_usec()
    var parsed: Variant = prefetch.cached_raw(path) if prefetch != null else null
    if parsed == null:
        parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    loader.last_transition["preflight_json_usec"] = Time.get_ticks_usec() - json_started
    return loader.validate_config(parsed, path, entry)


static func validate_config(loader: RefCounted, parsed: Variant, path: String, entry: Vector2) -> Dictionary:
    loader.last_error = ""
    ROUTES.manifest_generation() # Explicit synchronous compatibility/oracle path.
    var validator = CONFIG_VALIDATOR.new()
    validator.begin(parsed, path, entry)
    while not validator.done:
        validator.step()
    loader.last_error = validator.error
    return validator.result


static func finite_tuple(loader: RefCounted, value: Variant, length: int) -> bool:
    if not value is Array or value.size() != length:
        return false
    for component in value:
        if typeof(component) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(component)):
            return false
    return true


static func replace_region(loader: RefCounted, host: Node, path: String, entry: Vector2) -> bool:
    # A rejected second request must not overwrite the in-flight preflight's
    # error field while its cache copy/reader is yielding between frames.
    if loader.phase != "idle":
        return false
    if not is_instance_valid(host.player):
        loader.last_error = "区域正在装载。"
        return false
    loader.phase = "preflight"
    var target: Dictionary = loader.preflight(path, entry, host.world_prefetch)
    if target.is_empty():
        loader.phase = "idle"
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
    loader.phase = "unloading"
    for child in host.get_children():
        if child == host.player or child == host.world_passage:
            continue
        host.remove_child(child)
        child.free()
        loader.unloaded_nodes += 1
    loader._reset_region_fields(host)
    host.config_path = path
    host.world_loading = true
    host.chapter_transitioning = true
    host.entry_spawn_override_enabled = true
    host.entry_spawn_override = entry
    host.entered_from_config_id = previous_id
    host.transition_entry_message = "旧路重新接通 · " + String(target.get("name", ""))
    loader.phase = "loading"
    host._initialize_region(target)
    host.chapter_transitioning = false
    host.player.reset_camera_after_arrival()
    host.process_mode = previous_mode
    loader.phase = "idle"
    return true


static func reset_region_fields(loader: RefCounted, host: Node) -> void:
    # Get typed defaults from a detached controller, without running _ready.
    # New region fields therefore cannot accidentally inherit the previous zone.
    var defaults: Node = host.get_script().new()
    for property in defaults.get_property_list():
        var name := String(property.name)
        if (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0 or name in loader.SESSION_FIELDS:
            continue
        var value: Variant = defaults.get(name)
        host.set(name, value.duplicate(true) if value is Array or value is Dictionary else value)
    defaults.free()


static func measure_batch(loader: RefCounted, operations: int, started: int, metric: String) -> void:
    loader.last_transition[metric] = maxi(int(loader.last_transition.get(metric, 0)), operations)
    var batch_usec := Time.get_ticks_usec() - started
    loader.last_transition["max_batch_usec"] = maxi(int(loader.last_transition.get("max_batch_usec", 0)), batch_usec)
    # Per phase (unload/build/commit), so the slowest phase is named.
    var phase_key := metric.replace("_operations", "_batch_usec")
    loader.last_transition[phase_key] = maxi(int(loader.last_transition.get(phase_key, 0)), batch_usec)
    loader.last_transition["batches"] = int(loader.last_transition.get("batches", 0)) + 1


static func discard_catalog_lookahead(loader: RefCounted, read_ahead: Dictionary) -> void:
    if not read_ahead.is_empty():
        loader.config_read_job.discard(int(read_ahead.ticket))
        read_ahead.clear()


static func discard_catalog_staging(loader: RefCounted, host: Variant, read_ahead: Dictionary = {}) -> void:
    discard_catalog_lookahead(loader, read_ahead)
    if is_instance_valid(host):
        host.world_catalog_prepare_staging = {}


static func poll_region_textures(loader: RefCounted, keep: bool) -> void:
    for index in range(loader.region_texture_jobs.size() - 1, -1, -1):
        var job: Dictionary = loader.region_texture_jobs[index]
        if not job.worker.ready():
            continue
        var texture := job.worker.take().get("resource") as Texture2D
        loader.region_texture_jobs.remove_at(index)
        if keep and texture != null:
            loader.region_texture_hold.append(texture)
        elif keep:
            loader.last_transition["region_texture_failures"] = int(loader.last_transition.get("region_texture_failures", 0)) + 1


static func begin_player_art(loader: RefCounted, host: Node) -> bool:
    if not host.has_method("_spawn_player") or is_instance_valid(host.get("player")) or loader.player_art_job != null or not loader.player_art_resources.is_empty(): return true
    loader.player_art_job = PLAYER_ART_WARM_JOB.new()
    if loader.player_art_job.begin() != OK:
        loader.player_art_job = null
        loader.last_error = "无法启动主角素材预读。"
        return false
    return true


static func finalize_prepare_metrics(loader: RefCounted, role: String, wall_started: int) -> void:
    loader.last_transition["prepare_wall_usec"] = Time.get_ticks_usec() - wall_started
    # Compatibility metric: prepare_usec retains the old synchronous-work
    # meaning and excludes yielded frame time.
    loader.last_transition["prepare_usec"] = int(loader.last_transition.get("prepare_work_usec", 0))
    var metric_keys := ["prepare_jobs", "prepare_cursor", "prepare_batches", "prepare_batch_operations",
        "prepare_work_usec", "prepare_wall_usec", "prepare_plan_usec", "prepare_usec",
        "max_prepare_operations", "max_prepare_batch_usec", "max_prepare_job_usec", "prepare_operation_usec", "catalog_reads"]
    var attempt: Dictionary = {"role": role}
    for key in metric_keys:
        var value: Variant = loader.last_transition.get(key, null)
        attempt[key] = value.duplicate(true) if value is Array or value is Dictionary else value
    var attempts: Array = loader.last_transition.get("prepare_attempts", [])
    attempts.append(attempt)
    loader.last_transition["prepare_attempts"] = attempts
    loader.last_transition["%s_prepare" % role] = attempt.duplicate(true)


static func set_destination(loader: RefCounted, host: Node, path: String, entry: Vector2, previous_id: String, target: Dictionary) -> void:
    loader._reset_region_fields(host)
    host.config_path = path
    host.world_loading = true
    host.chapter_transitioning = true
    host.entry_spawn_override_enabled = true
    host.entry_spawn_override = entry
    host.entered_from_config_id = previous_id
    host.transition_entry_message = "旧路重新接通 · " + String(target.get("name", ""))
