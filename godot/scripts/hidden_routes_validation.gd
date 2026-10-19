extends SceneTree
## W04: each planned hidden room shows a light-leak clue in the room that leads
## to it, the clue is noticed once in the live world and dims after the room is
## found, and the optional reward sits on a real floor inside the hidden room.
const ROUTES := preload("res://scripts/world_routes.gd")
const SAVE := "user://hidden_routes_validation.json"
var scene: Node
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func tick(count: int = 1) -> void:
	for unused in count:
		await physics_frame
		await process_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
	else:
		print("PASS " + label)

func room_rect(room_id: String) -> Rect2:
	for room in scene.config.get("map_rooms", []):
		if String(room.id) == room_id:
			return scene._room_layout_rect(room)
	return Rect2()

func room_rect_in(region: String, room_id: String) -> Rect2:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROUTES.config_path(region)))
	for room in data.get("map_rooms", []):
		if String(room.id) == room_id:
			return scene._rect2(room.get("layout_rect", [0, 0, 0, 0]))
	return Rect2()

## The player is parked (physics off) so the probes read exact positions.
func park(at: Vector2) -> void:
	scene.player.global_position = at
	scene.player.set("velocity", Vector2.ZERO)
	await tick(3)

func run() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	scene = load("res://scenes/World.tscn").instantiate()
	scene.world_resume = false
	scene.world_save_path = SAVE
	root.add_child(scene)
	await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
	current_scene = scene
	await tick(4)
	var plan: Array = ROUTES.cached_data().get("hidden_route_plan", [])
	check(plan.size() == 8, "eight hidden rooms have a planned clue")
	var regions := {}
	for entry in plan:
		regions[String(entry.region_id)] = true
	check(regions.size() == 6, "every region has at least one clued hidden room")
	for entry in plan:
		var id := String(entry.id)
		var region := String(entry.region_id)
		var entrance := String(entry.entrance_room_id)
		var hidden := String(entry.hidden_room_id)
		var clue_at: Vector2 = scene._vec2(entry.clue.position)
		if String(scene.config.get("id", "")) != region:
			scene._travel_world(ROUTES.config_path(region), room_rect_in(region, entrance).get_center())
			await tick(12)
		check(String(scene.config.get("id", "")) == region, id + " fixture reaches " + region)
		scene.player.debug_invulnerable = true
		scene.player.set_physics_process(false)
		# The clue must sit in the entrance room, right where that room meets the hidden one.
		var linked := false
		for connection in scene.config.get("connections", []):
			if String(connection.get("from", "")) == entrance and String(connection.get("to", "")) == hidden:
				linked = true
			if String(connection.get("to", "")) == entrance and String(connection.get("from", "")) == hidden and bool(connection.get("bidirectional", false)):
				linked = true
		check(linked, id + " entrance room actually leads into the hidden room")
		check(String(scene._room_for_position(clue_at).get("id", "")) == entrance, id + " clue sits inside the entrance room")
		var hidden_rect := room_rect(hidden)
		var gap := Vector2(maxf(0.0, maxf(hidden_rect.position.x - clue_at.x, clue_at.x - hidden_rect.end.x)), maxf(0.0, maxf(hidden_rect.position.y - clue_at.y, clue_at.y - hidden_rect.end.y)))
		check(gap.length() <= 140.0, id + " clue is at the hidden room's edge, not elsewhere in the room")
		var clue: Node2D = scene.get_node_or_null("HiddenClue_" + id)
		check(clue != null and not clue.found, id + " clue is drawn in the live region and not yet found")
		# Noticed once when the player comes near. "Away" steps back from the
		# hidden room so the probe never wanders into it.
		var away: Vector2 = clue_at + (clue_at - hidden_rect.get_center()).normalized() * 380.0
		await park(away)
		scene.story_flags.erase("hidden_clue_seen_" + id)
		if entry == plan[0]:
			# With the backpack open the notice waits instead of playing behind it.
			scene._toggle_backpack()
			scene.toast_label.text = ""
			scene.player.global_position = clue_at
			await tick(2)
			check(scene.active_overlay != "" and not bool(scene.story_flags.get("hidden_clue_seen_" + id, false)) and scene.toast_label.text != String(entry.clue.line), id + " no notice is spent while an overlay is open")
			scene._close_overlays()
			await park(away)
		scene.toast_label.text = ""
		scene.player.global_position = clue_at
		await tick(1)
		check(scene.toast_label.text == String(entry.clue.line), id + " coming near the clue says what the player notices (got: " + scene.toast_label.text + ")")
		check(bool(scene.story_flags.get("hidden_clue_seen_" + id, false)), id + " noticing the clue is remembered")
		var noticed_save = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
		check(noticed_save is Dictionary and bool(noticed_save.get("story_flags", {}).get("hidden_clue_seen_" + id, false)), id + " the noticed clue is saved at once")
		await park(away)
		scene.toast_label.text = ""
		scene.player.global_position = clue_at
		await tick(1)
		check(scene.toast_label.text != String(entry.clue.line), id + " the clue line is said only once")
		# Finding the hidden room dims the clue and is saved.
		await park(hidden_rect.get_center())
		check(scene.current_room_id == hidden, id + " fixture enters the hidden room")
		check(clue != null and is_instance_valid(clue) and clue.found, id + " finding the hidden room dims its clue")
		check(scene._save_world(), id + " progress saves")
		var saved = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
		check(saved is Dictionary and bool(saved.get("story_flags", {}).get("hidden_found_" + id, false)), id + " found state is on disk")
		if entry.has("reward_id"):
			var reward: Dictionary = {}
			for collectible in scene.config.get("collectibles", []):
				if String(collectible.get("id", "")) == String(entry.reward_id):
					reward = collectible
			check(String(reward.get("room_id", "")) == hidden and String(reward.get("reward_role", "")) == "optional_exploration", id + " reward is an optional pickup in the hidden room")
			var on_floor := false
			for platform in scene.config.get("platforms", []):
				if String(platform.get("id", "")) == String(reward.get("platform_id", "")):
					var rect: Rect2 = scene._rect2(platform.rect)
					var at: Vector2 = scene._vec2(reward.get("position", [0, 0]))
					on_floor = at.x >= rect.position.x and at.x <= rect.end.x and at.y < rect.position.y and rect.position.y - at.y <= 60.0
			check(on_floor, id + " reward rests on its floor")
			check(String(scene._room_for_position(scene._vec2(reward.get("position", [0, 0]))).get("id", "")) == hidden, id + " reward position is inside the hidden room")
		scene.player.set_physics_process(true)
	# A region reload rebuilds clues in their found state.
	var first: Dictionary = plan[0]
	scene._travel_world(ROUTES.config_path(String(plan[plan.size() - 1].region_id)), Vector2(2800, 2400))
	await tick(10)
	scene._travel_world(ROUTES.config_path(String(first.region_id)), scene._vec2(first.clue.position))
	await tick(12)
	var rebuilt: Node2D = scene.get_node_or_null("HiddenClue_" + String(first.id))
	check(rebuilt != null and rebuilt.found, "a found clue stays dim after leaving and returning")
	# A save from before the clues: the hidden room is visited but has no found flag.
	scene.story_flags.erase("hidden_found_" + String(first.id))
	check(bool(scene.visited_rooms.get(String(first.hidden_room_id), false)), "the fixture has visited the first hidden room")
	check(scene._save_world(), "an old-style save is written")
	scene.free()
	current_scene = null
	await tick(4)
	scene = load("res://scenes/World.tscn").instantiate()
	scene.world_resume = true
	scene.world_save_path = SAVE
	root.add_child(scene)
	await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
	current_scene = scene
	await tick(4)
	if String(scene.config.get("id", "")) != String(first.region_id):
		scene._travel_world(ROUTES.config_path(String(first.region_id)), scene._vec2(first.clue.position))
		await tick(12)
	var migrated: Node2D = scene.get_node_or_null("HiddenClue_" + String(first.id))
	check(migrated != null and migrated.found and bool(scene.story_flags.get("hidden_found_" + String(first.id), false)), "a hidden room visited in an old save loads as found")
	print("HIDDEN_ROUTES checks=%d failures=%d" % [checks, failures])
	quit(1 if failures > 0 else 0)
