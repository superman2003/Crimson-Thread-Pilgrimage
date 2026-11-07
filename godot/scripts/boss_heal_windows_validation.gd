extends "res://scripts/boss_move_matrix_validation.gd"
## C02 with damage on: each seal's heal fits the real recovery windows of every
## Boss in both phases. The production Boss runs its own AI against the real
## Player standing at the arena front. The Player starts a heal whenever the
## Boss is not mid-strike and no attack of its own is within 300px. A heal
## counts as completed only when HP actually rises; a hit during the channel
## interrupts it under the seal's own rule, which is checked on every live
## interruption (energy kept and reservation cleared). Each phase and seal must
## complete at least one heal, and each seal at least half of its attempts. The
## first half covers the court, canal and archive arenas.
const BUILD := preload("res://scripts/build_system.gd")
const SEALS := ["crimson", "bell", "salt"]
const SECONDS := 30
const STAND := 260.0
const THREAT_RADIUS := 300.0
const MIN_RATE := 0.5
var totals := {}


func _marker() -> String:
    return "BOSS_HEAL_WINDOWS"


func _run() -> void:
    for seal in SEALS:
        totals[seal] = {"started": 0, "completed": 0, "interrupted": 0}
    for path: String in _chapters():
        var entry: Dictionary = await _heal_chapter(path)
        if not entry.is_empty():
            report.append(entry)
    for seal in SEALS:
        var row: Dictionary = totals[seal]
        var rate := float(row.completed) / maxf(1.0, float(row.started))
        _check(rate >= MIN_RATE, "%s heals complete in %d/%d live windows (%.0f%%)" % [seal, row.completed, row.started, rate * 100.0])
    var interrupted_total := 0
    for seal in SEALS:
        interrupted_total += int(totals[seal].interrupted)
    # Each live interruption is settled against the seal's rule above; at least
    # one must happen so that check is not vacuous (seal_identity covers each
    # seal's rule directly).
    _check(interrupted_total >= 1, "live hits interrupt heals (%d), so the settlement check ran" % interrupted_total)
    await _frames(10)
    _check(await RETIRE.drain(self, 3000), "chapter audio is released before exit")
    var director := preload("res://scripts/audio_director.gd")
    director._stream_cache.clear()
    director._npc_voice_cache.clear()
    await _frames(2)
    print(_marker() + "_REPORT " + JSON.stringify({"bosses": report, "totals": totals}))
    if failures > 0:
        print("%s_FAIL failures=%d checks=%d" % [_marker(), failures, checks])
        call_deferred("quit", 1)
        return
    print("%s_PASS bosses=%d checks=%d" % [_marker(), report.size(), checks])
    call_deferred("quit", 0)


func _heal_chapter(path: String) -> Dictionary:
    var scene: Node = MAIN_SCENE.instantiate()
    scene.set("config_path", path)
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    await _frames(3)
    for enemy in get_nodes_in_group("enemy"):
        if not bool(enemy.get("is_boss")):
            enemy._cancel_attack_effects()
            enemy.queue_free()
    for node in scene.find_children("*", "Control", true, false):
        if node.get_script() != null and node.get_script().resource_path.ends_with("pilgrimage_interface.gd"):
            node.set_process(false)
    scene.boss_unlocked = true
    scene._spawn_boss()
    scene._set_boss_arena_locked(true)
    await _frames(4)
    var boss: Node2D = scene.boss_actor
    var player: CharacterBody2D = scene.player
    _check(is_instance_valid(boss) and boss.is_boss, path + " spawns its production Boss")
    if not is_instance_valid(boss):
        RETIRE.retire_tree(scene)
        scene.queue_free()
        await _frames(2)
        return {}
    player.debug_invulnerable = false
    var home: Vector2 = boss.global_position
    var checkpoint: Vector2 = scene._vec2(scene.config.get("boss_checkpoint", home + Vector2(-520, 0)))
    var front := -1 if checkpoint.x < home.x else 1
    var build := BUILD.new()
    build.state.unlocked_crests = build.catalog.crests.keys()
    build.state.mechanisms = SEALS.duplicate()
    player.build_system = build
    var commands: Array = boss.ai_profile.get("attacks", []).duplicate(true)
    var rows: Array = []
    for phase in [1, 2]:
        for seal in SEALS:
            build.state.crest = seal
            build._normalize_active_slots()
            player.apply_build_stats(build.profile())
            var row: Dictionary = await _live_heals(boss, player, commands, home, front, phase)
            row["seal"] = seal
            row["phase"] = phase
            rows.append(row)
            totals[seal].started += row.started
            totals[seal].completed += row.completed
            totals[seal].interrupted += row.interrupted
            _check(row.completed >= 1, "%s phase %d: %s completes a heal in a live window (%d/%d)" % [boss.kind, phase, seal, row.completed, row.started])
            _check(row.wrong_amount == 0, "%s phase %d: %s completed heals restore exactly the seal's amount" % [boss.kind, phase, seal])
            _check(row.wrong_settlement == 0, "%s phase %d: %s live interruptions keep exactly the seal's loss and clear the reservation (%d wrong)" % [boss.kind, phase, seal, row.wrong_settlement])
    var entry := {"kind": String(boss.kind), "chapter": path.get_file(), "rows": rows}
    RETIRE.retire_tree(scene)
    scene.queue_free()
    await _frames(3)
    return entry


