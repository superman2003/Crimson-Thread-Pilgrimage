extends SceneTree
## Bounded component fixtures for the repaired manifest on modern main.
## Fault injection changes only cache generations, isolated saves and detached
## candidates. Terminal placement below tests recovery, NEVER complete travel.
## Full five-link input/collision walks live in the two separate walk suites.
const ROUTES := preload("res://scripts/world_routes.gd")
const STATE := preload("res://scripts/world_state.gd")
const ATLAS := preload("res://scripts/world_atlas.gd")
const PREFETCH := preload("res://scripts/world_prefetch.gd")
const PASSAGE := preload("res://scripts/world_passage.gd")
const BODY := preload("res://scripts/world_platform_body.gd")
const GEOMETRY := preload("res://scripts/world_collision_geometry.gd")
const SOURCE := "demo_ch04_broken_string_greenhouse"
const TARGET := "demo_ch06_silent_crown_core"
const TARGET_PATH := "res://data/demo_ch06_silent_crown_core.json"
const SAVE := "user://world_route_manifest_integration.json"
const REWARD := "wish_claimed_manifest_commit_fixture"
const ARRIVAL := "manifest_arrival_fixture"

class FailedStartReader:
    extends "res://scripts/world_config_read_job.gd"
    var attempts := 0
    func request(_path: String) -> int:
        attempts += 1
        return 0 # Idle, no accepted ticket: deterministic Thread.start failure.

class StartupFailureHost:
    extends Node
    var world_initial_error := ""
    var world_slot := 3
    var world_save_path := "user://world_route_manifest_startup_failure.json"
    var retried_slot := 0
    var retried_path := ""
    func _replace_with_save_slot(slot: int, path: String) -> void:
        retried_slot = slot
        retried_path = path

var scene: Node
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)
        push_error("WORLD_ROUTE_MANIFEST_INTEGRATION: " + label)

func _frames(count: int = 1) -> void:
    for unused in count: await process_frame

func _clean() -> void:
    for suffix in ["", ".bak", ".tmp"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))

func _escape(pressed: bool) -> void:
    var event := InputEventKey.new()
    event.physical_keycode = KEY_ESCAPE
    event.keycode = KEY_ESCAPE
    event.pressed = pressed
    Input.parse_input_event(event)
    Input.flush_buffered_events()

func _node_ids() -> Array:
    # An actionable error toast may legitimately attach/retire a one-shot SFX
    # player. Every region/gameplay owner must otherwise remain identical.
    return scene.get_children().filter(func(node): return not (node is AudioStreamPlayer and String(node.name).begins_with("Sfx_"))).map(func(node): return node.get_instance_id())

func _at_boundary(loader: RefCounted, boundary: String) -> bool:
    var metric: Dictionary = loader.last_transition
    match boundary:
        "manifest_copy":
            return loader.manifest_refresh_running and loader.config_read_job._thread == null and not ROUTES.cache_is_current()
        "preflight_done":
            return loader.phase == "preflight" and bool(metric.get("preflight_done", false))
        "target_build":
            return loader.phase == "loading" and int(metric.get("max_build_operations", 0)) > 0
        "final_handoff":
            return loader.phase == "committing" and int(metric.get("commit_jobs", 0)) > 0 and int(metric.get("commit_cursor", 0)) == int(metric.commit_jobs)
    return false

func _wait_boundary(loader: RefCounted, boundary: String) -> bool:
    for unused in 3000:
        if _at_boundary(loader, boundary): return true
        if loader.phase == "idle" and not loader.manifest_refresh_running: break
        await process_frame
    _check(false, "reaches requested bounded fault window " + boundary)
    return false

func _wait_token(token: RefCounted) -> bool:
    if token == null:
        _check(false, "foreground request owns a transition token")
        return false
    for unused in 3000:
        if token.finished:
            _check(scene.world_loader.phase == "idle" and scene.world_loader.transition_token == null, "completed foreground token releases loader ownership")
            return true
        await process_frame
    _check(false, "foreground token finishes within component frame bound")
    return false

