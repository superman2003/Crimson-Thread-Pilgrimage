extends SceneTree
## B01 species roles on production enemy actors: ambush reveal range and post,
## alarm calls bounded by radius/territory/cooldown, wall occlusion and chase
## disengage, guards holding post, and authored ambushers away from arrivals.
## Role cues: reveal/alarm/support sounds and rings, the reveal hold, and calm
## posts not counting as combat for the music layer.
## Fixture target and walls; decisions, sight rays and movement are production.
const ENEMY := preload("res://scripts/enemy_actor.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const PROFILE_PATH := "res://data/original_creature_combat.json"
const AUDIO_DIRECTOR := preload("res://scripts/audio_director.gd")
const REGIONS := ["demo_ch01_moss_bell_court", "demo_ch02_rain_foundry_canal", "demo_ch03_saltwhite_archive", "demo_ch04_broken_string_greenhouse", "demo_ch05_obsidian_pilgrim_road", "demo_ch06_silent_crown_core"]
const AMBUSH_ENTRANCE_CLEARANCE := 240.0
var checks := 0
var failures := 0
var stage: Node2D
var target: CharacterBody2D
class CombatTarget extends CharacterBody2D:
    var ui_input_locked := false
    var damage_events := 0
    func take_damage(_amount: int, _origin: Vector2, _blockable := true) -> void:
        damage_events += 1

func _initialize() -> void:
    call_deferred("run")

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(label)

func spawn(kind: String, id: String, at: Vector2, boss := false, extra := {}) -> Area2D:
    var enemy: Area2D = ENEMY.new()
    # Chapters pass the species profile, so territory matches the authored leash.
    var species: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH)).get(kind, {})
    var data := {"id": id, "kind": kind, "hp": 6, "damage": 1, "patrol": 80.0}
    data.merge(extra, true)
    enemy.configure(data, String(data.get("sprite", "")), boss, species)
    enemy.position = at
    stage.add_child(enemy)
    enemy.set_physics_process(false)
    return enemy

func step(enemy: Area2D, seen: CharacterBody2D, count := 1) -> void:
    for index in count:
        enemy._update_patrol_or_aggro(0.1, seen)

func wall(x: float) -> StaticBody2D:
    var body := StaticBody2D.new()
    body.collision_layer = 1
    var shape := CollisionShape2D.new()
    var rect := RectangleShape2D.new()
    rect.size = Vector2(20, 400)
    shape.shape = rect
    body.add_child(shape)
    body.position = Vector2(x, 200)
    stage.add_child(body)
    return body

func clear_stage() -> void:
    for child in stage.get_children():
        if child != target: child.free()
    await physics_frame
    await physics_frame

func run() -> void:
    stage = Node2D.new()
    root.add_child(stage)
    target = CombatTarget.new()
    target.add_to_group("player")
    stage.add_child(target)
    await process_frame
    await _data_contract()
    await _ambush()
    await _alarm()
    await _occlusion_and_disengage()
    await _guard_post()
    await _support()
    await _role_cues()
    _ambush_placement()
    print("ENEMY_TACTICAL_ROLES checks=%d failures=%d" % [checks, failures])
    quit(0 if failures == 0 else 1)

func _data_contract() -> void:
    var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
    var counts := {}
    for kind in profiles:
        var entry: Dictionary = profiles[kind]
        var role := String(entry.get("tactical_role", ""))
        counts[role] = int(counts.get(role, 0)) + 1
        var motion := String(entry.locomotion)
        check(ENEMY.TACTICAL_ROLES.has(role), "%s has a known tactical role (%s)" % [kind, role])
        check((role == "boss") == bool(entry.get("tactical_ai", false)), "%s: only tactical bosses use the boss role" % kind)
        var consistent := true
        match role:
            "aerial": consistent = motion == "flight"
            "ranged": consistent = motion == "stationary" or float(entry.preferred_range) >= 120.0
            "ambush", "patrol": consistent = motion == "ground"
            "guard": consistent = motion == "stationary" or bool(entry.get("front_guard", false))
        check(consistent, "%s: %s role matches its locomotion and spacing" % [kind, role])
    for role in ENEMY.TACTICAL_ROLES:
        check(int(counts.get(role, 0)) > 0, "the roster includes at least one %s" % role)
    var bookmite := spawn("salt_bookmite", "role_probe", Vector2(0, 300))
    check(bookmite.tactical_role == "ambush" and bookmite.get_ai_debug_state().tactical_role == "ambush", "production actor reads its species role")
    var boss := spawn("rust_crown_guardian", "role_boss", Vector2(0, 300), true)
    check(boss.tactical_role == "boss" and not boss.hear_alarm(Vector2.ZERO), "bosses keep their own tactics and ignore alarms")
    var override: Area2D = ENEMY.new()
    override.configure({"id": "role_override", "kind": "salt_bookmite", "encounter_profile": {"tactical_role": "patrol"}}, "")
    check(override.tactical_role == "patrol", "a spawn can relax an entrance ambusher to patrol")
    override.free()
    await clear_stage()

