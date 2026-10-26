extends "res://journey/tests/i_support.gd"
const M := preload("res://journey/fieldwork/survey/model.gd")
const FEATURE := preload("res://journey/features/i_survey.gd")


func run() -> void:
    label = "I04_SURVEY"
    var context := field_fixture("i04_survey")
    await exercise(context, M, FEATURE, "survey", "rooms")
    domain_checks(context)
    finish()


func domain_checks(context: RefCounted) -> void:
    var payload := M.capture(context.snapshot())
    payload.rooms = [
        {"id": "a", "name": "甲", "bounds": [0, 0, 100, 100]},
        {"id": "b", "name": "乙", "bounds": [50, 0, 100, 100]}
    ]
    payload.cell_size = 50.0
    payload.origin = [25, 25]
    check(
        is_equal_approx(M.exact_union_area(payload), 15000),
        "overlapping rectangle union is not double-counted"
    )
    var grid := M.grid(payload)
    check(
        grid.cells.size() == 6 and M.occupied(grid).size() == 6,
        "known rectangles rasterize into six cells"
    )
    check(
        M.query(grid, M.prefix(grid), Rect2i(0, 0, 3, 2)) == 6,
        "prefix-sum window equals occupied cells"
    )
    check(M.components(grid, false).size() == 1, "adjacent known geometry forms one component")
    check(M.grid(payload).cells.size() <= M.MAX_CELLS, "raster capacity bound enforced")
    check(M.query(grid, [], Rect2i(0, 0, 3, 2)) == 0, "invalid prefix table cannot be indexed")
