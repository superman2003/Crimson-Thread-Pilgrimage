extends SceneTree
const COORDINATES := preload("res://scripts/world_coordinates.gd")
const WORLD := preload("res://scripts/world_state.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const PATH := "user://world_coordinates_validation.json"
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
    var regions: Dictionary = COORDINATES.manifest().regions
    var routes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROUTES.ROUTES_PATH)).chapters
    _check(regions.size() == 6 and regions.keys() == routes.keys(), "layout covers exactly the campaign regions")
    var detached := COORDINATES.manifest()
    detached.regions.clear()
    _check(COORDINATES.manifest().regions.size() == 6, "callers cannot change cached origins")
    for region_id in regions:
        var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROUTES.config_path(region_id)))
        config = ROUTES.apply_to(config)
        var bounds := COORDINATES.region_bounds(region_id)
        _check(bounds.size == Vector2(config.world.width, config.world.height), "extent matches authored world " + region_id)
        for peer_id in regions:
            if peer_id != region_id:
                _check(not bounds.intersects(COORDINATES.region_bounds(peer_id)), "regions do not overlap " + region_id + "/" + peer_id)
        for room in config.get("map_rooms", []):
            var rect: Array = room.get("layout_rect", [])
            _check(rect.size() == 4, "room has authored physical bounds " + str(room.id))
            if rect.size() != 4:
                continue
            for local_point in [Vector2(rect[0], rect[1]), Vector2(rect[0] + rect[2], rect[1] + rect[3])]:
                _check(COORDINATES.to_local(region_id, COORDINATES.to_world(region_id, local_point)) == local_point, "room conversion " + str(room.id))
        for portal in routes[region_id].get("portals", []):
            var source := Vector2(portal.position[0], portal.position[1])
            var target := Vector2(portal.target_spawn[0], portal.target_spawn[1])
            var target_id := String(portal.target_config_id)
            _check(COORDINATES.to_local(region_id, COORDINATES.to_world(region_id, source)) == source, "source portal " + str(portal.id))
            _check(COORDINATES.to_local(target_id, COORDINATES.to_world(target_id, target)) == target, "destination portal " + str(portal.id))
        _migration_checks(region_id)
    _check(not COORDINATES.to_world("missing", Vector2.ZERO).is_finite(), "unknown region cannot silently use identity coordinates")
    _clean()
    if failures.is_empty():
        print("WORLD COORDINATES PASS: %d checks; six fixed origins, all room/portal transforms, v1/v2 migration and transactional v3 saves" % checks)
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)

func _migration_checks(region_id: String) -> void:
    _clean()
    var entry := Vector2(330, 720)
    for version in [1, 2]:
        var old := WORLD.fresh_data()
        old.version = version
        old.erase("world_location")
        old.current_region = region_id
        old.entry = [entry.x, entry.y]
        old.currency = 47
        old.inventory_counts = {"echo_hook": 1}
        old.story_flags = {"cartography_v1": {region_id: {"owned": true, "charted": {"room": true}, "pending": {"secret": true}}}}
        old.regions[region_id] = WORLD.fresh_region()
        old.regions[region_id].checkpoint = [500, 600]
        old.build_state = {"selected": "test"}
        old.death_cache = {"region_id": region_id, "position": [200, 600], "currency": 3}
        if version == 1:
            old.erase("build_state")
            old.erase("death_cache")
        var original := JSON.stringify(old)
        _put(original)
        var world := WORLD.new()
        _check(world.read(PATH), "read v%d %s" % [version, region_id])
        _check(FileAccess.get_file_as_string(PATH) == original, "migration read never writes source")
        _check(world.data.version == WORLD.VERSION and world.resume_local_position() == entry, "resume migrated checkpoint")
        _check(world.data.currency == 47 and world.data.inventory_counts == old.inventory_counts and world.data.story_flags == old.story_flags, "migration retains currency, abilities and map journal")
        _check(_same_json(world.data.regions, old.regions), "migration retains region progress")
        if version == 2:
            _check(_same_json(world.data.build_state, old.build_state) and _same_json(world.data.death_cache, old.death_cache), "migration retains build and recovery")
        _check(world.checkpoint_world_position(region_id) == COORDINATES.to_world(region_id, Vector2(500, 600)), "world checkpoint uses region origin")
        _check(world.write(PATH), "install v3 atomically")
        _check(FileAccess.get_file_as_string(PATH + ".bak") == original, "retain exact pre-migration backup")
        var reboot := WORLD.new()
        _check(reboot.read(PATH) and reboot.resume_local_position() == entry, "v3 restart roundtrip")
        var before := reboot.data.duplicate(true)
        var mismatched: Dictionary = before.world_location.duplicate(true)
        mismatched.position[0] += 1
        _check(not reboot.capture_global({"world_location": mismatched}) and reboot.data == before, "mismatched local/global location rejected transactionally")
        mismatched = before.world_location.duplicate(true)
        mismatched.layout_version = 999
        _check(not reboot.capture_global({"world_location": mismatched}), "future layout rejected")
        mismatched.layout_version = true
        _check(not reboot.capture_global({"world_location": mismatched}), "boolean layout version rejected")
        mismatched = before.world_location.duplicate(true)
        mismatched.region_id = "missing"
        _check(not reboot.capture_global({"world_location": mismatched}), "wrong region rejected")
        _check(reboot.capture_global({"entry": Vector2(700, 800)}), "local checkpoint update derives global location")
        _check(reboot.resume_local_position() == Vector2(700, 800), "updated local/global pair agrees")
        var corrupt := before.duplicate(true)
        corrupt.world_location.position[0] += 5
        _put(JSON.stringify(corrupt))
        _check(not reboot.read(PATH), "inconsistent disk coordinates rejected")
        _check(not reboot.write(PATH), "invalid source cannot replace preserved backup")

func _put(contents: String) -> void:
    var file := FileAccess.open(PATH, FileAccess.WRITE)
    file.store_string(contents)
    file.close()

func _same_json(left: Variant, right: Variant) -> bool:
    return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))

func _clean() -> void:
    for suffix in ["", ".tmp", ".bak"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + suffix))

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)
