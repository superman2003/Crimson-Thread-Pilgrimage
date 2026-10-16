extends SceneTree
## Runtime action/door/reward regression. Known source positions and breakable
## floor approach are test fixtures. Door actions and room walking use real input.
## Enemies are removed: this is not a complete damage-enabled six-region run.
const ROUTES := preload("res://scripts/world_routes.gd")
const STATE := preload("res://scripts/world_state.gd")
const SAVE := "user://world_upgrade_validation.json"
const WORKSHOP_GROUP_ROOMS := {
    "movement_group_one": [
        "upgrade_thread_dash_1",
        "upgrade_thread_dash_2",
        "upgrade_silk_wall_grip_1",
        "upgrade_silk_wall_grip_2",
        "upgrade_echo_hook_1",
        "upgrade_echo_hook_2",
        "upgrade_double_thread_jump_1",
        "upgrade_double_thread_jump_2",
        "upgrade_bell_guard_1",
        "upgrade_bell_guard_2"
    ],
    "movement_group_two": [
        "upgrade_bell_guard_3",
        "upgrade_thorn_downstrike_1",
        "upgrade_thorn_downstrike_2",
        "upgrade_thorn_downstrike_3",
        "upgrade_lantern_phase_1",
        "upgrade_lantern_phase_2",
        "upgrade_crown_resonance_1",
        "upgrade_crown_resonance_2",
        "upgrade_crown_resonance_3"
    ]
}
var scene: Node
var checks := 0
var failures := 0
var inputs := ["move_left", "move_right", "jump", "dash", "attack", "aim_down", "aim_up", "hook", "bell_guard", "lantern_phase", "crown_resonance", "interact"]
var jump_diag_emitted := false

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

    # Let released ability inputs and the physics/collision state settle before
    # this ordinary jump. Player physics returns early while collision chunks
    # synchronize or UI input is locked, which can consume just_pressed.
    var stable_takeoff_frames := 0
    for unused in range(90):
        await _tick()
        var collision_ready := not scene.has_method("_world_collision_ready") or bool(scene._world_collision_ready())
        if player.is_on_floor() and collision_ready and not player.ui_input_locked:
            stable_takeoff_frames += 1
            if stable_takeoff_frames >= 3:
                break
        else:
            stable_takeoff_frames = 0
    var takeoff_ready := not scene.has_method("_world_collision_ready") or bool(scene._world_collision_ready())
    if stable_takeoff_frames < 3:
        return _step_timeout("takeoff state did not stabilize " + _takeoff_state(takeoff_ready), Vector2(target_x, target_y))
    if not jump_diag_emitted:
        push_warning("CH05 jump diagnostic before press " + _player_state() + " collision_ready=%s phase=%s jump_pressed=%s jump_just_pressed=%s jump_buffer=%.3f coyote=%.3f dash=%.3f attack=%.3f hurt=%.3f ui_locked=%s" % [
            str(takeoff_ready),
            str(player.phase_active), str(Input.is_action_pressed("jump")), str(Input.is_action_just_pressed("jump")),
            player.jump_buffer_timer, player.coyote_timer, player.dash_timer, player.attack_timer, player.hurt_timer, str(player.ui_input_locked)])

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
        if not jump_diag_emitted and frame < 3:
            push_warning("CH05 jump diagnostic physics_frame=%d " % (frame + 1) + _player_state() + " collision_ready=%s phase=%s jump_pressed=%s jump_just_pressed=%s jump_buffer=%.3f coyote=%.3f ui_locked=%s" % [
                str(scene._world_collision_ready()), str(player.phase_active), str(Input.is_action_pressed("jump")),
                str(Input.is_action_just_pressed("jump")), player.jump_buffer_timer, player.coyote_timer, str(player.ui_input_locked)])
            if frame == 2:
                jump_diag_emitted = true
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

func _takeoff_state(collision_ready: bool) -> String:
    var player: CharacterBody2D = scene.player
    return "actual=%s collision_ready=%s phase=%s ui_locked=%s" % [
        _player_state(), str(collision_ready), str(player.phase_active), str(player.ui_input_locked)]

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
    _assert(await preload("res://scripts/world_passage_terminal_fixture.gd").finish(scene), portal_id + ": terminal state fixture settles")
    await _tick(10)
    var arrival := Vector2(float(entry.target_spawn[0]), float(entry.target_spawn[1]))
    _assert(String(scene.config.id) == String(entry.target_config_id), portal_id + ": real later-region branch replaces scene")
    _assert(scene.player.position.distance_to(arrival) < 85, portal_id + ": branch has supported paired arrival")
    if not ability.is_empty():
        _assert(int(scene.inventory_counts.get(ability, 0)) > 0, portal_id + ": branch preserves acquired ability")
    if not String(entry.get("unlock_shortcut_id", "")).is_empty():
        _assert(bool(scene.story_flags.get("world_shortcut_" + String(entry.unlock_shortcut_id), false)), portal_id + ": far-side service latch persists")
    scene._activate_world_portal(scene.get_node(String(entry.target_portal_id)))
    _assert(await preload("res://scripts/world_passage_terminal_fixture.gd").finish(scene), portal_id + ": terminal state fixture settles")
    await _tick(10)
    _assert(String(scene.config.id) == region and scene.player.position.distance_to(source) < 85, portal_id + ": branch can return without boss-clear dependency")

