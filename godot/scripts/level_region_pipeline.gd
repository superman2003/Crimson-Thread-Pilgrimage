extends RefCounted
## The region pipeline: prepare jobs (config, catalogue, chapter, inventory, build, audio, residency), finish jobs, cartography, publishing and restoring the saved build.
## Moved out of main_level.gd unchanged in behaviour; it keeps one-line
## methods of the same names, so callers and validations are unaffected.

static func initialize_region(level: Node, prepared_config: Dictionary = {}) -> void:
    level._prepare_region(prepared_config)
    level._build_world_from_config()
    level._finish_region()


static func prepare_region(level: Node, prepared_config: Dictionary = {}) -> void:
    var jobs: Array = level._region_prepare_jobs(prepared_config)
    var cursor := 0
    while cursor < jobs.size():
        var job: Dictionary = jobs[cursor]
        var result: Variant = level.callv(job.method, job.args)
        if result is Array and not result.is_empty() and result[0] is Dictionary and result[0].has("method"):
            for offset in range(result.size()):
                jobs.insert(cursor + 1 + offset, result[offset])
        var completed_method := String(job.get("method", ""))
        if level.config.is_empty() and ((completed_method == "_prepare_narrative_config" and (not level.world_mode or not level.world_catalog.is_empty())) or completed_method == "_commit_world_catalog_prepare"):
            break
        cursor += 1


static func region_prepare_jobs(level: Node, prepared_config: Dictionary = {}) -> Array:
    var jobs: Array = [
        {"method": "_prepare_config_and_route", "args": [prepared_config]},
        {"method": "_prepare_narrative_config", "args": []}
    ]
    if level.world_mode and level.world_catalog.is_empty():
        jobs.append({"method": "_begin_world_catalog_prepare", "args": []})
        # The index job reads route order once and expands into one job per region.
        jobs.append({"method": "_prepare_world_catalog_jobs", "args": []})
        jobs.append({"method": "_commit_world_catalog_prepare", "args": []})
    jobs.append_array([
        {"method": "_prepare_campaign_metadata", "args": []},
        {"method": "_begin_chapter_metadata", "args": []}
    ])
    for path in level._chapter_metadata_paths():
        jobs.append({"method": "_prepare_chapter_metadata", "args": [path]})
    jobs.append_array([
        {"method": "_prepare_av_metadata", "args": []},
        {"method": "_prepare_item_lore_metadata", "args": []},
        {"method": "_resolve_chapter_world_and_spawn", "args": []},
        {"method": "_prepare_inventory_state", "args": []}
    ])
    if level.world_mode:
        jobs.append({"method": "_restore_inventory_and_region", "args": []})
    jobs.append_array([
        {"method": "_restore_build_state", "args": []},
        {"method": "_sync_build_progress", "args": []},
        {"method": "_prepare_build_inputs", "args": []},
        {"method": "_prepare_audio_settings_key", "args": []},
        {"method": "_prepare_metsys_bridge", "args": []},
        {"method": "_begin_audio", "args": []},
        {"method": "_start_audio_explore", "args": []},
        {"method": "_start_audio_ambience", "args": []}
    ])
    if level.world_mode:
        jobs.append({"method": "_prepare_platform_and_gameplay_residency", "args": []})
    return jobs


static func chapter_metadata_paths(level: Node) -> Array:
    var paths: Array = []
    var dir = DirAccess.open(level.CHAPTER_DATA_DIR)
    if dir == null:
        return paths
    dir.list_dir_begin()
    var file_name = dir.get_next()
    while file_name != "":
        if not dir.current_is_dir() and file_name.ends_with(".json"):
            paths.append(level.CHAPTER_DATA_DIR + "/" + file_name)
        file_name = dir.get_next()
    dir.list_dir_end()
    paths.sort()
    return paths


static func prepare_config_and_route(level: Node, prepared_config: Dictionary) -> void:
    level.config = prepared_config.duplicate(true) if not prepared_config.is_empty() else level._load_json(level.config_path)
    if level.world_mode and prepared_config.is_empty():
        if not level.WORLD_ROUTES_SCRIPT.cache_is_current():
            level.config = {}
            level.world_initial_error = "巡礼路线在区域准备期间已过期。"
            return
        level.config = level.WORLD_ROUTES_SCRIPT.apply_to_owned_cached(level.config)
    if level.config.is_empty():
        push_error("Missing demo config: " + level.config_path)


static func prepare_narrative_config(level: Node) -> void:
    if level.world_mode and level.world_narrative == null:
        level.world_narrative = level.WORLD_NARRATIVE_SCRIPT.new()


