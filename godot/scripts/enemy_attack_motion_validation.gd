extends SceneTree
var checks := 0
var failures := 0
class Target extends CharacterBody2D:
    var hits := 0
    var ui_input_locked := false
    func take_damage(_amount: int, _point: Vector2, _blockable: bool) -> void: hits += 1
class Enemy extends "res://scripts/enemy_actor.gd":
    func _ready() -> void: set_physics_process(false)
    func _pose_sprite(_pose: String, _command: Dictionary = {}) -> void: pass
    func _advance_pose_loop() -> void: pass
    func _clear_telegraph() -> void: pass
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures += 1; push_error(label)
func enemy(stage: Node, kind: String) -> Enemy:
    var node := Enemy.new(); stage.add_child(node)
    node.state = "active"; node.state_timer = 1.0; node.hurtbox_size = Vector2(20, 40); node.hurtbox_offset = Vector2(0, -20)
    node.active_attack = {"type": kind, "active": 1.0, "damage": 1, "lunge_speed": 1000, "hit_width": 40, "hit_height": 60, "offset": 0}
    node.attack_target = Vector2(300, 0)
    return node
func run() -> void:
    var stage := Node2D.new(); root.add_child(stage)
    var target := Target.new(); stage.add_child(target); target.position = Vector2(150, 0); target.add_to_group("player")
    for kind in ["lunge", "dive", "combo"]:
        var node := enemy(stage, kind); target.hits = 0; node._update_active(0.7)
        check(target.hits == 1, kind + " sweeps target between endpoints")
        node._update_active(0.1)
        check(target.hits == 1, kind + " retains single accepted contact")
        node.free()
    var node := enemy(stage, "lunge"); node.state_timer = 0.1; node._update_active(1)
    check(is_equal_approx(node.position.x, 100), "movement cannot borrow recovery duration")
    node.free()
    var wall := StaticBody2D.new(); wall.position = Vector2(100, -60)
    var collider := CollisionShape2D.new(); var shape := RectangleShape2D.new(); shape.size = Vector2(10, 240)
    collider.shape = shape; wall.add_child(collider); stage.add_child(wall)
    await physics_frame; await process_frame
    for kind in ["lunge", "dive", "combo"]:
        node = enemy(stage, kind); target.hits = 0; node._update_active(0.7)
        check(node.position.x < 86 and node.position.x > 80, kind + " body stops before actual wall")
        check(target.hits == 0, kind + " wall shields target behind it")
        node.free()
    target.position.x = 45; node = enemy(stage, "lunge"); node._update_active(0.7)
    check(target.hits == 1, "target before obstruction remains hittable")
    node.free()
    node = enemy(stage, "lunge"); node._update_active(NAN); node._update_active(-1)
    check(node.position == Vector2.ZERO and node.state_timer == 1, "invalid motion leaves attack state intact")
    node.free(); stage.free()
    print("ENEMY_ATTACK_MOTION checks=%d failures=%d" % [checks, failures])
    quit(0 if failures == 0 else 1)
