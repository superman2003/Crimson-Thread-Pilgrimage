extends Node2D
## W04: a crack of warm light leaking from a hidden room into its entrance
## room, so the secret is something the player sees in the world rather than a
## line on the map. It dims once the hidden room has been found.
const LIGHT := Color("f3d9a0")
var clue_id := ""
var found := false:
    set(value):
        found=value
        if is_inside_tree():
            set_process(not found and is_visible_in_tree())
            queue_redraw()
var elapsed := 0.0
var crack: PackedVector2Array

func _ready() -> void:
    z_index = 3
    set_process(not found and is_visible_in_tree())
    var rng := RandomNumberGenerator.new()
    rng.seed = hash(clue_id)
    crack = PackedVector2Array()
    for index in 6:
        crack.append(Vector2(rng.randf_range(-7.0, 7.0), -30.0 + index * 12.0))

func _process(delta: float) -> void:
    if not is_finite(delta) or delta<0:return
    elapsed = fposmod(elapsed+delta,3600.0)
    queue_redraw()

func _draw() -> void:
    var style:=material_style()
    var light: Color=style.tint
    _draw_material(String(style.kind),light)
    var strength := 0.35 if found else 0.75 + 0.25 * sin(elapsed * 2.2)
    for ring in 4:
        draw_circle(Vector2.ZERO, 46.0 - ring * 10.0, Color(light, 0.05 * strength * (ring + 1)))
    draw_polyline(crack, Color(light, strength), 3.0, true)
    # Motes drift up through the gap: the room beyond has air moving in it.
    for mote in (0 if found else 4):
        var t := fmod(elapsed * 0.35 + mote * 0.25, 1.0)
        var x := sin(elapsed * 1.3 + mote * 1.7) * 9.0
        draw_circle(Vector2(x, 26.0 - t * 70.0), 2.0, Color(light, strength * (1.0 - t)))


func _notification(what: int) -> void:
    if what==NOTIFICATION_VISIBILITY_CHANGED and is_inside_tree():
        set_process(not found and is_visible_in_tree())

func material_style() -> Dictionary:
    var data: Variant=get_meta("hidden_route",{})
    var region:=String(data.get("region_id","")) if data is Dictionary else ""
    var styles:={
        "ch01":{"kind":"moss","tint":Color("c1d5a2")},
        "ch02":{"kind":"steam","tint":Color("e7b58c")},
        "ch03":{"kind":"paper","tint":Color("e5d5af")},
        "ch04":{"kind":"root","tint":Color("b7d5a3")},
        "ch05":{"kind":"ash","tint":Color("b7b8d3")},
        "ch06":{"kind":"thread","tint":Color("d9bfda")}}
    for key in styles:
        if region.contains(key):return styles[key]
    return {"kind":"thread","tint":LIGHT}

func _draw_material(kind: String,tint: Color) -> void:
    var ink:=Color(tint,0.38 if found else 0.78)
    for side in [-1,1]:
        var x:=float(side)*22
        match kind:
            "moss":
                draw_polyline(PackedVector2Array([Vector2(x,29),Vector2(x-4,-3),Vector2(x+2,-31)]),ink,2,true)
                for y in [-20,-4,12]:draw_line(Vector2(x,y),Vector2(x+side*8,y-7),ink,3,true)
            "steam":
                draw_polyline(PackedVector2Array([Vector2(x,31),Vector2(x,-20),Vector2(x-side*10,-30)]),ink,4,true)
                for y in [-12,5,22]:draw_line(Vector2(x-5,y),Vector2(x+5,y),ink,2,true)
            "paper":
                for y in [-25,0,25]:
                    if side<0:draw_colored_polygon(PackedVector2Array([Vector2(x-8,y-6),Vector2(x+7,y-10),Vector2(x+3,y+9)]),ink)
                    else:draw_line(Vector2(x-6,y-3),Vector2(x+6,y+2),ink,2,true)
            "root":
                draw_polyline(PackedVector2Array([Vector2(x+side*5,31),Vector2(x-3,13),Vector2(x+4,-6),Vector2(x,-32)]),ink,3,true)
                draw_arc(Vector2(x,3),9,0,PI,12,ink,2,true)
            "ash":
                draw_polyline(PackedVector2Array([Vector2(x,32),Vector2(x-8,10),Vector2(x+6,-9),Vector2(x,-32),Vector2(x+9,-5),Vector2(x,32)]),ink,2,true)
                draw_line(Vector2(x,-21),Vector2(x+3,19),ink,1,true)
            _:
                for y in [-24,-8,8,24]:
                    draw_polyline(PackedVector2Array([Vector2(x+side*7,y-5),Vector2(x,y),Vector2(x+side*7,y+5)]),ink,2,true)
    if found:draw_polyline(PackedVector2Array([Vector2(16,34),Vector2(21,39),Vector2(31,29)]),ink,2,true)
