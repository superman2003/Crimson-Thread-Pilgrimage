extends RefCounted
## W00 stage 3 (docs/W00_SEAMLESS_RESIDENCY_PLAN.md): build the destination
## region hidden while the source region stays resident, then make it current.
##
## The destination is built by the ordinary prepare/build/finish jobs into a
## second, disabled and hidden container. Those jobs read and write the level
## host's fields, so the host carries the destination's field set only while a
## batch of jobs runs (loader._next_process_frame switches around every yield);
## between batches the host is the source region, exactly as before.
## Cancelling drops the container and the field set: nothing of the source was
## touched, so there is no snapshot to restore.
const REGION_STATE := preload("res://scripts/region_state.gd")
const LEVEL_HOST := preload("res://scripts/level_host.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const LEVEL_HUD_BUILD := preload("res://scripts/level_hud_build.gd")

## Jobs that act on the player, on what is audible, or on the shared map. They
## are held back from the hidden build and run, in this order, at handover.
const HANDOVER_JOBS := ["_start_audio_explore", "_start_audio_ambience", "_finish_region_spawn",
    "_restore_world_player", "_warm_arrival_cave", "_warm_arrival_terrain", "_warm_arrival_platforms",
    "_restore_world_discovery", "_bind_region_audio"]


static func switched_in(loader: RefCounted) -> bool:
    return not loader.staging.is_empty() and bool(loader.staging.switched_in)


static func enter(loader: RefCounted) -> void:
    var staging: Dictionary = loader.staging
    if staging.is_empty() or staging.switched_in or not loader._alive(staging.host):
        return
    var host: Node = staging.host
    staging.source_state = REGION_STATE.switch_to(host, staging.state, staging.fields)
    staging.source_root = host.region_root
    host.region_root = staging.root
    staging.switched_in = true


static func leave(loader: RefCounted) -> void:
    var staging: Dictionary = loader.staging
    if staging.is_empty() or not staging.switched_in or not is_instance_valid(staging.host):
        return
    var host: Node = staging.host
    staging.state = REGION_STATE.switch_to(host, staging.source_state, staging.fields)
    host.region_root = staging.source_root
    staging.switched_in = false
    # A CanvasLayer draws whatever its parent's visibility is.
    for child in staging.root.get_children():
        if child is CanvasLayer and child.visible:
            child.visible = false
            staging.hidden_layers.append(child)


## Moves the jobs that must wait for handover out of a job list.
static func hold_back(loader: RefCounted, jobs: Array) -> Array:
    if not switched_in(loader):
        return jobs
    var kept: Array = []
    for job in jobs:
        if String(job.get("method", "")) in HANDOVER_JOBS:
            loader.staging.held_jobs.append(job)
        else:
            kept.append(job)
    return kept


static func stage_region_async(loader: RefCounted, host: Node, path: String, entry: Vector2) -> bool:
    if loader.phase != "idle" or not loader.staging.is_empty() or not loader._alive(host) or not is_instance_valid(host.player) or not is_instance_valid(host.region_root):
        return false
    loader.phase = "staging"
    loader.cancel_requested = false
    loader.last_error = ""
    var source_id := String(host.config.get("id", ""))
    loader.last_transition = {"source": source_id, "target_path": path, "rolled_back": false, "staged": true}
    var started := Time.get_ticks_usec()
    var target: Dictionary = await loader._preflight_async(path, entry, host.world_prefetch, host)
    if not loader._alive(host):
        return false
    var route_generation := int(loader.last_transition.get("preflight_route_generation", -1))
    if target.is_empty() or loader.cancel_requested or route_generation < 0 or ROUTES.cached_generation() != route_generation:
        if not target.is_empty() and not loader.cancel_requested:
            loader.last_error = "区域路线清单在目标预检后已变化，请重试。"
        loader.phase = "idle"
        loader.cancel_requested = false
        return false
    var root := Node2D.new()
    root.name = "RegionStaging"
    root.set_meta(LEVEL_HOST.META, host)
    root.visible = false
    root.process_mode = Node.PROCESS_MODE_DISABLED
    host.add_child(root)
    host.move_child(root, host.region_root.get_index())
    var fields: Array[String] = REGION_STATE.travel_fields()
    loader.staging = {"host": host, "root": root, "fields": fields, "state": REGION_STATE.fresh(host, fields),
        "switched_in": false, "source_state": {}, "source_root": null, "hidden_layers": [], "held_jobs": [],
        "path": path, "entry": entry, "target_id": String(target.id), "source_id": source_id,
        # What the build may change outside the host: restored if it is dropped.
        "world_state": host.world_state.data.duplicate(true), "build": host.build_system.serialize(),
        "catalog": host.world_catalog}
    loader.last_transition["target"] = String(target.id)
    enter(loader)
    loader._set_destination(host, path, entry, source_id, target)
    loader.phase = "staging"
    var built: bool = await loader._construct_budgeted(host, target, true)
    if built and ROUTES.cached_generation() == route_generation:
        built = await loader._finish_budgeted(host, true)
    if not loader._alive(host):
        return false
    leave(loader)
    if not built or loader.cancel_requested or ROUTES.cached_generation() != route_generation:
        _drop(loader)
        loader.phase = "idle"
        loader.cancel_requested = false
        return false
    loader.last_transition["staging_wall_usec"] = Time.get_ticks_usec() - started
    loader.phase = "staged"
    return true


## Requests the hidden build to stop, or drops a finished one.
static func cancel(loader: RefCounted) -> void:
    if loader.phase == "staging":
        loader.cancel_requested = true
    elif loader.phase == "staged":
        _drop(loader)
        loader.phase = "idle"


static func _drop(loader: RefCounted) -> void:
    var staging: Dictionary = loader.staging
    if staging.is_empty():
        return
    var host: Variant = staging.host
    if is_instance_valid(host):
        # Region-owned services stop the way a departing region's do.
        enter(loader)
        if switched_in(loader):
            host._stop_region_tweens()
            host._release_region_audio()
            host._release_region_platforms()
            leave(loader)
        host.world_state.data = staging.world_state
        host.build_system.restore(staging.build)
        host.world_catalog = staging.catalog
    loader.staging = {}
    _retire(loader, staging.root)


## Frees a dropped container a few nodes per frame, like any region eviction.
static func _retire(loader: RefCounted, root: Node) -> void:
    if not is_instance_valid(root):
        return
    loader.staging_retiring += 1
    root.name = "RegionRetiring"
    var tree := root.get_tree()
    while is_instance_valid(root) and root.get_child_count() > 0 and tree != null and not loader.shutting_down:
        var started := Time.get_ticks_usec()
        var operations := 0
        while root.get_child_count() > 0 and operations < loader.MAX_OPERATIONS_PER_FRAME:
            if operations > 0 and Time.get_ticks_usec() - started >= loader.FRAME_BUDGET_USEC:
                break
            var child := root.get_child(root.get_child_count() - 1)
            root.remove_child(child)
            child.free()
            operations += 1
        await tree.process_frame
    if is_instance_valid(root):
        root.free()
    loader.staging_retiring -= 1


## Retires the source region and makes the hidden destination current. The
## source is evicted over several frames; the switch itself does not yield.
static func handover_async(loader: RefCounted, host: Node) -> bool:
    if loader.phase != "staged" or loader.staging.is_empty() or loader.staging.host != host or not loader._alive(host):
        return false
    var staging: Dictionary = loader.staging
    loader.phase = "unloading"
    host.world_loading = true
    host._stop_region_tweens()
    host._release_region_audio()
    host._release_region_platforms()
    loader.generation += 1 # invalidate departing callbacks before the first yield
    if not await loader._evict_budgeted(host):
        return false
    var switch_started := Time.get_ticks_usec()
    var old_root: Node = host.region_root
    REGION_STATE.apply(host, staging.state, staging.fields)
    host.region_root = staging.root
    loader.staging = {}
    if is_instance_valid(old_root):
        host.remove_child(old_root)
        old_root.free()
    staging.root.name = "Region"
    staging.root.process_mode = Node.PROCESS_MODE_INHERIT
    staging.root.visible = true
    for layer in staging.hidden_layers:
        if is_instance_valid(layer):
            layer.visible = true
    loader.phase = "committing"
    host._apply_chapter_reverb(String(host.config.get("id", "")))
    if is_instance_valid(host.metsys_bridge):
        host.metsys_bridge.complete_deferred()
    for job in staging.held_jobs:
        host.callv(job.method, job.args)
    if host.world_mode:
        LEVEL_HUD_BUILD.bind_journey_workbench(host)
    loader.phase = "publishing"
    host._publish_region()
    # The destination's residency was configured for the generation after the
    # one current when its build began; the source's departure added one more.
    if host.world_gameplay_residency != null:
        host.world_gameplay_residency.generation = loader.generation
    host.player.reset_camera_after_arrival()
    host.chapter_transitioning = false
    loader.phase = "idle"
    loader.last_transition["handover_switch_usec"] = Time.get_ticks_usec() - switch_started
    return true
