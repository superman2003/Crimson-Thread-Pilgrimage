extends SceneTree
## Actual World render of the C04 artisan page: one 校习 direction compared with
## the other, before and after buying it.
## Graphical engine: --script res://scripts/capture_skill_branches.gd -- --capture-output=DIR
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
	world.world_save_path = "user://skill_branch_capture.json"
	root.add_child(world)
	current_scene = world
	await preload("res://scripts/world_ready_validation_helper.gd").wait_for(world)
	world.player.debug_invulnerable = true
	# Showcase state: cleave practised, enough currency and moss for one direction.
	world.story_flags["skill_practiced_cleave"] = true
	world.currency_count = 260
	world.inventory_counts["moss_chitin"] = 4
	var apprentice: Node = null
	for child in world.get_children():
		if child is Area2D and String(child.get_meta("npc_id", "")) == "npc_threadsmith_apprentice":
			apprentice = child
	for offset in [Vector2(-110, 0), Vector2(110, 0), Vector2(-80, -40), Vector2(80, -40)]:
		world.player.global_position = apprentice.global_position + offset
		await frames(4)
		if world.is_near_artisan() and not world.is_near_shrine():
			break
	world.player.reset_camera_after_arrival()
	world._toggle_build()
	await frames(4)
	world.ui_shell.build_selection = "branch_cleave_a"
	world.ui_shell.refresh_build()
	await shot("artisan_branch_detail")
	world.perform_build_action("transact", "branch_cleave_a")
	world.ui_shell.build_selection = "branch_cleave_b"
	world.ui_shell.refresh_build()
	await shot("artisan_after_choice")
	quit(0)
