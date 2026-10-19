extends SceneTree
## C04 / E04 / U02: a skill is practised on its rack with real casts, then one of
## two exclusive 校习 directions is bought from a real artisan for currency and
## that region's material, and the chosen direction changes the actual cast.
const ROUTES := preload("res://scripts/world_routes.gd")
const SAVE := "user://skill_branches_validation.json"
const CH01 := "demo_ch01_moss_bell_court"
const CH02 := "demo_ch02_rain_foundry_canal"
var scene: Node
var player: Node
var build: RefCounted
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

func practice_spot(skill_id: String) -> Vector2:
	for entry in ROUTES.cached_data().get("seal_practice_plan", []):
		if String(entry.skill_id) == skill_id:
			return scene._vec2(entry.position)
	return Vector2.ZERO

func travel(region: String, at: Vector2) -> void:
	scene._travel_world(ROUTES.config_path(region), at)
	await tick(12)
	player = scene.player
	player.debug_invulnerable = true

## Stand left of the skill's rack, facing it, on the workshop floor.
func face_rack(skill_id: String, gap: float) -> Node:
	var rack: Node = scene.get_node_or_null("seal_training_" + skill_id)
	check(rack != null, skill_id + " practice rack exists")
	player.global_position = Vector2(rack.global_position.x - gap, rack.global_position.y + 10.0)
	player.set("velocity", Vector2.ZERO)
	player.facing = 1
	for frame in 90:
		await tick(1)
		if player.is_on_floor():
			break
	return rack

func wait_free() -> void:
	for attempt in 120:
		if player._can_start_action() and player.skill_cooldown <= 0.0 and float(build.cooldowns.get(String(player.last_skill_cast), 0.0)) <= 0.0:
			return
		await tick(1)

func cast(slot: int = 0) -> bool:
	await wait_free()
	player.energy = 100
	var ok: bool = player.cast_selected_skill(slot)
	await tick(30)
	return ok

func equip_skill(skill_id: String) -> void:
	scene.story_flags["skill_%s_learned" % skill_id] = true
	build.unlock_event("skill_%s_learned" % skill_id)
	# The crimson crest's first skill slot takes cleave and needle; the bell crest's takes ward and shockwave.
	if skill_id in ["ward", "shockwave"] and build.state.crest != "bell":
		build.unlock_event("repair_bell")
		check(build.switch_crest("bell").ok, "switch to the bell crest for " + skill_id)
	var result: Dictionary = build.select_skill(skill_id, 0)
	check(result.get("ok", false), skill_id + " equips in the first skill position")
	build.state.active_skill_slot = 0
	scene._sync_player_build()
	await tick(2)

func artisan_node(npc_id: String) -> Node:
	for child in scene.get_children():
		if child is Area2D and String(child.get_meta("npc_id", child.name)) == npc_id:
			return child
	return null

