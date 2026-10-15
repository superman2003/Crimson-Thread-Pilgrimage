extends SceneTree
## Active interaction residency regression. Region starts, focus jumps, and save
## flags are explicit fixtures; this does not represent natural six-region play.
const ROUTES := preload("res://scripts/world_routes.gd")
const STATE := preload("res://scripts/world_state.gd")
const REGIONS := ["demo_ch01_moss_bell_court", "demo_ch02_rain_foundry_canal", "demo_ch03_saltwhite_archive", "demo_ch04_broken_string_greenhouse", "demo_ch05_obsidian_pilgrim_road", "demo_ch06_silent_crown_core"]
const SAVE := "user://world_interaction_residency_validation.json"
const KEEP_PINNED_NPCS := ["npc_rain_smith_liu", "npc_threadsmith_apprentice", "npc_beeswax_vendor"]
const HALF := Vector2(1280.0, 900.0)
var scene: Node
var checks := 0
var failures: Array[String] = []
var region_metrics: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("INTERACTION RESIDENCY FAIL: " + label)

func tick(count: int = 1) -> void:
	for unused in count:
		await physics_frame
		await process_frame

func capture_review(filename: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path("res://../artifacts/active_residency")
	DirAccess.make_dir_recursive_absolute(directory)
	root.get_texture().get_image().save_jpg(directory.path_join(filename), 0.92)

func parse_region(id: String) -> Dictionary:
	var path := ROUTES.config_path(id)
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return ROUTES.apply_to(raw) if raw is Dictionary else {}

func expected_candidates(config: Dictionary) -> Dictionary:
	var excluded := {}
	var sellers: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/cartography_sellers.json"))
	if sellers is Dictionary:
		for seller in sellers.values():
			excluded[String(seller.get("npc_id", ""))] = true
	var result := {}
	for data in config.get("npcs", []):
		var id := String(data.get("id", ""))
		if id.is_empty() or excluded.has(id) or id in KEEP_PINNED_NPCS: continue
		var point := Vector2(float(data.position[0]), float(data.position[1]))
		if scene.world_narrative != null:
			var moved: Dictionary = scene.world_narrative.npc_world_state(id, scene.story_flags)
			if "demo_" + String(moved.get("region", "")) == String(config.get("id", "")) and moved.has("position"):
				point = Vector2(float(moved.position[0]), float(moved.position[1]))
		result["npc:" + id] = {"kind": "npc", "position": point}
	for data in config.get("save_points", []):
		result["save_point:" + String(data.get("id", ""))] = {"kind": "save_point", "position": Vector2(float(data.position[0]), float(data.position[1]))}
	for data in config.get("interactives", []):
		if String(data.get("kind", "")) == "lever":
			result["lever:" + String(data.get("id", ""))] = {"kind": "lever", "position": Vector2(float(data.position[0]), float(data.position[1]))}
	return result

func expected_window(focus: Vector2) -> Rect2:
	var viewport: Vector2 = scene.get_viewport_rect().size
	var zoom := Vector2.ONE
	var camera := scene.player.get_node_or_null("Camera2D") as Camera2D
	if camera != null: zoom = camera.zoom
	var half_view := Vector2(maxf(HALF.x, viewport.x / maxf(0.25, zoom.x) + 256.0), maxf(HALF.y, viewport.y / maxf(0.25, zoom.y) + 256.0))
	var base := Rect2(focus - HALF, HALF * 2.0)
	return base.merge(Rect2(focus - half_view, half_view * 2.0))

func settle_residency(focus: Vector2) -> void:
	var service: RefCounted = scene.world_gameplay_residency
	var player_physics: bool = scene.player.is_physics_processing()
	var world_focus: Vector2 = scene.to_global(focus)
	# The fixture moves the player/camera focus while keeping the real host
	# _process scheduler active; only player physics is paused to prevent falling
	# during an explicit off-map focus sample.
	scene.player.set_physics_process(false)
	scene.player.global_position = world_focus
	scene.player.velocity = Vector2.ZERO
	if is_instance_valid(scene.nearby_interactable) and scene.nearby_interactable.global_position.distance_to(world_focus) > 190.0:
		scene.nearby_interactable = null
	var deadline := Time.get_ticks_msec() + 10000
	await process_frame
	while Time.get_ticks_msec() < deadline:
		var state: Dictionary = service.snapshot()
		if state.pending_build == 0 and state.pending_release == 0 and bool(state.window_ready):
			scene.player.set_physics_process(player_physics)
			return
		await process_frame
	scene.player.set_physics_process(player_physics)
	var timeout_state: Dictionary = service.snapshot()
	print("RESIDENCY SETTLE TIMEOUT focus_local=" + str(focus) + " focus_global=" + str(world_focus) + " player=" + str(scene.player.global_position) + " checkpoint=" + str(scene.active_save_point_id) + " nearby=" + str(scene.nearby_interactable) + " overlay=" + str(scene.active_overlay) + " state=" + str(timeout_state))
	check(false, "fixture window settles before deadline")

func check_six_windows() -> void:
	for id in REGIONS:
		var config := parse_region(id)
		check(not config.is_empty(), id + " source configuration loads")
		var start := Vector2(float(config.player_start[0]), float(config.player_start[1]))
		scene._travel_world(ROUTES.config_path(id), start)
		await tick(3)
		var expected := expected_candidates(config)
		var focus: Vector2 = start
		var best_count := -1
		for candidate in expected.values():
			var candidate_focus: Vector2 = candidate.position
			var candidate_window := expected_window(candidate_focus)
			var count := 0
			for value in expected.values():
				if candidate_window.has_point(value.position): count += 1
			if count > best_count or (count == best_count and candidate_focus.distance_squared_to(start) < focus.distance_squared_to(start)):
				best_count = count
				focus = candidate_focus
		# This focus is selected independently from the residency service to give
		# each region a meaningful, explicitly positioned window fixture.
		var window := expected_window(focus)
		var keep_window := window.grow(1100.0)
		var expected_in_window: Array[String] = []
		for key in expected:
			if window.has_point(expected[key].position): expected_in_window.append(key)
		await settle_residency(focus)
		var service: RefCounted = scene.world_gameplay_residency
		var state: Dictionary = service.snapshot()
		var resident_keys: Array = service.resident.keys()
		var resident_in_window := 0
		for resident_key in resident_keys:
			if expected.has(resident_key) and window.has_point(expected[resident_key].position): resident_in_window += 1
		check(service.records.keys().size() == expected.size(), id + " candidate set equals independently derived config whitelist")
		for key in expected:
			check(service.records.has(key), id + " candidate registration " + key)
		check(int(state.window_eligible) == expected_in_window.size(), id + " independent window eligibility count")
		check(int(state.window_resident) == expected_in_window.size() and resident_in_window == expected_in_window.size(), id + " every current window interaction resident")
		for key in expected_in_window:
			var actor: Area2D = service.resident.get(key)
			check(actor != null and is_instance_valid(actor) and actor.is_inside_tree() and actor.get_parent() == scene, id + " window actor is genuinely tree resident " + key)
		for key in resident_keys:
			if expected.has(key) and key in expected_in_window: continue
			var is_pin: bool = key == "save_point:" + String(scene.active_save_point_id)
			var actor_value: Variant = service.resident.get(key)
			var actor: Area2D = actor_value as Area2D if is_instance_valid(actor_value) else null
			var near_player: bool = is_instance_valid(actor) and scene.player.global_position.distance_to(actor.global_position) <= 190.0
			var dialogue_held: bool = is_instance_valid(actor) and String(scene.active_overlay) == "dialogue" and scene.ui_shell.dialogue_area == actor
			var interaction_held: bool = is_instance_valid(actor) and scene.nearby_interactable == actor
			var in_keep_window: bool = service.records.has(key) and keep_window.has_point(service.records[key].position)
			check(is_pin or in_keep_window or near_player or dialogue_held or interaction_held, id + " distant resident is explained by keep-window/checkpoint/interaction hold " + String(key) + " actor_valid=" + str(is_instance_valid(actor_value)) + " actor=" + str(actor_value) + " parent=" + str(actor.get_parent() if is_instance_valid(actor) else null) + " actor_global=" + str(actor.global_position if is_instance_valid(actor) else Vector2.INF) + " record=" + str(service.records.get(key, {})) + " keep_contains=" + str(in_keep_window) + " player=" + str(scene.player.global_position) + " active_checkpoint=" + str(scene.active_save_point_id) + " nearby=" + str(scene.nearby_interactable) + " dialogue_area=" + str(scene.ui_shell.dialogue_area) + " pending_release=" + str(state.pending_release) + " generation=" + str(state.generation))
		region_metrics.append({"region": id, "candidates": expected.size(), "window_expected": expected_in_window.size(), "window_actual": str(state.window), "window_eligible_actual": state.window_eligible, "window_resident_actual": state.window_resident, "resident": resident_keys.size(), "active_tree_children": scene.get_child_count(), "service_generation": state.generation, "loader_generation": scene.world_loader.generation, "builds": state.builds, "releases": state.releases})

func actual_release_and_rebuild() -> void:
	var service: RefCounted = scene.world_gameplay_residency
	var id := String(scene.config.id)
	var candidates: Dictionary = expected_candidates(scene.config)
	var selected := ""
	for key in service.resident:
		if key.begins_with("save_point:") and key != "save_point:" + String(scene.active_save_point_id):
			selected = key
			break
	if selected.is_empty():
		for key in candidates:
			if key.begins_with("save_point:") and key != "save_point:" + String(scene.active_save_point_id):
				selected = key
				break
	check(not selected.is_empty(), "region has a non-checkpoint shrine suitable for a release probe")
	if selected.is_empty(): return
	var data: Dictionary = candidates[selected]
	await settle_residency(data.position)
	var actor: Area2D = service.resident.get(selected)
	var before_releases := int(service.snapshot().releases)
	var far := Vector2(data.position.x + 6000.0, data.position.y)
	await settle_residency(far)
	for unused in 4: await tick()
	check(not is_instance_valid(actor), "out-of-window owned node is actually freed")
	var after_release: Dictionary = service.snapshot()
	check(int(after_release.releases) > before_releases, "release metric increments for freed node; key=" + selected + " actor=" + str(actor) + " before_player=" + str(scene.player.global_position) + " after_player=" + str(far) + " overlay=" + str(scene.active_overlay) + " nearby=" + str(scene.nearby_interactable) + " snapshot=" + str(after_release))
	check(not service.resident.has(selected), "released actor no longer has active ownership")
	await settle_residency(data.position)
	var rebuilt: Area2D = service.resident.get(selected)
	check(is_instance_valid(rebuilt) and rebuilt.is_inside_tree(), "returning to window rebuilds a real interaction")
	check(rebuilt != actor, "rebuild does not claim detached cache reuse")
	if is_instance_valid(rebuilt): rebuilt.free() # external invalidation fixture for stale ownership cleanup
	await settle_residency(data.position)
	var recovered: Area2D = service.resident.get(selected)
	check(is_instance_valid(recovered) and recovered.is_inside_tree() and recovered != rebuilt, "service recovers after an owner externally frees a resident node")
	check(String(scene.config.id) == id, "focus-window fixture stays in the same active region")

func verify_npc_cursor_transfer() -> void:
	var service: RefCounted = scene.world_gameplay_residency
	var candidates: Dictionary = expected_candidates(scene.config)
	var key := ""
	var npc_point := Vector2.ZERO
	for candidate_key in candidates:
		if candidate_key.begins_with("npc:"):
			key = String(candidate_key)
			npc_point = candidates[key].position
			break
	if not key.is_empty(): await settle_residency(npc_point)
	var npc: Area2D = service.resident.get(key)
	check(is_instance_valid(npc), "ordinary story NPC enters window")
	if not is_instance_valid(npc): return
	var before_indices: Dictionary = npc.get_meta("dialogue_state_indices", {}).duplicate(true)
	var npc_position: Vector2 = npc.position
	scene._close_overlays()
	scene.player.global_position = npc.global_position
	scene.player.velocity = Vector2.ZERO
	await tick(3)
	await capture_review("ch01_npc_window.jpg")
	var dialogue_before := int(npc.get_meta("dialogue_index", 0))
	scene.nearby_interactable = null
	scene.player.set_physics_process(false)
	scene.player.global_position = npc.global_position
	await tick(2)
	Input.action_press("interact")
	await tick(2)
	Input.action_release("interact")
	await tick(2)
	scene.player.set_physics_process(true)
	check(scene.active_overlay == "dialogue" and int(npc.get_meta("dialogue_index", 0)) == dialogue_before + 1, "live interact input opens the resident story NPC; npc=" + npc.name + " distance=" + str(scene.player.global_position.distance_to(npc.global_position)) + " nearby=" + str(scene.nearby_interactable) + " overlay=" + str(scene.active_overlay) + " input_action=" + str(InputMap.has_action("interact")))
	# Advance the real world dialogue through its normal commit path. The
	# legacy cursor increments on display; the state cursor increments only
	# when the displayed line is committed after reveal/advance.
	var dialogue_state := String(npc.get_meta("dialogue_state", "repeat"))
	if scene.active_overlay == "dialogue":
		Input.action_press("interact")
		await tick(2)
		Input.action_release("interact")
		await tick(2)
		Input.action_press("interact")
		await tick(2)
		Input.action_release("interact")
		await tick(2)
	var expected_indices: Dictionary = npc.get_meta("dialogue_state_indices", {}).duplicate(true)
	check(int(expected_indices.get(dialogue_state, 0)) == int(before_indices.get(dialogue_state, 0)) + 1, "actual dialogue advance commits one state-specific cursor " + dialogue_state + " before=" + str(before_indices) + " after=" + str(expected_indices))
	if scene.active_overlay == "dialogue": scene._close_overlays()
	var expected_dialogue_index := int(npc.get_meta("dialogue_index", 0))
	var old_id := npc.get_instance_id()
	await settle_residency(npc_position + Vector2(6000, 0))
	check(not is_instance_valid(npc), "NPC outside keep window is freed after state transfer")
	await settle_residency(npc_position)
	var restored: Area2D = service.resident.get(key)
	check(is_instance_valid(restored) and restored.get_instance_id() != old_id, "NPC is reconstructed after return")
	if is_instance_valid(restored):
		check(int(restored.get_meta("dialogue_index", -1)) == expected_dialogue_index, "legacy dialogue cursor survives local release/rebuild")
		check(restored.get_meta("dialogue_state_indices", {}) == expected_indices, "state-specific dialogue cursor survives local release/rebuild")

func verify_dialogue_hold_and_checkpoint_pin() -> void:
	var service: RefCounted = scene.world_gameplay_residency
	var candidates: Dictionary = expected_candidates(scene.config)
	var npc_key := ""
	var npc_position := Vector2.ZERO
	for candidate_key in candidates:
		if candidate_key.begins_with("npc:"):
			npc_key = String(candidate_key)
			npc_position = candidates[npc_key].position
			break
	var npc: Area2D = service.resident.get(npc_key)
	if not is_instance_valid(npc):
		await settle_residency(npc_position)
		npc = service.resident.get(npc_key)
	check(is_instance_valid(npc), "dialogue-hold NPC is resident before opening conversation")
	if is_instance_valid(npc):
		var prior_releases := int(service.snapshot().releases)
		scene.active_overlay = "dialogue"
		scene.ui_shell.dialogue_area = npc
		await settle_residency(npc.position + Vector2(6500, 0))
		check(is_instance_valid(npc) and npc.is_inside_tree() and service.resident.get(npc_key) == npc, "active dialogue actor stays owned while window leaves")
		check(int(service.snapshot().releases) == prior_releases, "held dialogue actor is not counted as a release")
		scene.active_overlay = ""
		scene.ui_shell.dialogue_area = null
		await settle_residency(npc.position + Vector2(6500, 0))
		check(not is_instance_valid(npc) and not service.resident.has(npc_key), "dialogue actor releases after its overlay closes")
		await settle_residency(Vector2(900, 3000))

	var all_candidates := expected_candidates(scene.config)
	var shrine_key := ""
	for key in all_candidates:
		if key.begins_with("save_point:") and key != "save_point:" + String(scene.active_save_point_id):
			shrine_key = key
			break
	check(not shrine_key.is_empty(), "separate shrine exists for checkpoint-pin fixture")
	if not shrine_key.is_empty():
		var shrine_data: Dictionary = all_candidates[shrine_key]
		var shrine_position: Vector2 = shrine_data.position
		var original_checkpoint: String = scene.active_save_point_id
		var original_spawn: Vector2 = scene.active_spawn
		var far := shrine_position + Vector2(6000, 0)
		await settle_residency(far)
		check(not service.resident.has(shrine_key), "non-active shrine can leave residency before pin test")
		scene.active_save_point_id = String(shrine_key.get_slice(":", 1))
		scene.active_spawn = shrine_position
		var should_defer: bool = service.should_defer("save_point", {"id": scene.active_save_point_id, "position": [shrine_position.x, shrine_position.y]}, scene)
		check(not should_defer, "active checkpoint is pinned even before its node exists")
		if not should_defer:
			scene._save_point({"id": scene.active_save_point_id, "position": [shrine_position.x, shrine_position.y], "label": "Save Point"})
			var pinned: Area2D = scene.get_node_or_null(NodePath(scene.active_save_point_id))
			check(is_instance_valid(pinned) and pinned.is_inside_tree(), "active checkpoint is constructed despite remote focus")
		scene.active_save_point_id = original_checkpoint
		scene.active_spawn = original_spawn
		await settle_residency(Vector2(900, 3000))

func verify_generation_and_migration() -> void:
	var service: RefCounted = scene.world_gameplay_residency
	check(int(service.snapshot().generation) == int(scene.world_loader.generation), "active residency follows registered world generation")
	var moved_id := "npc_root_prisoner"
	var moved_key := "npc:" + moved_id
	var config := parse_region("demo_ch04_broken_string_greenhouse")
	var original: Dictionary = {}
	for npc_data in config.get("npcs", []):
		if String(npc_data.get("id", "")) == moved_id: original = npc_data
	check(not original.is_empty(), "migration fixture NPC is authored in its source chapter")
	if original.is_empty(): return
	var original_position := Vector2(float(original.position[0]), float(original.position[1]))
	var flags_before: Dictionary = scene.story_flags.duplicate(true)
	var moved_flag := "npc_root_prisoner_at_west_gate"
	scene._travel_world(ROUTES.config_path("demo_ch04_broken_string_greenhouse"), original_position)
	await tick(3)
	scene.story_flags.erase(moved_flag)
	var active_service: RefCounted = scene.world_gameplay_residency
	var before_record: Dictionary = active_service.records.get(moved_key, {})
	check(before_record.has("position") and before_record.position == original_position, "migrant begins at authored pre-migration position")
	scene._set_story_flag(moved_flag)
	var migrant_before_move: Area2D = active_service.resident.get(moved_key)
	if is_instance_valid(migrant_before_move): scene._apply_world_npc_state(migrant_before_move)
	var destination := Vector2(320, 1740)
	await settle_residency(destination)
	var after_record: Dictionary = active_service.records.get(moved_key, {})
	check(after_record.has("position") and after_record.position == destination, "story flag refreshes NPC residency position from narrative authority")
	var migrant: Area2D = active_service.resident.get(moved_key)
	check(is_instance_valid(migrant) and migrant.position == destination, "migrated NPC is rebuilt at destination")
	scene.story_flags = flags_before

func verify_lever_state() -> void:
	var data: Dictionary = {}
	for item in scene.config.get("interactives", []):
		if String(item.get("kind", "")) == "lever": data = item
	check(not data.is_empty(), "chapter has authored shortcut lever")
	if data.is_empty(): return
	var id := String(data.get("id", ""))
	var shortcut := String(data.get("shortcut_id", ""))
	var key := "lever:" + id
	var point := Vector2(float(data.position[0]), float(data.position[1]))
	await settle_residency(point)
	var lever: Area2D = scene.world_gameplay_residency.resident.get(key)
	check(is_instance_valid(lever), "lever becomes resident in its interaction window")
	if not is_instance_valid(lever): return
	var before_currency := int(scene.currency_count)
	var before_bells := int(scene.bell_count)
	# Exercise the real lever action so both regional shortcut state and the
	# MetSys stored marker follow their production writers.
	scene.player.global_position = lever.global_position
	scene._activate_lever(lever)
	check(scene._is_shortcut_open(shortcut), "normal lever action opens the permanent shortcut")
	check(bool(scene.opened_shortcuts.get(shortcut, false)), "shortcut is owned by persistent regional progression")
	var object_id := String(lever.get_meta("object_id", ""))
	var stored_key := StringName(object_id)
	var stored_before: bool = scene.metsys_bridge != null and scene.metsys_bridge.metsys.save_data.stored_objects.get(stored_key, false)
	check(stored_before, "opened lever keeps its registered MetSys stored marker")
	var opened_sprite: Sprite2D = lever.get_node_or_null("LeverSprite")
	var opened_pixels: PackedByteArray = opened_sprite.texture.get_image().get_data() if opened_sprite != null and opened_sprite.texture != null else PackedByteArray()
	check(not opened_pixels.is_empty(), "opened lever retains original authored artwork")
	await settle_residency(point + Vector2(6000, 0))
	var release_state: Dictionary = scene.world_gameplay_residency.snapshot()
	check(not is_instance_valid(lever), "opened lever is genuinely freed outside the keep window; player=" + str(scene.player.global_position) + " lever=" + str(lever) + " record=" + str(scene.world_gameplay_residency.records.get(key, {})) + " nearby=" + str(scene.nearby_interactable) + " dialogue_area=" + str(scene.ui_shell.dialogue_area) + " pending_release=" + str(release_state.pending_release) + " releases=" + str(release_state.releases) + " generation=" + str(release_state.generation) + " snapshot=" + str(release_state))
	await settle_residency(point)
	var rebuilt: Area2D = scene.world_gameplay_residency.resident.get(key)
	check(scene.metsys_bridge != null and scene.metsys_bridge.metsys.save_data.stored_objects.get(stored_key, false), "rebuilt lever remains on the same MetSys marker")
	check(scene.get_node_or_null(NodePath(id)) == rebuilt, "only one active actor owns the rebuilt lever id")
	var rebuilt_sprite: Sprite2D = rebuilt.get_node_or_null("LeverSprite") if is_instance_valid(rebuilt) else null
	var rebuilt_pixels: PackedByteArray = rebuilt_sprite.texture.get_image().get_data() if rebuilt_sprite != null and rebuilt_sprite.texture != null else PackedByteArray()
	check(is_instance_valid(rebuilt) and rebuilt_pixels == opened_pixels, "reconstructed lever preserves open-art contract")
	var reward_currency := int(scene.currency_count)
	if is_instance_valid(rebuilt): scene._activate_lever(rebuilt)
	check(scene._is_shortcut_open(shortcut) and int(scene.currency_count) == reward_currency and int(scene.bell_count) == before_bells and reward_currency >= before_currency, "repeated activation never relocks or grants duplicate currency/route marks")
	var persisted := STATE.new()
	check(persisted.read(SAVE) and bool(persisted.get_region(String(scene.config.id)).get("opened_shortcuts", {}).get(shortcut, false)), "permanent lever state survives a disk read")

func verify_restart_checkpoint() -> void:
	var shrines: Array = scene.config.get("save_points", [])
	var first: Dictionary = {}
	var second: Dictionary = {}
	for entry in shrines:
		if String(entry.get("id", "")) == String(scene.active_save_point_id): continue
		if first.is_empty(): first = entry
		elif second.is_empty(): second = entry
	check(not first.is_empty() and not second.is_empty(), "two non-current shrines available for activation-state fixture")
	if first.is_empty() or second.is_empty(): return
	var first_id := String(first.id)
	var first_point := Vector2(float(first.position[0]), float(first.position[1]))
	var first_key := "save_point:" + first_id
	await settle_residency(first_point)
	var first_shrine: Area2D = scene.world_gameplay_residency.resident.get(first_key)
	check(is_instance_valid(first_shrine), "first shrine is resident before rest interaction")
	if not is_instance_valid(first_shrine): return
	scene.player.global_position = first_point
	scene.player.hp = maxi(1, scene.player.hp - 1)
	scene._activate_save_point(first_shrine)
	check(bool(first_shrine.get_meta("activated", false)), "first rest marks shrine activated")
	var first_art: Color = (first_shrine.get_node("SavePointSprite") as Sprite2D).modulate
	var second_id := String(second.id)
	var second_point := Vector2(float(second.position[0]), float(second.position[1]))
	await settle_residency(second_point)
	var second_shrine: Area2D = scene.world_gameplay_residency.resident.get("save_point:" + second_id)
	check(is_instance_valid(second_shrine), "second shrine is resident before moving checkpoint")
	if not is_instance_valid(second_shrine): return
	scene.player.global_position = second_point
	scene._activate_save_point(second_shrine)
	await settle_residency(first_point + Vector2(6200, 0))
	check(not is_instance_valid(first_shrine), "previously activated non-checkpoint shrine is genuinely released")
	await settle_residency(first_point)
	# The service can expose a stale weak Object reference when a prior build
	# was invalidated during a window transition. Validate it before typed cast;
	# the following assertion still fails if the shrine was not rebuilt.
	var rebuilt_first_value: Variant = scene.world_gameplay_residency.resident.get(first_key)
	var rebuilt_first: Area2D = rebuilt_first_value as Area2D if is_instance_valid(rebuilt_first_value) else null
	check(is_instance_valid(rebuilt_first) and bool(rebuilt_first.get_meta("activated", false)), "non-current shrine activation survives release/rebuild")
	if is_instance_valid(rebuilt_first):
		var rebuilt_art: Color = (rebuilt_first.get_node("SavePointSprite") as Sprite2D).modulate
		check(rebuilt_art == first_art, "reconstructed shrine preserves its activated visual state")

	# The second rest is now the authoritative restart checkpoint.
	var data: Dictionary = second
	var point := second_point
	var shrine_id := second_id
	var saved := STATE.new()
	check(saved.read(SAVE) and String(saved.get_region(String(scene.config.id)).get("checkpoint_id", "")) == shrine_id, "rest interaction commits checkpoint to save")
	var world_location: Variant = saved.data.get("world_location", {})
	check(world_location is Dictionary and String(world_location.get("region_id", "")) == String(scene.config.id) and world_location.get("position", []) is Array and world_location.position.size() == 2, "rest interaction commits canonical world checkpoint")
	scene.free()
	current_scene = null
	await tick(2)
	scene = load("res://scenes/World.tscn").instantiate()
	scene.world_resume = true
	scene.world_save_path = SAVE
	root.add_child(scene)
	await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
	current_scene = scene
	await tick(5)
	check(String(scene.config.get("id", "")) == String(saved.data.current_region), "restart restores the checkpoint region")
	check(String(scene.active_save_point_id) == shrine_id and scene.active_spawn == point, "restart restores the exact shrine checkpoint")
	var restored: Area2D = scene.world_gameplay_residency.resident.get("save_point:" + shrine_id)
	check(is_instance_valid(restored) and bool(restored.get_meta("activated", false)), "checkpoint shrine returns with activated art state")

func run() -> void:
	for suffix in ["", ".tmp", ".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	scene = load("res://scenes/World.tscn").instantiate()
	scene.world_resume = false
	scene.world_save_path = SAVE
	root.add_child(scene)
	await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
	current_scene = scene
	await tick(4)
	await check_six_windows()
	# Region 1 position is an explicit fixture for NPC/dialogue and release tests.
	var source := "demo_ch01_moss_bell_court"
	var config := parse_region(source)
	var fixture := Vector2(float(config.player_start[0]), float(config.player_start[1]))
	scene._travel_world(ROUTES.config_path(source), fixture)
	var arrival_state: Dictionary = scene.world_gameplay_residency.snapshot()
	check(arrival_state.pending_build == 0, "critical arrival window is complete before interactive publication")
	await tick(3)
	await settle_residency(fixture)
	await actual_release_and_rebuild()
	await verify_npc_cursor_transfer()
	await verify_dialogue_hold_and_checkpoint_pin()
	await verify_lever_state()
	await verify_generation_and_migration()
	await verify_restart_checkpoint()
	print("ACTIVE INTERACTION RESIDENCY METRICS ", JSON.stringify(region_metrics))
	print("ACTIVE INTERACTION RESIDENCY SNAPSHOT ", JSON.stringify(scene.world_gameplay_residency.snapshot()))
	scene.free()
	current_scene = null
	await tick(2)
	check(not is_instance_valid(scene), "world teardown frees its active interaction nodes")
	for suffix in ["", ".tmp", ".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	if failures.is_empty():
		print("WORLD INTERACTION RESIDENCY PASS: %d checks" % checks)
		quit(0)
	else:
		print("WORLD INTERACTION RESIDENCY FAILURES: %d / %d" % [failures.size(), checks])
		quit(1)
