extends RefCounted
## Auxiliary records never replace the game's save. Publish after verified rename.
const VALUES := preload("res://journey/core/values.gd")
const MAX_BYTES := 2097152
var directory := "user://journey_workbench"
var scope := ""
var identities: Dictionary = {}
var error := ""
var writable := true

func configure(save_path: String) -> void:
    scope = save_path.sha256_text()
    identities.clear()
    error = ""

func path_for(id: String) -> String:
    if id.is_empty() or not id.is_valid_identifier() or scope.is_empty():
        return ""
    return directory.path_join(scope + "_" + id + ".json")

func identity(path: String) -> String:
    return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"

func read(id: String, initial: Dictionary) -> Dictionary:
    var path := path_for(id)
    error = ""
    if path.is_empty():
        error = "记录身份无效。"
        return initial.duplicate(true)
    var source := identity(path)
    identities[id] = source
    if source == "missing":
        return initial.duplicate(true)
    var envelope := VALUES.read_json(path, MAX_BYTES)
    if envelope.get("version") != 1 or envelope.get("scope") != scope or envelope.get("feature") != id or not envelope.get("data") is Dictionary:
        error = "辅助记录无法读取；原文件保留。"
        identities[id] = "unreadable"
        return initial.duplicate(true)
    if identity(path) != source:
        error = "记录在读取期间变化，请重新打开。"
        identities[id] = "unreadable"
        return initial.duplicate(true)
    return envelope.data.duplicate(true)

func write(id: String, candidate: Dictionary) -> bool:
    error = ""
    var path := path_for(id)
    if not writable or path.is_empty():
        error = "记录暂不能写入或身份无效。"
        return false
    if DirAccess.make_dir_recursive_absolute(directory) != OK:
        error = "无法建立记录目录。"
        return false
    var lock := path + ".writer_lock"
    if DirAccess.make_dir_absolute(lock) != OK:
        error = "其它实例正在保存此记录；请稍后重试。"
        return false
    var success := _write_locked(id, candidate)
    DirAccess.remove_absolute(lock)
    return success

func _write_locked(id: String, candidate: Dictionary) -> bool:
    error = ""
    var path := path_for(id)
    if not writable:
        error = "记录暂不能写入，请保留当前内容重试。"
        return false
    if path.is_empty() or not VALUES.json_safe(candidate, 0, [VALUES.MAX_ITEMS]):
        error = "候选记录无效。"
        return false
    var expected := String(identities.get(id, "missing"))
    if expected == "unreadable" or identity(path) != expected:
        error = "磁盘记录已变化或无法读取，请重新打开后再编辑。"
        return false
    var envelope := {"version":1, "scope":scope, "feature":id, "data":candidate}
    var raw := JSON.stringify(envelope)
    if raw.to_utf8_buffer().size() > MAX_BYTES:
        error = "辅助记录超过大小上限。"
        return false
    if DirAccess.make_dir_recursive_absolute(directory) != OK:
        error = "无法建立记录目录。"
        return false
    var temporary := path + ".pending_" + str(Time.get_ticks_usec())
    var file := FileAccess.open(temporary, FileAccess.WRITE)
    if file == null:
        error = "无法建立候选文件。"
        return false
    file.store_string(raw)
    file.flush()
    var status := file.get_error()
    file.close()
    if status != OK or FileAccess.get_file_as_string(temporary) != raw:
        DirAccess.remove_absolute(temporary)
        error = "候选文件校验失败。"
        return false
    if identity(path) != expected:
        DirAccess.remove_absolute(temporary)
        error = "写入前发现其它实例已更新记录。"
        return false
    if DirAccess.rename_absolute(temporary, path) != OK:
        DirAccess.remove_absolute(temporary)
        error = "无法安装候选记录。"
        return false
    identities[id] = raw.sha256_text()
    return true

func export_text(name: String, contents: String) -> Dictionary:
    var clean := name.validate_filename().left(80)
    if clean.is_empty() or contents.to_utf8_buffer().size() > MAX_BYTES:
        return {"ok":false, "reason":"导出名称或内容无效。"}
    var destination := directory.path_join("exports")
    if DirAccess.make_dir_recursive_absolute(destination) != OK:
        return {"ok":false, "reason":"无法建立导出目录。"}
    var path := destination.path_join(str(Time.get_unix_time_from_system()).replace(".", "_") + "_" + clean)
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return {"ok":false, "reason":"无法建立导出文件。"}
    file.store_string(contents)
    file.flush()
    var status := file.get_error()
    file.close()
    if status != OK or FileAccess.get_file_as_string(path) != contents:
        return {"ok":false, "reason":"导出内容未通过校验。"}
    return {"ok":true, "path":path, "reason":"已导出到 " + ProjectSettings.globalize_path(path)}
