extends SceneTree
## W04 audit: a shrine inside a secret room, or below a one-way drop, would trap
## a player who respawns there if the room cannot be left. For each such shrine
## this searches jumps with the production Player and NO abilities (new save):
## from the shrine, physically walked approaches and full jumps, following
## every new landing; a successful route is replayed continuously before reporting.
## Slow (about a minute per shrine), so it is an on-demand audit, not a CI suite.
## Run: godot --headless --fixed-fps 60 --path godot --script res://../tools/probe_shrine_exits.gd
const PROBE := preload("res://scripts/shrine_exit_probe.gd")
const READY := preload("res://scripts/world_ready_validation_helper.gd")
const REGIONS := ["demo_ch01_moss_bell_court", "demo_ch02_rain_foundry_canal", "demo_ch03_saltwhite_archive", "demo_ch04_broken_string_greenhouse", "demo_ch05_obsidian_pilgrim_road", "demo_ch06_silent_crown_core"]
const HIDDEN_KINDS := ["secret", "treasure", "reward"]
var results: Array = []
var region_filter := ""
var shrine_filter := ""

func _initialize() -> void: call_deferred("run")

func frames(n: int) -> void:
    for i in n:
        await physics_frame
        await process_frame

func rect_of(room: Dictionary) -> Rect2:
    var v: Array = room.layout_rect
    return Rect2(v[0], v[1], v[2], v[3])

func room_at(config: Dictionary, point: Vector2) -> Dictionary:
    var best: Dictionary = {}
    var area := INF
    for room in config.map_rooms:
        var r := rect_of(room)
        if r.has_point(point) and r.get_area() < area:
            best = room
            area = r.get_area()
    return best

func risky_shrines(config: Dictionary) -> Array:
    var drops := {}
    for c in config.get("connections", []):
        if String(c.get("type", "")) == "one_way_drop": drops[String(c.to)] = true
    var out := []
    for s in config.save_points:
        var room := room_at(config, Vector2(s.position[0], s.position[1]))
        if room.is_empty(): continue
        if String(room.get("kind", "")) in HIDDEN_KINDS or bool(room.get("hidden", false)) or drops.has(String(room.id)):
            out.append({"shrine": s, "room": room, "reason": "one_way_drop" if drops.has(String(room.id)) else "hidden"})
    return out

func run() -> void:
    var args := OS.get_cmdline_args()
    args.append_array(OS.get_cmdline_user_args())
    for arg in args:
        if arg.begins_with("--region="): region_filter = arg.get_slice("=", 1)
        if arg.begins_with("--shrine="): shrine_filter = arg.get_slice("=", 1)
    var world = load("res://scenes/World.tscn").instantiate()
    world.world_resume = false
    world.world_save_path = "user://probe_shrine_exits.json"
    PROBE.disable_ability_pickups(world)
    root.add_child(world)
    await READY.wait_for(world)
    for region in REGIONS:
        if not region_filter.is_empty() and not String(region).contains(region_filter): continue
        var path := "res://data/%s.json" % region
        var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
        for entry in risky_shrines(config):
            if not shrine_filter.is_empty() and String(entry.shrine.id) != shrine_filter: continue
            var start := Vector2(entry.shrine.position[0], entry.shrine.position[1])
            world.set_process(true)
            world._travel_world(path, start)
            await frames(10)
            world.set_process(false)
            for e in get_nodes_in_group("enemy"): e.queue_free()
            await frames(2)
            var result := await PROBE.new().search(world, config, start, entry.room)
            result.merge({"region": region, "shrine": String(entry.shrine.id), "room": String(entry.room.id), "reason": entry.reason})
            results.append(result)
            print("SHRINE_EXIT %s %s room=%s escaped=%s via=%s landings=%d" % [region, entry.shrine.id, entry.room.id, str(result.escaped), str(result.get("via", "")), int(result.landings)])
    var report_path := "res://../artifacts/shrine_exits/report.json" if region_filter.is_empty() and shrine_filter.is_empty() else "res://../artifacts/shrine_exits/report_filtered.json"
    var file := FileAccess.open(report_path, FileAccess.WRITE)
    if file == null:
        DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../artifacts/shrine_exits"))
        file = FileAccess.open(report_path, FileAccess.WRITE)
    file.store_string(JSON.stringify({"abilities": "none (new save)", "method": "continuous walk/jump edges with full route replay", "results": results}, "  ") + "\n")
    file.close()
    var unverified := (1 if results.is_empty() else 0) + results.filter(func(r): return not r.escaped or not r.get("replay_verified", false)).size()
    print("SHRINE_EXIT_AUDIT shrines=%d unverified=%d" % [results.size(), unverified])
    quit(0 if unverified == 0 else 1)
