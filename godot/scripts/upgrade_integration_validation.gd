extends SceneTree
const STATE := preload("res://scripts/world_state.gd")
const SAVE_PATH := "user://upgrade_integration.json"
var scene: Node
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    root.process_mode = Node.PROCESS_MODE_DISABLED
    scene = load("res://scenes/World.tscn").instantiate()
    scene.world_resume = false
    scene.world_save_path = SAVE_PATH
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene = scene
    await _frames()
    _check(scene.build_system != null and scene.player.build_system == scene.build_system, "real world injects build into player")
    _check(scene.player.dash_unlocked == (int(scene.inventory_counts.get("thread_dash", 0)) > 0), "world abilities obey inventory")
    _check(scene.get_build_system().get_snapshot().crests.size() == 3, "real UI receives three crests")
    scene._toggle_build()
    _check(scene.active_overlay == "build" and scene.ui_shell.build_panel.visible and scene.player.ui_input_locked, "build panel opens and locks gameplay")
    scene._toggle_map()
    _check(scene.active_overlay == "map" and not scene.ui_shell.build_panel.visible, "map closes build panel")
    scene._close_overlays()
    _check(not scene.player.ui_input_locked, "close restores gameplay")
    scene._add_inventory_item("silk_wall_grip", 1, false)
    scene._add_inventory_item("bell_guard", 1, false)
    scene._refresh_ability_gates()
    _check(not scene.perform_build_action("select_skill", "snare").ok, "exploration abilities do not grant equipment")
    scene.story_flags["skill_snare_learned"] = true
    scene.story_flags["seal_bell_repaired"] = true
    scene._sync_player_build()
    _check(scene.player.bell_guard_unlocked, "new ability is synchronized")
    _check(scene.perform_build_action("select_skill", "snare").ok, "explicit learned event unlocks actual control skill")
    scene.player.global_position = Vector2(1000, 400)
    var initial_crest := String(scene.build_system.state.crest)
    _check(not scene.perform_build_action("switch_crest", "bell").ok, "crest denied outside shrine")
    _check(scene.build_system.state.crest == initial_crest, "denied crest preserves state")
    var shrine: Area2D
    for child in scene.get_children():
        if child is Area2D and child.get_meta("kind", "") == "save_point":
            shrine = child
            break
    _check(shrine != null, "world has a shrine")
    if shrine != null:
        scene.player.global_position = shrine.global_position
        _check(scene.perform_build_action("switch_crest", "bell").ok, "crest changes at physical shrine")
        _check(scene.player.max_hp == int(scene.build_system.profile().max_hp), "player stats match chosen crest")
    var wallet_before := int(scene.currency_count)
    _check(not scene.perform_build_action("transact", "refill_shard").ok, "craft cannot run outside artisan")
    _check(scene.currency_count == wallet_before, "failed crafting never spends")
    var tools_before := int(scene.build_system.state.tool_counts.shard)
    scene._toggle_build()
    _check(not scene.perform_build_action("use_tool").ok and int(scene.build_system.state.tool_counts.shard) == tools_before, "overlay cannot consume tool")
    scene._close_overlays()
    scene.player.hp = scene.player.max_hp
    scene.player.hurt_timer = 0
    scene.player.attack_timer = 0
    scene.player.dash_timer = 0
    _check(scene.perform_build_action("use_tool").ok, "active tool casts in actual world")
    _check(int(scene.build_system.state.tool_counts.shard) == tools_before - 1, "successful cast consumes exactly once")
    scene.currency_count = 100
    scene.last_safe_ground = scene.active_spawn
    scene.death_recorded = false
    scene._record_death_cache()
    _check(scene.currency_count == 50 and scene.world_state.data.death_cache.currency == 50, "death has explicit half loss")
    scene._record_death_cache()
    _check(scene.currency_count == 50, "same death cannot double charge")
    var knot: Area2D = scene.death_cache_area
    _check(knot != null and knot.global_position == scene.active_spawn, "recovery knot is on supported checkpoint")
    if knot != null:
        scene._recover_death_cache(knot)
        _check(scene.currency_count == 100 and scene.world_state.data.death_cache.is_empty(), "recovery returns exact loss and clears record")
    scene.player.hp = 3
    scene.player.energy = 11
    scene.player.debug_invulnerable = false
    scene._void_respawn()
    _check(scene.player.hp == 2 and scene.player.energy < scene.player.max_energy, "fall costs health and does not fully restore energy")
    scene._save_world()
    _check(scene.world_state.data.version == STATE.VERSION and not scene.world_state.data.build_state.is_empty(), "world saves build in current schema")
    _check(scene.select_save_slot(2), "second slot can be opened from real scene")
    await _frames(8)
    scene = current_scene
    _check(scene.world_slot == 2 and scene.world_save_path.ends_with("slot_2.json"), "slot change creates actual isolated World")
    _check(scene.currency_count == 0 and int(scene.build_system.state.tool_counts.shard) == 3, "new slot does not inherit old wallet or consumables")
    scene.queue_free()
    await _frames()
    for suffix in ["", ".bak", ".tmp"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + suffix))
        DirAccess.remove_absolute(ProjectSettings.globalize_path("user://pilgrimage_world_slot_2.json" + suffix))
    if failures.is_empty():
        print("UPGRADE INTEGRATION PASS: %d checks, real scene build/UI/abilities/tools/death/save" % checks)
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)

func _frames(count: int = 4) -> void:
    for i in count:
        await process_frame

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)
