extends SceneTree

const MAIN_SCENE := "res://scenes/Main.tscn"
const MAIN_SCRIPT := preload("res://scripts/main_level.gd")
const CONFIG_PATHS := [
    "res://data/demo_ch01_moss_bell_court.json",
    "res://data/demo_ch02_rain_foundry_canal.json",
    "res://data/demo_ch03_saltwhite_archive.json",
    "res://data/demo_ch04_broken_string_greenhouse.json",
    "res://data/demo_ch05_obsidian_pilgrim_road.json",
    "res://data/demo_ch06_silent_crown_core.json"
]
const NESTED_ROOMS := {
    "demo_ch01_moss_bell_court": ["hub_gallery", "sluice_hall", "mossgrip_shaft", "maze_respite"],
    "demo_ch02_rain_foundry_canal": ["wish_board_landing", "gauge_gallery", "drowned_archive_pod", "counterweight_niche", "preboss_causeway", "pendulum_works"],
    "demo_ch05_obsidian_pilgrim_road": ["pilgrim_camp"]
}
var failures := 0
var checks := 0


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    _validate_room_fallback()
    for config_path in CONFIG_PATHS:
        await _validate_chapter(String(config_path))
    if failures == 0:
        print("CHAPTER_ROUTE_REGRESSION_PASS chapters=6 checks=%d" % checks)
        quit(0)
    else:
        push_error("CHAPTER_ROUTE_REGRESSION_FAIL failures=%d checks=%d" % [failures, checks])
        quit(1)


func _validate_room_fallback() -> void:
    var scene := MAIN_SCRIPT.new()
    scene.config = {"map_rooms": [
        {"id": "upper", "range": [0, 100], "layout_rect": [0, 0, 100, 100]},
        {"id": "lower", "range": [0, 100], "layout_rect": [0, 150, 100, 100]}
    ]}
    _assert(String(scene._room_for_position(Vector2(50, 50)).get("id", "")) == "upper", "same x resolves upper layer")
    _assert(String(scene._room_for_position(Vector2(50, 200)).get("id", "")) == "lower", "same x resolves lower layer")
    _assert(scene._room_for_position(Vector2(50, 400)).is_empty(), "outside authored 2D bounds does not visit an x-only room")
    scene.config = {"map_rooms": [{"id": "legacy", "range": [0, 100]}]}
    _assert(String(scene._room_for_position(Vector2(50, 400)).get("id", "")) == "legacy", "legacy x-only maps remain supported")
    _assert(scene._is_post_boss_blocker("boss_back_wall") and scene._is_post_boss_blocker("C4_BOSS_BACK_WALL"), "legacy and prefixed blocker IDs are recognized case-insensitively")
    _assert(scene._is_post_boss_blocker("ch05_post_boss_wall") and scene._is_post_boss_blocker("ch06_chapter_exit_wall"), "other existing post-boss naming conventions remain supported")
    _assert(not scene._is_post_boss_blocker("decor_boss_back_wall_trim"), "a decorative name containing the legacy ID is not removed")
    scene.free()