## Live AI for SECONDS. The Player's health is held above lethal outside a
## channel so one run measures windows, not a defeat; knockback drift is undone
## when the Boss starts its next windup so the stand stays at the arena front.
func _live_heals(boss: Node2D, player: CharacterBody2D, commands: Array, home: Vector2, front: int, phase: int) -> Dictionary:
    _end_hitstop()
    _release_inputs()
    _reset_boss(boss, home, {"phase": phase})
    if phase == 2:
        boss.hp = int(boss.max_hp * 0.4)
    boss.ai_commands = commands.duplicate(true)
    var stand := Vector2(home.x + front * STAND, home.y - 30.0)
    player.restore_at_save_point()
    player.max_hp = 20
    player.hp = 12
    player.global_position = stand
    player.velocity = Vector2.ZERO
    for frame in 20:
        boss.global_position = home
        await physics_frame
    var started := 0
    var completed := 0
    var interrupted := 0
    var wrong_amount := 0
    var channel_hp := -1
    var rest_until := 0
    var channel_cost := 0
    var channel_ratio := 0.0
    var wrong_settlement := 0
    for frame in SECONDS * 60:
        _end_hitstop()
        boss.contact_timer = 999.0
        if player.heal_timer <= 0.0 and player.hp < 8:
            player.hp = 12
        # Undo knockback drift only while the Boss is between moves, before its
        # next windup snapshots the target, so its aim follows the real stand.
        if not boss.state in ["windup", "active"] and player.heal_timer <= 0.0 and player.hurt_timer <= 0.0 and absf(player.global_position.x - stand.x) > 24.0:
            player.global_position = stand
            player.velocity = Vector2.ZERO
            # Let the Player land first: a grounded heal started mid-drop would
            # end on the fall, not on the Boss.
            rest_until = maxi(rest_until, frame + 12)
        var time_left := SECONDS * 60 - frame
        # Hit recovery and the heal cooldown keep their production timing.
        if boss.state != "active" and frame >= rest_until and time_left > int(ceil(player.heal_duration * 60.0)) + 2 and player.heal_timer <= 0.0 and player.is_on_floor() and _threats_near(boss, player) == 0:
            player.energy = player.max_energy
            player.hp = mini(player.hp, player.max_hp - 3)
            if player._try_heal():
                started += 1
                channel_hp = player.hp
                channel_cost = player.heal_reserved_cost
                channel_ratio = player.heal_reserved_loss_ratio
        await physics_frame
        physics_frames += 1
        if channel_hp >= 0 and player.heal_timer <= 0.0:
            if player.hp > channel_hp:
                completed += 1
                # A hit landing on the completing frame is a fair race: the
                # amount is only checked when no hit arrived with it.
                if player.hp != channel_hp + player.heal_amount and player.hurt_timer <= 0.0:
                    wrong_amount += 1
            elif player.hp < channel_hp:
                interrupted += 1
                # The seal's own rule: the hit keeps cost * loss ratio, refunds
                # the rest and clears the reservation.
                var loss := int(ceil(channel_cost * channel_ratio))
                var expected := mini(player.max_energy, player.max_energy - loss + player.energy_on_damage)
                if player.energy != expected or player.heal_reserved_cost != 0:
                    wrong_settlement += 1
            channel_hp = -1
            rest_until = frame + 30
    # A channel still running when time is up was neither completed nor broken.
    if channel_hp >= 0:
        started -= 1
    _release_inputs()
    _reset_boss(boss, home, {"phase": phase})
    boss.ai_commands = []
    return {"started": started, "completed": completed, "interrupted": interrupted, "wrong_amount": wrong_amount, "wrong_settlement": wrong_settlement, "heal_duration": player.heal_duration}


func _threats_near(boss: Node2D, player: Node2D) -> int:
    var count := 0
    var center := player.global_position - Vector2(0, 42)
    for effect in boss.owned_attack_effects:
        if is_instance_valid(effect) and not effect.is_queued_for_deletion() and effect.global_position.distance_to(center) < THREAT_RADIUS:
            count += 1
    return count
