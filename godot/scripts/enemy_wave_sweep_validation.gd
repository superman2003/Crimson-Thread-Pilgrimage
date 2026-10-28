extends SceneTree
const EFFECT := preload("res://scripts/enemy_attack_effect.gd")
var checks := 0
var failures := 0
class Target extends CharacterBody2D:
    var hits := 0
    var ui_input_locked := false
    func take_damage(_amount: int, _point: Vector2, _blockable: bool) -> void: hits += 1
class Stage extends Node2D:
    var chapter_terrain: Node = null
    var probes := 0
    func _ensure_collision_segment(_start: Vector2, _finish: Vector2) -> void: probes += 1
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures += 1; push_error(label)
func wave(stage: Node) -> Node2D:
    var node := EFFECT.new(); node.effect_kind = "wave"; node.radius = 10; node.duration = 2
    node.velocity = Vector2(1000, 0); stage.add_child(node); node.set_physics_process(false)
    return node
func run() -> void:
    var stage := Stage.new(); root.add_child(stage)
    var player := Target.new(); player.position = Vector2(150, 42); stage.add_child(player); player.add_to_group("player")
    for seconds in [0.2, 0.4, 1.0]:
        var node := wave(stage); player.hits = 0; node._physics_process(seconds)
        check(player.hits == 1, "fast wave crosses player between endpoints")
        node._physics_process(0.1)
        check(player.hits == 1, "one wave cannot repeat damage")
        node.free()
    var node := wave(stage); node.arm_delay = 0.3
    player.hits = 0; node._physics_process(0.2)
    check(node.position == Vector2.ZERO and player.hits == 0, "warning never moves or damages")
    node._physics_process(0.2)
    check(is_equal_approx(node.position.x, 100), "only active part of crossing step moves")
    check(player.hits == 0, "warning remainder cannot be reused as damaging motion")
    node.free()
    node = wave(stage); node.duration = 0.2; player.hits = 0
    node._physics_process(1.0)
    check(player.hits == 1 and is_equal_approx(node.position.x, 200), "final active interval resolves before expiration")
    check(node.cancelled, "wave retires at original lifetime")
    node.free()
    var wall := StaticBody2D.new(); wall.position.x = 100
    var collision := CollisionShape2D.new(); var shape := RectangleShape2D.new(); shape.size = Vector2(10, 300)
    collision.shape = shape; wall.add_child(collision); stage.add_child(wall)
    await physics_frame; await process_frame
    node = wave(stage); player.hits = 0; node._physics_process(0.5)
    check(node.cancelled and player.hits == 0 and is_equal_approx(node.position.x, 95), "actual wall wins before player")
    node.free(); player.position.x = 50
    node = wave(stage); node._physics_process(0.5)
    check(player.hits == 1 and node.cancelled, "player before wall is struck once")
    node.free(); player.hits = 0; player.ui_input_locked = true
    node = wave(stage); node._physics_process(0.5)
    check(node.age == 0 and node.position == Vector2.ZERO and player.hits == 0, "overlay pauses whole wave")
    node.free(); player.ui_input_locked = false
    node = wave(stage); node._physics_process(NAN); node._physics_process(-1)
    check(node.age == 0 and node.position == Vector2.ZERO, "invalid steps do not poison wave")
    check(stage.probes > 10, "production streaming warmup called on swept segments")
    node.free(); stage.free()
    print("ENEMY_WAVE_SWEEP checks=%d failures=%d" % [checks, failures])
    quit(0 if failures == 0 else 1)
