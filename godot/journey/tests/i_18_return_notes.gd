extends "res://journey/tests/i_support.gd"
const M := preload("res://journey/fieldwork/return_notes/model.gd")
const FEATURE := preload("res://journey/features/i_return_notes.gd")


func run() -> void:
    label = "I18_RETURN_NOTES"
    var context := field_fixture("i18_return_notes")
    await exercise(context, M, FEATURE, "return_notes", "rooms")
    domain_checks(context)
    finish()


func domain_checks(context: RefCounted) -> void:
    var before := M.capture(context.snapshot())
    var after := before.duplicate(true)
    after.region = "another_region"
    check(M.changes(before, after).is_empty(), "room ids from different regions are never merged")
    var ranked := M.ranked(before)
    check(ranked.size() <= before.rooms.size(), "revisit suggestions use known rooms only")
    if not before.rooms.is_empty():
        var id := String(before.rooms[0].id)
        before.questions[id] = "复访时核对机关"
        before.reviewed = [id]
        check(
            not M.ranked(before).any(func(row: Dictionary): return row.id == id),
            "personal reviewed filter changes only the auxiliary shortlist"
        )
        check(
            M.question_rows(before).size() == 1,
            "personal room question retains stable known identity"
        )
