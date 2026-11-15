extends SceneTree
const LEVEL_HOST := preload("res://scripts/level_host.gd")

const MAIN_SCENE := "res://scenes/Main.tscn"
const ART := preload("res://scripts/hand_drawn_assets.gd")
const CHAPTER_UNIQUENESS_CHECKS := preload("res://scripts/chapter_uniqueness_checks.gd")
const CHAPTER_ROUTE_CHECKS := preload("res://scripts/chapter_route_checks.gd")
const CONFIG_PATHS := [
    "res://data/demo_ch01_moss_bell_court.json",
    "res://data/demo_ch02_rain_foundry_canal.json",
    "res://data/demo_ch03_saltwhite_archive.json",
    "res://data/demo_ch04_broken_string_greenhouse.json",
    "res://data/demo_ch05_obsidian_pilgrim_road.json",
    "res://data/demo_ch06_silent_crown_core.json"
]
var failures := 0


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var configs: Array = []
    for config_path in CONFIG_PATHS:
        configs.append(_load_json(String(config_path)))
    _validate_ch01_ch02_differ(configs[0], configs[1])
    _validate_chapter_geometry_uniqueness(configs)
    _validate_chapter_visual_uniqueness()
    for config_path in CONFIG_PATHS:
        await _validate_chapter(String(config_path))
    if failures == 0:
        print("ALL_CHAPTERS_DEMO_VALIDATION_PASS chapters=6 complete=true")
        quit(0)
    else:
        push_error("ALL_CHAPTERS_DEMO_VALIDATION_FAIL failures=%d" % failures)
        quit(1)


func _validate_ch01_ch02_differ(ch01_config: Dictionary, ch02_config: Dictionary) -> void:
    CHAPTER_UNIQUENESS_CHECKS.validate_ch01_ch02_differ(self, ch01_config, ch02_config)


func _validate_chapter_geometry_uniqueness(configs: Array) -> void:
    CHAPTER_UNIQUENESS_CHECKS.validate_chapter_geometry_uniqueness(self, configs)


func _normalized_route_signature(config: Dictionary) -> String:
    return CHAPTER_UNIQUENESS_CHECKS.normalized_route_signature(self, config)


func _validate_chapter_visual_uniqueness() -> void:
    CHAPTER_UNIQUENESS_CHECKS.validate_chapter_visual_uniqueness(self)


func _material_signature(config: Dictionary) -> String:
    return CHAPTER_UNIQUENESS_CHECKS.material_signature(self, config)


func _platform_asset_paths(config: Dictionary) -> Array:
    return CHAPTER_UNIQUENESS_CHECKS.platform_asset_paths(self, config)


func _background_asset_paths(config: Dictionary) -> Array:
    return CHAPTER_UNIQUENESS_CHECKS.background_asset_paths(self, config)


func _original_art_theme_key(config: Dictionary) -> String:
    return CHAPTER_UNIQUENESS_CHECKS.original_art_theme_key(self, config)


func _art_theme_for_config(config: Dictionary) -> String:
    return CHAPTER_UNIQUENESS_CHECKS.art_theme_for_config(self, config)


func _array_min2(value, minimum: Vector2) -> bool:
    return CHAPTER_UNIQUENESS_CHECKS.array_min2(self, value, minimum)


func _visual_signature(data: Dictionary) -> String:
    return CHAPTER_UNIQUENESS_CHECKS.visual_signature(self, data)


func _uses_dark_fantasy_sprite(data: Dictionary) -> bool:
    return CHAPTER_UNIQUENESS_CHECKS.uses_dark_fantasy_sprite(self, data)


func _visual_has_runtime_keyframes(data: Dictionary) -> bool:
    return CHAPTER_UNIQUENESS_CHECKS.visual_has_runtime_keyframes(self, data)


func _validate_high_fidelity_boss_manifest(config: Dictionary, boss: Dictionary) -> void:
    CHAPTER_UNIQUENESS_CHECKS.validate_high_fidelity_boss_manifest(self, config, boss)