func _validate_chapter(config_path: String) -> void:
    var scene: Node = load(MAIN_SCENE).instantiate()
    scene.set("config_path", config_path)
    root.add_child(scene)
    scene.set_process(false)
    # This suite keeps the legacy combat-gated contract; cave progression is
    # exercised separately by cave_exploration_validation.
    scene.config["boss_route_via_exploration"] = false
    scene.player.set_physics_process(false)
    await process_frame
    var config: Dictionary = scene.config
    var config_id := String(config.get("id", ""))
    _validate_one_way_anchors(scene, config_id)
    await _validate_manual_pickup(scene, config_id)
    for room in config.get("map_rooms", []):
        if NESTED_ROOMS.get(config_id, []).has(String(room.get("id", ""))):
            var rect: Array = room.get("layout_rect", [])
            var point := Vector2(float(rect[0]) + float(rect[2]) * 0.5, float(rect[1]) + float(rect[3]) * 0.5)
            _assert(String(scene._room_for_position(point).get("id", "")) == String(room.get("id", "")), config_id + " identifies nested room " + String(room.get("id", "")))
    _assert(_has_landing(config, config.get("player_start", []), scene.player), config_id + " player start has a landing within the movement envelope")
    if config.has("entry_from_previous"):
        _assert(_has_landing(config, config["entry_from_previous"].get("position", []), scene.player), config_id + " campaign entry has a landing within the movement envelope")

    var lever: Area2D = null
    for interactive in config.get("interactives", []):
        if String(interactive.get("kind", "")) == "lever":
            lever = scene.get_node_or_null(String(interactive.get("id", "")))
            break
    _assert(lever != null, config_id + " has a shortcut lever")
    var shortcut_id := String(lever.get_meta("shortcut_id", ""))
    scene.player.global_position = lever.global_position
    scene.nearby_interactable = lever
    scene._try_interact()
    _assert(scene._is_shortcut_open(shortcut_id), config_id + " manual lever works before clearing unrelated enemies")
    _assert(not scene.boss_unlocked, config_id + " opening a manual shortcut does not bypass the combat goal")
    _assert(scene.hud_label.text.contains("Boss Route Closed") and scene.hud_label.text.contains("Shortcuts 1/%d" % scene._shortcut_total()), config_id + " HUD reports the opened shortcut separately from the locked boss route")

    # Start from a closed shortcut with exactly one normal enemy left.
    scene.opened_shortcuts.clear()
    scene.shortcut_open = false
    scene.boss_unlocked = false
    scene.enemy_defeated = scene.enemy_total - 1
    scene._on_enemy_died("route_regression_last_enemy", false, "regression")
    _assert(scene.boss_unlocked, config_id + " last normal enemy unlocks the boss route")
    _assert(not scene._is_shortcut_open(shortcut_id), config_id + " combat clear leaves the manual shortcut closed")
    _assert(scene.opened_shortcuts.is_empty(), config_id + " default combat clear opens no individual manual shortcuts")
    _assert(scene.shortcut_open and bool(scene.get_demo_state().get("shortcut_open", false)), config_id + " aggregate route state reports the unlocked boss route before using the lever")
    _assert(scene.hud_label.text.contains("Boss Route Open") and scene.hud_label.text.contains("Shortcuts 0/%d" % scene._shortcut_total()), config_id + " HUD reports the unlocked boss route separately from closed manual shortcuts")
    scene.config["connections"].append({"from": config["map_rooms"][0]["id"], "to": config["map_rooms"][1]["id"], "type": "shortcut", "shortcut_id": "regression_auto_shortcut"})
    scene._open_combat_clear_route()
    _assert(scene._is_shortcut_open("regression_auto_shortcut"), config_id + " legacy combat shortcuts still open on combat clear")
    scene._try_interact()
    _assert(scene._is_shortcut_open(shortcut_id), config_id + " lever opens the shortcut after combat clear")
    if config_id == "demo_ch01_moss_bell_court":
        scene.config["progression_mode"] = "keys"
        scene.opened_shortcuts.clear()
        scene.shortcut_open = false
        scene.boss_unlocked = false
        scene.bell_count = 0
        lever.set_meta("requires_keys", 3)
        scene._try_interact()
        _assert(not scene._is_shortcut_open(shortcut_id) and not scene.boss_unlocked, "legacy key progression still rejects an unpaid lever")
        scene.bell_count = 3
        scene._try_interact()
        _assert(scene._is_shortcut_open(shortcut_id) and scene.boss_unlocked, "legacy key progression opens after the required marks")
        scene.config["progression_mode"] = "combat_clear"
        lever.set_meta("requires_keys", 0)

    if config_id == "demo_ch06_silent_crown_core":
        await _validate_close_interactions(scene, "save_hidden_upper_respite", "npc_black_tide_child")
        await _validate_close_interactions(scene, "save_ch06_lower_loop", "npc_crown_tongue")

    # The current maps have no legacy exit walls. Inject the old PR's naming
    # convention to exercise actual body removal instead of a vacuous null check.
    var blocker_id := "c%d_boss_back_wall" % (CONFIG_PATHS.find(config_path) + 1)
    var blocker := StaticBody2D.new()
    blocker.name = blocker_id
    var collision := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = Vector2(40, 270)
    collision.shape = shape
    blocker.add_child(collision)
    scene.add_child(blocker)
    scene.config["platforms"].append({"id": blocker_id, "rect": [0, 0, 40, 270]})
    _assert(scene.get_node_or_null(blocker_id) != null, config_id + " legacy blocker exists before boss death")
    _assert(not scene._is_post_boss_blocker("boss_arena_lock_wall"), config_id + " ordinary arena walls are not post-boss blockers")
    scene.player.global_position = scene._boss_gate_position()
    scene._activate_boss_gate()
    _assert(scene.boss_arena_lock_body != null, config_id + " boss entry installs an arena lock")
    var boss: Dictionary = config.get("boss", {})
    var floor := _platform_rect(config, String(boss.get("platform_id", "")))
    var floor_body := _floor_body(scene, String(boss.get("platform_id", "")))
    _assert(_floor_has_collision(floor_body), config_id + " boss arena has a physical platform or terrain floor")
    var min_x := float(boss.get("arena_min_x", -INF))
    var max_x := float(boss.get("arena_max_x", INF))
    _assert(floor.size.x > 0 and min_x >= floor.position.x and max_x <= floor.end.x and min_x < max_x, config_id + " scalar boss bounds fit the current floor")
    var expected_body := Vector2(float(boss["body_size"][0]), float(boss["body_size"][1]))
    var expected_hurtbox := Vector2(float(boss["hurtbox_size"][0]), float(boss["hurtbox_size"][1]))
    _assert(scene.boss_actor.body_size.is_equal_approx(expected_body) and scene.boss_actor.get_hurtbox_rect().size.is_equal_approx(expected_hurtbox), config_id + " original Boss artwork preserves configured body and attack hitbox dimensions")
    var body_shape: CollisionShape2D
    for child in scene.boss_actor.get_children():
        if child is CollisionShape2D:
            body_shape = child
            break
    var expected_offset := Vector2(float(boss["hurtbox_offset"][0]), float(boss["hurtbox_offset"][1]))
    _assert(body_shape != null and body_shape.shape is RectangleShape2D and body_shape.shape.size.is_equal_approx(expected_body) and body_shape.position.is_equal_approx(expected_offset), config_id + " physical contact shape retains configured size and offset")
    scene.boss_actor.global_position.x = min_x - 500
    scene.boss_actor._clamp_movement_bounds()
    _assert(is_equal_approx(scene.boss_actor.global_position.x, min_x), config_id + " boss clamps at left bound")
    scene.boss_actor.global_position.x = max_x + 500
    scene.boss_actor._clamp_movement_bounds()
    _assert(is_equal_approx(scene.boss_actor.global_position.x, max_x), config_id + " boss clamps at right bound")
    scene._debug_kill_boss()
    await process_frame
    _assert(scene.demo_complete and scene.post_boss_route_open, config_id + " boss death opens the exit route")
    _assert(scene.get_node_or_null(blocker_id) == null, config_id + " boss death removes the prefixed legacy wall")
    _assert(is_instance_valid(floor_body) and not floor_body.is_queued_for_deletion() and _floor_has_collision(floor_body), config_id + " boss floor survives route opening")
    _assert(scene.boss_arena_lock_body == null, config_id + " boss death releases the arena lock")
    await _validate_deliveries(scene, config_id)

    for interactive in config.get("interactives", []):
        if String(interactive.get("kind", "")) in ["chapter_exit", "ending_exit"]:
            var exit_area: Area2D = scene.get_node_or_null(String(interactive.get("id", "")))
            _assert(scene._chapter_exit_can_open(exit_area), config_id + " configured exit is usable after boss death")
            if String(interactive.get("kind", "")) == "chapter_exit":
                await _validate_transition(scene, String(interactive.get("next_config_path", "")))
                return
    scene.queue_free()
    await process_frame


