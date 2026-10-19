extends SceneTree
const BUILD := preload("res://scripts/build_system.gd")
var failures: Array[String] = []
var checks := 0
func _initialize() -> void:
    var build := BUILD.new()
    var legacy := {"version": 1, "crest": "bell", "skill": "needle", "tool": "mine", "passives": ["shell"], "unlocked_crests": ["crimson", "bell", "salt"], "unlocked_skills": ["cleave", "needle", "snare", "ward"], "unlocked_passives": ["stride", "shell"], "tool_counts": {"shard": 5, "mine": 1}, "skill_levels": {"cleave": 0, "needle": 2, "snare": 0, "ward": 0}, "loadouts": {"旧配装": {"crest": "bell", "skill": "needle", "tool": "mine", "passives": ["shell"]}}, "cooldowns": {"needle": 1.6}}
    _check(build.restore(legacy).ok, "valid legacy migration")
    _check(build.state.version == 3 and build.state.skills == ["needle", ""] and build.state.tools == ["mine", ""], "legacy slots migrated into family schema")
    _check(build.state.tool_counts == {"shard": 3, "mine": 1, "fog": 0, "lure": 0}, "migration clamps downward no refill")
    _check(build.cooldowns.needle == 1.6 and build.state.skill_levels.needle == 2 and build.state.mechanisms.is_empty(), "legacy preserves levels/CD without inventing narrative")
    _check(build.restore_loadout("旧配装").ok and not build.try_cast(100).ok, "legacy preset keeps cooldown")
    var before := build.serialize()
    var bad := legacy.duplicate(true)
    bad.tool_counts.mine = -1
    _check(not build.restore(bad).ok and build.serialize() == before, "invalid v1 rollback")
    bad = legacy.duplicate(true)
    bad.skill = "unknown"
    _check(not build.restore(bad).ok and build.serialize() == before, "unknown v1 ID rejected")
    var fresh := BUILD.new()
    _check(not fresh.profile().crimson_repaired, "initial crimson no exclusive mechanism")
    fresh.sync_progress({}, "", {"quest_bring_names_complete": true})
    _check(fresh.profile().crimson_repaired, "side quest repairs initial mechanism")
    _check(not fresh.unlock_event("unrecognized").ok, "unknown event no grant")
    fresh.unlock_event("tool_mine_found")
    _check(fresh.state.tool_counts.mine == 0, "discovery does not create free stock away from shrine")
    _check(not fresh.refill_tools(true).ok and fresh.state.tool_counts.mine == 0, "shrine no longer gives free tool stock")
    var mine_price := int(fresh.catalog.tools.mine.resupply.currency)
    var supply := fresh.resupply_tools({"currency": mine_price, "inventory_counts": {"wet_chitin": 1}}, true)
    _check(supply.ok and fresh.state.tool_counts.mine == 1 and supply.wallet.currency == 0 and supply.wallet.inventory_counts.wet_chitin == 0,
        "paid mine resupply spends its renewable material and currency")
    fresh.select_tool("mine", 1)
    fresh.use_tool(1)
    _check(fresh.state.tool_counts.mine == 0 and fresh.state.tool_counts.shard == 3, "slot-specific consumption keeps paid stock finite")
    fresh.unlock_event("skill_needle_learned")
    fresh.select_skill("needle", 1)
    _check(fresh.try_cast(20, 1).ok and fresh.try_cast(25, 0).ok, "independent dual skill cooldown")
    var save := fresh.serialize()
    var restart := BUILD.new()
    var restored: Dictionary = restart.restore(JSON.parse_string(JSON.stringify(save)))
    _check(restored.ok and restart.serialize() == save, "family-schema restart exact")
    if failures.is_empty():
        print("SEAL SYSTEM PASS: %d checks" % checks)
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)
func _check(condition: bool, label: String) -> void:
    checks += 1
    if not condition:
        failures.append(label)
