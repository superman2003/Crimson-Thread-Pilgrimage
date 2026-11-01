extends SceneTree
## E02: every primary tool has a practice puppet its effect visibly acts on, free
## practice use that carries nothing away, and one real encounter it suits.
const ROUTES := preload("res://scripts/world_routes.gd")
const SAVE := "user://tool_practice_validation.json"
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

func plan_entry(tool_id: String, plan: String) -> Dictionary:
	for entry in ROUTES.cached_data().get(plan, []):
		if String(entry.get("tool_id", "")) == tool_id:
			return entry
	return {}

func floor_y(room_id: String) -> float:
	for platform in scene.config.get("platforms", []):
		if String(platform.get("id", "")) == room_id + "_foundation":
			return float(platform.rect[1])
	return NAN

func stand(at: Vector2, face: int) -> void:
	scene.player.global_position = at
	scene.player.set("velocity", Vector2.ZERO)
	scene.player.facing = face
	await tick(8)

func equip(tool_id: String) -> void:
	scene.build_system.unlock_event("tool_%s_found" % tool_id)
	# Crimson's first tool position takes shard; the repaired second takes mine, fog and lure.
	scene.build_system.unlock_event("repair_crimson")
	var slot := 0 if tool_id == "shard" else 1
	var result: Dictionary = scene.build_system.select_tool(tool_id, slot)
	check(result.get("ok", false), tool_id + " equips in a compatible tool position")
	scene.build_system.state.active_tool_slot = slot
	scene._sync_player_build()
	await tick(2)

func use_tool() -> Dictionary:
	# Wait out the previous action so each use starts from a free player.
	for attempt in 60:
		if scene.player._can_start_action():
			break
		await tick(1)
	return scene.perform_build_action("use_tool")

## Arrive at the region's practice room and return the puppet.
func visit(tool_id: String) -> Area2D:
	var entry := plan_entry(tool_id, "tool_practice_plan")
	check(not entry.is_empty(), tool_id + " has a practice plan")
	var region := String(entry.get("region_id", ""))
	var room_id := String(entry.get("room_id", ""))
	var spot: Vector2 = scene._vec2(entry.position)
	scene._travel_world(ROUTES.config_path(region), spot + Vector2(-160, -40))
	await tick(12)
	scene.player.debug_invulnerable = true
	check(String(scene.config.get("id", "")) == region, tool_id + " fixture reaches " + region)
	var puppet: Area2D = scene.get_node_or_null(String(entry.training_id))
	check(puppet != null and puppet.has_meta("tool_training_target"), tool_id + " practice puppet exists")
	if puppet == null:
		return null
	check(String(scene._room_for_position(puppet.global_position + Vector2(0, puppet.hover_height)).get("id", "")) == room_id, tool_id + " puppet stands in its practice room")
	var ray := PhysicsRayQueryParameters2D.create(puppet.global_position + Vector2(0, -8), puppet.global_position + Vector2(0, 60), 1)
	ray.collide_with_areas = false
	check(not puppet.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(), tool_id + " puppet stands on the workshop floor")
	for gate in scene.config.get("locked_gates", []):
		if String(gate.get("id", "")) == room_id + "_action_gate":
			var gate_rect: Rect2 = scene._rect2(gate.rect)
			check(puppet.global_position.x + 30.0 < gate_rect.position.x, tool_id + " puppet stands in the open anteroom, before the ability gate")
	var hostile := 0
	for spawn in scene.config.get("enemy_spawns", []):
		if String(scene._room_for_position(scene._vec2(spawn.get("position", [0, 0]))).get("id", "")) == room_id:
			hostile += 1
	check(hostile == 0, tool_id + " practice room has no real enemies, so free tool use cannot farm them")
	await equip(tool_id)
	return puppet

## Free practice: the stock after a use equals the stock before, even at zero,
## and practice never pays currency or materials.
func check_free_practice(tool_id: String, puppet: Area2D) -> void:
	var room_id := String(plan_entry(tool_id, "tool_practice_plan").get("room_id", ""))
	check(scene.current_room_id == room_id and scene._in_tool_practice_room(), tool_id + " fixture stands in the practice room")
	var stock: int = int(scene.build_system.state.tool_counts.get(tool_id, 0))
	var currency: int = scene.currency_count
	var inventory: Dictionary = scene.inventory_counts.duplicate(true)
	check(use_tool_ok(await use_tool()), tool_id + " can be used in the practice room")
	check(int(scene.build_system.state.tool_counts.get(tool_id, 0)) == stock, tool_id + " practice use keeps the carried stock")
	scene.build_system.state.tool_counts[tool_id] = 0
	check(use_tool_ok(await use_tool()), tool_id + " can be practised with an empty stock")
	check(int(scene.build_system.state.tool_counts.get(tool_id, 0)) == 0, tool_id + " empty-stock practice gives nothing to carry away")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	check(saved is Dictionary and int(saved.get("build_state", {}).get("tool_counts", {}).get(tool_id, -1)) == 0, tool_id + " saved stock is unchanged by practice")
	scene.build_system.state.tool_counts[tool_id] = stock
	await tick(30)
	check(scene.currency_count == currency and scene.inventory_counts == inventory, tool_id + " practice pays no currency or materials")
	check(is_instance_valid(puppet) and (puppet.hp > 0 or puppet.training_reset > 0.0), tool_id + " puppet never dies")

