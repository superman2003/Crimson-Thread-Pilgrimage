extends SceneTree

const CONFIG_PATH := "res://data/demo_ch02_rain_foundry_canal.json"
const MAIN_SCENE := "res://scenes/Main.tscn"
var failures := 0


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var config := _load_json(CONFIG_PATH)
    _assert(config.size() > 0, "CH02 config loads")
    _assert(config.get("id") == "demo_ch02_rain_foundry_canal", "CH02 runtime id is stable")
    _assert(String(config.get("name", "")).contains("铸雨渠"), "CH02 name is readable")
    _assert(String(config.get("art_theme", "")) == "rain_foundry", "CH02 uses rain foundry art theme")
    var ch01_config := _load_json("res://data/demo_ch01_moss_bell_court.json")
    _assert(not String(config.get("map_title", "")).is_empty() and String(config.get("map_title", "")) != String(ch01_config.get("map_title", "")), "CH02 map title is not CH01")
    var world: Dictionary = config.get("world", {})
    _assert(float(world.get("width", 0)) >= 5200.0 and float(world.get("height", 0)) >= 2400.0 and float(world.get("width", 0)) * float(world.get("height", 0)) >= 14000000.0, "CH02 world is substantially expanded")
    _assert(config.get("map_rooms", []).size() >= 30, "CH02 has boxgarden-scale rooms")
    _assert(config.get("platforms", []).size() >= config.get("map_rooms", []).size() * 2, "CH02 has expanded boxgarden platforms")
    _assert(_platform_materials(config).has("foundry_boss"), "CH02 has foundry boss material")
    _assert(not _platform_materials(config).has("moss_stone"), "CH02 no longer reuses CH01 moss platforms")
    _assert(config.get("npcs", []).size() == 4, "CH02 has 4 NPCs")
    _assert(config.get("enemy_spawns", []).size() >= 10, "CH02 has expanded normal enemies")
    _assert(String(config.get("progression_mode", "")) == "combat_clear", "CH02 uses combat-clear progression")
    _assert(_collectibles_are_ability_items(config), "CH02 collectibles are ability/reward items only (no route tokens)")
    _assert(_has_item_collectible(config, "silk_wall_grip"), "CH02 silk_wall_grip pickup exists (standpipe trial)")
    _assert(_has_item_collectible(config, "echo_hook"), "CH02 echo_hook pickup exists (pendulum works)")
    _assert(_has_item_collectible(config, "testimony_02"), "CH02 testimony_02 pickup exists (drowned archive pod)")
    _assert(bool(config.get("ability_gated_start", false)), "CH02 declares ability-gated start")
    _assert(config.get("inventory", {}).get("starting_tools", []).has("thread_dash"), "CH02 keeps thread_dash as back-compat starting tool")
    _assert(_locked_gates_structured(config), "CH02 locked gates expose id/rect/required_ability/from/to")
    _assert(_gate_count(config, "thread_dash") == 2 and _gate_count(config, "silk_wall_grip") == 3 and _gate_count(config, "echo_hook") == 2, "CH02 gate matrix matches topology spec (dash x2 / wall x3 / hook x2)")
    _assert(config.get("cross_chapter_anchors", []).size() >= 5, "CH02 declares cross-chapter anchors (bellpipe/riser/slag/bellbone/mossgrip)")
    _assert(config.get("parkour_segments", []).size() >= 3, "CH02 has multiple chapter parkour segments")
    _assert(config.get("connections", []).size() >= 15, "CH02 declares explicit MetSys room connections")
    var save_total: int = config.get("save_points", []).size()
    _assert(save_total >= 2 and save_total <= 4, "CH02 save points stay sparse (2-4)")
    _assert(config.get("save_points", []).any(func(item): return item is Dictionary and bool(item.get("hidden", false))), "CH02 has a hidden save point")
    _assert(config.get("boss", {}).get("id") == "C2_B01", "CH02 boss id is stable")
    _assert(config.get("boss", {}).get("name") == "绯线执剪者", "CH02 boss name is readable")
    _assert(String(config.get("boss", {}).get("sprite", "")).contains("boss_02_crimson_thread_scissor_apostle/manifest.json"), "CH02 boss uses high-fidelity boss_02 sprite")
    _assert(config.get("boss", {}).get("sprite_region", []).size() == 4, "CH02 boss has a cropped sprite region")
    _assert(config.get("boss", {}).get("sprite_regions", {}).has("attack"), "CH02 boss has attack sprite region")
    _assert(config.get("boss", {}).has("arena_min_x") and config.get("boss", {}).has("arena_max_x"), "CH02 boss has arena clamp")
    _assert(_visual_region_has_sprite(config.get("boss", {}), "boss"), "CH02 boss region is not blue placeholder")
    for enemy in config.get("enemy_spawns", []):
        if enemy is Dictionary:
            _assert(_visual_region_has_sprite(enemy, String(enemy.get("id", "enemy"))), String(enemy.get("id", "enemy")) + " region is not blue placeholder")
    _assert(_text_has(config.get("asset_policy", {}), "Dark Fantasy"), "CH02 enemies are mapped to open dark fantasy assets")
    _assert(_text_has(config.get("asset_policy", {}), "Crimson Thread original map art"), "CH02 environment uses project-owned original map art")
    _assert(_text_has(config.get("asset_policy", {}), "仅友方 NPC"), "CH02 same-family art remains NPC-only")

    var scene: Node = load(MAIN_SCENE).instantiate()
    scene.set("config_path", CONFIG_PATH)
    root.add_child(scene)
    await process_frame
    await process_frame

    var state: Dictionary = scene.get_demo_state()
    _assert(state.get("config_id") == "demo_ch02_rain_foundry_canal", "Main scene uses CH02 injected config")
    _assert(state.get("art_theme_id") == "rain_foundry", "runtime uses CH02 rain foundry theme")
    _assert(String(state.get("visual_asset_source", "")).contains("original map art"), "runtime reports original map art source")
    _assert((state.get("platform_materials", []) as Array).has("wet_metal"), "runtime exposes CH02 wet metal platforms")
    _assert(not (state.get("platform_materials", []) as Array).has("moss_stone"), "runtime CH02 platform materials are not CH01 moss")
    _assert(state.get("campaign_current_chapter") == "铸雨渠", "campaign maps runtime config to CH02")
    _assert(state.get("campaign_next_chapter") == "盐白书库", "campaign next chapter is CH03")
    _assert(state.get("normal_enemy_total") == config.get("enemy_spawns", []).size(), "scene spawned configured CH02 enemies")
    for enemy_position in state.get("enemy_positions", []):
        var enemy_state: Dictionary = enemy_position
        _assert(bool(enemy_state.get("spawn_clear", false)), "CH02 enemy spawn is clear of walls: " + String(enemy_state.get("id", "")))
        var leash_radius := float(enemy_state.get("leash_radius", 0.0))
        _assert(leash_radius > 0.0 and leash_radius <= 280.0, "CH02 normal enemy has small leash radius: " + String(enemy_state.get("id", "")))
    _assert(int(state.get("metsys_map_cells", 0)) >= config.get("map_rooms", []).size(), "CH02 MetSys includes expanded room cells")
    _assert(int(state.get("metsys_route_edges", 0)) >= config.get("connections", []).size(), "CH02 MetSys uses explicit room connections")
    _assert(int(state.get("metsys_connector_cells", 0)) >= 1, "CH02 MetSys adds vertical connector cells")
    _assert(state.get("hazard_total") >= 6, "scene spawned CH02 hazards")
    _assert(int(state.get("collectible_total", -1)) == _item_collectible_count(config), "scene spawned exactly the configured ability/reward items")
    _assert(state.get("npc_total") == 4, "scene spawned 4 CH02 NPCs")

    _assert(scene.player.dash_unlocked == true, "CH02 dash carries over via starting tools")
    _assert(scene.player.wall_grip_unlocked == false, "CH02 wall grip starts locked")
    _assert(not scene.locked_gate_bodies.has("gate_dash_wheel"), "CH02 dash gates open from chapter start (back-compat)")
    _assert(scene.locked_gate_bodies.has("gate_wall_standpipe"), "CH02 wall gate sealed before pickup")
    _assert(scene.locked_gate_bodies.has("gate_hook_chain"), "CH02 hook gate sealed before pickup")
    var grip_pickup: Area2D = scene.get_node_or_null("col_silk_wall_grip")
    _assert(grip_pickup != null, "CH02 silk_wall_grip pickup spawned in the trial cell")
    scene._on_collectible_body_entered(scene.player, grip_pickup)
    _assert(scene.player.wall_grip_unlocked == true, "CH02 silk_wall_grip pickup unlocks wall grip")
    _assert(not scene.locked_gate_bodies.has("gate_wall_standpipe"), "CH02 wall gates open after pickup")
    _assert(not scene.locked_gate_bodies.has("gate_wall_tower"), "CH02 all wall gates open after pickup")
    _assert(not scene.locked_gate_bodies.has("gate_wall_vault"), "CH02 vault wall gate opens after pickup")
    _assert(scene.locked_gate_bodies.has("gate_hook_chain"), "CH02 hook gates stay sealed until the boss reward")
    var hook_pickup: Area2D = scene.get_node_or_null("col_echo_hook")
    _assert(hook_pickup != null, "CH02 echo_hook pickup spawned in the pendulum works")
    scene._on_collectible_body_entered(scene.player, hook_pickup)
    _assert(not scene.locked_gate_bodies.has("gate_hook_chain"), "CH02 hook gates open after echo_hook")
    _assert(not scene.locked_gate_bodies.has("gate_hook_skylight"), "CH02 skylight hook gate opens after echo_hook")
    _assert(state.get("boss_spawned") == false, "CH02 boss waits behind gate")
    _assert(int(state.get("av_runtime_event_total", 0)) >= 8, "runtime AV manifest is loaded")
    _assert(state.get("av_chapter_total") == 6, "AV manifest still covers all 6 chapters")

    for npc_id in ["npc_rain_smith_liu", "npc_canal_child", "npc_sluice_nun", "npc_drowned_foreman"]:
        var npc: Area2D = scene.get_node_or_null(npc_id)
        _assert(npc != null, npc_id + " exists")
        _assert(String(npc.get_meta("kind", "")) == "npc", npc_id + " is an NPC interactable")
        _assert(npc.get_meta("dialogue", []).size() >= 3, npc_id + " has chapter dialogue")
        _assert(npc.has_node("FriendlyTalkBadge"), npc_id + " has friendly talk badge")
        _assert(npc.has_node("FriendlyHalo"), npc_id + " has friendly halo")

    var enemy_kinds := _enemy_kinds()
    for expected_kind in ["drain_leech", "pipe_thrower", "rust_diver", "bell_mote", "waterwheel_knight"]:
        _assert(enemy_kinds.has(expected_kind), "CH02 enemy kind exists: " + expected_kind)

    var first_npc: Area2D = scene.get_node_or_null("npc_rain_smith_liu")
    scene.nearby_interactable = first_npc
    scene._try_interact()
    _assert(int(first_npc.get_meta("dialogue_index", 0)) == 1, "CH02 NPC dialogue advances")

    scene._debug_clear_combat_route()
    var lever: Area2D = scene.get_node_or_null("waterwheel_shortcut_lever")
    _assert(lever != null, "CH02 shortcut lever exists")
    scene.nearby_interactable = lever
    scene._try_interact()
    state = scene.get_demo_state()
    _assert(state.get("shortcut_open") == true, "CH02 combat clear opens boss route")
    _assert(state.get("boss_unlocked") == true, "CH02 combat clear unlocks boss gate")

    var boss_gate: Area2D = scene.get_node_or_null("sunken_hammer_gate")
    _assert(boss_gate != null, "CH02 boss gate exists")
    scene.nearby_interactable = boss_gate
    scene._try_interact()
    await process_frame
    state = scene.get_demo_state()
    _assert(state.get("boss_spawned") == true, "CH02 boss gate spawns boss")
    _assert(state.get("boss_arena_locked") == true, "CH02 boss room locks after entry")
    _assert(scene.get_node_or_null("boss_arena_lock_wall") != null, "CH02 boss lock wall exists")
    _assert(scene.boss_actor != null, "CH02 boss actor exists")
    _assert(scene.boss_actor.spawn_id == "C2_B01", "CH02 boss actor has stable spawn id")
    _assert(scene.boss_actor.kind == "sunken_hammer_smith", "CH02 boss actor uses CH02 kind")
    _assert(scene.boss_actor.get("arena_min_x") < scene.boss_actor.get("arena_max_x"), "CH02 boss runtime has arena bounds")
    _assert(not bool(scene.boss_actor.get("sprite_faces_left")), "CH02 boss source faces right")
    _assert(String(scene.boss_actor.get("asset_path")).contains("boss_02_crimson_thread_scissor_apostle/manifest.json"), "CH02 boss runtime uses high-fidelity boss_02 manifest")
    scene.boss_actor.set("direction", 1)
    scene.boss_actor._begin_attack({
        "id": "validation_lock",
        "type": "melee",
        "windup": 0.2,
        "active": 0.1,
        "recover": 0.1,
        "cooldown": 1.0,
        "hit_width": 120,
        "hit_height": 80,
        "offset": 60
    })
    scene.boss_actor.set("direction", -1)
    _assert(int(scene.boss_actor.get("attack_direction")) == 1, "CH02 boss attack direction locks during windup")
    _assert(int(state.get("boss_attack_total", 0)) >= 9, "CH02 boss has expanded move list")
    _assert((state.get("boss_attack_types", []) as Array).has("shockwave"), "CH02 boss has shockwave")

    var leash_enemy := _first_normal_enemy(scene)
    _assert(leash_enemy != null, "CH02 has a normal enemy for leash validation")
    var leash_spawn: Vector2 = leash_enemy.get("spawn_position")
    var leash_radius := float(leash_enemy.get("leash_radius"))
    leash_enemy.global_position = Vector2(leash_spawn.x + leash_radius + 96.0, leash_spawn.y)
    leash_enemy._physics_process(0.1)
    _assert(absf(leash_enemy.global_position.x - leash_spawn.x) <= leash_radius + 1.0, "CH02 normal enemy clamps to leash radius")

    scene.boss_actor.take_hit(1, 1)
    _assert(int(scene.boss_actor.hp) < int(config.get("boss", {}).get("hp", 1)), "CH02 boss can be damaged before death reset")
    scene.player.respawn_at(scene.player.spawn_position)
    await process_frame
    await process_frame
    state = scene.get_demo_state()
    _assert(state.get("boss_spawned") == true, "CH02 player death restores active boss")
    _assert(state.get("boss_arena_locked") == false, "CH02 player death unlocks boss room")
    _assert(int(state.get("normal_enemy_defeated", -1)) == 0, "CH02 player death resets normal enemy defeat counter")
    _assert((state.get("enemy_positions", []) as Array).size() == config.get("enemy_spawns", []).size(), "CH02 player death respawns normal enemies")
    for enemy_position in state.get("enemy_positions", []):
        var reset_enemy_state: Dictionary = enemy_position
        _assert(bool(reset_enemy_state.get("spawn_clear", false)), "CH02 reset enemy spawn is clear of walls: " + String(reset_enemy_state.get("id", "")))

    scene.nearby_interactable = boss_gate
    scene._try_interact()
    await process_frame
    state = scene.get_demo_state()
    _assert(state.get("boss_spawned") == true, "CH02 boss can restart after death reset")
    _assert(state.get("boss_arena_locked") == true, "CH02 boss room relocks after restart")

    scene._debug_kill_boss()
    await process_frame
    state = scene.get_demo_state()
    _assert(state.get("demo_complete") == true, "CH02 demo can complete")
    _assert(state.get("boss_arena_locked") == false, "CH02 boss death unlocks boss room")
    _assert(scene.inventory_counts.has("smith_oath_plate"), "CH02 boss reward is granted")
    _assert(String(scene.win_label.text).contains("绯线执剪者"), "CH02 completion text is data-driven")
    var chapter_exit: Area2D = scene.get_node_or_null("ch02_chapter_exit")
    _assert(chapter_exit != null, "CH02 chapter exit exists")
    _assert(String(chapter_exit.get_meta("next_runtime_config_id", "")) == "demo_ch03_saltwhite_archive", "CH02 chapter exit points to CH03")
    scene.nearby_interactable = null
    scene.player.global_position = chapter_exit.global_position + Vector2(-95.0, 0.0)
    scene._try_interact()
    await process_frame
    await process_frame
    _assert(_find_runtime_scene("demo_ch03_saltwhite_archive") != null, "CH02 nearby F fallback enters CH03")

    if failures == 0:
        print("CH02_DEMO_VALIDATION_PASS enemies=%s npcs=4 keys=0 boss=C2_B01 combat_clear=true complete=true" % state.get("normal_enemy_total"))
        quit(0)
    else:
        push_error("CH02_DEMO_VALIDATION_FAIL failures=%d" % failures)
        quit(1)


