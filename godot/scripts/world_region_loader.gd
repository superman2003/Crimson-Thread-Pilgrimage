extends RefCounted
## The World node is the persistent host. Only its region-owned children are
## evicted; the Player, WorldState and BuildSystem remain the same instances.
## This is a coarse active-region chunk, not yet distance-based room streaming.
const COORDINATES := preload("res://scripts/world_coordinates.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const SESSION_FIELDS := ["player", "world_mode", "world_resume", "world_save_path",
    "world_state", "world_slot", "world_loader", "build_system", "applied_build_profile",
    "world_catalog", "world_narrative", "world_write_error_shown", "world_prefetch"]
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
    if not entry.is_finite() or not FileAccess.file_exists(path):
        last_error = "目标位置或区域文件无效。"
        return {}
    var parsed: Variant = prefetch.cached_raw(path) if prefetch != null else null
    if parsed == null:
        parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    return validate_config(parsed, path, entry)

func validate_config(parsed: Variant, path: String, entry: Vector2) -> Dictionary:
    last_error = ""
    if not entry.is_finite():
        last_error = "目标位置无效。"
        return {}
    if not parsed is Dictionary:
        last_error = "目标区域记录无法读取。"
        return {}
    var id := String(parsed.get("id", ""))
    if not COORDINATES.has_region(id) or ROUTES.config_path(id) != path:
        last_error = "目标区域不属于当前巡礼世界。"
        return {}
    if not parsed.get("world") is Dictionary or not parsed.get("map_rooms") is Array or parsed.map_rooms.is_empty():
        last_error = "目标区域缺少地形与房间记录。"
        return {}
    if not parsed.get("inventory", {}) is Dictionary:
        last_error = "目标区域的物品记录无效。"
        return {}
    for field in ["map_rooms", "platforms", "terrain", "locked_gates", "collectibles", "interactives", "npcs", "enemy_spawns", "save_points", "hazards", "grapple_anchors", "cave_lifts", "environment_blocks"]:
        if not parsed.get(field, []) is Array:
            last_error = "目标区域的%s记录无效。" % field
            return {}
        for item in parsed.get(field, []):
            if not item is Dictionary:
                last_error = "目标区域的%s条目无效。" % field
                return {}
            for key in ["position", "rect"]:
                if item.has(key) and not _finite_tuple(item[key], 2 if key == "position" else 4):
                    last_error = "目标区域的%s坐标无效。" % field
                    return {}
            if field == "terrain":
                if not item.get("surface", []) is Array:
                    last_error = "目标区域地形轮廓无效。"
                    return {}
                for point in item.get("surface", []):
                    if not _finite_tuple(point, 2):
                        last_error = "目标区域地形轮廓坐标无效。"
                        return {}
    var config := ROUTES.apply_to(parsed)
    var world: Variant = config.get("world")
    if not world is Dictionary:
        last_error = "目标区域缺少世界边界。"
        return {}
    for dimension in ["width", "height"]:
        var value: Variant = world.get(dimension)
        if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or float(value) <= 0:
            last_error = "目标区域世界边界无效。"
            return {}
    if Vector2(world.width, world.height) != COORDINATES.region_bounds(id).size:
        last_error = "目标区域边界与世界坐标记录不一致。"
        return {}
    if entry.x < -40 or entry.x > float(world.width) + 80 or entry.y < -120 or entry.y > float(world.height) + 70:
        last_error = "目标落点超出区域边界。"
        return {}
    return config

func _finite_tuple(value: Variant, length: int) -> bool:
    if not value is Array or value.size() != length:
        return false
    for component in value:
        if typeof(component) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(component)):
            return false
    return true


func replace_region(host: Node, path: String, entry: Vector2) -> bool:
    if phase != "idle" or not is_instance_valid(host.player):
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
    phase = "unloading"
    for child in host.get_children():
        if child == host.player:
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


## Escape requests rollback while the geometry plan is incomplete. Permanent
## progress is restored from the settled departure snapshot; transient attacks
## are cancelled and source enemies are reconstructed, as on ordinary revisit.
func cancel_transition() -> void:
    if phase in ["unloading", "loading"]:
        cancel_requested = true


func shutdown() -> void:
    shutting_down = true
    cancel_requested = true
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
            if not is_instance_valid(child) or child == host.player or child.get_parent() != host:
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
    var prepared_at := Time.get_ticks_usec()
    host._prepare_region(target)
    last_transition["prepare_usec"] = Time.get_ticks_usec() - prepared_at
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


func _set_destination(host: Node, path: String, entry: Vector2, previous_id: String, target: Dictionary) -> void:
    _reset_region_fields(host)
    host.config_path = path
    host.world_loading = true
    host.chapter_transitioning = true
    host.entry_spawn_override_enabled = true
    host.entry_spawn_override = entry
    host.entered_from_config_id = previous_id
    host.transition_entry_message = "旧路重新接通 · " + String(target.get("name", ""))


func replace_region_async(host: Node, path: String, entry: Vector2) -> bool:
    if phase != "idle" or not _alive(host) or not is_instance_valid(host.player):
        last_error = "区域正在装载。"
        return false
    phase = "preflight"
    var target := preflight(path, entry, host.world_prefetch)
    if target.is_empty():
        phase = "idle"
        return false
    var source_config: Dictionary = host.config.duplicate(true)
    var source_path: String = host.config_path
    var source_position: Vector2 = host.player.global_position
    var previous_mode: int = host.process_mode
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
    generation += 1 # invalidate departing callbacks before the first yield
    cancel_requested = false
    last_transition = {"source": source_id, "target": String(target.id), "rolled_back": false}
    _show_loading_canvas(host)
    phase = "unloading"
    if not await _evict_budgeted(host):
        _clear_loading_canvas()
        return false
    _set_destination(host, path, entry, source_id, target)
    phase = "loading"
    var built := await _construct_budgeted(host, target, true)
    if not _alive(host):
        _clear_loading_canvas()
        return false
    if not built:
        phase = "rollback"
        last_transition["rolled_back"] = true
        host._stop_region_tweens()
        host._release_region_audio()
        if not await _evict_budgeted(host):
            _clear_loading_canvas()
            return false
        host.world_state.data = source_state
        host.build_system.restore(source_build)
        _set_destination(host, source_path, source_position, source_id, source_config)
        host.transition_entry_message = "已返回来路。"
        if not await _construct_budgeted(host, source_config, false):
            _clear_loading_canvas()
            return false
    # Arrival, exploration, UI and save happen only after the entire geometry
    # plan is built. Partially loaded targets never become the saved location.
    phase = "committing"
    var committed_at := Time.get_ticks_usec()
    host._finish_region()
    last_transition["commit_usec"] = Time.get_ticks_usec() - committed_at
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
    if phase != "idle":
        return
    _run_transition(host, path, entry)


func _run_transition(host: Node, path: String, entry: Vector2) -> void:
    var result := await replace_region_async(host, path, entry)
    if not _alive(host):
        return
    if not result:
        host.chapter_transitioning = false
        if is_instance_valid(host.audio_director):
            host.audio_director.cancel_chapter_transition()
        host._toast(last_error)
