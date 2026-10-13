extends SceneTree
## Stateful runtime regression, not a physical route or reachability test.
## Portal activation reloads region content; positioning is deliberate test setup.
const PATH := "user://world_integration_validation.json"
const WORLD := preload("res://scripts/world_state.gd")
var failures: Array[String] = []
var checks := 0
var host: Node

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    create_timer(45.0).timeout.connect(func():
        _check(false, "runtime test timed out; inspect script errors")
        _finish())
    _clean()
    host = root
    host.process_mode = Node.PROCESS_MODE_DISABLED
    var scene := _spawn(true, false)
    await _frames()
    _check(scene.world_mode, "World enables persistent campaign")
    _check(scene.player_world_position() == WORLD.COORDINATES.to_world(String(scene.config.id), scene.player.global_position), "player exposes unified world position")
    _check(current_scene == scene, "test starts with real current_scene")
    var first_id := String(scene.config.id)
    var first_instance := scene.get_instance_id()
    var first_player: int = scene.player.get_instance_id()
    var pickup: Area2D
    for candidate in scene.get_children():
        if candidate is Area2D and candidate.has_meta("item_id"):
            pickup = candidate
            break
    _check(pickup != null, "initial region has a collectible")
    if pickup == null:
        _finish()
        return
    var pickup_id := String(pickup.name)
    var item_id := String(pickup.get_meta("item_id"))
    var item_before := int(scene.inventory_counts.get(item_id, 0))
    var currency_before: int = scene.currency_count
    scene._on_collectible_body_entered(scene.player, pickup)
    scene._on_collectible_body_entered(scene.player, pickup)
    var amount_after := int(scene.inventory_counts.get(item_id, 0))
    var currency_after: int = scene.currency_count
    _check(amount_after > item_before or currency_after > currency_before, "pickup grants its actual reward")
    _check(scene.world_collected_ids.has(pickup_id), "pickup records its region id")
    await _frames()
    _check(not is_instance_valid(pickup), "picked node removed")
    var shortcut_ids: Array = scene._shortcut_ids()
    var shortcut_id := String(shortcut_ids[0]) if not shortcut_ids.is_empty() else ""
    _check(not shortcut_id.is_empty(), "initial region has a shortcut")
    scene._open_shortcut(shortcut_id)
    scene._on_enemy_died("validation_boss", true, "rust_crown_guardian")
    var boss_reward_id := String(scene.config.boss.get("reward_item", "crown_splinter"))
    var boss_reward_count := int(scene.inventory_counts.get(boss_reward_id, 0))
    scene.player.hp = 3
    scene.player.energy = 41
    var apprentice: Area2D = scene.get_node_or_null("npc_threadsmith_apprentice")
    _check(apprentice != null, "quest apprentice exists")
    if apprentice != null:
        scene._talk_to_npc(apprentice)
        scene._commit_world_dialogue()
        _check(not scene.story_flags.get("quest_bring_names_started", false), "unread subtitle does not grant quest flag")
        scene.dialogue_text_label.visible_characters = -1
        scene._commit_world_dialogue()
        _check(not scene.story_flags.get("quest_bring_names_started", false), "first line does not complete dialogue round")
        _hear_round(scene, apprentice, 2)
        _check(scene.story_flags.get("quest_bring_names_started", false), "complete first conversation starts quest")
        scene._close_overlays()
    var portal: Area2D = scene.get_node_or_null("moss_rain_pipe")
    _check(portal != null, "outbound paired portal exists")
    if portal == null:
        _finish()
        return
    scene.player.global_position = portal.global_position
    scene._travel_world("res://data/demo_ch02_rain_foundry_canal.json", Vector2(330, 720)) # State fixture; physical tube is verified by world_passage.
    await _frames()
    scene = current_scene
    _check(scene.get_instance_id() == first_instance, "portal retains persistent world host")
    _check(scene.player.get_instance_id() == first_player, "portal retains the same player")
    _check(String(scene.config.id) == "demo_ch02_rain_foundry_canal", "A portal enters B")
    _check(scene.player_world_position() == WORLD.COORDINATES.to_world(String(scene.config.id), scene.player.global_position), "arrival uses destination world origin")
    _check(not scene.world_state.data.world_location.is_empty(), "runtime save records world checkpoint")
    _check(scene.world_state.resume_local_position() == scene.active_spawn, "runtime resume retains bell checkpoint")
    _check(scene.player.hp == 3 and scene.player.energy == 41, "travel preserves HP and energy")
    _check(scene.inventory_counts.get(item_id, 0) >= amount_after, "travel carries inventory")
    var child: Area2D = scene.get_node_or_null("npc_canal_child")
    _check(child != null, "canal witness exists")
    if child != null:
        _hear_round(scene, child)
        _check(scene.story_flags.get("quest_bring_names_canal_heard", false), "canal round commits witness")
        scene._close_overlays()
    var riser: Area2D = scene.get_node_or_null("rain_archive_riser")
    _check(riser != null, "archive capability portal exists")
    if riser == null:
        _finish()
        return
    scene._activate_world_portal(riser)
    _check(not scene.chapter_transitioning, "archive riser rejects missing wall grip")
    var grip: Area2D = scene.get_node_or_null("col_silk_wall_grip")
    _check(grip != null, "rain has actual wall grip pickup")
    if grip == null:
        _finish()
        return
    scene._on_collectible_body_entered(scene.player, grip)
    _check(scene.player.wall_grip_unlocked, "pickup unlocks player wall grip")
    scene.player.global_position = riser.global_position
    scene._activate_world_portal(riser)
    await _frames()
    scene = current_scene
    _check(String(scene.config.id) == "demo_ch03_saltwhite_archive", "wall grip opens real B to C transition")
    var scribe: Area2D = scene.get_node_or_null("npc_fugitive_scribe")
    _check(scribe != null, "archive quest witness exists")
    if scribe != null:
        _hear_round(scene, scribe)
        _check(not scene.story_flags.get("quest_bring_names_archive_heard", false), "scribe without physical evidence cannot certify names")
        scene._close_overlays()
    var evidence: Area2D = scene.get_node_or_null("col_testimony_03")
    _check(evidence != null, "archive testimony exists")
    if evidence == null:
        _finish()
        return
    scene._on_collectible_body_entered(scene.player, evidence)
    _hear_round(scene, scribe)
    _check(scene.story_flags.get("quest_bring_names_archive_heard", false), "evidence plus entire scribe round certifies names")
    scene._close_overlays()
    var jump: Area2D = scene.get_node_or_null("world_col_double_thread_jump")
    _check(jump != null, "archive new jump ability exists")
    if jump != null:
        scene._on_collectible_body_entered(scene.player, jump)
        _check(scene.player.double_jump_unlocked, "archive jump pickup updates actual player")
    var archive_return: Area2D = scene.get_node_or_null("archive_rain_riser")
    _check(archive_return != null, "archive can return to rain without lock")
    if archive_return == null:
        _finish()
        return
    scene.player.global_position = archive_return.global_position
    scene._activate_world_portal(archive_return)
    await _frames()
    scene = current_scene
    _check(String(scene.config.id) == "demo_ch02_rain_foundry_canal", "C returns to B")
    _check(scene.get_node_or_null("col_silk_wall_grip") == null, "rain wall grip does not duplicate after archive visit")
    var return_portal: Area2D = scene.get_node_or_null("rain_moss_pipe")
    _check(return_portal != null, "return paired portal exists")
    if return_portal == null:
        _finish()
        return
    scene.player.global_position = return_portal.global_position
    scene._travel_world("res://data/demo_ch01_moss_bell_court.json", Vector2(1790, 3712)) # State fixture; no teleport claim.
    await _frames()
    scene = current_scene
    _check(String(scene.config.id) == first_id, "B returns to A")
    _check(scene.get_node_or_null(pickup_id) == null, "collected pickup does not respawn on return")
    _check(scene._is_shortcut_open(shortcut_id), "shortcut restores on return")
    _check(scene.demo_complete and scene.post_boss_route_open, "dead boss and exit route restore")
    _check(scene.inventory_counts.get(boss_reward_id, 0) == boss_reward_count, "boss reward does not duplicate on return")
    _check(scene.player.hp == 3 and scene.player.energy == 41, "roundtrip preserves resources")
    apprentice = scene.get_node_or_null("npc_threadsmith_apprentice")
    var reward_before: int = scene.currency_count
    _hear_round(scene, apprentice)
    _check(scene.story_flags.get("quest_bring_names_complete", false), "homecoming completes only after whole round")
    _check(scene.currency_count == reward_before + 40, "homecoming grants exactly forty once")
    _hear_round(scene, apprentice)
    _check(scene.currency_count == reward_before + 40, "repeat conversation cannot grant reward again")
    scene._close_overlays()
    scene._save_world()
    var disk_before := FileAccess.get_file_as_string(PATH)
    var persistent_inventory: Dictionary = scene.inventory_counts.duplicate(true)
    scene.queue_free()
    await _frames()
    scene = _spawn(false, true)
    await _frames()
    _check(not scene.world_mode and scene.world_state == null, "Main stays standalone")
    _check(not scene.story_flags.get("quest_bring_names_complete", false), "campaign flags do not enter standalone")
    _check(FileAccess.get_file_as_string(PATH) == disk_before, "standalone does not touch world save")
    scene._save_world()
    _check(FileAccess.get_file_as_string(PATH) == disk_before, "standalone explicit save is inert")
    scene.queue_free()
    await _frames()
    scene = _spawn(true, true)
    await _frames()
    _check(scene.world_collected_ids.has(pickup_id) and scene.get_node_or_null(pickup_id) == null, "fresh runtime resumes pickup state")
    _check(scene.inventory_counts == persistent_inventory, "fresh runtime resumes complete inventory")
    _check(scene.demo_complete and scene._is_shortcut_open(shortcut_id), "fresh runtime resumes boss and shortcut")
    _check(scene.player.hp == 3 and scene.player.energy == 41, "restart preserves resources")
    _check(scene.story_flags.get("quest_bring_names_rewarded", false), "restart preserves paid reward flag")
    var resume_currency: int = scene.currency_count
    _hear_round(scene, scene.get_node_or_null("npc_threadsmith_apprentice"))
    _check(scene.currency_count == resume_currency, "restart cannot repeat quest reward")
    scene._close_overlays()
    scene._start_new_journey()
    await _frames()
    scene = current_scene
    _check(String(scene.config.id) == first_id and not scene.demo_complete, "new journey resets region and boss")
    _check(not scene.world_collected_ids.has(pickup_id) and scene.get_node_or_null(pickup_id) != null, "new journey resets collected objects")
    _check(not scene.story_flags.get("quest_bring_names_complete", false), "new journey resets quest")
    _check(scene.player.hp == 5 and scene.player.energy == 100, "new journey resets resources")
    var clean_disk := WORLD.new()
    _check(clean_disk.read(PATH), "new journey writes readable save")
    _check(not clean_disk.get_region(first_id).boss_defeated and clean_disk.data.currency == 0, "new save has no inherited old progress")
    var prior_disk := WORLD.new()
    _check(prior_disk.read(PATH + ".previous") and prior_disk.get_region(first_id).boss_defeated, "new journey preserves previous campaign")
    _finish()

