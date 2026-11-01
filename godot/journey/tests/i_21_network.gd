extends "res://journey/tests/i_support.gd"
const M := preload("res://journey/fieldwork/network/model.gd")
const A := preload("res://journey/fieldwork/network/advanced.gd")
const FEATURE := preload("res://journey/features/i_network.gd")


func run() -> void:
    label = "I21_NETWORK"
    var context := field_fixture("j21_network")
    await exercise(context, M, FEATURE, "j_network", "nodes")
    domain_checks(context)
    await inspector_checks(context)
    finish()


func cut_oracle(graph: Dictionary, source: String, sink: String) -> int:
    var ids := graph.keys()
    var best := 1000000
    for mask in (1 << ids.size()):
        var side := {}
        for i in ids.size():
            if mask & (1 << i):
                side[ids[i]] = true
        if not side.has(source) or side.has(sink):
            continue
        var count := 0
        for id in side:
            for target in graph[id]:
                if not side.has(target):
                    count += 1
        best = mini(best, count)
    return best


func domain_checks(context: RefCounted) -> void:
    var diamond := {"s":["a","b"],"a":["t"],"b":["t"],"t":[]}
    var solved := A.solve(diamond, "s", "t")
    check(solved.ok and solved.count == 2 and solved.cut.size() == 2, "diamond has two edge-disjoint directed routes")
    check(A.solve(diamond, "t", "s").count == 0, "outbound reachability never implies a return path")
    var bottleneck := diamond.duplicate(true)
    bottleneck["u"] = []
    bottleneck.t = ["u"]
    check(A.solve(bottleneck, "s", "u").count == 1, "shared final door is a real bottleneck")
    var duplicate := diamond.duplicate(true)
    duplicate.s.append("a")
    check(A.solve(duplicate, "s", "t").count == 2, "duplicate config rows cannot create fake capacity")
    var selfloop := diamond.duplicate(true)
    selfloop.s.append("s")
    check(A.solve(selfloop, "s", "t").count == 2, "self loops have no independent-route capacity")
    check(not A.solve(diamond, "s", "s").ok, "identical endpoints rejected")
    check(not A.solve(diamond, "missing", "s").ok, "unknown source rejected")
    check(not A.normalize({"s":["unknown"]}).ok, "dangling endpoint rejected")
    check(not A.normalize({"s":"not-an-array"}).ok, "malformed adjacency rejected")
    var huge := {}
    for i in 121:
        huge[str(i)] = []
    check(not A.normalize(huge).ok, "graph capacity enforced")
    var pairs := [["a","b"],["a","c"],["b","a"],["b","c"],["c","a"],["c","b"]]
    for mask in 64:
        var graph := {"a":[],"b":[],"c":[]}
        for i in pairs.size():
            if mask & (1 << i):
                graph[pairs[i][0]].append(pairs[i][1])
        var before := JSON.stringify(graph)
        for source in graph:
            for sink in graph:
                if source == sink:
                    continue
                var actual := A.solve(graph, source, sink)
                check(actual.ok and actual.count == cut_oracle(graph, source, sink), "all three-node digraphs match independent exhaustive cut oracle")
                var removed := {}
                for edge in actual.cut:
                    removed[JSON.stringify([edge.from, edge.to])] = true
                check(not A.reachable(graph, source, removed).has(sink), "reported cut actually separates its endpoints")
        check(JSON.stringify(graph) == before, "maxflow preserves caller graph")
    var impact := A.edge_impact({"s":["a"],"a":["b"],"b":[]}, "s")
    check(impact.size() == 2 and impact.filter(func(row: Dictionary): return row.from == "s")[0].lost == ["a", "b"], "door deletion impact counts all newly unreachable nodes")
    check(A.edge_impact(diamond, "s", 0).is_empty(), "zero impact budget does no hidden scan")
    check(A.vulnerability(diamond, "s", 1).size() == 1, "destination work cap is applied explicitly")
    var payload := M.capture(context.snapshot())
    var old := V.fingerprint(payload)
    var sections := M.analyze(payload, context.snapshot())
    check(sections.any(func(row: Dictionary): return row.get("title") == "有向门路容错"), "native analysis contains the new certificate section")
    check(V.fingerprint(payload) == old, "rendering certificates is read only")


func inspector_checks(context: RefCounted) -> void:
    var before := V.fingerprint(context.latest)
    var payload := M.capture(context.snapshot())
    var view := preload("res://journey/fieldwork/network/advanced_view.gd").new()
    view.configure({"nodes":payload.nodes,"graph":M.adjacency(payload)})
    view.size = Vector2(760, 600)
    root.add_child(view)
    await process_frame
    await process_frame
    check(view.get_child_count()>0, "native advanced inspector builds on its own branch")
    view._calculate()
    await process_frame
    check(V.fingerprint(context.latest)==before, "interactive inspector never changes live progress")
    view.free()
