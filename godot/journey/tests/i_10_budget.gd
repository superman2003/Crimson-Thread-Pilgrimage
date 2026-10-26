extends "res://journey/tests/i_support.gd"
const M := preload("res://journey/fieldwork/budget/model.gd")
const FEATURE := preload("res://journey/features/i_budget.gd")


func run() -> void:
    label = "I10_BUDGET"
    var context := field_fixture("i10_budget")
    await exercise(context, M, FEATURE, "budget", "recipes")
    domain_checks(context)
    finish()


func domain_checks(context: RefCounted) -> void:
    var payload := M.capture(context.snapshot())
    payload.initial = 100
    payload.income = {"0": 50.0}
    payload.expenses = {"0": 25.0}
    payload.contingency = 0.0
    var rows := M.schedule(payload)
    check(
        rows[0]["期末"] == 125 and rows[-1]["期末"] == 125,
        "stage flow retains initial plus income minus expense"
    )
    check(M.mass_balance(payload, rows).ok, "independent sum reconciles stage balances")
    payload.reserve = 200.0
    check(M.required_start(payload) >= 175, "required start accounts for reserve and early income")
    var snapshot_before := V.fingerprint(context.latest)
    M.production_sequence(payload, context.snapshot())
    check(
        V.fingerprint(context.latest) == snapshot_before,
        "production sequence is isolated from live wallet"
    )

    payload.reserve = 10.0
    payload.income = {"0":100.0}
    payload.expenses = {}
    check(is_zero_approx(M.required_start(payload)), "first-stage income can fully fund the personal reserve without fictitious starting cash")
    if not payload.recipes.is_empty():
        payload.order = [payload.recipes[0].id, payload.recipes[0].id]
        check(not M.validate(payload), "duplicate production order IDs cannot duplicate one recipe stage")

