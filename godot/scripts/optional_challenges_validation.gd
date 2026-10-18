extends SceneTree
## B04: optional challenge rooms and optional bosses — bypassable, revisit-safe,
## one-time rewards tied to evidence / growth, never blocking the main combat clear.
const ROUTES := preload("res://scripts/world_routes.gd")
const STATE := preload("res://scripts/world_state.gd")
const SAVE := "user://optional_challenges_validation.json"
const CH01 := "demo_ch01_moss_bell_court"
const CH02 := "demo_ch02_rain_foundry_canal"
const CH03 := "demo_ch03_saltwhite_archive"
const CH04 := "demo_ch04_broken_string_greenhouse"
const CH05 := "demo_ch05_obsidian_pilgrim_road"
const CH06 := "demo_ch06_silent_crown_core"
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

func finish() -> void:
	print("OPTIONAL_CHALLENGES checks=%d failures=%d fixture_scope=production_world_challenge_clear_and_antibuse" % [checks, failures])
	quit(1 if failures > 0 else 0)

func wipe_save() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))

func boot(resume: bool = false) -> void:
	scene = load("res://scenes/World.tscn").instantiate()
	scene.world_resume = resume
	scene.world_save_path = SAVE
	root.add_child(scene)
	await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
	current_scene = scene
	await tick(4)

func travel(region: String, at: Vector2) -> void:
	var path := ROUTES.config_path(region)
	check(not path.is_empty(), "world route resolves " + region)
	scene._travel_world(path, at)
	await tick(10)
	if scene.player != null:
		scene.player.debug_invulnerable = true

func challenge(region_challenge_id: String) -> Dictionary:
	return scene._optional_challenge(region_challenge_id)

func run_challenge_clear(challenge_id: String, evidence_id: String, expect_unlock: String = "") -> void:
	var data := challenge(challenge_id)
	check(not data.is_empty(), challenge_id + " is authored on the active region")
	var clear_flag := String(data.get("clear_flag", ""))
	check(not clear_flag.is_empty(), challenge_id + " records a clear flag")
	check(not bool(scene.story_flags.get(clear_flag, false)), challenge_id + " starts uncleared")
	var shrine_id := String(data.get("shrine", {}).get("id", ""))
	var shrine: Area2D = scene.get_node_or_null(shrine_id)
	check(shrine != null, challenge_id + " shrine exists in the live region")
	var before_currency: int = scene.currency_count
	var drop := String(scene.config.get("enemy_drop_item", ""))
	var before_mats: int = int(scene.inventory_counts.get(drop, 0))
	var before_evidence: int = int(scene.inventory_counts.get(evidence_id, 0))
	var before_defeated: int = scene.enemy_defeated
	var before_total: int = scene.enemy_total
	scene._start_optional_challenge(data)
	await tick(4)
	check(scene.active_challenge_id == challenge_id, challenge_id + " becomes the active challenge")
	check(scene.challenge_arena_lock_body != null and is_instance_valid(scene.challenge_arena_lock_body), challenge_id + " seals the entrance while active")
	check(scene.challenge_alive_ids.size() == data.get("enemies", []).size(), challenge_id + " spawns every authored challenge enemy")
	check(scene.enemy_total == before_total, challenge_id + " does not inflate the region's combat-clear total")
	# Defeat each challenge enemy through the normal death path.
	for spawn in data.get("enemies", []):
		var spawn_id := String(spawn.get("id", ""))
		var kind := String(spawn.get("kind", "moss_larva"))
		scene._on_enemy_died(spawn_id, false, kind)
		await tick(2)
	check(scene.active_challenge_id.is_empty(), challenge_id + " clears the active challenge after the last foe")
	check(scene.challenge_arena_lock_body == null or not is_instance_valid(scene.challenge_arena_lock_body), challenge_id + " opens the seal after clear")
	check(bool(scene.story_flags.get(clear_flag, false)), challenge_id + " writes the clear flag")
	var reward: Dictionary = data.get("reward", {})
	var expect_currency: int = before_currency + 8 * int(data.get("enemies", []).size()) + int(reward.get("currency", 0))
	check(scene.currency_count == expect_currency, challenge_id + " pays kill loot plus the one-time challenge reward")
	check(int(scene.inventory_counts.get(drop, 0)) == before_mats + int(data.get("enemies", []).size()) + int(reward.get("material_amount", 0)), challenge_id + " pays materials once")
	check(int(scene.inventory_counts.get(evidence_id, 0)) == before_evidence + int(reward.get("item_amount", 1)), challenge_id + " grants its evidence / growth item once")
	check(scene.enemy_defeated == before_defeated, challenge_id + " never advances the region's combat-clear counter")
	if not expect_unlock.is_empty():
		check(bool(scene.story_flags.get(expect_unlock, false)), challenge_id + " records the growth unlock flag")
	# Anti-farm: starting again after clear must no-op on rewards.
	var currency_after: int = scene.currency_count
	var evidence_after: int = int(scene.inventory_counts.get(evidence_id, 0))
	scene._activate_challenge_shrine(shrine)
	await tick(2)
	check(scene.active_challenge_id.is_empty(), challenge_id + " refuses to restart after clear")
	check(scene.currency_count == currency_after and int(scene.inventory_counts.get(evidence_id, 0)) == evidence_after, challenge_id + " cannot be farmed for a second reward")
	# Direct grant path is also latched.
	scene._grant_optional_challenge_reward(data)
	check(scene.currency_count == currency_after and int(scene.inventory_counts.get(evidence_id, 0)) == evidence_after, challenge_id + " grant helper stays latched by the clear flag")


