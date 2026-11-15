extends RefCounted
## All-chapters demo checks: chapters differ in geometry, visuals, materials and art themes; boss manifests and AI profiles are complete.
## Moved out of all_chapters_demo_validation.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.
const ART := preload("res://scripts/hand_drawn_assets.gd")

static func validate_ch01_ch02_differ(suite: SceneTree, ch01_config: Dictionary, ch02_config: Dictionary) -> void:
    suite._assert(String(ch01_config.get("art_theme", "")) == "moss_cavern", "CH01 declares moss cavern theme")
    suite._assert(String(ch02_config.get("art_theme", "")) == "rain_foundry", "CH02 declares rain foundry theme")
    suite._assert(String(ch01_config.get("map_title", "")) != String(ch02_config.get("map_title", "")), "CH01 and CH02 map titles differ")
    suite._assert(suite._world_is_expanded_2d(ch01_config.get("world", {})), "CH01 is expanded beyond the original short map")
    suite._assert(suite._world_is_expanded_2d(ch02_config.get("world", {})), "CH02 is expanded beyond the original copied map")
    # CH02 boxgarden rebuild: density-first vertical world, so require it to stay in
    # the CH01 scale band and be a boxgarden (aspect <= 1.7) instead of "bigger ribbon".
    suite._assert(suite._world_area(ch02_config) >= suite._world_area(ch01_config) * 0.6, "CH02 boxgarden area is within the CH01 scale band")
    var ch02_world: Dictionary = ch02_config.get("world", {})
    suite._assert(float(ch02_world.get("width", 0)) <= float(ch02_world.get("height", 1)) * 1.7, "CH02 is a vertical boxgarden, not a horizontal ribbon")
    suite._assert(ch01_config.get("map_rooms", []).size() >= 12, "CH01 has added rooms")
    suite._assert(ch02_config.get("map_rooms", []).size() >= 14, "CH02 has a larger room chain")
    suite._assert(suite._normalized_route_signature(ch01_config) != suite._normalized_route_signature(ch02_config), "CH02 normalized route rhythm is not a copy of CH01")
    suite._assert(suite._shared_enemy_position_count(ch01_config, ch02_config) <= 2, "CH02 enemy placement is not copied from CH01")
    var ch02_materials: Array = suite._platform_materials(ch02_config)
    suite._assert(ch02_materials.has("wet_metal") and ch02_materials.has("foundry_boss"), "CH02 has industrial material set")
    suite._assert(not ch02_materials.has("moss_stone"), "CH02 does not reuse moss platform material")


static func validate_chapter_geometry_uniqueness(suite: SceneTree, configs: Array) -> void:
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
        var route_signature: String = suite._normalized_route_signature(config)
        suite._assert(not topology_signatures.has(topology_signature), String(config.get("id", "")) + " unlabeled topology fingerprint is unique")
        suite._assert(not route_signatures.has(route_signature), String(config.get("id", "")) + " normalized route rhythm is unique")
        topology_signatures.append(topology_signature)
        route_signatures.append(route_signature)


static func normalized_route_signature(suite: SceneTree, config: Dictionary) -> String:
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


