extends RefCounted
const ADVANCED_VIEW := preload("res://journey/fieldwork/network/advanced_view.gd")
const ADVANCED := preload("res://journey/fieldwork/network/advanced.gd")
const K := preload("res://journey/fieldwork/knowledge.gd")
const V := preload("res://journey/fieldwork/scalars.gd")
const GATE := preload("res://scripts/survey_map_knowledge.gd")
const VIEW := preload("res://journey/fieldwork/network/view.gd")
const MAX_NODES := 120
const MAX_EDGES := 600


static func introduction() -> String:
    return "只对当前地区实际抵达过的房间分析连通关系、单向结构和替代通路。结果来自地图规则，不能证明角色在现场一定能通过。"


static func capture(snapshot: Dictionary) -> Dictionary:
    var nodes := []
    var edges := []
    var known := {}
    for room in K.rooms(snapshot).slice(0, MAX_NODES):
        var rect := K.rectangle(room.get("layout_rect", []))
        if rect.size == Vector2.ZERO:
            continue
        nodes.append(
            {
                "id": room.id,
                "name": String(room.get("name", room.id)),
                "point": V.pair(rect.get_center()),
                "kind": String(room.get("kind", "room"))
            }
        )
        known[room.id] = true
    for connection in snapshot.get("config", {}).get("connections", []):
        if (
            not connection is Dictionary
            or not known.has(connection.get("from"))
            or not known.has(connection.get("to"))
        ):
            continue
        var a := String(connection.from)
        var b := String(connection.to)
        if a == b:
            continue
        var permission := permission(connection, snapshot)
        if edges.size() < MAX_EDGES:
            edges.append({"from": a, "to": b, "open": permission.open, "reason": permission.reason})
        if K.flag(connection.get("bidirectional")) and edges.size() < MAX_EDGES:
            edges.append({"from": b, "to": a, "open": permission.open, "reason": permission.reason})
    return {
        "nodes": nodes,
        "edges": edges,
        "source": String(snapshot.get("room", "")),
        "include_blocked": false,
        "undirected": false,
        "region": String(snapshot.get("region", ""))
    }


static func permission(connection: Dictionary, snapshot: Dictionary) -> Dictionary:
    var ability := String(connection.get("required_ability", ""))
    if not ability.is_empty() and not K.positive(snapshot.get("inventory", {}).get(ability)):
        return {"open": false, "reason": "能力门未满足"}
    var shortcut := String(connection.get("shortcut_id", ""))
    var opened: Dictionary = snapshot.get("regions", {}).get(snapshot.get("region", ""), {}).get(
        "opened_shortcuts", {}
    )
    if not shortcut.is_empty() and not K.flag(opened.get(shortcut)):
        return {"open": false, "reason": "捷径未接通"}
    for gate in snapshot.get("config", {}).get("locked_gates", []):
        var pair := [String(gate.get("from", "")), String(gate.get("to", ""))]
        if pair.has(String(connection.from)) and pair.has(String(connection.to)):
            if not GATE.gate_open(gate, snapshot.get("inventory", {}), snapshot.get("flags", {})):
                return {"open": false, "reason": "门槛尚未开放"}
    return {"open": true, "reason": "当前规则允许"}


static func validate(payload: Dictionary) -> bool:
    if (
        not payload.get("nodes") is Array
        or payload.nodes.size() > MAX_NODES
        or not payload.get("edges") is Array
        or payload.edges.size() > MAX_EDGES
    ):
        return false
    if (
        not payload.get("source") is String
        or not payload.get("region") is String
        or not payload.get("include_blocked") is bool
        or not payload.get("undirected") is bool
    ):
        return false
    var known := {}
    for node in payload.nodes:
        if not node is Dictionary or not node.get("id") is String or known.has(node.id):
            return false
        if (
            not node.get("name") is String
            or node.name.length() > 200
            or not node.get("kind") is String
            or not V.point(node.get("point")).is_finite()
        ):
            return false
        known[node.id] = true
    for edge in payload.edges:
        if (
            not edge is Dictionary
            or not known.has(edge.get("from"))
            or not known.has(edge.get("to"))
            or edge.from == edge.to
        ):
            return false
        if (
            not edge.get("open") is bool
            or not edge.get("reason") is String
            or edge.reason.length() > 200
        ):
            return false
    return V.json_safe(payload, 0, [V.MAX_ITEMS])