func _manifest_has_directional_animation(sprite_path: String, animation_name: String) -> bool:
    return CHAPTER_UNIQUENESS_CHECKS.manifest_has_directional_animation(self, sprite_path, animation_name)


func _validate_runtime_boss_manifest(config_id: String, state: Dictionary) -> void:
    CHAPTER_UNIQUENESS_CHECKS.validate_runtime_boss_manifest(self, config_id, state)


func _text_has(value, needle: String) -> bool:
    return JSON.stringify(value).contains(needle)


func _validate_ai_profiles(config: Dictionary, config_id: String) -> void:
    CHAPTER_UNIQUENESS_CHECKS.validate_ai_profiles(self, config, config_id)


func _validate_boss_ai_animation(config_id: String, attack_data: Dictionary) -> int:
    return CHAPTER_UNIQUENESS_CHECKS.validate_boss_ai_animation(self, config_id, attack_data)


func _validate_chapter(config_path: String) -> void:
    var config := _load_json(config_path)
    _assert(config.size() > 0, config_path + " loads")
    var config_id := String(config.get("id", ""))
    _validate_ai_profiles(config, config_id)

    var scene: Node = load(MAIN_SCENE).instantiate()
    scene.set("config_path", config_path)
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    await process_frame
    await process_frame

    var state: Dictionary = scene.get_demo_state()
    var chapter_name := String(config.get("name", "")).replace("试玩章", "")
    var enemies: Array = config.get("enemy_spawns", [])
    var npcs: Array = config.get("npcs", [])
    var boss: Dictionary = config.get("boss", {})
    var interactives: Array = config.get("interactives", [])
    var save_points: Array = config.get("save_points", [])
    var expected_rooms := int(config.get("map_topology", {}).get("graph_fingerprint", {}).get("vertices", 0))
    var boss_kind := String(boss.get("kind", ""))
    var boss_profile: Dictionary = config.get("ai_profiles", {}).get(boss_kind, {})
    var boss_attack_types := _attack_types(boss_profile)

    _assert(state.get("config_id") == config_id, config_id + " scene uses injected config")
    _assert(String(state.get("progression_mode", "")) == "combat_clear", config_id + " uses combat-clear progression")
    _assert(String(state.get("art_theme_id", "")).is_empty() == false, config_id + " exposes runtime art theme")
    _assert((state.get("platform_visual_asset_paths", []) as Array).size() >= 1, config_id + " exposes runtime platform asset files")
    _assert((state.get("background_visual_asset_paths", []) as Array).size() >= 1, config_id + " exposes runtime background asset files")
    _assert(state.get("campaign_current_chapter") == chapter_name, config_id + " maps to campaign chapter")
    _assert(_world_is_expanded_2d(config.get("world", {})), config_id + " world is expanded in both axes")
    _assert(config.get("map_rooms", []).size() == expected_rooms, config_id + " room count matches its unique topology")
    _assert(config.get("platforms", []).size() >= config.get("map_rooms", []).size() * 2, config_id + " platform count supports expanded rooms")
    _assert(config.get("parkour_segments", []).size() >= 1, config_id + " has configured parkour segment")
    _assert(_rooms_cover_world(config.get("map_rooms", []), config.get("world", {})), config_id + " room layout rects cover expanded world")
    _assert(_has_multilayer_room_kinds(config.get("map_rooms", [])), config_id + " has at least four topology layers and varied room types")
    _assert(_has_multilevel_platforms(config.get("platforms", [])), config_id + " has playable upper, middle, and lower platform bands")
    _assert(_connections_reference_rooms(config.get("connections", []), config.get("map_rooms", [])), config_id + " room connections reference existing rooms")
    _assert(_positions_map_to_rooms(config, config_id), config_id + " all important positions map to expanded rooms")
    _assert(_exit_points_to_next(config, config_id), config_id + " chapter exit points to next chapter or ending")
    _assert(boss_profile.get("attacks", []).size() >= 4, config_id + " boss has expanded move list")
    _assert(boss_attack_types.size() >= 3, config_id + " boss has at least three different attack types")
    _assert(_visual_has_runtime_keyframes(boss), config_id + " boss attacks have drawn animation frames")
    var boss_room := _room_by_kind(config.get("map_rooms", []), "boss")
    var boss_gate_data := _interactive_by_kind(interactives, "boss_gate")
    var exit_data_static := _interactive_exit(interactives)
    _assert(_position_has_floor(config, config.get("boss_checkpoint", []), 40.0), config_id + " boss checkpoint has floor")
    _assert(_position_has_floor(config, boss_gate_data.get("position", []), 40.0), config_id + " boss gate has floor")
    _assert(_position_has_floor(config, boss.get("position", []), 40.0), config_id + " boss spawn has floor")
    _assert(_position_has_floor(config, exit_data_static.get("position", []), 40.0), config_id + " chapter exit has floor")
    _assert(_position_inside_room(boss.get("position", []), boss_room), config_id + " boss spawn is inside boss room")
    _assert(_position_inside_room(boss_gate_data.get("position", []), boss_room), config_id + " boss gate is inside boss room")
    _assert(_late_route_has_no_large_gap(config, exit_data_static.get("position", []), 160.0), config_id + " late route has continuous floor")
    _assert(state.get("normal_enemy_total") == enemies.size(), config_id + " enemy count matches config")
    _assert(state.get("npc_total") == npcs.size(), config_id + " NPC count matches config")
    _assert(int(state.get("collectible_total", -1)) == _item_collectible_count(config), config_id + " spawns only configured ability/reward item collectibles")
    _assert(_collectibles_have_no_route_tokens(config), config_id + " has no route-token collectibles")
    _assert(int(state.get("required_keys", -1)) == 0, config_id + " requires no keys")
    _assert(int(state.get("save_point_total", 0)) == save_points.size(), config_id + " save point count matches config")
    _assert(save_points.size() <= 4, config_id + " save points stay sparse")
    _assert(int(state.get("hidden_save_point_total", 0)) >= 1, config_id + " has at least one hidden save point")
    _assert(int(state.get("av_runtime_event_total", 0)) >= 2, config_id + " AV runtime manifest loaded")

    var first_npc_id := String((npcs[0] as Dictionary).get("id", ""))
    var first_npc: Area2D = LEVEL_HOST.find(scene, first_npc_id)
    _assert(first_npc != null, config_id + " first NPC exists")
    _assert(first_npc.get_meta("dialogue", []).size() >= 2, config_id + " first NPC has dialogue")
    scene.player.global_position = first_npc.global_position
    scene.player.global_position = first_npc.global_position
    scene._try_interact()
    _assert(scene.active_overlay == "dialogue", config_id + " first NPC dialogue advances")

    var actual_kinds := _normal_enemy_kinds(scene)
    for enemy in enemies:
        var enemy_data: Dictionary = enemy
        var expected_kind := String(enemy_data.get("kind", ""))
        _assert(actual_kinds.has(expected_kind), config_id + " enemy kind exists: " + expected_kind)
    for enemy_position in state.get("enemy_positions", []):
        var enemy_state: Dictionary = enemy_position
        _assert(not String(enemy_state.get("platform_id", "")).is_empty(), config_id + " enemy rests on playable platform: " + String(enemy_state.get("id", "")))
        _assert(bool(enemy_state.get("spawn_clear", false)), config_id + " enemy spawn is clear of walls: " + String(enemy_state.get("id", "")))
        var leash_radius := float(enemy_state.get("leash_radius", 0.0))
        _assert(leash_radius > 0.0 and leash_radius <= 460.0, config_id + " normal enemy has small leash radius: " + String(enemy_state.get("id", "")))
        _assert(bool(enemy_state.get("reads_player_commands", false)), config_id + " enemy reads player command state: " + String(enemy_state.get("id", "")))
        _assert(int(enemy_state.get("ai_command_total", 0)) >= 2, config_id + " small enemy has at least two active attack commands: " + String(enemy_state.get("id", "")))
        _assert(float(enemy_state.get("attack_desire_threshold", 0.0)) > 0.0, config_id + " enemy exposes attack desire threshold: " + String(enemy_state.get("id", "")))
        _assert(float(enemy_state.get("max_attack_range", 0.0)) >= 60.0, config_id + " enemy can actively threaten range: " + String(enemy_state.get("id", "")))

    var first_save_point := save_points[0] as Dictionary
    var save_node: Area2D = LEVEL_HOST.find(scene, String(first_save_point.get("id", "")))
    _assert(save_node != null, config_id + " first save point exists")
    _assert(save_node.has_node("SavePointSprite"), config_id + " save point uses open Kenney sprite")
    _assert(save_node.has_node("SavePointHalo"), config_id + " save point has animated halo")
    scene._close_overlays()
    scene.player.global_position = save_node.global_position
    scene.player.hp = 2
    scene.player.energy = 0
    scene.player.global_position = save_node.global_position
    scene._try_interact()
    state = scene.get_demo_state()
    _assert(String(state.get("active_save_point_id", "")) == String(first_save_point.get("id", "")), config_id + " save point interaction updates respawn")
    _assert(int(scene.player.hp) == scene.player.max_hp, config_id + " save point restores hp")
    _assert(int(scene.player.energy) == scene.player.max_energy, config_id + " save point restores energy")
    _assert(bool(save_node.get_meta("activated", false)), config_id + " save point activation anim state")

    scene._debug_clear_combat_route()
    var lever := _interactive_by_kind(interactives, "lever")
    var lever_node: Area2D = LEVEL_HOST.find(scene, String(lever.get("id", "")))
    _assert(lever_node != null, config_id + " shortcut lever exists")
    scene.player.global_position = lever_node.global_position
    scene.player.global_position = lever_node.global_position
    scene._try_interact()
    state = scene.get_demo_state()
    _assert(state.get("shortcut_open") == true, config_id + " combat clear opens boss route")
    _assert(state.get("boss_unlocked") == true, config_id + " combat clear unlocks boss")

    var boss_gate := _interactive_by_kind(interactives, "boss_gate")
    var boss_gate_node: Area2D = LEVEL_HOST.find(scene, String(boss_gate.get("id", "")))
    _assert(boss_gate_node != null, config_id + " boss gate exists")
    scene.player.global_position = boss_gate_node.global_position
    scene.player.global_position = boss_gate_node.global_position
    scene._try_interact()
    await process_frame
    state = scene.get_demo_state()
    _assert(state.get("boss_spawned") == true, config_id + " boss spawns")
    _assert(state.get("boss_arena_locked") == true, config_id + " boss room locks after entry")
    _assert(scene.boss_actor != null, config_id + " boss actor exists")
    _assert(scene.boss_actor.spawn_id == String(boss.get("id", "")), config_id + " boss spawn id matches")
    _assert(scene.boss_actor.kind == String(boss.get("kind", "")), config_id + " boss kind matches")
    _validate_runtime_boss_manifest(config_id, state)
    _assert(_array_min2(state.get("boss_body_size", []), Vector2(90.0, 120.0)), config_id + " runtime boss body matches its drawn silhouette")
    _assert(_array_min2(state.get("boss_hurtbox_size", []), Vector2(110.0, 130.0)), config_id + " runtime boss hurtbox is enlarged")
    _assert(int(state.get("boss_attack_total", 0)) >= 4, config_id + " runtime boss attack total expanded")
    _assert((state.get("boss_attack_types", []) as Array).size() >= 3, config_id + " runtime boss has varied attack types")

    scene._debug_kill_boss()
    await process_frame
    await process_frame
    state = scene.get_demo_state()
    var reward_item := String(boss.get("reward_item", ""))
    _assert(state.get("demo_complete") == true, config_id + " completes")
    _assert(state.get("boss_arena_locked") == false, config_id + " boss room unlocks after boss death")
    _assert(bool(state.get("post_boss_route_open", false)), config_id + " post-boss route opens")
    _assert(LEVEL_HOST.find(scene, "boss_back_wall") == null, config_id + " post-boss blocker is removed")
    _assert(reward_item.is_empty() or scene.inventory_counts.has(reward_item), config_id + " boss reward granted")
    _assert(String(scene.win_label.text).contains(String(boss.get("name", ""))), config_id + " completion text uses boss name")
    var exit_data := _interactive_exit(interactives)
    var exit_node: Area2D = LEVEL_HOST.find(scene, String(exit_data.get("id", "")))
    _assert(exit_node != null, config_id + " post-boss chapter exit exists")
    if String(exit_data.get("kind", "")) == "chapter_exit":
        var next_runtime_id := String(exit_data.get("next_runtime_config_id", ""))
        scene.nearby_interactable = null
        scene.player.global_position = _vec2(exit_data.get("position", [0, 0])) + Vector2(-90.0, 0.0)
        scene._try_interact()
        await process_frame
        await process_frame
        var next_scene := _find_runtime_scene(next_runtime_id)
        _assert(next_scene != null, config_id + " chapter exit transitions to " + next_runtime_id)
        if next_scene != null:
            var next_state: Dictionary = next_scene.get_demo_state()
            var next_config := _load_json(String(exit_data.get("next_config_path", "")))
            var entry_data: Dictionary = next_config.get("entry_from_previous", {})
            var expected_entry: Array = entry_data.get("position", next_config.get("player_start", []))
            _assert(bool(next_state.get("entry_spawn_override_enabled", false)), config_id + " next chapter uses transition entry spawn")
            _assert(String(next_state.get("entered_from_config_id", "")) == config_id, config_id + " next chapter records previous chapter")
            _assert(_points_match(next_state.get("active_spawn", []), expected_entry), config_id + " next chapter does not use default start")
            _assert(not String(next_state.get("transition_entry_message", "")).is_empty(), config_id + " next chapter shows entry message")
        if next_scene != null and is_instance_valid(next_scene) and next_scene.get_parent() != null:
            root.remove_child(next_scene)
            next_scene.queue_free()
            await process_frame
    else:
        scene.player.global_position = exit_node.global_position
        scene.player.global_position = exit_node.global_position
        scene._try_interact()
        _assert(scene.win_label.visible, config_id + " ending exit opens ending route")

    print("PASS_CHAPTER_RUNTIME: %s enemies=%d npcs=%d reward=%s" % [
        config_id,
        enemies.size(),
        npcs.size(),
        reward_item
    ])
    if is_instance_valid(scene) and scene.get_parent() != null:
        root.remove_child(scene)
        scene.queue_free()
    await process_frame


