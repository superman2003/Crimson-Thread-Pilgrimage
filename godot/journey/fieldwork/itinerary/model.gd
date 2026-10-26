extends RefCounted
const K := preload("res://journey/fieldwork/knowledge.gd")
const V := preload("res://journey/fieldwork/scalars.gd")
const GRAPH := preload("res://journey/fieldwork/network/model.gd")
const VIEW := preload("res://journey/fieldwork/itinerary/view.gd")
const MAX_STOPS := 10


static func introduction() -> String:
    return "在已抵达房间的当前通行规则上排定多站行程。小规模可精确求解，另提供最近邻及改良方案；所有时间均为个人速度假设下的估算。"


static func capture(snapshot: Dictionary) -> Dictionary:
    var graph := GRAPH.capture(snapshot)
    var stops := []
    for node in graph.nodes:
        if node.id != graph.source and stops.size() < 3:
            stops.append(node.id)
    return {
        "graph": graph,
        "stops": stops,
        "start": graph.source,
        "return": false,
        "speed": 250.0,
        "dwell": 20.0,
        "budget": 600.0,
        "method": "exact",
        "skip_unreachable": false
    }


static func validate(payload: Dictionary) -> bool:
    if not payload.get("graph") is Dictionary or not GRAPH.validate(payload.graph):
        return false
    if payload.graph.include_blocked or payload.graph.undirected:
        return false
    if (
        not payload.get("stops") is Array
        or payload.stops.size() > MAX_STOPS
        or not payload.get("start") is String
    ):
        return false
    if (
        not payload.get("return") is bool
        or not payload.get("skip_unreachable") is bool
        or payload.get("method") not in ["exact", "nearest", "improved", "budget"]
    ):
        return false
    for key in ["speed", "dwell", "budget"]:
        if not V.number(payload.get(key)):
            return false
    if (
        payload.speed < 1
        or payload.speed > 10000
        or payload.dwell < 0
        or payload.dwell > 3600
        or payload.budget < 1
        or payload.budget > 86400
    ):
        return false
    var nodes := GRAPH.index(payload.graph)
    if not nodes.is_empty() and not nodes.has(payload.start):
        return false
    var seen := {}
    for id in payload.stops:
        if not id is String or not nodes.has(id) or seen.has(id):
            return false
        seen[id] = true
    return V.json_safe(payload, 0, [V.MAX_ITEMS])


static func fields(payload: Dictionary) -> Array:
    var choices := []
    for node in payload.graph.nodes:
        choices.append({"id": node.id, "name": node.name})
    return [
        {"id": "start", "name": "出发房间", "kind": "choice", "choices": choices},
        {"id": "stops", "name": "访问站点（最多10站）", "kind": "checklist", "limit": MAX_STOPS, "choices": choices},
        {"id": "return", "name": "回到起点", "kind": "toggle"},
        {"id": "skip_unreachable", "name": "单独列出不可达目标", "kind": "toggle"},
        {"id": "speed", "name": "个人估算速度", "kind": "number", "min": 1, "max": 10000, "step": 10},
        {"id": "dwell", "name": "每站停留秒数", "kind": "number", "min": 0, "max": 3600},
        {"id": "budget", "name": "时间预算秒数", "kind": "number", "min": 1, "max": 86400, "step": 30},
        {
            "id": "method",
            "name": "排程方法",
            "kind": "choice",
            "choices":
            [
                {"id": "exact", "name": "精确最短总距离"},
                {"id": "nearest", "name": "最近邻"},
                {"id": "improved", "name": "最近邻与顺序改良"},
                {"id": "budget", "name": "预算内增量访问"}
            ]
        }
    ]


static func summary(payload: Dictionary) -> String:
    return "%d 个目标 · 个人速度 %.0f · 每站 %.0f 秒" % [payload.stops.size(), payload.speed, payload.dwell]


static func edge_distance(a: Dictionary, b: Dictionary) -> float:
    return maxf(1.0, V.point(a.point).distance_to(V.point(b.point)))


