extends RefCounted
## Budget-owned world-route overlay. Array scans and appended values advance
## incrementally; nested values are copied through the shared Variant job.
const COPY_JOB := preload("res://scripts/world_variant_copy_job.gd")
const OVERRIDE_FIELDS := [
	["map_room_overrides", "map_rooms"], ["terrain_overrides", "terrain"],
	["platform_overrides", "platforms"], ["locked_gate_overrides", "locked_gates"],
	["collectible_overrides", "collectibles"]]
const APPEND_FIELDS := ["collectibles", "platforms", "locked_gates", "map_rooms", "terrain", "grapple_anchors", "save_points"]
var done := true
var result: Dictionary = {}
var operation_name := "idle"
var edge_steps := 0
var max_copy_usec := 0
var total_operations := 0
var last_batch_operations := 0
var max_batch_operations := 0
var _config: Dictionary = {}
var _overlay: Dictionary = {}
var _stage := ""
var _field_i := 0
var _item_i := 0
var _target_i := 0
var _interactive_result: Array = []
var _copy: Variant
var _pending_target: Dictionary
var _pending_kind := ""
var _pending_field := ""
var _manifest_version: Variant = 1
var _merge_target: Dictionary = {}
var _merge_source: Dictionary = {}
var _merge_keys: Array = []
var _merge_i := 0
var _merge_next := ""
var _interactive_pending: Dictionary = {}
var _remove_index := 0
var _interactive_removed := false

func begin(config: Dictionary, overlay: Dictionary, version: Variant) -> void:
	_config = config
	result = {}
	_overlay = overlay
	_manifest_version = version
	done = overlay.is_empty()
	edge_steps = 0
	max_copy_usec = 0
	total_operations = 0
	last_batch_operations = 0
	max_batch_operations = 0
	_field_i = 0
	_item_i = 0
	_target_i = 0
	_interactive_result = []
	_copy = null
	_pending_target = {}
	_pending_kind = ""
	_stage = "world" if not done else "done"
	if done:
		result = _config

func step(max_operations: int = 32, budget_usec: int = 1200) -> bool:
	last_batch_operations = 0
	var batch_started := Time.get_ticks_usec()
	while not done and last_batch_operations < maxi(1, max_operations):
		if last_batch_operations > 0 and Time.get_ticks_usec() - batch_started >= maxi(1, budget_usec):
			break
		_step_once()
		last_batch_operations += 1
		total_operations += 1
	max_batch_operations = maxi(max_batch_operations, last_batch_operations)
	return done

func _step_once() -> void:
	if done:
		return
	if _copy != null:
		if not _copy.done:
			operation_name = "route_value_copy"
			var started := Time.get_ticks_usec()
			_copy.step(512)
			max_copy_usec = maxi(max_copy_usec, Time.get_ticks_usec() - started)
			edge_steps += 1
			return
		_finish_copy()
		return
	match _stage:
		"world":
			if _overlay.is_empty() or _overlay.get("world_overrides", {}).is_empty(): _stage = "override"
			else: _start_copy(_overlay.world_overrides, {}, "world")
		"override": _step_override()
		"append": _step_append()
		"interactives": _step_interactives()
		"catalog": _step_catalog()
		"merge": _step_merge()
		"done": _finish()

func _step_override() -> void:
	operation_name = "route_lookup"
	if _field_i >= OVERRIDE_FIELDS.size():
		_field_i = 0
		_item_i = 0
		_stage = "append"
		return
	var fields: Array = OVERRIDE_FIELDS[_field_i]
	var overrides: Array = _overlay.get(fields[0], [])
	var targets: Array = _config.get(fields[1], [])
	if _item_i >= overrides.size():
		_field_i += 1
		_item_i = 0
		_target_i = 0
		return
	if _target_i >= targets.size():
		_item_i += 1
		_target_i = 0
		return
	var target: Dictionary = targets[_target_i]
	_target_i += 1
	edge_steps += 1
	if str(target.get("id", "")) == str(overrides[_item_i].get("id", "")):
		_pending_target = target
		_pending_kind = "merge"
		_pending_field = ""
		_begin_copy(overrides[_item_i])

