extends VBoxContainer
const UI := preload("res://journey/core/ui.gd")
const A := preload("res://journey/fieldwork/network/advanced.gd")
var graph: Dictionary = {}
var nodes: Array = []
var source: OptionButton
var target: OptionButton
var output: VBoxContainer


func configure(data: Dictionary) -> void:
    graph = data.get("graph", {}).duplicate(true)
    nodes = data.get("nodes", []).duplicate(true)


func _ready() -> void:
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    UI.hint(self, "任选两个已知端点，检查当前阅读规则下的有向最小割；操作只改变本预览。")
    var choices := []
    for node in nodes:
        choices.append({"id":node.id, "name":node.name})
    var row := UI.row(self)
    source = UI.pick(row, choices)
    target = UI.pick(row, choices)
    if target.item_count > 1:
        target.select(1)
    UI.button(self, "计算并复核所选端点", _calculate)
    output = UI.column(self)
    _calculate()


func _calculate() -> void:
    UI.clear(output)
    var from := UI.chosen(source)
    var to := UI.chosen(target)
    var result := A.solve(graph, from, to)
    if not result.ok:
        UI.label(output, String(result.reason))
        return
    UI.label(output, "%s → %s：%d条独立有向门路" % [_name(from), _name(to), result.count], true)
    UI.hint(output, String(result.reason))
    if result.cut.is_empty():
        UI.label(output, "当前规则图中不可达；空割不代表存在一条备用门路。")
        return
    var blocked := {}
    for edge in result.cut:
        blocked[JSON.stringify([edge.from, edge.to])] = true
        UI.label(output, "割边：" + _name(edge.from) + " → " + _name(edge.to))
    var before := A.reachable(graph, from)
    var after := A.reachable(graph, from, blocked)
    var lost := before.filter(func(id: String): return not after.has(id))
    UI.label(output, "移除整组割边后失去的可达房间：%d" % lost.size())
    for id in lost.slice(0, 20):
        UI.hint(output, _name(id))
    if lost.size() > 20:
        UI.hint(output, "其余%d个房间未在此短列表展示；统计仍包含它们。" % (lost.size() - 20))
    var backward := A.solve(graph, to, from)
    UI.label(output, "返程独立门路：%d" % int(backward.get("count", 0)))


func _name(id: String) -> String:
    for node in nodes:
        if node.id == id:
            return String(node.name)
    return id