func _refresh() -> void:
    var loader: RefCounted = scene.world_loader
    # Backoff uses monotonic wall time. A SceneTreeTimer consumes frame delta
    # and can expire before that wall-clock deadline on a long rendering frame.
    # Keep the ordinary retry gate; wait until it really admits the next job.
    for unused in 3000:
        if not ROUTES.cache_is_current() and not loader.manifest_refresh_running and Time.get_ticks_msec() >= loader.manifest_refresh_retry_after_msec:
            loader.request_manifest_refresh(scene)
        if ROUTES.cache_is_current() and not loader.manifest_refresh_running: break
        await process_frame
    _check(ROUTES.cache_is_current() and not loader.manifest_refresh_running and loader.config_read_job._accepted == 0, "idle refresh publishes a valid manifest and releases the sole worker ticket")

func _target_entry() -> Vector2:
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TARGET_PATH))
    return Vector2(raw.player_start[0], raw.player_start[1])

func _seed_reward_candidate() -> void:
    # Same isolated wish-board publication oracle as world_async_loading.
    # This is NOT an earned quest or a natural ending/campaign fixture.
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TARGET_PATH))
    raw.wish_board = [{"id": "manifest_commit_fixture", "title": "清单交接夹具", "desc": "",
        "target_flag": "manifest_source_fixture", "reward_currency": 200}]
    var pref: RefCounted = scene.world_prefetch
    pref.synchronize_route_cache()
    pref.desired[TARGET] = {"path": TARGET_PATH, "entry": _target_entry(), "distance": 0}
    pref.configs[TARGET] = {"raw": raw, "stamp": FileAccess.get_modified_time(TARGET_PATH)}

func _generation_windows() -> void:
    scene.story_flags["manifest_source_fixture"] = true
    # A committed #83 narrative fact must survive every source rebuild.
    scene.story_flags["quest_root_rescue_complete"] = true
    scene._save_world()
    var saved_source := STATE.new()
    _check(saved_source.read(SAVE), "modern narrative source fixture has a valid isolated save")
    var state_before: Dictionary = scene.world_state.data.duplicate(true)
    var source_flags: Dictionary = scene.story_flags.duplicate(true)
    var inventory: Dictionary = scene.inventory_counts.duplicate(true)
    var currency: int = scene.currency_count
    var body: Vector2 = scene.player.global_position
    var persistent := [scene.get_instance_id(), scene.player.get_instance_id(), scene.build_system.get_instance_id(), scene.world_state.get_instance_id(), scene.world_narrative.get_instance_id()]
    var migration: Dictionary = scene.world_narrative.npc_world_state("npc_root_prisoner", source_flags)
    for boundary in ["preflight_done", "target_build", "final_handoff"]:
        _seed_reward_candidate()
        var source_nodes := _node_ids()
        var save_before := FileAccess.get_file_as_bytes(SAVE)
        var generation: int = scene.world_loader.generation
        var token: RefCounted = scene.world_loader.request_region_transition(scene, TARGET_PATH, _target_entry(), {ARRIVAL: true})
        if not await _wait_boundary(scene.world_loader, boundary): return
        _check(not bool(scene.story_flags.get(REWARD, false)) and not bool(scene.story_flags.get(ARRIVAL, false)) and FileAccess.get_file_as_bytes(SAVE) == save_before, boundary + ": completed candidate has not published reward, narrative flag or save")
        var route_generation := ROUTES.cached_generation()
        ROUTES._cache_generation += 1 # Lease race; authored route data stays intact.
        if not await _wait_token(token): return
        _check(not token.succeeded and ROUTES.cached_generation() > route_generation, boundary + ": changed route generation fails closed")
        _check(String(scene.config.id) == SOURCE and scene.player.global_position == body, boundary + ": source region and exact local location restore")
        _check(scene.story_flags == source_flags and scene.inventory_counts == inventory and scene.currency_count == currency, boundary + ": unaccepted destination cannot leak reward or story state")
        _check(scene.world_state.data == state_before and scene.world_narrative.npc_world_state("npc_root_prisoner", scene.story_flags) == migration, boundary + ": #83 source journal and rescued-NPC state survive")
        _check(persistent == [scene.get_instance_id(), scene.player.get_instance_id(), scene.build_system.get_instance_id(), scene.world_state.get_instance_id(), scene.world_narrative.get_instance_id()], boundary + ": persistent host/player/build/state/narrative owners survive")
        var restored := STATE.new()
        _check(restored.read(SAVE) and restored.data == saved_source.data, boundary + ": restart sees source only, with no destination discovery")
        _check(scene.player.collision_layer == 1 and scene.player.collision_mask != 0 and not scene.world_loading and not scene.chapter_transitioning and scene.world_loader.loading_canvas == null and scene.ui_shell.construction_complete, boundary + ": rollback restores complete UI/input/collision")
        if boundary == "preflight_done":
            _check(_node_ids() == source_nodes and scene.world_loader.generation == generation and not scene.world_loader.last_transition.rolled_back, "preflight lease rejection never evicts any source node")
        else:
            _check(bool(scene.world_loader.last_transition.rolled_back), boundary + ": partial target is retired and source rebuilt")
    # This explicit retry is the positive oracle for both withheld outcomes.
    _seed_reward_candidate()
    var retry: RefCounted = scene.world_loader.request_region_transition(scene, TARGET_PATH, _target_entry(), {ARRIVAL: true})
    if not await _wait_token(retry): return
    _check(retry.succeeded and String(scene.config.id) == TARGET and bool(scene.story_flags.get(ARRIVAL, false)), "explicit retry publishes the accepted target and its arrival flag")
    _check(scene.currency_count == currency + 200 and bool(scene.story_flags.get(REWARD, false)), "successful retry publishes the withheld reward exactly once")
    var saved := STATE.new()
    _check(saved.read(SAVE) and saved.data.currency == currency + 200 and String(saved.data.current_region) == TARGET and bool(saved.data.story_flags.get(ARRIVAL, false)), "only successful retry persists target reward and arrival state")

