extends RefCounted
## Activating levers and shortcuts, save points, chapter exits and boss gates, and moving to the next chapter.
## Moved out of main_level.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func activate_lever(level: Node, area: Area2D) -> void:
    if not level._can_interact_with_world() or area == null or not is_instance_valid(area):
        return
    var shortcut_id: String = level._shortcut_id_for_area(area)
    if level._is_shortcut_open(shortcut_id):
        level._toast("这条捷径已经接通。")
        return
    if level._combat_progression_enabled() and not level._shortcut_is_lever_controlled(shortcut_id):
        if not level._combat_goal_met():
            level._toast("先清除附近敌群")
            return
        level._open_shortcut(shortcut_id)
        level._play_sfx("lever")
        level._play_sfx("lever_latch", -10.0)
        return
    var required_keys := int(area.get_meta("requires_keys", level.max_bells))
    if level.bell_count < required_keys:
        level._toast("捷径需要 %d 枚路标 · 现有 %d" % [required_keys, level.bell_count])
        return
    level._open_shortcut(shortcut_id)
    level._play_sfx("lever")
    # 拉杆金属锁舌质感层（Kenney RPG Audio，与 Bread Adventure lever.ogg 叠放）。
    level._play_sfx("lever_latch", -10.0)
    if level.metsys_bridge != null:
        level.metsys_bridge.store_object(area)


static func open_shortcut(level: Node, shortcut_id: String = "") -> void:
    if shortcut_id.is_empty():
        var ids: Array = level._shortcut_ids()
        if not ids.is_empty():
            shortcut_id = String(ids[0])
    if not shortcut_id.is_empty():
        level.opened_shortcuts[shortcut_id] = true
    for child in level.get_children():
        if child is Area2D and String(child.get_meta("kind",""))=="lever" and level._shortcut_id_for_area(child)==shortcut_id:
            var sprite := child.get_node_or_null("LeverSprite") as Sprite2D
            if sprite!=null:level._apply_original_prop(sprite,"lever_open",52)
    level.shortcut_open = true
    if bool(level.config.get("boss_route_via_exploration", false)) or not level._combat_progression_enabled() or level._combat_goal_met():
        level._unlock_boss_route()
    # 捷径门接通（音频规格 §4.5 ui_door_open）："绕回来了"的木门吱呀。
    level._play_sfx("door_open", -9.0)
    var progress = "%d/%d" % [level._opened_shortcut_total(), max(1, level._shortcut_total())]
    level._toast("捷径已通 · %s" % progress)
    level._refresh_hud()
    level._save_world()


static func open_all_shortcuts(level: Node, show_toast: bool = true) -> void:
    var ids: Array = level._shortcut_ids()
    for shortcut_id in ids:
        level.opened_shortcuts[String(shortcut_id)] = true
    level.shortcut_open = true
    level._unlock_boss_route()
    if show_toast:
        level._toast("本区捷径均已接通。")
    level._refresh_hud()


static func activate_save_point(level: Node, area: Area2D) -> void:
    if not level._can_interact_with_world() or area == null or not is_instance_valid(area):
        return
    if level.world_mode:
        level._update_room_visit()
        level.CARTOGRAPHY.rest(level.story_flags)
    level.active_spawn = area.global_position
    level.active_save_point_id = String(area.name)
    level.save_point_residency_memory[String(level.config.get("id", "")) + ":" + String(area.name)] = true
    level.player.set_spawn(level.active_spawn)
    if level.player.has_method("restore_at_save_point"):
        level.player.restore_at_save_point()
    # 钟龛安坐（音频规格 §4.5 env_shrine_wrap/env_shrine_rest）：
    # 缠线窸窣 + 龛铃"龛中眠"动机（D-A-B），六区各自音色滤波变体。
    level._play_sfx("shrine_wrap", -9.0)
    level._play_sfx(level._shrine_rest_audio_key(), -6.0)
    # 钟龛摇篮曲（规格 §2.1）：安坐记锚点切摇篮曲；走远收场由 director 距离机自驱。
    if level.audio_director != null:
        level.audio_director.engage_shrine(area.global_position)
    level._play_save_point_activation(area)
    if level.metsys_bridge != null:
        level.metsys_bridge.store_object(area)
    level._save_world()
    var rest_message := "安坐钟龛 · 已记下归途，恢复生命与绯线。"
    if level.world_mode and not level.CARTOGRAPHY.has_quill(level.story_flags) and level.CARTOGRAPHY.pending_count(level.story_flags) > 0:
        rest_message += "途中笔记已记下；要有盐墨绘针才能补绘进地图（地图商人有售）。"
    level._toast(rest_message)
    level._refresh_hud()
    level.DEATH_RECALL.offer(level)


