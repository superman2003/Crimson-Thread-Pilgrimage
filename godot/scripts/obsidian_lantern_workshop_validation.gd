extends RefCounted
## Exercises the CH05 phase workshop with the production World, Player and
## collision surfaces. Portal entry and the newly acquired lantern ability are
## positioned fixtures; the gate action, tier climb and rewards use real input.
const ROUTES := preload("res://scripts/world_routes.gd")
const SAVE := "user://obsidian_lantern_workshop_validation.json"
const WORLD := "res://scenes/World.tscn"
const REGION := "demo_ch05_obsidian_pilgrim_road"
const ROOM := "upgrade_lantern_phase_3"
var scene: Node
var checker: Callable
var tree_ref: SceneTree

func run(tree: SceneTree, check_callback: Callable) -> void:
	checker = check_callback
	tree_ref = tree
	_clean_save()
	scene = load(WORLD).instantiate()
	scene.config_path = ROUTES.config_path(REGION)
	scene.world_resume = false
	scene.world_save_path = SAVE
	scene.entry_spawn_override_enabled = true
	scene.entry_spawn_override = Vector2(240, 1870)
	tree.root.add_child(scene)
	await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
	tree.current_scene = scene
	await _tick(tree, 8)
	_check(String(scene.config.get("id", "")) == REGION, "Workshop fixture loads the production CH05 region")
	if String(scene.config.get("id", "")) != REGION:
		await _dispose(tree)
		return

	# Practice assumes only the newly obtained lantern ability. Each tier is
	# within one normal jump, so the route must not depend on double jump.
	scene._add_inventory_item("lantern_phase", 1, false)
	scene._sync_player_abilities()
	var entrance: Node = scene.get_node_or_null("upgrade_lantern_phase_3_access_a")
	_check(entrance is Area2D, "Workshop has its authored paired entry portal")
	if not entrance is Area2D:
		await _dispose(tree)
		return
	scene._activate_world_portal(entrance)
	await _settle_transition(tree)
	_check(String(scene.config.get("id", "")) == REGION, "Paired workshop portal keeps the CH05 region loaded")
	_check(scene.player.global_position.distance_to(Vector2(7500, 530)) < 85, "Paired portal arrives at the workshop foyer")
	_check(scene.locked_gate_bodies.has(ROOM + "_action_gate"), "Phase latch remains physically closed before use")

	var target := Vector2(7672, 528)
	_check(await _walk_to(target), "Player walks to the phase latch approach")
	var currency_before: int = scene.currency_count
	scene.player.energy = scene.player.max_energy
	await _pulse("lantern_phase", 12)
	await _tick(tree, 35)
	_check(not scene.locked_gate_bodies.has(ROOM + "_action_gate"), "Real lantern-phase input opens the lower latch")
	if scene.locked_gate_bodies.has(ROOM + "_action_gate"):
		await _dispose(tree)
		return

	var reached_lower := await _walk_to(Vector2(7800, 490))
	_check(reached_lower, "Player climbs the lower service platform with collision actual=" + _player_state())
	# The upper gallery starts to the right of the lower step. Jumping straight
	# up at x=7800 hits the solid upper step's underside, so return to the left
	# side of the lower landing before making the real, single jump.
	var back_at_lower_takeoff := await _walk_to(Vector2(7758, 490))
	_check(back_at_lower_takeoff, "Player returns to the lower-step jump approach actual=" + _player_state())
	var reached_upper := await _walk_to(Vector2(7890, 380))
	_check(reached_upper, "Player climbs the upper lantern gallery with collision actual=" + _player_state())
	var crossed_gallery := await _walk_to(Vector2(7954, 380))
	_check(crossed_gallery, "Player crosses the gallery to the second cache actual=" + _player_state())
	await _tick(tree, 8)
	var evidence := ROOM + "_evidence"
	var resin := ROOM + "_resin"
	_check(scene.world_collected_ids.has(evidence), "Upper gallery awards the unique maintenance record collected=" + str(scene.world_collected_ids))
	_check(scene.world_collected_ids.has(resin), "Upper gallery awards the resin cache collected=" + str(scene.world_collected_ids))
	_check(scene.currency_count > currency_before, "Workshop cache grants spendable currency before=%d actual=%d" % [currency_before, scene.currency_count])
	var room: Dictionary = _find_room()
	_check(_same_coords(room.get("layout_rect"), [7390, 220, 664, 470]), "Workshop keeps its original physical room rectangle actual=" + str(room.get("layout_rect", "<missing>")) + " type=" + type_string(typeof(room.get("layout_rect", null))))
	_check(_same_coords(room.get("map_rect"), [2920, 0, 236, 168]), "Workshop keeps its original atlas map rectangle actual=" + str(room.get("map_rect", "<missing>")) + " type=" + type_string(typeof(room.get("map_rect", null))))
	var guide := String(room.get("guide", ""))
	_check(guide.contains("低台") and guide.contains("高台"), "Room guidance describes both platform tiers")
	var entry_data := ROUTES.portal(REGION, ROOM + "_access_a")
	var exit_data := ROUTES.portal(REGION, ROOM + "_access_b")
	_check(_same_coords(entry_data.get("position"), [240, 1870]) and _same_coords(entry_data.get("target_spawn"), [7500, 530]), "Workshop entry keeps its camp-to-room boundary contract actual=" + str(entry_data))
	_check(_same_coords(exit_data.get("position"), [7500, 530]) and _same_coords(exit_data.get("target_spawn"), [240, 1870]), "Workshop exit keeps its room-to-camp boundary contract actual=" + str(exit_data))

	_check(await _walk_to(Vector2(7500, 530)), "Player can drop from the gallery and return to the foyer")
	var exit_portal: Node = scene.get_node_or_null("upgrade_lantern_phase_3_access_b")
	_check(exit_portal is Area2D, "Workshop retains its supported return portal")
	if exit_portal is Area2D:
		scene._activate_world_portal(exit_portal)
		await _settle_transition(tree)
		_check(scene.player.global_position.distance_to(Vector2(240, 1870)) < 85, "Workshop exits to the original pilgrim-camp platform")
		_check(scene.world_collected_ids.has(evidence) and scene.world_collected_ids.has(resin), "Collected optional rewards persist after returning actual=" + str(scene.world_collected_ids))
	else:
		_check(false, "Workshop missing its supported return portal node")
	_check(scene.currency_count >= currency_before + 65, "Two tier rewards remain optional but collectible before=%d actual=%d" % [currency_before, scene.currency_count])
	await _dispose(tree)

