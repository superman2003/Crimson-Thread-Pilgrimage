extends SceneTree
## Connector integration, not natural campaign completion. Placement is only at
## authored mouths; gate prerequisites are explicit fixtures before admission.
## The complete connector then uses the existing Player's input and collisions.
## Keep split runners at fixed 60 Hz, with the ordinary 180-second suite limit.
const PASSAGE := preload("res://scripts/world_passage.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const COORD := preload("res://scripts/world_coordinates.gd")
const VALIDATOR := preload("res://scripts/world_config_validator.gd")
const STATE := preload("res://scripts/world_state.gd")
var scene: Node
var checks := 0
var failures: Array[String] = []
var traversals := 0

func route_ids() -> Array[String]:
    return []

func suite_name() -> String:
    return "WORLD_ROUTE_MANIFEST_WALK"

func save_path() -> String:
    return "user://%s.json" % suite_name().to_lower()

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)
        push_error(suite_name() + ": " + label)

func _frames(count: int = 1) -> void:
    for unused in count:
        await physics_frame
        await process_frame

func _release() -> void:
    for action in ["move_left", "move_right", "close_overlay"]:
        if InputMap.has_action(action): Input.action_release(action)

func _clean() -> void:
    for suffix in ["", ".bak", ".tmp"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path() + suffix))

func _spawn(route: Dictionary) -> void:
    _release()
    if is_instance_valid(scene):
        scene.free()
        await _frames(3)
    _clean()
    # Read the fixture mouth from authored data before starting measurement.
    # Production startup must publish its own current worker route lease.
    var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROUTES.ROUTES_PATH))
    var point := Vector2.ZERO
    for portal in manifest.chapters[String(route.a.region)].portals:
        if String(portal.id) == String(route.a.portal):
            point = Vector2(portal.position[0], portal.position[1])
    scene = load("res://scenes/World.tscn").instantiate()
    scene.world_resume = false
    scene.world_save_path = save_path()
    scene.config_path = "res://data/%s.json" % String(route.a.region)
    scene.entry_spawn_override_enabled = true
    scene.entry_spawn_override = point
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene = scene
    scene.process_mode = Node.PROCESS_MODE_DISABLED
    # Only the authored ability gates are seeded. No invulnerability, speed,
    # damage, wallet or endpoint alterations are used during either walk.
    for side in ["a", "b"]:
        var endpoint: Dictionary = route[side]
        var portal := ROUTES.cached_portal(String(endpoint.region), String(endpoint.portal))
        var ability := String(portal.get("required_ability", ""))
        if not ability.is_empty() and int(scene.inventory_counts.get(ability, 0)) == 0:
            scene._add_inventory_item(ability, 1, false)
    scene._sync_player_abilities()

