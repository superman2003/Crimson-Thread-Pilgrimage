extends "res://journey/core/feature.gd"
const MODEL := preload("res://journey/caseboard/model.gd")
const VIEW := preload("res://journey/caseboard/view.gd")
var kind := "all"
var tab := "board"
var graph: Dictionary = {}
var link_from := ""
var link_to := ""
var pending_remove := ""
var pending_clear := false
var page := 0
var chain_result: Dictionary = {}
const PAGE_SIZE := 16
const KIND_NAMES := {"all":"全部", "evidence":"证词", "quest":"委托", "npc":"已见人物", "ending":"已选结局"}

func descriptor() -> Dictionary:
    return {"id":"caseboard", "name":"故事关系板", "summary":"已知人物、证词与委托的关系图和个人阅读假设"}

func initial() -> Dictionary:
    return MODEL.fresh()

func valid(candidate: Dictionary) -> bool:
    return MODEL.valid(candidate)

func tick(snapshot: Dictionary, _delta: float) -> void:
    var candidate := MODEL.observe(data, snapshot)
    if candidate != data and context.store.write("caseboard", candidate):
        data = candidate

func draw(parent: Control) -> void:
    header(parent, "正文关联与个人假设分开显示。连线、手记和排列只保存在辅助记录，不会变成证词或推进任务。")
    graph = MODEL.graph(data, context.snapshot())
    if not graph.nodes.has(selected):
        selected = ""
    var tabs := UI.row(parent)
    for pair in [["board", "关系图"], ["catalog", "阅读目录"], ["links", "个人假设"], ["groups", "关系组"]]:
        var id := String(pair[0])
        UI.button(tabs, String(pair[1]), func():tab = id;context.refresh())
    _filters(parent)
    var filtered := MODEL.filtered(graph, data, search, kind)
    UI.label(parent, "已知%d项 · 当前显示%d项 · 正文关联%d · 个人假设%d" % [graph.nodes.size(), filtered.nodes.size(), _authored_count(), data.links.size()])
    if graph.nodes.is_empty():
        UI.hint(parent, "完成一次交谈、遇见线索或开始委托后，这里才会出现相应内容。")
        return
    if tab == "links":
        _link_editor(parent)
    elif tab == "groups":
        _groups(parent, filtered)
    elif tab == "catalog":
        _catalog(parent, filtered)
    else:
        var view := VIEW.new()
        view.configure(filtered, data.positions, selected)
        view.selected_node.connect(func(id: String):selected = id;context.refresh())
        view.moved_node.connect(func(id: String, point: Vector2):commit(MODEL.move(data, graph, id, point)))
        parent.add_child(view)
        UI.hint(parent, "实线：正文已公开关联 · 虚线：个人假设；最多绘制64个筛选节点，完整条目可在阅读目录中查看。")
        _detail(parent)
    UI.divider(parent)
    var actions := UI.row(parent)
    UI.button(actions, "导出当前筛选关系板", func():export_document("故事关系板.txt", MODEL.document(filtered, data)))
    UI.button(actions, "重置图面排列", func():pending_clear = true;context.refresh())
    if pending_clear:
        UI.hint(parent, "只清空节点摆放位置，保留所有手记与个人假设。")
        var confirm := UI.row(parent)
        UI.button(confirm, "保留排列", func():pending_clear = false;context.refresh())
        UI.button(confirm, "确认重新排布", func():
            var candidate := data.duplicate(true)
            candidate.positions = {}
            commit(candidate)
            pending_clear = false)

func _filters(parent: Control) -> void:
    var row := UI.row(parent)
    var query := UI.edit(row, "搜索已知标题、正文和我的手记", search)
    UI.button(row, "搜索", func():search = query.text;page = 0;context.refresh())
    var choices := []
    for id in KIND_NAMES:
        choices.append({"id":id, "name":KIND_NAMES[id]})
    var picker := UI.pick(row, choices, kind)
    picker.item_selected.connect(func(_index: int):kind = UI.chosen(picker);page = 0;context.refresh())

func _authored_count() -> int:
    var count := 0
    for edge in graph.edges:
        if edge.kind == "authored":
            count += 1
    return count

func _catalog(parent: Control, filtered: Dictionary) -> void:
    var ids: Array = filtered.nodes.keys()
    ids.sort_custom(func(a: String, b: String):return String(filtered.nodes[a].title).naturalnocasecmp_to(String(filtered.nodes[b].title)) < 0)
    page = clampi(page, 0, maxi(0, (ids.size() - 1) / PAGE_SIZE))
    var navigation := UI.row(parent)
    UI.button(navigation, "上一页", func():page -= 1;context.refresh(), page == 0)
    UI.label(navigation, "第%d页" % (page + 1))
    UI.button(navigation, "下一页", func():page += 1;context.refresh(), (page + 1) * PAGE_SIZE >= ids.size())
    for index in range(page * PAGE_SIZE, mini(ids.size(), (page + 1) * PAGE_SIZE)):
        var id := String(ids[index])
        var node: Dictionary = filtered.nodes[id]
        var card := UI.card(parent)
        UI.label(card, "%s · %s" % [node.title, node.status])
        UI.hint(card, String(node.guidance))
        UI.button(card, "阅读与手记", func():selected = id;tab = "board";context.refresh())
    if ids.is_empty():
        UI.hint(parent, "没有符合筛选的已知条目。")