func _normal_enemy_kinds(scene: Node) -> Array:
    return CHAPTER_ROUTE_CHECKS.normal_enemy_kinds(self, scene)


func _attacks_have_pose_keys(attacks: Array) -> bool:
    return CHAPTER_ROUTE_CHECKS.attacks_have_pose_keys(self, attacks)


func _find_runtime_scene(config_id: String) -> Node:
    return CHAPTER_ROUTE_CHECKS.find_runtime_scene(self, config_id)


func _points_match(actual_value, expected_value) -> bool:
    return CHAPTER_ROUTE_CHECKS.points_match(self, actual_value, expected_value)


func _vec2(value) -> Vector2:
    return CHAPTER_ROUTE_CHECKS.vec2(self, value)


func _interactive_by_kind(interactives: Array, kind: String) -> Dictionary:
    return CHAPTER_ROUTE_CHECKS.interactive_by_kind(self, interactives, kind)


func _interactive_exit(interactives: Array) -> Dictionary:
    return CHAPTER_ROUTE_CHECKS.interactive_exit(self, interactives)


func _item_collectible_count(config: Dictionary) -> int:
    return CHAPTER_ROUTE_CHECKS.item_collectible_count(self, config)


func _collectibles_have_no_route_tokens(config: Dictionary) -> bool:
    return CHAPTER_ROUTE_CHECKS.collectibles_have_no_route_tokens(self, config)


