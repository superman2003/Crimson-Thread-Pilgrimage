extends SceneTree
## Seal identity on the real Player: each seal heals its own way, switching
## seals mid-action leaves nothing behind, no legal adornment combination
## breaks the resource bounds, and practice-rack thread cannot be carried off.
const BUILD := preload("res://scripts/build_system.gd")
var checks := 0
var failures := 0
var player: CharacterBody2D
var build: RefCounted

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(label)

func frames(count: int) -> void:
    for i in count:
        await physics_frame
        await process_frame

func pulse(action: String, hold: int = 2, settle: int = 42) -> void:
    Input.action_press(action)
    await frames(hold)
    Input.action_release(action)
    await frames(settle)

func use_crest(crest: String) -> void:
    build.state.crest = crest
    build._normalize_active_slots()
    player.apply_build_stats(build.profile())
    player.restore_at_save_point()

func stand(at: Vector2 = Vector2(100, 180)) -> void:
    player.global_position = at
    player.velocity = Vector2.ZERO
    await frames(4)

func run() -> void:
    root.size = Vector2i(1280, 720)
    var floor := StaticBody2D.new()
    floor.position = Vector2(400, 202)
    var shape := CollisionShape2D.new()
    var rect := RectangleShape2D.new()
    rect.size = Vector2(3000, 44)
    shape.shape = rect
    floor.add_child(shape)
    root.add_child(floor)
    player = load("res://scenes/Player.tscn").instantiate()
    root.add_child(player)
    player.feel = null
    build = BUILD.new()
    build.state.unlocked_crests = build.catalog.crests.keys()
    build.state.unlocked_skills = build.catalog.skills.keys()
    build.state.unlocked_passives = build.catalog.passives.keys()
    build.state.mechanisms = ["crimson", "bell", "salt"]
    player.build_system = build
    await stand()
    check(not player.debug_invulnerable, "Seal identity uses a damage-enabled Player")
    await heal_styles()
    await switching_residue()
    adornment_bounds()
    await practice_energy()
    player.queue_free()
    floor.queue_free()
    await frames(2)
    check(await preload("res://scripts/audio_retirement.gd").drain(self), "Seal identity audio retires")
    print("SEAL_IDENTITY checks=%d failures=%d crests=3" % [checks, failures])
    call_deferred("quit", 1 if failures else 0)

