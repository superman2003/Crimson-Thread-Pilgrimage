extends RefCounted
## Incremental counterpart of WorldRegionLoader.validate_config. Each step
## inspects one record/point/identity/profile/geometry item and never yields
## from inside a partially processed item.
const COORDINATES := preload("res://scripts/world_coordinates.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const INCREMENTAL_COPY := preload("res://scripts/world_variant_copy_job.gd")
const ROUTE_OVERLAY_JOB := preload("res://scripts/world_route_overlay_job.gd")
const FIELDS := ["map_rooms", "platforms", "terrain", "locked_gates", "collectibles", "interactives", "npcs", "enemy_spawns", "save_points", "hazards", "grapple_anchors", "cave_lifts", "environment_blocks"]
const ID_FIELDS := ["enemy_spawns", "npcs", "save_points", "interactives"]
var done := true
var error := ""
var result: Dictionary = {}
var operation_name := "idle"
var progress := 0.0
var _parsed: Variant
var _path := ""
var _entry := Vector2.ZERO
var _use_default_entry := false
var _stage := ""
var _field_i := 0
var _record_i := 0
var _point_i := 0
var _id_field_i := 0
var _terrain_i := 0
var _cave_i := 0
var _platform_i := 0
var _dimension_i := 0
var _identities: Dictionary = {}
var _terrain_ids: Dictionary = {}
var _platform_ids: Dictionary = {}
var _config: Dictionary = {}
var _profiles: Dictionary = {}
var _cave: Dictionary = {}
var _world: Dictionary = {}
var _route_copy: RefCounted
var route_copy_steps := 0
var max_route_copy_step_usec := 0
var max_route_copy_begin_usec := 0
var _route_overlay_job: RefCounted
var route_overlay_steps := 0
var max_route_overlay_step_usec := 0
var max_route_overlay_begin_usec := 0
var _manifest_generation := -1
# A nonempty private context makes validation independent of the live cache.
# Only this data-only mode may be run by the shared reader worker.
var _route_context: Dictionary = {}

func begin(parsed: Variant, path: String, entry: Vector2, use_default_entry: bool = false, route_context: Dictionary = {}) -> void:
	_parsed = parsed
	_path = path
	_entry = entry
	_use_default_entry = use_default_entry
	done = false
	error = ""
	result = {}
	progress = 0.0
	operation_name = "header"
	_stage = "header"
	_field_i = 0
	_record_i = 0
	_point_i = 0
	_id_field_i = 0
	_terrain_i = 0
	_cave_i = 0
	_platform_i = 0
	_dimension_i = 0
	_identities.clear()
	_terrain_ids.clear()
	_platform_ids.clear()
	_config = {}
	_profiles = {}
	_cave = {}
	_world = {}
	_route_copy = null
	route_copy_steps = 0
	max_route_copy_step_usec = 0
	max_route_copy_begin_usec = 0
	_route_overlay_job = null
	route_overlay_steps = 0
	max_route_overlay_step_usec = 0
	max_route_overlay_begin_usec = 0
	_route_context = route_context
	_manifest_generation = int(_route_context.get("generation", -1)) if not _route_context.is_empty() else ROUTES.cached_generation()
	if _manifest_generation < 0:
		_fail("巡礼路线尚未由世界读取器准备好。")

func step() -> bool:
	if done: return true
	if _manifest_generation < 0 or (_route_context.is_empty() and ROUTES.cached_generation() != _manifest_generation):
		_fail("巡礼路线版本已变化，请重试。")
		return true
	match _stage:
		"header": _step_header()
		"records": _step_records()
		"identities": _step_identity()
		"profiles_header": _step_profiles_header()
		"profiles": _step_profile()
		"terrain_ids": _step_terrain_id()
		"cave_header": _step_cave_header()
		"cave_rects": _step_cave_rect()
		"apply_routes": _step_apply_routes()
		"platforms": _step_platform()
		"world_header": _step_world_header()
		"world_dimensions": _step_world_dimension()
		"world_bounds": _step_world_bounds()
		"entry": _step_entry()
		_: _fail("目标区域记录无法读取。")
	if not done:
		progress = minf(0.99, float(_stage_number()) / 14.0)
	return done

func _stage_number() -> int:
	var order := ["header", "records", "identities", "profiles_header", "profiles", "terrain_ids", "cave_header", "cave_rects", "apply_routes", "platforms", "world_header", "world_dimensions", "world_bounds", "entry"]
	return maxi(0, order.find(_stage))

func _step_header() -> void:
	operation_name = "header"
	if not _use_default_entry and not _entry.is_finite(): return _fail("目标位置无效。")
	if not _parsed is Dictionary: return _fail("目标区域记录无法读取。")
	var id := String(_parsed.get("id", ""))
	var known_region: bool = COORDINATES.has_region(id) if _route_context.is_empty() else bool(_route_context.get("known_region", false)) and id == String(_route_context.get("region_id", ""))
	var registered_path: String = ROUTES.cached_config_path(id) if _route_context.is_empty() else String(_route_context.get("path", ""))
	if not known_region or registered_path != _path: return _fail("目标区域不属于当前巡礼世界。")
	if not _parsed.get("world") is Dictionary or not _parsed.get("map_rooms") is Array or _parsed.map_rooms.is_empty(): return _fail("目标区域缺少地形与房间记录。")
	if not _parsed.get("inventory", {}) is Dictionary: return _fail("目标区域的物品记录无效。")
	_stage = "records"

func _step_records() -> void:
	operation_name = "records"
	if _field_i >= FIELDS.size():
		_stage = "identities"
		return
	var field: String = FIELDS[_field_i]
	var items: Variant = _parsed.get(field, [])
	if not items is Array: return _fail("目标区域的%s记录无效。" % field)
	if _record_i >= items.size():
		_field_i += 1
		_record_i = 0
		return
	var item: Variant = items[_record_i]
	if not item is Dictionary: return _fail("目标区域的%s条目无效。" % field)
	for key in ["position", "rect"]:
		if item.has(key) and not _finite_tuple(item[key], 2 if key == "position" else 4): return _fail("目标区域的%s坐标无效。" % field)
	if field == "terrain":
		var surface: Variant = item.get("surface", [])
		if not surface is Array: return _fail("目标区域地形轮廓无效。")
		if _point_i < surface.size():
			if not _finite_tuple(surface[_point_i], 2): return _fail("目标区域地形轮廓坐标无效。")
			_point_i += 1
			return
		_point_i = 0
	_record_i += 1

func _step_identity() -> void:
	operation_name = "identity"
	if _id_field_i >= ID_FIELDS.size():
		_stage = "profiles_header"
		return
	var field: String = ID_FIELDS[_id_field_i]
	var items: Array = _parsed.get(field, [])
	if _record_i >= items.size():
		_id_field_i += 1
		_record_i = 0
		_identities.clear()
		return
	var item: Dictionary = items[_record_i]
	var item_id: Variant = item.get("id")
	if not item_id is String or String(item_id).is_empty() or _identities.has(item_id): return _fail("目标区域的%s身份无效或重复。" % field)
	_identities[item_id] = true
	if not _finite_tuple(item.get("position"), 2): return _fail("目标区域的%s落点无效。" % field)
	for size_field in ["interaction_size", "body_size", "hurtbox_size"]:
		if not item.has(size_field): continue
		if size_field != "interaction_size" and item[size_field] is Array and item[size_field].is_empty(): continue
		var size: Variant = item[size_field]
		if not _finite_tuple(size, 2) or float(size[0]) <= 0 or float(size[1]) <= 0: return _fail("目标区域的%s尺寸无效。" % size_field)
	_record_i += 1

func _step_profiles_header() -> void:
	operation_name = "profiles"
	var profiles: Variant = _parsed.get("ai_profiles", {})
	if not profiles is Dictionary: return _fail("目标区域的敌人行为记录无效。")
	_profiles = profiles
	_record_i = 0
	_stage = "profiles"

func _step_profile() -> void:
	operation_name = "profile"
	var enemies: Array = _parsed.get("enemy_spawns", [])
	if _record_i >= enemies.size():
		_stage = "terrain_ids"
		_record_i = 0
		return
	var enemy: Dictionary = enemies[_record_i]
	if not _profiles.get(String(enemy.get("kind", "moss_larva")), {}) is Dictionary: return _fail("目标区域的敌人行为条目无效。")
	_record_i += 1

func _step_terrain_id() -> void:
	operation_name = "terrain"
	var terrain: Array = _parsed.get("terrain", [])
	if _terrain_i >= terrain.size():
		_stage = "cave_header"
		return
	var landform: Dictionary = terrain[_terrain_i]
	var terrain_id: Variant = landform.get("id")
	var depth: Variant = landform.get("depth", 104)
	if not terrain_id is String or String(terrain_id).is_empty() or _terrain_ids.has(terrain_id): return _fail("目标区域地形身份无效或重复。")
	if typeof(depth) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(depth)) or float(depth) <= 0: return _fail("目标区域地形厚度无效。")
	_terrain_ids[terrain_id] = true
	_terrain_i += 1

