extends SceneTree
const BUILD := preload("res://scripts/build_system.gd")
const WORLD := preload("res://scripts/world_state.gd")
var failures: Array[String] = []

func _initialize() -> void:
    var build := BUILD.new()
    _check(build.catalog.crests.size() == 3 and build.catalog.skills.size() == 4, "three crests and four distinct skill roles")
    _check(build.state.unlocked_skills == ["cleave"], "new run begins with one skill, discoveries unlock others")
    _check(not build.select_skill("needle").ok, "locked skill cannot be selected")
    var before := build.serialize()
    _check(not build.try_cast(0).ok and build.serialize() == before, "failed cast does not spend or start cooldown")
    var cast := build.try_cast(100)
    _check(cast.ok and cast.energy_cost == 30 and cast.kind == "melee", "melee cast returns execution contract")
    _check(not build.try_cast(100).ok, "cooldown blocks repeated cast")
    build.tick(0.5)
    var during_cooldown := build.serialize()
    var cooling := BUILD.new()
    _check(cooling.restore(JSON.parse_string(JSON.stringify(during_cooldown))).ok and not cooling.try_cast(100).ok, "cooldown survives save reload")
    build.tick(2.0)
    _check(build.try_cast(100).ok, "cooldown completes")
    build.sync_progress({"silk_wall_grip": 1, "echo_hook": 1, "bell_guard": 1}, "salt")
    _check(build.state.unlocked_skills.size() == 4 and build.state.unlocked_crests.size() == 3, "exploration unlocks all roles and crests")
    for id in ["needle", "snare", "ward"]:
        _check(build.select_skill(id).ok and build.try_cast(100).ok, "independent skill cast " + id)
    _check(not build.switch_crest("bell", false).ok, "crest switch requires bell")
    _check(build.switch_crest("bell").ok and build.profile().heal_amount == 2 and build.profile().max_hp == 6, "bell changes heal and survivability")
    _check(build.switch_crest("salt").ok and build.profile().max_energy == 120 and build.selected_skill().energy_cost == 32, "salt creates energy tradeoff")
    var wallet := {"currency": 200, "inventory_counts": {"moss_chitin": 2, "echo_hook": 1}}
    var wallet_before := wallet.duplicate(true)
    var purchase := build.transact("craft_shell", wallet)
    _check(purchase.ok and purchase.wallet.currency == 180 and purchase.wallet.inventory_counts.moss_chitin == 1, "atomic craft deducts correct materials")
    _check(wallet == wallet_before and purchase.wallet.inventory_counts.echo_hook == 1, "external wallet and abilities untouched")
    before = build.serialize()
    _check(not build.transact("craft_shell", purchase.wallet).ok and build.serialize() == before, "duplicate ownership cannot charge again")
    _check(not build.transact("buy_reflux", {"currency": 0, "inventory_counts": {}}).ok and build.serialize() == before, "insufficient balance is atomic")
    _check(build.transact("buy_reflux", wallet).ok and build.transact("buy_spur", wallet).ok, "alternate energy passives acquired")
    _check(not build.equip_passives(["reflux", "spur"]).ok, "mutually exclusive energy items rejected")
    _check(not build.equip_passives(["stride", "stride"]).ok, "duplicate passive rejected")
    _check(not build.equip_passives(["shell", "reflux"]).ok, "slot overflow rejected")
    _check(build.equip_passives(["shell", "stride"]).ok, "valid mixed passive build")
    var stats := build.profile()
    _check(is_equal_approx(float(stats.move_mult), 1.03) and stats.max_hp == 5, "passive modifiers accumulate once")
    _check(build.profile() == stats and build.profile() == stats, "repeated reads do not multiply stats")
    _check(build.save_loadout("探索").ok, "loadout saved")
    _check(build.switch_crest("bell").ok and build.equip_passives([]).ok, "alternate crest clears slots")
    _check(build.restore_loadout("探索").ok and build.state.crest == "salt" and build.state.passives == ["shell", "stride"], "loadout restores exact state")
    _check(build.select_skill("needle").ok, "select upgrade target")
    var level_zero := build.selected_skill()
    _check(build.transact("upgrade_needle", wallet).ok and build.selected_skill().pierce == 2 and build.selected_skill().range > level_zero.range, "skill upgrade changes use")
    _check(build.transact("upgrade_needle", wallet).ok and not build.transact("upgrade_needle", wallet).ok, "skill cap prevents repeated charge")
    _check(build.select_tool("shard").ok, "select active tool")
    for unused in range(3):
        _check(build.use_tool().ok, "each tool use consumes count")
    _check(not build.use_tool().ok and build.state.tool_counts.shard == 0, "empty tool rejects use")
    _check(build.transact("refill_shard", wallet).ok and build.state.tool_counts.shard == 3, "merchant refill restores finite stock")
    _check(build.transact("refill_shard", wallet).ok and not build.transact("refill_shard", wallet).ok, "full stock prevents waste purchase")
    var world := WORLD.new()
    _check(world.capture_global({"build_state": build.serialize()}), "live build keys satisfy strict world JSON validator")
    var restart := BUILD.new()
    var json_snapshot: Variant = JSON.parse_string(JSON.stringify(build.serialize()))
    _check(restart.restore(json_snapshot).ok and restart.serialize() == build.serialize(), "pure JSON state roundtrip")
    var corrupt: Dictionary = build.serialize()
    corrupt.tool_counts.shard = -1
    before = restart.serialize()
    _check(not restart.restore(corrupt).ok and restart.serialize() == before, "invalid restore preserves live state")
    corrupt = build.serialize()
    corrupt.skill_levels.needle = 1.5
    _check(not restart.restore(corrupt).ok, "fractional upgrade rejected")
    corrupt = build.serialize()
    corrupt.passives = ["stride", "stride"]
    _check(not restart.restore(corrupt).ok, "malformed duplicate equipment rejected")
    corrupt = build.serialize()
    corrupt.cooldowns = {"ward": -1}
    _check(not restart.restore(corrupt).ok, "negative cooldown rejected")
    var snapshot := build.get_snapshot()
    _check(snapshot.crests.size() == 3 and snapshot.skills.size() == 4 and snapshot.tools.size() == 2 and snapshot.passive_options.size() == 5 and snapshot.recipes.size() == 10, "UI catalog exposes all actionable content")
    if failures.is_empty():
        print("BUILD SYSTEM PASS: discovery, crests, casting, cooldown persistence, equipment constraints, merchant transactions, upgrades, tools, loadouts and corrupted saves")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)

func _check(condition: bool, label: String) -> void:
    if not condition:
        failures.append(label)
