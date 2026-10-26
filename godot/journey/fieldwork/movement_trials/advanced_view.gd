extends VBoxContainer
const UI := preload("res://journey/core/ui.gd")
const A := preload("res://journey/fieldwork/movement_trials/advanced.gd")
const V := preload("res://journey/fieldwork/scalars.gd")
var data: Dictionary = {}
var result: Dictionary = {}
var choice: OptionButton
var output: VBoxContainer
var canvas: AlignmentCanvas

class AlignmentCanvas extends Control:
    var left: Array = []
    var right: Array = []
    var origin_a := Vector2.ZERO
    var origin_b := Vector2.ZERO
    func _init() -> void:
        custom_minimum_size = Vector2(440,300)
        size_flags_horizontal = Control.SIZE_EXPAND_FILL
        mouse_filter = Control.MOUSE_FILTER_IGNORE
        clip_contents = true
    func _ready() -> void:
        resized.connect(queue_redraw)
    func _draw() -> void:
        draw_rect(Rect2(Vector2.ZERO,size),Color("#14292c"))
        var bounds := Rect2(Vector2.ZERO,Vector2.ONE)
        var sets := [PackedVector2Array(),PackedVector2Array()]
        for series in 2:
            var rows: Array = left if series==0 else right
            var origin := origin_a if series==0 else origin_b
            for row in rows:
                var point := Vector2(float(row.position[0]),float(row.position[1]))-origin
                sets[series].append(point)
                bounds = bounds.expand(point)
        var scale_factor := minf((size.x-40)/maxf(1,bounds.size.x),(size.y-40)/maxf(1,bounds.size.y))
        var colors := [Color("#e3b675"),Color("#89c9bb")]
        for series in 2:
            var points := PackedVector2Array()
            for point in sets[series]:
                points.append(size*0.5+(point-bounds.get_center())*scale_factor)
            if points.size()>1:
                draw_polyline(points,colors[series],2,true)
            if not points.is_empty():
                draw_circle(points[0],5,colors[series])
                draw_rect(Rect2(points[-1]-Vector2(4,4),Vector2(8,8)),colors[series])


func configure(value: Dictionary) -> void:
    data = value.duplicate(true)


func _ready() -> void:
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    result = A.compare(data.a,data.b)
    if not result.ok:
        UI.label(self,result.reason)
        return
    UI.hint(self,"金色为已存记录，绿色为当前对照；两侧减去各自起点后共用同一比例尺。圆点为开始，方点为结束。")
    var options := []
    for i in result.segments.size():
        options.append({"id":str(i),"name":"第%d段"% (i+1)})
    choice = UI.pick(self,options)
    UI.button(self,"显示所选分段",_show_segment)
    output = UI.column(self)
    canvas = AlignmentCanvas.new()
    add_child(canvas)
    _show_segment()


func _show_segment() -> void:
    UI.clear(output)
    var index := int(UI.chosen(choice))
    if index<0 or index>=result.segments.size():
        return
    var segment: Dictionary = result.segments[index]
    UI.label(output,"匹配%d对；均方根位移差%.2f；平均时间差%.3f秒" % [segment.pairs.size(),segment.rms,segment.mean_lag])
    UI.hint(output,"观测着地状态不同%d对；抽样%s" % [segment.ground_mismatch,"是" if segment.reduced else "否"])
    canvas.left = segment.left
    canvas.right = segment.right
    canvas.origin_a = V.point(data.a.origin)
    canvas.origin_b = V.point(data.b.origin)
    canvas.queue_redraw()