func _step_cave_header() -> void:
	operation_name = "cave"
	var cave: Variant = _parsed.get("cave_world", {})
	if not cave is Dictionary or not cave.get("solid_rects", []) is Array: return _fail("目标区域岩层记录无效。")
	_cave = cave
	_stage = "cave_rects"

func _step_cave_rect() -> void:
	operation_name = "cave_rectangle"
	var rects: Array = _cave.get("solid_rects", [])
	if _cave_i >= rects.size():
		_stage = "apply_routes"
		return
	var rect: Variant = rects[_cave_i]
	if not _finite_tuple(rect, 4) or float(rect[2]) <= 0 or float(rect[3]) <= 0: return _fail("目标区域岩层坐标或尺寸无效。")
	_cave_i += 1

func _step_apply_routes() -> void:
	operation_name = "apply_routes"
	if _route_copy == null:
		operation_name = "route_snapshot_begin"
		var begin_started := Time.get_ticks_usec()
		_route_copy = INCREMENTAL_COPY.new()
		_route_copy.begin(_parsed)
		max_route_copy_begin_usec = maxi(max_route_copy_begin_usec, Time.get_ticks_usec() - begin_started)
		return
	if not _route_copy.done:
		operation_name = "route_snapshot_copy"
		var copy_started := Time.get_ticks_usec()
		_route_copy.step(512)
		route_copy_steps += 1
		max_route_copy_step_usec = maxi(max_route_copy_step_usec, Time.get_ticks_usec() - copy_started)
		return
	if _route_overlay_job == null:
		operation_name = "route_overlay_begin"
		var overlay_begin_started := Time.get_ticks_usec()
		_route_overlay_job = ROUTE_OVERLAY_JOB.new()
		var bundle: Dictionary = ROUTES.cached_overlay_bundle(String(_parsed.get("id", ""))) if _route_context.is_empty() else _route_context.get("bundle", {})
		if int(bundle.get("generation", -1)) != _manifest_generation:
			_fail("巡礼路线版本已变化，请重试。")
			return
		_route_overlay_job.begin(_route_copy.result, bundle.overlay, bundle.version)
		max_route_overlay_begin_usec = maxi(max_route_overlay_begin_usec, Time.get_ticks_usec() - overlay_begin_started)
		return
	var overlay_started := Time.get_ticks_usec()
	var overlay_done: bool = _route_overlay_job.step(32, 1200)
	operation_name = String(_route_overlay_job.operation_name)
	route_overlay_steps += int(_route_overlay_job.last_batch_operations)
	max_route_overlay_step_usec = maxi(max_route_overlay_step_usec, Time.get_ticks_usec() - overlay_started)
	if overlay_done:
		_config = _route_overlay_job.result
		_route_overlay_job = null
		_stage = "platforms"

