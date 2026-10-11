extends SceneTree
## Redesigned UI rendered in the real World with isolated showcase progress.
## Graphical engine: --script res://scripts/capture_seal_world.gd -- --capture-output=DIR
var destination := ""
var world: Node

func _initialize() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--capture-output="):
            destination = argument.trim_prefix("--capture-output=")
    call_deferred("capture")

func frames(count: int) -> void:
    for index in count:
        await process_frame

func shot(filename: String) -> void:
    await frames(5)
    await RenderingServer.frame_post_draw
    var result := root.get_texture().get_image().save_png(destination.path_join(filename + ".png"))
    if result != OK:
        push_error("Cannot save World screenshot: " + filename)
        quit(1)

func capture() -> void:
    if destination.is_empty():
        push_error("Specify --capture-output=absolute-directory")
        quit(1)
        return
    DirAccess.make_dir_recursive_absolute(destination)
    root.size = Vector2i(1280, 720)
    world = load("res://scenes/World.tscn").instantiate()
    world.world_resume = false
    world.world_save_path = "user://seal_world_showcase.json"
    root.add_child(world)
    current_scene = world
    await frames(35)
    # Showcase-only acquisition state; actual events are tested separately.
    for table in ["crests", "skills", "tools", "passives"]:
        for item in world.build_system.catalog[table].values():
            world.story_flags[String(item.unlock_flag)] = true
    world._sync_player_build()
    world.build_system.select_skill("cleave", 0)
    world.build_system.select_skill("needle", 1)
    world.build_system.select_tool("shard", 0)
    world.build_system.select_tool("mine", 1)
    world.build_system.equip_passives(["reflux", "stride"])
    world.build_system.refill_tools(true)
    world._sync_player_build()
    world.currency_count = 120
    world.ui_shell.toast.text = ""
    await shot("world_hud")
    world._toggle_build()
    var pages := ["契印", "技能", "战具", "铭饰", "强化", "构筑"]
    var names := ["seal", "skills", "tools", "adornments", "upgrades", "loadout"]
    for index in pages.size():
        world.ui_shell.build_category = pages[index]
        world.ui_shell.refresh_build()
        await shot(names[index])
    world._close_overlays()
    world._add_inventory_item("moss_chitin",5,false)
    world._toggle_backpack()
    await shot("inventory")
    world.ui_shell.bag_category="旅记"
    world.ui_shell.refresh_inventory()
    await shot("journal")
    world._close_overlays()
    world._toggle_map()
    await shot("map")
    world._close_overlays()
    world._toggle_audio_settings()
    await shot("settings")
    world._close_overlays()
    for npc in get_nodes_in_group("interactable"):
        if String(npc.get_meta("kind",""))=="npc":
            world._show_dialogue(npc,"名字不会因为被抹去就从未存在。把针线带好，走过铜钟沉默的地方；若你寻到旧物，就把它们的来处也一起带回来。")
            world.subtitle_seconds=30.0
            world.subtitle_elapsed=30.0
            await frames(60)
            await shot("dialogue")
            world.ui_shell.accessibility.subtitle_size=26
            world.ui_shell._apply_accessibility()
            await shot("dialogue_large")
            break
    world._close_overlays()
    world.player.hp=1
    world.build_system.cooldowns["cleave"]=2.4
    await shot("low_health")
    world._toggle_backpack()
    world.ui_shell.bag_category="材料"
    world.ui_shell.refresh_inventory()
    root.size=Vector2i(1600,720)
    await shot("inventory_ultrawide")
    root.size=Vector2i(1280,720)
    world._close_overlays()
    var target := world.get_node("seal_training_cleave")
    world.player.global_position = Vector2(target.global_position.x - 80, target.global_position.y + 23)
    var camera: Camera2D = world.player.get_node("Camera2D")
    camera.reset_smoothing()
    await frames(45)
    await shot("practice")
    world.player.facing = 1
    world.player.cast_selected_skill(0)
    for index in 13:
        await physics_frame
    paused = true
    await shot("skill_action")
    paused = false
    print("UI_REDESIGN_CAPTURE_PASS isolated_showcase_progress=true")
    world.queue_free()
    await frames(2)
    quit()
