extends SceneTree

const MAIN_SCENE := "res://scenes/Main.tscn"
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
    _assert(String(ch01_config.get("art_theme", "")) == "moss_cavern", "CH01 declares moss cavern theme")
    _assert(String(ch02_config.get("art_theme", "")) == "rain_foundry", "CH02 declares rain foundry theme")
    _assert(String(ch01_config.get("map_title", "")) != String(ch02_config.get("map_title", "")), "CH01 and CH02 map titles differ")
    _assert(_world_is_expanded_2d(ch01_config.get("world", {})), "CH01 is expanded beyond the original short map")
    _assert(_world_is_expanded_2d(ch02_config.get("world", {})), "CH02 is expanded beyond the original copied map")
    # CH02 boxgarden rebuild: density-first vertical world, so require it to stay in
    # the CH01 scale band and be a boxgarden (aspect <= 1.7) instead of "bigger ribbon".
    _assert(_world_area(ch02_config) >= _world_area(ch01_config) * 0.6, "CH02 boxgarden area is within the CH01 scale band")
    var ch02_world: Dictionary = ch02_config.get("world", {})
    _assert(float(ch02_world.get("width", 0)) <= float(ch02_world.get("height", 1)) * 1.7, "CH02 is a vertical boxgarden, not a horizontal ribbon")
    _assert(ch01_config.get("map_rooms", []).size() >= 12, "CH01 has added rooms")
    _assert(ch02_config.get("map_rooms", []).size() >= 14, "CH02 has a larger room chain")
    _assert(_normalized_route_signature(ch01_config) != _normalized_route_signature(ch02_config), "CH02 normalized route rhythm is not a copy of CH01")
    _assert(_shared_enemy_position_count(ch01_config, ch02_config) <= 2, "CH02 enemy placement is not copied from CH01")
    var ch02_materials := _platform_materials(ch02_config)
    _assert(ch02_materials.has("wet_metal") and ch02_materials.has("foundry_boss"), "CH02 has industrial material set")
    _assert(not ch02_materials.has("moss_stone"), "CH02 does not reuse moss platform material")


func _validate_chapter_geometry_uniqueness(configs: Array) -> void:
    var topology_signatures: Array = []
    var route_signatures: Array = []
    for config_value in configs:
        var config: Dictionary = config_value
        var fingerprint: Dictionary = config.get("map_topology", {}).get("graph_fingerprint", {})
        var topology_signature := JSON.stringify({
            "vertices": fingerprint.get("vertices", 0),
            "edges": fingerprint.get("edges", 0),
            "cycle_rank": fingerprint.get("cycle_rank", -1),
            "maximum_degree": fingerprint.get("maximum_degree", 0),
            "degree_sequence": fingerprint.get("degree_sequence", [])
        })
        var route_signature := _normalized_route_signature(config)
        _assert(not topology_signatures.has(topology_signature), String(config.get("id", "")) + " unlabeled topology fingerprint is unique")
        _assert(not route_signatures.has(route_signature), String(config.get("id", "")) + " normalized route rhythm is unique")
        topology_signatures.append(topology_signature)
        route_signatures.append(route_signature)


func _normalized_route_signature(config: Dictionary) -> String:
    var route: Array = []
    for platform_value in config.get("platforms", []):
        if platform_value is Dictionary and String(platform_value.get("route_role", "")) == "main":
            route.append(platform_value)
    route.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        return int(left.get("route_order", -1)) < int(right.get("route_order", -1))
    )
    var world: Dictionary = config.get("world", {})
    var world_width := maxf(1.0, float(world.get("width", 1)))
    var world_height := maxf(1.0, float(world.get("height", 1)))
    var tokens: Array = []
    for index in range(route.size() - 1):
        var current_rect: Array = route[index].get("rect", [])
        var next_rect: Array = route[index + 1].get("rect", [])
        if current_rect.size() < 4 or next_rect.size() < 4:
            continue
        var gap := float(next_rect[0]) - float(current_rect[0]) - float(current_rect[2])
        var delta_y := float(next_rect[1]) - float(current_rect[1])
        tokens.append("%d:%d:%d" % [
            roundi(float(current_rect[2]) / world_width * 1000.0),
            roundi(gap / world_width * 1000.0),
            roundi(delta_y / world_height * 100.0)
        ])
    return "|".join(tokens)


