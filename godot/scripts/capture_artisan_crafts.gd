extends SceneTree
## Actual World render of the E04 craft page at the rain smith: a capacity
## upgrade previewed with its pattern, the same upgrade once made, and the
## travel clasp waiting on its pattern.
## Graphical engine: --script res://scripts/capture_artisan_crafts.gd -- --capture-output=DIR
const ROUTES := preload("res://scripts/world_routes.gd")
const CH02 := "demo_ch02_rain_foundry_canal"
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

func select(id: String) -> void:
	world.ui_shell.build_selection = id
	world.ui_shell.refresh_build()
	for entry in world.build_system.get_snapshot().recipes:
		if String(entry.id) == id:
			world.ui_shell._show_build_detail(entry)

func capture() -> void:
	if destination.is_empty():
		push_error("Specify --capture-output=absolute-directory")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(destination)
	root.size = Vector2i(1280, 720)
	world = load("res://scenes/World.tscn").instantiate()
	world.world_resume = false
	world.world_save_path = "user://artisan_crafts_capture.json"
	root.add_child(world)
	current_scene = world
	await preload("res://scripts/world_ready_validation_helper.gd").wait_for(world)
	# Showcase state: the smith's badge repaired (mine and 司铸 granted), the
	# counterweight trial cleared, but not the war graves.
	world.story_flags["seal_bell_repaired"] = true
	world.build_system.unlock_event("seal_bell_repaired")
	world.build_system.unlock_event("tool_mine_found")
	world.currency_count = 260
	world.inventory_counts["wet_chitin"] = 4
	world.inventory_counts["obsidian_splinter"] = 1
	world.inventory_counts["evidence_counterweight_echo"] = 1
	var config = JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json" % CH02))
	var smith_at := Vector2.ZERO
	for npc in config.get("npcs", []):
		if String(npc.get("id", "")) == "npc_rain_smith_liu":
			smith_at = Vector2(float(npc.position[0]), float(npc.position[1]))
	world._travel_world(ROUTES.config_path(CH02), smith_at)
	await frames(24)
	world.player.debug_invulnerable = true
	var smith: Node = null
	for child in world.get_children():
		if child is Area2D and String(child.get_meta("npc_id", "")) == "npc_rain_smith_liu":
			smith = child
	for offset in [Vector2(-110, 0), Vector2(110, 0), Vector2(-80, -40), Vector2(80, -40), Vector2(-60, 0), Vector2(60, 0)]:
		world.player.global_position = smith.global_position + offset
		await frames(4)
		if world.near_artisan_id() == "npc_rain_smith_liu" and not world.is_near_shrine():
			break
	world.player.reset_camera_after_arrival()
	world._toggle_build()
	await frames(4)
	select("mod_mine")
	await shot("craft_mod_mine_preview")
	world.ui_shell.build_detail.scroll_to_line(world.ui_shell.build_detail.get_line_count() - 1)
	await shot("craft_mod_mine_cost")
	world.perform_build_action("transact", "mod_mine")
	select("mod_mine")
	await shot("craft_mod_mine_made")
	select("clasp_travel")
	world.ui_shell.build_detail.scroll_to_line(world.ui_shell.build_detail.get_line_count() - 1)
	await shot("craft_clasp_missing_pattern")
	quit(0)
