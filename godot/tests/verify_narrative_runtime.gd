extends SceneTree
## Tests real NPC commits, reward persistence, migrations and ending gates.
## Inventory placement is deliberate fixture setup, not a physical route test.
const SAVE := "user://verify_narrative_runtime.json"
var checks := 0
var failures := 0
var scene: Node

func _initialize() -> void:
    call_deferred("run_checks")

func check(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error(message)

func frames() -> void:
    for index in range(3):
        await process_frame

func resident_npc(world: Node, npc_id: String) -> Area2D:
    var authored: Dictionary = {}
    for value in world.config.get("npcs", []):
        if String(value.get("id", "")) == npc_id:
            authored = value
            break
    check(not authored.is_empty(), "NPC fixture exists in authored region " + npc_id)
    if authored.is_empty():
        return null
    var point := Vector2(float(authored.position[0]), float(authored.position[1]))
    point = world._world_npc_residency_position(npc_id, point)
    var prior_mode: int = world.process_mode
    var prior_physics: bool = world.player.is_physics_processing()
    var paused_enemies: Array[Dictionary] = []
    for enemy in world.get_tree().get_nodes_in_group("enemy"):
        if is_instance_valid(enemy):
            paused_enemies.append({"node": enemy, "mode": enemy.process_mode})
            enemy.process_mode = Node.PROCESS_MODE_DISABLED
    world.process_mode = Node.PROCESS_MODE_ALWAYS
    world.player.set_physics_process(false)
    world.player.velocity = Vector2.ZERO
    world.player.global_position = world.to_global(point)
    for frame in range(120):
        await process_frame
        var npc := world.get_node_or_null(NodePath(npc_id)) as Area2D
        var snapshot: Dictionary = world.world_gameplay_residency.snapshot()
        if is_instance_valid(npc) and npc.is_inside_tree() and npc.get_parent() == world and String(npc.get_meta("npc_id", "")) == npc_id and world.player.global_position.distance_to(npc.global_position) <= 190.0 and bool(snapshot.window_ready) and int(snapshot.pending_build) == 0:
            world.player.set_physics_process(prior_physics)
            world.process_mode = prior_mode
            for paused in paused_enemies:
                if is_instance_valid(paused.node): paused.node.process_mode = int(paused.mode)
            return npc
    world.player.set_physics_process(prior_physics)
    world.process_mode = prior_mode
    for paused in paused_enemies:
        if is_instance_valid(paused.node): paused.node.process_mode = int(paused.mode)
    check(false, "moving the test player into the active window constructs the requested NPC " + npc_id)
    return null

func spawn(chapter_path: String, resume: bool = false) -> Node:
    var world: Node = load("res://scenes/World.tscn").instantiate()
    world.config_path = chapter_path
    world.world_resume = resume
    world.world_save_path = SAVE
    root.add_child(world)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(world)
    current_scene = world
    return world

func cleanup_save() -> void:
    for suffix in ["", ".bak", ".tmp"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))

func hear_round(npc: Area2D) -> void:
    var total: int = scene._resolve_npc_lines(npc).size()
    for index in range(total):
        scene._talk_to_npc(npc)
        scene.dialogue_text_label.visible_characters = -1
        scene._commit_world_dialogue()
    scene._close_overlays()

