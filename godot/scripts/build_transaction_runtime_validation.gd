extends SceneTree
## Exercises real World actions and a failed disk commit without mutating user saves.
const WORLD_SCENE := preload("res://scenes/World.tscn")
const SAVE_PATH := "user://build_transaction_runtime_validation.json"
var scene: Node
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	scene = WORLD_SCENE.instantiate()
	scene.world_resume = false
	scene.world_save_path = SAVE_PATH
	root.add_child(scene)
	current_scene = scene
	await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
	_check(scene.initial_region_ready, "initial World publishes before shrine transaction checks")
	if not scene.initial_region_ready:
		_finish()
		return
	var build: RefCounted = scene.build_system
	var player: CharacterBody2D = scene.player
	var shrine: Area2D = _find_area("save_point", "")
	_check(shrine != null, "real world contains a shrine")
	if shrine == null:
		_finish()
		return

	# Real rest heals the player and thread, but never fills tool stock.
	player.global_position = shrine.global_position
	player.hp = maxi(1, player.max_hp - 2)
	player.energy = maxi(0, player.max_energy - 31)
	for tool_id in build.state.tool_counts:
		build.state.tool_counts[tool_id] = 0
	build.cooldowns["cleave"] = 2.75
	var stock_before_rest: Dictionary = build.state.tool_counts.duplicate(true)
	scene._activate_save_point(shrine)
	_check(player.hp == player.max_hp and player.energy == player.max_energy, "shrine rest restores HP and thread")
	_check(build.state.tool_counts == stock_before_rest, "shrine rest does not refill any tool stock")
	_check(is_equal_approx(float(build.cooldowns.get("cleave", 0.0)), 2.75), "shrine rest preserves skill cooldown")

	# The quote is explicit and can only be requested at the shrine. Five coins
	# plus one resin shell afford one shard charge; the next tool costs more.
	var far_position := player.global_position + Vector2(600, 0)
	player.global_position = far_position
	_check(not scene.perform_build_action("quote_resupply").get("ok", false), "road cannot open a resupply quote")
	_check(not scene.perform_build_action("select_tool", "shard", 0).get("ok", false), "road cannot reconfigure tool slots")
	_check(scene.perform_build_action("cycle_tool").get("ok", false), "road can cycle equipped tools")
	player.global_position = shrine.global_position
	scene.currency_count = 5
	scene.inventory_counts["moss_chitin"] = 1
	var pre_purchase_stock: Dictionary = build.state.tool_counts.duplicate(true)
	var partial_quote: Dictionary = scene.perform_build_action("quote_resupply")
	var partial_charges := _total(partial_quote.get("charges", {}))
	_check(partial_quote.get("ok", false) and partial_charges == 1 and int(partial_quote.charges.get("shard", 0)) == 1,
		"limited funds receive a one-charge partial quote")
	var purchase_currency := int(scene.currency_count)
	var purchase_cost := int(partial_quote.get("cost", {}).get("currency", 0))
	var purchase: Dictionary = scene.perform_build_action("resupply_tools")
	_check(purchase.get("ok", false), "confirmed partial resupply succeeds")
	_check(scene.currency_count == purchase_currency - purchase_cost and purchase_cost == 4 and scene.currency_count == 1,
		"partial resupply charges the exact quoted wallet cost")
	_check(int(scene.inventory_counts.get("moss_chitin", 0)) == 0, "partial resupply consumes its quoted material")
	var charged: Dictionary = partial_quote.get("charges", {})
	for tool_id in charged:
		_check(int(build.state.tool_counts.get(tool_id, 0)) == int(pre_purchase_stock.get(tool_id, 0)) + int(charged[tool_id]),
			"paid resupply grants exactly quoted %s charges" % String(tool_id))
		_check(int(build.state.tool_counts[tool_id]) <= build.tool_capacity(String(tool_id)),
			"paid resupply respects %s capacity" % String(tool_id))

	# Inject failure at the World's storage boundary after state capture. This
	# exercises the production transaction path without provoking an OS rename error.
	var artisan := _find_area("npc", "npc_threadsmith_apprentice")
	_check(artisan != null, "real artisan exists for crafting")
	if artisan != null:
		player.global_position = artisan.global_position
		player.hp = 3
		player.energy = 47
		player.skill_cooldown = 1.25
		build.cooldowns["cleave"] = 2.75
		scene.currency_count = 100
		scene.world_save_failure_injected_for_validation = true
		var build_before: Dictionary = build.serialize()
		var wallet_before: Dictionary = scene._build_wallet_snapshot()
		var result: Dictionary = scene.perform_build_action("transact", "upgrade_cleave")
		_check(not result.get("ok", false) and String(result.get("reason", "")).begins_with("归途记录未能写入"),
			"valid craft reaches and reports failed persistence")
		_check(int(build_before.skill_levels.get("cleave", 0)) == 0 and int(wallet_before.currency) == 100,
			"craft failure fixture starts with an affordable, unapplied upgrade")
		_check(build.serialize() == build_before, "failed craft rolls back build progress and cooldowns")
		_check(scene.currency_count == wallet_before.currency and scene.inventory_counts == wallet_before.inventory_counts,
			"failed craft rolls back the complete wallet")
		_check(player.hp == 3 and player.energy == 47 and is_equal_approx(player.skill_cooldown, 1.25),
			"failed craft preserves HP, thread, and player cooldown")

	# The same durability boundary applies to paid resupply and tool use.
	player.global_position = shrine.global_position
	for tool_id in build.state.tool_counts:
		build.state.tool_counts[tool_id] = 0
	scene.currency_count = 5
	scene.inventory_counts["moss_chitin"] = 1
	var failure_quote: Dictionary = scene.perform_build_action("quote_resupply")
	var failure_build_before: Dictionary = build.serialize()
	var failure_wallet_before: Dictionary = scene._build_wallet_snapshot()
	var failed_supply: Dictionary = scene.perform_build_action("resupply_tools")
	_check(failure_quote.get("ok", false) and int(failure_quote.get("charges", {}).get("shard", 0)) == 1
		and not failed_supply.get("ok", false)
		and String(failed_supply.get("reason", "")).begins_with("归途记录未能写入"),
		"valid paid supply reaches and rolls back on failed save")
	_check(build.serialize() == failure_build_before, "failed supply grants no tools and preserves cooldowns")
	_check(scene.currency_count == failure_wallet_before.currency and scene.inventory_counts == failure_wallet_before.inventory_counts,
		"failed supply preserves wallet resources")
	_check(player.hp == 3 and player.energy == 47 and is_equal_approx(player.skill_cooldown, 1.25),
		"failed supply preserves HP, thread, and player cooldown")

	# A tool effect must not spawn until its consumed charge is durable. The
	# injected failure must leave both stock and action recovery exactly intact.
	build.state.tool_counts["shard"] = 1
	var tool_stock_before := int(build.state.tool_counts.shard)
	var tool_state_before: Dictionary = build.serialize()
	var effect_count_before := _tool_effect_count()
	var tool_attack_timer_before := float(player.attack_timer)
	var tool_skill_cooldown_before := float(player.skill_cooldown)
	var failed_use: Dictionary = scene.perform_build_action("use_tool")
	_check(not failed_use.get("ok", false) and String(failed_use.get("reason", "")).begins_with("归途记录未能写入"),
		"failed tool use reports persistence failure before casting")
	_check(build.serialize() == tool_state_before and int(build.state.tool_counts.shard) == tool_stock_before,
		"failed tool use preserves stock and build cooldown state")
	_check(_tool_effect_count() == effect_count_before, "failed tool use creates no effect node")
	_check(is_equal_approx(float(player.attack_timer), tool_attack_timer_before)
		and is_equal_approx(float(player.skill_cooldown), tool_skill_cooldown_before),
		"failed tool use preserves player recovery timers")
	scene.world_save_failure_injected_for_validation = false
	var successful_use: Dictionary = scene.perform_build_action("use_tool")
	_check(successful_use.get("ok", false), "tool use succeeds after persistence is available")
	_check(int(build.state.tool_counts.shard) == tool_stock_before - 1
		and _tool_effect_count() == effect_count_before + 1,
		"successful tool use spends exactly one charge for one effect")

	_finish()

func _find_area(kind: String, id: String) -> Area2D:
	for child in scene.get_children():
		if not child is Area2D or String(child.get_meta("kind", "")) != kind:
			continue
		if id.is_empty() or String(child.get_meta("npc_id", child.name)) == id:
			return child
	return null

func _total(values: Variant) -> int:
	if not values is Dictionary:
		return 0
	var total := 0
	for value in values.values():
		total += int(value)
	return total

func _tool_effect_count() -> int:
	var total := 0
	for child in scene.get_children():
		if child is Node2D and child.get_script() != null and child.get_script().resource_path == "res://scripts/player_tool_effect.gd":
			total += 1
	return total

func _frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("FAILED: " + label)

func _finish() -> void:
	if scene != null and is_instance_valid(scene):
		scene.queue_free()
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		var path: String = SAVE_PATH + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if failures.is_empty():
		print("BUILD TRANSACTION RUNTIME PASS: %d checks, real shrine, paid partial resupply and failed-save rollback" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