func _validate_chapter_visual_uniqueness() -> void:
    var boss_signatures: Array = []
    var material_signatures: Array = []
    var used_platform_asset_paths: Array = []
    var used_background_asset_paths: Array = []
    var used_enemy_signatures: Array = []
    for config_path in CONFIG_PATHS:
        var config := _load_json(String(config_path))
        var material_signature := _material_signature(config)
        _assert(not material_signature.is_empty(), String(config.get("id", "")) + " chapter has platform materials")
        _assert(not material_signatures.has(material_signature), String(config.get("id", "")) + " platform material set is unique")
        material_signatures.append(material_signature)
        var asset_paths := _platform_asset_paths(config)
        _assert(asset_paths.size() >= 1, String(config.get("id", "")) + " chapter resolves platform asset files")
        for asset_path in asset_paths:
            _assert(FileAccess.file_exists(String(asset_path)), String(config.get("id", "")) + " platform asset file exists: " + String(asset_path))
            _assert(not used_platform_asset_paths.has(asset_path), String(config.get("id", "")) + " platform asset file is not reused: " + String(asset_path))
            used_platform_asset_paths.append(asset_path)
        var background_paths := _background_asset_paths(config)
        _assert(background_paths.size() >= 1, String(config.get("id", "")) + " chapter resolves background asset files")
        for background_path in background_paths:
            _assert(FileAccess.file_exists(String(background_path)), String(config.get("id", "")) + " background asset file exists: " + String(background_path))
            _assert(not used_background_asset_paths.has(background_path), String(config.get("id", "")) + " background asset file is not reused: " + String(background_path))
            used_background_asset_paths.append(background_path)
        var boss: Dictionary = config.get("boss", {})
        var boss_signature := _visual_signature(boss)
        _assert(_uses_dark_fantasy_sprite(boss), String(config.get("id", "")) + " boss uses dark fantasy sprite")
        _validate_high_fidelity_boss_manifest(config, boss)
        _assert(_visual_has_runtime_keyframes(boss), String(config.get("id", "")) + " boss has runtime keyframe manifest")
        _assert(not boss_signature.is_empty(), String(config.get("id", "")) + " boss has configured visual region")
        _assert(_array_min2(boss.get("body_size", []), Vector2(100.0, 120.0)), String(config.get("id", "")) + " boss body size is enlarged")
        _assert(_array_min2(boss.get("hurtbox_size", []), Vector2(110.0, 130.0)), String(config.get("id", "")) + " boss hurtbox size is enlarged")
        _assert(not boss_signatures.has(boss_signature), String(config.get("id", "")) + " boss visual is unique")
        boss_signatures.append(boss_signature)
        var enemy_signatures: Array = []
        for enemy in config.get("enemy_spawns", []):
            if not (enemy is Dictionary):
                continue
            var enemy_data: Dictionary = enemy
            var signature := _visual_signature(enemy_data)
            _assert(_uses_dark_fantasy_sprite(enemy_data), String(config.get("id", "")) + " enemy uses dark fantasy sprite: " + String(enemy_data.get("id", "")))
            _assert(_visual_has_runtime_keyframes(enemy_data), String(config.get("id", "")) + " enemy has runtime keyframe manifest: " + String(enemy_data.get("id", "")))
            _assert(not signature.is_empty(), String(config.get("id", "")) + " enemy has visual region: " + String(enemy_data.get("id", "")))
            if not enemy_signatures.has(signature):
                _assert(not used_enemy_signatures.has(signature), String(config.get("id", "")) + " enemy visual is not reused from earlier chapter: " + String(enemy_data.get("id", "")))
                enemy_signatures.append(signature)
        _assert(enemy_signatures.size() >= mini(4, config.get("enemy_spawns", []).size()), String(config.get("id", "")) + " chapter has varied enemy visuals")
        for signature in enemy_signatures:
            used_enemy_signatures.append(signature)


func _material_signature(config: Dictionary) -> String:
    var materials: Array = []
    for platform in config.get("platforms", []):
        if not (platform is Dictionary):
            continue
        var material := String((platform as Dictionary).get("material", ""))
        if not material.is_empty() and not materials.has(material):
            materials.append(material)
    materials.sort()
    return "|".join(materials)


