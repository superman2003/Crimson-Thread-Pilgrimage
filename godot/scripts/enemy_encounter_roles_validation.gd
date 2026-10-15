extends SceneTree
## Natural, damage-enabled encounter role and leash checks against live actors.
## Spawn/player positions are fixtures; attack selection, movement, occlusion,
## effect lifetime and damage use production physics/scripts.
const ENEMY := preload("res://scripts/enemy_actor.gd")
const PROFILE_PATH := "res://data/original_creature_combat.json"
var checks := 0
var failures: Array[String] = []

class FixturePlayer extends CharacterBody2D:
	var hp := 20
	var ui_input_locked := false
	var damage_events: Array[int] = []
	var gravity := 1800.0

	func _physics_process(delta: float) -> void:
		velocity.y += gravity * delta
		move_and_slide()

	func take_damage(amount: int, _origin: Vector2, _blockable: bool = true) -> void:
		hp -= amount
		damage_events.append(amount)

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("ENEMY_ENCOUNTER_ROLE FAIL: " + label)

func frames(count: int = 1) -> void:
	for unused in count:
		await physics_frame
		await process_frame

func add_floor(stage: Node2D) -> void:
	var floor := StaticBody2D.new()
	floor.name = "FixtureFloor"
	floor.collision_layer = 1
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(4000, 20)
	collision.shape = shape
	floor.position = Vector2(1700, 500)
	floor.add_child(collision)
	stage.add_child(floor)

func add_player(stage: Node2D, point: Vector2) -> FixturePlayer:
	var player := FixturePlayer.new()
	player.name = "FixturePlayer"
	player.position = point
	player.collision_layer = 2
	player.collision_mask = 1
	player.add_to_group("player")
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(34, 84)
	collision.shape = shape
	collision.position = Vector2(0, -42)
	player.add_child(collision)
	stage.add_child(player)
	return player

func add_enemy(stage: Node2D, profiles: Dictionary, kind: String, point: Vector2, leash: float, role: String = "", encounter_profile: Dictionary = {}) -> Area2D:
	var data := {"id": "role_" + kind, "kind": kind, "hp": 6, "damage": 1, "patrol": 35, "leash_radius": leash, "encounter_role": role, "encounter_profile": encounter_profile}
	var enemy: Area2D = ENEMY.new()
	enemy.configure(data, "", false, profiles.get(kind, {}).duplicate(true))
	enemy.position = point
	stage.add_child(enemy)
	# AI and hitboxes stay live; suppress only the separate body-touch damage path
	# so each recorded HP loss is attributable to an authored attack effect.
	enemy.monitoring = false
	return enemy

func wait_for_hit(player: FixturePlayer, before: int, limit: int = 300) -> bool:
	for unused in limit:
		await frames()
		if player.damage_events.size() > before:
			return true
	return false

func _make_wall(stage: Node2D, x: float) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.position = Vector2(x, 405)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 190)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	wall.add_child(collision)
	stage.add_child(wall)
	return wall

func run() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
	check(parsed is Dictionary, "authored combat profiles load")
	if not parsed is Dictionary:
		finish()
		return
	var profiles: Dictionary = parsed
	var stage := Node2D.new()
	root.add_child(stage)
	add_floor(stage)
	var player := add_player(stage, Vector2(220, 490))
	await frames(4)
	await guard_wall_and_reentry(stage, profiles, player)
	await ranged_spacing(stage, profiles, player)
	await ambush_cancel_return_reentry(stage, profiles, player)
	stage.queue_free()
	await frames(3)
	finish()

