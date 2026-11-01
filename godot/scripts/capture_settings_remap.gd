extends SceneTree
## Actual World render of U06: the settings page with all 17 remappable actions.
## Graphical engine: --script res://scripts/capture_settings_remap.gd -- --capture-output=DIR
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
	world.world_save_path = "user://settings_remap_capture.json"
	root.add_child(world)
	current_scene = world
	await preload("res://scripts/world_ready_validation_helper.gd").wait_for(world)
	world._toggle_audio_settings()
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(destination.path_join("settings_remap.png")) != OK:
		push_error("Cannot save capture")
		quit(1)
		return
	quit(0)
