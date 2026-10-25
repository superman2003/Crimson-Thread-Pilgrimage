extends RefCounted
const V := preload("res://journey/core/values.gd")
const STORY := preload("res://scripts/world_narrative.gd")
const MAX_LINKS := 64
const RELATIONS := {"related":"相关", "supports":"相互支持", "questions":"待核对", "contrasts":"存在疑问"}

static func fresh() -> Dictionary:
    return {"version":1, "links":[], "notes":{}, "positions":{}, "seen_npcs":{}, "sequence":0}

static func valid(data: Dictionary) -> bool:
    if data.get("version") != 1 or not V.count(data.get("sequence")):
        return false
    if not data.get("links") is Array or data.links.size() > MAX_LINKS:
        return false
    for field in ["notes", "positions", "seen_npcs"]:
        if not data.get(field) is Dictionary or data[field].size() > 200:
            return false
    var ids := {}
    for link in data.links:
        if not link is Dictionary or not link.get("id") is String or ids.has(link.id):
            return false
        if not link.get("from") is String or not link.get("to") is String or link.from == link.to:
            return false
        if not RELATIONS.has(link.get("kind")) or not link.get("note") is String or link.note.length() > 500:
            return false
        ids[link.id] = true
    for id in data.notes:
        if not id is String or not data.notes[id] is String or data.notes[id].length() > 1200:
            return false
    for id in data.positions:
        var point := V.point(data.positions[id])
        if not point.is_finite() or point.x < 0 or point.x > 1 or point.y < 0 or point.y > 1:
            return false
    for id in data.seen_npcs:
        if not data.seen_npcs[id] is Dictionary or not data.seen_npcs[id].get("title") is String:
            return false
    return V.json_safe(data, 0, [V.MAX_ITEMS])

static func observe(data: Dictionary, snapshot: Dictionary) -> Dictionary:
    var result := data.duplicate(true)
    var flags: Dictionary = snapshot.get("flags", {})
    for npc in snapshot.get("config", {}).get("npcs", []):
        var id := String(npc.get("id", ""))
        if flags.get("npc_met_" + id) != true or result.seen_npcs.has(id):
            continue
        if result.seen_npcs.size() >= 200:
            break
        result.seen_npcs[id] = {"title":String(npc.get("name", "已见人物")), "region":String(snapshot.get("region_name", "")), "description":String(npc.get("role", ""))}
    return result

static func graph(data: Dictionary, snapshot: Dictionary) -> Dictionary:
    var story := STORY.new()
    var inventory: Dictionary = snapshot.get("inventory", {})
    var flags: Dictionary = snapshot.get("flags", {})
    var public: Dictionary = story.evaluate_progress(inventory, flags)
    var nodes := {}
    var edges := []
    for record in public.get("known_entries", []):
        var id := "evidence:" + String(record.get("id", ""))
        nodes[id] = {"id":id, "title":String(record.get("title", "证词")), "kind":"evidence", "status":"已取得" if record.get("acquired", false) else "已知线索", "text":String(record.get("description", record.get("text", ""))), "guidance":String(record.get("hint", ""))}
    for record in public.get("quests", []):
        var id := "quest:" + String(record.get("id", ""))
        var text := String(record.get("description", ""))
        for step in record.get("steps", []):
            if step.get("complete", false):
                text += "\n已完成：" + String(step.get("label", ""))
        nodes[id] = {"id":id, "title":String(record.get("title", "委托")), "kind":"quest", "status":"已完成" if record.get("status") == "complete" else "进行中", "text":text, "guidance":String(record.get("guidance", ""))}
    for id in data.seen_npcs:
        if flags.get("npc_met_" + String(id)) != true:
            continue
        var record: Dictionary = data.seen_npcs[id]
        var key := "npc:" + String(id)
        nodes[key] = {"id":key, "title":String(record.title), "kind":"npc", "status":"已交谈", "text":String(record.get("description", "")), "guidance":String(record.get("region", ""))}
    for record in public.get("endings", []):
        if not record.get("chosen", false):
            continue
        var id := "ending:" + String(record.id)
        nodes[id] = {"id":id, "title":String(record.get("title", "旅途结局")), "kind":"ending", "status":"已选择", "text":String(record.get("description", "")), "guidance":""}
    for link in story.evidence_connections(inventory):
        var required: Array = link.get("evidence_all", [])
        for index in range(1, required.size()):
            var a := "evidence:" + String(required[index - 1])
            var b := "evidence:" + String(required[index])
            if nodes.has(a) and nodes.has(b):
                edges.append({"id":"authored:" + str(edges.size()), "from":a, "to":b, "kind":"authored", "note":String(link.get("text", ""))})
    for link in data.links:
        if nodes.has(link.from) and nodes.has(link.to):
            edges.append(link.duplicate(true))
    return {"nodes":nodes, "edges":edges}

