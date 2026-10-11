extends RefCounted

static var textures: Dictionary = {}
static var frame_cache: Dictionary = {}
static var manifest_cache: Dictionary = {}

static func manifest(path: String) -> Dictionary:
    if manifest_cache.has(path):
        return manifest_cache[path]
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var value: Variant = JSON.parse_string(file.get_as_text())
    var data: Dictionary = value if value is Dictionary else {}
    manifest_cache[path] = data
    return data

static func texture(path: String) -> Texture2D:
    if textures.has(path):
        return textures[path]
    var result: Texture2D
    if ResourceLoader.exists(path):
        result = ResourceLoader.load(path) as Texture2D
    if result == null and FileAccess.file_exists(path):
        var raw := Image.load_from_file(path)
        if raw != null:
            result = ImageTexture.create_from_image(raw)
    if result != null:
        textures[path] = result
    return result

static func rect(value: Array) -> Rect2:
    return Rect2(float(value[0]),float(value[1]),float(value[2]),float(value[3]))

static func frame(value: Variant) -> Texture2D:
    if value is String:
        return texture(value)
    if not value is Dictionary:
        return null
    var atlas := AtlasTexture.new()
    atlas.atlas = texture(String(value.get("atlas", "")))
    if atlas.atlas == null:
        return null
    atlas.region = rect(value.get("region", [0,0,1,1]))
    if value.has("margin"):
        atlas.margin = rect(value["margin"])
    atlas.filter_clip = true
    return atlas

static func frames(path: String) -> SpriteFrames:
    if frame_cache.has(path):
        return frame_cache[path]
    var data := manifest(path)
    if data.is_empty():
        return null
    var result := SpriteFrames.new()
    result.remove_animation("default")
    for value in data.get("animations", []):
        var name := String(value.get("name", "idle"))
        result.add_animation(name)
        result.set_animation_speed(name, float(value.get("fps", 8)))
        result.set_animation_loop(name, bool(value.get("loop", true)))
        for pose in value.get("frames", []):
            var asset := frame(pose)
            if asset != null:
                result.add_frame(name, asset)
    frame_cache[path] = result
    return result

static func item(item_id: String) -> Texture2D:
    var data := manifest("res://assets/sprites/original_items/manifest.json")
    return frame(data.get(item_id, data.get("currency", {})))

static func portrait(npc_id: String) -> Texture2D:
    var data := manifest("res://assets/sprites/original_npcs/" + npc_id + "/manifest.json")
    return frame(data.get("portrait", {}))