func _ambush() -> void:
    var bookmite := spawn("salt_bookmite", "ambush_bookmite", Vector2(300, 300))
    var larva := spawn("moss_larva", "ambush_compare", Vector2(300, 600))
    target.position = Vector2(520, 300)
    await physics_frame
    step(bookmite, target, 10)
    check(bookmite.last_ai_decision == "lurk" and is_equal_approx(bookmite.global_position.x, 300.0), "ambusher stays hidden at its post outside its reveal range")
    check(bookmite.memory_timer == 0.0, "an unrevealed ambusher does not start tracking")
    check(not bookmite._is_aware_of(target), "a lurking ambusher does not turn toward a player outside its reveal range")
    target.position = Vector2(420, 300)
    var screen := wall(360)
    await physics_frame
    await physics_frame
    check(not bookmite._is_aware_of(target), "a lurking ambusher does not react through terrain")
    screen.free()
    await physics_frame
    await physics_frame
    check(bookmite._is_aware_of(target), "a nearby visible player is noticed by the ambusher")
    target.position = Vector2(520, 300)
    target.position = Vector2(520, 600)
    await physics_frame
    step(larva, target)
    check(larva.memory_timer > 0.0, "a patrolling species engages at its ordinary aggro range")
    target.position = Vector2(420, 300)
    await physics_frame
    step(bookmite, target)
    check(bookmite.memory_timer > 0.0 and bookmite.last_ai_decision != "lurk", "ambusher reveals itself once the player is close")
    bookmite.state = "patrol"
    bookmite.global_position.x = 380.0
    bookmite.memory_timer = 0.0
    step(bookmite, null)
    check(bookmite.last_ai_decision == "return_post" and bookmite.global_position.x < 380.0, "after losing the player an ambusher walks back to its post")
    step(bookmite, null, 60)
    check(bookmite.last_ai_decision == "lurk" and absf(bookmite.global_position.x - 300.0) <= 6.0, "ambusher resumes waiting at its exact post")
    await clear_stage()

func _alarm() -> void:
    # The near ally cannot see the player through a wall; only the bell can.
    var bell := spawn("spore_bellmaker", "alarm_bell", Vector2(200, 300))
    var near := spawn("moss_larva", "alarm_near", Vector2(0, 300))
    var far := spawn("moss_larva", "alarm_far", Vector2(-400, 300))
    var late := spawn("moss_larva", "alarm_late", Vector2(-60, 300))
    var blocker := wall(100)
    target.position = Vector2(260, 300)
    late.memory_timer = 0.5  # already searching: not counted as newly told
    await physics_frame
    await physics_frame
    step(near, target)
    check(near.memory_timer == 0.0, "the walled-off ally cannot see the player by itself")
    step(bell, target)
    check(bell.alarm_alerted == 1 and bell.alarm_cooldown > 0.0, "the bell alerts exactly the idle ally inside its radius")
    check(near.memory_timer > 0.0 and is_equal_approx(near.last_seen_position.x, 260.0), "the ally is told where the player was seen")
    check(far.memory_timer == 0.0, "allies beyond the alarm radius stay unaware")
    var engaged := false
    for index in 80:
        step(near, target)
        if near.last_ai_decision in ["press", "advance", "threaten", "space"] or near.state == "windup":
            engaged = true
            break
    check(engaged, "the alerted ally walks toward the call until it sees and engages the player")
    var repeat := spawn("moss_larva", "alarm_repeat", Vector2(100, 600))
    bell.memory_timer = 0.0
    step(bell, target)
    check(repeat.memory_timer == 0.0, "the alarm has a cooldown instead of ringing every frame")
    blocker.free()
    var edge := spawn("moss_larva", "alarm_edge", Vector2(-300, 300))
    target.position = Vector2(400, 300)
    edge.hear_alarm(target.global_position)
    check(is_equal_approx(edge.last_seen_position.x, -20.0), "a distant call is searched for only to the edge of the ally's own territory")
    # Leash tighter than aggro: the player stands just outside the ally's territory.
    var tight := spawn("moss_larva", "alarm_tight", Vector2(-1000, 900), false, {"leash_radius": 220.0})
    var tight_bell := spawn("spore_bellmaker", "alarm_tight_bell", Vector2(-850, 900))
    target.position = Vector2(-750, 900)
    await physics_frame
    step(tight_bell, target)
    check(tight.memory_timer > 0.0 and tight.alarm_search, "the tight-leash ally hears the call")
    var start_x: float = tight.global_position.x
    step(tight, target, 5)
    check(tight.last_ai_decision == "investigate" and tight.global_position.x > start_x, "a player just outside the ally's leash does not cancel the search")
    var quiet := spawn("moss_larva", "alarm_quiet_caller", Vector2(500, 600))
    var bystander := spawn("moss_larva", "alarm_bystander", Vector2(300, 600))
    target.position = Vector2(620, 600)
    await physics_frame
    step(quiet, target)
    check(quiet.memory_timer > 0.0 and bystander.memory_timer == 0.0, "non-alarm species do not call allies")
    await clear_stage()

