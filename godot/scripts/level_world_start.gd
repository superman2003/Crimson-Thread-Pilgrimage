extends RefCounted
## Starting or resuming the world: the start route and options, restoring inventory, player, routes and discovery, saving, and the first-journey hints.
## Moved out of main_level.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.
const CARTOGRAPHY := preload("res://scripts/pilgrimage_cartography.gd")
const WORLD_COORDINATES := preload("res://scripts/world_coordinates.gd")
const WORLD_PASSAGE := preload("res://scripts/world_passage.gd")
const WORLD_ROUTES_SCRIPT := preload("res://scripts/world_routes.gd")
const WORLD_STATE_SCRIPT := preload("res://scripts/world_state.gd")

static func prepare_world_start(level: Node) -> void:
    if not level.world_mode:
        return
    var startup_args := OS.get_cmdline_args()
    startup_args.append_array(OS.get_cmdline_user_args())
    var new_game_requested: bool = level._consume_world_startup_options(startup_args)
    if level.world_state == null:
        level.world_state = WORLD_STATE_SCRIPT.new()
        if new_game_requested:
            if level._preserve_previous_journey():
                level.world_resume = false
            else:
                level.world_resume = true
                level.world_initial_error = "旧旅途无法安全备份，未开始新旅途，原记录已保留。"
        if level.world_resume and level.world_state.read(level.world_save_path):
            level.world_resumed_journey = true
            level.world_start_region_id = String(level.world_state.data.current_region)
            level.entry_spawn_override_enabled = true
            level.entry_spawn_override = level.world_state.resume_local_position()
        elif level.world_resume and level.world_state.last_error != "missing":
            level.world_initial_error = level._damaged_save_message()
        # A journey that could not be read keeps its recorded time untouched.
        level.journey_clock = preload("res://scripts/journey_progress.gd").new()
        level.journey_clock.attach(level.world_save_path, level.world_resume)


static func damaged_save_message(level: Node) -> String:
    var backup = WORLD_STATE_SCRIPT.new()
    if backup.read(level.world_save_path + ".bak"):
        return "归途记录损坏，原文件已保留，本次进度不会写入。找到可用备份（%d 区 · %d 碎钱）：在设置里选“恢复当前槽备份”即可接着走。" % [backup.data.regions.size(), int(backup.data.currency)]
    return "归途记录损坏，备份也无法读取；原文件已保留，本次进度不会写入。"


static func resolve_world_start_route(level: Node) -> bool:
    if level.world_start_region_id.is_empty():
        return true
    var saved_path = WORLD_ROUTES_SCRIPT.cached_config_path(level.world_start_region_id)
    if saved_path.is_empty():
        # T02: a save naming a region this version no longer routes keeps all
        # of its progress and resumes at the route start instead of failing.
        level.world_start_region_id = ""
        level.entry_spawn_override_enabled = false
        level.world_initial_error = "存档所在的区域不在当前巡礼路线中；进度全部保留，从巡礼起点继续。"
        return true
    level.config_path = saved_path
    return true


static func consume_world_startup_options(level: Node, arguments: PackedStringArray) -> bool:
    if not level.world_startup_options_enabled:
        return false
    level.world_startup_options_enabled = false
    for argument in arguments:
        if argument.begins_with("--save-slot="):
            level.world_slot = clampi(int(argument.trim_prefix("--save-slot=")), 1, 3)
            level.world_save_path = WORLD_STATE_SCRIPT.slot_path(level.world_slot)
    return arguments.has("--new-game")


