extends SceneTree
## B03: every production Boss move in its authored arena against the real
## Player (damage on, no invulnerability). Each move is started through the
## Boss's own windup path and sampled with the Player standing at fixed floor
## offsets; HP loss is the only hit evidence. Body contact is held off so a
## sample measures the move, not walking into the Boss.
const MAIN_SCENE := preload("res://scenes/Main.tscn")
const CHAPTERS := [
    "res://data/demo_ch01_moss_bell_court.json",
    "res://data/demo_ch02_rain_foundry_canal.json",
    "res://data/demo_ch03_saltwhite_archive.json",
    "res://data/demo_ch04_broken_string_greenhouse.json",
    "res://data/demo_ch05_obsidian_pilgrim_road.json",
    "res://data/demo_ch06_silent_crown_core.json",
]
## Positive = toward the arena entrance (the side the Player arrives from).
const OFFSETS := [-240.0, 110.0, 240.0, 400.0, 580.0]
const MIN_WINDUP := 0.55
## Frames before the measured standing hit at which the guard is pressed.
const GUARD_LEADS := [9, 4, 14, 20]
const TRIAL_FRAMES := 270

var failures := 0
var checks := 0
var report: Array = []
## Settled standing spot per sampled offset, reused by every move of a Boss.
var stands := {}
var physics_frames := 0
## Height of the attacker above the Player's floor (non-zero for hovering foes).
var stand_drop := 0.0


func _initialize() -> void:
    call_deferred("_run")


## Runtime is split across two suites (first and last three arenas) so each
## stays well inside the default per-suite budget.
func _chapters() -> Array:
    return CHAPTERS.slice(0, 3)


func _marker() -> String:
    return "BOSS_MOVE_MATRIX"


func _offsets() -> Array:
    return OFFSETS


func _min_windup() -> float:
    return MIN_WINDUP


func _run() -> void:
    _check_distinct_move_sets()
    var only := ""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--only="):
            only = arg.trim_prefix("--only=")
    for path: String in _chapters():
        if not only.is_empty() and not path.contains(only):
            continue
        var entry: Dictionary = await _run_chapter(path)
        if not entry.is_empty():
            report.append(entry)
    print(_marker() + "_REPORT " + JSON.stringify(report))
    if failures > 0:
        print("%s_FAIL failures=%d checks=%d" % [_marker(), failures, checks])
        quit(1)
        return
    print("%s_COST attack_frames=%d elapsed_ms=%d" % [_marker(), physics_frames, Time.get_ticks_msec()])
    print("%s_PASS bosses=%d moves=%d checks=%d" % [_marker(), report.size(), _move_count(), checks])
    quit(0)


## All six authored move sets (type + guardability) differ, read from data so
## either half of the run checks the whole cast.
func _check_distinct_move_sets() -> void:
    var seen := {}
    for path: String in CHAPTERS:
        var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
        var kind := String(config.get("boss", {}).get("kind", ""))
        var signature: Array = []
        for command: Dictionary in config.get("ai_profiles", {}).get(kind, {}).get("attacks", []):
            signature.append("%s/%s" % [command.get("type", "melee"), "b" if bool(command.get("blockable", true)) else "u"])
        signature.sort()
        var key := ",".join(signature)
        _check(not kind.is_empty() and not seen.has(key), "%s move set differs from %s" % [kind, seen.get(key, "")])
        seen[key] = kind