func _occlusion_and_disengage() -> void:
    var larva := spawn("moss_larva", "sight_larva", Vector2(300, 300))
    target.position = Vector2(450, 300)
    var blocker := wall(375)
    await physics_frame
    await physics_frame
    step(larva, target)
    check(larva.memory_timer == 0.0 and larva.last_ai_decision == "patrol", "a terrain wall blocks sight inside aggro range")
    blocker.free()
    await physics_frame
    await physics_frame
    step(larva, target)
    check(larva.memory_timer > 0.0, "the same player is engaged once the wall is gone")
    larva.state = "patrol"
    blocker = wall(375)
    await physics_frame
    await physics_frame
    step(larva, target)
    check(larva.last_ai_decision == "investigate", "losing sight starts a search of the last-seen point")
    larva.memory_timer = 0.0
    step(larva, target)
    check(larva.last_ai_decision == "patrol", "the search ends and the enemy disengages to its patrol")
    await clear_stage()

func _guard_post() -> void:
    var sentinel := spawn("gear_sentinel", "guard_sentinel", Vector2(300, 300))
    step(sentinel, null, 20)
    check(sentinel.last_ai_decision == "hold_post" and is_equal_approx(sentinel.global_position.x, 300.0), "a guard stands its post instead of patrolling before any encounter")
    target.position = Vector2(420, 300)
    await physics_frame
    step(sentinel, target)
    check(sentinel.memory_timer > 0.0, "the guard engages a visible intruder")
    sentinel.state = "patrol"
    sentinel.global_position.x = 360.0
    step(sentinel, null)
    check(sentinel.last_ai_decision == "return_post" and sentinel.global_position.x < 360.0, "a guard returns to its post instead of searching the last-seen point")
    step(sentinel, null, 40)
    check(sentinel.last_ai_decision == "hold_post" and absf(sentinel.global_position.x - 300.0) <= 6.0, "the guard holds its post while still alert")
    sentinel.memory_timer = 0.0
    step(sentinel, null, 20)
    check(sentinel.last_ai_decision == "hold_post" and absf(sentinel.global_position.x - 300.0) <= 6.0, "the guard keeps its post after its memory expires")
    await clear_stage()