static func validate_chapter_visual_uniqueness(suite: SceneTree) -> void:
    var boss_signatures: Array = []
    var material_signatures: Array = []
    var used_platform_asset_paths: Array = []
    var used_background_asset_paths: Array = []
    var used_enemy_signatures: Array = []
    for config_path in suite.CONFIG_PATHS:
        var config: Dictionary = suite._load_json(String(config_path))
        var material_signature: String = suite._material_signature(config)
        suite._assert(not material_signature.is_empty(), String(config.get("id", "")) + " chapter has platform materials")
        suite._assert(not material_signatures.has(material_signature), String(config.get("id", "")) + " platform material set is unique")
        material_signatures.append(material_signature)
        var asset_paths: Array = suite._platform_asset_paths(config)
        suite._assert(asset_paths.size() >= 1, String(config.get("id", "")) + " chapter resolves platform asset files")
        for asset_path in asset_paths:
            suite._assert(FileAccess.file_exists(String(asset_path)), String(config.get("id", "")) + " platform asset file exists: " + String(asset_path))
            suite._assert(not used_platform_asset_paths.has(asset_path), String(config.get("id", "")) + " platform asset file is not reused: " + String(asset_path))
            used_platform_asset_paths.append(asset_path)
        var background_paths: Array = suite._background_asset_paths(config)
        suite._assert(background_paths.size() >= 1, String(config.get("id", "")) + " chapter resolves background asset files")
        for background_path in background_paths:
            suite._assert(FileAccess.file_exists(String(background_path)), String(config.get("id", "")) + " background asset file exists: " + String(background_path))
            suite._assert(not used_background_asset_paths.has(background_path), String(config.get("id", "")) + " background asset file is not reused: " + String(background_path))
            used_background_asset_paths.append(background_path)
        # V01: no solid ledge cuts through a standing NPC (head room the Player could not stand in).
        var clashes: Array = []
        for npc in config.get("npcs", []):
            var figure := Rect2(float(npc.position[0]) - 40.0, float(npc.position[1]) + 40.0 - 110.0, 80.0, 102.0)
            for platform in config.get("platforms", []):
                if figure.intersects(Rect2(platform.rect[0], platform.rect[1], platform.rect[2], platform.rect[3])):
                    clashes.append("%s/%s" % [npc.id, platform.get("id", "")])
        suite._assert(clashes.is_empty(), String(config.get("id", "")) + " NPCs stand clear of ledges " + str(clashes))
        var boss: Dictionary = config.get("boss", {})
        var boss_signature: String = suite._visual_signature(boss)
        suite._assert(suite._uses_dark_fantasy_sprite(boss), String(config.get("id", "")) + " boss uses dark fantasy sprite")
        suite._validate_high_fidelity_boss_manifest(config, boss)
        suite._assert(suite._visual_has_runtime_keyframes(boss), String(config.get("id", "")) + " boss has runtime keyframe manifest")
        suite._assert(not boss_signature.is_empty(), String(config.get("id", "")) + " boss has configured visual region")
        suite._assert(suite._array_min2(boss.get("body_size", []), Vector2(100.0, 120.0)), String(config.get("id", "")) + " boss body size is enlarged")
        suite._assert(suite._array_min2(boss.get("hurtbox_size", []), Vector2(110.0, 130.0)), String(config.get("id", "")) + " boss hurtbox size is enlarged")
        suite._assert(not boss_signatures.has(boss_signature), String(config.get("id", "")) + " boss visual is unique")
        boss_signatures.append(boss_signature)
        var enemy_signatures: Array = []
        for enemy in config.get("enemy_spawns", []):
            if not (enemy is Dictionary):
                continue
            var enemy_data: Dictionary = enemy
            var signature: String = suite._visual_signature(enemy_data)
            suite._assert(suite._uses_dark_fantasy_sprite(enemy_data), String(config.get("id", "")) + " enemy uses dark fantasy sprite: " + String(enemy_data.get("id", "")))
            suite._assert(suite._visual_has_runtime_keyframes(enemy_data), String(config.get("id", "")) + " enemy has runtime keyframe manifest: " + String(enemy_data.get("id", "")))
            suite._assert(not signature.is_empty(), String(config.get("id", "")) + " enemy has visual region: " + String(enemy_data.get("id", "")))
            if not enemy_signatures.has(signature):
                suite._assert(not used_enemy_signatures.has(signature), String(config.get("id", "")) + " enemy visual is not reused from earlier chapter: " + String(enemy_data.get("id", "")))
                enemy_signatures.append(signature)
        suite._assert(enemy_signatures.size() >= mini(4, config.get("enemy_spawns", []).size()), String(config.get("id", "")) + " chapter has varied enemy visuals")
        for signature in enemy_signatures:
            used_enemy_signatures.append(signature)


static func material_signature(suite: SceneTree, config: Dictionary) -> String:
    var materials: Array = []
    for platform in config.get("platforms", []):
        if not (platform is Dictionary):
            continue
        var material := String((platform as Dictionary).get("material", ""))
        if not material.is_empty() and not materials.has(material):
            materials.append(material)
    materials.sort()
    return "|".join(materials)


static func platform_asset_paths(suite: SceneTree, config: Dictionary) -> Array:
    var directory = "res://assets/sprites/flat_maps/"+suite._original_art_theme_key(config)
    return [directory+"/platform_atlas.png",directory+"/terrain_atlas.png"]


static func background_asset_paths(suite: SceneTree, config: Dictionary) -> Array:
    var directory = "res://assets/sprites/flat_maps/"+suite._original_art_theme_key(config)
    return [directory+"/background.png",directory+"/decor_atlas.png"]


static func original_art_theme_key(suite: SceneTree, config: Dictionary) -> String:
    var theme: String = suite._art_theme_for_config(config)
    return "moss_cavern" if theme == "moss_bell" else theme


static func art_theme_for_config(suite: SceneTree, config: Dictionary) -> String:
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


static func array_min2(suite: SceneTree, value, minimum: Vector2) -> bool:
    if not (value is Array):
        return false
    var data: Array = value
    if data.size() < 2:
        return false
    return float(data[0]) >= minimum.x and float(data[1]) >= minimum.y


