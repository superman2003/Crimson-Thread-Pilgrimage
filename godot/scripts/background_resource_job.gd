extends RefCounted
## A caller owns one plain Thread and its immutable resource result until take
## or whole-owner shutdown. No WorkerThreadPool LoadToken is used on Godot 4.6.1.
## Current consumers use imported images. Procedural GPU resources may call
## back into the main render thread and cannot be joined during owner teardown.
var _thread: Thread
## Headless result held under the same single-owner contract as a Thread.
var _inline_result: Dictionary = {}
var _inline_pending := false
var closed := false

## Godot 4.6.1's headless Dummy renderer keeps texture RIDs in a non-thread-safe
## RID_PtrOwner, so a worker and the main thread creating textures at once can
## corrupt it ("Initializing already initialized RID"). Headless runs upload
## nothing to a GPU, so loading on the caller costs no frame overlap there.
static func off_thread_loading_safe() -> bool:
    return DisplayServer.get_name() != "headless"

func start(path: String, type_hint: String = "", cache_mode: int = ResourceLoader.CACHE_MODE_REUSE) -> int:
    if closed or _thread != null or _inline_pending:
        return ERR_ALREADY_IN_USE
    if type_hint == "Texture2D" and path.get_extension().to_lower() in ["tres", "res"]:
        return ERR_UNAVAILABLE
    if not ResourceLoader.exists(path, type_hint):
        return ERR_FILE_NOT_FOUND
    if not off_thread_loading_safe():
        _inline_result = _load(path, type_hint, cache_mode)
        _inline_pending = true
        return OK
    _thread = Thread.new()
    var error := _thread.start(_load.bind(path, type_hint, cache_mode), Thread.PRIORITY_LOW)
    if error != OK:
        _thread = null
    return error

func ready() -> bool:
    return _inline_pending or (_thread != null and not _thread.is_alive())

func take() -> Dictionary:
    if not ready():
        return {}
    return finish()

## Only complete owner teardown may call this before ready().
func finish() -> Dictionary:
    if _inline_pending:
        var inline := _inline_result
        _inline_result = {}
        _inline_pending = false
        return inline
    if _thread == null:
        return {}
    var result: Dictionary = _thread.wait_to_finish()
    _thread = null
    return result

func shutdown() -> void:
    closed = true
    # Ordinary cancellation retains this job until ready. Only complete owner
    # teardown may join an unfinished read, then drop its result on this thread.
    finish()

static func _load(path: String, type_hint: String, cache_mode: int) -> Dictionary:
    return {"resource": ResourceLoader.load(path, type_hint, cache_mode),
        "worker_is_main": Thread.is_main_thread()}
