extends SceneTree
const LIFT=preload("res://scripts/cave_lift.gd")
const PROMPTS=preload("res://scripts/input_prompt_bindings.gd")
var checks:=0
var failures:=0
class Host extends Node2D:
    var player: CharacterBody2D
    var active_overlay:=""
    var world_loading:=false
class Rider extends CharacterBody2D:
    var hp:=5
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
    checks+=1;print("CHECK %s %s" % ["PASS" if ok else "FAIL",label])
    if not ok:failures+=1
func run() -> void:
    var existed:=InputMap.has_action("interact")
    if not existed:InputMap.add_action("interact")
    var bindings: Array=InputMap.action_get_events("interact").duplicate()
    InputMap.action_erase_events("interact")
    var key:=InputEventKey.new();key.keycode=KEY_E;InputMap.action_add_event("interact",key)
    PROMPTS.controller_device=-1
    var host:=Host.new();root.add_child(host)
    var rider:=Rider.new();rider.collision_layer=2;rider.collision_mask=1
    var body:=CollisionShape2D.new();var shape:=RectangleShape2D.new();shape.size=Vector2(34,80);body.shape=shape;body.position=Vector2(0,-40);rider.add_child(body)
    host.player=rider;host.add_child(rider);rider.position=Vector2(300,500)
    var lift:=LIFT.new();host.add_child(lift);lift.configure({"id":"lift_service_fixture","x":300,"top_y":100,"bottom_y":500,"speed":200},host);lift.set_physics_process(false)
    await physics_frame;await physics_frame
    check(lift.prompt.text.begins_with("E") and lift.landing_prompts[1].visible,"actual basket and landing prompts read remapped interaction key")
    var joy:=InputEventJoypadButton.new();joy.button_index=JOY_BUTTON_X;joy.device=-1;InputMap.action_add_event("interact",joy);PROMPTS.controller_device=7;lift._refresh_prompts()
    check(lift.prompt.text.contains("手柄 X"),"physical facility prompt follows active controller binding")
    PROMPTS.controller_device=-1
    check(not lift.request(Vector2.ZERO) and not lift.moving,"remote caller cannot activate physical facility")
    check(not lift.request(Vector2(NAN,500)) and not lift.request(Vector2(INF,500)),"non-finite caller coordinates rejected")
    check(lift.request(rider.position) and lift.moving and is_equal_approx(lift.travel_seconds(),2),"rider requests upper landing with actual distance divided by speed")
    var target:=lift.target_y
    check(lift.request(Vector2(300,100)) and lift.target_y==target and lift.last_request_text.contains("不会"),"repeated nearby call reports progress without reversing occupied basket")
    var start:=rider.position
    host.active_overlay="map";lift._physics_process(0.2)
    check(lift.basket.position.y==500 and rider.position==start and lift.prompt.text.contains("暂停"),"map/menu pauses actual basket and rider together")
    host.active_overlay="";host.world_loading=true;lift._physics_process(0.2)
    check(lift.basket.position.y==500,"region loading pauses physical transit")
    host.world_loading=false;rider.hp=0;lift._physics_process(0.2)
    check(lift.basket.position.y==500 and not lift.request(rider.position),"dead rider cannot start or advance service")
    rider.hp=5;lift._physics_process(NAN);lift._physics_process(-1)
    check(lift.basket.position.y==500,"invalid timing cannot corrupt physical coordinates")
    lift._physics_process(0.1)
    check(lift.basket.position.y==480 and rider.position.y==480 and lift.travel_seconds()<2,"actual basket and rider advance together and ETA falls")
    rider.velocity.y=-100;var jump_y:=rider.position.y;lift._physics_process(0.1)
    check(rider.position.y==jump_y and lift.basket.position.y==460,"jumping rider freely leaves moving basket")
    # Reset only this isolated mechanical fixture for a real collision sweep.
    lift.moving=false;lift.basket.position.y=500;rider.position=Vector2(300,500);rider.velocity=Vector2.ZERO
    var ceiling:=StaticBody2D.new();ceiling.position=Vector2(300,340)
    var obstacle:=CollisionShape2D.new();var block:=RectangleShape2D.new();block.size=Vector2(200,20);obstacle.shape=block;ceiling.add_child(obstacle);host.add_child(ceiling)
    await physics_frame;await physics_frame
    lift.request(rider.position)
    for unused in 20:lift._physics_process(0.05)
    check(lift.obstructed and not lift.moving and rider.position.y>=430 and lift.basket.position.y>=430,"actual rider-body sweep prevents carrying through a low ceiling")
    check(not rider.get_collision_exceptions().has(lift.basket) and lift.prompt.text.contains("受阻"),"obstruction restores physical basket collision and explains retry")
    ceiling.free();await physics_frame;await physics_frame
    check(lift.request(rider.position) and lift.target_y==100,"clearing obstruction resumes original requested destination")
    for unused in 50:lift._physics_process(0.05)
    check(not lift.moving and not lift.obstructed and rider.position.y==100 and lift.basket.position.y==100,"unblocked rider reaches exact physical upper landing")
    check(lift.request(Vector2(300,500)) and lift.target_y==500,"lower landing can call basket back while rider remains on board")
    for unused in 50:lift._physics_process(0.05)
    check(rider.position.y==500 and not lift.moving,"physical descent retains rider and exact destination")
    rider.position=Vector2(450,100)
    check(lift.request(rider.position) and lift.target_y==100,"unoccupied basket can be called from authored landing radius")
    var unboarded:=rider.position
    for unused in 50:lift._physics_process(0.05)
    check(rider.position==unboarded and lift.basket.position.y==100,"calling from landing never teleports waiting player")
    host.free();await process_frame
    InputMap.action_erase_events("interact")
    for event in bindings:InputMap.action_add_event("interact",event)
    if not existed:InputMap.erase_action("interact")
    PROMPTS.controller_device=-1
    print("LIFT_SERVICE checks=%d failures=%d" % [checks,failures]);quit(1 if failures else 0)
