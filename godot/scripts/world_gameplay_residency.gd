extends RefCounted
## Active-world residency for low-risk, reconstructible interactions. Stateful
## portals, map sellers, gates, exits, enemies and bosses remain world-owned.
const HALF := Vector2(1280.0, 900.0)
const KEEP_MARGIN := 1100.0
const BUDGET_US := 2000
const MAX_BUILD_PER_FRAME := 2
const MAX_RELEASE_PER_FRAME := 2
const FIELDS := {"npcs": "npc", "save_points": "save_point", "interactives": "interaction"}
const MAP_SELLERS_PATH := "res://data/cartography_sellers.json"
var records: Dictionary = {}
var resident: Dictionary = {}
var pending_build: Array[String] = []
var pending_release: Array[String] = []
var generation := -1
var host_instance_id := 0
var builds := 0
var releases := 0
var max_owned := 0
var last_frame_builds := 0
var last_frame_releases := 0
var critical_builds := 0
var warm_bypass_builds := 0
var warm_frame := -1
var warm_frame_builds := 0
var warm_frame_started_usec := 0
var last_window := Rect2()
var closed := false
var building_key := ""
var current_checkpoint_id := ""
var excluded_map_sellers := 0
var excluded_workshops := 0

func configure(host: Node, config: Dictionary, next_generation: int, focus: Vector2) -> void:
	shutdown()
	closed = false
	generation = next_generation
	host_instance_id = host.get_instance_id()
	var seller_ids: Dictionary = {}
	var seller_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MAP_SELLERS_PATH))
	if seller_data is Dictionary:
		for seller in seller_data.values():
			var seller_id := String(seller.get("npc_id", ""))
			if not seller_id.is_empty(): seller_ids[seller_id] = true
	for field in FIELDS:
		var category: String = FIELDS[field]
		for data_value in config.get(field, []):
			if not data_value is Dictionary: continue
			var data: Dictionary = data_value
			var kind := String(data.get("kind", "")) if category == "interaction" else category
			if kind not in ["npc", "save_point", "lever"]: continue
			var id := String(data.get("id", ""))
			var position: Variant = data.get("position", [])
			if id.is_empty() or not position is Array or position.size() < 2: continue
			if kind == "npc" and seller_ids.has(id):
				excluded_map_sellers += 1
				continue
			# These IDs are the exact proximity checks in _near_workstation().
			# Crafting depends on their physical presence as workshop anchors.
			if kind == "npc" and id in ["npc_rain_smith_liu", "npc_threadsmith_apprentice", "npc_beeswax_vendor"]:
				excluded_workshops += 1
				continue
			var key := kind + ":" + id
			var point := Vector2(float(position[0]), float(position[1]))
			if kind == "npc":
				point = host._world_npc_residency_position(id, point)
			records[key] = {"kind": kind, "id": id, "data": data.duplicate(true), "position": point}
			var actor := host.get_node_or_null(NodePath(id)) as Area2D
			if actor != null: resident[key] = actor
	_update_window(host, focus, Vector2.ZERO, 0.0)
	_refresh_queues(host, focus)
	max_owned = maxi(max_owned, resident.size())

