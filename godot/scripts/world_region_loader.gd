extends RefCounted
const PLAYER_ART_WARM_JOB := preload("res://scripts/player_art_warm_job.gd")
var player_art_job: RefCounted
var player_art_resources: Dictionary = {}
const CHARACTER_ART_WARM_JOB := preload("res://scripts/character_art_warm_job.gd")
const RESOURCE_JOB := preload("res://scripts/background_resource_job.gd")
const PREFETCH := preload("res://scripts/world_prefetch.gd")
## T03: the destination theme's large textures (backdrop, atlases, rock) are
## read on a worker before the build phase, which otherwise decoded each
## ~100 ms image synchronously inside one build job. Teleports, fast travel and
## save loads never pass the border prefetch that covers walking transitions.
var region_texture_jobs: Array[Dictionary] = []
var region_texture_hold: Array[Texture2D] = []
## The World node is the persistent host. Only its region-owned children are
## evicted; the Player, WorldState and BuildSystem remain the same instances.
## This is a coarse active-region chunk, not yet distance-based room streaming.
const COORDINATES := preload("res://scripts/world_coordinates.gd")
const ROUTES := preload("res://scripts/world_routes.gd")
const CONFIG_READ_JOB := preload("res://scripts/world_config_read_job.gd")
var config_read_job := CONFIG_READ_JOB.new()
const SAVE_BACKUP_JOB := preload("res://scripts/world_save_backup_job.gd")
var save_backup_job := SAVE_BACKUP_JOB.new()
const CONFIG_VALIDATOR := preload("res://scripts/world_config_validator.gd")
const VARIANT_COPY_JOB := preload("res://scripts/world_variant_copy_job.gd")
const TRANSITION_TOKEN := preload("res://scripts/world_transition_token.gd")
const LOADER_STARTUP_SUPPORT := preload("res://scripts/loader_startup_support.gd")
const LOADER_REGION_STATE := preload("res://scripts/loader_region_state.gd")
const LOADER_STARTUP := preload("res://scripts/loader_startup.gd")
const LOADER_BUDGETED_PREPARE := preload("res://scripts/loader_budgeted_prepare.gd")
const LOADER_TRANSITIONS := preload("res://scripts/loader_transitions.gd")
const SESSION_FIELDS := ["player", "world_mode", "world_resume", "world_save_path",
    "world_startup_options_enabled", "world_save_blocked",
    "world_state", "world_slot", "world_loader", "build_system", "applied_build_profile",
    "world_catalog", "world_narrative", "world_write_error_shown", "world_prefetch", "world_passage",
    "world_shared_metadata_cache", "world_shared_metadata_reads", "world_shared_metadata_probes",
    "world_shared_metadata_bytes", "world_shared_metadata_parses", "world_shared_metadata_failures"]
var generation := 0
var active_region_id := ""
var phase := "idle"
var last_error := ""
var unloaded_nodes := 0
const MAX_OPERATIONS_PER_FRAME := 8
const FRAME_BUDGET_USEC := 2000
var cancel_requested := false
var shutting_down := false
var loading_canvas: CanvasLayer
var loading_label: Label
var last_transition: Dictionary = {}
var transition_token: RefCounted
var transition_serial := 0
var startup_token: RefCounted
# A speculative startup read stays private until the exact manifest is committed.
var startup_config_read_ahead: Dictionary = {}
# Owned loading keeps frame wakeups so whole-host shutdown can unwind its token
# before SceneTree stops emitting frames (including --quit-after).
signal _startup_frame_ready
var _startup_frame_tree: SceneTree
var manifest_refresh_running := false
var manifest_refresh_retry_after_msec := 0

func request_manifest_refresh(host: Node) -> void:
    if manifest_refresh_running or shutting_down or not _alive(host):
        return
    if Time.get_ticks_msec() < manifest_refresh_retry_after_msec:
        return
    if ROUTES.cache_is_current():
        return
    manifest_refresh_running = true
    LOADER_STARTUP.run_background_manifest_refresh(self, host)


