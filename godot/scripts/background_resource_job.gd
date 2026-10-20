extends RefCounted
## A caller owns one plain Thread and its immutable resource result until take
## or whole-owner shutdown. No WorkerThreadPool LoadToken is used on Godot 4.6.1.
## Current consumers use imported images. Procedural GPU resources may call
## back into the main render thread and cannot be joined during owner teardown.
var _thread: Thread
var closed := false

func start(path: String, type_hint: String = "", cache_mode: int = ResourceLoader.CACHE_MODE_REUSE) -> int:
    if closed or _thread != null:
        return ERR_ALREADY_IN_USE
    if type_hint == "Texture2D" and path.get_extension().to_lower() in ["tres", "res"]:
        return ERR_UNAVAILABLE
    if not ResourceLoader.exists(path, type_hint):
        return ERR_FILE_NOT_FOUND
    _thread = Thread.new()
    var error := _thread.start(_load.bind(path, type_hint, cache_mode), Thread.PRIORITY_LOW)
    if error != OK:
        _thread = null
    return error

func ready() -> bool:
    return _thread != null and not _thread.is_alive()

func take() -> Dictionary:
    if not ready():
        return {}
    return finish()

## Only complete owner teardown may call this before ready().
func finish() -> Dictionary:
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
