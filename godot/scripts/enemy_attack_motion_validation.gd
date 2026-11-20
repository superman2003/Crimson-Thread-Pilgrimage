extends SceneTree
var checks := 0
var failures := 0
class Target extends CharacterBody2D:
    var hits := 0
    var ui_input_locked := false
    func take_damage(_amount: int, _point: Vector2, _blockable: bool) -> void: hits += 1
class MotionStage extends Node2D:
    var chapter_terrain: Node = null
class Enemy extends "res://scripts/enemy_actor.gd":
    func _ready() -> void: set_physics_process(false)
    func _pose_sprite(_pose: String, _command: Dictionary = {}) -> void: pass
    func _advance_pose_loop() -> void: pass
    func _clear_telegraph() -> void: pass
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures += 1; push_error(label)
func enemy(stage: Node, kind: String) -> Enemy:
    var node := Enemy.new(); stage.add_child(node)
    node.state = "active"; node.state_timer = 1.0; node.hurtbox_size = Vector2(20, 40); node.hurtbox_offset = Vector2(0, -20)
    node.active_attack = {"type": kind, "active": 1.0, "damage": 1, "lunge_speed": 1000, "hit_width": 40, "hit_height": 60, "offset": 0}
    node.attack_target = Vector2(300, 0)
    return node
func run() -> void:
    var stage := Node2D.new(); root.add_child(stage)
    var target := Target.new(); stage.add_child(target); target.position = Vector2(150, 0); target.add_to_group("player")
    for kind in ["lunge", "dive", "combo"]:
        var node := enemy(stage, kind); target.hits = 0; node._update_active(0.7)
        check(target.hits == 1, kind + " sweeps target between endpoints")
        node._update_active(0.1)
        check(target.hits == 1, kind + " retains single accepted contact")
        node.free()
    var node := enemy(stage, "lunge"); node.state_timer = 0.1; node._update_active(1)
    check(is_equal_approx(node.position.x, 100), "movement cannot borrow recovery duration")
    node.free()
    var wall := StaticBody2D.new(); wall.position = Vector2(100, -60)
    var collider := CollisionShape2D.new(); var shape := RectangleShape2D.new(); shape.size = Vector2(10, 240)
    collider.shape = shape; wall.add_child(collider); stage.add_child(wall)
    await physics_frame; await process_frame
    for kind in ["lunge", "dive", "combo"]:
        node = enemy(stage, kind); target.hits = 0; node._update_active(0.7)
        check(node.position.x < 86 and node.position.x > 80, kind + " body stops before actual wall")
        check(target.hits == 0, kind + " wall shields target behind it")
        node.free()
    target.position.x = 45; node = enemy(stage, "lunge"); node._update_active(0.7)
    check(target.hits == 1, "target before obstruction remains hittable")
    node.free()
    node = enemy(stage, "lunge"); node._update_active(NAN); node._update_active(-1)
    check(node.position == Vector2.ZERO and node.state_timer == 1, "invalid motion leaves attack state intact")
    node.free(); stage.free()
    _check_authored_ray_edges()
    _check_combo_manifests()
    print("ENEMY_ATTACK_MOTION checks=%d failures=%d" % [checks, failures])
    quit(0 if failures == 0 else 1)

func _check_authored_ray_edges() -> void:
    var host := Node2D.new()
    host.position = Vector2(80, -40)
    root.add_child(host)
    var rect := Rect2(10, 20, 32, 40)
    var cave := preload("res://scripts/cave_world.gd").new()
    host.add_child(cave)
    cave.collision_streaming = true
    cave.solid_rects.append(rect)
    var terrain := preload("res://scripts/chapter_terrain.gd").new()
    host.add_child(terrain)
    terrain.collision_streaming = true
    terrain.collision_regions.append({"bounds": rect, "polygon": PackedVector2Array([
        rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])})
    var platforms := preload("res://scripts/world_platform_residency.gd").new()
    platforms.records["fixture"] = {"bounds": rect, "data": {}}
    var platform_ray := func(a: Vector2, b: Vector2) -> Dictionary: return platforms.ray_hit(host, a, b)
    for ray: Callable in [cave.rock_ray_hit, terrain.terrain_ray_hit, platform_ray]:
        # The end of a short, axis-aligned strike can land exactly on a wall.
        for segment in [[Vector2(-10, 30), Vector2(10, 30)], [Vector2(20, 75), Vector2(20, 60)]]:
            var end := host.to_global(segment[1])
            var hit: Dictionary = ray.call(host.to_global(segment[0]), end)
            check(not hit.is_empty() and end.is_equal_approx(hit.position), "sweep endpoint touches authored collision")
        check(ray.call(host.to_global(Vector2(-10, 19)), host.to_global(Vector2(60, 19))).is_empty(),
              "short sweep outside the authored bounds stays clear")
    host.free()

func _check_combo_manifests() -> void:
    var stage := MotionStage.new()
    root.add_child(stage)
    for original in [true,false]:
        var actor = load("res://scripts/enemy_actor.gd").new()
        actor.configure({"id":"combo_manifest_probe","kind":"page_duelist","hp":20},"")
        if original:
            actor.asset_path = "res://assets/sprites/original_creatures/page_duelist/manifest.json"
        stage.add_child(actor)
        actor.set_physics_process(false)
        var command: Dictionary = {}
        for candidate: Dictionary in actor.ai_commands:
            if String(candidate.get("type","")) == "combo":
                command = candidate.duplicate(true)
                break
        check(not command.is_empty(),"production duelist exposes its real combo command")
        actor._begin_attack(command)
        if original:
            check(actor.authored_combat_sequences.is_empty(),"selected original manifest clears expanded choreography capabilities")
            check(actor.active_attack == command and not actor.active_attack.has("combo_beats"),"original drawing set retains its authored combo clock and motion")
        else:
            check(not actor.authored_combat_sequences.is_empty(),"production expanded manifest retains its choreography")
            check(actor.active_attack.has("combo_beats") and not command.has("combo_beats"),"expanded combo uses authored beats without mutating the catalog command")
        actor.free()
    stage.free()
