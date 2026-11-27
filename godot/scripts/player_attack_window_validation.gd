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
    for kind in ["ranged", "tool", "resonance", "defense"]:
        var skill_player := player()
        skill_player.active_skill = {"kind": kind}
        skill_player._update_attack(1.0)
        check(skill_player.active_skill.is_empty(), kind + " active-skill state ends with its recovery window")
        skill_player.dash_timer = 0.2
        check(skill_player.can_ignore_enemy_contact(Vector2.ZERO), kind + " cannot disable the next dash contact guard")
        skill_player.free()
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
    # Regression checks for cleave horizontal direction, shockwave additive stagger, and resonance damage.
    for action_name in ["move_left", "move_right", "aim_up", "aim_down"]:
        if not InputMap.has_action(action_name):
            InputMap.add_action(action_name)
    var floor_body := StaticBody2D.new()
    var floor_shape := CollisionShape2D.new()
    var floor_rect := RectangleShape2D.new()
    floor_rect.size = Vector2(400, 20)
    floor_shape.shape = floor_rect
    floor_body.position = Vector2(0, 20)
    floor_body.add_child(floor_shape)
    root.add_child(floor_body)
    var ability_player := player()
    var body_shape := CollisionShape2D.new()
    var body_rect := RectangleShape2D.new()
    body_rect.size = Vector2(20, 20)
    body_shape.shape = body_rect
    ability_player.add_child(body_shape)
    ability_player.position = Vector2(0, 0)
    ability_player.energy = 100
    ability_player.max_energy = 100
    ability_player.attack_timer = 0.0
    ability_player.facing = -1
    ability_player.current_attack_direction = Vector2.DOWN
    ability_player.selected_skill = {"id": "cleave", "kind": "melee", "energy_cost": 10, "damage": 2, "range": 120.0, "windup": 0.1, "active": 0.1, "recovery": 0.1, "cooldown": 0.1}
    check(ability_player.cast_selected_skill() and ability_player.current_attack_direction == Vector2(-1, 0),
        "cleave forces horizontal attack direction rather than vertical aim")
    ability_player.attack_timer = 0.0
    ability_player.skill_cooldown = 0.0
    ability_player.velocity = Vector2(0, 120)
    await physics_frame
    ability_player.move_and_slide()
    ability_player.build_profile = {"crest_id": "bell", "mechanism_unlocked": true}
    ability_player.bell_pressure = 2
    ability_player.selected_skill = {"id": "shockwave", "kind": "shockwave", "energy_cost": 10, "damage": 2, "stagger": 0.4, "range": 140.0, "windup": 0.1, "active": 0.1, "recovery": 0.1, "cooldown": 0.1}
    check(ability_player.is_on_floor() and ability_player.cast_selected_skill() and is_equal_approx(float(ability_player.active_skill.get("stagger", 0.0)), 1.0),
        "shockwave bell pressure adds to base stagger instead of overwriting Branch B stagger")
    ability_player.attack_timer = 0.0
    ability_player.skill_cooldown = 0.0
    ability_player.resonance_cooldown = 0.0
    ability_player.crown_resonance_unlocked = true
    ability_player.attack_damage = 5
    ability_player.bell_pressure = 2
    check(ability_player._try_resonance() and ability_player.attack_damage == 1,
        "crown resonance uses its own damage instead of inheriting attack_2 damage")
    ability_player.free()
    floor_body.free()
    print("PLAYER_ATTACK_WINDOW checks=%d failures=%d" % [checks, failures])
    quit(0 if failures == 0 else 1)