static func shortest(payload: Dictionary, source: String, target: String) -> Dictionary:
    var graph := GRAPH.adjacency(payload.graph)
    var nodes := GRAPH.index(payload.graph)
    if not nodes.has(source) or not nodes.has(target):
        return {"ok": false, "path": [], "distance": INF}
    var distance := {source: 0.0}
    var previous := {}
    var pending := {source: true}
    var settled := {}
    while not pending.is_empty():
        var current := ""
        var smallest := INF
        for key in pending:
            if float(distance[key]) < smallest:
                current = String(key)
                smallest = float(distance[key])
        pending.erase(current)
        if current == target:
            break
        settled[current] = true
        for next in graph[current]:
            if settled.has(next):
                continue
            var candidate := smallest + edge_distance(nodes[current], nodes[next])
            if candidate < float(distance.get(next, INF)):
                distance[next] = candidate
                previous[next] = current
                pending[next] = true
    if not distance.has(target):
        return {"ok": false, "path": [], "distance": INF}
    var path := [target]
    var cursor := target
    while cursor != source:
        if not previous.has(cursor):
            return {"ok": false, "path": [], "distance": INF}
        cursor = String(previous[cursor])
        path.push_front(cursor)
    return {"ok": true, "path": path, "distance": float(distance[target])}


static func targets(payload: Dictionary) -> Array:
    var result := []
    for id in payload.stops:
        if id != payload.start and not result.has(id):
            result.append(id)
    return result


static func matrix(payload: Dictionary) -> Dictionary:
    var nodes := [payload.start] + targets(payload)
    var costs := {}
    var paths := {}
    for a in nodes:
        costs[a] = {}
        paths[a] = {}
        for b in nodes:
            var result := shortest(payload, String(a), String(b))
            costs[a][b] = result.distance
            paths[a][b] = result.path
    return {"nodes": nodes, "costs": costs, "paths": paths}


static func route_cost(order: Array, costs: Dictionary, return_home: bool) -> float:
    var total := 0.0
    if order.is_empty():
        return total
    for i in range(1, order.size()):
        total += float(costs.get(order[i - 1], {}).get(order[i], INF))
    if return_home and order.size() > 1:
        total += float(costs.get(order[-1], {}).get(order[0], INF))
    return total


static func exact(payload: Dictionary, data: Dictionary) -> Dictionary:
    var stops := targets(payload)
    if stops.is_empty():
        return {"ok": true, "order": [payload.start], "distance": 0.0, "states": 0}
    var dp := {}
    var parent := {}
    for i in stops.size():
        var cost := float(data.costs[payload.start][stops[i]])
        if is_finite(cost):
            var key := str(1 << i) + ":" + str(i)
            dp[key] = cost
            parent[key] = -1
    var states := 0
    for mask in range(1, 1 << stops.size()):
        for last in stops.size():
            var key := str(mask) + ":" + str(last)
            if not dp.has(key):
                continue
            states += 1
            for next in stops.size():
                if mask & (1 << next):
                    continue
                var next_mask := mask | (1 << next)
                var next_key := str(next_mask) + ":" + str(next)
                var candidate := float(dp[key]) + float(data.costs[stops[last]][stops[next]])
                if candidate < float(dp.get(next_key, INF)):
                    dp[next_key] = candidate
                    parent[next_key] = last
    var full := (1 << stops.size()) - 1
    var best := INF
    var endpoint := -1
    for last in stops.size():
        var key := str(full) + ":" + str(last)
        var candidate := float(dp.get(key, INF))
        if payload.get("return", false):
            candidate += float(data.costs[stops[last]][payload.start])
        if candidate < best:
            best = candidate
            endpoint = last
    if endpoint < 0:
        return {"ok": false, "order": [], "distance": INF, "states": states}
    var order := []
    var mask := full
    while endpoint >= 0:
        order.push_front(stops[endpoint])
        var previous := int(parent[str(mask) + ":" + str(endpoint)])
        mask = mask & ~(1 << endpoint)
        endpoint = previous
    order.push_front(payload.start)
    return {"ok": true, "order": order, "distance": best, "states": states}


