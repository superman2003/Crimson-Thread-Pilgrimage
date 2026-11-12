extends SceneTree
const GEOMETRY := preload("res://scripts/cave_rim_geometry.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const COORD := preload("res://scripts/world_coordinates.gd")
const VISIBLE_ROCK := preload("res://scripts/visible_rock_mass.gd")
var checks := 0
var failures := 0
var metrics: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(label)
## The original full-scan rim and body-trim algorithms, kept as the reference
## the indexed versions must reproduce exactly (same pieces, same order).
func reference_exposed(rects: Array[Rect2]) -> Array[Dictionary]:
    var edges: Array[Dictionary] = []
    for index in range(rects.size()):
        var rect := rects[index]
        for ceiling in [false,true]:
            var y := rect.end.y if ceiling else rect.position.y
            var probe := y + (0.05 if ceiling else -0.05)
            var spans: Array = [Vector2(rect.position.x,rect.end.x)]
            for other_index in range(rects.size()):
                if other_index == index: continue
                var other := rects[other_index]
                var other_y := other.end.y if ceiling else other.position.y
                if (probe > other.position.y and probe < other.end.y) or (other_index < index and is_equal_approx(other_y,y)):
                    spans = GEOMETRY.subtract_span(spans,Vector2(other.position.x,other.end.x))
                if spans.is_empty(): break
            for span in spans:
                if span.y-span.x > 0.1:
                    edges.append({"left":Vector2(span.x,y),"right":Vector2(span.y,y),"ceiling":ceiling,"depth":minf(96,rect.size.y*0.5)})
    edges.sort_custom(func(a,b):
        if a.ceiling != b.ceiling: return not a.ceiling
        if a.left.y != b.left.y: return a.left.y < b.left.y
        return a.left.x < b.left.x)
    var merged: Array[Dictionary] = []
    for edge in edges:
        if not merged.is_empty():
            var previous: Dictionary = merged[-1]
            if previous.ceiling == edge.ceiling and is_equal_approx(previous.left.y,edge.left.y) and is_equal_approx(previous.right.x,edge.left.x):
                previous.right = edge.right
                previous.depth = minf(previous.depth,edge.depth)
                continue
        merged.append(edge.duplicate())
    return merged

func reference_body(rects: Array[Rect2], edges: Array[Dictionary]) -> Array[Rect2]:
    var body: Array[Rect2] = rects.duplicate()
    for edge in edges:
        var inset := minf(12,float(edge.depth)*0.25)
        var cut := Rect2(edge.left-Vector2(0,inset if edge.ceiling else 0),Vector2(edge.right.x-edge.left.x,inset))
        var remaining: Array[Rect2] = []
        for rect in body: remaining.append_array(GEOMETRY.subtract_rect(rect,cut))
        body = remaining
    return body

func same_geometry(rects: Array[Rect2], label: String) -> void:
    var expected_edges := reference_exposed(rects)
    var mass := VISIBLE_ROCK.new()
    root.add_child(mass)
    mass.configure(rects, null)
    check(str(mass.rim_descriptors) == str(expected_edges), label + " indexed rims equal the full scan (%d edges)" % expected_edges.size())
    check(str(mass.body_rects) == str(reference_body(rects, expected_edges)), label + " indexed body trim equals the full scan (%d pieces)" % mass.body_rects.size())
    # W00: the geometry is split over two build jobs and kept for revisits.
    var again := VISIBLE_ROCK.new()
    root.add_child(again)
    again.prepare(rects, null)
    check(again.geometry_ready() == rects.is_empty(), label + " prepare leaves a second build job only for nonempty rocks")
    var reused: bool = is_same(again.rim_descriptors, mass.rim_descriptors) and is_same(again.body_rects, mass.body_rects) and is_same(again.rim_chunks, mass.rim_chunks)
    check(reused or rects.is_empty(), label + " a second build of the same rects reuses the stored geometry")
    again.finish()
    check(again.geometry_ready() and str(again.rim_descriptors) == str(expected_edges) and str(again.body_rects) == str(mass.body_rects) and again.rim_chunks.size() == mass.rim_chunks.size(), label + " reused geometry equals the first build")
    var moved: Array[Rect2] = []
    for rect in rects: moved.append(Rect2(rect.position + Vector2(64, 0), rect.size))
    var other := VISIBLE_ROCK.new()
    root.add_child(other)
    other.configure(moved, null)
    check(rects.is_empty() or not is_same(other.body_rects, mass.body_rects), label + " different rects never share stored geometry")
    check(str(other.rim_descriptors) == str(reference_exposed(moved)), label + " shifted rects still equal the full scan")
    other.free()
    again.free()
    mass.free()

func run() -> void:
    # These different rock lists collide under the pinned Godot 4.6 hash, and
    # have the same length and first rect: neither check proves cache identity.
    var collision_a: Array[Rect2] = [Rect2(0, 0, 80, 80), Rect2(15328, 12636, 32, 32)]
    var collision_b: Array[Rect2] = [Rect2(0, 0, 80, 80), Rect2(7445, 17780, 32, 32)]
    check(hash(collision_a) == hash(collision_b), "fixture exercises a complete-list hash collision")
    same_geometry(collision_a, "hash collision first")
    same_geometry(collision_b, "hash collision second")
    same_geometry(collision_a, "hash collision return")
    same_geometry([], "empty rock list")
    var cave_timing := {}
    var loader = preload("res://scripts/world_region_loader.gd")
    loader._record_background_job(cave_timing, "_background_cave", 110)
    loader._record_background_job(cave_timing, "_background_cave_surface", 170)
    check(cave_timing.background_cave_usec == 280 and cave_timing.background_cave_edges_usec == 110 and cave_timing.background_cave_surface_usec == 170, "cave timing preserves the combined cost and both split jobs")
    loader._record_background_job(cave_timing, "_background_art", 50)
    check(cave_timing.background_cave_usec == 280 and cave_timing.background_art_usec == 50, "other background work does not change the cave total")
    # T03: rim/body geometry is indexed; it must match the original algorithm on
    # every authored region and on overlapping/touching/duplicate/oversized rects.
    for id in COORD.manifest().regions:
        var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROUTES.config_path(id)))
        var authored: Array[Rect2] = []
        for value in raw.get("cave_world", {}).get("solid_rects", []):
            authored.append(Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3])))
        same_geometry(authored, id)
    var random := RandomNumberGenerator.new()
    random.seed = 20261102
    for trial in 6:
        var fuzz: Array[Rect2] = []
        for index in 90:
            var position := Vector2(random.randi_range(-12, 12) * 128.0, random.randi_range(-8, 8) * 96.0) + Vector2(random.randi_range(0, 3) * 16.0, 0)
            var size := Vector2(random.randi_range(1, 14) * 64.0, random.randi_range(1, 6) * 48.0)
            if index % 17 == 0 and not fuzz.is_empty(): fuzz.append(fuzz[random.randi_range(0, fuzz.size() - 1)])
            elif index % 23 == 0: fuzz.append(Rect2(position, Vector2(4096, 40)))
            else: fuzz.append(Rect2(position, size))
        same_geometry(fuzz, "fuzz %d" % trial)
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
        var job_names: Array = []
        for job in scene._region_build_jobs(): job_names.append(String(job.method))
        var cave_job := job_names.find("_background_cave")
        check(cave_job >= 0 and cave_job + 1 < job_names.size() and job_names[cave_job + 1] == "_background_cave_surface", id+" the painted rock's second half is the build job right after the cave")
        check(mass.geometry_ready(), id+" arrives with the painted rock finished")
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
        var covered_rooms := 0
        var peak := 0
        var terrain_rims := 0
        for room in scene.config.map_rooms:
            var r: Array = room.get("layout_rect",[])
            if r.size()!=4: continue
            scene.player.position = Vector2(r[0]+r[2]*0.5,r[1]+r[3]*0.5)
            # The fixture teleports with processing disabled. Use the arrival
            # path so room bounds and interpolation describe this room's view.
            scene.player.reset_camera_after_arrival()
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
