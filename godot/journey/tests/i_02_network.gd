extends "res://journey/tests/i_support.gd"
const M := preload("res://journey/fieldwork/network/model.gd")
const FEATURE := preload("res://journey/features/i_network.gd")


func run() -> void:
    label = "I02_NETWORK"
    var context := field_fixture("i02_network")
    await exercise(context, M, FEATURE, "network", "nodes")
    domain_checks(context)
    finish()


func domain_checks(context: RefCounted) -> void:
    var graph := {"a": ["b"], "b": ["a", "c"], "c": ["b"]}
    check(M.strong_components(graph).size() == 1, "mutual reachability components")
    check(
        M.articulation(graph).size() == 1 and M.articulation(graph)[0].id == "b",
        "bridge room identified"
    )
    check(M.bridges(graph).size() == 2, "both undirected structural bridges identified")
    check(M.breadth(graph, "a")["c"] == 2, "directed breadth distance")
    var directed := {"a": ["b"], "b": ["c"], "c": []}
    check(
        M.strong_components(directed).size() == 3 and M.topological(directed).acyclic,
        "one-way chain remains three strong components"
    )
    check(M.shortest_path(directed, "c", "a").is_empty(), "reverse route is not invented")