func _worker_start_failure() -> void:
    var before := FileAccess.get_file_as_bytes(SAVE)
    var source_nodes := _node_ids()
    var old_generation := ROUTES._cache_generation
    ROUTES._cached_stamp = -1
    var host := StartupFailureHost.new()
    var file := FileAccess.open(host.world_save_path, FileAccess.WRITE)
    file.store_buffer(before)
    file.close()
    root.add_child(host)
    var startup := preload("res://scripts/world_region_loader.gd").new()
    var failed := FailedStartReader.new()
    startup.config_read_job = failed
    var token: RefCounted = startup.request_startup_region(host, Node.PROCESS_MODE_DISABLED)
    for unused in 12:
        if token.finished: break
        await process_frame
    _check(token.finished and startup.phase == "startup_error" and failed.attempts == 1, "idle worker start failure terminates cold startup promptly instead of waiting forever")
    var retry: Button = startup.loading_canvas.get_node_or_null("StartupRetry") if is_instance_valid(startup.loading_canvas) else null
    _check(is_instance_valid(retry) and not retry.disabled and not host.world_initial_error.is_empty(), "failed cold worker exposes the ordinary startup error and retry control")
    if is_instance_valid(retry):
        retry.pressed.emit()
        await _frames(2)
        _check(host.retried_slot == 3 and host.retried_path == host.world_save_path, "startup retry retains the selected save slot and path")
    _check(FileAccess.get_file_as_bytes(host.world_save_path) == before and ROUTES._cache_generation == old_generation, "failed cold startup cannot overwrite old save bytes or publish a route candidate")
    var failed_path: String = host.world_save_path
    startup.shutdown()
    host.free()
    await _frames(3)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(failed_path))
    # The same failure in foreground preflight must return to the live source.
    var loader: RefCounted = scene.world_loader
    source_nodes = _node_ids()
    var healthy_reader: RefCounted = loader.config_read_job
    var foreground_failed := FailedStartReader.new()
    loader.config_read_job = foreground_failed
    token = loader.request_region_transition(scene, TARGET_PATH, _target_entry())
    for unused in 12:
        if token.finished: break
        await process_frame
    _check(token.finished and not token.succeeded and loader.phase == "idle" and foreground_failed.attempts == 1, "idle foreground worker start failure returns false and releases its transition token")
    _check(_node_ids() == source_nodes, "foreground start failure retains every source region/gameplay owner")
    _check(FileAccess.get_file_as_bytes(SAVE) == before and not loader.last_error.is_empty(), "foreground start failure retains save bytes and an actionable diagnostic")
    # Avoid leaving a broken coroutine hanging if this regression reappears.
    if not token.finished:
        loader.cancel_transition()
        await _frames(3)
    foreground_failed.shutdown()
    loader.config_read_job = healthy_reader
    await _refresh()
    _check(ROUTES.cached_generation() > old_generation, "healthy sole reader can explicitly retry after a deterministic start failure")

