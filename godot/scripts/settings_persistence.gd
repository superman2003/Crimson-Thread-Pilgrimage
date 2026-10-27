extends RefCounted
## Save a complete preference candidate before replacing the old file. A failure
## keeps live settings usable and marks them pending until a verified retry.
var pending := false
var last_error: Error = OK
var attempts := 0

func save(config: ConfigFile, path: String) -> Error:
    attempts += 1
    pending = true
    var temporary := path + ".pending.tmp"
    last_error = _write(config, temporary)
    if last_error == OK and not _verified(config, temporary):
        last_error = ERR_FILE_CORRUPT
    if last_error == OK:
        last_error = _install(temporary, path)
    if last_error != OK:
        if FileAccess.file_exists(temporary):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
        return last_error
    pending = false
    return OK

func _write(config: ConfigFile, path: String) -> Error:
    return config.save(path)

func _verified(config: ConfigFile, path: String) -> bool:
    var decoded := ConfigFile.new()
    if decoded.load(path)!=OK:return false
    if config.get_sections().size()!=decoded.get_sections().size():return false
    for section in config.get_sections():
        if not decoded.has_section(section):return false
        var keys:=config.get_section_keys(section)
        if keys.size()!=decoded.get_section_keys(section).size():return false
        for key in keys:
            if not decoded.has_section_key(section,key) or not _same(config.get_value(section,key),decoded.get_value(section,key)):
                return false
    return true

## ConfigFile's decimal parser may shift a stepped slider by a floating-point
## last bit (.43000000000000005 -> .4300000000000001 in Godot 4.6.1).
## Verify every stored field, allowing only machine-precision numeric drift.
func _same(first: Variant, second: Variant) -> bool:
    if typeof(first)!=typeof(second):return false
    if first is float:
        return is_finite(first) and is_finite(second) and absf(first-second)<=maxf(1.0,maxf(absf(first),absf(second)))*2.220446049250313e-16
    if first is Array:
        if first.size()!=second.size():return false
        for index in first.size():
            if not _same(first[index],second[index]):return false
        return true
    if first is Dictionary:
        if first.size()!=second.size():return false
        for key in first:
            if not second.has(key) or not _same(first[key],second[key]):return false
        return true
    if first is InputEvent:
        if not second is InputEvent or first.get_class()!=second.get_class():return false
        for property in first.get_property_list():
            if int(property.usage)&PROPERTY_USAGE_STORAGE:
                if not _same(first.get(property.name),second.get(property.name)):return false
        return true
    return first==second

func _install(temporary: String, path: String) -> Error:
    return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))

func reconcile(config: ConfigFile, path: String) -> void:
    if pending and _verified(config, path):
        pending = false
        last_error = OK

func message() -> String:
    return "设置尚未保存 · 本次仍有效（%d）" % last_error if pending else ""