func _validate_close_interactions(scene: Node, save_id: String, npc_id: String) -> void:
    var save: Area2D = scene.get_node(save_id)
    var npc: Area2D = scene.get_node(npc_id)
    var dialogue_index := int(npc.get_meta("dialogue_index", 0))
    scene.player.global_position = npc.global_position
    scene.nearby_interactable = save
    scene._try_interact()
    _assert(scene.dialogue_panel.visible and int(npc.get_meta("dialogue_index", 0)) == dialogue_index + 1, npc_id + " dialogue wins over the cached nearby shrine")
    scene.nearby_interactable = save
    scene._try_interact()
    _assert(scene.ui_shell.dialogue_area == npc and int(npc.get_meta("dialogue_index", 0)) == dialogue_index + 2, npc_id + " F continues the visible speaker despite a cached shrine")
    scene.player.global_position = Vector2(100000, 100000)
    scene.nearby_interactable = npc
    scene._try_interact()
    _assert(not scene.dialogue_panel.visible, npc_id + " cannot be activated from a stale target outside interaction range")
    _assert(scene.active_overlay.is_empty() and scene.nearby_interactable == null, npc_id + " moving outside range closes dialogue and clears the target")
    scene.player.global_position = save.global_position
    scene.nearby_interactable = npc
    scene.player.hp = 1
    scene._try_interact()
    _assert(scene.active_save_point_id == save_id and scene.player.hp == scene.player.max_hp, save_id + " remains usable next to its NPC")
    scene._close_overlays()
    var removed_speaker := Area2D.new()
    removed_speaker.set_meta("npc_id", String(npc.get_meta("npc_id", "")))
    scene.add_child(removed_speaker)
    scene._show_dialogue(removed_speaker, "freed speaker regression")
    removed_speaker.queue_free()
    await process_frame
    scene.player.global_position = Vector2(100000, 100000)
    scene._try_interact()
    _assert(scene.active_overlay.is_empty() and scene.nearby_interactable == null, npc_id + " freeing the visible speaker safely closes dialogue")


