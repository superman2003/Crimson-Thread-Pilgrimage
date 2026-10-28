extends SceneTree
const EFFECT := preload("res://scripts/enemy_attack_effect.gd")
var checks := 0
var failures := 0
class Target extends CharacterBody2D:
    var hits := 0
    var ui_input_locked := false
    func take_damage(_amount: int, _source: Vector2, _blockable: bool) -> bool: hits += 1; return true
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures += 1; push_error(label)
func beam(stage: Node) -> Node2D:
    var node := EFFECT.new(); node.effect_kind = "beam"; node.length = 300; node.radius = 12; node.arm_delay = 0.3; node.duration = 1
    stage.add_child(node); node.set_physics_process(false)
    return node
func wall(stage: Node, point: Vector2, size: Vector2) -> StaticBody2D:
    var body := StaticBody2D.new(); body.position = point
    var collision := CollisionShape2D.new(); var shape := RectangleShape2D.new(); shape.size = size
    collision.shape = shape; body.add_child(collision); stage.add_child(body)
    return body
func run() -> void:
    var stage := Node2D.new(); root.add_child(stage)
    var player := Target.new(); player.position = Vector2(180, 42); stage.add_child(player); player.add_to_group("player")
    var node := beam(stage); node._physics_process(0.1)
    check(player.hits == 0 and node.length == 300, "warning preserves full unobstructed reach")
    var blocker := wall(stage, Vector2(120, 0), Vector2(10, 100))
    await physics_frame; await process_frame
    node._physics_process(0.25)
    check(player.hits == 0 and is_equal_approx(node.length, 115), "new wall clips beam before active damage")
    check(is_equal_approx(node._beam_channel_corners()[2].x, 115), "visible endpoint uses identical clipped reach")
    blocker.free(); await physics_frame; await process_frame
    node._physics_process(0.01)
    check(player.hits == 1 and node.length == 300, "removed obstruction restores authored reach")
    node._physics_process(0.1)
    check(player.hits == 1, "same beam cannot repeat accepted contact")
    node.free(); player.hits = 0
    blocker = wall(stage, Vector2(100, -12), Vector2(10, 4))
    await physics_frame; await process_frame
    node = beam(stage); node._physics_process(0.4)
    check(player.hits == 0 and is_equal_approx(node.length, 95), "edge obstruction clips wide beam even when center ray misses")
    node.free(); blocker.free(); await physics_frame; await process_frame
    node = beam(stage); node.heading = Vector2(3, 0); node._physics_process(0.4)
    check(node.heading == Vector2.RIGHT and player.hits == 1, "nonunit direction normalized for matching damage and art")
    node.free(); player.hits = 0
    node = beam(stage); node.heading = Vector2.ZERO; node._physics_process(0.4)
    check(node.cancelled and node.length == 0 and player.hits == 0, "invalid beam retires without damage")
    node.free()
    node = beam(stage); node.duration = 0.5; node._physics_process(1)
    check(player.hits == 1 and node.cancelled, "final crossed active interval resolves before retirement")
    node.free(); player.hits = 0
    node = beam(stage); player.ui_input_locked = true; node._physics_process(1)
    check(node.age == 0 and not node.cancelled and player.hits == 0, "UI pause freezes beam time")
    player.ui_input_locked = false; node.free(); stage.free()
    print("BEAM_CHANNEL checks=%d failures=%d" % [checks, failures])
    quit(0 if failures == 0 else 1)
