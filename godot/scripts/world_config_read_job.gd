extends RefCounted
## One privately owned file/JSON task. Only the main thread calls this API.
## The worker returns its data; it never edits the host, caches or SceneTree.
var _thread: Thread
var _serial := 0
var _accepted := 0
var closed := false

func busy() -> bool:
    return _thread != null and _thread.is_alive()

func request(path: String) -> int:
    if closed or busy() or _accepted != 0:
        return 0
    # Reap an abandoned result before admitting another task. At most one
    # worker/result is retained, including after cancellation.
    if _thread != null:
        _thread.wait_to_finish()
        _thread = null
    _serial += 1
    _accepted = _serial
    _thread = Thread.new()
    if _thread.start(_read.bind(path), Thread.PRIORITY_LOW) != OK:
        _thread = null
        _accepted = 0
        return 0
    return _accepted

func take(ticket: int) -> Dictionary:
    if _thread == null or busy() or ticket != _accepted or ticket == 0:
        return {}
    var result: Dictionary = _thread.wait_to_finish()
    _thread = null
    _accepted = 0
    return result

func discard(ticket: int) -> void:
    if ticket != _accepted:
        return
    _accepted = 0
    if _thread != null and not busy():
        _thread.wait_to_finish()
        _thread = null

func shutdown() -> void:
    closed = true
    _accepted = 0
    # Only whole-host teardown may join an unfinished read. Ordinary frame
    # polling and cancellation never wait on a running worker.
    if _thread != null:
        _thread.wait_to_finish()
        _thread = null

static func _read(path: String) -> Dictionary:
    var started := Time.get_ticks_usec()
    var stamp := FileAccess.get_modified_time(path)
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {"error": "目标位置或区域文件无效。"}
    var text := file.get_as_text()
    var bytes := file.get_length()
    var read_error := file.get_error()
    file.close()
    if read_error != OK or stamp != FileAccess.get_modified_time(path):
        return {"error": "目标区域文件读取失败或已改变。"}
    var json := JSON.new()
    var parsed: Variant = json.data if json.parse(text) == OK else null
    return {"raw": parsed, "stamp": stamp, "bytes": bytes, "worker_usec": Time.get_ticks_usec() - started,
        "worker_is_main": Thread.is_main_thread(), "error": ""}