static func fields(payload: Dictionary) -> Array:
    var choices := []
    for node in payload.nodes:
        choices.append({"id": node.id, "name": node.name})
    return [
        {"id": "source", "name": "分析起点", "kind": "choice", "choices": choices},
        {"id": "include_blocked", "name": "纳入未开放关系", "kind": "toggle"},
        {"id": "undirected", "name": "按无向关系阅读", "kind": "toggle"}
    ]


static func summary(payload: Dictionary) -> String:
    return "%d 个已知节点 · %d 条有向规则 · %s" % [payload.nodes.size(), payload.edges.size(), payload.region]


static func index(payload: Dictionary) -> Dictionary:
    var result := {}
    for node in payload.nodes:
        result[node.id] = node
    return result


static func adjacency(payload: Dictionary) -> Dictionary:
    var result := {}
    for node in payload.nodes:
        result[node.id] = []
    for edge in payload.edges:
        if not edge.open and not payload.include_blocked:
            continue
        if not result[edge.from].has(edge.to):
            result[edge.from].append(edge.to)
        if payload.undirected and not result[edge.to].has(edge.from):
            result[edge.to].append(edge.from)
    for key in result:
        result[key].sort()
    return result


static func reverse(graph: Dictionary) -> Dictionary:
    var result := {}
    for key in graph:
        result[key] = []
    for key in graph:
        for target in graph[key]:
            result[target].append(key)
    return result


static func breadth(graph: Dictionary, source: String, removed: String = "") -> Dictionary:
    if not graph.has(source) or source == removed:
        return {}
    var distance := {source: 0}
    var queue := [source]
    var cursor := 0
    while cursor < queue.size():
        var node: String = queue[cursor]
        cursor += 1
        for target in graph[node]:
            if target == removed or distance.has(target):
                continue
            distance[target] = int(distance[node]) + 1
            queue.append(target)
    return distance


static func weak_components(graph: Dictionary, removed: String = "") -> Array:
    var both := reverse(graph)
    for key in graph:
        for next in graph[key]:
            if not both[key].has(next):
                both[key].append(next)
    var seen := {}
    var result := []
    for key in graph:
        if key == removed or seen.has(key):
            continue
        var component := breadth(both, String(key), removed).keys()
        for node in component:
            seen[node] = true
        component.sort()
        result.append(component)
    return result


static func strong_components(graph: Dictionary) -> Array:
    var visited := {}
    var finish := []
    for root in graph:
        if visited.has(root):
            continue
        var stack := [[root, 0]]
        visited[root] = true
        while not stack.is_empty():
            var frame: Array = stack[-1]
            var node := String(frame[0])
            var offset := int(frame[1])
            if offset >= graph[node].size():
                finish.append(node)
                stack.pop_back()
                continue
            stack[-1][1] = offset + 1
            var target := String(graph[node][offset])
            if not visited.has(target):
                visited[target] = true
                stack.append([target, 0])
    var flipped := reverse(graph)
    visited.clear()
    var result := []
    finish.reverse()
    for root in finish:
        if visited.has(root):
            continue
        var component := []
        var stack := [root]
        visited[root] = true
        while not stack.is_empty():
            var node := String(stack.pop_back())
            component.append(node)
            for target in flipped[node]:
                if not visited.has(target):
                    visited[target] = true
                    stack.append(target)
        component.sort()
        result.append(component)
    return result


static func articulation(graph: Dictionary) -> Array:
    var original := weak_components(graph).size()
    var result := []
    for node in graph:
        var count := weak_components(graph, String(node)).size()
        if count > original:
            result.append({"id": node, "分组增量": count - original})
    return result