static func begin_world_catalog_prepare(level: Node) -> void:
    level.world_catalog_prepare_staging.clear()


static func prepare_world_catalog_jobs(level: Node) -> Array:
    var routes = {"chapters": level.WORLD_ROUTES_SCRIPT.cached_chapters()}
    var jobs: Array = []
    for region_id in routes.get("chapters", {}):
        var route: Dictionary = routes.chapters[region_id]
        var catalog: Dictionary = route.get("inventory_catalog", {}).duplicate(true)
        jobs.append({"method": "_prepare_world_catalog_region", "args": [String(region_id), catalog]})
    return jobs


static func prepare_world_catalog_region(level: Node, region_id: String, route_catalog: Dictionary) -> void:
    var region_config: Dictionary = level._load_json("res://data/%s.json" % region_id)
    var catalog: Dictionary = region_config.get("inventory", {}).get("catalog", {}).duplicate(true)
    catalog.merge(route_catalog, true)
    level.world_catalog_prepare_staging.merge(catalog, false)


static func commit_world_catalog_prepare(level: Node) -> void:
    level.world_catalog = level.world_catalog_prepare_staging
    level.world_catalog_prepare_staging = {}


static func prepare_campaign_metadata(level: Node) -> void:
    if level.config.is_empty():
        return
    level.campaign = level._load_world_shared_json(level.CAMPAIGN_PATH)


static func begin_chapter_metadata(level: Node) -> void:
    if level.config.is_empty():
        return
    level.chapter_file_configs.clear()


static func prepare_chapter_metadata(level: Node, path: String) -> void:
    if level.config.is_empty():
        return
    var chapter: Dictionary = level._load_world_shared_json(path)
    if not chapter.is_empty():
        level.chapter_file_configs.append(chapter)


static func prepare_av_metadata(level: Node) -> void:
    if level.config.is_empty():
        return
    level.audio_visual_manifest = level._load_world_shared_json(level.AV_MANIFEST_PATH)


static func prepare_item_lore_metadata(level: Node) -> void:
    if level.config.is_empty():
        return
    level.item_lore = level._load_world_shared_json(level.ITEM_LORE_PATH).get("items", {})


static func resolve_chapter_world_and_spawn(level: Node) -> void:
    if level.config.is_empty():
        return
    level.current_campaign_chapter = level._campaign_chapter_for_id(String(level.config.get("id", "")))
    var world: Dictionary = level.config.get("world", {})
    level.world_width = float(world.get("width", 4096.0))
    level.world_height = float(world.get("height", 720.0))
    level.fall_y = float(world.get("fall_y", 790.0))
    level.active_spawn = level._vec2(level.config.get("player_start", [120, 500]))
    if level.entry_spawn_override_enabled:
        level.active_spawn = level.entry_spawn_override
    level.max_bells = 0 if level._combat_progression_enabled() else int(level.config.get("required_keys", 3))


static func prepare_inventory_state(level: Node) -> void:
    if level.config.is_empty():
        return
    level._init_inventory_state()


static func restore_inventory_and_region(level: Node) -> void:
    if level.config.is_empty():
        return
    level._restore_world_inventory_and_region()


static func restore_build_state(level: Node) -> void:
    if level.config.is_empty():
        return
    if level.build_system == null:
        level.build_system = level.BUILD_SYSTEM_SCRIPT.new()
        level._restore_saved_build()


static func sync_build_progress(level: Node) -> void:
    if level.config.is_empty():
        return
    level.build_system.sync_progress(level.inventory_counts, String(level.config.get("id", "")), level.story_flags)


static func prepare_build_inputs(level: Node) -> void:
    if not level.config.is_empty():
        level._bind_build_inputs()


static func prepare_audio_settings_key(level: Node) -> void:
    if not level.config.is_empty():
        level._bind_audio_settings_key()


static func prepare_metsys_bridge(level: Node) -> void:
    if not level.config.is_empty():
        level._build_metsys_bridge()


static func prepare_audio(level: Node) -> void:
    if not level.config.is_empty():
        level._build_audio()


static func prepare_platform_and_gameplay_residency(level: Node) -> void:
    if level.config.is_empty():
        return
    level.world_platforms = level.WORLD_PLATFORMS.new()
    level.world_gameplay_residency = level.WORLD_GAMEPLAY_RESIDENCY.new()
    level.npc_residency_memory.clear()
    level.save_point_residency_memory.clear()
    var arrival_focus = level.entry_spawn_override if level.entry_spawn_override_enabled else level.active_spawn
    level.world_gameplay_residency.configure(level, level.config, level.world_loader.generation + 1, arrival_focus)


