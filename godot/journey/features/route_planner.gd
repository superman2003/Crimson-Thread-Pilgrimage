extends "res://journey/core/feature.gd"
const GRAPH := preload("res://journey/routes/graph.gd")
const VIEW := preload("res://journey/routes/view.gd")
var source := ""
var target := ""
var graph: Dictionary = {}
var alternatives: Array = []
var route_index := 0
var preferences := {"avoid_boss":false, "avoid_hazards":false, "risk_weight":1.0}
var note_draft := ""
var status_message := ""
var pending_remove := ""

func descriptor() -> Dictionary:
    return {"id":"route_planner", "name":"路线推演", "summary":"完整已知房间图上的方向、门槛、风险加权和返钟参考"}

func initial() -> Dictionary:
    return {"version":1, "sequence":0, "bookmarks":[]}

func valid(candidate: Dictionary) -> bool:
    if candidate.get("version") != 1 or not VALUES.count(candidate.get("sequence")):
        return false
    if not candidate.get("bookmarks") is Array or candidate.bookmarks.size() > 20:
        return false
    var ids := {}
    for record in candidate.bookmarks:
        if not record is Dictionary or not record.get("id") is String or ids.has(record.id):
            return false
        if VALUES.text(record.get("name"), 50).is_empty() or not record.get("source") is String or not record.get("target") is String:
            return false
        if not record.get("preferences") is Dictionary or not record.get("note") is String or record.note.length() > 600:
            return false
        ids[record.id] = true
    return VALUES.json_safe(candidate, 0, [VALUES.MAX_ITEMS])

func _refresh_graph() -> void:
    var snapshot: Dictionary = context.snapshot()
    graph = GRAPH.build(GRAPH.configurations(snapshot), snapshot)
    var current := String(snapshot.get("region", "")) + ":" + String(snapshot.get("room", ""))
    if source.is_empty() and graph.get("nodes", {}).has(current):
        source = current
    if not graph.get("nodes", {}).has(source):
        source = ""
    if not graph.get("nodes", {}).has(target):
        target = ""
    alternatives = []
    if not source.is_empty() and not target.is_empty():
        alternatives = GRAPH.alternatives(graph, source, target, preferences)
    route_index = clampi(route_index, 0, maxi(0, alternatives.size() - 1))

func draw(parent: Control) -> void:
    header(parent, "只在已购且完整补绘的房间上推演。图示成本是参考权重，不是耗时估计，也不是现场碰撞可达证明。")
    _refresh_graph()
    if not graph.get("ok", false):
        UI.hint(parent, String(graph.get("reason", "公开地图尚未就绪。")))
        return
    UI.label(parent, "公开节点%d · 有向连边%d · 已记路线%d" % [graph.nodes.size(), graph.edges.size(), data.bookmarks.size()])
    if graph.nodes.is_empty():
        UI.hint(parent, "先购图并在钟龛完整补绘至少两个房间。未补绘区不会成为规划结果。")
        return
    _selectors(parent)
    _preferences(parent)
    if not status_message.is_empty():
        UI.hint(parent, status_message)
    var route: Dictionary = alternatives[route_index] if not alternatives.is_empty() else {}
    var view := VIEW.new()
    view.configure(graph, route.get("nodes", []))
    view.room_selected.connect(func(id: String):target = id;route_index = 0;context.refresh())
    parent.add_child(view)
    UI.hint(parent, "圆环：已知钟龛 · 空心圆：起点 · 方框：终点；点击公开节点可选终点。")
    _result(parent, route)
    UI.divider(parent)
    _bookmarks(parent)

func _node_choices() -> Array:
    var result := []
    for id in graph.nodes:
        var node: Dictionary = graph.nodes[id]
        if not VALUES.matches(search, [String(node.name), String(node.region_name)]):
            continue
        result.append({"id":id, "name":String(node.region_name) + " / " + String(node.name)})
    result.sort_custom(func(a: Dictionary, b: Dictionary):return String(a.name).naturalnocasecmp_to(String(b.name)) < 0)
    return result

func _selectors(parent: Control) -> void:
    var search_row := UI.row(parent)
    var query := UI.edit(search_row, "搜索已完整补绘的地点", search)
    UI.button(search_row, "筛选地点", func():search = query.text;context.refresh())
    var choices := _node_choices()
    if choices.is_empty():
        UI.hint(parent, "筛选结果为空。清空搜索可重新选择。")
        return
    var row := UI.row(parent)
    UI.label(row, "起点")
    var a := UI.pick(row, choices, source)
    UI.label(row, "终点")
    var b := UI.pick(row, choices, target)
    UI.button(row, "推演", func():source = UI.chosen(a);target = UI.chosen(b);route_index = 0;context.refresh())
    var actions := UI.row(parent)
    UI.button(actions, "交换起终点", func():var temporary := source;source = target;target = temporary;context.refresh())
    UI.button(actions, "以当前房间为起点", func():
        var snapshot: Dictionary = context.snapshot()
        var key := String(snapshot.get("region", "")) + ":" + String(snapshot.get("room", ""))
        if graph.nodes.has(key):
            source = key
            context.refresh()
        else:
            context.tell("当前房间尚未完整补绘，不在推演图中。"))
    UI.button(actions, "查找低成本返钟路线", _return_route, source.is_empty())