func run_checks() -> void:
    create_timer(60.0).timeout.connect(func():
        check(false, "Narrative runtime timed out")
        quit(1))
    root.process_mode = Node.PROCESS_MODE_DISABLED
    cleanup_save()
    scene = await spawn("res://data/demo_ch04_broken_string_greenhouse.json")
    await frames()
    var prisoner: Area2D = await resident_npc(scene, "npc_root_prisoner")
    check(prisoner != null, "Actual root prisoner is built")
    if not is_instance_valid(prisoner):
        scene.free()
        cleanup_save()
        quit(1)
        return
    var original_position: Vector2 = prisoner.position
    hear_round(prisoner)
    check(not bool(scene.story_flags.get("quest_root_rescue_complete", false)), "Rescue cannot complete before ability acquisition")
    scene._add_inventory_item("thorn_downstrike", 1, false)
    var before: int = scene.currency_count
    scene._talk_to_npc(prisoner)
    scene.dialogue_text_label.visible_characters = 0
    scene._commit_world_dialogue()
    check(not bool(scene.story_flags.get("quest_root_rescue_complete", false)), "Unread subtitle cannot commit rescue or payment")
    scene._close_overlays()
    hear_round(prisoner)
    check(bool(scene.story_flags.get("quest_root_rescue_complete", false)), "Complete rescue conversation updates real story flags")
    check(scene.currency_count == before + 45, "Real NPC grants exactly one rescue reward")
    check(prisoner.position == Vector2(320, 1740) and prisoner.position != original_position, "Rescued NPC moves to actual safe west gate floor")
    check(String(scene._room_for_position(prisoner.position).get("id", "")) == "west_gate", "Migration position is inside destination room")
    hear_round(prisoner)
    check(scene.currency_count == before + 45, "Repeated real dialogue cannot duplicate rescue payment")
    scene._save_world()
    scene.free()
    scene = await spawn("res://data/demo_ch04_broken_string_greenhouse.json", true)
    await frames()
    prisoner = await resident_npc(scene, "npc_root_prisoner")
    check(is_instance_valid(prisoner) and prisoner.position == Vector2(320, 1740), "Save reload restores actual NPC migration")
    check(scene.currency_count == before + 45, "Save reload retains one-time payment")
    scene.free()
    cleanup_save()
    scene = await spawn("res://data/demo_ch05_obsidian_pilgrim_road.json")
    await frames()
    var deserter: Area2D = await resident_npc(scene, "npc_deserter_flagbearer")
    check(is_instance_valid(deserter), "Actual deserter enters its active interaction window")
    if not is_instance_valid(deserter):
        scene.free()
        cleanup_save()
        quit(1)
        return
    scene._add_inventory_item("silent_order", 1, false)
    before = scene.currency_count
    hear_round(deserter)
    check(scene.currency_count == before + 40, "Actual deserter quest grants one useful reward")
    check(deserter.position == Vector2(270, 1870), "Deserter moves to actual camp floor")
    check(String(scene._room_for_position(deserter.position).get("id", "")) == "pilgrim_camp", "Camp migration stays inside the actual hub")
    scene.free()
    cleanup_save()
    scene = await spawn("res://data/demo_ch06_silent_crown_core.json")
    await frames()
    scene._spawn_ending_gates()
    var gate: Area2D = scene.get_node_or_null("ending_gate_rewrite")
    check(gate != null, "Actual true-ending gate is built")
    scene._activate_ending_gate(gate)
    check(String(scene.story_flags.get("ending_chosen", "")).is_empty(), "Ending gate rejects before final boss completion")
    scene.story_flags["boss_down_ch06"] = true
    scene._activate_ending_gate(gate)
    check(String(scene.story_flags.get("ending_chosen", "")).is_empty(), "Ending gate rejects missing original evidence")
    for index in [6, 2, 4, 1, 5, 3]:
        scene._add_inventory_item("testimony_%02d" % int(index), 1, false)
    scene.story_flags.erase("true_ending_testimony_complete")
    scene._activate_ending_gate(gate)
    check(String(scene.story_flags.get("ending_chosen", "")) == "ending_c", "Six actual proofs unlock ending without stale derived flag or optional quests")
    check(bool(scene.story_flags.get("world_contract_rewritten", false)), "Gate persists concrete contract consequence")
    check(not scene.story_flags.get("ending_consequences", {}).is_empty(), "Gate saves NPC and environment aftermath details")
    check(String(scene.win_label.text).contains("世袭"), "Ending presents the actual causal consequence")
    var alternative: Area2D = scene.get_node_or_null("ending_gate_resound")
    scene._activate_ending_gate(alternative)
    check(String(scene.story_flags.get("ending_chosen", "")) == "ending_c", "A committed choice cannot be overwritten")
    scene._save_world()
    scene.free()
    scene = await spawn("res://data/demo_ch06_silent_crown_core.json", true)
    await frames()
    check(String(scene.story_flags.get("ending_chosen", "")) == "ending_c", "Reload restores chosen ending")
    check(bool(scene.story_flags.get("world_contract_rewritten", false)), "Reload restores concrete aftermath flags")
    scene.free()
    cleanup_save()
    await frames()
    print("NARRATIVE_RUNTIME_PASS checks=%d failures=%d" % [checks, failures])
    quit(1 if failures else 0)