func run() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	scene = load("res://scenes/World.tscn").instantiate()
	scene.world_resume = false
	scene.world_save_path = SAVE
	root.add_child(scene)
	await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
	current_scene = scene
	build = scene.build_system
	await tick(4)

	# --- Practice: only real casts of the rack's own skill count. ---
	await travel(CH01, practice_spot("cleave") + Vector2(-90, -20))
	await equip_skill("cleave")
	var rack := await face_rack("cleave", 70.0)
	for swing in 4:
		await wait_free()
		player._start_attack(&"attack_1", false, Vector2(1, 0))
		await tick(30)
	check(not bool(scene.story_flags.get("skill_practiced_cleave", false)), "basic attacks on the rack never train a skill")
	var base: Dictionary = build.selected_skill()
	check(base.branch == "", "cleave starts untrained")
	scene.currency_count = 400
	scene.inventory_counts["moss_chitin"] = 6
	var refused: Dictionary = scene.perform_build_action("transact", "branch_cleave_a")
	check(not refused.get("ok", false) and String(refused.get("reason", "")).contains("练熟"), "an unpractised skill cannot choose a direction")
	for hit in 3:
		# Each thrust lunges forward; step back in front of the rack every time.
		await face_rack("cleave", 70.0)
		check(await cast(), "cleave cast %d at its rack" % (hit + 1))
	check(bool(scene.story_flags.get("skill_practiced_cleave", false)), "three cleave hits on its rack train cleave")
	check(scene.toast_label.text.contains("已练熟") and scene.toast_label.text.contains("绯线穿刺"), "training is announced")

	# --- Buying a direction: at a real artisan, from the build page. ---
	var shrine_refusal: Dictionary = scene.perform_build_action("transact", "branch_cleave_a")
	check(not shrine_refusal.get("ok", false) and String(shrine_refusal.get("reason", "")).contains("面对面"), "a direction is bought from an artisan, not on the road")
	var apprentice := artisan_node("npc_threadsmith_apprentice")
	check(apprentice != null, "the thread apprentice stands in the court")
	scene._travel_world(ROUTES.config_path(CH01), apprentice.global_position if apprentice != null else Vector2.ZERO)
	await tick(12)
	player = scene.player
	apprentice = artisan_node("npc_threadsmith_apprentice")
	# The apprentice works beside a shrine; find where only the artisan is in reach.
	for offset in [Vector2(-110, 0), Vector2(110, 0), Vector2(-80, -40), Vector2(80, -40)]:
		player.global_position = apprentice.global_position + offset
		await tick(2)
		if scene.is_near_artisan() and not scene.is_near_shrine():
			break
	check(scene.is_near_artisan() and not scene.is_near_shrine(), "fixture stands beside the artisan, away from a shrine")
	scene._toggle_build()
	await tick(3)
	var ui: Node = scene.ui_shell
	var visible_tabs: Array = []
	for tab in ui.build_tabs:
		if tab.visible:
			visible_tabs.append(String(tab.get_meta("build_category", "")))
	check(visible_tabs == ["强化"] and ui.build_category == "强化", "beside an artisan the build page opens on 强化 only")
	ui.build_selection = "branch_cleave_a"
	ui.refresh_build()
	await tick(2)
	check(ui.build_detail.text.contains("远刺") and ui.build_detail.text.contains("连刺") and ui.build_detail.text.contains("距离 +60"), "the detail compares both directions with their real numbers")
	var currency_before: int = scene.currency_count
	var moss_before: int = int(scene.inventory_counts.get("moss_chitin", 0))
	var bought: Dictionary = scene.perform_build_action("transact", "branch_cleave_a")
	var recipe: Dictionary = build.catalog.recipes.branch_cleave_a
	check(bought.get("ok", false), "远刺 is bought at the artisan")
	check(scene.currency_count == currency_before - int(recipe.currency) and int(scene.inventory_counts.get("moss_chitin", 0)) == moss_before - int(recipe.materials.moss_chitin), "the purchase spends currency and moss shells")
	scene._close_overlays()
	await tick(2)
	var far: Dictionary = build.selected_skill()
	check(far.branch == "a" and is_equal_approx(float(far.range), float(base.range) + 60.0) and float(far.windup) > float(base.windup), "远刺 reaches further and starts slower")
	check(await cast(), "a 远刺 cast starts")
	check(is_equal_approx(float(player.attack_range), float(far.range)) and is_equal_approx(float(player.attack_windup), float(far.windup)), "the real attack uses 远刺's reach and start-up")
	var switch: Dictionary = scene.perform_build_action("transact", "branch_cleave_b")
	var quick: Dictionary = build.selected_skill()
	check(switch.get("ok", false) and quick.branch == "b" and float(quick.windup) < float(base.windup) and int(quick.damage) < int(base.damage), "switching to 连刺 replaces 远刺: quicker, one less damage")
	check(not scene.perform_build_action("transact", "branch_cleave_b").get("ok", true), "the current direction cannot be bought again")
	check(scene._save_world(), "the chosen direction saves")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	check(saved is Dictionary and int(saved.get("build_state", {}).get("skill_levels", {}).get("cleave", -1)) == 2, "the save keeps 连刺")

	# --- 震晕 shockwave: the stagger reaches the wave that hits enemies. ---
	await travel(CH02, practice_spot("shockwave") + Vector2(-90, -20))
	await equip_skill("shockwave")
	scene.story_flags["skill_practiced_shockwave"] = true
	build.state.skill_levels["shockwave"] = 2
	scene._sync_player_build()
	await face_rack("shockwave", 120.0)
	await wait_free()
	player.energy = 100
	check(player.cast_selected_skill(0), "a 震晕 shockwave is cast on the ground")
	var wave_stagger := -1.0
	for frame in 40:
		await tick(1)
		for node in scene.get_children():
			if node.get_script() != null and String(node.get_script().resource_path).ends_with("player_tool_effect.gd") and String(node.payload.get("kind", "")) == "wave":
				wave_stagger = float(node.payload.get("stagger", 0.0))
		if wave_stagger >= 0.0:
			break
	check(is_equal_approx(wave_stagger, 0.4), "the 震晕 wave carries its stagger to the hit")

	# --- Ward: a guard against its own rack is practice; the window follows the direction. ---
	await equip_skill("ward")
	var ward_rack := await face_rack("ward", 60.0)
	scene.skill_practice_hits.erase("ward")
	# A practice contact only counts against a real, vulnerable guard (the rack
	# deals no damage when the guard holds).
	player.debug_invulnerable = false
	var hp_before: int = player.hp
	for guard in 3:
		await wait_free()
		player.energy = 100
		player.cast_selected_skill(0)
		for frame in 30:
			await tick(1)
			if player.guard_timer > 0.0:
				break
		ward_rack.guard_practice_clock = 2.0
		await tick(30)
	check(player.hp == hp_before, "guarded rack contacts never hurt the player")
	player.debug_invulnerable = true
	check(bool(scene.story_flags.get("skill_practiced_ward", false)), "three guards against the ward rack train the ward")
	build.state.skill_levels["ward"] = 1
	scene._sync_player_build()
	await wait_free()
	player.energy = 100
	player.cast_selected_skill(0)
	await tick(1)
	check(is_equal_approx(float(player.attack_active_time), float(build.selected_skill().duration)) and float(build.selected_skill().duration) > float(build.catalog.skills.ward.duration), "长架 lengthens the real guard window")
	print("SKILL_BRANCHES checks=%d failures=%d" % [checks, failures])
	quit(1 if failures > 0 else 0)
