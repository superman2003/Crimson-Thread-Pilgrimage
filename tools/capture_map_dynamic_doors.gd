extends SceneTree
## Real-GL review captures for the map's shortcut state and pin clustering.
## Fixture: grants map ownership/charting and places pins directly; not a
## natural exploration run.
## Run: godot --display-driver x11 --rendering-method gl_compatibility
##      --path godot --script res://../tools/capture_map_dynamic_doors.gd
const JOURNAL := preload("res://scripts/pilgrimage_cartography.gd")
const PINS := preload("res://scripts/map_player_pins.gd")
const SAVE := "user://capture_map_dynamic_doors.json"
var output := ""

func _initialize() -> void: call_deferred("run")

func shot(name: String) -> void:
    for i in 3: await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(output.path_join(name + ".png"))

func run() -> void:
    root.size = Vector2i(1280, 720)
    output = ProjectSettings.globalize_path("res://../artifacts/map_dynamic_doors")
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
    var region := String(world.config.id)
    var journal := JOURNAL.region(world.story_flags, region)
    journal.owned = true
    for room in world.config.map_rooms: journal.charted[String(room.id)] = true
    # Three pins in neighbouring rooms: apart on the region map, one point on the overview.
    var configs := {region: world.config}
    var lever: Dictionary = {}
    for item in world.config.interactives:
        if String(item.get("shortcut_id", "")) != "": lever = item
    # Pins in the starting area, away from the lever, so both markers stay readable.
    var base: Vector2 = world.player.global_position
    for index in 3:
        var result := PINS.add(world.story_flags, configs, region, base + Vector2(index * 90, -10), PINS.KINDS[index])
        if result.ok: world.story_flags[PINS.KEY] = result.records
    world._toggle_map()
    await shot("region_shortcut_closed")
    world.opened_shortcuts[String(lever.shortcut_id)] = true
    world._refresh_map_overlay()
    await shot("region_shortcut_open")
    world.world_map_view = true
    world._refresh_map_overlay()
    world.survey_map_view.magnify(1.6, world.map_draw_root.get_node("PlayerMapPin_1").get_meta("map_anchor"))
    world._refresh_map_overlay()
    await shot("overview_pins_clustered")
    var clustered := 0
    for child in world.map_draw_root.get_children():
        if String(child.name).begins_with("PlayerMapPin_") and int(child.get_meta("cluster_size", 1)) > 1: clustered += 1
    print("MAP_DYNAMIC_DOORS_CAPTURE region=%s lever=%s clustered_pins=%d" % [region, lever.get("shortcut_id", ""), clustered])
    world.queue_free()
    await process_frame
    for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
    quit(0)
