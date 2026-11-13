extends "res://scripts/world_upgrade_validation.gd"
## Live World loader/portal/save integration at declared local approach fixtures.
## Existing helper removes enemies; this is not a damage-enabled campaign run.
func _run() -> void:
    var data: Dictionary = ROUTES._data()
    for entry in data.get("ability_routes", []):
        var failures_before := failures
        var id := String(entry.id)
        var region := String(entry.region_id)
        var ability := String(entry.required_ability)
        var forward: Dictionary = ROUTES.portal(region, String(entry.entry_portal_id))
        var reverse: Dictionary = ROUTES.portal(region, String(entry.return_portal_id))
        var source := Vector2(float(forward.position[0]), float(forward.position[1]))
        var arrival := Vector2(float(reverse.position[0]), float(reverse.position[1]))
        await _spawn(region, source)
        scene._add_inventory_item(ability, 1, false)
        scene._refresh_ability_gates()
        _assert(scene.locked_gate_bodies.has(String(entry.gate_id)), id + ": possession alone leaves the real seal closed")
        var portal: Node = scene.get_node_or_null(String(entry.entry_portal_id))
        _assert(portal != null, id + ": opening-side portal is resident at its real approach")
        if portal == null: continue
        scene._activate_world_portal(portal)
        _assert(not _transition_busy(), id + ": closed action latch blocks production portal activation")
        var gate: Dictionary = {}
        for candidate in scene.config.locked_gates:
            if String(candidate.id) == String(entry.gate_id): gate = candidate
        var actions: Array = []
        scene.player.ability_action.connect(func(key: String, origin: Vector2, _direction: Vector2): actions.append({"ability": key, "origin": origin}))
        await _do_action(ability, gate)
        _assert(not scene.locked_gate_bodies.has(String(entry.gate_id)), id + ": actual input opens the resident seal")
        if scene.locked_gate_bodies.has(String(entry.gate_id)):
            print("ROUTE_ACTION_DEBUG ", id, " position=", scene.player.position, " source=", source, " actions=", actions,
                " energy=", scene.player.energy, " locked=", scene.player.ui_input_locked)
            for ring in get_nodes_in_group("grapple_anchor"):
                if String(ring.name) == id + "_ring":
                    print("ROUTE_RING_DEBUG position=", ring.global_position, " enabled=", ring.get_meta("grapple_enabled", false),
                        " visible=", ring.is_visible_in_tree(), " clear=", preload("res://scripts/grapple_path.gd").clear(scene.player, ring))
            continue
        _assert(bool(scene.story_flags.get("world_shortcut_" + id, false)), id + ": actual input releases its paired route latch")
        scene._activate_world_portal(scene.get_node(String(entry.entry_portal_id)))
        await _tick(8)
        _assert(scene.player.position.distance_to(arrival) < 85, id + ": production loader arrives on the return-side floor")
        _assert(scene._save_world(), id + ": real World checkpoint completes")
        var saved := STATE.new()
        _assert(saved.read(SAVE), id + ": World checkpoint is readable from disk")
        _assert(bool(saved.data.story_flags.get("world_shortcut_" + id, false)), id + ": World checkpoint retains the latch")
        _release()
        scene.queue_free()
        await process_frame
        scene = load("res://scenes/World.tscn").instantiate()
        scene.world_resume = true
        scene.world_save_path = SAVE
        root.add_child(scene)
        await _await_ready()
        current_scene = scene
        await _tick(5)
        _assert(String(scene.config.id) == region, id + ": fresh World resumes the saved region")
        var back: Node = scene.get_node_or_null(String(entry.return_portal_id))
        _assert(back != null and ROUTES.access(reverse, scene.inventory_counts, scene.story_flags).open, id + ": reverse route is resident and open after disk restart")
        if back != null:
            scene._activate_world_portal(back)
            await _tick(8)
            _assert(scene.player.position.distance_to(source) < 85, id + ": restored reverse passage reaches the original floor")
            _assert(not scene.locked_gate_bodies.has(String(entry.gate_id)), id + ": restored seal cannot close again")
        if not String(entry.record_id).is_empty():
            _assert(int(scene.inventory_counts.get(String(entry.record_id), 0)) == 1, id + ": old bell record survives transitions and restart exactly once")
        print("ABILITY_ROUTE_WORLD ", id, " passed=", failures == failures_before, " local_approach_fixture=true")
    _release()
    if is_instance_valid(scene):
        scene.queue_free()
        await process_frame
    _clean()
    _assert(await preload("res://scripts/audio_retirement.gd").drain(self), "World route audio retires")
    print("ABILITY_ROUTES_WORLD checks=%d failures=%d" % [checks, failures])
    quit(1 if failures else 0)

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
    await _await_ready()
    current_scene = scene
    scene._close_overlays()
    await _tick(5)
    for index in range(60):
        if scene.player.is_on_floor(): break
        await _tick(1)
    _assert(scene.player.is_on_floor(), "declared portal approach settles on actual World collision")

func _await_ready() -> void:
    # This suite verifies five cold region boots and saves, not the separately
    # enforced startup performance budget. Keep a finite wall-clock deadline.
    var deadline := Time.get_ticks_msec() + 60000
    while is_instance_valid(scene) and not scene.initial_region_ready:
        var startup_error: bool = is_instance_valid(scene.world_loader) and scene.world_loader.phase == "startup_error"
        if Time.get_ticks_msec() > deadline or startup_error:
            _assert(false, "World route fixture startup failed: " + (String(scene.world_loader.last_error) if startup_error else "60 second deadline"))
            quit(1)
            await process_frame
            return
        await process_frame

func _settle_transition() -> bool:
    var deadline := Time.get_ticks_msec() + 60000
    while Time.get_ticks_msec() < deadline:
        if is_instance_valid(current_scene) and current_scene.get("world_mode") == true:
            scene = current_scene
        if not _transition_busy(): return true
        await process_frame
    _assert(false, "World route transition did not settle within 60 seconds")
    _release()
    quit(1)
    await process_frame
    return false