func _enemy_kinds() -> Array:
    var kinds: Array = []
    for enemy in get_nodes_in_group("enemy"):
        if enemy.is_boss:
            continue
        kinds.append(enemy.kind)
    return kinds


func _first_normal_enemy(scene: Node) -> Area2D:
    for enemy in scene.get_tree().get_nodes_in_group("enemy"):
        var area := enemy as Area2D
        if area == null or bool(area.get("is_boss")):
            continue
        return area
    return null


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


func _collectibles_are_ability_items(config: Dictionary) -> bool:
    var catalog: Dictionary = config.get("inventory", {}).get("catalog", {})
    for collectible in config.get("collectibles", []):
        if not (collectible is Dictionary):
            return false
        var data: Dictionary = collectible
        if String(data.get("kind", "")) != "item":
            return false
        if not catalog.has(String(data.get("item_id", ""))):
            return false
    return true


func _has_item_collectible(config: Dictionary, item_id: String) -> bool:
    for collectible in config.get("collectibles", []):
        if collectible is Dictionary and String((collectible as Dictionary).get("item_id", "")) == item_id:
            return true
    return false


func _item_collectible_count(config: Dictionary) -> int:
    var total := 0
    for collectible in config.get("collectibles", []):
        if collectible is Dictionary and String((collectible as Dictionary).get("kind", "")) == "item":
            total += 1
    return total