func guard_wall_and_reentry(stage: Node2D, profiles: Dictionary, player: FixturePlayer) -> void:
	player.position = Vector2(220, 490)
	player.hp = 20
	player.damage_events.clear()
	var enemy := add_enemy(stage, profiles, "gear_sentinel", Vector2(100, 490), 220, "guard")
	# Give this fixture a real authored movement bound before the wall, since
	# EnemyActor patrol uses platform bounds rather than body collision. The
	# sight ray still crosses the live solid wall independently of that bound.
	enemy.set_platform_movement_bounds(35.0, 145.0)
	var wall := _make_wall(stage, 160)
	await frames(100)
	if enemy.engage_announced or not player.damage_events.is_empty():
		print("Encounter guard fixture: engage=%s state=%s attack=%s position=%s decision=%s player_hp=%d" % [enemy.engage_announced, enemy.state, enemy.last_attack_id, enemy.global_position, enemy.last_ai_decision, player.hp])
	check(not enemy.engage_announced and player.damage_events.is_empty(), "guard holds its readable pocket and does not attack a rest target through a solid wall")
	wall.queue_free()
	enemy.set_platform_movement_bounds(35.0, 400.0)
	enemy.direction = 1
	await frames(2)
	var before := player.damage_events.size()
	var hit := await wait_for_hit(player, before, 220)
	check(hit, "guard naturally re-engages when line of sight returns and deals normal damage")
	check(player.hp < 20 and player.damage_events.size() > before, "guard attack reduces ordinary player HP")
	check(enemy.last_attack_id in ["gear_guard", "gear_spear"], "guard uses its authored guard/spear attack selection")
	enemy.queue_free()
	await frames(3)

func ranged_spacing(stage: Node2D, profiles: Dictionary, player: FixturePlayer) -> void:
	player.position = Vector2(830, 490)
	player.hp = 20
	player.damage_events.clear()
	var enemy := add_enemy(stage, profiles, "pipe_thrower", Vector2(700, 490), 220, "ranged")
	var before := player.damage_events.size()
	var hit := await wait_for_hit(player, before, 330)
	check(hit, "stationary ranged role naturally selects an authored projectile/beam and deals normal damage")
	check(player.hp < 20 and not enemy.last_attack_id.is_empty(), "ranged attack result is a real player HP loss")
	enemy.queue_free()
	await frames(3)
	# A mobile ranged profile uses its authored preferred_range under pressure,
	# while close-range guards/ambushers keep their forward commitment.
	player.position = Vector2(2540, 490)
	var spacer := add_enemy(stage, profiles, "bronze_moth", Vector2(2500, 395), 180, "mobile_ranged")
	spacer.attack_desire = 1.5
	for command in spacer.ai_commands:
		spacer.cooldowns[String(command.get("id", "attack"))] = 20.0
	var start_x: float = spacer.global_position.x
	await frames(24)
	check(spacer.global_position.x < start_x - 12.0, "mobile ranged profile maintains authored preferred_range even at high attack pressure")
	var spawn_y: float = spacer.spawn_position.y
	player.position = Vector2(spacer.spawn_position.x + 110.0, 820.0)
	await frames(40)
	check(absf(spacer.global_position.y - spawn_y) < 24.0, "off-leash target outside the vertical aggro window cannot pull a flyer out of its home pocket")
	spacer.queue_free()
	await frames(3)
	# A boss flyer keeps the previous target-height rule even when the target is
	# outside the ordinary enemy aggro window. Its no-attack profile also lets
	# this fixture check the original pressured spacing decision directly.
	player.gravity = 0.0
	player.position = Vector2(3100, 820)
	var boss_profile: Dictionary = profiles.get("bronze_moth", {}).duplicate(true)
	boss_profile["attacks"] = []
	boss_profile["tactical_ai"] = false
	var boss: Area2D = ENEMY.new()
	boss.configure({"id": "boss_flyer_parity", "kind": "bronze_moth", "hp": 20, "damage": 2, "patrol": 35, "leash_radius": 180}, "", true, boss_profile)
	boss.position = Vector2(2800, 395)
	stage.add_child(boss)
	boss.monitoring = false
	await frames(40)
	check(boss.global_position.y > boss.spawn_position.y + 20.0, "boss flyer retains target-height tracking outside the ordinary aggro window")
	player.position = Vector2(boss.global_position.x + 50.0, boss.global_position.y)
	boss.attack_desire = 1.5
	var boss_x: float = boss.global_position.x
	boss._move_in_combat(0.25, player)
	check(boss.last_ai_decision == "threaten" and is_equal_approx(boss.global_position.x, boss_x), "boss pressured close-range movement retains its prior no-retreat decision")
	boss.queue_free()
	player.gravity = 1800.0
	await frames(3)