static func nearest(payload: Dictionary, data: Dictionary) -> Dictionary:
    var remaining := targets(payload)
    var order := [payload.start]
    while not remaining.is_empty():
        var target := ""
        var best := INF
        for candidate in remaining:
            var cost := float(data.costs[order[-1]][candidate])
            if cost < best or (is_equal_approx(cost, best) and String(candidate) < target):
                best = cost
                target = String(candidate)
        if target.is_empty():
            return {"ok": false, "order": order, "distance": INF, "states": 0}
        order.append(target)
        remaining.erase(target)
    var cost := route_cost(order, data.costs, bool(payload.get("return", false)))
    return {"ok": is_finite(cost), "order": order, "distance": cost, "states": 0}


static func improve(payload: Dictionary, data: Dictionary) -> Dictionary:
    var solution := nearest(payload, data)
    if not solution.ok:
        return solution
    var order: Array = solution.order.duplicate()
    var best := float(solution.distance)
    var changed := true
    var passes := 0
    while changed and passes < 30:
        changed = false
        passes += 1
        for i in range(1, order.size() - 1):
            for j in range(i + 1, order.size()):
                var candidate := order.duplicate()
                var section := candidate.slice(i, j + 1)
                section.reverse()
                for offset in section.size():
                    candidate[i + offset] = section[offset]
                var cost := route_cost(candidate, data.costs, bool(payload.get("return", false)))
                if cost + 0.001 < best:
                    order = candidate
                    best = cost
                    changed = true
    return {"ok": true, "order": order, "distance": best, "states": passes}


static func budget_route(payload: Dictionary, data: Dictionary) -> Dictionary:
    var remaining := targets(payload)
    var order := [payload.start]
    while not remaining.is_empty():
        var winner := ""
        var cheapest := INF
        for id in remaining:
            var sample := order + [id]
            var cost := route_cost(sample, data.costs, bool(payload.get("return", false)))
            var seconds := cost / float(payload.speed) + (sample.size() - 1) * float(payload.dwell)
            if seconds <= float(payload.budget) and cost < cheapest:
                winner = String(id)
                cheapest = cost
        if winner.is_empty():
            break
        order.append(winner)
        remaining.erase(winner)
    var distance := route_cost(order, data.costs, bool(payload.get("return", false)))
    return {"ok": true, "order": order, "distance": distance, "states": 0, "omitted": remaining}


static func solve(payload: Dictionary, data: Dictionary) -> Dictionary:
    if payload.skip_unreachable:
        var sample := payload.duplicate(true)
        sample.skip_unreachable = false
        sample.stops = []
        var excluded := []
        for id in targets(payload):
            var allowed := is_finite(float(data.costs[payload.start][id]))
            if payload.get("return", false):
                allowed = allowed and is_finite(float(data.costs[id][payload.start]))
            if allowed:
                sample.stops.append(id)
            else:
                excluded.append(id)
        var partial := solve(sample, data)
        partial["excluded"] = excluded
        return partial
    match String(payload.method):
        "nearest":
            return nearest(payload, data)
        "improved":
            return improve(payload, data)
        "budget":
            return budget_route(payload, data)
    return exact(payload, data)


static func schedule(payload: Dictionary, solution: Dictionary, data: Dictionary) -> Array:
    if not solution.ok:
        return []
    var order: Array = solution.order.duplicate()
    if payload.get("return", false) and order.size() > 1:
        order.append(order[0])
    var result := []
    var elapsed := 0.0
    var nodes := GRAPH.index(payload.graph)
    for i in range(1, order.size()):
        var distance := float(data.costs[order[i - 1]][order[i]])
        var travel := distance / float(payload.speed)
        var path: Array = data.paths[order[i - 1]][order[i]]
        elapsed += travel
        var arrival := elapsed
        var dwell := (
            float(payload.dwell)
            if i < order.size() - 1 or not payload.get("return", false)
            else 0.0
        )
        elapsed += dwell
        result.append(
            {
                "站点": i,
                "起点": nodes[order[i - 1]].name,
                "终点": nodes[order[i]].name,
                "距离": distance,
                "旅行秒": travel,
                "到达秒": arrival,
                "离开秒": elapsed,
                "停留秒": dwell,
                "路径": GRAPH.names(path, nodes),
                "超预算": elapsed > float(payload.budget)
            }
        )
    return result


