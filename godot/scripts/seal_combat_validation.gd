extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
    call_deferred("_run")
func check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error(label)
func frames(count: int) -> void:
    for i in count:
        await physics_frame
func _run() -> void:
    var floor := StaticBody2D.new()
    var shape := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = Vector2(1800,20)
    shape.shape = rectangle
    floor.position = Vector2(0,10)
    floor.add_child(shape)
    root.add_child(floor)
    var player = load("res://scenes/Player.tscn").instantiate()
    root.add_child(player)
    await frames(8)
    player.set_physics_process(false)
    player.build_system = null
    player.apply_build_stats({"crest_id":"crimson", "crimson_repaired":true})
    player._basic_seal_hit()
    player._basic_seal_hit()
    player._basic_seal_hit()
    player._basic_seal_hit()
    check(player.line_stacks == 3, "line stack cap is three")
    player.energy = 100
    player.configure_selected_skill({"id":"cleave", "kind":"melee", "range":100, "energy_cost":25, "damage":2, "windup":0.12, "active":0.14, "recovery":0.2})
    check(player.cast_selected_skill(), "empowered thrust begins")
    check(not player.can_ignore_enemy_contact(Vector2(50,0)), "thrust grants no enemy contact immunity")
    check(player.energy == 75 and player.line_stacks == 0 and player.attack_range == 135, "thrust spends once and extends attack reach only")
    check(not player.cast_selected_skill(), "recovery cannot recast")
    check(player.velocity.x == 0, "empowerment never increases displacement")
    player._reset_traversal_state()
    player.skill_cooldown = 0
    player._basic_seal_hit()
    player._seal_tick(4)
    check(player.line_stacks == 0, "line expires without hits")
    player.apply_build_stats({"crest_id":"bell"})
    player.bell_guard_unlocked = true
    player.energy = 100
    for i in 3:
        player.guard_cooldown = 0
        player.hurt_timer = 0
        check(player._try_guard(), "guard starts with prepaid cost")
        player.take_damage(1, Vector2(100,0), true)
    check(player.bell_pressure == 2 and player.energy == 88, "precise guard caps pressure and cannot generate free energy")
    player.hurt_timer = 0
    player.guard_cooldown = 0
    player._try_guard()
    var before: int = player.hp
    player.take_damage(1, Vector2(100,0), false)
    check(player.hp == before - 1, "unblockable attack bypasses guard")
    player.hurt_timer = 0
    player.heal_stability_timer = 3
    before = player.hp
    player.take_damage(1, Vector2(100,0))
    check(player.hp == before - 1 and player.velocity == Vector2.ZERO and player.heal_stability_timer == 0, "healing stability prevents one knockback without preventing damage")
    player.apply_build_stats({"crest_id":"salt"})
    var enemy = load("res://scripts/enemy_actor.gd").new()
    enemy.configure({"id":"test", "hp":100, "kind":"moss_larva"}, "", false, {})
    enemy.position = Vector2(90,-20)
    root.add_child(enemy)
    enemy.set_physics_process(false)
    enemy.apply_salt_mark(5)
    enemy.extend_salt_mark_once(2)
    enemy.extend_salt_mark_once(2)
    check(enemy.salt_mark_timer == 7, "heal extends salt mark once only")
    check(enemy.consume_salt_mark() and not enemy.consume_salt_mark(), "salt mark consumed exactly once")
    enemy.apply_salt_mark(5)
    player._seal_heal_completed()
    check(enemy.salt_mark_timer == 7, "salt healing extends existing nearby mark")
    enemy.apply_trip(0.7)
    check(enemy.trip_timer > 0, "ordinary enemy trips")
    enemy.is_boss = true
    enemy.combat_resistance = {"trip_immune":true,"lure_immune":true,"snare_mult":0.35}
    enemy.trip_timer = 0
    enemy.apply_trip(1)
    enemy.investigate_lure(Vector2(100,0),2)
    enemy.apply_snare(2)
    check(enemy.trip_timer == 0 and enemy.lure_timer == 0 and is_equal_approx(enemy.snare_timer,0.7), "boss resists trip lure and receives weaker snare from explicit data")
    enemy.is_boss = false
    enemy.combat_resistance = {"trip_immune":false,"lure_immune":false,"snare_mult":1}
    enemy.apply_target_interference(2)
    enemy.investigate_lure(Vector2(150,-42),1)
    check(enemy.interference_timer == 2 and enemy.lure_timer == 1, "fog and lure have bounded enemy state")
    player.hp = 2
    player.energy = 53
    player.line_stacks = 3
    player.bell_pressure = 2
    player.dash_unlocked = true
    player.double_jump_unlocked = true
    player.apply_build_stats({"crest_id":"crimson"})
    check(player.hp == 2 and player.energy == 53, "switch does not refresh health or energy")
    check(player.line_stacks == 0 and player.bell_pressure == 0 and enemy.salt_mark_timer == 0, "switch clears temporary mechanisms and marks")
    check(player.dash_unlocked and player.double_jump_unlocked, "switch preserves permanent exploration abilities")
    var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/build_catalog.json"))
    for id in catalog.skills:
        catalog.skills[id]["id"] = id
    for id in catalog.tools:
        catalog.tools[id]["id"] = id
    enemy.reset_for_respawn()
    enemy.set_physics_process(false)
    enemy.hp = 100
    enemy.max_hp = 100
    enemy.position = Vector2(100,-20)
    player.global_position = Vector2.ZERO
    player.velocity = Vector2.ZERO
    player.hurt_timer = 0
    player._reset_traversal_state()
    player.skill_cooldown = 0
    player.energy = 100
    player.configure_selected_skill(catalog.skills.cleave)
    check(player.cast_selected_skill(), "actual catalog thrust starts")
    var enemy_before: int = enemy.hp
    player._update_attack(0.1)
    check(enemy.hp == enemy_before, "thrust preparation cannot hit")
    player._update_attack(0.12)
    check(enemy.hp < enemy_before and player.global_position.x > 0, "thrust active frame hits with real swept movement")
    player._reset_traversal_state()
    player.skill_cooldown = 0
    player.global_position = Vector2.ZERO
    player.velocity = Vector2.ZERO
    player.apply_build_stats({"crest_id":"salt"})
    enemy.global_position = Vector2(100,-20)
    enemy.clear_salt_mark()
    player.energy = 100
    player.configure_selected_skill(catalog.skills.needle)
    check(player.cast_selected_skill(), "actual needle starts")
    player._update_attack(float(catalog.skills.needle.windup) + 0.01)
    await frames(14)
    check(enemy.salt_mark_timer > 0 and player.energy == 80, "single target needle marks without self refund")
    player._reset_traversal_state()
    player.skill_cooldown = 0
    player.configure_selected_skill(catalog.skills.snare)
    check(player.cast_selected_skill(), "actual snare starts")
    player._update_attack(float(catalog.skills.snare.windup) + 0.01)
    await frames(2)
    check(enemy.salt_mark_timer == 0 and enemy.snare_timer > float(catalog.skills.snare.duration), "placed snare consumes salt mark for bounded extended control")
    player._reset_traversal_state()
    player.skill_cooldown = 0
    player.configure_selected_skill(catalog.skills.ward)
    check(player.cast_selected_skill(), "actual ward starts")
    player._update_attack(float(catalog.skills.ward.windup) + 0.01)
    check(player.guard_timer > 0, "ward guard begins only in active stage")
    player.hurt_timer = 0
    player.take_damage(1, Vector2(100,0))
    check(player.guard_timer == 0 and player.energy == 30, "ward blocks a prescribed forward hit without energy refund")
    player._reset_traversal_state()
    player.hurt_timer = 0
    player.skill_cooldown = 0
    player.apply_build_stats({"crest_id":"crimson", "crimson_repaired":true})
    player._basic_seal_hit()
    player._basic_seal_hit()
    player._basic_seal_hit()
    player.energy = 100
    player.configure_selected_skill(catalog.skills.crosscut)
    enemy.global_position = Vector2(-45,-20)
    enemy_before = enemy.hp
    check(player.cast_selected_skill(), "actual crosscut starts")
    var original_position: Vector2 = player.global_position
    player._update_attack(float(catalog.skills.crosscut.windup) + 0.01)
    check(enemy.hp < enemy_before and player.global_position == original_position and player.energy == 80, "crosscut covers rear with no displacement and refund below cost")
    player._reset_traversal_state()
    player.skill_cooldown = 0
    player.global_position = Vector2.ZERO
    player.velocity = Vector2.ZERO
    player.set_physics_process(true)
    await frames(3)
    player.set_physics_process(false)
    player.apply_build_stats({"crest_id":"bell"})
    player.bell_pressure = 2
    player.energy = 100
    player.configure_selected_skill(catalog.skills.shockwave)
    enemy.global_position = Vector2(100,-20)
    enemy_before = enemy.hp
    check(player.cast_selected_skill(), "grounded catalog shockwave starts")
    player._update_attack(float(catalog.skills.shockwave.windup) + 0.01)
    await frames(14)
    check(enemy.hp < enemy_before and player.bell_pressure == 0 and player.energy == 65, "shockwave consumes bell pressure and only paid energy")
    for field in get_nodes_in_group("player_snare_field"):
        field.queue_free()
    player._reset_traversal_state()
    player.hurt_timer = 0
    player.skill_cooldown = 0
    player.energy = 100
    enemy.global_position = Vector2(600,-20)
    check(player.cast_tool(catalog.tools.mine), "first finite groundtrap placed")
    player._reset_traversal_state()
    check(player.cast_tool(catalog.tools.mine), "second finite groundtrap placed")
    player._reset_traversal_state()
    check(not player.cast_tool(catalog.tools.mine), "third trap denied at instance cap")
    for trap in get_nodes_in_group("player_trap"):
        trap.queue_free()
    await frames(2)
    player._reset_traversal_state()
    check(player.cast_tool(catalog.tools.shard), "ballistic pot starts")
    var pot = root.get_child(root.get_child_count()-1)
    check(pot.ballistic_velocity.y < 0, "pot launches upward on an arc")
    pot.set_physics_process(false)
    pot.landed = true
    pot.global_position = Vector2(100,-5)
    pot.warning_timer = 0.35
    enemy.global_position = Vector2(100,-20)
    enemy_before = enemy.hp
    pot._physics_process(0.1)
    check(enemy.hp == enemy_before, "landed pot warns before explosion")
    pot._physics_process(0.26)
    check(enemy.hp < enemy_before and player.energy == 100, "warned pot explodes without energy return")
    pot.queue_free()
    player._reset_traversal_state()
    enemy.ai_commands = [{"type":"projectile"}]
    enemy.interference_timer = 0
    enemy.lure_timer = 0
    enemy.state = "patrol"
    check(player.cast_tool(catalog.tools.fog), "fog tool starts")
    await frames(2)
    check(enemy.interference_timer > 0 and enemy._target_player() == null, "fog denies ordinary ranged acquisition")
    player._reset_traversal_state()
    enemy.interference_timer = 0
    check(player.cast_tool(catalog.tools.lure), "lure tool starts")
    await frames(2)
    check(enemy.lure_timer > 0 and enemy._target_player() == null, "lure prompts bounded investigation")
    enemy._tick_timers(3.0)
    check(enemy._target_player() == player, "enemy can reacquire player after investigation")
    player._reset_traversal_state()
    player.guard_cooldown = 0
    player.hurt_timer = 0
    player.energy = 100
    player._try_guard()
    var practice_hp: int = player.hp
    check(player.practice_guard_contact(Vector2(100,0)) and player.hp == practice_hp and player.energy == 96, "practice precise guard cannot create health or energy")
    check(not player.practice_guard_contact(Vector2(100,0)), "practice without active guard is harmless")
    player.hurt_timer = 0
    player.guard_cooldown = 0
    player._try_guard()
    var effect = load("res://scripts/enemy_attack_effect.gd").new()
    effect.effect_kind = "wave"
    effect.position = player.global_position - Vector2(0,42)
    effect.set_meta("blockable", false)
    root.add_child(effect)
    effect.set_physics_process(false)
    effect._physics_process(0.01)
    check(player.hp == practice_hp - 1, "unblockable spawned effect bypasses guard consistently")
    effect.queue_free()
    player._reset_traversal_state()
    player.hp = 5
    player.death_timer = 0
    player.hurt_timer = 0
    player.skill_cooldown = 0
    player.energy = 100
    player.global_position = Vector2.ZERO
    player.velocity = Vector2.ZERO
    player.configure_selected_skill(catalog.skills.ward)
    check(player.cast_selected_skill(), "ward audit starts")
    check(is_equal_approx(player.attack_active_time, float(catalog.skills.ward.duration)), "guard effectiveness is represented by its active phase")
    var prepaid: int = player.energy
    player.take_damage(1,Vector2(100,0),false)
    check(player.attack_timer == 0 and player.guard_timer == 0 and player.energy == prepaid + player.energy_on_damage, "preparation interruption stops guard without refunding skill payment")
    player._reset_traversal_state()
    player.hurt_timer = 0
    player.skill_cooldown = 0
    var wall := StaticBody2D.new()
    var wall_shape := CollisionShape2D.new()
    var wall_rectangle := RectangleShape2D.new()
    wall_rectangle.size = Vector2(10,160)
    wall_shape.shape = wall_rectangle
    wall.position = Vector2(45,-80)
    wall.add_child(wall_shape)
    root.add_child(wall)
    await frames(2)
    enemy.global_position = Vector2(100,-20)
    enemy.lure_timer = 0
    enemy.state = "patrol"
    enemy.investigate_lure(Vector2(0,-42),1)
    check(enemy.lure_timer == 0, "lure cannot draw investigation through a solid wall")
    enemy.ai_profile["lure_eligible"] = false
    enemy.investigate_lure(Vector2(120,-42),1)
    check(enemy.lure_timer == 0, "explicitly ineligible enemies ignore lure")
    player.energy = 100
    player.configure_selected_skill(catalog.skills.cleave)
    enemy_before = enemy.hp
    check(player.cast_selected_skill(), "thrust against wall starts")
    player._update_attack(float(catalog.skills.cleave.windup) + 0.08)
    check(player.global_position.x < 35 and enemy.hp == enemy_before, "thrust displacement and damage stop at solid terrain")
    player._reset_traversal_state()
    player.skill_cooldown = 0
    player.global_position = Vector2.ZERO
    player.energy = 100
    player.configure_selected_skill(catalog.skills.snare)
    check(player.cast_selected_skill(), "field against wall starts")
    player._update_attack(float(catalog.skills.snare.windup) + 0.01)
    var newest_field: Node2D = null
    for field in get_nodes_in_group("player_snare_field"):
        if not field.is_queued_for_deletion():
            newest_field = field
    check(newest_field != null and newest_field.global_position.x < 45, "field placement clamps to near side of terrain")
    await frames(2)
    check(enemy.hp == enemy_before, "placed field cannot damage through its blocking wall")
    if newest_field != null:
        newest_field.queue_free()
    player._reset_traversal_state()
    player.snare_timer = 2
    player.apply_build_stats({"crest_id":"crimson","status_buildup_mult":0.8})
    player._seal_heal_completed()
    check(player.snare_timer == 2, "completed healing does not cleanse existing negative status")
    player.snare_timer = 0
    player.apply_snare(2)
    check(is_equal_approx(player.snare_timer,1.6), "status fragment reduces only new buildup in postheal window")
    wall.queue_free()
    await frames(2)
    player.snare_timer = 0
    player.apply_build_stats({"crest_id":"bell"})
    player.hurt_timer = 0
    player.energy = 100
    player.skill_cooldown = 0
    player.configure_selected_skill(catalog.skills.ward)
    check(player.cast_selected_skill() and not player.can_deflect_projectile(), "ward preparation cannot reflect a projectile")
    player._update_attack(float(catalog.skills.ward.windup) + 0.01)
    check(not player.can_deflect_projectile(), "ward active frame remains defense rather than slash reflection")
    var ward_hp: int = player.hp
    var guard_projectile = load("res://scripts/enemy_attack_effect.gd").new()
    guard_projectile.effect_kind = "projectile"
    guard_projectile.position = player.global_position + Vector2(10,-42)
    guard_projectile.set_meta("blockable",true)
    root.add_child(guard_projectile)
    guard_projectile.set_physics_process(false)
    guard_projectile._physics_process(0.01)
    check(player.hp == ward_hp and player.bell_pressure == 1 and not guard_projectile.reflected, "eligible projectile is physically guarded and builds pressure without reflection")
    guard_projectile.queue_free()
    player._reset_traversal_state()
    player.hurt_timer = 0
    player._start_attack(&"attack_1")
    check(not player.can_deflect_projectile(), "ordinary slash preparation cannot reflect")
    player._update_attack(player.attack_windup + 0.01)
    check(player.can_deflect_projectile(), "ordinary slash can deflect only during actual active frame")
    var unblockable_projectile = load("res://scripts/enemy_attack_effect.gd").new()
    unblockable_projectile.effect_kind = "projectile"
    unblockable_projectile.position = player.global_position + Vector2(10,-42)
    unblockable_projectile.set_meta("blockable",false)
    root.add_child(unblockable_projectile)
    unblockable_projectile.set_physics_process(false)
    unblockable_projectile._physics_process(0.01)
    check(player.hp == ward_hp - 1 and not unblockable_projectile.reflected, "unblockable projectile cannot be reflected even by active slash")
    unblockable_projectile.queue_free()
    player._reset_traversal_state()
    player.hurt_timer = 0
    player.skill_cooldown = 0
    player.global_position = Vector2(0,-200)
    player.configure_selected_skill({"id":"shockwave","kind":"wave","energy_cost":35})
    player.set_physics_process(true)
    await frames(1)
    player.set_physics_process(false)
    player.energy = 100
    check(not player.cast_selected_skill() and player.energy == 100, "airborne grounded-wave denied without resource spend")
    await thread_skill_limits(player)
    enemy.queue_free()
    player.queue_free()
    floor.queue_free()
    await frames(100)
    await natural_pot_landings(catalog)
    failures += await preload("res://scripts/player_skill_art_validation.gd").new().run(self)
    print("SEAL_COMBAT_VALIDATION %s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL",checks,failures])
    quit(0 if failures == 0 else 1)

