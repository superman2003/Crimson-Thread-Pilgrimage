extends RefCounted
## Unit-capacity directed max flow, with a separately verified cut certificate.
## Parallel configuration rows represent the same doorway and are deduplicated.
const K := preload("res://journey/fieldwork/knowledge.gd")
const LIMIT := 120


static func normalize(graph: Dictionary) -> Dictionary:
    if graph.size() > LIMIT:
        return {"ok": false, "reason": "节点超过120个"}
    var clean := {}
    var keys := graph.keys()
    keys.sort()
    for id in keys:
        if not id is String or not graph[id] is Array:
            return {"ok": false, "reason": "图字段无效"}
        clean[id] = []
        for target in graph[id]:
            if not target is String or not graph.has(target):
                return {"ok": false, "reason": "边引用未知节点"}
            if target != id and not clean[id].has(target):
                clean[id].append(target)
        clean[id].sort()
    return {"ok": true, "graph": clean}


static func reachable(graph: Dictionary, source: String, blocked: Dictionary = {}) -> Array:
    if not graph.has(source):
        return []
    var queue := [source]
    var seen := {source: true}
    var cursor := 0
    while cursor < queue.size():
        var current: String = queue[cursor]
        cursor += 1
        for target in graph[current]:
            if blocked.has(JSON.stringify([current, target])) or seen.has(target):
                continue
            seen[target] = true
            queue.append(target)
    return queue


static func solve(graph: Dictionary, source: String, sink: String) -> Dictionary:
    var normalized := normalize(graph)
    if not normalized.ok:
        return normalized
    graph = normalized.graph
    if not graph.has(source) or not graph.has(sink) or source == sink:
        return {"ok": false, "reason": "请选择两个不同的已知节点"}
    var residual := {}
    var original := {}
    for id in graph:
        residual[id] = {}
        original[id] = {}
    for id in graph:
        for target in graph[id]:
            original[id][target] = 1
            residual[id][target] = int(residual[id].get(target, 0)) + 1
            if not residual[target].has(id):
                residual[target][id] = 0
    var flow := 0
    while flow < graph.size():
        var parents := {source: ""}
        var queue := [source]
        var cursor := 0
        while cursor < queue.size() and not parents.has(sink):
            var id: String = queue[cursor]
            cursor += 1
            var targets: Array = residual[id].keys()
            targets.sort()
            for target in targets:
                if int(residual[id][target]) > 0 and not parents.has(target):
                    parents[target] = id
                    queue.append(target)
        if not parents.has(sink):
            break
        var current := sink
        while current != source:
            var previous: String = parents[current]
            residual[previous][current] -= 1
            residual[current][previous] = int(residual[current].get(previous, 0)) + 1
            current = previous
        flow += 1
    var side := {source: true}
    var queue := [source]
    var cursor := 0
    while cursor < queue.size():
        var id: String = queue[cursor]
        cursor += 1
        for target in residual[id]:
            if int(residual[id][target]) > 0 and not side.has(target):
                side[target] = true
                queue.append(target)
    var cut := []
    for id in graph:
        if not side.has(id):
            continue
        for target in graph[id]:
            if not side.has(target):
                cut.append({"from": id, "to": target})
    var blocked := {}
    for edge in cut:
        blocked[JSON.stringify([edge.from, edge.to])] = true
    var certified := cut.size() == flow and not reachable(graph, source, blocked).has(sink)
    return {
        "ok": certified, "count": flow, "cut": cut, "source_side": side.keys(),
        "reason": "有向最小割证书复核通过" if certified else "最小割证书不一致"
    }


static func vulnerability(graph: Dictionary, source: String, maximum: int = 12) -> Array:
    var result := []
    var normalized := normalize(graph)
    if not normalized.ok or not graph.has(source):
        return result
    var targets := reachable(normalized.graph, source)
    targets.erase(source)
    targets.sort()
    for target in targets.slice(0, clampi(maximum, 0, LIMIT)):
        var forward := solve(normalized.graph, source, target)
        var backward := solve(normalized.graph, target, source)
        if forward.ok and backward.ok:
            result.append({
                "id": target, "outbound": forward.count, "return": backward.count,
                "cut": forward.cut, "return_cut": backward.cut,
                "single_failure": mini(forward.count, backward.count) < 2
            })
    result.sort_custom(func(a: Dictionary, b: Dictionary):
        if a.single_failure != b.single_failure:
            return a.single_failure
        return String(a.id) < String(b.id))
    return result


static func edge_impact(graph: Dictionary, source: String, maximum: int = 80) -> Array:
    var result := []
    var normalized := normalize(graph)
    if not normalized.ok:
        return result
    graph = normalized.graph
    var before := reachable(graph, source)
    var tested := 0
    for id in graph:
        for target in graph[id]:
            if tested >= maximum:
                return result
            tested += 1
            var after := reachable(graph, source, {JSON.stringify([id, target]): true})
            var lost := before.filter(func(node: String): return not after.has(node))
            if not lost.is_empty():
                result.append({"from": id, "to": target, "lost": lost})
    return result


static func sections(payload: Dictionary, graph: Dictionary) -> Array:
    var labels := {}
    for node in payload.nodes:
        labels[node.id] = node.name
    var rows := []
    var cuts := []
    var sample := vulnerability(graph, String(payload.source))
    for row in sample:
        rows.append({
            "目的地": labels.get(row.id, row.id), "去程独立门路": row.outbound,
            "返程独立门路": row.return,
            "单门失效风险": "是" if row.single_failure else "至少两路"
        })
        for edge in row.cut:
            cuts.append({
                "目的地": labels.get(row.id, row.id),
                "割边起点": labels.get(edge.from, edge.from),
                "割边终点": labels.get(edge.to, edge.to)
            })
    var impacts := []
    for row in edge_impact(graph, String(payload.source)):
        impacts.append({
            "门路": str(labels.get(row.from, row.from)) + " → " + str(labels.get(row.to, row.to)),
            "失联已知房间数": row.lost.size()
        })
    return [
        K.notice("有向门路容错", "每条不同的有向房间关系容量为1。相反方向分别计算；同一门路不能重复计作备选。最多展示按ID前12个可达目的地、审计前80条边。"),
        K.table("去程与返程独立门路", ["目的地", "去程独立门路", "返程独立门路", "单门失效风险"], rows),
        K.table("最小割证书", ["目的地", "割边起点", "割边终点"], cuts),
        K.table("单条门路失效影响", ["门路", "失联已知房间数"], impacts,
            "这是已知规则图的容错分析，不模拟角色碰撞、战斗、地图外路线或真实封门。纳入未开放关系时仅表示假设图。")
    ]
