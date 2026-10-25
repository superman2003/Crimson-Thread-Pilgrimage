extends Control
## Prospective scalar InputMap response; this control never injects input.
var axes: Array = []
var threshold := 0.2
const NAMES := ["左 X", "左 Y", "右 X", "右 Y"]

static func response(value: float, deadzone: float) -> float:
    if not is_finite(value):return 0.0
    var boundary:=clampf(deadzone,0.1,0.6) if is_finite(deadzone) else 0.2
    return signf(value)*clampf((absf(value)-boundary)/(1.0-boundary),0.0,1.0)

func update_sample(values: Array, deadzone: float) -> void:
    axes=values.duplicate()
    threshold=clampf(deadzone,0.1,0.6) if is_finite(deadzone) else 0.2
    queue_redraw()

func _draw() -> void:
    var font:=get_theme_default_font()
    var start:=65.0
    var width:=maxf(80.0,size.x-285.0)
    for index in 4:
        var y:=20.0+index*27.0
        draw_string(font,Vector2(0,y+4),NAMES[index],HORIZONTAL_ALIGNMENT_LEFT,-1,14)
        var center:=start+width*0.5
        draw_rect(Rect2(center-width*threshold*0.5,y-6,width*threshold,12),Color(0.3,0.33,0.37,0.8))
        draw_line(Vector2(start,y),Vector2(start+width,y),Color(0.55,0.55,0.55),1.0)
        draw_line(Vector2(center,y-7),Vector2(center,y+7),Color(0.7,0.7,0.7),1.0)
        if axes.size()!=4:continue
        var raw:=float(axes[index]) if typeof(axes[index]) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(axes[index])) else 0.0
        raw=clampf(raw,-1.0,1.0)
        var output:=response(raw,threshold)
        draw_circle(Vector2(start+(raw+1.0)*width*0.5,y-4),3.0,Color(0.94,0.91,0.85))
        draw_circle(Vector2(start+(output+1.0)*width*0.5,y+4),3.0,Color(0.86,0.69,0.36))
        draw_string(font,Vector2(start+width+12,y+4),"原始 %+.2f → 预估 %+.2f" % [raw,output],HORIZONTAL_ALIGNMENT_LEFT,-1,14)
