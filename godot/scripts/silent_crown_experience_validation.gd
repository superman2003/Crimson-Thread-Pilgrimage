extends SceneTree
## Production World and actors; positioned fixtures, not a natural clear.
## Covers the crown's encounter pass: no enemy engages from an NPC or lamp, the
## relocated enemies still engage on their own platforms, and the boss-door
## guard keeps its species attacks with a healing window after each.
const AUDIO := preload("res://scripts/audio_retirement.gd")
const READY := preload("res://scripts/world_ready_validation_helper.gd")
const PATH := "res://data/demo_ch06_silent_crown_core.json"
const CANAL := "res://data/demo_ch02_rain_foundry_canal.json"
const SAVE_PATH := "user://silent_crown_experience.json"
var checks := 0
var failures: Array[String] = []
var capture := false
var data_by_id := {}

func _initialize() -> void:
    capture = "--capture" in OS.get_cmdline_user_args()
    call_deferred("run")

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label)

func frames(count: int = 3) -> void:
    for i in count:
        await physics_frame
        await process_frame

func pause_world(world: Node) -> void:
    world.set_process(false)
    world.set_physics_process(false)
    world.player.set_physics_process(false)
    world.player.feel = null
    for enemy in get_nodes_in_group("enemy"):
        enemy.set_physics_process(false)

func clear_damage_guards(player: Node) -> void:
    player.arrival_guard_timer = 0.0
    player.hurt_timer = 0.0
    player.enemy_contact_guard_timer = 0.0

func spawn_record(data: Dictionary, eid: String) -> Dictionary:
    for record in data.enemy_spawns:
        if record.id == eid: return record
    return {}

func run() -> void:
    root.size = Vector2i(1280, 720)
    data_contract()
    await door_guard()
    await production_world()
    for action in ["attack", "move_left", "move_right", "heal"]:
        Input.action_release(action)
    await frames()
    for failure in failures: push_error(failure)
    print("SILENT_CROWN_EXPERIENCE checks=%d failures=%d fixture_scope=positioned_waiting_and_live_local_combat" % [checks, failures.size()])
    call_deferred("quit", 0 if failures.is_empty() else 1)

## Static placement: every relocated enemy stands on its named platform, and
## no enemy's aggro reaches an NPC or lamp even from the far end of its patrol.
func data_contract() -> void:
    var combat: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/original_creature_combat.json"))
    for path in [PATH, CANAL]:
        var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
        var platforms := {}
        for platform in data.platforms: platforms[platform.id] = platform
        var safe: Array = data.npcs + data.save_points
        for spawn: Dictionary in data.enemy_spawns:
            var profile: Dictionary = combat.get(spawn.kind, {})
            if profile.is_empty(): continue
            var platform: Dictionary = platforms.get(String(spawn.get("platform_id", "")), {})
            check(not platform.is_empty() and is_equal_approx(float(spawn.position[1]), float(platform.rect[1]) - 40.0) and float(spawn.position[0]) >= float(platform.rect[0]) and float(spawn.position[0]) <= float(platform.rect[0]) + float(platform.rect[2]), String(spawn.id) + " stands on its named platform in " + String(data.id))
            # Engagement needs the player inside the leash (+42 px attack margin) and
            # inside aggro range of the patrolling enemy; per-spawn profiles override.
            var override: Dictionary = spawn.get("encounter_profile", {})
            var aggro := float(override.get("aggro_range", data.ai_profiles.get(spawn.kind, profile).get("aggro_range", profile.aggro_range)))
            var reach := minf(aggro + float(spawn.get("patrol", 0)), float(spawn.get("leash_radius", 300)) + 42.0)
            for point: Dictionary in safe:
                var dx := absf(float(spawn.position[0]) - float(point.position[0]))
                var dy := absf(float(spawn.position[1]) - float(point.position[1]))
                check(dx >= reach or dy >= float(profile.get("aggro_vertical_tolerance", 140)), String(spawn.id) + " cannot aggro from " + String(point.id) + " in " + String(data.id))
    var crown: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
    var elites := []
    for spawn in crown.enemy_spawns:
        if bool(spawn.get("elite", false)): elites.append(String(spawn.id))
    check(elites == ["E01", "E08"], "Crown elites fight in pressure rooms, not beside the runback lamp")
    var guard := spawn_record(crown, "E14")
    check(String(guard.platform_id) == "boss_threshold" and float(guard.leash_radius) <= 60.0, "Boss-door guard holds the threshold")
    var rooms := {}
    for room in crown.map_rooms: rooms[room.id] = room
    check(not String(rooms.bell_tongue_vault.objective).contains("清怪"), "Vault lever is not described as needing a clear")
    check(String(rooms.ring_west.danger).contains("迟影") and String(rooms.ring_west.danger).contains("光核"), "West ring warns about its two relocated enemies")

