extends SceneTree
## Actual World render of U03: the HUD with nothing behind it, then with an
## enemy placed behind the top HUD after it steps aside. Only the enemy position is set by the capture.
## Graphical engine: --script res://scripts/capture_hud_occlusion.gd -- --capture-output=DIR
const OCCLUSION := preload("res://scripts/hud_occlusion.gd")
var destination := ""

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-output="):
			destination = argument.trim_prefix("--capture-output=")
	call_deferred("capture")

func shot(name: String) -> bool:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image().save_png(destination.path_join(name)) == OK

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(destination)
	root.size = Vector2i(1280, 720)
	var world: Node = load("res://scenes/World.tscn").instantiate()
	world.world_resume = false
	world.world_save_path = "user://hud_occlusion_capture.json"
	root.add_child(world)
	current_scene = world
	await preload("res://scripts/world_ready_validation_helper.gd").wait_for(world)
	for node in get_nodes_in_group("enemy"): node.set_physics_process(false)
	var enemy: Area2D
	for node in get_nodes_in_group("enemy"):
		if node.world_residency_active() and not node.is_boss:
			enemy = node
			break
	for frame in 10: await process_frame
	var ui: Node = world.ui_shell
	var top := OCCLUSION.group_rect(ui._hud_groups().top)
	var canvas_inverse: Transform2D = world.get_viewport().get_canvas_transform().affine_inverse()
	var offset: Vector2 = enemy.get_hurtbox_rect().get_center() - enemy.global_position
	if not await shot("hud_clear.png"):
		quit(1)
		return
	enemy.global_position = canvas_inverse * (top.position + Vector2(150, 70)) - offset
	for frame in 20: await process_frame
	var alpha: float = ui.hud_group_alpha.top
	if not await shot("hud_faded.png"):
		quit(1)
		return
	print("HUD_OCCLUSION_CAPTURE enemy=%s top_alpha=%.2f tactical_alpha=%.2f" % [enemy.kind, alpha, ui.hud_group_alpha.tactical])
	quit(0)