func use_tool_ok(result: Dictionary) -> bool:
	if not result.get("ok", false):
		print("use_tool refused: ", result)
	return result.get("ok", false)

## A normal melee hit on the new puppet earns practice-only thread. Leave the
## range of every rack and ensure none of that thread can be carried away.
func check_practice_energy(puppet: Area2D) -> void:
	var player = scene.player
	var original_position: Vector2 = player.global_position
	player._reset_traversal_state()
	player.hurt_timer = 0.0
	player.energy = 0
	player.practice_energy = 0
	player.global_position = puppet.global_position + Vector2(-60, 23)
	player.facing = 1
	var hp_before: int = puppet.hp
	player._start_attack(&"attack_1", false)
	# Keep this regression specific to the puppet, even when a skill rack is
	# inside the same melee swing. Those racks have separate existing coverage.
	for other in get_nodes_in_group("enemy"):
		if other != puppet: player.hit_targets[other.get_instance_id()] = true
	await tick(40)
	check(puppet.hp < hp_before, "a real normal melee swing hits the tool puppet")
	check(player.energy > 0 and player.practice_energy == player.energy, "all puppet hit energy is practice-only thread")
	player.global_position = Vector2(-1000, -1000)
	player._settle_practice_energy()
	check(player.energy == 0 and player.practice_energy == 0, "leaving practice removes every point of puppet-earned thread")
	player.global_position = original_position

