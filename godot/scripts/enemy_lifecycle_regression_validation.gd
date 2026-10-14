extends SceneTree
## Asset-independent adversarial lifecycle probes against the production scripts.
const ENEMY = preload("res://scripts/enemy_actor.gd")
const EFFECT = preload("res://scripts/enemy_attack_effect.gd")
const DUMMY = preload("res://scripts/enemy_dummy.gd")
var failures := 0
var checks := 0
var deaths := 0

class Target extends CharacterBody2D:
    var ui_input_locked := false
    var hits := 0
    var snares := 0
    var callback := Callable()
    func take_damage(_amount: int, _point: Vector2, _blockable: bool = true) -> void:
        hits += 1
        if callback.is_valid():
            var action := callback
            callback = Callable()
            action.call()
    func apply_snare(_seconds: float) -> void:
        snares += 1

class OptionalTarget extends CharacterBody2D:
    # Minimal valid combat target: UI-lock state is intentionally absent.
    var hits := 0
    func take_damage(_amount: int, _point: Vector2, _blockable: bool = true) -> void:
        hits += 1

class OptionalVictim extends Node2D:
    # Minimal enemy target: dying state is intentionally absent.
    var hits := 0
    func take_hit(_amount: int, _direction: int) -> void:
        hits += 1

class Victim extends Node2D:
    var dying := false
    var hits := 0
    var callback := Callable()
    func take_hit(_amount: int, _direction: int) -> void:
        hits += 1
        if callback.is_valid():
            var action := callback
            callback = Callable()
            action.call()

class Owner extends Node2D:
    var dying := false
    var resident := true
    func world_residency_active() -> bool:
        return resident

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("FAIL: " + label)
    else:
        print("PASS: " + label)

func _new_effect(stage: Node, owner_node: Node2D = null):
    var effect = EFFECT.new()
    effect.owner_actor = owner_node
    effect.effect_kind = "pool"
    stage.add_child(effect)
    effect.set_physics_process(false)
    return effect