func _locked_gates_structured(config: Dictionary) -> bool:
    var gates: Array = config.get("locked_gates", [])
    if gates.size() < 7:
        return false
    for gate in gates:
        if not (gate is Dictionary):
            return false
        var data: Dictionary = gate
        if String(data.get("id", "")).is_empty() or String(data.get("required_ability", "")).is_empty():
            return false
        if data.get("rect", []).size() != 4:
            return false
        if String(data.get("from", "")).is_empty() or String(data.get("to", "")).is_empty():
            return false
    return true


func _gate_count(config: Dictionary, ability: String) -> int:
    var total := 0
    for gate in config.get("locked_gates", []):
        if gate is Dictionary and String((gate as Dictionary).get("required_ability", "")) == ability:
            total += 1
    return total


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


func _visual_region_has_sprite(data: Dictionary, label: String) -> bool:
    var sprite_path := String(data.get("sprite", ""))
    if sprite_path.is_empty():
        return false
    if sprite_path.ends_with(".json"):
        return _manifest_has_visible_frames(sprite_path, label)
    var image := Image.load_from_file(ProjectSettings.globalize_path(sprite_path))
    if image == null:
        return false
    if not _image_region_has_visible_non_blue(image, data.get("sprite_region", [])):
        return false
    var regions: Dictionary = data.get("sprite_regions", {})
    for key in regions.keys():
        if not _image_region_has_visible_non_blue(image, regions[key]):
            push_error("FAIL: " + label + " " + String(key) + " region is blue/empty placeholder")
            return false
    return true


