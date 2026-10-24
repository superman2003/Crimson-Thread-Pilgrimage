extends SceneTree
## Actual World render of U03: the thread meter's heal notch and art diamond,
## once with thread for the art only and once with thread for both.
## Graphical engine: --script res://scripts/capture_thread_thresholds.gd -- --capture-output=DIR
var destination := ""

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-output="):
			destination = argument.trim_prefix("--capture-output=")
	call_deferred("capture")

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(destination)
	root.size = Vector2i(1280, 720)
	var world: Node = load("res://scenes/World.tscn").instantiate()
	world.world_resume = false
	world.world_save_path = "user://thread_thresholds_capture.json"
	root.add_child(world)
	current_scene = world
	await preload("res://scripts/world_ready_validation_helper.gd").wait_for(world)
	var ui: Node = world.ui_shell
	var card: Control = ui.thread_bar.get_parent()
	var lines: Array[String] = []
	for energy in [40, 70]:
		world.player.energy = energy
		for frame in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		var rect := Rect2i(card.get_global_rect())
		var image := root.get_texture().get_image().get_region(rect)
		image.resize(rect.size.x * 2, rect.size.y * 2, Image.INTERPOLATE_NEAREST)
		var state: Dictionary = ui.thread_thresholds.threshold_state()
		if image.save_png(destination.path_join("thread_meter_%d.png" % energy)) != OK:
			push_error("Cannot save capture")
			quit(1)
			return
		lines.append("energy=%d heal=%d/%s skill=%d/%s" % [energy, ui.thread_thresholds.heal_cost, str(state.heal_lit), ui.thread_thresholds.skill_cost, str(state.skill_lit)])
	print("THREAD_THRESHOLDS_CAPTURE " + " | ".join(lines))
	quit(0)
