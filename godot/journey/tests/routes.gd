extends "res://journey/tests/support.gd"
const GRAPH := preload("res://journey/routes/graph.gd")
func run() -> void:
    label = "ROUTES"
    var context := fixture("routes")
    var config := {"id":REGION, "chapter_name":"已知地区", "map_rooms":[], "connections":[], "hazards":[], "enemy_spawns":[], "save_points":[{"position":[350,50]}]}
    for index in 4:
        config.map_rooms.append({"id":str(index), "name":"房间" + str(index), "layout_rect":[index * 100,0,90,90]})
    config.connections = [
        {"from":"0", "to":"1", "bidirectional":true},
        {"from":"1", "to":"2", "bidirectional":false, "required_ability":"thread_dash"},
        {"from":"2", "to":"3", "bidirectional":true},
        {"from":"0", "to":"3", "bidirectional":true}
    ]
    context.latest.config = config
    context.latest.room = "0"
    context.latest.flags = {"cartography_v1":{REGION:{"owned":true, "charted":{"0":true,"1":true,"2":true,"3":true}, "pending":{}}}}
    var graph := GRAPH.build({REGION:config}, context.snapshot())
    check(graph.ok and graph.nodes.size() == 4, "only fully charted room nodes admitted")
    var a := REGION + ":0"
    var b := REGION + ":2"
    var route := GRAPH.shortest(graph, a, b)
    check(route.ok and route.nodes == [a, REGION + ":3", b], "missing ability forces open alternative")
    check(GRAPH.verify(graph, route, {}).ok, "returned route passes continuity and weight audit")
    var forged := route.duplicate(true)
    forged.cost = 0
    check(not GRAPH.verify(graph, forged, {}).ok, "audit rejects mismatched route cost")
    context.latest.inventory.thread_dash = 1
    var unlocked := GRAPH.build({REGION:config}, context.snapshot())
    check(GRAPH.shortest(unlocked, REGION + ":1", b).nodes.size() == 2, "earned ability admits authored directed edge")
    check(GRAPH.shortest(unlocked, b, REGION + ":1").nodes.size() > 2, "reverse path does not invent one-way edge")
    check(GRAPH.nearest_shrine(graph, a, {}).ok, "nearest known shrine route is computed")
    var private_flags: Dictionary = context.latest.flags.duplicate(true)
    private_flags.cartography_v1[REGION].charted.erase("2")
    var private_snapshot: Dictionary = context.snapshot()
    private_snapshot.flags = private_flags
    check(not GRAPH.build({REGION:config}, private_snapshot).nodes.has(b), "unmapped node cannot appear in planning")
    check(GRAPH.alternatives(unlocked, a, b, {}).size() <= 3, "alternatives are bounded")
    var feature := preload("res://journey/features/route_planner.gd").new()
    feature.setup(context)
    feature.source = a
    feature.target = b
    var box := node_container()
    feature.draw(box)
    await process_frame
    check(box.get_child_count() > 5, "native planning controls and graph render")
    box.free()

    var nested := {"map_rooms":[{"id":"outer","layout_rect":[0,0,1000,1000]},{"id":"inner","layout_rect":[100,100,100,100]}], "hazards":[{"rect":[120,120,10,10]}], "save_points":[{"position":[130,130]}]}
    check(GRAPH._risk(nested, nested.map_rooms[0], {}) == 0 and GRAPH._risk(nested, nested.map_rooms[1], {}) == 2, "nested hazard belongs only to canonical owning room")
    check(not GRAPH._shrine(nested, nested.map_rooms[0]) and GRAPH._shrine(nested, nested.map_rooms[1]), "nested shrine belongs only to canonical owning room")
    finish()