static func verify(payload: Dictionary, solution: Dictionary, data: Dictionary) -> Dictionary:
    if (
        not solution.get("ok", false)
        or solution.order.is_empty()
        or solution.order[0] != payload.start
    ):
        return {"ok": false, "reason": "路线没有有效起点。"}
    var graph := GRAPH.adjacency(payload.graph)
    var visited := {}
    for id in solution.order:
        if visited.has(id):
            return {"ok": false, "reason": "目标重复。"}
        visited[id] = true
    var nodes := GRAPH.index(payload.graph)
    for id in solution.order:
        if not nodes.has(id) or (id != payload.start and not targets(payload).has(id)):
            return {"ok": false, "reason": "路线包含非候选站点。"}
    if payload.method != "budget":
        for id in targets(payload):
            if not visited.has(id) and not solution.get("excluded", []).has(id):
                return {"ok": false, "reason": "路线漏掉了目标站点。"}
    var order: Array = solution.order.duplicate()
    if payload.get("return", false) and order.size() > 1:
        order.append(order[0])
    for i in range(1, order.size()):
        var path: Array = data.paths.get(order[i - 1], {}).get(order[i], [])
        if path.is_empty() or path[0] != order[i - 1] or path[-1] != order[i]:
            return {"ok": false, "reason": "路径端点不符。"}
        var distance := 0.0
        for j in range(1, path.size()):
            if not graph.get(path[j - 1], []).has(path[j]):
                return {"ok": false, "reason": "路径引用了当前图中不存在的边。"}
            distance += edge_distance(nodes[path[j - 1]], nodes[path[j]])
        if absf(distance - float(data.costs[order[i - 1]][order[i]])) > 0.01:
            return {"ok": false, "reason": "单段距离复核不符。"}
    var expected := route_cost(solution.order, data.costs, bool(payload.get("return", false)))
    if not is_finite(expected) or absf(expected - float(solution.distance)) > 0.01:
        return {"ok": false, "reason": "距离复核不符。"}
    return {"ok": true, "reason": "路径边与距离复核通过。"}


static func sensitivity(payload: Dictionary, solution: Dictionary) -> Array:
    if not solution.ok:
        return []
    var result := []
    var visits := maxi(0, solution.order.size() - 1)
    for multiplier in [0.5, 0.75, 1.0, 1.25, 1.5]:
        var speed := float(payload.speed) * float(multiplier)
        var seconds := float(solution.distance) / speed + visits * float(payload.dwell)
        result.append({"速度假设": speed, "预计秒数": seconds, "预算差秒": float(payload.budget) - seconds})
    return result


static func matrix_rows(data: Dictionary, nodes: Dictionary) -> Array:
    var result := []
    for a in data.nodes:
        for b in data.nodes:
            if a == b:
                continue
            var distance := float(data.costs[a][b])
            result.append(
                {
                    "起点": nodes[a].name,
                    "终点": nodes[b].name,
                    "距离": snappedf(distance, 0.1) if is_finite(distance) else "当前图不可达"
                }
            )
    return result


