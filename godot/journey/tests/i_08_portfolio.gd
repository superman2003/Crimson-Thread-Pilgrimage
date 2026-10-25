extends "res://journey/tests/i_support.gd"
const M := preload("res://journey/fieldwork/portfolio/model.gd")
const FEATURE := preload("res://journey/features/i_portfolio.gd")


func run() -> void:
    label = "I08_PORTFOLIO"
    var context := field_fixture("i08_portfolio")
    await exercise(context, M, FEATURE, "portfolio", "assets")
    domain_checks(context)
    finish()


func domain_checks(context: RefCounted) -> void:
    var payload := M.capture(context.snapshot())
    payload.assets = [{"id": "a", "name": "甲", "count": 9}, {"id": "b", "name": "乙", "count": 1}]
    payload.prices = {"a": 1.0, "b": 1.0}
    payload.targets = {"a": 1.0, "b": 1.0}
    payload.reserves = {"a": 0.0, "b": 0.0}
    payload.protected = ["a"]
    payload.budget = 10.0
    check(M.gini(payload) > 0.3 and M.gini(payload) < 0.5, "known unequal two-item Lorenz area")
    var allocation := M.allocation(payload)
    check(
        allocation.ok and allocation.spent <= payload.budget + 0.00001,
        "integer allocation cannot exceed personal budget"
    )
    check(
        M.stress(payload, 100).assets[0].count == 9,
        "protected asset is unchanged in hypothetical loss"
    )
    payload.reserves = {"a": 100.0}
    check(not M.allocation(payload).ok, "unfunded minimum reserves reject allocation")
