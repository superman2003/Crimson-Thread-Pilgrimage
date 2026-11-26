extends RefCounted
const RESOURCE_JOB := preload("res://scripts/background_resource_job.gd")
const LOOP_ENTRIES_PATH := "res://data/character_loop_entries.json"

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
    if family=="original_creatures" and FileAccess.file_exists(root+"motion_redraw_manifest.json"):return root+"motion_redraw_manifest.json"
    if family=="original_creatures" and FileAccess.file_exists(root+"motion_transition_manifest.json"):return root+"motion_transition_manifest.json"
    # Onion-skin drawings supersede earlier generated and authored layers.
    if family=="original_creatures" and FileAccess.file_exists(root+"motion_onion_manifest.json"):return root+"motion_onion_manifest.json"
    if family=="original_creatures" and FileAccess.file_exists(root+"motion_v8_manifest.json"):return root+"motion_v8_manifest.json"
    if FileAccess.file_exists(root+"boss_behavior_manifest.json"):return root+"boss_behavior_manifest.json"
    if FileAccess.file_exists(root+"combat_motion_v7_manifest.json"):return root+"combat_motion_v7_manifest.json"
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
        var skill_manifest := "res://assets/vfx/minor_enemy_skills/manifest.json"
        if FileAccess.file_exists(skill_manifest):
            var skill_path := String(manifest(skill_manifest).get("creatures", {}).get(String(data.get("kind", "")), {}).get("texture", ""))
            if not skill_path.is_empty(): result.append(skill_path)
    elif kind == "item":
        var item_id := String(data.get("item_id", data.get("kind", "bell_key")))
        var path := String(item_spec(item_id).get("atlas", ""))
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


static func _collect_enemy_dicts(node: Variant, out: Array) -> void:
    if node is Array:
        for item in node:
            _collect_enemy_dicts(item, out)
    elif node is Dictionary:
        if node.has("kind") and node["kind"] is String and not String(node["kind"]).is_empty():
            out.append(node)
        for key in ["enemy_spawns", "enemies", "spawns", "waves", "wave_enemies", "encounters", "ambushes", "gauntlets", "arenas", "optional_challenges"]:
            if node.has(key):
                _collect_enemy_dicts(node[key], out)


static func collect_region_assets(config: Dictionary) -> Dictionary:
    var manifests: Dictionary = {}
    var keep_textures: Dictionary = {}
    if config.is_empty():
        return {"manifests": manifests, "textures": keep_textures}
    var enemy_entries: Array = []
    _collect_enemy_dicts(config.get("enemy_spawns", []), enemy_entries)
    var boss: Variant = config.get("boss", {})
    if boss is Dictionary and not boss.is_empty():
        enemy_entries.append(boss)
    for key in ["encounters", "waves", "ambushes", "gauntlets", "arenas", "optional_challenges"]:
        if config.has(key):
            _collect_enemy_dicts(config[key], enemy_entries)
    for enemy in enemy_entries:
        for mpath in character_manifests("enemy", enemy):
            manifests[mpath] = true
            for apath in atlas_paths(mpath):
                keep_textures[apath] = true
    for npc in config.get("npcs", []):
        if not npc is Dictionary:
            continue
        for mpath in character_manifests("npc", npc):
            manifests[mpath] = true
            for apath in atlas_paths(mpath):
                keep_textures[apath] = true
    return {"manifests": manifests, "textures": keep_textures}


static func evict_unused_region_assets(configs: Array) -> Dictionary:
    var keep_manifests: Dictionary = {}
    var keep_textures: Dictionary = {}
    for entry in configs:
        if entry is Dictionary and not entry.is_empty():
            var assets := collect_region_assets(entry)
            for mpath in assets.manifests:
                keep_manifests[mpath] = true
            for apath in assets.textures:
                keep_textures[apath] = true
    var evicted_frames := 0
    for key in frame_cache.keys():
        var path := String(key)
        if not path.begins_with("res://assets/sprites/original_creatures/") and not path.begins_with("res://assets/sprites/original_npcs/"):
            continue
        if not keep_manifests.has(path):
            frame_cache.erase(key)
            evicted_frames += 1
    var evicted_textures := 0
    for key in textures.keys():
        var path := String(key)
        if not path.begins_with("res://assets/sprites/original_creatures/") and not path.begins_with("res://assets/sprites/original_npcs/") and not path.begins_with("res://assets/vfx/minor_enemy_skills/"):
            continue
        if not keep_textures.has(path) and not texture_requests.has(path):
            textures.erase(key)
            evicted_textures += 1
    return {"evicted_textures": evicted_textures, "evicted_frames": evicted_frames,
        "retained_textures": textures.size(), "retained_frames": frame_cache.size()}


