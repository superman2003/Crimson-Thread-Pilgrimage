extends SceneTree
## E04: artisans make tool capacity upgrades and the 行旅承力扣 from an optional
## challenge's evidence (shown as a pattern, never consumed), shards and a
## regional material. Only the named artisan makes each piece; a refused or
## unsaved craft changes nothing; old saves keep the slot they already had.
const ROUTES := preload("res://scripts/world_routes.gd")
const AUDIO := preload("res://scripts/audio_retirement.gd")
const BUILD := preload("res://scripts/build_system.gd")
const SAVE := "user://artisan_crafts_validation.json"
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

func artisan_node(npc_id: String) -> Node:
	for child in scene.get_children():
		if child is Area2D and String(child.get_meta("npc_id", child.name)) == npc_id:
			return child
	return null

func npc_position(region: String, npc_id: String) -> Vector2:
	var config = JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json" % region))
	for npc in config.get("npcs", []):
		if String(npc.get("id", "")) == npc_id:
			return Vector2(float(npc.position[0]), float(npc.position[1]))
	return Vector2.ZERO

## Stand where only this artisan (no shrine) is in reach.
func stand_at(region: String, npc_id: String) -> bool:
	scene._travel_world(ROUTES.config_path(region), npc_position(region, npc_id))
	await tick(12)
	player = scene.player
	player.debug_invulnerable = true
	var npc := artisan_node(npc_id)
	if npc == null:
		return false
	for offset in [Vector2(-110, 0), Vector2(110, 0), Vector2(-80, -40), Vector2(80, -40), Vector2(-60, 0), Vector2(60, 0), Vector2.ZERO]:
		player.global_position = npc.global_position + offset
		await tick(2)
		if scene.near_artisan_id() == npc_id and not scene.is_near_shrine():
			return true
	return false