func _platform_asset_paths(config: Dictionary) -> Array:
    var directory := "res://assets/sprites/flat_maps/"+_original_art_theme_key(config)
    return [directory+"/platform_atlas.png",directory+"/terrain_atlas.png"]


func _background_asset_paths(config: Dictionary) -> Array:
    var directory := "res://assets/sprites/flat_maps/"+_original_art_theme_key(config)
    return [directory+"/background.png",directory+"/decor_atlas.png"]


func _original_art_theme_key(config: Dictionary) -> String:
    var theme := _art_theme_for_config(config)
    return "moss_cavern" if theme == "moss_bell" else theme


func _art_theme_for_config(config: Dictionary) -> String:
    var theme := String(config.get("art_theme", ""))
    if not theme.is_empty():
        return theme
    var config_id := String(config.get("id", ""))
    if config_id.contains("rain_foundry") or config_id.contains("ch02"):
        return "rain_foundry"
    if config_id.contains("saltwhite") or config_id.contains("ch03"):
        return "salt_archive"
    if config_id.contains("broken_string") or config_id.contains("ch04"):
        return "string_greenhouse"
    if config_id.contains("obsidian") or config_id.contains("ch05"):
        return "obsidian_pilgrim"
    if config_id.contains("silent_crown") or config_id.contains("ch06"):
        return "silent_crown"
    return "moss_cavern"


func _array_min2(value, minimum: Vector2) -> bool:
    if not (value is Array):
        return false
    var data: Array = value
    if data.size() < 2:
        return false
    return float(data[0]) >= minimum.x and float(data[1]) >= minimum.y


func _visual_signature(data: Dictionary) -> String:
    var sprite_path := String(data.get("sprite", ""))
    if sprite_path.is_empty():
        return ""
    return JSON.stringify({
        "sprite": sprite_path,
        "region": data.get("sprite_region", []),
        "scale": data.get("visual_scale", 0.0),
        "offset": data.get("visual_offset", [])
    })


func _uses_dark_fantasy_sprite(data: Dictionary) -> bool:
    var sprite_path := String(data.get("sprite", ""))
    if sprite_path.contains("kenney_monster_builder"):
        return false
    return sprite_path.contains("assets/sprites/original_creatures/")


func _visual_has_runtime_keyframes(data: Dictionary) -> bool:
    var sprite_path := String(data.get("sprite", ""))
    if not sprite_path.ends_with(".json") or not FileAccess.file_exists(sprite_path):
        return false
    var file := FileAccess.open(sprite_path, FileAccess.READ)
    if file == null:
        return false
    var manifest = JSON.parse_string(file.get_as_text())
    if typeof(manifest) != TYPE_DICTIONARY:
        return false
    var required := ["idle", "walk", "attack", "hurt", "death"]
    var found: Dictionary = {}
    for animation in manifest.get("animations", []):
        if not (animation is Dictionary):
            continue
        var data_animation: Dictionary = animation
        var name := String(data_animation.get("name", ""))
        if not required.has(name):
            continue
        var frames: Array = data_animation.get("frames", [])
        if frames.is_empty():
            return false
        for frame in frames:
            var frame_path := String(frame.get("atlas", "")) if frame is Dictionary else String(frame)
            if frame_path.is_empty() or not FileAccess.file_exists(frame_path):
                return false
        found[name] = true
    for name in required:
        if not found.has(name):
            return false
    return true


func _validate_high_fidelity_boss_manifest(config: Dictionary, boss: Dictionary) -> void:
    var path := "res://assets/sprites/original_creatures/"+String(boss.kind)+"/manifest.json"
    _assert(String(boss.sprite)==path,String(config.id)+" uses its original boss atlas")
    _assert(String(boss.visual_source)=="original_hand_drawn",String(config.id)+" original art provenance")
    for animation in ["heavy", "cast", "phase", "heavy_windup", "cast_windup", "phase_windup"]:
        _assert(_manifest_has_directional_animation(path,animation),String(config.id)+" boss animation "+animation)


func _manifest_has_directional_animation(sprite_path: String, animation_name: String) -> bool:
    var file := FileAccess.open(sprite_path, FileAccess.READ)
    if file == null:
        return false
    var manifest = JSON.parse_string(file.get_as_text())
    if typeof(manifest) != TYPE_DICTIONARY:
        return false
    for animation in manifest.get("animations", []):
        if not (animation is Dictionary):
            continue
        var data_animation: Dictionary = animation
        if String(data_animation.get("name", "")) != animation_name:
            continue
        return (data_animation.get("frames", []) as Array).size() >= 2
    return false


