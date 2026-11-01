extends "res://journey/tests/i_support.gd"
const M := preload("res://journey/fieldwork/curriculum/model.gd")
const FEATURE := preload("res://journey/features/i_curriculum.gd")


func run() -> void:
    label = "I11_CURRICULUM"
    var context := field_fixture("i11_curriculum")
    await exercise(context, M, FEATURE, "curriculum", "actions")
    domain_checks(context)
    finish()


func domain_checks(context: RefCounted) -> void:
    var payload := M.capture(context.snapshot())
    check(not payload.actions.is_empty(), "fixture uses explicit gameplay mappings")
    payload.sequence = ["attack", "attack"]
    payload.repeats = 2.0
    payload.rest = 5.0
    var rows := M.timeline(payload)
    check(rows.size() == 5, "two repetitions include one intervening rest")
    var stats := M.resource_summary(payload, rows)
    check(is_equal_approx(stats.rest, 5), "rest time is counted once between repetitions")
    var hidden: Dictionary = context.snapshot()
    hidden.inventory["thread_dash"] = true
    check(
        not M.known_actions(hidden).any(func(row: Dictionary): return row.id == "dash"),
        "truth value is not a positive ability inventory count"
    )

    payload.actions = [{"id":"guard", "name":"守势", "binding":"G", "bindings":["G"], "movement":false, "cost":8.0, "cooldown":0.8, "duration":0.1}]
    payload.sequence = ["guard", "guard", "guard"]
    payload.waits = {"guard":0.4}
    payload.repeats = 1
    payload.energy = 16.0
    rows = M.timeline(payload)
    check(rows[1]["假设动作费用"] == 0.0 and rows[2]["假设可承受"], "cooldown rejection consumes no energy and does not restart cooldown")
    payload.actions[0].cost_rate = "invalid"
    check(not M.validate(payload), "imported per-second energy metadata is type checked")
    check(M.binding_signature(["A", "B", "C"]) != M.binding_signature(["A", "B", "D"]), "binding signatures include mappings beyond shortened labels")

