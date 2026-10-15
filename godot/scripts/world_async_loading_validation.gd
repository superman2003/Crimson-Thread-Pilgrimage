extends SceneTree
## State/configuration fixtures; not a natural six-region traversal or FPS claim.
const ROUTES := preload("res://scripts/world_routes.gd")
const COORDINATES := preload("res://scripts/world_coordinates.gd")
const STATE := preload("res://scripts/world_state.gd")
const PATH := "user://world_async_loading_validation.json"
var checks := 0
var failures: Array[String] = []
var scene: Node
var metrics: Array = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    root.process_mode = Node.PROCESS_MODE_DISABLED
    for suffix in ["", ".bak", ".tmp"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + suffix))
    scene = load("res://scenes/World.tscn").instantiate()
    scene.world_resume = false
    scene.world_save_path = PATH
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene = scene
    await _frames(3)
    var player_id: int = scene.player.get_instance_id()
    var camera_id: int = scene.player.get_node("Camera2D").get_instance_id()
    var state_id: int = scene.world_state.get_instance_id()
    var build_id: int = scene.build_system.get_instance_id()
    var map_font_id: int = scene.map_panel.theme.default_font.get_instance_id()
    for ability in scene.WORLD_ABILITIES:
        scene._add_inventory_item(ability, 1, false)
    scene.player.hp = 3
    scene.player.energy = 51
    scene.currency_count = 317
    scene.story_flags["async_fixture"] = true
    scene.build_system.cooldowns["cleave"] = 4.5
    for id in COORDINATES.manifest().regions:
        var path: String = ROUTES.config_path(id)
        var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
        var entry := Vector2(raw.player_start[0], raw.player_start[1])
        var ok: bool = await scene.world_loader.replace_region_async(scene, path, entry)
        await _frames(2)
        _check(ok and scene.world_loader.phase == "idle", id + " async arrival completes")
        _check(scene.player.get_instance_id() == player_id and scene.player.get_node("Camera2D").get_instance_id() == camera_id, id + " persistent player/camera")
        _check(scene.world_state.get_instance_id() == state_id and scene.build_system.get_instance_id() == build_id, id + " persistent state/build")
        _check(scene.player.hp == 3 and scene.player.energy == 51 and scene.currency_count == 317, id + " resources preserved")
        _check(scene.build_system.cooldowns.get("cleave") == 4.5, id + " cooldown cannot reset during travel")
        _check(scene.player.collision_layer == 1 and scene.player.collision_mask != 0, id + " collision restored")
        _check(not scene.world_loading and not scene.chapter_transitioning and scene.world_loader.loading_canvas == null, id + " input/loading UI released")
        _check(scene.ui_shell.construction_complete and scene.ui_shell.is_processing_input(), id + " complete UI enables input only at arrival")
        _check(scene.map_panel.theme.default_font.get_instance_id() == map_font_id and scene.map_panel.theme.default_font.multichannel_signed_distance_field, id + " zoomable map reuses the shared font cache")
        var metric: Dictionary = scene.world_loader.last_transition.duplicate(true)
        metrics.append(metric)
        _check(metric.max_build_operations <= 8 and metric.max_unload_operations <= 8 and metric.batches > 2, id + " bounded multi-frame operations")
        _check(metric.max_commit_operations <= 8 and metric.commit_batches > 2 and metric.commit_cursor == metric.commit_jobs, id + " arrival/UI jobs are bounded and complete across frames")
        var actual := _geometry_signature()
        var ui := _ui_signature()
        scene._travel_world(path, entry)
        await _frames(2)
        _check(_geometry_signature() == actual, id + " async geometry equals synchronous authored content")
        _check(_ui_signature() == ui, id + " async HUD/panels/inventory equal synchronous content")
        var saved := STATE.new()
        _check(saved.read(PATH) and saved.data.current_region == id and saved.data.hp == 3 and saved.data.currency == 317, id + " restart reads committed destination")
    var source_id: String = scene.config.id
    var source_position: Vector2 = scene.player.global_position
    var source_geometry := _geometry_signature()
    var generation: int = scene.world_loader.generation
    _check(not await scene.world_loader.replace_region_async(scene, "res://missing.json", Vector2.ZERO), "bad target rejected")
    _check(scene.world_loader.generation == generation and _geometry_signature() == source_geometry, "failed preflight leaves source intact")
    for field in ["platforms", "hazards", "npcs", "enemy_spawns"]:
        var malformed: Dictionary = scene.config.duplicate(true)
        malformed[field] = [{"position": ["invalid", 2]}]
        _check(scene.world_loader.validate_config(malformed, scene.config_path, source_position).is_empty(), "reject nonnumeric " + field + " before unloading")
    var bad_surface: Dictionary = scene.config.duplicate(true)
    bad_surface.terrain = [{"surface": [[0, 0], [1, "bad"]]}]
    _check(scene.world_loader.validate_config(bad_surface, scene.config_path, source_position).is_empty(), "reject nonnumeric terrain before unloading")
    var target_id: String = COORDINATES.manifest().regions.keys()[0]
    var target_path := ROUTES.config_path(target_id)
    var target_bytes := FileAccess.get_file_as_bytes(target_path)
    var target_config: Dictionary = JSON.parse_string(target_bytes.get_string_from_utf8())
    var target_entry := Vector2(target_config.player_start[0], target_config.player_start[1])
    # A completed destination wish is an explicit fixture. Its reward must not
    # leak out of any cancellable phase, even when the entire UI already exists.
    target_config.wish_board = [{"id": "async_commit_reward", "title": "提交隔离夹具", "desc": "",
        "target_flag": "async_fixture", "reward_currency": 200}]
    scene.world_prefetch.desired[target_id] = {"path": target_path}
    scene.world_prefetch.configs[target_id] = {"raw": target_config, "stamp": FileAccess.get_modified_time(target_path), "size": target_bytes.size()}
    for cancel_at in ["unloading", "loading", "committing", "partial_hud", "ready_hud"]:
        var cancel_phase: String = "committing" if cancel_at in ["partial_hud", "ready_hud"] else cancel_at
        scene._request_world_travel(target_path, target_entry)
        _check(scene.world_loader.phase != "idle", "travel starts asynchronously")
        var active_error: String = scene.world_loader.last_error
        _check(not scene.world_loader.replace_region(scene, target_path, target_entry), "sync reentrant travel blocked")
        _check(not await scene.world_loader.replace_region_async(scene, target_path, target_entry), "async reentrant travel blocked")
        _check(scene.world_loader.last_error == active_error, "rejected reentrant requests do not poison the active preflight")
        for frame in range(2000):
            if _reached_boundary(cancel_at):
                break
            await process_frame
        _check(_reached_boundary(cancel_at), "reached cancellation boundary " + cancel_at)
        _check(not bool(scene.story_flags.get("wish_claimed_async_commit_reward", false)), cancel_at + " destination reward is not published")
        if cancel_at == "partial_hud":
            var overlay: String = scene.active_overlay
            scene.ui_shell._process(0.01)
            var shortcut := InputEventKey.new()
            shortcut.pressed = true
            shortcut.physical_keycode = KEY_B
            scene.ui_shell._input(shortcut)
            _check(scene.active_overlay == overlay and not scene.ui_shell.is_processing_input(), "unfinished interface cannot process input or frames")
        var saved := STATE.new()
        _check(saved.read(PATH) and saved.data.current_region == source_id, cancel_phase + " partial destination never saved")
        _check(scene.player.collision_layer == 0 and scene.process_mode == Node.PROCESS_MODE_DISABLED, cancel_phase + " no partial gameplay")
        var currency: int = scene.currency_count
        # Physics area signals must be harmless even though SceneTree processing
        # is disabled: physics-server notifications are independent of _process.
        var trap := Area2D.new()
        trap.set_meta("damage", 99)
        trap.set_meta("kind", "currency")
        trap.set_meta("amount", 999)
        scene._on_hazard_body_entered(scene.player, trap)
        scene._on_collectible_body_entered(scene.player, trap)
        scene._on_interactable_entered(scene.player, trap)
        trap.free()
        _check(scene.player.hp == 3 and scene.currency_count == currency, cancel_phase + " area signals cannot grant rewards/damage")
        if cancel_at in ["loading", "partial_hud", "ready_hud"]:
            var escape := InputEventKey.new()
            escape.physical_keycode = KEY_ESCAPE
            escape.keycode = KEY_ESCAPE
            escape.pressed = true
            Input.parse_input_event(escape)
            await _frames(2)
            escape.pressed = false
            Input.parse_input_event(escape)
        else:
            scene.world_loader.cancel_transition()
        await _wait_idle()
        _check(scene.config.id == source_id and scene.player.global_position == source_position, cancel_phase + " original region/position restored")
        _check(_geometry_signature() == source_geometry, cancel_phase + " source content fully reconstructed")
        _check(scene.player.hp == 3 and scene.player.energy == 51 and scene.currency_count == 317 and scene.story_flags.async_fixture, cancel_phase + " settled progress survives rollback")
        _check(not scene.world_state.data.regions.has(target_id) or bool(scene.world_state.data.regions[target_id].visited_rooms.is_empty()), cancel_phase + " cancellation does not discover target rooms")
        _check(scene.world_loader.last_transition.rolled_back and not scene.chapter_transitioning and scene.world_loader.loading_canvas == null, cancel_phase + " rollback releases input/UI")
        _check(scene.ui_shell.construction_complete and scene.ui_shell.is_processing_input() and not bool(scene.story_flags.get("wish_claimed_async_commit_reward", false)), cancel_at + " rollback restores complete source UI without destination reward")
        var restored := STATE.new()
        _check(restored.read(PATH) and restored.data.current_region == source_id, cancel_phase + " restart remains in source")
    _check(await scene.world_loader.replace_region_async(scene, target_path, target_entry), "complete destination publishes successfully")
    _check(scene.currency_count == 517 and bool(scene.story_flags.get("wish_claimed_async_commit_reward", false)), "destination reward publishes once after all UI jobs")
    scene._travel_world(target_path, target_entry)
    await _frames(2)
    var rewarded := STATE.new()
    _check(scene.currency_count == 517 and rewarded.read(PATH) and rewarded.data.currency == 517, "revisit/restart retains the reward without duplicate grant")
    # Teardown of partial and fully prepared UI must retire root-owned loading
    # UI and resume awaiting coroutines without touching the freed host.
    for teardown_at in ["unloading", "partial_hud", "ready_hud"]:
        scene._request_world_travel(target_path, target_entry)
        for frame in range(2000):
            if _reached_boundary(teardown_at): break
            await process_frame
        _check(_reached_boundary(teardown_at), "reached teardown boundary " + teardown_at)
        var loader: RefCounted = scene.world_loader
        scene.free()
        current_scene = null
        await _frames(3)
        _check(loader.shutting_down and loader.loading_canvas == null, teardown_at + " host exit retires in-flight UI/task")
        loader = null
        if teardown_at != "ready_hud":
            scene = load("res://scenes/World.tscn").instantiate()
            scene.world_resume = false
            scene.world_save_path = PATH
            root.add_child(scene)
            await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
            current_scene = scene
            await _frames(3)
    for suffix in ["", ".bak", ".tmp"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + suffix))
    print("ASYNC METRICS ", JSON.stringify(metrics))
    if failures.is_empty():
        print("WORLD ASYNC LOADING PASS: %d checks; six-region geometry/UI parity, commit budgets, reward/save isolation, rollback and teardown" % checks)
        call_deferred("quit", 0)
    else:
        for failure in failures:
            push_error(failure)
        call_deferred("quit", 1)

