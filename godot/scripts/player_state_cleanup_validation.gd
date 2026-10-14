extends SceneTree
## Actual controller state logic with presentation disabled. Not a World/playthrough test.
class TestPlayer extends "res://scripts/player_controller.gd":
    func _ready() -> void:
        _ensure_input_actions()
        set_physics_process(false)
    func _play(_name: StringName, _restart: bool = false) -> void:
        pass
    func _spawn_thread_snap_vfx(_source_position: Vector2) -> void:
        pass

var failures := 0
var checks := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(label)

func _run() -> void:
    var player := TestPlayer.new()
    var sprite := AnimatedSprite2D.new()
    sprite.name = "AnimatedSprite2D"
    player.add_child(sprite)
    var hitbox := Area2D.new()
    hitbox.name = "AttackHitbox"
    player.add_child(hitbox)
    var shape := CollisionShape2D.new()
    shape.name = "CollisionShape2D"
    shape.shape = RectangleShape2D.new()
    hitbox.add_child(shape)
    root.add_child(player)
    player.dash_timer = 0.1
    player.velocity = Vector2(player.dash_speed, 0)
    _check(player.can_ignore_enemy_contact(Vector2.ZERO), "Dash still ignores ordinary enemy body contact")
    player.take_damage(1, player.global_position + Vector2(50, 0))
    _check(player.hp == player.max_hp - 1, "Direct hazard damage lands during dash")
    _check(player.dash_timer == 0.0, "Damage cancels active dash")
    _check(player.velocity.x < 0 and player.velocity.y < 0, "Damage applies knockback")
    player._physics_process(0.01)
    _check(player.velocity.x < 0 and player.velocity.y < 0, "Next tick preserves knockback instead of resuming dash")
    player.hurt_timer = 0.0
    player.dash_timer = 0.1
    player.arrival_guard_timer = 0.5
    player.take_damage(1, player.global_position + Vector2(50, 0))
    _check(player.dash_timer == 0.1, "Ignored damage does not cancel dash")
    player.arrival_guard_timer = 0.0
    player.apply_snare(5.0)
    player.respawn_at(Vector2.ZERO)
    _check(player.snare_timer == 5.0, "Generic relocation preserves status effects")
    player.restore_at_save_point()
    _check(player.snare_timer == 0.0 and player.hp == player.max_hp and player.energy == player.max_energy, "Full save-point restoration clears snare")
    player.apply_snare(5.0)
    player._hard_respawn()
    _check(player.snare_timer == 0.0 and player.hp == player.max_hp and player.energy == 0, "Death respawn clears snare and retains normal restoration rules")
    player.queue_free()
    await process_frame
    print("PLAYER_STATE_CLEANUP_%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
    quit(0 if failures == 0 else 1)
