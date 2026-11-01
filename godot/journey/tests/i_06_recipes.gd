extends "res://journey/tests/i_support.gd"
const M := preload("res://journey/fieldwork/recipes/model.gd")
const FEATURE := preload("res://journey/features/i_recipes.gd")


func run() -> void:
    label = "I06_RECIPES"
    var context := field_fixture("i06_recipes")
    await exercise(context, M, FEATURE, "recipes", "recipes")
    domain_checks(context)
    finish()


func domain_checks(context: RefCounted) -> void:
    var payload := M.capture(context.snapshot())
    check(payload.recipes.size() > 0, "earned fixture exposes eligible recipes")
    payload.selected = []
    for row in payload.recipes:
        if row.kind == "skill_branch" and row.target == "cleave":
            payload.selected.append(row.id)
    payload.multiplier = 2.0
    var requirements := M.requirements(payload)
    check(M.branch_conflicts(payload).size() == 1, "same-skill branch directions conflict")
    check(requirements.currency == 400, "resource multiplier applies to both selected branch costs")
    var before := V.fingerprint(context.latest)
    M.production_quote(payload, context.snapshot())
    check(V.fingerprint(context.latest) == before, "quote clone never mutates actual fixture state")
