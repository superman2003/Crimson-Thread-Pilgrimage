extends SceneTree
const GEOMETRY := preload("res://scripts/cave_rim_geometry.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const COORD := preload("res://scripts/world_coordinates.gd")
var checks := 0
var failures := 0
var metrics: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(label)
func run() -> void:
    var stack: Array[Rect2] = [Rect2(0,0,100,40),Rect2(0,40,100,40)]
    var edges := GEOMETRY.exposed(stack)
    check(edges.size()==2,"stacked rocks have only two exterior horizontal rims")
    var adjacent: Array[Rect2] = [Rect2(0,0,100,40),Rect2(100,0,100,40)]
    edges = GEOMETRY.exposed(adjacent)
    check(edges.size()==2 and edges[0].right.x-edges[0].left.x==200,"adjacent rock edges merge without internal joins")
    var duplicate: Array[Rect2] = [Rect2(0,0,100,40),Rect2(0,0,100,40)]
    check(GEOMETRY.exposed(duplicate).size()==2,"overlapping duplicate rectangles do not duplicate rims")
    root.process_mode = Node.PROCESS_MODE_DISABLED
    for id in COORD.manifest().regions:
        var scene: Node = load("res://scenes/World.tscn").instantiate()
        scene.world_resume = false
        scene.world_save_path = "user://world_rim_fixture.json"
        root.add_child(scene)
        await preload("res://scripts/world_ready_validation_helper.gd").wait_for(scene)
        if String(scene.config.id)!=id:
            var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROUTES.config_path(id)))
            scene._travel_world(ROUTES.config_path(id),Vector2(config.player_start[0],config.player_start[1]))
        scene.set_process(false)
        scene.player.set_physics_process(false)
        for enemy in get_nodes_in_group("enemy"): enemy.set_physics_process(false)
        var mass: Node = scene.cave_world.get_node("PaintedRockMass")
        var count: int = scene.cave_world.get_node("SolidCaveMass").get_child_count()
        check(not mass.rim_chunks.is_empty(),id+" exposed floor/ceiling descriptors installed")
        var ceiling_count := 0
        for edge in mass.rim_descriptors:
            ceiling_count += int(edge.ceiling)
            var mid: Vector2 = edge.left.lerp(edge.right,0.5)
            var outside := mid+Vector2(0,0.05 if edge.ceiling else -0.05)
            var inside := mid-Vector2(0,0.05 if edge.ceiling else -0.05)
            check(not scene.cave_world.intersects_rect(Rect2(outside-Vector2(0.001,0.001),Vector2(0.002,0.002))),id+" rim faces air rather than another solid")
            check(scene.cave_world.intersects_rect(Rect2(inside-Vector2(0.001,0.001),Vector2(0.002,0.002))),id+" rim has authoritative rock support")
        check(ceiling_count>0 and ceiling_count<mass.rim_descriptors.size(),id+" independent top and bottom art present")
        var camera: Camera2D = scene.player.get_node("Camera2D")
        var covered_rooms := 0
        var peak := 0
        var terrain_rims := 0
        for room in scene.config.map_rooms:
            var r: Array = room.get("layout_rect",[])
            if r.size()!=4: continue
            scene.player.position = Vector2(r[0]+r[2]*0.5,r[1]+r[3]*0.5)
            camera.reset_smoothing()
            camera.force_update_scroll()
            await process_frame
            await process_frame
            mass._refresh_view()
            scene.chapter_terrain.refresh_visual_chunks(mass.view_bounds,true)
            scene.world_platforms.warm(scene,scene.player.global_position)
            for key in scene.chapter_terrain.resident_chunks:
                var chunk: Node = scene.chapter_terrain.resident_chunks[key]
                var authored := 0
                for face in chunk.get_children():
                    if face.has_meta("independent_edge_art"): authored += 1
                check(authored==scene.chapter_terrain.visual_chunks[key].faces.size(),id+" resident slope chunk has every independent rim")
                terrain_rims += authored
            var expected := 0
            for key in mass.rim_chunks:
                if mass.rim_chunks[key].bounds.intersects(mass.view_bounds):
                    expected += 1
                    check(mass.resident_rims.has(key),id+":"+String(room.id)+" visible authored rim resident")
            if expected>0: covered_rooms += 1
            peak = maxi(peak,mass.resident_rims.size())
            for key in mass.resident_rims:
                check(mass.rim_chunks[key].bounds.intersects(mass.view_bounds.grow(384)),id+" distant edge nodes retire")
        check(scene.cave_world.get_node("SolidCaveMass").get_child_count()==count,id+" visual room sweep preserves collision")
        check(terrain_rims>0,id+" authored slope/terrain floor edges installed")
        var platform_count := 0
        for data in scene.config.platforms:
            if data.has("terrain_id"): continue
            var platform: Node = scene.get_node_or_null(String(data.id))
            if platform==null: continue
            if platform.has_node("AuthoredFloor"):
                platform_count += 1
                check(platform.has_node("AuthoredCeiling"),id+" stone ledge also has independent underside")
        check(platform_count>0,id+" stone platform rims installed")
        metrics.append({"region":id,"room_views":scene.config.map_rooms.size(),"views_with_cave_rims":covered_rooms,"cave_edges":mass.rim_descriptors.size(),"rim_chunks":mass.rim_chunks.size(),"peak_resident_rims":peak,"terrain_rims":terrain_rims,"stone_platforms":platform_count})
        scene.free()
        await process_frame
    print("WORLD_RIM_METRICS ",JSON.stringify(metrics))
    print("WORLD_RIMS checks=%d failures=%d" % [checks,failures])
    quit(1 if failures else 0)
