extends SceneTree
## Real graphical viewport capture. All grants/positioning are showcase fixtures.
const CROWN_SOURCE_SHA := "75bf220cb3079181e8ffd715bf571eca6764662724a6db4641d71be38290652b"
const SAVE := "user://current_showcase_20261015.json"
const ROUTES := preload("res://scripts/world_routes.gd")
const CARTOGRAPHY := preload("res://scripts/pilgrimage_cartography.gd")
var output := ""
var world: Node
var records: Array[Dictionary] = []
var label: Label
var fixture_layer: CanvasLayer

func _initialize() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--capture-output="): output = argument.trim_prefix("--capture-output=")
    call_deferred("capture")

func frames(count: int = 8) -> void:
    for unused in count:
        for actor in get_nodes_in_group("enemy"): actor.process_mode = Node.PROCESS_MODE_DISABLED
        await process_frame

func spawn(region: String, point: Vector2 = Vector2.INF) -> void:
    world = load("res://scenes/World.tscn").instantiate()
    world.world_resume = false
    world.world_save_path = SAVE
    world.config_path = "res://data/" + region + ".json"
    if point.is_finite():
        world.entry_spawn_override_enabled = true
        world.entry_spawn_override = point
    root.add_child(world)
    current_scene = world
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(world)
    world.set_process(false)
    world.player.set_physics_process(false)
    for table in ["crests", "skills", "tools", "passives"]:
        for item in world.build_system.catalog[table].values(): world.story_flags[String(item.unlock_flag)] = true
    for ability in world.WORLD_ABILITIES: world.inventory_counts[String(ability)] = 1
    world.currency_count = 120
    world.inventory_counts["moss_chitin"] = 10
    world.inventory_counts["wet_chitin"] = 10
    world._sync_player_build()
    world.build_system.select_skill("cleave", 0)
    world.build_system.select_skill("needle", 1)
    world.build_system.select_tool("shard", 0)
    world.build_system.select_tool("mine", 1)
    world.build_system.equip_passives(["reflux", "stride"])
    world.build_system.refill_tools(true)
    world._sync_player_build()
    world._refresh_hud()
    world.ui_shell.toast.text = ""
    await frames()

func position_player(point: Vector2) -> void:
    world.player.global_position = point
    world.player.velocity = Vector2.ZERO
    world.world_platforms.warm(world, point)
    world.cave_world.warm_collision_focus(point)
    world.chapter_terrain.warm_focus(point)
    world.player.reset_camera_after_arrival()
    world.player.set_physics_process(true)
    await frames(35)
    world.player.set_physics_process(false)
    world.player.reset_camera_after_arrival()
    await frames(10)

func shot(name: String, description: String) -> bool:
    label.text = "SHOWCASE | GRANTED GEAR + MATERIALS / POSITIONED PLAYER / ENEMIES PAUSED"
    world.ui_shell.toast.text = ""
    world.ui_shell.toast_age = 10.0
    await frames(10)
    await RenderingServer.frame_post_draw
    var viewport_image := root.get_texture().get_image()
    if viewport_image.get_size() != Vector2i(1280, 720):
        push_error("Unexpected showcase viewport size")
        quit(1)
        return false
    var path := output.path_join(name + ".webp")
    var quality := 0.9
    var bytes := 0
    while quality >= 0.55:
        if viewport_image.save_webp(path, true, quality) != OK:
            push_error("Cannot save showcase " + name)
            quit(1)
            return false
        bytes = FileAccess.get_file_as_bytes(path).size()
        if bytes < 250000: break
        quality -= 0.05
    if bytes >= 250000:
        push_error("Showcase exceeds image byte budget: " + name)
        quit(1)
        return false
    var camera: Camera2D = world.player.get_node("Camera2D")
    records.append({"file": name + ".webp", "description": description, "region": String(world.config.id),
        "overlay": world.active_overlay, "build_page": world.ui_shell.build_category, "build_family": world.ui_shell.build_family,
        "world_map": world.world_map_view, "save_fixture": SAVE, "fixture_grants": true,
        "fixture_positioning": true, "enemies_paused": true, "player_position": [world.player.position.x, world.player.position.y],
        "camera_position": [camera.get_screen_center_position().x, camera.get_screen_center_position().y],
        "camera_room": String(world.player.room_camera.current.get("id", "")), "dimensions": [1280, 720],
        "authored_config_sha256": FileAccess.get_sha256(world.config_path),
        "workshop_gate_locked": world.locked_gate_bodies.has("upgrade_crown_resonance_3_action_gate"),
        "renderer": RenderingServer.get_video_adapter_name(), "bytes": bytes, "webp_lossy_quality": quality,
        "sha256": FileAccess.get_sha256(path), "frame_post_draw": true})
    print("SHOWCASE_IMAGE ", name, " bytes=", bytes)
    return true

