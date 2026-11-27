extends SceneTree
const LEVEL_HOST := preload("res://scripts/level_host.gd")
## W00 stage 0 (docs/W00_SEAMLESS_RESIDENCY_PLAN.md): inventory, no behaviour
## change. Checks that the host field list is fully classified, that region
## travel leaves nothing outside the host's region-owned children, and records
## per-region and per-exit sizes for the neighbour-shell budget. Regions are
## reached with the synchronous travel fixture, not by natural play.
const ROUTES := preload("res://scripts/world_routes.gd")
const COORD := preload("res://scripts/world_coordinates.gd")
const FIELDS := preload("res://scripts/region_state.gd")
const HAND_DRAWN_ASSETS := preload("res://scripts/hand_drawn_assets.gd")
const LOADER := preload("res://scripts/world_region_loader.gd")
const PASSAGE := preload("res://scripts/world_passage.gd")
## Same reach as the neighbour prefetch trigger and the camera half extents.
const SHELL_HALF := Vector2(1280, 900)
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func check_fields() -> void:
	var host: Node = load("res://scripts/main_level.gd").new()
	var script_fields: Array[String] = []
	for property in host.get_property_list():
		if (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
			script_fields.append(String(property.name))
	host.free()
	var seen: Dictionary = {}
	for group in FIELDS.GROUPS:
		check(FIELDS.TARGET.has(group), "group %s has a target" % group)
		for field in FIELDS.GROUPS[group]:
			check(not seen.has(field), "%s listed once (also in %s)" % [field, seen.get(field, "")])
			seen[field] = group
			check(field in script_fields, "%s is still a main_level variable" % field)
			check(not field in LOADER.SESSION_FIELDS, "%s is reset on travel, not a session field" % field)
	for field in script_fields:
		if field in LOADER.SESSION_FIELDS:
			continue
		check(seen.has(field), "%s is reset on travel but not classified in region_state.gd" % field)
	var counts := {}
	for group in FIELDS.GROUPS:
		counts[group] = FIELDS.GROUPS[group].size()
	print("WORLD_RESIDENCY_FIELDS ", JSON.stringify({"script_fields": script_fields.size(),
		"session": LOADER.SESSION_FIELDS.size(), "reset_on_travel": seen.size(), "groups": counts}))


## Stage 2: the region's field set can be taken off the host and put back with
## nothing lost, and an empty set is exactly what travel resets the host to.
func check_region_state(scene: Node, id: String) -> void:
	var names: Array[String] = FIELDS.fields()
	var progress_before := {}
	for field in FIELDS.PROGRESS_VALUES:
		progress_before[field] = var_to_str(scene.get(field))
	var state: Dictionary = FIELDS.capture(scene)
	check(state.size() == names.size() and names.size() == 95, "%s region set holds every region field (%d)" % [id, state.size()])
	var defaults: Node = scene.get_script().new()
	var previous: Dictionary = FIELDS.switch_to(scene, FIELDS.fresh(scene))
	var not_default: Array[String] = []
	for field in names:
		if var_to_str(scene.get(field)) != var_to_str(defaults.get(field)):
			not_default.append(field)
	defaults.free()
	check(not_default.is_empty(), "%s an empty set equals the script defaults (%s)" % [id, ",".join(not_default)])
	for field in FIELDS.PROGRESS_VALUES:
		check(var_to_str(scene.get(field)) == progress_before[field], "%s switching the region set leaves %s alone" % [id, field])
	FIELDS.apply(scene, previous)
	var changed: Array[String] = []
	for field in names:
		var now: Variant = scene.get(field)
		var before: Variant = state[field]
		var same: bool = is_same(now, before) if (before is Object or before is Array or before is Dictionary) else now == before
		if not same:
			changed.append(field)
	check(changed.is_empty(), "%s putting the set back restores every field (%s)" % [id, ",".join(changed)])
	check(is_instance_valid(scene.hud_label) and String(scene.config.id) == id, id + " host works on the restored set")


static func shape_bounds(node: Node) -> Rect2:
	var points := PackedVector2Array()
	if node is CollisionShape2D and node.shape != null:
		var rect: Rect2 = node.shape.get_rect()
		points = PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	elif node is CollisionPolygon2D:
		points = node.polygon
	if points.is_empty():
		return Rect2()
	var transform: Transform2D = node.global_transform
	var bounds := Rect2(transform * points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(transform * point)
	return bounds


## Numbers only; no node or resource is retained.
func measure(host: Node, window: Rect2 = Rect2()) -> Dictionary:
	var out := {"top_level": 0, "nodes": 0, "bodies": 0, "areas": 0, "shapes": 0, "canvas_items": 0, "textures": 0, "texture_bytes": 0}
	var textures: Dictionary = {}
	var stack: Array = []
	for child in LEVEL_HOST.children(host):
		if child == host.player or child == host.world_passage:
			continue
		out.top_level += 1
		stack.append(child)
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if window.has_area():
			if (node is CollisionShape2D or node is CollisionPolygon2D) and not node.disabled and shape_bounds(node).intersects(window):
				out.shapes += 1
			continue
		out.nodes += 1
		if node is Area2D:
			out.areas += 1
		elif node is CollisionObject2D:
			out.bodies += 1
		if node is CollisionShape2D or node is CollisionPolygon2D:
			out.shapes += 1
		if node is CanvasItem:
			out.canvas_items += 1
		var texture: Variant = null
		for property in ["texture", "normal_map"]:
			if property in node:
				texture = node.get(property)
				if texture is AtlasTexture and texture.atlas != null:
					texture = texture.atlas
				if texture is Texture2D and not textures.has(texture.get_rid()):
					textures[texture.get_rid()] = true
					out.textures += 1
					out.texture_bytes += texture.get_width() * texture.get_height() * 4
		if node is AnimatedSprite2D and node.sprite_frames != null:
			var frames: SpriteFrames = node.sprite_frames
			for anim_name in frames.get_animation_names():
				for frame_index in frames.get_frame_count(anim_name):
					var frame_tex: Texture2D = frames.get_frame_texture(anim_name, frame_index)
					if frame_tex is AtlasTexture and frame_tex.atlas != null:
						frame_tex = frame_tex.atlas
					if frame_tex is Texture2D and not textures.has(frame_tex.get_rid()):
						textures[frame_tex.get_rid()] = true
						out.textures += 1
						out.texture_bytes += frame_tex.get_width() * frame_tex.get_height() * 4
	if window.has_area():
		return {"window_shapes": out.shapes}
	var art_cache := HAND_DRAWN_ASSETS.cache_stats()
	out["cached_art_textures"] = int(art_cache.textures)
	out["cached_art_estimated_rgba_bytes"] = int(art_cache.estimated_rgba_bytes)
	out["rendering_texture_mem_bytes"] = int(art_cache.rendering_texture_mem_bytes)
	out["gpu_metric_available"] = bool(art_cache.gpu_metric_available)
	return out


func run() -> void:
	check_fields()
	root.process_mode = Node.PROCESS_MODE_DISABLED
	var scene: Node = load("res://scenes/World.tscn").instantiate()
	scene.world_resume = false
	scene.world_save_path = "user://world_residency_inventory_fixture.json"
	root.add_child(scene)
	await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
	# Counted once the first region has settled (the startup loading layer is gone).
	var root_children := -1
	var player_children := -1
	var regions: Array = []
	var exits: Array = []
	var previous_hud: Object = null
	var previous_progress := {}
	for id in COORD.manifest().regions:
		if String(scene.config.id) != id:
			var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROUTES.config_path(id)))
			scene._travel_world(ROUTES.config_path(id), Vector2(config.player_start[0], config.player_start[1]))
		check(String(scene.config.id) == id, id + " reached by the travel fixture")
		scene.set_process(false)
		scene.player.set_physics_process(false)
		for enemy in get_nodes_in_group("enemy"):
			enemy.set_physics_process(false)
		await process_frame
		if root_children < 0:
			root_children = root.get_child_count()
			player_children = scene.player.get_child_count()
		# Stage 1c: region nodes sit in the persistent container; only session nodes
		# and a few strays (freed on travel all the same) stay directly on the host.
		var region: Node2D = scene.region_root
		check(region != null and region.get_parent() == scene and region.position == Vector2.ZERO and region.visible, id + " region container present at the origin")
		check(region.get_meta(LEVEL_HOST.META) == scene, id + " container names its host")
		var direct := 0
		for child in scene.get_children():
			if child != region and child != scene.player and child != scene.world_passage: direct += 1
		check(region.get_child_count() >= 60 and direct <= 8, "%s region nodes are in the container (%d inside, %d strays on the host)" % [id, region.get_child_count(), direct])
		# Region travel must leave no node outside the host's region-owned children.
		var root_names: Array[String] = []
		for child in root.get_children():
			root_names.append(String(child.name))
		check(root.get_child_count() == root_children, id + " travel adds nothing to the tree root: " + ",".join(root_names))
		check(scene.player.get_child_count() == player_children, id + " travel attaches nothing to the player")
		for group in ["enemy", "boss"]:
			for node in get_nodes_in_group(group):
				var owner_child: Node = node
				while owner_child != null and not LEVEL_HOST.owns(scene, owner_child):
					owner_child = owner_child.get_parent()
				check(owner_child != null and owner_child != scene.player and owner_child != scene.world_passage,
					"%s %s %s lives under a region-owned host child" % [id, group, node.name])
		# Stage 2 evidence: interface is rebuilt per region, progress only restored.
		if previous_hud != null:
			check(scene.hud_label != previous_hud and not is_instance_valid(previous_hud), id + " HUD rebuilt by travel")
			for field in FIELDS.PROGRESS_VALUES:
				check(var_to_str(scene.get(field)) == previous_progress[field], "%s %s survives travel unchanged" % [id, field])
		previous_hud = scene.hud_label
		for field in FIELDS.PROGRESS_VALUES:
			previous_progress[field] = var_to_str(scene.get(field))
		check_region_state(scene, id)
		var metrics := measure(scene)
		metrics["region"] = id
		check(metrics.top_level > 0 and metrics.shapes > 0, id + " region owns nodes and collision")
		regions.append(metrics)
		# Neighbour-shell size: resident collision around each passage mouth after
		# the normal arrival warm-up at that point.
		for passage in PASSAGE.routes():
			for side in ["a", "b"]:
				if String(passage[side].region) != id:
					continue
				var portal: Dictionary = ROUTES.cached_portal(id, String(passage[side].portal))
				check(portal.get("position", []) is Array and portal.position.size() >= 2, "%s %s portal has a position" % [id, passage.id])
				if not portal.get("position", []) is Array or portal.position.size() < 2:
					continue
				var point := Vector2(float(portal.position[0]), float(portal.position[1]))
				scene.player.global_position = point
				scene.player.reset_camera_after_arrival()
				scene.world_platforms.warm(scene, point)
				scene.chapter_terrain.refresh_visual_chunks(Rect2(point - SHELL_HALF, SHELL_HALF * 2), true)
				await process_frame
				var window := measure(scene, Rect2(point - SHELL_HALF, SHELL_HALF * 2))
				check(window.window_shapes > 0, "%s %s mouth has collision to share" % [id, passage.id])
				window.merge({"region": id, "passage": String(passage.id), "share_of_region_shapes": snappedf(float(window.window_shapes) / maxf(1.0, float(metrics.shapes)), 0.01)})
				exits.append(window)
	check(exits.size() == PASSAGE.routes().size() * 2, "every passage mouth measured (%d)" % exits.size())
	var final_art_cache := HAND_DRAWN_ASSETS.cache_stats()
	check(int(final_art_cache.textures) <= 130 and int(final_art_cache.estimated_rgba_bytes) < 1400 * 1024 * 1024,
		"character art cache bounds residency to recent regions instead of accumulating all six (textures=%d estimated_rgba_bytes=%d rendering_texture_mem_bytes=%d)" % [int(final_art_cache.textures), int(final_art_cache.estimated_rgba_bytes), int(final_art_cache.rendering_texture_mem_bytes)])
	print("WORLD_RESIDENCY_REGIONS ", JSON.stringify(regions))
	print("WORLD_RESIDENCY_EXITS ", JSON.stringify(exits))
	HAND_DRAWN_ASSETS.clear_caches()
	scene.free()
	await process_frame
	print("WORLD_RESIDENCY_INVENTORY checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
