extends "res://journey/tests/support.gd"
const MODEL := preload("res://journey/caseboard/model.gd")
func run() -> void:
    label = "CASEBOARD"
    var context := fixture("caseboard")
    var state := MODEL.fresh()
    check(MODEL.graph(state, context.snapshot()).nodes.is_empty(), "unknown narrative nodes remain private")
    context.latest.flags.quest_bring_names_started = true
    context.latest.flags.evidence_known_testimony_01 = true
    var graph := MODEL.graph(state, context.snapshot())
    check(graph.nodes.size() >= 2, "only encountered quest and evidence become nodes")
    var ids: Array = graph.nodes.keys()
    var linked := MODEL.connect_nodes(state, graph, String(ids[0]), String(ids[1]), "questions", "仍需核对")
    check(MODEL.valid(linked) and linked.links.size() == 1, "personal hypothesis stores separately")
    check(MODEL.connect_nodes(linked, graph, String(ids[1]), String(ids[0]), "questions", "重复") == linked, "reverse duplicate hypothesis rejected")
    check(MODEL.connect_nodes(linked, graph, String(ids[0]), "unseen", "related", "") == linked, "cannot link private node")
    var annotated := MODEL.annotate(linked, graph, String(ids[0]), "自己的阅读")
    check(MODEL.filtered(graph, annotated, "自己的阅读", "all").nodes.size() == 1, "personal notes participate in known-only search")
    graph = MODEL.graph(annotated, context.snapshot())
    var chain := MODEL.chain(graph, String(ids[0]), String(ids[1]))
    check(chain.ok and chain.hypotheses == 1, "relationship chain retains hypothesis provenance")
    check(MODEL.components(graph).size() >= 1, "known graph components bounded")
    check(not MODEL.chain(graph, "unseen", String(ids[0])).ok, "chain query cannot reveal hidden source")
    var moved := MODEL.move(annotated, graph, String(ids[0]), Vector2(2, -1))
    check(moved.positions[ids[0]] == [1.0,0.0], "graph positions clamp to normalized canvas")
    var before := VALUES.fingerprint(context.latest.flags)
    var feature := preload("res://journey/features/caseboard.gd").new()
    feature.setup(context)
    feature.data = annotated
    feature.selected = String(ids[0])
    for tab in ["board", "catalog", "links", "groups"]:
        var box := node_container()
        feature.tab = tab
        feature.draw(box)
        await process_frame
        check(box.get_child_count() > 3, "caseboard tab renders: " + tab)
        box.free()
    check(VALUES.fingerprint(context.latest.flags) == before, "reading and hypotheses grant no story flags")
    finish()
