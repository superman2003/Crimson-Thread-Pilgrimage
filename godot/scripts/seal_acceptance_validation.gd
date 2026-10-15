extends SceneTree
## End-to-end fixtures use real World, UI buttons, player and enemy damage code.
const BUILD := preload("res://scripts/build_system.gd")
const ENEMY := preload("res://scripts/enemy_actor.gd")
const SAVE_PATH := "user://seal_acceptance.json"
var checks := 0
var failures: Array[String] = []
var scene: Node

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)
        print("FAIL: " + label)

func _frames(count: int = 3) -> void:
    for index in count:
        await physics_frame
        await process_frame

func _click(id: String) -> bool:
    for child in scene.ui_shell.build_grid.get_children():
        if child is Button and child.get_meta("build_id", "") == id:
            child.pressed.emit()
            return true
    return false

func _freeze_world() -> void:
    scene.set_process(false)
    scene.player.set_physics_process(false)
    for enemy in get_nodes_in_group("enemy"):
        enemy.set_physics_process(false)

func _run() -> void:
    scene = load("res://scenes/World.tscn").instantiate()
    scene.world_resume = false
    scene.world_save_path = SAVE_PATH
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene = scene
    await _frames()
    _freeze_world()
    var practice_count := 0
    for enemy in get_nodes_in_group("enemy"):
        if enemy.get_meta("seal_training_target", false):
            practice_count += 1
            var ray := PhysicsRayQueryParameters2D.create(enemy.global_position + Vector2(0, 10), enemy.global_position + Vector2(0, 40), 1)
            ray.collide_with_areas = false
            _check(not enemy.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(), "actual practice target stands on supporting floor")
    _check(practice_count == 2, "first region has both acquired-skill practice targets")
    _check(load("res://scripts/world_routes.gd")._data().get("seal_practice_plan", []).size() == 6, "all six skills have authored practice spaces")
    var build: RefCounted = scene.build_system
    _check(build.state.skills.size() == 2 and build.state.tools.size() == 2, "two skill and tool positions exist")
    _check(not build.select_skill("needle", 1).ok, "fresh run cannot equip an undiscovered skill")
    scene.story_flags["seal_bell_repaired"] = true
    scene.story_flags["seal_salt_restored"] = true
    scene.story_flags["quest_bring_names_complete"] = true
    scene.story_flags["skill_needle_learned"] = true
    scene.story_flags["tool_mine_found"] = true
    scene.story_flags["charm_reflux_found"] = true
    scene.story_flags["charm_shell_found"] = true
    scene._sync_player_build()
    for ability in ["thread_dash", "silk_wall_grip", "double_thread_jump", "echo_hook", "bell_guard", "thorn_downstrike", "lantern_phase", "crown_resonance"]:
        scene._add_inventory_item(ability, 1, false)
    scene._refresh_ability_gates()
    var player: CharacterBody2D = scene.player
    var shrine: Area2D
    for child in scene.get_children():
        if child is Area2D and child.get_meta("kind", "") == "save_point":
            shrine = child
            break
    _check(shrine != null, "actual shrine exists")
    if shrine == null:
        quit(1)
        return
    player.global_position = shrine.global_position
    for tool_id in build.state.tool_counts:
        build.state.tool_counts[tool_id] = 0
    player.hp = maxi(1, player.max_hp - 2)
    player.energy = maxi(0, player.max_energy - 31)
    build.cooldowns["cleave"] = 2.75
    var stock_before_rest: Dictionary = build.state.tool_counts.duplicate(true)
    scene._activate_save_point(shrine)
    _check(player.hp == player.max_hp and player.energy == player.max_energy, "actual shrine restores HP and thread")
    _check(build.state.tool_counts == stock_before_rest, "actual shrine rest does not refill tool stock")
    _check(build.cooldowns.cleave == 2.75, "actual shrine rest does not reset skill cooldown")
    scene.currency_count = 5
    scene.inventory_counts["moss_chitin"] = 1
    var partial_quote: Dictionary = scene.perform_build_action("quote_resupply")
    _check(partial_quote.get("ok", false) and int(partial_quote.get("charges", {}).get("shard", 0)) == 1
        and int(partial_quote.get("cost", {}).get("currency", 0)) == 4
        and int(partial_quote.get("cost", {}).get("materials", {}).get("moss_chitin", 0)) == 1,
        "actual shrine quotes one affordable partial charge with its material cost")
    var partial_currency := int(scene.currency_count)
    var quoted_cost := int(partial_quote.get("cost", {}).get("currency", 0))
    var partial_supply: Dictionary = scene.perform_build_action("resupply_tools")
    _check(partial_supply.get("ok", false) and scene.currency_count == partial_currency - quoted_cost
        and int(scene.inventory_counts.get("moss_chitin", 0)) == 0
        and int(build.state.tool_counts.shard) == 1 and int(build.state.tool_counts.mine) == 0,
        "paid partial resupply charges exactly the previewed cost")
    _check(int(build.state.tool_counts.shard) <= build.tool_capacity("shard") and int(build.state.tool_counts.mine) <= build.tool_capacity("mine"),
        "paid resupply never exceeds tool capacity")
    var cycle_keys: Array = InputMap.action_get_events("skill_cycle").filter(func(event): return event is InputEventKey)
    var hook_keys: Array = InputMap.action_get_events("hook").filter(func(event): return event is InputEventKey)
    _check(cycle_keys.all(func(cycle): return hook_keys.all(func(hook): return cycle.physical_keycode != hook.physical_keycode)), "default skill cycle does not collide with permanent hook")
    player.hp = 3
    player.energy = 63
    build.cooldowns["cleave"] = 2.75
    build.state.tool_counts.shard = 1
    scene._toggle_build()
    scene.ui_shell.build_category = "契印"
    scene.ui_shell.refresh_build()
    _check(_click("bell") and build.state.crest == "bell", "real seal button changes equipped seal")
    _check(player.hp == 3 and player.energy == 63, "seal click cannot refresh health or energy")
    _check(build.state.tool_counts.shard == 1 and build.cooldowns.cleave == 2.75, "seal click cannot refresh tools or cooldown")
    scene.ui_shell.build_category = "技能"
    scene.ui_shell.build_assign_slot = 1
    scene.ui_shell.refresh_build()
    _check(_click("needle") and build.state.skills == ["cleave", "needle"], "real skill button assigns second position")
    scene.ui_shell.build_category = "战具"
    scene.ui_shell.build_assign_slot = 1
    scene.ui_shell.refresh_build()
    _check(_click("mine") and build.state.tools == ["shard", "mine"], "real tool button assigns second position")
    _check(not build.select_skill("cleave", 1).ok, "duplicate skill assignment rejected")
    _check(not build.equip_passives(["reflux", "reflux"]).ok, "duplicate adornment rejected")
    _check(build.equip_passives(["reflux", "shell"]).ok, "two compatible adornments fit cast seal")
    scene._sync_player_build()
    var speed_once: float = player.speed
    var attack_once: int = player.attack_damage
    for index in 5:
        scene._sync_player_build()
    _check(player.speed == speed_once and player.attack_damage == attack_once, "repeated synchronization never compounds base values")
    _check(build.switch_crest("salt").ok and build.slots_used() <= 3, "lower-capacity seal removes overflowing adornment deterministically")
    scene._sync_player_build()
    _check(player.dash_unlocked and player.wall_grip_unlocked and player.double_jump_unlocked and player.thread_grapple_unlocked, "switch preserves all movement capabilities")
    _check(player.bell_guard_unlocked and player.thorn_downstrike_unlocked and player.lantern_phase_unlocked and player.crown_resonance_unlocked, "switch preserves four new exploration actions")
    scene._close_overlays()
    # Real combat code, with all damage enabled and no invulnerability fixture.
    player.debug_invulnerable = false
    player.arrival_guard_timer = 0.0
    player.hurt_timer = 0.0
    player._reset_traversal_state()
    player.facing = 1
    var enemy = ENEMY.new()
    enemy.position = player.global_position + Vector2(55, 0)
    enemy.hp = 10
    enemy.max_hp = 10
    enemy.hurtbox_offset = Vector2(0, -42)
    scene.add_child(enemy)
    enemy.set_physics_process(false)
    await _frames(2)
    var enemy_before: int = enemy.hp
    player._start_attack(&"attack_1")
    player._update_attack(0.25)
    _check(enemy.hp < enemy_before, "real normal attack damages actual enemy actor")
    player._reset_traversal_state()
    var hp_before: int = player.hp
    enemy.attack_has_hit = false
    enemy._try_damage_player({"type": "melee", "hit_width": 160, "hit_height": 100, "damage": 1})
    _check(player.hp == hp_before - 1, "actual enemy attack damages unprotected player")
    enemy.apply_salt_mark(5.0)
    enemy.extend_salt_mark_once(2.0)
    var mark_once: float = enemy.salt_mark_timer
    enemy.extend_salt_mark_once(2.0)
    _check(enemy.salt_mark_timer == mark_once and enemy.consume_salt_mark() and not enemy.consume_salt_mark(), "salt mark extends once and consumes once")
    enemy.apply_trip(1.0)
    enemy.reset_for_respawn()
    _check(enemy.salt_mark_timer == 0.0 and enemy.trip_timer == 0.0, "respawn removes expired combat state")
    enemy.queue_free()
    await _frames()
    player.hurt_timer = 0.0
    player.hp = 3
    player.energy = 40
    build.cooldowns["cleave"] = 2.75
    build.state.tool_counts.shard = 1
    scene.perform_build_action("save_loadout", "验收配置")
    var preserved: Dictionary = build.serialize()
    scene.currency_count = 100
    scene.death_recorded = false
    scene._record_death_cache()
    _check(build.serialize() == preserved, "death loss does not change loadout unlocks or cooldown")
    scene._save_world()
    var rain_path: String = load("res://scripts/world_routes.gd").config_path("demo_ch02_rain_foundry_canal")
    _check(not rain_path.is_empty(), "cross-region runtime path exists")
    scene._travel_world(rain_path, Vector2(120, 500))
    scene = current_scene
    _freeze_world()
    _check(scene.build_system.serialize() == preserved, "real cross-region scene replacement preserves entire build")
    _check(scene.player.dash_unlocked and scene.player.double_jump_unlocked, "cross-region retains permanent movement")
    var same_path: String = scene.config_path
    scene._save_world()
    scene.free()
    scene = load("res://scenes/World.tscn").instantiate()
    scene.config_path = same_path
    scene.world_save_path = SAVE_PATH
    scene.world_resume = true
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    current_scene = scene
    _freeze_world()
    _check(scene.build_system.serialize() == preserved, "disk restart preserves complete build and all cooldowns")
    _check(scene.world_state.data.death_cache.currency == 50, "disk restart preserves explicit recovery loss")
    scene.free()
    await _frames()
    for suffix in ["", ".bak", ".tmp"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + suffix))
    print("SEAL_ACCEPTANCE_%s checks=%d failures=%d real_world_ui_damage_crossregion_restart" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
    quit(0 if failures.is_empty() else 1)