func _run() -> void:
    var stage := Node2D.new()
    root.add_child(stage)
    var target := Target.new()
    stage.add_child(target)
    target.add_to_group("player")
    target.position = Vector2(0, 42)
    var effect = _new_effect(stage)
    effect.snare = 1
    target.callback = func(): effect._physics_process(0.01)
    effect._physics_process(0.01)
    effect._physics_process(0.01)
    _check(target.hits == 1 and target.snares == 1, "hazard consumes damage before reentrant callback and never repeats")
    effect.cancel()
    effect.cancel()
    effect._physics_process(0.01)
    _check(target.hits == 1 and not effect.is_in_group("hostile_attack") and not effect.visible, "cancel is immediate, idempotent and terminal")
    effect = _new_effect(stage)
    effect.snare = 1
    target.callback = func(): effect.cancel()
    effect._physics_process(0.01)
    _check(target.snares == 1, "damage-triggered cancellation prevents a late snare")
    effect = _new_effect(stage)
    effect.queue_free()
    effect._physics_process(0.01)
    _check(target.hits == 2, "queued effect cannot damage before deferred free")
    var owner_node := Owner.new()
    stage.add_child(owner_node)
    effect = _new_effect(stage, owner_node)
    owner_node.free()
    effect._physics_process(0.01)
    _check(effect.cancelled and target.hits == 2, "freed owner cancels hazard")
    owner_node = Owner.new()
    stage.add_child(owner_node)
    effect = _new_effect(stage, owner_node)
    stage.remove_child(owner_node)
    effect._physics_process(0.01)
    _check(effect.cancelled, "detached owner cancels hazard")
    owner_node.free()
    owner_node = Owner.new()
    stage.add_child(owner_node)
    effect = _new_effect(stage, owner_node)
    owner_node.resident = false
    effect._physics_process(0.01)
    _check(effect.cancelled, "nonresident owner cannot retain offscreen hazard")
    effect = _new_effect(stage)
    effect.arm_delay = 0.1
    target.ui_input_locked = true
    effect._physics_process(1.0)
    _check(effect.age == 0 and target.hits == 2, "UI pause freezes warning clock and damage")
    target.ui_input_locked = false
    effect._physics_process(0.05)
    _check(target.hits == 2, "warning remains safe after resume")
    effect._physics_process(0.06)
    _check(target.hits == 3, "warning resumes and arms once")
    effect.cancel()
    effect = _new_effect(stage)
    effect.duration = 0.01
    effect._physics_process(0.02)
    _check(effect.cancelled and not effect.is_in_group("hostile_attack"), "natural expiry uses same terminal path")
    var enemy = ENEMY.new()
    stage.add_child(enemy)
    enemy.set_physics_process(false)
    enemy.ai_commands = [{"id": "test", "start_cooldown": 0.75}]
    enemy.cooldowns = {"test": 8.0, "stale": 99.0}
    enemy.battle_phase = 2
    enemy.phase_pause = 0.9
    enemy.attack_elapsed = 1
    enemy.trail_clock = 1
    var pending = enemy._effect("pool", Vector2.ZERO, Vector2.ZERO, {}, 3, 3)
    var tween: Tween = enemy._combat_tween()
    tween.tween_interval(5)
    enemy.reset_for_respawn()
    _check(pending.cancelled and enemy.owned_attack_effects.is_empty(), "respawn cancels previous encounter hazards")
    _check(enemy.battle_phase == 1 and enemy.phase_pause == 0 and enemy.attack_elapsed == 0 and enemy.trail_clock == 0, "respawn resets phase and attack clocks")
    _check(enemy.cooldowns == {"test": 0.75}, "respawn rebuilds configured initial cooldowns")
    _check(not tween.is_valid(), "respawn kills old pose and warning tweens")
    enemy.lure_timer = 2
    target.ui_input_locked = true
    enemy._physics_process(0.5)
    _check(enemy.lure_timer == 2 and enemy.combat_visuals_paused, "lured enemy still honors UI pause")
    enemy._on_body_entered(target)
    _check(target.hits == 3, "UI lock rejects contact callback")
    target.ui_input_locked = false
    enemy.died.connect(func(_id, _boss, _kind):
        deaths += 1
        if deaths == 1:
            enemy._begin_death_dissolve()
        enemy._on_body_entered(target))
    enemy.take_hit(999, 1)
    enemy.take_hit(999, 1)
    enemy._begin_death_dissolve()
    _check(deaths == 1 and target.hits == 3, "death is idempotent even when reward callback re-enters death/contact")
    _check(not enemy.is_in_group("enemy") and enemy.state == "dead" and enemy.active_attack.is_empty(), "dead enemy leaves targeting and attack state immediately")
    var dummy = DUMMY.new()
    stage.add_child(dummy)
    dummy.take_hit(999, 1)
    var dead_hp: int = dummy.hp
    dummy.take_hit(1, 1)
    dummy._on_body_entered(target)
    _check(dummy.hp == dead_hp and target.hits == 3 and not dummy.is_in_group("enemy"), "dummy death blocks late hit and contact callbacks")
    await process_frame
    _check(not enemy.monitoring and not enemy.monitorable, "deferred death disables both collision roles")
    _check(enemy._effect("pool", Vector2.ZERO, Vector2.ZERO, {}, 0, 1) == null, "dead owner cannot spawn a new trail hazard")
    var collision_enemy = ENEMY.new()
    collision_enemy.position = target.position
    stage.add_child(collision_enemy)
    collision_enemy.set_physics_process(false)
    var target_shape := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = Vector2(20, 20)
    target_shape.shape = rectangle
    target.add_child(target_shape)
    target.callback = func(): collision_enemy.take_hit(999, 1)
    for index in range(4):
        await physics_frame
        await process_frame
    _check(collision_enemy.dying and not collision_enemy.monitoring, "lethal hit inside real physics contact callback defers collision changes safely")
    var snares_before := target.snares
    effect = _new_effect(stage)
    effect.position = target.position - Vector2(0, 42)
    effect.snare = 1
    target.callback = func(): effect.queue_free()
    effect._physics_process(0.01)
    _check(target.snares == snares_before, "damage-triggered queued removal also suppresses late snare")
    var victim := Victim.new()
    stage.add_child(victim)
    victim.add_to_group("enemy")
    effect = _new_effect(stage)
    effect.reflected = true
    victim.callback = func(): effect._physics_process(0.01)
    effect._physics_process(0.01)
    _check(victim.hits == 1 and effect.cancelled, "reflected hit is consumed before reentrant enemy callback")
    var melee_enemy = ENEMY.new()
    stage.add_child(melee_enemy)
    melee_enemy.set_physics_process(false)
    var hits_before := target.hits
    var command := {"type": "melee", "hit_width": 200, "hit_height": 200}
    target.callback = func(): melee_enemy._try_damage_player(command)
    melee_enemy._try_damage_player(command)
    _check(target.hits == hits_before + 1, "melee hit is consumed before reentrant damage callback")
    target.remove_from_group("player")
    var optional := OptionalTarget.new()
    optional.position = Vector2(0, 42)
    stage.add_child(optional)
    optional.add_to_group("player")
    melee_enemy.attack_has_hit = false
    melee_enemy._try_damage_player(command)
    _check(optional.hits == 1, "melee accepts target without optional UI-lock property")
    melee_enemy.contact_timer = 0
    melee_enemy._on_body_entered(optional)
    _check(optional.hits == 2, "contact accepts target without optional UI-lock property")
    var live_dummy = DUMMY.new()
    stage.add_child(live_dummy)
    live_dummy.set_physics_process(false)
    live_dummy._on_body_entered(optional)
    live_dummy._physics_process(0.01)
    _check(optional.hits == 3, "dummy movement and contact accept absent optional UI-lock property")
    var optional_owner := Node2D.new()
    stage.add_child(optional_owner)
    effect = _new_effect(stage, optional_owner)
    effect._physics_process(0.01)
    _check(optional.hits == 4, "effect accepts absent UI-lock and owner dying properties")
    effect.cancel()
    for enemy_node in get_nodes_in_group("enemy"):
        enemy_node.remove_from_group("enemy")
    var optional_victim := OptionalVictim.new()
    stage.add_child(optional_victim)
    optional_victim.add_to_group("enemy")
    effect = _new_effect(stage)
    effect.reflected = true
    effect._physics_process(0.01)
    _check(optional_victim.hits == 1, "reflected hit accepts absent optional dying property")
    stage.queue_free()
    await process_frame
    print("ENEMY_LIFECYCLE_REGRESSION checks=%d failures=%d" % [checks, failures])
    quit(0 if failures == 0 else 1)