func _trace_workshop_phase(label: String, started_msec: int) -> int:
    # Diagnostics only: keep the same scene lifetimes, inputs and frame waits.
    var ended := Time.get_ticks_msec()
    var metrics: Dictionary = scene.world_loader.last_transition if is_instance_valid(scene) and is_instance_valid(scene.world_loader) else {}
    print("WORKSHOP_TIMING phase=%s elapsed_ms=%d frame=%d prepare_work_us=%d prepare_wall_us=%d commit_work_us=%d commit_wall_us=%d" % [label, ended-started_msec, Engine.get_process_frames(), int(metrics.get("prepare_work_usec",0)), int(metrics.get("prepare_wall_usec",0)), int(metrics.get("commit_work_usec",0)), int(metrics.get("commit_wall_usec",0))])
    return ended

func _verify_workshop_restart(target: Dictionary, entry: Dictionary, source: Vector2) -> void:
    var phase_started := Time.get_ticks_msec()
    var wallet: int=scene.currency_count
    var record_id := String(target.room_id)+"_record"
    var records: int=scene.inventory_counts.get(record_id,0)
    var previous_world_id: int=scene.get_instance_id()
    _assert(records==1,String(target.room_id)+": route grants exactly one unique record before restart")
    _release()
    scene.free()
    await process_frame
    scene=load("res://scenes/World.tscn").instantiate()
    scene.world_resume=true
    scene.world_save_path=SAVE
    scene.config_path=ROUTES.config_path(String(target.region_id))
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene=scene
    await _tick(5)
    _assert(scene.get_instance_id()!=previous_world_id,String(target.room_id)+": disk restart uses a genuinely new World instance")
    phase_started = _trace_workshop_phase(String(target.room_id)+":disk_boot",phase_started)
    _assert(String(scene.config.id)==String(target.region_id),String(target.room_id)+": disk restart restores original region")
    _assert(scene.currency_count==wallet and int(scene.inventory_counts.get(record_id,0))==records,String(target.room_id)+": restart preserves wallet and exactly one record")
    _assert(bool(scene.story_flags.get("action_gate_"+String(target.gate_id),false)),String(target.room_id)+": restart restores permanent latch")
    for reward in target.reward_ids:
        _assert(bool(scene.world_collected_ids.get(String(reward),false)),String(target.room_id)+": collected identity restored from disk "+String(reward))
    # Explicit source-position fixture: restart is real; this is not a natural
    # walk from the saved shrine through the entire original region.
    scene.player.global_position=source
    scene.player.velocity=Vector2.ZERO
    scene._activate_world_portal(scene.get_node(String(target.entry_portal_id)))
    await _tick(10)
    phase_started = _trace_workshop_phase(String(target.room_id)+":disk_revisit_entry",phase_started)
    _assert(not scene.locked_gate_bodies.has(String(target.gate_id)),String(target.room_id)+": disk-resumed revisit keeps latch physically open")
    for reward in target.reward_ids:
        _assert(scene.get_node_or_null(String(reward))==null,String(target.room_id)+": disk-resumed room does not respawn reward "+String(reward))
    _assert(scene.currency_count==wallet and int(scene.inventory_counts.get(record_id,0))==records,String(target.room_id)+": revisit cannot duplicate resources")
    scene._activate_world_portal(scene.get_node(String(entry.target_portal_id)))
    await _tick(10)
    _trace_workshop_phase(String(target.room_id)+":disk_revisit_exit",phase_started)
    _assert(scene.player.position.distance_to(source)<85,String(target.room_id)+": resumed room still has its actual exit")