static func restore_world_inventory_and_region(level: Node) -> void:
    var snapshot: Dictionary = level.world_state.data
    level.story_flags = snapshot.story_flags.duplicate(true)
    for item_id in snapshot.inventory_counts:
        var missing := int(snapshot.inventory_counts[item_id]) - int(level.inventory_counts.get(item_id, 0))
        if missing > 0:
            level._add_inventory_item(String(item_id), missing, false)
    level.currency_count = int(snapshot.currency)
    level.story_flags = snapshot.story_flags.duplicate(true)
    if level.world_narrative != null:
        level.story_flags = level.world_narrative.restored_ending_flags(level.story_flags)
    CARTOGRAPHY.migrate(level.story_flags, snapshot.regions)
    CARTOGRAPHY.legacy_quill(level.story_flags)
    var cache: Dictionary = snapshot.get("death_cache", {})
    if not cache.is_empty() and WORLD_ROUTES_SCRIPT.cached_config_path(String(cache.get("region_id", ""))).is_empty():
        # T02: an 归途结 left in a region this version no longer has could never be reached.
        level.currency_count += int(cache.get("currency", 0))
        level.world_state.capture_global({"death_cache": {}, "currency": level.currency_count})
    var region = level.world_state.get_region(String(level.config.get("id", "")))
    level.world_collected_ids = region.collected_ids.duplicate(true)
    level.opened_shortcuts = region.opened_shortcuts.duplicate(true)
    level.visited_rooms = region.visited_rooms.duplicate(true)
    level.bell_count = int(region.bell_count)
    level.shortcut_open = bool(region.shortcut_open)
    level.boss_unlocked = bool(region.boss_unlocked)
    level.demo_complete = bool(region.boss_defeated)
    if not String(region.checkpoint_id).is_empty():
        level.active_spawn = level._vec2(region.checkpoint)
        level.active_save_point_id = String(region.checkpoint_id)


static func world_runtime_jobs(level: Node) -> Array:
    return [{"method": "_restore_world_player", "args": []},
        {"method": "_warm_arrival_cave", "args": []},
        {"method": "_warm_arrival_terrain", "args": []},
        {"method": "_warm_arrival_platforms", "args": []},
        {"method": "_restore_world_routes", "args": []},
        {"method": "_restore_world_discovery", "args": []}]


static func restore_world_player(level: Node) -> void:
    if level.entry_spawn_override_enabled:
        level.player.global_position = level.entry_spawn_override
        level.player.arrival_guard_timer = 1.2
    level.player.set_spawn(level.active_spawn)
    level.player.hp = clampi(int(level.world_state.data.hp), 1, level.player.max_hp)
    level.player.energy = clampi(int(level.world_state.data.energy), 0, level.player.max_energy)
    if level.world_gameplay_residency != null:
        level.world_gameplay_residency.warm_arrival(level, level.player.global_position)


static func warm_arrival_cave(level: Node) -> void:
    if is_instance_valid(level.cave_world):
        level.cave_world.warm_collision_focus(level.player.global_position)


static func warm_arrival_terrain(level: Node) -> void:
    if is_instance_valid(level.chapter_terrain):
        level.chapter_terrain.warm_collision_focus(level.player.global_position)


static func warm_arrival_platforms(level: Node) -> void:
    if level.world_platforms != null:
        level.world_platforms.warm(level, level.player.global_position)


static func restore_world_routes(level: Node) -> void:
    if level.shortcut_open or level.boss_unlocked:
        level._unlock_boss_route()
    if level.demo_complete:
        level._open_post_boss_route()


static func restore_world_discovery(level: Node) -> void:
    level._sync_hidden_route_clues_with_visits()
    # Reconstruct discovered cells after MetSys builds this region's map.
    if level.metsys_bridge != null:
        for room_id in level.visited_rooms:
            if bool(level.visited_rooms[room_id]):
                level.metsys_bridge.discover_room(String(room_id))


static func player_world_position(level: Node) -> Vector2:
    if level.player == null or not level.world_mode:
        return Vector2.INF
    if is_instance_valid(level.world_passage) and level.world_passage.active:
        return level.world_passage.terminal_world_point if level.world_passage.settling else WORLD_COORDINATES.to_world(level.world_passage.source_id, level.player.global_position)
    return WORLD_COORDINATES.to_world(String(level.config.get("id", "")), level.player.global_position)


static func prepare_world_checkpoint(level: Node, global_snapshot: Dictionary, region_patch: Dictionary={}) -> Dictionary:
    var region_id:=String(level.config.get("id",""))
    var region_snapshot: Dictionary={"collected_ids":level.world_collected_ids,"opened_shortcuts":level.opened_shortcuts,
        "visited_rooms":level.visited_rooms,"boss_defeated":level.demo_complete,"boss_unlocked":level.boss_unlocked,
        "shortcut_open":level.shortcut_open,"bell_count":level.bell_count,"checkpoint":level.active_spawn,"checkpoint_id":level.active_save_point_id}
    region_snapshot.merge(region_patch,true)
    return level.world_state.prepare_checkpoint(region_id,region_snapshot,global_snapshot)


