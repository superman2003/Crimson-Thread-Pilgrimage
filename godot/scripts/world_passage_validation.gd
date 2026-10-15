extends SceneTree
## Real Player input along the full connector, with fixture endpoint placement.
## The tube has no encounters; this is not six-region combat acceptance.
const SAVE := "user://world_passage_validation.json"
const COORD := preload("res://scripts/world_coordinates.gd")
const STATE := preload("res://scripts/world_state.gd")
var scene: Node
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    scene = load("res://scenes/World.tscn").instantiate()
    scene.world_resume = false
    scene.world_save_path = SAVE
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene = scene
    await _frames(4)
    scene.process_mode = Node.PROCESS_MODE_DISABLED
    var passage: Node = scene.world_passage
    var host_id := scene.get_instance_id()
    var player_id: int = scene.player.get_instance_id()
    var build_id: int = scene.build_system.get_instance_id()
    var origin_id: String = scene.config.id
    scene.player.hp = 3
    scene.player.energy = 41
    scene.currency_count = 97
    scene.player.dash_cooldown = 1.1
    var portal: Node = scene.get_node("moss_rain_pipe")
    scene.player.global_position = portal.global_position
    _check(passage.begin("moss_rain_pipe"), "physical pipe enters at authored endpoint")
    _check(scene.player_world_position() == COORD.to_world(origin_id, portal.global_position), "entry does not teleport")
    _check(not passage.begin("moss_rain_pipe"), "double entry rejected")
    _check(scene.player.hp == 3 and scene.player.energy == 41 and scene.player.dash_cooldown == 1.1, "entry preserves resources and cooldown")
    _check(not scene.player._can_start_action(), "source actors cannot be attacked while frozen")
    _check(not scene.ui_canvas.visible, "source UI hidden in pipe")
    var before := FileAccess.get_file_as_string(SAVE)
    scene._save_world()
    _check(FileAccess.get_file_as_string(SAVE) == before, "pipe position is not written as checkpoint")
    var journal: Dictionary = scene.world_state.data.duplicate(true)
    var trap := Area2D.new()
    trap.set_meta("damage", 99)
    trap.set_meta("kind", "currency")
    trap.set_meta("amount", 999)
    scene._on_hazard_body_entered(scene.player, trap)
    scene._on_collectible_body_entered(scene.player, trap)
    trap.free()
    _check(scene.player.hp == 3 and scene.currency_count == 97, "frozen source signals cannot hurt or reward")
    _check(scene.world_state.data == journal, "unwalked destination stays unexplored")
    var flags_before: Dictionary = scene.story_flags.duplicate(true)
    scene._on_ability_action("thread_dash", scene.player.global_position, Vector2.RIGHT)
    scene._defer_region_call("_record_death_cache")
    await _frames(2)
    _check(scene.story_flags == flags_before and scene.world_state.data.death_cache.is_empty(), "tube actions/deferred callbacks cannot mutate source progression")
    # Explicit cancellation is allowed to return to the entry, not the far end.
    passage._return_to_source(true)
    await _frames(3)
    _check(not passage.active and scene.player.global_position == portal.global_position, "cancel returns to source endpoint")
    _check(scene.ui_canvas.visible and scene.player.collision_layer == 1, "cancel restores UI and collision")
    _check(scene.player._can_start_action(), "cancel restores combat input")
    # Walk back over the mouth rather than teleporting: real collision/input.
    _check(passage.begin("moss_rain_pipe"), "reenter for physical reversal")
    await _walk(-1, false)
    _check(String(scene.config.id) == origin_id and not passage.active, "walking backwards exits into source")
    for portal_id in ["moss_rain_pipe", "rain_moss_pipe"]:
        portal = scene.get_node_or_null(portal_id)
        if portal == null:
            _check(false, "expected portal exists " + portal_id)
            quit(1)
            return
        scene.player.global_position = portal.global_position # fixture placement
        var start: Vector2 = scene.player_world_position()
        # Test the normal directional mouth path instead of F/calling begin.
        scene.world_platforms.warm(scene, scene.player.global_position)
        scene.cave_world.warm_collision_focus(scene.player.global_position)
        scene.chapter_terrain.warm_focus(scene.player.global_position)
        scene.player.process_mode = Node.PROCESS_MODE_ALWAYS
        await _frames(12)
        var direction := 1 if portal_id == "moss_rain_pipe" else -1
        Input.action_press("move_right" if direction > 0 else "move_left")
        for frame in range(30):
            passage.try_walk_entry()
            if passage.active:
                break
            await _frames()
        _check(passage.active, "directional step enters " + portal_id)
        scene.player.process_mode = Node.PROCESS_MODE_INHERIT
        await _walk(direction, true)
        var target := "demo_ch02_rain_foundry_canal" if direction > 0 else origin_id
        _check(String(scene.config.id) == target, "full walk reaches " + target)
        _check(bool(passage.last_result.get("arrived", false)) and float(passage.last_result.get("distance", 0)) >= 8500, "full 8540px connector traversed by physics")
        _check(scene.get_instance_id() == host_id and scene.player.get_instance_id() == player_id and scene.build_system.get_instance_id() == build_id, "host player build identities survive terminal loading")
        _check(scene.player.hp == 3 and scene.player.energy == 41 and scene.currency_count == 97, "full walk preserves HP energy currency")
        _check(scene.player.collision_layer == 1 and scene.player.collision_mask != 64 and passage.get_child_count() == 0, "arrival clears tube physics and restores mask")
        _check(scene.player_world_position().distance_to(passage.last_result.get("world_position", Vector2.INF)) < 0.1, "terminal rebase preserves world position")
        var saved := STATE.new()
        _check(saved.read(SAVE) and saved.data.current_region == target, "completed target is restartable")
        _check(scene.player_world_position().distance_to(start) > 8500, "world distance is traversed rather than paired teleport")
    # Gate fixtures exercise the live source descriptor, not just the registry.
    portal = scene.get_node("moss_rain_pipe")
    scene.player.global_position = portal.global_position
    for descriptor in scene.config.interactives:
        if String(descriptor.get("id", "")) != "moss_rain_pipe":
            continue
        descriptor["required_ability"] = "lantern_phase"
        _check(not passage.begin("moss_rain_pipe") and not passage.active, "physical entry respects missing ability")
        descriptor.erase("required_ability")
        descriptor["requires_shortcut"] = "passage_fixture_latch"
        _check(not passage.begin("moss_rain_pipe") and not passage.active, "physical entry respects far-side latch")
        descriptor.erase("requires_shortcut")
    var source_checkpoint: Vector2 = scene.active_spawn
    _check(passage.begin("moss_rain_pipe"), "enter for terminal cancellation fixture")
    # Fixture positioning at the terminal only tests rollback; not travel evidence.
    scene.player.global_position = passage.destination_point + Vector2(0, 40)
    passage.step()
    for frame in range(2000):
        if scene.world_loader.phase == "loading":
            break
        await process_frame
    _check(scene.world_loader.phase == "loading" and passage.settling, "terminal uses cancellable budgeted loader")
    scene.world_loader.cancel_transition()
    for frame in range(2000):
        if not passage.settling:
            break
        await process_frame
    _check(passage.active and passage.retry_blocked and String(scene.config.id) == origin_id, "cancelled load restores source and arms explicit retry")
    var cancelled := STATE.new()
    _check(cancelled.read(SAVE) and cancelled.data.current_region == origin_id, "cancelled terminal never commits destination")
    _check(cancelled.resume_local_position() == source_checkpoint and COORD.region_bounds(origin_id).has_point(COORD.to_world(origin_id, cancelled.resume_local_position())), "rollback retains original in-region checkpoint instead of far terminal")
    _check(scene.player.collision_mask == 64 and not scene.ui_canvas.visible, "cancelled terminal resumes tube isolation")
    passage._return_to_source(true)
    _check(not passage.active and scene.ui_canvas.visible and scene.player.collision_layer == 1, "Esc after rollback restores rebuilt source UI and physics")
    _check(scene.player.hp == 3 and scene.player.energy == 41 and scene.currency_count == 97, "terminal rollback preserves resources")
    _check(passage.begin("moss_rain_pipe"), "active-passage teardown fixture")
    scene.free()
    current_scene = null
    await _frames(3)
    for suffix in ["", ".bak", ".tmp"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
    if failures.is_empty():
        print("WORLD PASSAGE PASS: %d checks; physical input roundtrip, reversal, save isolation and terminal continuity" % checks)
        call_deferred("quit", 0)
    else:
        for label in failures:
            push_error(label)
        call_deferred("quit", 1)

func _walk(direction: int, arrival: bool) -> void:
    Input.action_release("move_left")
    Input.action_release("move_right")
    Input.action_press("move_right" if direction > 0 else "move_left")
    # Source controller is disabled: player and tube physics remain live.
    scene.player.process_mode = Node.PROCESS_MODE_ALWAYS
    var previous: Vector2 = scene.player_world_position()
    var max_step := 0.0
    for frame in range(3600):
        await _frames()
        if not scene.world_passage.settling:
            scene.world_passage.step()
        if scene.world_passage.settling:
            scene.player.process_mode = Node.PROCESS_MODE_INHERIT
        var position: Vector2 = scene.player_world_position()
        max_step = maxf(max_step, position.distance_to(previous))
        previous = position
        if not scene.world_passage.active:
            break
    Input.action_release("move_left")
    Input.action_release("move_right")
    scene.player.process_mode = Node.PROCESS_MODE_INHERIT
    _check(not scene.world_passage.active, "connector finishes within frame budget")
    _check(max_step < 35, "no world-coordinate teleport during walking or terminal loading")
    if arrival:
        _check(scene.world_loader.phase == "idle", "terminal loader finishes")

func _frames(count: int = 1) -> void:
    for i in range(count):
        await physics_frame
        await process_frame

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)
        print("FAIL ", label)