func _geometry_signature() -> Dictionary:
    var signature := {"types": {}, "enemy_positions": [], "collision_shapes": 0, "polygons": 0,
        "hazards": scene.hazard_total, "collectibles": scene.collectible_total, "saves": scene.save_point_total, "gates": scene.locked_gate_bodies.keys()}
    # Renderer residency depends on prior camera history; compare its immutable
    # authoritative exposed-edge descriptors separately from tree node counts.
    var rock: Node = scene.cave_world.get_node("PaintedRockMass")
    scene.player.get_node("Camera2D").force_update_scroll()
    rock._refresh_view()
    signature["authored_cave_rims"] = JSON.stringify(rock.rim_descriptors)
    for key in rock.rim_chunks:
        if rock.rim_chunks[key].bounds.intersects(rock.view_bounds):
            _check(rock.resident_rims.has(key), "arrival view has complete cave rims")
    _walk(scene, signature)
    signature.enemy_positions.sort()
    signature.gates.sort()
    return signature

func _reached_boundary(boundary: String) -> bool:
    if boundary not in ["partial_hud", "ready_hud"]:
        return scene.world_loader.phase == boundary
    if scene.world_loader.phase != "committing" or not is_instance_valid(scene.ui_shell):
        return false
    return scene.ui_shell.construction_complete if boundary == "ready_hud" else (scene.ui_shell.bag != null and not scene.ui_shell.construction_complete)

