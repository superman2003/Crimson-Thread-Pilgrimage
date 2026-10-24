extends SceneTree

var checks := 0
var failures := 0

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const ENEMY_SCRIPT := preload("res://scripts/enemy_actor.gd")


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)


func _frames(count: int) -> void:
	for _index in count:
		await physics_frame


func _run() -> void:
	var floor := _static_box(Vector2(300, 202), Vector2(1000, 44), 17)
	root.add_child(floor)
	var player := PLAYER_SCENE.instantiate()
	root.add_child(player)
	player.global_position = Vector2(100, 180)
	player.velocity = Vector2.ZERO
	await _frames(4)
	# Keep gameplay physics and input live while suppressing only cinematic
	# hitstop; it changes Engine.time_scale and makes fixed-frame input probes
	# depend on presentation feedback timing.
	player.feel = null
	_check(player.is_on_floor(), "player reaches the real static terrain floor")
	_check(player.collision_mask & 1 == 1, "player body collides with terrain bit one")

	# This confirms the production attack ray sees terrain, while the enemy hurtbox
	# remains an Area2D actor and is excluded from the terrain-only ray query.
	var blocked := _spawn_enemy(Vector2(162, 140), 3)
	var wall := _static_box(Vector2(133, 125), Vector2(12, 150), 17)
	root.add_child(wall)
	await _frames(2)
	_check(not player._attack_line_clear(blocked.get_hurtbox_rect().get_center()), "solid wall blocks player melee ray to an enemy behind it")
	_check(player._attack_line_clear(Vector2(120, 138)), "clear front-side target has a terrain-clear ray")
	await _input_attack(player, Vector2(100, 180), 1, false)
	_check(blocked.hp == 3, "real buffered attack input cannot hit an enemy behind static terrain")
	wall.queue_free()
	await _frames(2)
	_check(player._attack_line_clear(blocked.get_hurtbox_rect().get_center()), "enemy Area2D collision layer does not block the terrain-only ray")
	blocked.queue_free()
	await _frames(2)

	# One swing may hit multiple accepted enemies. Each target keeps its authored
	# per-hit reward, but the pogo impulse and feedback happen once for the swing.
	player.energy = 0
	var first := _spawn_enemy(Vector2(155, 140), 4)
	var second := _spawn_enemy(Vector2(190, 140), 4)
	await _input_attack(player, Vector2(100, 180), 1, false)
	_check(first.hp < 4 and second.hp < 4, "real attack input hits both enemies inside the active arc")
	_check(player.energy == player.energy_per_hit * 2, "separate accepted targets each retain one per-target energy reward")
	first.queue_free()
	second.queue_free()
	await _frames(2)

	# A guarding front-facing actor rejects the hit without spending the attack's
	# resource reward or producing an air-pogo bounce.
	player.energy = 0
	player.global_position = Vector2(100, 95)
	player.velocity = Vector2(0, 220)
	player.thorn_downstrike_unlocked = true
	var guard := _spawn_enemy(Vector2(145, 145), 4)
	guard.ai_profile["front_guard"] = true
	guard.active_attack = {"type": "guard"}
	guard.state = "active"
	guard.direction = -1
	await _input_attack(player, player.global_position, 1, true)
	_check(player.current_attack_direction.y > 0.5, "real aim-down input is captured for the guarded attack")
	_check(guard.hp == 4, "front guard rejects the real downstrike hit")
	_check(player.energy == 0, "rejected guarded hit grants no energy")
	_check(player.velocity.y > 0.0, "rejected guarded hit does not pogo the player")
	guard.queue_free()
	await _frames(2)

	# Accepted downstrike hit on a real airborne enemy retains the bounce.
	player.global_position = Vector2(100, 95)
	player.velocity = Vector2(0, 220)
	player.pogo_chain = 0
	var air_target := _spawn_enemy(Vector2(145, 145), 4)
	await _input_attack(player, player.global_position, 1, true)
	_check(player.current_attack_direction.y > 0.5, "real aim-down input is captured for airborne pogo")
	_check(air_target.hp < 4, "real downslash input and physics hit the airborne enemy")
	_check(player.velocity.y < 0.0, "accepted airborne enemy hit produces downward pogo recovery")
	_check(player.pogo_chain == 1, "one accepted target advances the pogo chain once")
	air_target.queue_free()
	await _frames(2)

	await _recovery_cancel(player)

	# Each crest shares the same heal reservation behavior: movement interrupts
	# the channel, no healing is applied, and the authored interruption loss is
	# charged against the prepaid reservation.
	for crest in ["crimson", "bell", "salt"]:
		player._reset_traversal_state()
		player.apply_build_stats({"crest_id": crest, "heal_interrupt_loss_ratio": 1.0})
		player.global_position = Vector2(100, 180)
		player.velocity = Vector2.ZERO
		player.hurt_timer = 0.0
		player.death_timer = 0.0
		player.hp = 3
		player.energy = 100
		await _frames(2)
		_check(player.is_on_floor(), crest + " heal test starts grounded")
		_check(player._try_heal(), crest + " crest starts a paid heal")
		_check(player.energy == 100 - player.heal_energy_cost and player.heal_reserved_cost == player.heal_energy_cost, crest + " heal reserves the authored energy cost")
		Input.action_press("move_right")
		await _frames(1)
		Input.action_release("move_right")
		_check(player.heal_timer == 0.0 and player.heal_reserved_cost == 0, crest + " movement input interrupts and clears heal reservation")
		_check(player.hp == 3 and player.energy == 100 - player.heal_energy_cost, crest + " interrupted heal grants no HP and retains authored interruption charge")
		# Allow the production 0.3s post-interrupt cooldown to expire naturally
		# before starting the next crest's independent reservation.
		await _frames(20)

	if failures > 0:
		quit(1)
		return
	print("MELEE_RECOVERY_VALIDATION_PASS checks=%d terrain_occlusion=true accepted_hit_rewards=true rejected_hit_pogo=false heal_interrupts=3" % checks)
	quit(0)


