extends SceneTree
const BUILD := preload("res://scripts/build_system.gd")
const BUDGET := preload("res://scripts/resupply_budget.gd")
const PLANNER := preload("res://scripts/resupply_planner.gd")
var checks := 0
var failures := 0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)
func fresh() -> RefCounted:
    var build := BUILD.new()
    for event in ["tool_mine_found", "tool_fog_found", "tool_lure_found"]:build.unlock_event(event)
    for id in build.state.tool_counts:build.state.tool_counts[id] = 0
    return build
func wallet(coins: int = 10) -> Dictionary:
    return {"currency":coins,"inventory_counts":{"moss_chitin":10,"wet_chitin":10,"salt_crystal_shard":10,"pollen_wax":10}}
func run() -> void:
    var starter := BUILD.new()
    for id in starter.state.tool_counts:starter.state.tool_counts[id] = 0
    var starter_quote: Dictionary = starter.quote_resupply(wallet(100))
    var starter_budget: Dictionary = starter_quote.get("budget",{})
    check(starter.state.unlocked_tools == ["shard"], "default budget fixture starts with only the owned shard")
    check(starter_budget.get("units",-1) == starter.tool_capacity("shard"), "default budget excludes the capacity of locked tools")
    check(starter_budget.get("cost",{}).get("currency",-1) == starter.tool_capacity("shard") * int(starter.catalog.tools.shard.resupply.currency), "default budget charges only the unlocked recipe")
    check(starter_budget.get("cost",{}).get("materials",{}) == {"moss_chitin":starter.tool_capacity("shard")}, "locked recipes add no material requirements")
    check(starter.get_snapshot(wallet(100)).resupply_quote.budget == starter_budget, "snapshot preview uses the same unlocked-only budget")
    var build := fresh()
    var money := wallet()
    var before: Dictionary = build.serialize()
    var original := money.duplicate(true)
    var plan := {"order":["mine","shard"],"limits":{"mine":2,"shard":2}}
    var quote: Dictionary = build.quote_resupply(money, plan)
    var budget: Dictionary = quote.get("budget", {})
    check(budget.get("cost",{}).get("currency",-1) == 16, "full request cost differs from affordable partial cost")
    check(budget.get("missing",{}).get("currency",-1) == 6, "currency shortfall is based on the whole requested list")
    check(quote.cost.currency == 8 and quote.charges == {"mine":2}, "original partial-priority quote is preserved")
    check(build.serialize() == before and money == original, "affordability details never mutate wallet or stock")
    check(not budget.get("affordable",true), "partially affordable request is not described as fully affordable")
    var ample: Dictionary = build.quote_resupply(wallet(100),plan)
    check(ample.get("budget",{}).get("affordable",false), "adequate funds and materials mark the full request affordable")
    var dry := wallet(0)
    dry.inventory_counts.moss_chitin = 1
    dry.inventory_counts.wet_chitin = 0
    var unavailable: Dictionary = build.quote_resupply(dry,plan)
    var short: Dictionary = unavailable.get("budget",{})
    check(not unavailable.ok, "descriptive shortfalls do not make a zero-purchase quote executable")
    check(short.get("missing",{}).get("materials",{}) == {"moss_chitin":1,"wet_chitin":2}, "simultaneous material gaps are aggregated")
    check(short.get("missing",{}).get("currency",-1) == 16, "unaffordable quote still explains the money gap")
    var caption := "\n".join(BUDGET.lines(short,func(id):return {"moss_chitin":"苔壳","wet_chitin":"湿锈甲片"}.get(id,id)))
    check(caption.contains("苔壳：总需2 / 持有1 / 还差1"), "material display uses known player-facing names")
    check(caption.contains("湿锈甲片：总需2 / 持有0 / 还差2"), "zero stock has an exact readable shortage")
    check(not caption.contains("当前仍可") and caption.contains("以当前报价为准"), "zero-purchase budget never promises an available partial purchase")
    build.state.tool_counts.mine = 1
    var capped: Dictionary = build.quote_resupply(wallet(100),{"limits":{"mine":99}})
    check(capped.get("budget",{}).get("units",-1) == 1 and capped.get("budget",{}).get("cost",{}).get("currency",-1) == 4, "requested costs use real missing capacity rather than raw spinner limits")
    build.state.tool_counts.mine = 0
    var empty: Dictionary = build.quote_resupply(money,{"limits":{}})
    check(BUDGET.lines(empty.get("budget",{}),Callable()).is_empty(), "empty request does not invent refill requirements")
    check(not build.quote_resupply(money,{"limits":{"mine":true}}).has("budget"), "invalid requests never acquire a misleading budget")
    var shared := fresh()
    shared.catalog = shared.catalog.duplicate(true)
    shared.catalog.tools.mine.resupply.materials = {"moss_chitin":1}
    var shared_wallet := wallet(100)
    shared_wallet.inventory_counts.moss_chitin = 2
    var shared_quote: Dictionary = shared.quote_resupply(shared_wallet,plan)
    check(shared_quote.get("budget",{}).get("cost",{}).get("materials",{}) == {"moss_chitin":4}, "shared materials are summed across selected tools")
    check(shared_quote.get("budget",{}).get("missing",{}).get("materials",{}) == {"moss_chitin":2}, "shared stock cannot be counted separately for each recipe")
    check(shared_quote.charges == {"mine":2}, "shared-material shortage preserves the existing priority allocator")
    var paid: Dictionary = build.resupply_tools(money,true,plan)
    check(paid.charges == quote.charges and paid.cost == quote.cost and paid.wallet == quote.remaining_wallet, "actual purchase uses the original partial quote")
    check(money == original and build.state.tool_counts.shard == 0 and build.state.tool_counts.mine == 2, "budget explains without granting unpurchased charges")
    var modal := PLANNER.new()
    root.add_child(modal)
    var ui_build := fresh()
    modal.open(ui_build.get_snapshot().tools,func(request):return ui_build.quote_resupply(dry,request),func(_request):return {"ok":false},func(id):return id)
    modal.quantities = {"mine":2,"shard":2,"fog":0,"lure":0}
    modal._refresh_quote()
    check(modal.detail.text.contains("还差16") and modal.detail.text.contains("wet_chitin：总需2 / 持有0 / 还差2"), "real refill dialog renders shortages even when purchase is disabled")
    check(modal.get_ok_button().disabled and ui_build.state.tool_counts.mine == 0, "shortage inspection cannot buy anything")
    modal.free()
    await process_frame
    for bad in [true, -1, 0.5, NAN, INF, "2"]:
        check(BUDGET.quote(build.catalog.tools,{"mine":bad},wallet()).is_empty(), "malformed quantities never produce a budget")
    for bad in [true, -1, 0.5, NAN, INF, "2"]:
        var invalid := wallet()
        invalid.inventory_counts.wet_chitin = bad
        check(BUDGET.quote(build.catalog.tools,{"mine":1},invalid).is_empty(), "malformed relevant stock never produces an optimistic budget")
    print("RESUPPLY_BUDGET checks=%d failures=%d" % [checks,failures])
    quit(0 if failures == 0 else 1)