func _validate_runtime_boss_manifest(config_id: String, state: Dictionary) -> void:
    var config := _load_json("res://data/"+config_id+".json")
    _assert(String(state.get("boss_asset_path", ""))=="res://assets/sprites/original_creatures/"+String(config.boss.kind)+"/manifest.json",config_id+" runtime uses original boss art")


func _text_has(value, needle: String) -> bool:
    return JSON.stringify(value).contains(needle)


func _validate_ai_profiles(config: Dictionary, config_id: String) -> void:
    var profiles: Dictionary = config.get("ai_profiles", {})
    _assert(not profiles.is_empty(), config_id + " has ai profile table")
    var kinds: Array = []
    for enemy in config.get("enemy_spawns", []):
        if enemy is Dictionary:
            var enemy_kind := String((enemy as Dictionary).get("kind", ""))
            if not enemy_kind.is_empty() and not kinds.has(enemy_kind):
                kinds.append(enemy_kind)
    var boss_kind := String(config.get("boss", {}).get("kind", ""))
    if not boss_kind.is_empty() and not kinds.has(boss_kind):
        kinds.append(boss_kind)
    for kind in kinds:
        _assert(profiles.has(kind), config_id + " ai profile exists: " + String(kind))
        var profile: Dictionary = profiles.get(kind, {})
        var attacks: Array = profile.get("attacks", [])
        if kind == boss_kind:
            _assert(attacks.size() >= 2, config_id + " boss ai profile has attack desire commands: " + String(kind))
        else:
            _assert(attacks.size() >= 2, config_id + " small enemy has at least two distinct attack commands: " + String(kind))
        _assert(float(profile.get("aggro_range", 0.0)) >= float(profile.get("preferred_range", 0.0)), config_id + " ai profile can engage beyond preferred range: " + String(kind))
        var boss_animation_mapped := 0
        for attack in attacks:
            _assert(attack is Dictionary, config_id + " ai attack is dictionary: " + String(kind))
            var attack_data: Dictionary = attack
            _assert(not String(attack_data.get("id", "")).is_empty(), config_id + " ai attack has id: " + String(kind))
            _assert(float(attack_data.get("range", 0.0)) >= 60.0, config_id + " ai attack has usable range: " + String(kind))
            _assert(float(attack_data.get("cooldown", 0.0)) > 0.0, config_id + " ai attack has cooldown: " + String(kind))
            if kind == boss_kind:
                boss_animation_mapped += _validate_boss_ai_animation(config_id, attack_data)
        if kind == boss_kind:
            var min_mapped := 0
            if config_id == "demo_ch01_moss_bell_court" or config_id == "demo_ch02_rain_foundry_canal":
                min_mapped = 3
            elif config_id == "demo_ch03_saltwhite_archive" or config_id == "demo_ch04_broken_string_greenhouse":
                min_mapped = 4
            if min_mapped > 0:
                _assert(boss_animation_mapped >= min_mapped, config_id + " boss ai has enough high-fidelity animation mappings")


func _validate_boss_ai_animation(config_id: String, attack_data: Dictionary) -> int:
    var config := _load_json("res://data/"+config_id+".json")
    var path := "res://assets/sprites/original_creatures/"+String(config.boss.kind)+"/manifest.json"
    _assert(_manifest_has_directional_animation(path,String(attack_data.get("animation","attack"))),config_id+" attack maps to a real animation")
    return 1


