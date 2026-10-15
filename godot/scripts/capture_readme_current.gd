extends SceneTree
## Actual World render with isolated showcase progress, not a completion proof.
## Graphical engine: --script res://scripts/capture_readme_current.gd -- --capture-output=DIR
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
    world.ui_shell.toast.text = ""
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
    world.world_save_path = "user://readme_current_showcase.json"
    root.add_child(world)
    current_scene = world
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(world)
    await frames(35)
    var initial_position: Vector2 = world.player.global_position
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
    # Explicit showcase wallet/materials; this is not a natural acquisition run.
    world.currency_count = 120
    world.inventory_counts["moss_chitin"] = 10
    world.inventory_counts["wet_chitin"] = 10
    var rest_position: Vector2 = initial_position
    for child in world.get_children():
        if child is Area2D and String(child.get_meta("kind", "")) == "save_point":
            rest_position = child.global_position
            world.player.global_position = rest_position
            break
    world.perform_build_action("resupply_tools")
    world._sync_player_build()
    world.currency_count = 120
    world.player.global_position = initial_position
    world.player.get_node("Camera2D").reset_smoothing()
    await frames(30)
    world.ui_shell.toast.text = ""
    await shot("world_hud")
    # Equipment editing requires proximity to a real rest point.
    world.player.global_position = rest_position
    world.player.set_physics_process(false)
    world.player.get_node("Camera2D").reset_smoothing()
    await frames(5)
    world._toggle_build()
    var pages := ["契印", "技能", "战具", "铭饰", "铭饰", "构筑"]
    var names := ["seal", "skills", "tools", "combat_accessory", "travel_accessory", "loadout"]
    for index in pages.size():
        world.ui_shell.build_category = pages[index]
        world.ui_shell.build_family = "travel_accessory" if index == 4 else "combat_accessory"
        if index == 2:
            world.build_system.state.tool_counts["shard"] = 0
            world.build_system.state.tool_counts["mine"] = 0
        world.ui_shell.refresh_build()
        if index == 2: world.ui_shell._preview_tool_resupply()
        await shot(names[index])
    world._close_overlays()
    world._add_inventory_item("moss_chitin", 5, false)
    world._toggle_backpack()
    await shot("inventory")
    world.ui_shell.bag_category = "旅记"
    world.ui_shell.refresh_inventory()
    await shot("journal")
    world._close_overlays()
    # Showcase map ownership only: keep hidden rooms and uncharted details hidden.
    for region_id in preload("res://scripts/world_coordinates.gd").manifest().regions:
        preload("res://scripts/pilgrimage_cartography.gd").region(world.story_flags, region_id).owned = true
    world._toggle_map()
    await shot("map")
    world.world_map_view = true
    world._refresh_map_overlay()
    await shot("world_map")
    world._close_overlays()
    world._toggle_audio_settings()
    await shot("settings")
    world._close_overlays()
    world.player.set_physics_process(true)
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
    world.queue_free()
    world = null
    # Let deferred frees, render commands and retiring audio complete before exit.
    await frames(10)
    await create_timer(0.5).timeout
    print("README_CURRENT_CAPTURE_PASS screenshots=14 isolated_showcase_progress=true")
    quit()
