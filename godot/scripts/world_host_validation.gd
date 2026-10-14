extends SceneTree
## Stateful fixtures, not natural traversal or full combat acceptance.
const STATE := preload("res://scripts/world_state.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const CARTO := preload("res://scripts/pilgrimage_cartography.gd")
const AUDIO := preload("res://scripts/audio_director.gd")
const PATH := "user://world_host_validation.json"
var checks := 0
var failures: Array[String] = []
var scene: Node
var peak_nodes := 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    _clean()
    root.process_mode = Node.PROCESS_MODE_DISABLED
    scene = load("res://scenes/World.tscn").instantiate()
    scene.world_resume = false
    scene.world_save_path = PATH
    root.add_child(scene)
    current_scene = scene
    await _frames()
    var host_id := scene.get_instance_id()
    var player_id: int = scene.player.get_instance_id()
    var camera_id: int = scene.player.get_node("Camera2D").get_instance_id()
    var state_id: int = scene.world_state.get_instance_id()
    var build_id: int = scene.build_system.get_instance_id()
    var loader_id: int = scene.world_loader.get_instance_id()
    var first_region := String(scene.config.id)
    var first_nodes := scene.get_child_count()
    _check(scene.world_loader.generation == 1, "initial region registered once")
    for ability in scene.WORLD_ABILITIES:
        scene._add_inventory_item(ability, 1, false)
    scene._refresh_ability_gates()
    scene.currency_count = 247
    scene.story_flags["host_validation_story"] = true
    CARTO.purchase(scene.story_flags, first_region, scene.currency_count)
    CARTO.visit(scene.story_flags, first_region, "entry_bell")
    CARTO.rest(scene.story_flags)
    CARTO.visit(scene.story_flags, first_region, "secret_fixture")
    scene.world_collected_ids["host_validation_pickup"] = true
    scene.opened_shortcuts["host_validation_shortcut"] = true
    scene.player.hp = 3
    scene.player.energy = 58
    scene.player.dash_cooldown = 1.2
    scene.player.guard_cooldown = 0.9
    scene.player.resonance_cooldown = 1.4
    scene.player.grapple_recovery_timer = 0.4
    scene.build_system.cooldowns["cleave"] = 4.5
    scene._save_world()
    var journal: Dictionary = scene.story_flags[CARTO.KEY].duplicate(true)
    var before_nodes := scene.get_child_count()
    var before_state: Dictionary = scene.world_state.data.duplicate(true)
    var before_position: Vector2 = scene.player.global_position
    var generation: int = scene.world_loader.generation
    for invalid_entry in [Vector2.INF, Vector2(-500, -500)]:
        scene._travel_world(ROUTES.config_path(first_region), invalid_entry)
        _check(scene.world_loader.phase == "idle" and scene.world_loader.generation == generation, "invalid arrival leaves loader idle")
        _check(scene.get_child_count() == before_nodes and scene.player.global_position == before_position, "failed preflight retains geometry and player")
        _check(scene.world_state.data == before_state and not scene.chapter_transitioning, "failed preflight retains state and input")
    scene._travel_world("res://data/missing_world_region.json", Vector2.ZERO)
    _check(scene.get_child_count() == before_nodes and scene.world_loader.generation == generation, "missing target cannot evict current region")
    var music_rest: float = scene.audio_director._music_rest_db()
    scene.audio_director.begin_chapter_transition()
    var transition: Tween = scene.audio_director.bus_tweens.get("BGM")
    scene.audio_director._set_bus_db("BGM", -60)
    scene._travel_world("res://data/missing_world_region.json", Vector2.ZERO)
    _check(not transition.is_valid() and not scene.audio_director.bus_tweens.has("BGM"), "failed load cancels music fade")
    _check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("BGM")), music_rest), "failed load restores current music mix")
    var initial_config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROUTES.config_path(first_region)))
    for field in ["world", "map_rooms", "platforms", "inventory"]:
        var corrupt: Dictionary = initial_config.duplicate(true)
        corrupt[field] = [1] if field == "map_rooms" else [] if field in ["world", "inventory"] else {}
        _check(scene.world_loader.validate_config(corrupt, ROUTES.config_path(first_region), before_position).is_empty(), "reject malformed " + field + " before overlay construction")
        _check(scene.get_child_count() == before_nodes and scene.world_loader.generation == generation, "bad config cannot evict region " + field)
    scene.world_loader.phase = "loading"
    _check(not scene.world_loader.replace_region(scene, ROUTES.config_path(first_region), before_position), "reentrant replacement rejected")
    scene.world_loader.phase = "idle"
    scene._defer_region_call("_toast", ["world host live callback"])
    await _frames()
    _check(scene.toast_label.text == "world host live callback", "current-generation deferred callback executes")
    # Keep live references to the departing physics geometry to verify cleanup.
    var old_terrain: Node = scene.chapter_terrain
    var old_audio: Node = scene.audio_director
    var old_seller: Node = scene.get_node("npc_gear_cartographer")
    var anchor: Node2D = null
    var body: PhysicsBody2D = null
    for node in scene.get_children():
        if node is Node2D and node.is_in_group("grapple_anchor"):
            anchor = node
        if node is PhysicsBody2D:
            body = node
    _check(anchor != null and body != null, "fixture has anchor and terrain body")
    if anchor != null:
        scene.player.grapple_anchor = anchor
        scene.player.grapple_timer = 0.5
    if body != null:
        scene.player.add_collision_exception_with(body)
        scene.player.phase_exceptions.append(body)
        scene.player.phase_active = true
        scene.player.phase_safe_position = scene.player.global_position
    scene.player.attack_timer = 0.2
    scene.player.active_skill = {"kind": "resonance"}
    scene.player.traversal_downstrike_active = true
    scene.player.velocity = Vector2(150, -200)
    # Exercise a legitimate partially refundable interruption without awarding
    # a completed heal or restoring the pre-interruption resource snapshot.
    scene.player.build_profile["heal_interrupt_loss_ratio"] = 0.5
    scene.player.heal_timer = 0.6
    scene.player.heal_reserved_cost = 20
    var tween: Tween = scene._region_tween()
    tween.tween_interval(2)
    var target := "demo_ch02_rain_foundry_canal"
    scene._defer_region_call("_record_death_cache")
    scene._defer_region_call("_activate_chapter_exit", [old_seller])
    scene._travel_world(ROUTES.config_path(target), Vector2(330, 720))
    await _frames()
    _check(not is_instance_valid(old_terrain) and not is_instance_valid(old_audio) and not is_instance_valid(old_seller), "old terrain audio and seller freed immediately")
    _check(not tween.is_valid(), "old host-bound tween cancelled")
    _check(scene.currency_count == 247 and scene.world_state.data.death_cache.is_empty(), "departed-generation callbacks cannot mutate new region")
    _check(scene.player.grapple_anchor == null and scene.player.grapple_timer == 0 and scene.player.phase_exceptions.is_empty() and not scene.player.phase_active, "geometry references cancelled before eviction")
    _check(scene.player.heal_timer == 0 and scene.player.attack_timer == 0 and scene.player.active_skill.is_empty() and not scene.player.traversal_downstrike_active, "actions do not leak into next region")
    _check(scene.player.energy == 68 and scene.player.hp == 3, "heal cancellation settles ten-point refund without healing")
    _check(scene.player.dash_cooldown == 1.2 and scene.player.guard_cooldown == 0.9 and scene.player.resonance_cooldown == 1.4, "travel cannot erase action cooldowns")
    _check(scene.player.grapple_recovery_timer == 0.4, "travel retains grapple recovery")
    _check(scene.build_system.cooldowns.get("cleave", 0) == 4.5, "skill cooldown remains on same build instance")
    _check(scene.player.velocity == Vector2.ZERO and not scene.player.ui_input_locked, "safe arrival clears movement and input lock")
    _check(scene.nearby_interactable == null and scene.boss_actor == null and not scene.boss_spawned and not scene.pending_enemy_respawn, "region-local references reset")
    var region_ids: Array = scene.WORLD_COORDINATES.manifest().regions.keys()
    var warmed_counts: Dictionary = {}
    # Six complete revisits after warmup: deterministic scene-tree residency
    # checks, not a claim of long-duration GPU/audio memory stability.
    for cycle in range(7):
        for region_value in region_ids:
            var region_id := String(region_value)
            var path := ROUTES.config_path(region_id)
            var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
            var entry: Array = config.player_start
            scene._travel_world(path, Vector2(entry[0], entry[1]))
            await _frames()
            var settled := await _settle_region_runtime()
            _check(settled, "region residency and one-shot audio settle " + region_id)
            _check(current_scene == scene and scene.get_instance_id() == host_id, "host identity " + region_id)
            _check(scene.player.get_instance_id() == player_id and scene.player.get_node("Camera2D").get_instance_id() == camera_id, "player/camera identity " + region_id)
            _check(scene.world_state.get_instance_id() == state_id and scene.build_system.get_instance_id() == build_id and scene.world_loader.get_instance_id() == loader_id, "session identities " + region_id)
            var status: Dictionary = scene.world_loader.snapshot(scene)
            _check(status.resident_regions == 1 and status.phase == "idle" and status.region_id == region_id, "one resident chunk " + region_id)
            _check(scene.player.hp == 3 and scene.player.energy == 68 and scene.currency_count == 247, "resources preserved " + region_id)
            _check(scene.story_flags[CARTO.KEY].get(first_region, {}) == journal[first_region] and scene.story_flags.host_validation_story, "survey and story preserved " + region_id)
            _check(scene.get_tree().get_nodes_in_group("player").size() == 1, "exactly one player " + region_id)
            _check(scene.player.hp_changed.get_connections().size() == 1 and scene.player.ability_action.get_connections().size() == 1, "signal bindings do not accumulate " + region_id)
            _check(AUDIO.instance == scene.audio_director and scene.audio_director.is_inside_tree(), "audio belongs to current chunk " + region_id)
            _check(scene.world_state.resume_local_position() == scene.active_spawn, "resume uses current bell " + region_id)
            peak_nodes = maxi(peak_nodes, scene.get_child_count())
            if cycle == 0:
                warmed_counts[region_id] = scene.get_child_count()
            else:
                var child_names: Array[String] = []
                for child in scene.get_children(): child_names.append(String(child.name))
                _check(scene.get_child_count() == warmed_counts[region_id], "bounded region node count " + region_id + " expected=" + str(warmed_counts[region_id]) + " actual=" + str(scene.get_child_count()) + " residency=" + JSON.stringify(scene.world_gameplay_residency.snapshot()) + " children=" + ",".join(child_names))
            if region_id == first_region:
                _check(scene.world_collected_ids.has("host_validation_pickup") and scene.opened_shortcuts.has("host_validation_shortcut"), "home region remembers pickups and shortcuts")
    var reboot := STATE.new()
    _check(reboot.read(PATH) and reboot.data.story_flags[CARTO.KEY].get(first_region, {}) == journal[first_region], "repeated transitions persist map journal to disk")
    _check(reboot.data.inventory_counts.size() >= 8, "all eight abilities persist")
    print("WORLD HOST METRICS: transitions=%d peak_region_nodes=%d initial_region_nodes=%d fixture_positioning=true" % [scene.world_loader.generation - 1, peak_nodes, first_nodes])
    scene.queue_free()
    await _frames()
    _clean()
    if failures.is_empty():
        print("WORLD HOST PASS: %d checks; persistent host/player, single-region eviction, cancellation, cooldowns, failure recovery and seven six-region cycles" % checks)
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)

