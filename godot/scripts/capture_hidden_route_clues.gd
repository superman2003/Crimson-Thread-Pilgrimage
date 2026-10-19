extends SceneTree
## Actual World render of each W04 hidden-route clue as the player first meets it.
## Graphical engine: --script res://scripts/capture_hidden_route_clues.gd -- --capture-output=DIR
const ROUTES := preload("res://scripts/world_routes.gd")
var destination := ""
var world: Node

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-output="):
			destination = argument.trim_prefix("--capture-output=")
	call_deferred("capture")

func frames(count: int) -> void:
	for index in count:
		await process_frame

func shot(filename: String) -> void:
	await frames(5)
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(destination.path_join(filename + ".png")) != OK:
		push_error("Cannot save clue screenshot: " + filename)
		quit(1)

func room_center(region: String, room_id: String) -> Vector2:
	return entrance_center(region, room_id)

func entrance_center(region: String, room_id: String) -> Vector2:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROUTES.config_path(region)))
	for room in data.get("map_rooms", []):
		if String(room.id) == room_id:
			return world._rect2(room.layout_rect).get_center()
	return Vector2.ZERO

func capture() -> void:
	if destination.is_empty():
		push_error("Specify --capture-output=absolute-directory")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(destination)
	root.size = Vector2i(1280, 720)
	world = load("res://scenes/World.tscn").instantiate()
	world.world_resume = false
	world.world_save_path = "user://hidden_route_clue_capture.json"
	root.add_child(world)
	current_scene = world
	await preload("res://scripts/world_ready_validation_helper.gd").wait_for(world)
	world.player.debug_invulnerable = true
	var only := OS.get_environment("CLUE_ONLY")
	for entry in ROUTES.cached_data().get("hidden_route_plan", []):
		if not only.is_empty() and not only.split(",").has(String(entry.id)):
			continue
		var clue_at: Vector2 = world._vec2(entry.clue.position)
		world._travel_world(ROUTES.config_path(String(entry.region_id)), entrance_center(String(entry.region_id), String(entry.entrance_room_id)))
		await frames(30)
		# Show the clue as met in play: the line is said, the crack is lit.
		world.story_flags.erase("hidden_clue_seen_" + String(entry.id))
		# Held in place: three entrances are drops the player would fall through.
		world.player.set_physics_process(false)
		# Beside the clue, on the side away from the hidden room so it stays unfound.
		var hidden_center := room_center(String(entry.region_id), String(entry.hidden_room_id))
		world.player.global_position = clue_at + Vector2(signf(clue_at.x - hidden_center.x) * 90.0, 0)
		world.player.set("velocity", Vector2.ZERO)
		world.player.reset_camera_after_arrival()
		await frames(50)
		await shot(String(entry.id))
		world.player.set_physics_process(true)
	quit(0)
