extends "res://journey/tests/i_support.gd"
const M := preload("res://journey/fieldwork/rooms/model.gd")
const FEATURE := preload("res://journey/features/i_rooms.gd")


func run() -> void:
    label = "I01_ROOMS"
    var context := field_fixture("i01_rooms")
    await exercise(context, M, FEATURE, "rooms", "rooms")
    domain_checks(context)
    finish()


func domain_checks(context: RefCounted) -> void:
    var payload := M.capture(context.snapshot())
    check(
        payload.rooms.size() <= 6 and payload.rooms.size() > 0,
        "only visited fixture rooms captured"
    )
    var private: Dictionary = context.snapshot()
    private.regions[REGION].visited_rooms = {}
    private.room = "not_a_room"
    check(M.capture(private).rooms.is_empty(), "unvisited room names are not emitted")
    check(M.rows(payload).size() <= payload.rooms.size(), "radius filter is bounded")
    var invalid := payload.duplicate(true)
    invalid.origin = [1e308, 0]
    check(not M.validate(invalid), "overflow-scale coordinate rejected")

    check(
        RECORDS.semantic_key({"a": 1, "b": [2.0]}) == RECORDS.semantic_key({"b": [2], "a": 1.0}),
        "semantic keys ignore JSON numeric representation and dictionary order"
    )
    check(
        RECORDS.semantic_key(true) != RECORDS.semantic_key(1),
        "semantic keys distinguish bool from number"
    )
    check(
        RECORDS.semantic_key(9007199254740993) != RECORDS.semantic_key(9007199254740992.0),
        "large exact integer is not rounded into another number"
    )