func _walk_route(route: Dictionary, side: String) -> bool:
    var passage: Node = scene.world_passage
    var mouth: Dictionary = route[side]
    var other: Dictionary = route["b" if side == "a" else "a"]
    var label := String(route.id) + " " + side
    var area: Node = scene.get_node_or_null(String(mouth.portal))
    _check(is_instance_valid(area), label + ": authored mouth exists")
    if not is_instance_valid(area): return false
    # The same mouth-only setup and input/collision stepping as the unchanged
    # world_passage_network suite. No position assignment occurs after entry.
    scene.player.global_position = area.global_position
    scene.player.velocity = Vector2.ZERO
    scene.world_platforms.warm(scene, area.global_position)
    scene.cave_world.warm_collision_focus(area.global_position)
    scene.chapter_terrain.warm_focus(area.global_position)
    scene.player.process_mode = Node.PROCESS_MODE_ALWAYS
    await _frames(12)
    var direction := 1 if PASSAGE.glyph(String(mouth.region), String(mouth.portal)) == "→" else -1
    var key := "move_right" if direction > 0 else "move_left"
    Input.action_press(key)
    for unused in 30:
        passage.try_walk_entry()
        if passage.active: break
        await _frames()
    _check(passage.active and String(passage.route.get("id", "")) == String(route.id), label + ": real directional input admits the expected connector")
    if not passage.active:
        _release()
        return false
    var admitted_path: String = passage.destination_config_path
    var old_generation := ROUTES.cached_generation()
    var identities := [scene.get_instance_id(), scene.player.get_instance_id(), scene.build_system.get_instance_id(), scene.world_state.get_instance_id()]
    var resources := [scene.player.hp, scene.player.energy, scene.currency_count]
    var inventory: Dictionary = scene.inventory_counts.duplicate(true)
    var source_save := FileAccess.get_file_as_bytes(save_path())
    var saved_source := STATE.new()
    _check(saved_source.read(save_path()) and String(saved_source.data.current_region) == String(mouth.region), label + ": admission saves only the source")
    var source_checkpoint: Vector2 = saved_source.resume_local_position()
    var world_span: float = passage.source_point.distance_to(passage.destination_point)
    var expected_terminal: Vector2 = COORD.to_world(String(mouth.region), passage.destination_point)
    var previous: Vector2 = scene.player_world_position()
    var max_step := 0.0
    var invalidated := false
    var held_source := true
    var reached_preflight := false
    var frame_count := 0
    var movement_frames := 0
    var loading_deadline := 0
    ROUTES.sync_manifest_parses = 0
    while movement_frames < 4200:
        frame_count += 1
        await _frames()
        if not invalidated and passage.active and not passage.settling and float(passage.travelled) >= 160:
            ROUTES._cached_stamp = -1
            invalidated = true
            _check(ROUTES.cached_config_path(String(other.region)).is_empty() and passage.destination_config_path == admitted_path and not admitted_path.is_empty(), label + ": stale cache hides lookup but retains the admitted path in transit")
            scene._save_world()
            _check(FileAccess.get_file_as_bytes(save_path()) == source_save, label + ": stale transit cannot overwrite the source checkpoint")
        if not passage.settling:
            movement_frames += 1
            passage.step()
        if passage.settling:
            scene.player.process_mode = Node.PROCESS_MODE_INHERIT
            reached_preflight = reached_preflight or scene.world_loader.phase == "preflight"
            # Keep the movement cap independent of real worker scheduling.
            if loading_deadline == 0: loading_deadline = Time.get_ticks_msec() + 15000
            if Time.get_ticks_msec() >= loading_deadline: break
        if passage.active:
            held_source = held_source and FileAccess.get_file_as_bytes(save_path()) == source_save
        var point: Vector2 = scene.player_world_position()
        max_step = maxf(max_step, point.distance_to(previous))
        previous = point
        if not passage.active: break
    _release()
    scene.player.process_mode = Node.PROCESS_MODE_INHERIT
    _check(invalidated and reached_preflight, label + ": invalidation occurs during walking before terminal foreground preflight")
    _check(not passage.active and scene.world_loader.phase == "idle", label + ": complete physics walk finishes within movement and IO budgets")
    _check(max_step < 35, label + ": world position stays continuous through walking and terminal rebase")
    _check(held_source, label + ": original source save survives every unpublished transit frame")
    _check(String(scene.config.get("id", "")) == String(other.region), label + ": current five-link destination commits")
    if passage.active or String(scene.config.get("id", "")) != String(other.region):
        print("MANIFEST_WALK_STUCK route=", route.id, " side=", side, " player=", scene.player.global_position, " target=", passage.destination_point, " phase=", scene.world_loader.phase)
        return false
    var metric: Dictionary = scene.world_loader.last_transition
    _check(ROUTES.cache_is_current() and ROUTES.cached_generation() > old_generation and int(metric.get("preflight_route_generation", -1)) == ROUTES.cached_generation(), label + ": terminal validator and committed region use the new route generation")
    _check(ROUTES.sync_manifest_parses == 0 and not bool(metric.get("route_manifest_worker_is_main", true)), label + ": no main-thread manifest parse or synchronous repair")
    _check(int(metric.get("route_manifest_copy_batches", 0)) > 0 and int(metric.get("route_manifest_copy_max_step_edges", 999)) <= 512, label + ": sole-worker manifest ownership transfers in bounded copy batches")
    _check(bool(passage.last_result.get("arrived", false)) and float(passage.last_result.get("distance", 0)) >= world_span - 65, label + ": full authored span is traveled by input and collisions")
    _check(scene.player_world_position().distance_to(expected_terminal) < 65 and VALIDATOR.entry_in_bounds(scene.player.global_position, scene.config.world), label + ": modern authored terminal has a legal landing")
    _check(scene.player_world_position().distance_to(passage.last_result.get("world_position", Vector2.INF)) < 0.1, label + ": published landing preserves the final world position")
    _check(identities == [scene.get_instance_id(), scene.player.get_instance_id(), scene.build_system.get_instance_id(), scene.world_state.get_instance_id()], label + ": host/player/build/state identity survives")
    _check(resources == [scene.player.hp, scene.player.energy, scene.currency_count], label + ": admitted HP, energy and wallet survive without injected immunity")
    # Production initializes the destination's authored starter items and then
    # fills missing carried counts using max(), rather than replacing the bag.
    # In particular CH02 legitimately adds rain_gauge on its first arrival.
    var expected_inventory: Dictionary = inventory.duplicate(true)
    for field in ["starting_tools", "starting_relics"]:
        for item_value in scene.config.get("inventory", {}).get(field, []):
            var item := String(item_value)
            if field == "starting_tools" and scene.WORLD_ABILITIES.has(item): continue
            expected_inventory[item] = maxi(int(expected_inventory.get(item, 0)), 1)
    _check(scene.inventory_counts == expected_inventory, label + ": inventory equals exact carried-count and authored starter-item merge")
    if scene.inventory_counts != expected_inventory:
        print("MANIFEST_INVENTORY expected=", JSON.stringify(expected_inventory), " actual=", JSON.stringify(scene.inventory_counts))
    _check(scene.player.collision_layer == 1 and scene.player.collision_mask != 64 and passage.get_child_count() == 0 and scene.ui_canvas.visible, label + ": passage physics retires and source isolation releases")
    var saved := STATE.new()
    _check(saved.read(save_path()) and String(saved.data.current_region) == String(other.region), label + ": only successful destination is restartable")
    _check(saved.data.regions.get(String(mouth.region), {}).get("checkpoint", []) == [source_checkpoint.x, source_checkpoint.y], label + ": arrival keeps the original source checkpoint in its local frame")
    traversals += 1
    print("MANIFEST_PHYSICAL_WALK route=%s side=%s frames=%d distance=%.2f generation=%d" % [route.id, side, frame_count, passage.last_result.distance, ROUTES.cached_generation()])
    return true

func _run() -> void:
    # Real GL still draws; pixel/style acceptance remains the separate 15 probes.
    root.size = Vector2i(384, 216)
    var definitions := PASSAGE.routes()
    _check(definitions.size() == 5, "modern registry retains all five physical links")
    var matched := 0
    var completed := true
    for route in definitions:
        if String(route.id) not in route_ids(): continue
        matched += 1
        await _spawn(route)
        for side in ["a", "b"]:
            if not await _walk_route(route, side):
                completed = false
                break
        if not completed: break
    _check(matched == route_ids().size() and traversals == route_ids().size() * 2, "each selected physical connector completes both directions")
    _release()
    if is_instance_valid(scene): scene.free()
    scene = null
    current_scene = null
    await _frames(4)
    _clean()
    print("%s checks=%d failures=%d physical_crossings=%d" % [suite_name(), checks, failures.size(), traversals])
    quit(0 if failures.is_empty() else 1)
