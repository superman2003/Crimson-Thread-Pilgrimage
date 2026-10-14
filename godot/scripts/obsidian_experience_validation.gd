extends SceneTree
## Production World, camera and actors; positioned fixtures, not a natural clear.
const PATH := "res://data/demo_ch05_obsidian_pilgrim_road.json"
const SAVE_PATH := "user://obsidian_experience.json"
var checks := 0
var failures: Array[String] = []
var capture := false

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

func run() -> void:
    root.size = Vector2i(1280, 720)
    await encounters()
    await room_views()
    for action in ["attack", "move_left", "move_right", "heal"]:
        Input.action_release(action)
    await frames()
    for failure in failures: push_error(failure)
    print("OBSIDIAN_EXPERIENCE checks=%d failures=%d fixture_scope=positioned_camera_and_live_local_combat" % [checks, failures.size()])
    call_deferred("quit", 0 if failures.is_empty() else 1)

func encounters() -> void:
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
    player.global_position = Vector2(510, 2640)
    await frames(15)
    check(player.is_on_floor(), "Local encounter fixture has physical floor contact")
    check(not player.debug_invulnerable, "Local encounter keeps ordinary damage enabled")
    for eid in ["E07", "E13"]:
        var waiting_x := 510.0 if eid == "E07" else 4150.0
        player.respawn_at(Vector2(waiting_x, 2640))
        await frames(4)
        clear_damage_guards(player)
        var spawn: Dictionary = {}
        for record in data.enemy_spawns:
            if record.id == eid: spawn = record
        var enemy := Area2D.new()
        enemy.set_script(load("res://scripts/enemy_actor.gd"))
        enemy.configure(spawn, String(spawn.sprite), false, data.ai_profiles[spawn.kind])
        enemy.position = Vector2(spawn.position[0], 2600)
        stage.add_child(enemy)
        check(enemy.ai_commands.size() == 2, eid + " retains both species attacks")
        var expected := ["lunge", "wave"] if eid == "E07" else ["lunge", "pool"]
        var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/original_creature_combat.json"))[spawn.kind]
        for index in 2:
            check(enemy.ai_commands[index].type == expected[index] and int(enemy.ai_commands[index].damage) == 1, eid + " preserves attack identity and damage")
            check(float(enemy.ai_commands[index].recover) >= player.heal_duration + 0.15, eid + " offers recovery after attack " + str(index))
            var actual: Dictionary = enemy.ai_commands[index].duplicate(true)
            var original: Dictionary = baseline.attacks[index].duplicate(true)
            for field in ["recover", "start_cooldown"]:
                actual.erase(field)
                original.erase(field)
            check(actual == original, eid + " preserves all non-pacing attack fields " + str(index))
        var hp_before: int = player.hp
        await frames(180)
        check(not enemy.engage_announced and player.hp == hp_before, eid + " does not start combat at the waiting position")
        check(absf(enemy.global_position.x - enemy.spawn_position.x) <= enemy.leash_radius + 1, eid + " patrol stays on the exit platform")
        player.global_position = Vector2(enemy.spawn_position.x - 45, 2640)
        player.velocity = Vector2.ZERO
        clear_damage_guards(player)
        hp_before = player.hp
        var windup := false
        for tick in 180:
            await frames(1)
            if enemy.state == "windup":
                windup = true
                break
        check(windup, eid + " naturally starts an attack when approached")
        await frames(80)
        check(player.hp < hp_before, eid + " retained attack damages the production Player")
        # Retreat does not grant immunity or destroy an already-started wave/pool.
        enemy.set_physics_process(false)
        enemy.attack_target = player.global_position
        enemy._spawn_command_effects(enemy.ai_commands[1], false)
        var effects: Array = enemy.owned_attack_effects.duplicate()
        player.global_position = Vector2(waiting_x, 2640)
        await frames(10)
        var surviving := 0
        for effect in effects:
            if is_instance_valid(effect) and not effect.is_queued_for_deletion(): surviving += 1
        check(surviving > 0, eid + " retreat leaves existing wave/pool alive")
        enemy.queue_free()
        await frames(8)
    stage.queue_free()
    await frames(6)

