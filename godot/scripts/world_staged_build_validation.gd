extends SceneTree
## W00 stage 3 (docs/W00_SEAMLESS_RESIDENCY_PLAN.md): a destination region is
## built hidden while the source region stays resident, then becomes current.
## For every region this checks that (1) the source is untouched on every frame
## of the hidden build and after a cancelled one, and (2) the region that takes
## over is the one ordinary travel builds. The source is held still the way a
## passage holds it; regions are reached by fixture calls, not by natural play.
const ROUTES := preload("res://scripts/world_routes.gd")
const COORDINATES := preload("res://scripts/world_coordinates.gd")
const REGION_STATE := preload("res://scripts/region_state.gd")
const LEVEL_HOST := preload("res://scripts/level_host.gd")
const PATH := "user://world_staged_build_validation.json"
## Host fields that advance on their own while a frozen source is on screen.
const TICKING := ["subtitle_elapsed", "lore_banner_time_left", "last_toast_sfx_ms"]
var scene: Node
var checks := 0
var failures := 0
var metrics: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _frames(count: int) -> void:
	for index in range(count):
		await process_frame


func _entry(id: String) -> Vector2:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROUTES.config_path(id)))
	return Vector2(raw.player_start[0], raw.player_start[1])


func _walk(node: Node, result: Dictionary) -> void:
	if node.has_meta("rim_chunk"):
		return
	if node == scene.player or node is CanvasLayer or node is Window or node is AudioStreamPlayer or node is AudioStreamPlayer2D or node == scene.audio_director or node == scene.metsys_bridge:
		return
	var kind := node.get_class()
	result.types[kind] = int(result.types.get(kind, 0)) + 1
	if node is CollisionShape2D or node is CollisionPolygon2D:
		result.shapes += 1
	# Spawn points: enemies already patrol during the settling frames.
	if node.is_in_group("enemy") and node is Node2D:
		result.enemies.append(str(node.get("spawn_position") if node.get("spawn_position") != null else node.position))
	for child in node.get_children():
		_walk(child, result)


## What ordinary travel and a handed-over hidden build must agree on.
func _region_signature() -> Dictionary:
	var world := {"types": {}, "shapes": 0, "enemies": [], "hazards": scene.hazard_total, "collectibles": scene.collectible_total,
		"saves": scene.save_point_total, "enemy_total": scene.enemy_total, "gates": scene.locked_gate_bodies.keys(),
		"size": [scene.world_width, scene.world_height], "spawn": str(scene.active_spawn)}
	for child in scene.region_root.get_children():
		_walk(child, world)
	world.enemies.sort()
	world.gates.sort()
	var ui := {"types": {}, "buttons": [], "items": []}
	var pending: Array[Node] = [scene.ui_canvas]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		var kind := node.get_class()
		ui.types[kind] = int(ui.types.get(kind, 0)) + 1
		if node is Button:
			ui.buttons.append(node.text)
		if node.has_meta("item_id"):
			ui.items.append(String(node.get_meta("item_id")))
		pending.append_array(node.get_children())
	ui.buttons.sort()
	ui.items.sort()
	var map: Dictionary = scene.metsys_bridge.get_state()
	return {"world": JSON.stringify(world), "ui": JSON.stringify(ui),
		"map": [map.get("metsys_ready"), map.get("metsys_map_cells"), map.get("metsys_room_coords"), map.get("metsys_registered_objects"), map.get("metsys_route_edges")],
		"player": [scene.player.global_position.round(), scene.player.hp, scene.player.energy]}


## A comparable digest of a field value. Objects count by identity (a node
## replaced by another is a change; its internals are covered by the tree and
## the other parts of the fingerprint), containers by their contents.
func _stable(value: Variant, depth: int = 0) -> String:
	if value is Object:
		return "obj:%d" % (value.get_instance_id() if is_instance_valid(value) else 0)
	if depth > 6:
		return "deep"
	if value is Array:
		var parts: PackedStringArray = []
		for item in value:
			parts.append(_stable(item, depth + 1))
		return "[" + ",".join(parts) + "]"
	if value is Dictionary:
		var parts: PackedStringArray = []
		for key in value:
			parts.append(str(key) + ":" + _stable(value[key], depth + 1))
		return "{" + ",".join(parts) + "}"
	return var_to_str(value)