## Real ballistic flight and terrain contact; the older pot test above starts
## with an already-landed fixture and cannot detect expiry during its fuse.
func natural_pot_landings(catalog: Dictionary) -> void:
    for direction in [-1, 1]:
        for lower_floor in [0.0, 20.0]:
            await natural_pot_case(catalog, direction, lower_floor, false)
    # A floor below the original flight lifetime remains out of reach. Waiting
    # for a fuse must not turn a missed throw into an unbounded falling object.
    await natural_pot_case(catalog, 1, 180.0, true)
    await natural_pot_case(catalog, 1, 0.0, true, {"range":80.0, "duration":5.0})
    await natural_pot_case(catalog, 1, 0.0, false, {}, true)

func natural_pot_case(catalog: Dictionary, direction: int, lower_floor: float, expires_in_air: bool, limits: Dictionary = {}, blocked: bool = false) -> void:
    var label := "natural pot direction=%d lower_floor=%d range_limited=%s blocked=%s" % [direction, int(lower_floor), not limits.is_empty(), blocked]
    var stage := Node2D.new()
    stage.position = Vector2(2000, 700)
    root.add_child(stage)
    var ground := StaticBody2D.new()
    var floor_shape := CollisionShape2D.new()
    var floor_rect := RectangleShape2D.new()
    floor_rect.size = Vector2(1200, 20)
    floor_shape.shape = floor_rect
    ground.position.y = lower_floor + 10
    ground.add_child(floor_shape)
    stage.add_child(ground)
    if lower_floor > 0:
        var ledge := StaticBody2D.new()
        var ledge_shape := CollisionShape2D.new()
        var ledge_rect := RectangleShape2D.new()
        ledge_rect.size = Vector2(120, 20)
        ledge_shape.shape = ledge_rect
        ledge.position = Vector2(-direction * 320, 10)
        ledge.add_child(ledge_shape)
        stage.add_child(ledge)
    var caster = load("res://scenes/Player.tscn").instantiate()
    caster.position = Vector2(-direction * 300, 0)
    stage.add_child(caster)
    await frames(8)
    check(caster.is_on_floor(), label + " begins on a real launch floor")
    caster.set_physics_process(false)
    caster.facing = direction
    var target = load("res://scripts/enemy_actor.gd").new()
    target.configure({"id":"pot_fuse_target", "hp":10, "kind":"moss_larva", "hurtbox_size":[40,40], "hurtbox_offset":[0,0]}, "", false, {})
    target.position = Vector2(0, lower_floor - 20)
    stage.add_child(target)
    target.set_physics_process(false)
    if blocked:
        var wall := StaticBody2D.new()
        var wall_shape := CollisionShape2D.new()
        var wall_rect := RectangleShape2D.new()
        wall_rect.size = Vector2(20, 160)
        wall_shape.shape = wall_rect
        wall.position = Vector2(-60, -80)
        wall.add_child(wall_shape)
        stage.add_child(wall)
        await frames(2)
    var hp_before: int = target.hp
    var energy_before: int = caster.energy
    var payload: Dictionary = catalog.tools.shard.duplicate(true)
    payload.merge(limits, true)
    check(caster.cast_tool(payload), label + " launches the production pot")
    var pot: Node2D
    for child in stage.get_children():
        if child.get_script() == preload("res://scripts/player_tool_effect.gd"):
            pot = child
    check(pot != null, label + " creates one physical effect")
    var observed_landing := false
    var warned_past_flight_limit := false
    var damaged_during_warning := false
    var landed_frame := -1
    var damage_frame := -1
    for frame in 100:
        await frames(1)
        if target.hp != hp_before and damage_frame < 0:
            damage_frame = frame
        if is_instance_valid(pot) and not pot.is_queued_for_deletion() and pot.landed:
            observed_landing = true
            if landed_frame < 0:
                landed_frame = frame
            if pot.warning_timer > 0:
                damaged_during_warning = damaged_during_warning or target.hp != hp_before
                warned_past_flight_limit = warned_past_flight_limit or pot.elapsed >= float(payload.duration)
    if expires_in_air:
        check(not observed_landing and target.hp == hp_before, label + " preserves airborne expiry without damage")
    else:
        check(observed_landing, label + " reaches the floor without forcing landed state")
        check(warned_past_flight_limit and not damaged_during_warning, label + " finishes its full landed warning beyond the flight limit")
        if blocked:
            check(target.hp == hp_before, label + " cannot damage through its landing wall")
        else:
            var warning_seconds := float(damage_frame - landed_frame) / float(Engine.physics_ticks_per_second)
            check(damage_frame > landed_frame and absf(warning_seconds - 0.35) <= 2.0 / Engine.physics_ticks_per_second, label + " measures the actual 0.35-second fuse")
            check(target.hp == hp_before - int(catalog.tools.shard.damage), label + " explodes once for catalog damage")
    check(not is_instance_valid(pot) or pot.is_queued_for_deletion(), label + " retires its gameplay effect")
    check(caster.energy == energy_before, label + " never generates combat energy")
    print("POT_FLIGHT_CASE direction=%d drop=%d range_limited=%s blocked=%s landed=%s warned_after_limit=%s damage=%d" % [direction, int(lower_floor), not limits.is_empty(), blocked, observed_landing, warned_past_flight_limit, hp_before - target.hp])
    stage.queue_free()
    await frames(8)