func room_views() -> void:
    for suffix in ["", ".bak", ".tmp"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + suffix))
    var world = load("res://scenes/World.tscn").instantiate()
    world.world_resume = false
    world.world_save_path = SAVE_PATH
    root.add_child(world)
    current_scene = world
    await frames(8)
    pause_world(world)
    var player_id: int = world.player.get_instance_id()
    var camera: Camera2D = world.player.get_node("Camera2D")
    var camera_id := camera.get_instance_id()
    world._travel_world(PATH, Vector2(300, 2720))
    pause_world(world)
    await frames(4)
    check(world.config.id == "demo_ch05_obsidian_pilgrim_road", "Production World loads the pilgrim road")
    check(world.config.chapter_name == "黑曜巡礼道" and String(world.config.map_title).begins_with("黑曜巡礼道"), "HUD and map use the campaign region name")
    check(not world.win_label.visible, "Arrival never occupies the persistent ending banner")
    world._show_chapter_entry_message()
    check(world.toast_label.text == "黑曜巡礼道", "Arrival uses the player-facing region name")
    check(world.player.get_instance_id() == player_id and camera.get_instance_id() == camera_id, "Arrival preserves Player and Camera instances")
    check(world.player.room_camera.zones.size() == 14, "All 14 original pilgrim rooms have authored camera ranges")
    check(not world.player.debug_invulnerable, "Production waiting fixtures keep ordinary damage rules")
    for encounter in [["E07", Vector2(510, 1870)], ["E07", Vector2(190, 1870)], ["E13", Vector2(4150, 578)], ["E10", Vector2(3350, 650)], ["E12", Vector2(230, 1352)]]:
        var actor: Area2D = null
        for candidate in get_nodes_in_group("enemy"):
            if candidate.get_parent() == world and candidate.spawn_id == encounter[0]: actor = candidate
        check(actor != null, String(encounter[0]) + " production actor exists")
        if actor == null: continue
        world.player.global_position = encounter[1]
        clear_damage_guards(world.player)
        world.player.reset_camera_after_arrival()
        world._warm_arrival_cave()
        world._warm_arrival_terrain()
        world._warm_arrival_platforms()
        world.world_gameplay_residency.warm_enemy_arrival(world, world.player.global_position)
        pause_world(world)
        var hp_before: int = world.player.hp
        actor.set_physics_process(true)
        await frames(90)
        check(not actor.engage_announced, String(encounter[0]) + " does not engage at the actual NPC/rest position")
        check(world.player.hp == hp_before, String(encounter[0]) + " production waiting fixture takes no new damage")
        actor.set_physics_process(false)
    var zoom := camera.zoom
    var half := Vector2(root.size) / zoom * 0.5
    for room in world.config.map_rooms:
        if not room.has("camera_bounds"): continue # Workshops remain a separate task.
        var rect := Rect2(room.layout_rect[0], room.layout_rect[1], room.layout_rect[2], room.layout_rect[3])
        for point in [rect.get_center(), rect.position + Vector2(40, 70), rect.end - Vector2(40, 70)]:
            world.player.global_position = point
            world.player.reset_camera_after_arrival()
            var screen := Rect2(camera.get_screen_center_position() - half, half * 2)
            check(screen.has_point(point + Vector2(0, -40)) and screen.has_point(point + Vector2(0, 15)), String(room.id) + " body and footing visible at " + str(point))
            check(camera.limit_left < camera.limit_right and camera.limit_top < camera.limit_bottom, String(room.id) + " ordered camera limits")
    check(camera.zoom == zoom, "Room framing preserves configured zoom")
    for shaft in [["funicular_shaft", Vector2(3460, 1880), Vector2(3460, 2620)], ["watch_tower", Vector2(3400, 650), Vector2(3400, 1220)], ["cable_descent", Vector2(5590, 900), Vector2(5590, 2380)]]:
        world.player.global_position = shaft[1]
        world.player.reset_camera_after_arrival()
        var top := camera.get_screen_center_position().y
        world.player.global_position = shaft[2]
        world.player.reset_camera_after_arrival()
        check(camera.get_screen_center_position().y - top > 350, String(shaft[0]) + " follows the route instead of fixing its full-height center")
    for sample in [["entry", Vector2(300, 2760)], ["camp", Vector2(510, 1910)], ["graves", Vector2(230, 1392)], ["tower", Vector2(3350, 690)], ["mirror_rest", Vector2(4150, 618)]]:
        world.player.global_position = sample[1]
        world.player.reset_camera_after_arrival()
        world._warm_arrival_cave()
        world._warm_arrival_terrain()
        world._warm_arrival_platforms()
        world.world_gameplay_residency.warm_enemy_arrival(world, world.player.global_position)
        pause_world(world)
        world.player.velocity = Vector2.ZERO
        world.player.set_physics_process(true)
        await frames(12)
        check(world.player.is_on_floor(), String(sample[0]) + " capture fixture stands on production ground")
        world.player.set_physics_process(false)
        world.player.reset_camera_after_arrival()
        if capture:
            world.ui_shell.toast.text = ""
            await RenderingServer.frame_post_draw
            DirAccess.make_dir_recursive_absolute("res://../artifacts/obsidian")
            root.get_texture().get_image().save_png("res://../artifacts/obsidian/" + String(sample[0]) + ".png")
    world.player.global_position = Vector2(5100, 660)
    world.player.reset_camera_after_arrival()
    world._set_boss_arena_locked(true)
    check(world.player.camera_focus.active_lock == "boss_arena", "Mirror pool seal overrides exploration framing")
    world._set_boss_arena_locked(false)
    check(world.player.camera_focus.active_lock == "exploration_room", "Seal release restores room framing")
    world._set_boss_arena_locked(true)
    world.player.respawn_at(Vector2(4150, 578))
    check(world.player.camera_focus.active_lock == "exploration_room" and world.player.room_camera.current.id == "mirror_approach", "Actual respawn signal restores the mirror rest before rendering")
    check(camera.get_screen_center_position().distance_to(world.player.global_position) < 250, "Respawn immediately frames the mirror rest")
    var next_path := "res://data/demo_ch06_silent_crown_core.json"
    var next_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(next_path))
    world._travel_world(next_path, Vector2(next_data.player_start[0], next_data.player_start[1]))
    pause_world(world)
    check(world.player.room_camera.zones.is_empty() and not world.player.camera_focus.locks.has("exploration_room"), "Leaving pilgrim road clears its room limits")
    world._travel_world(PATH, Vector2(300, 2720))
    pause_world(world)
    check(world.player.room_camera.zones.size() == 14 and world.player.room_camera.current.id == "ravine_gate", "Returning rebuilds entry framing without stale locks")
    world.queue_free()
    await frames(6)
    for suffix in ["", ".bak", ".tmp"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + suffix))
