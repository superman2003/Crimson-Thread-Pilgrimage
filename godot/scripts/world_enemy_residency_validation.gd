extends SceneTree
## Exercise active-world enemy suspension through the normal region builder.
## Region load and focus jumps are explicit fixtures, not natural playthroughs.
const ROUTES := preload("res://scripts/world_routes.gd")
const STATE := preload("res://scripts/world_state.gd")
const AUDIO_DIRECTOR := preload("res://scripts/audio_director.gd")
const SAVE := "user://world_enemy_residency_validation.json"
const REGION := "demo_ch01_moss_bell_court"
const REGIONS := [
	"demo_ch01_moss_bell_court", "demo_ch02_rain_foundry_canal", "demo_ch03_saltwhite_archive",
	"demo_ch04_broken_string_greenhouse", "demo_ch05_obsidian_pilgrim_road", "demo_ch06_silent_crown_core"
]

var scene: Node
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("ENEMY RESIDENCY FAIL: " + label)

func tick(count: int = 1) -> void:
	for unused in count:
		await physics_frame
		await process_frame

func find_enemy(id: String) -> Area2D:
	for actor in get_nodes_in_group("enemy"):
		if is_instance_valid(actor) and String(actor.get("spawn_id")) == id and not bool(actor.get("is_boss")):
			return actor as Area2D
	return null

func wait_for_residency(id: String, active: bool, max_frames: int = 90) -> Area2D:
	for unused in max_frames:
		await tick()
		var actor := find_enemy(id)
		if actor != null and actor.world_residency_active() == active:
			return actor
	return find_enemy(id)

func focus_at(point: Vector2) -> void:
	scene.player.global_position = point
	scene.player.velocity = Vector2.ZERO
	await tick(3)