func _run_chapter(path: String) -> Dictionary:
    var scene: Node = MAIN_SCENE.instantiate()
    scene.set("config_path", path)
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    await _frames(3)
    for enemy in get_nodes_in_group("enemy"):
        if not bool(enemy.get("is_boss")):
            enemy._cancel_attack_effects()
            enemy.queue_free()
    # The HUD shell only reads combat state; its per-frame refresh is most of
    # a headless frame here, so it is paused for the sampling run.
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
        scene.queue_free()
        await _frames(2)
        return {}
    player.debug_invulnerable = false
    player.bell_guard_unlocked = true
    var home: Vector2 = boss.global_position
    stands.clear()
    var checkpoint: Vector2 = scene._vec2(scene.config.get("boss_checkpoint", home + Vector2(-520, 0)))
    var front := -1 if checkpoint.x < home.x else 1
    var commands: Array = boss.ai_profile.get("attacks", []).duplicate(true)
    boss.ai_commands = []
    var moves: Array = []
    var signature: Array = []
    _check(commands.size() == 4, "%s has four authored moves" % boss.kind)
    for command: Dictionary in commands:
        var move: Dictionary = await _sample_move(scene, boss, player, command, home, front)
        moves.append(move)
        signature.append("%s/%s" % [command.get("type", "melee"), "b" if bool(command.get("blockable", true)) else "u"])
    _check(_footprints_distinct(moves), "%s four moves threaten different floor or differ in type" % boss.kind)
    var phase_two := commands.filter(func(c: Dictionary) -> bool: return int(c.get("phase", 1)) >= 2).size()
    _check(phase_two >= 1, "%s keeps at least one move for its second phase" % boss.kind)
    _check(commands.any(func(c: Dictionary) -> bool: return bool(c.get("blockable", true))) and commands.any(func(c: Dictionary) -> bool: return not bool(c.get("blockable", true))), "%s mixes guardable and unblockable moves" % boss.kind)
    var kind := String(boss.kind)
    var max_hp := int(boss.max_hp)
    var retry: Dictionary = await _retry_cost(scene, boss, player)
    signature.sort()
    var entry := {"kind": kind, "chapter": path.get_file(), "hp": max_hp, "front": front, "moves": moves, "signature": signature, "retry": retry}
    scene.queue_free()
    await _frames(3)
    return entry


func _sample_move(scene: Node, boss: Node2D, player: CharacterBody2D, command: Dictionary, home: Vector2, front: int) -> Dictionary:
    var id := String(command.get("id", ""))
    var trials := {}
    var hits: Array = []
    var safe: Array = []
    var skipped: Array = []
    var warned := true
    for offset: float in _offsets():
        var trial: Dictionary = await _trial(boss, player, command, home, front, offset, {})
        if not bool(trial.valid):
            skipped.append(offset)
            continue
        trials[offset] = trial
        warned = warned and bool(trial.warned)
        (hits if int(trial.damage) > 0 else safe).append(offset)
    # Inputs start from the closest wounded spot in front of the Boss, or the
    # closest front spot when standing still is itself the answer (a cage).
    var probe := INF
    for offset: float in (hits.filter(func(o: float) -> bool: return o > 0.0) if hits.any(func(o: float) -> bool: return o > 0.0) else (hits if not hits.is_empty() else safe)):
        if probe == INF or (offset > 0.0 and (probe < 0.0 or offset < probe)):
            probe = offset
    var escapes: Array = []
    var wounded_by: Array = []
    var guard := "untested"
    var hit_frame := -1
    if probe != INF:
        var standing: Dictionary = trials[probe]
        hit_frame = int(standing.hit_frame)
        if int(standing.damage) == 0:
            escapes.append("stand")
        # The first input that slips the move is enough; listing every one
        # would triple the run for no extra guarantee.
        for plan: Dictionary in _evasion_plans(hit_frame):
            if not escapes.is_empty():
                break
            var evaded: Dictionary = await _trial(boss, player, command, home, front, probe, plan)
            if bool(evaded.valid):
                (escapes if int(evaded.damage) == 0 else wounded_by).append(plan.name)
        if hits.is_empty():
            # Nothing reaches a still Player (a cage): stepping once the
            # hazard arms must wound, or the move is decoration.
            var armed := int((float(command.get("windup", 0.6)) + float(command.get("warning", 0.65))) * 60.0) + 6
            for plan: Dictionary in [{"name": "late_step_away", "hold": "away", "from": armed, "until": armed + 18}, {"name": "late_step_toward", "hold": "toward", "from": armed, "until": armed + 18}]:
                var stepped: Dictionary = await _trial(boss, player, command, home, front, probe, plan)
                if bool(stepped.valid) and int(stepped.damage) > 0:
                    wounded_by.append(plan.name)
                    break
        if hit_frame >= 0:
            # Arrival of homing or delayed hazards shifts by a few frames with
            # host speed; a player times the press, so try a few leads and
            # keep the first one where the guard was actually raised.
            var blockable := bool(command.get("blockable", true))
            for lead: int in GUARD_LEADS:
                var guarded: Dictionary = await _trial(boss, player, command, home, front, probe, {"guard": maxi(0, hit_frame - lead)})
                if not bool(guarded.get("valid", false)) or not bool(guarded.get("guarded", false)):
                    continue
                guard = "blocked" if int(guarded.get("damage", 1)) == 0 else "through"
                if guard == ("blocked" if blockable else "through"):
                    break
            if blockable:
                _check(guard == "blocked", "%s is stopped by a timed bell guard" % id)
            else:
                _check(guard == "through", "%s still wounds through a raised guard" % id)
    _check(float(command.get("windup", 0.0)) >= _min_windup(), "%s winds up for at least %.2fs" % [id, _min_windup()])
    _check(warned, "%s shows a warning during every sampled windup" % id)
    _check(hits.size() + safe.size() >= 4, "%s has enough valid floor samples (%s skipped)" % [id, str(skipped)])
    _check(not hits.is_empty() or not wounded_by.is_empty(), "%s actually removes Player HP when stood in or moved through" % id)
    _check(not escapes.is_empty(), "%s can be escaped from %+.0f by standing or a real move/jump/dash input" % [id, probe])
    _check(guard != "untested" or not bool(command.get("blockable", true)), "%s guard response is measured" % id)
    return {"id": id, "name": command.get("name", ""), "type": command.get("type", "melee"), "phase": int(command.get("phase", 1)), "windup": command.get("windup", 0.0), "blockable": bool(command.get("blockable", true)), "hits": hits, "safe": safe, "skipped": skipped, "probe": probe if probe != INF else null, "hit_frame": hit_frame, "guard": guard, "escapes": escapes, "wounded_by": wounded_by}


