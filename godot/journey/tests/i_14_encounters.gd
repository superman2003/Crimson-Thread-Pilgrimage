extends "res://journey/tests/i_support.gd"
const M := preload("res://journey/fieldwork/encounters/model.gd")
const FEATURE := preload("res://journey/features/i_encounters.gd")


func run() -> void:
    label = "I14_ENCOUNTERS"
    var context := field_fixture("i14_encounters")
    await exercise(context, M, FEATURE, "encounters", "enemies")
    domain_checks(context)
    finish()


func domain_checks(context: RefCounted) -> void:
    var payload := M.capture(context.snapshot())
    check(payload.enemies.size() == 2, "only two explicitly defeated fixture enemies appear")
    var hidden: Dictionary = context.snapshot()
    for key in hidden.flags:
        if String(key).begins_with("journal_enemy_"):
            hidden.flags[key] = 1
    check(
        M.capture(hidden).enemies.is_empty(), "numeric enemy flag cannot disclose enemy catalogue"
    )
    payload.health = 5.0
    payload.damage_multiplier = 1.5
    var move := {"damage": 2.0}
    check(
        M.damage(payload, move) == 3,
        "personal damage multiplier uses bounded upward integer reference"
    )
    check(
        M.response_matrix(payload).size() <= enemy_limit(payload),
        "response matrix stays within earned skill and defeated attack product"
    )


func enemy_limit(payload: Dictionary) -> int:
    var count := 0
    for enemy in payload.enemies:
        if enemy.id == payload.enemy:
            count = enemy.attacks.size()
    return count * payload.skills.size()
