extends "res://journey/tests/i_support.gd"
const M := preload("res://journey/fieldwork/budget/model.gd")
const A := preload("res://journey/fieldwork/budget/advanced.gd")
const FEATURE := preload("res://journey/features/i_budget.gd")


func run() -> void:
    label = "I25_BUDGET"
    var context := field_fixture("j25_budget")
    await exercise(context, M, FEATURE, "j_budget", "plan")
    domain_checks(context)
    await inspector_checks(context)
    finish()


func plan() -> Dictionary:
    return {
        "recipes":[
            {"id":"a","name":"A","currency":10,"materials":{"ore":3}},
            {"id":"b","name":"B","currency":2,"materials":{"ore":1}},
            {"id":"c","name":"C","currency":7,"materials":{"cloth":1}}
        ],"plan":["a","b","c"],"inventory":{"ore":3,"cloth":1},"labels":{},
        "initial":0,"income":{"0":3.0,"1":8.0,"2":10.0},"expenses":{},
        "material_inflow":{},"reserve":2.0,"cost_factor":1.0,"contingency":0.0
    }


func orders(ids: Array) -> Array:
    if ids.is_empty():
        return [[]]
    var result := []
    for i in ids.size():
        var rest := ids.duplicate()
        var first: Variant = rest.pop_at(i)
        for suffix in orders(rest):
            var row := [first]
            row.append_array(suffix)
            result.append(row)
    return result


func independent_capital(payload: Dictionary, order: Array) -> float:
    var recipes := {}
    for row in payload.recipes:
        recipes[row.id] = row
    var running := 0.0
    var required := 0.0
    for stage in 8:
        running += float(payload.income.get(str(stage),0))
        running -= float(payload.expenses.get(str(stage),0))+float(payload.contingency)
        if stage < order.size():
            running -= ceil(float(recipes[order[stage]].currency)*float(payload.cost_factor))
        required = maxf(required,float(payload.reserve)-running)
    return maxf(0,required)


func domain_checks(_context: RefCounted) -> void:
    var payload := plan()
    check(M.validate(payload), "budget optimization uses real saved schema")
    var result := A.solve(payload)
    check(result.ok and result.certified, "subset DP obtains a certified complete eight-stage schedule")
    check(result.required <= A.replay(payload,payload.plan).required, "optimization cannot require more initial capital than supplied order")
    check(result.material_gaps.ore == 1, "reordering never hides shared-material deficit")
    check(result.rows.size() == 8, "later empty stages remain in the cash proof")
    for seed in 24:
        var sample := plan()
        sample.reserve = float(seed%6)
        sample.initial = seed%4
        sample.cost_factor = 0.5+float(seed%5)*0.4
        sample.contingency = float(seed%3)
        for i in 8:
            sample.income[str(i)] = float((i*7+seed*3)%13)
            sample.expenses[str(i)] = float((i*11+seed)%5)
        var before := JSON.stringify(sample)
        var best := INF
        for order in orders(sample.plan):
            var needed := independent_capital(sample,order)
            best = minf(best,needed)
            check(absf(A.replay(sample,order).required-needed)<0.000001, "every order cash replay agrees with separate stage oracle")
        var solved := A.solve(sample)
        check(solved.ok and solved.certified and absf(solved.required-best)<0.000001, "DP optimum equals full permutation search")
        check(absf(solved.additional-maxf(0,best-sample.initial))<0.000001, "additional funds are measured from current wallet")
        check(JSON.stringify(sample) == before, "optimization preserves input stage assumptions")
    var late := plan()
    late.expenses["7"] = 100.0
    check(A.solve(late).required >= 100-21+19+2, "late expense after the final recipe remains binding")
    var empty := plan()
    empty.plan=[]
    empty.income={"0":100.0}
    check(is_zero_approx(A.solve(empty).required), "first-stage income may fund reserve before first boundary")
    empty.income={}
    check(is_equal_approx(A.solve(empty).required,2), "empty plan still funds reserve at stage boundary")
    var bad := plan()
    bad.plan=["a","a"]
    check(not A.solve(bad).ok, "duplicated planned recipe rejected")
    check(not A.replay(plan(),["a"]).ok, "incomplete schedule cannot masquerade as successful")
    check(not A.replay(plan(),["a","b","missing"]).ok, "unknown recipe does not become a zero-cost action")
    payload.material_inflow.ore=1
    check(A.solve(payload).material_gaps.is_empty(), "declared material inflow is accounted exactly once")


func inspector_checks(context: RefCounted) -> void:
    var before := V.fingerprint(context.latest)
    var payload := M.capture(context.snapshot())
    var view := preload("res://journey/fieldwork/budget/advanced_view.gd").new()
    view.configure({"payload":payload})
    view.size = Vector2(760, 600)
    root.add_child(view)
    await process_frame
    await process_frame
    check(view.get_child_count()>0, "native advanced inspector builds on its own branch")
    pass
    await process_frame
    check(V.fingerprint(context.latest)==before, "interactive inspector never changes live progress")
    view.free()
