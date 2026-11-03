extends SceneTree
## Actual GL frames for the V03 parallax layout: per region, the camera at the
## far right of its limit rect (where the old backdrop showed its mirror join),
## once as the normal frame and once with only the parallax layers drawn.
## Graphical engine: --script res://scripts/capture_parallax_layout.gd -- --capture-output=DIR [--label=NAME] [--view=WxH]
const ROUTES := preload("res://scripts/world_routes.gd")
const REGIONS := ["demo_ch01_moss_bell_court", "demo_ch04_broken_string_greenhouse"]
var destination := ""
var label := "after"
var view := Vector2i(1706, 720)

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-output="):
			destination = argument.trim_prefix("--capture-output=")
		elif argument.begins_with("--label="):
			label = argument.trim_prefix("--label=")
		elif argument.begins_with("--view="):
			var parts := argument.trim_prefix("--view=").split("x")
			view = Vector2i(int(parts[0]), int(parts[1]))
	call_deferred("capture")

func frames(count: int) -> void:
	for index in count:
		await process_frame

func save(name: String) -> bool:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image().save_png(destination.path_join("%s_%dx%d_%s.png" % [name, view.x, view.y, label])) == OK

func capture() -> void:
	if destination.is_empty():
		push_error("Specify --capture-output=absolute-directory")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(destination)
	root.size = view
	var level: Node = load("res://scenes/World.tscn").instantiate()
	root.add_child(level)
	# Software GL can need well over the validation helper's 15 seconds.
	var deadline := Time.get_ticks_msec() + 180000
	while not level.initial_region_ready and Time.get_ticks_msec() < deadline:
		await process_frame
	for id in REGIONS:
		if String(level.config.get("id", "")) != id:
			var start: Array = (JSON.parse_string(FileAccess.get_file_as_string("res://data/" + id + ".json")) as Dictionary).get("player_start", [300, 300])
			await level.world_loader.replace_region_async(level, ROUTES.cached_config_path(id), Vector2(start[0], start[1]))
		level.set_process(false)
		level.player.set_physics_process(false)
		for actor in get_nodes_in_group("enemy"):
			actor.set_physics_process(false)
		if is_instance_valid(level.get("ui_canvas")): level.ui_canvas.visible = false
		var camera: Camera2D = level.player.get_node("Camera2D")
		camera.top_level = true
		camera.position_smoothing_enabled = false
		camera.limit_left = -40; camera.limit_top = -120
		camera.limit_right = int(level.world_width + 80); camera.limit_bottom = int(level.world_height + 70)
		camera.global_position = level.to_global(Vector2(level.world_width + 80, level.world_height * 0.5))
		camera.reset_smoothing()
		await frames(30)
		if not await save(id + "_frame"):
			quit(1)
			return
		var hidden: Array = []
		for child in level.get_children():
			if child is CanvasItem and child != level.flat_map_art and child.visible:
				child.visible = false
				hidden.append(child)
		for child in level.flat_map_art.get_children():
			if not child is Parallax2D and child.visible:
				child.visible = false
				hidden.append(child)
		await frames(3)
		if not await save(id + "_parallax"):
			quit(1)
			return
		for child in hidden:
			child.visible = true
	quit(0)
