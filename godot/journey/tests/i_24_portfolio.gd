extends "res://journey/tests/i_support.gd"
const M := preload("res://journey/fieldwork/portfolio/model.gd")
const A := preload("res://journey/fieldwork/portfolio/advanced.gd")
const FEATURE := preload("res://journey/features/i_portfolio.gd")


func run() -> void:
    label = "I24_PORTFOLIO"
    var context := field_fixture("j24_portfolio")
    await exercise(context, M, FEATURE, "j_portfolio", "assets")
    domain_checks(context)
    await inspector_checks(context)
    finish()


func small_plan(budget: float = 12.0) -> Dictionary:
    return {
        "assets":[{"id":"a","name":"A","count":10},{"id":"b","name":"B","count":10}],
        "integer_selected":["a","b"],"prices":{"a":2.0,"b":3.0},
        "targets":{"a":1.0,"b":1.0},"reserves":{"a":0.0,"b":0.0},
        "protected":[],"budget":budget,"loss":25.0,"omitted":0
    }


func brute_loss(payload: Dictionary) -> float:
    var total := float(payload.targets.a)+float(payload.targets.b)
    var target_a := float(payload.budget)*float(payload.targets.a)/total/float(payload.prices.a)
    var target_b := float(payload.budget)*float(payload.targets.b)/total/float(payload.prices.b)
    var best := INF
    for a in range(int(ceil(payload.reserves.a)),int(floor(payload.budget/payload.prices.a))+1):
        for b in range(int(ceil(payload.reserves.b)),int(floor(payload.budget/payload.prices.b))+1):
            if a*payload.prices.a+b*payload.prices.b <= payload.budget+0.000001:
                best=minf(best,absf(a-target_a)*payload.prices.a+absf(b-target_b)*payload.prices.b)
    return best


func domain_checks(context: RefCounted) -> void:
    var payload := small_plan()
    check(M.validate(payload), "integer options extend the valid saved model")
    var result := A.solve(payload)
    check(result.ok and A.certify(payload,result), "integer plan respects actual budget and reserves")
    check(is_equal_approx(result.spent,12) and is_zero_approx(result.loss), "exact affordable target has zero error")
    for budget in range(1,25):
        var sample := small_plan(float(budget))
        sample.targets.a = float(1+budget%4)
        sample.targets.b = float(1+budget%3)
        var signature := JSON.stringify(sample)
        var actual := A.solve(sample)
        check(actual.ok and A.certify(sample,actual), "all small finite budgets have certified integer choices")
        check(absf(actual.loss-brute_loss(sample)) < 0.00001, "conservative exact-tick cases match independent exhaustive objective oracle")
        check(JSON.stringify(sample) == signature, "integer search is read only")
    payload.reserves.a = 1.2
    result = A.solve(payload)
    check(result.ok and result.rows[0]["整数数量"] >= 2, "fractional reserves round up to actual integers")
    payload.budget = 2.0
    check(not A.solve(payload).ok, "unaffordable rounded reserves reject with explicit result")
    payload = small_plan()
    payload.targets = {"a":0.0,"b":0.0}
    check(not A.solve(payload).ok, "undefined all-zero target is not presented as optimal")
    payload = small_plan()
    payload.integer_selected = ["a"]
    result = A.solve(payload)
    check(result.ok and result.rows.size() == 1 and result.rows[0].id == "a", "fitting scope is explicit and independent from the main analysis")
    payload.integer_selected = []
    check(A.solve(payload).ok and A.solve(payload).rows.is_empty(), "empty chosen scope allocates no resources")
    var legacy := small_plan()
    legacy.erase("integer_selected")
    check(M.validate(legacy) and A.active_assets(legacy).is_empty(), "old saved observations remain readable without silently choosing a scope")
    var duplicate := small_plan()
    duplicate.integer_selected = ["a","a"]
    check(not M.validate(duplicate), "duplicated fitting choice rejected by persistence schema")
    duplicate.integer_selected = ["unknown"]
    check(not M.validate(duplicate), "unknown fitting choice rejected")
    payload = small_plan(11.7)
    payload.prices = {"a":2.15,"b":3.07}
    result = A.solve(payload)
    check(result.ok and result.spent <= payload.budget and A.certify(payload,result), "fractional prices are conservatively affordable")
    var forged := result.duplicate(true)
    forged.spent += 1
    check(not A.certify(payload,forged), "forged cash certificate fails")
    var captured := M.capture(context.snapshot())
    check(captured.integer_selected.size() <= 12, "capture establishes bounded default scope")
    check(M.fields(captured).any(func(field: Dictionary): return field.id == "integer_selected"), "native editor exposes exact fitting scope")


func inspector_checks(context: RefCounted) -> void:
    var before := V.fingerprint(context.latest)
    var payload := M.capture(context.snapshot())
    var view := preload("res://journey/fieldwork/portfolio/advanced_view.gd").new()
    view.configure({"payload":payload})
    view.size = Vector2(760, 600)
    root.add_child(view)
    await process_frame
    await process_frame
    check(view.get_child_count()>0, "native advanced inspector builds on its own branch")
    view.budget.value = 20; view._calculate()
    await process_frame
    check(V.fingerprint(context.latest)==before, "interactive inspector never changes live progress")
    view.free()
