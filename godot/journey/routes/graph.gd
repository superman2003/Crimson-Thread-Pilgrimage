extends RefCounted
const V := preload("res://journey/core/values.gd")
const JOURNAL := preload("res://scripts/pilgrimage_cartography.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const KNOWLEDGE := preload("res://scripts/survey_map_knowledge.gd")
const MAX_NODES := 600
const MAX_EDGES := 3000

static func configurations(snapshot: Dictionary) -> Dictionary:
    var result := {}
    var flags: Dictionary = snapshot.get("flags", {})
    var books: Variant = flags.get(JOURNAL.KEY, {})
    if not books is Dictionary:
        return result
    for id in books:
        var record: Variant = books[id]
        if not id is String or not record is Dictionary or not record.get("owned") is bool or not record.owned:
            continue
        if id == snapshot.get("region"):
            result[id] = snapshot.get("config", {}).duplicate(true)
            continue
        var path := ROUTES.cached_config_path(id)
        if path.is_empty():
            continue
        var parsed := V.read_json(path, 4194304)
        if parsed.get("id") != id:
            continue
        result[id] = ROUTES.apply_to_owned_cached(parsed)
    return result

static func room_rect(room: Dictionary) -> Rect2:
    var source: Variant = room.get("layout_rect", room.get("play_rect", []))
    if not source is Array or source.size() != 4:
        return Rect2()
    for value in source:
        if not V.number(value):
            return Rect2()
    var result := Rect2(float(source[0]), float(source[1]), float(source[2]), float(source[3]))
    return result if result.size.x > 0 and result.size.y > 0 and result.end.is_finite() else Rect2()

static func build(configs: Dictionary, snapshot: Dictionary) -> Dictionary:
    var nodes := {}
    var edges := []
    var flags: Dictionary = snapshot.get("flags", {})
    var inventory: Dictionary = snapshot.get("inventory", {})
    for region in configs:
        var config: Dictionary = configs[region]
        for room in config.get("map_rooms", []):
            if nodes.size() >= MAX_NODES:
                return {"ok":false, "reason":"公开地图超出规划容量。", "nodes":{}, "edges":[]}
            if not room is Dictionary or not room.get("id") is String:
                continue
            if not JOURNAL.charted_whole(flags, String(region), room):
                continue
            var rect := room_rect(room)
            if rect.size == Vector2.ZERO:
                continue
            var key := String(region) + ":" + String(room.id)
            var risk := _risk(config, room, flags)
            nodes[key] = {"id":key, "region":region, "room":room.id, "name":String(room.get("name", room.id)), "region_name":String(config.get("chapter_name", region)), "point":V.pair(rect.get_center()), "kind":String(room.get("kind", "room")), "risk":risk, "shrine":_shrine(config, rect), "boss":String(room.get("kind", "")) == "boss"}
    for region in configs:
        var config: Dictionary = configs[region]
        var opened: Dictionary = snapshot.get("regions", {}).get(region, {}).get("opened_shortcuts", {})
        for connection in config.get("connections", []):
            if not connection is Dictionary:
                continue
            var a := String(region) + ":" + String(connection.get("from", ""))
            var b := String(region) + ":" + String(connection.get("to", ""))
            if not nodes.has(a) or not nodes.has(b) or a == b:
                continue
            var access := connection_access(config, connection, inventory, flags, opened)
            var distance := V.point(nodes[a].point).distance_to(V.point(nodes[b].point))
            _edge(edges, a, b, distance, access, "room")
            if connection.get("bidirectional") is bool and connection.bidirectional:
                _edge(edges, b, a, distance, access, "room")
        for portal in config.get("interactives", []):
            if not portal is Dictionary or portal.get("kind") != "world_portal":
                continue
            var target := String(portal.get("target_config_id", ""))
            if not configs.has(target):
                continue
            var peer := ROUTES.cached_portal(target, String(portal.get("target_portal_id", "")))
            var a := String(region) + ":" + String(portal.get("room_id", ""))
            var b := target + ":" + String(peer.get("room_id", ""))
            if not nodes.has(a) or not nodes.has(b):
                continue
            var access := ROUTES.access(portal, inventory, flags)
            _edge(edges, a, b, 800.0, access, "portal")
    return {"ok":edges.size() <= MAX_EDGES, "reason":"" if edges.size() <= MAX_EDGES else "公开连边超出规划容量。", "nodes":nodes, "edges":edges}

static func _edge(edges: Array, a: String, b: String, distance: float, access: Dictionary, kind: String) -> void:
    if edges.size() > MAX_EDGES or not is_finite(distance):
        return
    var id := a + "=>" + b
    for existing in edges:
        if existing.id == id:
            return
    edges.append({"id":id, "from":a, "to":b, "distance":maxf(1.0, distance), "open":access.get("open") is bool and access.get("open", false), "reason":String(access.get("label", "门槛未满足")), "kind":kind})

static func connection_access(config: Dictionary, connection: Dictionary, inventory: Dictionary, flags: Dictionary, opened: Dictionary) -> Dictionary:
    var ability := String(connection.get("required_ability", ""))
    if not ability.is_empty() and not V.held(inventory.get(ability, 0)):
        return {"open":false, "label":"需要已获能力"}
    var shortcut := String(connection.get("shortcut_id", ""))
    if not shortcut.is_empty() and (not opened.get(shortcut) is bool or not opened.get(shortcut, false)):
        return {"open":false, "label":"捷径尚未接通"}
    var a := String(connection.get("from", ""))
    var b := String(connection.get("to", ""))
    for gate in config.get("locked_gates", []):
        var x := String(gate.get("from", ""))
        var y := String(gate.get("to", ""))
        if (x == a and y == b) or (x == b and y == a):
            if not KNOWLEDGE.gate_open(gate, inventory, flags):
                return {"open":false, "label":"能力门尚未开放"}
    return {"open":true, "label":"规则允许"}

static func _risk(config: Dictionary, room: Dictionary, flags: Dictionary) -> int:
    var rect := room_rect(room)
    var count := 0
    for hazard in config.get("hazards", []):
        var value: Variant = hazard.get("rect", [])
        if value is Array and value.size() == 4:
            var center := Vector2(float(value[0]) + float(value[2]) * 0.5, float(value[1]) + float(value[3]) * 0.5)
            if rect.has_point(center):
                count += 2
    for enemy in config.get("enemy_spawns", []):
        var kind := String(enemy.get("kind", ""))
        if flags.get("journal_enemy_" + kind) != true:
            continue
        var point := V.point(enemy.get("position", []))
        if point.is_finite() and rect.has_point(point):
            count += 1
    return count

static func _shrine(config: Dictionary, room: Rect2) -> bool:
    for shrine in config.get("save_points", []):
        var point := V.point(shrine.get("position", []))
        if point.is_finite() and room.has_point(point):
            return true
    return false

static func weight(edge: Dictionary, nodes: Dictionary, preferences: Dictionary) -> float:
    if not edge.get("open", false) or not nodes.has(edge.get("to")):
        return INF
    var target: Dictionary = nodes[edge.to]
    if preferences.get("avoid_boss", false) and target.boss:
        return INF
    if preferences.get("avoid_hazards", false) and int(target.risk) > 0:
        return INF
    var distance := float(edge.get("distance", 1.0)) / 1000.0
    var risk := float(target.risk) * clampf(float(preferences.get("risk_weight", 1.0)), 0.0, 10.0)
    var transition := 2.0 if edge.kind == "portal" else 0.0
    return maxf(0.001, 1.0 + distance + risk + transition)

static func shortest(graph: Dictionary, source: String, target: String, preferences: Dictionary = {}, excluded: Dictionary = {}) -> Dictionary:
    var nodes: Dictionary = graph.get("nodes", {})
    if not graph.get("ok", false) or not nodes.has(source) or not nodes.has(target):
        return {"ok":false, "reason":"起点或终点不在已完整补绘的公开地图中。"}
    var distance := {source:0.0}
    var previous := {}
    var pending := {source:true}
    var visited := {}
    var examined := 0
    while not pending.is_empty() and examined <= MAX_NODES:
        var current := ""
        var best := INF
        for key in pending:
            var candidate := float(distance.get(key, INF))
            if candidate < best or (is_equal_approx(candidate, best) and String(key) < current):
                current = String(key)
                best = candidate
        if current.is_empty():
            break
        pending.erase(current)
        if current == target:
            break
        visited[current] = true
        examined += 1
        for edge in graph.get("edges", []):
            if edge.from != current or excluded.has(edge.id) or visited.has(edge.to):
                continue
            var cost := weight(edge, nodes, preferences)
            if not is_finite(cost):
                continue
            var next := best + cost
            if next < float(distance.get(edge.to, INF)):
                distance[edge.to] = next
                previous[edge.to] = edge
                pending[edge.to] = true
    if not distance.has(target):
        return {"ok":false, "reason":"当前公开图和偏好下没有规则可通的路线。"}
    var route := [target]
    var edges := []
    var cursor := target
    while cursor != source:
        if not previous.has(cursor) or route.size() > MAX_NODES:
            return {"ok":false, "reason":"路线链无法复核。"}
        var edge: Dictionary = previous[cursor]
        edges.push_front(edge)
        cursor = String(edge.from)
        route.push_front(cursor)
    return {"ok":true, "nodes":route, "edges":edges, "cost":float(distance[target]), "source":source, "target":target}

static func alternatives(graph: Dictionary, source: String, target: String, preferences: Dictionary) -> Array:
    var first := shortest(graph, source, target, preferences)
    if not first.get("ok", false):
        return []
    var result := [first]
    var signatures := {"|".join(first.nodes):true}
    var candidates := []
    for edge in first.edges:
        var excluded := {String(edge.id):true}
        var candidate := shortest(graph, source, target, preferences, excluded)
        if not candidate.get("ok", false):
            continue
        var signature := "|".join(candidate.nodes)
        if signatures.has(signature):
            continue
        signatures[signature] = true
        candidates.append(candidate)
    candidates.sort_custom(func(a: Dictionary, b: Dictionary):return float(a.cost) < float(b.cost))
    for candidate in candidates:
        result.append(candidate)
        if result.size() >= 3:
            break
    return result

static func nearest_shrine(graph: Dictionary, source: String, preferences: Dictionary) -> Dictionary:
    var best := {"ok":false, "reason":"已知图中没有可达钟龛。"}
    for id in graph.get("nodes", {}):
        if not graph.nodes[id].shrine:
            continue
        var route := shortest(graph, source, String(id), preferences)
        if route.get("ok", false) and (not best.get("ok", false) or float(route.cost) < float(best.cost)):
            best = route
    return best

static func verify(graph: Dictionary, route: Dictionary, preferences: Dictionary) -> Dictionary:
    if not route.get("ok", false) or not route.get("nodes") is Array or not route.get("edges") is Array:
        return {"ok":false, "reason":"路线格式无效。"}
    if route.nodes.is_empty() or route.nodes.size() != route.edges.size() + 1:
        return {"ok":false, "reason":"路线节点与连边数量不一致。"}
    if route.nodes[0] != route.get("source") or route.nodes[-1] != route.get("target"):
        return {"ok":false, "reason":"路线起终点不一致。"}
    var seen := {}
    var cost := 0.0
    for index in route.nodes.size():
        var id := String(route.nodes[index])
        if not graph.get("nodes", {}).has(id) or seen.has(id):
            return {"ok":false, "reason":"路线包含未公开节点或重复环。"}
        seen[id] = true
        if index >= route.edges.size():
            continue
        var edge: Dictionary = route.edges[index]
        if edge.get("from") != id or edge.get("to") != route.nodes[index + 1]:
            return {"ok":false, "reason":"路线连边方向不一致。"}
        var found := false
        for candidate in graph.get("edges", []):
            if candidate.id == edge.get("id") and candidate == edge:
                found = true
                break
        var value := weight(edge, graph.nodes, preferences)
        if not found or not is_finite(value):
            return {"ok":false, "reason":"连边不属于当前规则允许的公开图。"}
        cost += value
    if not V.number(route.get("cost")) or not is_equal_approx(cost, float(route.cost)):
        return {"ok":false, "reason":"路线权重与逐边合计不一致。"}
    return {"ok":true, "reason":"公开节点、连边方向、规则和权重合计已复核。"}