static func finish_region(level: Node) -> void:
    # Initial/synchronous loads use exactly the same plan as async arrivals.
    for job in level._region_finish_jobs():
        level.callv(job.method, job.args)
    level._publish_region()


static func region_finish_jobs(level: Node) -> Array:
    var jobs: Array = [{"method": "_finish_region_spawn", "args": []}]
    if level.world_mode:
        jobs.append({"method": "_spawn_death_cache", "args": []})
        jobs.append_array(level._world_runtime_jobs())
    jobs.append({"method": "_bind_region_audio", "args": []})
    jobs.append_array(level._hud_build_jobs())
    if level.world_mode:
        jobs.append({"method": "_setup_cartography", "args": []})
        jobs.append({"method": "_build_new_journey_dialog", "args": []})
    return jobs


static func finish_region_spawn(level: Node) -> void:
    level._spawn_player()
    level.last_safe_ground = level.active_spawn


static func bind_region_audio(level: Node) -> void:
    level.audio_director.configure_ambience(level.config, level)
    level.audio_director.bind_runtime(level.player, func() -> Array: return level.get_tree().get_nodes_in_group("enemy"))


static func setup_cartography(level: Node) -> void:
    level.CARTOGRAPHY_UI.setup(level)
    level.DEATH_RECALL.setup(level)
    level.MAP_PLAYER_PINS.setup(level)
    preload("res://scripts/map_directory_runtime.gd").setup(level)
    preload("res://scripts/map_control_layout.gd").apply(level)
    preload("res://scripts/shrine_return_dialog.gd").setup(level)
    preload("res://scripts/death_recovery_map.gd").setup(level)


static func publish_region(level: Node) -> void:
    # No yields here: rewards, discovery, saved location and loader generation
    # become visible together only after every arrival/UI job has completed.
    if level.world_mode and level.world_gameplay_residency != null and is_instance_valid(level.player):
        level.world_gameplay_residency.warm_enemy_arrival(level, level.player.global_position)
    level._check_wish_board_rewards()
    level._refresh_hud()
    if level.demo_complete:
        level._spawn_ending_gates()
    if level.world_save_blocked and level.world_initial_error.is_empty():
        level.world_initial_error = "原构筑记录已保留，自动保存仍暂停；请恢复备份或开始新旅途。"
    level._show_chapter_entry_message()
    level.world_loading = false
    level.initial_region_ready = true
    if level.world_mode:
        if not level.world_initial_error.is_empty():
            level._toast(level.world_initial_error)
        level._save_world()
        level.world_loader.register_region(level)
        preload("res://scripts/title_card.gd").present(level, level.world_resumed_journey)
    if level.boss_trial_mode:
        level._defer_region_call("_start_boss_trial")


static func restore_saved_build(level: Node) -> void:
    if not level.world_mode or level.world_state == null or level.world_state.data.get("build_state", {}).is_empty():
        return
    var restored: Dictionary = level.build_system.restore(level.world_state.data.build_state)
    if restored.get("ok", false):
        return
    # T02: keep the original file, then rebuild the build from story progress so
    # autosave can continue instead of pausing for the rest of the journey.
    var repairable: bool = level.build_system.salvageable(level.world_state.data.build_state) and FileAccess.file_exists(level.world_save_path)
    var preserved: String = level.WORLD_STATE_SCRIPT.preserve_copy(level.world_save_path, "before_build_repair") if repairable else ""
    var salvaged: Dictionary = level.build_system.salvage(level.world_state.data.build_state, level.inventory_counts, level.story_flags) if not preserved.is_empty() else {}
    if salvaged.get("ok", false):
        var dropped: Array = salvaged.get("dropped", [])
        level.world_initial_error = "构筑记录有本版本无法识别的内容，已按剧情进度重建构筑%s；原存档已另存。" % ("（未能保留：%s）" % "、".join(dropped.slice(0, 4)) if not dropped.is_empty() else "")
    else:
        level.world_save_blocked = true
        level.world_initial_error = "构筑记录不兼容，原记录已保留；本次使用初始构筑，自动保存已暂停。请恢复备份或开始新旅途。"


static func apply_cmdline_config_override(level: Node) -> void:
    var args := OS.get_cmdline_args()
    args.append_array(OS.get_cmdline_user_args())
    for arg in args:
        var text := String(arg)
        if text.begins_with("--demo-config="):
            level.config_path = text.get_slice("=", 1)
            level.world_mode = false
        elif text == "--boss-trial" or text == "--ch01-boss-trial":
            level.boss_trial_mode = true
            level.world_mode = false
            level.config_path = level.BOSS_TRIAL_CONFIG_PATH