func _verify_ability_pickups(data: Dictionary) -> void:
    var fields := {"thread_dash":"dash_unlocked","silk_wall_grip":"wall_grip_unlocked","echo_hook":"thread_grapple_unlocked","double_thread_jump":"double_jump_unlocked","bell_guard":"bell_guard_unlocked","thorn_downstrike":"thorn_downstrike_unlocked","lantern_phase":"lantern_phase_unlocked","crown_resonance":"crown_resonance_unlocked"}
    var seen := {}
    for region in data.chapters:
        var base: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROUTES.config_path(String(region))))
        var items: Array=ROUTES.apply_to(base).get("collectibles",[])
        for item in items:
            var ability := String(item.get("item_id",""))
            if not fields.has(ability): continue
            _assert(not seen.has(ability),ability+": one production acquisition")
            seen[ability]=true
            var point := Vector2(item.position[0],item.position[1])
            # Explicit supported local approach fixture, not a six-region walk.
            await _spawn(String(region),point+Vector2(-70,0))
            _assert(not scene.inventory_counts.has(ability) and not bool(scene.player.get(fields[ability])),ability+": acquisition approach starts without its own ability")
            _assert(await _walk_x(point.x),ability+": real movement reaches production pickup")
            if not scene.inventory_counts.has(ability):
                await _pulse("interact",2)
            await _tick(5)
            _assert(int(scene.inventory_counts.get(ability,0))==1 and bool(scene.player.get(fields[ability])),ability+": production pickup synchronizes actual Player capability")
            _assert(bool(scene.world_collected_ids.get(String(item.id),false)),ability+": actual pickup identity saved "+str(scene.world_collected_ids.keys()))
            var saved := STATE.new()
            _assert(saved.read(SAVE),ability+": pickup save is readable")
            _release()
            scene.free()
            await process_frame
            scene=load("res://scenes/World.tscn").instantiate()
            scene.world_resume=true
            scene.world_save_path=SAVE
            scene.config_path=ROUTES.config_path(String(region))
            root.add_child(scene)
            await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
            current_scene=scene
            await _tick(5)
            _assert(int(scene.inventory_counts.get(ability,0))==1 and bool(scene.player.get(fields[ability])),ability+": disk restart restores capability exactly once")
            _assert(scene.get_node_or_null(String(item.id))==null,ability+": acquired source does not respawn after disk restart")
            # Visit an existing old-area target with the acquired inventory.
            var target: Dictionary={}
            for value in data.ability_backtracks:
                if value.ability_id==ability and value.role=="backtrack":
                    target=value
                    break
            var status: Dictionary=ROUTES.access(ROUTES.portal(String(target.region_id),String(target.entry_portal_id)),scene.inventory_counts,scene.story_flags)
            _assert(status.open,ability+": restored inventory admits its existing return-workshop entry")
            print("WORKSHOP_ACQUISITION ability=",ability," actual_pickup=true disk_restart=true local_approach_fixture=true")
    _assert(seen.size()==8,"All eight actual acquisition sources are exercised")

func _verify_workshop_targets(data: Dictionary, targets: Array, restart_from_disk: bool) -> Dictionary:
    # One action/reward implementation serves the original 20-room contract and
    # the new authored-group persistence suites. No scene or state is cached.
    var rebuilt_routes_exercised := 0
    var completed := 0
    var disk_restarts := 0
    for target in targets:
        var region := String(target.region_id)
        var ability := String(target.ability_id)
        var gate_id := String(target.gate_id)
        var source := Vector2(float(target.source_position[0]), float(target.source_position[1]))
        var phase_started := Time.get_ticks_msec()
        await _spawn(region, source)
        phase_started = _trace_workshop_phase(String(target.room_id)+":fresh_boot",phase_started)
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
        phase_started = _trace_workshop_phase(String(target.room_id)+":enter_and_open",phase_started)
        var authored_room: Dictionary = {}
        for value in scene.config.map_rooms:
            if String(value.id)==String(target.room_id): authored_room=value
        if authored_room.get("layout_group","") in ["movement_group_one","movement_group_two"]:
            rebuilt_routes_exercised+=1
            var route_probe = preload("res://scripts/ability_workshop_route_validation.gd").new()
            if not await route_probe.run(scene,self,authored_room,_assert):
                continue
        if String(target.room_id) == "upgrade_lantern_phase_3":
            var traversal = preload("res://scripts/obsidian_lantern_workshop_validation.gd").new()
            _assert(await traversal.walk_to_landing(scene,self,Vector2(7800,490)), gate_id + ": single jump reaches lower service platform")
            _assert(await traversal.walk_to_landing(scene,self,Vector2(7890,380)), gate_id + ": single jump reaches upper reward gallery")
        phase_started = _trace_workshop_phase(String(target.room_id)+":movement_and_capture",phase_started)
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
        if authored_room.get("layout_group","") in ["movement_group_one","movement_group_two"]:
            var cache_amount := 0
            for reward in data.chapters[region].collectibles:
                if String(reward.id)==String(target.room_id)+"_resin": cache_amount=int(reward.amount)
            _assert(scene.currency_count==currency_before+cache_amount,gate_id+": cache grants exactly its authored amount")
        var saved := STATE.new()
        _assert(saved.read(SAVE), gate_id + ": save readable after action and rewards")
        _assert(bool(saved.data.story_flags.get("action_gate_" + gate_id, false)), gate_id + ": action unlock persisted on disk")
        phase_started = _trace_workshop_phase(String(target.room_id)+":rewards_and_save",phase_started)
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
        phase_started = _trace_workshop_phase(String(target.room_id)+":initial_return",phase_started)
        if restart_from_disk and authored_room.get("layout_group","") in ["movement_group_one","movement_group_two"]:
            await _verify_workshop_restart(target,entry,source)
            disk_restarts += 1
        completed += 1
        print("WORKSHOP_ACTION_PASS " + gate_id)
    return {"routes": rebuilt_routes_exercised, "completed": completed, "disk_restarts": disk_restarts}