func _until(condition: Callable, limit: int = 40) -> bool:
	for _index in limit:
		if condition.call():
			return true
		await _frames(1)
	return condition.call()


## Held for two physics ticks, like the other movement probes: a press made
## from a resumed coroutine is observed by the player on the following tick.
func _tap(action: String) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


## C01 cancel cost: wind-up and active frames commit the swing; only its
## recovery yields to jump or dash, and the cut recovery is still owed before
## the next strike, so cancelling never swings faster than standing still.
func _recovery_cancel(player: CharacterBody2D) -> void:
	player._reset_traversal_state()
	player.global_position = Vector2(100, 180)
	player.velocity = Vector2.ZERO
	player.dash_unlocked = true
	player.energy = 100
	player.skill_cooldown = 0.0
	await _frames(4)
	_check(player.is_on_floor(), "cancel probe starts grounded")
	var in_active := func() -> bool:
		var elapsed: float = player.attack_duration - player.attack_timer
		return player.attack_timer > 0.0 and elapsed >= player.attack_windup and elapsed <= player.attack_windup + player.attack_active_time * 0.5
	var in_recovery := func() -> bool:
		return player.attack_timer > 0.0 and player._attack_recovery_cancelable()
	var tick := 1.0 / float(Engine.physics_ticks_per_second)

	Input.action_press("attack")
	var started := await _until(func() -> bool: return player.attack_timer > 0.0, 4)
	Input.action_release("attack")
	var start_frame := Engine.get_physics_frames()
	_check(started and player.current_attack == &"attack_1", "cancel probe swing starts from real input")
	_check(await _until(in_active), "cancel probe reaches the active frames")
	await _tap("jump")
	_check(player.jump_buffer_timer > 0.0, "the active-frame jump press was observed")
	_check(player.attack_timer > 0.0 and player.velocity.y >= 0.0 and player.recovery_cancel_count == 0, "a jump during the active frames does not cut the committed swing")
	# Drop that early press so the recovery press below is measured alone.
	player.jump_buffer_timer = 0.0
	_check(await _until(in_recovery), "cancel probe reaches the recovery")
	_check(player.is_on_floor() and player.velocity.y >= 0.0, "the swing is still grounded when its recovery opens")
	var recovery_left: float = player.attack_timer
	await _tap("jump")
	_check(player.attack_timer == 0.0 and player.velocity.y < 0.0 and player.recovery_cancel_count == 1, "a jump in the recovery cuts the swing and leaves the ground")
	_check(player.attack_cancel_lock > 0.0 and player.attack_cancel_lock <= recovery_left, "the cut recovery is owed as a strike lock")
	await _tap("attack")
	_check(player.attack_timer == 0.0 and player.buffered_action == &"attack", "a swing pressed while the recovery is owed waits instead of starting")
	_check(not player.cast_selected_skill() and String(player.get_cast_readiness("thread_burst").get("text", "")) == "收势", "thread arts also wait out the owed recovery")
	_check(await _until(func() -> bool: return player.attack_timer > 0.0, 12), "the buffered swing starts once the owed recovery is paid")
	var cadence := float(Engine.get_physics_frames() - start_frame) * tick
	_check(cadence >= player.attack_duration - tick * 1.5, "jump-cancelling never swings faster than the uncancelled cadence (%.3fs >= %.3fs)" % [cadence, player.attack_duration])

	await _until(func() -> bool: return player.attack_timer <= 0.0 and player.is_on_floor(), 90)
	# A heavier swing can owe more than the 0.10s input buffer; the press still lands.
	player.attack_cancel_lock = 0.2
	await _tap("attack")
	_check(player.attack_timer == 0.0, "a swing pressed under a long owed recovery waits")
	_check(await _until(func() -> bool: return player.attack_timer > 0.0, 20) and player.attack_cancel_lock == 0.0, "a press under an owed recovery longer than the input buffer is kept until it is paid")
	await _until(func() -> bool: return player.attack_timer <= 0.0 and player.is_on_floor(), 90)
	player._reset_traversal_state()
	await _frames(2)
	Input.action_press("attack")
	await _until(func() -> bool: return player.attack_timer > 0.0, 4)
	Input.action_release("attack")
	await _until(in_active)
	await _tap("dash")
	_check(player.buffered_action == &"dash", "the active-frame dash press was observed")
	_check(player.dash_timer == 0.0 and player.attack_timer > 0.0, "a dash during the active frames does not cut the committed swing")
	player._clear_action_buffer()
	await _until(in_recovery)
	var start_x: float = player.global_position.x
	await _tap("dash")
	_check(player.dash_timer > 0.0 and player.attack_timer == 0.0 and player.recovery_cancel_count == 2, "a dash in the recovery cuts the swing")
	await _frames(3)
	_check(player.global_position.x > start_x + 20.0, "the cancelling dash actually moves the player")

	await _until(func() -> bool: return player.dash_timer <= 0.0 and player.is_on_floor(), 90)
	player._reset_traversal_state()
	await _frames(2)
	player._start_attack(&"hook_throw")
	await _until(func() -> bool: return player.attack_duration - player.attack_timer > player.attack_windup + player.attack_active_time and player.attack_timer > 0.0)
	await _tap("jump")
	_check(player.jump_buffer_timer > 0.0 and player.attack_timer > 0.0 and player.velocity.y >= 0.0 and player.recovery_cancel_count == 2, "a hook throw keeps its full recovery")
	await _until(func() -> bool: return player.attack_timer <= 0.0 and player.is_on_floor(), 90)
	player._reset_traversal_state()
	_check(player.attack_cancel_lock == 0.0, "traversal reset clears an owed recovery")
	await _frames(2)


