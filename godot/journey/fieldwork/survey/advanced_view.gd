extends VBoxContainer
const UI := preload("res://journey/core/ui.gd")
const A := preload("res://journey/fieldwork/survey/advanced.gd")
var grid: Dictionary = {}
var count: SpinBox
var radius: SpinBox
var output: VBoxContainer
var canvas: CoverageCanvas

class CoverageCanvas extends Control:
    var grid: Dictionary = {}
    var result: Dictionary = {}
    func _init() -> void:
        custom_minimum_size = Vector2(440, 300)
        size_flags_horizontal = Control.SIZE_EXPAND_FILL
        clip_contents = true
        mouse_filter = Control.MOUSE_FILTER_IGNORE
    func _ready() -> void:
        resized.connect(queue_redraw)
    func _draw() -> void:
        draw_rect(Rect2(Vector2.ZERO, size), Color("#14292c"))
        if int(grid.get("width",0)) <= 0 or int(grid.get("height",0)) <= 0:
            return
        var unit := minf((size.x - 24) / float(grid.width), (size.y - 24) / float(grid.height))
        var origin := (size - Vector2(grid.width,grid.height) * unit) * 0.5
        var covered := {}
        for id in result.get("covered",[]):
            covered[id] = true
        for id in grid.cells.size():
            if grid.cells[id] <= 0:
                continue
            var point := origin + Vector2(id % int(grid.width), id / int(grid.width)) * unit
            draw_rect(Rect2(point,Vector2.ONE * maxf(1,unit-1)), Color("#86b3a1") if covered.has(id) else Color("#57535a"))
        for station in result.get("stations",[]):
            var point := origin + Vector2(station.x + 0.5,station.y + 0.5) * unit
            draw_circle(point,maxf(3,unit*0.28),Color("#ffda8a"))


func configure(data: Dictionary) -> void:
    grid = data.get("grid",{}).duplicate(true)


func _ready() -> void:
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    UI.hint(self,"调整复查站点数和四邻参考半径，显式计算后更新图面。绿色为覆盖格，灰色为剩余格，金点为站点。")
    var row := UI.row(self)
    count = UI.spin(row,4,0,8)
    radius = UI.spin(row,3,0,20)
    UI.button(row,"试算覆盖",_calculate)
    output = UI.column(self)
    canvas = CoverageCanvas.new()
    add_child(canvas)
    canvas.grid = grid
    _calculate()


func _calculate() -> void:
    UI.clear(output)
    var result := A.plan(grid,int(count.value),int(radius.value))
    if not result.ok:
        UI.label(output,result.reason)
        return
    UI.label(output,"覆盖%d / %d格；剩余%d格；证书%s" % [result.covered.size(),result.total,result.uncovered.size(),"通过" if A.certify(grid,result) else "未通过"])
    UI.hint(output,"候选抽样：" + ("是，128个候选" if result.sampled else "否，全量候选"))
    canvas.result = result
    canvas.queue_redraw()
