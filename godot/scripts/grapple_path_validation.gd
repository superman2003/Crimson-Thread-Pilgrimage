extends SceneTree
const PATH := preload("res://scripts/grapple_path.gd")
var checks := 0
var failures := 0
class Stage extends Node2D:
    var blocked := false
    var probes := 0
    func _ensure_collision_segment(_start: Vector2, _finish: Vector2) -> void: probes += 1
    func _rock_ray_hit(start: Vector2, finish: Vector2) -> Dictionary:
        return {"position": start.lerp(finish, 0.5)} if blocked else {}
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures += 1; push_error(label)
func run() -> void:
    var stage := Stage.new(); root.add_child(stage)
    var player: CharacterBody2D = load("res://scenes/Player.tscn").instantiate(); stage.add_child(player)
    player.set_physics_process(false); player.thread_grapple_unlocked = true
    var later := Node2D.new(); later.name = "z_anchor"; later.position = Vector2(160, -42); stage.add_child(later); later.add_to_group("grapple_anchor")
    var earlier := Node2D.new(); earlier.name = "a_anchor"; earlier.position = later.position; stage.add_child(earlier); earlier.add_to_group("grapple_anchor")
    check(player._try_start_grapple() and player.grapple_anchor == earlier, "equal score selects stable anchor path independent of group order")
    check(stage.probes >= 2, "candidate path warms collision segments")
    player._stop_grapple(); stage.blocked = true
    check(not player._try_start_grapple(), "authored rock blocks starting grapple")
    stage.blocked = false
    check(player._try_start_grapple(), "clear authored path remains selectable")
    stage.blocked = true; player._update_grapple(0.01)
    check(player.grapple_timer == 0 and player.grapple_anchor == null, "new obstruction releases pull")
    stage.blocked = false; later.hide(); earlier.set_meta("grapple_enabled", false)
    check(not player._try_start_grapple(), "hidden and disabled anchors cannot attach")
    earlier.set_meta("grapple_enabled", true); player._try_start_grapple(); earlier.hide(); player._update_grapple(0.01)
    check(player.grapple_timer == 0, "hidden active anchor releases pull")
    earlier.show(); player._try_start_grapple(); earlier.set_meta("grapple_enabled", false); player._update_grapple(0.01)
    check(player.grapple_timer == 0, "disabled active anchor releases pull")
    earlier.set_meta("grapple_enabled", true); player._try_start_grapple(); earlier.position.x = player.grapple_range * 2; player._update_grapple(0.01)
    check(player.grapple_timer == 0, "anchor moving beyond tether limit releases pull")
    earlier.position.x = 160
    var wall := StaticBody2D.new(); wall.position = Vector2(80, -42)
    var collider := CollisionShape2D.new(); var shape := RectangleShape2D.new(); shape.size = Vector2(10, 200)
    collider.shape = shape; wall.add_child(collider); stage.add_child(wall)
    await physics_frame; await process_frame
    check(not player._try_start_grapple(), "actual static body also blocks attachment")
    wall.free(); await physics_frame; await process_frame
    check(player._try_start_grapple(), "removing wall restores actual route")
    var timer: float = player.grapple_timer; player._update_grapple(0); player._update_grapple(NAN)
    check(player.grapple_timer == timer and player.velocity.is_finite(), "invalid step cannot divide by zero or spend tether time")
    player._stop_grapple()
    var retirement := preload("res://scripts/audio_retirement.gd"); retirement.retire_tree(stage); stage.free(); await process_frame
    check(await retirement.drain(self), "fixture drains actual player audio")
    print("GRAPPLE_PATH checks=%d failures=%d" % [checks, failures])
    quit(0 if failures == 0 else 1)
