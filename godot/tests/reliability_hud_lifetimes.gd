extends SceneTree
const HUD = preload("res://scripts/hud_occlusion.gd")
class Level extends Node2D:
    var player: Node2D
class Enemy extends Node2D:
    var dying := false
    var owned_attack_effects: Array = []
    func get_hurtbox_rect() -> Rect2:return Rect2(global_position, Vector2(30, 80))
class Effect extends Node2D:
    var radius := 12.0
    var heading := Vector2.RIGHT
    var length := 300.0
    var effect_kind := "beam"
    var cancelled := false
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:failures.append(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
    var level := Level.new();root.add_child(level)
    var enemy := Enemy.new();level.add_child(enemy);enemy.add_to_group("enemy")
    var effect := Effect.new();level.add_child(effect);effect.add_to_group("hostile_attack")
    effect.position = Vector2(500, 200)
    check(HUD.occupant_rects(level).size() == 2, "group-owned effect participates without owner-array registration")
    enemy.owned_attack_effects.append(effect)
    check(HUD.occupant_rects(level).size() == 2, "group and legacy owner arrays cannot duplicate footprint")
    var rects := HUD.occupant_rects(level)
    check(HUD.covered(Rect2(770, 195, 30, 10), rects), "beam tip makes HUD step aside")
    enemy.dying = true
    check(HUD.occupant_rects(level).size() == 1, "dying body does not erase still-visible effect before cancellation")
    effect.cancelled = true
    check(HUD.occupant_rects(level).is_empty(), "cancelled effect immediately stops fading HUD")
    effect.cancelled = false;effect.hide()
    check(HUD.occupant_rects(level).is_empty(), "hidden effect cannot fade HUD")
    effect.show();effect.queue_free()
    check(HUD.occupant_rects(level).is_empty(), "queued effect cannot fade HUD")
    await process_frame
    check(HUD.occupant_rects(level).is_empty(), "stale freed owner reference is safe")
    enemy.dying = false;enemy.hide()
    check(HUD.occupant_rects(level).is_empty(), "hidden enemy hurtbox cannot fade HUD")
    var control := Control.new();root.add_child(control);control.size = Vector2(40, 20)
    var dead := Control.new();dead.free()
    check(HUD.group_rect([dead, control]).size == Vector2(40, 20), "freed control is filtered before casting")
    check(HUD.step_alpha(NAN, true, 0) == HUD.FADED_ALPHA, "invalid prior alpha recovers to visible policy target")
    check(HUD.step_alpha(1.0, true, NAN) == 1.0, "invalid delta cannot poison alpha")
    check(HUD.step_alpha(0.3, false, -1) == 0.3, "negative time cannot reverse fade")
    check(HUD.step_alpha(1, true, 1) == HUD.FADED_ALPHA and HUD.step_alpha(0.3, false, 1) == 1, "normal fade reaches both bounds")
    level.queue_free();control.queue_free();await process_frame
    for failure in failures:push_error(failure)
    print("RELIABILITY_HUD_LIFETIMES checks=%d failures=%d" % [checks, failures.size()])
    quit(0 if failures.is_empty() else 1)