func _room_by_kind(rooms: Array, kind: String) -> Dictionary:
    return CHAPTER_ROUTE_CHECKS.room_by_kind(self, rooms, kind)


func _position_inside_room(position_value, room: Dictionary) -> bool:
    return CHAPTER_ROUTE_CHECKS.position_inside_room(self, position_value, room)


func _position_has_floor(config: Dictionary, position_value, clearance: float) -> bool:
    return CHAPTER_ROUTE_CHECKS.position_has_floor(self, config, position_value, clearance)


func _late_route_has_no_large_gap(config: Dictionary, exit_position_value, max_gap: float) -> bool:
    return CHAPTER_ROUTE_CHECKS.late_route_has_no_large_gap(self, config, exit_position_value, max_gap)


func _uses_layout_rects(rooms: Array) -> bool:
    return CHAPTER_ROUTE_CHECKS.uses_layout_rects(self, rooms)


func _late_route_start_x(config: Dictionary) -> float:
    return CHAPTER_ROUTE_CHECKS.late_route_start_x(self, config)


func _playable_floor_allowed(platform_data: Dictionary, rect: Rect2) -> bool:
    return CHAPTER_ROUTE_CHECKS.playable_floor_allowed(self, platform_data, rect)


func _platform_rect(rect_value) -> Rect2:
    return CHAPTER_ROUTE_CHECKS.platform_rect(self, rect_value)


