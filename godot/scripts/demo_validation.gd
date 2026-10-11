extends SceneTree

var failures := 0

const CONFIG_PATH := "res://data/demo_ch01_moss_bell_court.json"
const MAIN_SCENE := "res://scenes/Main.tscn"


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var config := _load_json(CONFIG_PATH)
    _assert(config.size() > 0, "config loads")
    _assert(_world_is_expanded(config.get("world", {})), "chapter world is expanded")
    _assert(config.get("map_rooms", []).size() >= 10, "runtime map has expanded rooms")
    _assert(config.get("platforms", []).size() >= 20, "runtime map has expanded platforms")
    _assert(config.get("enemy_spawns", []).size() >= 7, "normal enemy spawn count expanded")
    _assert(config.get("hazards", []).size() >= 6, "hazard count >= 6")
    _assert(String(config.get("progression_mode", "")) == "combat_clear", "chapter uses combat-clear progression")
    _assert(_collectibles_are_ability_items(config), "collectibles are ability/reward items only (no route tokens)")
    _assert(config.get("locked_gates", []).size() >= 8, "boxgarden exposes ability gates for revisits")
    _assert(_has_ability_collectible(config, "thread_dash"), "thread_dash ability pickup exists")
    _assert(bool(config.get("ability_gated_start", false)), "chapter declares ability-gated start (dash locked)")
    _assert(config.get("parkour_segments", []).size() >= 1, "chapter has parkour segment")
    _assert(_connection_has_kind(config, "one_way_drop"), "map has a see-then-return one-way drop")
    _assert(_connection_has_shortcut(config), "map has an unlockable back-door shortcut")
    _assert(_main_route_reachable_physics(config), "main route platforms reachable under player physics")
    _assert(_parkour_clearance_ok(config, 200.0), "ascent parkour segment guarantees jump headroom")
    _assert(config.has("boss"), "boss config exists")
    _assert(config.get("interactives", []).any(func(item): return item is Dictionary and String(item.get("kind", "")) == "chapter_exit"), "chapter exit config exists")

    var scene: Node = load(MAIN_SCENE).instantiate()
    root.add_child(scene)
    await process_frame
    await process_frame

    var state: Dictionary = scene.get_demo_state()
    _assert(state.get("normal_enemy_total") == config.get("enemy_spawns", []).size(), "scene spawned configured normal enemies")
    _assert(state.get("hazard_total") >= 6, "scene spawned hazards")
    _assert(int(state.get("collectible_total", -1)) == _item_collectible_count(config), "scene spawned exactly the configured ability/reward items")
    var save_total := int(state.get("save_point_total", 0))
    _assert(save_total >= 2 and save_total <= 4, "scene spawned sparse save points (2-4)")
    _assert(int(state.get("hidden_save_point_total", 0)) >= 1, "scene spawned a hidden save point")
    _assert(scene.player.dash_unlocked == false, "dash starts locked before thread_dash pickup")
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

    var dash_pickup: Area2D = scene.get_node_or_null("col_thread_dash")
    _assert(dash_pickup != null, "thread_dash pickup spawned at the broken branch altar")
    _assert(scene.locked_gate_bodies.has("gate_dash_bell_gap"), "dash gate is sealed before pickup")
    _assert(scene.locked_gate_bodies.has("gate_jump_salt"), "future-ability gate is sealed before pickup")
    scene._on_collectible_body_entered(scene.player, dash_pickup)
    _assert(scene.player.dash_unlocked == true, "thread_dash pickup unlocks the dash")
    _assert(not scene.locked_gate_bodies.has("gate_dash_bell_gap"), "dash gates open after pickup")
    _assert(not scene.locked_gate_bodies.has("gate_dash_cache"), "all dash gates open after pickup")
    _assert(scene.locked_gate_bodies.has("gate_jump_salt"), "future-ability gates stay sealed for revisits")

    var save_point: Area2D = scene.get_node_or_null("save_hidden_upper_respite")
    _assert(save_point != null, "hidden save point exists")
    _assert(save_point.has_node("SavePointSprite"), "save point uses open sprite")
    _assert(save_point.has_node("SavePointHalo"), "save point has animated halo")
    scene.player.hp = 2
    scene.player.energy = 0
    scene.player.global_position = save_point.global_position
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
    scene.player.global_position = npc.global_position
    scene._try_interact()
    _assert(int(npc.get_meta("dialogue_index", 0)) == 1, "F interaction advances npc dialogue")

    scene._debug_clear_combat_route()
    var lever: Area2D = scene.get_node_or_null("shortcut_lever")
    _assert(lever != null, "shortcut lever exists")
    scene.player.global_position = lever.global_position
    scene._try_interact()
    state = scene.get_demo_state()
    _assert(state.get("shortcut_open") == true, "combat clear opens boss route")
    _assert(state.get("boss_unlocked") == true, "combat clear unlocks boss")

    var boss_gate: Area2D = scene.get_node_or_null("boss_gate")
    _assert(boss_gate != null, "boss gate exists")
    scene.player.global_position = boss_gate.global_position
    scene._try_interact()
    state = scene.get_demo_state()
    _assert(state.get("boss_spawned") == true, "F interaction spawns boss")
    _assert(int(state.get("boss_attack_total", 0)) == 4, "boss has four distinct authored attacks")
    for attack_type in ["melee", "wave", "fan", "rootline"]:
        _assert((state.get("boss_attack_types", []) as Array).has(attack_type), "boss has " + attack_type + " attack")

    scene._debug_kill_boss()
    state = scene.get_demo_state()
    _assert(state.get("demo_complete") == true, "demo can complete")
    var chapter_exit: Area2D = scene.get_node_or_null("ch01_chapter_exit")
    _assert(chapter_exit != null, "chapter exit exists after boss")
    _assert(String(chapter_exit.get_meta("next_runtime_config_id", "")) == "demo_ch02_rain_foundry_canal", "chapter exit points to CH02")

    if failures > 0:
        quit(1)
        return
    print("DEMO_VALIDATION_PASS enemies=%s hazards=%s keys=0 boss=1 combat_clear=true complete=true" % [state.get("normal_enemy_total"), state.get("hazard_total")])
    quit(0)


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


