extends SceneTree
## Runtime action/door/reward regression. Known source positions and breakable
## floor approach are test fixtures. Door actions and room walking use real input.
## Enemies are removed: this is not a complete damage-enabled six-region run.
const ROUTES := preload("res://scripts/world_routes.gd")
const STATE := preload("res://scripts/world_state.gd")
const SAVE := "user://world_upgrade_validation.json"
var scene: Node
var checks := 0
var failures := 0
var inputs := ["move_left", "move_right", "jump", "dash", "attack", "aim_down", "aim_up", "hook", "bell_guard", "lantern_phase", "crown_resonance", "interact"]

func _initialize() -> void:
    call_deferred("_run")

func _assert(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(label)

func _release() -> void:
    for action in inputs:
        if InputMap.has_action(action):
            Input.action_release(action)

func _transition_busy() -> bool:
    if not is_instance_valid(scene):
        return false
    var loader: Variant = scene.world_loader
    return scene.world_portal_request_pending or scene.chapter_transitioning or scene.world_loading or (is_instance_valid(loader) and loader.phase != "idle")

func _settle_transition() -> bool:
    for frame in range(2000):
        if is_instance_valid(current_scene) and current_scene.get("world_mode") == true:
            scene = current_scene
        if not _transition_busy():
            return true
        await process_frame
    _assert(false, "budgeted portal request/preflight/transition did not settle before action probe")
    _release()
    quit(1)
    await process_frame
    return false

func _tick(count: int = 1) -> void:
    if not await _settle_transition():
        return
    for unused in range(count):
        for actor in get_nodes_in_group("enemy"):
            actor.queue_free()
        await physics_frame
        if is_instance_valid(current_scene) and current_scene.get("world_mode") == true:
            scene = current_scene
        # A held interaction can queue the request during the physics yield.
        # Do not return control to assertions or fixture teardown mid-preflight.
        if not await _settle_transition():
            return

func _clean() -> void:
    for suffix in ["", ".tmp", ".bak"]:
        if FileAccess.file_exists(SAVE + suffix):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))

func _spawn(region: String, point: Vector2) -> void:
    _release()
    if is_instance_valid(scene):
        scene.queue_free()
        await process_frame
    _clean()
    scene = load("res://scenes/World.tscn").instantiate()
    scene.config_path = ROUTES.config_path(region)
    scene.world_resume = false
    scene.world_save_path = SAVE
    scene.entry_spawn_override_enabled = true
    scene.entry_spawn_override = point
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene = scene
    scene._close_overlays()
    await _tick(5)

func _walk_x(target: float, limit: int = 150) -> bool:
    _release()
    for unused in range(limit):
        var dx: float = target - scene.player.position.x
        if absf(dx) < 9:
            _release()
            await _tick(2)
            return true
        if dx > 0:
            Input.action_release("move_left")
            Input.action_press("move_right")
        else:
            Input.action_release("move_right")
            Input.action_press("move_left")
        await _tick()
    _release()
    return false

func _walk_lantern_workshop_tier(target_x: float) -> bool:
    # This workshop has two solid collision platforms. Reach them with normal
    # movement input; horizontal-only _walk_x cannot climb their side walls.
    var player: CharacterBody2D = scene.player
    if player.is_on_floor() and absf(player.global_position.y - 380.0) < 5.0:
        return await _walk_x(target_x)

    if not (player.is_on_floor() and absf(player.global_position.y - 490.0) < 5.0):
        # Start from the foyer side of the lower ledge, with room to rise before
        # the player's 17px half-width reaches its solid left edge.
        if not await _walk_x(7670.0):
            return _step_timeout("lower takeoff", Vector2(7670.0, 490.0))
        if not await _jump_to_landing(7800.0, 490.0, 12):
            return false

    # Move back to the low step's left side. This gives the player enough
    # horizontal run to clear the upper step's underside during the jump.
    if not await _walk_x(7758.0):
        return _step_timeout("upper takeoff", Vector2(7758.0, 490.0))
    return await _jump_to_landing(target_x, 380.0, 20)

func _jump_to_landing(target_x: float, target_y: float, jump_hold_frames: int) -> bool:
    _release()
    var player: CharacterBody2D = scene.player
    if not player.is_on_floor():
        for unused in range(90):
            await _tick()
            if player.is_on_floor():
                break
    if not player.is_on_floor():
        return _step_timeout("takeoff was not grounded", Vector2(target_x, target_y))

    Input.action_press("jump")
    for frame in range(180):
        var dx: float = target_x - player.global_position.x
        if frame == jump_hold_frames:
            Input.action_release("jump")
        if absf(dx) < 7.0:
            _release()
        else:
            _set_horizontal_axis(signf(dx))
        await _tick()
        if frame > jump_hold_frames and player.is_on_floor() and absf(player.global_position.x - target_x) < 18.0 and absf(player.global_position.y - target_y) < 5.0:
            _release()
            return true
    _release()
    return _step_timeout("landing timeout", Vector2(target_x, target_y))

