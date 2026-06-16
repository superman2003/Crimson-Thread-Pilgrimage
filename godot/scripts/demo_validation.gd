extends SceneTree

const CONFIG_PATH := "res://data/demo_ch01_moss_bell_court.json"
const MAIN_SCENE := "res://scenes/Main.tscn"


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var config := _load_json(CONFIG_PATH)
    _assert(config.size() > 0, "config loads")
    _assert(config.get("world", {}).get("width", 0) >= 9600, "chapter world is expanded")
    _assert(config.get("map_rooms", []).size() >= 10, "runtime map has expanded rooms")
    _assert(config.get("platforms", []).size() >= 20, "runtime map has expanded platforms")
    _assert(config.get("enemy_spawns", []).size() >= 7, "normal enemy spawn count expanded")
    _assert(config.get("hazards", []).size() >= 6, "hazard count >= 6")
    _assert(String(config.get("progression_mode", "")) == "combat_clear", "chapter uses combat-clear progression")
    _assert(config.get("collectibles", []).is_empty(), "chapter has no route-token collectibles")
    _assert(config.get("parkour_segments", []).size() >= 1, "chapter has parkour segment")
    _assert(_platform_step_reachable(config, "outer_drop", "outer_return_lip", 190.0, 70.0), "outer court drop has return lip")
    _assert(_platform_step_reachable(config, "outer_return_lip", "gear_lift", 170.0, 70.0), "outer return lip reaches gear lift")
    _assert(_platform_step_reachable(config, "gear_lift", "gear_lift_return_step", 170.0, 60.0), "gear lift has forward return step")
    _assert(_platform_step_reachable(config, "gear_lift_return_step", "moss_steps_a", 180.0, 60.0), "gear return step reaches moss steps")
    _assert(_climb_corridor_clear(config, Rect2(1760.0, 380.0, 1000.0, 170.0), ["outer_return_lip", "gear_lift", "gear_lift_return_step", "moss_steps_a"]), "outer court return climb shaft has headroom")
    _assert(config.has("boss"), "boss config exists")
    _assert(config.get("interactives", []).any(func(item): return item is Dictionary and String(item.get("kind", "")) == "chapter_exit"), "chapter exit config exists")

    var scene: Node = load(MAIN_SCENE).instantiate()
    root.add_child(scene)
    await process_frame
    await process_frame

    var state: Dictionary = scene.get_demo_state()
    _assert(state.get("normal_enemy_total") == config.get("enemy_spawns", []).size(), "scene spawned configured normal enemies")
    _assert(state.get("hazard_total") >= 6, "scene spawned hazards")
    _assert(state.get("collectible_total") == 0, "scene spawned no route-token collectibles")
    _assert(int(state.get("save_point_total", 0)) == 2, "scene spawned sparse save points")
    _assert(int(state.get("hidden_save_point_total", 0)) == 1, "scene spawned a hidden save point")
    _assert(state.get("boss_spawned") == false, "boss waits behind gate")
    _assert(state.get("npc_total") >= 1, "scene spawned interactive npc")
    _assert(int(state.get("av_runtime_event_total", 0)) >= 8, "scene loads required runtime audio visual events")
    _assert(state.get("av_chapter_total") == 6, "scene loads CH01-CH06 audio visual beats")

    var trap: Area2D = scene.get_node_or_null("trap_fake_moss_01")
    _assert(trap != null, "trap exists")
    scene.player.global_position = Vector2(1500, 550)
    var position_before_trap: Vector2 = scene.player.global_position
    var hp_before_trap := int(scene.player.hp)
    scene._on_hazard_body_entered(scene.player, trap)
    _assert(int(scene.player.hp) == hp_before_trap - 1, "trap costs 1 hp")
    _assert(scene.player.global_position.distance_to(position_before_trap) < 0.1, "trap does not teleport the player")

    var save_point: Area2D = scene.get_node_or_null("save_hidden_upper_respite")
    _assert(save_point != null, "hidden save point exists")
    _assert(save_point.has_node("SavePointSprite"), "save point uses open sprite")
    _assert(save_point.has_node("SavePointHalo"), "save point has animated halo")
    scene.player.hp = 2
    scene.player.energy = 0
    scene.nearby_interactable = save_point
    scene._try_interact()
    state = scene.get_demo_state()
    _assert(String(state.get("active_save_point_id", "")) == "save_hidden_upper_respite", "F interaction activates save point")
    _assert(int(scene.player.hp) == scene.player.max_hp, "save point restores hp")
    _assert(int(scene.player.energy) == scene.player.max_energy, "save point restores energy")
    _assert(bool(save_point.get_meta("activated", false)), "save point activation state is marked")
    scene.player.hurt_timer = 0.0
    scene.player.hp = scene.player.max_hp
    scene.player.take_damage(scene.player.hp, scene.player.global_position + Vector2(0, -80))
    for frame in range(80):
        await physics_frame
    _assert(scene.player.global_position.distance_to(save_point.global_position) < 40.0, "death respawns at activated save point")
    _assert(int(scene.player.hp) == scene.player.max_hp, "death respawn restores hp")
    scene.player.global_position = Vector2(260, float(scene.fall_y) + 80.0)
    await process_frame
    for frame in range(80):
        await physics_frame
    _assert(scene.player.global_position.distance_to(save_point.global_position) < 40.0, "void fall respawns at activated save point after death")

    var npc: Area2D = scene.get_node_or_null("npc_threadsmith_apprentice")
    _assert(npc != null, "threadsmith npc exists")
    scene.nearby_interactable = npc
    scene._try_interact()
    _assert(int(npc.get_meta("dialogue_index", 0)) == 1, "F interaction advances npc dialogue")

    scene._debug_clear_combat_route()
    var lever: Area2D = scene.get_node_or_null("shortcut_lever")
    _assert(lever != null, "shortcut lever exists")
    scene.nearby_interactable = lever
    scene._try_interact()
    state = scene.get_demo_state()
    _assert(state.get("shortcut_open") == true, "combat clear opens boss route")
    _assert(state.get("boss_unlocked") == true, "combat clear unlocks boss")

    var boss_gate: Area2D = scene.get_node_or_null("boss_gate")
    _assert(boss_gate != null, "boss gate exists")
    scene.nearby_interactable = boss_gate
    scene._try_interact()
    state = scene.get_demo_state()
    _assert(state.get("boss_spawned") == true, "F interaction spawns boss")
    _assert(int(state.get("boss_attack_total", 0)) >= 9, "boss has expanded move list")
    _assert((state.get("boss_attack_types", []) as Array).has("shockwave"), "boss has shockwave attack")
    _assert((state.get("boss_attack_types", []) as Array).has("retreat"), "boss has retreat attack")
    _assert((state.get("boss_attack_types", []) as Array).has("feint"), "boss has feint attack")

    scene._debug_kill_boss()
    state = scene.get_demo_state()
    _assert(state.get("demo_complete") == true, "demo can complete")
    var chapter_exit: Area2D = scene.get_node_or_null("ch01_chapter_exit")
    _assert(chapter_exit != null, "chapter exit exists after boss")
    _assert(String(chapter_exit.get_meta("next_runtime_config_id", "")) == "demo_ch02_rain_foundry_canal", "chapter exit points to CH02")

    print("DEMO_VALIDATION_PASS enemies=%s hazards=%s keys=0 boss=1 combat_clear=true complete=true" % [state.get("normal_enemy_total"), state.get("hazard_total")])
    quit(0)


