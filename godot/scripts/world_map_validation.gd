extends SceneTree
const ATLAS := preload("res://scripts/world_atlas.gd")
const COORD := preload("res://scripts/world_coordinates.gd")
const SURVEY := preload("res://scripts/cartography_runtime.gd")
const JOURNAL := preload("res://scripts/pilgrimage_cartography.gd")
const SURFACE := preload("res://scripts/survey_map_surface.gd")
const TERRAIN := preload("res://scripts/chapter_terrain.gd")

var failures := 0
var checks := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)

func _run() -> void:
    # Exterior perimeter stays correct for overlaps, duplicates and holes.
    var ring: Array[Rect2] = [Rect2(0,0,20,5),Rect2(0,15,20,5),Rect2(0,5,5,10),Rect2(15,5,5,10)]
    var perimeter := 0.0
    for segment in SURFACE.boundaries(ring): perimeter += segment[0].distance_to(segment[1])
    _check(is_equal_approx(perimeter,120.0), "room union retains the enclosed empty pocket")
    var overlaps: Array[Rect2] = [Rect2(0,0,10,10),Rect2(5,0,10,10),Rect2(0,0,10,10)]
    perimeter = 0.0
    for segment in SURFACE.boundaries(overlaps): perimeter += segment[0].distance_to(segment[1])
    _check(is_equal_approx(perimeter,50.0), "overlapping and duplicate rooms have one exterior border")
    var scene: Node = load("res://scenes/World.tscn").instantiate()
    scene.world_resume = false
    scene.world_save_path = "user://world_map_validation.json"
    root.add_child(scene)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
    scene.set_process(false)
    scene.player.set_physics_process(false)
    for enemy in get_nodes_in_group("enemy"):
        enemy.set_physics_process(false)
    scene._toggle_map()
    _check(scene.active_overlay == "map" and scene.player.ui_input_locked, "map locks player movement")
    _check(scene.map_draw_root.get_node_or_null("WorldRegion_demo_ch01_moss_bell_court") == null, "local map remains initial view")
    scene.world_map_view = true
    scene._refresh_map_overlay()
    _check(scene.map_panel.get_node("SurveyMapTitle").text == "世界地图", "world atlas has a concise title")
    var panels := 0
    var edges := 0
    for child in scene.map_draw_root.get_children():
        if String(child.name).begins_with("WorldRegion_") and not String(child.name).ends_with("Border"):
            panels += 1
            _check(child.position.y + child.size.y <= scene.map_draw_root.size.y, "world panels fit above map text")
        if child is Line2D:
            edges += 1
            _check(child.points.size() == 2, "atlas edges represent actual paired endpoints")
    _check(panels == 6, "atlas contains six canonical regions")
    _check(edges == 0, "atlas does not reveal routes before buying and charting a map")
    _check(scene.map_draw_root.get_node_or_null("WorldSurveyPlayer") != null, "atlas projects the live player")
    var layout: Dictionary = scene.map_draw_root.get_meta("world_atlas_frame")
    var original_flags: Dictionary = scene.story_flags.duplicate(true)
    for id in COORD.manifest().regions:
        _check(scene.map_draw_root.get_node("WorldRegion_" + id).position.is_equal_approx(ATLAS.project(COORD.region_bounds(id).position, layout) - Vector2(0,22)), id + " title uses fixed world origin")
        var journal := JOURNAL.region(scene.story_flags, id)
        journal.owned = true
    scene._refresh_map_overlay()
    var frames: Dictionary = {}
    var hidden: Array[String] = []
    for id in COORD.manifest().regions:
        for room in ATLAS.configuration(id).map_rooms:
            var name := "WorldSurvey_" + String(id) + "_" + String(room.id)
            var ink: Control = scene.map_draw_root.get_node_or_null(name)
            if not SURVEY.public_room(room):
                _check(ink == null, name + " hidden before charting")
                hidden.append(name)
                continue
            var physical := SURVEY.room_rect(room)
            if physical.size.x <= 0 or physical.size.y <= 0: continue
            _check(ink != null, name + " purchased coarse outline exists")
            if ink == null: continue
            _check(ink.position.is_equal_approx(ATLAS.project(COORD.to_world(id, physical.position), layout)) and ink.size.is_equal_approx(physical.size * layout.scale), name + " physical bounds projected with uniform scale")
            frames[name] = Rect2(ink.position, ink.size)
    for id in COORD.manifest().regions:
        for room in ATLAS.configuration(id).map_rooms:
            JOURNAL.visit(scene.story_flags, id, String(room.id))
    scene._refresh_map_overlay()
    for name in hidden:
        _check(scene.map_draw_root.get_node_or_null(name) == null, name + " pending notes cannot reveal hidden rooms")
    JOURNAL.rest(scene.story_flags)
    scene._refresh_map_overlay()
    _check(scene.map_draw_root.get_meta("world_atlas_frame") == layout, "charting all hidden rooms leaves atlas frame fixed")
    for name in frames:
        var ink: Control = scene.map_draw_root.get_node(name)
        _check(Rect2(ink.position, ink.size) == frames[name] and ink.detailed, name + " charting changes ink without moving or scaling room")
    for name in hidden:
        _check(scene.map_draw_root.get_node_or_null(name) != null, name + " rest reveals charted hidden room")
    var physical_routes := 0
    for child in scene.map_draw_root.get_children():
        if not child is Line2D: continue
        _check(child.points[0].is_equal_approx(ATLAS.project(child.get_meta("source_world"), layout)) and child.points[1].is_equal_approx(ATLAS.project(child.get_meta("target_world"), layout)), "route ends align with actual world portals")
        if child.get_meta("physical_passage"):
            physical_routes += 1
            _check(child.get_meta("source_world").distance_to(child.get_meta("target_world")) > 8500, "pipe keeps real world length")
    _check(physical_routes == 1, "one real pipe drawn once in both directions")
    _check(not scene.map_text.text.contains("\n"), "world map instructions occupy one line")
    for child in scene.map_draw_root.get_children():
        if child is Line2D and not bool(child.get_meta("physical_passage")):
            _check(not child.visible, "abstract links stay out of the default overview")
            var source := "WorldSurvey_" + String(child.get_meta("source_region")) + "_" + String(child.get_meta("source_room"))
            var room: Control = scene.map_draw_root.get_node_or_null(source)
            if room != null:
                room.mouse_entered.emit()
                _check(child.visible, "hovering a portal room reveals its old link")
                room.mouse_exited.emit()
                _check(not child.visible, "old link disappears when leaving the room")
    var camera: Control = scene.survey_map_view
    _check(camera.clip_contents and scene.map_draw_root.get_parent() == camera, "camera clips drawing below the map header")
    var position_before: Vector2 = scene.map_draw_root.get_node("WorldSurveyPlayer").position
    camera.magnify(2.0, Vector2(300,200))
    _check(is_equal_approx(camera.zoom,2.0) and scene.map_draw_root.position.is_equal_approx(Vector2(-300,-200)), "zoom preserves the position beneath its anchor")
    _check(scene.map_draw_root.get_node("WorldSurveyPlayer").position == position_before and scene.map_draw_root.get_meta("world_atlas_frame") == layout, "zoom never modifies cartography coordinates")
    scene.map_draw_root.position = Vector2(-10000,10000)
    camera.clamp_pan()
    _check(scene.map_draw_root.position.is_equal_approx(Vector2(-scene.map_draw_root.size.x,0)), "pan stops at content edges")
    camera.reset()
    _check(camera.zoom == 1.0 and scene.map_draw_root.position == Vector2.ZERO, "reset restores the full atlas")
    # Same clipped terrain as the local hand-drawn map, without scene building.
    var descriptor_polygons := ATLAS.terrain(String(scene.config.id))
    var live_polygons := SURVEY.terrain_polygons(scene)
    _check(descriptor_polygons == live_polygons, "atlas terrain matches live local-map collision descriptors")
    for id in COORD.manifest().regions:
        var data := ATLAS.configuration(id)
        var reference := TERRAIN.new()
        root.add_child(reference)
        reference.configure(data, String(data.art_theme))
        var polygons: Array[PackedVector2Array] = []
        for region in reference.collision_regions: polygons.append(region.polygon)
        for platform in data.get("platforms", []):
            if not String(platform.get("terrain_id", "")).is_empty(): continue
            polygons.append(SURVEY.rect_polygon(scene._rect2(platform.rect)))
        _check(ATLAS.terrain(id) == polygons, id + " atlas describes authoritative terrain and ordinary platforms")
        reference.free()
    scene.story_flags = original_flags
    _check(scene.wish_panel == null or not scene.wish_panel.visible, "atlas does not overlap wish board")
    var anchor: Node2D = scene.get_node("moss_viaduct_ring")
    _check(not bool(anchor.get_meta("grapple_enabled")), "real world anchor remains locked without hook")
    scene._add_inventory_item("echo_hook", 1, false)
    scene._sync_player_abilities()
    _check(bool(anchor.get_meta("grapple_enabled")) and scene.player.thread_grapple_unlocked, "real world anchor and action unlock together")
    scene.world_map_view = false
    scene._refresh_map_overlay()
    _check(scene.map_draw_root.get_node_or_null("WorldRegion_demo_ch01_moss_bell_court") == null, "returning to local map clears atlas")
    _check(camera.zoom == 1.0 and not scene.map_text.text.contains("\n"), "local map resets camera and uses a quiet footer")
    for child in scene.map_draw_root.get_children():
        _check(not String(child.name).begins_with("SurveyLabel_") and not String(child.name).begins_with("SurveyEdge_"), "local map has no text labels or artificial center links")
    _check(scene.wish_panel == null or not scene.wish_panel.visible, "hand-drawn map keeps quest board out of paper")
    scene._close_overlays()
    _check(not scene.player.ui_input_locked, "map close returns player control")
    scene.queue_free()
    await process_frame
    for suffix in ["", ".tmp", ".bak"]:
        var path: String = "user://world_map_validation.json" + String(suffix)
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    print("WORLD_MAP checks=%d failures=%d" % [checks, failures])
    quit(1 if failures > 0 else 0)