## Scene `_ready` must be fire-and-forget; this token gives the startup
## coroutine an owner that survives until success or host teardown.
func request_startup_region(host: Node, previous_mode: int) -> RefCounted:
    if shutting_down or not _alive(host) or phase != "idle":
        return null
    var token = TRANSITION_TOKEN.new()
    token.serial = transition_serial + 1
    transition_serial = token.serial
    startup_token = token
    phase = "startup"
    last_transition["startup_requested_frame"] = Engine.get_process_frames()
    last_transition["startup_requested_usec"] = Time.get_ticks_usec()
    LOADER_STARTUP.run_owned_startup(self, token, host, previous_mode)
    return token


## Initial world boot uses the same bounded preparation/build/finish plan as
## travel. The synchronous initializer remains available to explicit fixtures.
func initialize_startup_region(host: Node, restore_process_mode: int = Node.PROCESS_MODE_INHERIT) -> bool:
    return await LOADER_STARTUP.initialize_startup_region(self, host, restore_process_mode)


## Startup has no travel entry until the route overlay is complete. The shared
## validator resolves the authored default then, or checks the saved override.
func _startup_config_context_valid(host: Variant, tree: SceneTree, lease: Dictionary) -> bool:
    return _alive(host) and (startup_token == null or not startup_token.cancelled) and host.get_tree() == tree and generation == int(lease.generation) and ROUTES.cached_generation() == int(lease.route_generation) and int(lease.route_generation) >= 0 and String(host.config_path) == String(lease.path) and host.entry_spawn_override_enabled == bool(lease.entry_enabled) and host.entry_spawn_override == lease.entry and (not lease.has("stamp") or FileAccess.get_modified_time(String(lease.path)) == int(lease.stamp))

func _discard_startup_config_read_ahead() -> void:
    LOADER_STARTUP_SUPPORT.discard_startup_config_read_ahead(self)

func _begin_startup_config_read_ahead(host: Node, tree: SceneTree, route_ticket: Dictionary) -> void:
    LOADER_STARTUP_SUPPORT.begin_startup_config_read_ahead(self, host, tree, route_ticket)

func _startup_config_read_ahead_source_valid(host: Node, tree: SceneTree) -> bool:
    return LOADER_STARTUP_SUPPORT.startup_config_read_ahead_source_valid(self, host, tree)

func _prepare_startup_config(host: Node, tree: SceneTree) -> Dictionary:
    return await LOADER_STARTUP.prepare_startup_config(self, host, tree)


func _show_startup_error(host: Node) -> void:
    LOADER_STARTUP_SUPPORT.show_startup_error(self, host)

func _manifest_refresh_cancelled(background: bool) -> bool:
    return LOADER_STARTUP_SUPPORT.manifest_refresh_cancelled(self, background)

func _prepare_routes_manifest(host: Node, tree: SceneTree, background: bool = false) -> bool:
    return await LOADER_STARTUP.prepare_routes_manifest(self, host, tree, background)

func register_region(host: Node) -> void:
    active_region_id = String(host.config.get("id", ""))
    generation += 1

func snapshot(host: Node) -> Dictionary:
    return LOADER_REGION_STATE.snapshot(self, host)

func preflight(path: String, entry: Vector2, prefetch: RefCounted = null) -> Dictionary:
    return LOADER_REGION_STATE.preflight(self, path, entry, prefetch)

func validate_config(parsed: Variant, path: String, entry: Vector2) -> Dictionary:
    return LOADER_REGION_STATE.validate_config(self, parsed, path, entry)

func _preflight_async(path: String, entry: Vector2, prefetch: RefCounted, host: Node) -> Dictionary:
    return await LOADER_BUDGETED_PREPARE.preflight_async(self, path, entry, prefetch, host)

func _finite_tuple(value: Variant, length: int) -> bool:
    return LOADER_REGION_STATE.finite_tuple(self, value, length)


func replace_region(host: Node, path: String, entry: Vector2) -> bool:
    return LOADER_REGION_STATE.replace_region(self, host, path, entry)


func _reset_region_fields(host: Node) -> void:
    LOADER_REGION_STATE.reset_region_fields(self, host)


## Escape requests rollback while geometry or arrival/UI jobs are incomplete. Permanent
## progress is restored from the settled departure snapshot; transient attacks
## are cancelled and source enemies are reconstructed, as on ordinary revisit.
func cancel_transition() -> void:
    if phase in ["preflight", "unloading", "loading", "committing"]:
        cancel_requested = true


