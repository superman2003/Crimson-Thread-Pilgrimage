extends "res://journey/tests/i_support.gd"
const M := preload("res://journey/fieldwork/survey/model.gd")
const A := preload("res://journey/fieldwork/survey/advanced.gd")
const FEATURE := preload("res://journey/features/i_survey.gd")


func run() -> void:
    label = "I22_SURVEY"
    var context := field_fixture("j22_survey")
    await exercise(context, M, FEATURE, "j_survey", "rooms")
    domain_checks(context)
    await inspector_checks(context)
    finish()


func grid(width: int, height: int, occupied: Array) -> Dictionary:
    var values := []
    for i in width * height:
        values.append(1 if occupied.has(i) else 0)
    return {"width":width,"height":height,"cells":values}


func domain_checks(context: RefCounted) -> void:
    var line := grid(7, 1, [0,1,2,3,4,5,6])
    check(A.distances(line, 0)[6] == 6, "grid distance uses four-neighbor steps")
    check(A.footprint(line, 3, 1) == [2,3,4], "footprint includes both radius endpoints")
    var split := grid(7, 1, [0,1,2,4,5,6])
    check(not A.distances(split, 0).has(4), "empty reference cells separate components")
    var edge := grid(2,2,[1,2])
    check(A.distances(edge,1).size() == 1, "row boundary cannot wrap horizontally")
    check(not A.valid_grid({"width":2,"height":2,"cells":[1]}), "dimension mismatch rejected")
    check(not A.valid_grid({"width":1,"height":1,"cells":[NAN]}), "nonfinite density rejected")
    check(not A.plan(line,9).ok, "station cap enforced")
    check(not A.plan(line,1,-1).ok, "negative radius rejected")
    check(A.plan(line,0).covered.is_empty(), "zero stations gives no phantom coverage")
    var empty := grid(0,0,[])
    check(A.plan(empty).ok and A.plan(empty).total == 0, "empty survey is a valid empty plan")
    for seed in 20:
        var occupied := []
        for i in 30:
            if ((i * 17 + seed * 13) % 11) < 8:
                occupied.append(i)
        var sample := grid(6,5,occupied)
        var signature := JSON.stringify(sample)
        for radius in [0,1,2,3]:
            var result := A.plan(sample,4,radius)
            check(result.ok and A.certify(sample,result), "every generated plan replays its exact incremental gains")
            var covered := {}
            var chosen := []
            for station in result.stations:
                var maximum := 0
                for id in occupied:
                    if chosen.has(id):
                        continue
                    var gain := 0
                    for target in A.footprint(sample,id,radius):
                        if not covered.has(target):
                            gain += 1
                    maximum = maxi(maximum,gain)
                check(station.gain == maximum, "each step independently verifies maximum marginal gain")
                chosen.append(station.cell)
                for target in A.footprint(sample,station.cell,radius):
                    covered[target] = true
            var unseen := occupied.filter(func(id: int): return not covered.has(id))
            check(unseen == result.uncovered, "uncovered cells are the exact complement")
            check(result.covered.size() <= occupied.size(), "coverage never exceeds occupied grid")
        check(JSON.stringify(sample) == signature, "coverage planning does not alter survey cells")
    var dense := grid(40,40,range(1600))
    var plan := A.plan(dense,1,2)
    check(plan.sampled and plan.candidates == 128, "large candidate set declares bounded sampling")
    check(A.certify(dense,plan), "sampled candidate plan still has exact coverage certificate")
    var changed := plan.duplicate(true)
    changed.stations[0].gain += 1
    check(not A.certify(dense,changed), "tampered marginal gain certificate rejected")
    var captured := M.capture(context.snapshot())
    check(M.analyze(captured,context.snapshot()).size() > 5, "native page retains existing and new analysis")


func inspector_checks(context: RefCounted) -> void:
    var before := V.fingerprint(context.latest)
    var payload := M.capture(context.snapshot())
    var view := preload("res://journey/fieldwork/survey/advanced_view.gd").new()
    view.configure({"grid":M.grid(payload)})
    view.size = Vector2(760, 600)
    root.add_child(view)
    await process_frame
    await process_frame
    check(view.get_child_count()>0, "native advanced inspector builds on its own branch")
    view.count.value = 2; view.radius.value = 1; view._calculate()
    await process_frame
    check(V.fingerprint(context.latest)==before, "interactive inspector never changes live progress")
    view.free()