func run() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	scene = load("res://scenes/World.tscn").instantiate()
	scene.world_resume = false
	scene.world_save_path = SAVE
	root.add_child(scene)
	current_scene = scene
	await tick(4)
	var config_path := ROUTES.config_path(REGION)
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(config_path))
	var start := Vector2(float(raw.player_start[0]), float(raw.player_start[1]))
	scene._travel_world(config_path, start)
	await tick(8)
	var data: Dictionary = raw.enemy_spawns[0]
	var enemy_id := String(data.id)
	var enemy := find_enemy(enemy_id)
	check(enemy != null, "authored normal enemy is created by the production region builder")
	if enemy == null:
		await finish()
		return
	var service: RefCounted = scene.world_gameplay_residency
	var arrival_snapshot: Dictionary = service.snapshot()
	check(not scene.world_loading and bool(arrival_snapshot.arrival_ready) and int(arrival_snapshot.enemy_active) > 0 and
		int(arrival_snapshot.enemy_tracked) == int(arrival_snapshot.enemy_authored) and int(arrival_snapshot.enemy_arrival_suspensions) > 0,
		"arrival warm batch tracks all region enemies, suspends off-window actors, and publishes current-view actors before input unlock")
	var total_group_count := get_nodes_in_group("enemy").size()
	await focus_at(enemy.global_position + Vector2(-64, 40))
	check(bool(enemy.call("world_residency_active")) and enemy.process_mode != Node.PROCESS_MODE_DISABLED and enemy.visible and enemy.monitoring and enemy.monitorable,
		"camera-window enemy is visible, processing and physically monitored")
	check(enemy.is_in_group("enemy") and get_nodes_in_group("enemy").size() == total_group_count,
		"active residency preserves canonical enemy group membership")
	var reads_before := int(enemy.get("command_read_count"))
	for unused in 20:
		await tick()
	check(int(enemy.get("command_read_count")) > reads_before, "near enemy continues normal AI command sampling")

	# A genuine player attack lowers HP before the actor leaves the active area.
	scene.player.facing = 1
	scene.player._start_attack(&"attack_1")
	await tick(16)
	var hp_after_attack := int(enemy.get("hp"))
	check(hp_after_attack < int(enemy.get("max_hp")), "real player melee input path damages resident enemy")
	if int(enemy.get("hp")) <= 0:
		check(false, "first melee fixture hit is partial so HP persistence can be measured")
		await finish()
		return
	# Keep the same actor just outside the activation window to exercise hysteresis.
	var last_window: Rect2 = service.last_window
	var edge_focus := enemy.position - Vector2(last_window.size.x * 0.5 + 500.0, 0.0)
	service._update_window(scene, scene.to_global(edge_focus), Vector2.ZERO, 0.0)
	if service.last_window.has_point(enemy.position):
		edge_focus.x -= 1000.0
		service._update_window(scene, scene.to_global(edge_focus), Vector2.ZERO, 0.0)
	var outside_activation: bool = not service.last_window.has_point(enemy.position)
	var inside_retention: bool = service.last_window.grow(1100.0).has_point(enemy.position)
	check(outside_activation and inside_retention, "boundary fixture is outside activation but inside retention window")
	await focus_at(scene.to_global(edge_focus))
	check(bool(enemy.call("world_residency_active")), "small boundary excursion does not toggle the enemy")

	var far_focus: Vector2 = scene.to_global(enemy.position + Vector2(24000.0, 0.0))
	var max_frame_activations := 0
	var max_frame_deactivations := 0
	await focus_at(far_focus)
	var waited := 0
	while bool(enemy.call("world_residency_active")) and waited < 90:
		await tick()
		var frame_snapshot: Dictionary = service.snapshot()
		max_frame_activations = maxi(max_frame_activations, int(frame_snapshot.enemy_last_frame_activations))
		max_frame_deactivations = maxi(max_frame_deactivations, int(frame_snapshot.enemy_last_frame_deactivations))
		waited += 1
	check(not bool(enemy.call("world_residency_active")), "far enemy becomes dormant after leaving retention window")
	check(enemy.is_inside_tree() and enemy.is_in_group("enemy") and not enemy.visible and not enemy.monitoring and not enemy.monitorable,
		"dormancy suspends processing/physics presentation in place while retaining node and group")
	var state_while_dormant := String(enemy.get("state"))
	var timer_while_dormant := float(enemy.get("state_timer"))
	await tick(20)
	check(int(enemy.get("hp")) == hp_after_attack and String(enemy.get("state")) == state_while_dormant and is_equal_approx(float(enemy.get("state_timer")), timer_while_dormant),
		"suspended enemy retains HP and frozen AI state")
	var snapshot: Dictionary = service.snapshot()
	check(int(snapshot.enemy_deactivations) > 0 and int(snapshot.enemy_suspended) > 0 and int(snapshot.enemy_active) < int(snapshot.enemy_tracked),
		"runtime reports reduced active AI/Area count without claiming freed nodes")
	check(max_frame_activations <= int(snapshot.enemy_frame_activation_limit) and max_frame_deactivations <= int(snapshot.enemy_frame_deactivation_limit),
		"observed normal per-frame activation/deactivation respects the declared 4/4 budget")

	await focus_at(enemy.global_position + Vector2(-64, 40))
	var returned := await wait_for_residency(enemy_id, true)
	check(returned == enemy and int(returned.get("hp")) == hp_after_attack and returned.visible and returned.monitoring and returned.monitorable,
		"re-entry restores the same enemy instance, HP and interaction flags")
	check(get_nodes_in_group("enemy").size() == total_group_count, "re-entry creates no duplicate group actor")

	# Keep the real world Boss outside the ordinary-enemy service and prove its
	# damage/lifecycle owner remains untouched by focus changes.
	scene._spawn_boss()
	var boss: Area2D = scene.boss_actor
	check(boss != null and bool(boss.get("is_boss")) and bool(boss.call("world_residency_active")), "Boss remains outside normal enemy residency")
	var boss_hp := int(boss.get("hp"))
	var boss_mode := boss.process_mode
	var boss_reads := int(boss.get("command_read_count"))
	await focus_at(far_focus)
	await tick(20)
	check(is_instance_valid(boss) and boss.process_mode == boss_mode and boss.visible and boss.monitoring and int(boss.get("hp")) == boss_hp and int(boss.get("command_read_count")) > boss_reads,
		"focus movement leaves real Boss active and its AI processing intact")

	# Move back and finish the partially damaged normal enemy with the same real
	# attack path. Death signal, counter and material/currency reward are one-shot.
	await focus_at(enemy.global_position + Vector2(-64, 40))
	await wait_for_residency(enemy_id, true)
	var wallet_before := int(scene.currency_count)
	var defeated_before := int(scene.enemy_defeated)
	var drop := String(scene.config.get("enemy_drop_item", "moss_chitin"))
	var item_before := int(scene.inventory_counts.get(drop, 0))
	var kill_frames := 0
	while is_instance_valid(enemy) and not bool(enemy.get("dying")) and kill_frames < 160:
		scene.player.global_position = enemy.global_position + Vector2(-64, 40)
		scene.player.velocity = Vector2.ZERO
		scene.player.facing = 1
		if scene.player._can_start_action(): scene.player._start_attack(&"attack_1")
		await tick(16)
		kill_frames += 16
	check(is_instance_valid(enemy) and bool(enemy.get("dying")), "resident enemy death still runs through EnemyActor death signal")
	check(int(scene.currency_count) == wallet_before + 8 and int(scene.enemy_defeated) == defeated_before + 1 and int(scene.inventory_counts.get(drop, 0)) == item_before + 1,
		"one death grants exactly one configured drop, one count and eight fragments")
	var saved := STATE.new()
	check(saved.read(SAVE) and int(saved.data.currency) == int(scene.currency_count), "single death reward is persisted once")
	# Trigger the player death timer and normal hard-respawn signal chain. The
	# world callback clears the old residents, then the next process pass rebuilds.
	var reward_wallet := int(scene.currency_count)
	var reward_count := int(scene.enemy_defeated)
	var expected_lost := int(reward_wallet / 2)
	scene.player.debug_invulnerable = false
	scene.player.arrival_guard_timer = 0.0
	scene.player.hurt_timer = 0.0
	scene.player.take_damage(999, scene.player.global_position + Vector2(80, 0), false)
	check(float(scene.player.get("death_timer")) > 0.0, "lethal player damage enters the production death timer")
	var cache: Dictionary = scene.world_state.data.get("death_cache", {})
	check(int(scene.currency_count) == reward_wallet - expected_lost and int(cache.get("currency", -1)) == expected_lost and String(cache.get("region_id", "")) == REGION and is_instance_valid(scene.death_cache_area),
		"death applies the exact half-currency penalty and persists one recovery knot in-region")
	await tick(75)
	check(int(scene.player.get("death_timer")) == 0 and int(scene.player.get("hp")) == int(scene.player.get("max_hp")),
		"production hard respawn completes and restores player health")
	await tick(4)
	var respawned_enemy := find_enemy(enemy_id)
	check(respawned_enemy != null and respawned_enemy != enemy and respawned_enemy.world_residency_active() and respawned_enemy.visible and respawned_enemy.monitoring and scene.player._can_start_action(),
		"player_respawned signal rebuilds an active enemy and restores player input")
	var matching_after_respawn := 0
	for actor in get_nodes_in_group("enemy"):
		if String(actor.get("spawn_id")) == enemy_id and not bool(actor.get("is_boss")):
			matching_after_respawn += 1
	var reset_snapshot: Dictionary = scene.world_gameplay_residency.snapshot()
	check(matching_after_respawn == 1 and int(scene.currency_count) == reward_wallet - expected_lost and int(scene.enemy_defeated) == 0 and reward_count > 0 and int(reset_snapshot.enemy_tracked) > 0,
		"death reset clears old tracked nodes, rebuilds one generation, and grants no repeat reward")

	# Exercise one normal authored spawn from each of the six region configs using
	# the actual host travel/build path. These are location fixtures, not a
	# continuous-world playthrough.
	for region_id in REGIONS:
		var region_path := ROUTES.config_path(region_id)
		var region_raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(region_path))
		if region_raw.get("enemy_spawns", []).is_empty():
			check(false, "six-region residency fixture has an enemy spawn: " + region_id)
			continue
		var region_start := Vector2(float(region_raw.player_start[0]), float(region_raw.player_start[1]))
		scene._travel_world(region_path, region_start)
		await tick(8)
		var region_enemy_id := String(region_raw.enemy_spawns[0].get("id", ""))
		var region_enemy := await wait_for_residency(region_enemy_id, true, 30)
		if region_enemy == null:
			check(false, "production region builder creates first normal spawn: " + region_id)
			continue
		await focus_at(region_enemy.global_position + Vector2(-64, 40))
		check(region_enemy.world_residency_active() and region_enemy.is_in_group("enemy"), "region activation restores authored enemy: " + region_id)
		var region_service: RefCounted = scene.world_gameplay_residency
		var region_active_snapshot: Dictionary = region_service.snapshot()
		check(int(region_active_snapshot.enemy_tracked) == int(region_active_snapshot.enemy_authored) and int(region_active_snapshot.enemy_active) > 0 and
			int(region_active_snapshot.enemy_arrival_suspensions) > 0,
			"current region service tracks all enemies and warm-suspends off-window actors: " + region_id)
		var region_hp := int(region_enemy.get("hp"))
		var region_far := region_enemy.global_position + Vector2(24000.0, 0.0)
		await focus_at(region_far)
		var region_dormant := await wait_for_residency(region_enemy_id, false, 90)
		check(region_dormant == region_enemy and int(region_enemy.get("hp")) == region_hp, "region spawn suspends same actor without HP loss: " + region_id)
		var region_dormant_snapshot: Dictionary = scene.world_gameplay_residency.snapshot()
		check(int(region_dormant_snapshot.enemy_suspended) > 0,
			"current region service reports dormant actor: " + region_id)
		await focus_at(region_enemy.global_position + Vector2(-64, 40))
		var region_returned := await wait_for_residency(region_enemy_id, true, 90)
		check(region_returned == region_enemy and int(region_returned.get("hp")) == region_hp, "region spawn resumes same actor: " + region_id)
		var region_return_snapshot: Dictionary = scene.world_gameplay_residency.snapshot()
		print("ENEMY_RESIDENCY_REGION region=%s id=%s authored=%d tracked=%d active=%d suspended=%d arrival_suspended=%d activations=%d deactivations=%d" % [
			region_id, region_enemy_id, int(region_return_snapshot.enemy_authored), int(region_return_snapshot.enemy_tracked),
			int(region_return_snapshot.enemy_active), int(region_return_snapshot.enemy_suspended),
			int(region_return_snapshot.enemy_arrival_suspensions),
			int(region_return_snapshot.enemy_activations), int(region_return_snapshot.enemy_deactivations)])
	var state: Dictionary = scene.world_gameplay_residency.snapshot()
	print("WORLD_ENEMY_RESIDENCY checks=%d failures=%d snapshot=%s" % [checks, failures.size(), JSON.stringify(state)])
	await finish()

func finish() -> void:
	if scene != null and is_instance_valid(scene): scene.queue_free()
	# Chapter-transition stingers intentionally outlive MainLevel. This harness
	# owns those root-level one-shot players and must retire them at teardown.
	for node in root.get_children():
		if node is AudioStreamPlayer and String(node.name).begins_with("PersistentSfx_"):
			node.stop()
			node.stream = null
			node.free()
	# Let MainLevel/AudioDirector stop playback and release node-bound resources
	# before this standalone harness exits; drop the deliberate static stream cache
	# only after all players have detached their references.
	await process_frame
	await process_frame
	AUDIO_DIRECTOR._stream_cache.clear()
	quit(1 if not failures.is_empty() else 0)