func door_guard() -> void:
    var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
    var stage := Node2D.new()
    root.add_child(stage)
    var floor_body := StaticBody2D.new()
    var collision := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = Vector2(9000, 20)
    collision.shape = rectangle
    floor_body.position = Vector2(4000, 2650)
    floor_body.add_child(collision)
    stage.add_child(floor_body)
    var player = load("res://scenes/Player.tscn").instantiate()
    stage.add_child(player)
    player.feel = null
    var lamp_x := 2690.0
    player.global_position = Vector2(lamp_x, 2640)
    await frames(15)
    check(player.is_on_floor(), "Local guard fixture has physical floor contact")
    check(not player.debug_invulnerable, "Local guard fixture keeps ordinary damage enabled")
    clear_damage_guards(player)
    var spawn := spawn_record(data, "E14")
    var enemy := Area2D.new()
    enemy.set_script(load("res://scripts/enemy_actor.gd"))
    enemy.configure(spawn, String(spawn.sprite), false, data.ai_profiles[spawn.kind])
    enemy.position = Vector2(spawn.position[0], 2600)
    stage.add_child(enemy)
    check(enemy.ai_commands.size() == 2 and not enemy.is_elite, "Boss-door guard keeps both species attacks as an ordinary knight")
    var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/original_creature_combat.json"))[spawn.kind]
    for index in 2:
        check(String(enemy.ai_commands[index].type) == String(baseline.attacks[index].type) and int(enemy.ai_commands[index].damage) == 1, "Guard preserves attack identity and damage " + str(index))
        check(float(enemy.ai_commands[index].recover) >= player.heal_duration + 0.15, "Guard leaves a healing window after attack " + str(index))
        var actual: Dictionary = enemy.ai_commands[index].duplicate(true)
        var original: Dictionary = baseline.attacks[index].duplicate(true)
        for field in ["recover", "start_cooldown"]:
            actual.erase(field)
            original.erase(field)
        check(actual == original, "Guard preserves all non-pacing attack fields " + str(index))
    var hp_before: int = player.hp
    await frames(180)
    check(not enemy.engage_announced and player.hp == hp_before, "Guard does not start combat while the player rests at the runback lamp")
    check(absf(enemy.global_position.x - enemy.spawn_position.x) <= enemy.leash_radius + 1, "Guard patrol stays on the threshold")
    player.global_position = Vector2(enemy.spawn_position.x - 60, 2640)
    player.velocity = Vector2.ZERO
    clear_damage_guards(player)
    hp_before = player.hp
    var windup := false
    for tick in 240:
        await frames(1)
        if enemy.state == "windup":
            windup = true
            break
    check(windup, "Guard naturally starts an attack when approached")
    var hurt := false
    for tick in 240:
        await frames(1)
        if player.hp < hp_before:
            hurt = true
            break
    check(hurt, "Guard attack damages the production Player")
    enemy.set_physics_process(false)
    enemy.attack_target = player.global_position
    enemy._spawn_command_effects(enemy.ai_commands[1], false)
    var effects: Array = enemy.owned_attack_effects.duplicate()
    player.global_position = Vector2(lamp_x, 2640)
    await frames(10)
    var surviving := 0
    for effect in effects:
        if is_instance_valid(effect) and not effect.is_queued_for_deletion(): surviving += 1
    check(surviving > 0, "Retreating to the lamp leaves an existing wave alive")
    AUDIO.retire_tree(enemy)
    enemy.queue_free()
    AUDIO.retire_tree(stage)
    stage.queue_free()
    await frames(8)

