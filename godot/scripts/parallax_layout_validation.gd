extends SceneTree
## V03: the painted backdrop's mirror joins and the distance ornaments' repeat
## period stay out of normal play. In the formal World, each region's camera is
## swept over its whole limit rect at several "expand" viewports and the layer
## space actually on screen (read back from the engine's canvas transforms) is
## compared with FlatMapArt's prediction and layout.
const ROUTES := preload("res://scripts/world_routes.gd")
const ART := preload("res://scripts/flat_map_art.gd")
const RETIRE := preload("res://scripts/audio_retirement.gd")
const REGIONS := ["demo_ch01_moss_bell_court", "demo_ch02_rain_foundry_canal", "demo_ch03_saltwhite_archive", "demo_ch04_broken_string_greenhouse", "demo_ch05_obsidian_pilgrim_road", "demo_ch06_silent_crown_core"]
const VIEWS := [Vector2i(1280, 720), Vector2i(1706, 720), Vector2i(1280, 960)]
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: " + label)

func frames(count: int) -> void:
	for index in count:
		await process_frame

## Wrap a layer-space difference into (-period/2, period/2].
func wrapped(value: float, period: float) -> float:
	return fposmod(value + period * 0.5, period) - period * 0.5 if period > 0.0 else value

func run() -> void:
	root.size = VIEWS[0]
	var level: Node = load("res://scenes/World.tscn").instantiate()
	root.add_child(level)
	await preload("res://scripts/world_ready_validation_helper.gd").wait_for(level)
	for id in REGIONS:
		if String(level.config.get("id", "")) != id:
			var start: Array = (JSON.parse_string(FileAccess.get_file_as_string("res://data/" + id + ".json")) as Dictionary).get("player_start", [300, 300])
			check(await level.world_loader.replace_region_async(level, ROUTES.cached_config_path(id), Vector2(start[0], start[1])), id + " formal region transition")
			await frames(3)
		await verify_region(level, id)
	root.size = VIEWS[0]
	RETIRE.retire_tree(level)
	level.queue_free()
	await process_frame
	check(await RETIRE.drain(self), "World audio retirement")
	print("PARALLAX_LAYOUT regions=%d checks=%d failures=%d" % [REGIONS.size(), checks, failures])
	quit(0 if failures == 0 else 1)

func verify_region(level: Node, id: String) -> void:
	var art: Node2D = level.flat_map_art
	check(is_instance_valid(art) and art.region_size == Vector2(level.world_width, level.world_height), id + " art knows the region size the camera uses")
	var backdrop: Parallax2D = art.get_node_or_null("PaintedBackdrop")
	check(backdrop != null and backdrop.get_child_count() == 2, id + " backdrop keeps a plain and a mirrored copy")
	if backdrop == null: return
	var plain: Sprite2D = backdrop.get_child(0)
	var mirrored: Sprite2D = backdrop.get_child(1)
	var tile := Vector2(plain.texture.get_size()) * plain.scale
	check(not plain.flip_h and mirrored.flip_h and is_equal_approx(mirrored.position.x - plain.position.x, tile.x), id + " mirrored copy sits right after the plain copy")
	# The painting may grow to cover the region but never shrinks below the old 960px height.
	check(tile.y >= 959.0 and plain.scale.x <= 1.25, id + " backdrop scale %.3f stays between the old size and +25%%" % plain.scale.x)
	verify_ornaments(art, id)
	verify_rebuild(level, art, id)
	await verify_sweep(level, art, id, tile)

func verify_ornaments(art: Node2D, id: String) -> void:
	for layer_name in ["FlatMiddleDistance", "FlatNearEdges"]:
		var layer: Parallax2D = art.get_node_or_null(layer_name)
		check(layer != null, id + " " + layer_name + " exists")
		if layer == null: continue
		var reach: Rect2 = ART.parallax_reach(art.region_size, layer.scroll_scale)
		check(layer.repeat_size.x >= reach.size.x and layer.repeat_size.y >= reach.size.y, "%s %s repeat %s covers everything the region can show %s" % [id, layer_name, layer.repeat_size, reach.size])
		var cells := Vector2i(roundi(layer.repeat_size.x / ART.ORNAMENT_CELL.x), roundi(layer.repeat_size.y / ART.ORNAMENT_CELL.y))
		check(layer.get_child_count() == cells.x * cells.y, "%s %s keeps one ornament per cell (%d for %s)" % [id, layer_name, layer.get_child_count(), cells])
		var grid := {}
		var flips := {}
		for child in layer.get_children():
			var cell := Vector2i(((child.position - reach.position) / ART.ORNAMENT_CELL).floor())
			grid[cell] = int(child.get_meta("decoration_variant", -1))
			var feather: ShaderMaterial = child.material as ShaderMaterial
			var uv: Vector4 = feather.get_shader_parameter("region_uv") if feather != null else Vector4.ZERO
			var size := Vector2(child.texture.get_size())
			check(feather != null and Rect2(uv.x * size.x, uv.y * size.y, (uv.z - uv.x) * size.x, (uv.w - uv.y) * size.y).grow(0.01).encloses(child.region_rect) and Rect2(child.region_rect).grow(0.01).encloses(Rect2(uv.x * size.x, uv.y * size.y, (uv.z - uv.x) * size.x, (uv.w - uv.y) * size.y)), "%s %s ornament fades out at its own atlas cell edges" % [id, layer_name])
			flips[child.flip_h] = true
			check(Rect2(reach.position + Vector2(cell) * ART.ORNAMENT_CELL, ART.ORNAMENT_CELL).encloses(Rect2(child.position, child.region_rect.size * child.scale)), "%s %s ornament stays inside its cell %s" % [id, layer_name, cell])
		check(grid.size() == layer.get_child_count(), id + " " + layer_name + " cells are distinct")
		var repeats := 0
		for cell in grid:
			for step in [Vector2i(1, 0), Vector2i(0, 1)]:
				if grid.has(cell + step) and grid[cell + step] == grid[cell]: repeats += 1
		check(repeats == 0, "%s %s neighbouring ornaments differ (%d same-variant pairs)" % [id, layer_name, repeats])
		var variants := {}
		for value in grid.values(): variants[value] = true
		check(variants.size() >= mini(4, grid.size()) and flips.size() == 2, "%s %s uses %d ornament variants and both facings" % [id, layer_name, variants.size()])

