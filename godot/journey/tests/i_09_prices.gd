extends "res://journey/tests/i_support.gd"
const M := preload("res://journey/fieldwork/prices/model.gd")
const FEATURE := preload("res://journey/features/i_prices.gd")


func run() -> void:
    label = "I09_PRICES"
    var context := field_fixture("i09_prices")
    await exercise(context, M, FEATURE, "prices", "quotes")
    domain_checks(context)
    finish()


func domain_checks(context: RefCounted) -> void:
    var payload := M.capture(context.snapshot())
    var id := String(payload.quotes[0].id)
    payload.prices[id] = 100.0
    payload.quantities[id] = 3.0
    payload.discount = 10.0
    payload.fee = 5.0
    payload.rounding = "exact"
    check(
        is_equal_approx(M.total(payload, id, 3).net, 275),
        "discount and one fixed fee are applied once per hypothetical plan"
    )
    check(M.total(payload, id, 0).net == 0, "empty quantity does not incur fixed fee")
    var indices := M.price_indices(payload, payload)
    check(
        indices.old_defined and is_equal_approx(indices.laspeyres, 1),
        "unchanged basket cost index is one"
    )
    check(M.quantile([0, 10, 20, 30], 0.5) == 15, "history quantile interpolation")