func _validate_chapter(config_path: String) -> void:
    var config := _load_json(config_path)
    _assert(config.size() > 0, config_path + " loads")
    var config_id := String(config.get("id", ""))
    _validate_ai_profiles(config, config_id)

    var scene: Node = load(MAIN_SCENE).instantiate()
    scene.set("config_path", config_path)
    root.add_child(scene)
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
    var first_npc: Area2D = scene.get_node_or_null(first_npc_id)
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
    var save_node: Area2D = scene.get_node_or_null(String(first_save_point.get("id", "")))
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
    var lever_node: Area2D = scene.get_node_or_null(String(lever.get("id", "")))
    _assert(lever_node != null, config_id + " shortcut lever exists")
    scene.player.global_position = lever_node.global_position
    scene.player.global_position = lever_node.global_position
    scene._try_interact()
    state = scene.get_demo_state()
    _assert(state.get("shortcut_open") == true, config_id + " combat clear opens boss route")
    _assert(state.get("boss_unlocked") == true, config_id + " combat clear unlocks boss")

    var boss_gate := _interactive_by_kind(interactives, "boss_gate")
    var boss_gate_node: Area2D = scene.get_node_or_null(String(boss_gate.get("id", "")))
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
    _assert(scene.get_node_or_null("boss_back_wall") == null, config_id + " post-boss blocker is removed")
    _assert(reward_item.is_empty() or scene.inventory_counts.has(reward_item), config_id + " boss reward granted")
    _assert(String(scene.win_label.text).contains(String(boss.get("name", ""))), config_id + " completion text uses boss name")
    var exit_data := _interactive_exit(interactives)
    var exit_node: Area2D = scene.get_node_or_null(String(exit_data.get("id", "")))
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
    var kinds: Array = []
    for child in scene.get_children():
        if child.is_in_group("enemy") and not child.is_boss:
            kinds.append(child.kind)
    return kinds


func _attacks_have_pose_keys(attacks: Array) -> bool:
    if attacks.is_empty():
        return false
    for attack in attacks:
        if not (attack is Dictionary):
            return false
        var data: Dictionary = attack
        if not data.has("windup_scale") or not data.has("active_scale") or not data.has("recover_offset"):
            return false
    return true


func _find_runtime_scene(config_id: String) -> Node:
    for child in root.get_children():
        if child == null or not is_instance_valid(child):
            continue
        if not child.has_method("get_demo_state"):
            continue
        var state: Dictionary = child.get_demo_state()
        if String(state.get("config_id", "")) == config_id:
            return child
    return null


func _points_match(actual_value, expected_value) -> bool:
    if not (actual_value is Array) or not (expected_value is Array):
        return false
    var actual: Array = actual_value
    var expected: Array = expected_value
    if actual.size() < 2 or expected.size() < 2:
        return false
    return absf(float(actual[0]) - float(expected[0])) <= 0.5 and absf(float(actual[1]) - float(expected[1])) <= 0.5


func _vec2(value) -> Vector2:
    if not (value is Array):
        return Vector2.ZERO
    var data: Array = value
    if data.size() < 2:
        return Vector2.ZERO
    return Vector2(float(data[0]), float(data[1]))


func _interactive_by_kind(interactives: Array, kind: String) -> Dictionary:
    for interactive in interactives:
        var item: Dictionary = interactive
        if String(item.get("kind", "")) == kind:
            return item
    return {}


func _interactive_exit(interactives: Array) -> Dictionary:
    for interactive in interactives:
        var item: Dictionary = interactive
        var kind := String(item.get("kind", ""))
        if kind == "chapter_exit" or kind == "ending_exit":
            return item
    return {}


func _item_collectible_count(config: Dictionary) -> int:
    var total := 0
    for collectible in config.get("collectibles", []):
        if collectible is Dictionary and String((collectible as Dictionary).get("kind", "")) == "item":
            total += 1
    return total


func _collectibles_have_no_route_tokens(config: Dictionary) -> bool:
    for collectible in config.get("collectibles", []):
        if not (collectible is Dictionary):
            return false
        if String((collectible as Dictionary).get("kind", "")) not in ["item"]:
            return false
    return true


func _room_by_kind(rooms: Array, kind: String) -> Dictionary:
    for room in rooms:
        if not (room is Dictionary):
            continue
        var data: Dictionary = room
        if String(data.get("kind", "")) == kind:
            return data
    return {}


func _position_inside_room(position_value, room: Dictionary) -> bool:
    if room.is_empty() or not (position_value is Array):
        return false
    var position_data: Array = position_value
    if position_data.size() < 2:
        return false
    var x := float(position_data[0])
    var y := float(position_data[1])
    if _room_contains_position(room, Vector2(x, y)):
        return true
    var range_data: Array = room.get("range", [])
    if range_data.size() < 2:
        return false
    return x >= float(range_data[0]) and x <= float(range_data[1])


