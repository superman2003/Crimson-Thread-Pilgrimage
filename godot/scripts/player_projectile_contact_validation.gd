extends SceneTree
const EFFECT := preload("res://scripts/player_tool_effect.gd")
const SWEEP := preload("res://scripts/attack_sweep.gd")
var checks := 0
var failures := 0
var stage: Node2D
var shooter: CharacterBody2D
class Target extends Node2D:
    var hits := 0
    var active := true
    var dying := false
    var hp := 100
    func get_hurtbox_rect() -> Rect2: return Rect2(global_position - Vector2(10, 10), Vector2(20, 20))
    func world_residency_active() -> bool: return active
    func take_hit(amount: int, _direction: int) -> void: hits += 1; hp -= amount
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures += 1; push_error(label)
func target(id: String, x: float) -> Target:
    var actor := Target.new(); actor.name = id; actor.position.x = x
    stage.add_child(actor); actor.add_to_group("enemy")
    return actor
func shot(kind: String = "projectile", reach: float = 420.0) -> Node2D:
    var effect := EFFECT.new()
    effect.payload = {"kind": kind, "damage": 2, "duration": 2.0, "range": reach}
    effect.owner_player = shooter
    stage.add_child(effect); effect.set_physics_process(false)
    return effect
func clear() -> void:
    for child in stage.get_children():
        if child != shooter: child.free()
func run() -> void:
    var box := Rect2(90, -10, 20, 20)
    for distance in [120.0, 300.0, 1000.0]:
        check(is_equal_approx(SWEEP.rect_time(Vector2.ZERO, Vector2(distance, 0), box), 90.0 / distance), "exact rectangle entry")
        check(is_equal_approx(SWEEP.rect_time(Vector2(distance, 0), Vector2.ZERO, box), (distance - 110) / distance), "reverse entry")
        check(is_inf(SWEEP.rect_time(Vector2(0, 20), Vector2(distance, 20), box)), "parallel miss")
    check(SWEEP.rect_time(Vector2(100, 0), Vector2(100, 0), box) == 0, "stationary overlap")
    check(is_inf(SWEEP.rect_time(Vector2.ZERO, Vector2.ZERO, box)), "stationary miss")
    check(is_inf(SWEEP.rect_time(Vector2.INF, Vector2.ZERO, box)), "invalid input")
    stage = Node2D.new(); root.add_child(stage)
    shooter = CharacterBody2D.new(); stage.add_child(shooter)
    var far := target("far", 150)
    var near := target("near", 70)
    var effect := shot(); effect._physics_process(0.4)
    check(near.hits == 1 and far.hits == 0, "nearest target wins reverse group order")
    check(is_equal_approx(effect.position.x, 52), "projectile stops at first box entry")
    effect._physics_process(0.4)
    check(near.hits == 1, "retired effect cannot repeat")
    clear()
    near = target("near", 70); far = target("far", 150)
    effect = shot("wave"); effect._physics_process(0.4)
    check(near.hits == 1 and far.hits == 1, "piercing wave crosses both targets once")
    effect._physics_process(0.1)
    check(near.hits == 1 and far.hits == 1, "piercing ledger remains once per target")
    clear()
    near = target("near", 70); far = target("far", 180)
    var wall := StaticBody2D.new(); wall.position.x = 120
    var collider := CollisionShape2D.new(); var shape := RectangleShape2D.new(); shape.size = Vector2(10, 300)
    collider.shape = shape; wall.add_child(collider); stage.add_child(wall)
    await physics_frame; await process_frame
    effect = shot(); effect._physics_process(0.4)
    check(near.hits == 1 and far.hits == 0, "enemy before wall receives single shot")
    effect = shot("wave"); effect._physics_process(0.4)
    check(near.hits == 2 and far.hits == 0 and is_equal_approx(effect.position.x, 115), "piercing wave stops at real terrain")
    clear(); await physics_frame; await process_frame
    far = target("beyond_range", 150)
    effect = shot("projectile", 100); effect._physics_process(1)
    check(far.hits == 0 and is_equal_approx(effect.position.x, 100), "long step cannot hit beyond authored range")
    check(effect.is_queued_for_deletion(), "range exhaustion retires on boundary")
    clear()
    near = target("inactive", 70); near.active = false
    far = target("active", 150)
    effect = shot(); effect._physics_process(0.4)
    check(near.hits == 0 and far.hits == 1, "inactive resident cannot consume a shot")
    clear()
    near = target("dying", 70); near.dying = true
    far = target("active", 150)
    effect = shot(); effect._physics_process(0.4)
    check(near.hits == 0 and far.hits == 1, "dying actor cannot consume a shot")
    clear()
    near = target("above_path", 70); near.position.y = 35
    far = target("on_path", 150)
    effect = shot(); effect._physics_process(0.4)
    check(near.hits == 0 and far.hits == 1, "hurtbox slab rejects off-axis target")
    clear(); stage.free()
    print("PLAYER_PROJECTILE_CONTACT checks=%d failures=%d" % [checks, failures])
    quit(0 if failures == 0 else 1)