func _support() -> void:
    var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/demo_ch05_obsidian_pilgrim_road.json"))
    var pair: Array = []
    for challenge in config.optional_challenges:
        if challenge.id == "ch05_war_graves_trial": pair = challenge.enemies
    # This is the existing military-grave optional encounter, not a new spawn.
    check(pair.size() == 2, "the authored grave encounter supplies a spear fighter and flag bearer")
    if pair.size() != 2: return
    var spear_data: Dictionary = pair[0]
    var flag_data: Dictionary = pair[1]
    check(flag_data.kind == "ash_banner_imp" and config.ai_profiles.ash_banner_imp.tactical_role == "support", "the authored optional encounter uses the production support profile")
    var donor := spawn(flag_data.kind, flag_data.id, Vector2(flag_data.position[0], flag_data.position[1]), false, flag_data)
    var ally := spawn(spear_data.kind, spear_data.id, Vector2(spear_data.position[0], spear_data.position[1]), false, spear_data)
    target.position = donor.position + Vector2(130, 0)
    ally.hp = 1
    ally.set_meta("optional_challenge_id", "different_challenge")
    check(not donor._support_ally_valid(ally), "support cannot heal across optional challenge boundaries")
    ally.remove_meta("optional_challenge_id")
    await physics_frame
    step(donor, target)
    check(donor.state == "support" and ally.hp == 1, "the flag bearer channels before mending its wounded elite companion")
    var support_cue := donor.get_node_or_null("MinorEnemySupportChannel") if donor.get_node_or_null("MinorEnemySupportChannel") != null else donor.get_node_or_null("EnemySupportLink")
    check(support_cue != null and donor.support_target.get_ref() == ally, "a visible non-damaging material connection identifies the chosen ally")
    for index in 4: donor._physics_process(0.1)
    check(ally.hp == 1 and donor.state == "support", "support does not heal before its readable windup ends")
    var remaining: float = donor.state_timer
    var cooldown: float = donor.support_cooldown
    target.ui_input_locked = true
    donor._physics_process(2.0)
    check(donor.state_timer == remaining and donor.support_cooldown == cooldown and ally.hp == 1, "UI pause freezes both support channel and cooldown")
    target.ui_input_locked = false
    for index in 6: donor._physics_process(0.1)
    check(ally.hp == 2 and donor.state == "recover", "a completed support channel mends exactly one HP and leaves a recovery window")
    check(donor.support_target == null and donor.windup_vfx == null and donor.owned_attack_effects.is_empty(), "release clears the weak target and link without spawning damage")
    for index in 6: donor._physics_process(0.1)
    donor.attack_desire = 2.0
    donor._physics_process(0.1)
    check(donor.state == "windup" and donor.last_attack_id in ["imp_flurry", "imp_retreat"], "during the eight-second support cooldown the flag bearer still uses its ordinary attacks")
    check(ally.hp == 2 and donor.support_cooldown > 0.0, "the injured ally is not healed again on the next decision")
    await clear_stage()
    await _support_filters()
    for reason in ["hit", "trip", "interference", "lure", "wall", "player_hidden", "range", "floor", "ally_retired", "source_retired", "suspend_resume", "freed", "ally_dead", "source_dead", "respawn"]:
        await _support_cancel(reason)

func cue_rings(enemy: Node, ring_name: String) -> int:
    var count := 0
    for child in enemy.get_children():
        if child.name.begins_with(ring_name) and not child.is_queued_for_deletion(): count += 1
    return count

