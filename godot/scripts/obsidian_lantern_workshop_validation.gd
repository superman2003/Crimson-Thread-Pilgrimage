extends RefCounted
## Exercises the CH05 phase workshop with the production World, Player and
## collision surfaces. Portal entry and the newly acquired lantern ability are
## positioned fixtures; the gate action, tier climb and rewards use real input.
const AUDIO := preload("res://scripts/audio_retirement.gd")
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
	_release()
	_check(_numbers_match([1.0, 2.0], [1, 2]), "Numeric contracts accept JSON float representation")
	_check(not _numbers_match([1, 3], [1, 2]), "Numeric contracts reject a changed coordinate")
	_check(not _numbers_match([1], [1, 2]), "Numeric contracts reject missing coordinates")
	_check(not _numbers_match(["1", 2], [1, 2]), "Numeric contracts reject nonnumeric values")
	_check(not _numbers_match([NAN], [0]), "Numeric contracts reject nonfinite coordinates")
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
	_check(not scene.player.double_jump_unlocked and not scene.player.wall_grip_unlocked, "Workshop route has no double jump or wall-climb assistance")
	_check(not scene.player.debug_invulnerable, "Workshop keeps normal damage enabled")
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

	var target := Vector2(7672, 570)
	_check(await _walk_to(target, false), "Player walks to the phase latch approach")
	_set_axis(1.0)
	await _tick(tree, 24)
	_release()
	_check(scene.player.global_position.x < 7704 and scene.locked_gate_bodies.has(ROOM + "_action_gate"), "Closed phase latch physically blocks forward movement")
	var currency_before: int = scene.currency_count
	var record_before: int = scene.inventory_counts.get(ROOM + "_record", 0)
	scene.player.energy = scene.player.max_energy
	var energy_before: int = scene.player.energy
	await _pulse("lantern_phase", 12)
	await _tick(tree, 35)
	_check(not scene.locked_gate_bodies.has(ROOM + "_action_gate"), "Real lantern-phase input opens the lower latch")
	_check(scene.player.energy < energy_before, "Real phase operation spends player energy")
	_check(scene.story_flags.get("action_gate_" + ROOM + "_action_gate", false), "Phase latch records its permanent action unlock")
	if scene.locked_gate_bodies.has(ROOM + "_action_gate"):
		await _dispose(tree)
		return

	_check(await _walk_to(Vector2(7800, 490)), "Player climbs the lower service platform with collision")
	_check(await _walk_to(Vector2(7890, 380)), "Player climbs the upper lantern gallery with collision")
	_check(await _walk_to(Vector2(7954, 380), false), "Player crosses the gallery to the second cache")
	await _tick(tree, 8)
	var evidence := ROOM + "_evidence"
	var resin := ROOM + "_resin"
	_check(scene.world_collected_ids.has(evidence), "Upper gallery awards the unique maintenance record")
	_check(scene.world_collected_ids.has(resin), "Upper gallery awards the resin cache")
	_check(scene.currency_count == currency_before + 70, "Workshop cache grants exactly its authored 70 currency")
	_check(scene.inventory_counts.get(ROOM + "_record", 0) == record_before + 1, "Workshop grants exactly one maintenance record")
	var room: Dictionary = _find_room()
	_check(_numbers_match(room.get("layout_rect", []), [7390, 220, 664, 470]), "Workshop keeps its original physical room rectangle")
	_check(_numbers_match(room.get("map_rect", []), [2920, 0, 236, 168]), "Workshop keeps its original atlas map rectangle")
	var guide := String(room.get("guide", ""))
	_check(guide.contains("低台") and guide.contains("高台"), "Room guidance describes both platform tiers")
	var entry_data := ROUTES.portal(REGION, ROOM + "_access_a")
	var exit_data := ROUTES.portal(REGION, ROOM + "_access_b")
	_check(_numbers_match(entry_data.get("position", []), [240, 1870]) and _numbers_match(entry_data.get("target_spawn", []), [7500, 530]), "Workshop entry keeps its camp-to-room boundary contract")
	_check(_numbers_match(exit_data.get("position", []), [7500, 530]) and _numbers_match(exit_data.get("target_spawn", []), [240, 1870]), "Workshop exit keeps its room-to-camp boundary contract")

	_check(await _walk_to(Vector2(7500, 570), false), "Player can drop from the gallery and return to the foyer")
	var exit_portal: Node = scene.get_node_or_null("upgrade_lantern_phase_3_access_b")
	_check(exit_portal is Area2D, "Workshop retains its supported return portal")
	if exit_portal is Area2D:
		await _pulse("interact", 1)
		await _settle_transition(tree)
		_check(scene.player.global_position.distance_to(Vector2(240, 1870)) < 85, "Workshop exits to the original pilgrim-camp platform")
		_check(scene.world_collected_ids.has(evidence) and scene.world_collected_ids.has(resin), "Collected optional rewards persist after returning")
	else:
		_check(false, "Workshop missing its supported return portal node")
	_check(scene.currency_count == currency_before + 70, "Two tier rewards remain optional but collectible")
	# Revisit through the production interact action, never collect by direct API.
	await _pulse("interact", 1)
	await _settle_transition(tree)
	_check(scene.player.global_position.distance_to(Vector2(7500, 530)) < 85, "Interact input revisits the optional workshop from camp")
	_check(not scene.locked_gate_bodies.has(ROOM + "_action_gate"), "Revisited workshop keeps the phase latch open")
	_check(scene.get_node_or_null(evidence) == null and scene.get_node_or_null(resin) == null, "Collected gallery rewards do not respawn on revisit")
	_check(scene.inventory_counts.get(ROOM + "_record", 0) == record_before + 1 and scene.currency_count == currency_before + 70, "Revisit cannot duplicate the record or currency")
	_check(await _walk_to(Vector2(7500, 570), false), "Revisited foyer retains its physical exit landing")
	await _pulse("interact", 1)
	await _settle_transition(tree)
	_check(scene.player.global_position.distance_to(Vector2(240, 1870)) < 85, "Interact input exits the revisited workshop back to camp")
	await _dispose(tree)

