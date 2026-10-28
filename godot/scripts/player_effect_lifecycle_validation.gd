extends SceneTree
const EFFECT := preload("res://scripts/player_tool_effect.gd")
var checks := 0
var failures := 0
class Shooter extends CharacterBody2D:
    var hp := 5
    var death_timer := 0.0
    var ui_input_locked := false
    var combat_effect_generation := 0
class Stage extends Node2D:
    var world_loading := false
    var chapter_transitioning := false
class Target extends Node2D:
    var hp := 100
    var hits := 0
    func take_hit(amount: int, _direction: int) -> void: hits += 1; hp -= amount
    func get_hurtbox_rect() -> Rect2: return Rect2(position - Vector2(10, 10), Vector2(20, 20))
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures += 1; push_error(label)
func run() -> void:
    var stage := Stage.new(); root.add_child(stage)
    var shooter := Shooter.new(); stage.add_child(shooter)
    var enemy := Target.new(); enemy.position.x = 70; stage.add_child(enemy); enemy.add_to_group("enemy")
    for kind in ["projectile", "wave", "trap", "snare_field"]:
        var effect := EFFECT.new(); effect.owner_player = shooter
        effect.payload = {"kind": kind, "duration": 2.0, "range": 420.0, "damage": 1}
        stage.add_child(effect); effect.set_physics_process(false)
        shooter.ui_input_locked = true
        for tick in range(3): effect._physics_process(0.5)
        check(effect.elapsed == 0 and effect.position == Vector2.ZERO and enemy.hits == 0, kind + " pauses clock, position and damage")
        check(not effect.cancelled, kind + " remains resumable")
        shooter.ui_input_locked = false
        effect._physics_process(0.2)
        check(effect.elapsed > 0, kind + " resumes normally")
        effect.cancel(); effect._physics_process(0.2)
        var hits := enemy.hits
        effect._physics_process(0.2)
        check(enemy.hits == hits and effect.cancelled and not effect.visible, kind + " cancel is idempotent and inert")
        effect.free(); enemy.hits = 0
    for reason in ["death", "generation", "transition", "loading", "detached"]:
        var effect := EFFECT.new(); effect.owner_player = shooter
        effect.payload = {"kind": "projectile", "damage": 1}; stage.add_child(effect); effect.set_physics_process(false)
        match reason:
            "death": shooter.hp = 0
            "generation": shooter.combat_effect_generation += 1
            "transition": stage.chapter_transitioning = true
            "loading": stage.world_loading = true
            "detached": stage.remove_child(shooter)
        effect._physics_process(0.5)
        check(effect.cancelled and effect.elapsed == 0 and enemy.hits == 0, reason + " retires before contact")
        effect.free(); shooter.hp = 5; stage.chapter_transitioning = false; stage.world_loading = false
        if not shooter.is_inside_tree(): stage.add_child(shooter)
    var pot := EFFECT.new(); pot.owner_player = shooter; pot.payload = {"id": "shard"}
    stage.add_child(pot); pot.set_physics_process(false); pot.landed = true; pot.warning_timer = 0.2
    shooter.ui_input_locked = true; pot._physics_process(1)
    check(is_equal_approx(pot.warning_timer, 0.2) and not pot.cancelled, "landed pot fuse pauses with UI")
    shooter.ui_input_locked = false; pot._physics_process(0.1)
    check(is_equal_approx(pot.warning_timer, 0.1), "fuse resumes from same warning")
    pot.cancel(); pot.free()
    var orphan := EFFECT.new(); orphan.owner_player = shooter; orphan.payload = {"kind": "projectile"}
    stage.add_child(orphan); orphan.set_physics_process(false); shooter.free(); orphan._physics_process(0.1)
    check(orphan.cancelled and orphan.elapsed == 0, "freed owner retires before typed object access")
    orphan.free(); stage.free()
    print("PLAYER_EFFECT_LIFECYCLE checks=%d failures=%d" % [checks, failures])
    quit(0 if failures == 0 else 1)
