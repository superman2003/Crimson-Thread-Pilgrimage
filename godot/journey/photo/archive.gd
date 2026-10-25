extends RefCounted
const V := preload("res://journey/core/values.gd")
const LIMIT := 40

static func fresh() -> Dictionary:
    return {"version":1, "photos":[], "notes":{}, "favorites":[]}

static func valid(data: Dictionary) -> bool:
    if data.get("version") != 1 or not data.get("photos") is Array or data.photos.size() > LIMIT:
        return false
    if not data.get("notes") is Dictionary or not data.get("favorites") is Array:
        return false
    var known := {}
    for photo in data.photos:
        if not photo is Dictionary or not photo.get("path") is String or not photo.get("sha256") is String:
            return false
        if photo.sha256.length() != 64 or known.has(photo.path):
            return false
        if not V.count(photo.get("width"), 16384) or not V.count(photo.get("height"), 16384):
            return false
        if not V.count(photo.get("created"), 9999999999) or not photo.get("options") is Dictionary:
            return false
        known[photo.path] = true
    for id in data.notes:
        if not known.has(id) or not data.notes[id] is String or data.notes[id].length() > 800:
            return false
    for id in data.favorites:
        if not known.has(id):
            return false
    return V.json_safe(data, 0, [V.MAX_ITEMS])

static func add(data: Dictionary, photo: Dictionary) -> Dictionary:
    var result := data.duplicate(true)
    if result.photos.size() >= LIMIT:
        return result
    for record in result.photos:
        if record.path == photo.get("path"):
            return result
    result.photos.push_front(photo.duplicate(true))
    return result if valid(result) else data.duplicate(true)

static func annotate(data: Dictionary, path: String, note: String, favorite: bool) -> Dictionary:
    var result := data.duplicate(true)
    var found := false
    for photo in result.photos:
        if photo.path == path:
            found = true
            break
    if not found:
        return result
    var clean := V.text(note, 800)
    if clean.is_empty():
        result.notes.erase(path)
    else:
        result.notes[path] = clean
    result.favorites.erase(path)
    if favorite:
        result.favorites.append(path)
    return result

static func remove(data: Dictionary, path: String) -> Dictionary:
    var result := data.duplicate(true)
    for index in range(result.photos.size() - 1, -1, -1):
        if result.photos[index].path == path:
            result.photos.remove_at(index)
    result.notes.erase(path)
    result.favorites.erase(path)
    return result

static func records(data: Dictionary, query: String, favorites_only: bool) -> Array:
    var result := []
    for photo in data.photos:
        if favorites_only and not data.favorites.has(photo.path):
            continue
        if not V.matches(query, [String(photo.get("region", "")), String(photo.get("room", "")), String(data.notes.get(photo.path, ""))]):
            continue
        var row: Dictionary = photo.duplicate(true)
        row["favorite"] = data.favorites.has(photo.path)
        row["note"] = String(data.notes.get(photo.path, ""))
        result.append(row)
    return result

static func permitted(path: String, directory: String) -> bool:
    return path.simplify_path() == path and path.get_base_dir() == directory.simplify_path() and path.get_file().begins_with("pilgrimage_") and path.ends_with(".png")

static func inspect(photo: Dictionary, directory: String) -> Dictionary:
    var path := String(photo.get("path", ""))
    if not permitted(path, directory):
        return {"ok":false, "reason":"照片路径不属于拍照目录。"}
    if not FileAccess.file_exists(path):
        return {"ok":false, "reason":"照片文件已经移动或移除；辅助手记仍保留。"}
    if FileAccess.get_sha256(path) != String(photo.get("sha256", "")):
        return {"ok":false, "reason":"照片内容已经变化；保留文件，不自动读取。"}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null or file.get_length() > 16777216:
        return {"ok":false, "reason":"照片无法读取或超出预览上限。"}
    var bytes := file.get_length()
    file.close()
    return {"ok":true, "bytes":bytes, "path":path}

static func report(data: Dictionary) -> String:
    var lines: Array[String] = ["巡礼相册索引", "图片文件位于游戏用户目录，此索引不包含图片字节。", ""]
    for photo in data.photos:
        lines.append(V.date(int(photo.created)) + " · " + String(photo.get("region", "")))
        lines.append("文件：" + String(photo.path))
        lines.append("SHA256：" + String(photo.sha256))
        if data.notes.has(photo.path):
            lines.append("手记：" + String(data.notes[photo.path]))
        lines.append("")
    return "\n".join(lines)

static func presets() -> Array:
    return [
        {"id":"natural", "name":"原色", "exposure":1.0, "saturation":1.0, "warmth":0.0},
        {"id":"monochrome", "name":"墨色", "exposure":1.1, "saturation":0.0, "warmth":0.0},
        {"id":"warm", "name":"旧铜暖调", "exposure":1.0, "saturation":0.8, "warmth":0.1},
        {"id":"cool", "name":"雨渠冷调", "exposure":0.9, "saturation":0.9, "warmth":-0.1}
    ]

static func camera_options(id: String) -> Dictionary:
    var result := {"zoom":1.0, "exposure":1.0, "saturation":1.0, "warmth":0.0, "guides":"thirds", "letterbox":false, "include_guides":false}
    for preset in presets():
        if preset.id == id:
            for key in ["exposure", "saturation", "warmth"]:
                result[key] = float(preset[key])
            break
    return result
