extends Area2D
## Small in-world artifacts extend the existing copper/ink linework props.
## Fixed authored population; no particle nodes, colliders or navigation pins.
const INK := Color("322e2b")
const COPPER := Color("a78155")
const PAPER := Color("d8c9aa")
const PALE := Color("8caaa1")
var entry: Dictionary = {}
var seen := false
var elapsed := 0.0

func _ready() -> void:
    z_index=2
    collision_layer=0
    collision_mask=1
    add_to_group("interactable")
    if String(entry.get("role",""))=="witness":visible=false
    set_process(String(entry.get("role",""))=="witness" or String(entry.get("look",""))=="pump_manifold")
    var collision := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size=Vector2(100,80)
    collision.shape=shape
    add_child(collision)

func _process(delta: float) -> void:
    if String(entry.get("role",""))=="witness":
        visible=String(get_parent().get("current_room_id"))==String(entry.get("room_id",""))
    if visible and String(entry.get("look",""))=="pump_manifold":
        elapsed+=delta
        queue_redraw()

func accessible_from(player: CharacterBody2D) -> bool:
    var query := PhysicsRayQueryParameters2D.create(player.global_position,global_position,1,[player.get_rid()])
    return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func mark_seen() -> void:
    seen=true
    queue_redraw()

func stroke(points: Array,color: Color=COPPER,width: float=2.0) -> void:
    draw_polyline(PackedVector2Array(points),color,width,true)

func key_at(at: Vector2,color: Color) -> void:
    draw_arc(at,7,0,TAU,16,color,2,true)
    stroke([at+Vector2(6,0),at+Vector2(25,0),at+Vector2(25,7),at+Vector2(19,7)],color)

