extends RefCounted
## The demo state snapshot read by validations, and the debug shortcuts.
## Moved out of main_level.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func get_demo_state(level: Node) -> Dictionary:
    var chapter_exit_total := 0
    var ending_exit_total := 0
    for interactive in level.config.get("interactives", []):
        if not (interactive is Dictionary):
            continue
        var interactive_data: Dictionary = interactive
        var interactive_kind := String(interactive_data.get("kind", ""))
        if interactive_kind == "chapter_exit":
            chapter_exit_total += 1
        elif interactive_kind == "ending_exit":
            ending_exit_total += 1
    var boss_data: Dictionary = level.config.get("boss", {})
    var boss_kind := String(boss_data.get("kind", ""))
    var boss_profile: Dictionary = level.config.get("ai_profiles", {}).get(boss_kind, {})
    var transition_state: Dictionary = level.config.get("chapter_transition", {})
    var boss_attack_types: Array = []
    for attack in boss_profile.get("attacks", []):
        if not (attack is Dictionary):
            continue
        var attack_data: Dictionary = attack
        var attack_type := String(attack_data.get("type", ""))
        if not boss_attack_types.has(attack_type):
            boss_attack_types.append(attack_type)
    var platform_materials: Array = []
    var platform_visual_asset_paths: Array = []
    for platform in level.config.get("platforms", []):
        if not (platform is Dictionary):
            continue
        var platform_data: Dictionary = platform
        var material := String(platform_data.get("material", "moss_stone"))
        if not platform_materials.has(material):
            platform_materials.append(material)
        for asset_path in level._platform_visual_asset_paths_for_material(material):
            var asset_path_string := String(asset_path)
            if not asset_path_string.is_empty() and not platform_visual_asset_paths.has(asset_path_string):
                platform_visual_asset_paths.append(asset_path_string)
    var state := {
        "config_path": level.config_path,
        "config_id": level.config.get("id", ""),
        "config_name": level.config.get("name", ""),
        "config_goal": level.config.get("goal", ""),
        "progression_mode": level.config.get("progression_mode", "keys"),
        "art_theme_id": level._art_theme_id(),
        "map_title": level._theme_map_title(),
        "visual_asset_source": level._theme_asset_source(),
        "platform_materials": platform_materials,
        "platform_visual_asset_paths": platform_visual_asset_paths,
        "background_visual_asset_paths": level._background_visual_asset_paths(),
        "world_width": level.world_width,
        "map_room_total": level.config.get("map_rooms", []).size(),
        "platform_total": level.config.get("platforms", []).size(),
        "bell_count": level.bell_count,
        "required_keys": level.max_bells,
        "shortcut_open": level.shortcut_open,
        "shortcut_total": level._shortcut_total(),
        "opened_shortcut_total": level._opened_shortcut_total(),
        "opened_shortcut_ids": level.opened_shortcuts.keys(),
        "boss_unlocked": level.boss_unlocked,
        "boss_spawned": level.boss_spawned,
        "boss_arena_locked": level.boss_arena_lock_body != null and is_instance_valid(level.boss_arena_lock_body),
        "demo_complete": level.demo_complete,
        "post_boss_route_open": level.post_boss_route_open,
        "entry_spawn_override_enabled": level.entry_spawn_override_enabled,
        "entered_from_config_id": level.entered_from_config_id,
        "transition_entry_message": level.transition_entry_message,
        "normal_enemy_total": level.enemy_total,
        "normal_enemy_defeated": level.enemy_defeated,
        "hazard_total": level.hazard_total,
        "collectible_total": level.collectible_total,
        "save_point_total": level.save_point_total,
        "hidden_save_point_total": level.hidden_save_point_total,
        "active_save_point_id": level.active_save_point_id,
        "active_spawn": [level.active_spawn.x, level.active_spawn.y],
        "ai_profile_total": level.config.get("ai_profiles", {}).size(),
        "npc_total": level.config.get("npcs", []).size(),
        "story_flag_total": level.story_flags.size(),
        "story_flags": level.story_flags.duplicate(),
        "currency_count": level.currency_count,
        "inventory_item_total": level.inventory_counts.size(),
        "unlocked_ability_total": level.unlocked_abilities.size(),
        "unlocked_ability_ids": level.unlocked_abilities.keys(),
        "locked_gate_total": level.config.get("locked_gates", []).size(),
        "locked_gate_remaining": level.locked_gate_bodies.size(),
        "visited_room_total": level.visited_rooms.size(),
        "current_room_id": level.current_room_id,
        "current_room_archetype": level._room_map_copy(level.current_room_id, "archetype", ""),
        "current_room_pacing_role": level._room_map_copy(level.current_room_id, "pacing_role", ""),
        "current_room_traversal_focus": level._room_map_copy(level.current_room_id, "traversal_focus", ""),
        "current_room_reward_contract": level._room_map_copy(level.current_room_id, "reward_contract", ""),
        "current_room_setpiece": level._room_map_copy(level.current_room_id, "setpiece", ""),
        "current_room_micro_objective": level._room_map_copy(level.current_room_id, "micro_objective", ""),
        "backpack_overlay_ready": level.backpack_panel != null,
        "map_overlay_ready": level.map_panel != null,
        "dialogue_overlay_ready": level.dialogue_panel != null,
        "guide_marker_total": level.config.get("guides", []).size(),
        "active_overlay": level.active_overlay,
        "boss_trial_mode": level.boss_trial_mode,
        "chapter_exit_total": chapter_exit_total,
        "ending_exit_total": ending_exit_total,
        "carried_inventory_enabled": level.carried_inventory_enabled,
        "ending_gate_total": level._ending_gate_entries().size(),
        "ending_gates_spawned": level.ending_gates_spawned,
        "ending_chosen": String(level.story_flags.get("ending_chosen", "")),
        "wish_total": level._wish_board_entries().size(),
        "wish_claimed_total": level._wish_claimed_total(),
        "chapter_transition_to": transition_state.get("to_runtime_config_id", ""),
        "boss_attack_total": boss_profile.get("attacks", []).size(),
        "boss_attack_types": boss_attack_types
    }
    var enemy_positions: Array = []
    for enemy_node in level.get_tree().get_nodes_in_group("enemy"):
        var enemy_area := enemy_node as Area2D
        if enemy_area == null or not is_instance_valid(enemy_area):
            continue
        if bool(enemy_area.get("is_boss")):
            continue
        var spawn_position_value: Vector2 = enemy_area.get("spawn_position")
        var leash_radius_value := float(enemy_area.get("leash_radius"))
        var spawn_half_width := float(enemy_area.get_meta("spawn_half_width", 36.0))
        var spawn_visual_height := float(enemy_area.get_meta("spawn_visual_height", 104.0))
        var query := PhysicsShapeQueryParameters2D.new()
        var shape := RectangleShape2D.new()
        # Birth clearance uses the terrain footprint retained by motion sweeps;
        # the enlarged combat hurtbox can extend beyond that footprint.
        var motion_size: Variant = enemy_area.get("motion_box_size")
        var has_motion_box: bool = motion_size is Vector2 and motion_size != Vector2.ZERO
        shape.size=motion_size if has_motion_box else enemy_area.hurtbox_size
        query.shape=shape
        # Zero is a configured offset here, rather than the combat-rect fallback.
        var clearance_offset: Vector2 = enemy_area.get("motion_box_offset") if has_motion_box else enemy_area.hurtbox_offset
        query.transform=Transform2D(0,enemy_area.global_position+clearance_offset)
        query.collision_mask=1
        query.collide_with_areas=false
        var spawn_clear = level.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()
        var ai_debug := {}
        if enemy_area.has_method("get_ai_debug_state"):
            ai_debug = enemy_area.get_ai_debug_state()
        enemy_positions.append({
            "id": String(enemy_area.get("spawn_id")),
            "kind": String(enemy_area.get("kind")),
            "position": [enemy_area.global_position.x, enemy_area.global_position.y],
            "spawn_position": [spawn_position_value.x, spawn_position_value.y],
            "leash_radius": leash_radius_value,
            "spawn_visual_height": spawn_visual_height,
            "platform_id": String(enemy_area.get_meta("platform_id","")),
            "locomotion": String(enemy_area.get("locomotion")),
            "spawn_clear": spawn_clear,
            "ai_command_total": int(ai_debug.get("ai_command_total", 0)),
            "attack_desire": float(ai_debug.get("attack_desire", 0.0)),
            "attack_desire_threshold": float(ai_debug.get("attack_desire_threshold", 0.0)),
            "last_player_command": String(ai_debug.get("last_player_command", "none")),
            "last_ai_decision": String(ai_debug.get("last_ai_decision", "none")),
            "last_attack_id": String(ai_debug.get("last_attack_id", "")),
            "reads_player_commands": bool(ai_debug.get("reads_player_commands", false)),
            "command_read_count": int(ai_debug.get("command_read_count", 0)),
            "max_attack_range": float(ai_debug.get("max_attack_range", 0.0))
        })
    state["enemy_positions"] = enemy_positions
    if level.boss_actor != null and is_instance_valid(level.boss_actor):
        var boss_body_size: Vector2 = level.boss_actor.get("body_size")
        var boss_hurtbox_size: Vector2 = level.boss_actor.get("hurtbox_size")
        state["boss_position"] = [level.boss_actor.global_position.x, level.boss_actor.global_position.y]
        state["boss_body_size"] = [boss_body_size.x, boss_body_size.y]
        state["boss_hurtbox_size"] = [boss_hurtbox_size.x, boss_hurtbox_size.y]
        state["boss_visual_scale"] = float(level.boss_actor.get("visual_scale"))
        state["boss_asset_path"] = String(level.boss_actor.get("asset_path"))
        if level.boss_actor.has_method("get_ai_debug_state"):
            var boss_ai_debug: Dictionary = level.boss_actor.get_ai_debug_state()
            state["boss_last_attack_id"] = String(boss_ai_debug.get("last_attack_id", ""))
            state["boss_last_ai_decision"] = String(boss_ai_debug.get("last_ai_decision", ""))
            state["boss_tactical_ai"] = bool(boss_ai_debug.get("tactical_ai", false))
            state["boss_tactic"] = String(boss_ai_debug.get("boss_tactic", ""))
            state["boss_tactic_timer"] = float(boss_ai_debug.get("boss_tactic_timer", 0.0))
            state["boss_attack_desire"] = float(boss_ai_debug.get("attack_desire", 0.0))
            state["boss_attack_desire_threshold"] = float(boss_ai_debug.get("attack_desire_threshold", 0.0))
    if not level.campaign.is_empty():
        state["campaign_chapter_total"] = level.campaign.get("chapters", []).size()
        state["campaign_current_chapter"] = level.current_campaign_chapter.get("name", "")
        state["campaign_next_chapter"] = level._next_campaign_chapter_name()
        state["chapter_file_total"] = level.chapter_file_configs.size()
        state["chapter_file_ids"] = level._chapter_file_ids()
    if not level.audio_visual_manifest.is_empty():
        state["av_runtime_event_total"] = level.audio_visual_manifest.get("runtime_events", {}).size()
        state["av_chapter_total"] = level.audio_visual_manifest.get("chapter_audio_visual", []).size()
    if level.metsys_bridge != null:
        state.merge(level.metsys_bridge.get_state(), true)
    return state


static func debug_collect_all_abilities(level: Node) -> void:
    for collectible in level.config.get("collectibles", []):
        if not (collectible is Dictionary):
            continue
        var data: Dictionary = collectible
        if String(data.get("kind", "")) != "item":
            continue
        var item_id := String(data.get("item_id", ""))
        if item_id.is_empty():
            continue
        level._add_inventory_item(item_id, 1, false)
        level.unlocked_abilities[item_id] = String(data.get("ability_name", data.get("label", item_id)))
    level._refresh_ability_gates()
    level._refresh_hud()


static func debug_clear_combat_route(level: Node) -> void:
    level.enemy_defeated = level.enemy_total
    if level._combat_progression_enabled():
        level._open_combat_clear_route()
    level._refresh_hud()


static func debug_open_all_shortcuts(level: Node) -> void:
    level._open_all_shortcuts()


static func debug_start_boss(level: Node) -> void:
    level.boss_unlocked = true
    level._spawn_boss()


static func debug_kill_boss(level: Node) -> void:
    if not level.boss_spawned:
        level._debug_start_boss()
    if level.boss_actor != null and is_instance_valid(level.boss_actor):
        level.boss_actor.take_hit(999, 1)