func _exit_points_to_next(config: Dictionary, config_id: String) -> bool:
    return CHAPTER_ROUTE_CHECKS.exit_points_to_next(self, config, config_id)


func _attack_types(profile: Dictionary) -> Array:
    return CHAPTER_ROUTE_CHECKS.attack_types(self, profile)


func _world_area(config: Dictionary) -> float:
    return CHAPTER_ROUTE_CHECKS.world_area(self, config)


func _world_is_expanded_2d(world: Dictionary) -> bool:
    return CHAPTER_ROUTE_CHECKS.world_is_expanded_2d(self, world)


func _rooms_cover_world(rooms: Array, world: Dictionary) -> bool:
    return CHAPTER_ROUTE_CHECKS.rooms_cover_world(self, rooms, world)


func _has_multilayer_room_kinds(rooms: Array) -> bool:
    return CHAPTER_ROUTE_CHECKS.has_multilayer_room_kinds(self, rooms)


func _has_multilevel_platforms(platforms: Array) -> bool:
    return CHAPTER_ROUTE_CHECKS.has_multilevel_platforms(self, platforms)


func _connections_reference_rooms(connections: Array, rooms: Array) -> bool:
    return CHAPTER_ROUTE_CHECKS.connections_reference_rooms(self, connections, rooms)


