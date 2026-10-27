extends RefCounted
## Stage, validate and atomically replace; never truncate the last saved settings.
const KEYS := ["master", "music", "sfx", "ambience"]
const MAX_BYTES := 1048576
const TEMP_SUFFIX := ".audio-pending"

func valid(values: Dictionary) -> bool:
    if values.size() != KEYS.size():return false
    for key in KEYS:
        var value: Variant = values.get(key)
        if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or float(value) < 0.0 or float(value) > 100.0:return false
    return true

func _stage(candidate: ConfigFile, temporary: String) -> int:
    return candidate.save(temporary)

func _install(temporary: String, path: String) -> int:
    return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))

func save(path: String, values: Dictionary) -> int:
    if path.is_empty() or not valid(values):return ERR_INVALID_DATA
    var candidate := ConfigFile.new()
    if FileAccess.file_exists(path):
        var source := FileAccess.open(path, FileAccess.READ)
        if source == null:return FileAccess.get_open_error()
        var length := source.get_length()
        source.close()
        if length > MAX_BYTES:return ERR_INVALID_DATA
        var loaded := candidate.load(path)
        if loaded != OK:return loaded
    # Preserve other sections and extra future volume keys.
    for key in KEYS:
        candidate.set_value("volumes", key, float(values[key]))
    var temporary := path + TEMP_SUFFIX
    var result := _stage(candidate, temporary)
    if result == OK:
        var staged := FileAccess.open(temporary, FileAccess.READ)
        if staged == null:result = FileAccess.get_open_error()
        else:
            var length := staged.get_length()
            staged.close()
            if length > MAX_BYTES:result = ERR_INVALID_DATA
    if result == OK:
        var readback := ConfigFile.new()
        result = readback.load(temporary)
        if result == OK and readback.encode_to_text() != candidate.encode_to_text():
            result = ERR_INVALID_DATA
    if result == OK:result = _install(temporary, path)
    if result != OK:DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
    return result

