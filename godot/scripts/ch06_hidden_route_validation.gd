extends SceneTree
## Exercises the authored CH06 bell-tongue vault from a real physics fixture.
## Only the starting position is placed by the test; entry, NPC interaction,
## pickup, and the eastward return use ordinary movement/interaction input.
const ROUTES := preload("res://scripts/world_routes.gd")
const STATE := preload("res://scripts/world_state.gd")
const REGION := "demo_ch06_silent_crown_core"
const SAVE := "user://ch06_hidden_route_validation.json"
const PICKUP := "col_branch_bell_tongue_vault"
const SHARD := "crown_echo_shard"
var scene: Node
var failures := 0
var frames := 0

func _initialize() -> void:
	call_deferred("run")

func tick(count: int = 1) -> void:
	for unused in count:
		await physics_frame
		await process_frame
		frames += 1

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
	else:
		print("PASS "+label)

func release_input() -> void:
	for action in ["move_left", "move_right", "jump", "attack", "interact"]:
		Input.action_release(action)

func axis(direction: float) -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	if absf(direction) > 0.0:
		Input.action_press("move_right" if direction > 0.0 else "move_left")

func walk_to_x(target_x: float, label: String, limit: int = 900) -> bool:
	for unused in limit:
		if scene.player.hp <= 0:
			break
		var dx: float = target_x - scene.player.global_position.x
		if absf(dx) < 18.0 and scene.player.is_on_floor():
			release_input()
			return true
		axis(signf(dx) if absf(dx) > 8.0 else 0.0)
		await tick()
	release_input()
	check(false, "live movement reaches %s at %s" % [label, str(scene.player.global_position)])
	return false

func press(action: String) -> void:
	Input.action_press(action)
	await tick(2)
	Input.action_release(action)
	await tick(2)

func run() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	scene = load("res://scenes/World.tscn").instantiate()
	scene.world_resume = false
	scene.world_save_path = SAVE
	root.add_child(scene)
	await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
	current_scene = scene
	await tick(4)
	var path := ROUTES.config_path(REGION)
	check(not path.is_empty(), "world route resolves the runtime CH06 config")
	scene._travel_world(path, Vector2(2840, 2600)) # Authored core-fall platform fixture only.
	await tick(8)
	scene.player.debug_invulnerable = true # Suppresses incidental enemy damage; movement/physics remain live.
	var initial_shards: int = int(scene.inventory_counts.get(SHARD, 0))
	var initial_room: Dictionary = scene.player.room_camera.current
	check(initial_room.has("id") and String(initial_room["id"]) == "core_shaft", "fixture starts in the authored core shaft")
	# Walking off the one-way ledge is the actual drop into the vault.
	var entered := false
	for unused in 420:
		axis(-1.0)
		await tick()
		if String(scene.player.room_camera.current.get("id", "")) == "bell_tongue_vault" and scene.player.is_on_floor():
			entered = true
			break
	release_input()
	check(entered, "live fall and collision land the player on the bell-vault floor")
	if not entered:
		finish()
		return
	var npc: Area2D = scene.get_node_or_null("npc_crown_tongue")
	check(npc != null, "authored old-king tongue NPC is present")
	if npc == null or not await walk_to_x(2540.0, "old-king tongue"):
		finish()
		return
	await press("interact")
	check(scene.active_overlay == "dialogue" and scene.ui_shell.dialogue_area == npc, "live interaction opens the vault NPC dialogue")
	if scene.active_overlay == "dialogue":
		scene.ui_shell._topic("route")
		var route_line: String = String(npc.get_meta("dialogue_topics", {}).get("route", ""))
		check(scene.dialogue_text_label.text == route_line and route_line.contains("可选") and route_line.contains("西") and route_line.contains("王座前廊"), "visible route answer names optional reward and both authored directions")
		scene._close_overlays()
	if await walk_to_x(2710.0, "optional crown echo shard"):
		await tick(8)
		check(int(scene.inventory_counts.get(SHARD, 0)) == initial_shards + 5, "live contact grants the optional shard amount once")
		check(bool(scene.world_collected_ids.get(PICKUP, false)) and scene.get_node_or_null(PICKUP) == null, "pickup is latched and removed from the active region")
		var saved := STATE.new()
		check(saved.read(SAVE) and bool(saved.get_region(REGION).collected_ids.get(PICKUP, false)) and int(saved.data.inventory_counts.get(SHARD, 0)) == initial_shards + 5, "world save records the unique reward and inventory")
	if await walk_to_x(3000.0, "east return to the throne approach"):
		var exit_room: Dictionary = scene.player.room_camera.current
		check(exit_room.has("id") and String(exit_room["id"]) == "throne_approach", "live eastward walk returns from vault to the throne approach")
	check(scene._save_world(), "saved progress is available for a real reload check")
	scene.free()
	current_scene = null
	await tick(4)
	scene = load("res://scenes/World.tscn").instantiate()
	scene.world_resume = true
	scene.world_save_path = SAVE
	root.add_child(scene)
	await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
	current_scene = scene
	await tick(4)
	scene.player.debug_invulnerable = true
	check(String(scene.config.id) == REGION and int(scene.inventory_counts.get(SHARD, 0)) == initial_shards + 5, "reload restores the region and optional reward count")
	check(scene.get_node_or_null(PICKUP) == null and bool(scene.world_collected_ids.get(PICKUP, false)), "collected shard stays absent after reload")
	if await walk_to_x(2710.0, "previous pickup after reload"):
		await tick(8)
		check(scene.get_node_or_null(PICKUP) == null and int(scene.inventory_counts.get(SHARD, 0)) == initial_shards + 5, "returning to the pickup after reload cannot grant it twice")
	finish()

func finish() -> void:
	release_input()
	var result := {"region": REGION, "physics_frames": frames, "live_input": true, "movement_damage_suppressed": true, "failures": failures}
	var summary_path := ProjectSettings.globalize_path("res://../artifacts/ch06_hidden_route/ci.json")
	DirAccess.make_dir_recursive_absolute(summary_path.get_base_dir())
	var summary := FileAccess.open(summary_path, FileAccess.WRITE)
	if summary != null:
		summary.store_string(JSON.stringify(result, "  ")+"\n")
		summary.close()
	else:
		failures += 1
		result["failures"] = failures
	print("CH06_HIDDEN_ROUTE_VALIDATION failures=%d metrics=%s" % [failures, JSON.stringify(result)])
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	quit(1 if failures > 0 else 0)