## Owned startup and foreground travel must unwind before the host leaves.
## Ordinary callers and background refresh retain their SceneTree waits.
func _next_process_frame(tree: SceneTree) -> Signal:
    if startup_token == null and transition_token == null:
        return tree.process_frame
    if _startup_frame_tree != tree:
        _disconnect_startup_frames()
        _startup_frame_tree = tree
        tree.process_frame.connect(_wake_startup_frame)
    return _startup_frame_ready

func _wake_startup_frame() -> void:
    _startup_frame_ready.emit()

func _disconnect_startup_frames() -> void:
    LOADER_STARTUP_SUPPORT.disconnect_startup_frames(self)

## A scalar-only exit snapshot keeps verbose release failures diagnosable even
## when the frame deadline stops startup before publication. Never emit the
## lease, config, save, paths, or token payload from last_transition.
func _startup_exit_snapshot() -> Dictionary:
    return LOADER_STARTUP_SUPPORT.startup_exit_snapshot(self)

func _write_startup_exit_snapshot(snapshot: Dictionary) -> void:
    print("WORLD_STARTUP_EXIT " + JSON.stringify(snapshot))

func shutdown() -> void:
    await LOADER_TRANSITIONS.shutdown(self)


func _clear_loading_canvas() -> void:
    LOADER_STARTUP_SUPPORT.clear_loading_canvas(self)


func _show_loading_canvas(host: Node) -> void:
    LOADER_STARTUP_SUPPORT.show_loading_canvas(self, host)


func _alive(host: Variant) -> bool:
    return not shutting_down and is_instance_valid(host) and host.is_inside_tree()


func _cancel_input() -> void:
    if Input.is_physical_key_pressed(KEY_ESCAPE):
        cancel_transition()


func _measure_batch(operations: int, started: int, metric: String) -> void:
    LOADER_REGION_STATE.measure_batch(self, operations, started, metric)


func _evict_budgeted(host: Node) -> bool:
    return await LOADER_BUDGETED_PREPARE.evict_budgeted(self, host)


## Sequential cold-catalog reads share the loader's single ticket service.
## Parsed region trees are worker-owned; only catalog entries survive handoff.
func _catalog_context_valid(host: Variant, tree: SceneTree, expected_generation: int, route_generation: int, cancellable: bool) -> bool:
    return _alive(host) and (phase != "startup" or not last_transition.has("startup_config_lease") or _startup_config_context_valid(host, tree, last_transition.startup_config_lease)) and host.get_tree() == tree and generation == expected_generation and route_generation >= 0 and ROUTES.cached_generation() == route_generation and (not cancellable or not cancel_requested)


func _discard_catalog_staging(host: Variant, read_ahead: Dictionary = {}) -> void:
    LOADER_REGION_STATE.discard_catalog_staging(self, host, read_ahead)

func _prepare_catalog_region_async(host: Node, region_id: String, route_catalog: Dictionary, tree: SceneTree, expected_generation: int, route_generation: int, cancellable: bool, source_path: String = "", read_ahead: Dictionary = {}, next_region_id: String = "") -> bool:
    return await LOADER_BUDGETED_PREPARE.prepare_catalog_region_async(self, host, region_id, route_catalog, tree, expected_generation, route_generation, cancellable, source_path, read_ahead, next_region_id)


func _construct_budgeted(host: Node, target: Dictionary, cancellable: bool) -> bool:
    return await LOADER_BUDGETED_PREPARE.construct_budgeted(self, host, target, cancellable)


static func _record_background_job(stats: Dictionary, method: String, job_usec: int) -> void:
    if method == "_background_art":
        stats["background_art_usec"] = job_usec
    elif method in ["_background_cave", "_background_cave_surface"]:
        var key := "background_cave_edges_usec" if method == "_background_cave" else "background_cave_surface_usec"
        stats[key] = job_usec
        stats["background_cave_usec"] = int(stats.get("background_cave_edges_usec", 0)) + int(stats.get("background_cave_surface_usec", 0))