func _frames() -> void:
    await process_frame
    await process_frame

func _settle_region_runtime() -> bool:
    var service: RefCounted = scene.world_gameplay_residency
    var previous_sfx_modes: Dictionary = {}
    var settled := false
    for _frame in range(180):
        service.update(scene, scene.player.global_position, scene.player.velocity, 1.0 / 60.0)
        var active_sfx := scene.get_children().filter(func(child): return child is AudioStreamPlayer and String(child.name).begins_with("Sfx_"))
        var pending_sfx: Array = []
        for pending_value in scene.pending_sfx_players.values():
            var pending: Dictionary = pending_value
            var player: AudioStreamPlayer = pending.get("player")
            if is_instance_valid(player): pending_sfx.append(player)
        for player in active_sfx + pending_sfx:
            var instance_id: int = player.get_instance_id()
            if not previous_sfx_modes.has(instance_id): previous_sfx_modes[instance_id] = player.process_mode
            player.process_mode = Node.PROCESS_MODE_ALWAYS
        var state: Dictionary = service.snapshot()
        if state.pending_build == 0 and state.pending_release == 0 and bool(state.window_ready) and active_sfx.is_empty() and pending_sfx.is_empty():
            # Let queue_free finish before measuring the host's strict node count.
            await process_frame
            state = service.snapshot()
            active_sfx = scene.get_children().filter(func(child): return child is AudioStreamPlayer and String(child.name).begins_with("Sfx_"))
            if state.pending_build == 0 and state.pending_release == 0 and bool(state.window_ready) and active_sfx.is_empty() and scene.pending_sfx_players.is_empty():
                settled = true
                break
        await process_frame
    for child in scene.get_children():
        var instance_id: int = child.get_instance_id()
        if previous_sfx_modes.has(instance_id): child.process_mode = int(previous_sfx_modes[instance_id])
    for pending_value in scene.pending_sfx_players.values():
        var pending: Dictionary = pending_value
        var player: AudioStreamPlayer = pending.get("player")
        if is_instance_valid(player) and previous_sfx_modes.has(player.get_instance_id()):
            player.process_mode = int(previous_sfx_modes[player.get_instance_id()])
    return settled

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)
        print("WORLD HOST FAILED: " + label)

func _clean() -> void:
    for suffix in ["", ".tmp", ".bak"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + suffix))