func run_tracking_hunt_gate(challenge_id: String, evidence_id: String, expect_unlock: String = "") -> void:
	var data := challenge(challenge_id)
	check(not data.is_empty(), challenge_id + " is authored on the active region")
	check(String(data.get("kind", "")) == "tracking_hunt", challenge_id + " is a tracking hunt")
	var tracks: Array = data.get("tracks", [])
	check(tracks.size() >= 2, challenge_id + " authors at least two tracks")
	var shrine_id := String(data.get("shrine", {}).get("id", ""))
	var shrine: Area2D = scene.get_node_or_null(shrine_id)
	check(shrine != null, challenge_id + " quarry shrine exists")
	# Before tracks: shrine must refuse to start.
	scene._activate_challenge_shrine(shrine)
	await tick(2)
	check(scene.active_challenge_id.is_empty(), challenge_id + " refuses to start before tracks are found")
	for track in tracks:
		var track_id := String(track.get("id", ""))
		var area: Area2D = scene.get_node_or_null(track_id)
		check(area != null, challenge_id + " track " + track_id + " exists in the live region")
		var flag := String(track.get("flag", ""))
		check(not bool(scene.story_flags.get(flag, false)), challenge_id + " track " + track_id + " starts unread")
		scene._activate_hunt_track(area)
		await tick(2)
		check(bool(scene.story_flags.get(flag, false)), challenge_id + " track " + track_id + " writes its flag")
	check(scene._challenge_tracks_ready(data), challenge_id + " becomes ready after all tracks")
	await run_challenge_clear(challenge_id, evidence_id, expect_unlock)