func _positions_map_to_rooms(config: Dictionary, config_id: String) -> bool:
    return CHAPTER_ROUTE_CHECKS.positions_map_to_rooms(self, config, config_id)
func _position_inside_any_room(position_value, rooms: Array) -> bool:
    return CHAPTER_ROUTE_CHECKS.position_inside_any_room(self, position_value, rooms)


func _room_layout_rect(room: Dictionary) -> Rect2:
    return CHAPTER_ROUTE_CHECKS.room_layout_rect(self, room)


func _room_contains_position(room: Dictionary, position_value: Vector2) -> bool:
    return CHAPTER_ROUTE_CHECKS.room_contains_position(self, room, position_value)


func _platform_materials(config: Dictionary) -> Array:
    return CHAPTER_ROUTE_CHECKS.platform_materials(self, config)


func _platform_signature_overlap(left_config: Dictionary, right_config: Dictionary) -> float:
    return CHAPTER_ROUTE_CHECKS.platform_signature_overlap(self, left_config, right_config)


func _platform_signature(platform: Dictionary) -> String:
    return CHAPTER_ROUTE_CHECKS.platform_signature(self, platform)


func _shared_enemy_position_count(left_config: Dictionary, right_config: Dictionary) -> int:
    return CHAPTER_ROUTE_CHECKS.shared_enemy_position_count(self, left_config, right_config)


func _enemy_position_signature(enemy: Dictionary) -> String:
    return CHAPTER_ROUTE_CHECKS.enemy_position_signature(self, enemy)


func _load_json(path: String) -> Dictionary:
    return CHAPTER_ROUTE_CHECKS.load_json(self, path)


func _assert(condition: bool, label: String) -> void:
    if condition:
        print("PASS: " + label)
        return
    push_error("FAIL: " + label)
    failures += 1
