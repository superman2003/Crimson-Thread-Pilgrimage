extends RefCounted
## Recoverable replacement: Godot's Windows rename removes an existing target.
const KEYS := ["master", "music", "sfx", "ambience"]
const MAX_BYTES := 1048576
const TEMP_SUFFIX := ".audio-pending"
const BACKUP_SUFFIX := ".audio-backup"
const LOCK_SUFFIX := ".audio-lock"
var quarantine_current := false

func valid(values: Dictionary) -> bool:
    if values.size() != KEYS.size():return false
    for key in KEYS:
        var value: Variant = values.get(key)
        if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or float(value) < 0.0 or float(value) > 100.0:return false
    return true

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
        file.store_string("audio preference transaction")
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
    return _move(backup,path + ".audio-recovered." + _tag())

func recover(path: String) -> int:
    var absolute := ProjectSettings.globalize_path(path)
    var lock := _lock(absolute)
    if lock.is_empty():return ERR_BUSY
    var result := _recover_locked(absolute)
    _unlock(lock)
    return result

func _stage(candidate: ConfigFile, temporary: String) -> int:
    return candidate.save(temporary)

func _place(temporary: String, path: String) -> int:
    return _move(temporary,path)

func _install(temporary: String, path: String) -> int:
    var absolute := ProjectSettings.globalize_path(path)
    var staged := ProjectSettings.globalize_path(temporary)
    var lock := _lock(absolute)
    if lock.is_empty():return ERR_BUSY
    var result := _recover_locked(absolute)
    var backup := absolute + BACKUP_SUFFIX
    var had_original := FileAccess.file_exists(absolute)
    if result == OK and had_original:result = _move(absolute,backup)
    if result == OK:
        result = _place(staged,absolute)
        if result != OK and had_original:
            var restored := _move(backup,absolute)
            if restored != OK:result = restored # backup remains recoverable
        elif result == OK and had_original:
            if quarantine_current:_move(backup,absolute + ".audio-corrupt." + _tag())
            else:DirAccess.remove_absolute(backup)
    _unlock(lock)
    return result

func save(path: String, values: Dictionary) -> int:
    if path.is_empty() or not valid(values):return ERR_INVALID_DATA
    var recovered := recover(path)
    if recovered != OK:return recovered
    var candidate := ConfigFile.new()
    quarantine_current = false
    if FileAccess.file_exists(path):
        var source := FileAccess.open(path,FileAccess.READ)
        if source == null:return FileAccess.get_open_error()
        var length := source.get_length()
        source.close()
        if length > MAX_BYTES or candidate.load(path) != OK:
            quarantine_current = true
            candidate = ConfigFile.new()
    for key in KEYS:candidate.set_value("volumes",key,float(values[key]))
    var temporary := path + TEMP_SUFFIX + "." + _tag()
    var result := _stage(candidate,temporary)
    if result == OK:
        var staged := FileAccess.open(temporary,FileAccess.READ)
        if staged == null:result = FileAccess.get_open_error()
        else:
            var length := staged.get_length()
            staged.close()
            if length > MAX_BYTES:result = ERR_INVALID_DATA
    if result == OK:
        var readback := ConfigFile.new()
        result = readback.load(temporary)
        if result == OK and readback.encode_to_text() != candidate.encode_to_text():result = ERR_INVALID_DATA
    if result == OK:result = _install(temporary,path)
    if result != OK:DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
    return result