static func bridges(graph: Dictionary) -> Array:
    var original := weak_components(graph).size()
    var result := []
    var seen := {}
    for source in graph:
        for target in graph[source]:
            var pair := [String(source), String(target)]
            pair.sort()
            var key := "|".join(pair)
            if seen.has(key):
                continue
            seen[key] = true
            var sample := graph.duplicate(true)
            sample[source].erase(target)
            sample[target].erase(source)
            if weak_components(sample).size() > original:
                result.append({"from": source, "to": target})
    return result


static func centrality(graph: Dictionary) -> Array:
    var incoming := reverse(graph)
    var result := []
    for node in graph:
        var distances := breadth(graph, String(node))
        var total := 0.0
        var harmonic := 0.0
        var eccentricity := 0
        for other in distances:
            var distance := int(distances[other])
            if distance > 0:
                total += distance
                harmonic += 1.0 / distance
                eccentricity = maxi(eccentricity, distance)
        result.append(
            {
                "id": node,
                "入度": incoming[node].size(),
                "出度": graph[node].size(),
                "可达": distances.size() - 1,
                "平均跳数": total / maxf(1, distances.size() - 1),
                "最远跳数": eccentricity,
                "调和中心性": harmonic
            }
        )
    result.sort_custom(
        func(a: Dictionary, b: Dictionary):
            if is_equal_approx(a["调和中心性"], b["调和中心性"]):
                return String(a.id) < String(b.id)
            return a["调和中心性"] > b["调和中心性"]
    )
    return result


static func levels(graph: Dictionary, source: String) -> Dictionary:
    var result := {}
    var distances := breadth(graph, source)
    for key in distances:
        var distance := int(distances[key])
        var label := "%d 跳" % distance
        result[label] = int(result.get(label, 0)) + 1
    return result


static func topological(graph: Dictionary) -> Dictionary:
    var incoming := reverse(graph)
    var degree := {}
    var ready := []
    for node in graph:
        degree[node] = incoming[node].size()
        if degree[node] == 0:
            ready.append(node)
    ready.sort()
    var order := []
    while not ready.is_empty():
        var node: String = ready.pop_front()
        order.append(node)
        for target in graph[node]:
            degree[target] = int(degree[target]) - 1
            if degree[target] == 0:
                ready.append(target)
                ready.sort()
    return {"acyclic": order.size() == graph.size(), "order": order}


static func shortest_path(graph: Dictionary, source: String, target: String) -> Array:
    if not graph.has(source) or not graph.has(target):
        return []
    var previous := {source: ""}
    var queue := [source]
    var cursor := 0
    while cursor < queue.size() and not previous.has(target):
        var node: String = queue[cursor]
        cursor += 1
        for next in graph[node]:
            if not previous.has(next):
                previous[next] = node
                queue.append(next)
    if not previous.has(target):
        return []
    var result := [target]
    var node := target
    while node != source:
        node = String(previous[node])
        result.push_front(node)
    return result


static func pair_redundancy(graph: Dictionary, source: String, target: String) -> Dictionary:
    var path := shortest_path(graph, source, target)
    if path.is_empty():
        return {"path": [], "survives": 0, "tested": 0}
    var survives := 0
    for offset in range(path.size() - 1):
        var sample := graph.duplicate(true)
        sample[path[offset]].erase(path[offset + 1])
        if not shortest_path(sample, source, target).is_empty():
            survives += 1
    return {"path": path, "survives": survives, "tested": maxi(0, path.size() - 1)}


static func names(ids: Array, nodes: Dictionary) -> String:
    var result: Array[String] = []
    for id in ids:
        result.append(String(nodes.get(id, {}).get("name", "已知空间")))
    return " → ".join(result)


static func component_rows(groups: Array, nodes: Dictionary) -> Array:
    var result := []
    for i in groups.size():
        result.append({"分组": i + 1, "房间数": groups[i].size(), "房间": names(groups[i], nodes)})
    return result