func _short_escape_windows() -> void:
    for boundary in ["manifest_read", "manifest_copy"]:
        var source_nodes := _node_ids()
        var before := FileAccess.get_file_as_bytes(SAVE)
        var old_generation := ROUTES._cache_generation
        ROUTES._cached_stamp = -1
        var token: RefCounted = scene.world_loader.request_region_transition(scene, TARGET_PATH, _target_entry())
        if boundary == "manifest_copy":
            if not await _wait_boundary(scene.world_loader, boundary): return
        else:
            _check(scene.world_loader.manifest_refresh_running and scene.world_loader.config_read_job._accepted > 0, "cold preflight exposes its real sole-worker read cancellation window")
        _escape(true)
        await process_frame
        _escape(false)
        if not await _wait_token(token): return
        _check(not token.succeeded and bool(scene.world_loader.last_transition.get("preflight_cancelled", false)), boundary + ": a one-frame physical Esc cancels the foreground manifest handoff")
        _check(ROUTES._cache_generation == old_generation and not ROUTES.cache_is_current(), boundary + ": cancelled private manifest copy never publishes")
        _check(_node_ids() == source_nodes and FileAccess.get_file_as_bytes(SAVE) == before and String(scene.config.id) == SOURCE, boundary + ": cancellation preserves source objects and save bytes")
        await _refresh()
        _check(ROUTES.cached_generation() > old_generation, boundary + ": released worker retries successfully from idle")

func _obsolete_refresh_ticket() -> void:
    var loader: RefCounted = scene.world_loader
    var before := FileAccess.get_file_as_bytes(SAVE)
    var old_generation := ROUTES._cache_generation
    ROUTES._cached_stamp = -1
    loader.request_manifest_refresh(scene)
    if not await _wait_boundary(loader, "manifest_copy"): return
    loader.generation += 1 # Supersedes the real in-flight ticket after worker read.
    for unused in 3000:
        if not loader.manifest_refresh_running: break
        await process_frame
    _check(not loader.manifest_refresh_running and not ROUTES.cache_is_current() and ROUTES._cache_generation == old_generation, "superseded background ticket discards its private copy without cache publication")
    _check(FileAccess.get_file_as_bytes(SAVE) == before, "obsolete refresh cannot write progression")
    await _refresh()
    _check(ROUTES.cached_generation() > old_generation, "obsolete refresh is retryable through the same worker after its backoff")

