extends Control
## Stable hand-inked contours; geometry comes from the actual room map rectangle.
var detailed := false
var seed_value := 0
func _draw() -> void:
    var ink := Color("60452b") if detailed else Color(0.38,0.27,0.17,0.32)
    var corners := [Vector2(3,3),Vector2(size.x-3,3),Vector2(size.x-3,size.y-3),Vector2(3,size.y-3),Vector2(3,3)]
    var strokes := PackedVector2Array()
    for side in 4:
        for step in 7:
            var point: Vector2 = corners[side].lerp(corners[side+1],float(step)/7)
            var wobble := sin(float(seed_value%997)+side*17+step*2.3)*0.8
            point += Vector2(wobble,wobble*0.6)
            strokes.append(point)
    strokes.append(corners[0])
    draw_polyline(strokes,ink,1.8 if detailed else 1.0,true)
    if detailed and size.x>16 and size.y>16:
        for i in 4:
            var x:=size.x*(0.18+float(i)*0.18)
            draw_line(Vector2(x,size.y-6),Vector2(x+4,size.y-11),Color(0.38,0.27,0.17,0.30),1,true)