func _validate_transition(scene: Node, next_path: String) -> void:
    scene._add_inventory_item("echo_hook", 1, false)
    scene.story_flags["route_regression_carried"] = true
    var expected_currency := int(scene.currency_count)
    scene._transition_to_next_chapter(next_path)
    var next_scene: Node = null
    for child in root.get_children():
        if child.has_method("get_demo_state") and String(child.get("config_path")) == next_path:
            next_scene = child
            break
    _assert(next_scene != null, next_path + " campaign transition creates a scene")
    if next_scene != null:
        next_scene.set_process(false)
        next_scene.player.set_physics_process(false)
        var next_config: Dictionary = next_scene.config
        var entry: Array = next_config.get("entry_from_previous", {}).get("position", next_config.get("player_start", []))
        var expected := Vector2(float(entry[0]), float(entry[1]))
        _assert(next_scene.active_spawn.is_equal_approx(expected), next_path + " transition sets the authored respawn point")
        _assert(next_scene.player.spawn_position.is_equal_approx(expected), next_path + " player respawn uses the campaign entry")
        _assert(int(next_scene.inventory_counts.get("echo_hook", 0)) == 1, next_path + " carries acquired abilities without duplicates")
        _assert(int(next_scene.currency_count) == expected_currency, next_path + " carries currency")
        _assert(bool(next_scene.story_flags.get("route_regression_carried", false)), next_path + " carries story flags")
        next_scene.queue_free()
    await process_frame


func _platform_rect(config: Dictionary, platform_id: String) -> Rect2:
    for platform in config.get("platforms", []):
        if String(platform.get("id", "")) == platform_id:
            var r: Array = platform.get("rect", [])
            return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
    return Rect2()


func _has_landing(config: Dictionary, point: Array, player: Node) -> bool:
    if point.size() < 2:
        return false
    var max_jump_height := pow(absf(float(player.jump_velocity)), 2) / (2.0 * float(player.gravity))
    for platform in config.get("platforms", []):
        var rect: Array = platform.get("rect", [])
        var drop := float(rect[1]) - float(point[1])
        if float(rect[0]) <= float(point[0]) and float(point[0]) <= float(rect[0]) + float(rect[2]) and float(rect[3]) <= 90 and drop >= 0 and drop <= max_jump_height:
            return true
    return false


func _assert(condition: bool, label: String) -> void:
    checks += 1
    if condition:
        print("PASS: " + label)
    else:
        push_error("FAIL: " + label)
        failures += 1

func _floor_body(scene: Node, platform_id: String) -> Node:
    for platform in scene.config.get("platforms", []):
        if String(platform.get("id", "")) == platform_id:
            var terrain_id := String(platform.get("terrain_id", ""))
            if not terrain_id.is_empty() and scene.chapter_terrain != null:
                return scene.chapter_terrain.get_node_or_null(terrain_id)
    return scene.get_node_or_null(platform_id)