## Report cached texture/frame counts, an uncompressed RGBA8 pixel-footprint
## estimate (`estimated_rgba_bytes = w * h * 4`, not compressed GPU VRAM), and
## Godot's RenderingServer texture memory counter (`rendering_texture_mem_bytes`,
## which is 0 under the headless Dummy renderer and non-zero only on a real GPU backend).
static func cache_stats() -> Dictionary:
    var seen_rids: Dictionary = {}
    var estimated_rgba_bytes := 0
    for value in textures.values():
        if value is Texture2D:
            var rid: RID = value.get_rid()
            if not seen_rids.has(rid):
                seen_rids[rid] = true
                estimated_rgba_bytes += value.get_width() * value.get_height() * 4
    var rendering_texture_mem_bytes := int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED))
    return {
        "textures": textures.size(),
        "frames": frame_cache.size(),
        "estimated_rgba_bytes": estimated_rgba_bytes,
        "rendering_texture_mem_bytes": rendering_texture_mem_bytes,
        "gpu_metric_available": rendering_texture_mem_bytes > 0,
    }


static func clear_caches() -> void:
    shutdown_texture_requests()
    textures.clear()
    frame_cache.clear()
    manifest_cache.clear()
    texture_failures.clear()


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
    if path.begins_with("res://assets/sprites/original_creatures/") or path.begins_with("res://assets/sprites/original_npcs/"):
        var entries: Dictionary = manifest(LOOP_ENTRIES_PATH).get(path, {})
        if not entries.is_empty():
            result.set_meta(&"character_loop_entries", entries)
    frame_cache[path] = result
    return result

## Enter a repeating stance on the drawing closest to the one on screen.
## One-shot gestures and attack phases always play in their authored order.
static func play_matched_loop(sprite: AnimatedSprite2D, action: StringName, clock := Vector2.ZERO) -> void:
    if sprite.animation == action:
        sprite.play(action)
        return
    var frames := sprite.sprite_frames
    var entries: Dictionary = frames.get_meta(&"character_loop_entries", {})
    var target: Dictionary = entries.get(action, {})
    var matches: Array = target.get(sprite.animation, [])
    var count := frames.get_frame_count(action)
    var entry := clampi(int(clock.x), 0, maxi(0, count - 1))
    if target.get("count", 0) == count and sprite.frame < matches.size() and matches.size() == frames.get_frame_count(sprite.animation):
        var matched := int(matches[sprite.frame])
        if matched >= 0 and matched < count:
            entry = matched
    sprite.play(action)
    if count > 0:
        sprite.set_frame_and_progress(entry, clock.y if entry == int(clock.x) else 0.0)

## Per-frame body size corrections measured by tools/build_creature_frame_fit.py:
## {animation: [[scale, pivot_x, pivot_y], ...]}. Empty when the file was measured
## for another drawing layer than the one being loaded.
static func frame_fit(manifest_path: String) -> Dictionary:
    var path := manifest_path.get_base_dir() + "/frame_fit.json"
    if not FileAccess.file_exists(path): return {}
    var data := manifest(path)
    if String(data.get("manifest", "")) != manifest_path.get_file(): return {}
    return data.get("frames", {})

static func item_spec(item_id: String) -> Dictionary:
    var data := manifest("res://assets/sprites/original_items/manifest.json")
    return data.get(item_id, data.get("thread_burst" if item_id.contains("_ability_") else "map_fragment", {}))

static func item(item_id: String) -> Texture2D:
    return frame(item_spec(item_id))

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
