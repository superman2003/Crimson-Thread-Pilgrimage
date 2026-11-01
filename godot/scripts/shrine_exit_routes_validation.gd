extends SceneTree
## Replay checked-in route certificates in the real World. This is fast enough
## for default CI; exhaustive route discovery remains an on-demand audit.
const PROBE := preload("res://scripts/shrine_exit_probe.gd")
const REGIONS := ["demo_ch01_moss_bell_court", "demo_ch02_rain_foundry_canal", "demo_ch03_saltwhite_archive", "demo_ch04_broken_string_greenhouse", "demo_ch05_obsidian_pilgrim_road", "demo_ch06_silent_crown_core"]
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func tick(count: int) -> void:
    for frame in count:
        await physics_frame
        await process_frame
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(label)
func run() -> void:
    var raw = JSON.parse_string(FileAccess.get_file_as_string("res://../artifacts/shrine_exits/report.json"))
    check(raw is Dictionary and raw.get("results") is Array, "exit certificates are a valid report")
    if not raw is Dictionary or not raw.get("results") is Array:
        quit(1)
        return
    var report: Dictionary = raw
    var expected := {}
    for region in REGIONS:
        var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json" % region))
        var drops := {}
        for connection in config.get("connections", []):
            if String(connection.get("type", "")) == "one_way_drop": drops[String(connection.to)] = true
        for shrine in config.get("save_points", []):
            var room := PROBE.room_at(config, Vector2(shrine.position[0], shrine.position[1]))
            if not room.is_empty() and (String(room.get("kind", "")) in PROBE.HIDDEN_KINDS or bool(room.get("hidden", false)) or drops.has(String(room.id))):
                expected[region + "/" + String(shrine.id)] = true
    var seen := {}
    var world = load("res://scenes/World.tscn").instantiate()
    world.world_resume = false
    world.world_save_path = "user://shrine_exit_routes_validation.json"
    PROBE.disable_ability_pickups(world)
    root.add_child(world)
    await preload("res://scripts/world_ready_validation_helper.gd").wait_for(world)
    current_scene = world
    for certificate in report.results:
        var region := String(certificate.get("region", ""))
        var key := region + "/" + String(certificate.get("shrine", ""))
        check(expected.has(key) and not seen.has(key), "certificate belongs to one current risky shrine: " + key)
        seen[key] = true
        check(bool(certificate.get("replay_verified", false)) and not certificate.get("inputs", []).is_empty(), "certificate has real replay inputs: " + key)
        if not expected.has(key): continue
        var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json" % region))
        var room: Dictionary = {}
        for candidate in config.map_rooms:
            if String(candidate.id) == String(certificate.room): room = candidate
        var start := Vector2(certificate.from[0], certificate.from[1])
        var matches_start := false
        for shrine in config.save_points:
            if String(shrine.id) == String(certificate.shrine): matches_start = start.is_equal_approx(Vector2(shrine.position[0], shrine.position[1]))
        check(matches_start, "certificate starts at the actual shrine: " + key)
        world.set_process(true)
        world._travel_world("res://data/%s.json" % region, start)
        await tick(12)
        world.set_process(false)
        for enemy in get_nodes_in_group("enemy"): enemy.queue_free()
        await tick(2)
        var replayed: Dictionary = await PROBE.new().replay(world, config, start, room, certificate.inputs)
        check(not replayed.is_empty() and replayed.get("escaped", false), "continuous production replay leaves the hidden room without abilities: " + key)
    check(seen.size() == expected.size(), "every current risky shrine has a replayed certificate")
    print("SHRINE_EXIT_ROUTES checks=%d failures=%d" % [checks, failures])
    quit(1 if failures else 0)