static func activate_chapter_exit(level: Node, area: Area2D) -> void:
    if not level._can_interact_with_world() or area == null or not is_instance_valid(area):
        return
    if not level._chapter_exit_can_open(area):
        level._toast("需先击败守门者")
        return
    var kind := String(area.get_meta("kind", "chapter_exit"))
    if kind == "ending_exit":
        level.win_label.text = String(level.config.get("ending_message", "结局之路已开：无声王冠有了回应。"))
        level.win_label.visible = true
        level._toast("最后的巡礼之路已经开启。")
        return
    var next_config_path := String(area.get_meta("next_config_path", ""))
    if next_config_path.is_empty():
        level._toast("前路尚未接通。")
        return
    level.chapter_transitioning = true
    # 章节转场：BGM 总线 0.5s 淡出（新章 set_chapter 起播再从静音 0.8s 淡入）。
    if level.audio_director != null:
        level.audio_director.begin_chapter_transition()
    # 章节切换线音（音频规格 §4.5 env_chapter_transition）：挂 root 不被换场截断。
    level._play_sfx_persistent("chapter_transition", -7.0)
    level._toast("前往下一区域。")
    level._defer_region_call("_transition_to_next_chapter", [next_config_path])


static func chapter_exit_can_open(level: Node, area: Area2D) -> bool:
    return not bool(area.get_meta("requires_demo_complete", true)) or level.demo_complete


static func transition_to_next_chapter(level: Node, next_config_path: String) -> void:
    var parent_node = level.get_parent()
    if parent_node == null:
        level.chapter_transitioning = false
        return
    if level.world_mode:
        var next_config_id := String(level._load_json(next_config_path).get("id", ""))
        var path = level.WORLD_ROUTES_SCRIPT.cached_config_path(next_config_id)
        if path.is_empty():
            if level.world_loader != null:
                level.world_loader.request_manifest_refresh(level)
            level.chapter_transitioning = false
            return
        var legacy_entry: Dictionary = level._load_json(path).get("entry_from_previous", {})
        level._travel_world(path, level._vec2(legacy_entry.get("position", level._load_json(path).get("player_start", [120,500]))))
        return
    var next_config: Dictionary = level._load_json(next_config_path)
    var entry_data: Dictionary = next_config.get("entry_from_previous", {})
    var entry_position: Vector2 = level._vec2(entry_data.get("position", next_config.get("player_start", [120, 500])))
    var entry_message := String(entry_data.get("message", "进入" + String(next_config.get("name", "下一区域")) + "。"))
    var next_scene: Node = load("res://scenes/Main.tscn").instantiate()
    next_scene.set("config_path", next_config_path)
    next_scene.set("entry_spawn_override_enabled", true)
    next_scene.set("entry_spawn_override", entry_position)
    next_scene.set("entered_from_config_id", String(level.config.get("id", "")))
    next_scene.set("transition_entry_message", entry_message)
    next_scene.set("story_flags", level.story_flags.duplicate(true))
    next_scene.set("carried_inventory_enabled", true)
    next_scene.set("carried_inventory_counts", level.inventory_counts.duplicate(true))
    next_scene.set("carried_currency", level.currency_count)
    parent_node.add_child(next_scene)
    level.queue_free()


static func activate_boss_gate(level: Node) -> void:
    if not level._can_interact_with_world():
        return
    if level.demo_complete:
        level._toast("前路已开启")
        return
    if not level.boss_unlocked:
        if level._combat_progression_enabled():
            level._toast("钟门未应 · 先接通捷径拉杆" if bool(level.config.get("boss_route_via_exploration",false)) else "钟门未应 · 先清除本区敌群")
        else:
            level._toast("钟门未应 · 先接通捷径")
        return
    level._spawn_boss()
    if level.boss_spawned and not level.demo_complete:
        level._set_boss_arena_locked(true)