func _set_horizontal_axis(direction: float) -> void:
    if direction > 0:
        Input.action_release("move_left")
        Input.action_press("move_right")
    elif direction < 0:
        Input.action_release("move_right")
        Input.action_press("move_left")
    else:
        Input.action_release("move_left")
        Input.action_release("move_right")

func _step_timeout(stage: String, target: Vector2) -> bool:
    push_warning("CH05 workshop " + stage + " target=" + str(target) + " actual=" + _player_state())
    return false

func _player_state() -> String:
    var player: CharacterBody2D = scene.player
    return "pos=%s velocity=%s floor=%s wall=%s" % [str(player.global_position), str(player.velocity), str(player.is_on_floor()), str(player.is_on_wall())]

func _pulse(action: String, frames: int = 2) -> void:
    Input.action_press(action)
    await _tick(frames)
    Input.action_release(action)
    await _tick(2)

func _do_action(ability: String, gate: Dictionary) -> void:
    scene.player.energy = scene.player.max_energy
    match ability:
        "thread_dash":
            await _pulse("dash", 5)
        "silk_wall_grip":
            Input.action_press("move_right")
            await _tick(20)
            await _pulse("jump", 8)
            await _tick(12)
            await _pulse("jump", 5)
        "double_thread_jump":
            await _pulse("jump", 8)
            await _pulse("jump", 4)
        "echo_hook":
            Input.action_press("aim_up")
            await _pulse("hook", 5)
        "bell_guard":
            await _pulse("bell_guard", 5)
        "thorn_downstrike":
            # Repositioning onto the authored sealed floor is explicit setup;
            # the air jump/down attack and collapse use actual player physics.
            var r: Array = gate.rect
            scene.player.position = Vector2(float(r[0]) + float(r[2]) * 0.5, float(r[1]) - 2)
            scene.player.velocity = Vector2.ZERO
            await _tick(5)
            await _pulse("jump", 8)
            Input.action_press("aim_down")
            await _pulse("attack", 5)
        "lantern_phase":
            await _pulse("lantern_phase", 12)
        "crown_resonance":
            await _pulse("crown_resonance", 5)
    _release()
    await _tick(40)

func _verify_late_branch(region: String, portal_id: String, ability: String = "") -> void:
    var entry: Dictionary = ROUTES.portal(region, portal_id)
    var source := Vector2(float(entry.position[0]), float(entry.position[1]))
    await _spawn(region, source)
    if not ability.is_empty():
        scene._activate_world_portal(scene.get_node(portal_id))
        _assert(not scene.chapter_transitioning, portal_id + ": ability lock rejects fresh traveler")
        scene._add_inventory_item(ability, 1, false)
        scene._sync_player_abilities()
    scene._activate_world_portal(scene.get_node(portal_id))
    await _tick(10)
    var arrival := Vector2(float(entry.target_spawn[0]), float(entry.target_spawn[1]))
    _assert(String(scene.config.id) == String(entry.target_config_id), portal_id + ": real later-region branch replaces scene")
    _assert(scene.player.position.distance_to(arrival) < 85, portal_id + ": branch has supported paired arrival")
    if not ability.is_empty():
        _assert(int(scene.inventory_counts.get(ability, 0)) > 0, portal_id + ": branch preserves acquired ability")
    if not String(entry.get("unlock_shortcut_id", "")).is_empty():
        _assert(bool(scene.story_flags.get("world_shortcut_" + String(entry.unlock_shortcut_id), false)), portal_id + ": far-side service latch persists")
    scene._activate_world_portal(scene.get_node(String(entry.target_portal_id)))
    await _tick(10)
    _assert(String(scene.config.id) == region and scene.player.position.distance_to(source) < 85, portal_id + ": branch can return without boss-clear dependency")

