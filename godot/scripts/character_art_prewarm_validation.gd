extends SceneTree
## A cold process warms actual production atlases, then uses normal consumers.
const ART := preload("res://scripts/hand_drawn_assets.gd")
const RESOURCE_JOB := preload("res://scripts/background_resource_job.gd")
const WARM := preload("res://scripts/character_art_warm_job.gd")
const LEVEL := preload("res://scripts/main_level.gd")
const ENEMY := preload("res://scripts/enemy_actor.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(label)
func run() -> void:
    failures += await preload("res://scripts/player_art_prewarm_validation.gd").new().run(self)
    await resource_job_lifecycle()
    await shared_request_shutdown()
    var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/demo_ch01_moss_bell_court.json"))
    # Include a remote NPC whose art is not in the three landing winners.
    config.npcs.append({"id":"npc_gear_cartographer", "name":"warm fixture", "position":[90000,90000]})
    var baseline := ART.synchronous_texture_loads
    var job := WARM.new()
    job.begin(config)
    var deadline := Time.get_ticks_msec() + 15000
    while not job.done and Time.get_ticks_msec() < deadline:
        job.step(2, 2000)
        check(ART.texture_requests.size() <= 2, "bounded background texture ownership")
        await process_frame
    check(job.done and job.error.is_empty(), "complete production region artwork warms successfully: " + job.error)
    check(job.max_step_operations <= 2, "descriptor work respects operation admission")
    check(ART.synchronous_texture_loads == baseline, "prewarm performs no synchronous texture loading")
    check(ART.threaded_texture_loads > 0, "cold process actually used background requests")
    var level := LEVEL.new()
    for npc in config.npcs:
        var area: Area2D = level._make_npc(npc)
        check(area.get_node_or_null("FriendlyFamilySprite") != null, "normal NPC factory consumes warmed frames")
        check(ART.portrait(String(npc.id)) != null, "original portrait already warmed")
        area.free()
    for data in config.enemy_spawns + [config.boss]:
        var enemy := ENEMY.new()
        enemy.configure(data, "", data == config.boss)
        enemy.prepare_presentation()
        check(enemy.animated_sprite != null and enemy.animated_sprite.sprite_frames != null, "normal enemy factory consumes warmed frames")
        enemy.free()
    check(ART.synchronous_texture_loads == baseline, "formal frames and portraits perform zero first synchronous texture loads")
    check(ART.textures.has(ART.atlas_paths(ART.character_manifest("original_npcs", "npc_gear_cartographer"))[0]), "far NPC outside landing window is warmed")
    level.free()
    # A cancelled speculative plan cannot create requests or publish readiness.
    var cancelled := WARM.new()
    cancelled.begin(config)
    cancelled.cancel()
    cancelled.step()
    check(cancelled.cancelled and cancelled.scanned == 0, "cancelled plan does no further descriptor or texture work")
    var failed := WARM.new()
    failed.begin({}, [{"kind":"enemy", "data":{"kind":"no_such_creature", "sprite":"res://missing_character_warm.png"}}], true)
    for index in range(10):
        failed.step()
        if failed.done: break
    check(failed.done and not failed.error.is_empty(), "missing resource fails explicitly without a synchronous fallback")
    check(ART.synchronous_texture_loads == baseline, "failed prewarm also never decodes synchronously")
    print("CHARACTER_ART_PREWARM checks=%d failures=%d sync_loads=%d" % [checks, failures, ART.synchronous_texture_loads - baseline])
    quit(0 if failures == 0 else 1)

## Exercise actual resource ownership, including a completed but unclaimed
## request and a whole-owner teardown while the worker may still be running.
func resource_job_lifecycle() -> void:
    const PATH := "user://background_resource_lifetime_fixture.tres"
    var fixture := Resource.new()
    fixture.set_meta("payload", PackedInt32Array([3, 5, 8]))
    check(ResourceSaver.save(fixture, PATH) == OK, "write resource ownership fixture")
    fixture = null
    var worker := RESOURCE_JOB.new()
    check(worker.take().is_empty(), "no result before admission")
    check(worker.start(PATH, "Texture2D") == ERR_UNAVAILABLE and worker._thread == null, "procedural GPU texture resources reject before worker admission")
    check(worker.start("res://does_not_exist_lifetime_test.tres") == ERR_FILE_NOT_FOUND and worker._thread == null, "missing path rejects without a live worker")
    for cycle in 100:
        check(worker.start(PATH, "", ResourceLoader.CACHE_MODE_IGNORE) == OK, "start real resource worker")
        check(worker.start(PATH) == ERR_ALREADY_IN_USE, "unclaimed request retains exclusive ownership")
        var deadline := Time.get_ticks_msec() + 5000
        while not worker.ready() and Time.get_ticks_msec() < deadline:
            check(worker.take().is_empty(), "polling an unfinished request never joins")
            await process_frame
        check(worker.ready(), "worker completes inside original frame-polling deadline")
        if not worker.ready():
            worker.shutdown()
            break
        var result: Dictionary = worker.take()
        var loaded := result.get("resource") as Resource
        check(bool(result.get("worker_is_main", true)) != RESOURCE_JOB.off_thread_loading_safe(), "resource decoding runs off main thread, or inline under the headless Dummy renderer")
        check(loaded != null and loaded.get_meta("payload") == PackedInt32Array([3, 5, 8]), "claimed resource preserves actual payload")
        check(worker._thread == null and worker.take().is_empty(), "completed thread joined exactly once")
    check(worker.start(PATH, "", ResourceLoader.CACHE_MODE_IGNORE) == OK, "start owner teardown fixture")
    worker.shutdown()
    check(worker.closed and worker._thread == null and worker.take().is_empty(), "owner shutdown joins and drops unclaimed result")
    check(worker.start(PATH) == ERR_ALREADY_IN_USE, "closed owner rejects new work")
    worker.shutdown()
    DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

func shared_request_shutdown() -> void:
    var paths: Array[String] = [
        "res://assets/sprites/flat_maps/moss_cavern/background.png",
        "res://assets/sprites/flat_maps/rain_foundry/background.png",
        "res://assets/sprites/flat_maps/salt_archive/background.png"]
    ART.request_texture(paths[0])
    ART.request_texture(paths[1])
    ART.request_texture(paths[2])
    check(ART.texture_requests.size() == ART.MAX_TEXTURE_REQUESTS and not ART.texture_requests.has(paths[2]), "third texture waits outside bounded admission")
    var owners: Array = ART.texture_requests.values()
    ART.shutdown_texture_requests()
    check(ART.texture_requests.is_empty() and owners.all(func(owner): return owner._thread == null), "shutdown joins all outstanding shared texture workers")
    check(ART.textures.has(paths[0]) and ART.textures.has(paths[1]), "shutdown preserves successfully decoded immutable atlases for other hosts")
    var plan := WARM.new()
    plan.begin({}, [{"kind":"enemy", "data":{"kind":"owner_shutdown_fixture", "sprite":paths[2]}}], true)
    var deadline := Time.get_ticks_msec() + 5000
    while ART.texture_requests.is_empty() and not plan.done and Time.get_ticks_msec() < deadline:
        plan.step()
        if ART.texture_requests.is_empty(): await process_frame
    check(ART.texture_requests.has(paths[2]), "speculative plan actually admitted a shared resource worker")
    plan.cancel()
    plan.step()
    check(ART.texture_requests.has(paths[2]), "ordinary plan cancellation retains the outstanding worker owner")
    ART.shutdown_texture_requests()
    check(ART.texture_requests.is_empty() and ART.textures.has(paths[2]), "whole-owner shutdown reaps the cancelled plan's resource")
    for path in paths:
        ART.textures.erase(path)