func _finish_workshop_resources() -> void:
    _release()
    if is_instance_valid(scene):
        scene.queue_free()
        await process_frame
    _assert(await preload("res://scripts/audio_retirement.gd").drain(self), "AudioServer releases retired seal playback before shutdown")
    _clean()

func _run_workshop_group(group: String, marker: String, expected_count: int) -> void:
    # These fixed groups are the authored PR84/PR85 responsibilities, not an
    # arbitrary timeout shard. Each room starts fresh and truly rereads its save.
    var started := Time.get_ticks_msec()
    var data: Dictionary = ROUTES._data()
    var all_ids: Array = WORKSHOP_GROUP_ROOMS.movement_group_one.duplicate()
    all_ids.append_array(WORKSHOP_GROUP_ROOMS.movement_group_two)
    _assert(WORKSHOP_GROUP_ROOMS.movement_group_one.size()==10 and WORKSHOP_GROUP_ROOMS.movement_group_two.size()==9,"Authored workshop groups retain their ten/nine room responsibilities")
    _assert(all_ids.size()==19 and not all_ids.has("upgrade_lantern_phase_3"),"New groups cover exactly nineteen rebuilt rooms and retain CH05 in the original suite")
    var unique := {}
    for id in all_ids:
        _assert(not unique.has(id),"Workshop group membership is disjoint: "+String(id))
        unique[id]=true
    var targets: Array = []
    var covered := {}
    for target in data.get("ability_backtracks",[]):
        var id := String(target.room_id)
        if not unique.has(id):
            _assert(id=="upgrade_lantern_phase_3","Only the retained CH05 room is outside the new authored groups")
            continue
        var authored_group := ""
        for room in data.chapters[String(target.region_id)].map_rooms:
            if String(room.id)==id:
                authored_group=String(room.get("layout_group",""))
        var expected_group := "movement_group_one" if WORKSHOP_GROUP_ROOMS.movement_group_one.has(id) else "movement_group_two"
        _assert(authored_group==expected_group,"Authored group identity remains exact: "+id)
        _assert(not covered.has(id),"Each rebuilt target occurs exactly once: "+id)
        covered[id]=true
        if WORKSHOP_GROUP_ROOMS[group].has(id):
            targets.append(target)
    _assert(covered.size()==19,"The two authored suites cover every rebuilt target")
    _assert(targets.size()==expected_count,"Selected authored group has its exact room count")
    var result := await _verify_workshop_targets(data, targets, true)
    _assert(int(result.routes)==expected_count,"Every selected room executes its full actual movement route")
    _assert(int(result.completed)==expected_count,"Every selected room completes actions, exact rewards and return")
    _assert(int(result.disk_restarts)==expected_count,"Every selected room truly restarts from disk and revisits both directions")
    await _finish_workshop_resources()
    print("%s checks=%d failures=%d rooms=%d disk_restarts=%d enemy_removal=true fixture_positioning=true elapsed_ms=%d" % [marker,checks,failures,int(result.completed),int(result.disk_restarts),Time.get_ticks_msec()-started])
    call_deferred("quit",1 if failures else 0)

func _run() -> void:
    var suite_started := Time.get_ticks_msec()
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
    _trace_workshop_phase("late_branch_preamble",suite_started)
    var result := await _verify_workshop_targets(data, targets, false)
    var rebuilt_routes_exercised: int = result.routes
    _assert(rebuilt_routes_exercised==19,"All nineteen rebuilt rooms execute their actual movement routes")
    _assert(int(result.completed)==20,"Original world_upgrade completes all twenty workshop action flows")
    _assert(int(result.disk_restarts)==0,"Original world_upgrade adds no per-room disk restart workload")
    await _finish_workshop_resources()
    print("WORLD_UPGRADE_TIMING elapsed_ms=%d" % (Time.get_ticks_msec()-suite_started))
    print("WORLD_UPGRADE checks=%d failures=%d enemy_removal=true fixture_positioning=true" % [checks, failures])
    # Let the async test stack release its final saved-state Resource first.
    # Direct quit can race reference teardown on faster CI runners.
    call_deferred("quit", 1 if failures > 0 else 0)
