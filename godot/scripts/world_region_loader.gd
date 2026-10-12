extends RefCounted
## The World node is the persistent host. Only its region-owned children are
## evicted; the Player, WorldState and BuildSystem remain the same instances.
## This is a coarse active-region chunk, not yet distance-based room streaming.
const COORDINATES := preload("res://scripts/world_coordinates.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const SESSION_FIELDS := ["player", "world_mode", "world_resume", "world_save_path",
    "world_state", "world_slot", "world_loader", "build_system", "applied_build_profile",
    "world_catalog", "world_narrative", "world_write_error_shown"]
var generation := 0
var active_region_id := ""
var phase := "idle"
var last_error := ""
var unloaded_nodes := 0

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

func preflight(path: String, entry: Vector2) -> Dictionary:
    last_error = ""
    if not entry.is_finite() or not FileAccess.file_exists(path):
        last_error = "目标位置或区域文件无效。"
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
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
    for field in ["map_rooms", "platforms", "terrain", "locked_gates", "collectibles", "interactives", "npcs", "enemy_spawns", "save_points"]:
        if not parsed.get(field, []) is Array:
            last_error = "目标区域的%s记录无效。" % field
            return {}
        for item in parsed.get(field, []):
            if not item is Dictionary:
                last_error = "目标区域的%s条目无效。" % field
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

func replace_region(host: Node, path: String, entry: Vector2) -> bool:
    if phase != "idle" or not is_instance_valid(host.player):
        last_error = "区域正在装载。"
        return false
    phase = "preflight"
    var target := preflight(path, entry)
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
    host.config_path = path
    host.world_loading = true
    host.entry_spawn_override_enabled = true
    host.entry_spawn_override = entry
    host.entered_from_config_id = previous_id
    host.transition_entry_message = "旧路重新接通 · " + String(target.get("name", ""))
    phase = "loading"
    host._initialize_region(target)
    host.player.reset_camera_after_arrival()
    host.process_mode = previous_mode
    phase = "idle"
    return true