static func persist_world_change(level: Node, patch: Dictionary, region_patch: Dictionary={}) -> Dictionary:
    var failure := {"ok":false,"reason":"归途记录尚未写入，请重试。"}
    if not level.world_mode or level.world_loading or level.world_state==null or level.player==null:return failure
    var snapshot: Dictionary={"inventory_counts":level.inventory_counts,"currency":level.currency_count,"story_flags":level.story_flags,
        "current_region":String(level.config.get("id","")),"entry":level.active_spawn,"hp":level.player.hp,
        "energy":maxi(0,level.player.energy-level.player.practice_energy),"build_state":level.build_system.serialize() if level.build_system!=null else {}}
    snapshot.merge(patch,true)
    var prepared: Dictionary = level._prepare_world_checkpoint(snapshot,region_patch)
    if not prepared.ok:return failure
    failure["candidate"]=prepared.candidate
    if level.world_save_blocked or level.world_save_failure_injected_for_validation or not level.world_state.write_candidate(prepared.candidate,level.world_save_path):return failure
    return {"ok":true,"candidate":prepared.candidate}


static func save_world(level: Node) -> bool:
    level.world_save_capture_ok = false
    if not level.world_mode:
        return true
    if level.world_loading or level.world_state == null or level.player == null:
        return false
    var prepared = level._prepare_world_checkpoint({
        "inventory_counts": level.inventory_counts, "currency": level.currency_count,
        "story_flags": level.story_flags, "current_region": String(level.config.get("id", "")),
        "entry": level.active_spawn, "hp": level.player.hp, "energy": maxi(0, level.player.energy - int(level.player.get("practice_energy") if level.player.get("practice_energy") != null else 0)),
        "build_state": level.build_system.serialize() if level.build_system != null else {}})
    if not prepared.ok:
        if not level.world_write_error_shown:
            level.world_write_error_shown = true
            level._toast("归途记录暂未写入，当前旅途进度仍保留。")
        return false
    level.world_save_capture_ok = true
    var candidate: Dictionary = prepared.candidate
    # A blocked incompatible save still carries the live region/global snapshot
    # in memory for world travel, while withholding all disk writes.
    if level.world_save_blocked:
        level.world_state.data = candidate
        if not level.world_write_error_shown:
            level.world_write_error_shown = true
            level._toast("归途记录暂未写入，当前旅途进度仍保留。")
        return false
    if level.world_save_failure_injected_for_validation or not level.world_state.write_candidate(candidate, level.world_save_path):
        if not level.world_write_error_shown:
            level.world_write_error_shown = true
            level._toast("归途记录暂未写入，当前旅途进度仍保留。")
        return false
    level.world_state.data = candidate # transfer the fully persisted, privately owned tree.
    if level.journey_clock != null:
        level.journey_clock.flush()
    if level.achievements == null:
        level.achievements = preload("res://scripts/achievements.gd").new()
    preload("res://scripts/achievement_notice.gd").show_on(level, level.achievements.sync(candidate, int(Time.get_unix_time_from_system())))
    return true


static func first_interaction_type(level: Node, area: Area2D) -> String:
    var kind := String(area.get_meta("kind", ""))
    if kind == "npc":
        return "map_shop" if area.has_meta("map_seller_region") else "talk"
    if kind == "world_portal":
        return "walk_passage" if not WORLD_PASSAGE.endpoint(String(level.config.id), String(area.name)).is_empty() else "portal"
    return kind


static func show_first_interaction_hint(level: Node, area: Area2D) -> void:
    var kind: String = level._first_interaction_type(area)
    var flag = "tutorial_interaction_seen_" + kind
    if bool(level.story_flags.get(flag, false)):
        return
    var key: String = level.ui_shell._short_binding("interact") if is_instance_valid(level.ui_shell) else "F"
    var hints := {
        "save_point": "按 %s 休息，恢复状态并记录归途。" % key,
        "talk": "按 %s 与人物交谈。" % key,
        "map_shop": "按 %s 交谈，购买本区地图。" % key,
        "lever": "按 %s 操作机关。" % key,
        "portal": "按 %s 通过旧通路。" % key,
        "walk_passage": "沿路牌箭头步行进入通道，可沿来路折返。",
        "boss_gate": "按 %s 开启钟门。" % key,
        "ending_gate": "按 %s 查看归途的选择。" % key,
        "death_cache": "按 %s 取回遗落物资。" % key}
    if not hints.has(kind):
        return
    level.story_flags[flag] = true
    level._toast(String(hints[kind]))
    level._save_world()


