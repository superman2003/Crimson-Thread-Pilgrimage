extends "res://journey/tests/i_support.gd"
const M := preload("res://journey/fieldwork/milestones/model.gd")
const FEATURE := preload("res://journey/features/i_milestones.gd")


func run() -> void:
    label = "I17_MILESTONES"
    var context := field_fixture("i17_milestones")
    await exercise(context, M, FEATURE, "milestones", "facts")
    domain_checks(context)
    finish()


func domain_checks(context: RefCounted) -> void:
    var before := M.capture(context.snapshot())
    var after := before.duplicate(true)
    var target := 0
    for i in after.facts.size():
        if after.facts[i].kind == "物资":
            target = i
            break
    after.facts[target].count = int(after.facts[target].count) + 2
    after.recorded = int(before.recorded) + 120
    check(
        M.differences(before, after).size() == 1,
        "one observed quantity change yields one fact difference"
    )
    check(
        is_equal_approx(float(M.rates(before, after)[0]["两次观察间每分钟差值"]), 1),
        "average observation delta uses actual record interval"
    )
    var raw: Dictionary = context.snapshot()
    raw.inventory["thread_dash"] = false
    check(
        not M.capture(raw).facts.any(func(row: Dictionary): return row.id == "ability:thread_dash"),
        "false count cannot become earned ability milestone"
    )
