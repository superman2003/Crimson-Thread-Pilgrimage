extends SceneTree
const BUILD = preload("res://scripts/build_system.gd")
const PLANNER = preload("res://scripts/resupply_planner.gd")
var checks := 0
var failures: Array[String] = []
var purchases := 0

func _initialize() -> void:call_deferred("run")

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:failures.append(label)

func fresh() -> RefCounted:
    var build := BUILD.new()
    for event in ["tool_mine_found", "tool_fog_found", "tool_lure_found"]:build.unlock_event(event)
    for id in build.state.tool_counts:build.state.tool_counts[id] = 0
    return build

func wallet(coins: int = 100) -> Dictionary:
    return {"currency": coins, "inventory_counts": {"moss_chitin": 10, "wet_chitin": 10, "salt_crystal_shard": 10, "pollen_wax": 10}}

func run() -> void:
    var build := fresh()
    var money := wallet(10)
    var before: Dictionary = build.serialize()
    var original := money.duplicate(true)
    var request := {"order": ["mine", "shard"], "limits": {"mine": 2, "shard": 2}}
    var quote: Dictionary = build.quote_resupply(money, request)
    check(quote.ok and quote.charges == {"mine": 2}, "shared currency follows player priority rather than catalog order")
    check(quote.cost == {"currency": 10, "materials": {"wet_chitin": 2}}, "chosen purchases carry exact materials and currency")
    check(quote.unfilled.shard == 2 and quote.unfilled.mine == 0, "partial quote explains requested units it cannot fill")
    check(build.serialize() == before and money == original, "quote is detached from stock and wallet")
    check(request == {"order": ["mine", "shard"], "limits": {"mine": 2, "shard": 2}}, "normalization does not mutate caller order or limits")
    var reversed: Dictionary = build.quote_resupply(money, {"order": ["shard", "mine"], "limits": request.limits})
    check(reversed.charges == {"shard": 2} and reversed.cost.currency == 8, "changing priority changes the affordable shopping list")
    var selected: Dictionary = build.quote_resupply(wallet(), {"limits": {"lure": 1}})
    check(selected.charges == {"lure": 1}, "explicit selection never buys other owned tools")
    var legacy: Dictionary = build.quote_resupply(wallet())
    check(legacy.charges.size() == 4, "empty default plan preserves legacy automatic refill")
    check(not build.quote_resupply(wallet(), {"limits": {}}).ok, "empty explicit list grants nothing")
    check(not build.quote_resupply(wallet(), {"limits": {"shard": 0}}).ok, "zero quantity skips a tool")
    for invalid in [null, [], {"order": "mine"}, {"order": ["mine", "mine"]}, {"order": ["unknown"]}, {"order": [true]},
        {"limits": []}, {"limits": {"unknown": 1}}, {"limits": {"mine": -1}}, {"limits": {"mine": 0.5}},
        {"limits": {"mine": true}}, {"limits": {"mine": "2"}}, {"limits": {"mine": NAN}}, {"limits": {"mine": INF}},
        {"limits": {"mine": 101}}, {"free": true}]:
        check(not build.quote_resupply(wallet(), invalid).ok and build.serialize() == before, "malformed request rejects atomically: " + str(invalid))
    var locked := BUILD.new()
    check(not locked.quote_resupply(wallet(), {"limits": {"mine": 1}}).ok, "unobtained tools cannot be ordered")
    check(not locked.quote_resupply(wallet(), {"order": ["mine"]}).ok, "priority cannot reveal an unowned tool")
    var dry := wallet()
    dry.inventory_counts.wet_chitin = 0
    var material_limited: Dictionary = build.quote_resupply(dry, request)
    check(material_limited.charges == {"shard": 2}, "unaffordable high-priority material does not block later selected tools")
    check(not build.resupply_tools(wallet(), false, request).ok and build.serialize() == before, "purchase remains shrine-only")
    var purchase: Dictionary = build.resupply_tools(money, true, request)
    check(purchase.ok and purchase.wallet.currency == 0 and build.state.tool_counts.mine == 2, "purchase applies the exact selected quote")
    check(build.state.tool_counts.shard == 0 and money == original, "purchase grants no unselected stock and leaves caller wallet detached")
    var restarted := BUILD.new()
    check(restarted.restore(build.serialize()).ok and restarted.state.tool_counts == build.state.tool_counts, "paid selected stock survives real schema restore")
    build.state.tool_counts.mine = 1
    check(build.quote_resupply(wallet(), {"limits": {"mine": 99}}).charges == {"mine": 1}, "request cannot exceed current carry capacity")

    # Exercise the real modal, quantities, row ordering and stale-price guard.
    var modal := PLANNER.new()
    root.add_child(modal)
    var ui_build := fresh()
    var ui_wallet := wallet(10)
    var query := func(plan: Dictionary):return ui_build.quote_resupply(ui_wallet, plan)
    var buy := func(plan: Dictionary):
        purchases += 1
        return ui_build.resupply_tools(ui_wallet, true, plan)
    modal.open(ui_build.get_snapshot().tools, query, buy, func(id: String):return id)
    check(modal.rows.size() == 4 and modal.get_cancel_button().has_focus(), "all owned tools appear with cancellation as default focus")
    var first_row := modal.choices.get_child(0)
    var quantity := first_row.get_child(1) as SpinBox
    quantity.value = 1
    check(modal.quantities.shard == 1 and modal.quote.charges.get("shard", 0) == 1, "actual quantity control updates detached quote")
    modal.move_priority("mine", -1)
    check(modal.plan().order[0] == "mine" and modal.quote.charges.get("mine", 0) == 2, "priority control rebuilds rows and recomputes affordability")
    check(purchases == 0 and ui_build.state.tool_counts.mine == 0, "opening, changing and moving rows never buys")
    ui_wallet.currency = 5
    modal._confirm_purchase()
    check(purchases == 0 and modal.status.text.contains("复核"), "wallet change requires a fresh confirmation")
    modal._confirm_purchase()
    check(purchases == 1 and ui_build.state.tool_counts.mine == 1 and not modal.visible, "second explicit confirmation buys only the current quote")
    modal.open(ui_build.get_snapshot().tools, query, buy, func(id: String):return id)
    modal.hide()
    check(purchases == 1, "cancellation creates no transaction")
    modal.free()
    await process_frame
    if failures.is_empty():print("RESUPPLY_PLAN checks=%d failures=0" % checks)
    else:
        for failure in failures:push_error(failure)
    quit(0 if failures.is_empty() else 1)
