extends SceneTree
## Exercise real physics occlusion and warning cleanup independently of assets.
const ENEMY_SCRIPT := preload("res://scripts/enemy_actor.gd")
var failures := 0
var checks := 0

class TestPlayer extends CharacterBody2D:
    var damage_received := 0
    func take_damage(amount: int, _origin: Vector2) -> void:
        damage_received += amount

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var stage := Node2D.new()
    root.add_child(stage)
    var enemy = ENEMY_SCRIPT.new()
    enemy.position = Vector2(100, 100)
    stage.add_child(enemy)
    enemy.set_physics_process(false)
    var player := TestPlayer.new()
    player.position = Vector2(150, 100)
    player.collision_layer = 2
    player.add_to_group("player")
    stage.add_child(player)
    var wall := StaticBody2D.new()
    wall.position = Vector2(125, 58)
    var collider := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = Vector2(8, 150)
    collider.shape = shape
    wall.add_child(collider)
    stage.add_child(wall)
    await _frames(2)
    _assert(not enemy._has_line_of_sight(player), "solid wall occludes enemy sight")
    var command := {"type": "melee", "id": "test", "hit_width": 160, "hit_height": 100, "damage": 1}
    enemy.ai_commands = [command]
    enemy.attack_desire = 10
    _assert(not enemy._try_start_attack(player), "enemy cannot begin an attack through wall")
    enemy._try_damage_player(command)
    _assert(player.damage_received == 0, "active melee cannot damage through wall")
    var beam: Node2D = enemy._effect("beam", Vector2(100, 58), Vector2.RIGHT, {"beam_length": 300}, 1.0, 0.1)
    _assert(beam.length < 25 and not beam._hits_player(Vector2(150, 58)), "beam warning and damage stop at the first solid wall")
    beam.cancel()
    wall.queue_free()
    await _frames(2)
    _assert(enemy._has_line_of_sight(player), "removing wall restores sight")
    enemy.attack_has_hit = false
    enemy._try_damage_player(command)
    _assert(player.damage_received == 1, "same attack damages visible player")
    enemy.apply_snare(1.0)
    _assert(is_equal_approx(enemy._movement_speed(), enemy.speed * 0.5), "snare halves voluntary movement")
    enemy.apply_snare(0.5)
    _assert(is_equal_approx(enemy.snare_timer, 1.0), "repeated snare cannot shorten existing control")
    enemy.cooldowns = {"test": 2.0}
    enemy._tick_timers(0.5)
    _assert(is_equal_approx(enemy.snare_timer, 0.5) and is_equal_approx(enemy.cooldowns.test, 1.5), "control and cooldown timers advance at real speed")
    enemy._tick_timers(0.6)
    _assert(is_equal_approx(enemy._movement_speed(), enemy.speed), "expired control restores movement")
    enemy.apply_snare(1.0)
    enemy.reset_for_respawn()
    _assert(is_zero_approx(enemy.snare_timer), "respawn clears control status")
    for index in range(12):
        enemy.original_visual = false
        enemy._show_telegraph(command)
        var warning_tween: Tween = enemy.telegraph_tween
        _assert(warning_tween.is_valid(), "telegraph %d starts tween" % index)
        enemy._clear_telegraph()
        _assert(not warning_tween.is_valid() and enemy.telegraph == null, "telegraph %d cancels tween before deleting node" % index)
        await _frames(1)
    _assert(enemy.combat_tweens.size() <= 2, "repeated cancelled warnings do not accumulate live tweens")
    stage.queue_free()
    await _frames(2)
    print("ENEMY_VISIBILITY_VALIDATION checks=%d failures=%d" % [checks, failures])
    quit(0 if failures == 0 else 1)

func _frames(count: int) -> void:
    for index in range(count):
        await physics_frame
        await process_frame

func _assert(condition: bool, label: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error("FAIL: " + label)