func ambush_cancel_return_reentry(stage: Node2D, profiles: Dictionary, player: FixturePlayer) -> void:
	player.position = Vector2(1600, 490)
	player.hp = 20
	player.damage_events.clear()
	var profile: Dictionary = profiles.get("root_cage_hunter", {}).duplicate(true)
	# Isolate the authored net attack so the effect-lifetime assertion samples a
	# projectile launched by natural attack selection, without changing its data.
	profile.attacks = [profile.attacks[0].duplicate(true)]
	var enemy := add_enemy(stage, profiles, "root_cage_hunter", Vector2(1400, 490), 180, "ambush", {"attacks": profile.attacks})
	enemy.attack_desire = 1.5
	var launched: Node2D = null
	var target_moved_after_windup := false
	for unused in 180:
		await frames()
		if not target_moved_after_windup and enemy.state == "windup" and enemy.last_attack_id == "cage_net":
			# Attack target is snapshotted at windup; move the live target aside
			# before the projectile emerges so the projectile remains observable.
			player.position = Vector2(1150, 490)
			target_moved_after_windup = true
		if enemy.state == "active" and not enemy.owned_attack_effects.is_empty():
			for effect in enemy.owned_attack_effects:
				if is_instance_valid(effect) and not effect.is_queued_for_deletion() and effect.effect_kind == "projectile":
					launched = effect
					break
		if launched != null:
			break
	check(launched != null, "ambush role naturally launches its authored net projectile")
	if launched == null:
		print("Encounter ambush fixture: state=%s attack=%s position=%s decision=%s cooldowns=%s effects=%d desire=%.2f target=%s" % [enemy.state, enemy.last_attack_id, enemy.global_position, enemy.last_ai_decision, enemy.cooldowns, enemy.owned_attack_effects.size(), enemy.attack_desire, player.global_position])
		enemy.queue_free()
		await frames(3)
		return
	var delayed_warning: Node2D = enemy._effect("pool", enemy.global_position, Vector2.ZERO, {"radius": 11, "damage": 1}, 0.9, 0.7)
	check(delayed_warning != null and float(delayed_warning.get("age")) < float(delayed_warning.get("arm_delay")), "interruption fixture includes a visible effect that has not reached its arm delay")
	# Leave the projectile's flight path, exceed leash, and interrupt the attacker.
	player.position = Vector2(1150, 490)
	enemy.take_hit(1, -1)
	check(is_instance_valid(launched) and not launched.cancelled and not launched.is_queued_for_deletion(), "interrupting an attack preserves its already-launched valid projectile")
	check(is_instance_valid(delayed_warning) and delayed_warning.cancelled and delayed_warning.is_queued_for_deletion(), "interrupting an attack cancels a visible delay-warning effect before it arms")
	await frames(100)
	check(enemy.last_ai_decision == "return" or absf(enemy.global_position.x - enemy.spawn_position.x) < 14.0, "ambush returns to its authored home when the target leaves its leash")
	check(is_instance_valid(launched) and not launched.cancelled, "return-home does not cancel an already-launched effect")
	# Let that effect expire before testing a fresh natural attack after re-entry.
	await frames(130)
	player.position = Vector2(1550, 490)
	var before := player.damage_events.size()
	var reattacked := false
	for unused in 240:
		await frames()
		if enemy.state == "windup" and enemy.last_attack_id == "cage_net":
			reattacked = true
		if player.damage_events.size() > before:
			break
	if not reattacked:
		print("Encounter reentry fixture: state=%s attack=%s active=%s position=%s spawn=%s decision=%s cooldowns=%s desire=%.2f target=%s enemy_hp=%d" % [enemy.state, enemy.last_attack_id, enemy.active_attack, enemy.global_position, enemy.spawn_position, enemy.last_ai_decision, enemy.cooldowns, enemy.attack_desire, player.global_position, enemy.hp])
	check(reattacked, "ambush role naturally selects a fresh attack after the player re-enters its territory")
	check(player.damage_events.size() > before and player.hp < 20, "re-engaged ambush applies ordinary damage")
	enemy.queue_free()
	await frames(3)

func finish() -> void:
	for failure in failures:
		push_error(failure)
	print("ENEMY_ENCOUNTER_ROLES checks=%d failures=%d fixture_scope=authored_profiles_and_positions_live_physics_ai_attacks_damage" % [checks, failures.size()])
	call_deferred("quit", 1 if not failures.is_empty() else 0)
