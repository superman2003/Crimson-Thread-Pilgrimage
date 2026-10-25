extends RefCounted
## Bounded auxiliary records. Never opens or writes a gameplay save.
const MAX_BYTES := 262144
var path := ""
var error := ""
var writable := true
var writer: Callable

func configure(feature: String, journey: String) -> void:
    path = "user://journey_desks/%s_%s.json" % [feature.validate_filename().left(40), journey.sha256_text()]
    error = ""
    writable = true

func read() -> Dictionary:
    if not FileAccess.file_exists(path):return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:return _invalid("记录无法读取，保留原文件。")
    if file.get_length() > MAX_BYTES:return _invalid("记录过大，保留原文件。")
    var parser := JSON.new()
    if parser.parse(file.get_as_text()) != OK:return _invalid("记录损坏，保留原文件。")
    var data: Variant = parser.data
    if not data is Dictionary or typeof(data.get("version")) not in [TYPE_INT, TYPE_FLOAT] or data.version != 1 or not data.get("payload") is Dictionary:
        return _invalid("记录版本不兼容，保留原文件。")
    return data.payload.duplicate(true)

func _invalid(reason: String) -> Dictionary:
    writable = false
    error = reason
    return {}

func write(payload: Dictionary) -> bool:
    if not writable:return false
    var data := {"version":1, "payload":payload.duplicate(true)}
    var serialized := JSON.stringify(data)
    if serialized.to_utf8_buffer().size() > MAX_BYTES:
        error = "记录容量已满。"
        return false
    var result := OK
    if writer.is_valid():result = int(writer.call(data))
    else:
        result = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
        if result == OK:
            var temporary := path + ".tmp"
            var file := FileAccess.open(temporary, FileAccess.WRITE)
            if file == null:result = FileAccess.get_open_error()
            else:
                file.store_string(serialized)
                file.flush()
                result = file.get_error()
                file.close()
                if result == OK:result = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))
            if result != OK:DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
    error = "" if result == OK else "记录保存失败（%d），原记录未更改。" % result
    return result == OK