func _find_room() -> Dictionary:
	for value in scene.config.get("map_rooms", []):
		if value is Dictionary and String(value.get("id", "")) == ROOM:
			return value
	return {}

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

# Shared by the all-workshop regression, which keeps its own reward/save checks.
func walk_to_landing(world: Node, tree: SceneTree, target: Vector2) -> bool:
	scene = world
	tree_ref = tree
	return await _walk_to(target)

func _walk_to(target: Vector2, allow_jump: bool = true) -> bool:
	_release()
	# A release and a new press in the same tick exposes both edges to Player;
	# jump-cut would otherwise shorten the next jump. Give release its own ticks.
	await _tick(tree_ref, 2)
	var jump_hold := 0
	var jump_rearm := 0
	for frame in range(420):
		var player: CharacterBody2D = scene.player
		var dx := target.x - player.global_position.x
		var rise := player.global_position.y - target.y
		if absf(dx) < 15 and absf(rise) < 4 and player.is_on_floor():
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
		elif player.is_on_floor() and allow_jump:
			var ahead := player.global_position + Vector2(signf(dx) * 52, -3)
			var query := PhysicsRayQueryParameters2D.create(ahead, ahead + Vector2(0, 90), 1, [player.get_rid()])
			var gap := player.get_world_2d().direct_space_state.intersect_ray(query).is_empty()
			if (rise > 24 and absf(dx) < 170) or (gap and absf(dx) > 50) or (player.is_on_wall() and absf(dx) > 30):
				Input.action_press("jump")
				jump_hold = 42
		await _tick(tree_ref, 1)
	_release()
	return false

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
		AUDIO.retire_tree(scene)
		scene.queue_free()
		await tree.process_frame
	_check(await AUDIO.drain(tree), "Workshop releases audio playback before teardown")
	_clean_save()

func _clean_save() -> void:
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))

func _numbers_match(value: Variant, expected: Array) -> bool:
	if not value is Array or value.size() != expected.size():return false
	for index in expected.size():
		if not (value[index] is int or value[index] is float):return false
		if not is_finite(float(value[index])) or float(value[index]) != float(expected[index]):return false
	return true