func update(host: Node, focus: Vector2, velocity: Vector2, delta: float) -> void:
	last_frame_builds = 0
	last_frame_releases = 0
	if closed or host_instance_id != host.get_instance_id() or generation != host.world_loader.generation or not focus.is_finite() or not velocity.is_finite(): return
	_update_window(host, focus, velocity, delta)
	_refresh_queues(host, focus)
	var started := Time.get_ticks_usec()
	while not pending_release.is_empty() and last_frame_releases < MAX_RELEASE_PER_FRAME:
		if Time.get_ticks_usec() - started >= BUDGET_US: break
		var key: String = pending_release.pop_front()
		if not resident.has(key): continue
		if not is_instance_valid(resident[key]):
			resident.erase(key)
			continue
		var actor: Area2D = resident[key]
		if _must_hold(host, key, actor): continue
		if not host._release_resident_interaction(records[key].kind, records[key].id, actor): continue
		resident.erase(key)
		last_frame_releases += 1
		releases += 1
	while not pending_build.is_empty() and last_frame_builds < MAX_BUILD_PER_FRAME:
		if Time.get_ticks_usec() - started >= BUDGET_US: break
		var key: String = pending_build.pop_front()
		if resident.has(key) or not records.has(key): continue
		var record: Dictionary = records[key]
		building_key = key
		var actor: Area2D = host._build_resident_interaction(record.kind, record.data)
		building_key = ""
		if actor == null: continue
		resident[key] = actor
		last_frame_builds += 1
		builds += 1
	max_owned = maxi(max_owned, resident.size())

func _update_window(host: Node, focus: Vector2, velocity: Vector2, delta: float) -> void:
	var local_focus: Vector2 = host.to_local(focus)
	var sweep := velocity * clampf(delta, 0.0, 0.25)
	var critical := Rect2(local_focus - HALF, HALF * 2.0).expand(local_focus + sweep - HALF).expand(local_focus + sweep + HALF)
	var viewport: Vector2 = host.get_viewport_rect().size
	var zoom := Vector2.ONE
	if is_instance_valid(host.player):
		var camera := host.player.get_node_or_null("Camera2D") as Camera2D
		if camera != null: zoom = camera.zoom
	var half_view := Vector2(maxf(HALF.x, viewport.x / maxf(0.25, zoom.x) + 256.0), maxf(HALF.y, viewport.y / maxf(0.25, zoom.y) + 256.0))
	last_window = critical.merge(Rect2(local_focus - half_view, half_view * 2.0))

func _refresh_queues(host: Node, focus: Vector2) -> void:
	var keep: Rect2 = last_window.grow(KEEP_MARGIN)
	current_checkpoint_id = String(host.active_save_point_id)
	pending_build.clear()
	pending_release.clear()
	for key in records:
		var record: Dictionary = records[key]
		var actor: Area2D
		if resident.has(key) and is_instance_valid(resident[key]):
			actor = resident[key]
		else:
			resident.erase(key)
		if record.kind == "npc":
			var authored: Array = record.data.position
			var fallback: Vector2 = actor.position if is_instance_valid(actor) else Vector2(authored[0], authored[1])
			record.position = host._world_npc_residency_position(record.id, fallback)
			if is_instance_valid(actor): actor.position = record.position
		elif is_instance_valid(actor):
			record.position = actor.position
		var local_point: Vector2 = record.position
		if (last_window.has_point(local_point) or (record.kind == "save_point" and String(host.active_save_point_id) == record.id)) and (actor == null or not is_instance_valid(actor)):
			pending_build.append(key)
		elif not keep.has_point(local_point) and actor != null and is_instance_valid(actor) and not _must_hold(host, key, actor):
			pending_release.append(key)
	var local_focus: Vector2 = host.to_local(focus)
	pending_build.sort_custom(func(a, b): return records[a].position.distance_squared_to(local_focus) < records[b].position.distance_squared_to(local_focus))
	pending_release.sort_custom(func(a, b): return records[b].position.distance_squared_to(local_focus) < records[a].position.distance_squared_to(local_focus))

func _must_hold(host: Node, key: String, actor: Area2D) -> bool:
	if actor == host.nearby_interactable: return true
	if String(host.active_overlay) == "dialogue" and is_instance_valid(host.ui_shell) and host.ui_shell.dialogue_area == actor: return true
	if key.begins_with("save_point:") and String(host.active_save_point_id) == String(records[key].id): return true
	if is_instance_valid(host.ui_shell) and host.ui_shell.dialogue_area == actor: return true
	return host.player != null and is_instance_valid(host.player) and host.player.global_position.distance_to(actor.global_position) <= 190.0

