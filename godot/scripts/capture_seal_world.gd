extends SceneTree
## Actual World render with isolated showcase progress, not a completion proof.
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
    print("WORLD_CAPTURE_PASS screenshots=9 isolated_showcase_progress=true")
    world.queue_free()
    await frames(2)
    quit()