func _role_cues() -> void:
    var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/audio_visual_manifest.json")).sfx_catalog
    for cue in ["ambush_reveal", "alarm_call", "support_mend"]:
        var path := String(ENEMY.SFX.get("role_" + cue, ""))
        var stream := AudioStreamOggVorbis.load_from_file(path) if FileAccess.file_exists(path) else null
        check(stream != null and stream.get_length() >= 0.3 and stream.get_length() <= 1.0, cue + ": the cue has its own short generated sound")
        var entry: Dictionary = manifest.get("enemy_" + cue, {})
        check(entry.get("status") == "wired" and entry.get("path") == path and entry.get("runtime_key") == "role_" + cue, cue + ": the AV manifest lists the wired cue")
    # Ambush reveal: one cue and a short hold before the ambusher may act.
    var bookmite := spawn("salt_bookmite", "cue_bookmite", Vector2(300, 300))
    target.position = Vector2(520, 300)
    await physics_frame
    step(bookmite, target, 5)
    check(bookmite.role_cue_counts.is_empty() and not bookmite.combat_engaged(), "a lurking ambusher makes no cue and is calm for the music layer")
    target.position = Vector2(420, 300)
    await physics_frame
    bookmite.attack_desire = 2.0
    step(bookmite, target)
    check(int(bookmite.role_cue_counts.get("ambush_reveal", 0)) == 1 and cue_rings(bookmite, "EnemyAmbushRevealCue") == 1, "revealing plays the ambush cue and draws one burst")
    check(bookmite.last_ai_decision == "ambush:reveal" and bookmite.state == "patrol" and bookmite.combat_engaged(), "the revealed ambusher holds instead of striking on the same frame")
    check(bookmite.direction == 1, "the reveal faces the player")
    var held := true
    var acted := false
    for index in 8:
        bookmite._physics_process(0.05)
        if bookmite.state == "windup" and index < 6: held = false
        if bookmite.last_ai_decision != "ambush:reveal": acted = true
    check(held and acted, "the hold lasts about a third of a second, then ordinary combat resumes")
    check(int(bookmite.role_cue_counts.get("ambush_reveal", 0)) == 1, "tracking does not repeat the reveal cue")
    bookmite.state = "patrol"
    bookmite.memory_timer = 0.0
    target.position = Vector2(5000, 300)
    step(bookmite, null, 60)
    target.position = Vector2(420, 300)
    await physics_frame
    step(bookmite, target)
    check(int(bookmite.role_cue_counts.get("ambush_reveal", 0)) == 2, "an ambusher back at its post reveals again with a fresh cue")
    await clear_stage()
    # Alarm: the caller rings once per cooldown; told allies stay quiet.
    var bell := spawn("spore_bellmaker", "cue_bell", Vector2(200, 300))
    var ally := spawn("moss_larva", "cue_ally", Vector2(0, 300))
    target.position = Vector2(260, 300)
    await physics_frame
    step(bell, target)
    check(int(bell.role_cue_counts.get("alarm_call", 0)) == 1 and cue_rings(bell, "EnemyAlarmCue") == 2, "an alarm plays its call and draws two widening rings")
    check(ally.memory_timer > 0.0 and ally.role_cue_counts.is_empty(), "allies hearing the call do not raise cues of their own")
    bell.memory_timer = 0.0
    step(bell, target)
    check(int(bell.role_cue_counts.get("alarm_call", 0)) == 1, "the call cue follows the alarm cooldown")
    await clear_stage()
    # Support: the channel begins with its cue.
    var donor := spawn("ash_banner_imp", "cue_donor", Vector2(300, 300))
    var hurt := spawn("moss_larva", "cue_hurt", Vector2(180, 300))
    hurt.hp = 1
    target.position = Vector2(430, 300)
    await physics_frame
    step(donor, target)
    check(donor.state == "support" and int(donor.role_cue_counts.get("support_mend", 0)) == 1, "a support channel starts with its own sound")
    await clear_stage()
    await _calm_music_layer()

func _calm_music_layer() -> void:
    var lurker := spawn("salt_bookmite", "calm_lurker", Vector2(300, 300))
    var sentinel := spawn("gear_sentinel", "calm_sentinel", Vector2(-300, 300))
    var larva := spawn("moss_larva", "calm_larva", Vector2(300, 900))
    target.position = Vector2(5000, 300)
    step(lurker, null, 5)
    step(sentinel, null, 5)
    check(lurker.last_ai_decision == "lurk" and sentinel.last_ai_decision == "hold_post", "fixture enemies wait at their posts")
    var director: Node = AUDIO_DIRECTOR.new()
    director.autoplay_enabled = false
    director.runtime_player = target
    director._tick_combat_layer(0.25, [lurker, sentinel])
    check(not director.combat_active, "lurking ambushers and guards at post do not start combat music")
    sentinel.global_position.x = -260.0
    sentinel.memory_timer = 0.0
    step(sentinel, null)
    check(sentinel.last_ai_decision == "return_post", "the guard walks back to its post")
    director._tick_combat_layer(0.25, [sentinel])
    check(not director.combat_active, "returning to a post is calm")
    target.position = Vector2(420, 900)
    await physics_frame
    step(larva, target)
    director._tick_combat_layer(0.25, [lurker, sentinel, larva])
    check(director.combat_active, "an engaged enemy still starts combat music")
    director.free()
    await clear_stage()

