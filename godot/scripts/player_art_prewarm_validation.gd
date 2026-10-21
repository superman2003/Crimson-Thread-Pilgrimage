extends RefCounted
## Real imported-image worker and actual Player ready path; no timing gate is
## inferred from a warm process. Published cold startup timing is separate.
const JOB := preload("res://scripts/player_art_warm_job.gd")
const RESOURCE_JOB := preload("res://scripts/background_resource_job.gd")
var checks := 0
var failures := 0

class CachedPlayer extends "res://scripts/player_controller.gd":
    var texture_misses := 0
    func _load_texture_resource(path: String) -> Texture2D:
        if not ResourceLoader.has_cached(path): texture_misses += 1
        return super._load_texture_resource(path)
    func _should_play_sfx() -> bool: return false

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error("PLAYER_ART_PREWARM: " + label)

func wait_for(tree: SceneTree, job: RefCounted) -> void:
    var deadline := Time.get_ticks_msec() + 15000
    while not job.ready() and Time.get_ticks_msec() < deadline:
        check(job.take().is_empty(), "polling never joins an unfinished player read")
        await tree.process_frame
    check(job.ready(), "player resource read completes within fixture deadline")

func run(tree: SceneTree) -> int:
    var job := JOB.new()
    check(job.begin() == OK, "begin immutable player artwork worker")
    check(job.begin() == ERR_ALREADY_IN_USE, "unclaimed player ticket cannot be overwritten")
    await wait_for(tree,job)
    if not job.ready(): job.shutdown();return failures
    var result: Dictionary = job.take()
    check(String(result.get("error","missing")).is_empty() and bool(result.get("worker_is_main",true)) != RESOURCE_JOB.off_thread_loading_safe(), "actual image decode runs in the private worker, or inline under the headless Dummy renderer")
    check(result.get("textures",{}).size() > 0 and job._thread == null, "completed owner transfers real native resource references")
    for path in result.get("textures",{}):
        check(ResourceLoader.has_cached(path) and result.textures[path] is Texture2D, "every retained native entry is a real imported image")
    var player = load("res://scenes/Player.tscn").instantiate()
    player.set_script(CachedPlayer)
    var started := Time.get_ticks_usec()
    tree.root.add_child(player)
    var ready_usec := Time.get_ticks_usec()-started
    player.set_physics_process(false)
    player.set_process(false)
    check(player.texture_misses == 0, "actual Player frames perform zero first synchronous texture reads")
    check(player.sprite.sprite_frames.get_animation_names().size() >= 15 and player.layered_idle != null, "all body animations and original layered idle still build normally")
    player.free()
    result.clear()
    check(job.take().is_empty(), "joined result cannot be taken twice")
    const BAD := "user://ctp_player_art_warm_invalid.json"
    for contents in ["broken json", JSON.stringify({"animations":[{"frames":["res://missing_player_warm.png"]}]}), JSON.stringify({"animations":[{"frames":["res://unsupported_player_warm.tres"]}]})]:
        var file := FileAccess.open(BAD,FileAccess.WRITE)
        file.store_string(contents);file.close()
        check(job.begin(BAD) == OK, "fixture rejection still has one real worker owner")
        await wait_for(tree,job)
        if not job.ready(): job.shutdown();break
        var rejected: Dictionary = job.take()
        check(not String(rejected.get("error","")).is_empty() and rejected.get("textures",{}).is_empty(), "bad manifest, missing image and procedural GPU resource never publish a partial result")
    for optional in ["user://ctp_missing_optional_idle.json", BAD]:
        var file := FileAccess.open(BAD,FileAccess.WRITE)
        file.store_string(JSON.stringify({"support":{"file":"unsupported.tres"},"cloth":{"file":"missing.png"}}));file.close()
        check(job.begin(JOB.PLAYER.PLAYER_MANIFEST,optional) == OK, "optional idle failure still uses the bounded worker")
        await wait_for(tree,job)
        if not job.ready(): job.shutdown();break
        var fallback: Dictionary = job.take()
        check(String(fallback.get("error","missing")).is_empty() and not fallback.get("textures",{}).is_empty() and not fallback.get("optional_skipped",[]).is_empty(), "optional idle assets never turn a usable body idle into a startup failure")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(BAD))
    var retiring := JOB.new()
    check(retiring.begin() == OK, "start actual whole-owner teardown fixture")
    retiring.shutdown()
    check(retiring.closed and retiring._thread == null and retiring.take().is_empty(), "teardown joins and drops its unfinished or unclaimed native result")
    check(retiring.begin() == ERR_ALREADY_IN_USE, "closed owner cannot restart")
    retiring.shutdown()
    print("PLAYER_ART_PREWARM checks=%d failures=%d ready_usec=%d" % [checks,failures,ready_usec])
    return failures
