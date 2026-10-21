extends SceneTree
## Shared atlas requests and the private Player warmup run while the main
## thread keeps creating textures. Under the headless Dummy renderer the jobs
## must load inline: its texture RID owner is not thread-safe in Godot 4.6.1.
const ART := preload("res://scripts/hand_drawn_assets.gd")
const RESOURCE_JOB := preload("res://scripts/background_resource_job.gd")
const PLAYER_JOB := preload("res://scripts/player_art_warm_job.gd")
const CYCLES := 24
const SHARED := [
    "res://assets/sprites/flat_maps/salt_archive/decor_atlas.png",
    "res://assets/sprites/flat_maps/salt_archive/terrain_atlas.png"]
const MAIN_THREAD := [
    "res://assets/sprites/flat_maps/moss_cavern/background.png",
    "res://assets/sprites/flat_maps/rain_foundry/background.png",
    "res://assets/sprites/flat_maps/salt_archive/background.png",
    "res://assets/sprites/flat_maps/string_greenhouse/background.png"]
const ICONS := ["ash_ring", "bell", "cleave", "compass", "crimson", "crosscut", "fog", "lure",
    "mender", "mine", "needle", "reflux", "salt", "shard", "shell", "snare", "spur", "ward"]
const STRESS_CYCLES := 40
const STRESS_JOBS := 6
var checks := 0
var failures := 0

func _initialize() -> void:call_deferred("run")

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(label)

func run() -> void:
    var threaded := RESOURCE_JOB.off_thread_loading_safe()
    var inline_results := 0
    var threaded_results := 0
    for cycle in CYCLES:
        for path in SHARED: ART.textures.erase(path)
        for path in SHARED: ART.request_texture(path)
        var player := PLAYER_JOB.new()
        check(player.begin() == OK, "player warmup admitted in cycle %d" % cycle)
        var jobs: Array = ART.texture_requests.values()
        jobs.append(player)
        # Fresh main-thread textures overlap every outstanding worker without
        # yielding, so both sides allocate texture RIDs at the same time.
        var deadline := Time.get_ticks_msec() + 10000
        var main_loads := 0
        while jobs.any(func(job): return not job.ready()) and Time.get_ticks_msec() < deadline:
            for path in MAIN_THREAD:
                if ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) is Texture2D: main_loads += 1
        check(main_loads > 0 or not threaded, "main thread created textures while workers were loading")
        check(jobs.all(func(job): return job.ready()), "all texture owners finish inside the cycle deadline")
        var result: Dictionary = player.take()
        check(String(result.get("error", "missing")).is_empty() and result.get("textures", {}).size() > 0, "player warmup returns its real textures")
        if bool(result.get("worker_is_main", true)): inline_results += 1
        else: threaded_results += 1
        while not ART.texture_requests.is_empty():
            ART.poll_textures(4, 1000000)
            await process_frame
        for path in SHARED:
            check(ART.textures.get(path) is Texture2D, "shared atlas published: " + path)
    check(inline_results == (0 if threaded else CYCLES) and threaded_results == (CYCLES if threaded else 0),
        "jobs use worker threads only off the headless Dummy renderer")
    await _small_texture_stress(threaded)
    for path in SHARED: ART.textures.erase(path)
    print("BACKGROUND_TEXTURE_CONTENTION checks=%d failures=%d threaded=%s" % [checks, failures, threaded])
    quit(0 if failures == 0 else 1)

## Small images make RID allocation, not decoding, dominate each load, which is
## what exposed the Dummy renderer race; several owners plus the main thread.
func _small_texture_stress(threaded: bool) -> void:
    var off_main := 0
    for cycle in STRESS_CYCLES:
        var jobs: Array = []
        for index in STRESS_JOBS:
            var job := RESOURCE_JOB.new()
            var icon: String = ICONS[(cycle * STRESS_JOBS + index) % ICONS.size()]
            check(job.start("res://assets/ui/seals/%s.svg" % icon, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) == OK, "stress owner admitted")
            jobs.append(job)
        var deadline := Time.get_ticks_msec() + 5000
        var spin := 0
        while jobs.any(func(job): return not job.ready()) and Time.get_ticks_msec() < deadline:
            var icon: String = ICONS[spin % ICONS.size()]
            ResourceLoader.load("res://assets/ui/seals/%s.svg" % icon, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE)
            spin += 1
        for job in jobs:
            var result: Dictionary = job.take()
            check(result.get("resource") is Texture2D, "stress owner returns a real texture")
            if not bool(result.get("worker_is_main", true)): off_main += 1
        await process_frame
    check(off_main == (STRESS_CYCLES * STRESS_JOBS if threaded else 0), "stress owners stay off the main thread only where texture RIDs are thread-safe")
