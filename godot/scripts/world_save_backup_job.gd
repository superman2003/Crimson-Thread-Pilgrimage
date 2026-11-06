extends RefCounted
## Maintains a verified copy of an already saved source checkpoint. The worker
## never receives destination progress and never writes the primary save.
const STATE := preload("res://scripts/world_state.gd")
var _thread: Thread
var _pending_path := ""
var _serial := 0
var closed := false
var started := 0
var last_result: Dictionary = {}

func begin(path: String, source_hash: String) -> bool:
    if closed or _thread != null or not _pending_path.is_empty() or source_hash.length() != 64:
        return false
    var absolute := ProjectSettings.globalize_path(path).simplify_path()
    _serial += 1
    _pending_path = "%s.backup-warm-%d-%d-%d.pending" % [absolute,OS.get_process_id(),get_instance_id(),_serial]
    _thread = Thread.new()
    if _thread.start(_prepare_backup.bind(absolute,_pending_path,source_hash),Thread.PRIORITY_LOW) != OK:
        _thread = null
        _pending_path = ""
        return false
    started += 1
    return true

func busy() -> bool:
    return _thread != null and _thread.is_alive()

func pending() -> bool:
    return _thread != null or not _pending_path.is_empty()

func take() -> Dictionary:
    if _thread == null:
        _remove_pending()
        return {}
    if busy():
        return {}
    var value: Variant = _thread.wait_to_finish()
    _thread = null
    # Also retires an issued private file if a script failure interrupted the
    # worker before its ordinary cleanup. This path belongs to this job alone.
    last_result = value if value is Dictionary else {"ok":false,"reason":"worker failed"}
    _remove_pending()
    return last_result.duplicate()

func shutdown() -> void:
    closed = true
    if _thread != null:
        var value: Variant = _thread.wait_to_finish()
        _thread = null
        last_result = value if value is Dictionary else {"ok":false,"reason":"worker failed"}
    _remove_pending()

func _remove_pending() -> void:
    if not _pending_path.is_empty() and FileAccess.file_exists(_pending_path):
        if DirAccess.remove_absolute(_pending_path) != OK:
            # Retain ownership and disable new admissions instead of churning
            # abandoned private copies when the filesystem refuses cleanup.
            last_result["cleanup_failed"] = true
            return
    _pending_path = ""

## A narrow virtual file operation permits corruption/failure fixtures without
## replacing the worker's source guards, hashing, rename or cleanup algorithm.
func _copy_source(source: String, pending_path: String) -> Error:
    return DirAccess.copy_absolute(source,pending_path)

func _prepare_backup(source: String, pending_path: String, expected: String) -> Dictionary:
    # CopyFile can hold an OS read handle on the primary. Serialize the whole
    # source operation with cooperative writers, not just its final rename.
    STATE._file_write_mutex.lock()
    var value: Variant = _prepare_backup_locked(source,pending_path,expected)
    STATE._file_write_mutex.unlock()
    return value if value is Dictionary else {"ok":false,"reason":"worker failed"}

func _prepare_backup_locked(source: String, pending_path: String, expected: String) -> Dictionary:
    var began := Time.get_ticks_usec()
    var result := {"ok":false,"reason":"source changed","copied":false,"installed":false,
        "worker_is_main":OS.get_thread_caller_id() == OS.get_main_thread_id(),"worker_usec":0}
    # The caller validated this exact source hash on the main thread. Recheck
    # its bytes here; an external writer must not authorize a different backup.
    if STATE._file_hash(source) == expected:
        if STATE._backup_matches(source,expected):
            result.ok = true
            result.reason = "already verified"
        else:
            var status := _copy_source(source,pending_path)
            result.copied = status == OK
            if status != OK:
                result.reason = "copy failed"
            elif STATE._file_hash(source) != expected:
                result.reason = "source changed after copy"
            elif STATE._file_hash(pending_path) != expected or not STATE._files_identical(pending_path,source):
                result.reason = "copied bytes changed"
            else:
                # Only the known-good source becomes .bak. Destination data is
                # installed later by the original main-thread write_candidate.
                # A second WorldState in this process cannot install a newer
                # primary/backup between this final source guard and rename.
                if STATE._file_hash(source) != expected:
                    result.reason = "source changed after copy"
                elif STATE._backup_matches(source,expected):
                    result.ok = true
                    result.reason = "already verified"
                else:
                    status = _rename_backup(pending_path,source+".bak")
                    result.ok = status == OK
                    result.installed = status == OK
                    result.reason = "verified source backed up" if status == OK else "backup install failed"
    if FileAccess.file_exists(pending_path):
        DirAccess.remove_absolute(pending_path)
    result.worker_usec = Time.get_ticks_usec()-began
    return result

func _rename_backup(pending_path: String, backup_path: String) -> Error:
    return DirAccess.rename_absolute(pending_path,backup_path)