static func connect_nodes(data: Dictionary, graph: Dictionary, a: String, b: String, kind: String, note: String) -> Dictionary:
    var result := data.duplicate(true)
    if a == b or not graph.nodes.has(a) or not graph.nodes.has(b) or not RELATIONS.has(kind):
        return result
    if result.links.size() >= MAX_LINKS:
        return result
    for link in result.links:
        if ((link.from == a and link.to == b) or (link.from == b and link.to == a)) and link.kind == kind:
            return result
    result.sequence = int(result.sequence) + 1
    result.links.append({"id":"thought_" + str(int(result.sequence)), "from":a, "to":b, "kind":kind, "note":V.text(note, 500)})
    return result

static func annotate(data: Dictionary, graph: Dictionary, id: String, note: String) -> Dictionary:
    var result := data.duplicate(true)
    if not graph.nodes.has(id):
        return result
    var clean := V.text(note, 1200)
    if clean.is_empty():
        result.notes.erase(id)
    else:
        result.notes[id] = clean
    return result

static func move(data: Dictionary, graph: Dictionary, id: String, point: Vector2) -> Dictionary:
    var result := data.duplicate(true)
    if graph.nodes.has(id) and point.is_finite():
        result.positions[id] = V.pair(point.clamp(Vector2.ZERO, Vector2.ONE))
    return result

static func remove_link(data: Dictionary, id: String) -> Dictionary:
    var result := data.duplicate(true)
    for index in range(result.links.size() - 1, -1, -1):
        if result.links[index].id == id:
            result.links.remove_at(index)
    return result

static func filtered(graph: Dictionary, data: Dictionary, query: String, kind: String) -> Dictionary:
    var nodes := {}
    for id in graph.nodes:
        var node: Dictionary = graph.nodes[id]
        if kind != "all" and node.kind != kind:
            continue
        if V.matches(query, [String(node.title), String(node.text), String(data.notes.get(id, "")), String(node.guidance)]):
            nodes[id] = node.duplicate(true)
    var edges := []
    for edge in graph.edges:
        if nodes.has(edge.from) and nodes.has(edge.to):
            edges.append(edge.duplicate(true))
    return {"nodes":nodes, "edges":edges}

static func connected(graph: Dictionary, id: String) -> Array:
    var result := []
    for edge in graph.edges:
        if edge.from == id or edge.to == id:
            var peer := String(edge.to if edge.from == id else edge.from)
            if graph.nodes.has(peer):
                result.append({"node":graph.nodes[peer], "edge":edge})
    return result

static func components(graph: Dictionary) -> Array:
    var seen := {}
    var groups := []
    for id in graph.nodes:
        if seen.has(id):
            continue
        var group := []
        var pending := [id]
        while not pending.is_empty() and group.size() <= 200:
            var current: String = pending.pop_front()
            if seen.has(current):
                continue
            seen[current] = true
            group.append(current)
            for link in connected(graph, current):
                if not seen.has(link.node.id):
                    pending.append(link.node.id)
        groups.append(group)
    return groups

static func document(graph: Dictionary, data: Dictionary) -> String:
    var lines: Array[String] = ["已知故事关系板", "个人连线只代表阅读假设，不推进剧情或授予证词。", ""]
    for id in graph.nodes:
        var node: Dictionary = graph.nodes[id]
        lines.append("【%s】%s" % [node.status, node.title])
        lines.append(String(node.text))
        if data.notes.has(id):
            lines.append("我的手记：" + String(data.notes[id]))
        lines.append("")
    lines.append("关系：")
    for edge in graph.edges:
        var label := "正文关联" if edge.kind == "authored" else String(RELATIONS.get(edge.kind, "个人假设"))
        lines.append("%s ↔ %s · %s" % [graph.nodes[edge.from].title, graph.nodes[edge.to].title, label])
        lines.append(String(edge.note))
    return "\n".join(lines)

static func chain(graph: Dictionary, source: String, target: String) -> Dictionary:
    if not graph.get("nodes", {}).has(source) or not graph.nodes.has(target):
        return {"ok":false, "reason":"只查找当前公开条目之间的关系链。"}
    var pending := [source]
    var seen := {source:true}
    var previous := {}
    while not pending.is_empty() and seen.size() <= 200:
        var current: String = pending.pop_front()
        if current == target:
            break
        for relationship in connected(graph, current):
            var next := String(relationship.node.id)
            if seen.has(next):
                continue
            seen[next] = true
            previous[next] = {"from":current, "edge":relationship.edge}
            pending.append(next)
    if not seen.has(target):
        return {"ok":false, "reason":"当前已知连线没有形成这条关系链。"}
    var nodes := [target]
    var edges := []
    var cursor := target
    while cursor != source:
        if not previous.has(cursor) or nodes.size() > 200:
            return {"ok":false, "reason":"关系链无法复核。"}
        var step: Dictionary = previous[cursor]
        edges.push_front(step.edge)
        cursor = String(step.from)
        nodes.push_front(cursor)
    var hypotheses := 0
    for edge in edges:
        if edge.kind != "authored":
            hypotheses += 1
    return {"ok":true, "nodes":nodes, "edges":edges, "hypotheses":hypotheses, "reason":"最少连线关系链；存在路径不代表因果关系或剧情结论。"}
