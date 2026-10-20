extends RefCounted
## Frozen pre-optimization search is an oracle for positions and first-winner
## ties. Actual six-region overlays use production polygon/rock descriptors.
const ROUTES := preload("res://scripts/world_routes.gd")
const TERRAIN := preload("res://scripts/chapter_terrain.gd")
const CAVE := preload("res://scripts/cave_world.gd")
const GEOMETRY := preload("res://scripts/world_collision_geometry.gd")
const REGIONS := ["demo_ch01_moss_bell_court", "demo_ch02_rain_foundry_canal", "demo_ch03_saltwhite_archive", "demo_ch04_broken_string_greenhouse", "demo_ch05_obsidian_pilgrim_road", "demo_ch06_silent_crown_core"]
var checks := 0
var failures := 0
var old_e04_checks := 0
var new_e04_checks := 0

class Current extends "res://scripts/main_level.gd":
    var clearance_checks := 0
    func _enemy_spawn_rect_clear(position: Vector2,width: float=36.0,height: float=104.0,floor_id: String="") -> bool:
        clearance_checks += 1
        return super._enemy_spawn_rect_clear(position,width,height,floor_id)

class Legacy extends "res://scripts/main_level.gd":
    var clearance_checks := 0
    func _enemy_spawn_rect_clear(position: Vector2,width: float=36.0,height: float=104.0,floor_id: String="") -> bool:
        clearance_checks += 1
        return super._enemy_spawn_rect_clear(position,width,height,floor_id)
    # Frozen verbatim from main af210f7f5a8b919fda002ff8fff95d1eb7d2e260.
    func _safe_enemy_spawn_on_platform(data: Dictionary, requested: Vector2, platform_id: String, rect: Rect2, clearance: float) -> Vector2:
        var half_width := float(data.get("spawn_half_width", 36.0))
        var visual_height := float(data.get("spawn_visual_height", _enemy_spawn_visual_height(data)))
        var margin := maxf(half_width + 12.0, minf(54.0, rect.size.x * 0.24))
        var min_x := rect.position.x + margin
        var max_x := rect.position.x + rect.size.x - margin
        if min_x > max_x:
            var center_x := rect.position.x + rect.size.x * 0.5
            var center_position := Vector2(center_x, rect.position.y - clearance)
            if _enemy_spawn_rect_clear(center_position, half_width, visual_height, platform_id):
                return center_position
            return _fallback_enemy_spawn_position(data, requested, clearance, platform_id)

        var requested_x := clampf(requested.x, min_x, max_x)
        var candidate_xs: Array = [
            requested_x,
            requested_x - 70.0,
            requested_x + 70.0,
            requested_x - 140.0,
            requested_x + 140.0,
            min_x,
            max_x,
            rect.position.x + rect.size.x * 0.5
        ]
        var best_position := Vector2(requested_x, rect.position.y - clearance)
        var best_score := INF
        for candidate_value in candidate_xs:
            var x := clampf(float(candidate_value), min_x, max_x)
            var position_value := Vector2(x, rect.position.y - clearance)
            if not _enemy_spawn_rect_clear(position_value, half_width, visual_height, platform_id):
                continue
            var score := absf(x - requested.x)
            if score < best_score:
                best_score = score
                best_position = position_value
        if best_score < INF:
            return best_position
        return _fallback_enemy_spawn_position(data, requested, clearance, platform_id)


    func _fallback_enemy_spawn_position(data: Dictionary, requested: Vector2, clearance: float, preferred_platform_id: String = "") -> Vector2:
        var half_width := float(data.get("spawn_half_width", 36.0))
        var visual_height := float(data.get("spawn_visual_height", _enemy_spawn_visual_height(data)))
        var requested_top := requested.y + clearance
        var best_position := requested
        var best_score := INF
        for platform in config.get("platforms", []):
            if not (platform is Dictionary):
                continue
            var platform_data: Dictionary = platform
            var platform_id := String(platform_data.get("id", ""))
            var rect := _rect2(platform_data.get("rect", []))
            if not _enemy_spawn_platform_allowed(platform_id, rect):
                continue
            var margin := maxf(half_width + 12.0, minf(54.0, rect.size.x * 0.24))
            var min_x := rect.position.x + margin
            var max_x := rect.position.x + rect.size.x - margin
            if min_x > max_x:
                continue
            var candidate_xs: Array = [
                clampf(requested.x, min_x, max_x),
                rect.position.x + rect.size.x * 0.5,
                min_x,
                max_x
            ]
            var step := maxf(44.0, half_width * 1.5)
            var scan_x := min_x
            while scan_x <= max_x + 0.5:
                candidate_xs.append(scan_x)
                scan_x += step
            for candidate_value in candidate_xs:
                var x := clampf(float(candidate_value), min_x, max_x)
                var position_value := Vector2(x, rect.position.y - clearance)
                if not _enemy_spawn_rect_clear(position_value, half_width, visual_height, platform_id):
                    continue
                var platform_bias := 0.0 if platform_id == preferred_platform_id else 220.0
                var score := absf(rect.position.y - requested_top) * 1.8 + absf(x - requested.x) * 0.35 + platform_bias
                if score < best_score:
                    best_score = score
                    best_position = position_value
        if best_score >= INF:
            push_warning("No clear enemy spawn found for " + String(data.get("id", "enemy")) + "; check platform geometry.")
        return best_position

