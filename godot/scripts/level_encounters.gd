extends RefCounted
## Enemy deaths and elite rewards, resetting encounters after the player dies, and opening the route after a boss.
## Moved out of main_level.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.
const VISUAL_POLICY := preload("res://scripts/combat_visual_policy.gd")

static func on_enemy_died(level: Node, spawn_id: String, is_boss: bool, kind: String) -> void:
    # Defeat is a production encounter, unlike offscreen residency/prewarming.
    # The existing final save persists this flag with rewards, no extra write.
    if level.world_mode:
        var journal_flag := preload("res://scripts/enemy_journal.gd").flag_for(kind)
        if not journal_flag.is_empty():level.story_flags[journal_flag]=true
    if is_boss:
        if level.demo_complete:
            return
        var boss_data: Dictionary = level.config.get("boss", {})
        var boss_name: String = level._boss_display_name(boss_data)
        var reward_item := String(boss_data.get("reward_item", "crown_splinter"))
        level.demo_complete = true
        level._set_story_flag("boss_down_%s" % level._chapter_story_id())
        level._set_boss_arena_locked(false)
        # Boss 战收尾：停 Boss 曲、恢复本章探索循环。
        if level.audio_director != null:
            level.audio_director.stop_boss_music()
        level.win_label.text = String(level.config.get("completion_message", "DEMO COMPLETE: " + boss_name + " defeated"))
        level.win_label.visible = true
        level._add_currency(30)
        level._add_inventory_item(reward_item, 1, false)
        level._announce_lore_pickup(reward_item)
        if level.metsys_bridge != null and level.boss_actor != null:
            if not level.boss_actor.has_meta("object_id"):
                level.boss_actor.set_meta("object_id", "boss/" + spawn_id)
                var boss_room: Dictionary = level._room_for_position(level.boss_actor.global_position)
                level.metsys_bridge.register_object(level.boss_actor, String(level.boss_actor.get_meta("object_id")), String(boss_room.get("id", "boss_chamber")))
            level.metsys_bridge.store_object(level.boss_actor)
        if level.player != null:
            level.player.gain_energy(30)
        level._open_post_boss_route()
        level._spawn_ending_gates(true)
        level._toast(String(level.config.get("completion_toast", "Demo complete: " + boss_name + " defeated.")))
        var transition: Dictionary = level.config.get("chapter_transition", {})
        if not transition.is_empty():
            level._toast("前往下一片土地 · " + String(transition.get("entry_hint", level._next_campaign_chapter_name())))
    else:
        var drop_item := String(level.config.get("enemy_drop_item", "moss_chitin"))
        var challenge_spawn: bool = level._is_optional_challenge_spawn(spawn_id)
        # Challenge foes pay only through the one-time clear reward: they are not
        # in the region's combat-clear tally, and a failed attempt cannot be farmed
        # for currency, materials, or energy (ring the bell, kill one, leave).
        if not challenge_spawn:
            level.enemy_defeated += 1
            level._add_currency(8)
            level._add_inventory_item(drop_item, 1, false)
            if level.player != null:
                level.player.gain_energy(20)
        level._toast("试炼之敌倒下" if challenge_spawn else "拾得碎钱与材料 · 绯线回充")
        var elite_message = "" if challenge_spawn else level._grant_elite_first_defeat(spawn_id, drop_item)
        if challenge_spawn:
            level._on_challenge_enemy_died(spawn_id)
        elif level._combat_progression_enabled() and level._combat_goal_met():
            level._open_combat_clear_route()
            level._play_sfx("door_open", -9.0)
            # One toast label: keep the elite reward visible alongside the clear.
            level._toast("本区敌群已清 · 钟门道路开启" + ("" if elite_message.is_empty() else " " + elite_message))
    level._refresh_hud()
    level._save_world()


static func spawn_is_elite(level: Node, spawn_id: String) -> bool:
    for spawn in level.config.get("enemy_spawns", []):
        if spawn is Dictionary and String(spawn.get("id", "")) == spawn_id:
            return bool(spawn.get("elite", false))
    return false


static func grant_elite_first_defeat(level: Node, spawn_id: String, drop_item: String) -> String:
    if not level.world_mode or not level._spawn_is_elite(spawn_id):
        return ""
    var flag = "elite_first_%s_%s" % [String(level.config.get("id", "")), spawn_id]
    if bool(level.story_flags.get(flag, false)):
        return ""
    level.story_flags[flag] = true
    level._add_currency(level.ELITE_FIRST_CURRENCY)
    level._add_inventory_item(drop_item, level.ELITE_FIRST_MATERIALS, false)
    var message = "精英首胜：额外 %d 枚碎钱与 %d 份材料。" % [level.ELITE_FIRST_CURRENCY, level.ELITE_FIRST_MATERIALS]
    level._toast(message)
    return message