func run() -> void:
	failures += await preload("res://scripts/player_tool_art_validation.gd").new().run(self)
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	scene = load("res://scenes/World.tscn").instantiate()
	scene.world_resume = false
	scene.world_save_path = SAVE
	root.add_child(scene)
	await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
	current_scene = scene
	await tick(4)
	check(ROUTES.cached_data().get("tool_practice_plan", []).size() == 4, "all four tools have a practice puppet")
	check(ROUTES.cached_data().get("tool_encounter_plan", []).size() == 4, "all four tools have a suited encounter")
	for tool_id in ["shard", "mine", "fog", "lure"]:
		var tool: Dictionary = scene.build_system.catalog.tools[tool_id]
		check(not String(tool.get("practice", "")).is_empty() and not String(tool.get("encounter", "")).is_empty(), tool_id + " build page names its practice spot and encounter")
		var encounter := plan_entry(tool_id, "tool_encounter_plan")
		var region_config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROUTES.config_path(String(encounter.region_id))))
		var room_names := {}
		for room in region_config.get("map_rooms", []):
			room_names[String(room.id)] = String(room.get("name", ""))
		check(String(tool.encounter).contains(String(room_names.get(String(encounter.room_id), "?"))), tool_id + " build page encounter names the planned room")

	# Shard: a static puppet. Knocked down, it stands back up and pays nothing.
	var shard := await visit("shard")
	if shard != null:
		var spot := shard.global_position
		await stand(Vector2(spot.x - 150, floor_y(String(plan_entry("shard", "tool_practice_plan").room_id)) - 30), 1)
		await check_free_practice("shard", shard)
		var defeated: int = scene.enemy_defeated
		var currency: int = scene.currency_count
		shard.take_hit(99, 1)
		check(shard.hp == 0 and is_instance_valid(shard), "shard puppet is knocked down, not killed")
		await tick(110)
		check(shard.hp == shard.max_hp, "shard puppet stands back up")
		check(scene.enemy_defeated == defeated and scene.currency_count == currency, "knocking down a puppet is not a kill and pays nothing")
		scene._reset_encounters_after_player_death()
		await tick(4)
		var seal_racks := 0
		for node in get_nodes_in_group("enemy"):
			if node.has_meta("seal_training_target"):
				seal_racks += 1
		check(is_instance_valid(shard) and not shard.is_queued_for_deletion(), "a death reset keeps the tool puppet")
		check(seal_racks == 2, "a death reset keeps both skill practice racks")
		await check_practice_energy(shard)

	# Mine: the puppet walks toward the player; a spike in its path trips it.
	var mine := await visit("mine")
	if mine != null:
		var ground := floor_y(String(plan_entry("mine", "tool_practice_plan").room_id))
		await stand(Vector2(mine.global_position.x - 180, ground - 30), 1)
		await check_free_practice("mine", mine)
		for trap in get_nodes_in_group("player_trap"):
			trap.queue_free()
		await tick(2)
		var start_gap: float = absf(mine.global_position.x - scene.player.global_position.x)
		check(use_tool_ok(await use_tool()), "a trip spike is laid in the puppet's path")
		var tripped := false
		for frame in 360:
			await tick(1)
			if mine.trip_timer > 0.0:
				tripped = true
				break
		check(absf(mine.global_position.x - scene.player.global_position.x) < start_gap, "mine puppet walks toward the player")
		check(tripped, "mine puppet is tripped by the spike")

	# Fog: the puppet fires a harmless practice beam; inside salt fog it stops.
	var fog := await visit("fog")
	if fog != null:
		var ground := floor_y(String(plan_entry("fog", "tool_practice_plan").room_id))
		await stand(Vector2(fog.global_position.x - 120, ground - 30), 1)
		await check_free_practice("fog", fog)
		var aimed := false
		for frame in 360:
			await tick(1)
			if String(fog.state) == "windup":
				aimed = true
				break
		check(aimed, "fog puppet winds up its practice beam at the player")
		for frame in 240:
			if not String(fog.state) in ["windup", "active", "recover"]:
				break
			await tick(1)
		var hp_before: int = scene.player.hp
		scene.player.debug_invulnerable = false
		check(use_tool_ok(await use_tool()), "salt fog is thrown over the puppet")
		await tick(2)
		check(fog.interference_timer > 0.0, "salt fog blinds the puppet")
		var fired := false
		for frame in 90:
			await tick(1)
			if String(fog.state) == "windup":
				fired = true
		check(not fired, "a blinded puppet does not wind up another beam")
		check(scene.player.hp == hp_before, "the practice beam never hurts the player")
		scene.player.debug_invulnerable = true

	# Lure: the puppet follows the player, then turns to the bell's landing point.
	var lure := await visit("lure")
	if lure != null:
		var ground := floor_y(String(plan_entry("lure", "tool_practice_plan").room_id))
		await stand(Vector2(lure.global_position.x - 200, ground - 30), 1)
		await check_free_practice("lure", lure)
		var bell_x: float = scene.player.global_position.x + 24.0
		check(use_tool_ok(await use_tool()), "the echo bell is rung near the puppet")
		await tick(2)
		check(lure.lure_timer > 0.0, "the puppet hears the bell")
		await stand(Vector2(lure.global_position.x + 90, ground - 30), -1)
		var gap_before: float = absf(lure.global_position.x - bell_x)
		await tick(30)
		check(absf(lure.global_position.x - bell_x) < gap_before, "a lured puppet heads for the bell, away from the player")

	# Encounter hint: entering the suited room with the tool equipped explains it once.
	var fog_room := plan_entry("fog", "tool_encounter_plan")
	scene._travel_world(ROUTES.config_path(String(fog_room.region_id)), Vector2(4700, 2400))
	await tick(12)
	await equip("fog")
	var flag := "tool_hint_%s_%s" % [String(fog_room.region_id), String(fog_room.room_id)]
	scene.story_flags.erase(flag)
	scene.current_room_id = ""
	var stacks: Dictionary = {}
	for room in scene.config.get("map_rooms", []):
		if String(room.id) == String(fog_room.room_id):
			stacks = room
	var stacks_rect: Rect2 = scene._room_layout_rect(stacks)
	scene.player.global_position = stacks_rect.get_center()
	await tick(3)
	check(scene.current_room_id == String(fog_room.room_id), "fixture enters the fog encounter room")
	check(scene.toast_label.text.contains("战具提示") and scene.toast_label.text.contains("盐雾瓶"), "entering the room with salt fog equipped shows its encounter hint")
	check(bool(scene.story_flags.get(flag, false)), "the encounter hint is remembered")
	scene.toast_label.text = ""
	scene.current_room_id = ""
	await tick(3)
	check(not scene.toast_label.text.contains("战具提示"), "the encounter hint is shown only once")
	print("TOOL_PRACTICE checks=%d failures=%d" % [checks, failures])
	quit(1 if failures > 0 else 0)