func run() -> void:
	wipe_save()
	await boot(false)
	# Challenge room in ch01 crown splinter nook (dash-gated optional side room).
	await travel(CH01, Vector2(2060, 720))
	await tick(6)
	check(String(scene.config.get("id", "")) == CH01, "fixture is in moss bell court")
	check(scene.config.get("optional_challenges", []).size() >= 1, "ch01 authors at least one optional challenge")
	# Lock push must keep the player on the shrine/enemy side (left of ch01's east wall).
	var ch01 := challenge("ch01_crown_nook_trial")
	var ch01_lock: Rect2 = scene._rect2(ch01.get("lock_rect", []))
	var ch01_inside: float = scene._challenge_lock_inside_x(ch01, ch01_lock)
	check(ch01_inside < ch01_lock.position.x, "ch01 lock inside is left of the east wall")
	scene.player.global_position = Vector2(ch01_lock.position.x + 10.0, 720)
	scene._start_optional_challenge(ch01)
	await tick(2)
	check(scene.player.global_position.x < ch01_lock.position.x, "ch01 seal push keeps the player inside left of the wall")
	scene._clear_active_challenge(false)
	await tick(2)
	await run_challenge_clear("ch01_crown_nook_trial", "evidence_crown_echo")
	check(scene._save_world(), "challenge progress saves")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	check(saved is Dictionary and bool(saved.get("story_flags", {}).get("challenge_clear_ch01_crown_nook", false)), "ch01 clear flag is on disk")
	# Challenge room + tracking hunt in ch02 rain foundry (optional side content).
	await travel(CH02, Vector2(5560, 4140))
	await tick(6)
	check(String(scene.config.get("id", "")) == CH02, "fixture is in rain foundry canal")
	check(scene.config.get("optional_challenges", []).size() >= 2, "ch02 authors challenge room and tracking hunt")
	await run_challenge_clear("ch02_counterweight_trial", "evidence_counterweight_echo")
	# Hunt tracks live across wish board / gauge gallery; travel near the quarry shrine.
	await travel(CH02, Vector2(3200, 1740))
	await tick(6)
	var track_a: Area2D = scene.get_node_or_null("hunt_track_ch02_canal_a")
	check(track_a != null, "canal hunt track A spawns at the wish board")
	scene._activate_hunt_track(track_a)
	await tick(2)
	await travel(CH02, Vector2(3340, 2208))
	await tick(6)
	var track_b: Area2D = scene.get_node_or_null("hunt_track_ch02_canal_b")
	check(track_b != null, "canal hunt track B spawns in the gauge gallery")
	scene._activate_hunt_track(track_b)
	await tick(2)
	await travel(CH02, Vector2(3580, 4760))
	await tick(6)
	var hunt := challenge("ch02_canal_shadow_hunt")
	check(scene._challenge_tracks_ready(hunt), "canal hunt becomes ready after both tracks")
	var shrine_hunt: Area2D = scene.get_node_or_null(String(hunt.get("shrine", {}).get("id", "")))
	# Without tracks the shrine would refuse; with tracks, clear through the shared path.
	# Re-clear gate: wipe track readiness check already passed; run full clear.
	# Ensure shrine still refuses if we strip a track flag (anti-skip).
	scene.story_flags["hunt_track_ch02_canal_b"] = false
	scene._activate_challenge_shrine(shrine_hunt)
	await tick(2)
	check(scene.active_challenge_id.is_empty(), "canal hunt still refuses when a track is missing")
	scene.story_flags["hunt_track_ch02_canal_b"] = true
	await run_challenge_clear("ch02_canal_shadow_hunt", "evidence_canal_track", "charm_shell_found")
	check(scene._save_world(), "ch02 challenge progress saves")
	saved = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	check(saved is Dictionary and bool(saved.get("story_flags", {}).get("challenge_clear_ch02_counterweight", false)), "ch02 challenge-room clear flag is on disk")
	check(bool(saved.get("story_flags", {}).get("challenge_clear_ch02_canal_hunt", false)), "ch02 hunt clear flag is on disk")
	# Optional boss in ch03 wax seal vault (already an optional branch).
	await travel(CH03, Vector2(4465, 2634))
	await tick(6)
	check(String(scene.config.get("id", "")) == CH03, "fixture is in saltwhite archive")
	var ch03 := challenge("ch03_wax_optional_boss")
	var ch03_lock: Rect2 = scene._rect2(ch03.get("lock_rect", []))
	var ch03_inside: float = scene._challenge_lock_inside_x(ch03, ch03_lock)
	check(ch03_inside > ch03_lock.position.x + ch03_lock.size.x, "ch03 lock inside is right of the west wall")
	scene.player.global_position = Vector2(ch03_lock.position.x - 10.0, 2634)
	scene._start_optional_challenge(ch03)
	await tick(2)
	check(scene.player.global_position.x > ch03_lock.position.x + ch03_lock.size.x, "ch03 seal push keeps the player inside right of the wall")
	scene._clear_active_challenge(false)
	await tick(2)
	await run_challenge_clear("ch03_wax_optional_boss", "evidence_salt_ledger", "charm_stride_found")
	check(scene._save_world(), "optional boss progress saves")
	saved = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	check(saved is Dictionary and bool(saved.get("story_flags", {}).get("challenge_clear_ch03_wax_boss", false)), "ch03 clear flag is on disk")
	check(bool(saved.get("story_flags", {}).get("challenge_clear_ch01_crown_nook", false)), "ch01 clear flag survives travel")
	check(bool(saved.get("story_flags", {}).get("challenge_clear_ch02_counterweight", false)), "ch02 challenge-room clear survives travel")
	check(bool(saved.get("story_flags", {}).get("challenge_clear_ch02_canal_hunt", false)), "ch02 hunt clear survives travel")
	# Challenge room in ch04 beeswax nook (reward side room on the south ring).
	await travel(CH04, Vector2(4980, 2265))
	await tick(6)
	check(String(scene.config.get("id", "")) == CH04, "fixture is in broken string greenhouse")
	check(scene.config.get("optional_challenges", []).size() >= 1, "ch04 authors at least one optional challenge")
	var ch04 := challenge("ch04_beeswax_nook_trial")
	var ch04_lock: Rect2 = scene._rect2(ch04.get("lock_rect", []))
	var ch04_inside: float = scene._challenge_lock_inside_x(ch04, ch04_lock)
	check(ch04_inside > ch04_lock.position.x + ch04_lock.size.x, "ch04 lock inside is right of the west wall")
	scene.player.global_position = Vector2(ch04_lock.position.x - 10.0, 2265)
	scene._start_optional_challenge(ch04)
	await tick(2)
	check(scene.player.global_position.x > ch04_lock.position.x + ch04_lock.size.x, "ch04 seal push keeps the player inside right of the wall")
	scene._clear_active_challenge(false)
	await tick(2)
	await run_challenge_clear("ch04_beeswax_nook_trial", "evidence_beeswax_echo")
	check(scene._save_world(), "ch04 challenge progress saves")
	saved = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	check(saved is Dictionary and bool(saved.get("story_flags", {}).get("challenge_clear_ch04_beeswax", false)), "ch04 clear flag is on disk")
	check(bool(saved.get("story_flags", {}).get("challenge_clear_ch01_crown_nook", false)), "ch01 clear flag survives ch04 travel")
	check(bool(saved.get("story_flags", {}).get("challenge_clear_ch02_counterweight", false)), "ch02 challenge-room clear survives ch04 travel")
	check(bool(saved.get("story_flags", {}).get("challenge_clear_ch02_canal_hunt", false)), "ch02 hunt clear survives ch04 travel")
	check(bool(saved.get("story_flags", {}).get("challenge_clear_ch03_wax_boss", false)), "ch03 clear flag survives ch04 travel")

	# Tracking hunt in ch04 greenhouse: overlook + west spoke tracks -> root vault quarry.
	await travel(CH04, Vector2(1980, 880))
	await tick(6)
	check(String(scene.config.get("id", "")) == CH04, "fixture is in broken string greenhouse for hunt")
	check(scene.config.get("optional_challenges", []).size() >= 2, "ch04 authors challenge room and tracking hunt")
	var track_root_a: Area2D = scene.get_node_or_null("hunt_track_ch04_root_a")
	check(track_root_a != null, "root hunt track A spawns at the canopy overlook")
	scene._activate_hunt_track(track_root_a)
	await tick(2)
	await travel(CH04, Vector2(1400, 1570))
	await tick(6)
	var track_root_b: Area2D = scene.get_node_or_null("hunt_track_ch04_root_b")
	check(track_root_b != null, "root hunt track B spawns on the west spoke")
	scene._activate_hunt_track(track_root_b)
	await tick(2)
	await travel(CH04, Vector2(2480, 1942))
	await tick(6)
	var root_hunt := challenge("ch04_root_cage_hunt")
	check(scene._challenge_tracks_ready(root_hunt), "root hunt becomes ready after both tracks")
	var shrine_root: Area2D = scene.get_node_or_null(String(root_hunt.get("shrine", {}).get("id", "")))
	# Anti-skip: missing a track still refuses.
	scene.story_flags["hunt_track_ch04_root_b"] = false
	scene._activate_challenge_shrine(shrine_root)
	await tick(2)
	check(scene.active_challenge_id.is_empty(), "root hunt still refuses when a track is missing")
	scene.story_flags["hunt_track_ch04_root_b"] = true
	# Lock push keeps player on the shrine/enemy side (left of east wall).
	var ch04_hunt_lock: Rect2 = scene._rect2(root_hunt.get("lock_rect", []))
	var ch04_hunt_inside: float = scene._challenge_lock_inside_x(root_hunt, ch04_hunt_lock)
	check(ch04_hunt_inside < ch04_hunt_lock.position.x, "ch04 hunt lock inside is left of the east wall")
	scene.player.global_position = Vector2(ch04_hunt_lock.position.x + 10.0, 1942)
	scene._start_optional_challenge(root_hunt)
	await tick(2)
	check(scene.player.global_position.x < ch04_hunt_lock.position.x, "ch04 hunt seal push keeps the player inside left of the wall")
	scene._clear_active_challenge(false)
	await tick(2)
	await run_challenge_clear("ch04_root_cage_hunt", "evidence_root_track", "charm_mender_found")
	check(scene._save_world(), "ch04 hunt progress saves")
	saved = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	check(saved is Dictionary and bool(saved.get("story_flags", {}).get("challenge_clear_ch04_root_hunt", false)), "ch04 hunt clear flag is on disk")
	check(bool(saved.get("story_flags", {}).get("challenge_clear_ch04_beeswax", false)), "ch04 beeswax clear survives hunt")

	# Challenge room in ch05 war graves (lantern/obsidian reward branch off the banner bridge).
	await travel(CH05, Vector2(200, 1352))
	await tick(6)
	check(String(scene.config.get("id", "")) == CH05, "fixture is in obsidian pilgrim road")
	check(scene.config.get("optional_challenges", []).size() >= 1, "ch05 authors at least one optional challenge")
	var ch05 := challenge("ch05_war_graves_trial")
	var ch05_lock: Rect2 = scene._rect2(ch05.get("lock_rect", []))
	var ch05_inside: float = scene._challenge_lock_inside_x(ch05, ch05_lock)
	check(ch05_inside < ch05_lock.position.x, "ch05 lock inside is left of the east wall")
	scene.player.global_position = Vector2(ch05_lock.position.x + 10.0, 1352)
	scene._start_optional_challenge(ch05)
	await tick(2)
	check(scene.player.global_position.x < ch05_lock.position.x, "ch05 seal push keeps the player inside left of the wall")
	scene._clear_active_challenge(false)
	await tick(2)
	await run_challenge_clear("ch05_war_graves_trial", "evidence_lantern_graves_echo")
	check(scene._save_world(), "ch05 challenge progress saves")
	saved = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	check(saved is Dictionary and bool(saved.get("story_flags", {}).get("challenge_clear_ch05_war_graves", false)), "ch05 clear flag is on disk")
	check(bool(saved.get("story_flags", {}).get("challenge_clear_ch01_crown_nook", false)), "ch01 clear flag survives ch05 travel")
	check(bool(saved.get("story_flags", {}).get("challenge_clear_ch02_counterweight", false)), "ch02 challenge-room clear survives ch05 travel")
	check(bool(saved.get("story_flags", {}).get("challenge_clear_ch02_canal_hunt", false)), "ch02 hunt clear survives ch05 travel")
	check(bool(saved.get("story_flags", {}).get("challenge_clear_ch03_wax_boss", false)), "ch03 clear flag survives ch05 travel")
	check(bool(saved.get("story_flags", {}).get("challenge_clear_ch04_beeswax", false)), "ch04 clear flag survives ch05 travel")
	check(bool(saved.get("story_flags", {}).get("challenge_clear_ch04_root_hunt", false)), "ch04 hunt clear survives ch05 travel")


	# Challenge room in ch06 bell tongue vault (optional crown-side reward room).
	await travel(CH06, Vector2(2660, 2860))
	await tick(6)
	check(String(scene.config.get("id", "")) == CH06, "fixture is in silent crown core")
	check(scene.config.get("optional_challenges", []).size() >= 1, "ch06 authors at least one optional challenge")
	var ch06 := challenge("ch06_bell_tongue_trial")
	var ch06_lock: Rect2 = scene._rect2(ch06.get("lock_rect", []))
	var ch06_inside: float = scene._challenge_lock_inside_x(ch06, ch06_lock)
	check(ch06_inside > ch06_lock.position.x + ch06_lock.size.x, "ch06 lock inside is right of the west wall")
	scene.player.global_position = Vector2(ch06_lock.position.x - 10.0, 2860)
	scene._start_optional_challenge(ch06)
	await tick(2)
	check(scene.player.global_position.x > ch06_lock.position.x + ch06_lock.size.x, "ch06 seal push keeps the player inside right of the wall")
	scene._clear_active_challenge(false)
	await tick(2)
	await run_challenge_clear("ch06_bell_tongue_trial", "evidence_bell_tongue_echo")
	check(scene._save_world(), "ch06 challenge progress saves")
	saved = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	check(saved is Dictionary and bool(saved.get("story_flags", {}).get("challenge_clear_ch06_bell_tongue", false)), "ch06 clear flag is on disk")
	check(bool(saved.get("story_flags", {}).get("challenge_clear_ch01_crown_nook", false)), "ch01 clear flag survives ch06 travel")
	check(bool(saved.get("story_flags", {}).get("challenge_clear_ch02_counterweight", false)), "ch02 challenge-room clear survives ch06 travel")
	check(bool(saved.get("story_flags", {}).get("challenge_clear_ch02_canal_hunt", false)), "ch02 hunt clear survives ch06 travel")
	check(bool(saved.get("story_flags", {}).get("challenge_clear_ch03_wax_boss", false)), "ch03 clear flag survives ch06 travel")
	check(bool(saved.get("story_flags", {}).get("challenge_clear_ch04_beeswax", false)), "ch04 clear flag survives ch06 travel")
	check(bool(saved.get("story_flags", {}).get("challenge_clear_ch05_war_graves", false)), "ch05 clear flag survives ch06 travel")
	check(bool(saved.get("story_flags", {}).get("challenge_clear_ch04_root_hunt", false)), "ch04 hunt clear survives ch06 travel")

	# Reload from disk: cleared challenges stay cleared, rewards do not repeat.
	scene.free()
	current_scene = null
	await tick(4)
	await boot(true)
	await travel(CH01, Vector2(2060, 720))
	await tick(6)
	check(bool(scene.story_flags.get("challenge_clear_ch01_crown_nook", false)), "reloaded save keeps the ch01 clear flag")
	var data: Dictionary = challenge("ch01_crown_nook_trial")
	var before: int = scene.currency_count
	scene._activate_challenge_shrine(scene.get_node_or_null(String(data.get("shrine", {}).get("id", ""))))
	await tick(2)
	check(scene.currency_count == before and scene.active_challenge_id.is_empty(), "reloaded clear still blocks farming")
	# Main combat-clear total stays the authored enemy_spawns size (optional fights are extra).
	check(scene.enemy_total == scene.config.get("enemy_spawns", []).size(), "optional challenges never change enemy_total")
	finish()
