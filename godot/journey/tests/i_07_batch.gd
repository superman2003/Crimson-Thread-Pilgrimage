extends "res://journey/tests/i_support.gd"
const M := preload("res://journey/fieldwork/batch/model.gd")
const FEATURE := preload("res://journey/features/i_batch.gd")


func run() -> void:
    label = "I07_BATCH"
    var context := field_fixture("i07_batch")
    await exercise(context, M, FEATURE, "batch", "candidates")
    domain_checks(context)
    finish()


func domain_checks(context: RefCounted) -> void:
    var payload := M.capture(context.snapshot())
    payload.candidates = [
        {
            "id": "a",
            "name": "甲",
            "kind": "slot_part",
            "target": "a",
            "available": true,
            "reason": "允许",
            "currency": 60,
            "materials": {"m": 1}
        },
        {
            "id": "b",
            "name": "乙",
            "kind": "slot_part",
            "target": "b",
            "available": true,
            "reason": "允许",
            "currency": 60,
            "materials": {"m": 1}
        }
    ]
    payload.weights = {"a": 1.0, "b": 2.0}
    payload.inventory = {"m": 1}
    payload.labels = {"m": "样本材料"}
    payload.wallet = 100
    payload.reserve = 0.0
    payload.mandatory = []
    var winner := M.best(payload)
    check(
        winner.ids == ["b"],
        "multi-resource optimizer chooses higher personal value within shared inventory"
    )
    check(not M.subset(payload, 3).feasible, "shared materials cannot be spent twice")
    for option in M.frontier(M.enumerate(payload)):
        check(option.feasible, "frontier contains feasible candidates only")
    payload.mandatory = ["a", "b"]
    check(M.best(payload).is_empty(), "infeasible mandatory set has no partial recommendation")

    check(not M.actual_quote({}, context.snapshot()).ok, "no feasible target cannot be reported as a successful zero-cost production quote")