func _detail(parent: Control) -> void:
    if selected.is_empty() or not graph.nodes.has(selected):
        UI.hint(parent, "选中一个节点可阅读正文、写下手记并查看直接关联。")
        return
    var node: Dictionary = graph.nodes[selected]
    var card := UI.card(parent)
    UI.label(card, String(node.title), true)
    UI.hint(card, String(KIND_NAMES.get(node.kind, "记录")) + " · " + String(node.status))
    UI.label(card, String(node.text))
    if not String(node.guidance).is_empty():
        UI.hint(card, String(node.guidance))
    UI.label(card, "我的阅读手记")
    var note := UI.memo(card, String(data.notes.get(selected, "")), 100)
    var id := selected
    UI.button(card, "保存此条手记", func():commit(MODEL.annotate(data, graph, id, note.text)))
    UI.label(card, "直接关联")
    for relationship in MODEL.connected(graph, selected):
        var peer: Dictionary = relationship.node
        var edge: Dictionary = relationship.edge
        var label := "正文关联" if edge.kind == "authored" else String(MODEL.RELATIONS.get(edge.kind, "个人假设"))
        UI.hint(card, label + " · " + String(edge.note))
        UI.button(card, String(peer.title), func():selected = String(peer.id);context.refresh())
    UI.button(card, "以此项开始建立假设", func():link_from = id;tab = "links";context.refresh())

func _node_choices() -> Array:
    var result := []
    for id in graph.nodes:
        result.append({"id":id, "name":String(graph.nodes[id].title)})
    result.sort_custom(func(a: Dictionary, b: Dictionary):return String(a.name).naturalnocasecmp_to(String(b.name)) < 0)
    return result

func _link_editor(parent: Control) -> void:
    UI.label(parent, "建立个人阅读假设", true)
    UI.hint(parent, "只能连接当前公开的节点。个人连线没有剧情判定效力，不会自动证明某个结论。")
    var choices := _node_choices()
    if choices.size() < 2:
        UI.hint(parent, "至少公开两个条目后可建立关系。")
        return
    var row := UI.row(parent)
    var a := UI.pick(row, choices, link_from)
    var b := UI.pick(row, choices, link_to)
    var relations := []
    for id in MODEL.RELATIONS:
        relations.append({"id":id, "name":MODEL.RELATIONS[id]})
    var relation := UI.pick(parent, relations, "questions")
    var note := UI.memo(parent, "", 80)
    UI.button(parent, "保存个人连线", func():
        link_from = UI.chosen(a)
        link_to = UI.chosen(b)
        var candidate := MODEL.connect_nodes(data, graph, link_from, link_to, UI.chosen(relation), note.text)
        if candidate == data:
            context.tell("起终点相同、连线重复或数量已满。")
        else:
            commit(candidate))
    for record in data.links:
        if not graph.nodes.has(record.from) or not graph.nodes.has(record.to):
            continue
        var card := UI.card(parent)
        UI.label(card, "%s ↔ %s" % [graph.nodes[record.from].title, graph.nodes[record.to].title])
        UI.hint(card, String(MODEL.RELATIONS[record.kind]) + " · " + String(record.note))
        UI.button(card, "删除此假设", func():pending_remove = String(record.id);context.refresh())
        if pending_remove == record.id:
            var actions := UI.row(card)
            UI.button(actions, "保留", func():pending_remove = "";context.refresh())
            UI.button(actions, "确认删除", func():commit(MODEL.remove_link(data, String(record.id)));pending_remove = "")

func _groups(parent: Control, filtered: Dictionary) -> void:
    var choices := _node_choices()
    if choices.size() >= 2:
        var selectors := UI.row(parent)
        var source := UI.pick(selectors, choices, link_from)
        var target := UI.pick(selectors, choices, link_to)
        UI.button(selectors, "查找关系链", func():
            link_from = UI.chosen(source)
            link_to = UI.chosen(target)
            chain_result = MODEL.chain(graph, link_from, link_to)
            context.refresh())
    if not chain_result.is_empty():
        UI.hint(parent, String(chain_result.reason))
        if chain_result.get("ok", false):
            UI.label(parent, "其中%d条为个人假设，不能作为正文已经证明的结论。" % chain_result.hypotheses)
            for id in chain_result.nodes:
                if graph.nodes.has(id):
                    UI.label(parent, "→ " + String(graph.nodes[id].title))
    UI.hint(parent, "关系组由当前可见连线的无向连通分量计算。组内相连不代表因果，也不代表剧情已经认可个人假设。")
    var index := 0
    for group in MODEL.components(filtered):
        index += 1
        var card := UI.card(parent)
        UI.label(card, "关系组%d · %d项" % [index, group.size()], true)
        for id in group:
            var node: Dictionary = filtered.nodes[id]
            UI.button(card, String(node.title), func():selected = String(id);tab = "board";context.refresh())