func heal_styles() -> void:
    var styles := {}
    for crest in ["crimson", "bell", "salt"]:
        use_crest(crest)
        var row: Dictionary = build.catalog.crests[crest]
        check(player.heal_energy_cost == int(row.heal_cost) and player.heal_amount == int(row.heal_amount) and is_equal_approx(player.heal_duration, float(row.heal_duration)), crest + ": Player heals with its own catalog cost, amount and time")
        styles[[player.heal_energy_cost, player.heal_amount, player.heal_duration, bool(row.get("heal_airborne", false))]] = crest
        # Grounded channel, completed with real time.
        await stand()
        player.hp = player.max_hp - 2
        player.energy = player.max_energy
        var hp_before: int = player.hp
        await pulse("heal", 1, 0)
        check(player.heal_timer > 0.0 and player.energy == player.max_energy - player.heal_energy_cost, crest + ": real heal input reserves the seal's cost")
        await frames(int(ceil(player.heal_duration * 60.0)) + 3)
        check(player.hp == hp_before + player.heal_amount, crest + ": grounded heal restores the seal's amount")
        # Airborne: only the light seal may stitch in the air, and it completes mid-fall.
        player.restore_at_save_point()
        player.hp = player.max_hp - 1
        player.heal_cooldown = 0.0
        player.global_position = Vector2(100, -1500)
        player.velocity = Vector2.ZERO
        await frames(2)
        check(not player.is_on_floor(), crest + ": airborne fixture is actually falling")
        var readiness: Dictionary = player.get_heal_readiness()
        if bool(row.get("heal_airborne", false)):
            check(readiness.available, crest + ": HUD offers the airborne stitch")
            await pulse("heal", 1, 0)
            check(player.heal_timer > 0.0, crest + ": airborne heal input starts the channel")
            await frames(int(ceil(player.heal_duration * 60.0)) + 2)
            check(player.hp == player.max_hp and not player.is_on_floor(), crest + ": airborne stitch completes before landing")
        else:
            check(readiness.reason == "airborne" and not player._try_heal() and player.energy == player.max_energy, crest + ": heavy and record seals must land before healing")
        await stand()
        # Interruption follows the seal's own loss ratio.
        player.restore_at_save_point()
        player.hp = player.max_hp - 2
        player.energy = player.max_energy
        player.heal_cooldown = 0.0
        check(player._try_heal(), crest + ": interruption fixture starts a paid channel")
        await frames(4)
        player.arrival_guard_timer = 0.0
        var loss := int(ceil(player.heal_energy_cost * float(row.heal_interrupt_loss_ratio)))
        hp_before = player.hp
        player.take_damage(1, player.global_position + Vector2(80, 0), false)
        check(player.heal_timer == 0.0 and player.hp == hp_before - 1 and player.energy == mini(player.max_energy, player.max_energy - loss + player.energy_on_damage), crest + ": damage interrupts and keeps exactly the seal's refund")
        player.hurt_timer = 0.0
        await stand()
    check(styles.size() == 3, "Three seals heal in three different ways")
    # A heavier seal heals more per channel but is slower; the light one is the fastest.
    var bell: Dictionary = build.catalog.crests.bell
    var crimson: Dictionary = build.catalog.crests.crimson
    var salt: Dictionary = build.catalog.crests.salt
    check(int(bell.heal_amount) > int(crimson.heal_amount) and float(bell.heal_duration) > float(salt.heal_duration) and float(salt.heal_duration) > float(crimson.heal_duration), "Heavier heals take longer to channel")
    check(int(salt.heal_cost) < int(crimson.heal_cost) and float(salt.energy_gain_mult) < float(crimson.energy_gain_mult), "Record seal's cheaper heal offsets its slower thread gain")
    for crest in ["crimson", "bell", "salt"]:
        build.state.crest = crest
        check(build.equip_passives(["shell"]).ok and is_equal_approx(float(build.profile().heal_duration), float(build.catalog.crests[crest].heal_duration) * 1.15), crest + ": copper back clasp slows this seal's own heal by 15%")
        build.equip_passives([])

func switching_residue() -> void:
    var enemy: Area2D = load("res://scripts/enemy_actor.gd").new()
    enemy.configure({"id": "seal_residue_target", "hp": 200, "kind": "moss_larva"}, "", false, {})
    enemy.position = Vector2(400, 140)
    root.add_child(enemy)
    enemy.set_physics_process(false)
    enemy.contact_timer = 1000.0
    use_crest("crimson")
    await stand()
    player.line_stacks = 3
    player.line_expiry = 3.0
    player.heal_speed_timer = 1.5
    player.hp = player.max_hp - 1
    player.energy = player.max_energy
    check(player._try_heal(), "Residue fixture starts a crimson channel")
    var crimson_loss := int(ceil(player.heal_energy_cost * float(build.catalog.crests.crimson.heal_interrupt_loss_ratio)))
    var energy_paid: int = player.energy
    var hp_before: int = player.hp
    build.state.crest = "bell"
    player.apply_build_stats(build.profile())
    check(player.heal_timer == 0.0 and player.heal_reserved_cost == 0 and player.energy == energy_paid + player.heal_energy_cost * 0 + (int(build.catalog.crests.crimson.heal_cost) - crimson_loss), "Switching mid-heal settles under the old seal's rule")
    check(player.hp == hp_before, "Switching never completes or refreshes a heal")
    check(player.line_stacks == 0 and player.heal_speed_timer == 0.0 and player.heal_stability_timer == 0.0, "Crimson momentum and heal buffs do not follow into bell")
    player.bell_pressure = 2
    player.heal_stability_timer = 2.0
    enemy.salt_mark_timer = 4.0
    build.state.crest = "salt"
    player.apply_build_stats(build.profile())
    check(player.bell_pressure == 0 and player.heal_stability_timer == 0.0 and enemy.salt_mark_timer == 0.0, "Bell pressure and stale marks clear when switching to salt")
    check(player.heal_energy_cost == int(build.catalog.crests.salt.heal_cost) and not bool(player.build_profile.get("heal_airborne", true)), "Salt takes its own heal rule immediately")
    enemy.queue_free()
    await frames(2)