## Input plans start at the windup; "away" is away from the Boss.
func _evasion_plans(hit_frame: int) -> Array:
    var late := maxi(0, hit_frame - 14)
    var dash := maxi(0, hit_frame - 8)
    return [
        {"name": "retreat", "hold": "away", "from": 0},
        {"name": "advance", "hold": "toward", "from": 0},
        {"name": "jump", "jump": late},
        {"name": "dash_away", "hold": "away", "from": dash, "dash": dash},
        {"name": "dash_through", "hold": "toward", "from": dash, "dash": dash},
        {"name": "retreat_jump", "hold": "away", "from": 0, "jump": late},
    ]


func _trial(boss: Node2D, player: CharacterBody2D, command: Dictionary, home: Vector2, front: int, offset: float, plan: Dictionary) -> Dictionary:
    _end_hitstop()
    _reset_boss(boss, home, command)
    _release_inputs()
    var floor_y := home.y + stand_drop
    var target := Vector2(home.x + front * offset, floor_y - 30.0)
    if stands.has(offset) and stands[offset] == null:
        return {"valid": false}
    player.restore_at_save_point()
    player.global_position = stands.get(offset, target)
    player.velocity = Vector2.ZERO
    player.arrival_guard_timer = 0.0
    player.guard_timer = 0.0
    player.guard_cooldown = 0.0
    for frame in (4 if stands.has(offset) else 24):
        boss.contact_timer = 999.0
        boss.global_position = home
        await physics_frame
    var landed := player.is_on_floor() and absf(player.global_position.x - target.x) < 28.0 and absf(player.global_position.y - floor_y) < 90.0
    if not stands.has(offset):
        stands[offset] = player.global_position if landed else null
    if not landed:
        return {"valid": false}
    player.restore_at_save_point()
    var side := 1 if player.global_position.x > home.x else -1
    player.facing = -side
    boss.direction = side
    var away := "move_right" if side > 0 else "move_left"
    var toward := "move_left" if side > 0 else "move_right"
    var hp_before: int = player.hp
    _end_hitstop()
    boss._begin_attack(command)
    var warned := _warning_visible(boss)
    var hit_frame := -1
    var guarded := false
    var held := ""
    for frame in TRIAL_FRAMES:
        boss.contact_timer = 999.0
        boss.attack_desire = 0.0
        if plan.has("hold") and frame == int(plan.get("from", 0)):
            held = away if plan.hold == "away" else toward
            Input.action_press(held)
        if not held.is_empty() and frame == int(plan.get("until", -999)):
            Input.action_release(held)
        if frame == int(plan.get("jump", -999)):
            Input.action_press("jump")
        if frame == int(plan.get("jump", -999)) + 16:
            Input.action_release("jump")
        if frame == int(plan.get("dash", -999)):
            Input.action_press("dash")
        if frame == int(plan.get("dash", -999)) + 2:
            Input.action_release("dash")
        if frame == int(plan.get("guard", -999)):
            player.energy = player.max_energy
            Input.action_press("bell_guard")
        guarded = guarded or player.guard_timer > 0.0
        if frame == int(plan.get("guard", -999)) + 3:
            Input.action_release("bell_guard")
        await physics_frame
        physics_frames += 1
        if boss.state == "windup":
            warned = warned or _warning_visible(boss)
        if hit_frame < 0 and player.hp < hp_before:
            hit_frame = frame
            break
        if frame > 4 and not boss._is_attack_state() and _live_effects(boss) == 0:
            break
    _release_inputs()
    var damage: int = hp_before - int(player.hp)
    _reset_boss(boss, home, command)
    return {"valid": true, "offset": offset, "damage": damage, "hit_frame": hit_frame, "warned": warned, "guarded": guarded}


