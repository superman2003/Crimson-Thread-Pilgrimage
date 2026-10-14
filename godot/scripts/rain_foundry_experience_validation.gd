extends SceneTree
## Real production camera/actors with positioned fixtures; not a natural chapter clear.
const PATH := "res://data/demo_ch02_rain_foundry_canal.json"
const SAVE_PATH := "user://rain_foundry_experience.json"
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

func run() -> void:
    root.size = Vector2i(1280, 720)
    await encounters()
    await room_views()
    for action in ["attack", "move_left", "move_right", "heal"]:
        Input.action_release(action)
    await frames()
    for failure in failures: push_error(failure)
    print("RAIN_FOUNDRY_EXPERIENCE checks=%d failures=%d fixture_scope=positioned_camera_and_live_local_combat" % [checks, failures.size()])
    call_deferred("quit", 0 if failures.is_empty() else 1)

func encounters() -> void:
    var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
    var stage := Node2D.new()
    root.add_child(stage)
    var floor_body := StaticBody2D.new()
    var collision := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = Vector2(2500, 20)
    collision.shape = rectangle
    floor_body.position = Vector2(1600, 3670)
    floor_body.add_child(collision)
    stage.add_child(floor_body)
    var player = load("res://scenes/Player.tscn").instantiate()
    stage.add_child(player)
    player.feel = null
    player.global_position = Vector2(1830, 3660)
    await frames(15)
    check(player.is_on_floor(), "Encounter fixture has physical floor contact")
    # Same configure contract as direct spawn and tree-out residency prefabs.
    for eid in ["E02", "E13", "E14"]:
        player.respawn_at(Vector2(1640 if eid == "E02" else 1830, 3660))
        await frames(4)
        var spawn: Dictionary = {}
        for record in data.enemy_spawns:
            if record.id == eid: spawn = record
        var enemy := Area2D.new()
        enemy.set_script(load("res://scripts/enemy_actor.gd"))
        enemy.configure(spawn, String(spawn.sprite), false, data.ai_profiles[spawn.kind])
        enemy.position = Vector2(spawn.position[0], 3620)
        stage.add_child(enemy)
        enemy.set_physics_process(false)
        check(enemy.ai_commands.size() == 2, eid + " retains both species attacks")
        check(int(enemy.ai_commands[0].damage) > 0 and int(enemy.ai_commands[1].damage) > 0, eid + " keeps damage enabled")
        if eid != "E14":
            player.global_position = Vector2(1640 if eid == "E02" else 1830, 3660)
            player.velocity = Vector2.ZERO
            var hp_before: int = player.hp
            enemy.set_physics_process(true)
            await frames(180)
            check(not enemy.engage_announced and player.hp == hp_before, eid + " does not initiate combat at the NPC's horizontal position: player=%s enemy=%s spawn=%s leash=%s engaged=%s hp=%d->%d" % [player.global_position, enemy.global_position, enemy.spawn_position, enemy.leash_radius, enemy.engage_announced, hp_before, player.hp])
            check(absf(enemy.global_position.x - enemy.spawn_position.x) <= enemy.leash_radius + 1, eid + " patrol stays in its authored territory")
        else:
            check(minf(enemy.ai_commands[0].recover, enemy.ai_commands[1].recover) > player.heal_duration + 0.15, "Trial knight offers recovery after both attacks")
            player.global_position = Vector2(enemy.global_position.x + 65, 3660)
            player.hurt_timer = 0
            var hp_before: int = player.hp
            enemy.set_physics_process(true)
            var windup := false
            for tick in 180:
                await frames(1)
                if enemy.state == "windup":
                    windup = true
                    break
            check(windup, "Trial knight naturally starts its attack when approached")
            await frames(80)
            check(player.hp < hp_before, "Retained trial attack actually damages the production Player")
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
    world._travel_world(PATH, Vector2(200, 720))
    pause_world(world)
    await frames(4)
    check(world.config.id == "demo_ch02_rain_foundry_canal", "Production World loads the foundry")
    check(not world.win_label.visible, "Region arrival never occupies the persistent ending banner")
    world._show_chapter_entry_message() # Inspect the actual adapter before nearby signs replace the toast.
    check(world.toast_label.text == "铸雨渠", "Foundry arrival uses its player-facing region name")
    check(world.player.get_instance_id() == player_id and camera.get_instance_id() == camera_id, "Arrival preserves Player and Camera instances")
    check(world.player.room_camera.zones.size() == 38, "All 38 original foundry rooms have authored camera ranges")
    var zoom := camera.zoom
    var half := Vector2(root.size) / zoom * 0.5
    for room in world.config.map_rooms:
        if not room.has("camera_bounds"): continue # Upgrade workshops remain a separate task.
        var rect := Rect2(room.layout_rect[0], room.layout_rect[1], room.layout_rect[2], room.layout_rect[3])
        for point in [rect.get_center(), rect.position + Vector2(40, 70), rect.end - Vector2(40, 70)]:
            world.player.global_position = point
            world.player.reset_camera_after_arrival()
            var screen := Rect2(camera.get_screen_center_position() - half, half * 2)
            check(screen.has_point(point + Vector2(0, -40)) and screen.has_point(point + Vector2(0, 15)), String(room.id) + " body and footing visible at " + str(point))
            check(camera.limit_left < camera.limit_right and camera.limit_top < camera.limit_bottom, String(room.id) + " ordered camera limits")
    check(camera.zoom == zoom, "Room framing preserves the player's configured zoom")
    for shaft in [["standpipe_shaft", Vector2(1170, 1700), Vector2(1170, 3400)], ["pendulum_gantry", Vector2(6370, 2050), Vector2(6370, 3450)]]:
        world.player.global_position = shaft[1]
        world.player.reset_camera_after_arrival()
        var top := camera.get_screen_center_position().y
        world.player.global_position = shaft[2]
        world.player.reset_camera_after_arrival()
        check(camera.get_screen_center_position().y - top > 900, String(shaft[0]) + " follows the shaft instead of fixing its full-height center")
    for sample in [["entry", Vector2(350, 760)], ["rain_deck", Vector2(1620, 920)], ["pump_atrium", Vector2(2850, 3320)], ["wall_trial", Vector2(1300, 3660)], ["forge_shrine", Vector2(4920, 3760)]]:
        world.player.global_position = sample[1]
        world.player.reset_camera_after_arrival()
        world._warm_arrival_cave()
        world._warm_arrival_terrain()
        world._warm_arrival_platforms()
        world.world_gameplay_residency.warm_enemy_arrival(world, world.player.global_position)
        pause_world(world)
        await frames(12)
        if capture:
            world.ui_shell.toast.text = ""
            await RenderingServer.frame_post_draw
            DirAccess.make_dir_recursive_absolute("res://../artifacts/rain_foundry")
            root.get_texture().get_image().save_png("res://../artifacts/rain_foundry/" + String(sample[0]) + ".png")
    world.player.global_position = Vector2(5650, 3820)
    world.player.reset_camera_after_arrival()
    world._set_boss_arena_locked(true)
    check(world.player.camera_focus.active_lock == "boss_arena", "Foundry Boss seal overrides exploration framing")
    world._set_boss_arena_locked(false)
    check(world.player.camera_focus.active_lock == "exploration_room", "Seal release restores foundry room framing")
    world._set_boss_arena_locked(true)
    world.player.respawn_at(Vector2(4920, 3760))
    check(world.player.camera_focus.active_lock == "exploration_room" and world.player.room_camera.current.id == "forge_shrine", "Actual respawn signal restores the forge shrine before rendering")
    check(camera.get_screen_center_position().distance_to(world.player.global_position) < 250, "Respawn visible center is immediately near the shrine")
    world._travel_world("res://data/demo_ch03_saltwhite_archive.json", Vector2(300, 2580))
    pause_world(world)
    check(world.player.room_camera.zones.size() == 15 and world.player.room_camera.current.id == "salt_gatehouse" and not world.player.camera_focus.locks.has("boss_arena"), "Leaving foundry replaces its room limits with archive framing")
    world._travel_world(PATH, Vector2(200, 720))
    pause_world(world)
    check(world.player.room_camera.zones.size() == 38 and world.player.room_camera.current.id == "upper_sluice", "Returning rebuilds foundry framing without stale locks")
    world.queue_free()
    await frames(6)
    for suffix in ["", ".bak", ".tmp"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + suffix))