## Everything of the resident source a hidden build must leave alone.
func _source_fingerprint() -> Dictionary:
	var out := {}
	for field in REGION_STATE.travel_fields():
		if not field in TICKING:
			out["field:" + field] = _stable(scene.get(field)).hash()
	out["container"] = [scene.region_root.get_instance_id(), scene.region_root.get_child_count(), scene.region_root.visible, scene.region_root.process_mode]
	var strays: PackedStringArray = []
	for child in scene.get_children():
		if not child.has_meta(LEVEL_HOST.META):
			strays.append(String(child.name) + ("" if child.get_script() == null else "<" + child.get_script().resource_path.get_file() + ">"))
	out["host_children"] = ",".join(strays)
	out["player"] = [scene.player.global_position, scene.player.hp, scene.player.energy, scene.player.collision_layer]
	out["world_state"] = _stable(scene.world_state.data).hash()
	out["build"] = _stable(scene.build_system.serialize()).hash()
	out["catalog"] = _stable(scene.world_catalog).hash()
	out["map"] = _stable(scene.metsys_bridge.get_state()).hash()
	var owned_enemies := 0
	for enemy in get_nodes_in_group("enemy"):
		if LEVEL_HOST.owns(scene, enemy):
			owned_enemies += 1
	out["owned_enemies"] = owned_enemies
	out["generation"] = scene.world_loader.generation
	return out


func _differences(before: Dictionary, after: Dictionary) -> String:
	var changed: Array[String] = []
	for key in before:
		if before[key] != after.get(key):
			changed.append(String(key) + (" %s->%s" % [before[key], after.get(key)] if key == "host_children" else ""))
	return ",".join(changed)


## Which keys differ between two signature parts (JSON text or plain values).
func _explain(staged: Variant, ordinary: Variant) -> String:
	if staged is String and ordinary is String:
		var a: Variant = JSON.parse_string(staged)
		var b: Variant = JSON.parse_string(ordinary)
		if a is Dictionary and b is Dictionary:
			var out: PackedStringArray = []
			for key in b:
				if a.get(key) != b[key]:
					if a.get(key) is Dictionary and b[key] is Dictionary:
						for sub in b[key]:
							if a[key].get(sub) != b[key][sub]: out.append("%s.%s %s/%s" % [key, sub, a[key].get(sub), b[key][sub]])
						for sub in a[key]:
							if not b[key].has(sub): out.append("%s.%s %s/-" % [key, sub, a[key][sub]])
					elif a.get(key) is Array and b[key] is Array:
						var only_a: Array = a.get(key).filter(func(x): return not x in b[key])
						var only_b: Array = b[key].filter(func(x): return not x in a.get(key))
						out.append("%s +%s -%s" % [key, str(only_a).left(200), str(only_b).left(200)])
					else:
						out.append("%s %s/%s" % [key, str(a.get(key)).left(80), str(b[key]).left(80)])
			return "; ".join(out)
	return "%s / %s" % [str(staged).left(200), str(ordinary).left(200)]


## The slowest single jobs of a hidden build: they run while the player walks.
func _slowest_jobs(metric: Dictionary) -> Array:
	var jobs: Array = []
	for key in metric.get("prepare_operation_usec", {}):
		jobs.append(["prepare " + String(key).get_slice(":", 1), int(metric.prepare_operation_usec[key])])
	for key in metric.get("commit_operation_usec", {}):
		jobs.append(["commit " + String(key), int(metric.commit_operation_usec[key])])
	for key in metric.get("build_operation_usec", {}):
		jobs.append(["build " + String(key), int(metric.build_operation_usec[key])])
	jobs.sort_custom(func(a, b): return a[1] > b[1])
	var out: Array = []
	for job in jobs.slice(0, 8):
		out.append("%s %.1fms" % [job[0], float(job[1]) / 1000.0])
	return out


func _containers() -> Array[String]:
	var names: Array[String] = []
	for child in scene.get_children():
		if child.has_meta(LEVEL_HOST.META):
			names.append(String(child.name))
	return names


## Holds the source still, as walking a passage does.
func _hold_source() -> void:
	scene.world_passage._freeze_current_region()
	scene.world_loading = true
	scene.player.set_physics_process(false)