func _floor_has_collision(body: Node) -> bool:
    if body == null:
        return false
    for child in body.get_children():
        if child is CollisionPolygon2D and not child.disabled and child.polygon.size() >= 3:
            return true
        if child is CollisionShape2D and not child.disabled and child.shape != null:
            return true
    return false


func _validate_one_way_anchors(scene: Node, config_id: String) -> void:
    for platform in scene.config.get("platforms", []):
        if String(platform.get("collision_role", "")) != "one_way" or String(platform.get("terrain_id", "")).is_empty():
            continue
        var body := _floor_body(scene, String(platform.get("id", "")))
        var rect: Array = platform.get("rect", [])
        var point := Vector2(float(rect[0]) + float(rect[2]) * 0.5, float(rect[1]) + 1.0)
        var preserved := false
        if body != null:
            for child in body.get_children():
                if child is CollisionPolygon2D and child.one_way_collision and Geometry2D.is_point_in_polygon(point, child.polygon):
                    preserved = true
        _assert(preserved, config_id + " converted terrain preserves one-way anchor " + String(platform.get("id", "")))


func _validate_manual_pickup(scene: Node, config_id: String) -> void:
    var pickup: Area2D = null
    for child in scene.get_children():
        if child is Area2D and bool(child.get_meta("manual_pickup", false)):
            pickup = child
            break
    _assert(pickup != null, config_id + " has a manual story pickup")
    if pickup == null:
        return
    var item_id := String(pickup.get_meta("item_id", ""))
    var before := int(scene.inventory_counts.get(item_id, 0))
    scene.player.global_position = pickup.global_position
    scene._try_interact()
    var expected := before + int(pickup.get_meta("amount", 1))
    _assert(int(scene.inventory_counts.get(item_id, 0)) == expected and pickup.is_queued_for_deletion(), config_id + " F collects the actual story pickup")
    scene._on_collectible_body_entered(scene.player, pickup)
    _assert(int(scene.inventory_counts.get(item_id, 0)) == expected, config_id + " same-frame body event cannot duplicate a manual pickup")
    await process_frame


func _validate_deliveries(scene: Node, config_id: String) -> void:
    for npc_data in scene.config.get("npcs", []):
        var quest: Dictionary = npc_data.get("dialogue_topics", {}).get("quest", {})
        if quest.is_empty():
            continue
        var item_id := String(quest.get("item", ""))
        if int(scene.inventory_counts.get(item_id, 0)) <= 0:
            var pickup: Area2D = null
            for collectible in scene.config.get("collectibles", []):
                if String(collectible.get("item_id", "")) == item_id:
                    pickup = scene.get_node_or_null(String(collectible.get("id", "")))
                    break
            _assert(pickup != null, config_id + " quest has an obtainable pickup for " + item_id)
            if pickup == null:
                continue
            scene._close_overlays()
            scene.player.global_position = pickup.global_position
            if bool(pickup.get_meta("manual_pickup", false)):
                scene._try_interact()
            else:
                scene._on_collectible_body_entered(scene.player, pickup)
            await process_frame
        var npc: Area2D = scene.get_node_or_null(String(npc_data.get("id", "")))
        var reward := String(quest.get("reward", ""))
        var reward_before := int(scene.inventory_counts.get(reward, 0))
        scene._close_overlays()
        scene.player.global_position = npc.global_position
        scene._try_interact()
        scene.ui_shell._topic("wish")
        _assert(bool(scene.story_flags.get(String(quest.get("complete_flag", "")), false)), config_id + " actual item completes " + String(npc.name) + " delivery")
        if not reward.is_empty():
            _assert(int(scene.inventory_counts.get(reward, 0)) == reward_before + 1, config_id + " delivery grants its reward once")
            scene.ui_shell._topic("wish")
            _assert(int(scene.inventory_counts.get(reward, 0)) == reward_before + 1, config_id + " repeated wish cannot duplicate the reward")
        if reward == "heart_knot":
            _assert(String(scene._item_data(reward).get("category", "")) == "Upgrades" and not scene.inventory_materials.has(reward), "heart knot delivery reward stays in the upgrade category")
        scene._close_overlays()