func _ui_signature() -> Dictionary:
    var signature := {"types": {}, "buttons": [], "items": [], "panels": []}
    var pending: Array[Node] = [scene.ui_canvas]
    while not pending.is_empty():
        var node: Node = pending.pop_back()
        var kind := node.get_class()
        signature.types[kind] = int(signature.types.get(kind, 0)) + 1
        if node is Button: signature.buttons.append(node.text)
        if node.has_meta("item_id"): signature.items.append(String(node.get_meta("item_id")))
        if String(node.name) in ["BackpackOverlay", "DialogueOverlay", "AudioSettingsOverlay", "BuildOverlay", "CourtMapOverlay"]:
            signature.panels.append([String(node.name), str(node.position), str(node.size)])
        pending.append_array(node.get_children())
    signature.buttons.sort()
    signature.items.sort()
    signature.panels.sort_custom(func(a: Array, b: Array): return a[0] < b[0])
    return signature

func _walk(node: Node, result: Dictionary) -> void:
    if node.has_meta("rim_chunk"):
        return
    if node == scene.player or node is CanvasLayer or node is Window or node is AudioStreamPlayer or node is AudioStreamPlayer2D or node == scene.audio_director or node == scene.metsys_bridge:
        return
    var kind := node.get_class()
    result.types[kind] = int(result.types.get(kind, 0)) + 1
    if node is CollisionShape2D:
        result.collision_shapes += 1
    if node is CollisionPolygon2D:
        result.polygons += 1
    if node.is_in_group("enemy") and node is Node2D:
        result.enemy_positions.append(str(node.position))
    for child in node.get_children():
        _walk(child, result)

func _wait_idle() -> void:
    for frame in range(4000):
        if scene.world_loader.phase == "idle":
            return
        await process_frame
    _check(false, "transition failed to finish within fixture frame limit")

func _frames(count: int) -> void:
    for index in range(count):
        await process_frame

func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures.append(message)