func wallet() -> Dictionary:
	return scene._build_wallet_snapshot()

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

	# --- Data: every crest's third travel slot needs its mechanism and the clasp. ---
	for crest_id in build.catalog.crests:
		var spec: Dictionary = build.catalog.crests[crest_id].slot_layout.travel_accessory[2]
		check(String(spec.get("requires_mechanism", "")) == crest_id and String(spec.get("requires_part", "")) == "travel_clasp", crest_id + " third travel slot needs its mechanism and the clasp")
	build.unlock_event("repair_bell")
	build.unlock_event("charm_compass_found")
	check(build.switch_crest("bell").ok, "switch to the repaired bell crest")
	# 司铸 has no slot for the starting copper pot; the dormant pot leaves no usable
	# tool. That build is what the game saves, so a reload must accept it.
	check(String(build.state.equipped_families.tool[0]) == "shard" and not build._slot_accepts("tool", 0, "shard"), "fixture: the copper pot is dormant under the bell crest")
	check(scene._save_world(), "a build with no usable tool saves")
	var dormant = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	check(dormant is Dictionary and BUILD.new().restore(dormant.get("build_state", {})).ok, "and the same save loads again instead of pausing autosave")
	check(not build._slot_unlocked("travel_accessory", 2) and not build.equip_family_slot("compass", "travel_accessory", 2).ok, "a repaired crest alone no longer opens the third travel slot")
	var travel_slots: Array = build.get_snapshot().slot_layout.travel_accessory
	check(not bool(travel_slots[2].part_ready) and String(travel_slots[2].part_recipe) == "clasp_travel", "the locked slot names the clasp recipe")

	# --- Tool capacity: only the rain smith makes the trip-nail spring. ---
	build.unlock_event("tool_mine_found")
	scene.currency_count = 400
	scene.inventory_counts["wet_chitin"] = 3
	scene.inventory_counts["moss_chitin"] = 3
	scene.inventory_counts.erase("evidence_counterweight_echo")
	var base_capacity: int = build.tool_capacity("mine")
	check(base_capacity == int(build.catalog.tools.mine.capacity), "the trip nails start at their catalog capacity")
	var road: Dictionary = scene.perform_build_action("transact", "mod_mine")
	check(not road.get("ok", false) and String(road.get("reason", "")).contains("面对面"), "crafting needs an artisan in reach")
	check(await stand_at(CH02, "npc_rain_smith_liu"), "fixture stands beside the rain smith, away from a shrine")
	var before_build: Dictionary = build.serialize()
	var before_wallet := wallet()
	var wrong: Dictionary = scene.perform_build_action("transact", "mod_shard")
	check(not wrong.get("ok", false) and String(wrong.get("reason", "")).contains("织线学徒"), "the rain smith sends the copper pot to the thread apprentice")
	var no_pattern: Dictionary = scene.perform_build_action("transact", "mod_mine")
	check(not no_pattern.get("ok", false) and String(no_pattern.get("reason", "")).contains("图样") and String(no_pattern.get("reason", "")).contains("配重余响"), "without the counterweight evidence the smith has no pattern")
	check(build.serialize() == before_build and wallet() == before_wallet, "refused crafts change neither build nor wallet")

	scene.inventory_counts["evidence_counterweight_echo"] = 1
	player.hp = 3
	player.energy = 47
	scene.world_save_failure_injected_for_validation = true
	before_build = build.serialize()
	before_wallet = wallet()
	var unsaved: Dictionary = scene.perform_build_action("transact", "mod_mine")
	scene.world_save_failure_injected_for_validation = false
	check(not unsaved.get("ok", false) and String(unsaved.get("reason", "")).begins_with("归途记录未能写入"), "a craft that cannot be saved reports it")
	check(build.serialize() == before_build and wallet() == before_wallet and build.tool_capacity("mine") == base_capacity, "an unsaved craft rolls back capacity, shards and materials")
	check(player.hp == 3 and player.energy == 47, "an unsaved craft leaves HP and thread alone")

	var recipe: Dictionary = build.catalog.recipes.mod_mine
	var made: Dictionary = scene.perform_build_action("transact", "mod_mine")
	check(made.get("ok", false), "the rain smith makes the counterweight spring")
	check(scene.currency_count == int(before_wallet.currency) - int(recipe.currency) and int(scene.inventory_counts.get("wet_chitin", 0)) == 3 - int(recipe.materials.wet_chitin), "the craft spends shards and wet shells")
	check(int(scene.inventory_counts.get("evidence_counterweight_echo", 0)) == 1, "the evidence is only shown as a pattern and stays in the bag")
	check(build.tool_capacity("mine") == base_capacity + 1, "the trip nails carry one more")
	check(int(build.state.tool_counts.get("mine", 0)) == int(before_build.tool_counts.get("mine", 0)), "a bigger pouch comes empty: no free charge")
	build.state.tool_counts["mine"] = base_capacity
	check(int(build.get_snapshot().tool_deficits.mine) == 1 and int(build.quote_resupply({"currency": 50, "inventory_counts": {"wet_chitin": 5}}).charges.get("mine", 0)) == 1, "the extra charge is bought at the shrine like any other")
	var again: Dictionary = scene.perform_build_action("transact", "mod_mine")
	check(not again.get("ok", false) and String(again.get("reason", "")).contains("已经制作过"), "each piece is made once")

	# --- U02 page at the smith: crafts are listed with their maker and pattern. ---
	scene._toggle_build()
	await tick(3)
	var ui: Node = scene.ui_shell
	check(ui.build_category == "强化" and String(ui.build_summary.text).contains("改制战具"), "the artisan page offers 改制 beside 校习")
	var labels := {}
	var order: Array = []
	for button in ui.build_grid.get_children():
		if button is Button and button.has_meta("build_id"):
			labels[String(button.get_meta("build_id"))] = String(button.text)
			order.append(String(button.get_meta("build_id")))
	check(order.slice(0, 3) == ["mod_mine", "mod_lure", "clasp_travel"], "the smith's own crafts head the list")
	check(String(labels.get("mod_mine", "")).contains("已制作"), "the made spring is marked as made")
	check(String(labels.get("mod_shard", "")).contains("织线学徒") and String(labels.get("mod_shard", "")).contains("缺图样"), "another artisan's craft names its maker and the missing pattern")
	ui.build_selection = "clasp_travel"
	for entry in build.get_snapshot().recipes:
		if String(entry.id) == "clasp_travel":
			ui._show_build_detail(entry)
	check(String(ui.build_detail.text).contains("军墓灯影") and String(ui.build_detail.text).contains("第 3 个行旅铭饰槽") and String(ui.build_detail.text).contains("制作费用"), "the clasp detail previews its pattern, effect and cost")
	scene._close_overlays()
	await tick(2)

	# --- The clasp: the rain smith learns it from repairing the bell crest. ---
	scene.currency_count = 400
	scene.inventory_counts["obsidian_splinter"] = 3
	scene.inventory_counts["evidence_lantern_graves_echo"] = 1
	scene.story_flags.erase("seal_bell_repaired")
	before_build = build.serialize()
	var unrepaired: Dictionary = scene.perform_build_action("transact", "clasp_travel")
	check(not unrepaired.get("ok", false) and String(unrepaired.get("reason", "")).contains("铜徽章") and build.serialize() == before_build, "the clasp waits for the smith's badge repair")
	scene.story_flags["seal_bell_repaired"] = true
	scene.inventory_counts.erase("evidence_lantern_graves_echo")
	check(not scene.perform_build_action("transact", "clasp_travel").get("ok", false), "the clasp also needs the war-graves pattern")
	scene.inventory_counts["evidence_lantern_graves_echo"] = 1
	var clasp: Dictionary = scene.perform_build_action("transact", "clasp_travel")
	check(clasp.get("ok", false) and build.has_part("travel_clasp"), "the rain smith makes the travel clasp")
	check(int(scene.inventory_counts.get("obsidian_splinter", 0)) == 0, "the clasp spends obsidian splinters, which had no other use")
	check(build._slot_unlocked("travel_accessory", 2, "bell") and not build._slot_unlocked("travel_accessory", 2, "crimson"), "the clasp opens the slot only where the crest's mechanism is repaired")
	# Equipment changes happen at a shrine; the model is driven directly here.
	check(build.equip_family_slot("compass", "travel_accessory", 2).ok and build.state.passives.has("compass"), "the compass fits the newly opened third travel slot")

	# --- Save round trip. ---
	check(scene._save_world(), "the crafts save")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	var saved_build: Dictionary = saved.get("build_state", {}) if saved is Dictionary else {}
	check(Array(saved_build.get("crafted", [])) == ["mod_mine", "clasp_travel"], "the save lists both crafts")
	var reloaded := BUILD.new()
	saved_build.tool_counts.mine = base_capacity + 1
	check(reloaded.restore(saved_build).ok and reloaded.tool_capacity("mine") == base_capacity + 1 and reloaded.has_part("travel_clasp"), "a reload keeps the larger pouch, its full stock and the clasp")

	# --- Old saves: the slot they had stays theirs; nothing new is handed out. ---
	var legacy: Dictionary = saved_build.duplicate(true)
	legacy.erase("crafted")
	legacy.tool_counts.mine = base_capacity
	var migrated := BUILD.new()
	check(migrated.restore(legacy).ok and migrated.has_part("travel_clasp") and migrated.state.passives.has("compass"), "a save from before the clasp keeps its third travel slot and what is in it")
	check(migrated.tool_capacity("mine") == base_capacity, "an old save gains no capacity upgrade")
	var fresh_legacy: Dictionary = BUILD.new().serialize()
	fresh_legacy.erase("crafted")
	var fresh := BUILD.new()
	check(fresh.restore(fresh_legacy).ok and not fresh.has_part("travel_clasp"), "an old save with no repaired crest gets no clasp")
	var forged: Dictionary = saved_build.duplicate(true)
	forged.crafted = ["branch_cleave_a"]
	var guard := BUILD.new()
	var guard_before: Dictionary = guard.serialize()
	check(not guard.restore(forged).ok and guard.serialize() == guard_before, "a 校习 id cannot pose as a craft")
	forged.crafted = ["mod_mine", "mod_mine"]
	check(not guard.restore(forged).ok, "a duplicated craft is rejected")
	var overstock: Dictionary = legacy.duplicate(true)
	overstock.tool_counts.mine = base_capacity + 1
	check(not BUILD.new().restore(overstock).ok, "stock above capacity is rejected without the upgrade")

	await preload("res://scripts/proof_crafts_validation.gd").new().run(self)
	scene._close_overlays()
	AUDIO.retire_tree(scene)
	scene.queue_free()
	await tick(6)
	check(await AUDIO.drain(self), "the fixture releases playback")
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
	print("ARTISAN_CRAFTS checks=%d failures=%d" % [checks, failures])
	quit(1 if failures > 0 else 0)