static func on_player_respawned(level: Node) -> void:
    if level.world_platforms != null and is_instance_valid(level.player):
        level.world_platforms.warm(level, level.player.global_position)
    if is_instance_valid(level.cave_world) and is_instance_valid(level.player):
        level.cave_world.warm_collision_focus(level.player.global_position)
    if level.chapter_terrain != null:
        level.chapter_terrain.warm_focus(level.player.global_position)
    level.death_recorded = false
    level._reset_encounters_after_player_death()
    # Respawn first removes the old Boss event lock. Recompute the visible
    # center after that release, before the next rendered frame.
    level.player.reset_camera_after_arrival()
    level._save_world()


static func reset_encounters_after_player_death(level: Node) -> void:
    if level.demo_complete and not level.world_mode:
        level._refresh_hud()
        return
    level._set_boss_arena_locked(false)
    level._clear_active_challenge(false)
    if level.world_gameplay_residency != null:
        level.world_gameplay_residency.clear_enemy_actors()
    for enemy_node in level.get_tree().get_nodes_in_group("enemy"):
        var enemy_area := enemy_node as Area2D
        if enemy_area == null or not is_instance_valid(enemy_area):
            continue
        # Practice racks and puppets are built once per region and never respawn.
        if enemy_area.has_meta("seal_training_target") or enemy_area.has_meta("tool_training_target"):
            continue
        if enemy_area.has_method("_cancel_attack_effects"):
            enemy_area._cancel_attack_effects()
        enemy_area.queue_free()
    level.boss_actor = null
    level.boss_spawned = false
    level.enemy_defeated = 0
    if level.boss_trial_mode:
        level._open_all_shortcuts(false)
        level.pending_enemy_respawn = false
        if level.player != null and is_instance_valid(level.player):
            level.player.global_position = level.active_spawn
            if level.player.has_method("restore_at_save_point"):
                level.player.restore_at_save_point()
            if level.player.has_method("reset_camera_after_arrival"):
                level.player.reset_camera_after_arrival()
        level._defer_region_call("_respawn_boss_trial_boss")
        level._toast("试炼重置 · 守门者已经归位。")
    else:
        level.pending_enemy_respawn = true
        # 死亡重置：停 Boss 曲回到本章探索循环（director 缺席回退旧 ch01 单曲）。
        if level.audio_director != null:
            level.audio_director.stop_boss_music()
        else:
            level._switch_bgm("bgm_ch01")
        level._toast("重新开始 · 敌群已归位")
    level._refresh_hud()


static func respawn_boss_trial_boss(level: Node) -> void:
    if level.demo_complete or not level.boss_trial_mode:
        return
    level._spawn_boss()


static func open_post_boss_route(level: Node) -> void:
    if level.post_boss_route_open:
        return
    level.post_boss_route_open = true
    for platform in level.config.get("platforms", []):
        if not (platform is Dictionary):
            continue
        var platform_data: Dictionary = platform
        var platform_id := String(platform_data.get("id", ""))
        if not level._is_post_boss_blocker(platform_id):
            continue
        var blocker = level.get_node_or_null(platform_id)
        if blocker != null:
            level._spawn_route_open_effect(blocker.global_position)
            blocker.queue_free()


static func is_post_boss_blocker(level: Node, platform_id: String) -> bool:
    var lowered := platform_id.to_lower()
    return lowered == "boss_back_wall" or lowered.ends_with("_boss_back_wall") or lowered.contains("post_boss_wall") or lowered.contains("chapter_exit_wall")


static func spawn_route_open_effect(level: Node, position_value: Vector2) -> void:
    for index in range(3):
        var ring := Line2D.new()
        ring.name = "PostBossRouteOpenRing"
        ring.closed = true
        ring.width = 3.0
        ring.default_color = Color(0.44, 1.0, 0.86, 0.72)
        ring.points = PackedVector2Array([
            Vector2(-34, -46),
            Vector2(34, -46),
            Vector2(54, 0),
            Vector2(34, 46),
            Vector2(-34, 46),
            Vector2(-54, 0)
        ])
        ring.position = position_value
        ring.z_index = 12
        if not VISUAL_POLICY.attach_secondary(level, ring, &"environment", level): continue
        var tween: Tween = level._region_tween()
        tween.tween_interval(float(index) * 0.08)
        tween.tween_property(ring, "scale", Vector2(1.65, 1.65), 0.42)
        tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.42)
        tween.tween_callback(ring.queue_free)