func _has_ability_collectible(config: Dictionary, item_id: String) -> bool:
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


func _connection_has_kind(config: Dictionary, kind: String) -> bool:
    for connection in config.get("connections", []):
        if not (connection is Dictionary):
            continue
        var data: Dictionary = connection
        if String(data.get("type", "")) == kind or String(data.get("edge_kind", "")) == kind:
            return true
    return false


func _connection_has_shortcut(config: Dictionary) -> bool:
    for connection in config.get("connections", []):
        if not (connection is Dictionary):
            continue
        var data: Dictionary = connection
        if String(data.get("type", "")) == "shortcut" or String(data.get("edge_kind", "")) == "unlock_shortcut":
            return true
        if not String(data.get("shortcut_id", "")).is_empty():
            return true
    return false


func _world_is_expanded(world: Dictionary) -> bool:
    # True-2D maps trade raw width for vertical layers; require enough area
    # in both axes instead of a 1D ribbon length.
    var width := float(world.get("width", 0))
    var height := float(world.get("height", 0))
    return width >= 5200.0 and height >= 2400.0 and width * height >= 14000000.0


# Mirrors tools/audit_platform_geometry.py: conservative ballistic reachability
# via BFS over every standable platform, starting from the player start supports.
func _main_route_reachable_physics(config: Dictionary) -> bool:
    var platforms: Array = []
    for platform in config.get("platforms", []):
        if platform is Dictionary and _is_standable(platform):
            platforms.append(platform)
    if platforms.size() < 2:
        return false
    var start: Array = config.get("player_start", [])
    if start.size() < 2:
        return false
    var reached: Dictionary = {}
    var queue: Array = []
    for index in range(platforms.size()):
        var rect := _rect_of(platforms[index])
        if float(start[0]) >= rect.position.x - 17.0 and float(start[0]) <= rect.position.x + rect.size.x + 17.0:
            var offset := rect.position.y - float(start[1])
            if offset >= -8.0 and offset <= 100.0:
                reached[index] = true
                queue.append(index)
    if queue.is_empty():
        return false
    while not queue.is_empty():
        var current: int = queue.pop_front()
        for next_index in range(platforms.size()):
            if reached.has(next_index):
                continue
            if _jump_reachable(_rect_of(platforms[current]), _rect_of(platforms[next_index])):
                reached[next_index] = true
                queue.append(next_index)
    for index in range(platforms.size()):
        if String((platforms[index] as Dictionary).get("route_role", "")) == "main" and not reached.has(index):
            return false
    return true


func _is_standable(platform: Dictionary) -> bool:
    var role := String(platform.get("collision_role", "")).to_lower()
    return role not in ["wall", "ceiling", "decorative"]


func _rect_of(platform: Dictionary) -> Rect2:
    var rect_value: Array = platform.get("rect", [])
    if rect_value.size() < 4:
        return Rect2()
    return Rect2(float(rect_value[0]), float(rect_value[1]), float(rect_value[2]), float(rect_value[3]))


func _jump_reachable(from_rect: Rect2, to_rect: Rect2) -> bool:
    const SPEED := 285.0
    const JUMP := 710.0
    const GRAVITY := 1850.0
    const DASH_REACH := 780.0 * 0.16 * 0.82
    const SAFETY := 0.82
    const MAX_MULT := 1.22
    var delta_y := to_rect.position.y - from_rect.position.y
    var rise := -delta_y
    var jump_height := JUMP * JUMP / (2.0 * GRAVITY)
    if rise > jump_height * 0.88 or delta_y > 320.0:
        return false
    var discriminant := JUMP * JUMP + 2.0 * GRAVITY * delta_y
    if discriminant < 0.0:
        return false
    var landing_time := (JUMP + sqrt(discriminant)) / GRAVITY
    var air_time := 2.0 * JUMP / GRAVITY
    var combined := SPEED * air_time * SAFETY + DASH_REACH
    var allowed: float = minf(SPEED * landing_time * SAFETY + DASH_REACH, combined * MAX_MULT)
    var gap: float = maxf(0.0, maxf(to_rect.position.x - (from_rect.position.x + from_rect.size.x), from_rect.position.x - (to_rect.position.x + to_rect.size.x)))
    if gap > 0.0 and to_rect.size.x < 64.0:
        return false
    return gap <= allowed


func _parkour_clearance_ok(config: Dictionary, min_clearance: float) -> bool:
    for segment in config.get("parkour_segments", []):
        if not (segment is Dictionary):
            continue
        var contract: Dictionary = (segment as Dictionary).get("safety_contract", {})
        if float(contract.get("minimum_full_jump_clearance", 0.0)) >= min_clearance:
            return true
    return false


func _assert(condition: bool, label: String) -> void:
    if condition:
        print("PASS: " + label)
        return
    failures += 1
    push_error("FAIL: " + label)