func _support_filters() -> void:
    var donor := spawn("ash_banner_imp", "support_filters", Vector2(300, 300))
    var ally := spawn("moss_larva", "support_healthy", Vector2(180, 300))
    var other := spawn("ash_banner_imp", "support_other", Vector2(200, 300))
    var boss := spawn("rust_crown_guardian", "support_boss", Vector2(180, 300), true)
    donor.hp = 1
    other.hp = 1
    boss.hp = 1
    target.position = Vector2(430, 300)
    await physics_frame
    check(not donor._support_ally_valid(donor) and not donor._support_ally_valid(other) and not donor._support_ally_valid(boss), "support excludes self, other supporters and bosses")
    check(not donor._support_ally_valid(ally), "support does not waste a channel on full health")
    ally.hp = 0
    check(not donor._support_ally_valid(ally), "support cannot revive a zero-HP actor")
    ally.hp = 1
    var less_hurt := spawn("moss_larva", "support_less_hurt", Vector2(250, 300))
    less_hurt.hp = 4
    target.position = Vector2(5000, 300)
    donor._physics_process(0.1)
    check(donor.state != "support" and ally.hp == 1, "wounded allies do not start support out of combat")
    target.position = Vector2(430, 300)
    step(donor, target)
    check(donor.state == "support" and donor.support_target.get_ref() == ally, "support prioritizes the most injured ally rather than the nearest")
    check(donor.direction == -1 and donor.attack_direction == -1, "the channel faces the ally behind it, not the player or a stale attack side")
    donor._finish_support()
    var foreign := Node2D.new()
    stage.add_child(foreign)
    ally.reparent(foreign)
    check(not donor._support_ally_valid(ally), "support cannot cross a region host boundary")
    await clear_stage()

func _support_cancel(reason: String) -> void:
    var donor := spawn("ash_banner_imp", "support_cancel_" + reason, Vector2(300, 300), false, {"elite": true})
    var ally := spawn("moss_larva", "support_cancel_ally", Vector2(180, 300))
    ally.hp = 1
    target.position = Vector2(430, 300)
    await physics_frame
    step(donor, target)
    check(donor.state == "support", reason + ": the channel actually began")
    match reason:
        "hit": donor.take_hit(1, 1)
        "trip": donor.apply_trip(0.5)
        "interference": donor.apply_target_interference(2.0)
        "lure": donor.investigate_lure(Vector2(280, 300), 2.0)
        "wall": wall(240)
        "player_hidden": wall(375)
        "range": ally.position.x = -500
        "floor": ally.position.y += 120
        "ally_retired": ally.set_meta("world_residency_active", false)
        "source_retired": donor.set_meta("world_residency_active", false)
        "suspend_resume":
            var residency := preload("res://scripts/world_gameplay_residency.gd").new()
            residency.adopt_enemy(donor)
            residency._set_enemy_active(donor.spawn_id, false)
            check(donor.process_mode == Node.PROCESS_MODE_DISABLED and donor.support_target == null, "residency cancels before disabling processing")
            residency._set_enemy_active(donor.spawn_id, true)
        "freed": ally.free()
        "ally_dead": ally.take_hit(6, 1)
        "source_dead": donor.take_hit(donor.max_hp, 1)
        "respawn": donor.reset_for_respawn()
    await physics_frame
    await physics_frame
    if reason != "respawn": donor._physics_process(1.0)
    check(not is_instance_valid(ally) or ally.hp <= 1, reason + ": cancelled support never releases healing")
    check(donor.state != "support" and donor.support_target == null and donor.windup_vfx == null, reason + ": channel target and cue are cleared")
    if reason == "respawn":
        check(donor.support_cooldown == 0.0, "respawn resets support cooldown")
    else:
        check(donor.support_cooldown > 0.0, reason + ": cancellation cannot bypass support cooldown")
    await clear_stage()

func _ambush_placement() -> void:
    var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
    var routes: Dictionary = ROUTES.cached_data()
    var ambushers := 0
    for region in REGIONS:
        var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json" % region))
        var arrivals: Array = []
        for portal in routes.get("chapters", {}).get(region, {}).get("portals", []):
            arrivals.append(Vector2(portal.position[0], portal.position[1]))
        if config.has("player_start"):
            arrivals.append(Vector2(config.player_start[0], config.player_start[1]))
        for spawn_data in config.get("enemy_spawns", []):
            var role := String(spawn_data.get("encounter_profile", {}).get("tactical_role", profiles.get(String(spawn_data.get("kind", "")), {}).get("tactical_role", "")))
            if role != "ambush":
                continue
            ambushers += 1
            var at := Vector2(spawn_data.position[0], spawn_data.position[1])
            var nearest := INF
            for point in arrivals: nearest = minf(nearest, at.distance_to(point))
            check(nearest >= AMBUSH_ENTRANCE_CLEARANCE, "%s %s ambusher is %.0fpx from the nearest arrival" % [region, spawn_data.id, nearest])
    check(ambushers >= 6, "authored rooms still contain real ambushers (%d)" % ambushers)