static func _before_advanced_analyze(payload: Dictionary, _snapshot: Dictionary) -> Array:
    var graph := adjacency(payload)
    var nodes := index(payload)
    var distances := breadth(graph, String(payload.source))
    var inaccessible := []
    for id in nodes:
        if not distances.has(id):
            inaccessible.append({"房间": nodes[id].name, "类型": nodes[id].kind})
    var cuts := articulation(graph)
    for row in cuts:
        row["房间"] = nodes[row.id].name
    var links := bridges(graph)
    for row in links:
        row["起点"] = nodes[row.from].name
        row["终点"] = nodes[row.to].name
    var ranks := centrality(graph)
    for row in ranks:
        row["房间"] = nodes[row.id].name
    var alternatives := []
    for node in ranks.slice(0, 10):
        var redundancy := pair_redundancy(graph, String(payload.source), String(node.id))
        alternatives.append(
            {
                "目标": nodes[node.id].name,
                "路径": names(redundancy.path, nodes),
                "单边移除后仍可达": redundancy.survives,
                "受测路径边": redundancy.tested
            }
        )
    var order := topological(graph)
    return [
        K.notice("已知连通结构", summary(payload)),
        {"kind": "custom", "title": "已知空间关系图", "view": VIEW, "data": payload},
        K.notice("规则阅读方式", "包含未开放关系" if payload.include_blocked else "仅当前允许关系"),
        K.table("互相可达分组", ["分组", "房间数", "房间"], component_rows(strong_components(graph), nodes)),
        K.table("忽略方向的分组", ["分组", "房间数", "房间"], component_rows(weak_components(graph), nodes)),
        K.table("起点未能到达的已知节点", ["房间", "类型"], inaccessible),
        K.table("结构割点", ["房间", "分组增量"], cuts, "移除此节点后已知关系图的弱连通分组增加；不是现场机关必经证明。"),
        K.table("结构桥边", ["起点", "终点"], links),
        K.table("已知图中心性", ["房间", "入度", "出度", "可达", "平均跳数", "最远跳数"], ranks),
        K.bars("起点跳数分层", levels(graph, String(payload.source))),
        K.table("最短路径的单边替代测试", ["目标", "路径", "单边移除后仍可达", "受测路径边"], alternatives),
        K.notice("有向循环", "此关系图存在有向循环。" if not order.acyclic else "此关系图无有向循环。"),
        K.notice("边界", "只分析记录中的节点和规则。不推断未发现房间、秘密通路、敌人AI或实际跳跃可达性。")
    ]


static func compare(a: Dictionary, b: Dictionary) -> Array:
    var first := adjacency(a)
    var second := adjacency(b)
    var changed := []
    var nodes := index(b)
    for id in second:
        var old: Array = first.get(id, [])
        for next in second[id]:
            if not old.has(next):
                changed.append({"关系": "新增", "起点": nodes[id].name, "终点": nodes[next].name})
        for next in old:
            if not second[id].has(next):
                changed.append(
                    {
                        "关系": "本次未包含",
                        "起点": nodes[id].name,
                        "终点": String(index(a).get(next, {}).get("name", "已知空间"))
                    }
                )
    return [
        K.table("已知规则变化", ["关系", "起点", "终点"], changed),
        K.notice(
            "分组变化",
            (
                "强连通分组 %d → %d；弱连通分组 %d → %d。"
                % [
                    strong_components(first).size(),
                    strong_components(second).size(),
                    weak_components(first).size(),
                    weak_components(second).size()
                ]
            )
        )
    ]


static func analyze(payload: Dictionary, snapshot: Dictionary) -> Array:
    return _before_advanced_analyze(payload, snapshot) + ADVANCED.sections(payload, adjacency(payload)) + [{"kind":"custom","title":"路线容错与有向最小割 · 交互预览","view":ADVANCED_VIEW,"data":{"nodes":payload.nodes,"graph":adjacency(payload)}}]