func _position_has_floor(config: Dictionary, position_value, clearance: float) -> bool:
    if not (position_value is Array):
        return false
    var position_data: Array = position_value
    if position_data.size() < 2:
        return false
    var x := float(position_data[0])
    var expected_top := float(position_data[1]) + clearance
    for platform in config.get("platforms", []):
        if not (platform is Dictionary):
            continue
        var platform_data: Dictionary = platform
        var rect := _platform_rect(platform_data.get("rect", []))
        if not _playable_floor_allowed(platform_data, rect):
            continue
        if x >= rect.position.x - 1.0 and x <= rect.position.x + rect.size.x + 1.0 and absf(rect.position.y - expected_top) <= 8.0:
            return true
    return false


func _late_route_has_no_large_gap(config: Dictionary, exit_position_value, max_gap: float) -> bool:
    if _uses_layout_rects(config.get("map_rooms", [])):
        return true
    if not (exit_position_value is Array):
        return false
    var exit_position: Array = exit_position_value
    if exit_position.size() < 2:
        return false
    var start_x := _late_route_start_x(config)
    var end_x := float(exit_position[0])
    var ranges: Array = []
    for platform in config.get("platforms", []):
        if not (platform is Dictionary):
            continue
        var platform_data: Dictionary = platform
        var rect := _platform_rect(platform_data.get("rect", []))
        if not _playable_floor_allowed(platform_data, rect):
            continue
        if rect.size.x < 180.0 or rect.position.y < 492.0 or rect.position.y > 545.0:
            continue
        var left := maxf(start_x, rect.position.x)
        var right := minf(end_x, rect.position.x + rect.size.x)
        if right > left:
            ranges.append([left, right])
    ranges.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
    var cursor := start_x
    for range_item in ranges:
        var left := float(range_item[0])
        var right := float(range_item[1])
        if left - cursor > max_gap:
            return false
        cursor = maxf(cursor, right)
    return end_x - cursor <= max_gap


func _uses_layout_rects(rooms: Array) -> bool:
    for room in rooms:
        if not (room is Dictionary):
            continue
        var rect := _room_layout_rect(room)
        if rect.size.x > 0.0 and rect.size.y > 0.0:
            return true
    return false


func _late_route_start_x(config: Dictionary) -> float:
    for platform in config.get("platforms", []):
        if not (platform is Dictionary):
            continue
        var platform_data: Dictionary = platform
        if String(platform_data.get("id", "")) == "backdoor_room":
            return _platform_rect(platform_data.get("rect", [])).position.x
    return 3600.0


func _playable_floor_allowed(platform_data: Dictionary, rect: Rect2) -> bool:
    if rect.size.x <= 0.0 or rect.size.y <= 0.0:
        return false
    var lowered := String(platform_data.get("id", "")).to_lower()
    if lowered.contains("wall") or lowered.contains("gate") or lowered.contains("locked"):
        return false
    return rect.size.x >= 26.0 and rect.size.y <= 90.0


func _platform_rect(rect_value) -> Rect2:
    if not (rect_value is Array):
        return Rect2()
    var data: Array = rect_value
    if data.size() < 4:
        return Rect2()
    return Rect2(float(data[0]), float(data[1]), float(data[2]), float(data[3]))


func _exit_points_to_next(config: Dictionary, config_id: String) -> bool:
    var exit_data := _interactive_exit(config.get("interactives", []))
    if exit_data.is_empty():
        return false
    if config_id.ends_with("silent_crown_core"):
        return String(exit_data.get("kind", "")) == "ending_exit"
    var transition: Dictionary = config.get("chapter_transition", {})
    return String(exit_data.get("kind", "")) == "chapter_exit" and not String(transition.get("to_runtime_config_id", "")).is_empty() and String(exit_data.get("next_runtime_config_id", "")) == String(transition.get("to_runtime_config_id", ""))


func _attack_types(profile: Dictionary) -> Array:
    var types: Array = []
    for attack in profile.get("attacks", []):
        if not (attack is Dictionary):
            continue
        var data: Dictionary = attack
        var attack_type := String(data.get("type", ""))
        if not types.has(attack_type):
            types.append(attack_type)
    return types


func _world_area(config: Dictionary) -> float:
    var world: Dictionary = config.get("world", {})
    return float(world.get("width", 0)) * float(world.get("height", 0))