## Exhaustive: every adornment set each seal can legally equip.
func adornment_bounds() -> void:
    var ids: Array = build.catalog.passives.keys()
    var legal := 0
    for crest in ["crimson", "bell", "salt"]:
        build.state.crest = crest
        for mask in range(1 << ids.size()):
            var chosen := []
            for i in ids.size():
                if mask & (1 << i): chosen.append(ids[i])
            if not build.equip_passives(chosen).ok: continue
            legal += 1
            var profile: Dictionary = build.profile()
            var label: String = crest + " " + str(chosen)
            check(profile == build.profile(), label + ": profile is idempotent")
            check(int(profile.energy_per_hit) >= 12 and int(profile.energy_per_hit) <= 30, label + ": one hit grants 12-30 thread")
            check(float(profile.heal_cost) / float(profile.heal_amount) >= 40.0, label + ": healing still costs at least 40 thread per mask")
            check(int(profile.guard_refund) == 0, label + ": perfect guard never refunds thread")
            check(float(profile.heal_duration) >= 0.3 and float(profile.skill_cost_mult) >= 1.0, label + ": no adornment makes heals instant or skills cheaper")
            for key in ["energy_gain_mult", "melee_energy_mult", "move_mult", "knockback_mult", "status_buildup_mult", "ranged_range_mult", "skill_damage_mult"]:
                check(float(profile[key]) >= 0.5 and float(profile[key]) <= 1.5, label + ": " + key + " stays within 0.5-1.5")
            # Energy needed per heal in basic hits: at least two hits for every seal.
            check(int(ceil(float(profile.heal_cost) / float(profile.energy_per_hit))) >= 2, label + ": a heal costs at least two basic hits")
        build.equip_passives([])
    check(legal >= 30, "Adornment audit covers every legal set (" + str(legal) + ")")
    check(not build.equip_passives(["stride", "stride"]).ok, "The same adornment cannot be stacked twice")

func practice_energy() -> void:
    use_crest("crimson")
    var rack := Area2D.new()
    rack.set_script(load("res://scripts/seal_training_target.gd"))
    rack.name = "seal_identity_rack"
    rack.position = Vector2(155, 157)
    rack.configure({"id": "seal_identity_rack", "kind": "seal_training", "hp": 30, "visual_scale": 0.7, "body_size": [50, 46], "hurtbox_size": [58, 56], "hurtbox_offset": [0, 0], "speed": 0, "damage": 0}, "res://assets/ui/seals/ward.svg", false, {"attacks": []})
    root.add_child(rack)
    await stand()
    player.energy = 10
    player.facing = 1
    for swing in 3:
        await stand()
        await pulse("attack")
    check(player.energy > 10 and player.practice_energy == player.energy - 10, "Rack hits grant practice thread and record it")
    var practiced: int = player.practice_energy
    check(practiced > 0, "Practice thread is tracked")
    # Spending at the rack uses it up first; what is spent is not taken back twice.
    player.energy -= 5
    await frames(2)
    check(player.practice_energy <= player.energy, "Practice ledger never exceeds the meter")
    var before_leaving: int = player.energy
    var unspent: int = player.practice_energy
    await stand(Vector2(1200, 180))
    check(player.practice_energy == 0 and player.energy == before_leaving - unspent, "Leaving the rack takes back only the unspent practice thread")
    var enemy: Area2D = load("res://scripts/enemy_actor.gd").new()
    enemy.configure({"id": "seal_identity_real", "hp": 200, "kind": "moss_larva"}, "", false, {})
    enemy.position = Vector2(1255, 140)
    root.add_child(enemy)
    enemy.set_physics_process(false)
    enemy.contact_timer = 1000.0
    var real_before: int = player.energy
    await stand(Vector2(1200, 180))
    await pulse("attack")
    await frames(4)
    check(player.energy > real_before and player.practice_energy == 0, "Real enemies still grant thread that the player keeps")
    rack.queue_free()
    enemy.queue_free()
    await frames(2)