func _input_attack(player: CharacterBody2D, start: Vector2, face: int, down: bool) -> void:
	player.global_position = start
	player.velocity = Vector2.ZERO if not down else Vector2(0, 220)
	player.facing = face
	player.hurt_timer = 0.0
	player.death_timer = 0.0
	player.attack_timer = 0.0
	player.active_skill.clear()
	player.enemy_contact_guard_timer = 0.0
	if down:
		Input.action_press("aim_down")
		# Ensure the player has observed the held aim input before sampling attack.
		await _frames(1)
	Input.action_press("attack")
	var attack_started := false
	# `physics_frame` resumes this SceneTree after the corresponding player
	# physics callback. Keep attack and aim held until that callback actually
	# consumes the real InputMap action; releasing on the first signal can race
	# ahead of `_physics_process` and leave the attack unstarted.
	for _attempt in 4:
		await _frames(1)
		if player.attack_timer > 0.0:
			attack_started = true
			break
	_check(attack_started, "real InputMap attack press starts player attack")
	Input.action_release("attack")
	if down:
		Input.action_release("aim_down")
		# Active-frame hit acceptance and bounce occur by the third frame. End
		# here so the rejected-hit probe observes downward velocity before the
		# player later lands and physics correctly zeros it.
		await _frames(3)
	else:
		await _frames(18)


func _spawn_enemy(position_value: Vector2, health: int) -> Area2D:
	var enemy := Area2D.new()
	enemy.set_script(ENEMY_SCRIPT)
	enemy.global_position = position_value
	enemy.configure({"id": "test", "kind": "moss_larva", "hp": health, "damage": 1, "patrol": 0}, "", false, {})
	root.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy


func _static_box(position_value: Vector2, size: Vector2, layer: int) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = position_value
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	body.add_child(shape)
	return body