func _preferences(parent: Control) -> void:
    var row := UI.row(parent)
    UI.toggle(row, "避开首领房", bool(preferences.avoid_boss), func(value: bool):preferences.avoid_boss = value;context.refresh())
    UI.toggle(row, "避开已知危险房", bool(preferences.avoid_hazards), func(value: bool):preferences.avoid_hazards = value;context.refresh())
    UI.label(row, "风险权重")
    var weight := UI.spin(row, float(preferences.risk_weight), 0, 10, 0.5)
    UI.button(row, "更新权重", func():preferences.risk_weight = float(weight.value);context.refresh())
    UI.hint(parent, "成本 = 每条边基础1 + 中心距离/1000 + 目的房已知风险×权重 + 跨区2。房间图不能表达所有现场动作。")

func _return_route() -> void:
    var outcome := GRAPH.nearest_shrine(graph, source, preferences)
    if not outcome.get("ok", false):
        status_message = String(outcome.get("reason", "没有已知返钟路线。"))
    else:
        target = String(outcome.target)
        route_index = 0
        status_message = "已选择公开图中的低成本钟龛；角色位置没有改变。"
    context.refresh()

func _result(parent: Control, route: Dictionary) -> void:
    if route.is_empty():
        UI.hint(parent, "尚无路线。起终点、单向边、能力门或当前避险条件可能限制了图上连通。")
        return
    var audit := GRAPH.verify(graph, route, preferences)
    UI.hint(parent, String(audit.reason))
    if not audit.ok:
        return
    var navigation := UI.row(parent)
    for index in alternatives.size():
        var selected_index := index
        UI.button(navigation, "路线%d · 权重%.2f" % [index + 1, alternatives[index].cost], func():route_index = selected_index;context.refresh())
    UI.hint(parent, "备选路线通过逐个排除首选路线的边得到，最多三条；不保证列出所有可能路径。")
    for index in route.nodes.size():
        var node: Dictionary = graph.nodes[route.nodes[index]]
        var card := UI.card(parent)
        UI.label(card, "%d. %s / %s" % [index + 1, node.region_name, node.name])
        UI.hint(card, "已知风险权重%d%s%s" % [node.risk, " · 钟龛" if node.shrine else "", " · 首领房" if node.boss else ""])
        if index < route.edges.size():
            var edge: Dictionary = route.edges[index]
            UI.hint(card, "下一段：%s · 权重%.2f" % ["跨区端点" if edge.kind == "portal" else "地区连接", GRAPH.weight(edge, graph.nodes, preferences)])
    var name := UI.edit(parent, "保存路线的名称", "", 50)
    var note := UI.memo(parent, note_draft, 70)
    var actions := UI.row(parent)
    UI.button(actions, "保存路线参考", func():_save_route(name.text, note.text))
    UI.button(actions, "导出当前步骤", func():export_document("已知路线.txt", _document(route)))

func _save_route(title: String, note: String) -> void:
    if VALUES.text(title, 50).is_empty() or data.bookmarks.size() >= 20 or alternatives.is_empty():
        context.tell("请填写名称；最多保存20份路线参考。")
        return
    var candidate := data.duplicate(true)
    candidate.sequence = int(candidate.sequence) + 1
    candidate.bookmarks.append({"id":"route_" + str(int(candidate.sequence)), "name":VALUES.text(title, 50), "source":source, "target":target, "preferences":preferences.duplicate(true), "note":VALUES.text(note, 600)})
    commit(candidate)

func _bookmarks(parent: Control) -> void:
    UI.label(parent, "已记路线参考", true)
    for record in data.bookmarks:
        var known: bool = graph.nodes.has(record.source) and graph.nodes.has(record.target)
        var card := UI.card(parent)
        UI.label(card, String(record.name))
        UI.hint(card, String(record.note))
        if not known:
            UI.hint(card, "起终点当前不在公开图中；保留记录，暂不透露地点或重算路线。")
        var buttons := UI.row(card)
        UI.button(buttons, "按当前规则重算", func():
            source = String(record.source)
            target = String(record.target)
            preferences = record.preferences.duplicate(true)
            context.refresh(), not known)
        UI.button(buttons, "删除参考", func():pending_remove = String(record.id);context.refresh())
        if pending_remove == record.id:
            UI.button(card, "确认删除这份路线参考", func():
                var candidate := data.duplicate(true)
                for index in range(candidate.bookmarks.size() - 1, -1, -1):
                    if candidate.bookmarks[index].id == record.id:
                        candidate.bookmarks.remove_at(index)
                commit(candidate)
                pending_remove = "")
    UI.hint(parent, "每次打开都按当前已知地图与能力重新计算，不执行传送、购图或补绘。")

func _document(route: Dictionary) -> String:
    var lines: Array[String] = ["已知路线参考", "仅为抽象房间连接与规则提示；未证明实际物理可达性。", ""]
    for index in route.nodes.size():
        var node: Dictionary = graph.nodes[route.nodes[index]]
        lines.append("%d. %s / %s" % [index + 1, node.region_name, node.name])
    lines.append("参考权重 %.2f" % float(route.cost))
    return "\n".join(lines)
