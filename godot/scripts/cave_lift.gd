extends Node2D
## Call from either landing with F; travel on a physical moving basket.

var scene: Node2D
var x := 0.0
var top_y := 0.0
var bottom_y := 0.0
var speed := 300.0
var target_y := 0.0
var basket: AnimatableBody2D
var moving := false

func configure(data: Dictionary, owner_scene: Node2D) -> void:
    name = String(data.id)
    scene = owner_scene
    x=float(data.x); top_y=float(data.top_y); bottom_y=float(data.bottom_y)
    speed=float(data.get("speed",300))
    target_y=bottom_y
    basket=AnimatableBody2D.new()
    basket.name="MovingBasket"
    basket.collision_layer=1
    basket.collision_mask=0
    basket.sync_to_physics=false
    basket.position=Vector2(x,bottom_y)
    var collision:=CollisionShape2D.new()
    var shape:=RectangleShape2D.new()
    shape.size=Vector2(132,22)
    collision.position=Vector2(0,11)
    collision.shape=shape
    basket.add_child(collision)
    var floor_panel:=Polygon2D.new()
    floor_panel.polygon=PackedVector2Array([Vector2(-66,0),Vector2(66,0),Vector2(66,22),Vector2(-66,22)])
    floor_panel.color=Color("667968")
    basket.add_child(floor_panel)
    var rim:=Line2D.new()
    rim.points=PackedVector2Array([Vector2(-61,-62),Vector2(-61,0),Vector2(61,0),Vector2(61,-62)])
    rim.width=5;rim.default_color=Color("9ba47e")
    basket.add_child(rim)
    add_child(basket)
    var prompt:=Label.new()
    prompt.text="F · 升降笼"
    prompt.add_theme_font_override("font",load("res://assets/fonts/NotoSansSC.ttf"))
    prompt.add_theme_font_size_override("font_size",15)
    prompt.position=Vector2(-48,-100)
    basket.add_child(prompt)
    queue_redraw()

func _draw() -> void:
    draw_line(Vector2(x-50,top_y-110),Vector2(x-50,bottom_y+25),Color(.22,.30,.29),3)
    draw_line(Vector2(x+50,top_y-110),Vector2(x+50,bottom_y+25),Color(.22,.30,.29),3)
    for y in [top_y,bottom_y]:
        draw_circle(Vector2(x+95,y-45),12,Color("a1b288"))
        draw_line(Vector2(x+95,y-62),Vector2(x+95,y-28),Color("dce4c5"),3)

func _physics_process(delta: float) -> void:
    if basket==null or scene.player==null:return
    var player: CharacterBody2D=scene.player
    if not moving:return
    var previous:=basket.position.y
    var next:=move_toward(previous,target_y,speed*delta)
    # Keep a rider with the basket while grounded; jumping freely leaves it.
    var riding:=absf(player.global_position.x-x)<61 and absf(player.global_position.y-previous)<8 and player.velocity.y>=0
    basket.position.y=next
    if riding:player.global_position.y+=next-previous
    if is_equal_approx(next,target_y):moving=false

func request(from: Vector2) -> bool:
    if moving:return false
    var on_basket:=absf(from.x-x)<100 and absf(from.y-basket.position.y)<110
    var at_landing:=absf(from.x-x)<160 and (absf(from.y-top_y)<120 or absf(from.y-bottom_y)<120)
    if not on_basket and not at_landing:return false
    if on_basket:
        target_y=top_y if absf(basket.position.y-bottom_y)<3 else bottom_y
    else:target_y=top_y if absf(from.y-top_y)<absf(from.y-bottom_y) else bottom_y
    moving=not is_equal_approx(target_y,basket.position.y)
    return true