func warm_at(world: Node, point: Vector2) -> void:
    world.player.global_position = point
    clear_damage_guards(world.player)
    world.player.reset_camera_after_arrival()
    world._warm_arrival_cave()
    world._warm_arrival_terrain()
    world._warm_arrival_platforms()
    world.world_gameplay_residency.warm_enemy_arrival(world, point)
    pause_world(world)

func world_enemies(world: Node) -> Array:
    var result := []
    for candidate in get_nodes_in_group("enemy"):
        if candidate.get_parent() == world and not bool(candidate.get("is_boss")): result.append(candidate)
    return result

func find_enemy(world: Node, eid: String) -> Area2D:
    for candidate in world_enemies(world):
        if candidate.spawn_id == eid: return candidate
    return null

## Every enemy that is live around a safe point runs for 1.5 s while the
## player waits there; none may engage or hurt the player.
func wait_at_safe_points(world: Node, data: Dictionary, expect_live: Dictionary) -> void:
    for point: Dictionary in data.npcs + data.save_points:
        var position := Vector2(point.position[0], point.position[1])
        warm_at(world, position)
        for eid in expect_live.get(point.id, []):
            check(find_enemy(world, eid) != null, eid + " is live around " + String(point.id))
        var enemies := world_enemies(world)
        for enemy in enemies:
            enemy.engage_announced = false
            var record := spawn_record(data_by_id.get(world.config.id, {}), String(enemy.spawn_id))
            if not record.is_empty():
                # Flyers hover above their authored point; their column must still match.
                var authored := Vector2(record.position[0], record.position[1])
                var drift: float = absf(enemy.spawn_position.x - authored.x) if enemy.locomotion == "flight" else enemy.spawn_position.distance_to(authored)
                check(drift < 4.0, String(enemy.spawn_id) + " runtime spawn matches its authored platform in " + String(world.config.id) + " drift=" + str(drift))
        var hp_before: int = world.player.hp
        for enemy in enemies: enemy.set_physics_process(true)
        await frames(90)
        var engaged := []
        for enemy in enemies:
            if enemy.engage_announced: engaged.append(String(enemy.spawn_id))
            enemy.set_physics_process(false)
        check(engaged.is_empty(), String(point.id) + " stays quiet; engaged: " + str(engaged))
        check(world.player.hp == hp_before, String(point.id) + " waiting fixture takes no damage")

func engages_on_its_platform(world: Node, eid: String, point: Vector2) -> void:
    warm_at(world, point)
    var actor := find_enemy(world, eid)
    check(actor != null, eid + " production actor exists on its new platform")
    if actor == null: return
    actor.engage_announced = false
    actor.set_physics_process(true)
    var engaged := false
    for tick in 180:
        await frames(1)
        if actor.engage_announced:
            engaged = true
            break
    actor.set_physics_process(false)
    check(engaged, eid + " still engages a player on its own platform")

