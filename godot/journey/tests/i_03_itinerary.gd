extends "res://journey/tests/i_support.gd"
const M := preload("res://journey/fieldwork/itinerary/model.gd")
const FEATURE := preload("res://journey/features/i_itinerary.gd")


func run() -> void:
    label = "I03_ITINERARY"
    var context := field_fixture("i03_itinerary")
    await exercise(context, M, FEATURE, "itinerary", "graph")
    domain_checks(context)
    finish()


func domain_checks(context: RefCounted) -> void:
    var payload := M.capture(context.snapshot())
    payload.graph = {
        "nodes":
        [
            {"id": "a", "name": "甲", "point": [0, 0], "kind": "room"},
            {"id": "b", "name": "乙", "point": [100, 0], "kind": "room"},
            {"id": "c", "name": "丙", "point": [200, 0], "kind": "room"}
        ],
        "edges":
        [
            {"from": "a", "to": "b", "open": true, "reason": "允许"},
            {"from": "b", "to": "c", "open": true, "reason": "允许"},
            {"from": "b", "to": "a", "open": true, "reason": "允许"},
            {"from": "c", "to": "b", "open": true, "reason": "允许"}
        ],
        "source": "a",
        "region": "fixture",
        "include_blocked": false,
        "undirected": false
    }
    payload.start = "a"
    payload.stops = ["b", "c"]
    payload["return"] = true
    var matrix := M.matrix(payload)
    var solution := M.exact(payload, matrix)
    check(
        solution.ok and is_equal_approx(solution.distance, 400),
        "exact solver includes directed return cost"
    )
    check(M.verify(payload, solution, matrix).ok, "computed itinerary passes continuity audit")
    var forged := solution.duplicate(true)
    forged.distance = 0
    check(not M.verify(payload, forged, matrix).ok, "forged total rejected")
    check(
        M.minimum_spanning_bound(matrix).distance <= solution.distance,
        "lower bound does not exceed exact route"
    )
    payload.budget = 1.0
    check(
        M.budget_route(payload, matrix).order.size() <= solution.order.size(),
        "budget heuristic does not invent extra stops"
    )

    var broken_matrix := matrix.duplicate(true)
    broken_matrix.paths[solution.order[-1]]["a"] = [solution.order[-1]]
    check(not M.verify(payload, solution, broken_matrix).ok, "closing return edge is audited")
    var incomplete := {"ok": true, "order": ["a"], "distance": 0.0}
    check(
        not M.verify(payload, incomplete, matrix).ok,
        "non-budget route cannot silently omit target stops"
    )
