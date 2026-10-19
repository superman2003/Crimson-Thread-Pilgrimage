extends SceneTree
## Real-GL review captures: the map seller offering the quill and compass, and
## the region map before and after equipping the compass. Fixture: sets the
## wallet and map ownership directly; not a natural run.
const JOURNAL := preload("res://scripts/pilgrimage_cartography.gd")
const RUNTIME := preload("res://scripts/cartography_runtime.gd")
const SAVE := "user://capture_survey_tools.json"
var output := ""

func _initialize() -> void: call_deferred("run")

func shot(name: String) -> void:
    for i in 3: await process_frame
    await RenderingServer.frame_post_draw
    # Same names and format as the committed evidence.
    root.get_texture().get_image().save_webp(output.path_join(name + ".webp"), true, 0.85)

func run() -> void:
    root.size = Vector2i(1280, 720)
    output = ProjectSettings.globalize_path("res://../artifacts/survey_tools")
    DirAccess.make_dir_recursive_absolute(output)
    for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
    var world = load("res://scenes/World.tscn").instantiate()
    world.world_resume = false
    world.world_save_path = SAVE
    root.add_child(world)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(world)
    world.set_process(false)
    world.player.set_physics_process(false)
    for enemy in get_nodes_in_group("enemy"): enemy.set_physics_process(false)
    var stall: Area2D = world.get_node("npc_gear_cartographer")
    world.player.global_position = stall.global_position
    world.currency_count = 60
    RUNTIME.open_shop(world, stall)
    await shot("seller_offers_quill_and_compass")
    world._close_overlays()
    var region := String(world.config.id)
    JOURNAL.region(world.story_flags, region).owned = true
    for room in world.config.map_rooms: JOURNAL.visit(world.story_flags, region, String(room.id))
    JOURNAL.grant_quill(world.story_flags)
    JOURNAL.rest(world.story_flags)
    world.player.global_position = world._vec2(world.config.player_start)
    world._toggle_map()
    await shot("map_without_compass")
    world.build_system.unlock_event("charm_compass_found")
    var slot: int = world.build_system.state.equipped_families.travel_accessory.find("")
    world.build_system.equip_family_slot("compass", "travel_accessory", slot)
    world._refresh_map_overlay()
    await shot("map_with_compass")
    print("SURVEY_TOOLS_CAPTURE marker_with_compass=%s" % str(world.map_draw_root.get_node_or_null("SurveyPlayerMarker") != null))
    world.queue_free()
    await process_frame
    for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
    quit(0)
