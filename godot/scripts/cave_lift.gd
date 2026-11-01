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
var obstructed := false
var last_request_text := ""
var prompt: Label
var landing_prompts: Array[Label]=[]
const PROMPTS=preload("res://scripts/input_prompt_bindings.gd")

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
    prompt=Label.new()
    prompt.add_theme_font_override("font",load("res://assets/fonts/GlobalTypeface.otf"))
    prompt.add_theme_font_size_override("font_size",15)
    prompt.position=Vector2(-48,-100)
    basket.add_child(prompt)
    for y in [top_y,bottom_y]:
        var label:=Label.new();label.add_theme_font_override("font",load("res://assets/fonts/GlobalTypeface.otf"));label.add_theme_font_size_override("font_size",15)
        label.position=Vector2(x+110,y-95);label.custom_minimum_size=Vector2(260,60)
        add_child(label);landing_prompts.append(label)
    _refresh_prompts()
    queue_redraw()

func _draw() -> void:
    draw_line(Vector2(x-50,top_y-110),Vector2(x-50,bottom_y+25),Color(.22,.30,.29),3)
    draw_line(Vector2(x+50,top_y-110),Vector2(x+50,bottom_y+25),Color(.22,.30,.29),3)
    for y in [top_y,bottom_y]:
        draw_circle(Vector2(x+95,y-45),12,Color("a1b288"))
        draw_line(Vector2(x+95,y-62),Vector2(x+95,y-28),Color("dce4c5"),3)

func travel_seconds() -> float:
    return absf(target_y-basket.position.y)/speed if basket!=null and speed>0 else 0.0

func _paused_for_context() -> bool:
    if not is_instance_valid(scene) or not is_instance_valid(scene.player):return true
    var overlay: Variant=scene.get("active_overlay")
    var loading: Variant=scene.get("world_loading")
    var hp: Variant=scene.player.get("hp")
    return (overlay is String and not overlay.is_empty()) or loading==true or (hp!=null and float(hp)<=0)

func _refresh_prompts() -> void:
    if not is_instance_valid(prompt) or not is_instance_valid(scene) or not is_instance_valid(scene.player):return
    var key:=PROMPTS.action_label("interact")
    var direction:="上行" if is_equal_approx(target_y,top_y) else "下行"
    var status:="%s · 约%.1f秒" % [direction,travel_seconds()] if moving else "通道受阻，清空笼顶后重试" if obstructed else "上层" if is_equal_approx(basket.position.y,top_y) else "下层"
    if moving and _paused_for_context():status="暂停 · 关闭界面后继续"
    prompt.text=status if moving else key+" · 升降笼 · "+status
    for index in landing_prompts.size():
        var label:=landing_prompts[index]
        var y:=top_y if index==0 else bottom_y
        label.visible=scene.player.global_position.distance_squared_to(Vector2(x,y))<230.0*230.0
        label.text=("升降笼 · "+status) if moving else key+" · 呼叫升降笼\n"+status

func _physics_process(delta: float) -> void:
    if not is_instance_valid(basket) or not is_instance_valid(scene) or not is_instance_valid(scene.player):return
    _refresh_prompts()
    if not moving or _paused_for_context() or not is_finite(delta) or delta<=0:return
    var player: CharacterBody2D=scene.player
    var previous:=basket.position.y
    var next:=move_toward(previous,target_y,speed*delta)
    var motion:=Vector2(0,next-previous)
    # Test the actual rider body against terrain before carrying it. Ignore only
    # this basket during the sweep; it must remain physical ground afterwards.
    var riding:=absf(player.global_position.x-x)<61 and absf(player.global_position.y-previous)<8 and player.velocity.y>=0
    if riding:
        var already_excepted:=basket in player.get_collision_exceptions()
        if not already_excepted:player.add_collision_exception_with(basket)
        var blocked:=player.test_move(player.global_transform,motion)
        if not already_excepted:player.remove_collision_exception_with(basket)
        if blocked:
            moving=false;obstructed=true;last_request_text="升降笼通道受阻；清空笼顶或离开笼沿后重试。";_refresh_prompts();return
    basket.position.y=next
    if riding:player.global_position+=motion
    if is_equal_approx(next,target_y):moving=false
    _refresh_prompts()

func request(from: Vector2) -> bool:
    if not is_instance_valid(basket) or not from.is_finite() or _paused_for_context():return false
    var on_basket:=absf(from.x-x)<100 and absf(from.y-basket.position.y)<110
    var at_landing:=absf(from.x-x)<160 and (absf(from.y-top_y)<120 or absf(from.y-bottom_y)<120)
    if not on_basket and not at_landing:return false
    if moving:
        last_request_text="升降笼正在%s，约%.1f秒后抵达；不会因重复呼叫突然折返。" % ["上行" if is_equal_approx(target_y,top_y) else "下行",travel_seconds()]
        return true
    if on_basket:
        if is_equal_approx(basket.position.y,bottom_y):target_y=top_y
        elif is_equal_approx(basket.position.y,top_y):target_y=bottom_y
        # A mid-shaft obstruction keeps its requested destination on retry.
    else:target_y=top_y if absf(from.y-top_y)<absf(from.y-bottom_y) else bottom_y
    moving=not is_equal_approx(target_y,basket.position.y);obstructed=false
    last_request_text="升降笼%s，约%.1f秒后抵达。可在途中跳离。" % ["上行" if is_equal_approx(target_y,top_y) else "下行",travel_seconds()] if moving else "升降笼已在这一层，进入笼内可前往另一层。"
    _refresh_prompts()
    return true
