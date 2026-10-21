extends SceneTree
## Captures real UI with an isolated save; never reads the player's world save.
var destination := ""
var world: Node
func _initialize() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--capture-output="):destination=argument.trim_prefix("--capture-output=")
    call_deferred("capture")
func frames(count: int=5) -> void:
    for index in count:await process_frame
func shot(filename: String) -> void:
    await frames()
    await RenderingServer.frame_post_draw
    var result := root.get_texture().get_image().save_png(destination.path_join(filename+".png"))
    if result!=OK:
        push_error("Cannot save inscription screenshot: "+filename)
        quit(1)
func capture() -> void:
    if destination.is_empty():
        push_error("Specify --capture-output=absolute-directory")
        quit(1)
        return
    DirAccess.make_dir_recursive_absolute(destination)
    root.size=Vector2i(1280,800)
    var specimen: Control=load("res://scenes/InscriptionSpecimen.tscn").instantiate()
    root.add_child(specimen)
    await shot("00_typography")
    specimen.queue_free()
    await frames(2)
    root.size=Vector2i(1280,720)
    world=load("res://scenes/World.tscn").instantiate()
    world.world_resume=false
    world.world_save_path="user://inscription_showcase.json"
    root.add_child(world)
    current_scene=world
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(world)
    await frames(30)
    world.player.set_physics_process(false)
    world.set_process(false)
    for enemy in get_nodes_in_group("enemy"):enemy.set_physics_process(false)
    for table in ["crests","skills","tools","passives"]:
        for item in world.build_system.catalog[table].values():world.story_flags[String(item.unlock_flag)]=true
    world._sync_player_build()
    world.build_system.select_skill("cleave",0)
    world.build_system.select_skill("needle",1)
    world.build_system.select_tool("shard",0)
    world.build_system.select_tool("mine",1)
    world.build_system.refill_tools(true)
    world._sync_player_build()
    world.currency_count=120
    world.player.energy=74
    world.ui_shell.toast.text=""
    await shot("01_hud")
    world.player.hp=1
    await shot("02_low_health")
    world.player.hp=world.player.max_hp
    for child in world.get_children():
        if child is Area2D and String(child.get_meta("kind",""))=="save_point":
            world.player.global_position=child.global_position
            break
    world._toggle_build()
    world.ui_shell.build_category="契印"
    world.ui_shell.refresh_build()
    await shot("03_seals")
    world.ui_shell.build_category="铭饰"
    world.ui_shell.refresh_build()
    await shot("04_adornments")
    world._close_overlays()
    world._add_inventory_item("moss_chitin",5,false)
    world._toggle_backpack()
    await shot("05_inventory")
    world.ui_shell.bag_category="旅记"
    world.ui_shell.refresh_inventory()
    await shot("06_journal")
    world._close_overlays()
    for region_id in preload("res://scripts/world_coordinates.gd").manifest().regions:
        preload("res://scripts/pilgrimage_cartography.gd").region(world.story_flags,region_id).owned=true
    # Isolated preview of a partly surveyed folio, using production map drawing.
    var journal := preload("res://scripts/pilgrimage_cartography.gd")
    var visible_rooms := 0
    for room in world.config.get("map_rooms",[]):
        if preload("res://scripts/cartography_runtime.gd").public_room(room) and visible_rooms<8:
            journal.visit(world.story_flags,String(world.config.id),String(room.id))
            visible_rooms+=1
    journal.grant_quill(world.story_flags)
    journal.rest(world.story_flags)
    world._toggle_map()
    await shot("07_map")
    world._close_overlays()
    world._toggle_audio_settings()
    await shot("08_settings")
    world._close_overlays()
    for npc in get_nodes_in_group("interactable"):
        if String(npc.get_meta("kind",""))=="npc":
            world._show_dialogue(npc,"名字不会因为被抹去就从未存在。把针线带好，走过铜钟沉默的地方；若你寻到旧物，就把它们的来处也一起带回来。")
            world.subtitle_seconds=30.0
            world.subtitle_elapsed=30.0
            world.ui_shell.dialogue_body.visible_characters=-1
            await shot("09_dialogue")
            break
    world._close_overlays()
    root.size=Vector2i(960,540)
    await shot("10_hud_small")
    root.size=Vector2i(1600,720)
    world._toggle_backpack()
    await shot("11_inventory_wide")
    world.queue_free()
    world=null
    await frames(10)
    await create_timer(0.6).timeout
    for suffix in ["",".tmp",".bak"]:DirAccess.remove_absolute(ProjectSettings.globalize_path("user://inscription_showcase.json"+suffix))
    print("INSCRIPTION_CAPTURE_PASS isolated_showcase_progress=true")
    quit()