## The previous sample's hit starts a wall-clock hitstop; left running it
## slows the next sample by however long the host takes per frame.
func _end_hitstop() -> void:
    var feel := root.get_node_or_null("FeelKit")
    if feel != null and feel.has_method("cancel_hitstop"):
        feel.cancel_hitstop()


func _release_inputs() -> void:
    for action in ["move_left", "move_right", "jump", "dash", "bell_guard"]:
        Input.action_release(action)


func _reset_boss(boss: Node2D, home: Vector2, command: Dictionary) -> void:
    boss._cancel_attack_effects()
    boss._clear_telegraph()
    preload("res://scripts/boss_skill_art.gd").clear(boss)
    boss.active_attack = {}
    boss.state = "patrol"
    boss.state_timer = 0.0
    boss.phase_pause = 0.0
    boss.cooldowns.clear()
    boss.battle_phase = maxi(1, int(command.get("phase", 1)))
    boss.hp = boss.max_hp
    boss.global_position = home


func _retry_cost(scene: Node, boss: Node2D, player: CharacterBody2D) -> Dictionary:
    # A fatal hit mid-fight retires the wounded phase-two Boss and opens the
    # arena. This demo host re-arms the gate Boss at respawn; World waits for
    # the bell gate (world_g02_death_playback) and takes half the wallet
    # (world_bride_retry_playback), neither repeated here.
    var kind := String(boss.kind)
    boss.hp = maxi(1, int(boss.max_hp / 2))
    boss.battle_phase = 2
    player.hp = 1
    player.hurt_timer = 0.0
    var fatal: bool = player.take_damage(1, boss.global_position, false)
    var respawned := false
    for frame in 240:
        await physics_frame
        if player.hp > 0 and player.death_timer <= 0.0:
            respawned = true
            break
    await _frames(4)
    _check(fatal and respawned, "%s retry probe dies from a real hit and respawns" % kind)
    _check(not is_instance_valid(boss) and not is_instance_valid(scene.boss_arena_lock_body), "%s death retires the wounded Boss and opens the arena" % kind)
    var fresh: Node2D = scene.boss_actor
    _check(is_instance_valid(fresh) and fresh.hp == fresh.max_hp and fresh.battle_phase == 1, "%s next attempt starts from full HP in phase one" % kind)
    if is_instance_valid(fresh):
        fresh._cancel_attack_effects()
    var checkpoint: Vector2 = scene._vec2(scene.config.get("boss_checkpoint", scene.active_spawn))
    return {"boss_checkpoint_to_gate": snappedf(checkpoint.distance_to(scene._boss_gate_position()), 1.0), "respawn_hp": player.hp}


func _warning_visible(boss: Node2D) -> bool:
    if is_instance_valid(boss.telegraph) or is_instance_valid(boss.windup_vfx):
        return true
    for child in boss.get_children():
        if (child.get_meta("boss_skill_art", "") == "warning" or child.get_meta("minor_enemy_skill_art", "") == "warning") and not child.is_queued_for_deletion():
            return true
    for effect in boss.owned_attack_effects:
        if is_instance_valid(effect) and float(effect.age) < float(effect.arm_delay):
            return true
    return false


func _live_effects(boss: Node2D) -> int:
    var live := 0
    for effect in boss.owned_attack_effects:
        if is_instance_valid(effect) and not effect.is_queued_for_deletion() and not bool(effect.cancelled):
            live += 1
    return live


func _footprints_distinct(moves: Array) -> bool:
    for i in moves.size():
        for j in range(i + 1, moves.size()):
            if moves[i].type == moves[j].type and moves[i].hits == moves[j].hits and moves[i].blockable == moves[j].blockable:
                return false
    return true


func _move_count() -> int:
    var count := 0
    for entry in report:
        count += entry.moves.size()
    return count


func _frames(count: int) -> void:
    for index in count:
        await process_frame


func _check(condition: bool, label: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error(_marker() + " " + label)
