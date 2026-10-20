extends SceneTree
## Actual World render of N05: the 苔钟庭 first-bell shrine under each ending,
## and the journal's per-region list for the chosen one.
## Graphical engine: --script res://scripts/capture_ending_aftermath.gd -- --capture-output=DIR
const ROUTES := preload("res://scripts/world_routes.gd")
const COURT := "demo_ch01_moss_bell_court"
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
		push_error("Cannot save capture: " + filename)
		quit(1)

func capture() -> void:
	if destination.is_empty():
		push_error("Specify --capture-output=absolute-directory")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(destination)
	root.size = Vector2i(1280, 720)
	world = load("res://scenes/World.tscn").instantiate()
	world.world_resume = false
	world.world_save_path = "user://ending_aftermath_capture.json"
	root.add_child(world)
	current_scene = world
	await preload("res://scripts/world_ready_validation_helper.gd").wait_for(world)
	world.player.debug_invulnerable = true
	for index in range(1, 7):
		world.story_flags["boss_down_ch%02d" % index] = true
	for ending in ["ending_a", "ending_b", "ending_c"]:
		for other in ["ending_a", "ending_b", "ending_c"]:
			world.story_flags.erase(other + "_done")
		world.story_flags["ending_chosen"] = ending
		world.story_flags[ending + "_done"] = true
		world.story_flags = world.world_narrative.restored_ending_flags(world.story_flags)
		world.story_flags.erase("aftermath_seen_ch01_moss_bell_court")
		world._spawn_ending_aftermath()
		await frames(2)
		# Stand a little short of the shrine so the lamp and the change share the frame.
		world.player.global_position = world.ending_aftermath.global_position + Vector2(-260, -40)
		world.player.reset_camera_after_arrival()
		await frames(30)
		world.player.global_position = world.ending_aftermath.global_position + Vector2(-200, -40)
		await frames(40)
		await shot("court_shrine_" + ending)
	world.story_flags["aftermath_seen_ch02_rain_foundry_canal"] = true
	world.ui_shell.bag_category = "旅记"
	world._toggle_backpack()
	world.ui_shell.refresh_inventory()
	for ending in world.world_narrative.evaluate_progress(world.inventory_counts, world.story_flags).endings:
		if bool(ending.get("chosen", false)):
			world.ui_shell._show_journal_record(ending.merged({"record_kind": "ending"}))
	if world.ui_shell.bag_description is RichTextLabel:
		world.ui_shell.bag_description.scroll_to_line(world.ui_shell.bag_description.get_line_count() - 1)
	await shot("journal_aftermath_rows")
	quit(0)