func _seed_detached(pref: RefCounted) -> Dictionary:
    var id := String(scene.config.id)
    var path: String = scene.config_path
    var entry: Vector2 = scene.player.global_position
    pref.generation = scene.world_loader.generation
    pref.route_cache_seen = true
    pref.route_cache_generation = ROUTES.cached_generation()
    pref.selection_elapsed = -100000
    pref.desired[id] = {"path": path, "entry": entry, "distance": 0}
    pref.configs[id] = {"path": path, "entry": entry, "stamp": FileAccess.get_modified_time(path), "raw": scene.config, "prepared": scene.config}
    var owned: Array[Node] = []
    var bodies: Dictionary = {}
    var platform := {"id": "manifest_lease_0", "rect": [entry.x - 60, entry.y + 40, 120, 20]}
    for index in 3:
        var data := {"id": "manifest_lease_%d" % index, "rect": [entry.x - 60 + index * 140, entry.y + 40, 120, 20]}
        var node := BODY.create(String(data.id), Rect2(data.rect[0], data.rect[1], data.rect[2], data.rect[3]), "")
        bodies[String(data.id)] = {"body": node, "data": data}
        owned.append(node)
    var collision := {"polygon": PackedVector2Array([entry + Vector2(-100, 40), entry + Vector2(100, 40), entry + Vector2(100, 100), entry + Vector2(-100, 100)]), "one_way": false}
    var polygon := GEOMETRY.terrain_polygon(collision)
    owned.append(polygon)
    pref.entities[id] = {"entry": entry, "pending": [], "bodies": bodies, "collisions": {"terrain:fixture": {"body": polygon, "data": collision}}}
    var actors: Dictionary = {}
    var npc: Dictionary = scene.config.npcs[0].duplicate(true)
    for index in 2:
        var data: Dictionary = npc.duplicate(true)
        data.id = "manifest_lease_npc_%d" % index
        var actor: Area2D = scene._create_gameplay_prefab("npc", data, scene.config)
        actors["npc:" + String(data.id)] = {"actor": actor, "data": data, "profile": {}}
        owned.append(actor)
        if index == 0: npc = data
    pref.gameplay.generation = scene.world_loader.generation
    pref.gameplay.regions[id] = {"entry": entry, "stamp": FileAccess.get_modified_time(path), "path": path, "prepared": scene.config, "pending": [], "actors": actors}
    return {"id": id, "path": path, "platform": platform, "collision": collision, "npc": npc, "owned": owned}

func _cached_ownership() -> void:
    _check(ROUTES.cache_is_current(), "cache adoption component begins with a valid real route lease")
    if not ROUTES.cache_is_current(): return
    var real_pref: RefCounted = scene.world_prefetch
    var loader: RefCounted = scene.world_loader
    loader.phase = "preflight" # Suppress read/refresh admission; this component owns its leases.
    for stale in [false, true]:
        for accessor in ["raw", "platform", "collision", "gameplay", "landing_support"]:
            var pref := PREFETCH.new()
            var fixture := _seed_detached(pref)
            var support: Node
            if accessor == "landing_support":
                # Geometry-only positive control: same-generation cached floor
                # really intersects this landing and creates physical support.
                support = PASSAGE.new()
                support.bind(scene)
                root.add_child(support)
                support.source_id = String(fixture.id)
                support.destination_id = String(fixture.id)
                support.destination_point = pref.desired[fixture.id].entry
                scene.world_prefetch = pref
                support._build_landing_support()
                scene.world_prefetch = real_pref
                _check(support.get_node_or_null("PassageLanding") != null and not support.landing_support_key.is_empty() and pref.retiring.is_empty(), "same-generation landing support borrows matching geometry without adopting or retiring its cache")
                for child in support.get_children(): child.free()
                support.landing_support_key = ""
            var stamp := ROUTES._cached_stamp
            if stale: ROUTES._cached_stamp = -1
            else: ROUTES._cache_generation += 1
            var taken: Variant = null
            # No prefetch.step occurs between invalidation and the production
            # adoption API. All objects are genuine detached physics/prefabs.
            match accessor:
                "raw": taken = pref.cached_raw(String(fixture.path))
                "platform": taken = pref.take_platform(String(fixture.id), fixture.platform)
                "collision": taken = pref.take_collision(String(fixture.id), "terrain", "fixture", fixture.collision)
                "gameplay":
                    scene.world_prefetch = pref
                    taken = scene._take_gameplay_prefab("npc", fixture.npc)
                    scene.world_prefetch = real_pref
                "landing_support":
                    scene.world_prefetch = pref
                    support._build_landing_support()
                    scene.world_prefetch = real_pref
                    taken = support.get_node_or_null("PassageLanding")
                    _check(support.landing_support_key.is_empty(), "obsolete landing lease cannot expose a cached support key before any prefetch step")
            var label := "%s stale=%s" % [accessor, stale]
            _check(taken == null, label + ": first cache-use call cannot adopt an obsolete route lease")
            if is_instance_valid(support): support.free()
            _check(pref.entities.is_empty() and pref.configs.is_empty() and pref.gameplay.regions.is_empty(), label + ": invalidation detaches both geometry and gameplay ownership")
            _check(pref.entity_releases == 0 and pref.gameplay.releases == 0 and pref.retiring.size() == 4 and pref.gameplay.retiring.size() == 2 and fixture.owned.all(func(node): return is_instance_valid(node) and not node.is_inside_tree()), label + ": foreground adoption only enqueues retirement, never eagerly frees")
            pref.selection_elapsed = -100000
            var bounded := true
            for unused in 12:
                var released: int = pref.entity_releases + pref.gameplay.releases
                pref.step(scene, 0)
                bounded = bounded and pref.entity_releases + pref.gameplay.releases - released <= 2
                if pref.retiring.is_empty() and pref.gameplay.retiring.is_empty(): break
                await process_frame
            _check(bounded and pref.snapshot().owned_bodies == 0 and pref.gameplay.owned() == 0 and fixture.owned.all(func(node): return not is_instance_valid(node)), label + ": shared two-object frame cap eventually retires every obsolete owner")
            pref.shutdown()
            ROUTES._cached_stamp = stamp
    loader.phase = "idle"
    _check(scene.world_prefetch == real_pref, "cache component restores the real host prefetch owner")