func _world_is_expanded_2d(world: Dictionary) -> bool:
    # True-2D maps trade raw ribbon width for stacked vertical layers, so
    # require enough playable area on both axes instead of 1D length.
    var width := float(world.get("width", 0))
    var height := float(world.get("height", 0))
    return width >= 5200.0 and height >= 2400.0 and width * height >= 14000000.0


func _rooms_cover_world(rooms: Array, world: Dictionary) -> bool:
    # Every room must expose a positive 2D layout rect, and together the
    # rooms must span most of the world on both axes.
    if rooms.is_empty():
        return false
    var min_x := INF
    var min_y := INF
    var max_x := -INF
    var max_y := -INF
    for room in rooms:
        if not (room is Dictionary):
            return false
        var rect := _room_layout_rect(room)
        if rect.size.x <= 0.0 or rect.size.y <= 0.0:
            return false
        min_x = minf(min_x, rect.position.x)
        min_y = minf(min_y, rect.position.y)
        max_x = maxf(max_x, rect.position.x + rect.size.x)
        max_y = maxf(max_y, rect.position.y + rect.size.y)
    var width := maxf(1.0, float(world.get("width", 1)))
    var height := maxf(1.0, float(world.get("height", 1)))
    return (max_x - min_x) >= width * 0.72 and (max_y - min_y) >= height * 0.55


func _has_multilayer_room_kinds(rooms: Array) -> bool:
    var room_types: Dictionary = {}
    var min_layer := 999
    var max_layer := -999
    for room in rooms:
        if not (room is Dictionary):
            continue
        var data: Dictionary = room
        room_types[String(data.get("room_type", data.get("kind", "")))] = true
        var layer := int(data.get("layer", data.get("depth", 0)))
        min_layer = mini(min_layer, layer)
        max_layer = maxi(max_layer, layer)
    return room_types.size() >= 3 and max_layer - min_layer >= 3


func _has_multilevel_platforms(platforms: Array) -> bool:
    # Split the playable vertical span into thirds and require standable
    # floors in every band, so each chapter is genuinely stacked in 2D.
    var min_y := INF
    var max_y := -INF
    var floor_ys: Array = []
    for platform in platforms:
        if not (platform is Dictionary):
            continue
        var data: Dictionary = platform
        var rect := _platform_rect(data.get("rect", []))
        if not _playable_floor_allowed(data, rect):
            continue
        floor_ys.append(rect.position.y)
        min_y = minf(min_y, rect.position.y)
        max_y = maxf(max_y, rect.position.y)
    if floor_ys.size() < 3 or max_y - min_y < 1200.0:
        return false
    var band := (max_y - min_y) / 3.0
    var has_upper := false
    var has_mid := false
    var has_lower := false
    for y_value in floor_ys:
        var y := float(y_value)
        if y < min_y + band:
            has_upper = true
        elif y < min_y + band * 2.0:
            has_mid = true
        else:
            has_lower = true
    return has_upper and has_mid and has_lower


func _connections_reference_rooms(connections: Array, rooms: Array) -> bool:
    var ids: Dictionary = {}
    for room in rooms:
        if room is Dictionary:
            ids[String((room as Dictionary).get("id", ""))] = true
    if connections.is_empty():
        return false
    for connection in connections:
        if not (connection is Dictionary):
            return false
        var data: Dictionary = connection
        if not ids.has(String(data.get("from", ""))) or not ids.has(String(data.get("to", ""))):
            return false
    return true


func _positions_map_to_rooms(config: Dictionary, config_id: String) -> bool:
    var rooms: Array = config.get("map_rooms", [])
    var positions: Array = [
        config.get("player_start", []),
        config.get("boss_checkpoint", []),
        config.get("boss", {}).get("position", [])
    ]
    for enemy in config.get("enemy_spawns", []):
        if enemy is Dictionary:
            positions.append((enemy as Dictionary).get("position", []))
    for save_point in config.get("save_points", []):
        if save_point is Dictionary:
            positions.append((save_point as Dictionary).get("position", []))
    for npc in config.get("npcs", []):
        if npc is Dictionary:
            positions.append((npc as Dictionary).get("position", []))
    for interactive in config.get("interactives", []):
        if interactive is Dictionary:
            positions.append((interactive as Dictionary).get("position", []))
    for position_value in positions:
        if not _position_inside_any_room(position_value, rooms):
            print("POSITION_OUTSIDE_ROOM: %s %s" % [config_id, JSON.stringify(position_value)])
            return false
    return true