func _spawn(world: bool, resume: bool) -> Node:
    var scene: Node = load("res://scenes/World.tscn" if world else "res://scenes/Main.tscn").instantiate()
    scene.world_save_path = PATH
    scene.world_resume = resume
    host.add_child(scene)
    current_scene = scene
    return scene

func _hear_round(scene: Node, npc: Area2D, count: int = -1) -> void:
    if npc == null:
        _check(false, "dialogue NPC missing")
        return
    var lines: Array = scene._resolve_npc_lines(npc)
    for index in range(lines.size() if count < 0 else count):
        scene._talk_to_npc(npc)
        scene.dialogue_text_label.visible_characters = -1
        scene._commit_world_dialogue()

func _frames() -> void:
    await process_frame
    await process_frame
    # A real portal now rebuilds across frames. Keep the existing assertions,
    # but await completion rather than assuming two render frames are enough.
    for frame in range(2000):
        if not is_instance_valid(current_scene) or not current_scene.chapter_transitioning:
            return
        await process_frame
    _check(false, "budgeted portal transition did not settle")

func _check(condition: bool, label: String) -> void:
    checks += 1
    if not condition:
        failures.append(label)
        print("WORLD_INTEGRATION_FAIL " + label)

func _clean() -> void:
    for suffix in ["", ".tmp", ".bak", ".previous"]:
        if FileAccess.file_exists(PATH + suffix):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + suffix))

func _finish() -> void:
    if is_instance_valid(current_scene):
        current_scene.queue_free()
    _clean()
    print("WORLD_INTEGRATION checks=%d failures=%d" % [checks, failures.size()])
    quit(0 if failures.is_empty() else 1)