func _step_append() -> void:
	operation_name = "route_append"
	if _field_i >= APPEND_FIELDS.size():
		_field_i = 0
		_item_i = 0
		_stage = "interactives"
		return
	var field: String = APPEND_FIELDS[_field_i]
	var source: Array = _overlay.get(field, [])
	if source.is_empty():
		_field_i += 1
		_item_i = 0
		return
	if not _config.has(field): _config[field] = []
	if _item_i >= source.size():
		_field_i += 1
		_item_i = 0
		return
	_pending_kind = "append"
	_pending_field = field
	_begin_copy(source[_item_i])
	_item_i += 1

func _step_interactives() -> void:
	operation_name = "route_interactive"
	var source: Array = _config.get("interactives", [])
	if not _interactive_pending.is_empty():
		var removals: Array = _overlay.get("remove_interactives", [])
		if _remove_index < removals.size():
			var removal_id: Variant = removals[_remove_index]
			if typeof(removal_id) == TYPE_STRING and str(_interactive_pending.get("id", "")) == removal_id:
				_interactive_removed = true
			_remove_index += 1
			edge_steps += 1
			return
		if not _interactive_removed:
			_interactive_result.append(_interactive_pending)
		_interactive_pending = {}
		_remove_index = 0
		_interactive_removed = false
		return
	if _item_i < source.size():
		_interactive_pending = source[_item_i]
		_item_i += 1
		return
	if _field_i < _overlay.get("portals", []).size():
		_pending_kind = "portal"
		_begin_copy(_overlay.portals[_field_i])
		_field_i += 1
		return
	_config["interactives"] = _interactive_result
	_field_i = 0
	_item_i = 0
	_stage = "catalog"

func _step_catalog() -> void:
	operation_name = "route_catalog"
	var catalog: Dictionary = _overlay.get("inventory_catalog", {})
	if catalog.is_empty():
		_stage = "done"
		return
	_pending_kind = "catalog"
	_begin_copy(catalog)

func _begin_copy(value: Variant) -> void:
	_copy = COPY_JOB.new()
	_copy.begin(value)

func _start_copy(value: Variant, target: Dictionary, kind: String) -> void:
	_pending_target = target
	_pending_kind = kind
	_begin_copy(value)

func _finish_copy() -> void:
	var value: Variant = _copy.result
	_copy = null
	match _pending_kind:
		"world":
			_start_merge(_config["world"], value, "override")
		"merge": _start_merge(_pending_target, value, "override")
		"append": _config[_pending_field].append(value)
		"portal": _interactive_result.append(value)
		"catalog":
			if not _config.has("inventory"): _config["inventory"] = {}
			if not _config.inventory.has("catalog"): _config.inventory["catalog"] = {}
			_start_merge(_config.inventory.catalog, value, "done")
	_pending_kind = ""
	_pending_target = {}
	_pending_field = ""

func _start_merge(target: Dictionary, source: Dictionary, next_stage: String) -> void:
	_merge_target = target
	_merge_source = source
	# This shallow key enumeration is the largest remaining indivisible route
	# operation for unusually wide JSON dictionaries; values are assigned one
	# per subsequent validator step.
	_merge_keys = source.keys()
	_merge_i = 0
	_merge_next = next_stage
	_stage = "merge"

func _step_merge() -> void:
	operation_name = "route_merge"
	if _merge_i < _merge_keys.size():
		var key: Variant = _merge_keys[_merge_i]
		_merge_i += 1
		_merge_target[key] = _merge_source[key]
		edge_steps += 1
		return
	_merge_target = {}
	_merge_source = {}
	_merge_keys = []
	_stage = _merge_next

func _finish() -> void:
	_config["world_routes_version"] = _manifest_version
	result = _config
	done = true
	_stage = "done"