func _atlas_refresh() -> void:
    var id := String(scene.config.id)
    var original := ATLAS.terrain(id)
    _check(not original.is_empty(), "atlas direct terrain cache begins with real geometry")
    if original.is_empty(): return
    ATLAS.configurations[id]["manifest_stale_fixture"] = true
    ATLAS.geometry["obsolete_fixture"] = []
    ATLAS.room_contours["obsolete_fixture:room"] = []
    ROUTES._cache_generation += 1
    var refreshed := ATLAS.terrain(id) # Deliberately no configuration() first.
    _check(refreshed == original and not ATLAS.configurations[id].has("manifest_stale_fixture") and not ATLAS.geometry.has("obsolete_fixture") and ATLAS.room_contours.is_empty(), "direct terrain hit revalidates route generation and clears configuration/geometry/contour caches")
    scene._toggle_map()
    scene.world_map_view = true
    scene._refresh_map_overlay()
    var camera: Control = scene.survey_map_view
    camera.magnify(2.0, Vector2(300, 180))
    var pan: Vector2 = scene.map_draw_root.position
    var flags: Dictionary = scene.story_flags.duplicate(true)
    var body: Vector2 = scene.player.global_position
    var old_generation := ROUTES.cached_generation()
    ROUTES._cached_stamp = -1
    _check(ATLAS.terrain(id).is_empty() and ATLAS.configurations.is_empty() and ATLAS.geometry.is_empty() and ATLAS.room_contours.is_empty(), "stale terrain direct hit exposes no old atlas geometry")
    scene._refresh_map_overlay() # Starts the production background refresh.
    _check(scene.map_draw_root.get_node_or_null("WorldRegion_" + id) == null, "stale open atlas withholds its old region drawing")
    for unused in 3000:
        if not scene.world_loader.manifest_refresh_running: break
        await process_frame
    _check(ROUTES.cached_generation() > old_generation and scene.map_draw_root.get_node_or_null("WorldRegion_" + id) != null and scene.map_draw_root.get_node_or_null("WorldSurveyPlayer") != null, "completed background refresh redraws the still-open modern world map")
    _check(camera.zoom == 2.0 and scene.map_draw_root.position == pan and scene.active_overlay == "map", "background atlas redraw preserves zoom/pan and the chosen map view")
    var event := InputEventKey.new()
    event.physical_keycode = KEY_D
    event.pressed = true
    camera._input(event)
    camera._process(0.1)
    event.pressed = false
    camera._input(event)
    _check(scene.map_draw_root.position.x < pan.x and camera.keyboard_pan == Vector2.ZERO, "refreshed atlas retains keyboard navigation and release")
    var axis := InputEventJoypadMotion.new()
    axis.device = 5
    axis.axis = JOY_AXIS_LEFT_Y
    axis.axis_value = 1.0
    var before: Vector2 = scene.map_draw_root.position
    camera._input(axis)
    camera._process(0.1)
    axis.axis_value = 0.0
    camera._input(axis)
    _check(scene.map_draw_root.position.y < before.y and camera.stick_pan == Vector2.ZERO, "refreshed atlas retains controller navigation and dead zone")
    _check(scene.story_flags == flags and scene.player.global_position == body, "refresh and map navigation do not chart, buy maps or move the player")
    camera.reset()
    scene._close_overlays()

