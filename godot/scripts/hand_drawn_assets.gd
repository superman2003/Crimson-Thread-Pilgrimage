extends RefCounted
const RESOURCE_JOB := preload("res://scripts/background_resource_job.gd")

static var textures: Dictionary = {}
static var frame_cache: Dictionary = {}
static var manifest_cache: Dictionary = {}
# Immutable artwork is shared across region leases. At most two background
# texture requests survive cancellation; no caller waits on an unfinished get.
const MAX_TEXTURE_REQUESTS := 2
static var texture_requests: Dictionary = {}
static var texture_failures: Dictionary = {}
static var synchronous_texture_loads := 0
static var threaded_texture_loads := 0

static func character_manifest(family: String, id: String) -> String:
    var root := "res://assets/sprites/" + family + "/" + id + "/"
    return root + ("motion_manifest.json" if FileAccess.file_exists(root + "motion_manifest.json") else "manifest.json")

static func character_manifests(kind: String, data: Dictionary) -> Array[String]:
    var result: Array[String] = []
    if kind == "npc":
        var id := npc_art_id(String(data.get("id", "")))
        result.append(character_manifest("original_npcs", id))
        # Portraits deliberately keep their original art and original atlas.
        result.append("res://assets/sprites/original_npcs/" + id + "/manifest.json")
    elif kind == "enemy":
        var path := character_manifest("original_creatures", String(data.get("kind", "moss_larva")))
        if not FileAccess.file_exists(path): path = String(data.get("sprite", ""))
        if not path.is_empty(): result.append(path)
    return result

static func atlas_paths(path: String) -> Array[String]:
    if not path.ends_with(".json"):
        var single: Array[String] = []
        if not path.is_empty(): single.append(path)
        return single
    var data := manifest(path)
    var unique: Dictionary = {}
    for animation in data.get("animations", []):
        for pose in animation.get("frames", []):
            var atlas := String(pose.get("atlas", "")) if pose is Dictionary else String(pose)
            if not atlas.is_empty(): unique[atlas] = true
    var portrait_data: Variant = data.get("portrait", {})
    if portrait_data is Dictionary:
        var atlas := String(portrait_data.get("atlas", ""))
        if not atlas.is_empty(): unique[atlas] = true
    var result: Array[String] = []
    for atlas in unique: result.append(String(atlas))
    return result

static func request_texture(path: String) -> void:
    if textures.has(path) or texture_requests.has(path) or texture_failures.has(path): return
    if texture_requests.size() >= MAX_TEXTURE_REQUESTS: return
    if not ResourceLoader.exists(path):
        texture_failures[path] = "Texture resource does not exist: " + path
        return
    # Standalone SceneTree tools may never construct a World/region loader.
    # Keep the shared owners until the entire tree exits, then join them while
    # the resource/render backends are still alive. One hook serves every host.
    var tree := Engine.get_main_loop() as SceneTree
    if tree != null and not tree.root.tree_exiting.is_connected(shutdown_texture_requests):
        tree.root.tree_exiting.connect(shutdown_texture_requests, CONNECT_ONE_SHOT)
    var job := RESOURCE_JOB.new()
    var error := job.start(path, "Texture2D")
    if error != OK:
        texture_failures[path] = "Texture request failed: " + path
        return
    texture_requests[path] = job

static func poll_textures(max_operations: int = 2, budget_usec: int = 2000) -> int:
    var operations := 0
    var started := Time.get_ticks_usec()
    for path in texture_requests.keys():
        if operations >= max_operations or Time.get_ticks_usec() - started >= budget_usec: break
        var job: RefCounted = texture_requests[path]
        if not job.ready(): continue
        operations += 1
        _accept_texture(path, job.take())
        texture_requests.erase(path)
    return operations


static func _accept_texture(path: String, result: Dictionary) -> void:
    var loaded := result.get("resource") as Texture2D
    if loaded != null:
        textures[path] = loaded
        threaded_texture_loads += 1
    else:
        texture_failures[path] = "Texture background load failed: " + path

static func shutdown_texture_requests() -> void:
    # Whole-host teardown only. Publish immutable completed atlases so another
    # live host sharing this cache can still use them; never discard a Thread.
    for path in texture_requests:
        var job: RefCounted = texture_requests[path]
        _accept_texture(path, job.finish())
    texture_requests.clear()


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
    synchronous_texture_loads += 1
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
    return frame(data.get(item_id, data.get("thread_burst" if item_id.contains("_ability_") else "map_fragment", {})))

static func portrait(npc_id: String) -> Texture2D:
    var data := manifest("res://assets/sprites/original_npcs/" + npc_art_id(npc_id) + "/manifest.json")
    return frame(data.get("portrait", {}))

static func npc_art_id(npc_id: String) -> String:
    if FileAccess.file_exists("res://assets/sprites/original_npcs/" + npc_id + "/manifest.json"):
        return npc_id
    var fallback: Array[String] = ["npc_threadsmith_apprentice", "npc_canal_child", "npc_salt_librarian_ye", "npc_old_gardener", "npc_obsidian_guide", "npc_first_pilgrim_echo"]
    var parts := npc_id.split("_")
    var chapter := int(parts[1].trim_prefix("ch")) if parts.size() > 1 else 1
    return fallback[clampi(chapter - 1, 0, fallback.size() - 1)]