func verify_rebuild(level: Node, art: Node2D, id: String) -> void:
	# Streaming rebuilds a region from the same config: identical layout.
	var copy: Node2D = ART.new()
	copy.configure(String(art.theme), level.config)
	for layer_name in ["PaintedBackdrop", "FlatMiddleDistance", "FlatNearEdges"]:
		var a: Parallax2D = art.get_node(layer_name)
		var b: Parallax2D = copy.get_node(layer_name)
		var same := a.repeat_size == b.repeat_size and a.get_child_count() == b.get_child_count()
		if same:
			for index in a.get_child_count():
				var x: Node2D = a.get_child(index)
				var y: Node2D = b.get_child(index)
				same = same and x.position == y.position and x.scale == y.scale and x.get("flip_h") == y.get("flip_h") and x.get_meta("decoration_variant", -1) == y.get_meta("decoration_variant", -1)
		check(same, id + " " + layer_name + " rebuilds identically")
	copy.free()

func verify_sweep(level: Node, art: Node2D, id: String, tile: Vector2) -> void:
	level.set_process(false)
	level.player.set_physics_process(false)
	var camera: Camera2D = level.player.get_node("Camera2D")
	var saved := [camera.top_level, camera.global_position, camera.position_smoothing_enabled, camera.limit_left, camera.limit_top, camera.limit_right, camera.limit_bottom]
	camera.top_level = true
	camera.position_smoothing_enabled = false
	# The whole region rect main_level gives the camera (rooms only narrow it).
	var low: Vector2 = level.to_global(ART.CAMERA_LIMIT_MIN)
	var high: Vector2 = level.to_global(art.region_size + ART.CAMERA_LIMIT_MAX_MARGIN)
	camera.limit_left = int(low.x); camera.limit_top = int(low.y)
	camera.limit_right = int(high.x); camera.limit_bottom = int(high.y)
	for view in VIEWS:
		root.size = view
		await frames(2)
		var viewport := root.get_visible_rect().size
		var worst := 0.0
		var crossing := 0
		var samples := 0
		var seen := {}
		for gx in 13:
			for gy in 7:
				camera.global_position = low + (high - low) * Vector2(gx / 12.0, gy / 6.0)
				camera.reset_smoothing()
				camera.force_update_scroll()
				await process_frame
				var centre: Vector2 = level.to_local(camera.get_screen_center_position())
				for layer in art.get_children():
					if not layer is Parallax2D: continue
					var first: Node2D = layer.get_child(0)
					var to_layer: Transform2D = (first.get_global_transform_with_canvas() * first.transform.affine_inverse()).affine_inverse()
					var left: Vector2 = to_layer * Vector2.ZERO
					var right: Vector2 = to_layer * viewport
					var half: Vector2 = viewport / (2.0 * camera.zoom)
					var predicted: Vector2 = layer.scroll_scale * (centre - viewport * 0.5) + viewport * 0.5 - half
					worst = maxf(worst, maxf(absf(wrapped(left.x - predicted.x, layer.repeat_size.x)), absf(wrapped(left.y - predicted.y, layer.repeat_size.y))))
					var window: Rect2 = ART.parallax_window(art.region_size, layer.scroll_scale, viewport)
					var rel := predicted - window.position
					seen[layer.name] = true if rel.x >= -0.5 and rel.y >= -0.5 and rel.x + (right.x - left.x) <= window.size.x + 0.5 and rel.y + (right.y - left.y) <= window.size.y + 0.5 and seen.get(layer.name, true) else false
					if layer.name == "PaintedBackdrop":
						samples += 1
						if fposmod(left.x - first.position.x, layer.repeat_size.x) + (right.x - left.x) > tile.x + 0.5: crossing += 1
		check(worst < 0.5, "%s %s engine parallax offsets match the layout formula (worst %.4fpx)" % [id, viewport, worst])
		for layer_name in seen:
			check(seen[layer_name], "%s %s every %s frame lies inside parallax_window()" % [id, viewport, layer_name])
		check(crossing == 0, "%s %s backdrop never shows a copy join (%d/%d frames)" % [id, viewport, crossing, samples])
	root.size = VIEWS[0]
	camera.top_level = saved[0]; camera.global_position = saved[1]; camera.position_smoothing_enabled = saved[2]
	camera.limit_left = saved[3]; camera.limit_top = saved[4]; camera.limit_right = saved[5]; camera.limit_bottom = saved[6]
	level.set_process(true)
	level.player.set_physics_process(true)
	await frames(2)