func production_world() -> void:
    for suffix in ["", ".bak", ".tmp"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + suffix))
    var world = load("res://scenes/World.tscn").instantiate()
    world.world_resume = false
    world.world_save_path = SAVE_PATH
    root.add_child(world)
    await READY.wait_for(world)
    current_scene = world
    await frames(8)
    pause_world(world)
    var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
    data_by_id[data.id] = data
    world._travel_world(PATH, Vector2(data.player_start[0], data.player_start[1]))
    pause_world(world)
    await frames(4)
    check(world.config.id == "demo_ch06_silent_crown_core", "Production World loads the silent crown")
    check(world.config.chapter_name == "无声王冠" and String(world.config.map_title).begins_with("无声王冠"), "HUD and map use the campaign region name")
    world._show_chapter_entry_message()
    check(world.toast_label.text == "无声王冠", "Arrival uses the player-facing region name")
    check(READY.original_camera_zones(world) == 15, "All 15 crown rooms keep their authored camera ranges")
    check(not world.player.debug_invulnerable, "Production waiting fixtures keep ordinary damage rules")
    elite_first_defeat(world, data)
    await wait_at_safe_points(world, data, {"save_late_runback": ["E14"], "save_hidden_upper_respite": ["E11"], "save_ch06_lower_loop": ["E07"]})
    await engages_on_its_platform(world, "E07", Vector2(2200, 2538))
    await engages_on_its_platform(world, "E13", Vector2(2040, 2320))
    await engages_on_its_platform(world, "E14", Vector2(2990, 3020))
    await engages_on_its_platform(world, "E12", Vector2(1560, 2100))
    for sample in [["runback_lamp", Vector2(2690, 3106)], ["vault", Vector2(2570, 2900)], ["moss_respite", Vector2(1965, 1400)], ["west_ring", Vector2(2200, 2578)], ["throne_door", Vector2(2960, 3060)]]:
        warm_at(world, sample[1])
        world.player.velocity = Vector2.ZERO
        world.player.set_physics_process(true)
        await frames(30)
        check(world.player.is_on_floor(), String(sample[0]) + " capture fixture stands on production ground")
        world.player.set_physics_process(false)
        world.player.reset_camera_after_arrival()
        if capture:
            world.ui_shell.toast.text = ""
            await RenderingServer.frame_post_draw
            DirAccess.make_dir_recursive_absolute("res://../artifacts/silent_crown")
            root.get_texture().get_image().save_png("res://../artifacts/silent_crown/" + String(sample[0]) + ".png")
    world.player.respawn_at(Vector2(2690, 3066))
    check(world.player.room_camera.current.id == "throne_approach", "Respawn at the runback lamp frames the throne approach")
    var canal: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CANAL))
    data_by_id[canal.id] = canal
    world._travel_world(CANAL, Vector2(canal.player_start[0], canal.player_start[1]))
    pause_world(world)
    await frames(4)
    check(world.config.id == "demo_ch02_rain_foundry_canal", "Production World loads the canal for its foreman check")
    var foreman := {"npcs": [], "save_points": []}
    for npc in canal.npcs:
        if npc.id == "npc_drowned_foreman": foreman.npcs.append(npc)
    await wait_at_safe_points(world, foreman, {})
    await engages_on_its_platform(world, "E10", Vector2(4480, 4490))
    AUDIO.retire_tree(world)
    world.queue_free()
    await frames(6)
    check(await AUDIO.drain(self), "Crown fixture releases playback")
    for suffix in ["", ".bak", ".tmp"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + suffix))

## B04: an elite's first defeat pays a one-time bonus; respawns and regular
## enemies pay only the ordinary kill reward.
func elite_first_defeat(world: Node, data: Dictionary) -> void:
    var drop := String(data.enemy_drop_item)
    world.currency_count = 0
    var materials: int = int(world.inventory_counts.get(drop, 0))
    world._on_enemy_died("E01", false, "echo_waterwheel_knight")
    check(world.toast_label.text.contains("精英首胜"), "The elite reward message is shown")
    check(world.currency_count == 8 + world.ELITE_FIRST_CURRENCY and int(world.inventory_counts.get(drop, 0)) == materials + 1 + world.ELITE_FIRST_MATERIALS, "First elite defeat pays the kill reward plus the one-time elite bonus")
    check(bool(world.story_flags.get("elite_first_demo_ch06_silent_crown_core_E01", false)), "The elite bonus is recorded in story flags")
    world._on_enemy_died("E01", false, "echo_waterwheel_knight")
    check(world.currency_count == 16 + world.ELITE_FIRST_CURRENCY, "A respawned elite pays only the ordinary kill reward")
    world._on_enemy_died("E09", false, "echo_waterwheel_knight")
    check(world.currency_count == 24 + world.ELITE_FIRST_CURRENCY, "A regular enemy never pays the elite bonus")
    var saved = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
    check(saved is Dictionary and bool(saved.get("story_flags", {}).get("elite_first_demo_ch06_silent_crown_core_E01", false)), "The elite bonus flag is written to disk")
    # Review case: a first-time elite that is the region's last enemy keeps its
    # reward message inside the combat-clear toast.
    world.story_flags.erase("elite_first_demo_ch06_silent_crown_core_E08")
    world.enemy_defeated = world.enemy_total - 1
    var was_clear: bool = world._combat_goal_met()
    world._on_enemy_died("E08", false, "echo_pilgrim_commander_minor")
    if world._combat_progression_enabled() and not was_clear:
        check(world.toast_label.text.contains("本区敌群已清") and world.toast_label.text.contains("精英首胜"), "A combat clear keeps the elite reward message visible")
    else:
        check(world.toast_label.text.contains("精英首胜"), "The last elite's reward message stays visible")