func check(ok: bool,label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("SPAWN_SEARCH: "+label)

func compare(config: Dictionary,probes: Array,label: String) -> void:
    var current := Current.new()
    var legacy := Legacy.new()
    var terrain := TERRAIN.new()
    for landform in config.get("terrain",[]):
        var surface: Array=landform.get("surface",[])
        if surface.size()<2: continue
        var spans := GEOMETRY.terrain_spans(config,String(landform.id),surface)
        for section in GEOMETRY.terrain_sections(surface,float(landform.get("depth",104)),spans):
            terrain.collision_regions.append(section)
    var cave := CAVE.new()
    for value in config.get("cave_world",{}).get("solid_rects",[]):
        cave.solid_rects.append(Rect2(value[0],value[1],value[2],value[3]))
    for scene in [current,legacy]:
        scene.config=config
        scene.chapter_terrain=terrain
        scene.cave_world=cave
    for probe in probes:
        current.clearance_checks=0
        legacy.clearance_checks=0
        var actual: Vector2=current._resolve_enemy_spawn_position(probe)
        var expected: Vector2=legacy._resolve_enemy_spawn_position(probe)
        check(actual==expected,label+" exact spawn including original score ties: "+String(probe.get("id","")))
        check(current._platform_under_position(actual,float(probe.get("clearance",40)))==legacy._platform_under_position(expected,float(probe.get("clearance",40))),label+" same supporting platform")
        if label==REGIONS[1] and String(probe.get("id",""))=="E04":
            old_e04_checks=legacy.clearance_checks
            new_e04_checks=current.clearance_checks
            check(actual==Vector2(3345,2130),"authored bell mote keeps its original fallback ground anchor")
        if probe.has("expected"):
            var authored: Array=probe.expected
            check(actual==Vector2(authored[0],authored[1]),"explicit first-winner fixture: "+String(probe.id))
    # Exercise the fallback entry point with and without preferred-floor bias.
    if not probes.is_empty():
        var probe: Dictionary=probes[0]
        var requested: Vector2=current._vec2(probe.get("position",[0,0]))
        for preferred in ["",String(probe.get("platform_id",""))]:
            var clearance := float(probe.get("clearance",40))
            check(current._fallback_enemy_spawn_position(probe,requested,clearance,preferred)==legacy._fallback_enemy_spawn_position(probe,requested,clearance,preferred),label+" exhaustive fallback winner and preference bias")
    current.free()
    legacy.free()
    terrain.free()
    cave.free()

func run() -> int:
    for region in REGIONS:
        var raw: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/"+region+".json"))
        var config: Dictionary=ROUTES.apply_to(raw)
        var probes: Array=config.get("enemy_spawns",[]).duplicate(true)
        if not config.get("boss",{}).is_empty(): probes.append(config.boss)
        compare(config,probes,region)
    compare({"platforms":[{"id":"floor","rect":[0,100,300,20]},{"id":"wall","rect":[125,0,50,100]}]},[
        {"id":"blocked_center_left_tie","position":[150,60],"platform_id":"floor","expected":[80,60]},
        {"id":"nearest_safe","position":[70,60],"platform_id":"floor","expected":[70,60]}
    ],"wall fixture")
    compare({"platforms":[{"id":"left","rect":[-340,100,100,20]},{"id":"right","rect":[240,100,100,20]}]},[
        {"id":"first_equal_score","position":[0,60],"expected":[-288,60]}
    ],"score tie fixture")
    # Repeat deterministic irregular layouts; candidate ordering and blockers
    # differ while a distant safe floor prevents no-solution warning fixtures.
    var rng := RandomNumberGenerator.new()
    rng.seed=40821
    for iteration in range(24):
        var platforms: Array=[{"id":"safe","rect":[5000,1000,300,20]}]
        var probes: Array=[]
        var rocks: Array=[]
        for index in range(10):
            var x:=rng.randi_range(-900,900)
            var y:=rng.randi_range(100,700)
            var width:=rng.randi_range(90,400)
            var id:="p%d"%index
            platforms.append({"id":id,"rect":[x,y,width,24]})
            probes.append({"id":id,"position":[x+width*0.5,y-40],"platform_id":id,"spawn_half_width":rng.randf_range(12,42),"spawn_visual_height":rng.randf_range(28,110)})
            if index%3==0: rocks.append([x+width*0.25,y-150,width*0.5,150])
        compare({"platforms":platforms,"cave_world":{"solid_rects":rocks}},probes,"seeded layout %d"%iteration)
    check(old_e04_checks>0 and new_e04_checks*4<old_e04_checks,"real bell mote cuts at least 75 percent of clearance calls without changing its anchor")
    print("SPAWN_SEARCH checks=%d failures=%d old_e04_checks=%d new_e04_checks=%d"%[checks,failures,old_e04_checks,new_e04_checks])
    return failures