func _passage_recovery_and_exit() -> Dictionary:
    # Start at the current CH06 root-pipe mouth. This fixture positions the
    # terminal to reach rollback promptly; no full-walk claim is made here.
    var passage: Node = scene.world_passage
    var mouth: Node = scene.get_node("upgrade_greenhouse_crown_branch_b")
    scene.player.global_position = mouth.global_position
    scene.player.velocity = Vector2.ZERO
    _check(passage.begin(String(mouth.name)), "modern root-pipe component admits its ungated reverse mouth")
    var source_id := String(scene.config.id)
    var source_save := FileAccess.get_file_as_bytes(SAVE)
    ROUTES._cached_stamp = -1
    scene.player.global_position = passage.destination_point + Vector2(0, 40) # Recovery-only terminal fixture.
    passage.step()
    if not await _wait_boundary(scene.world_loader, "preflight_done"): return {}
    ROUTES._cache_generation += 1
    for unused in 3000:
        if not passage.settling: break
        await process_frame
    _check(passage.active and passage.retry_blocked and String(scene.config.id) == source_id and FileAccess.get_file_as_bytes(SAVE) == source_save, "modern terminal lease failure resumes isolated transit and retains source save")
    _check(scene.player.collision_mask == 64 and scene.world_loading and not scene.ui_canvas.visible, "failed modern terminal keeps source signals and ordinary collision isolated")
    var direction := 1 if passage.destination_point.x > passage.source_point.x else -1
    var forward := "move_right" if direction > 0 else "move_left"
    Input.action_press(forward)
    passage.step()
    _check(not passage.retry_blocked, "a new directional input explicitly releases failed terminal retry")
    scene.player.process_mode = Node.PROCESS_MODE_ALWAYS
    for unused in 3000:
        await physics_frame
        await process_frame
        if not passage.settling: passage.step()
        if passage.settling: scene.player.process_mode = Node.PROCESS_MODE_INHERIT
        if not passage.active: break
    Input.action_release(forward)
    scene.player.process_mode = Node.PROCESS_MODE_INHERIT
    _check(not passage.active and bool(passage.last_result.get("arrived", false)) and String(scene.config.id) == SOURCE, "explicit retry walks the remaining terminal step and commits the correct modern region")
    if passage.active or String(scene.config.id) != SOURCE: return {}
    # Gate fixture only for testing source exit/re-entry, not campaign rewards.
    scene._add_inventory_item("lantern_phase", 1, false)
    scene._sync_player_abilities()
    mouth = scene.get_node("upgrade_greenhouse_crown_branch_a")
    scene.player.global_position = mouth.global_position
    scene.player.velocity = Vector2.ZERO
    _check(passage.begin(String(mouth.name)), "root-pipe component re-enters with its explicit ability-gate fixture")
    ROUTES._cached_stamp = -1
    Input.action_press("close_overlay")
    passage.step()
    Input.action_release("close_overlay")
    _check(not passage.active and not scene.world_loading and scene.player.collision_layer == 1 and scene.ui_canvas.visible and scene.player.global_position == mouth.global_position, "Esc from stale-route transit restores the modern source mouth/UI/collision")
    await _refresh()
    await _frames(2)
    _check(passage.begin(String(mouth.name)), "cancelled modern connector can be admitted again after worker refresh")
    direction = 1 if passage.destination_point.x > passage.source_point.x else -1
    var backward := "move_left" if direction > 0 else "move_right"
    Input.action_press(backward)
    scene.player.process_mode = Node.PROCESS_MODE_ALWAYS
    for unused in 120:
        await physics_frame
        await process_frame
        passage.step()
        if not passage.active: break
    Input.action_release(backward)
    scene.player.process_mode = Node.PROCESS_MODE_INHERIT
    _check(not passage.active and not bool(passage.last_result.get("cancelled", true)) and not bool(passage.last_result.get("arrived", true)) and String(scene.config.id) == SOURCE, "real reverse input leaves the modern mouth into source without destination publication")
    scene.player.global_position = mouth.global_position # Teardown component setup only.
    scene.player.velocity = Vector2.ZERO
    _check(passage.begin(String(mouth.name)), "modern connector is reusable after physical reversal")
    ROUTES._cached_stamp = -1
    scene.player.global_position = passage.destination_point + Vector2(0, 40) # Teardown-only terminal fixture.
    passage.step()
    var loader: RefCounted = scene.world_loader
    var reader: RefCounted = loader.config_read_job
    var retired_owners := {"loader": weakref(loader), "reader": weakref(reader)}
    # Observe the real terminal token without introducing a fixture-owned strong
    # reference that could itself keep the transition alive after host teardown.
    if loader.transition_token != null:
        retired_owners["token"] = weakref(loader.transition_token)
    print("MANIFEST_TERMINAL_OWNERS loader_id=%d reader_id=%d token_id=%d" % [loader.get_instance_id(), reader.get_instance_id(), loader.transition_token.get_instance_id() if loader.transition_token != null else 0])
    source_save = FileAccess.get_file_as_bytes(SAVE)
    _check(loader.phase == "preflight" and loader.manifest_refresh_running, "teardown interrupts a real cold terminal manifest request")
    scene.free()
    scene = null
    current_scene = null
    await _frames(3)
    _check(reader.closed and not reader.busy() and reader._accepted == 0 and not loader.manifest_refresh_running and loader.loading_canvas == null and loader.phase == "idle", "host exit drains the sole reader and abandons terminal/loading ownership")
    _check(FileAccess.get_file_as_bytes(SAVE) == source_save and not ROUTES.cache_is_current(), "terminal exit neither saves the destination nor publishes its abandoned manifest")

    # Business-state shutdown is not sufficient: the externally awaited loader
    # coroutine must also release the sole reader after its Node caller exits.
    loader = null
    reader = null
    return retired_owners