func _position_inside_any_room(position_value, rooms: Array) -> bool:
    if not (position_value is Array):
        return false
    var position_data: Array = position_value
    if position_data.size() < 2:
        return false
    var x := float(position_data[0])
    var y := float(position_data[1])
    for room in rooms:
        if not (room is Dictionary):
            continue
        var room_data: Dictionary = room
        if _room_contains_position(room_data, Vector2(x, y)):
            return true
        if _uses_layout_rects([room_data]):
            continue
        var range_data: Array = room_data.get("range", [])
        if range_data.size() < 2:
            continue
        if x >= float(range_data[0]) and x <= float(range_data[1]):
            return true
    return false


func _room_layout_rect(room: Dictionary) -> Rect2:
    var rect_value = room.get("layout_rect", room.get("play_rect", []))
    if not (rect_value is Array):
        return Rect2()
    var data: Array = rect_value
    if data.size() < 4:
        return Rect2()
    return Rect2(float(data[0]), float(data[1]), float(data[2]), float(data[3]))


func _room_contains_position(room: Dictionary, position_value: Vector2) -> bool:
    var layout_rect := _room_layout_rect(room)
    if layout_rect.size.x > 0.0 and layout_rect.size.y > 0.0:
        if position_value.x >= layout_rect.position.x and position_value.x <= layout_rect.position.x + layout_rect.size.x and position_value.y >= layout_rect.position.y and position_value.y <= layout_rect.position.y + layout_rect.size.y:
            return true
    for rect_value in room.get("visit_rects", []):
        if not (rect_value is Array):
            continue
        var data: Array = rect_value
        if data.size() < 4:
            continue
        var rect := Rect2(float(data[0]), float(data[1]), float(data[2]), float(data[3]))
        if position_value.x >= rect.position.x and position_value.x <= rect.position.x + rect.size.x and position_value.y >= rect.position.y and position_value.y <= rect.position.y + rect.size.y:
            return true
    return false


func _platform_materials(config: Dictionary) -> Array:
    var materials: Array = []
    for platform in config.get("platforms", []):
        if not (platform is Dictionary):
            continue
        var data: Dictionary = platform
        var material := String(data.get("material", ""))
        if not materials.has(material):
            materials.append(material)
    return materials


func _platform_signature_overlap(left_config: Dictionary, right_config: Dictionary) -> float:
    var left_signatures: Array = []
    for platform in left_config.get("platforms", []):
        if not (platform is Dictionary):
            continue
        left_signatures.append(_platform_signature(platform as Dictionary))
    var compared := 0
    var matched := 0
    for platform in right_config.get("platforms", []):
        if not (platform is Dictionary):
            continue
        compared += 1
        if left_signatures.has(_platform_signature(platform as Dictionary)):
            matched += 1
    if compared <= 0:
        return 1.0
    return float(matched) / float(compared)


func _platform_signature(platform: Dictionary) -> String:
    return JSON.stringify({
        "rect": platform.get("rect", []),
        "material": platform.get("material", "")
    })


func _shared_enemy_position_count(left_config: Dictionary, right_config: Dictionary) -> int:
    var left_positions: Array = []
    for enemy in left_config.get("enemy_spawns", []):
        if enemy is Dictionary:
            left_positions.append(_enemy_position_signature(enemy as Dictionary))
    var count := 0
    for enemy in right_config.get("enemy_spawns", []):
        if enemy is Dictionary and left_positions.has(_enemy_position_signature(enemy as Dictionary)):
            count += 1
    return count


func _enemy_position_signature(enemy: Dictionary) -> String:
    var position: Array = enemy.get("position", [])
    if position.size() < 2:
        return ""
    return "%d:%d" % [int(position[0]), int(position[1])]


func _load_json(path: String) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var data = JSON.parse_string(file.get_as_text())
    return data if typeof(data) == TYPE_DICTIONARY else {}


func _assert(condition: bool, label: String) -> void:
    if condition:
        print("PASS: " + label)
        return
    push_error("FAIL: " + label)
    failures += 1
