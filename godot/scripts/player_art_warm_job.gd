extends RefCounted
## Private immutable imported-image warmup. The worker touches no SceneTree,
## scripts' mutable caches, gameplay state or SpriteFrames. Its result keeps
## native cache entries alive until the actual Player has taken its own refs.
const PLAYER := preload("res://scripts/player_controller.gd")
const RESOURCE_JOB := preload("res://scripts/background_resource_job.gd")
var _thread: Thread
## Headless Dummy-renderer result; see RESOURCE_JOB.off_thread_loading_safe().
var _inline_result: Dictionary = {}
var _inline_pending := false
var closed := false

func begin(manifest_path: String = PLAYER.PLAYER_MANIFEST, idle_path: String = PLAYER.LAYERED_IDLE.MANIFEST_PATH) -> int:
    if closed or _thread != null or _inline_pending: return ERR_ALREADY_IN_USE
    if not RESOURCE_JOB.off_thread_loading_safe():
        _inline_result = _load(manifest_path, idle_path)
        _inline_pending = true
        return OK
    _thread = Thread.new()
    var error := _thread.start(_load.bind(manifest_path, idle_path), Thread.PRIORITY_LOW)
    if error != OK: _thread = null
    return error

func ready() -> bool:
    return _inline_pending or (_thread != null and not _thread.is_alive())

func take() -> Dictionary:
    if not ready(): return {}
    if _inline_pending:
        var inline := _inline_result
        _inline_result = {}
        _inline_pending = false
        return inline
    var result: Dictionary = _thread.wait_to_finish()
    _thread = null
    return result

func shutdown() -> void:
    closed = true
    _inline_result = {}
    _inline_pending = false
    # Whole-host teardown only. Cancellation keeps this one bounded owner;
    # background cache data cannot publish a player or alter a save by itself.
    if _thread != null:
        _thread.wait_to_finish()
        _thread = null

static func _read_manifest(path: String) -> Dictionary:
    var stamp := FileAccess.get_modified_time(path)
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null: return {"error":"无法读取主角素材清单。"}
    var parser := JSON.new()
    if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary or FileAccess.get_modified_time(path) != stamp:
        return {"error":"主角素材清单无效或已改变。"}
    return {"data":parser.data,"error":""}

static func _path(value: String) -> String:
    return "res://" + value.trim_prefix("godot/") if value.begins_with("godot/") else value

static func _load(manifest_path: String, idle_path: String) -> Dictionary:
    var started := Time.get_ticks_usec()
    var read := _read_manifest(manifest_path)
    if not String(read.error).is_empty(): return read
    var data: Dictionary = read.data
    var paths: Dictionary = {}
    if data.has("frames"):
        if not data.frames is Dictionary: return {"error":"主角帧清单无效。"}
        for value in data.frames.values():
            if not value is String: return {"error":"主角帧路径无效。"}
            paths[_path(value)] = true
    else:
        if not data.get("animations") is Array: return {"error":"主角动画清单无效。"}
        for animation in data.animations:
            if not animation is Dictionary or not animation.get("frames") is Array: return {"error":"主角动画帧清单无效。"}
            for value in animation.frames:
                if not value is String: return {"error":"主角动画帧路径无效。"}
                paths[_path(value)] = true
    # Layered idle is optional in the existing Player attach contract. Missing
    # or unsupported optional assets must leave the original body idle usable.
    var optional_paths: Dictionary = {}
    var optional_skipped: Array[String] = []
    read = _read_manifest(idle_path)
    if not String(read.error).is_empty():
        optional_skipped.append(idle_path)
    else:
        var idle: Dictionary = read.data
        for key in ["support", "cloth"]:
            if not idle.get(key) is Dictionary or not idle[key].get("file") is String:
                optional_skipped.append(String(key))
                continue
            optional_paths[idle_path.get_base_dir().path_join(String(idle[key].file))] = true
    if paths.is_empty(): return {"error":"主角素材清单没有图片。"}
    var textures: Dictionary = {}
    for path in paths:
        # Procedural GPU resources can require a main-render-thread callback.
        # Only imported images belong to this pipeline, including legacy paths.
        if String(path).get_extension().to_lower() in ["tres", "res"] or not ResourceLoader.exists(path, "Texture2D"):
            return {"error":"主角图片缺失或不是受支持的导入图片：" + String(path)}
        var texture := ResourceLoader.load(path, "Texture2D") as Texture2D
        if texture == null: return {"error":"无法预读主角图片：" + String(path)}
        textures[path] = texture
    for path in optional_paths:
        if String(path).get_extension().to_lower() in ["tres", "res"] or not ResourceLoader.exists(path, "Texture2D"):
            optional_skipped.append(String(path))
            continue
        var texture := ResourceLoader.load(path, "Texture2D") as Texture2D
        if texture != null: textures[path] = texture
        else: optional_skipped.append(String(path))
    return {"error":"", "textures":textures, "optional_skipped":optional_skipped,
        "worker_is_main":Thread.is_main_thread(), "worker_usec":Time.get_ticks_usec()-started}
