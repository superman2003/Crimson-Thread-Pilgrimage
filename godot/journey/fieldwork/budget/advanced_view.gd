extends VBoxContainer
const UI := preload("res://journey/core/ui.gd")
const A := preload("res://journey/fieldwork/budget/advanced.gd")
var payload: Dictionary = {}

class CashCanvas extends Control:
    var current: Array = []
    var optimized: Array = []
    var initial := 0.0
    var reserve := 0.0
    func _init() -> void:
        custom_minimum_size = Vector2(440,260)
        size_flags_horizontal = Control.SIZE_EXPAND_FILL
        mouse_filter = Control.MOUSE_FILTER_IGNORE
    func _ready() -> void:
        resized.connect(queue_redraw)
    func _draw() -> void:
        draw_rect(Rect2(Vector2.ZERO,size),Color("#14292c"))
        var low := minf(0,initial)
        var high := maxf(reserve,initial)
        for rows in [current,optimized]:
            for row in rows:
                low = minf(low,initial+float(row["累计净流"]))
                high = maxf(high,initial+float(row["累计净流"]))
        high = maxf(low+1,high)
        var area := Rect2(Vector2(30,25),Vector2(maxf(1,size.x-60),maxf(1,size.y-50)))
        var reserve_y := area.end.y-(reserve-low)/(high-low)*area.size.y
        draw_line(Vector2(area.position.x,reserve_y),Vector2(area.end.x,reserve_y),Color("#e0b87a"),1)
        var colors := [Color("#de8678"),Color("#8ad1b2")]
        for series in 2:
            var rows: Array = current if series==0 else optimized
            var points := PackedVector2Array()
            points.append(Vector2(area.position.x,area.end.y-(initial-low)/(high-low)*area.size.y))
            for i in rows.size():
                var amount := initial+float(rows[i]["累计净流"])
                points.append(Vector2(area.position.x+(i+1)*area.size.x/8,area.end.y-(amount-low)/(high-low)*area.size.y))
            if points.size()>1:
                draw_polyline(points,colors[series],2,true)
            for point in points:
                draw_circle(point,3,colors[series])


func configure(data: Dictionary) -> void:
    payload = data.get("payload",{}).duplicate(true)


func _ready() -> void:
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var optimized := A.solve(payload)
    if not optimized.ok:
        UI.label(self,optimized.reason)
        return
    var current := A.replay(payload,payload.plan)
    UI.hint(self,"红线为原顺序，绿线为优化顺序，金线为储备；两条线都按记录中的实际起始资金绘制。")
    var canvas := CashCanvas.new()
    canvas.current = current.rows
    canvas.optimized = optimized.rows
    canvas.initial = float(payload.initial)
    canvas.reserve = float(payload.reserve)
    add_child(canvas)
    UI.label(self,"期末净流相同：%.1f / %.1f；原/优最低启动资金：%.1f / %.1f" % [current.final_net,optimized.final_net,current.required,optimized.required])
    for i in 8:
        UI.hint(self,"阶段%d：原 %s → 优 %s" % [i+1,current.rows[i]["目标"],optimized.rows[i]["目标"]])