## C03: thread cost and the action's own timing limit every skill; the
## catalog cooldown is only a short recovery lock, never the main gate.
func thread_skill_limits(player) -> void:
    var build = preload("res://scripts/build_system.gd").new()
    build.state.unlocked_crests = build.catalog.crests.keys()
    build.state.unlocked_skills = build.catalog.skills.keys()
    build.state.mechanisms = ["crimson", "bell", "salt"]
    player.build_system = build
    player.global_position = Vector2(0, -2)
    player.velocity = Vector2.ZERO
    player.set_physics_process(true)
    await frames(6)
    for id in build.catalog.skills:
        var row: Dictionary = build.catalog.skills[id]
        var crest := ""
        var slot := -1
        for candidate in build.catalog.crests:
            for index in 2:
                if crest.is_empty() and build._slot_accepts("thread_skill", index, id, candidate):
                    crest = candidate
                    slot = index
        check(not crest.is_empty(), id + ": some seal can equip it in a thread slot")
        if crest.is_empty(): continue
        build.state.crest = crest
        build.state.equipped_families.thread_skill = [id, ""] if slot == 0 else ["", id]
        build._normalize_active_slots()
        build.cooldowns.clear()
        player.apply_build_stats(build.profile())
        player.global_position = Vector2(0, -2)
        player.velocity = Vector2.ZERO
        await frames(4)
        var action: float = float(row.windup) + float(row.active) + float(row.recovery) + (float(row.get("duration", 0.0)) if String(row.kind) == "defense" else 0.0)
        check(float(row.cooldown) <= maxf(action + 0.4, 2.0), id + ": cooldown is a short recovery lock, not a multi-second gate")
        player.energy = player.max_energy
        var cost := int(build.selected_skill(slot).energy_cost)
        var casts := 0
        for attempt in 12:
            var before: int = player.energy
            if not player.cast_selected_skill(slot):
                check(player.energy == before, id + ": a refused cast spends nothing")
                break
            casts += 1
            check(player.energy == before - cost, id + ": each cast pays its listed thread")
            var spent: int = player.energy
            check(not player.cast_selected_skill(slot) and player.energy == spent, id + ": the running action cannot be recast or paid twice")
            for tick in 240:
                await frames(1)
                if player.attack_timer <= 0.0 and float(build.cooldowns.get(id, 0.0)) <= 0.0: break
            player.global_position = Vector2(0, -2)
            player.velocity = Vector2.ZERO
        check(casts == int(player.max_energy / cost), id + ": a full meter pays for exactly %d casts (got %d)" % [int(player.max_energy / cost), casts])
    player.set_physics_process(false)
    player.build_system = null

