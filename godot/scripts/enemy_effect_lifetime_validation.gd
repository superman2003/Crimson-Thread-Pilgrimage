extends SceneTree
## Long exploration permits earlier projectiles and combat tweens to expire.
const ENEMY_SCRIPT := preload("res://scripts/enemy_actor.gd")
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var stage := Node2D.new()
    root.add_child(stage)
    var enemy = ENEMY_SCRIPT.new()
    stage.add_child(enemy)
    enemy.set_physics_process(false)
    for round_index in range(5):
        var effect: Node2D = enemy._effect("projectile", Vector2(100, 100), Vector2.RIGHT * 30.0, {}, 0.0, 0.02)
        _assert(is_instance_valid(effect), "round %d spawns after prior effects expire" % round_index)
        _assert(enemy.owned_attack_effects.size() == 1, "round %d prunes freed effect references" % round_index)
        var tween: Tween = enemy._combat_tween()
        tween.tween_interval(0.02)
        _assert(enemy.combat_tweens.size() == 1, "round %d prunes finished tween references" % round_index)
        await _frames(5)
        _assert(not is_instance_valid(effect), "round %d effect expires through its real physics lifetime" % round_index)
        _assert(not tween.is_valid(), "round %d combat tween finishes naturally" % round_index)
        enemy._set_combat_visuals_paused(true)
        enemy._set_combat_visuals_paused(false)
    var pending: Node2D = enemy._effect("projectile", Vector2.ZERO, Vector2.ZERO, {}, 0.0, 2.0)
    pending.queue_free()
    var active: Node2D = enemy._effect("projectile", Vector2.ZERO, Vector2.ZERO, {}, 0.0, 2.0)
    _assert(enemy.owned_attack_effects.size() == 1, "queued deletion is pruned before the next projectile")
    enemy._cancel_attack_effects()
    _assert(enemy.owned_attack_effects.is_empty() and active.is_queued_for_deletion(), "owner cancellation clears remaining effects")
    await _frames(2)
    _assert(not is_instance_valid(active), "cancelled effect is freed")
    var last: Node2D = enemy._effect("projectile", Vector2.ZERO, Vector2.ZERO, {}, 0.0, 2.0)
    enemy.queue_free()
    await _frames(3)
    _assert(not is_instance_valid(last), "enemy removal cancels its live attack effects")
    stage.queue_free()
    await _frames(2)
    print("ENEMY_EFFECT_LIFETIME_VALIDATION checks=29 failures=%d" % failures)
    quit(0 if failures == 0 else 1)

func _frames(count: int) -> void:
    for index in range(count):
        await physics_frame
        await process_frame

func _assert(condition: bool, label: String) -> void:
    if condition:
        print("PASS: " + label)
    else:
        failures += 1
        push_error("FAIL: " + label)