func _step_platform() -> void:
	operation_name = "platform"
	var platforms: Array = _config.get("platforms", [])
	if _platform_i >= platforms.size():
		_stage = "world_header"
		return
	var platform: Dictionary = platforms[_platform_i]
	var id_value: Variant = platform.get("id")
	var rect: Variant = platform.get("rect")
	if not id_value is String or String(id_value).is_empty() or not _finite_tuple(rect, 4) or float(rect[2]) <= 0 or float(rect[3]) <= 0: return _fail("目标区域的平台身份或尺寸无效。")
	if _platform_ids.has(id_value): return _fail("目标区域的平台身份重复。")
	_platform_ids[id_value] = true
	_platform_i += 1

func _step_world_header() -> void:
	operation_name = "world"
	var world: Variant = _config.get("world")
	if not world is Dictionary: return _fail("目标区域缺少世界边界。")
	_world = world
	_dimension_i = 0
	_stage = "world_dimensions"

func _step_world_dimension() -> void:
	operation_name = "world_dimension"
	var dimension := "width" if _dimension_i == 0 else "height"
	var value: Variant = _world.get(dimension)
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or float(value) <= 0: return _fail("目标区域世界边界无效。")
	_dimension_i += 1
	if _dimension_i >= 2: _stage = "world_bounds"

func _step_world_bounds() -> void:
	operation_name = "world_bounds"
	var id := String(_parsed.get("id", ""))
	var expected_size: Vector2 = COORDINATES.region_bounds(id).size if _route_context.is_empty() else _route_context.get("world_size", Vector2.ZERO)
	if Vector2(_world.width, _world.height) != expected_size: return _fail("目标区域边界与世界坐标记录不一致。")
	_stage = "entry"

func _step_entry() -> void:
	operation_name = "entry"
	if _use_default_entry:
		var start: Variant = _config.get("player_start", [120, 500])
		if not _finite_tuple(start, 2): return _fail("初始区域出生位置无效。")
		_entry = Vector2(float(start[0]), float(start[1]))
	if not entry_in_bounds(_entry, _world): return _fail("目标落点超出区域边界。")
	result = _config
	done = true
	progress = 1.0
	_stage = "done"

## Call only with previously validated world dimensions. A different entrance
## does not change authored region data; it only needs this landing check.
static func entry_in_bounds(entry: Vector2, world: Dictionary) -> bool:
	return entry.is_finite() and entry.x >= -40 and entry.x <= float(world.width) + 80 and entry.y >= -120 and entry.y <= float(world.height) + 70

func _fail(message: String) -> void:
	error = message
	result = {}
	done = true
	progress = 1.0
	_stage = "done"

func _finite_tuple(value: Variant, length: int) -> bool:
	if not value is Array or value.size() != length: return false
	for component in value:
		if typeof(component) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(component)):
			return false
	return true
