extends Control
## The coarse room frame stays fixed; charted ink follows collision geometry.
var detailed := false
var seed_value := 0
var stroke_scale := 1.0
var contours: Array[PackedVector2Array]=[]
func _draw() -> void:
    if detailed:
        for contour in contours:
            var points:=PackedVector2Array()
            for point in contour: points.append(point*size)
            if points.size()<3: continue
            draw_colored_polygon(points,Color(0.38,0.27,0.17,0.14))
            points.append(points[0])
            draw_polyline(points,Color("60452b"),1.3 * stroke_scale,true)
        return
    var ink := Color("60452b") if detailed else Color(0.38,0.27,0.17,0.32)
    var inset := Vector2(minf(3,size.x*0.2),minf(3,size.y*0.2))
    var corners := [inset,Vector2(size.x-inset.x,inset.y),size-inset,Vector2(inset.x,size.y-inset.y),inset]
    var strokes := PackedVector2Array()
    for side in 4:
        for step in 7:
            var point: Vector2 = corners[side].lerp(corners[side+1],float(step)/7)
            var wobble := sin(float(seed_value%997)+side*17+step*2.3)*0.8 * stroke_scale
            point += Vector2(wobble,wobble*0.6)
            strokes.append(point)
    strokes.append(corners[0])
    draw_polyline(strokes,ink,(1.8 if detailed else 1.0) * stroke_scale,true)
