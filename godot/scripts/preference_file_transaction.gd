extends RefCounted
## Same-directory, no-overwrite installation. A surviving backup is recovered
## before the next read/write. Lock ownership is explicit; uncertain locks fail closed.
const BACKUP_SUFFIX := ".preference-backup"
const LOCK_SUFFIX := ".preference-lock"

func _tag() -> String:
    return "%d_%s" % [OS.get_process_id(),Crypto.new().generate_random_bytes(16).hex_encode()]

func _move(source: String, target: String) -> int:
    # All callers hold the per-path lock. Never invoke Windows rename-over-file.
    if FileAccess.file_exists(target) or DirAccess.dir_exists_absolute(target):return ERR_ALREADY_EXISTS
    return DirAccess.rename_absolute(source,target)

func _owner_running(pid: int) -> bool:
    if pid == OS.get_process_id():return true
    # Unix is_process_running uses waitpid: it can only query this process's
    # children. A lock can belong to another game instance, or to ourselves.
    if OS.get_name() == "Linux":
        # Fail closed if procfs is unavailable; never steal an uncertain lock.
        if not DirAccess.dir_exists_absolute("/proc/self"):return true
        return DirAccess.dir_exists_absolute("/proc/%d" % pid)
    if OS.get_name() == "Windows":return OS.is_process_running(pid)
    return true

func _lock(path: String) -> Dictionary:
    var target := path + LOCK_SUFFIX
    for attempt in 2:
        var owner := "owner_" + _tag()
        var candidate := target + "." + owner
        if DirAccess.make_dir_absolute(candidate) != OK:return {}
        var file := FileAccess.open(candidate.path_join(owner),FileAccess.WRITE)
        if file == null:
            DirAccess.remove_absolute(candidate)
            return {}
        file.store_string("preference transaction")
        file.close()
        # Published lock directories are nonempty and cannot be overwritten.
        if DirAccess.rename_absolute(candidate,target) == OK:
            return {"path":target,"owner":owner}
        DirAccess.remove_absolute(candidate.path_join(owner))
        DirAccess.remove_absolute(candidate)
        var directory := DirAccess.open(target)
        if directory == null:continue
        var files := directory.get_files()
        if files.size() == 1 and files[0].begins_with("owner_"):
            var parts := String(files[0]).split("_")
            if parts.size() != 3 or not parts[1].is_valid_int():return {}
            var pid := int(parts[1])
            if pid <= 0 or _owner_running(pid):return {}
            # Remove only the observed dead owner's unique file. A competing
            # recovery cannot remove a different, newly acquired owner's file.
            if DirAccess.remove_absolute(target.path_join(files[0])) != OK:return {}
        elif not files.is_empty():return {}
        DirAccess.remove_absolute(target) # succeeds only for an empty directory
    return {}

func _unlock(lock: Dictionary) -> void:
    DirAccess.remove_absolute(String(lock.path).path_join(String(lock.owner)))
    DirAccess.remove_absolute(lock.path)

func _recover_locked(path: String) -> int:
    var backup := path + BACKUP_SUFFIX
    if not FileAccess.file_exists(backup):return OK
    if not FileAccess.file_exists(path):return _move(backup,path)
    # The replacement reached disk before interruption. Retain previous bytes.
    return _move(backup,path + ".preference-recovered." + _tag())

func recover(path: String) -> int:
    var absolute := ProjectSettings.globalize_path(path)
    var lock := _lock(absolute)
    if lock.is_empty():return ERR_BUSY
    var result := _recover_locked(absolute)
    _unlock(lock)
    return result

func temporary(path: String) -> String:
    return path + ".preference-pending." + _tag()

func _place(source: String, target: String) -> int:
    return _move(source, target)

func install(temporary_path: String, path: String) -> int:
    var absolute := ProjectSettings.globalize_path(path)
    var staged := ProjectSettings.globalize_path(temporary_path)
    if staged.get_base_dir() != absolute.get_base_dir() or staged == absolute:
        return ERR_INVALID_PARAMETER
    var lock := _lock(absolute)
    if lock.is_empty():return ERR_BUSY
    var result := _recover_locked(absolute)
    var backup := absolute + BACKUP_SUFFIX
    var had_original := FileAccess.file_exists(absolute)
    if result == OK and had_original:result = _move(absolute, backup)
    if result == OK:
        result = _place(staged, absolute)
        if result != OK and had_original:
            var restored := _move(backup, absolute)
            if restored != OK:result = restored # leave backup for a later reader
        elif result == OK and had_original:
            DirAccess.remove_absolute(backup)
    _unlock(lock)
    return result