func _run() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + suffix))
	scene = load("res://scenes/World.tscn").instantiate()
	scene.world_resume = false
	scene.world_save_path = PATH
	root.add_child(scene)
	await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
	current_scene = scene
	await _frames(3)
	scene.player.debug_invulnerable = true
	var loader: RefCounted = scene.world_loader
	var regions: Array = COORDINATES.manifest().regions.keys()
	for id in regions:
		if String(scene.config.id) == id:
			# Leave and come back so every region is also a staged destination.
			var other: String = regions[(regions.find(id) + 1) % regions.size()]
			await loader.replace_region_async(scene, ROUTES.config_path(other), _entry(other))
			await _frames(2)
		var source := String(scene.config.id)
		var label := "%s -> %s" % [source.get_slice("_", 1), id.get_slice("_", 1)]
		_hold_source()
		await _frames(2)
		var before := _source_fingerprint()
		# 1. A hidden build cancelled part-way leaves nothing behind.
		loader.stage_region_async(scene, ROUTES.config_path(id), _entry(id))
		var frames := 0
		var touched := ""
		while loader.phase == "staging" and int(loader.last_transition.get("build_cursor", 0)) < 6 and frames < 4000:
			await process_frame
			frames += 1
			if touched.is_empty():
				touched = _differences(before, _source_fingerprint())
		_check(loader.phase == "staging" and not loader.staging.is_empty(), label + " hidden build reaches its build jobs")
		_check(touched.is_empty(), label + " source untouched while the build runs (" + touched + ")")
		loader.cancel_staging()
		frames = 0
		while (loader.phase != "idle" or loader.staging_retiring > 0) and frames < 4000:
			await process_frame
			frames += 1
		_check(loader.phase == "idle" and loader.staging.is_empty() and loader.staging_retiring == 0, label + " cancelled build unwinds")
		_check(_containers() == ["Region"], label + " cancelled build leaves no container (" + ",".join(_containers()) + ")")
		var after_cancel := _differences(before, _source_fingerprint())
		_check(after_cancel.is_empty(), label + " source identical after a cancelled build (" + after_cancel + ")")
		# 2. A finished hidden build, with the source resident throughout.
		loader.stage_region_async(scene, ROUTES.config_path(id), _entry(id))
		frames = 0
		touched = ""
		var shown := 0
		var peak_nodes := 0
		while loader.phase == "staging" and frames < 6000:
			await process_frame
			frames += 1
			if touched.is_empty():
				touched = _differences(before, _source_fingerprint())
			if not loader.staging.is_empty():
				var staged_root: Node2D = loader.staging.root
				if staged_root.visible or staged_root.process_mode != Node.PROCESS_MODE_DISABLED:
					shown += 1
				for child in staged_root.get_children():
					if child is CanvasLayer and child.visible:
						shown += 1
			peak_nodes = maxi(peak_nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		_check(loader.phase == "staged", label + " hidden build completes (" + loader.last_error + ")")
		if loader.phase != "staged":
			break
		_check(touched.is_empty(), label + " source untouched on every frame of the build (" + touched + ")")
		_check(shown == 0, label + " destination stays hidden and disabled while it is built")
		_check(String(scene.config.id) == source and _containers().size() == 2, label + " both regions resident, source current")
		var staged_metric: Dictionary = loader.last_transition.duplicate(true)
		var staged_root_id: int = loader.staging.root.get_instance_id()
		# 3. Handover: the source is retired, the destination becomes current.
		scene.player.set_physics_process(true)
		var handed: bool = await loader.handover_staged_async(scene)
		_check(handed and loader.phase == "idle" and loader.staging.is_empty(), label + " handover completes")
		_check(scene.world_gameplay_residency.generation == loader.generation, label + " residency follows the published generation")
		_check(String(scene.world_state.data.get("current_region", "")) == id, label + " arrival saved the destination")
		_check(scene.player.global_position.distance_to(_entry(id)) < 1.0, label + " player placed at the destination entry")
		await _frames(5)
		var arrived := _region_signature()
		_check(String(scene.config.id) == id and not scene.world_loading and not scene.chapter_transitioning, label + " destination is current and released")
		_check(_containers() == ["Region"] and scene.region_root.get_instance_id() == staged_root_id, label + " the staged container is the region now")
		_check(scene.region_root.visible and scene.region_root.process_mode == Node.PROCESS_MODE_INHERIT and scene.ui_canvas.visible, label + " destination shown and live")
		var handed_metric: Dictionary = loader.last_transition.duplicate(true)
		# Reference: leave, then reach the same region by ordinary travel, with the
		# same progress, and compare after the same settling frames.
		var away: bool = await loader.replace_region_async(scene, ROUTES.config_path(source), _entry(source))
		var back: bool = await loader.replace_region_async(scene, ROUTES.config_path(id), _entry(id))
		_check(away and back and String(scene.config.id) == id, label + " ordinary travel reaches the same region")
		await _frames(5)
		var reference: Dictionary = _region_signature()
		for part in ["world", "ui", "map"]:
			_check(arrived[part] == reference[part], "%s %s matches ordinary travel: %s" % [label, part, _explain(arrived[part], reference[part])])

		metrics.append({"route": label, "staging_wall_ms": snappedf(float(staged_metric.get("staging_wall_usec", 0)) / 1000.0, 0.1),
			"max_batch_ms": snappedf(float(staged_metric.get("max_batch_usec", 0)) / 1000.0, 0.1),
			"max_commit_batch_ms": snappedf(float(staged_metric.get("max_commit_batch_usec", 0)) / 1000.0, 0.1),
			"handover_switch_ms": snappedf(float(handed_metric.get("handover_switch_usec", 0)) / 1000.0, 0.1),
			"held_jobs": staged_metric.get("commit_jobs", 0), "peak_nodes": peak_nodes,
			"slowest_jobs": _slowest_jobs(staged_metric)})
	print("WORLD_STAGED_BUILD_METRICS ", JSON.stringify(metrics))
	scene.free()
	await process_frame
	print("WORLD_STAGED_BUILD checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