func _load_json(path: String) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var data = JSON.parse_string(file.get_as_text())
    return data if typeof(data) == TYPE_DICTIONARY else {}


func _platform_step_reachable(config: Dictionary, from_id: String, to_id: String, max_gap: float, max_rise: float) -> bool:
    var from_rect := _platform_rect_by_id(config, from_id)
    var to_rect := _platform_rect_by_id(config, to_id)
    if from_rect.size.x <= 0.0 or to_rect.size.x <= 0.0:
        return false
    var horizontal_gap := 0.0
    if from_rect.position.x + from_rect.size.x < to_rect.position.x:
        horizontal_gap = to_rect.position.x - (from_rect.position.x + from_rect.size.x)
    elif to_rect.position.x + to_rect.size.x < from_rect.position.x:
        horizontal_gap = from_rect.position.x - (to_rect.position.x + to_rect.size.x)
    var rise := from_rect.position.y - to_rect.position.y
    return horizontal_gap <= max_gap and rise <= max_rise


func _platform_rect_by_id(config: Dictionary, platform_id: String) -> Rect2:
    for platform in config.get("platforms", []):
        if not (platform is Dictionary):
            continue
        var data: Dictionary = platform
        if String(data.get("id", "")) != platform_id:
            continue
        var rect_value: Array = data.get("rect", [])
        if rect_value.size() < 4:
            return Rect2()
        return Rect2(float(rect_value[0]), float(rect_value[1]), float(rect_value[2]), float(rect_value[3]))
    return Rect2()


func _climb_corridor_clear(config: Dictionary, corridor: Rect2, allowed_platform_ids: Array) -> bool:
    for platform in config.get("platforms", []):
        if not (platform is Dictionary):
            continue
        var data: Dictionary = platform
        var platform_id := String(data.get("id", ""))
        if allowed_platform_ids.has(platform_id):
            continue
        var rect_value: Array = data.get("rect", [])
        if rect_value.size() < 4:
            continue
        var rect := Rect2(float(rect_value[0]), float(rect_value[1]), float(rect_value[2]), float(rect_value[3]))
        if corridor.intersects(rect):
            return false
    return true


func _assert(condition: bool, label: String) -> void:
    if condition:
        print("PASS: " + label)
        return
    push_error("FAIL: " + label)
    quit(1)
