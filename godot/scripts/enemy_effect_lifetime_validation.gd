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
    failures += await preload("res://scripts/projectile_art_validation.gd").new().run(self, enemy)
    failures += await preload("res://scripts/ground_hazard_art_validation.gd").new().run(self, enemy)
    await _verify_beam_channel(enemy)
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
    print("ENEMY_EFFECT_LIFETIME_VALIDATION checks=46 failures=%d" % failures)
    quit(0 if failures == 0 else 1)

func _verify_beam_channel(enemy) -> void:
    var heading := Vector2(3.0, 4.0).normalized()
    var beam: Node2D = enemy._effect(
        "beam",
        Vector2(180.0, 240.0),
        heading * 420.0,
        {"radius": 12.0, "beam_length": 180.0, "damage": 2},
        0.5,
        0.4
    )
    _assert(is_instance_valid(beam), "configured beam is created through the enemy attack path")
    if not is_instance_valid(beam):
        return

    _assert(beam.get("effect_kind") == "beam", "beam effect kind is preserved")
    _assert(beam.get("heading").distance_to(heading) < 0.001, "beam channel follows configured attack direction")
    _assert(is_equal_approx(float(beam.get("radius")), 12.0), "beam visual half-width uses configured radius")
    _assert(is_equal_approx(float(beam.get("length")), 180.0), "beam channel ends at configured length")
    _assert(is_equal_approx(float(beam.get("damage")), 2), "visual geometry leaves configured damage unchanged")
    _assert(is_equal_approx(float(beam.get("arm_delay")), 0.5), "beam warning duration remains unchanged")
    _assert(is_equal_approx(float(beam.get("duration")), 0.9), "beam total lifetime remains unchanged")

    var corners: PackedVector2Array = beam.call("_beam_channel_corners")
    var side := heading.orthogonal() * 12.0
    var endpoint := heading * 180.0
    _assert(corners.size() == 4, "beam channel geometry has four corners")
    if corners.size() == 4:
        _assert(corners[0].distance_to(-side) < 0.001, "beam channel begins at negative radius edge")
        _assert(corners[1].distance_to(side) < 0.001, "beam channel begins at positive radius edge")
        _assert(corners[2].distance_to(endpoint + side) < 0.001, "beam channel ends at positive radius edge")
        _assert(corners[3].distance_to(endpoint - side) < 0.001, "beam channel ends at negative radius edge")

    var axis_center := beam.global_position + heading * 90.0
    var player_half_width_and_tolerance := 19.0
    var visual_radius := float(beam.get("radius"))
    _assert(beam.call("_hits_player", axis_center + heading.orthogonal() * (visual_radius + player_half_width_and_tolerance - 0.1)), "beam player-center hit threshold includes player half-width and tolerance")
    _assert(not beam.call("_hits_player", axis_center + heading.orthogonal() * (visual_radius + player_half_width_and_tolerance + 0.1)), "beam player-center threshold remains separate from visual radius")
    beam.call("cancel")
    _assert(beam.is_queued_for_deletion(), "beam test fixture uses the production cancellation path")
    await _frames(2)
    _assert(not is_instance_valid(beam), "cancelled beam is freed before lifetime rounds begin")

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