func _manifest_has_visible_frames(sprite_path: String, label: String) -> bool:
    var file := FileAccess.open(sprite_path, FileAccess.READ)
    if file == null:
        return false
    var manifest = JSON.parse_string(file.get_as_text())
    if typeof(manifest) != TYPE_DICTIONARY:
        return false
    var required := ["idle", "walk", "attack", "hurt", "death"]
    for animation_name in required:
        var found := false
        for animation in manifest.get("animations", []):
            if not (animation is Dictionary):
                continue
            var animation_data: Dictionary = animation
            if String(animation_data.get("name", "")) != animation_name:
                continue
            found = true
            var frames: Array = animation_data.get("frames", [])
            if frames.is_empty():
                push_error("FAIL: " + label + " " + animation_name + " has no keyframes")
                return false
            var image := Image.load_from_file(ProjectSettings.globalize_path(String(frames[0])))
            if image == null or not _image_region_has_visible_non_blue(image, [0, 0, image.get_width(), image.get_height()]):
                push_error("FAIL: " + label + " " + animation_name + " keyframe is empty/blue")
                return false
        if not found:
            push_error("FAIL: " + label + " missing " + animation_name + " animation")
            return false
    return true


func _image_region_has_visible_non_blue(image: Image, region_value) -> bool:
    if not (region_value is Array) or region_value.size() < 4:
        return false
    var x0 := clampi(int(region_value[0]), 0, image.get_width())
    var y0 := clampi(int(region_value[1]), 0, image.get_height())
    var x1 := clampi(x0 + int(region_value[2]), 0, image.get_width())
    var y1 := clampi(y0 + int(region_value[3]), 0, image.get_height())
    var visible := 0
    var non_blue := 0
    for y in range(y0, y1):
        for x in range(x0, x1):
            var color := image.get_pixel(x, y)
            if color.a <= 0.05:
                continue
            visible += 1
            var is_placeholder_blue := color.r < 0.08 and color.g < 0.08 and color.b > 0.85
            if not is_placeholder_blue:
                non_blue += 1
    if visible <= 0:
        return false
    return float(non_blue) / float(visible) > 0.08


func _load_json(path: String) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var data = JSON.parse_string(file.get_as_text())
    return data if typeof(data) == TYPE_DICTIONARY else {}


func _text_has(value, needle: String) -> bool:
    return JSON.stringify(value).contains(needle)


func _assert(condition: bool, label: String) -> void:
    if condition:
        print("PASS: " + label)
        return
    push_error("FAIL: " + label)
    failures += 1