func _draw() -> void:
    # The foot reaches the authored floor, 32 pixels below this interaction anchor.
    draw_rect(Rect2(-44,25,88,7),INK)
    stroke([Vector2(-44,25),Vector2(-29,23),Vector2(18,25),Vector2(44,24)],COPPER)
    var look := String(entry.get("look",""))
    match look:
        "bell_mold":
            for side in [-1,1]:
                var offset := float(side)*22
                draw_rect(Rect2(offset-17,-29,34,52),INK)
                stroke([Vector2(offset-15,20),Vector2(offset-12,-15),Vector2(offset,-27),Vector2(offset+12,-15),Vector2(offset+15,20)],COPPER,3)
                draw_line(Vector2(offset-12,6),Vector2(offset+12,6),PAPER,2,true)
            draw_line(Vector2(-5,-10),Vector2(5,-10),PALE,2,true)
        "pump_manifold":
            draw_rect(Rect2(-29,-31,58,54),INK)
            for row in 3:
                var y := float(row)*16-22
                stroke([Vector2(-44,y),Vector2(-14,y),Vector2(-7,y+8),Vector2(44,y+8)],COPPER,4)
            draw_arc(Vector2(0,-11),14,0,TAU,24,PAPER,2,true)
            var arm := Vector2.from_angle(sin(elapsed*.6)*.3)*12
            draw_line(-arm+Vector2(0,-11),arm+Vector2(0,-11),PAPER,2,true)
        "book_press":
            for x in [-34,34]:draw_line(Vector2(x,24),Vector2(x,-30),COPPER,4,true)
            for y in [-22,-8]:draw_rect(Rect2(-39,y,78,8),INK);draw_line(Vector2(-39,y),Vector2(39,y),COPPER,2,true)
            for row in 3:draw_line(Vector2(-26,7+row*4),Vector2(26,5+row*4),PAPER,2,true)
            draw_line(Vector2(-42,25),Vector2(42,25),COPPER,3,true)
        "graft_bench":
            draw_rect(Rect2(-41,5,82,17),INK)
            stroke([Vector2(-42,5),Vector2(-32,-1),Vector2(37,1),Vector2(42,5)],COPPER,3)
            for index in 4:
                var x := -28.0+index*18
                stroke([Vector2(x,10),Vector2(x-3,-8),Vector2(x+4,-27)],PALE,3)
                draw_line(Vector2(x-6,-9),Vector2(x+6,-11),PAPER,2,true)
        "name_spool":
            for x in [-34,34]:draw_line(Vector2(x,25),Vector2(x,-28),COPPER,3,true)
            draw_circle(Vector2.ZERO,25,INK)
            draw_arc(Vector2.ZERO,25,0,TAU,32,COPPER,3,true)
            for index in 6:
                var direction := Vector2.from_angle(index*TAU/6)
                draw_line(direction*11,direction*21,PAPER,4,true)
            draw_line(Vector2(-29,-31),Vector2(28,-29),COPPER,2,true)
        "lock_comb":
            draw_rect(Rect2(-42,-29,84,52),INK)
            for row in 3:
                var y := -20.0+row*16
                key_at(Vector2(-26,y),PAPER)
                stroke([Vector2(3,y),Vector2(30,y),Vector2(35,18)],COPPER)
            draw_circle(Vector2(35,18),5,PALE)
        "pledge_scar":
            draw_rect(Rect2(-33,-32,66,57),INK)
            stroke([Vector2(-17,-16),Vector2(-10,-24),Vector2(0,-16),Vector2(10,-24),Vector2(17,-16),Vector2(0,0),Vector2(-17,-16)],PAPER)
            for x in [-24,0,24]:stroke([Vector2(0,0),Vector2(x,9),Vector2(x,18)],COPPER)
        "reversed_badges":
            stroke([Vector2(-40,-23),Vector2(39,-23)],COPPER,3)
            for index in 3:
                var x := -26.0+index*26
                draw_line(Vector2(x,-23),Vector2(x,-12),PAPER,2,true)
                draw_rect(Rect2(x-10,-11,20,31),INK)
                draw_rect(Rect2(x-10,-11,20,31),COPPER,false,2)
                for row in 3:draw_line(Vector2(x-5,-4+row*7),Vector2(x+3,(-3 if index==1 else -4)+row*7),PAPER,1,true)
        "scraped_page":
            draw_colored_polygon(PackedVector2Array([Vector2(-37,-23),Vector2(31,-29),Vector2(40,18),Vector2(-31,24)]),PAPER)
            for row in 5:draw_line(Vector2(-23,-15+row*7),Vector2(25,-18+row*7),INK,2,true)
            draw_line(Vector2(-10,-14),Vector2(7,0),COPPER,5,true)
            draw_line(Vector2(-10,-14),Vector2(7,0),PAPER,2,true)
        "grafted_collar":
            stroke([Vector2(-35,28),Vector2(-19,10),Vector2(-10,-25),Vector2(0,-33),Vector2(12,-22),Vector2(19,10),Vector2(36,28)],PALE,7)
            for y in [-12,0,12]:draw_line(Vector2(-18,y),Vector2(20,y-3),COPPER,5,true)
            draw_line(Vector2(18,-4),Vector2(42,-22),PAPER,2,true)
        "rewritten_muster":
            draw_rect(Rect2(-35,-29,70,54),INK)
            for row in 5:
                var y := -19.0+row*9
                draw_line(Vector2(-26,y),Vector2(25,y),PAPER,2,true)
                if row%2==0:draw_line(Vector2(-29,y-3),Vector2(27,y+3),COPPER,2,true)
            draw_circle(Vector2(24,17),4,COPPER)
        "swallowed_key":
            draw_arc(Vector2(2,-2),28,.2,TAU-.25,28,COPPER,4,true)
            key_at(Vector2(-23,-1),PAPER)
            for x in [-14,3,20]:draw_line(Vector2(x,-27),Vector2(x+2,-20),PALE,3,true)
    # A small fixed notch distinguishes a recorded observation without flashing.
    if seen:stroke([Vector2(27,17),Vector2(31,21),Vector2(39,12)],PALE,2)