static func analyze(payload: Dictionary, _snapshot: Dictionary) -> Array:
    var data := matrix(payload)
    var solution := solve(payload, data)
    var nodes := GRAPH.index(payload.graph)
    var result := [K.notice("多站排程", summary(payload))]
    if not solution.ok:
        result.append(K.notice("未生成完整行程", "选中的目标存在不可达关系。可减少目标或使用预算内增量访问；不会凭空补上未知路线。"))
        result.append(K.table("站间有向距离", ["起点", "终点", "距离"], matrix_rows(data, nodes)))
        return result
    var rows := schedule(payload, solution, data)
    var verified := verify(payload, solution, data)
    result.append(
        K.notice(
            "求解与复核",
            (
                "顺序：%s\n距离 %.1f · %s"
                % [GRAPH.names(solution.order + ([solution.order[0]] if payload.get("return", false) and solution.order.size() > 1 else []), nodes), solution.distance, verified.reason]
            )
        )
    )
    result.append(
        {
            "kind": "custom",
            "title": "个人时间预算图",
            "view": VIEW,
            "data": {"rows": rows, "budget": payload.budget}
        }
    )
    result.append(K.table("逐站排程", ["站点", "起点", "终点", "距离", "旅行秒", "到达秒", "离开秒", "超预算", "路径"], rows))
    result.append(K.table("速度假设敏感性", ["速度假设", "预计秒数", "预算差秒"], sensitivity(payload, solution)))
    var comparisons := []
    for method in ["exact", "nearest", "improved", "budget"]:
        var sample := payload.duplicate(true)
        sample.method = method
        var other := solve(sample, data)
        comparisons.append(
            {
                "方法": method,
                "访问目标": maxi(0, other.order.size() - 1),
                "总距离": other.distance if other.ok else "无完整解",
                "处理状态数": other.states
            }
        )
    result.append(K.table("方法比较", ["方法", "访问目标", "总距离", "处理状态数"], comparisons))
    var visited_data := data.duplicate(true)
    visited_data.nodes = solution.order.duplicate()
    result.append(K.notice("距离下界参考", bound_report(visited_data, solution)))
    var omitted := targets(payload).filter(func(id: String): return not solution.order.has(id))
    if not omitted.is_empty():
        result.append(K.notice("本方案未访问目标", GRAPH.names(omitted, nodes)))
    if solution.has("excluded") and not solution.excluded.is_empty():
        result.append(K.notice("单独列出的不可达目标", GRAPH.names(solution.excluded, nodes)))
    result.append(K.notice("估算边界", "采用已知房间中心间的规则距离。没有模拟落脚、攀爬、战斗、平台等待或实际游戏耗时。"))
    return result


static func compare(a: Dictionary, b: Dictionary) -> Array:
    var left := solve(a, matrix(a))
    var right := solve(b, matrix(b))
    return [
        K.table(
            "排程变化",
            ["样本", "访问目标", "总距离", "速度假设", "停留秒"],
            [
                {
                    "样本": "记录",
                    "访问目标": maxi(0, left.order.size() - 1),
                    "总距离": left.distance if left.ok else "无完整解",
                    "速度假设": a.speed,
                    "停留秒": a.dwell
                },
                {
                    "样本": "当前",
                    "访问目标": maxi(0, right.order.size() - 1),
                    "总距离": right.distance if right.ok else "无完整解",
                    "速度假设": b.speed,
                    "停留秒": b.dwell
                }
            ]
        )
    ]


static func minimum_spanning_bound(data: Dictionary) -> Dictionary:
    var nodes: Array = data.nodes
    if nodes.is_empty():
        return {"connected": true, "distance": 0.0, "edges": []}
    var selected := {String(nodes[0]): true}
    var edges := []
    var total := 0.0
    while selected.size() < nodes.size():
        var best := INF
        var from := ""
        var to := ""
        for a in selected:
            for b in nodes:
                if selected.has(b):
                    continue
                var forward := float(data.costs[a][b])
                var backward := float(data.costs[b][a])
                var weight := minf(forward, backward)
                if weight < best:
                    best = weight
                    from = String(a)
                    to = String(b)
        if to.is_empty():
            return {"connected": false, "distance": INF, "edges": edges}
        edges.append({"from": from, "to": to, "distance": best})
        selected[to] = true
        total += best
    return {"connected": true, "distance": total, "edges": edges}


static func bound_report(data: Dictionary, solution: Dictionary) -> String:
    var lower := minimum_spanning_bound(data)
    if not lower.connected:
        return "已知关系在忽略方向后仍不能连接全部目标。"
    var gap := maxf(0, float(solution.distance) - float(lower.distance))
    return "忽略方向的生成树距离下界 %.1f；当前方案超出下界 %.1f。下界不是现场行走证明，也不等于最优行程。" % [lower.distance, gap]