func crown_source_current() -> bool:
    if FileAccess.get_sha256("res://data/demo_ch06_silent_crown_core.json") == CROWN_SOURCE_SHA: return true
    push_error("CH06 showcase source changed from 3841ae1; capture rejected")
    quit(1)
    return false

func capture() -> void:
    if output.is_empty() or DisplayServer.get_name() == "headless":
        push_error("Showcase requires graphical GL and --capture-output=absolute-path")
        quit(1)
        return
    if not crown_source_current(): return
    DirAccess.make_dir_recursive_absolute(output)
    root.size = Vector2i(1280, 720)
    fixture_layer = CanvasLayer.new()
    fixture_layer.layer = 110
    root.add_child(fixture_layer)
    var strip := ColorRect.new()
    strip.position = Vector2.ZERO
    strip.size = Vector2(1280, 24)
    strip.color = Color(0.025, 0.04, 0.045, 0.94)
    fixture_layer.add_child(strip)
    label = Label.new()
    label.position = Vector2(85, 2)
    label.size = Vector2(1110, 22)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 14)
    label.add_theme_color_override("font_color", Color("ffd580"))
    fixture_layer.add_child(label)
    await spawn("demo_ch01_moss_bell_court")
    var shrine: Area2D
    for child in world.get_children():
        if child is Area2D and String(child.get_meta("kind", "")) == "save_point":
            shrine = child
            break
    if not is_instance_valid(shrine):
        push_error("Showcase shrine missing")
        quit(1)
        return
    await position_player(shrine.global_position)
    if not await shot("world_hud", "Current World HUD near the authored shrine"): return
    world._toggle_build()
    world.ui_shell.build_category = "铭饰"
    world.ui_shell.build_family = "travel_accessory"
    world.ui_shell.build_selection = "stride"
    world.ui_shell.refresh_build()
    if not await shot("travel_slots", "Four-family summary and travel-accessory slot page"): return
    world.ui_shell.build_category = "战具"
    world.build_system.state.tool_counts["shard"] = 0
    world.build_system.state.tool_counts["mine"] = 0
    world.ui_shell.refresh_build()
    world.ui_shell._preview_tool_resupply()
    if not bool(world.ui_shell.resupply_quote.get("ok", false)):
        push_error("Showcase paid resupply quote is unavailable")
        quit(1)
        return
    if not await shot("tools_quote", "Actual shrine paid-resupply quote; no purchase asserted"): return
    world._close_overlays()
    for id in ROUTES.cached_chapters():
        var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROUTES.cached_config_path(String(id))))
        CARTOGRAPHY.region(world.story_flags, String(id)).owned = true
        for room in raw.get("map_rooms", []): CARTOGRAPHY.visit(world.story_flags, String(id), String(room.id))
    CARTOGRAPHY.rest(world.story_flags)
    world._toggle_map()
    world.world_map_view = true
    world._refresh_map_overlay()
    if not await shot("world_map", "Campaign map with fixture-owned and charted regional maps"): return
    world.free()
    await frames()
    if not crown_source_current(): return
    await spawn("demo_ch06_silent_crown_core", Vector2(2960, 660))
    await position_player(Vector2(2960, 660))
    if not await shot("crown_hud", "Sixth region at authored crown antechamber fixture position"): return
    await position_player(Vector2(6082, 528))
    if not await shot("practice", "Authored crown-resonance workshop, action seal intact"): return
    if not crown_source_current(): return
    world.free()
    world = null
    await frames(12)
    for suffix in ["", ".tmp", ".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))
    var sources := {}
    for script in ["main_level.gd", "world_state.gd", "world_region_loader.gd", "pilgrimage_interface.gd", "capture_current_showcase.gd"]:
        sources[script] = FileAccess.get_sha256("res://scripts/" + script)
    var manifest := {"source_revision": "3841ae1", "engine": Engine.get_version_info(), "dimensions": [1280, 720],
        "method": "real GL viewport after RenderingServer.frame_post_draw; direct lossy WebP encoding; no compositing",
        "fixture": "isolated user:// save; granted equipment/materials/abilities/maps; positioned player; paused enemies",
        "save_fixture_cleaned": not FileAccess.file_exists(SAVE), "crown_config_sha256_before_and_after": CROWN_SOURCE_SHA, "sources_sha256": sources, "screenshots": records}
    var handle := FileAccess.open(output.path_join("manifest.json"), FileAccess.WRITE)
    handle.store_string(JSON.stringify(manifest, "  "))
    handle.close()
    print("CURRENT_SHOWCASE_CAPTURE_PASS screenshots=6 width=1280 height=720")
    quit(0)