func _run() -> void:
    root.process_mode = Node.PROCESS_MODE_DISABLED
    _clean()
    scene = load("res://scenes/World.tscn").instantiate()
    scene.world_resume = false
    scene.world_save_path = SAVE
    scene.config_path = "res://data/%s.json" % SOURCE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene = scene
    ROUTES.sync_manifest_parses = 0
    await _worker_start_failure()
    await _short_escape_windows()
    await _obsolete_refresh_ticket()
    await _cached_ownership()
    await _atlas_refresh()
    await _generation_windows()
    var retired_owners: Dictionary = await _passage_recovery_and_exit()
    _check(ROUTES.sync_manifest_parses == 0, "all modern integration paths remain cache-only with zero synchronous route parses")
    _escape(false)
    for action in ["move_left", "move_right", "close_overlay"]:
        if InputMap.has_action(action): Input.action_release(action)
    if is_instance_valid(scene): scene.free()
    current_scene = null
    await _frames(3)
    _check(retired_owners.has("loader") and retired_owners.loader.get_ref() == null, "terminal teardown releases the real loader coroutine owner after its existing frame boundary")
    _check(retired_owners.has("reader") and retired_owners.reader.get_ref() == null, "terminal teardown releases the sole reader object after its existing frame boundary")
    _check(retired_owners.has("token") and retired_owners.token.get_ref() == null, "terminal teardown releases the passage transition token after its existing frame boundary")
    print("MANIFEST_TERMINAL_RELEASE loader_alive=%s reader_alive=%s token_alive=%s" % [retired_owners.has("loader") and retired_owners.loader.get_ref() != null, retired_owners.has("reader") and retired_owners.reader.get_ref() != null, retired_owners.has("token") and retired_owners.token.get_ref() != null])
    _clean()
    print("WORLD_ROUTE_MANIFEST_INTEGRATION checks=%d failures=%d" % [checks, failures.size()])
    quit(0 if failures.is_empty() else 1)
