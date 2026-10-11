extends SceneTree

var failures := 0
var checks := 0

class ClockBuild:
    extends RefCounted
    var ticks := 0
    func tick(_delta: float) -> void:
        ticks += 1

class Target:
    extends Node2D
    var hp := 100
    var hit_count := 0
    var snared := 0.0
    func _ready() -> void:
        add_to_group("enemy")
    func take_hit(amount: int, _direction: int) -> void:
        hp -= amount
        hit_count += 1
    func get_hurtbox_rect() -> Rect2:
        return Rect2(global_position - Vector2(20, 30), Vector2(40, 60))
    func apply_snare(seconds: float) -> void:
        snared = seconds

func _initialize() -> void:
    call_deferred("_run")

func _assert(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error(label)

func _body(point: Vector2, size: Vector2) -> StaticBody2D:
    var body := StaticBody2D.new()
    body.position = point
    var collision := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = size
    collision.shape = rectangle
    body.add_child(collision)
    root.add_child(body)
    return body

func _run() -> void:
    var floor := _body(Vector2(0, 10), Vector2(2000, 20))
    var player = load("res://scenes/Player.tscn").instantiate()
    player.position = Vector2(0, -2)
    root.add_child(player)
    var actions: Array[String] = []
    player.ability_action.connect(func(id: String, _origin: Vector2, _direction: Vector2): actions.append(id))
    for index in range(8):
        await physics_frame
    player.set_physics_process(false)
    _assert(player.is_on_floor(), "heal test fixture has grounded player")
    player.hp = 3
    player.energy = 100
    _assert(player._try_heal(), "grounded heal can begin")
    _assert(player.hp == 3 and player.energy == 40, "heal reserves energy without immediate health")
    _assert(not player.cast_selected_skill(), "healing blocks skill cast")
    player._update_heal(player.heal_duration * 0.5)
    _assert(player.hp == 3, "health waits for full channel")
    player.take_damage(1, Vector2(100, -30))
    _assert(player.heal_timer == 0.0 and player.hp == 2, "damage interrupts healing")
    _assert(player.energy == 50, "interrupted heal does not refund reserved energy")
    player.hurt_timer = 0.0
    player.heal_cooldown = 0.0
    player.energy = 100
    _assert(player._try_heal(), "second heal begins after interruption cooldown")
    player._update_heal(player.heal_duration + 0.01)
    _assert(player.hp == 3 and player.heal_timer == 0.0, "completed channel heals once")

    var stats := {"max_hp": 6, "max_energy": 120, "move_mult": 0.9, "energy_gain_mult": 1.2, "attack_damage_mult": 1.5, "heal_cost": 45, "heal_amount": 2, "heal_duration": 1.0}
    player.apply_build_stats(stats)
    var speed_once: float = player.speed
    var gain_once: int = player.energy_per_hit
    player.apply_build_stats(stats)
    _assert(player.speed == speed_once and player.energy_per_hit == gain_once, "reapplying same build is idempotent")
    player.apply_build_stats({"attack_damage_mult": 1.5, "attack_bonus": 1, "energy_per_hit": 24, "energy_gain_mult": 1.2})
    player._start_attack(&"attack_1")
    _assert(player.attack_damage == 2 and player.energy_per_hit == 24, "derived absolute profile values do not multiply twice")
    player._reset_traversal_state()
    player.apply_build_stats({})
    _assert(player.speed == 285.0 and player.heal_energy_cost == 60 and player.max_hp == 5, "empty profile restores baseline")

    player.energy = 100
    player.hp = 5
    _assert(not player._try_guard(), "locked bell guard is inert")
    player.bell_guard_unlocked = true
    _assert(player._try_guard(), "unlocked bell guard begins")
    player.take_damage(2, Vector2(100, -30))
    _assert(player.hp == 5 and player.energy == 100, "perfect guard blocks and caps refund")
    player.hurt_timer = 0.0
    _assert(not player._try_guard(), "guard cannot be chained through cooldown")
    player.guard_cooldown = 0.0
    player.energy = 50
    player._try_guard()
    player.guard_timer = 0.2
    player.take_damage(2, Vector2(100, -30))
    _assert(player.hp == 5 and player.energy == 30, "late guard spends block energy and grants no refund")
    player.hurt_timer = 0.0
    player.guard_cooldown = 0.0
    player._try_guard()
    player.take_damage(1, Vector2(-100, -30))
    _assert(player.hp == 4, "guard does not cover rear attacks")
    player._reset_traversal_state()
    player.hurt_timer = 0.0
    player.enemy_contact_guard_timer = 0.0
    _assert(not player.can_ignore_enemy_contact(Vector2(100, 0)), "idle and phase do not ignore enemy contact")

    var target := Target.new()
    target.position = Vector2(75, -42)
    root.add_child(target)
    player.global_position = Vector2.ZERO
    player._start_attack(&"attack_1")
    player._update_attack(0.02)
    _assert(target.hit_count == 0, "attack startup does not hit")
    player._update_attack(0.06)
    player._update_attack(0.02)
    _assert(target.hit_count == 1, "active attack hits target only once")
    var wall := _body(Vector2(36, -42), Vector2(10, 84))
    await physics_frame
    player._start_attack(&"attack_1")
    player._update_attack(0.1)
    _assert(target.hit_count == 1, "solid wall blocks attack damage")
    wall.queue_free()
    await physics_frame
    player._reset_traversal_state()
    player.skill_cooldown = 0.0
    player.energy = 100
    player.configure_selected_skill({"id": "control_test", "kind": "control", "damage": 1, "range": 160, "energy_cost": 20, "windup": 0.08, "active": 0.15, "recovery": 0.2, "duration": 1.4, "cooldown": 1.0})
    _assert(player.cast_selected_skill(), "control skill starts and spends energy")
    _assert(player.energy == 80 and target.snared == 0, "control waits for active frame")
    player._update_attack(0.1)
    _assert(target.snared == 1.4, "control skill applies finite snare")
    _assert(player.energy == 80, "special skill hit cannot refund its own cost")

    player._reset_traversal_state()
    player.lantern_phase_unlocked = true
    var gate := _body(Vector2(100, -42), Vector2(24, 84))
    gate.add_to_group("phase_gate")
    var ordinary := _body(Vector2(200, -42), Vector2(24, 84))
    await physics_frame
    player.energy = 100
    Input.action_press("lantern_phase")
    player._update_phase(0.01)
    _assert(player.is_phasing() and player.get_collision_exceptions().has(gate), "phase ignores explicit shadow gate")
    _assert(not player.get_collision_exceptions().has(ordinary), "phase keeps ordinary walls collidable")
    player._update_phase(0.5)
    _assert(player.energy == 80, "phase has entry cost and continuing drain")
    player.global_position = Vector2(100, 0)
    await physics_frame
    Input.action_release("lantern_phase")
    player._update_phase(0.01)
    _assert(not player.is_phasing() and player.global_position.x == 0.0, "phase released inside gate restores last safe position")
    _assert(player.get_collision_exceptions().is_empty(), "phase restores all gate collisions")

    player._reset_traversal_state()
    player.crown_resonance_unlocked = true
    player.energy = 100
    _assert(player._try_resonance(), "crown resonance is a paid action")
    player._update_attack(0.12)
    _assert(player.energy == 80 and target.hit_count >= 3, "resonance deals one readable pulse without energy feedback")
    player._reset_traversal_state()
    _assert(not player._try_resonance(), "resonance cooldown survives traversal reset")

    player._reset_traversal_state()
    player.hurt_timer = 0.0
    player.global_position = Vector2(-200, -160)
    player.velocity = Vector2.ZERO
    player.move_and_slide()
    Input.action_press("aim_down")
    player._start_attack(&"attack_1")
    _assert(not actions.has("thorn_downstrike"), "ordinary downslash cannot open thorn terrain")
    player.thorn_downstrike_unlocked = true
    player._start_attack(&"attack_1")
    _assert(actions.has("thorn_downstrike") and player.velocity.y >= 760.0, "unlocked aerial downstrike emits terrain action and accelerates fall")
    Input.action_release("aim_down")
    player._reset_traversal_state()
    player.double_jump_unlocked = true
    player.set_physics_process(true)
    Input.action_press("jump")
    await physics_frame
    await physics_frame
    player.set_physics_process(false)
    _assert(actions.has("double_thread_jump") and not player.air_jump_available, "double jump consumes one aerial charge")
    Input.action_release("jump")
    await process_frame
    player._reset_traversal_state()
    player.global_position = Vector2(-200, -160)
    player.facing = 1
    var anchor := Node2D.new()
    anchor.position = Vector2(0, -220)
    root.add_child(anchor)
    anchor.add_to_group("grapple_anchor")
    _assert(not player._try_start_grapple(), "locked grapple cannot pull")
    player.thread_grapple_unlocked = true
    _assert(player._try_start_grapple() and actions.has("echo_hook"), "unlocked grapple selects authored anchor and emits action")
    player._reset_traversal_state()
    anchor.queue_free()

    player.global_position = Vector2(-300, 0)
    player.facing = 1
    var ranged_target := Target.new()
    ranged_target.position = Vector2(-200, -42)
    root.add_child(ranged_target)
    player.cast_tool({"kind": "projectile", "damage": 2, "range": 220.0, "duration": 1.0})
    for index in range(14):
        await physics_frame
    _assert(ranged_target.hit_count == 1 and ranged_target.hp == 98, "swept projectile hits exactly once")
    player.skill_cooldown = 0.0
    player.energy = 100
    player.configure_selected_skill({"id": "needle_test", "kind": "ranged", "damage": 2, "range": 220.0, "energy_cost": 25, "windup": 0.12, "active": 0.1, "recovery": 0.2, "cooldown": 1.0})
    _assert(player.cast_selected_skill(), "ranged skill starts with an energy cost")
    player._update_attack(0.13)
    for index in range(14):
        await physics_frame
    _assert(ranged_target.hp == 96 and player.energy == 75, "ranged skill emits swept projectile in active frame without self refund")
    player._update_attack(0.5)
    var hp_after: int = ranged_target.hp
    player.cast_tool({"kind": "trap", "damage": 3, "range": 100.0, "duration": 0.25})
    ranged_target.position = Vector2(-270, -42)
    for index in range(20):
        await physics_frame
    _assert(ranged_target.hp == hp_after - 3 and ranged_target.snared > 0.0, "trap hits and snares each target once then expires")
    player._reset_traversal_state()
    player.skill_cooldown = 0.0
    player.energy = 100
    player.configure_selected_skill({"id": "ward_test", "kind": "defense", "damage": 0, "range": 0, "energy_cost": 40, "windup": 0.08, "active": 0.1, "recovery": 0.1, "duration": 0.8, "cooldown": 1.0})
    var hp_before_ward: int = player.hp
    player.cast_selected_skill()
    player._update_attack(0.1)
    player.take_damage(2, player.global_position + Vector2(-100, 0))
    _assert(player.hp == hp_before_ward and player.energy == 60 and player.guard_timer == 0.0, "paid ward blocks one hit from either direction without refund")
    var clock := ClockBuild.new()
    player.build_system = clock
    player.ui_input_locked = true
    player._physics_process(0.2)
    _assert(clock.ticks == 0, "overlay pauses build cooldown clock")
    player.ui_input_locked = false
    player._physics_process(0.2)
    _assert(clock.ticks == 1, "build cooldown clock advances after gameplay resumes")
    player.build_system = null
    ranged_target.queue_free()
    gate.queue_free()
    ordinary.queue_free()
    target.queue_free()
    player.queue_free()
    floor.queue_free()
    await process_frame
    print("PLAYER_UPGRADE_REGRESSION_%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
    quit(0 if failures == 0 else 1)
