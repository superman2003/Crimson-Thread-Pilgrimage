extends SceneTree
## Production World camera, action seal, reward and return smoke test for CH06.
## Positioning at authored portals is a fixture; door and ability inputs use the
## real World, Player, physics bodies and save state.
const ROUTES := preload("res://scripts/world_routes.gd")
const SAVE := "user://ch06_workshop_experience.json"
var world: Node
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func frames(count: int = 3) -> void:
	for i in count:
		await physics_frame
		await process_frame

func release_inputs() -> void:
	for action in ["move_left", "move_right", "jump", "dash", "crown_resonance", "interact"]:
		if InputMap.has_action(action): Input.action_release(action)

func walk_x(target: float) -> bool:
	for i in 180:
		var delta: float = target - world.player.position.x
		if absf(delta) < 10.0:
			release_inputs()
			await frames(2)
			return true
		if delta > 0.0:
			Input.action_release("move_left")
			Input.action_press("move_right")
		else:
			Input.action_release("move_right")
			Input.action_press("move_left")
		await frames(1)
	release_inputs()
	return false

func settle_region(region_id: String, point: Vector2) -> bool:
	for i in 2000:
		if is_instance_valid(current_scene) and current_scene.get("world_mode") == true:
			world = current_scene
		var loader: Variant = world.world_loader
		var idle: bool = not world.world_portal_request_pending and not world.chapter_transitioning and not world.world_loading
		if is_instance_valid(loader): idle = idle and loader.phase == "idle"
		if idle and String(world.config.id) == region_id and world.player.position.distance_to(point) < 90.0:
			return true
		await frames(1)
	return false

func run() -> void:
	root.size = Vector2i(1280, 720)
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(SAVE + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	var region := "demo_ch06_silent_crown_core"
	var targets: Array = ROUTES._data().get("ability_backtracks", [])
	var target: Dictionary = {}
	for value in targets:
		if value.region_id == region and value.ability_id == "crown_resonance":
			target = value
			break
	check(not target.is_empty(), "CH06 has a crown-resonance workshop route")
	if target.is_empty():
		call_deferred("quit", 1)
		return
	var source := Vector2(target.source_position[0], target.source_position[1])
	var entry: Dictionary = ROUTES.portal(region, String(target.entry_portal_id))
	world = load("res://scenes/World.tscn").instantiate()
	world.config_path = ROUTES.config_path(region)
	world.world_resume = false
	world.world_save_path = SAVE
	world.entry_spawn_override_enabled = true
	world.entry_spawn_override = source
	root.add_child(world)
	await preload("res://scripts/world_ready_validation_helper.gd").wait_for(world)
	current_scene = world
	await frames(10)
	world._close_overlays()
	check(world.config.id == region, "Production World loaded the sixth region")
	check(world.player.room_camera.zones.size() == 16, "All 15 main rooms plus the CH06 workshop have active camera framing")
	var main_rooms: Array = []
	for room in world.config.map_rooms:
		if not String(room.id).begins_with("upgrade_"): main_rooms.append(room)
	check(main_rooms.size() == 15 and main_rooms.all(func(room): return room.get("camera_bounds", []).size() == 4), "All 15 CH06 main rooms provide camera bounds")
	check(world.player.room_camera.current.id == target.source_room_id, "Production camera starts in the authored source room")
	world._activate_world_portal(world.get_node(String(target.entry_portal_id)))
	var landing := Vector2(entry.target_spawn[0], entry.target_spawn[1])
	check(await settle_region(region, landing), "World loader completes the paired portal transition")
	check(world.player.position.distance_to(landing) < 90, "Paired portal enters the live workshop at its authored landing")
	check(world.player.room_camera.current.id == target.room_id, "Live camera switches to the workshop bounds")
	check(world.player.room_camera.current.bounds.has_area(), "Workshop camera applies its own bounded view")
	world._close_overlays()
	world._add_inventory_item("crown_resonance", 1, false)
	world._refresh_ability_gates()
	var gate_id := String(target.gate_id)
	check(world.locked_gate_bodies.has(gate_id), "Ability possession alone leaves the workshop seal closed")
	check(await walk_x(float(target.action_position[0])), "Player walks from entry to the authored action point")
	Input.action_press("crown_resonance")
	await frames(7)
	Input.action_release("crown_resonance")
	await frames(5)
	check(not world.locked_gate_bodies.has(gate_id), "Real crown-resonance input opens the production action seal")
	var currency_before: int = world.currency_count
	var rewards_exist := true
	for reward_id in target.reward_ids:
		rewards_exist = rewards_exist and world.get_node_or_null(String(reward_id)) != null
	check(rewards_exist, "Workshop evidence and currency rewards remain behind the closed seal")
	var reward_landing := Vector2(target.reward_landing[0], target.reward_landing[1])
	check(await walk_x(reward_landing.x + 45.0), "Opened seal permits walking to the reward landing")
	for reward_id in target.reward_ids:
		check(bool(world.world_collected_ids.get(String(reward_id), false)), "Live workshop reward persists its unique collection ID")
	check(world.currency_count > currency_before, "Live workshop grants spendable currency")
	check(await walk_x(landing.x), "Opened seal allows return to the workshop exit")
	var exit_id := String(entry.target_portal_id)
	world._close_overlays()
	world._activate_world_portal(world.get_node(exit_id))
	check(await settle_region(region, source), "World loader completes the live return transition")
	check(world.config.id == region and world.player.position.distance_to(source) < 90, "Live return portal lands back at the original CH06 platform")
	check(world.player.room_camera.current.id == target.source_room_id, "Returning restores the source-room camera")
	release_inputs()
	world.queue_free()
	await frames(2)
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(SAVE + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	for failure in failures: push_error(failure)
	print("CH06_WORKSHOP_EXPERIENCE checks=%d failures=%d production_world=true static_map_search=false" % [checks, failures.size()])
	call_deferred("quit", 0 if failures.is_empty() else 1)
