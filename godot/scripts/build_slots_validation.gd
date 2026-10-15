extends SceneTree
const BUILD := preload("res://scripts/build_system.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	var build := BUILD.new()
	var initial := build.get_snapshot()
	_check(initial.slot_layout.keys().size() == 4 and initial.slot_families.size() == 4, "snapshot exposes four functional families")
	for family in ["tool", "combat_accessory", "travel_accessory", "thread_skill"]:
		_check(initial.slot_layout.has(family) and not initial.slot_layout[family].is_empty(), "layout includes " + family)
		for slot in initial.slot_layout[family]:
			_check(slot.has("id") and slot.family == family and slot.has("index") and slot.has("compatible") and slot.has("unlocked") and slot.has("equipped_id"), "slot snapshot contract " + family)
	_check(not initial.slot_layout.tool[1].unlocked, "rare tool expansion begins locked")
	_check(not build.equip_family_slot("mine", "tool", 1).ok, "locked expansion rejects equip")
	var before := build.serialize()
	_check(not build.equip_family_slot("cleave", "tool", 0).ok and build.serialize() == before, "incompatible equip is atomic")
	_check(build.cycle_tool().ok and build.state.active_tool_slot == 0, "road cycle skips locked and empty slots")
	build.sync_progress({}, "", {"quest_bring_names_complete": true, "seal_bell_repaired": true})
	for id in ["skill_needle_learned", "skill_snare_learned", "skill_ward_learned", "skill_shockwave_learned", "skill_crosscut_learned", "tool_mine_found", "tool_fog_found", "tool_lure_found", "charm_shell_found", "charm_reflux_found", "charm_mender_found", "charm_spur_found", "charm_needlecase_found"]:
		_check(build.unlock_event(id).ok, "unlock " + id)
	_check(build.select_tool("mine", 1).ok, "unlocked tool family slot accepts compatible item")
	_check(not build.select_tool("shard", 1).ok, "family compatibility rejects a wrong tool")
	_check(build.select_skill("needle", 1).ok and build.select_skill("cleave", 1).ok == false, "skill slot enforces no duplicate")
	_check(build.equip_family_slot("shell", "combat_accessory", 0).ok, "combat accessory can be equipped")
	_check(build.equip_family_slot("stride", "travel_accessory", 0).ok, "travel accessory can be equipped")
	var conflict := build.serialize()
	_check(not build.equip_family_slot("needlecase", "combat_accessory", 0).ok and build.serialize() == conflict, "wrong accessory family fails atomically")
	build.state.tool_counts.shard = 0
	var saved := build.serialize()
	var restarted := BUILD.new()
	_check(restarted.restore(saved).ok and restarted.serialize() == saved, "v3 family layout roundtrips exactly")
	var tampered := saved.duplicate(true)
	tampered.equipped_families.tool[1] = "shard"
	tampered.tools[1] = "shard"
	tampered.tool = "shard"
	var restart_before := restarted.serialize()
	_check(not restarted.restore(tampered).ok and restarted.serialize() == restart_before, "tampered family compatibility rejected transactionally")
	var v2: Dictionary = saved.duplicate(true)
	v2.version = 2
	v2.erase("equipped_families")
	var migrated := BUILD.new()
	_check(migrated.restore(v2).ok and migrated.state.version == 3, "v2 aliases migrate to the family schema")
	var wallet := {"currency": 5, "inventory_counts": {"moss_chitin": 1}}
	var wallet_before := wallet.duplicate(true)
	var quote := build.quote_resupply(wallet)
	_check(quote.ok and quote.charges.get("shard", 0) == 1 and quote.cost.currency == 4, "quote exposes partial tool refill cost")
	_check(build.serialize() == saved and wallet == wallet_before, "quote does not mutate stock or wallet")
	var purchase := build.resupply_tools(wallet, true)
	_check(purchase.ok and build.state.tool_counts.shard == int(saved.tool_counts.shard) + 1 and purchase.wallet.currency == 1, "purchase adds only paid charges")
	var stock: Dictionary = build.state.tool_counts.duplicate(true)
	var cooldowns: Dictionary = build.cooldowns.duplicate(true)
	_check(build.switch_crest("bell").ok and build.state.tool_counts == stock and build.cooldowns == cooldowns, "crest reconfiguration does not refresh stock or cooldown")
	_check(build.equip_family_slot("cleave", "thread_skill", 0, false).ok == false, "full family edit remains shrine-only")
	if failures.is_empty():
		print("BUILD SLOTS PASS: %d checks" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
