extends SceneTree
const BUILD := preload("res://scripts/build_system.gd")
const WORLD := preload("res://scripts/world_state.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
    var build := BUILD.new()
    _check(build.catalog.crests.size() == 3 and build.catalog.skills.size() == 6 and build.catalog.tools.size() == 4, "three seals, six skills and four tools")
    _check(build.state.skills == ["cleave", ""] and build.state.tools == ["shard", ""], "two slots with explicit empty slot")
    _check(not build.select_skill("needle").ok and not build.select_tool("fog").ok, "locked content rejected")
    var before := build.serialize()
    build.sync_progress({"echo_hook": 1, "silk_wall_grip": 1, "bell_guard": 1}, "ch06_salt")
    _check(build.serialize() == before, "exploration abilities and regions never grant equipment")
    _check(not build.try_cast(0).ok and build.serialize() == before, "failed cast cannot spend/start cooldown")
    var cast := build.try_cast(100)
    _check(cast.ok and cast.energy_cost == 25 and cast.kind == "thrust", "thrust contract")
    _check(not build.try_cast(100).ok, "independent cooldown blocks repeat")
    var restart := BUILD.new()
    _check(restart.restore(JSON.parse_string(JSON.stringify(build.serialize()))).ok and not restart.try_cast(100).ok, "cooldown persists on restart")
    build.tick(2.1)
    _check(build.try_cast(100).ok, "cooldown expires")
    build.sync_progress({}, "", {"quest_bring_names_complete": true, "seal_bell_repaired": true, "seal_salt_restored": true})
    _check(build.state.mechanisms.size() == 3 and build.state.unlocked_crests.size() == 3, "narrative repair grants mechanisms")
    for id in build.catalog.skills:
        _check(build.unlock_event("skill_" + id + "_learned").ok, "skill event " + id)
    for id in build.catalog.tools:
        _check(build.unlock_event("tool_" + id + "_found").ok, "tool event " + id)
    for id in build.catalog.passives:
        _check(build.unlock_event("charm_" + id + "_found").ok, "charm event " + id)
    _check(build.select_skill("needle", 1).ok and build.state.skills == ["cleave", "needle"], "equip second skill")
    _check(not build.select_skill("cleave", 1).ok, "duplicate skill rejected")
    _check(build.cycle_skill().ok and build.state.skill == "cleave", "cycle preserves active alias")
    _check(build.select_tool("mine", 1).ok and build.cycle_tool().ok and build.state.tool == "shard", "two tools and active alias")
    _check(not build.refill_tools(false).ok, "refill requires shrine")
    var stock_before_rest: Dictionary = build.state.tool_counts.duplicate(true)
    _check(not build.refill_tools(true).ok and build.state.tool_counts == stock_before_rest, "legacy refill cannot create free stock")
    before = build.serialize()
    _check(not build.switch_crest("bell", false).ok and build.serialize() == before, "switch cannot occur away from shrine")
    for id in ["crimson", "bell", "salt"]:
        _check(build.switch_crest(id).ok, "seal switch " + id)
        var stats := build.profile()
        var crest: Dictionary = build.catalog.crests[id]
        _check(stats.max_hp == 5 and stats.max_energy == 100 and stats.heal_amount == crest.heal_amount and stats.heal_cost == crest.heal_cost and stats.heal_duration == crest.heal_duration and stats.heal_airborne == bool(crest.get("heal_airborne", false)), "seal heal comes from its own catalog row " + id)
        _check(build.state.tool_counts == before.tool_counts and build.cooldowns == before.cooldowns, "switch does not refresh stock/cooldown " + id)
    _check(build.equip_passives(["shell", "stride"]).ok, "capacity valid")
    var stats := build.profile()
    _check(stats.max_hp == 5 and stats.max_energy == 100 and is_equal_approx(stats.move_mult, 1.08) and is_equal_approx(stats.heal_duration, float(build.catalog.crests[build.state.crest].heal_duration) * 1.15) and stats.knockback_mult < 1, "charm benefit and drawback")
    _check(build.profile() == stats and build.profile() == stats, "profile idempotent")
    _check(not build.equip_passives(["stride", "stride"]).ok and not build.equip_passives(["reflux", "spur"]).ok, "duplicate and capacity rejection")
    _check(build.save_loadout("记名").ok, "save dual-slot build")
    var stock: Dictionary = build.state.tool_counts.duplicate(true)
    var cds := build.cooldowns.duplicate(true)
    _check(build.switch_crest("bell").ok and build.equip_passives([]).ok and build.restore_loadout("记名").ok, "restore exact build")
    _check(build.state.skills == ["cleave", "needle"] and build.state.passives == ["shell", "stride"] and stock == build.state.tool_counts and cds == build.cooldowns, "loadout preserves stock/CD")
    var wallet := {"currency": 200, "inventory_counts": {"echo_hook": 1}}
    var wallet_before := wallet.duplicate(true)
    _check(build.switch_crest("crimson").ok, "return to a crest whose open skill slot accepts needle")
    _check(build.select_skill("needle", 1).ok, "upgrade target")
    var zero := build.selected_skill()
    var purchase := build.transact("upgrade_needle", wallet)
    _check(purchase.ok and purchase.wallet.currency == 200 - int(build.catalog.recipes.upgrade_needle.currency) and wallet == wallet_before, "upgrade atomic wallet charges the catalog price")
    _check(build.selected_skill().pierce == 1 and build.selected_skill().range > zero.range, "upgrade remains single target")
    _check(build.transact("upgrade_needle", wallet).ok and not build.transact("upgrade_needle", wallet).ok, "upgrade cap")
    _check(build.select_tool("shard", 0).ok, "select tool")
    for unused in range(3):
        _check(build.use_tool().ok, "finite tool consumption")
    _check(not build.use_tool().ok and build.state.tool_counts.shard == 0, "no infinite tools")
    before = build.serialize()
    _check(not build.transact("refill_shard", wallet).ok and build.serialize() == before, "refill is not a crafting recipe")
    _check(build.equip_passives(["needlecase"]).ok and build.state.tool_counts.shard == 0, "capacity increase never adds stock")
    var broke := {"currency": 3, "inventory_counts": {"moss_chitin": 1}}
    var broke_before := build.serialize()
    var broke_quote := build.quote_resupply(broke)
    _check(not broke_quote.ok and broke_quote.charges.is_empty() and build.serialize() == broke_before and broke.currency == 3, "unaffordable supply quote has no side effects")
    var partial_wallet := {"currency": 5, "inventory_counts": {"moss_chitin": 1}}
    var partial_quote := build.quote_resupply(partial_wallet)
    _check(partial_quote.ok and partial_quote.charges == {"shard": 1} and partial_quote.cost == {"currency": 4, "materials": {"moss_chitin": 1}}, "preview offers only one affordable shard charge")
    var off_bell := build.resupply_tools(partial_wallet, false)
    _check(not off_bell.ok and build.state.tool_counts.shard == 0 and partial_wallet.currency == 5, "road supply rejected without mutation")
    var partial_purchase := build.resupply_tools(partial_wallet, true)
    _check(partial_purchase.ok and partial_purchase.wallet.currency == 1 and partial_purchase.wallet.inventory_counts.moss_chitin == 0 and build.state.tool_counts.shard == 1, "paid partial purchase commits exact costs and stock")
    _check(build.state.tool_counts.mine == 0 and build.state.tool_counts.fog == 0, "partial wallet cannot refill unaffordable tools")
    _check(build.equip_passives([]).ok and build.state.tool_counts.shard == 1, "unequip leaves paid stock unchanged")
    var world := WORLD.new()
    _check(world.capture_global({"build_state": build.serialize()}), "strict global JSON captures build")
    var roundtrip: Dictionary = restart.restore(JSON.parse_string(JSON.stringify(build.serialize())))
    _check(roundtrip.ok and restart.serialize() == build.serialize(), "v3 exact JSON roundtrip")
    for corrupt_kind in ["negative", "fractional", "duplicate", "cooldown", "unknown", "alias"]:
        var corrupt := build.serialize()
        match corrupt_kind:
            "negative": corrupt.tool_counts.shard = -1
            "fractional": corrupt.skill_levels.needle = 1.5
            "duplicate": corrupt.passives = ["stride", "stride"]
            "cooldown": corrupt.cooldowns = {"ward": -1}
            "unknown": corrupt.unlocked_skills.append("unknown_skill")
            "alias": corrupt.skill = "snare"
        before = restart.serialize()
        _check(not restart.restore(corrupt).ok and restart.serialize() == before, "transactional corruption rejection " + corrupt_kind)
    var snapshot := build.get_snapshot()
    _check(snapshot.skills.size() == 6 and snapshot.tools.size() == 4 and snapshot.passive_options.size() == build.catalog.passives.size() and snapshot.recipes.size() == 6, "full UI catalog")
    _check(snapshot.skills_equipped == ["cleave", "needle"] and snapshot.skills[1].equipped_slots == [1], "UI equipped positions")
    if failures.is_empty():
        print("BUILD SYSTEM PASS: %d checks" % checks)
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)

func _check(condition: bool, label: String) -> void:
    checks += 1
    if not condition:
        failures.append(label)
