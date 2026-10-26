extends "res://journey/tests/i_support.gd"
const M := preload("res://journey/fieldwork/save_diff/model.gd")
const FEATURE := preload("res://journey/features/i_save_diff.gd")


func run() -> void:
    label = "I19_SAVE_DIFF"
    var context := field_fixture("i19_save_diff")
    await exercise(context, M, FEATURE, "save_diff", "snapshot")
    domain_checks(context)
    finish()


func domain_checks(context: RefCounted) -> void:
    var options := {"epsilon": 0.0, "array_mode": "ordered", "category": "全部", "query": ""}
    var before := {"flag": false, "null": null, "a/b~c": 1, "list": [1, 2]}
    var after := {"flag": 0, "a/b~c": 2, "list": [0, 1, 2, 3]}
    var diff := M.difference(before, after, options)
    check(
        diff.ok and not diff.ops.is_empty(), "null removal and bool-to-number are real differences"
    )
    var replay := M.apply(before, diff.ops)
    check(
        replay.ok and M.equivalent(replay.value, after),
        "ordered array insertion and escaped pointer replay to exact target"
    )
    check(
        before.list == [1, 2] and before.flag == false,
        "in-memory replay does not mutate its baseline"
    )
    var merged := M.three_way({"a": 0, "b": 0}, {"a": 1, "b": 0}, {"a": 0, "b": 2}, options)
    check(
        merged.ok and merged.value == {"a": 1, "b": 2},
        "disjoint dictionary branches merge in memory"
    )
    check(
        not M.three_way({"a": 0}, {"a": 1}, {"a": 2}, options).ok,
        "same-field divergence reports conflict"
    )
    check(
        not M.apply({}, [{"op": "add", "path": "/x"}]).ok,
        "malformed operation rejected without engine error"
    )
    check(not M.pointer_parts("/invalid~2escape").ok, "invalid JSON pointer escape rejected")
    options.array_mode = "multiset"
    check(
        M.difference({"x": [1, 2, 2]}, {"x": [2, 1, 2]}, options).ops.is_empty(),
        "multiset ignores order while retaining multiplicity"
    )

    options.array_mode = "ordered"
    var baseline := {"items":[1, 2, 3], "a":0, "b":0}
    var same_array_left := {"items":[4], "a":1, "b":0}
    var same_array_right := {"items":[4], "a":0, "b":2}
    merged = M.three_way(baseline, same_array_left, same_array_right, options)
    check(merged.ok and merged.value == {"items":[4], "a":1, "b":2}, "matching multi-operation array edits merge once with unrelated changes")
    var repeated := M.difference({"items":[1, 2, 3]}, {"items":[]}, options)
    var view := preload("res://journey/fieldwork/save_diff/tree.gd").new()
    view.configure({"rows":M.operation_rows(repeated.ops, options)})
    var box := node_container()
    box.add_child(view)
    var folder: TreeItem = view.tree.get_root().get_first_child()
    check(folder.get_child_count() == 3, "repeated deletions at the same array pointer each retain a visible tree operation")
    box.queue_free()
    options.epsilon = 0.6
    var fuzzy := M.three_way({"items":[0,0],"a":0,"b":0}, {"items":[0.5,1],"a":1,"b":0}, {"items":[1,1],"a":0,"b":1}, options)
    check(not fuzzy.ok, "non-transitive numeric tolerance cannot silently drop a divergent array edit")