static func visual_signature(suite: SceneTree, data: Dictionary) -> String:
    var sprite_path := String(data.get("sprite", ""))
    if sprite_path.is_empty():
        return ""
    return JSON.stringify({
        "sprite": sprite_path,
        "region": data.get("sprite_region", []),
        "scale": data.get("visual_scale", 0.0),
        "offset": data.get("visual_offset", [])
    })


static func uses_dark_fantasy_sprite(suite: SceneTree, data: Dictionary) -> bool:
    var sprite_path := String(data.get("sprite", ""))
    if sprite_path.contains("kenney_monster_builder"):
        return false
    return sprite_path.contains("assets/sprites/original_creatures/")


static func visual_has_runtime_keyframes(suite: SceneTree, data: Dictionary) -> bool:
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


static func validate_high_fidelity_boss_manifest(suite: SceneTree, config: Dictionary, boss: Dictionary) -> void:
    var path := "res://assets/sprites/original_creatures/"+String(boss.kind)+"/manifest.json"
    suite._assert(String(boss.sprite)==path,String(config.id)+" uses its original boss atlas")
    suite._assert(String(boss.visual_source)=="original_hand_drawn",String(config.id)+" original art provenance")
    for animation in ["heavy", "cast", "phase", "heavy_windup", "cast_windup", "phase_windup"]:
        suite._assert(suite._manifest_has_directional_animation(path,animation),String(config.id)+" boss animation "+animation)


static func manifest_has_directional_animation(suite: SceneTree, sprite_path: String, animation_name: String) -> bool:
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


static func validate_runtime_boss_manifest(suite: SceneTree, config_id: String, state: Dictionary) -> void:
    var config: Dictionary = suite._load_json("res://data/"+config_id+".json")
    var path = ART.character_manifest("original_creatures", String(config.boss.kind))
    suite._assert(String(state.get("boss_asset_path", "")) == path, config_id + " runtime uses the current original-art motion manifest")


static func validate_ai_profiles(suite: SceneTree, config: Dictionary, config_id: String) -> void:
    var profiles: Dictionary = config.get("ai_profiles", {})
    suite._assert(not profiles.is_empty(), config_id + " has ai profile table")
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
        suite._assert(profiles.has(kind), config_id + " ai profile exists: " + String(kind))
        var profile: Dictionary = profiles.get(kind, {})
        var attacks: Array = profile.get("attacks", [])
        if kind == boss_kind:
            suite._assert(attacks.size() >= 2, config_id + " boss ai profile has attack desire commands: " + String(kind))
        else:
            suite._assert(attacks.size() >= 2, config_id + " small enemy has at least two distinct attack commands: " + String(kind))
        suite._assert(float(profile.get("aggro_range", 0.0)) >= float(profile.get("preferred_range", 0.0)), config_id + " ai profile can engage beyond preferred range: " + String(kind))
        var boss_animation_mapped := 0
        for attack in attacks:
            suite._assert(attack is Dictionary, config_id + " ai attack is dictionary: " + String(kind))
            var attack_data: Dictionary = attack
            suite._assert(not String(attack_data.get("id", "")).is_empty(), config_id + " ai attack has id: " + String(kind))
            suite._assert(float(attack_data.get("range", 0.0)) >= 60.0, config_id + " ai attack has usable range: " + String(kind))
            suite._assert(float(attack_data.get("cooldown", 0.0)) > 0.0, config_id + " ai attack has cooldown: " + String(kind))
            if kind == boss_kind:
                boss_animation_mapped += suite._validate_boss_ai_animation(config_id, attack_data)
        if kind == boss_kind:
            var min_mapped := 0
            if config_id == "demo_ch01_moss_bell_court" or config_id == "demo_ch02_rain_foundry_canal":
                min_mapped = 3
            elif config_id == "demo_ch03_saltwhite_archive" or config_id == "demo_ch04_broken_string_greenhouse":
                min_mapped = 4
            if min_mapped > 0:
                suite._assert(boss_animation_mapped >= min_mapped, config_id + " boss ai has enough high-fidelity animation mappings")


static func validate_boss_ai_animation(suite: SceneTree, config_id: String, attack_data: Dictionary) -> int:
    var config: Dictionary = suite._load_json("res://data/"+config_id+".json")
    var path = "res://assets/sprites/original_creatures/"+String(config.boss.kind)+"/manifest.json"
    suite._assert(suite._manifest_has_directional_animation(path,String(attack_data.get("animation","attack"))),config_id+" attack maps to a real animation")
    return 1