func _find_room() -> Dictionary:
	for value in scene.config.get("map_rooms", []):
		if value is Dictionary and String(value.get("id", "")) == ROOM:
			return value
	return {}

func _same_coords(actual: Variant, expected: Array) -> bool:
	if not actual is Array or actual.size() != expected.size():
		return false
	for index in expected.size():
		if typeof(actual[index]) not in [TYPE_INT, TYPE_FLOAT]:
			return false
		if not is_equal_approx(float(actual[index]), float(expected[index])):
			return false
	return true

func _settle_transition(tree: SceneTree) -> void:
	for unused in range(1600):
		if is_instance_valid(tree.current_scene) and tree.current_scene.get("world_mode") == true:
			scene = tree.current_scene
		var loader: Variant = scene.world_loader
		if not scene.world_portal_request_pending and not scene.chapter_transitioning and not scene.world_loading and (not is_instance_valid(loader) or loader.phase == "idle"):
			await _tick(tree, 10)
			return
		await tree.process_frame
	_check(false, "Workshop portal transition settles within its bounded budget")

func _walk_to(target: Vector2) -> bool:
	_release()
	var jump_hold := 0
	var jump_rearm := 0
	for frame in range(420):
		var player: CharacterBody2D = scene.player
		var dx := target.x - player.global_position.x
		var rise := player.global_position.y - target.y
		if absf(dx) < 15 and absf(rise) < 45 and player.is_on_floor():
			_release()
			return true
		_set_axis(signf(dx) if absf(dx) > 7 else 0.0)
		if jump_hold > 0:
			jump_hold -= 1
			if jump_hold == 0:
				Input.action_release("jump")
				jump_rearm = 4
		elif jump_rearm > 0:
			jump_rearm -= 1
		elif player.is_on_floor():
			var ahead := player.global_position + Vector2(signf(dx) * 52, -3)
			var query := PhysicsRayQueryParameters2D.create(ahead, ahead + Vector2(0, 90), 1, [player.get_rid()])
			var gap := player.get_world_2d().direct_space_state.intersect_ray(query).is_empty()
			if (rise > 24 and absf(dx) < 170) or (gap and absf(dx) > 50) or (player.is_on_wall() and absf(dx) > 30):
				Input.action_press("jump")
				jump_hold = 42
		elif player.double_jump_unlocked and rise > 50 and player.velocity.y > -100 and player.air_jump_available and jump_hold == 0 and jump_rearm == 0:
			Input.action_press("jump")
			jump_hold = 32
		await _tick(tree_ref, 1)
	_release()
	push_warning("Lantern workshop walk timed out target=" + str(target) + " actual=" + _player_state())
	return false

func _player_state() -> String:
	if not is_instance_valid(scene) or not is_instance_valid(scene.player):
		return "<missing player>"
	var player: CharacterBody2D = scene.player
	return "pos=%s velocity=%s floor=%s wall=%s room=%s collected=%s currency=%s" % [
		str(player.global_position), str(player.velocity), str(player.is_on_floor()), str(player.is_on_wall()),
		str(scene.config.get("id", "<unknown>")), str(scene.world_collected_ids), str(scene.currency_count)]

func _pulse(action: String, count: int) -> void:
	Input.action_press(action)
	await _tick(tree_ref, count)
	Input.action_release(action)
	await _tick(tree_ref, 3)

func _tick(tree: SceneTree, count: int) -> void:
	for unused in range(count):
		await tree.physics_frame
		await tree.process_frame

func _set_axis(direction: float) -> void:
	if direction > 0:
		Input.action_release("move_left")
		Input.action_press("move_right")
	elif direction < 0:
		Input.action_release("move_right")
		Input.action_press("move_left")
	else:
		Input.action_release("move_left")
		Input.action_release("move_right")

func _release() -> void:
	for action in ["move_left", "move_right", "jump", "lantern_phase", "interact"]:
		if InputMap.has_action(action):
			Input.action_release(action)

func _check(ok: bool, label: String) -> void:
	checker.call(ok, label)

func _dispose(tree: SceneTree) -> void:
	_release()
	if is_instance_valid(scene):
		scene.queue_free()
		await tree.process_frame
	_clean_save()

func _clean_save() -> void:
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