func warm_arrival(host: Node, focus: Vector2) -> void:
	if closed or host_instance_id != host.get_instance_id(): return
	# Arrival and respawn readiness is critical work. It may exceed the normal
	# frame admission cap; the snapshot reports these builds separately.
	_update_window(host, focus, Vector2.ZERO, 0.0)
	_refresh_queues(host, focus)
	# Call before publishing a newly assembled region so every interaction in
	# the camera/arrival window is already present when input becomes available.
	var warmed := 0
	var frame := Engine.get_process_frames()
	if frame != warm_frame:
		warm_frame = frame
		warm_frame_builds = 0
		warm_frame_started_usec = Time.get_ticks_usec()
	while not pending_build.is_empty():
		var key: String = pending_build.pop_front()
		if resident.has(key) or not records.has(key): continue
		var record: Dictionary = records[key]
		var bypass_admission := warm_frame_builds >= MAX_BUILD_PER_FRAME or Time.get_ticks_usec() - warm_frame_started_usec >= BUDGET_US
		building_key = key
		var actor: Area2D = host._build_resident_interaction(record.kind, record.data)
		building_key = ""
		if actor == null: continue
		resident[key] = actor
		builds += 1
		warmed += 1
		warm_frame_builds += 1
		critical_builds += 1
		if bypass_admission: warm_bypass_builds += 1
	max_owned = maxi(max_owned, resident.size())

func should_defer(kind: String, data: Dictionary, host: Node) -> bool:
	if closed: return false
	var key := kind + ":" + String(data.get("id", ""))
	if building_key == key or not records.has(key): return false
	var point: Vector2 = records[key].position
	if kind == "save_point" and String(host.active_save_point_id) == String(data.get("id", "")): return false
	return not last_window.has_point(point)

func adopt(kind: String, id: String, actor: Area2D) -> void:
	var key := kind + ":" + id
	if records.has(key) and is_instance_valid(actor):
		resident[key] = actor
		max_owned = maxi(max_owned, resident.size())

func refresh_actor_position(kind: String, id: String, position: Vector2) -> void:
	var key := kind + ":" + id
	if records.has(key) and position.is_finite(): records[key].position = position

func snapshot() -> Dictionary:
	var live := 0
	var visible_candidates := 0
	var visible_resident := 0
	for key in resident:
		if is_instance_valid(resident[key]):
			live += 1
			if last_window.has_point(records[key].position): visible_resident += 1
	for record in records.values():
		if last_window.has_point(record.position): visible_candidates += 1
	var checkpoint_resident := true
	for key in records:
		if records[key].kind == "save_point" and String(records[key].id) == current_checkpoint_id:
			checkpoint_resident = resident.has(key) and is_instance_valid(resident[key])
			break
	return {"authored": records.size(), "eligible": records.size(), "resident": live,
		"excluded_map_sellers": excluded_map_sellers, "excluded_workshops": excluded_workshops,
		"window_eligible": visible_candidates, "window_resident": visible_resident,
		"window_ready": visible_resident >= visible_candidates,
		"checkpoint_id": current_checkpoint_id, "checkpoint_resident": checkpoint_resident,
		"arrival_ready": visible_resident >= visible_candidates and checkpoint_resident,
		"pending_build": pending_build.size(), "pending_release": pending_release.size(),
		"builds": builds, "releases": releases, "max_owned": max_owned,
		"last_frame_builds": last_frame_builds, "last_frame_releases": last_frame_releases,
		"normal_max_operations": MAX_BUILD_PER_FRAME + MAX_RELEASE_PER_FRAME,
		"critical_builds": critical_builds, "warm_bypass_builds": warm_bypass_builds,
		"generation": generation, "window": last_window}

func shutdown() -> void:
	closed = true
	host_instance_id = 0
	records.clear()
	resident.clear()
	pending_build.clear()
	pending_release.clear()
