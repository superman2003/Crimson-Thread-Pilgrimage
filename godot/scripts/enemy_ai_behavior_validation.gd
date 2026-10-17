extends SceneTree
## Regular-enemy decisions: situational attack choice, non-banned repeats,
## seeded determinism, turn-taking, release lead, poise/backstep, awareness,
## patrol pauses and last-seen investigation. Fixture target, no Player scene.
const ENEMY := preload("res://scripts/enemy_actor.gd")
var checks := 0
var failures := 0
var stage: Node2D
var target: CharacterBody2D

func _initialize() -> void:
    call_deferred("run")

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(label)

func spawn(kind: String, id: String, x: float, elite := false) -> Area2D:
    var enemy: Area2D = ENEMY.new()
    var data := {"id": id, "kind": kind, "hp": 6, "damage": 1, "patrol": 80.0}
    if elite:
        data["elite"] = true
    enemy.configure(data, "")
    enemy.position = Vector2(x, 300)
    stage.add_child(enemy)
    enemy.set_physics_process(false)
    return enemy

func command(enemy: Area2D, attack_id: String) -> Dictionary:
    for item in enemy.ai_commands:
        if String(item.id) == attack_id:
            return item
    return {}

func run() -> void:
    stage = Node2D.new()
    root.add_child(stage)
    target = CharacterBody2D.new()
    target.add_to_group("player")
    target.position = Vector2(400, 300)
    stage.add_child(target)
    await process_frame

    # Situational scoring.
    var moth := spawn("bronze_moth", "ai_moth", 300)
    var dive := command(moth, "moth_dive")
    var dust := command(moth, "moth_dust")
    moth.last_player_command = "jump"
    target.position = Vector2(420, 180)
    check(moth._attack_candidate_score(dust, target) > moth._attack_candidate_score(dive, target), "airborne player draws the anti-air fan")
    target.position = Vector2(400, 300)
    var larva := spawn("moss_larva", "ai_larva", 330)
    larva.last_player_command = "heal"
    check(larva._attack_candidate_score(command(larva, "larva_curl"), target) > larva._attack_candidate_score(command(larva, "larva_snap"), target), "healing player is punished by the lunge")
    var spearman := spawn("obsidian_spearman", "ai_spear", 300)
    check(spearman._attack_has_role(command(spearman, "obsidian_raise"), "anti_air"), "anti-air melee recognised from its mechanic")

    # Weighted choice: varied, never banned, seeded per spawn.
    var acolyte := spawn("bellroot_acolyte", "ai_acolyte", 330)
    acolyte.last_player_command = "idle"
    var pool: Array = acolyte.ai_commands.duplicate()
    var tally := {}
    var longest := 0
    var streak := 0
    var previous := ""
    for index in 300:
        var picked: Dictionary = acolyte._choose_attack(pool, target)
        var id := String(picked.id)
        tally[id] = int(tally.get(id, 0)) + 1
        acolyte.attack_repeat_count = acolyte.attack_repeat_count + 1 if id == acolyte.last_attack_id else 0
        acolyte.last_attack_id = id
        streak = streak + 1 if id == previous else 1
        longest = maxi(longest, streak)
        previous = id
    check(tally.size() == 2 and int(tally.values().min()) >= 60, "both attacks appear in a long fight: %s" % [tally])
    check(longest <= 4, "repeat penalty keeps streaks short (longest %d)" % longest)
    var twin_a := spawn("bellroot_acolyte", "ai_twin", 330)
    var twin_b := spawn("bellroot_acolyte", "ai_twin", 330)
    var same := true
    for index in 40:
        same = same and String(twin_a._choose_attack(pool, target).id) == String(twin_b._choose_attack(pool, target).id)
    check(same, "same spawn id makes the same choices (prebuilt and live stay in step)")

    # Turn-taking: two others mid-attack near the player.
    var busy_a := spawn("gear_sentinel", "ai_busy_a", 340)
    var busy_b := spawn("gear_sentinel", "ai_busy_b", 460)
    busy_a.state = "windup"
    busy_b.state = "active"
    var third := spawn("gear_sentinel", "ai_third", 350)
    third.attack_desire = 5.0
    check(not third._try_start_attack(target) and third.waiting_for_turn and third.last_ai_decision == "wait_turn", "third attacker waits for a turn")
    var elite := spawn("gear_sentinel", "ai_elite", 350, true)
    elite.attack_desire = 5.0
    check(elite._try_start_attack(target) and elite.state == "windup", "elite does not wait in line")
    busy_b.state = "patrol"
    elite.state = "patrol"
    check(third._try_start_attack(target) and not third.waiting_for_turn, "attacker slot frees for the next enemy")
    for node in [busy_a, busy_b, third, elite]:
        node.queue_free()
    await process_frame

    # Wind-up lead: aimed shot anticipates a running player, capped, then commits.
    var mote := spawn("bell_mote", "ai_mote", 150)
    target.position = Vector2(400, 300)
    target.velocity = Vector2(285, 0)
    mote.attack_target = target.global_position
    mote._aim_attack(command(mote, "mote_seek"), target)
    var lead: float = mote.attack_target.x - target.global_position.x
    check(lead > 20.0 and lead <= 140.0, "projectile leads a running player within the cap (%.1f px)" % lead)
    target.velocity = Vector2.ZERO
    mote._aim_attack(command(mote, "mote_seek"), target)
    check(is_equal_approx(mote.attack_target.x, target.global_position.x), "standing player is aimed at directly")
    var pooled := spawn("bellroot_acolyte", "ai_pool_aim", 300)
    pooled.attack_target = Vector2(10, 10)
    pooled._aim_attack(command(pooled, "root_bell_wave"), target)
    check(pooled.attack_target == Vector2(10, 10), "area attacks keep the spot they telegraph")
    mote.active_attack = command(mote, "mote_seek")
    mote.state = "windup"
    mote.state_timer = 0.01
    var committed: Vector2 = mote.attack_target
    target.position = Vector2(900, 300)
    mote._update_windup(0.02)
    check(mote.attack_target == committed, "release keeps the wind-up aim (dodging during the wind-up works)")
    target.position = Vector2(400, 300)

    # Poise and backstep.
    var fighter := spawn("moss_larva", "ai_fighter", 380)
    target.position = Vector2(440, 300)
    fighter.take_hit(1, 1)
    check(fighter.state == "recover", "first hit interrupts an ordinary enemy")
    fighter.take_hit(1, 1)
    check(absf(fighter.knockback_velocity) >= 559.0 and fighter.backstep_cooldown > 0.0, "second quick hit makes a close fighter hop clear")
    fighter.take_hit(1, 1)
    check(fighter.poise_timer > 0.0 and fighter.attack_desire >= fighter._attack_desire_threshold(), "chained hits grant poise and a retaliation")
    fighter.state = "windup"
    fighter.state_timer = 0.5
    fighter.take_hit(1, 1)
    check(fighter.state == "windup", "poised wind-up is not interrupted")
    var armored := spawn("page_duelist", "ai_armored", 380, true)
    armored.state = "active"
    armored.active_attack = command(armored, "page_elite_flurry")
    armored.take_hit(1, 1)
    check(armored.state == "active", "elite keeps its strike once begun")

    # Awareness-gated facing.
    var watcher := spawn("gear_sentinel", "ai_watch", 300)
    watcher.direction = -1
    target.position = Vector2(1400, 300)
    check(not watcher._is_aware_of(target), "distant player is not noticed")
    target.position = Vector2(420, 300)
    check(watcher._is_aware_of(target), "nearby player is noticed")

    # Patrol: pause at the turn, then reverse.
    var walker := spawn("moss_larva", "ai_walker", 300)
    target.position = Vector2(5000, 300)
    walker.position.x = walker.start_x + 81.0
    walker.patrol_direction = 1
    walker._patrol(0.016)
    check(walker.patrol_direction == -1 and walker.patrol_pause_timer > 0.0, "patrol turns with a pause")
    var paused_x: float = walker.position.x
    walker._patrol(0.016)
    check(is_equal_approx(walker.position.x, paused_x), "patrol stands still while pausing")

    var guard: Area2D = ENEMY.new()
    guard.configure({"id": "ai_guard", "kind": "obsidian_bellwheel", "hp": 4, "patrol": 80.0, "leash_radius": 55.0}, "")
    guard.position = Vector2(300, 300)
    stage.add_child(guard)
    guard.set_physics_process(false)
    var post: float = guard.position.x
    for tick in 120:
        guard._patrol(0.016)
    check(is_equal_approx(guard.position.x, post), "tight-leash guard holds its post instead of pacing")

    # Investigation of the last seen position.
    var hunter := spawn("moss_larva", "ai_hunter", 300)
    hunter.last_seen_position = Vector2(360, 300)
    hunter.memory_timer = 2.0
    var before: float = hunter.position.x
    hunter._update_patrol_or_aggro(0.1, null)
    check(hunter.last_ai_decision == "investigate" and hunter.position.x > before, "lost target is searched for at its last seen spot")
    hunter.memory_timer = 0.0
    hunter._update_patrol_or_aggro(0.1, null)
    check(hunter.last_ai_decision == "patrol", "search gives up after the memory window")

    print("ENEMY_AI_BEHAVIOR checks=%d failures=%d" % [checks, failures])
    quit(0 if failures == 0 else 1)
