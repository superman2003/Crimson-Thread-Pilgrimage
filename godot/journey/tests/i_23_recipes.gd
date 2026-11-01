extends "res://journey/tests/i_support.gd"
const M := preload("res://journey/fieldwork/recipes/model.gd")
const A := preload("res://journey/fieldwork/recipes/advanced.gd")
const FEATURE := preload("res://journey/features/i_recipes.gd")


func run() -> void:
    label = "I23_RECIPES"
    var context := field_fixture("j23_recipes")
    await exercise(context, M, FEATURE, "j_recipes", "recipes")
    domain_checks(context)
    await inspector_checks(context)
    finish()


func fixture_plan() -> Dictionary:
    return {
        "recipes":[
            {"id":"a","name":"A","kind":"tool","target":"tool","currency":3,"materials":{"ore":2},"proofs":[],"crafted":false},
            {"id":"b","name":"B","kind":"skill_branch","target":"skill","currency":5,"materials":{"ore":3},"proofs":[],"crafted":false},
            {"id":"c","name":"C","kind":"skill_branch","target":"skill","currency":4,"materials":{"cloth":1},"proofs":[],"crafted":false}
        ],
        "selected":["a","b","c"],"inventory":{"ore":4,"cloth":1},"labels":{},
        "wallet":10,"multiplier":1.0,"buffer":0.0,"include_crafted":false
    }


func independent_feasible(payload: Dictionary, mask: int) -> bool:
    var costs := {}
    var money := 0
    var branches := {}
    for i in payload.selected.size():
        if mask & (1 << i) == 0:
            continue
        var recipe: Dictionary = payload.recipes[i]
        if recipe.crafted and not payload.include_crafted:
            return false
        if recipe.kind == "skill_branch":
            if branches.has(recipe.target):
                return false
            branches[recipe.target] = true
        money += int(recipe.currency) * int(payload.multiplier)
        for id in recipe.materials:
            costs[id] = int(costs.get(id,0)) + int(recipe.materials[id]) * int(payload.multiplier)
    if money > payload.wallet:
        return false
    for id in costs:
        if ceil(float(costs[id])*(1+float(payload.buffer)/100)) > float(payload.inventory.get(id,0)):
            return false
    return true


func domain_checks(_context: RefCounted) -> void:
    var payload := fixture_plan()
    check(M.validate(payload), "controlled plan uses actual public recipe schema")
    var result := A.enumerate(payload)
    check(result.ok and result.tested == 8 and result.best == 2, "all eight subsets are enumerated")
    check(A.certify(payload,result), "maximal subset costs replay exactly")
    check(result.maximal.size() == 2, "incompatible branches and material shortage yield two maximal choices")
    check(result.essential == ["a","c"], "every maximum-cardinality feasible plan includes C")
    check(result.all[7].conflicts == ["skill"], "branch incompatibility is not disguised as an affordable plan")
    check(result.all[3].deficits.ore == 1, "shared material is summed rather than independently afforded")
    check(A.opportunity(result).size() == 3, "every selected recipe gets opportunity analysis")
    for seed in 24:
        var sample := fixture_plan()
        sample.wallet = seed
        sample.inventory.ore = seed % 12
        sample.inventory.cloth = seed % 3
        sample.multiplier = float(1+seed%3)
        sample.buffer = float(seed%5)*12.5
        sample.recipes[0].crafted = seed%2 == 0
        sample.include_crafted = seed%4 == 0
        var before := JSON.stringify(sample)
        var enumerated := A.enumerate(sample)
        var best := 0
        for mask in 8:
            var feasible := independent_feasible(sample,mask)
            check(enumerated.all[mask].feasible == feasible, "exhaustive feasibility agrees with separate resource/conflict oracle")
            if feasible:
                best = maxi(best,enumerated.all[mask].count)
        check(enumerated.best == best, "reported cardinality is the exact feasible maximum")
        for subset in enumerated.maximal:
            for i in 3:
                if subset.mask & (1<<i) == 0:
                    check(not independent_feasible(sample,subset.mask | (1<<i)), "maximal plan cannot be extended by another selected recipe")
        check(JSON.stringify(sample) == before, "exhaustive planning never edits quoted inventory")
    var large := fixture_plan()
    large.recipes.clear()
    large.selected.clear()
    large.inventory = {"ore":100}
    large.wallet = 100
    for i in 8:
        large.recipes.append({"id":str(i),"name":str(i),"kind":"tool","target":str(i),"currency":1,"materials":{"ore":1},"proofs":[],"crafted":false})
        large.selected.append(str(i))
    check(A.enumerate(large).tested == 256 and A.enumerate(large).best == 8, "maximum supported selection includes every subset")
    large.selected.append("ninth")
    check(not A.enumerate(large).ok, "ninth selected target rejects exact work rather than truncating")
    var broken := fixture_plan()
    broken.selected = ["missing"]
    check(not A.enumerate(broken).ok, "unknown selected target rejected")
    broken.selected = ["a","a"]
    check(not A.enumerate(broken).ok, "duplicate target rejected")
    var empty := fixture_plan()
    empty.selected = []
    check(A.enumerate(empty).tested == 1 and A.enumerate(empty).best == 0, "empty subset remains a valid defer-everything plan")


func inspector_checks(context: RefCounted) -> void:
    var before := V.fingerprint(context.latest)
    var payload := M.capture(context.snapshot())
    var view := preload("res://journey/fieldwork/recipes/advanced_view.gd").new()
    view.configure({"payload":payload,"result":A.enumerate(payload)})
    view.size = Vector2(760, 600)
    root.add_child(view)
    await process_frame
    await process_frame
    check(view.get_child_count()>0, "native advanced inspector builds on its own branch")
    view._inspect()
    await process_frame
    check(V.fingerprint(context.latest)==before, "interactive inspector never changes live progress")
    view.free()
