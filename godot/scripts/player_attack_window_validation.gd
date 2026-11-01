extends SceneTree
const WINDOW := preload("res://scripts/action_time_window.gd")
var checks := 0
var failures := 0
class Player extends "res://scripts/player_controller.gd":
    var hit_calls := 0
    var effect_calls := 0
    var visual_calls := 0
    var stages: Array[String] = []
    func _ready() -> void: set_physics_process(false)
    func _apply_attack_hits() -> void: hit_calls += 1
    func _apply_special_skill() -> void: effect_calls += 1
    func _spawn_attack_vfx(_animation: StringName) -> void: visual_calls += 1
    func _seal_present(_id: String, stage: String) -> void: stages.append(stage)
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures += 1; push_error(label)
func player() -> Player:
    var node := Player.new()
    var sprite := AnimatedSprite2D.new(); sprite.name = "AnimatedSprite2D"; node.add_child(sprite)
    var box := Area2D.new(); box.name = "AttackHitbox"; node.add_child(box)
    var shape := CollisionShape2D.new(); shape.name = "CollisionShape2D"; shape.shape = RectangleShape2D.new(); box.add_child(shape)
    root.add_child(node)
    node.attack_duration = 0.4; node.attack_timer = 0.4; node.attack_windup = 0.1; node.attack_active_time = 0.1
    return node
func run() -> void:
    for delta in [0.21, 0.3, 0.4, 1.0]:
        var node := player(); node._update_attack(delta)
        check(node.hit_calls == 1 and node.visual_calls == 1, "long step resolves real melee window")
        check(node.attack_shape.disabled, "recovery retains no active collision")
        node._update_attack(0.05)
        check(node.hit_calls == 1, "post-window step cannot repeat damage")
        node.free()
    for delta in [0.21, 0.4, 1.0]:
        var node := player(); node.active_skill = {"id": "needle", "kind": "ranged"}
        node._update_attack(delta); node._update_attack(0.1)
        check(node.effect_calls == 1 and node.hit_calls == 0, "special cast fires once across skipped active interval")
        check(node.stages == ["active", "recovery"], "presentation transitions remain chronological")
        node.free()
    var node := player(); node._update_attack(0.05)
    check(node.hit_calls == 0, "windup remains inactive")
    node._update_attack(0.06)
    check(node.hit_calls == 1 and not node.attack_shape.disabled, "ordinary active sample unchanged")
    node._update_attack(NAN); node._update_attack(-1)
    check(is_equal_approx(node.attack_timer, 0.29), "invalid delta leaves attack clock intact")
    node.free()
    check(not WINDOW.intersects(0.2, 0.3, 0.1, 0.1), "end boundary cannot reopen window")
    check(WINDOW.intersects(0.0, 0.1, 0.1, 0.1), "begin boundary is inclusive")
    check(not WINDOW.intersects(0.0, 1.0, 0.1, 0.0), "zero active tool windup never becomes a hit")
    print("PLAYER_ATTACK_WINDOW checks=%d failures=%d" % [checks, failures])
    quit(0 if failures == 0 else 1)
