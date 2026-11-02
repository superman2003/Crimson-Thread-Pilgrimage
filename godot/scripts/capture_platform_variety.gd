extends SceneTree
## Actual GL render of V03 ledge variety: in each listed region, frame the
## camera on the densest cluster of ordinary ledges and save one screenshot.
## Graphical engine: --script res://scripts/capture_platform_variety.gd -- --capture-output=DIR [--label=NAME]
const MAP_ART := preload("res://scripts/flat_map_art.gd")
const REGIONS := ["demo_ch01_moss_bell_court", "demo_ch02_rain_foundry_canal", "demo_ch04_broken_string_greenhouse"]
var destination := ""
var label := "after"

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-output="):
			destination = argument.trim_prefix("--capture-output=")
		elif argument.begins_with("--label="):
			label = argument.trim_prefix("--label=")
	call_deferred("capture")

func frames(count: int) -> void:
	for index in count:
		await process_frame

func densest(config: Dictionary) -> Vector2:
	var centers: Array = []
	for data in config.get("platforms", []):
		if data.has("terrain_id") or MAP_ART.material_variant_for(String(data.get("material", "moss_stone"))) != 2:
			continue
		var rect: Array = data.get("rect", [])
		if rect.size() == 4:
			centers.append(Vector2(rect[0] + rect[2] * 0.5, rect[1] + rect[3] * 0.5))
	var best := Vector2.ZERO
	var best_count := -1
	for center in centers:
		var count := 0
		for other in centers:
			if absf(other.x - center.x) < 560.0 and absf(other.y - center.y) < 300.0:
				count += 1
		if count > best_count:
			best_count = count
			best = center
	return best

func capture() -> void:
	if destination.is_empty():
		push_error("Specify --capture-output=absolute-directory")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(destination)
	root.size = Vector2i(1280, 720)
	for id in REGIONS:
		var scene: Node = load("res://scenes/Main.tscn").instantiate()
		scene.config_path = "res://data/" + id + ".json"
		root.add_child(scene)
		await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
		scene.player.set_physics_process(false)
		for actor in get_nodes_in_group("enemy"):
			actor.set_physics_process(false)
		scene.player.global_position = densest(scene.config)
		var camera: Camera2D = scene.player.get_node("Camera2D")
		# Pull back past room framing so several ledges share one frame.
		camera.set_process(false)
		camera.top_level = true
		camera.global_position = scene.player.global_position
		camera.zoom = Vector2(0.45, 0.45)
		for limit in ["limit_left", "limit_top"]: camera.set(limit, -10000000)
		for limit in ["limit_right", "limit_bottom"]: camera.set(limit, 10000000)
		if is_instance_valid(scene.get("ui_canvas")): scene.ui_canvas.visible = false
		camera.reset_smoothing()
		await frames(20)
		await RenderingServer.frame_post_draw
		if root.get_texture().get_image().save_png(destination.path_join("%s_%s.png" % [id, label])) != OK:
			push_error("Cannot save capture: " + id)
			quit(1)
			return
		scene.queue_free()
		await frames(3)
	quit(0)