static func region_texture_paths(theme: String) -> Array[String]:
    var result: Array[String] = []
    if theme == "moss_bell":
        theme = "moss_cavern"
    if theme.is_empty():
        return result
    for filename in PREFETCH.TEXTURES:
        var path := "res://assets/sprites/flat_maps/%s/%s" % [theme, filename]
        if ResourceLoader.exists(path, "Texture2D"):
            result.append(path)
    return result

## Take finished reads; a cancelled transition leaves its reads here until
## they finish (joined only by whole-loader shutdown).
func _poll_region_textures(keep: bool) -> void:
    LOADER_REGION_STATE.poll_region_textures(self, keep)

func _warm_region_textures(host: Node, tree: SceneTree, expected_generation: int, route_generation: int, cancellable: bool) -> bool:
    return await LOADER_TRANSITIONS.warm_region_textures(self, host, tree, expected_generation, route_generation, cancellable)


func _begin_player_art(host: Node) -> bool:
    return LOADER_REGION_STATE.begin_player_art(self, host)

func _await_player_art(host: Node, tree: SceneTree, expected_generation: int, route_generation: int, cancellable: bool) -> bool:
    return await LOADER_TRANSITIONS.await_player_art(self, host, tree, expected_generation, route_generation, cancellable)

func _finalize_prepare_metrics(role: String, wall_started: int) -> void:
    LOADER_REGION_STATE.finalize_prepare_metrics(self, role, wall_started)


func _finish_budgeted(host: Node, cancellable: bool) -> bool:
    return await LOADER_BUDGETED_PREPARE.finish_budgeted(self, host, cancellable)


## Only the settled source is mirrored. The target checkpoint, rewards and
## generation still publish together inside the original non-yielding boundary.
## A cancelled transition may finish this source-only maintenance; shutdown
## joins its one owned worker before the host releases the loader.
func _warm_arrival_save_backup(host: Node, cancellable: bool) -> bool:
    return await LOADER_TRANSITIONS.warm_arrival_save_backup(self, host, cancellable)


func _set_destination(host: Node, path: String, entry: Vector2, previous_id: String, target: Dictionary) -> void:
    LOADER_REGION_STATE.set_destination(self, host, path, entry, previous_id, target)


var shrine_return_request: Dictionary={}

func replace_region_async(host: Node, path: String, entry: Vector2, rollback_entry: Vector2 = Vector2.INF, publish_flags: Dictionary = {}) -> bool:
    return await LOADER_TRANSITIONS.replace_region_async(self, host, path, entry, rollback_entry, publish_flags)


## Passage observers can leave the tree while their terminal load is yielding.
## Keep the async owner here; the passage observes its independent token and
## retains its existing collision, retry and source-mouth rollback behavior.
func request_passage_transition(host: Node, path: String, entry: Vector2, rollback_entry: Vector2) -> RefCounted:
    if phase != "idle" or shutting_down or not _alive(host):
        return null
    transition_serial += 1
    var token = TRANSITION_TOKEN.new()
    token.serial = transition_serial
    transition_token = token
    LOADER_TRANSITIONS.run_owned_passage_transition(self, token, host, path, entry, rollback_entry)
    return token


func start_region_transition(host: Node, path: String, entry: Vector2) -> void:
    request_region_transition(host, path, entry)

## Capture the strict authorization before replace_region_async first yields.
## Ordinary walking portals retain their existing save-blocked in-memory policy.
func request_shrine_return_transition(host: Node, key: String, path: String, entry: Vector2, fingerprint: String) -> RefCounted:
    if phase!="idle" or shutting_down or not shrine_return_request.is_empty():return null
    shrine_return_request={"key":key,"fingerprint":fingerprint}
    var result:=request_region_transition(host,path,entry)
    shrine_return_request={}
    return result

func request_region_transition(host: Node, path: String, entry: Vector2, publish_flags: Dictionary = {}) -> RefCounted:
    if phase != "idle" or shutting_down or not _alive(host):
        return null
    transition_serial += 1
    var token = TRANSITION_TOKEN.new()
    token.serial = transition_serial
    transition_token = token
    LOADER_TRANSITIONS.run_owned_transition(self, token, host, path, entry, publish_flags)
    return token

