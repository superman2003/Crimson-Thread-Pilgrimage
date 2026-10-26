extends VBoxContainer
const UI := preload("res://journey/core/ui.gd")
const A := preload("res://journey/fieldwork/landmarks/advanced.gd")
const V := preload("res://journey/fieldwork/scalars.gd")
var payload: Dictionary = {}
var rows: Array = []
var omit: OptionButton
var output: VBoxContainer
var canvas: BearingCanvas

class BearingCanvas extends Control:
    var rows: Array = []
    var result: Dictionary = {}
    func _init() -> void:
        custom_minimum_size = Vector2(440,300)
        size_flags_horizontal = Control.SIZE_EXPAND_FILL
        clip_contents = true
        mouse_filter = Control.MOUSE_FILTER_IGNORE
    func _ready() -> void:
        resized.connect(queue_redraw)
    func _draw() -> void:
        draw_rect(Rect2(Vector2.ZERO,size),Color("#14292c"))
        if not result.get("ok",false):
            return
        var at := Vector2(result.point[0],result.point[1])
        var radius := maxf(1,float(result.major)*3)
        for row in rows:
            radius = maxf(radius,at.distance_to(Vector2(row.point[0],row.point[1])))
        var scale_factor := minf(size.x-40,size.y-40)*0.5/radius
        var center := size*0.5
        for row in rows:
            var point := center+(Vector2(row.point[0],row.point[1])-at)*scale_factor
            draw_line(center,point,Color("#6e8f91"),1,true)
            draw_circle(point,4,Color("#dfc088"))
        var ellipse := PackedVector2Array()
        for i in 65:
            var angle := TAU*i/64.0
            var delta := Vector2(cos(angle)*float(result.major),sin(angle)*float(result.minor))
            delta = delta.rotated(deg_to_rad(float(result.orientation)))
            ellipse.append(center+delta*scale_factor)
        draw_polyline(ellipse,Color("#91d1b3"),2,true)
        draw_circle(center,4,Color("#e6ece3"))


func configure(data: Dictionary) -> void:
    payload = data.get("payload",{}).duplicate(true)
    rows = A.observations(payload)


func _ready() -> void:
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    UI.hint(self,"金点为半径内已知地标，白点为反算位置，绿椭圆为误差尺度。可临时排除一项，检查几何退化。")
    var choices := [{"id":"","name":"保留全部地标"}]
    for row in rows:
        choices.append({"id":row.id,"name":"排除：" + String(row.id)})
    omit = UI.pick(self,choices)
    UI.button(self,"更新定位图",_calculate)
    output = UI.column(self)
    canvas = BearingCanvas.new()
    add_child(canvas)
    _calculate()


func _calculate() -> void:
    UI.clear(output)
    var excluded := UI.chosen(omit)
    var selected := rows.filter(func(row: Dictionary): return row.id!=excluded)
    var result := A.solve(selected)
    canvas.rows = selected
    canvas.result = result
    canvas.queue_redraw()
    if not result.ok:
        UI.label(output,result.reason)
        return
    UI.label(output,"%d个地标 · 条件数%.2f · 误差长/短轴%.3f/%.3f" % [selected.size(),result.condition,result.major,result.minor])
    UI.hint(output,"与原记录点的几何反算距离差：%.4f；图面按世界尺度统一缩放，不放大椭圆。" % V.point(result.point).distance_to(V.point(payload.origin)))