static func update_first_journey_hint(level: Node) -> void:
    if not bool(level.config.get("first_journey_teaching", false)) or level.world_loading or not level.active_overlay.is_empty() or not is_instance_valid(level.ui_shell):
        return
    if not level.player.is_on_floor() or not level.player._can_start_action() or level.player.land_timer > 0.0 or level.ui_shell.toast_age < 5.5:
        return
    var lesson := ""
    var text := ""
    if level.current_room_id == "entry_bell" and level.player.global_position.x < 340 and not bool(level.story_flags.get("tutorial_action_seen_move", false)):
        lesson = "move"
        text = "用 %s / %s 移动，沿苔灯走向断阶。" % [level.ui_shell._short_binding("move_left"), level.ui_shell._short_binding("move_right")]
    elif level.current_room_id == "entry_bell" and level.player.global_position.x >= 340 and not bool(level.story_flags.get("tutorial_action_seen_jump", false)):
        lesson = "jump"
        text = "按 %s 跳跃；提前松开可跳得更低。" % level.ui_shell._short_binding("jump")
    elif level.current_room_id == "moss_descent" and not bool(level.story_flags.get("tutorial_action_seen_attack", false)):
        lesson = "attack"
        text = "按 %s 挥刃，命中敌人可回充绯线。" % level.ui_shell._short_binding("attack")
    elif level.player.hp < level.player.max_hp and level.player.energy >= level.player.heal_energy_cost and absf(level.player._move_axis()) < 0.1 and not bool(level.story_flags.get("tutorial_action_seen_heal", false)):
        if not level._first_journey_heal_safe():
            return
        lesson = "heal"
        text = "站稳后按 %s 缝补；移动或受击会打断。" % level.ui_shell._short_binding("heal")
    elif level.current_room_id == "court_hub" and level.player.hp == level.player.max_hp and not bool(level.story_flags.get("tutorial_action_seen_thread", false)):
        if not level._first_journey_heal_safe():
            return
        lesson = "thread"
        text = "挥刃命中会回充绯线；留一些给缝补和战技。"
    elif level.player.dash_unlocked and level.current_room_id in ["threadmakers_cache", "bell_gap_crossing"] and not bool(level.story_flags.get("tutorial_action_seen_dash", false)):
        lesson = "dash"
        text = "按 %s 冲刺越过缺口；空中也能使用。" % level.ui_shell._short_binding("dash")
    elif level.current_room_id in ["first_bell_shrine", "maze_respite", "pre_boss_shrine"] and level.player.hp == level.player.max_hp and level.build_system != null and not bool(level.story_flags.get("tutorial_action_seen_tool", false)):
        var tool_id := String(level.build_system.state.get("tool", ""))
        if tool_id.is_empty() or int(level.build_system.state.get("tool_counts", {}).get(tool_id, 0)) <= 0 or not level._first_journey_heal_safe():
            return
        lesson = "tool"
        text = "按 %s 使用战具；在钟龛休息可补满次数。" % level.ui_shell._short_binding("tool_cast")
    if lesson.is_empty():
        return
    level.story_flags["tutorial_action_seen_" + lesson] = true
    level._toast(text)
    level._save_world()


static func first_journey_heal_safe(level: Node) -> bool:
    if is_instance_valid(level.boss_arena_lock_body):
        return false
    for enemy in level.get_tree().get_nodes_in_group("enemy"):
        if not is_instance_valid(enemy) or enemy.get_parent() != level or enemy.dying or not enemy.world_residency_active():
            continue
        var distance: Vector2 = enemy.global_position - level.player.global_position
        if absf(distance.y) < 150 and absf(distance.x) < 320:
            return false
    return true