func _run() -> void:
    var data: Dictionary = ROUTES._data()
    await _verify_late_branch("demo_ch03_saltwhite_archive", "upgrade_archive_obsidian_branch_a", "double_thread_jump")
    await _verify_late_branch("demo_ch04_broken_string_greenhouse", "upgrade_greenhouse_crown_branch_a", "lantern_phase")
    var near_entry: Dictionary = ROUTES.portal("demo_ch02_rain_foundry_canal", "upgrade_obsidian_rain_return_b")
    await _spawn("demo_ch02_rain_foundry_canal", Vector2(float(near_entry.position[0]), float(near_entry.position[1])))
    scene._activate_world_portal(scene.get_node("upgrade_obsidian_rain_return_b"))
    _assert(not scene.chapter_transitioning, "old service line cannot open from the near side")
    await _verify_late_branch("demo_ch05_obsidian_pilgrim_road", "upgrade_obsidian_rain_return_a")
    var targets: Array = data.get("ability_backtracks", [])
    _assert(targets.size() == 20, "16 return workshops plus four acquisition practice workshops")
    for target in targets:
        var region := String(target.region_id)
        var ability := String(target.ability_id)
        var gate_id := String(target.gate_id)
        var source := Vector2(float(target.source_position[0]), float(target.source_position[1]))
        await _spawn(region, source)
        var entry: Dictionary = ROUTES.portal(region, String(target.entry_portal_id))
        var arrival := Vector2(float(entry.target_spawn[0]), float(entry.target_spawn[1]))
        scene._activate_world_portal(scene.get_node(String(target.entry_portal_id)))
        await _tick(10)
        _assert(scene.player.position.distance_to(arrival) < 85, gate_id + ": paired route arrives at workshop foyer")
        scene._close_overlays()
        scene.player.hurt_timer = 0.0
        _assert(scene.locked_gate_bodies.has(gate_id), gate_id + ": closed before acquiring ability")
        var gate: Dictionary = {}
        for value in scene.config.locked_gates:
            if String(value.id) == gate_id:
                gate = value
        if gate.is_empty():
            _assert(false, gate_id + ": fixture missing actual gate")
            continue
        _assert(await _walk_x(float(target.approach_position[0])), gate_id + ": walk from foyer to action approach")
        scene._add_inventory_item(ability, 1, false)
        scene._refresh_ability_gates()
        _assert(scene.locked_gate_bodies.has(gate_id), gate_id + ": possession alone does not open action seal")
        var currency_before: int = scene.currency_count
        var reward_positions: Dictionary = {}
        for reward_id in target.reward_ids:
            var reward: Node = scene.get_node_or_null(String(reward_id))
            _assert(reward != null, gate_id + ": reward node instantiated before opening")
            if reward != null:
                reward_positions[String(reward_id)] = reward.position
        await _do_action(ability, gate)
        _assert(not scene.locked_gate_bodies.has(gate_id), gate_id + ": real ability input opens authored seal")
        if scene.locked_gate_bodies.has(gate_id):
            print("ACTION_DEBUG %s pos=%s locked=%s hurt=%s attack=%s" % [ability, str(scene.player.position), str(scene.player.ui_input_locked), str(scene.player.hurt_timer), str(scene.player.attack_timer)])
            continue
        for reward_id in target.reward_ids:
            if reward_positions.has(String(reward_id)):
                var reached_reward := false
                if String(target.room_id) == "upgrade_lantern_phase_3":
                    reached_reward = await _walk_lantern_workshop_tier(float(reward_positions[String(reward_id)].x))
                else:
                    reached_reward = await _walk_x(reward_positions[String(reward_id)].x)
                _assert(reached_reward, gate_id + ": opened gate permits reward approach")
                await _tick(5)
                _assert(bool(scene.world_collected_ids.get(String(reward_id), false)), gate_id + ": reward collection persists unique ID")
        _assert(scene.currency_count > currency_before, gate_id + ": reward grants spendable currency")
        var saved := STATE.new()
        _assert(saved.read(SAVE), gate_id + ": save readable after action and rewards")
        _assert(bool(saved.data.story_flags.get("action_gate_" + gate_id, false)), gate_id + ": action unlock persisted on disk")
        if ability == "thorn_downstrike":
            var bottom_id := String(target.room_id) + "_well_lift_b"
            var bottom: Dictionary = ROUTES.portal(region, bottom_id)
            _assert(await _walk_x(float(bottom.position[0])), gate_id + ": collapsed well has supported return access")
            scene._activate_world_portal(scene.get_node(bottom_id))
            await _tick(10)
            _assert(bool(scene.story_flags.get("world_shortcut_" + String(bottom.unlock_shortcut_id), false)), gate_id + ": far-side return lift opens permanently")
        _assert(await _walk_x(arrival.x), gate_id + ": safely walk back to foyer")
        scene._activate_world_portal(scene.get_node(String(entry.target_portal_id)))
        await _tick(10)
        _assert(scene.player.position.distance_to(source) < 85, gate_id + ": workshop returns to actual original platform")
        _assert(not scene.locked_gate_bodies.has(gate_id), gate_id + ": action gate remains open after real scene replacement")
        for reward_id in target.reward_ids:
            _assert(scene.get_node_or_null(String(reward_id)) == null, gate_id + ": collected reward does not respawn")
        print("WORKSHOP_ACTION_PASS " + gate_id)
    _release()
    if is_instance_valid(scene):
        scene.queue_free()
        await process_frame
    _assert(await preload("res://scripts/audio_retirement.gd").drain(self), "AudioServer releases retired seal playback before shutdown")
    _clean()
    print("WORLD_UPGRADE checks=%d failures=%d enemy_removal=true fixture_positioning=true" % [checks, failures])
    # Let the async test stack release its final saved-state Resource first.
    # Direct quit can race reference teardown on faster CI runners.
    call_deferred("quit", 1 if failures > 0 else 0)
